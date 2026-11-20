// Vorschaubilder neue Casinospiele. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/arcade/arcade_screen.dart';
import 'package:gluckspfennig/games/hilo/hilo_screen.dart';
import 'package:gluckspfennig/games/pachislo/pachislo_screen.dart';
import 'package:gluckspfennig/games/pusher/pusher_screen.dart';
import 'package:gluckspfennig/games/roulette/roulette_screen.dart';
import 'package:gluckspfennig/games/threecard/three_card_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:gluckspfennig/ui/progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

void main() {
  Future<void> open(WidgetTester tester, Widget screen, {Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(p), sfx: Sfx(p, silent: true), settings: Settings(p)));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => screen));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> snap(String name) => expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

  testWidgets('Goldene Sieben', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const ArcadeScreen(seed: 2));
    await snap('neu_spielhalle_start');
    for (var k = 0; k < 12; k++) {
      await tester.tap(find.textContaining('Drehen').first);
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (find.textContaining('Annehmen').evaluate().isNotEmpty) break;
    }
    await snap('neu_spielhalle_gedreht');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Pachislo', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const PachisloScreen(seed: 5));
    await snap('neu_pachislo_start');
    await tester.tap(find.textContaining('Hebel:'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_pachislo_laeuft');
    for (var r = 0; r < 3; r++) {
      await tester.tapAt(tester.getCenter(find.text('STOPP').at(r)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_pachislo_gestoppt');
    // Mit leuchtender Glückslampe
    await open(tester, const PachisloScreen(seed: 6), prefs: {'save.pachislo': '{"held":"big","coin":2}'});
    await snap('neu_pachislo_lampe');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Münzschieber', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const PusherScreen(seed: 3));
    await snap('neu_schieber_start');
    for (var k = 0; k < 6; k++) {
      await tester.tap(find.textContaining('Einwerfen'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_schieber_laeuft');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Höher oder Tiefer', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const HiloScreen(seed: 3));
    await tester.tap(find.textContaining('Erste Karte'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_hilo');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Three Card Poker', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const ThreeCardScreen(seed: 3));
    await tester.tap(find.textContaining('Austeilen'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_threecard');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Roulette amerikanisch', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const RouletteScreen(), prefs: {'save.roulette': '{"variant":"american"}'});
    await snap('neu_roulette_amerikanisch');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Erfolge und Aufgaben', (tester) async {
    await tester.runAsync(loadFonts);
    await open(tester, const ProgressScreen());
    await snap('neu_aufgaben');
    await tester.tap(find.text('Erfolge'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await snap('neu_erfolge');
  });
}
