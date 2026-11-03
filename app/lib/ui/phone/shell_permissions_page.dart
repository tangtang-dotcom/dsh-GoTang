import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/phone_state.dart';

/// 设置 → 手机操控 → 进阶 → 终端权限。
///
/// 三档：原版（没有终端）/ 进阶（只跑勾选的命令，危险命令永久锁死）/ 高危（任意命令）。
/// 判定在原生侧的 ShellGuard 里，这里只是选择器。
class ShellPermissionsPage extends ConsumerWidget {
  const ShellPermissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(phoneProvider).status.shell;
    final controller = ref.read(phoneProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('终端权限')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            '让模型以 root 执行 shell 命令。三档按需要选，档位越高越危险。',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'original', label: Text('关闭')),
              ButtonSegment(value: 'safe', label: Text('进阶')),
              ButtonSegment(value: 'full', label: Text('高危')),
            ],
            selected: {status.mode},
            onSelectionChanged: (set) => controller.setShellMode(set.first),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                switch (status.mode) {
                  'safe' => '进阶模式：只放行下面勾选的命令；dd / mkfs / insmod / reboot 等永久禁止；'
                      '写文件只能落在 Download、/data/local/tmp 和 App 私有目录。',
                  'full' => '高危模式：任意命令，包括改系统、刷机、删除数据。只在你完全信任的情况下使用。',
                  _ => '关闭：模型看不到终端工具，和原版一致。',
                },
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          if (status.isSafe) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('允许读写整个 /sdcard'),
              subtitle: const Text('默认只允许 Download；打开后 AI 可以读写整个存储（相册仍然只读新增，不可覆盖删除）'),
              value: status.sdcardAllowed,
              onChanged: (on) => controller.setSdcardAllowed(on),
            ),
            const SizedBox(height: 8),
            Text('允许的命令', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final group in _groups(status))
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(group.$1),
                subtitle: Text('${group.$2} 条'),
                children: [
                  for (final cmd in group.$3)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(cmd.name, style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: cmd.desc.isEmpty ? null : Text(cmd.desc),
                      value: status.isAllowed(cmd.name),
                      onChanged: (_) => controller.setAllowedCommands(_toggle(status, cmd.name)),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  static List<String> _toggle(PhoneShellStatus status, String name) {
    final next = {...status.allowed};
    if (!next.remove(name)) next.add(name);
    return next.toList()..sort();
  }

  /// 按分组合并命令；组标题用组 id（原生只给 id 和单条说明）。
  static List<(String, int, List<PhoneShellCommand>)> _groups(PhoneShellStatus status) {
    final map = <String, List<PhoneShellCommand>>{};
    for (final c in status.commands) {
      map.putIfAbsent(c.group, () => []).add(c);
    }
    const order = ['read', 'file', 'system', 'network', 'packages', 'script'];
    const titles = {
      'read': '只读命令',
      'file': '文件操作',
      'system': '系统操作',
      'network': '网络',
      'packages': '包管理',
      'script': '脚本执行',
    };
    return [
      for (final id in [...order, ...map.keys.where((k) => !order.contains(k))])
        if (map[id]?.isNotEmpty ?? false) (titles[id] ?? id, map[id]!.length, map[id]!),
    ];
  }
}
