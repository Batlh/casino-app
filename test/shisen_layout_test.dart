import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/shisen_engine.dart';
import 'package:gluckspfennig/games/mahjong/solitaire_engine.dart';

/// Spielt gierig mit Rückgängig-freier Suche: nimmt das erste freie Paar.
bool solveSolitaire(MahjongSolitaire e, int depth) {
  if (e.won) return true;
  if (depth > 200) return false;
  final pairs = e.freePairs();
  for (final (a, b) in pairs.take(3)) {
    e.remove(a, b);
    if (solveSolitaire(e, depth + 1)) return true;
    e.undo();
  }
  return false;
}

void main() {
  group('Solitär-Formen', () {
    for (final l in SolitaireLayout.values) {
      test('${solitaireLayoutNames[l]} ist gültig', () {
        final slots = layoutSlots(l);
        expect(slots.length.isEven, isTrue);
        expect(slots.length, lessThanOrEqualTo(144));
        final keys = {for (final s in slots) '${s.x},${s.y},${s.z}'};
        expect(keys.length, slots.length, reason: 'doppelte Plätze');
        final e = MahjongSolitaire(rng: Random(1), layout: l);
        expect(e.freePairs(), isNotEmpty);
      });
    }
  });

  group('Shisen-Sho', () {
    test('Gerade Linie und Weg außen herum', () {
      final s = ShisenSho(rng: Random(1), cols: 4, rows: 3);
      s.cells = List.filled(12, 7);
      // Zwei Steine in der obersten Reihe verbinden sich außen herum
      expect(s.path(0, 3), isNotNull);
      // Mitte ist eingeschlossen
      s.cells = List.filled(12, 7);
      expect(s.path(5, 6), isNotNull, reason: 'Nachbarn');
      expect(s.path(4, 7), isNull, reason: 'Steine dazwischen, Rand braucht drei Knicke');
    });

    for (final size in [(12, 6), (18, 8)]) {
      test('Brett ${size.$1}x${size.$2} ist lösbar', () {
        for (var seed = 0; seed < 3; seed++) {
          final s = ShisenSho(rng: Random(seed), cols: size.$1, rows: size.$2);
          expect(s.remaining, size.$1 * size.$2);
          // Gierig lösen: immer das erste verbindbare Paar, bei Sackgasse rückwärts
          var guard = 0;
          bool solve() {
            if (s.won) return true;
            if (++guard > 20000) return false;
            for (final (a, b) in s.freePairs().take(4)) {
              s.remove(a, b);
              if (solve()) return true;
              s.undo();
            }
            return false;
          }

          expect(solve(), isTrue, reason: 'Seed $seed');
        }
      });
    }

    test('Mischen behält die Steine', () {
      final s = ShisenSho(rng: Random(3), cols: 12, rows: 6);
      final pairs = s.freePairs();
      s.remove(pairs.first.$1, pairs.first.$2);
      final before = [...s.cells.where((c) => c >= 0)]..sort();
      s.shuffle();
      final after = [...s.cells.where((c) => c >= 0)]..sort();
      expect(after, before);
    });
  });
}
