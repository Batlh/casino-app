import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart' as v8;
import 'package:gluckspfennig/games/pinball/pinball_tables.dart' as now;

import 'fixtures/main/lib/games/pinball/pinball_table.dart' as v7main;
import 'fixtures/main/lib/games/pinball/pinball_tables.dart' as before;

void main() {
  for (var table = 0; table < 5; table++) {
    test(
      '${now.pinballTables[table].name}: main (0.9.2) und V9 verhalten sich in 12000 Simulationsschritten gleich',
      () {
        for (var seed = 0; seed < 10; seed++) {
          final a = v8.PinballTable(
            spec: now.pinballTables[table],
            rng: Random(seed),
          );
          final b = v7main.PinballTable(
            spec: before.pinballTables[table],
            rng: Random(seed),
          );
          for (var frame = 0; frame < 1200; frame++) {
            if (a.ballInLane) {
              a.charge = .35 + (seed % 6) * .1;
              a.launch();
            }
            if (b.ballInLane) {
              b.charge = .35 + (seed % 6) * .1;
              b.launch();
            }
            a.leftPressed = b.leftPressed = (frame % 79) < 17;
            a.rightPressed = b.rightPressed = (frame % 101) < 23;
            a.step(1 / 120);
            b.step(1 / 120);
            final why = 'Seed $seed, Frame $frame';
            expect(
              [
                a.score,
                a.ballsLeft,
                a.locks,
                a.multiplier,
                a.missionIndex,
                a.missionProgress,
                a.gameOver,
                a.ballInLane,
                a.gateClosed,
              ],
              [
                b.score,
                b.ballsLeft,
                b.locks,
                b.multiplier,
                b.missionIndex,
                b.missionProgress,
                b.gameOver,
                b.ballInLane,
                b.gateClosed,
              ],
              reason: why,
            );
            expect(a.balls.length, b.balls.length, reason: why);
            for (var i = 0; i < a.balls.length; i++) {
              expect(
                a.balls[i].pos.x,
                closeTo(b.balls[i].pos.x, 1e-10),
                reason: why,
              );
              expect(
                a.balls[i].pos.y,
                closeTo(b.balls[i].pos.y, 1e-10),
                reason: why,
              );
              expect(
                a.balls[i].ramp?.spec.id,
                b.balls[i].ramp?.spec.id,
                reason: why,
              );
            }
            expect(
              a.events
                  .map((e) => [e.kind.name, e.points, e.x, e.y, e.text])
                  .toList(),
              b.events
                  .map((e) => [e.kind.name, e.points, e.x, e.y, e.text])
                  .toList(),
              reason: why,
            );
            a.events.clear();
            b.events.clear();
          }
        }
        print(
          '${now.pinballTables[table].name}: 12000 Schritte einschließlich Kugelbahnen und Ereignissen identisch',
        );
      },
    );
  }
}
