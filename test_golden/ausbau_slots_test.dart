// Vorschaubilder der Automaten aus dem Ausbau. Läuft nur mit --update-goldens.
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

final _games = [zauberbibliothek, bonbonfabrik, goldgraeber];

class _Sheet extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, Size size) {
    final cell = size.width / 11;
    for (var g = 0; g < _games.length; g++) {
      _games[g].paintBackdrop(canvas, Rect.fromLTWH(0, g * cell, size.width, cell), 0.2);
      final names = _games[g].symbolNames;
      final syms = [for (var i = 0; i < names.length; i++) if (names[i].isNotEmpty) i];
      for (var k = 0; k < syms.length; k++) {
        _games[g].paintSymbol(canvas, Rect.fromLTWH(k * cell, g * cell, cell, cell), syms[k]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  /// Pumpt, bis ein Text erscheint (höchstens etwa eine Minute Spielzeit).
  Future<void> until(WidgetTester tester, String text) async {
    for (var i = 0; i < 600 && find.textContaining(text).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining(text), findsWidgets);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('Symbole Ausbau', (tester) async {
    tester.view.physicalSize = const Size(1650, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadFonts);
    await tester.pumpWidget(Center(child: RepaintBoundary(child: CustomPaint(size: const Size(1650, 450), painter: _Sheet()))));
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/symbole_ausbau.png'));
  });

  testWidgets('Zauberbibliothek: Buch-Freispiele', (tester) async {
    await tester.runAsync(loadFonts);
    final game = zauberbibliothek;
    final stake = game.stakes[2];
    // Erste Drehung startet Freispiele, das erste Freispiel breitet das Sondersymbol aus
    var seed = 1;
    for (; seed < 400000; seed++) {
      final e = SlotEngine(game.rules, rng: Random(seed));
      if (e.play(stake).freeSpinsWon == 0) continue;
      if (e.play(stake, free: true).steps.last.expanded) break;
    }
    await start(tester, SlotScreen(game: game));
    await snap('buch_ruhe');
    await start(tester, SlotScreen(game: game, seed: seed));
    await spin(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await snap('buch_ausloeser');
    await until(tester, 'Ausgebreitet');
    await tester.pump(const Duration(milliseconds: 500));
    await snap('buch_ausgebreitet');
    await finish(tester);
  });

  testWidgets('Bonbonfabrik: Gruppen und Kaskaden', (tester) async {
    await tester.runAsync(loadFonts);
    final game = bonbonfabrik;
    var seed = 1;
    while (SlotEngine(game.rules, rng: Random(seed)).play(game.stakes[2]).steps.length < 3) {
      seed++;
    }
    await start(tester, SlotScreen(game: game));
    await snap('bonbon_ruhe');
    await start(tester, SlotScreen(game: game, seed: seed));
    await spin(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await snap('bonbon_gruppe');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 500));
    await snap('bonbon_kaskade');
    await finish(tester);
  });

  testWidgets('Goldgräber: wandernde Joker und Riesensymbol', (tester) async {
    await tester.runAsync(loadFonts);
    final game = goldgraeber;
    final stake = game.stakes[2];
    var seed = 1;
    while (SlotEngine(game.rules, rng: Random(seed)).play(stake).steps.where((s) => s.respin).length < 2) {
      seed++;
    }
    await start(tester, SlotScreen(game: game, seed: seed));
    await spin(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await snap('gold_joker');
    await until(tester, 'Nachdrehung 1');
    await tester.pump(const Duration(milliseconds: 450));
    await snap('gold_nachdrehung');
    // Erste Drehung startet Freispiele: Riesensymbol
    var free = 1;
    for (; free < 400000; free++) {
      if (SlotEngine(game.rules, rng: Random(free)).play(stake).freeSpinsWon > 0) break;
    }
    await start(tester, SlotScreen(game: game, seed: free));
    await spin(tester);
    await until(tester, 'Noch 7 Freispiele');
    await tester.pump(const Duration(milliseconds: 2400));
    await snap('gold_riese');
    await finish(tester);
  });
}
