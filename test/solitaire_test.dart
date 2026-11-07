import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/solitaire/klondike_engine.dart';
import 'package:gluckspfennig/games/solitaire/spider_engine.dart';
import 'package:gluckspfennig/games/solitaire/table_card.dart';

TableCard up(int rank, Suit suit) => TableCard(PlayingCard(rank == 1 ? 14 : rank, suit), up: true);
const t = PileKind.tableau;
const f = PileKind.foundation;

void main() {
  group('Klondike', () {
    test('Austeilen: sieben Spalten, oberste Karte offen, 24 im Stapel', () {
      final e = KlondikeEngine(rng: Random(1));
      for (var i = 0; i < 7; i++) {
        expect(e.tableau[i].length, i + 1);
        expect(e.tableau[i].last.up, isTrue);
        expect(e.tableau[i].where((c) => c.up).length, 1);
      }
      expect(e.stock.length, 24);
      expect(e.cardCount, 52);
    });

    test('Anlegen: abwechselnde Farbe, absteigend, König auf leere Spalte', () {
      final e = KlondikeEngine(rng: Random(1));
      e.tableau = [
        [up(9, Suit.spades)],
        [up(8, Suit.hearts)],
        [up(8, Suit.clubs)],
        [],
        [up(13, Suit.diamonds)],
        [up(1, Suit.hearts)],
        [up(2, Suit.hearts)],
      ];
      expect(e.canDrop(const PileRef(t, 1), 0, const PileRef(t, 0)), isTrue);
      expect(e.canDrop(const PileRef(t, 2), 0, const PileRef(t, 0)), isFalse);
      expect(e.canDrop(const PileRef(t, 1), 0, const PileRef(t, 3)), isFalse);
      expect(e.canDrop(const PileRef(t, 4), 0, const PileRef(t, 3)), isTrue);
      expect(e.canDrop(const PileRef(t, 6), 0, const PileRef(f, 0)), isFalse);
      expect(e.move(const PileRef(t, 5), 0, const PileRef(f, 0)), isTrue);
      expect(e.canDrop(const PileRef(t, 6), 0, const PileRef(f, 0)), isTrue);
    });

    test('Umzug deckt die nächste Karte auf, Rückgängig stellt alles her', () {
      final e = KlondikeEngine(rng: Random(1));
      e.tableau[0] = [TableCard(const PlayingCard(4, Suit.clubs)), up(7, Suit.hearts)];
      e.tableau[1] = [up(8, Suit.spades)];
      expect(e.move(const PileRef(t, 0), 1, const PileRef(t, 1)), isTrue);
      expect(e.tableau[0].single.up, isTrue);
      expect(e.tableau[1].length, 2);
      e.undo();
      expect(e.tableau[0].length, 2);
      expect(e.tableau[0].first.up, isFalse);
      expect(e.tableau[1].length, 1);
    });

    test('Drei ziehen und Stapel wieder umdrehen', () {
      final e = KlondikeEngine(drawCount: 3, rng: Random(2));
      final first = e.stock.last.card;
      e.draw();
      expect(e.waste.length, 3);
      expect(e.waste.first.card, first);
      for (var i = 0; i < 7; i++) {
        e.draw();
      }
      expect(e.stock, isEmpty);
      expect(e.waste.length, 24);
      e.draw();
      expect(e.stock.length, 24);
      expect(e.stock.last.card, first);
      expect(e.stock.every((c) => !c.up), isTrue);
    });

    test('Automatisch ablegen beendet ein offenes Spiel', () {
      final e = KlondikeEngine(rng: Random(3));
      e.stock = [];
      e.waste = [];
      e.tableau = List.generate(7, (_) => <TableCard>[]);
      for (var s = 0; s < 4; s++) {
        for (var r = 13; r >= 1; r--) {
          e.tableau[s].add(up(r, Suit.values[s]));
        }
      }
      expect(e.canAutoFinish, isTrue);
      var guard = 0;
      while (e.autoFinishStep()) {
        guard++;
      }
      expect(guard, 52);
      expect(e.isWon, isTrue);
    });

    test('Zufällige Züge verlieren nie eine Karte', () {
      final rng = Random(9);
      for (var game = 0; game < 30; game++) {
        final e = KlondikeEngine(drawCount: game.isEven ? 1 : 3, rng: rng);
        for (var step = 0; step < 300; step++) {
          final froms = <(PileRef, int)>[
            if (e.waste.isNotEmpty) (const PileRef(PileKind.waste), e.waste.length - 1),
            for (var c = 0; c < 7; c++)
              for (var i = 0; i < e.tableau[c].length; i++)
                if (e.tableau[c][i].up) (PileRef(t, c), i),
          ];
          final moves = [
            for (final (from, i) in froms)
              if (e.autoTarget(from, i) case final to?) (from, i, to),
          ];
          if (moves.isEmpty || rng.nextInt(4) == 0) {
            e.draw();
          } else {
            final (from, i, to) = moves[rng.nextInt(moves.length)];
            expect(e.move(from, i, to), isTrue);
          }
          if (rng.nextInt(20) == 0) e.undo();
          expect(e.cardCount, 52);
        }
      }
    });
  });

  group('Spider', () {
    test('Austeilen: 54 Karten in zehn Spalten, 50 im Stapel', () {
      for (final suits in [1, 2, 4]) {
        final e = SpiderEngine(suits: suits, rng: Random(1));
        expect(e.tableau.map((c) => c.length).toList(), [6, 6, 6, 6, 5, 5, 5, 5, 5, 5]);
        expect(e.stock.length, 50);
        expect(e.dealsLeft, 5);
        expect(e.cardCount, 104);
        final used = {
          for (final c in e.tableau) ...c.map((x) => x.suit),
          ...e.stock.map((x) => x.suit),
        };
        expect(used.length, suits);
      }
    });

    test('Nur gleichfarbige Reihen lassen sich bewegen', () {
      final e = SpiderEngine(suits: 2, rng: Random(1));
      e.tableau[0] = [up(9, Suit.spades), up(8, Suit.spades), up(7, Suit.hearts)];
      expect(e.canPick(0, 2), isTrue);
      expect(e.canPick(0, 1), isFalse);
      e.tableau[1] = [up(9, Suit.hearts), up(8, Suit.hearts)];
      expect(e.canDrop(0, 2, 1), isTrue);
      expect(e.autoTarget(0, 2), 1);
    });

    test('Volle Reihe wird abgelegt, Austeilen nur ohne leere Spalte', () {
      final e = SpiderEngine(suits: 1, rng: Random(1));
      e.tableau[0] = [
        TableCard(const PlayingCard(5, Suit.spades)),
        for (var r = 13; r >= 2; r--) up(r, Suit.spades),
      ];
      e.tableau[1] = [up(1, Suit.spades)];
      expect(e.move(1, 0, 0), isTrue);
      expect(e.completed.length, 1);
      expect(e.tableau[0].single.up, isTrue);
      expect(e.tableau[1], isEmpty);
      expect(e.canDeal, isFalse);
      e.undo();
      expect(e.completed, isEmpty);
      expect(e.tableau[1].length, 1);
    });

    test('Zufällige Züge verlieren nie eine Karte', () {
      final rng = Random(5);
      for (var game = 0; game < 20; game++) {
        final e = SpiderEngine(suits: [1, 2, 4][game % 3], rng: rng);
        for (var step = 0; step < 300; step++) {
          final moves = [
            for (var c = 0; c < 10; c++)
              for (var i = 0; i < e.tableau[c].length; i++)
                if (e.autoTarget(c, i) case final to?) (c, i, to),
          ];
          if (moves.isEmpty || (e.canDeal && rng.nextInt(6) == 0)) {
            if (e.canDeal) e.deal();
          } else {
            final (from, i, to) = moves[rng.nextInt(moves.length)];
            expect(e.move(from, i, to), isTrue);
          }
          if (rng.nextInt(25) == 0) e.undo();
          expect(e.cardCount, 104);
        }
      }
    });
  });
}
