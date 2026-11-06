// fork 层的「这个对话」开关：完全权限提醒 / root 状态条。
// plus_panel 只留 `...forkChatPillSwitches(context, ref)` 一行。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/common/list_page_row.dart';
import 'chat_pill_prefs.dart';

List<Widget> forkChatPillSwitches(BuildContext context, WidgetRef ref) => [
  MergeSemantics(
    child: ListPageRow(
      title: '隐藏「完全权限」提醒',
      subtitle: '只是不再提示，对话权限本身不变',
      trailing: Switch(
        value: ref.watch(hidePermissionPillProvider),
        onChanged: (v) => unawaited(ref.read(hidePermissionPillProvider.notifier).set(v)),
      ),
    ),
  ),
  MergeSemantics(
    child: ListPageRow(
      title: '在输入框上方显示 root 状态',
      subtitle: '关闭后不再显示终端档位条',
      trailing: Switch(
        value: ref.watch(showRootPillProvider),
        onChanged: (v) => unawaited(ref.read(showRootPillProvider.notifier).set(v)),
      ),
    ),
  ),
];
