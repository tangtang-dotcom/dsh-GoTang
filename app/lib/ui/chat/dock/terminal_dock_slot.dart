import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/phone_state.dart';
import '../../phone/shell_permissions_page.dart';
import 'dock_pill.dart';

/// 输入条上方的终端权限胶囊：显示当前档位，点一下进设置。
///
/// 原版不显示（没有终端能力就没必要打扰）；进阶黄、高危红 —— 危险档位不该安安静静待着。
class TerminalDockSlot extends ConsumerWidget {
  const TerminalDockSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(phoneProvider.select((s) => s.status.shell));
    if (shell.isOriginal) return const DockSlot(child: null);
    final theme = Theme.of(context);
    // 和他的胶囊一致：显示“root 已启用”，点一下直接关掉。
    final (label, color, icon) = switch (shell.mode) {
      'safe' => ('root 已启用 · 进阶', Colors.amber.shade700, Icons.shield_outlined),
      'full' => ('root 已启用 · 高危', Colors.red.shade600, Icons.terminal),
      _ => ('启用终端', theme.colorScheme.onSurfaceVariant, Icons.terminal_outlined),
    };
    return DockSlot(
      key: const ValueKey('terminal'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Semantics(
          button: true,
          label: '$label，点击关闭',
          excludeSemantics: true,
          child: Material(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              // 轻点关闭（和他的胶囊一致）；长按进设置。
              onTap: () => ref.read(phoneProvider.notifier).setShellMode('original'),
              onLongPress: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShellPermissionsPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('点击关闭', style: theme.textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
