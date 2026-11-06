import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 是否隐藏输入条上方的「⚠ 完全权限」提醒。
///
/// 默认显示：它提醒的是“这个对话比默认权限更宽”。用户明确关掉后不再出现，
/// 权限本身不受影响。
class HidePermissionPill extends Notifier<bool> {
  static const _key = 'chat.hidePermissionPill';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ref.mounted) state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final hidePermissionPillProvider = NotifierProvider<HidePermissionPill, bool>(HidePermissionPill.new);

/// 是否在输入框上方显示 root 状态条（终端权限档位）。
///
/// 默认显示；关掉后连生成期间的紧凑图标也不出现。
class ShowRootPill extends Notifier<bool> {
  static const _key = 'chat.showRootPill';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ref.mounted) state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showRootPillProvider = NotifierProvider<ShowRootPill, bool>(ShowRootPill.new);

/// 是否显示输入条上方的「插件」按钮。
///
/// 默认显示；关掉后插件自己的动作胶囊还在，只是不再显示这个入口。
class ShowPluginPill extends Notifier<bool> {
  static const _key = 'chat.showPluginPill';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ref.mounted) state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showPluginPillProvider = NotifierProvider<ShowPluginPill, bool>(ShowPluginPill.new);
