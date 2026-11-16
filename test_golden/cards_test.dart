// Bogen mit den gezeichneten Spielkarten zur Sichtprüfung. Läuft nur mit --update-goldens.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/sfx.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/pikdame/pd_engine.dart';
import 'package:gluckspfennig/games/pikdame/pd_screen.dart';
import 'package:gluckspfennig/main.dart';
import 'package:gluckspfennig/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_test.dart' show loadFonts;

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cards) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 8, runSpacing: 8, children: cards),
        );
    return Scaffold(
      backgroundColor: const Color(0xFF2A5A3C),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in Suit.values)
              row([for (var r = 2; r <= 14; r++) PlayingCardView(width: 100, card: PlayingCard(r, s))]),
            row([
              const PdCardView(card: PdCard.joker(104), width: 100),
              const PdCardView(card: PdCard.joker(105), width: 100),
              for (final r in [11, 12, 13]) PlayingCardView(width: 100, card: PlayingCard(r, Suit.hearts), strip: true),
              for (var r = 2; r <= 14; r += 3) PlayingCardView(width: 48, card: PlayingCard(r, Suit.clubs)),
              for (final r in [11, 12, 13, 14]) PlayingCardView(width: 60, card: PlayingCard(r, Suit.diamonds)),
            ]),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Spielkarten', (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(GluckspfennigApp(wallet: Wallet(prefs), sfx: Sfx(prefs, silent: true), settings: Settings(prefs)));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => const _Sheet()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Bilder laden wirklich asynchron, deshalb außerhalb der Testuhr vorladen.
    for (var pass = 0; pass < 3; pass++) {
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate().toList()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/spielkarten.png'));
  });
}
