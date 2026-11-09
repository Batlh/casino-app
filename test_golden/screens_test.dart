// Erzeugt Bilder zur Sichtprüfung. Läuft nur im Build mit --update-goldens.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/chess/chess_screen.dart';
import 'package:gluckspfennig/games/chess/chess_tutorial.dart';
import 'package:gluckspfennig/games/mahjong/mahjong_tutorial.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_screen.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_variants_screen.dart';
import 'package:gluckspfennig/games/mahjong/riichi_screen.dart';
import 'package:gluckspfennig/games/mahjong/solitaire_screen.dart';
import 'package:gluckspfennig/games/pinball/pinball_screen.dart';
import 'package:gluckspfennig/games/shogi/shogi_screen.dart';
import 'package:gluckspfennig/games/shogi/shogi_tutorial.dart';
import 'package:gluckspfennig/ui/guide.dart';
import 'package:gluckspfennig/ui/guides.dart';
import 'package:gluckspfennig/games/blackjack/blackjack_screen.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';
import 'package:gluckspfennig/games/eins/eins_screen.dart';
import 'package:gluckspfennig/games/quatro/quatro_screen.dart';
import 'package:gluckspfennig/games/hearts/hearts_screen.dart';
import 'package:gluckspfennig/games/holdem/holdem_screen.dart';
import 'package:gluckspfennig/games/maumau/maumau_screen.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_screen.dart';
import 'package:gluckspfennig/games/roulette/roulette_screen.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_screen.dart';
import 'package:gluckspfennig/games/solitaire/klondike_screen.dart';
import 'package:gluckspfennig/games/solitaire/spider_screen.dart';
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
    'Kanji': ['assets/fonts/NotoSerifJP-Subset.ttf'],
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
    final games = allSlots;
    final cell = size.width / 8;
    for (var g = 0; g < games.length; g++) {
      final row = Rect.fromLTWH(0, g * cell, size.width, cell);
      games[g].paintBackdrop(canvas, row, 0.2);
      for (var i = 0; i < 8; i++) {
        games[g].paintSymbol(
          canvas,
          Rect.fromLTWH(i * cell, g * cell, cell, cell),
          i,
        );
      }
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
      GluckspfennigApp(
        wallet: Wallet(prefs),
        sfx: Sfx(prefs, silent: true),
        settings: Settings(prefs),
      ),
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
      'slot': SlotScreen(game: kosmos78),
      'tiefsee': SlotScreen(game: tiefsee),
      'garten': SlotScreen(game: schrebergarten),
      'holdem': HoldemScreen(),
      'pachinko': PachinkoScreen(),
      'solitaire': KlondikeScreen(),
      'spider': SpiderScreen(),
      'maumau': MauMauScreen(),
      'eins': EinsScreen(),
      'eins_kehrseite': EinsScreen(mode: EinsMode.flip),
      'eins_werfer': EinsScreen(mode: EinsMode.extreme),
      'eins_kraft': EinsScreen(mode: EinsMode.flex),
      'eins_gluecksrad': EinsScreen(mode: EinsMode.spin),
      'eins_gnadenlos': EinsScreen(mode: EinsMode.noMercy),
      'schwarzedame': HeartsScreen(),
      'viererkette': QuatroScreen(),
      'schach': ChessScreen(),
      'schach_lernen': ChessTutorialScreen(),
      'shogi': ShogiScreen(),
      'shogi_lernen': ShogiTutorialScreen(),
      'mahjong_solitaer': MahjongSolitaireScreen(seed: 3),
      'riichi': RiichiScreen(seed: 5),
      'flipper': PinballScreen(seed: 1),
    };
    for (final g in games.entries) {
      await shot(tester, '${g.key}_handy', phone, Brightness.dark, screen: g.value);
      await shot(tester, '${g.key}_quer', landscape, Brightness.light, screen: g.value);
      await shot(tester, '${g.key}_desktop', desktop, Brightness.dark, screen: g.value);
    }

    final mahjong = <String, Widget>{
      'sichuan': MjScreen(rules: mjRules[MjVariant.sichuanRiver]!, seed: 2),
      'hongkong': MjScreen(rules: mjRules[MjVariant.hongKong]!, seed: 3),
      'taiwan': MjScreen(rules: mjRules[MjVariant.taiwan]!, seed: 4),
      'korea': MjScreen(rules: mjRules[MjVariant.korean]!, seed: 5),
      'mahjong_varianten': const MjVariantsScreen(),
    };
    for (final g in mahjong.entries) {
      await shot(tester, '${g.key}_handy', phone, Brightness.dark, screen: g.value);
      await shot(tester, '${g.key}_quer', landscape, Brightness.light, screen: g.value);
      await shot(tester, '${g.key}_desktop', desktop, Brightness.dark, screen: g.value);
    }

    final extra = <String, Widget>{
      'erklaerung_sichuan': GuideScreen(guide: mjGuideFor(MjVariant.sichuanRiver)),
      'erklaerung_mcr': GuideScreen(guide: mjGuideFor(MjVariant.mcr)),
      'sichuan_lernen': mjTutorialFor(MjVariant.sichuanRiver),
      'singapur_lernen': mjTutorialFor(MjVariant.singapore),
      'erklaerung_schach': GuideScreen(guide: chessGuide),
      'erklaerung_shogi': GuideScreen(guide: shogiGuide),
      'erklaerung_riichi': GuideScreen(guide: riichiGuide),
      'erklaerung_eins': const GuideScreen(guide: einsGuide),
      'erklaerung_flipper': const GuideScreen(guide: pinballGuide),
      'mahjong_lernen': QuizTutorialScreen(title: 'Mahjong lernen', lessons: riichiLessons),
      'mahjong_solitaer_lernen': QuizTutorialScreen(title: 'Mahjong Solitär lernen', lessons: solitaireLessons),
    };
    for (final g in extra.entries) {
      await shot(tester, '${g.key}_handy', phone, Brightness.dark, screen: g.value);
      await shot(tester, '${g.key}_desktop', desktop, Brightness.light, screen: g.value);
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
      screen: const SlotScreen(game: kosmos78),
      act: () async {
        await tester.tap(find.text('Drehen'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
    await shot(
      tester,
      'holdem_tisch',
      phone,
      Brightness.dark,
      screen: const HoldemScreen(),
      act: () async {
        await tester.tap(find.textContaining('Hinsetzen'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Symbole', (tester) async {
    tester.view.physicalSize = const Size(1600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          child: CustomPaint(size: const Size(1600, 600), painter: _Sheet()),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/symbole.png'),
    );
  });
}
