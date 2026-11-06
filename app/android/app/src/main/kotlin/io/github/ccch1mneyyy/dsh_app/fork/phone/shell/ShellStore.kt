package io.github.ccch1mneyyy.dsh_app.phone

import android.content.Context
import android.content.SharedPreferences

/**
 * 终端权限的偏好：档位、命令白名单、是否放开整个 /sdcard。
 *
 * fork 层文件：`PhoneControl` 只留三个转发方法，合并上游时不会和它的业务代码纠缠。
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

/** 设置页需要的完整状态；[PhoneControl.status] 把它放进 `shell` 字段。 */
internal object ForkShellStatus {
    fun map(policy: ShellPolicy): Map<String, Any?> = linkedMapOf(
        "mode" to policy.mode.key,
        "allowed" to policy.allowed.sorted(),
        "sdcardAllowed" to policy.sdcardAllowed,
        "commands" to ShellCommands.CATALOG,
        "groups" to ShellCommands.GROUPS,
    )
}
