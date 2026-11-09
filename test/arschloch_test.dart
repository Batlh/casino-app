import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/arschloch/ah_engine.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';

void main() {
  test('Nur höhere Karten in gleicher Anzahl', () {
    final g = AhGame(rng: Random(1))..start();
    final p = g.current;
    final hand = g.players[p].hand;
    final low = hand.first;
    g.play(p, [low]);
    final q = g.current;
    final lower = g.players[q].hand.where((c) => c.rank <= low.rank).toList();
    if (lower.isNotEmpty) expect(g.canPlay(q, [lower.first]), isFalse);
    final two = g.players[q].hand.where((c) => c.rank > low.rank).take(2).toList();
    if (two.length == 2 && two[0].rank == two[1].rank) expect(g.canPlay(q, two), isFalse);
  });

  test('Ganze Spiele laufen durch, mit Tausch', () {
    for (var seed = 0; seed < 5; seed++) {
      final g = AhGame(rng: Random(seed))..start();
      var steps = 0;
      while (g.phase != AhPhase.gameOver && steps < 5000) {
        steps++;
        switch (g.phase) {
          case AhPhase.exchange:
            g.humanGiveBack(sortAh(g.players[0].hand).take(g.humanGives).toList());
          case AhPhase.roundOver:
            g.nextRound();
          case AhPhase.play:
            final p = g.current;
            final m = ahBotMove(g, p);
            if (m == null) {
              if (g.leading) fail('Ausspielen ohne Zug');
              g.pass(p);
            } else {
              g.play(p, m);
            }
            final cards = g.players.fold(0, (a, pl) => a + pl.hand.length);
            expect(cards, lessThanOrEqualTo(32));
          case AhPhase.gameOver:
            break;
        }
      }
      expect(g.phase, AhPhase.gameOver);
      expect(g.players.fold(0, (a, p) => a + p.points), 6 * 6);
      expect(g.players.where((p) => p.title == 0).length, 1);
    }
  });

  test('Kreuz 7 fängt an', () {
    final g = AhGame(rng: Random(4))..start();
    expect(g.players[g.current].hand, contains(const PlayingCard(7, Suit.clubs)));
  });
}
