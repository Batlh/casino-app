import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/hand_eval.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/holdem/holdem_engine.dart';

PlayingCard c(int r, Suit s) => PlayingCard(r, s);

void main() {
  test('Omaha: genau zwei Handkarten zählen', () {
    final board = [c(2, Suit.hearts), c(5, Suit.hearts), c(9, Suit.hearts), c(13, Suit.hearts), c(3, Suit.clubs)];
    // Nur ein Herz auf der Hand: kein Flush
    final one = bestOmaha([c(14, Suit.hearts), c(14, Suit.spades), c(7, Suit.clubs), c(8, Suit.diamonds)], board);
    expect(one.category, isNot(HandCategory.flush));
    // Zwei Herz: Flush
    final two = bestOmaha([c(14, Suit.hearts), c(10, Suit.hearts), c(7, Suit.clubs), c(8, Suit.diamonds)], board);
    expect(two.category, HandCategory.flush);
  });

  test('Omaha-Hände laufen mit Computern durch', () {
    final rng = Random(3);
    final players = [for (var i = 0; i < 4; i++) HoldemPlayer('P$i', 1000)];
    final e = HoldemEngine(players: players, smallBlind: 5, bigBlind: 10, rng: Random(1), omaha: true);
    for (var hand = 0; hand < 10; hand++) {
      if (players.where((p) => p.stack > 0).length < 2) break;
      e.startHand();
      expect(players.where((p) => p.inHand).every((p) => p.hole.length == 4), isTrue);
      var guard = 0;
      while (!e.handOver && guard++ < 200) {
        e.apply(botDecide(e, rng));
      }
      expect(e.handOver, isTrue);
      expect(players.fold(0, (a, p) => a + p.stack), 4000);
    }
  });
}
