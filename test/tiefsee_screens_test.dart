// Drehungen von den Screenshots des Nutzers (18.11.2026), Einsatz 100.
// Raster je Walze von oben nach unten, abgelesen vom Bildschirm und mit den Walzenbändern abgeglichen.
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_log.dart';

const st = 0, mu = 1, sp = 2, ku = 3, kr = 4, an = 5, q = symWild, pe = symScatter;

/// Raster wie auf dem Bildschirm, gewertete Linien (1-basiert) und erwarteter Gesamtgewinn.
final screens = <String, (List<List<int>>, Set<int>, int)>{
  '10:11:46': ([[st, mu, st, sp], [mu, ku, mu, st], [kr, st, mu, st], [q, ku, q, ku], [ku, st, an, mu]], {19}, 75),
  '10:12:17 bis 10:12:43': ([[st, sp, ku, mu], [ku, st, ku, st], [st, mu, st, sp], [an, mu, st, ku], [ku, kr, mu, an]], {5, 9}, 50),
  '10:14:59': ([[mu, an, st, kr], [ku, st, ku, st], [st, sp, ku, st], [sp, kr, pe, ku], [st, ku, sp, mu]], {8}, 25),
  '10:15:26 bis 10:15:55': ([[mu, st, sp, ku], [st, sp, q, sp], [st, sp, st, sp], [st, st, mu, sp], [ku, sp, sp, ku]], {16, 19, 20}, 105),
  '10:16:41': ([[kr, st, mu, an], [st, ku, st, ku], [sp, st, an, mu], [mu, pe, ku, st], [st, sp, ku, kr]], {11}, 25),
};

void main() {
  final engine = SlotEngine(tiefsee.rules);

  for (final e in screens.entries) {
    test('Tiefsee ${e.key}: Gewinn wie angezeigt', () {
      final (grid, lines, total) = e.value;
      final r = engine.evaluateGrid(grid, 100);
      expect({for (final w in r.lineWins) w.line + 1}, lines);
      expect(r.total, total);
      expect(r.scatterCount < 3, isTrue);
    });
  }

  test('Tiefsee 10:17:40: letztes Freispiel mit zwei Quallen-Walzen', () {
    // Walzen 3 und 4 stehen voll Quallen (vor dem Ausfüllen je eine Qualle)
    final grid = [[mu, ku, st, sp], [st, mu, st, mu], [st, q, mu, st], [q, ku, st, mu], [st, an, mu, st]];
    final r = engine.evaluateGrid(grid, 100, free: true);
    expect(r.grid[2], everyElement(q));
    expect(r.grid[3], everyElement(q));
    // Linie 2: 4 Seesterne, Linien 5, 9 und 17: je 4 Muscheln, Linie 16: 5 Seesterne
    expect({for (final w in r.lineWins) w.line + 1}, {2, 5, 9, 16, 17});
    expect(r.total, 50 + 75 + 75 + 125 + 75);
  });

  test('Gleiche Symbole nur in der Mitte zahlen nicht', () {
    // Oben Muschel, dann drei Seesterne; unten Kugelfisch, dann drei Seepferdchen
    final r = engine.evaluateGrid(screens['10:15:26 bis 10:15:55']!.$1, 100);
    expect(r.lineWins.where((w) => w.line == 2 || w.line == 3), isEmpty);
  });

  test('Protokoll nennt Raster, Linien und Gewinn', () {
    final r = engine.evaluateGrid(screens['10:15:26 bis 10:15:55']!.$1, 100, stops: const [37, 13, 9, 2, 0]);
    final text = describeSlotSpin(tiefsee, r, stake: 100, free: false, balance: 16734);
    expect(text, contains('Tiefsee Einsatz 100'));
    expect(text, contains('Stopps 37/13/9/2/0'));
    expect(text, contains('R1: Muschel | Seestern | Seestern | Seestern | Kugelfisch'));
    expect(text, contains('Linie 16 (3-3-2-1-1): 3 × Seepferdchen mit 1 Joker = 40'));
    expect(text, contains('Gewinn 105'));
  });
}
