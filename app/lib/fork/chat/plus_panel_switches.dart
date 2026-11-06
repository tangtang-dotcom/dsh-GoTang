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
      title: ForkText.hidePermissionTitle,
      subtitle: ForkText.hidePermissionSubtitle,
      trailing: Switch(
        value: ref.watch(hidePermissionPillProvider),
        onChanged: (v) => unawaited(ref.read(hidePermissionPillProvider.notifier).set(v)),
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
];
