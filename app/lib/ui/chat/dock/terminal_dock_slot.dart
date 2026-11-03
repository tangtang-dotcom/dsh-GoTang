import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/phone_state.dart';
import '../../phone/shell_permissions_page.dart';
import 'dock_pill.dart';

/// 输入条上方的终端权限条：和输入框同宽、同一套圆角，显示「root 已启用 / 点击关闭」。
///
/// 轻点关闭终端权限，长按进设置。原版档位不显示。
class TerminalDockSlot extends ConsumerWidget {
  const TerminalDockSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(phoneProvider.select((s) => s.status.shell));
    if (shell.isOriginal) return const DockSlot(child: null);
    final theme = Theme.of(context);
    final gold = theme.brightness == Brightness.dark ? Colors.amber.shade200 : Colors.amber.shade900;
    final detail = switch (shell.mode) {
      'safe' => '（进阶）',
      'full' => '（高危）',
      _ => '',
    };

    return DockSlot(
      key: const ValueKey('terminal'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Semantics(
          button: true,
          label: 'root 已启用$detail，点击关闭',
          excludeSemantics: true,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => ref.read(phoneProvider.notifier).setShellMode('original'),
              onLongPress: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ShellPermissionsPage()),
              ),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.terminal, size: 18, color: gold),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'root 已启用',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '点击关闭',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
