import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';

void main() {
  const k = 5; // höchstes normales Symbol
  const mond = 0;
  const stern = 1;
  const w = symWild;
  const s = symScatter;
  final kosmos = kosmos78.rules;

  test('Alle Slots: Walzen und Linien passen zusammen', () {
    for (final g in allSlots) {
      final r = g.rules;
      for (final strip in r.strips) {
        expect(strip.every((x) => x >= 0 && x <= symScatter), isTrue, reason: g.name);
      }
      for (final line in r.lines) {
        expect(line.length, r.reels, reason: g.name);
        expect(line.every((row) => row >= 0 && row < r.rows), isTrue, reason: g.name);
      }
      for (final stake in g.stakes) {
        expect(stake % r.lineCount, 0, reason: '${g.name} Einsatz $stake');
      }
      for (final strip in r.strips) {
        for (final sym in strip) {
          expect(sym == symScatter || r.linePays.containsKey(sym), isTrue);
        }
      }
    }
  });

  test('Linienwertung', () {
    expect(kosmos.evaluateLine([k, k, k, mond, mond])?.multiplier, 20);
    expect(kosmos.evaluateLine([w, k, k, k, k])?.multiplier, 500);
    expect(kosmos.evaluateLine([mond, mond, stern, mond, mond]), isNull);
    expect(kosmos.evaluateLine([s, k, k, k, k]), isNull);
    final wild = kosmos.evaluateLine([w, w, w, mond, stern]);
    expect(wild?.symbol, w);
    expect(wild?.multiplier, 50);
    expect(kosmos.evaluateLine(List.filled(5, w))?.multiplier, 1000);
  });

  test('Schrebergarten: Joker verdoppeln den Gewinn', () {
    final r = schrebergarten.rules;
    final base = r.evaluateLine([k, k, k])!.multiplier;
    expect(r.evaluateLine([k, w, k])!.multiplier, base * 2);
    expect(r.evaluateLine([w, w, k])!.multiplier, base * 4);
    expect(r.evaluateLine([w, w, w])!.symbol, w);
  });

  test('Tiefsee: Joker füllt in Freispielen die innere Walze', () {
    final e = SlotEngine(tiefsee.rules, rng: Random(1));
    final grid = [
      [0, 1, 2, 3],
      [1, w, 3, 0],
      [2, 3, 0, 1],
      [3, 0, 1, 2],
      [0, 1, 2, 3],
    ];
    expect(e.evaluateGrid(grid, 100).grid[1], [1, w, 3, 0]);
    expect(e.evaluateGrid(grid, 100, free: true).grid[1], List.filled(4, w));
  });

  test('Scatter zählt überall und startet Freispiele', () {
    final e = SlotEngine(kosmos, rng: Random(1));
    final grid = [
      [s, 0, 1],
      [1, s, 0],
      [0, 1, 2],
      [2, s, 4],
      [4, 2, 3],
    ];
    final r = e.evaluateGrid(grid, 50);
    expect(r.scatterCount, 3);
    expect(r.scatterWin, 100);
    expect(r.freeSpinsWon, kosmos.freeSpins);
  });

  for (final g in allSlots) {
    test('${g.name}: Auszahlungsquote nahe der Abstimmung', () {
      final engine = SlotEngine(g.rules, rng: Random(4));
      final stake = g.stakes[3];
      const spins = 300000;
      var paid = 0;
      var free = 0;
      for (var i = 0; i < spins; i++) {
        var r = engine.spin(stake);
        paid += r.total;
        free += r.freeSpinsWon;
        while (free > 0) {
          free--;
          r = engine.spin(stake, free: true);
          paid += r.total;
          free += r.freeSpinsWon;
        }
      }
      final rtp = paid / (spins * stake);
      // ignore: avoid_print
      print('${g.name}: Auszahlungsquote ${(rtp * 100).toStringAsFixed(1)} %');
      expect(rtp, inInclusiveRange(0.90, 1.0), reason: 'RTP war $rtp');
    });
  }
}
