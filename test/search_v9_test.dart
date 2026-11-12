import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

bool frontContact(PinballTable t, bool left) {
  final f = t.flippers.firstWhere((f) => f.spec.left == left);
  for (final ball in t.balls) {
    final b = ball.body;
    if (b == null) continue;
    for (final c in b.contacts) {
      if (!c.isTouching() ||
          !(identical(c.fixtureA.body, f.body) ||
              identical(c.fixtureB.body, f.body)))
        continue;
      final dx = cos(f.angle) * f.spec.dir, dy = sin(f.angle) * f.spec.dir;
      final px = b.position.x - f.spec.pivot.x,
          py = b.position.y - f.spec.pivot.y;
      final u = (px * dx + py * dy) / f.spec.length;
      var nx = dy, ny = -dx;
      if (ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      if (u >= .05 && u <= .95 && px * nx + py * ny > 0) return true;
    }
  }
  return false;
}

void controls(PinballTable t, bool left, String phase) {
  if (phase == 'Oben') {
    t.leftPressed = true;
    t.rightPressed = true;
  }
  if (phase == 'Zeitpunkt') {
    final p = t.ball;
    // Beim vollständigen Rampenschuss vor der Übergabe noch nicht flippern.
    final ready = p != null && p.y > t.flippers.first.spec.pivot.y - .86;
    t.leftPressed = left && ready;
    t.rightPressed = !left && ready;
  }
}

void main() {
  test('V9: reale Flipper-Schussfenster suchen', () {
    final found = <String, List<num>>{};
    for (final left in [false, true]) {
      final desired = {
        left ? 'rechts' : 'links',
        left ? 'rechts_innen' : 'links_innen',
        left ? 'umlauf_rechts' : 'umlauf_links',
        'kern',
      };
      final prefix = left ? 'L' : 'R';
      for (final vy in [1.0, 2.0, 3.0, 4.0, 5.0]) {
        for (var delay = 0; delay <= 36; delay += 2) {
          for (var k = 2; k <= 19; k++) {
            final u = k * .05;
            final t = PinballTable(rng: Random(1), spec: cityTable);
            for (var i = 0; i < 40; i++) {
              t.step(1 / 120);
            }
            final f = t.flippers.firstWhere((f) => f.spec.left == left),
                sp = f.spec;
            final dx = cos(f.angle) * sp.dir, dy = sin(f.angle) * sp.dir;
            var nx = dy, ny = -dx;
            if (ny > 0) {
              nx = -nx;
              ny = -ny;
            }
            final clear =
                sp.heelHalfWidth +
                (sp.tipHalfWidth - sp.heelHalfWidth) * u +
                PinballTable.ballRadius +
                .025;
            t.debugPlaceBall(
              sp.pivot.x + dx * sp.length * u + nx * clear,
              sp.pivot.y + dy * sp.length * u + ny * clear,
              0,
              vy,
            );
            var contact = false;
            for (var frame = 0; frame < 360; frame++) {
              t.leftPressed = left && frame >= delay;
              t.rightPressed = !left && frame >= delay;
              t.step(1 / 120);
              if (frontContact(t, left)) {
                contact = true;
              }
              if (!contact) continue;
              String? id = t.balls.isEmpty ? null : t.balls.first.ramp?.spec.id;
              if (t.events.any((e) => e.kind == PinballEventKind.saucer)) {
                id = 'kern';
              }
              if (id != null) {
                if (desired.contains(id) && !found.containsKey('$prefix:$id')) {
                  found['$prefix:$id'] = [u, delay, vy];
                  print('GEFUNDEN $prefix:$id $u $delay $vy');
                }
                break;
              }
              if (t.ballInLane || t.gameOver) break;
            }
            if (desired.every((id) => found.containsKey('$prefix:$id'))) break;
          }
          if (desired.every((id) => found.containsKey('$prefix:$id'))) break;
        }
        if (desired.every((id) => found.containsKey('$prefix:$id'))) break;
      }
    }
    print(found);
    expect(found.length, 8);
  });
}
