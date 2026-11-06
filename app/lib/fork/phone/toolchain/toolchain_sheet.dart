// fork 层的「逆向工具」面板：状态轮询 + 安装按钮。
// phone_control_screen 只留 _openToolchain 里的 ForkToolchainSheet 一行。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../runtime/runtime_state.dart';
import '../../../ui/common/list_page_row.dart';
import '../../../ui/theme/app_icons.dart';

class ForkToolchainSheet extends ConsumerStatefulWidget {
  const ForkToolchainSheet({super.key});

  @override
  ConsumerState<ForkToolchainSheet> createState() => _ForkToolchainSheetState();
}

class _ForkToolchainSheetState extends ConsumerState<ForkToolchainSheet> {
  static const _labels = <String, String>{
    'java': 'Java 17',
    'jadx': 'jadx',
    'apktool': 'apktool',
    'r2': 'radare2',
    'objdump': 'binutils',
  };

  Map<Object?, Object?> _status = const {};
  Timer? _timer;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final next = await ref.read(runtimeBridgeProvider).toolchainStatus();
      if (mounted) setState(() => _status = next);
    } catch (_) {
      // The native side may be busy starting the engine; keep the last snapshot.
    }
  }

  Future<void> _install() async {
    setState(() => _starting = true);
    try {
      final result = await ref.read(runtimeBridgeProvider).installToolchain();
      if (!mounted) return;
      if (result['ok'] == false) {
        final reason = result['reason']?.toString().trim();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(reason == null || reason.isEmpty ? '安装失败。' : '安装失败：$reason')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('安装失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final installed = (_status['installed'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final running = _status['running'] == true;
    final runtimeReady = _status['runtimeReady'] != false;
    final allInstalled = _status['allInstalled'] == true;
    final log = (_status['log'] as String?)?.trim() ?? '';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.toolchainTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  l10n.toolchainHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                for (final entry in _labels.entries)
                  ListPageRow(
                    title: entry.value,
                    subtitle: installed[entry.key] == true ? l10n.toolchainInstalled : l10n.toolchainMissing,
                    trailing: Icon(
                      installed[entry.key] == true ? AppIcons.completed : AppIcons.radioOff,
                      size: 20,
                      color: installed[entry.key] == true ? theme.colorScheme.primary : theme.colorScheme.outline,
                    ),
                  ),
                if (log.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    log,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 12),
                if (!runtimeReady)
                  Text(l10n.toolchainNoRuntime, style: theme.textTheme.bodySmall)
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_starting || running) ? null : _install,
                      icon: const Icon(AppIcons.download, size: 18),
                      label: Text(
                        running
                            ? l10n.toolchainInstalling
                            : (allInstalled ? l10n.toolchainReinstall : l10n.toolchainInstall),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
