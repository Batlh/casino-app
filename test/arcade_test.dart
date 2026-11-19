import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/arcade/arcade_engine.dart';

void main() {
  test('Goldene Sieben: Quote nach der Hilfe etwa 96 %', () {
    final m = ArcadeMachine(rng: Random(4))..bet = 1;
    var staked = 0, paid = 0;
    for (var i = 0; i < 1500000; i++) {
      if (m.freeSpins == 0) staked += 1;
      var win = m.spin();
      if (m.offer == ArcadeOffer.nudge) {
        final s = m.suggestNudge();
        if (s != null) win = m.nudge(s.$1, s.$2);
      } else if (m.offer == ArcadeOffer.hold) {
        m.held.addAll(m.suggestHold());
      }
      paid += win;
    }
    expect(paid / staked, inInclusiveRange(0.945, 0.975));
  });

  test('Gewinnlinie und Sonderspiele', () {
    expect(arcadeLinePay([7, 7, 7]), 100);
    expect(arcadeLinePay([0, 0, 5]), arcadeTwoCherries);
    expect(arcadeLinePay([0, 3, 5]), arcadeOneCherry);
    expect(arcadeLinePay([3, 0, 0]), 0);
    expect(arcadeLinePay([arcadeStar, arcadeStar, arcadeStar]), 0);
    expect(arcadeStars([arcadeStar, arcadeStar, arcadeStar]), isTrue);
    final m = ArcadeMachine(rng: Random(1));
    // Stellung mit drei Sternen suchen und prüfen, dass Sonderspiele kommen
    m.pos = [for (var r = 0; r < 3; r++) arcadeStrips[r].indexOf(arcadeStar)];
    m.held.addAll([0, 1, 2]);
    m.spin();
    expect(m.freeSpins, arcadeFreeSpins);
    expect(m.offer, ArcadeOffer.none);
  });

  test('Walzen enthalten jedes Symbol', () {
    for (final s in arcadeStrips) {
      for (var i = 0; i < arcadeSymbols.length; i++) {
        expect(s.contains(i), isTrue);
      }
    }
  });
}
