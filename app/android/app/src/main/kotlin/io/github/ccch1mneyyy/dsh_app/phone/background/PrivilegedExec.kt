package io.github.ccch1mneyyy.dsh_app.phone.background

import android.os.Bundle
import android.os.Process
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * `exec`: one shell command, run by whichever uid started this engine — root when the Root
 * channel launched it, shell (2000) when Shizuku or the self-ADB stream did.
 *
 * The engine does not decide whether the person wants this: the app does, in
 * [io.github.ccch1mneyyy.dsh_app.phone.PhoneControl], and only offers it on the Root channel.
 * What is here is the execution contract: a bounded wait, bounded output, and a process tree
 * that does not outlive its caller.
 */
internal object PrivilegedExec {
    /** Per stream. Enough for `ls`, `ps`, `cat` of a small file; larger output is cut, not buffered. */
    private const val MAX_OUTPUT_BYTES = 64 * 1024
    private const val DEFAULT_TIMEOUT_MS = 20_000
    private const val MIN_TIMEOUT_MS = 1_000
    private const val MAX_TIMEOUT_MS = 120_000
    private const val MAX_COMMAND_CHARS = 8_000
    private const val KILL_GRACE_MS = 500L

    fun run(request: Bundle): Bundle {
        val command = request.getString(Proto.COMMAND)?.takeIf { it.isNotBlank() }
            ?: return failure("invalidArguments")
        if (command.length > MAX_COMMAND_CHARS) return failure("invalidArguments")
        val uid = Process.myUid()
        if (uid != Process.ROOT_UID && uid != Process.SHELL_UID) return failure("rootRequired")

        val timeoutMs = request.getInt(Proto.TIMEOUT_MS, DEFAULT_TIMEOUT_MS)
            .coerceIn(MIN_TIMEOUT_MS, MAX_TIMEOUT_MS)

        val process = try {
            ProcessBuilder("/system/bin/sh", "-c", command)
                .redirectErrorStream(false)
                .apply {
                    environment().apply {
                        put("PATH", "/system/bin:/system/xbin:/sbin:/product/bin")
                        putIfAbsent("HOME", "/")
                    }
                }
                .start()
        } catch (_: Throwable) {
            return failure("deviceUnavailable")
        }

        // Nothing is fed to stdin: a command that reads it sees EOF instead of hanging forever.
        runCatching { process.outputStream.close() }

        var out = Capture()
        var err = Capture()
        val outThread = thread(name = "dsh-exec-stdout", isDaemon = true) {
            out = capture(process.inputStream)
            runCatching { process.inputStream.close() }
        }
        val errThread = thread(name = "dsh-exec-stderr", isDaemon = true) {
            err = capture(process.errorStream)
            runCatching { process.errorStream.close() }
        }

        val finished = try {
            process.waitFor(timeoutMs.toLong(), TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!finished) {
            destroyTree(process)
            runCatching { process.waitFor(KILL_GRACE_MS, TimeUnit.MILLISECONDS) }
        }
        runCatching { outThread.join(KILL_GRACE_MS) }
        runCatching { errThread.join(KILL_GRACE_MS) }

        val response = Bundle()
        if (!finished) {
            response.putBoolean(Proto.OK, false)
            response.putString(Proto.ERROR, "timeout")
            response.putString(Proto.STDOUT, out.text)
            response.putString(Proto.STDERR, err.text)
            response.putBoolean(Proto.TRUNCATED, out.truncated || err.truncated)
            return response
        }
        response.putBoolean(Proto.OK, true)
        response.putInt(Proto.EXIT_CODE, runCatching { process.exitValue() }.getOrDefault(-1))
        response.putString(Proto.STDOUT, out.text)
        response.putString(Proto.STDERR, err.text)
        response.putBoolean(Proto.TRUNCATED, out.truncated || err.truncated)
        return response
    }

    private class Capture(val text: String = "", val truncated: Boolean = false)

    /** Reads to the cap, then keeps draining so the child never blocks on a full pipe. */
    private fun capture(input: InputStream): Capture {
        val kept = ByteArrayOutputStream(MIN_CAPACITY)
        val buffer = ByteArray(8 * 1024)
        var truncated = false
        while (true) {
            val read = try {
                input.read(buffer)
            } catch (_: Throwable) {
                break
            }
            if (read < 0) break
            val room = MAX_OUTPUT_BYTES - kept.size()
            if (room <= 0) {
                truncated = true
                continue
            }
            val take = if (read <= room) read else room
            kept.write(buffer, 0, take)
            if (take < read) truncated = true
        }
        return Capture(kept.toString(Charsets.UTF_8.name()), truncated)
    }

    private fun destroyTree(process: Process) {
        // Children first: a shell's own kill would leave backgrounded grandchildren behind.
        runCatching {
            process.toHandle().descendants().forEach { runCatching { it.destroyForcibly() } }
        }
        runCatching { process.destroyForcibly() }
    }

    private fun failure(code: String) = Bundle().apply {
        putBoolean(Proto.OK, false)
        putString(Proto.ERROR, code)
    }

    private const val MIN_CAPACITY = 1024
}
