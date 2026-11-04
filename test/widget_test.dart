import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/blackjack/blackjack_screen.dart';
import 'package:gluckspfennig/games/holdem/holdem_screen.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_screen.dart';
import 'package:gluckspfennig/games/roulette/roulette_screen.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_screen.dart';
import 'package:gluckspfennig/games/videopoker/video_poker_screen.dart';
import 'package:gluckspfennig/main.dart';
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
        HoldemScreen(),
        PachinkoScreen(),
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

  testWidgets('Black Jack lässt sich austeilen', (tester) async {
    await pumpApp(tester, const Size(393, 852), screen: const BlackjackScreen());
    await tester.tap(find.textContaining('Austeilen'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
