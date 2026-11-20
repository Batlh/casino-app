import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/horses/horse_engine.dart';

void main() {
  test('Chancen summieren sich: Sieg zu 1, Platz zu 2', () {
    final c = RaceCard.fromSeed(1);
    var w = 0.0, p = 0.0;
    for (var i = 0; i < horseNames.length; i++) {
      w += c.winChance(i);
      p += c.placeChance(i);
    }
    expect(w, closeTo(1, 1e-9));
    expect(p, closeTo(2, 1e-9));
  });

  test('Ausgeloste Rennen passen zu den Chancen und zahlen etwa 95 %', () {
    final rng = Random(2);
    var staked = 0, paid = 0;
    for (var r = 0; r < 3000; r++) {
      final card = RaceCard.fromSeed(rng.nextInt(1 << 31));
      for (var k = 0; k < 20; k++) {
        final order = card.race(rng.nextInt(1 << 31));
        expect(order.toSet().length, horseNames.length);
        for (var h = 0; h < horseNames.length; h++) {
          for (final kind in BetKind.values) {
            staked += 10;
            paid += card.payout(HorseBet(h, kind, 10), order);
          }
        }
      }
    }
    final rtp = paid / staked;
    // ignore: avoid_print
    print('Pferderennen: ${(rtp * 100).toStringAsFixed(1)} %');
    expect(rtp, inInclusiveRange(0.9, 0.97));
  });

  test('Gleicher Startwert, gleiches Rennen (Netztisch)', () {
    final a = RaceCard.fromSeed(5), b = RaceCard.fromSeed(5);
    expect(a.race(9), b.race(9));
    expect(a.odds10(2, BetKind.win), b.odds10(2, BetKind.win));
  });

  test('Fortschritt passt zur Einlaufreihenfolge', () {
    final card = RaceCard.fromSeed(3);
    final order = card.race(4);
    for (var k = 1; k < order.length; k++) {
      // Wer vorne einläuft, ist im Ziel, wenn der Nächste es noch nicht ist
      final t = 0.82 + (k - 1) * 0.035 + 0.001;
      expect(horseProgress(order, order[k - 1], t, 4), 1.0);
      expect(horseProgress(order, order[k], t, 4), lessThan(1.0));
    }
  });
}
