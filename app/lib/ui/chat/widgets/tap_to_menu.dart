import 'package:flutter/widgets.dart';

/// 轻点回调，绕开手势竞技场。
///
/// 用在被 [SelectionArea] 包住的气泡上：`GestureDetector.onTap` 会被 SelectionArea
/// 的点击处理抢走（它用点击取消选择），但原始指针事件仍然到手，所以这里自己判定
/// 「按下到抬起位移很小、时间很短」= 一次轻点。
class TapToMenu extends StatefulWidget {
  const TapToMenu({super.key, required this.onTap, required this.child});

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
        final down = _downAt;
        final downMs = _downMs;
        _downAt = null;
        _downMs = null;
        if (down == null || downMs == null) return;
        final moved = (event.position - down).distance;
        final held = event.timeStamp.inMilliseconds - downMs;
        // 手指几乎没动且很快抬起：轻点。拖动选字会超出这个阈值，不会误触。
        if (moved <= 12 && held <= 400) widget.onTap();
      },
      onPointerCancel: (_) {
        _downAt = null;
        _downMs = null;
      },
      child: widget.child,
    );
  }
}
