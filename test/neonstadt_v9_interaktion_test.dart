import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';
import 'package:gluckspfennig/games/pinball/neonstadt_rules.dart';

void tick(PinballTable t, int n) {
  for (var i = 0; i < n; i++) t.step(1 / 120);
}

void lane(PinballTable t, LaneSpec l) {
  t.debugPlaceBall(l.x, l.y, 0, 1);
  t.step(1 / 120);
}

void main() {
  test('Sieben Hauptschüsse in der freigegebenen Reihenfolge', () {
    expect(NeonstadtRules.shots, [
      'umlauf_links',
      'links',
      'links_innen',
      'kern',
      'rechts_innen',
      'rechts',
      'umlauf_rechts',
    ]);
  });
  for (var mode = 0; mode < 8; mode++) {
    test(
      'Modus $mode: Pfeile entsprechen litShots einschließlich Blinkzustand',
      () {
        final r = NeonstadtRules()..nextMode = mode;
        r.hit('shot', 'kern');
        for (var k = 0; k < 7; k++) {
          for (final id in NeonstadtRules.shots)
            expect(
              r.shotState(id) != NeonstadtLamp.aus,
              r.litShots.contains(id),
            );
          if (mode == 3 || mode == 5)
            expect(r.shotState(r.movingShot), NeonstadtLamp.blinkend);
          r.tick(4);
        }
      },
    );
  }
  for (final pair in [
    ['umlauf_links', 'umlauf_rechts'],
    ['umlauf_rechts', 'umlauf_links'],
  ]) {
    test('Umlauf-Kombo ${pair.join(' → ')} und Drei-Sekunden-Grenze', () {
      final r = NeonstadtRules();
      r.hit('shot', pair[0]);
      expect(r.shotState(pair[1]), NeonstadtLamp.blinkend);
      r.tick(3);
      r.hit('shot', pair[1]);
      expect(r.comboCount, 1);
      expect(r.points, 2000);
      r.hit('shot', pair[0]);
      r.tick(3.01);
      r.hit('shot', pair[1]);
      expect(r.comboCount, 2);
    });
  }
  test('Netzrundlauf braucht alle sieben; fünf alte Schüsse genügen nicht', () {
    final r = NeonstadtRules()..nextMode = 4;
    r.hit('shot', 'kern');
    for (final id in ['links', 'rechts', 'links_innen', 'rechts_innen', 'kern'])
      r.hit('shot', id);
    expect(r.progress, 5);
    expect(r.active, 4);
    r.hit('shot', 'umlauf_links');
    expect(r.active, 4);
    r.hit('shot', 'umlauf_rechts');
    expect(r.completed, contains(4));
  });
  test('Überlastung zählt Umlauf +3, B +5 und Bumper +1', () {
    final r = NeonstadtRules()..nextMode = 1;
    r.hit('shot', 'kern');
    r.hit('shot', 'umlauf_links');
    expect(r.progress, 3);
    r.hit('shot', 'umlauf_rechts');
    expect(r.progress, 6);
    r.hit('shot', 'links_innen');
    expect(r.progress, 11);
    r.hit('bumper');
    expect(r.progress, 12);
  });
  test('Stromausfall wandert in 28 s über alle sieben Schüsse', () {
    final r = NeonstadtRules()..nextMode = 5;
    r.hit('shot', 'kern');
    final seen = <String>{};
    for (var i = 0; i < 7; i++) {
      seen.add(r.movingShot);
      r.tick(4);
    }
    expect(seen, NeonstadtRules.shots.toSet());
  });
  test('Multiball-Jackpot bleibt während eines anderen Modus beleuchtet', () {
    final r = NeonstadtRules()..nextMode = 3;
    r.hit('shot', 'kern');
    r.hit('shot', 'kern');
    r.hit('shot', 'kern');
    expect(r.multiball, 'Datenupload');
    expect(r.litShots, containsAll(['links', 'rechts']));
    r.hit('shot', 'links');
    expect(r.hologramUntil, greaterThan(r.clock));
    expect(r.sideWallUntil, greaterThan(r.clock));
  });
  test('Vier untere Gassen erhöhen den Bonus, obere nur die Bumper-Stufe', () {
    final t = PinballTable(rng: Random(2), spec: cityTable);
    final lower = cityTable.lanes.where((l) => l.group != 'top').toList();
    for (final l in lower.take(3)) lane(t, l);
    expect(t.multiplier, 1);
    expect(t.lanes.where((l) => l.spec.group != 'top' && l.lit).length, 3);
    lane(t, lower.last);
    expect(t.multiplier, 2);
    expect(t.cityBumperLevel, 1);
    for (final l in cityTable.lanes.where((l) => l.group == 'top')) lane(t, l);
    expect(t.cityBumperLevel, 2);
    expect(t.multiplier, 2);
  });
  test('Beide Gassengruppen wechseln mit den Flippertasten', () {
    final t = PinballTable(rng: Random(2), spec: cityTable);
    final lower = t.lanes.where((l) => l.spec.group != 'top').toList(),
        top = t.lanes.where((l) => l.spec.group == 'top').toList();
    lower[0].lit = true;
    top[0].lit = true;
    t.rightPressed = true;
    t.step(1 / 120);
    expect(lower[1].lit, isTrue);
    expect(top[1].lit, isTrue);
    t.rightPressed = false;
    t.step(1 / 120);
    t.leftPressed = true;
    t.step(1 / 120);
    expect(lower[0].lit, isTrue);
    expect(top[0].lit, isTrue);
  });
  test('Bonus am Kugelende zählt tatsächliche Treffer mal Multiplikator', () {
    final t = PinballTable(rng: Random(2), spec: cityTable);
    for (final l in cityTable.lanes.where((l) => l.group != 'top')) lane(t, l);
    final hits = t.cityBonusHits, mult = t.multiplier, score = t.score;
    expect(hits, 4);
    expect(mult, 2);
    t.debugPlaceBall(4.625, 18.25, 0, 3);
    tick(t, 10);
    expect(t.cityLastBonus, hits * mult);
    expect(t.score - score, t.cityLastBonus);
    expect(t.cityBonusText, contains('$hits TREFFER'));
    expect(t.cityBonusVisible, isTrue);
    expect(t.multiplier, 1);
  });
  test('Entladener Kickback lässt die Kugel ablaufen', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.city!.kickbackLit = false;
    t.debugPlaceBall(.53, 15.65, 0, 3);
    tick(t, 180);
    expect(t.ballsLeft, 2);
    expect(t.events.where((e) => e.kind == PinballEventKind.saved), isEmpty);
  });
  test('Kickback zeigt Schlag und Wandblitz, beide Inlanes laden nach', () {
    final t = PinballTable(rng: Random(1), spec: cityTable);
    t.debugPlaceBall(.53, 15.65, 0, 3);
    t.step(1 / 120);
    expect(t.cityKickbackFlash, greaterThan(.9));
    expect(t.city!.sideWallUntil, greaterThan(t.city!.clock));
    for (final l in cityTable.lanes.where((l) => l.group.startsWith('inlane_')))
      lane(t, l);
    expect(t.city!.kickbackLit, isTrue);
  });
  test('Bank-Einzelziele bleiben an und die volle Bank blinkt', () {
    final t = PinballTable(rng: Random(1), spec: cityTable),
        bank = cityTable.targets.first;
    for (var i = 0; i < 3; i++) {
      final p = bank.targets[i], nx = -sin(bank.angle), ny = cos(bank.angle);
      t.debugPlaceBall(p.x + nx * .55, p.y + ny * .55, -nx * 4, -ny * 4);
      tick(t, 20);
      expect(
        t.targetBanks.first.targets.take(i + 1).every((t) => t.lit),
        isTrue,
      );
      tick(t, 40);
    }
    expect(t.targetBanks.first.completedUntil, greaterThan(t.city!.clock));
  });
  for (final id in ['links', 'rechts']) {
    test('$id zählt genau einmal am blauen Drahtschalter, vor dem Auslauf', () {
      final t = PinballTable(rng: Random(1), spec: cityTable),
          r = cityTable.ramps.firstWhere((r) => r.id == id);
      t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .4, 0, -12);
      var countedOnWire = false;
      for (var i = 0; i < 900; i++) {
        t.step(1 / 120);
        if (t.events.any(
          (e) =>
              e.kind == PinballEventKind.ramp &&
              e.text.contains('Drahtschalter'),
        )) {
          countedOnWire |= t.balls.any((b) => b.ramp?.spec.id == id);
        }
        if (countedOnWire && t.balls.any((b) => b.body != null)) break;
      }
      expect(countedOnWire, isTrue);
      expect(
        t.events
            .where(
              (e) =>
                  e.kind == PinballEventKind.ramp &&
                  e.text.contains('Drahtschalter'),
            )
            .length,
        1,
      );
    });
  }

  test(
    'Spezial nach viertem Modus gilt 20 s und wird rechts einmal ausgezahlt',
    () {
      final r = NeonstadtRules()
        ..completed.addAll([0, 1, 2])
        ..nextMode = 3;
      r.hit('shot', 'kern');
      for (var i = 0; i < 3; i++) {
        r.tick(4);
        r.hit('shot', r.movingShot);
      }
      expect(r.completed.length, 4);
      expect(r.specialLit, isTrue);
      final before = r.points;
      r.hit('lane', 'outlane_rechts');
      expect(r.points - before, 50000);
      expect(r.specialLit, isFalse);
      r.hit('lane', 'outlane_rechts');
      expect(r.points - before, 50000);
      r.specialUntil = r.clock + 20;
      r.tick(20);
      expect(r.specialLit, isFalse);
    },
  );
  test('Gassenstufen sind jeweils bei fünf gedeckelt', () {
    final t = PinballTable(rng: Random(5), spec: cityTable);
    for (var n = 0; n < 6; n++) {
      for (final l in cityTable.lanes.where((l) => l.group != 'top'))
        lane(t, l);
      for (final l in cityTable.lanes.where((l) => l.group == 'top'))
        lane(t, l);
      t.debugPlaceBall(4.6, 10, 0, 0);
      tick(t, 60);
    }
    expect(t.multiplier, 5);
    expect(t.cityBumperLevel, 5);
  });
  test(
    'Bonus bleibt auch nach der letzten Kugel sichtbar und läuft dann aus',
    () {
      final t = PinballTable(rng: Random(5), spec: cityTable);
      t.ballsLeft = 1;
      lane(t, cityTable.lanes[3]);
      t.debugPlaceBall(4.625, 18.25, 0, 3);
      tick(t, 10);
      expect(t.gameOver, isTrue);
      expect(t.cityBonusVisible, isTrue);
      tick(t, 370);
      expect(t.cityBonusVisible, isFalse);
    },
  );

  test('Neonrennen-Regelbonus verdoppelt nicht die physische Trefferzahl', () {
    final t = PinballTable(rng: Random(1), spec: cityTable),
        r = cityTable.ramps.firstWhere((r) => r.id == 'links');
    t.city!.nextMode = 7;
    t.city!.hit('shot', 'kern');
    t.step(1 / 120);
    t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .4, 0, -12);
    for (var i = 0; i < 800; i++) {
      t.step(1 / 120);
      if (t.events.any((e) => e.text.contains('Neonrennen · Rampe'))) break;
    }
    expect(t.events.any((e) => e.text.contains('Neonrennen · Rampe')), isTrue);
    expect(t.cityBonusHits, 1);
  });
}
