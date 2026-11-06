package io.github.ccch1mneyyy.dsh_app.phone

/**
 * 终端权限的三档。默认 [ORIGINAL]：安装完不给终端。
 *
 * 这个文件属于 fork 层（`app/android/.../fork/phone/shell`）。上游 `PhoneCore` 只通过
 * `ForkShell.run` 调用它；合并上游时只需要保留 `PhoneCore` 里那几行转发。
 */
enum class ShellMode(val key: String) {
    ORIGINAL("original"),
    SAFE("safe"),
    FULL("full"),
    ;

    companion object {
        fun of(key: String?): ShellMode = values().firstOrNull { it.key == key } ?: ORIGINAL
    }
}

/** 一次 shell 调用看到的事实；[PhoneEnv.shellPolicy] 返回它。 */
data class ShellPolicy(
    val mode: ShellMode,
    val allowed: Set<String>,
    val sdcardAllowed: Boolean,
) {
    companion object {
        /** 默认原版：没有终端能力。 */
        val DISABLED = ShellPolicy(ShellMode.ORIGINAL, emptySet(), false)
    }
}

/** 一次 shell 调用该不该放行；[Allow] 带的是已经重新生成过的命令，执行时不碰原始字符串。 */
sealed class ShellVerdict {
    data class Allow(val command: String) : ShellVerdict()
    data class Deny(val reason: String) : ShellVerdict()
}
