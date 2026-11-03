// Erzeugt Bilder zur Sichtprüfung. Läuft nur im Build mit --update-goldens.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/blackjack/blackjack_screen.dart';
import 'package:gluckspfennig/games/roulette/roulette_screen.dart';
import 'package:gluckspfennig/games/slots/kosmos_art.dart';
import 'package:gluckspfennig/games/slots/slot_screen.dart';
import 'package:gluckspfennig/games/videopoker/video_poker_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFonts() async {
  for (final entry in {
    'Shrikhand': ['assets/fonts/Shrikhand-Regular.ttf'],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    'Barlow': [
      'assets/fonts/BarlowSemiCondensed-Medium.ttf',
      'assets/fonts/BarlowSemiCondensed-Bold.ttf',
    ],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

class _Sheet extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, Size size) {
    paintKosmosSky(canvas, Offset.zero & size, 0.2);
    final cell = size.width / 4;
    for (var i = 0; i < 8; i++) {
      paintKosmosSymbol(
        canvas,
        Rect.fromLTWH((i % 4) * cell, (i ~/ 4) * cell, cell, cell),
        i,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  const phone = Size(393, 852);
  const landscape = Size(852, 393);
  const desktop = Size(1600, 900);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Size size,
    Brightness b, {
    Widget? screen,
    Future<void> Function()? act,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = b;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true)),
    );
    await tester.pump();
    if (screen != null) {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    if (act != null) {
      await act();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('Bilder', (tester) async {
    await tester.runAsync(loadFonts);
    await shot(tester, 'lobby_dunkel', phone, Brightness.dark);
    await shot(tester, 'lobby_hell', phone, Brightness.light);
    await shot(tester, 'lobby_desktop', desktop, Brightness.dark);
    const games = <String, Widget>{
      'blackjack': BlackjackScreen(),
      'roulette': RouletteScreen(),
      'videopoker': VideoPokerScreen(),
      'slot': SlotScreen(),
    };
    for (final g in games.entries) {
      await shot(tester, '${g.key}_handy', phone, Brightness.dark, screen: g.value);
      await shot(tester, '${g.key}_quer', landscape, Brightness.light, screen: g.value);
      await shot(tester, '${g.key}_desktop', desktop, Brightness.dark, screen: g.value);
    }

    await shot(
      tester,
      'blackjack_spiel',
      phone,
      Brightness.dark,
      screen: const BlackjackScreen(),
      act: () async {
        await tester.tap(find.text('Austeilen: 50'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    await shot(
      tester,
      'roulette_einsatz',
      phone,
      Brightness.dark,
      screen: const RouletteScreen(),
      act: () async {
        await tester.tap(find.text('17'));
        await tester.pump();
        await tester.tap(find.text('Rot'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
    await shot(
      tester,
      'videopoker_spiel',
      phone,
      Brightness.dark,
      screen: const VideoPokerScreen(),
      act: () async {
        await tester.tap(find.text('Karten geben: 50'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
    await shot(
      tester,
      'slot_dreht',
      phone,
      Brightness.dark,
      screen: const SlotScreen(),
      act: () async {
        await tester.tap(find.text('Drehen'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Symbole', (tester) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: CustomPaint(size: const Size(1000, 500), painter: _Sheet()),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/symbole.png'),
    );
  });
}
