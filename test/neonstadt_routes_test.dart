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

void tick(PinballTable t, int frames) {
  for (var i = 0; i < frames; i++) {
    t.step(1 / 120);
  }
}

void core(PinballTable t) {
  final s = t.saucers.first.spec;
  t.debugPlaceBall(s.x, s.y + .6, 0, -4);
  tick(t, 35);
  expect(t.saucers.first.held, isNotNull);
}

void bankHit(PinballTable t, String id) {
  final bank = cityTable.targets.firstWhere((b) => b.id == id);
  for (final p in bank.targets) {
    tick(t, 40);
    final nx = -sin(bank.angle), ny = cos(bank.angle);
    t.debugPlaceBall(p.x + nx * .55, p.y + ny * .55, -nx * 4, -ny * 4);
    tick(t, 20);
  }
}

void main() {
  const shots = [
    (false, 'kern', .50, 0, 1.0),
    (false, 'links', .90, 36, 1.0),
    (false, 'links_innen', .40, 12, 1.0),
    (true, 'kern', .80, 0, 1.0),
    (true, 'rechts', .35, 26, 1.0),
    (true, 'rechts_innen', .90, 26, 1.0),
    (false, 'umlauf_links', .60, 2, 1.0),
    (true, 'umlauf_rechts', .30, 14, 5.0),
  ];
  for (final (left, id, u, delay, vy) in shots) {
    test(
      '$id vom ${left ? 'linken' : 'rechten'} Flipper: wirklicher Kontakt und anschließender Treffer',
      () {
        final t = PinballTable(rng: Random(1), spec: cityTable);
        tick(t, 40);
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
        var contact = false, hit = false;
        for (var frame = 0; frame < 360; frame++) {
          t.leftPressed = left && frame >= delay;
          t.rightPressed = !left && frame >= delay;
          t.step(1 / 120);
          contact |= frontContact(t, left);
          hit =
              contact &&
              (id == 'kern'
                  ? t.events.any((e) => e.kind == PinballEventKind.saucer)
                  : t.balls.any((b) => b.ramp?.spec.id == id));
          if (hit) break;
        }
        expect(contact, isTrue);
        expect(hit, isTrue);
      },
    );
  }
  for (final bank in cityTable.targets) {
    for (final front in [true, false]) {
      test(
        '${bank.id}: ${front ? 'Front zählt' : 'Rückseite zählt nicht'}',
        () {
          final t = PinballTable(rng: Random(1), spec: cityTable);
          final p = bank.targets[1],
              nx = -sin(bank.angle),
              ny = cos(bank.angle),
              sign = front ? 1.0 : -1.0;
          t.debugPlaceBall(
            p.x + nx * .55 * sign,
            p.y + ny * .55 * sign,
            -nx * 4 * sign,
            -ny * 4 * sign,
          );
          tick(t, 20);
          expect(t.events.any((e) => e.kind == PinballEventKind.target), front);
        },
      );
    }
  }
  for (final r in cityTable.ramps.where((r) => r.skillBand < 0)) {
    test('${r.id}: zu schwacher Schuss rollt frei zurück', () {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .35, 0, -3);
      var entered = false, returned = false;
      for (var i = 0; i < 120; i++) {
        t.step(1 / 120);
        entered |= t.balls.any((b) => b.ramp?.spec.id == r.id);
        returned |= t.balls.any(
          (b) =>
              b.body != null &&
              b.body!.position.y > r.a.y + .6 &&
              b.body!.linearVelocity.y > 0,
        );
      }
      expect(entered, isFalse);
      expect(returned, isTrue);
    });
  }
  for (final id in ['links_innen', 'rechts_innen']) {
    test('$id: erhöhte Überfahrt über Bank, Auslauf trifft Bumper', () {
      final t = PinballTable(rng: Random(1), spec: cityTable),
          r = cityTable.ramps.firstWhere((r) => r.id == id);
      t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .4, 0, -12);
      var entered = false, bumper = false;
      for (var i = 0; i < 600; i++) {
        t.step(1 / 120);
        entered |= t.balls.any((b) => b.ramp?.spec.id == id);
        bumper |=
            entered && t.events.any((e) => e.kind == PinballEventKind.bumper);
        if (bumper) break;
      }
      expect(entered, isTrue);
      expect(bumper, isTrue);
      final bank = cityTable.targets.firstWhere((b) => id.startsWith(b.id));
      final samples = [
        for (var i = 0; i < r.path.length; i++)
          if ((r.path[i].x - bank.targets[1].x).abs() < .7 &&
              (r.path[i].y - bank.targets[1].y).abs() < .5)
            i,
      ];
      expect(samples, isNotEmpty);
      for (final i in samples) {
        expect(r.heights[i], greaterThan(.9));
      }
    });
  }
  for (var band = 0; band < 3; band++) {
    test('Skill-Shot: echter Abschuss über Brücke in Leuchtgasse $band', () {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.skillTargetLane = band;
      t.charge = [.22, .55, .92][band];
      t.launch();
      var bridge = false, bonus = false;
      for (var i = 0; i < 840; i++) {
        t.step(1 / 120);
        bridge |= t.balls.any((b) => b.ramp?.spec.id == 'skill_$band');
        bonus |= t.events.any((e) => e.kind == PinballEventKind.skillShot);
        if (bonus) break;
      }
      expect(bridge, isTrue);
      expect(bonus, isTrue);
    });
  }
  test('Gassenwechsel und Ausgänge ins Bumperfeld', () {
    final t = PinballTable(rng: Random(1), spec: cityTable),
        top = t.lanes.where((l) => l.spec.group == 'top').toList();
    top[0].lit = true;
    t.rightPressed = true;
    t.step(1 / 120);
    expect(top[1].lit, isTrue);
    t.rightPressed = false;
    t.step(1 / 120);
    t.leftPressed = true;
    t.step(1 / 120);
    expect(top[0].lit, isTrue);
    for (final l in cityTable.lanes.where((l) => l.group == 'top')) {
      final q = PinballTable(rng: Random(1), spec: cityTable);
      q.debugPlaceBall(l.x, .55, 0, 2);
      var leftLane = false;
      for (var i = 0; i < 360; i++) {
        q.step(1 / 120);
        leftLane |= q.balls.any(
          (b) => b.body != null && b.body!.position.y > 1.2,
        );
      }
      expect(leftLane, isTrue);
    }
  });
  test(
    'Drei echte Kern-Locks halten Kugeln und geben exakt drei Kugeln frei',
    () {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      for (var i = 1; i <= 2; i++) {
        core(t);
        tick(t, 230);
        expect(t.cityLockedBalls.length, i);
        expect(t.locks, i);
        expect(t.ballsLeft, 3);
        expect(t.ballInLane, isTrue);
      }
      core(t);
      var concurrent = 0;
      for (var i = 0; i < 360; i++) {
        t.step(1 / 120);
        concurrent = max(concurrent, t.balls.length);
      }
      expect(t.city!.multiball, 'Datenupload');
      expect(t.cityLockedBalls, isEmpty);
      expect(concurrent, 3);
    },
  );
  test('Zielbank-Alarm gibt nach beiden Bänken genau zwei Kugeln frei', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    bankHit(t, 'links');
    bankHit(t, 'rechts');
    tick(t, 120);
    expect(t.city!.multiball, 'Zielbank-Alarm');
    expect(t.balls.length, 2);
  });
  test('Wizard wird im Engine-Ablauf als Vierkugelspiel bedient', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    // Regelabschluss separat geprüft; hier wird die physische Kugelausgabe geprüft.
    t.city!.completed.addAll(List.generate(8, (i) => i));
    core(t);
    tick(t, 300);
    expect(t.city!.wizard, isTrue);
    expect(t.balls.length, 4);
  });
  test('Kickback verbraucht sich und lädt über beide Inlane-Schalter nach', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.debugPlaceBall(.53, 15.65, 0, 2);
    t.step(1 / 120);
    expect(t.city!.kickbackLit, isFalse);
    expect(t.balls.first.body!.linearVelocity.y, lessThan(-10));
    for (final l in cityTable.lanes.where(
      (l) => l.group.startsWith('inlane_'),
    )) {
      t.debugPlaceBall(l.x, l.y, 0, 1);
      t.step(1 / 120);
    }
    expect(t.city!.kickbackLit, isTrue);
  });
  test('Alle vier unteren Gassen besitzen eigene Überroll-Schalter', () {
    for (final lane in cityTable.lanes.where((l) => l.group != 'top')) {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.debugPlaceBall(lane.x, lane.y, 0, 1);
      t.step(1 / 120);
      expect(
        t.lanes.firstWhere((l) => l.spec.group == lane.group).cooldown,
        greaterThan(0),
      );
    }
  });
  test('Ballrettung fördert verzögert und startet automatisch erneut', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.charge = 1;
    t.launch();
    t.debugPlaceBall(4.625, 18.25, 0, 3);
    tick(t, 5);
    expect(t.events.any((e) => e.kind == PinballEventKind.saved), isTrue);
    expect(t.balls, isEmpty);
    tick(t, 150);
    expect(t.ballInLane, isFalse);
    expect(t.ballNumber, 1);
    expect(t.events.where((e) => e.kind == PinballEventKind.launch).length, 2);
  });
  test('Kern-Auswurf zeigt seitwärts, nicht zwischen die Flipper', () {
    final s = cityTable.saucers.first;
    expect(s.ex, greaterThan(3));
    expect(s.ey, greaterThan(0));
  });

  for (final id in ['links', 'rechts']) {
    test('$id: A mit C und Inlane bis zur eigenen Flipperfläche', () {
      final t = PinballTable(rng: Random(1), spec: cityTable),
          r = cityTable.ramps.firstWhere((r) => r.id == id);
      t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .4, 0, -12);
      var entered = false, exited = false, contact = false;
      for (var i = 0; i < 1200; i++) {
        t.step(1 / 120);
        entered |= t.balls.any((b) => b.ramp?.spec.id == id);
        exited |= entered && t.balls.any((b) => b.body != null);
        contact |= exited && frontContact(t, id == 'links');
        if (contact) break;
      }
      expect(entered, isTrue);
      expect(exited, isTrue);
      expect(contact, isTrue);
    });
  }
  test('Einweg-Klappe unter der Abschussbrücke verhindert Rücklauf', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.debugPlaceBall(4.6, 8, 0, 0);
    t.step(1 / 120);
    expect(t.gateClosed, isTrue);
    t.debugPlaceBall(9.0, 2.5, 6, 0);
    var maximum = 0.0;
    for (var i = 0; i < 60; i++) {
      t.step(1 / 120);
      for (final b in t.balls) {
        if (b.body != null) maximum = max(maximum, b.body!.position.x);
      }
    }
    expect(maximum, lessThan(9.1));
  });
  for (var m = 0; m < 8; m++) {
    test('Modus $m startet über den physischen Kern-Einlass in der Engine', () {
      final t = PinballTable(rng: Random(1), spec: cityTable);
      t.city!.nextMode = m;
      core(t);
      expect(t.city!.active, m);
      expect(t.city!.hologramUntil, greaterThan(t.city!.clock));
    });
  }
}
