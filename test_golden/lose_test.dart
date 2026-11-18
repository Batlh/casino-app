// Vorschaubilder Rubbellose und Pull-Tabs. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/lose/lose_screens.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> start(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(393, 852);
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

  testWidgets('Rubbellose', (tester) async {
    await tester.runAsync(loadFonts);
    await start(tester, const RubbelScreen(seed: 11));
    await snap('rubbel_start');
    for (final (i, name) in ['Glücksklee', 'Goldrausch', 'Diamantfieber'].indexed) {
      await tester.tap(find.textContaining(name).first);
      await tester.pump();
      await tester.tap(find.textContaining('Los kaufen:'));
      await tester.pump();
      // Ein Stück freirubbeln
      final area = tester.getCenter(find.byType(CustomPaint).last);
      await tester.dragFrom(area - const Offset(120, 40), const Offset(240, 60));
      await tester.pump();
      await snap('rubbel_${i}_halb');
      await tester.tap(find.text('Alles aufrubbeln'));
      await tester.pump(const Duration(milliseconds: 300));
      await snap('rubbel_${i}_offen');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Pull-Tabs', (tester) async {
    await tester.runAsync(loadFonts);
    await start(tester, const PullTabScreen(seed: 5));
    for (final (i, name) in ['Kirsch-Tabs', 'Glocken-Tabs', 'Goldbarren-Tabs'].indexed) {
      await tester.tap(find.textContaining(name).first);
      await tester.pump();
      await tester.tap(find.textContaining('Los kaufen:'));
      await tester.pump();
      await snap('pull_${i}_neu');
      await tester.tap(find.textContaining('AUFREISSEN').first);
      await tester.pump(const Duration(milliseconds: 400));
      await snap('pull_${i}_eins');
      await tester.tap(find.text('Alle aufreißen'));
      await tester.pump(const Duration(milliseconds: 400));
      await snap('pull_${i}_offen');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });
}
