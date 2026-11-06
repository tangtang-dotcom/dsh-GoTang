// Fork-layer UI copy.
//
// These strings belong to features the fork adds on top of upstream. Keeping
// them here (instead of lib/l10n/parts) means an upstream l10n regeneration
// never conflicts with the fork, and `flutter gen-l10n` has nothing to merge.
// The getters follow the app language the same way `context.l10n` does.

import '../l10n/l10n.dart';

abstract final class ForkText {
  static bool get _en => AppLocale.isEnglish;

  // Terminal pill.
  static String get rootTierSafe => _en ? 'Terminal · Advanced' : '终端 · 进阶';
  static String get rootTierFull => _en ? 'Terminal · High risk' : '终端 · 高危';
  static String get rootEnable => _en ? 'Enable terminal' : '启用终端';
  static String rootSemantics(String label) => _en ? '$label. Tap to set terminal permissions' : '$label，点击设置终端权限';
  static String get rootSettings => _en ? 'Settings' : '点击设置';

  // Chat pill switches in the plus panel.
  static String get hidePermissionTitle => _en ? 'Hide the full-permission notice' : '隐藏「完全权限」提醒';
  static String get hidePermissionSubtitle =>
      _en ? 'Only hides the notice in every chat; the permission itself is unchanged' : '只是不再提示，所有对话都不再显示；权限本身不变';
  static String get showRootTitle => _en ? 'Show root status above the composer' : '在输入框上方显示 root 状态';
  static String get showRootSubtitle =>
      _en ? 'Hides the terminal tier bar in every chat when off' : '关闭后所有对话都不再显示终端档位条';

  // Phone settings entry.
  static String get terminalPermissions => _en ? 'Terminal permissions' : '终端权限';
  static String tierSafeCount(int n) => _en ? 'Advanced · $n commands allowed' : '进阶模式 · 已允许 $n 条命令';
  static String get tierFullAny => _en ? 'High risk · any command' : '高危模式 · 任意命令';
  static String get tierOff => _en ? 'Not enabled' : '未开启';

  // Shell permissions page.
  static String get highRiskTitle => _en ? 'Switch to high-risk mode?' : '切到高危模式？';
  static String get highRiskBody => _en
      ? 'In this tier the AI can run any command on your phone, including deleting files and changing system settings.\n\n'
            'Every action stays in the conversation and the log below, but it will not ask each time.'
      : '这个档位里，AI 能在你的手机上执行任意命令，包括删文件、改系统设置。\n\n'
            '所有操作都会留在对话和下面的记录里，但它不会每次问你。';
  static String get cancel => _en ? 'Cancel' : '取消';
  static String get confirmKnow => _en ? 'I understand' : '我知道了';
  static String get sdcardTitle => _en ? 'Allow reading and writing all of /sdcard?' : '允许读写整个 /sdcard？';
  static String get sdcardBody => _en
      ? '/sdcard holds photos (DCIM) and other apps\' folders besides Download.\n\n'
            'When on, the AI can touch those places. Deleted files have no recycle bin.\n'
            'The system, /data/adb and other apps\' private folders are still off-limits.'
      : '/sdcard 里除了 Download，还有照片（DCIM）、别的 App 的文件夹。\n\n'
            '打开之后 AI 就能动这些地方，删掉的东西没有回收站。\n'
            '系统的 /system、/data/adb 和其他 App 的私有目录仍然碰不到。';
  static String get sdcardOpen => _en ? 'Turn on anyway' : '仍然打开';
  static String get permissionsSubtitle =>
      _en ? 'Controls which commands the AI may run on this phone' : '决定 AI 能在这台手机上执行哪些命令';
  static String get tiersTitle => _en ? 'Tier' : '档位';
  static String get originalMode => _en ? 'Original mode' : '原版模式';
  static String get originalSummary =>
      _en ? 'Same as upstream: look, tap, type and open apps; no commands.' : '和原版一样：只能看屏幕、点屏幕、打字、开 App，不能执行命令。';
  static String get safeMode => _en ? 'Advanced mode' : '进阶模式';
  static String get safeSummary => _en
      ? 'Runs only the commands you check: read files, inspect state, copy. Scripts and package management stay locked.'
      : '只跑你勾选的命令：能读文件、看状态、复制；脚本和包管理锁死。';
  static String get fullMode => _en ? 'High-risk mode' : '高危模式';
  static String get fullSummary =>
      _en ? 'Runs any command, including deleting files and changing settings.' : '能执行任意命令，包括删文件、改系统设置。';
  static String get extraSettings => _en ? 'Extra settings' : '额外设置';
  static String get showCommands => _en ? 'Expand the command list' : '展开命令清单';
  static String get showCommandsSubtitle =>
      _en ? 'Expand to toggle commands; your choices are kept when collapsed' : '展开后可以逐条开关；收起仍保留你的选择';
  static String get showRootBar => _en ? 'Show root status above the composer' : '在输入框上方显示 root 状态条';
  static String get showRootBarSubtitle =>
      _en ? 'Only hides the hint; terminal capability is unchanged' : '关掉只是不显示提示，终端能力不变';
  static String get sdcardAllow => _en ? 'Allow reading and writing all of /sdcard' : '允许读写整个 /sdcard';
  static String get sdcardAllowedSummary => _en
      ? 'Allowed: photos and other apps\' folders (gallery is read-only: no writes or deletes)'
      : '已允许：包括照片和别的 App 的文件夹（相册只能看，不能写也不能删）';
  static String get sdcardDeniedSummary => _en ? 'Not allowed: Download only' : '未允许：只能写 Download';
  static String get groupSwitch => _en ? 'Whole group' : '整组开关';
  static String get groupFullSummary =>
      _en ? 'High-risk mode allows everything; this is just the command list' : '高危模式全部放行，下面只是命令清单';
  static String get groupLockedSummary =>
      _en ? 'Locked in advanced mode; switch to high risk to use it' : '进阶模式下这一组锁死，切到高危才能用';
  static String get recentTitle => _en ? 'Recent activity' : '最近记录';
  static String get recentExpand => _en ? 'Expand recent activity' : '展开最近记录';
  static String get recentEmpty => _en ? 'No activity yet' : '还没有记录';
  static String recentCount(int n, int limit) => _en ? '$n recent entries (up to $limit)' : '最近 $n 条（最多 $limit）';
}
