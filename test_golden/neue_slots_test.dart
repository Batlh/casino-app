// Vorschaubilder der neuen Slots und ihrer Funktionen. Läuft nur mit --update-goldens.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

final _games = [tiefsee, edelsteinmine, drachenhort, jahrmarkt, vulkaninsel];
const _ids = ['tiefsee', 'mine', 'drachen', 'jahrmarkt', 'vulkan'];

class _Sheet extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, Size size) {
    final cell = size.width / 10;
    for (var g = 0; g < _games.length; g++) {
      _games[g].paintBackdrop(canvas, Rect.fromLTWH(0, g * cell, size.width, cell), 0.2);
      for (var i = 0; i < 10; i++) {
        if (i >= _games[g].symbolNames.length) continue;
        _games[g].paintSymbol(canvas, Rect.fromLTWH(i * cell, g * cell, cell, cell), i);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Erster Startwert, bei dem die erste Drehung die Bedingung erfüllt.
int _seedFor(SlotGame game, bool Function(SpinOutcome) want) {
  final stake = game.stakes[2];
  for (var seed = 1; seed < 200000; seed++) {
    if (want(SlotEngine(game.rules, rng: Random(seed)).play(stake))) return seed;
  }
  throw StateError('kein Startwert für ${game.name}');
}

void main() {
  const phone = Size(393, 852);

  Future<void> start(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = phone;
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

  Future<void> spin(WidgetTester tester) async {
    await tester.tap(find.text('Drehen').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('Symbole neue Slots', (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(Center(child: RepaintBoundary(child: CustomPaint(size: const Size(1600, 800), painter: _Sheet()))));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/symbole_neu.png'));
  });

  testWidgets('Ruhebilder', (tester) async {
    await tester.runAsync(loadFonts);
    for (var i = 0; i < _games.length; i++) {
      await start(tester, SlotScreen(game: _games[i]));
      await snap('slot_${_ids[i]}');
    }
    await finish(tester);
  });

  testWidgets('Tiefsee: Wege überall', (tester) async {
    await tester.runAsync(loadFonts);
    final seed = _seedFor(tiefsee, (o) => o.steps.first.wins.any((w) => w.start > 0) && o.steps.first.wins.length >= 2);
    await start(tester, SlotScreen(game: tiefsee, seed: seed));
    await spin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await snap('tiefsee_wege');
    await finish(tester);
  });

  testWidgets('Edelsteinmine: Kaskaden', (tester) async {
    await tester.runAsync(loadFonts);
    final seed = _seedFor(edelsteinmine, (o) => o.steps.length >= 3);
    await start(tester, SlotScreen(game: edelsteinmine, seed: seed));
    await spin(tester);
    await snap('mine_kaskade_1');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 200));
    await snap('mine_kaskade_2_fallen');
    await tester.pump(const Duration(milliseconds: 400));
    await snap('mine_kaskade_2');
    await finish(tester);
  });

  testWidgets('Vulkaninsel: wechselnde Höhen und Kaskaden', (tester) async {
    await tester.runAsync(loadFonts);
    final seed = _seedFor(vulkaninsel, (o) => o.steps.length >= 3);
    await start(tester, SlotScreen(game: vulkaninsel, seed: seed));
    await spin(tester);
    await snap('vulkan_kaskade_1');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 500));
    await snap('vulkan_kaskade_2');
    await finish(tester);
  });

  testWidgets('Drachenhort: Hold & Spin', (tester) async {
    await tester.runAsync(loadFonts);
    final seed = _seedFor(drachenhort, (o) => o.holdSpin != null && o.holdSpin!.boards.length >= 3);
    await start(tester, SlotScreen(game: drachenhort, seed: seed));
    await spin(tester);
    await snap('drachen_muenzen');
    await tester.pump(const Duration(milliseconds: 1300));
    await snap('drachen_hold_start');
    await tester.pump(const Duration(milliseconds: 1500));
    await snap('drachen_hold_respin');
    await finish(tester);
  });

  testWidgets('Jahrmarkt: Glücksrad', (tester) async {
    await tester.runAsync(loadFonts);
    final seed = _seedFor(jahrmarkt, (o) => o.wheel != null);
    await start(tester, SlotScreen(game: jahrmarkt, seed: seed));
    await spin(tester);
    await snap('jahrmarkt_bonus');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 500));
    await snap('gluecksrad_start');
    await tester.tap(find.text('Drehen').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await snap('gluecksrad_dreht');
    await tester.pump(const Duration(milliseconds: 3200));
    await snap('gluecksrad_ergebnis');
    await finish(tester);
  });

  testWidgets('Gewinnpläne', (tester) async {
    await tester.runAsync(loadFonts);
    final plans = [..._games, kosmos78, schrebergarten];
    const planIds = [..._ids, 'kosmos', 'garten'];
    for (var i = 0; i < plans.length; i++) {
      final g = plans[i];
      await start(tester, SlotScreen(game: g));
      showSlotPayTable(tester.element(find.byType(Navigator).first), g, g.stakes[2]);
      await tester.pump(const Duration(milliseconds: 600));
      await snap('gewinnplan_${planIds[i]}_1');
      final pos = tester
          .state<ScrollableState>(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first)
          .position;
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 300));
      await snap('gewinnplan_${planIds[i]}_2');
    }
    await finish(tester);
  });
}
