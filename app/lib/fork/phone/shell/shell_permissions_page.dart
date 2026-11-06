import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fork_text.dart';
import '../../chat/chat_pill_prefs.dart';
import '../../../state/phone_state.dart';
import '../../../ui/settings/settings_widgets.dart';
import '../../../ui/theme/app_icons.dart';
import '../../../ui/shell/page_frame.dart';

const _prefShowCommands = 'shell_show_commands';
const _prefShowRecent = 'shell_show_recent';

/// 终端权限：三档 + 分类命令开关 + 最近记录。
///
/// 设计上刻意分开两种展开状态：
/// - 「展开命令清单」是总开关，写进 prefs，退出重进要记住；
/// - 每个分类的展开只是当前页面里的临时状态，退出重进一律收起。
class ShellPermissionsPage extends ConsumerStatefulWidget {
  const ShellPermissionsPage({super.key});

  @override
  ConsumerState<ShellPermissionsPage> createState() => _ShellPermissionsPageState();
}

class _ShellPermissionsPageState extends ConsumerState<ShellPermissionsPage> {
  bool _showCommands = false;
  // 最近记录的展开状态也要提到页面级：放在子组件的 State 里，滚出视口
  // 被 Flutter 回收后就会重置成默认值，看起来像「开关自己又打开了」。
  bool _showRecent = true;
  final Set<String> _expanded = <String>{};
  bool _loaded = false;

  /// 乐观更新的本地副本：点一下就改这里，背后的写入合并成一次。
  String? _mode;
  Set<String>? _allowed;
  bool? _sdcard;
  Timer? _flushTimer;
  late final PhoneController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(phoneProvider.notifier);
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _showCommands = p.getBool(_prefShowCommands) ?? false;
        _showRecent = p.getBool(_prefShowRecent) ?? true;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    // 页面一关就立刻把还没落盘的勾选写掉，别等 300ms 的合并窗口。
    _flushTimer?.cancel();
    if (_allowed != null) {
      _controller.setAllowedCommands(_allowed!.toList());
    }
    super.dispose();
  }

  void _setShowCommands(bool on) {
    setState(() => _showCommands = on);
    SharedPreferences.getInstance().then((p) => p.setBool(_prefShowCommands, on));
  }

  void _setShowRecent(bool on) {
    setState(() => _showRecent = on);
    SharedPreferences.getInstance().then((p) => p.setBool(_prefShowRecent, on));
  }

  /// 切档位：先改本地、立刻重建，再异步落盘。
  void _pickMode(PhoneShellStatus shell, String mode) {
    if (mode == shell.mode) return;
    final controller = ref.read(phoneProvider.notifier);

    Future<void> apply() async {
      // 切档时本地白名单属于旧档位，立刻作废；否则退出页面的 dispose
      // 会把旧档位的集合写进新档位的 prefs key。
      _flushTimer?.cancel();
      setState(() {
        _mode = mode;
        _allowed = null;
        _sdcard = null;
      });
      final ok = await controller.setShellMode(mode);
      if (!mounted) return;
      if (!ok) setState(() => _mode = null);
    }

    if (mode == 'full') {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ForkText.highRiskTitle),
          content: Text(ForkText.highRiskBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ForkText.cancel)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                apply();
              },
              child: Text(ForkText.confirmKnow),
            ),
          ],
        ),
      );
      return;
    }
    apply();
  }

  void _toggleCommand(PhoneShellStatus shell, String name, bool on) {
    final base = Set<String>.from(_allowed ?? shell.allowed);
    if (on) {
      base.add(name);
    } else {
      base.remove(name);
    }
    setState(() => _allowed = base);
    _scheduleFlush(() => _controller.setAllowedCommands(base.toList()));
  }

  void _toggleGroup(PhoneShellStatus shell, String group, bool on) {
    final names = shell.commands.where((c) => c.group == group).map((c) => c.name);
    final base = Set<String>.from(_allowed ?? shell.allowed);
    if (on) {
      base.addAll(names);
    } else {
      base.removeAll(names);
    }
    setState(() => _allowed = base);
    _scheduleFlush(() => _controller.setAllowedCommands(base.toList()));
  }

  /// 300ms 内的连续点击合并成一次写入。
  void _scheduleFlush(Future<void> Function() run) {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(run());
    });
  }

  Future<void> _toggleSdcard(PhoneShellStatus shell, bool on) async {
    if (on) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ForkText.sdcardTitle),
          content: Text(ForkText.sdcardBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ForkText.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ForkText.sdcardOpen)),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _sdcard = on);
    final done = await ref.read(phoneProvider.notifier).setSdcardAllowed(on);
    if (!mounted) return;
    if (!done) setState(() => _sdcard = null);
  }

  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(phoneProvider.select((s) => s.status.shell));
    final mode = _mode ?? shell.mode;
    final allowed = _allowed ?? shell.allowed.toSet();
    // 刚切档、服务端 status 还没回来时，别拿旧档位留下的 sdcardAllowed 顶包
    // （高危恒开，切回进阶会先显示开、1.5 秒后再关，闪一下）。
    // 服务端确认（shell.mode == _mode）之前才算「切档中」，否则一直卡在 false 上。
    final pendingMode = _mode != null && shell.mode != _mode;
    final sdcard = _sdcard ?? (mode == 'full' ? true : (pendingMode ? false : shell.sdcardAllowed));
    final isOriginal = mode == 'original';
    final isSafe = mode == 'safe';
    final isFull = mode == 'full';

    // 档位一变，本地乐观副本就作废，以服务端为准。
    if (_mode != null && shell.mode == _mode) {
      _mode = null;
      _allowed = null;
      _sdcard = null;
    }

    return AppPage.list(
      title: ForkText.terminalPermissions,
      subtitle: Text(ForkText.permissionsSubtitle),
      children: [
        SettingsSection(
          title: ForkText.tiersTitle,
          children: [
            _TierTile(
              label: ForkText.originalMode,
              tone: Colors.green,
              selected: isOriginal,
              summary: ForkText.originalSummary,
              onTap: () => _pickMode(shell, 'original'),
            ),
            _TierTile(
              label: ForkText.safeMode,
              tone: Colors.amber,
              selected: isSafe,
              summary: ForkText.safeSummary,
              onTap: () => _pickMode(shell, 'safe'),
            ),
            _TierTile(
              label: ForkText.fullMode,
              tone: Colors.red,
              selected: mode == 'full',
              summary: ForkText.fullSummary,
              onTap: () => _pickMode(shell, 'full'),
            ),
          ],
        ),
        if (!isOriginal && _loaded) ...[
          SettingsSection(
            title: ForkText.extraSettings,
            children: [
              SettingsSwitchTile(
                title: ForkText.showCommands,
                subtitle: ForkText.showCommandsSubtitle,
                value: _showCommands,
                onChanged: _setShowCommands,
              ),
              SettingsSwitchTile(
                title: ForkText.showRootBar,
                subtitle: ForkText.showRootBarSubtitle,
                value: ref.watch(showRootPillProvider),
                onChanged: (v) => unawaited(ref.read(showRootPillProvider.notifier).set(v)),
              ),
              if (!isFull)
                SettingsSwitchTile(
                  title: ForkText.sdcardAllow,
                  subtitle: sdcard ? ForkText.sdcardAllowedSummary : ForkText.sdcardDeniedSummary,
                  value: sdcard,
                  onChanged: (v) => _toggleSdcard(shell, v),
                ),
            ],
          ),
          if (_showCommands)
            for (final group in _groups(shell)) _groupSection(shell, group, allowed, isSafe: isSafe, isFull: isFull),
          _RecentSection(limit: 100, open: _showRecent, onOpenChanged: _setShowRecent),
        ],
      ],
    );
  }

  List<_CommandGroup> _groups(PhoneShellStatus shell) {
    // 分组顺序和标题都来自原生 ShellCommands.GROUPS；这里不再维护第二份清单。
    final groups = shell.groups.isEmpty ? const <PhoneShellGroup>[] : shell.groups;
    return [
      for (final g in groups)
        if (shell.commands.any((c) => c.group == g.id))
          _CommandGroup(
            id: g.id,
            title: g.title,
            desc: g.desc,
            commands: shell.commands.where((c) => c.group == g.id).toList(growable: false),
          ),
    ];
  }

  Widget _groupSection(
    PhoneShellStatus shell,
    _CommandGroup group,
    Set<String> allowed, {
    required bool isSafe,
    required bool isFull,
  }) {
    // 进阶模式：包管理和脚本整组锁死，不可勾选。
    // 高危模式整档放行，逐条开关没有意义：全部显示为开、不可点，避免误导。
    final locked = isFull || (isSafe && (group.id == 'packages' || group.id == 'script'));
    final on = isFull || group.commands.every((c) => allowed.contains(c.name));
    final open = _expanded.contains(group.id);

    return SettingsSection(
      title: group.title,
      children: [
        SettingsTile(
          title: ForkText.groupSwitch,
          subtitle: isFull
              ? ForkText.groupFullSummary
              : locked
              ? ForkText.groupLockedSummary
              : group.desc,
          // 点整行 = 展开这一组；总开关在右边的 Switch 上，两个互不干扰。
          onTap: () => setState(() {
            if (open) {
              _expanded.remove(group.id);
            } else {
              _expanded.add(group.id);
            }
          }),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(open ? AppIcons.collapse : AppIcons.expand, size: 20, color: Theme.of(context).colorScheme.outline),
              Switch(value: on, onChanged: locked ? null : (v) => _toggleGroup(shell, group.id, v)),
            ],
          ),
        ),
        if (open)
          for (final c in group.commands)
            SettingsSwitchTile(
              title: c.name,
              subtitle: c.desc,
              value: locked ? true : allowed.contains(c.name),
              onChanged: locked ? null : (v) => _toggleCommand(shell, c.name, v),
            ),
      ],
    );
  }
}

class _CommandGroup {
  const _CommandGroup({required this.id, required this.title, required this.desc, required this.commands});

  final String id;
  final String title;
  final String desc;
  final List<PhoneShellCommand> commands;
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.label,
    required this.tone,
    required this.selected,
    required this.summary,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final bool selected;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsTile(
      icon: AppIcons.radioOff,
      tint: 0,
      title: label,
      subtitle: summary,
      onTap: onTap,
      trailing: Icon(selected ? AppIcons.completed : AppIcons.radioOff, color: selected ? tone : scheme.outlineVariant),
    );
  }
}

/// 最近记录：默认展开，显示真实命令。
class _RecentSection extends ConsumerStatefulWidget {
  const _RecentSection({required this.limit, required this.open, required this.onOpenChanged});

  final int limit;
  final bool open;
  final ValueChanged<bool> onOpenChanged;

  @override
  ConsumerState<_RecentSection> createState() => _RecentSectionState();
}

class _RecentSectionState extends ConsumerState<_RecentSection> {
  @override
  void initState() {
    super.initState();
    // 进页面拉一次，之后跟着 state 走，不再自己持有列表。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(phoneProvider.notifier).refreshLog(limit: widget.limit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(phoneProvider.select((s) => s.log));
    return SettingsSection(
      title: ForkText.recentTitle,
      children: [
        SettingsSwitchTile(
          title: ForkText.recentExpand,
          subtitle: entries.isEmpty ? ForkText.recentEmpty : ForkText.recentCount(entries.length, widget.limit),
          value: widget.open,
          onChanged: widget.onOpenChanged,
        ),
        if (widget.open)
          for (final e in entries.take(widget.limit))
            SettingsTile(
              icon: AppIcons.disclosure,
              title: e.summary.isEmpty ? e.tool : e.summary,
              subtitle: [
                e.tool,
                _stamp(e.time),
                if (e.rawDecision != null && e.rawDecision!.isNotEmpty) e.rawDecision!,
              ].where((x) => x.isNotEmpty).join(' · '),
            ),
      ],
    );
  }

  String _stamp(DateTime? t) {
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
