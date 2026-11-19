import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/hilo/hilo_engine.dart';

void main() {
  test('Höher oder Tiefer: ein Tipp, dann aussteigen, bringt etwa 97 %', () {
    final g = HiloGame(rng: Random(1));
    final rng = Random(2);
    var staked = 0, paid = 0;
    for (var i = 0; i < 200000; i++) {
      g.start(100);
      staked += 100;
      // Die bessere Seite wählen, wie die meisten spielen
      final guess = g.chance(HiloGuess.higher) >= g.chance(HiloGuess.lower) ? HiloGuess.higher : HiloGuess.lower;
      g.guess(rng.nextBool() ? guess : guess);
      if (g.phase == HiloPhase.running) paid += g.cashOut();
    }
    final rtp = paid / staked;
    expect(rtp, inInclusiveRange(0.95, 0.975));
  });

  test('Kein kostenloses Aussteigen vor dem ersten Treffer, Grenze nach zehn Treffern', () {
    final g = HiloGame(rng: Random(5));
    g.start(10);
    expect(g.canCashOut, isFalse);
    expect(g.cashOut(), 0);
    var rounds = 0;
    while (rounds < 2000) {
      g.start(10);
      while (g.phase == HiloPhase.running) {
        final h = g.chance(HiloGuess.higher), l = g.chance(HiloGuess.lower);
        g.guess(h >= l ? HiloGuess.higher : HiloGuess.lower);
      }
      if (g.phase == HiloPhase.cashed) {
        expect(g.steps <= hiloMaxSteps, isTrue);
        expect(g.win <= 10 * hiloMaxFactor, isTrue);
        expect(g.cashOut(), g.win);
        return;
      }
      rounds++;
    }
    fail('Nie zehn Treffer geschafft');
  });

  test('Unmögliche Richtung hat Faktor 0', () {
    final g = HiloGame(rng: Random(9));
    for (var i = 0; i < 500; i++) {
      g.start(10);
      final r = g.card!.rank;
      if (r == 14) expect(g.factor100(HiloGuess.higher), 0);
      if (r == 2) expect(g.factor100(HiloGuess.lower), 0);
    }
  });
}
