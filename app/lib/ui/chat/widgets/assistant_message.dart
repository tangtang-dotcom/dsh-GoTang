// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../common/expand_reveal.dart';
import '../../common/typing_indicator.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../dsh_ui/dsh_ui.dart';
import '../../plugins/native/message_plugin_menu.dart';
import '../../share/share_entry.dart' show shareReply;
import '../render/markdown_body.dart';
import 'message_actions.dart';
import 'thinking_pill.dart';

/// 助手消息:**无框裸排的全宽正文**(Claude 式),没有头像也没有署名。
///
/// ```
/// (思考过程 ⌄)
/// 正文 Markdown…▍
/// ⚠ 响应已中断
/// ⧉ ⇪ ⑂ ↻ ⋯        ← 一轮的最后一条才有(分叉视 DSH 是否支持;
///                    ↻ 重新回答只给整个对话的最后一条)
/// ```
///
/// ⇪ 和菜单里的「分享」打开同一个分享面板。长按或 ⋯:同一个消息菜单(复制 /
/// 选择文字 / 引用 / 分享 / 重新回答 / 从这里分叉)。正文因此不再直接长按选字,选字走菜单里的
/// "选择文字",选中一段还能「引用」(Claude 式)。
class AssistantMessage extends StatefulWidget {
  const AssistantMessage({
    super.key,
    required this.item,
    this.showActions = false,
    this.onBranch,
    this.branching = false,
    this.onRegenerate,
    this.regenerating = false,
    this.onQuote,
    this.footnote,
  });

  final AssistantChatItem item;

  /// 是否在正文下方显示复制等操作(只给一轮里最后一条助手正文)。
  final bool showActions;

  /// "从这里分叉";null = 这条不是已完成一轮的最后一条回复。
  final VoidCallback? onBranch;

  /// 正在从这里分叉:分叉键转圈,不能再点。
  final bool branching;

  /// 「重新回答」;null = 这条不是对话的最后一条回复,或提问发不了第二次。
  final VoidCallback? onRegenerate;

  /// 正在准备重新回答:重答键转圈,不能再点。
  final bool regenerating;

  /// 「引用」:整条回复,或「选择文字」里选中的一段,放到输入框上方。
  final ValueChanged<String>? onQuote;

  /// 回合脚注(这一轮在这条回复处结束),挂在操作行右端。
  final Widget? footnote;

  @override
  State<AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<AssistantMessage> {
  Widget? _body;
  String? _bodyText;
  bool? _bodyStreaming;

  /// 已经显示出来的那段文字及其长度。流式内容是按块到达的（一次几十上百字），
  /// 收到就整段替换会看到「一跳一跳」；这里让显示长度自己朝目标追，落后越多
  /// 追得越快，落后很少时每次两三个字，看上去就是连续流淌。
  String _revealed = '';
  int _revealedLength = 0;
  String _target = '';
  Timer? _pump;

  @override
  void dispose() {
    _pump?.cancel();
    super.dispose();
  }

  /// 追一帧，然后看还要不要继续。
  void _advance() {
    final text = _target;
    final pending = text.length - _revealedLength;
    if (pending <= 0) {
      _revealed = text;
      return;
    }
    final step = pending <= 8 ? 2 : (pending / 6).ceil();
    var next = _revealedLength + step;
    if (next > text.length) next = text.length;
    // 不把代理对（emoji 等）切成两半。
    if (next < text.length) {
      final unit = text.codeUnitAt(next - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) next -= 1;
    }
    _revealedLength = next;
    _revealed = text.substring(0, next);
  }

  String _smooth(String text, bool streaming) {
    _target = text;
    if (!streaming) {
      _pump?.cancel();
      _pump = null;
      _revealed = text;
      _revealedLength = text.length;
      return text;
    }
    // 内容被整体替换（重新生成、工具卡换回文字）：不再慢慢追，直接对齐。
    if (!text.startsWith(_revealed)) {
      _revealed = text;
      _revealedLength = text.length;
      return text;
    }
    _advance();
    if (_revealedLength < text.length) _startPump();
    return _revealed;
  }

  /// ~41fps 自己推进；追上目标或流式结束时停，不用等父组件下一次重建。
  void _startPump() {
    if (_pump != null) return;
    _pump = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (!mounted || !widget.item.streaming) {
        timer.cancel();
        _pump = null;
        return;
      }
      if (_revealedLength >= _target.length) {
        timer.cancel();
        _pump = null;
        return;
      }
      setState(_advance);
    });
  }

  /// 流式期间：已经写完的段落照常渲染成 Markdown，只有正在写的最后一块用
  /// 轻量文本追字。这样每帧成本与回复长度无关 —— 思考行之所以流畅就是这个原因。
  String? _prefixText;
  Widget? _prefixBody;

  /// 最后一个「完整块」的边界：空行，且不在 ``` 围栏里；没有就返回 0（整段都算正在写）。
  static int _streamSplit(String text) {
    var fences = 0;
    var safe = 0;
    var i = 0;
    while (i < text.length) {
      if (text.startsWith('```', i)) {
        fences++;
        i += 3;
        continue;
      }
      if (text.startsWith('\n\n', i)) {
        if (fences.isEven) safe = i + 2;
        i += 2;
        continue;
      }
      i++;
    }
    return safe;
  }

  /// 末尾还在写的这一块：去掉行内的 Markdown 标记，先当普通文字显示；
  /// 整块写完时它会并进上面的 Markdown 里。
  static String _plainTail(String text) => text
      .replaceAll('**', '')
      .replaceAll('~~', '')
      .replaceAll('`', '');

  /// 只有「纯散文」才配得上轻量渲染：代码块、表格、列表、标题、引用、链接、
  /// 图片、公式、dsh-ui 围栏都要如实画，宁可回到全文 Markdown 慢一点。
  static bool _plainOk(String tail) {
    if (tail.contains('```') || tail.contains('$$')) return false;
    for (final line in tail.split('\n')) {
      final t = line.trimLeft();
      if (t.startsWith('|') || t.startsWith('![')) return false;
      if (t.startsWith('#') || t.startsWith('>') || t.startsWith('- ') || t.startsWith('* ')) return false;
      if (RegExp(r'^\d+[.)]\s').hasMatch(t)) return false;
      if (t.contains('](')) return false;
    }
    return true;
  }

  Widget? _structuredBody;
  String? _structuredText;

  Widget _markdown(String text, bool streaming, TextStyle? style) {
    if (!streaming) {
      _pump?.cancel();
      _pump = null;
      final shown = _smooth(text, false);
      if (_body == null || _bodyText != shown || _bodyStreaming != streaming) {
        // Long-press opens the menu; selecting text is one of its entries.
        // repairBareViews: a model that forgets the ```dsh-ui fence still gets
        // its view drawn instead of a wall of JSON.
        _body = MarkdownBody(text: shown, streaming: false, selectable: false, repairBareViews: true);
        _bodyText = shown;
        _bodyStreaming = streaming;
      }
      return _body!;
    }

    final cut = _streamSplit(text);
    final tailRaw = cut > 0 ? text.substring(cut) : text;
    if (!_plainOk(tailRaw)) {
      // 结构化内容：整段交给 Markdown，正确优先。
      _pump?.cancel();
      _pump = null;
      if (_structuredText != text) {
        _structuredText = text;
        _structuredBody = MarkdownBody(text: text, streaming: true, selectable: false, repairBareViews: true);
      }
      return _structuredBody!;
    }
    final prefix = cut > 0 ? text.substring(0, cut) : '';
    if (_prefixText != prefix) {
      _prefixText = prefix;
      _prefixBody = prefix.isEmpty
          ? null
          : MarkdownBody(text: prefix, streaming: false, selectable: false, repairBareViews: true);
    }
    final tail = _plainTail(cut > 0 ? text.substring(cut) : text);
    final shownTail = _smooth(tail, true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_prefixBody != null) _prefixBody!,
        if (shownTail.isNotEmpty) Text(shownTail, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final text = item.text.trimRight();
    final reasoning = item.reasoning.trim();
    final streaming = item.streaming;

    if (text.isEmpty && reasoning.isEmpty) {
      if (streaming) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(label: l10n.chatReplying, child: const TypingIndicator()),
          ),
        );
      }
      if (!item.interrupted) return const SizedBox.shrink();
    }

    final actions = widget.showActions && !streaming && text.isNotEmpty;
    // 正文样式：和 MarkdownBody 里用的同一套，末尾追字时保持字号/行高一致。
    final bodyStyle = AppType.chatBody(context, color: Theme.of(context).colorScheme.onSurface);
    final reply = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: streaming || text.isEmpty ? null : () => _menu(text),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reasoning.isNotEmpty) ...[
            ThinkingPill(reasoning: reasoning, active: streaming && text.isEmpty, streaming: streaming),
            if (text.isNotEmpty) const SizedBox(height: 8),
          ],
          if (text.isNotEmpty) _markdown(text, streaming, bodyStyle),
          if (item.interrupted) const _InterruptedMark(),
          // 一轮结束时和输入条上的胶囊同一节奏展开:胶囊收回多少,这里长出
          // 多少,回答不会先被顶上去再落回来。打开对话时已结束的轮直接展开。
          ExpandReveal(
            open: actions,
            duration: AppMotion.standard,
            curve: AppMotion.std,
            child: actions
                ? ReplyActionRow(
                    // Copy / share carry a one-line summary of each visual
                    // reply, never its raw JSON.
                    text: dshUiPlainText(text),
                    onBranch: widget.onBranch,
                    branching: widget.branching,
                    onShare: () => shareReply(context, widget.item),
                    onRegenerate: widget.onRegenerate,
                    regenerating: widget.regenerating,
                    onMore: () => _menu(text),
                    trailing: widget.footnote,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
    // 一条回复是读屏里的一个分组,里面的段落、标题照常逐个读。
    return Semantics(container: true, explicitChildNodes: true, child: reply);
  }

  Future<void> _menu(String markdown) async {
    final text = dshUiPlainText(markdown);
    final onBranch = widget.onBranch;
    final onRegenerate = widget.onRegenerate;
    final onQuote = widget.onQuote;
    final action = await showMessageMenu(
      context,
      text: text,
      // Plugins' items for this reply, under each plugin's name.
      extra: nativeMessageMenuGroups(context, widget.item, text: markdown),
      actions: [
        MessageAction.copy,
        MessageAction.selectText,
        if (onQuote != null) MessageAction.quote,
        MessageAction.share,
        if (onRegenerate != null && !widget.regenerating) MessageAction.regenerate,
        if (onBranch != null && !widget.branching) MessageAction.branch,
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MessageAction.copy:
        await copyMessage(context, text);
      case MessageAction.selectText:
        await showSelectTextSheet(context, text, markdown: true, onQuote: onQuote);
      case MessageAction.quote:
        onQuote?.call(text);
      case MessageAction.share:
        await shareReply(context, widget.item);
      case MessageAction.regenerate:
        onRegenerate?.call();
      case MessageAction.branch:
        onBranch?.call();
      case MessageAction.edit:
        break;
    }
  }
}

/// 被取消 / 中断:正文末尾一行 danger 小字,不改正文颜色。
class _InterruptedMark extends StatelessWidget {
  const _InterruptedMark();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final danger = DshColors.of(context).danger;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.stopped, size: 16, color: danger),
          const SizedBox(width: 4),
          Text(
            l10n.chatInterrupted,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: danger, height: 1.3),
          ),
        ],
      ),
    );
  }
}
