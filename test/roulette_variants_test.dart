import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/roulette/roulette_engine.dart';

double rtp(Map<BetSpot, int> bets, RouletteVariant v) {
  final order = wheelFor(v);
  final staked = bets.values.fold(0, (a, b) => a + b) * order.length;
  var back = 0;
  for (final n in order) {
    back += resolveBets(bets, n, partage: v == RouletteVariant.french);
  }
  return back / staked;
}

void main() {
  test('Kessel: europäisch 37 Taschen, amerikanisch 38 mit Doppelnull', () {
    expect(wheelOrder.toSet().length, 37);
    expect(wheelOrderAmerican.toSet().length, 38);
    expect(wheelOrderAmerican.contains(doubleZero), isTrue);
    expect(pocketLabel(doubleZero), '00');
  });

  test('Quoten je Spielart', () {
    const red = BetSpot(BetType.red);
    expect(rtp({red: 10}, RouletteVariant.european), closeTo(36 / 37, 1e-9));
    expect(rtp({red: 10}, RouletteVariant.french), closeTo(36.5 / 37, 1e-9));
    expect(rtp({red: 10}, RouletteVariant.american), closeTo(36 / 38, 1e-9));
    expect(rtp({const BetSpot(BetType.straight, 17): 10}, RouletteVariant.american), closeTo(36 / 38, 1e-9));
  });

  test('Kesselansagen: richtige Stücke und alle zahlen 36/37 zurück', () {
    final names = {for (final c in callBets) c.name: c};
    expect(names['Voisins du Zéro']!.pieces, 9);
    expect(names['Tiers du Cylindre']!.pieces, 6);
    expect(names['Orphelins']!.pieces, 5);
    expect(names['Jeu Zéro']!.pieces, 4);
    // Abgedeckte Zahlen
    Set<int> covered(CallBet c) => {for (final (nums, _) in c.parts) ...nums};
    expect(covered(names['Voisins du Zéro']!).length, 17);
    expect(covered(names['Tiers du Cylindre']!).length, 12);
    expect(covered(names['Orphelins']!).length, 8);
    expect(covered(names['Jeu Zéro']!).length, 7);
    // Zusammen decken Voisins, Tiers und Orphelins den ganzen Kessel ab
    expect({...covered(names['Voisins du Zéro']!), ...covered(names['Tiers du Cylindre']!), ...covered(names['Orphelins']!)}.length, 37);
    for (final c in [...callBets, neighbours(17), neighbours(0)]) {
      expect(rtp(c.spots(10), RouletteVariant.european), closeTo(36 / 37, 1e-9), reason: c.name);
    }
    expect(neighbours(0).parts.map((p) => p.$1.first).toList(), [3, 26, 0, 32, 15]);
  });

  test('Gruppen und Gleichheit', () {
    expect(BetSpot.group([5, 8]), BetSpot.group([8, 5]));
    expect(BetSpot.group([5, 8]).odds, 17);
    expect(BetSpot.group([0, 2, 3]).odds, 11);
    expect(BetSpot.group([25, 26, 28, 29]).odds, 8);
    expect(BetSpot.group([5, 8]) == const BetSpot(BetType.straight, 5), isFalse);
    expect(spinWheel(Random(1), RouletteVariant.american), isIn(wheelOrderAmerican));
  });
}
