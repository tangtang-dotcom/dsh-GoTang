package io.github.ccch1mneyyy.dsh_app.phone

/**
 * 命令清单：设置页按组展示，默认值也在这里。
 *
 * fork 层唯一的一份清单。UI 从 `PhoneControl.status()["shell"]` 读 `groups`/`commands`，
 * 不再手写第二份分组，因此原生加一条命令时页面会自动出现。
 */
object ShellCommands {
    /** 分组顺序 + 中文标题 + 一句话说明。 */
    val GROUPS: List<Map<String, String>> = listOf(
        linkedMapOf("id" to "read", "title" to "只读命令", "desc" to "只看不改：读文件、看进程和系统状态"),
        linkedMapOf(
            "id" to "file",
            "title" to "文件操作",
            "desc" to "复制、移动、删除；只能碰 Download、tmp、App 私有目录（开 /sdcard 后含整个存储）",
        ),
        linkedMapOf("id" to "system", "title" to "系统操作", "desc" to "安卓层面的开关：装应用、模拟点击、改设置"),
        linkedMapOf("id" to "network", "title" to "网络", "desc" to "联网请求、测速、查 DNS"),
        linkedMapOf("id" to "packages", "title" to "包管理", "desc" to "apt / pip / npm / git，第一次用要联网下载"),
        linkedMapOf("id" to "script", "title" to "脚本执行", "desc" to "把整段脚本交给解释器：内容不受白名单约束"),
    )

    /** 命令 → (分组, 一句话介绍)。保持无重复。 */
    private val DEF: List<Triple<String, String, String>> = listOf(
        Triple("cd", "read", "切当前目录（只在同一条命令里有效）"),
        Triple("pwd", "read", "打印当前目录"),
        Triple("echo", "read", "打印一段文字"),
        Triple("printf", "read", "格式化输出文字"),
        Triple("ls", "read", "列出目录内容"),
        Triple("cat", "read", "输出文件内容"),
        Triple("head", "read", "看文件开头几行"),
        Triple("tail", "read", "看文件结尾几行"),
        Triple("grep", "read", "在文件或输出里搜文字"),
        Triple("wc", "read", "数行数、字数"),
        Triple("uniq", "read", "去重"),
        Triple("cut", "read", "按列截取"),
        Triple("tr", "read", "替换或删除字符"),
        Triple("find", "read", "按名字/时间找文件"),
        Triple("stat", "read", "看文件大小、权限、时间"),
        Triple("file", "read", "判断文件是什么类型"),
        Triple("du", "read", "看目录占多少空间"),
        Triple("df", "read", "看各分区剩余空间"),
        Triple("free", "read", "看内存占用"),
        Triple("ps", "read", "看正在跑的进程"),
        Triple("top", "read", "看谁在吃 CPU"),
        Triple("uptime", "read", "开机多久、负载多少"),
        Triple("id", "read", "看当前用户和权限"),
        Triple("whoami", "read", "看当前用户名"),
        Triple("getprop", "read", "读系统属性：型号、Android 版本"),
        Triple("dumpsys", "read", "读系统服务状态：电池、显示、WiFi"),
        Triple("screencap", "read", "截屏存成图片（带路径会写文件）"),
        Triple("uname", "read", "看内核版本"),
        Triple("nproc", "read", "看有几个 CPU 核"),
        Triple("which", "read", "查命令装在哪"),
        Triple("basename", "read", "取路径里的文件名"),
        Triple("dirname", "read", "取路径里的目录部分"),
        Triple("realpath", "read", "把相对路径转成绝对路径"),
        Triple("sort", "system", "排序（带 -o 会写文件）"),
        Triple("logcat", "system", "读系统日志（带 -f 会写文件）"),
        Triple("date", "system", "看时间（带 -s 会改系统时间）"),
        Triple("env", "read", "看环境变量"),
        Triple("am", "system", "启动应用、发广播"),
        Triple("pm", "packages", "装/卸应用、查包名"),
        Triple("input", "system", "模拟点屏幕、打字"),
        Triple("cmd", "system", "调系统命令（WiFi、电池等）"),
        Triple("settings", "system", "读改系统设置项"),
        Triple("svc", "system", "开关 WiFi、数据、飞行模式"),
        Triple("wm", "system", "改屏幕分辨率、密度"),
        Triple("cp", "file", "复制文件"),
        Triple("mv", "file", "移动或改名"),
        Triple("rm", "file", "删除文件"),
        Triple("mkdir", "file", "新建目录"),
        Triple("rmdir", "file", "删除空目录"),
        Triple("touch", "file", "新建空文件或改时间"),
        Triple("chmod", "file", "改文件权限"),
        Triple("chown", "file", "改文件属主"),
        Triple("ln", "file", "建快捷方式（软链接）"),
        Triple("tee", "file", "把输出同时写进文件"),
        Triple("truncate", "file", "把文件截断或撑大"),
        Triple("sed", "file", "按规则替换文件内容"),
        Triple("awk", "file", "按列处理文本"),
        Triple("curl", "network", "发 HTTP 请求"),
        Triple("ping", "network", "测网络通不通"),
        Triple("nslookup", "network", "查域名对应 IP"),
        Triple("netstat", "network", "看网络连接"),
        Triple("apt", "packages", "装系统软件包"),
        Triple("apt-get", "packages", "装系统软件包（老写法）"),
        Triple("pip", "packages", "装 Python 包"),
        Triple("pip3", "packages", "装 Python 3 包"),
        Triple("npm", "packages", "装 Node 包"),
        Triple("pnpm", "packages", "装 Node 包（更快）"),
        Triple("git", "packages", "拉代码、提交"),
        Triple("sh", "script", "跑一段 shell 脚本"),
        Triple("bash", "script", "跑一段 bash 脚本"),
        Triple("zsh", "script", "跑一段 zsh 脚本"),
        Triple("python", "script", "跑 Python 代码"),
        Triple("python3", "script", "跑 Python 3 代码"),
        Triple("node", "script", "跑 JavaScript 代码"),
        Triple("eval", "script", "把字符串当命令执行"),
        Triple("exec", "script", "替换成另一个进程执行"),
        Triple("xargs", "script", "把输入拼成命令批量执行"),
        Triple("source", "script", "加载脚本文件"),
    )

    /** 设置页用的扁平清单，每项带分组和介绍。 */
    val CATALOG: List<Map<String, Any?>> = DEF.map {
        linkedMapOf<String, Any?>("name" to it.first, "group" to it.second, "desc" to it.third)
    }

    /** 进阶模式下整组锁死、不可打开的组。 */
    val SAFE_LOCKED_GROUPS: Set<String> = setOf("packages", "script")

    /**
     * 危险到进阶模式不该默认开的单条命令（可手动开，但默认关）。
     *
     * `cmd` 能绕过 `pm`/`settings` 的整组锁死；`awk`/`sed` 自带执行/写文件能力；
     * `env` 后面跟命令就是换一条命令执行。它们都保留在清单里，但默认关。
     */
    private val SAFE_OFF: Set<String> = setOf(
        "rm", "rmdir", "chmod", "chown", "truncate", "ln", "mv",
        "am", "pm", "input", "settings", "svc", "wm", "curl", "cmd",
        "env", "awk", "sed",
        // 名字像只读、实际带写参数：sort -o / logcat -f 能写文件，date -s 能改系统时间。
        "sort", "logcat", "date",
    )

    /** 进阶模式默认打开：只读全开，文件类只留只读性的，系统类关掉能改状态的。 */
    val SAFE_DEFAULT: Set<String> = CATALOG
        .filter { it["group"] !in SAFE_LOCKED_GROUPS }
        .map { it["name"] as String }
        .filter { it !in SAFE_OFF }
        .toSet()

    fun groupOf(name: String): String? = CATALOG.firstOrNull { it["name"] == name }?.get("group") as String?

    fun groupTitle(id: String): String = GROUPS.firstOrNull { it["id"] == id }?.get("title") ?: id

    /** 高危模式默认：除包管理外全开（第一次 apt 要联网下载，默认关）。 */
    val DEFAULT_ALLOWED: Set<String> = CATALOG
        .filter { it["group"] != "packages" }
        .map { it["name"] as String }
        .toSet()
}
