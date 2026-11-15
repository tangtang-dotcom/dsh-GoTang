# fork 层边界

本仓库是 `ccch1mneyyy/dsh-go` 的 fork。所有相对于官方的自定义实现都放在
`app/android/.../dsh_app/fork/` 和 `app/lib/fork/` 下；
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
| `app/lib/fork/fork_text.dart` | fork 自有文案（中英），避免占用上游 l10n 键 |
| `app/lib/fork/chat/root_pill.dart` | 输入框上方的终端档位胶囊 |
| `app/lib/fork/chat/root_dock.dart` | 终端胶囊 + 完全权限 + 插件入口同排 |
| `app/lib/fork/chat/plugins_pill.dart` | 「插件」入口胶囊（可收缩成方块） |

`PhoneCore.kt` 的 `shell()`、`PhoneControl.kt` 的 `statusMap["shell"]`、
`PhoneToolCatalog.kt` 的 `SHELL` 工具定义、`PhonePlugin.kt` 的三个 setter 是钩子。

## 聊天交互

| 位置 | 作用 |
| --- | --- |
| `app/lib/fork/chat/chat_pill_prefs.dart` | 「这个对话」开关的持久化（完全权限提醒 / root 状态 / 插件按钮） |
| `app/lib/fork/chat/plus_panel_switches.dart` | 开关 UI |
| `app/lib/fork/chat/tap_to_menu.dart` | 消息轻点菜单 |
| `app/lib/fork/chat/root_dock.dart` | 权限胶囊布局 |

`app/lib/ui/chat/chat_screen.dart` 只保留 `ForkRootDock` 调用；
`plus_panel.dart` 只保留 `forkChatPillSwitches` 调用；
`composer_capsules.dart`/`native_composer_bar.dart` 只保留 `showChatPluginsCapsule` 开关；
`assistant_message.dart`/`user_bubble.dart`/`secret_mask.dart` 保留轻点钩子；
`chat_list.dart` 用外层 `SelectionArea` 统一提供选区（不再每条消息一个）；
`render/markdown_body.dart` 只加链接/代码块的轻点抑制；
`activity_strip.dart` 保留窄条时钟隐藏的布局修正。

## 通知文案

`notify/LiveContent.kt` 的 `headline`/`detail` 与 `LiveActivity.kt`、
`XiaomiFocus.kt` 的调用是 fork 行为；`LiveContentTest.kt` 有对应断言。

## 合并检查

1. `tooling/fork_check.sh` 必须通过（差异只出现在本文列出的路径和上游钩子）。
2. `python3 app/tool/l10n_merge.py --check` 必须通过。
3. `dart format --output=none --page-width 120 app/lib app/test` 必须无改动。
4. Android JVM 单测与 `flutter analyze --no-pub` 必须通过。

构建侧另有 `runtime/build-runtime.sh`、`runtime/locks/`、`runtime/lib/rtbuild.py`、
`tooling/setup-toolchain.sh` 的版本 pin；它们属于 fork 的运行环境，不随上游 UI 改动。
