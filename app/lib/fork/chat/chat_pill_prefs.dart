import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 是否显示输入条上方的「⚠ 完全权限」提醒。
///
/// 默认显示：它提醒的是“这个对话比默认权限更宽”。关掉后不再出现，
/// 权限本身不受影响。
class ShowPermissionPill extends Notifier<bool> {
  bool _userSet = false;
  static const _key = 'chat.showPermissionPill';
  static const _legacyKey = 'chat.hidePermissionPill';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_key);
    final value = stored ?? !(prefs.getBool(_legacyKey) ?? false);
    if (ref.mounted && !_userSet) state = value;
  }

  Future<void> set(bool value) async {
    _userSet = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showPermissionPillProvider = NotifierProvider<ShowPermissionPill, bool>(ShowPermissionPill.new);

/// 是否在输入框上方显示 root 状态条（终端权限档位）。
///
/// 默认显示；关掉后连生成期间的紧凑图标也不出现。
class ShowRootPill extends Notifier<bool> {
  bool _userSet = false;
  static const _key = 'chat.showRootPill';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ref.mounted && !_userSet) state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    _userSet = true;
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
  bool _userSet = false;
  static const _key = 'chat.showPluginPill';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ref.mounted && !_userSet) state = prefs.getBool(_key) ?? true;
  }

  Future<void> set(bool value) async {
    _userSet = true;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showPluginPillProvider = NotifierProvider<ShowPluginPill, bool>(ShowPluginPill.new);
