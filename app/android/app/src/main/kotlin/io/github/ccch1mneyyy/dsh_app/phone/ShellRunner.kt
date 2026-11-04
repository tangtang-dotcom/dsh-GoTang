package io.github.ccch1mneyyy.dsh_app.phone

import java.io.File
import java.util.concurrent.TimeUnit

/** 一次命令的结果；[PhoneCore] 只负责把它变成给模型的文字。 */
internal data class ShellResult(
    val output: String,
    val timedOut: Boolean,
    val failed: String? = null,
)

/**
 * `su -c` 直连执行一条命令。
 *
 * 和虚拟屏那套特权进程分开：终端不需要不打扰模式，只要手机有 su。输出写临时文件
 * 而不是走管道 —— 管道 64 KiB 塞满时子进程会卡住（`logcat -d`、`dumpsys`、`find /`
 * 都会越线）。
 */
internal object ShellRunner {
    private const val MAX_COMMAND_CHARS = 4_000
    private const val MAX_OUTPUT = 8_000
    private const val MAX_FILE_BYTES = 1_000_000

    fun execute(
        command: String,
        timeoutMs: Long,
        cacheDir: File?,
    ): ShellResult {
        if (command.length > MAX_COMMAND_CHARS) {
            return ShellResult("", false, "命令太长（上限 $MAX_COMMAND_CHARS 字符）。")
        }
        val outDir = cacheDir ?: File(System.getProperty("java.io.tmpdir") ?: "/data/local/tmp")
        val outFile = File(outDir, ".dsh_shell_${System.nanoTime()}.out")
        val proc = try {
            ProcessBuilder("su", "-c", command)
                .redirectErrorStream(true)
                .redirectOutput(outFile)
                .redirectInput(ProcessBuilder.Redirect.from(File("/dev/null")))
                .start()
        } catch (e: Exception) {
            return ShellResult(
                "",
                false,
                "跑不起来：${e.javaClass.simpleName}。这台手机可能没有 root。",
            )
        }
        val finished = try {
            proc.waitFor(timeoutMs.coerceIn(1_000L, 120_000L), TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!finished) killTree(proc)

        val raw = try {
            when {
                !outFile.exists() -> ""
                outFile.length() > MAX_FILE_BYTES -> {
                    val head = ByteArray(MAX_FILE_BYTES.toInt())
                    val n = outFile.inputStream().use { it.read(head) }
                    String(head, 0, maxOf(n, 0), Charsets.UTF_8) + "\n…（只保留前 $MAX_FILE_BYTES 字节）"
                }
                else -> outFile.readText()
            }
        } catch (_: Exception) {
            ""
        } finally {
            outFile.delete()
        }

        val body = if (raw.length > MAX_OUTPUT) {
            raw.take(MAX_OUTPUT) + "\n…（截断到 $MAX_OUTPUT 字符）"
        } else {
            raw
        }
        return ShellResult(body, !finished)
    }

    /** 超时后按 /proc 里的父子关系自底向上杀，避免留下孤儿进程。 */
    private fun killTree(p: java.lang.Process) {
        val pid = pidOf(p)
        if (pid == null) {
            runCatching { p.destroyForcibly() }
            return
        }
        runCatching {
            val children = HashMap<Long, MutableList<Long>>()
            File("/proc").listFiles()?.forEach { d ->
                val child = d.name.toLongOrNull() ?: return@forEach
                val stat = runCatching { File(d, "stat").readText() }.getOrNull() ?: return@forEach
                val parts = stat.substringAfterLast(')').trim().split(' ')
                val ppid = parts.getOrNull(1)?.toLongOrNull() ?: return@forEach
                children.getOrPut(ppid) { mutableListOf() }.add(child)
            }
            val order = ArrayList<Long>()
            val queue = ArrayDeque<Long>()
            queue.add(pid)
            var depth = 0
            while (queue.isNotEmpty() && depth < 16) {
                val level = queue.size
                repeat(level) {
                    val cur = queue.removeFirst()
                    order.add(cur)
                    children[cur]?.forEach { queue.add(it) }
                }
                depth++
            }
            // 用系统 kill 而不是 android.os.Process.sendSignal：后者不是稳定的公开 API。
            val victims = order.asReversed().joinToString(" ")
            runCatching {
                ProcessBuilder("/system/bin/sh", "-c", "kill -9 $victims").start().waitFor()
            }
        }
        runCatching { p.destroyForcibly() }
    }

    private fun pidOf(process: java.lang.Process): Long? = runCatching {
        (process.javaClass.getMethod("pid").invoke(process) as Number).toLong()
    }.getOrNull()
}
