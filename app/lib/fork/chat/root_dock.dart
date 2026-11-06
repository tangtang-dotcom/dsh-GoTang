// fork 层的终端胶囊 + 「完全权限」组合行。
// 上游 chat_screen 只留一个 ForkRootDock 调用点，合并时不会碰到内部布局。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_modes.dart';
import '../../ui/chat/dock/dock_pill.dart';
import '../../ui/chat/widgets/permission_pill.dart';
import '../../ui/chat/widgets/plus_panel.dart';
import '../../ui/plugins/native/chat_plugins_sheet.dart';
import '../../ui_config/ui_config_model.dart';
import '../../ui_config/ui_config_state.dart';
import 'chat_pill_prefs.dart';
import 'plugins_pill.dart';
import 'root_pill.dart';

/// 终端胶囊与「完全权限」合成的一行：终端胶囊占满，完全权限收成右端的
/// 圆形 ⚠，各点各的（终端进设置、⚠ 进会话权限）；没有 ⚠ 就只放终端胶囊。
class ForkRootDock extends ConsumerWidget {
  const ForkRootDock({super.key, required this.sessionId, required this.autoApprove});

  final String? sessionId;
  final bool autoApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = sessionId;
    final risky = id == null || autoApprove
        ? null
        : ref.watch(sessionModesProvider(id).select((m) => m.risky ? m.preset : null));
    final showPermission = risky != null && !ref.watch(hidePermissionPillProvider);
    final showPlugin =
        id != null &&
        ref.watch(showPluginPillProvider) &&
        !ref.watch(uiHiddenProvider(UiHideItem.pluginCapsule)) &&
        ref.watch(chatPluginsHaveContentProvider(id));
    if (!showPermission && !showPlugin) return const RootPill();
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          const Expanded(child: RootPill()),
          if (showPlugin) ...[
            const SizedBox(width: DockMetrics.gap),
            ChatPluginsPill(sessionId: id!, compact: constraints.maxWidth < 350),
          ],
          if (showPermission) ...[
            const SizedBox(width: DockMetrics.gap),
            PermissionPill(preset: risky!, compact: true, onTap: () => unawaited(showPermissionSheet(context, id!))),
          ],
        ],
      ),
    );
  }
}
