import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/bingo/bingo_screen.dart';
import 'package:gluckspfennig/games/ente/ente_screen.dart';
import 'package:gluckspfennig/games/gluecksrad/gluecksrad_screen.dart';
import 'package:gluckspfennig/games/lose/lose_screens.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
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
import 'package:gluckspfennig/ui/widgets.dart';
import 'package:gluckspfennig/ui/help_screen.dart';
import 'package:gluckspfennig/games/arcade/arcade_screen.dart';
import 'package:gluckspfennig/games/hilo/hilo_screen.dart';
import 'package:gluckspfennig/games/claw/claw_screen.dart';
import 'package:gluckspfennig/games/pachislo/pachislo_screen.dart';
import 'package:gluckspfennig/games/pusher/pusher_screen.dart';
import 'package:gluckspfennig/games/threecard/three_card_screen.dart';
import 'package:gluckspfennig/ui/progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sizes = <String, Size>{
  'Handy klein': Size(320, 568),
  'Handy': Size(393, 852),
  'Handy quer': Size(852, 393),
  'Tablet': Size(800, 1280),
  'Desktop': Size(1920, 1080),
};

Future<void> pumpApp(WidgetTester tester, Size size, {Widget? screen}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  sizes.forEach((name, size) {
    testWidgets('Kein Layoutfehler: $name', (tester) async {
      await pumpApp(tester, size);
      expect(find.text('Glückspfennig'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final screen in const <Widget>[
        BlackjackScreen(),
        RouletteScreen(),
        VideoPokerScreen(),
        SlotScreen(game: kosmos78),
        SlotScreen(game: tiefsee),
        SlotScreen(game: schrebergarten),
        SlotScreen(game: edelsteinmine),
        SlotScreen(game: drachenhort),
        SlotScreen(game: jahrmarkt),
        SlotScreen(game: vulkaninsel),
        SlotScreen(game: sakura),
        SlotScreen(game: jadetempel),
        SlotScreen(game: fruechtekorb),
        SlotScreen(game: fruchtlawine),
        SlotScreen(game: pharaonengold),
        SlotScreen(game: zauberbibliothek),
        SlotScreen(game: bonbonfabrik),
        SlotScreen(game: goldgraeber),
        SlotScreen(game: runenpfad),
        HoldemScreen(),
        HoldemScreen(draw: true),
        BingoScreen(),
        EntenScreen(),
        GluecksradScreen(),
        RubbelScreen(),
        PullTabScreen(),
        PachinkoScreen(),
        KlondikeScreen(),
        SpiderScreen(),
        MauMauScreen(),
        EinsScreen(),
        EinsScreen(mode: EinsMode.flip),
        EinsScreen(mode: EinsMode.extreme),
        EinsScreen(mode: EinsMode.flex),
        HeartsScreen(),
        QuatroScreen(),
        HelpScreen(),
        HiloScreen(seed: 1),
        ArcadeScreen(seed: 1),
        ThreeCardScreen(seed: 1),
        PachisloScreen(seed: 1),
        PusherScreen(seed: 1),
        ClawScreen(seed: 1),
        ProgressScreen(),
      ]) {
        await pumpApp(tester, size, screen: screen);
        expect(tester.takeException(), isNull, reason: '$screen bei $name');
      }
    });
  });

  sizes.forEach((name, size) {
    testWidgets("Texas Hold'em Tisch ohne Layoutfehler: $name", (tester) async {
      await pumpApp(tester, size, screen: const HoldemScreen());
      await tester.tap(find.textContaining('Hinsetzen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  for (final scale in [0.8, 1.6]) {
    sizes.forEach((name, size) {
      testWidgets('Kartengröße ${(scale * 100).round()} %: $name', (tester) async {
        SharedPreferences.setMockInitialValues({'settings.cardScale': scale});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final prefs = await SharedPreferences.getInstance();
        for (final screen in const <Widget>[
          KlondikeScreen(),
          SpiderScreen(),
          MauMauScreen(),
          EinsScreen(),
          HeartsScreen(),
        ]) {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            GluckspfennigApp(
              wallet: Wallet(prefs),
              sfx: Sfx(prefs, silent: true),
              settings: Settings(prefs),
            ),
          );
          await tester.pump();
          tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .push(MaterialPageRoute<void>(builder: (_) => screen));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$screen');
        }
      });
    });
  }

  testWidgets('Schwarze Dame: weitergeben und spielen ohne Fehler', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const HeartsScreen());
    final cards = find.byType(PlayingCardView);
    final count = tester.widgetList(cards).length;
    expect(count, greaterThanOrEqualTo(13));
    for (var i = 0; i < 3; i++) {
      // Links oben antippen, dort liegt keine Nachbarkarte darüber
      await tester.tapAt(tester.getTopLeft(cards.at(count - 1 - i)) + const Offset(6, 30));
      await tester.pump();
    }
    expect(find.text('Drei Karten nach links weitergeben (3 von 3)'), findsOneWidget);
    await tester.tap(find.text('Weitergeben'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Mau Mau: ziehen und Gegner spielen lassen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const MauMauScreen());
    await tester.tap(find.text('Ziehen'));
    await tester.pump();
    if (find.text('Behalten').evaluate().isNotEmpty) {
      await tester.tap(find.text('Behalten'));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Eins!: ziehen und Gegner spielen lassen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const EinsScreen());
    await tester.tap(find.text('Ziehen'));
    await tester.pump();
    if (find.text('Behalten').evaluate().isNotEmpty) {
      await tester.tap(find.text('Behalten'));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  for (final mode in EinsMode.values) {
    for (final size in const [Size(393, 852), Size(852, 393)]) {
      testWidgets('Eins! ${modeName(mode)} ${size.width.round()}: Computer spielen mit', (tester) async {
        await pumpApp(tester, size, screen: EinsScreen(mode: mode));
        final label = find.text(mode == EinsMode.extreme ? 'Drücken' : 'Ziehen');
        if (label.evaluate().isNotEmpty) {
          await tester.tap(label.first);
          await tester.pump();
        }
        if (find.text('Behalten').evaluate().isNotEmpty) {
          await tester.tap(find.text('Behalten'));
          await tester.pump();
        }
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }

  testWidgets('Viererkette: Stein legen und Gegner spielen lassen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const QuatroScreen());
    for (var c = 0; c < 7; c++) {
      await tester.tap(find.bySemanticsLabel('Spalte ${c + 1}'), warnIfMissed: false);
      await tester.pump();
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Solitaire: Stapel ziehen und Karten antippen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const KlondikeScreen());
    for (var i = 0; i < 5; i++) {
      final cards = find.byType(PlayingCardView);
      await tester.tap(cards.first, warnIfMissed: false);
      await tester.pump();
      await tester.tap(cards.last, warnIfMissed: false);
      await tester.pump();
    }
    await tester.tap(find.text('Rückgängig'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Black Jack lässt sich austeilen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const BlackjackScreen());
    await tester.tap(find.textContaining('Austeilen'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
