// Drehungen von den Screenshots des Nutzers (18.11.2026), Einsatz 100.
// Raster je Walze von oben nach unten, abgelesen vom Bildschirm und mit den Walzenbändern abgeglichen.
// Seit der Umstellung zahlt Tiefsee auf 1024 Wegen, und zwar überall: drei oder mehr Walzen nebeneinander,
// egal ab welcher Walze und in welcher Reihe.
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';
import 'package:gluckspfennig/games/slots/slot_log.dart';

const st = 0, mu = 1, sp = 2, ku = 3, kr = 4, an = 5, q = symWild, pe = symScatter;

/// Raster wie auf dem Bildschirm, erwartete Treffer (Symbol, Startwalze 1-basiert, Walzen, Wege, Betrag) und Summe.
final screens = <String, (List<List<int>>, Set<(int, int, int, int, int)>, int)>{
  '10:11:46': (
    [[st, mu, st, sp], [mu, ku, mu, st], [kr, st, mu, st], [q, ku, q, ku], [ku, st, an, mu]],
    {(st, 1, 5, 8, 64), (mu, 1, 5, 4, 48)},
    112,
  ),
  '10:12:17 bis 10:12:43': (
    [[st, sp, ku, mu], [ku, st, ku, st], [st, mu, st, sp], [an, mu, st, ku], [ku, kr, mu, an]],
    {(st, 1, 4, 4, 12), (mu, 3, 3, 1, 1)},
    13,
  ),
  '10:14:59': (
    [[mu, an, st, kr], [ku, st, ku, st], [st, sp, ku, st], [sp, kr, pe, ku], [st, ku, sp, mu]],
    {(st, 1, 3, 4, 4), (sp, 3, 3, 1, 2), (ku, 2, 4, 2, 20)},
    26,
  ),
  '10:15:26 bis 10:15:55': (
    [[mu, st, sp, ku], [st, sp, q, sp], [st, sp, st, sp], [st, st, mu, sp], [ku, sp, sp, ku]],
    {(st, 1, 4, 8, 24), (sp, 1, 5, 12, 204)},
    228,
  ),
  '10:16:41': (
    [[kr, st, mu, an], [st, ku, st, ku], [sp, st, an, mu], [mu, pe, ku, st], [st, sp, ku, kr]],
    {(st, 1, 5, 2, 16)},
    16,
  ),
};

void main() {
  final engine = SlotEngine(tiefsee.rules);

  for (final e in screens.entries) {
    test('Tiefsee ${e.key}: alle sichtbaren Treffer zählen', () {
      final (grid, hits, total) = e.value;
      final o = engine.playGrid(grid, 100);
      final wins = o.steps.single.wins;
      expect({for (final w in wins) (w.symbol, w.start + 1, w.count, w.ways, w.payout)}, hits);
      expect(o.total, total);
      expect(o.scatterCount < 3, isTrue);
    });
  }

  test('Tiefsee 10:17:40: Freispiel mit zwei Quallen-Walzen', () {
    // Walzen 3 und 4 stehen voll Quallen (vor dem Ausfüllen je eine Qualle)
    final grid = [[mu, ku, st, sp], [st, mu, st, mu], [st, q, mu, st], [q, ku, st, mu], [st, an, mu, st]];
    final o = engine.playGrid(grid, 100, free: true);
    final shown = o.steps.single.grid;
    expect(shown[2], everyElement(q));
    expect(shown[3], everyElement(q));
    expect(o.total, greaterThan(400));
  });

  test('Treffer in der Mitte zählen jetzt auch', () {
    // Muschel nur auf Walze 3 bis 5, Seepferdchen erst ab Walze 3
    final o = engine.playGrid(screens['10:12:17 bis 10:12:43']!.$1, 100);
    expect(o.steps.single.wins.any((w) => w.symbol == mu && w.start == 2), isTrue);
  });

  test('Joker allein zahlt nicht', () {
    final grid = [for (var r = 0; r < 5; r++) [q, q, q, q]];
    final wins = engine.winsOf(grid, 100, 1);
    expect(wins, isEmpty);
  });

  test('Protokoll nennt Raster, Wege und Gewinn', () {
    final o = engine.playGrid(screens['10:15:26 bis 10:15:55']!.$1, 100, stops: const [37, 13, 9, 2, 0]);
    final text = describeSlotOutcome(tiefsee, o, stake: 100, free: false, balance: 16734);
    expect(text, contains('Tiefsee Einsatz 100'));
    expect(text, contains('Wege überall'));
    expect(text, contains('Stopps 37/13/9/2/0'));
    expect(text, contains('R1: Muschel | Seestern | Seestern | Seestern | Kugelfisch'));
    expect(text, contains('Wege ab Walze 1: 5 × Seepferdchen, 12 Wege mit 1 Joker = 204'));
    expect(text, contains('Gewinn 228'));
  });
}
