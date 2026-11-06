// fork 层的「插件」入口胶囊：当终端/完全权限占着输入条上方那一行时，
// 把插件入口也收进同一行；窄屏时收成一个方块图标，不另起一行。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../ui/plugins/native/chat_plugins_sheet.dart';
import '../../ui/plugins/native/composer_capsules.dart';
import '../../ui/theme/app_icons.dart';
import '../../ui/theme/theme.dart';

class ChatPluginsPill extends ConsumerWidget {
  const ChatPluginsPill({super.key, required this.sessionId, this.compact = false});

  final String sessionId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = context.l10n.plugslotsChatEntry;
    void open() => unawaited(showChatPluginsSheet(context, sessionId: sessionId));
    if (compact) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GlassSurface(
          tier: GlassTier.chrome,
          stadium: true,
          grouped: true,
          onTap: open,
          child: SizedBox.square(
            dimension: CapsuleMetrics.height,
            child: Icon(AppIcons.plugin, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ComposerCapsule(
      item: CapsuleItem(id: chatPluginsCapsuleId, label: label, icon: AppIcons.plugin, onTap: open),
    );
  }
}
