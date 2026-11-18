import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';
import 'package:gluckspfennig/games/slots/slot_explain.dart';
import 'package:gluckspfennig/games/slots/slot_games.dart';

void main() {
  test('Sakura 14:58:27 vom Nutzer: Aufschlüsselung 16 Wege = 1.200', () {
    const t = 0, f = 1, k = 2, l = 3, q = symWild, torii = symScatter;
    final grid = [
      [f, t, k, t],
      [q, l, t, k],
      [f, k, t, torii],
      [t, k, t, f],
      [t, k, l, t],
    ];
    final o = SlotEngine(sakura.rules).playGrid(grid, 300);
    expect(o.total, 1458);
    final tea = o.steps.single.wins.firstWhere((w) => w.symbol == t);
    final text = winBreakdown(sakura, o.steps.single.grid, tea, stake: 300, multiplier: 1);
    expect(text, contains('Walze 2: 2-mal (davon 1 Joker)'));
    expect(text, contains('Wege: 2 × 2 × 1 × 2 × 2 = 16'));
    expect(text, contains('Laut Gewinnplan je Weg: 75 (bei Einsatz 300)'));
    expect(text.last, '16 × 75 = 1.200');
  });

  test('Linien-Slot: Aufschlüsselung mit Linieneinsatz', () {
    final engine = SlotEngine(kosmos78.rules);
    // Drei gleiche auf der mittleren Linie (Linie 1)
    final grid = [
      [1, 0, 2],
      [3, 0, 2],
      [4, 0, 5],
      [5, 4, 3],
      [2, 3, 1],
    ];
    final o = engine.playGrid(grid, 100);
    final w = o.steps.single.wins.firstWhere((w) => w.line == 0);
    final text = winBreakdown(kosmos78, grid, w, stake: 100, multiplier: 1);
    expect(text.first, startsWith('Linie 1: 3 ×'));
    expect(text, contains('Linieneinsatz: 100 ÷ 10 Linien = 10.'));
    expect(text.last, endsWith('= ${w.payout}'));
  });

  test('Erklärungen für alle Slots passen zu den Regeln', () {
    for (final g in allSlots) {
      final guide = slotGuide(g);
      final heads = guide.sections.map((s) => s.heading).toList();
      expect(heads.contains('Wege zählen'), g.rules.mode == PayMode.ways, reason: g.name);
      expect(heads.contains('Kaskaden'), g.rules.cascades, reason: g.name);
      expect(heads.contains('Hold & Spin'), g.rules.holdSpin != null, reason: g.name);
      expect(heads.contains('Glücksrad'), g.rules.wheel != null, reason: g.name);
      expect(heads.contains('Freispiele'), g.rules.hasScatter, reason: g.name);
      final all = guide.sections.map((s) => s.text).join(' ');
      expect(all.contains('Gewinnlinien'), g.rules.mode == PayMode.lines, reason: '${g.name}: keine Linien bei Wegen');
    }
  });
}
