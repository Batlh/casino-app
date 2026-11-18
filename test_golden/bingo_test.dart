// Vorschaubilder Bingo. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/bingo/bingo_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> start(WidgetTester tester, Size size) async {
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
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const BingoScreen(seed: 3)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  Future<void> balls(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
  }

  for (final (name, size) in [('handy', const Size(393, 852)), ('quer', const Size(852, 393))]) {
    testWidgets('Bingo $name', (tester) async {
      await tester.runAsync(loadFonts);
      await start(tester, size);
      await snap('bingo_einstellungen_$name');
      await tester.ensureVisible(find.textContaining('Allein spielen:'));
      await tester.tap(find.textContaining('Allein spielen:'));
      await tester.pump();
      await balls(tester, 25);
      await snap('bingo75_mitte_$name');
      await balls(tester, 60);
      await tester.pump(const Duration(milliseconds: 300));
      await snap('bingo75_ende_$name');
      await tester.tap(find.text('Einstellungen'));
      await tester.pump();
      await tester.tap(find.text('90 Kugeln (UK)'));
      await tester.pump();
      await tester.ensureVisible(find.textContaining('Allein spielen:'));
      await tester.tap(find.textContaining('Allein spielen:'));
      await tester.pump();
      await balls(tester, 35);
      await snap('bingo90_mitte_$name');
      await balls(tester, 60);
      await tester.pump(const Duration(milliseconds: 300));
      await snap('bingo90_ende_$name');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
