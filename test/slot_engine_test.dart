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
        expect(strip.every((x) => x >= 0 && x <= symBonus), isTrue, reason: g.name);
      }
      for (final line in r.lines) {
        expect(line.length, r.reels, reason: g.name);
        expect(line.every((row) => row >= 0 && row < r.rows), isTrue, reason: g.name);
      }
      for (final stake in g.stakes) {
        expect(stake % r.betDivisor, 0, reason: '${g.name} Einsatz $stake');
        if (r.holdSpin != null) expect(stake % 10, 0, reason: '${g.name} Münzen in Zehnteln');
      }
      expect(g.symbolNames.length, greaterThanOrEqualTo(8), reason: g.name);
      for (final strip in r.strips) {
        for (final sym in strip) {
          expect(sym == symScatter || sym == symCoin || sym == symBonus || r.linePays.containsKey(sym) || sym == symWild, isTrue);
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
        var r = engine.play(stake);
        paid += r.total;
        free += r.freeSpinsWon;
        while (free > 0) {
          free--;
          r = engine.play(stake, free: true);
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

  test('Vulkaninsel: jede Walze 2 bis 5 hoch, Wege = Produkt der Treffer je Walze', () {
    final engine = SlotEngine(vulkaninsel.rules, rng: Random(12));
    for (var i = 0; i < 500; i++) {
      final o = engine.play(500);
      expect(o.heights.every((h) => h >= 2 && h <= 5), isTrue);
      for (final s in o.steps) {
        for (var r = 0; r < 6; r++) {
          expect(s.grid[r].length, o.heights[r], reason: 'Kaskaden behalten die Höhe');
        }
        for (final w in s.wins) {
          expect(w.start, 0);
          var ways = 1;
          for (var r = 0; r < w.count; r++) {
            ways *= s.grid[r].where((x) => x == w.symbol || x == symWild).length;
          }
          expect(w.ways, ways);
        }
      }
    }
  });

  test('Alte Slots: play() zahlt genau wie spin()', () {
    for (final g in [kosmos78, schrebergarten]) {
      final a = SlotEngine(g.rules, rng: Random(9));
      final b = SlotEngine(g.rules, rng: Random(9));
      for (var i = 0; i < 2000; i++) {
        final free = i % 7 == 0;
        expect(a.play(g.stakes[2], free: free).total, b.spin(g.stakes[2], free: free).total, reason: '${g.name} Dreh $i');
      }
    }
  });

  test('Wege überall: Mitte zählt, Zickzack zählt, Joker ersetzt', () {
    final e = SlotEngine(tiefsee.rules);
    // Walze 1 ohne Seestern, Walzen 2–4 je ein Seestern in verschiedenen Reihen
    final grid = [
      [1, 2, 3, 4],
      [0, 2, 3, 4],
      [3, 0, 2, 4],
      [2, 3, 0, 4],
      [1, 2, 3, 5],
    ];
    final wins = e.winsOf(grid, 100, 1);
    final star = wins.where((w) => w.symbol == 0).single;
    expect(star.start, 1);
    expect(star.count, 3);
    expect(star.ways, 1);
    expect(star.payout, tiefsee.rules.linePays[0]![0] * 100 ~/ 100);
    // Krake auf allen vier ersten Walzen, Joker auf Walze 3 doppelt
    final g2 = [
      [4, 0, 1, 2],
      [4, 1, 2, 3],
      [w, 4, 1, 2],
      [4, 4, 2, 3],
      [0, 1, 2, 3],
    ];
    final kraken = e.winsOf(g2, 100, 1).where((x) => x.symbol == 4).single;
    expect(kraken.count, 4);
    expect(kraken.ways, 1 * 1 * 2 * 2);
  });

  test('Kaskaden: Gewinn verschwindet, Neues fällt nach, Multiplikator steigt', () {
    final e = SlotEngine(edelsteinmine.rules, rng: Random(3));
    var seen = false;
    for (var i = 0; i < 3000 && !seen; i++) {
      final o = e.play(100);
      if (o.steps.length < 3) continue;
      seen = true;
      expect(o.steps[1].multiplier, 2);
      expect(o.steps[2].multiplier, 3);
      expect(o.steps[1].falls, isNotNull);
      // Jede Walze behält ihre Höhe
      for (final s in o.steps) {
        expect(s.grid.every((c) => c.length == 3), isTrue);
      }
      expect(o.total, o.reelWin + o.scatterWin);
    }
    expect(seen, isTrue);
  });

  test('Hold & Spin: Münzen bleiben, Respins setzen zurück, Summe stimmt', () {
    final e = SlotEngine(drachenhort.rules, rng: Random(5));
    final start = {for (var c = 0; c < 6; c++) c: 10};
    final h = e.runHoldSpin(start, 100);
    for (var i = 1; i < h.boards.length; i++) {
      expect(h.boards[i].keys.toSet().containsAll(h.boards[i - 1].keys), isTrue);
      final grew = h.boards[i].length > h.boards[i - 1].length;
      expect(h.respinsLeft[i], grew ? 3 : h.respinsLeft[i - 1] - 1);
    }
    expect(h.respinsLeft.last == 0 || h.full, isTrue);
    final sum = h.boards.last.values.fold(0, (a, b) => a + b) + (h.full ? drachenhort.rules.holdSpin!.grand : 0);
    expect(h.total, sum * 100 ~/ 10);
  });

  test('Glücksrad: drei Bonus-Symbole drehen das Rad', () {
    final e = SlotEngine(jahrmarkt.rules, rng: Random(2));
    final grid = [
      [symBonus, 0, 1],
      [1, 2, 3],
      [2, symBonus, 4],
      [3, 4, 5],
      [4, 5, symBonus],
    ];
    final o = e.playGrid(grid, 100);
    expect(o.bonusCount, 3);
    final wheel = o.wheel!;
    switch (wheel.segment.kind) {
      case WheelKind.coins:
        expect(wheel.win, wheel.segment.amount * 100);
      case WheelKind.freeSpins:
        expect(o.freeSpinsWon, wheel.segment.amount);
      case WheelKind.holdSpin:
        expect(o.holdSpin, isNotNull);
    }
  });
}
