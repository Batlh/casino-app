import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/lose/lose_engine.dart';

void main() {
  test('Quoten und Gewinnchancen der Sorten', () {
    for (final s in rubbelSorten) {
      final q = expectedPayout(s.table) / s.price;
      expect(q, inInclusiveRange(0.6, 0.8), reason: s.name);
      expect(winChance(s.table), lessThan(1));
    }
    for (final s in pullSorten) {
      final q = expectedPayout(s.table) / s.price;
      expect(q, inInclusiveRange(0.6, 0.8), reason: s.name);
    }
  });

  test('Rubbellose: Bild passt immer zum ausgewürfelten Gewinn', () {
    final rng = Random(3);
    for (final s in rubbelSorten) {
      var paid = 0;
      const n = 60000;
      for (var i = 0; i < n; i++) {
        final l = makeRubbelLos(s, rng);
        paid += l.prize;
        switch (s.kind) {
          case RubbelKind.dreiGleiche:
            expect(l.fields.length, 6);
            final counts = <int, int>{};
            for (final f in l.fields) {
              counts[f.amount] = (counts[f.amount] ?? 0) + 1;
            }
            final triples = counts.entries.where((e) => e.value >= 3).toList();
            if (l.prize > 0) {
              expect(triples.single.key, l.prize);
              expect(triples.single.value, 3);
            } else {
              expect(triples, isEmpty);
            }
          case RubbelKind.gewinnzahlen:
            final hits = l.fields.where((f) => l.winningNumbers.contains(f.number)).toList();
            expect(hits.length, l.prize > 0 ? 1 : 0);
            if (l.prize > 0) expect(hits.single.amount, l.prize);
            expect(l.fields.map((f) => f.number).toSet().length, 8);
          case RubbelKind.symbolSuche:
            final d = l.fields.where((f) => f.symbol == 'Diamant').toList();
            expect(d.length, l.prize > 0 ? 1 : 0);
            if (l.prize > 0) expect(d.single.amount, l.prize);
        }
      }
      // Ausgezahlt wird ungefähr, was die Tabelle verspricht (große Gewinne schwanken stark)
      final q = paid / (n * s.price);
      expect(q, greaterThan(0.4), reason: s.name);
    }
  });

  test('Pull-Tabs: höchstens ein Fenster mit drei Gleichen, passend zum Gewinn', () {
    final rng = Random(4);
    for (final s in pullSorten) {
      var wins = 0;
      const n = 30000;
      for (var i = 0; i < n; i++) {
        final t = makePullTab(s, rng);
        final triples = [for (var r = 0; r < 5; r++) if (t.rows[r].toSet().length == 1) r];
        if (t.prize > 0) {
          wins++;
          expect(triples, [t.winRow]);
          expect(t.prize, s.pays[t.rows[t.winRow].first]!.amount * s.price);
        } else {
          expect(triples, isEmpty);
          expect(t.winRow, -1);
        }
      }
      expect(wins / n, closeTo(winChance(s.table), 0.02), reason: s.name);
    }
  });
}
