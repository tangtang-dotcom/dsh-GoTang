// Temporary probe (removed with probe.yml): dumps the widget chain behind a
// RenderFlex overflow at 320 dp / 1.3x, which the goldens only report as a bare
// "overflowed by 34 pixels".
import 'package:dsh_app/state/adaptive_layout_state.dart';
import 'package:dsh_app/ui/chat/chat_screen.dart';
import 'package:dsh_app/ui/shell/home_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/support/harness.dart';
import '../support/english_preview.dart';
import 'adaptive/support.dart';

void main() {
  setUpAll(loadTestFonts);

  Future<List<FlutterErrorDetails>> capture(WidgetTester tester, Future<void> Function() pump) async {
    final seen = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => seen.add(details);
    await pump();
    FlutterError.onError = previous;
    return seen;
  }

  Future<void> home(WidgetTester tester, {required bool english}) async {
    if (english) useEnglish();
    SharedPreferences.setMockInitialValues({});
    useWindow(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    mockClipboard(tester);
    final shell = HomeShell(chatBuilder: (openDrawer) => ChatScreen(onOpenDrawer: openDrawer, backdrop: false));
    await tester.pumpWidget(
      testApp(
        english ? inEnglish(shell) : shell,
        overrides: homeOverrides(prefs: const LayoutPrefs(loaded: true)),
      ),
    );
    await pumpFrames(tester, 10);
  }

  for (final english in [false, true]) {
    final tag = english ? 'en' : 'zh';

    testWidgets('probe chat $tag', (tester) async {
      final found = await capture(tester, () => home(tester, english: english));
      debugPrint('PROBE chat $tag: ${found.length} error(s)');
      for (final d in found) {
        debugPrint('PROBE >>>> ${d.toString()}');
      }
    });

    testWidgets('probe panel $tag', (tester) async {
      await home(tester, english: english);
      final found = await capture(tester, () async {
        final finger = await tester.startGesture(const Offset(240, 320));
        for (var i = 0; i < 40; i++) {
          await finger.moveBy(const Offset(-8, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 400));
        await finger.up();
        await pumpFrames(tester, 10);
      });
      debugPrint('PROBE panel $tag: ${found.length} error(s)');
      for (final d in found) {
        debugPrint('PROBE >>>> ${d.toString()}');
      }
    });
  }
}
