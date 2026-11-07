import 'dart:async';

import 'package:flutter/widgets.dart';

/// 轻点回调，绕开手势竞技场。
///
/// 用在被 [SelectionArea] 包住的气泡上：`GestureDetector.onTap` 会被 SelectionArea
/// 的点击处理抢走（它用点击取消选择），但原始指针事件仍然到手，所以这里自己判定
/// 「按下到抬起位移很小、时间很短」= 一次轻点。
class TapToMenu extends StatefulWidget {
  const TapToMenu({super.key, required this.onTap, required this.child});

  /// 这一下轻点已经被里面的控件用掉了（气泡里的眼睛、正文里的链接/代码块）：
  /// 别再开消息菜单。
  static bool _suppressed = false;
  static void suppressNextTap() => _suppressed = true;

  final VoidCallback onTap;
  final Widget child;

  @override
  State<TapToMenu> createState() => _TapToMenuState();
}

class _TapToMenuState extends State<TapToMenu> {
  Offset? _downAt;
  int? _downMs;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _downAt = event.position;
        _downMs = event.timeStamp.inMilliseconds;
      },
      onPointerUp: (event) {
        if (TapToMenu._suppressed) {
          TapToMenu._suppressed = false;
          _downAt = null;
          _downMs = null;
          return;
        }
        final down = _downAt;
        final downMs = _downMs;
        _downAt = null;
        _downMs = null;
        if (down == null || downMs == null) return;
        final moved = (event.position - down).distance;
        final held = event.timeStamp.inMilliseconds - downMs;
        // 手指几乎没动且很快抬起：轻点。拖动选字会超出这个阈值，不会误触。
        // 延后一个微任务，让正文里的链接/按钮先跑完自己的 onTap 并登记抑制。
        if (moved <= 12 && held <= 400) {
          scheduleMicrotask(() {
            if (TapToMenu._suppressed) {
              TapToMenu._suppressed = false;
              return;
            }
            widget.onTap();
          });
        }
      },
      onPointerCancel: (_) {
        TapToMenu._suppressed = false;
        _downAt = null;
        _downMs = null;
      },
      child: widget.child,
    );
  }
}
