import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/claw/claw_engine.dart';

void main() {
  test('Perfektes Zielen bringt bei jedem Preis höchstens 95 %', () {
    for (final k in prizeKinds) {
      expect(ClawMachine.holdChance(k, 1) * k.value, closeTo(clawReturn, 1e-9));
    }
  });

  test('Haufen bleibt voll und in der Kiste', () {
    final m = ClawMachine(rng: Random(1));
    final rng = Random(2);
    for (var i = 0; i < 2000; i++) {
      m.grab(chuteWidth + rng.nextDouble() * (clawBoxWidth - chuteWidth));
      expect(m.prizes.length, 14);
      for (final p in m.prizes) {
        expect(p.x, inInclusiveRange(chuteWidth, clawBoxWidth));
      }
    }
  });

  for (final aim in [true, false]) {
    test('Auszahlungsquote ${aim ? 'genau gezielt' : 'zufällig'}', () {
      final m = ClawMachine(rng: Random(aim ? 3 : 4));
      final rng = Random(5);
      var paid = 0;
      const n = 200000;
      for (var i = 0; i < n; i++) {
        double x;
        if (aim) {
          // Auf den wertvollsten erreichbaren Preis genau zielen
          final top = m.prizes.where((p) => m.prizeAt(p.x) == p).reduce((a, b) => a.info.value >= b.info.value ? a : b);
          x = top.x;
        } else {
          x = chuteWidth + rng.nextDouble() * (clawBoxWidth - chuteWidth);
        }
        final r = m.grab(x);
        if (r.won) paid += r.prize!.info.value;
      }
      final rtp = paid / n;
      // ignore: avoid_print
      print('Greifautomat ${aim ? 'gezielt' : 'zufällig'}: ${(rtp * 100).toStringAsFixed(1)} %');
      expect(rtp, aim ? closeTo(0.95, 0.03) : inInclusiveRange(0.3, 0.93));
    });
  }
}
