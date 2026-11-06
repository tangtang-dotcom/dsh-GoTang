package io.github.ccch1mneyyy.dsh_app.phone

import java.io.File
import java.nio.file.Paths

/**
 * 进阶模式的白名单判定。
 *
 * 这是 fork 层重写后的实现：先用 [ForkLexer]/[ForkParser] 得到语法树，再按命令表检查，
 * 最后用 [ForkShellCompiler] 重新生成命令交给 `su -c`。原始字符串永远不会直接执行，
 * 所以引号、`;`、`&&`、`|`、`>`、`<`、`&` 都不可能把检查骗过去。
 */
object ShellGuard {

    /** 进阶模式永久禁止：一旦执行就不可挽回。 */
    val LOCKED = setOf(
        "dd", "mkfs", "mke2fs", "mkntfs", "mkdosfs", "fdisk", "parted", "sgdisk", "gdisk",
        "fastboot", "setenforce", "insmod", "rmmod", "modprobe", "wipe", "chroot",
        "pivot_root", "reboot", "shutdown", "halt",
    )

    /** 脚本执行类：能跑任意代码；SAFE 下整组锁死，FULL 由用户自己承担。 */
    val SCRIPTS = setOf(
        "sh", "bash", "zsh", "dash", "ash", "python", "python3", "perl", "ruby",
        "node", "deno", "eval", "exec", "xargs", "source", ".",
    )

    /** 把另一条命令包起来执行的包装器。 */
    private val WRAPPERS = setOf(
        "nice", "nohup", "timeout", "watch", "setsid", "stdbuf", "busybox", "toybox",
        "strace", "ltrace", "su", "sudo", "runuser",
    )

    /** 会改文件的命令：目标必须落在安全根里。 */
    private val WRITE_CMDS = setOf(
        "rm", "mv", "cp", "mkdir", "rmdir", "touch", "chmod", "chown", "ln", "tee",
        "truncate", "sed", "awk", "screencap",
    )

    /** 相册里的路径只允许这些命令碰；它们没有“把内容写到指定文件”的常见参数。 */
    private val PHOTO_READ = setOf(
        "ls", "cat", "head", "tail", "grep", "find", "file", "stat",
        "du", "wc", "cut", "tr", "uniq",
    )

    private val PHOTO_DIRS = listOf(
        "/sdcard/DCIM/", "/storage/emulated/0/DCIM/",
        "/sdcard/Pictures/", "/storage/emulated/0/Pictures/",
        "/sdcard/Movies/", "/storage/emulated/0/Movies/",
        "/sdcard/Android/media/", "/storage/emulated/0/Android/media/",
    )

    private val FORBIDDEN = listOf(
        "/system/", "/vendor/", "/product/", "/apex/", "/odm/", "/proc/", "/sys/", "/dev/",
        "/data/adb/", "/data/data/", "/data/system/", "/data/misc/", "/data/app/", "/data/vendor/",
        "/sdcard/DCIM/", "/storage/emulated/0/DCIM/",
    )

    private val APP_PRIVATE = listOf(
        "/data/user/0/io.github.ccch1mneyyy.dsh_app/",
        "/data/data/io.github.ccch1mneyyy.dsh_app/",
    )

    private val BASE_ROOTS = listOf(
        "/sdcard/Download/", "/storage/emulated/0/Download/",
        "/data/local/tmp/",
    ) + APP_PRIVATE

    private val SDCARD_ROOTS = listOf("/sdcard/", "/storage/emulated/0/")

    /** 相册纯只读：这些命令可以看，但不能写、不能删、不能搬出去。 */
    fun judge(
        mode: ShellMode,
        command: String,
        allowed: Set<String>,
        sdcardOn: Boolean = false,
    ): ShellVerdict {
        val cmd = command.trim()
        if (cmd.isEmpty()) return ShellVerdict.Deny("命令是空的。")
        if (mode == ShellMode.FULL) return ShellVerdict.Allow(cmd)
        val tokens = try {
            ForkLexer.lex(cmd)
        } catch (e: ForkSyntaxException) {
            return ShellVerdict.Deny(e.message ?: "命令语法不支持。")
        }
        val tree = try {
            ForkParser.parse(tokens)
        } catch (e: ForkSyntaxException) {
            return ShellVerdict.Deny(e.message ?: "命令语法不支持。")
        }
        return try {
            Walker(allowed, sdcardOn).walk(tree)
            ShellVerdict.Allow(ForkShellCompiler.compile(tree))
        } catch (e: ForkSyntaxException) {
            ShellVerdict.Deny(e.message ?: "命令没有通过检查。")
        }
    }

    private class Walker(private val allowed: Set<String>, private val sdcardOn: Boolean) {
        private var cwd = "/"

        fun walk(node: ForkNode) {
            when (node) {
                is ForkList -> {
                    walk(node.first)
                    for ((_, child) in node.rest) walk(child)
                }
                is ForkPipeline -> walkPipeline(node)
                is ForkCommand -> walkCommand(node, false)
            }
        }

        private fun walkPipeline(pipeline: ForkPipeline) {
            val single = pipeline.commands.size == 1
            for (cmd in pipeline.commands) walkCommand(cmd, single)
        }

        private fun walkCommand(cmd: ForkCommand, canChangeCwd: Boolean) {
            val name = cmd.name.substringAfterLast('/').lowercase()
            if (name.isEmpty()) {
                checkRedirects(cmd)
                return
            }
            if (name.contains('=')) throw ForkSyntaxException("环境变量赋值（$name）不在进阶模式的支持范围内。")

            val group = ShellCommands.groupOf(name)
            if (group != null && group in ShellCommands.SAFE_LOCKED_GROUPS) {
                throw ForkSyntaxException("「$name」属于「${ShellCommands.groupTitle(group)}」，进阶模式下整组锁死，切到高危模式才能用。")
            }
            if (name in LOCKED) throw ForkSyntaxException("「$name」可能损坏分区或系统，进阶模式下不可用。要跑它请切到高危模式。")
            if (name !in allowed) throw ForkSyntaxException("「$name」没有在当前档位开启。去 设置 → 终端权限 里的命令清单把它打开。")
            if (name in WRAPPERS) throw ForkSyntaxException("「$name」会把另一条命令包起来执行，绕开命令白名单，进阶模式下不允许。请切到高危模式。")
            if (name == "env" && cmd.argv.size > 1) throw ForkSyntaxException("「env」后面跟命令等于换一条命令执行，进阶模式下不允许。要跑它请切到高危模式。")

            val args = cmd.argv.drop(1)
            when (name) {
                "awk" -> {
                    if (args.any { it == "-f" || it.startsWith("-f") }) throw ForkSyntaxException("awk -f 会加载文件里的程序，进阶模式下不允许。")
                    val body = args.joinToString(" ")
                    if (Regex("""system\s*\(|\bgetline\b""").containsMatchIn(body)) {
                        throw ForkSyntaxException("这个 awk 里有 system() 或 getline，可以在白名单外执行命令或读写文件，进阶模式下不允许。")
                    }
                }
                "sed" -> {
                    if (args.any { Regex("""\bs/[^/\n]*/[^/\n]*/[a-zA-Z]*e[a-zA-Z]*\b""").containsMatchIn(it) }) {
                        throw ForkSyntaxException("这个 sed 的 s///e 会把替换结果当命令执行，进阶模式下不允许。")
                    }
                }
                "sort" -> if (args.any { it.contains("--compress-program") }) {
                    throw ForkSyntaxException("「sort --compress-program」会执行外部程序，进阶模式下不允许。")
                }
                "find" -> {
                    val bad = setOf("-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprintf", "-fprint", "-fprint0", "-fls")
                    if (args.any { it in bad }) throw ForkSyntaxException("find 带 ${args.first { it in bad }} 等于执行任意操作或写文件，进阶模式下不可用。")
                }
                "pm" -> if (args.firstOrNull() == "clear") throw ForkSyntaxException("pm clear 会清掉一个 App 的全部数据，进阶模式下不可用。")
                "cmd" -> {
                    val sub = args.firstOrNull().orEmpty()
                    if (sub in setOf("package", "activity", "appops", "settings", "deviceidle", "role", "uiautomator", "overlay")) {
                        throw ForkSyntaxException("cmd $sub 会绕过 pm/settings 的整组限制，进阶模式下不可用。")
                    }
                }
                "date" -> if (args.any { it == "-s" || it.startsWith("--set") }) {
                    throw ForkSyntaxException("date -s 会改系统时间，进阶模式下不允许。")
                }
                "cd" -> {
                    if (!canChangeCwd) throw ForkSyntaxException("管道里的 cd 不改变外层目录，进阶模式不支持。")
                    val target = args.firstOrNull() ?: throw ForkSyntaxException("「cd」后面要写目录。")
                    if (target == "-" || target == "~" || target.startsWith("~/")) throw ForkSyntaxException("「cd $target」不在进阶模式的支持范围内，请写明确的绝对路径。")
                    val next = resolve(target, cwd) ?: throw ForkSyntaxException("「cd」的目标看不懂：$target。")
                    forbidden(next)?.let { throw ForkSyntaxException("碰到受保护的位置：$it，进阶模式下不允许。") }
                    if (inPhoto(next)) throw ForkSyntaxException("「cd」不能进相册/视频目录（$next）。")
                    checkRedirects(cmd)
                    cwd = next
                    return
                }
            }

            // 先把所有像路径的参数和重定向目标收集起来，再按命令类型检查。
            val pathTokens = args.mapNotNull(::pathToken)
            val paths = pathTokens.map { raw -> resolve(raw, cwd) ?: raw }
            for (p in paths) {
                forbidden(p)?.let { throw ForkSyntaxException("碰到受保护的位置：$it，进阶模式下不允许。") }
                if (!sdcardOn && isSdcard(p) && !inSafeRoot(p) && !inPhoto(p)) {
                    throw ForkSyntaxException("「$name」碰到了 $p。要让 AI 读写整个 /sdcard，去 设置 → 终端权限 → 额外设置 里打开「允许读写整个 /sdcard」。")
                }
                if (inPhoto(p)) {
                    if (name !in PHOTO_READ) throw ForkSyntaxException("「$name」的参数里有相册里的路径（$p）。进阶模式下相册只给读。")
                    if (name in WRITE_CMDS) throw ForkSyntaxException("相册是只读的（$p）。进阶模式下只能看，不能往里写、也不能删。")
                }
            }

            checkRedirects(cmd)

            if (name in setOf("cp", "mv", "ln")) {
                checkCopyLike(name, args, paths)
            } else if (name in WRITE_CMDS) {
                if (args.any { it.contains('*') || it.contains('?') || it.contains('{') }) {
                    throw ForkSyntaxException("「$name」在进阶模式下不支持通配符，先把文件列出来再操作。")
                }
                for (p in paths) {
                    if (!inSafeRoot(p)) throw ForkSyntaxException(outOfScope(name, p))
                    if (inPhoto(p)) throw ForkSyntaxException("相册是只读的（$p）。进阶模式下只能看，不能往里写、也不能删。")
                }
            }
            if (name == "sort") {
                val out = optionValue(args, "-o", "--output")
                if (out != null) {
                    val p = resolve(out, cwd) ?: out
                    if (!inSafeRoot(p) || inPhoto(p)) throw ForkSyntaxException("「sort -o」的目标不在允许范围内：$p。")
                }
            }
            if (name == "logcat") {
                val out = optionValue(args, "-f", "--file")
                if (out != null) {
                    val p = resolve(out, cwd) ?: out
                    if (!inSafeRoot(p) || inPhoto(p)) throw ForkSyntaxException("「logcat -f」的目标不在允许范围内：$p。")
                }
            }
            if (name == "curl") {
                val out = optionValue(args, "-o", "--output")
                if (out != null) {
                    val p = resolve(out, cwd) ?: out
                    if (!inSafeRoot(p) || inPhoto(p)) throw ForkSyntaxException("「curl -o」的目标不在允许范围内：$p。")
                }
                if (args.any { it == "-O" || it == "--remote-name" }) {
                    if (!inSafeRoot(cwd) || inPhoto(cwd)) throw ForkSyntaxException("「curl -O」会把文件写到当前目录，当前目录不在允许范围内：$cwd。")
                }
            }
            if (name == "screencap") {
                for (p in paths) {
                    if (!inSafeRoot(p) || inPhoto(p)) throw ForkSyntaxException("「screencap」的目标不在允许范围内：$p。")
                }
            }
        }

        private fun checkRedirects(cmd: ForkCommand) {
            for (r in cmd.redirects) {
                if (r.op == "dup") continue
                val raw = r.target.orEmpty()
                val p = resolve(raw, cwd) ?: raw
                if (r.op == "<") {
                    forbidden(p)?.let { throw ForkSyntaxException("碰到受保护的位置：$it，进阶模式下不允许。") }
                    continue
                }
                forbidden(p)?.let { throw ForkSyntaxException("碰到受保护的位置：$it，进阶模式下不允许。") }
                if (!inSafeRoot(p)) throw ForkSyntaxException(outOfScope("重定向", p))
                if (inPhoto(p)) throw ForkSyntaxException("相册是只读的（$p）。进阶模式下只能看，不能往里写、也不能删。")
            }
        }

        private fun checkCopyLike(name: String, args: List<String>, paths: List<String>) {
            if (paths.isEmpty()) return
            val targetFlag = optionValue(args, "-t", "--target-directory")
            val targets: List<String>
            val sources: List<String>
            if (targetFlag != null) {
                val t = resolve(targetFlag, cwd) ?: targetFlag
                targets = listOf(t)
                sources = paths.filter { it != t }
            } else {
                targets = listOf(paths.last())
                sources = paths.dropLast(1)
            }
            for (src in sources) {
                if (inPhoto(src)) throw ForkSyntaxException("「$src」在相册/视频目录里，搬出去就等于从相册消失了，进阶模式下不允许。要动它请切到高危模式。")
            }
            for (t in targets) {
                if (!inSafeRoot(t)) throw ForkSyntaxException(outOfScope(name, t))
                if (inPhoto(t)) throw ForkSyntaxException("相册是只读的（$t）。进阶模式下只能看，不能往里写、也不能删。要动它请切到高危模式。")
            }
        }

        private fun optionValue(args: List<String>, short: String, long: String): String? {
            for (i in args.indices) {
                val a = args[i]
                if (a == short || a == long) return args.getOrNull(i + 1)
                if (a.startsWith("$long=")) return a.substringAfter('=')
                if (short.length == 2 && a.startsWith(short) && a.length > short.length) return a.substring(short.length)
            }
            return null
        }

        private fun pathToken(raw: String): String? {
            var t = raw
            if (t == "--") return null
            if (t.startsWith("--") && t.contains('=')) t = t.substringAfter('=')
            if (t.isEmpty() || t.startsWith("-")) return null
            if (t == "." || t == ".." || t.startsWith("/") || t.startsWith("./") || t.startsWith("../") || t.startsWith("~/")) return t
            if (t.contains('/')) return t
            return null
        }

        private fun resolve(p: String, cwd: String): String? = try {
            val path = Paths.get(p)
            val abs = if (path.isAbsolute) path else Paths.get(cwd).resolve(path)
            val norm = abs.normalize()
            val f = norm.toFile()
            when {
                f.exists() -> f.canonicalPath
                f.parentFile?.exists() == true -> File(f.parentFile.canonicalFile, f.name).path
                else -> norm.toString()
            }
        } catch (_: Exception) {
            null
        }

        private fun isSdcard(p: String): Boolean =
            p == "/sdcard" || p.startsWith("/sdcard/") || p == "/storage/emulated/0" || p.startsWith("/storage/emulated/0/")

        private fun inSafeRoot(p: String): Boolean {
            if (p == "/dev/null") return true
            val withSlash = if (p.endsWith("/")) p else "$p/"
            if (sdcardOn && SDCARD_ROOTS.any { withSlash.startsWith(it) }) return true
            return BASE_ROOTS.any { withSlash.startsWith(it) }
        }

        private fun inPhoto(p: String): Boolean {
            val withSlash = if (p.endsWith("/")) p else "$p/"
            return PHOTO_DIRS.any { withSlash.startsWith(it) }
        }

        private fun forbidden(p: String): String? {
            val withSlash = if (p.endsWith("/")) p else "$p/"
            if (p == "/dev/null") return null
            if (APP_PRIVATE.any { withSlash.startsWith(it) }) return null
            if (withSlash.startsWith("/data/local/tmp/")) return null
            if (withSlash.startsWith("/data/")) return p
            for (f in FORBIDDEN) {
                if (withSlash != f && !withSlash.startsWith(f)) continue
                if (sdcardOn && (f.startsWith("/sdcard/") || f.startsWith("/storage/emulated/0/"))) continue
                return p
            }
            return null
        }

        private fun outOfScope(word: String, p: String): String =
            if (!sdcardOn && isSdcard(p)) {
                "「$word」只能改 Download 和 /data/local/tmp，这一条碰到了 $p。" +
                    "要让 AI 读写整个 /sdcard，去 设置 → 终端权限 → 额外设置 里打开「允许读写整个 /sdcard」。"
            } else {
                "「$word」碰到了一个不在允许范围内的位置：$p。"
            }
    }
}
