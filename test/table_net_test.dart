import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/blackjack/blackjack_engine.dart';
import 'package:gluckspfennig/games/memory/memory_engine.dart';

void main() {
  test('Black Jack am Netztisch: Geber hat bei allen dieselben Karten', () {
    for (var seed = 1; seed <= 40; seed++) {
      final a = BlackjackEngine(rng: Random(seed * 3));
      final b = BlackjackEngine(rng: Random(seed * 5 + 1));
      a.deal(10, dealerCards: bjDealerCards(seed));
      b.deal(10, dealerCards: bjDealerCards(seed));
      expect(b.dealer, a.dealer);
      // Unterschiedlich viele eigene Karten ändern die Geberhand nicht
      while (a.phase == BjPhase.playerTurn) {
        a.hit();
      }
      if (b.phase == BjPhase.playerTurn) b.stand();
      while (a.dealerStep()) {}
      while (b.dealerStep()) {}
      if (a.hands.any((h) => !h.busted) && b.hands.any((h) => !h.busted)) {
        expect(b.dealer.map((c) => '${c.rank}${c.suit}'), a.dealer.map((c) => '${c.rank}${c.suit}'));
      }
    }
  });

  test('Memory im Netz: gleicher Startwert, gleiches Feld', () {
    final a = MemoryGame(12, 3, rng: Random(42));
    final b = MemoryGame(12, 3, rng: Random(42));
    expect(b.cards, a.cards);
    for (final i in [0, 1, 2, 3]) {
      a.flip(i);
      b.flip(i);
      if (a.waiting) {
        expect(b.resolve(), a.resolve());
      }
    }
    expect(b.current, a.current);
    expect(b.scores, a.scores);
  });
}
