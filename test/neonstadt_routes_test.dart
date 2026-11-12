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
  test('Neonstadt: 162 Rücklaufvarianten treffen die eigene Arbeitsfläche', () {
    var count = 0;
    for (final left in [true, false])
      for (final phase in ['Ruhe', 'Oben', 'Zeitpunkt'])
        for (final offset in [-.1, 0.0, .1])
          for (final vx in [-.4, 0.0, .4])
            for (final vy in [3.0, 4.0, 5.0]) {
              final t = PinballTable(rng: Random(1), spec: cityTable);
              controls(t, left, phase);
              for (var i = 0; i < 40; i++) t.step(1 / 120);
              final end = cityTable.ramps
                  .firstWhere((r) => r.id == (left ? 'links' : 'rechts'))
                  .path
                  .last;
              t.debugPlaceBall(end.x + offset, end.y, vx, vy);
              var hit = false;
              for (var i = 0; i < 360; i++) {
                controls(t, left, phase);
                t.step(1 / 120);
                if (frontContact(t, left)) {
                  hit = true;
                  break;
                }
                if (t.events.any(
                  (e) =>
                      e.kind == PinballEventKind.drain ||
                      e.kind == PinballEventKind.saved,
                ))
                  break;
              }
              expect(
                hit,
                isTrue,
                reason: 'Seite $left, $phase, Offset $offset, v=($vx,$vy)',
              );
              count++;
            }
    print('$count / $count Rücklaufkontakte');
  });
  test('Neonstadt: 54 vollständige Rampenfahrten bis zur Schlagfläche', () {
    var count = 0;
    for (final left in [true, false])
      for (final phase in ['Ruhe', 'Oben', 'Zeitpunkt'])
        for (final offset in [-.1, 0.0, .1])
          for (final speed in [7.0, 10.0, 14.0]) {
            final t = PinballTable(rng: Random(1), spec: cityTable);
            controls(t, left, phase);
            for (var i = 0; i < 40; i++) t.step(1 / 120);
            final r = cityTable.ramps.firstWhere(
              (r) => r.id == (left ? 'links' : 'rechts'),
            );
            t.debugPlaceBall(
              (r.a.x + r.b.x) / 2 + offset,
              r.a.y + .4,
              0,
              -speed,
            );
            var entered = false, exited = false, hit = false;
            for (var i = 0; i < 120 * 8; i++) {
              controls(t, left, phase);
              t.step(1 / 120);
              if (t.balls.any((b) => b.ramp?.spec.id == r.id)) entered = true;
              if (entered && t.balls.any((b) => b.body != null)) exited = true;
              if (exited && frontContact(t, left)) {
                hit = true;
                break;
              }
              if (t.events.any(
                (e) =>
                    e.kind == PinballEventKind.drain ||
                    e.kind == PinballEventKind.saved,
              ))
                break;
            }
            expect(entered, isTrue, reason: 'Einfahrt ${r.id}, $speed');
            expect(exited, isTrue, reason: 'Ausfahrt ${r.id}');
            expect(
              hit,
              isTrue,
              reason: 'Schlagfläche ${r.id}, $phase, Offset $offset, $speed',
            );
            count++;
          }
    print('$count / $count vollständige Rampenrouten');
  });
  test('Neonstadt: frontaler Dateneinlass nimmt an und wirft aus', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.debugPlaceBall(
      cityTable.saucers.first.x,
      cityTable.saucers.first.y + .75,
      0,
      -4,
    );
    var held = false, released = false;
    for (var i = 0; i < 120 * 4; i++) {
      t.step(1 / 120);
      if (t.saucers.first.held != null) held = true;
      if (held &&
          t.saucers.first.held == null &&
          t.balls.any((b) => b.body != null)) {
        released = true;
        break;
      }
    }
    expect(held, isTrue);
    expect(released, isTrue);
    expect(t.locks, 1);
  });
  test(
    'Neonstadt: Zielbanken zählen Fronttreffer und sperren die Rückseite',
    () {
      for (final bank in cityTable.targets) {
        final target = bank.targets[1];
        final nx = -sin(bank.angle), ny = cos(bank.angle);
        for (final front in [true, false]) {
          final t = PinballTable(rng: Random(1), spec: cityTable);
          final side = front ? 1.0 : -1.0;
          final distance = front ? .55 : .8;
          t.debugPlaceBall(
            target.x + nx * distance * side,
            target.y + ny * distance * side,
            -nx * 3 * side,
            -ny * 3 * side,
          );
          for (var i = 0; i < 30; i++) t.step(1 / 120);
          expect(
            t.events.any((e) => e.kind == PinballEventKind.target),
            front,
            reason: '${bank.id}, Front=$front',
          );
        }
      }
    },
  );
  test('Neonstadt: alle drei eingefassten Rollover-Gassen sind erreichbar', () {
    for (final lane in cityTable.lanes) {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.debugPlaceBall(lane.x, .55, 0, 1);
      for (var i = 0; i < 40; i++) t.step(1 / 120);
      expect(t.lanes.any((l) => l.spec.x == lane.x && l.lit), isTrue);
    }
  });
  test('Neonstadt: drei Datenuploads starten Multiball', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    // Regulärer Multiball über die dritte Speicherung, kein neuer Debug-Einstieg.
    for (var lock = 0; lock < 3; lock++) {
      for (var i = 0; i < 240; i++) t.step(1 / 120);
      t.debugPlaceBall(
        cityTable.saucers.first.x,
        cityTable.saucers.first.y + .75,
        0,
        -4,
      );
      for (var i = 0; i < 70; i++) t.step(1 / 120);
    }
    expect(t.multiball, isTrue);
    expect(t.balls.length, greaterThanOrEqualTo(2));
  });
  test('Neonstadt: Inlane und Outlane sind auf beiden Seiten getrennt', () {
    for (final left in [true, false]) {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.debugPlaceBall(left ? .53 : 8.72, 10.14, 0, 2);
      var lost = false, wrongReturn = false;
      for (var i = 0; i < 480; i++) {
        t.step(1 / 120);
        if (frontContact(t, left)) wrongReturn = true;
        if (t.events.any((e) => e.kind == PinballEventKind.drain)) {
          lost = true;
          break;
        }
      }
      expect(lost, isTrue, reason: 'Outlane ${left ? "links" : "rechts"}');
      expect(wrongReturn, isFalse);
    }
  });
  test('Neonstadt: frühe Outlane-Verluste lösen die Ballrettung aus', () {
    for (final left in [true, false]) {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.charge = 1;
      t.launch();
      t.debugPlaceBall(left ? .53 : 8.72, 10.14, 0, 2);
      var saved = false;
      for (var i = 0; i < 480; i++) {
        t.step(1 / 120);
        if (t.events.any((e) => e.kind == PinballEventKind.saved)) {
          saved = true;
          break;
        }
      }
      expect(saved, isTrue);
      expect(t.ballInLane, isTrue);
      expect(t.ballNumber, 1);
    }
  });
  test('Neonstadt: jede Rampe ist von jedem Flipper aus treffbar', () {
    const cases = [
      (true, 'links', .3, 4, 1.0),
      (true, 'rechts', .9, 2, 2.0),
      (false, 'links', .6, 0, 0.0),
      (false, 'rechts', .2, 0, 3.0),
    ];
    for (final (left, id, u, delay, vy) in cases) {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      for (var i = 0; i < 40; i++) t.step(1 / 120);
      final f = t.flippers.firstWhere((f) => f.spec.left == left), sp = f.spec;
      final dx = cos(f.angle) * sp.dir, dy = sin(f.angle) * sp.dir;
      var nx = dy, ny = -dx;
      if (ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      final clearance =
          sp.heelHalfWidth +
          (sp.tipHalfWidth - sp.heelHalfWidth) * u +
          PinballTable.ballRadius +
          .025;
      // Kugel direkt über der realen Schlagfläche, v_x=0 und v_y>=0.
      // Ausschließlich das anschließende Flippergelenk liefert den Aufwärtsschlag.
      t.debugPlaceBall(
        sp.pivot.x + dx * sp.length * u + nx * clearance,
        sp.pivot.y + dy * sp.length * u + ny * clearance,
        0,
        vy,
      );
      var contact = false, entered = false;
      for (var frame = 0; frame < 480; frame++) {
        t.leftPressed = left && frame >= delay;
        t.rightPressed = !left && frame >= delay;
        t.step(1 / 120);
        if (frontContact(t, left)) contact = true;
        final r = t.balls.first.ramp;
        if (r != null) {
          entered = contact && r.spec.id == id;
          break;
        }
      }
      expect(contact, isTrue, reason: 'echter Schlagflächenkontakt $left');
      expect(entered, isTrue, reason: 'Flipper $left → Rampe $id');
    }
  });
  test('Neonstadt: hinter den Zielgehäusen gibt es keine Sackgassen', () {
    for (final bank in cityTable.targets)
      for (final offset in [-.65, 0.0, .65]) {
        final t = PinballTable(rng: Random(1), spec: cityTable);
        final center = bank.targets[1];
        final nx = -sin(bank.angle), ny = cos(bank.angle);
        t.debugPlaceBall(
          center.x + offset * cos(bank.angle) - nx * .65,
          center.y + offset * sin(bank.angle) - ny * .65,
          0,
          1,
        );
        var slow = 0.0, maxSlow = 0.0;
        for (var i = 0; i < 360; i++) {
          t.step(1 / 120);
          final b = t.balls.first;
          if (b.body != null && t.ballSpeed < .25)
            slow += 1 / 120;
          else
            slow = 0;
          maxSlow = max(maxSlow, slow);
        }
        expect(maxSlow, lessThan(1.5), reason: '${bank.id}, $offset');
      }
  });
  test('Neonstadt: Abschuss verlässt die kürzere Federbahn', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.charge = 1;
    t.launch();
    var field = false;
    for (var i = 0; i < 360; i++) {
      t.step(1 / 120);
      final b = t.ball;
      if (b != null && b.x < PinballTable.fieldRight - .3 && b.y < 3)
        field = true;
    }
    expect(field, isTrue);
  });
}
