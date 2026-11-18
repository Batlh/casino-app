import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/bingo/bingo_engine.dart';

void main() {
  test('Karten mit 75 Kugeln: Spalten B bis O, Mitte frei', () {
    final rng = Random(1);
    for (var i = 0; i < 300; i++) {
      final c = makeCard75(rng);
      expect(c.rows[2][2], 0);
      for (var col = 0; col < 5; col++) {
        for (var r = 0; r < 5; r++) {
          final n = c.rows[r][col];
          if (r == 2 && col == 2) continue;
          expect(n, inInclusiveRange(col * 15 + 1, col * 15 + 15));
        }
      }
      expect(c.numbers.toSet().length, 24);
    }
  });

  test('Karten mit 90 Kugeln: 15 Zahlen, fünf je Reihe, Spalten sortiert', () {
    final rng = Random(2);
    for (var i = 0; i < 300; i++) {
      final c = makeCard90(rng);
      expect(c.numbers.length, 15);
      for (final row in c.rows) {
        expect(row.where((n) => n > 0).length, 5);
      }
      for (var col = 0; col < 9; col++) {
        final nums = [for (var r = 0; r < 3; r++) if (c.rows[r][col] > 0) c.rows[r][col]];
        expect(nums, isNotEmpty);
        expect(nums, orderedEquals([...nums]..sort()));
        final lo = col == 0 ? 1 : col * 10, hi = col == 8 ? 90 : col * 10 + 9;
        expect(nums.every((n) => n >= lo && n <= hi), isTrue);
      }
    }
  });

  test('Spiele laufen durch, der Pot wird höchstens ganz ausgezahlt', () {
    final rng = Random(3);
    for (final v in BingoVariant.values) {
      for (final pattern in v == BingoVariant.us75 ? BingoPattern.values : [BingoPattern.line]) {
        for (var round = 0; round < 40; round++) {
          final players = [
            for (var i = 0; i < 6; i++) BingoPlayer('P$i', human: i == 0)..cards.addAll(BingoGame.dealCards(v, 1 + i % 3, rng)),
          ];
          final g = BingoGame(variant: v, players: players, cardPrice: 50, pattern: pattern, rng: rng);
          var guard = 0;
          while (!g.over && guard++ < 100) {
            final wins = g.callNext();
            for (final w in wins) {
              // Gewinner hat das Muster wirklich
              expect(w.card.wins(v, g.drawn, pattern: pattern, stage: w.stage), isTrue);
            }
          }
          expect(g.over, isTrue, reason: '$v $pattern');
          final paid = g.wins.fold(0, (a, w) => a + w.amount);
          expect(paid, lessThanOrEqualTo(g.pot));
          expect(paid, greaterThan(g.pot * 0.95));
          if (v == BingoVariant.uk90) expect(g.wins.map((w) => w.stage).toSet(), {0, 1, 2});
        }
      }
    }
  });

  test('Gleichstand wird geteilt', () {
    final card = BingoCard([
      [1, 16, 31, 46, 61],
      [2, 17, 32, 47, 62],
      [3, 18, 0, 48, 63],
      [4, 19, 34, 49, 64],
      [5, 20, 35, 50, 65],
    ]);
    final a = BingoPlayer('A')..cards.add(card);
    final b = BingoPlayer('B')..cards.add(card);
    final g = BingoGame(variant: BingoVariant.us75, players: [a, b], cardPrice: 100, rng: Random(1));
    while (!g.over) {
      g.callNext();
    }
    expect(g.wins.length, 2);
    expect(g.wins[0].amount, g.wins[1].amount);
    expect(g.wins[0].amount, g.pot ~/ 2);
  });
}
