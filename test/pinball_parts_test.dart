import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

/// Neue Bauteile der Tische Angelsee, Dschungeltempel und Zirkus.
List<PinballEventKind> run(PinballTable t, double seconds) {
  final seen = <PinballEventKind>[];
  for (var time = 0.0; time < seconds; time += 1 / 120) {
    t.step(1 / 120);
    seen.addAll(t.events.map((e) => e.kind));
    t.events.clear();
  }
  return seen;
}

void main() {
  test('Angelsee: Rückschuss holt die Kugel aus der Auslaufbahn und muss neu scharf gemacht werden', () {
    final t = PinballTable(rng: Random(1), spec: lakeTable);
    run(t, 0.2);
    final k = t.kickbacks.single;
    expect(k.armed, isTrue);
    t.debugPlaceBall(0.45, 14.6, 0, 3);
    var minY = 99.0;
    final seen = <PinballEventKind>[];
    for (var i = 0; i < 120; i++) {
      t.step(1 / 120);
      seen.addAll(t.events.map((e) => e.kind));
      t.events.clear();
      if (seen.contains(PinballEventKind.kickback)) minY = min(minY, t.ball?.y ?? 99);
    }
    expect(seen, contains(PinballEventKind.kickback));
    expect(minY, lessThan(12), reason: 'Die Kugel fliegt nach oben zurück ins Feld');
    expect(k.armed, isFalse);

    // Zweites Mal ohne Scharfmachen: die Kugel geht verloren
    t.debugPlaceBall(0.45, 14.6, 0, 3);
    final again = run(t, 2);
    expect(again, isNot(contains(PinballEventKind.kickback)));
    expect(again, contains(PinballEventKind.drain));
  });

  test('Dschungeltempel: Fallziele öffnen das Tor, die Kammer fängt die Kugel und das Tor geht wieder zu', () {
    final t = PinballTable(rng: Random(2), spec: jungleTable);
    run(t, 0.2);
    final gate = t.gates.single;
    expect(gate.open, isFalse);
    final bank = t.dropBanks.single;
    final seen = <PinballEventKind>[];
    for (final d in bank.targets) {
      t.debugPlaceBall(d.c.x - 0.6, d.c.y, 7, 0);
      seen.addAll(run(t, 0.25));
    }
    expect(bank.targets.every((d) => d.down) || seen.contains(PinballEventKind.dropBank), isTrue);
    expect(seen, contains(PinballEventKind.gateOpen));
    expect(gate.open, isTrue);

    // Kugel von unten in die Kammer: das Loch fängt sie, das Tor schließt sich
    t.debugPlaceBall(4.6, 9.6, 0, -7);
    final caught = run(t, 0.6);
    expect(caught, contains(PinballEventKind.saucer));
    expect(gate.open, isFalse);
    // Beim Auswerfen kommt die Kugel heraus
    run(t, 2.5);
    final p = t.ball!;
    expect(p.y, greaterThan(8.7), reason: 'Kugel ist nicht in der Kammer gefangen');
  });

  test('Dschungeltempel: dritter Flipper schwingt mit der linken Taste', () {
    final t = PinballTable(rng: Random(3), spec: jungleTable);
    final upper = t.flippers.firstWhere((f) => f.spec.pivot.y < 12);
    final rest = upper.angle;
    t.leftPressed = true;
    run(t, 0.2);
    expect(upper.angle, lessThan(rest - 0.5));
  });

  test('Zirkus: Kanonenkugel zählt Treffer und federt zurück', () {
    final t = PinballTable(rng: Random(4), spec: circusTable);
    run(t, 0.3);
    final c = t.captives.single;
    final home = c.pos.y;
    t.debugPlaceBall(7.6, 7.6, 0, -13);
    final seen = run(t, 0.6);
    expect(seen, contains(PinballEventKind.captive));
    expect(c.hits, 1);
    run(t, 2);
    expect(c.pos.y, closeTo(home, 0.15));
  });

  test('Zirkus: Glücksrad in der Manege gibt einen Preis', () {
    final t = PinballTable(rng: Random(5), spec: circusTable);
    run(t, 0.2);
    final s = t.saucers.firstWhere((s) => s.spec.wheel);
    t.debugPlaceBall(s.spec.x, s.spec.y - 0.1, 0, 0.5);
    final seen = run(t, 2.6);
    expect(seen, contains(PinballEventKind.saucer));
    expect(seen, contains(PinballEventKind.wheel));
    expect(s.wheelPrize, inInclusiveRange(0, wheelPrizes.length - 1));
  });
}
