# fork 层边界

本仓库是 `ccch1mneyyy/dsh-go` 的 fork。所有相对于官方的自定义实现都放在
`app/android/.../dsh_app/fork/`、`app/lib/fork/` 和 `runtime/toolchain/` 下；
上游文件只保留登记过的调用点。合并新上游时，先按本文检查这些文件。

## 终端权限

| 位置 | 作用 |
| --- | --- |
| `app/android/.../fork/phone/shell/ShellTypes.kt` | `ShellMode`、`ShellPolicy`、`ShellVerdict` |
| `.../fork/phone/shell/ShellStore.kt` | SharedPreferences 持久化、状态 JSON |
| `.../fork/phone/shell/ShellCatalog.kt` | 命令目录、分组、SAFE 默认集合 |
| `.../fork/phone/shell/ShellLexer.kt` | 引号感知的词法分析；拒绝 `$()`、反引号、`( )`、`<<`、`|&` |
| `.../fork/phone/shell/ShellParser.kt` | 管道/列表/重定向语法树与规范化重写 |
| `.../fork/phone/shell/ShellRules.kt` | 白名单、路径、相册只读、重定向、`cd` 判定 |
| `.../fork/phone/shell/ForkShell.kt` | `PhoneCore.shell` 的入口 |
| `.../fork/phone/shell/ShellRunner.kt` | `su -c` 执行、超时、输出截断 |
| `app/lib/fork/phone/shell/shell_permissions_page.dart` | 终端权限页面 |
| `app/lib/fork/chat/root_pill.dart` | 输入框上方的终端档位胶囊 |
| `app/lib/fork/chat/root_dock.dart` | 终端胶囊 + 完全权限同排 |

`PhoneCore.kt` 的 `shell()`、`PhoneControl.kt` 的 `statusMap["shell"]`、
`PhoneToolCatalog.kt` 的 `SHELL` 工具定义、`PhonePlugin.kt` 的三个 setter 是钩子。

## 逆向工具

| 位置 | 作用 |
| --- | --- |
| `app/android/.../fork/runtime/ToolchainInstaller.kt` | 安装/状态/日志 |
| `runtime/toolchain/install-tools.sh` | rootfs 内安装脚本 |
| `app/lib/fork/phone/toolchain/toolchain_sheet.dart` | 面板 UI |

`RuntimeController.kt` 的 `toolchainStatus`/`installToolchain`、
`RuntimePlugin.kt` 的两个 handler、`runtime/lib/rtbuild.py` 的 overlay、
`tooling/setup-toolchain.sh` 的 JDK/Flutter/NDK 部分是钩子。

## 聊天交互

| 位置 | 作用 |
| --- | --- |
| `app/lib/fork/chat/chat_pill_prefs.dart` | 「这个对话」开关的持久化 |
| `app/lib/fork/chat/plus_panel_switches.dart` | 开关 UI |
| `app/lib/fork/chat/tap_to_menu.dart` | 消息轻点菜单 |
| `app/lib/fork/chat/root_dock.dart` | 权限胶囊布局 |

`app/lib/ui/chat/chat_screen.dart` 只保留 `ForkRootDock` 调用；
`plus_panel.dart` 只保留 `forkChatPillSwitches` 调用；
`assistant_message.dart`/`user_bubble.dart`/`secret_mask.dart` 保留选择与轻点钩子；
`activity_strip.dart` 保留窄条时钟隐藏的布局修正。

## 通知文案

`notify/LiveContent.kt` 的 `headline`/`detail` 与 `LiveActivity.kt`、
`XiaomiFocus.kt` 的调用是 fork 行为；`LiveContentTest.kt` 有对应断言。

## 合并检查

1. `git diff upstream/main..HEAD --stat` 只应出现本文列出的路径和上游钩子。
2. `python3 runtime/tests/test_toolchain_installer.py` 与
   `python3 app/tool/l10n_merge.py --check` 必须通过。
3. `dart format --output=none --page-width 120 app/lib app/test` 必须无改动。
4. Android JVM 单测与 `flutter analyze --no-pub` 必须通过。
