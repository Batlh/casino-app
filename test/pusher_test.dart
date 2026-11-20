import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pusher/pusher_table.dart';

void main() {
  test('Münzen bleiben auf dem Tisch oder fallen über eine Kante', () {
    final t = PusherTable(rng: Random(1));
    final start = t.coins.length;
    expect(start, greaterThan(30));
    for (var i = 0; i < 60 * 20; i++) {
      t.step(1 / 60);
      for (final c in t.coins) {
        expect(c.y, greaterThan(t.pusherFront - PusherTable.coinRadius));
        expect(c.x.isFinite && c.y.isFinite, isTrue);
      }
    }
    expect(t.coins.length + t.events.length, start);
  });

  test('Gespeicherte Münzen kommen an dieselbe Stelle', () {
    final a = PusherTable(rng: Random(2));
    final b = PusherTable(coins: a.coins.toList());
    expect(b.coins.length, a.coins.length);
    expect(b.coins.first.x, closeTo(a.coins.first.x, 1e-6));
  });

  test('Auszahlungsquote auf lange Sicht', () {
    final rng = Random(3);
    final t = PusherTable(rng: rng);
    var inserted = 0, won = 0, lost = 0;
    const warm = 300, total = 2600;
    for (var n = 0; n < total; n++) {
      t.drop(rng.nextDouble() * PusherTable.width, 1);
      for (var i = 0; i < 54; i++) {
        t.step(1 / 60);
      }
      if (n >= warm) inserted++;
      for (final e in t.events) {
        if (n < warm) continue;
        if (e.won) {
          won += e.value;
        } else {
          lost += e.value;
        }
      }
      t.events.clear();
      expect(t.coins.length, lessThan(200));
    }
    final rtp = won / inserted;
    // ignore: avoid_print
    print('Münzschieber: Quote ${(rtp * 100).toStringAsFixed(1)} %, verloren an den Seiten $lost, Münzen auf dem Tisch ${t.coins.length}');
    expect(rtp, inInclusiveRange(0.85, 1.0));
  });
}
