package io.github.ccch1mneyyy.dsh_app.runtime

import android.content.Context
import java.io.File

/** The installer shipped in the runtime image (runtime/toolchain/install-tools.sh). */
internal const val TOOLCHAIN_SCRIPT = "/opt/dsh-app/install-tools.sh"

/**
 * 设置 → 能力 → 手机操控 → 进阶 → 逆向工具.
 *
 * The kit (JDK, jadx, apktool, radare2, binutils) is optional and lives *inside* the rootfs
 * under /root/opt: an App update replaces /opt and /usr, but /root is carried over, so the
 * tools survive. The installer script itself ships in the image at [TOOLCHAIN_SCRIPT], so it
 * exists on a fresh install and is refreshed by an upgrade. Installing means running it
 * through the same PRoot the engine launches — no shell string comes from the caller, and
 * the only thing the UI can choose is "run it".
 */
internal class ToolchainInstaller(private val context: Context, private val manifest: RuntimeManifest) {
    private val rootfs = File(context.filesDir, "runtime/rootfs")
    private val log = File(context.filesDir, "toolchain-install.log")

    @Volatile
    private var process: Process? = null

    /** Name → path under the rootfs. Kept in step with runtime/toolchain/install-tools.sh. */
    private val tools = listOf(
        "java" to "root/opt/jdk/bin/java",
        "jadx" to "root/opt/bin/jadx",
        "apktool" to "root/opt/bin/apktool",
        "r2" to "root/opt/bin/r2",
        "objdump" to "root/opt/bin/objdump",
    )

    fun status(): Map<String, Any?> {
        val installed = LinkedHashMap<String, Any?>()
        tools.forEach { (name, rel) -> installed[name] = File(rootfs, rel).isFile }
        return linkedMapOf(
            "runtimeReady" to (rootfs.isDirectory && File(rootfs, TOOLCHAIN_SCRIPT.trimStart('/')).isFile),
            "installed" to installed,
            "allInstalled" to installed.values.all { it == true },
            "running" to (process?.isAlive == true),
            "log" to logTail(),
        )
    }

    /** Starts the script in the background; the UI polls [status] for progress. */
    fun install(): Map<String, Any?> {
        if (!rootfs.isDirectory) return linkedMapOf("ok" to false, "reason" to "runtimeMissing")
        if (!File(rootfs, TOOLCHAIN_SCRIPT.trimStart('/')).isFile) {
            return linkedMapOf("ok" to false, "reason" to "installerMissing")
        }
        if (process?.isAlive == true) return linkedMapOf("ok" to true, "alreadyRunning" to true)
        val argv = command() ?: return linkedMapOf("ok" to false, "reason" to "manifest")
        return try {
            log.parentFile?.mkdirs()
            log.writeText("")
            val builder = ProcessBuilder(argv).directory(context.filesDir)
            val env = builder.environment()
            env.clear()
            val tmp = File(context.cacheDir, "proot-tmp").apply { mkdirs() }.absolutePath
            env["PATH"] = "/system/bin:/system/xbin"
            env["HOME"] = context.filesDir.absolutePath
            env["TMPDIR"] = tmp
            env["PROOT_TMP_DIR"] = tmp
            env["ANDROID_ROOT"] = System.getenv("ANDROID_ROOT") ?: "/system"
            env["ANDROID_DATA"] = System.getenv("ANDROID_DATA") ?: "/data"
            manifest.launchEnv.forEach { (k, v) -> env[k] = expand(v, tmp) }
            process = builder.redirectErrorStream(true)
                .redirectOutput(ProcessBuilder.Redirect.appendTo(log))
                .start()
            linkedMapOf("ok" to true, "running" to true)
        } catch (e: Exception) {
            linkedMapOf("ok" to false, "reason" to e.javaClass.simpleName)
        }
    }

    /**
     * The manifest's proot prefix (binary, flags, binds) up to `/usr/bin/env`, then a fixed
     * guest command. The manifest's own `dsh web` tail is never reused.
     */
    private fun command(): List<String>? {
        val argv = manifest.launchArgv
        val envAt = argv.indexOf("/usr/bin/env")
        if (envAt < 1) return null
        val tmp = File(context.cacheDir, "proot-tmp").apply { mkdirs() }.absolutePath
        return argv.take(envAt + 1).map { expand(it, tmp) } + listOf(
            "-i",
            "HOME=/root",
            "USER=root",
            "LOGNAME=root",
            "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "/bin/sh",
            // 随运行时镜像一起更新；它安装出来的工具在 /root/opt，升级会保留。
            TOOLCHAIN_SCRIPT,
        )
    }

    private fun expand(value: String, tmp: String): String = value
        .replace("{NATIVE_LIB_DIR}", context.applicationInfo.nativeLibraryDir)
        .replace("{ROOTFS}", runCatching { rootfs.canonicalPath }.getOrDefault(rootfs.absolutePath))
        .replace("{TMP}", tmp)
        .replace("{FILES_DIR}", context.filesDir.absolutePath)
        .replace("{PORT}", "0")

    /** The last line of the install log, for the page to show under the rows. */
    private fun logTail(): String? = runCatching {
        if (!log.isFile) return null
        log.readLines().lastOrNull { it.isNotBlank() }?.take(160)
    }.getOrNull()
}
