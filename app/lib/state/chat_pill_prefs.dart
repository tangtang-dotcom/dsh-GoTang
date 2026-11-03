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
