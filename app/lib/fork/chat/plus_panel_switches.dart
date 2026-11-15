// fork 层的聊天胶囊开关：完全权限提醒 / root 状态条（Storage 是全局的）。
// plus_panel 只留 `...forkChatPillSwitches(context, ref)` 一行。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fork_text.dart';
import '../../ui/common/list_page_row.dart';
import 'chat_pill_prefs.dart';

List<Widget> forkChatPillSwitches(BuildContext context, WidgetRef ref) => [
  MergeSemantics(
    child: ListPageRow(
      title: ForkText.showPermissionTitle,
      subtitle: ForkText.showPermissionSubtitle,
      trailing: Switch(
        value: ref.watch(showPermissionPillProvider),
        onChanged: (v) => unawaited(ref.read(showPermissionPillProvider.notifier).set(v)),
      ),
    ),
  ),
  MergeSemantics(
    child: ListPageRow(
      title: ForkText.showRootTitle,
      subtitle: ForkText.showRootSubtitle,
      trailing: Switch(
        value: ref.watch(showRootPillProvider),
        onChanged: (v) => unawaited(ref.read(showRootPillProvider.notifier).set(v)),
      ),
    ),
  ),
  MergeSemantics(
    child: ListPageRow(
      title: ForkText.showPluginTitle,
      subtitle: ForkText.showPluginSubtitle,
      trailing: Switch(
        value: ref.watch(showPluginPillProvider),
        onChanged: (v) => unawaited(ref.read(showPluginPillProvider.notifier).set(v)),
      ),
    ),
  ),
];
