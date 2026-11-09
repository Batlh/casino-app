import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/pikdame/pd_engine.dart';

var _id = 1000;
PdCard c(int r, Suit s) => PdCard(r, s, _id++);
PdCard j() => PdCard.joker(_id++);

void main() {
  test('Sätze und Folgen', () {
    expect(pdBuildMeld([c(7, Suit.hearts), c(7, Suit.spades), c(7, Suit.clubs)], 0)?.run, isFalse);
    expect(pdBuildMeld([c(7, Suit.hearts), c(7, Suit.hearts), c(7, Suit.clubs)], 0), isNull, reason: 'gleiche Farbe doppelt');
    expect(pdBuildMeld([c(5, Suit.hearts), c(6, Suit.hearts), c(7, Suit.hearts)], 0)?.run, isTrue);
    expect(pdBuildMeld([c(5, Suit.hearts), c(6, Suit.clubs), c(7, Suit.hearts)], 0), isNull);
    expect(pdBuildMeld([c(14, Suit.hearts), c(2, Suit.hearts), c(3, Suit.hearts)], 0), isNotNull, reason: 'Ass tief');
    expect(pdBuildMeld([c(12, Suit.hearts), c(13, Suit.hearts), c(14, Suit.hearts)], 0), isNotNull, reason: 'Ass hoch');
    expect(pdBuildMeld([c(13, Suit.hearts), c(14, Suit.hearts), c(2, Suit.hearts)], 0), isNull, reason: 'kein Rundlauf');
    expect(pdBuildMeld([c(5, Suit.hearts), j(), c(7, Suit.hearts)], 0), isNotNull, reason: 'Joker in der Lücke');
    expect(pdBuildMeld([c(5, Suit.hearts), j(), j()], 0), isNull, reason: 'höchstens ein Joker');
  });

  test('Joker tauschen', () {
    final joker = j();
    final m = pdBuildMeld([c(5, Suit.hearts), joker, c(7, Suit.hearts)], 0)!;
    expect(pdCanSwapJoker(m, c(6, Suit.hearts)), isTrue);
    expect(pdCanSwapJoker(m, c(6, Suit.clubs)), isFalse);
  });

  test('Werte', () {
    const a = PdOptions();
    const b = PdOptions(aceHigh: true);
    expect(pdValue(c(12, Suit.spades), a), 100);
    expect(pdValue(c(14, Suit.hearts), a), 15);
    expect(pdValue(c(14, Suit.hearts), b), 20);
    expect(pdValue(j(), a), 20);
    expect(pdValue(j(), b), 15);
    expect(pdValue(c(9, Suit.hearts), a), 5);
    expect(pdValue(c(10, Suit.hearts), a), 10);
  });

  for (final players in [2, 3, 4]) {
    test('Ganze Partien mit $players Spielern', () {
      for (var seed = 0; seed < 3; seed++) {
        final rng = Random(seed);
        final g = PdGame(PdOptions(players: players, target: 500, firstMeld50: seed != 1, aceHigh: seed == 2), rng: Random(seed + 50))
          ..start();
        var turns = 0;
        var rounds = 0;
        while (g.phase != PdPhase.gameOver && turns < 30000) {
          if (g.phase == PdPhase.roundOver) {
            rounds++;
            g.nextRound();
            continue;
          }
          final before = g.current;
          pdBotTurn(g, g.current, rng);
          turns++;
          // Kartenzahl bleibt 110
          if (g.phase == PdPhase.draw) {
            final total = g.stack.length +
                g.pile.length +
                g.players.fold(0, (a, p) => a + p.hand.length) +
                g.melds.fold(0, (a, m) => a + m.cards.length);
            expect(total, 110, reason: 'Zug $turns');
            expect(g.current, isNot(before), reason: 'Zug endet nicht');
          }
        }
        expect(g.phase, PdPhase.gameOver, reason: 'Seed $seed endet nicht');
        // ignore: avoid_print
        print('Pik Dame $players Spieler, Seed $seed: $rounds Runden, $turns Züge, ${g.players.map((p) => p.score).join('/')}');
      }
    });
  }
}
