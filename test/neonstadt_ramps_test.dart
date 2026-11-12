import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

void main() {
  test(
    'Neonstadt: Höhenprofile enden auf dem Boden und trennen die Überführung',
    () {
      for (final spec in cityTable.ramps) {
        final ramp = Ramp(spec);
        expect(spec.heights.length, spec.path.length);
        expect(ramp.heightAt(0), 0);
        expect(ramp.heightAt(ramp.length), 0);
        expect(spec.heights.reduce(max), greaterThan(1));
        expect(spec.deckWidth, greaterThan(PinballTable.ballRadius * 2 + .20));
        final lengths = <double>[0];
        for (var i = 1; i < spec.path.length; i++) {
          final a = spec.path[i - 1], b = spec.path[i];
          lengths.add(
            lengths.last + sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2)),
          );
          expect(spec.heights[i], greaterThanOrEqualTo(0));
          expect(spec.path[i].x, inInclusiveRange(.4, 8.9));
          expect(spec.path[i].y, inInclusiveRange(.6, 12.6));
        }
        // Materialwechsel am oberen Übergabepunkt: gleicher Punkt und gleiche
        // Tangente, kein getrennter oder springender Rücklauf.
        expect(
          (ramp.length * spec.wireStart - lengths[36]).abs(),
          lessThan(.01),
        );
        expect(spec.heights[36], greaterThan(1.3));
        final first = spec.path.first, last = spec.path.last;
        expect((first.x - (spec.a.x + spec.b.x) / 2).abs(), lessThan(.001));
        expect((first.y - spec.a.y).abs(), lessThan(.001));
        expect(
          (last.x - (spec.id == 'links' ? 1.30 : 7.95)).abs(),
          lessThan(.001),
        );
        expect((last.y - 9.126).abs(), lessThan(.001));
      }
    },
  );

  for (final rampSpec in cityTable.ramps) {
    test('Neonstadt ${rampSpec.id}: Einfahrt und Rückkehr in die Gasse', () {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      final x = (rampSpec.a.x + rampSpec.b.x) / 2;
      t.debugPlaceBall(x, rampSpec.a.y + .4, 0, -12);
      var entered = false;
      var exited = false;
      for (var frame = 0; frame < 120 * 8; frame++) {
        t.step(1 / 120);
        final ball = t.balls.first;
        if (ball.ramp?.spec.id == rampSpec.id) entered = true;
        if (entered && !ball.raised) {
          final end = rampSpec.path.last;
          expect((ball.pos.x - end.x).abs(), lessThan(.08));
          expect((ball.pos.y - end.y).abs(), lessThan(.08));
          expect(ball.elevation, 0);
          exited = true;
          break;
        }
      }
      expect(entered, isTrue);
      expect(exited, isTrue);
    });
  }
}
