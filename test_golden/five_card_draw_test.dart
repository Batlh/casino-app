// Vorschaubilder Five Card Draw. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/holdem/holdem_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:gluckspfennig/ui/guide.dart';
import 'package:gluckspfennig/ui/guides.dart';
import 'package:gluckspfennig/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> start(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  bool enabled(WidgetTester tester, Finder f) {
    if (f.evaluate().isEmpty) return false;
    final b = tester.widget<ActionButton>(find.ancestor(of: f.first, matching: find.byType(ActionButton)).first);
    return b.onPressed != null;
  }

  for (final (name, size) in [('handy', const Size(393, 852)), ('quer', const Size(852, 393))]) {
    testWidgets('Five Card Draw $name', (tester) async {
      await tester.runAsync(loadFonts);
      await start(tester, size, const HoldemScreen(draw: true));
      await snap('draw_lobby_$name');
      await tester.ensureVisible(find.textContaining('Hinsetzen'));
      await tester.pump();
      await tester.tap(find.textContaining('Hinsetzen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await snap('draw_runde1_$name');
      var swapped = false;
      for (var i = 0; i < 400; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        if (enabled(tester, find.text('Alle behalten'))) {
          // Zwei Karten zum Tauschen markieren
          await tester.tap(find.byKey(const ValueKey('hand-0')));
          await tester.tap(find.byKey(const ValueKey('hand-2')));
          await tester.pump(const Duration(milliseconds: 300));
          await snap('draw_tauschen_$name');
          await tester.tap(find.textContaining('Tauschen:'));
          await tester.pump(const Duration(milliseconds: 400));
          await snap('draw_getauscht_$name');
          swapped = true;
          continue;
        }
        for (final label in ['Schieben', 'Mitgehen']) {
          final f = find.textContaining(label);
          if (enabled(tester, f)) {
            await tester.tap(f.first);
            await tester.pump();
            break;
          }
        }
        if (find.text('Nächste Hand').evaluate().isNotEmpty) {
          if (swapped) break;
          await tester.tap(find.text('Nächste Hand'));
          await tester.pump();
        }
      }
      await tester.pump(const Duration(milliseconds: 400));
      await snap('draw_aufgedeckt_$name');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('Five Card Draw Erklärung', (tester) async {
    await tester.runAsync(loadFonts);
    await start(tester, const Size(393, 852), const GuideScreen(guide: fiveCardDrawGuide));
    await snap('draw_erklaerung');
  });
}
