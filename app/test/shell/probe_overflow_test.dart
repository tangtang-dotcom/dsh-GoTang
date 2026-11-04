// Temporary probe (removed with probe.yml): dumps the widget chain behind a
// RenderFlex overflow at 320 dp / 1.3x in English.
import 'package:dsh_app/state/adaptive_layout_state.dart';
import 'package:dsh_app/ui/chat/chat_screen.dart';
import 'package:dsh_app/ui/settings/quick_panel_items_sheet.dart';
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

  Future<void> home(WidgetTester tester) async {
    useEnglish();
    SharedPreferences.setMockInitialValues({});
    useWindow(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    mockClipboard(tester);
    final shell = HomeShell(chatBuilder: (openDrawer) => ChatScreen(onOpenDrawer: openDrawer, backdrop: false));
    await tester.pumpWidget(
      testApp(inEnglish(shell), overrides: homeOverrides(prefs: const LayoutPrefs(loaded: true))),
    );
    await pumpFrames(tester, 10);
  }

  void report(String where, List<FlutterErrorDetails> found) {
    debugPrint('PROBE $where: ${found.length} error(s)');
    for (final d in found) {
      debugPrint('PROBE >>>> ${d.toString()}');
    }
  }

  testWidgets('probe en chat', (tester) async {
    report('chat', await capture(tester, () => home(tester)));
  });

  testWidgets('probe en sheet', (tester) async {
    await home(tester);
    report('sheet', await capture(tester, () async {
      showQuickPanelItems(tester.element(find.byType(HomeShell)));
      await pumpFrames(tester, 10);
    }));
  });
}
