package io.github.ccch1mneyyy.dsh_app.phone

import java.io.File

/** [PhoneCore] 与 fork shell 层之间唯一的数据交换。 */
internal data class ForkShellResult(
    val text: String,
    val error: Boolean = false,
    val summary: String? = null,
    val decision: String? = null,
)

/**
 * 终端工具的 fork 入口。上游 `PhoneCore` 只保留一行 `PhoneToolCatalog.SHELL -> shell(a)`，
 * 具体判定、执行和错误文案都在这里。
 */
internal object ForkShell {
    fun run(
        policy: ShellPolicy,
        command: String,
        timeoutMs: Long,
        cacheDir: File?,
    ): ForkShellResult {
        if (policy.mode == ShellMode.ORIGINAL) {
            return ForkShellResult(
                "终端权限没开。请用户在 设置 → 终端权限 里切到「进阶模式」或「高危模式」。",
                error = true,
                summary = PhoneToolCatalog.SHELL,
                decision = "refused:original",
            )
        }
        val raw = command.trim()
        val summary = raw.take(120).replace('\n', ' ')
        if (raw.isEmpty()) return ForkShellResult("command 不能为空。", error = true, summary = summary)
        when (val verdict = ShellGuard.judge(policy.mode, raw, policy.allowed, policy.sdcardAllowed)) {
            is ShellVerdict.Deny -> return ForkShellResult(
                verdict.reason,
                error = true,
                summary = summary,
                decision = "refused:guard",
            )
            is ShellVerdict.Allow -> {
                val result = ShellRunner.execute(verdict.command, timeoutMs, cacheDir)
                result.failed?.let { return ForkShellResult(it, error = true, summary = summary) }
                val prefix = if (result.timedOut) "（超时 ${timeoutMs}ms，已终止）\n" else ""
                val code = result.exitCode
                // 非零退出码是失败：模型和操作记录都不能把它当成成功。
                val failed = !result.timedOut && code != null && code != 0
                val tail = if (failed) "\n（退出码 $code）" else ""
                val body = if (prefix.isEmpty() && result.output.isBlank()) "（没有输出）" else prefix + result.output
                return ForkShellResult(
                    body + tail,
                    error = failed,
                    summary = summary,
                    decision = when {
                        result.timedOut -> "timeout"
                        failed -> "failed"
                        else -> null
                    },
                )
            }
        }
    }
}
