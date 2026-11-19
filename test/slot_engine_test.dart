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
        expect(strip.every((x) => x >= 0 && (x <= symBonus || r.linePays.containsKey(x))), isTrue, reason: g.name);
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

  for (final (i, g) in [...allSlots, ...slotVariants].indexed) {
    test('${g.name}${i >= allSlots.length ? ' (Variante)' : ''}: Auszahlungsquote nahe der Abstimmung', () {
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

  test('Sakura: Kirschblüten bleiben in Freispielen liegen, im Grundspiel nicht', () {
    final engine = SlotEngine(sakura.rules, rng: Random(21));
    var checked = 0;
    for (var i = 0; i < 3000; i++) {
      final before = {...engine.stickyWilds};
      final o = engine.play(100, free: i % 10 != 0);
      if (i % 10 == 0) {
        // Grundspiel: nichts liegt mehr
        expect(engine.stickyWilds, isEmpty);
        continue;
      }
      for (final (r, row) in before) {
        expect(o.firstGrid[r][row], symWild, reason: 'Joker bleibt liegen');
        checked++;
      }
      expect(engine.stickyWilds.containsAll(before), isTrue);
    }
    expect(checked, greaterThan(50));
  });

  test('Jadetempel: Hold & Spin auf 6 × 5 Feldern mit wechselnder Höhe', () {
    final engine = SlotEngine(jadetempel.rules, rng: Random(8));
    var rounds = 0;
    for (var i = 0; i < 20000 && rounds < 20; i++) {
      final o = engine.play(500);
      for (final cell in o.coins.keys) {
        final r = cell ~/ 5;
        final row = cell % 5;
        expect(row, lessThan(o.heights[r]));
        expect(o.firstGrid[r][row], symCoin);
      }
      final h = o.holdSpin;
      if (h == null) continue;
      rounds++;
      expect(h.boards.last.keys.every((c) => c >= 0 && c < 30), isTrue);
    }
    expect(rounds, greaterThan(0));
  });

  test('Edelsteinmine B: Grubenlampen fallen nach und zählen im letzten Bild', () {
    final engine = SlotEngine(edelsteinmineB.rules, rng: Random(5));
    var viaCascade = 0;
    for (var i = 0; i < 20000; i++) {
      final o = engine.play(100);
      int count(List<List<int>> grid) => grid.expand((c) => c).where((x) => x == symScatter).length;
      expect(o.scatterCount, count(o.lastGrid));
      if (o.freeSpinsWon > 0 && count(o.firstGrid) < 3) viaCascade++;
    }
    expect(viaCascade, greaterThan(0));
  });

  test('Kaskaden: Streusymbole fallen nicht nach, was am Ende liegt, zählt', () {
    for (final g in [edelsteinmine, vulkaninsel]) {
      final engine = SlotEngine(g.rules, rng: Random(31));
      for (var i = 0; i < 3000; i++) {
        final o = engine.play(g.stakes.first);
        int count(List<List<int>> grid) => grid.expand((c) => c).where((x) => x == symScatter).length;
        expect(count(o.lastGrid), count(o.firstGrid), reason: g.name);
        expect(o.scatterCount, count(o.lastGrid));
      }
    }
  });

  test('Früchtekorb: Joker mit Multiplikator zählt als so viele Wege', () {
    // Kirsche · Sieben · zwei Kirschen; die Sieben bekommt ×3 → 1 × 3 × 2 = 6 Wege
    final grid = [
      [0, 1, 2],
      [3, symWild, 4],
      [0, 0, 5],
    ];
    final engine = SlotEngine(fruechtekorb.rules);
    final wins = engine.winsOf(grid, 100, 1, wildMults: {1 * 3 + 1: 3});
    final cherry = wins.firstWhere((w) => w.symbol == 0);
    expect(cherry.ways, 6);
    expect(cherry.payout, 5 * 6 * 100 ~/ 20);
    // Ohne Multiplikator wären es 2 Wege
    expect(engine.winsOf(grid, 100, 1).firstWhere((w) => w.symbol == 0).ways, 2);
    // Beim Drehen bekommt jeder Joker einen der Werte
    final e2 = SlotEngine(fruechtekorb.rules, rng: Random(2));
    var seen = <int>{};
    for (var i = 0; i < 3000; i++) {
      final o = e2.play(100);
      seen.addAll(o.wildMults.values);
      expect(o.wildMults.length, o.firstGrid.expand((c) => c).where((x) => x == symWild).length);
    }
    expect(seen, {2, 3, 5});
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

  group('Zauberbibliothek (Buch)', () {
    final rules = zauberbibliothek.rules;
    const b = symScatter;

    test('Buch ersetzt auf Linien, zahlt selbst aber nicht als Linie', () {
      final e = SlotEngine(rules, rng: Random(1));
      final o = e.playGrid([
        [0, 4, 1],
        [1, b, 2],
        [2, 4, 10],
        [10, 11, 0],
        [11, 2, 1],
      ], 100);
      final mid = o.steps.first.wins.firstWhere((w) => w.line == 0);
      expect(mid.symbol, 4);
      expect(mid.count, 3);
      expect(mid.payout, 20 * 10);
      expect(o.steps.first.wins.any((w) => w.symbol == symWild || w.symbol == b), isFalse);
    });

    test('Drei Bücher starten Freispiele und ziehen ein Sondersymbol', () {
      final e = SlotEngine(rules, rng: Random(2));
      final o = e.playGrid([
        [b, 0, 1],
        [1, 2, 10],
        [2, b, 10],
        [10, 11, 0],
        [11, 2, b],
      ], 100);
      expect(o.freeSpinsWon, 10);
      expect(o.scatterWin, 2 * 100);
      expect(rules.expandingChoices, contains(o.expandSymbol));
      expect(e.expandSymbol, o.expandSymbol);
    });

    test('Sondersymbol breitet sich über nicht benachbarte Walzen aus und zahlt auf allen Linien', () {
      final e = SlotEngine(rules, rng: Random(3))..expandSymbol = 5;
      final o = e.playGrid([
        [5, 0, 1],
        [0, 1, 2],
        [2, 10, 5],
        [10, 11, 0],
        [1, 5, 2],
      ], 100, free: true);
      final last = o.steps.last;
      expect(last.expanded, isTrue);
      expect(last.grid[0], [5, 5, 5]);
      expect(last.grid[1], [0, 1, 2]);
      expect(last.grid[4], [5, 5, 5]);
      final w = last.wins.single;
      expect(w.kind, WinKind.expand);
      expect(w.count, 3);
      expect(w.payout, 50 * 10 * 10);
      expect(o.total, o.steps.fold(0, (a, s) => a + s.win));
    });

    test('Ohne Freispiele breitet sich nichts aus', () {
      final e = SlotEngine(rules, rng: Random(4))..expandSymbol = 5;
      final o = e.playGrid([
        [5, 0, 1],
        [0, 1, 2],
        [2, 10, 5],
        [10, 11, 0],
        [1, 5, 2],
      ], 100);
      expect(o.steps.any((s) => s.expanded), isFalse);
    });
  });

  group('Bonbonfabrik (Gruppen)', () {
    final rules = bonbonfabrik.rules;
    List<List<int>> filled() => [
          for (var r = 0; r < 7; r++) [for (var row = 0; row < 7; row++) const [0, 1, 10, 2, 11, 4, 0][(r * 3 + row * 5) % 7]],
        ];

    test('Raster ohne Gruppe gewinnt nichts', () {
      final o = SlotEngine(rules, rng: Random(1)).playGrid(filled(), 100);
      expect(o.steps.first.wins, isEmpty);
    });

    test('Fünf zusammenhängende gleiche bilden eine Gruppe, schräg zählt nicht', () {
      final g = filled();
      // L-Form aus Lutschern: (0,0) (0,1) (0,2) (1,2) (2,2)
      for (final (r, row) in [(0, 0), (0, 1), (0, 2), (1, 2), (2, 2)]) {
        g[r][row] = 5;
      }
      g[3][3] = 5; // nur schräg daneben
      final e = SlotEngine(rules, rng: Random(1));
      final w = e.winsOf(g, 100, 1).where((w) => w.symbol == 5).single;
      expect(w.kind, WinKind.cluster);
      expect(w.count, 5);
      expect(w.payout, 800);
      expect(w.cells, isNot(contains((3, 3))));
    });

    test('Joker verbindet und zählt für zwei Symbole', () {
      final g = filled();
      for (final (r, row) in [(0, 0), (1, 0), (2, 0), (3, 0)]) {
        g[r][row] = 5;
      }
      for (final (r, row) in [(4, 1), (5, 1), (6, 1), (6, 2)]) {
        g[r][row] = 3;
      }
      g[4][0] = symWild;
      final wins = SlotEngine(rules, rng: Random(1)).winsOf(g, 100, 1);
      expect(wins.where((w) => w.symbol == 5).single.count, 5);
      expect(wins.where((w) => w.symbol == 3).single.count, 5);
    });

    test('Große Gruppen zahlen den letzten Betrag', () {
      expect(rules.payFor(5, 15), 80000);
      expect(rules.payFor(5, 30), 80000);
      expect(rules.payFor(5, 4), 0);
    });

    test('Kaskaden behalten 7 × 7', () {
      final e = SlotEngine(rules, rng: Random(9));
      for (var i = 0; i < 300; i++) {
        for (final s in e.play(100).steps) {
          expect(s.grid.length, 7);
          expect(s.grid.every((c) => c.length == 7), isTrue);
        }
      }
    });
  });

  group('Goldgräber (wandernde Joker, Riesensymbol)', () {
    final rules = goldgraeber.rules;

    test('Joker wandert bis links hinaus, jede Nachdrehung wird gewertet', () {
      final e = SlotEngine(rules, rng: Random(5));
      final o = e.playGrid([
        [0, 1, 2],
        [10, 11, 3],
        [4, 5, 0],
        [1, symWild, 2],
        [3, 4, 10],
      ], 100, stops: const [0, 0, 0, 0, 0]);
      final respins = o.steps.where((s) => s.respin).toList();
      expect(respins.length, greaterThanOrEqualTo(3), reason: 'Walze 4 → 3 → 2 → 1');
      expect(respins[0].grid[2][1], symWild);
      expect(respins[1].grid[1][1], symWild);
      expect(respins[2].grid[0][1], symWild);
      for (final s in respins) {
        expect(s.grid.expand((c) => c).contains(symScatter), isFalse, reason: 'keine Streusymbole in Nachdrehungen');
        expect(s.win, s.wins.fold(0, (a, w) => a + w.payout));
      }
      expect(o.total, o.steps.fold(0, (a, s) => a + s.win));
    });

    test('Ohne Joker keine Nachdrehung, in Freispielen nie', () {
      final e = SlotEngine(rules, rng: Random(6));
      for (var i = 0; i < 400; i++) {
        final o = e.play(100, free: true);
        expect(o.steps.any((s) => s.respin), isFalse);
      }
    });

    test('Freispiele: 3 × 3 Riesensymbol auf den mittleren Walzen', () {
      final e = SlotEngine(rules, rng: Random(7));
      for (var i = 0; i < 200; i++) {
        final o = e.play(100, free: true);
        final g = o.steps.first.giant!;
        expect(g, (1, 0, 3));
        final sym = o.firstGrid[1][0];
        expect(sym, isNot(symScatter));
        for (var r = 1; r < 4; r++) {
          expect(o.firstGrid[r], [sym, sym, sym]);
        }
      }
    });
  });

  group('Runenpfad (endlose Walzen)', () {
    final rules = runenpfad.rules;

    test('Start mit drei offenen Walzen, jeder Gewinn öffnet eine weitere', () {
      final e = SlotEngine(rules, rng: Random(8));
      var grown = 0;
      for (var i = 0; i < 3000; i++) {
        final o = e.play(100);
        expect(o.firstGrid.where((c) => c.isNotEmpty).length, 3);
        for (var k = 1; k < o.steps.length; k++) {
          final prev = o.steps[k - 1];
          final s = o.steps[k];
          expect(s.respin, isTrue);
          expect(prev.wins, isNotEmpty, reason: 'nur nach einem Gewinn');
          expect(s.grid.where((c) => c.isNotEmpty).length, prev.grid.where((c) => c.isNotEmpty).length + 1);
          expect(s.grid.expand((c) => c).contains(symScatter), isFalse);
          grown++;
        }
        final last = o.steps.last;
        expect(last.wins.isEmpty || last.grid.every((c) => c.isNotEmpty), isTrue, reason: 'Ende ohne Gewinn oder alle offen');
        expect(o.total, o.steps.fold(0, (a, s) => a + s.win) + o.scatterWin);
      }
      expect(grown, greaterThan(100));
    });

    test('In Freispielen steigt der Multiplikator mit jeder neuen Walze', () {
      final e = SlotEngine(rules, rng: Random(9));
      for (var i = 0; i < 2000; i++) {
        final o = e.play(100, free: true);
        for (final s in o.steps) {
          expect(s.multiplier, s.grid.where((c) => c.isNotEmpty).length - 2);
        }
      }
    });
  });
}
