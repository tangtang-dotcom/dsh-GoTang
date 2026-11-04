package io.github.ccch1mneyyy.dsh_app.phone

import android.content.Context
import android.content.SharedPreferences

/**
 * 终端权限的偏好：档位、命令白名单、是否放开整个 /sdcard。
 *
 * 单独一个文件，是为了让 [PhoneControl] 只留几个转发方法 —— 上游改那个文件时
 * 我们几乎不会撞车。
 */
internal class ShellPolicyStore private constructor(private val prefs: SharedPreferences) {

    fun mode(): ShellMode = ShellMode.of(prefs.getString(K_MODE, null))

    fun allowed(): Set<String> {
        val key = if (mode() == ShellMode.SAFE) K_SAFE_CMDS else K_FULL_CMDS
        val def = if (mode() == ShellMode.SAFE) ShellCommands.SAFE_DEFAULT else ShellCommands.DEFAULT_ALLOWED
        return prefs.getStringSet(key, null) ?: def
    }

    fun sdcardAllowed(): Boolean = mode() == ShellMode.FULL || prefs.getBoolean(K_SDCARD, false)

    fun setMode(mode: ShellMode) {
        prefs.edit().putString(K_MODE, mode.key).apply()
    }

    fun setAllowed(commands: Set<String>) {
        val key = if (mode() == ShellMode.SAFE) K_SAFE_CMDS else K_FULL_CMDS
        prefs.edit().putStringSet(key, commands).apply()
    }

    fun setSdcardAllowed(on: Boolean) {
        prefs.edit().putBoolean(K_SDCARD, on).apply()
    }

    fun snapshot(): ShellPolicy = ShellPolicy(mode(), allowed(), sdcardAllowed())

    companion object {
        private const val K_MODE = "shell_mode"
        private const val K_SAFE_CMDS = "shell_safe_allowed"
        private const val K_FULL_CMDS = "shell_full_allowed"
        private const val K_SDCARD = "shell_sdcard_allowed"

        fun of(context: Context): ShellPolicyStore =
            ShellPolicyStore(context.getSharedPreferences("dsh_phone", Context.MODE_PRIVATE))
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
