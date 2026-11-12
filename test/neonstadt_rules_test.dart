import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/neonstadt_rules.dart';

NeonstadtRules start(int mode) {
  final r = NeonstadtRules()..nextMode = mode;
  r.hit('shot', 'kern');
  expect(r.active, mode);
  expect(r.remaining, mode == 7 ? 30 : 45);
  expect(r.hologramUntil, greaterThan(r.clock));
  return r;
}

void complete(NeonstadtRules r, int mode) {
  switch (mode) {
    case 0:
      for (final s in ['links', 'rechts', 'links', 'rechts']) {
        r.hit('shot', s);
      }
      break;
    case 1:
      r.hit('shot', 'links_innen');
      for (var i = 0; i < 20; i++) {
        r.hit('bumper');
      }
      break;
    case 2:
      r.hit('bank', 'links');
      r.hit('bank', 'rechts');
      break;
    case 3:
      for (var i = 0; i < 3; i++) {
        r.tick(4);
        r.hit('shot', r.movingShot);
      }
      break;
    case 5:
      for (var i = 0; i < 3; i++) {
        r.tick(4);
        r.hit('shot', r.movingShot);
      }
      break;
    case 4:
      for (final s in NeonstadtRules.shots) {
        r.hit('shot', s);
      }
      break;
    case 6:
      for (var i = 0; i < 3; i++) {
        r.hit('shot', 'links');
        r.tick(1);
        r.hit('shot', 'rechts');
      }
      break;
    case 7:
      r.hit('shot', 'links');
      r.hit('shot', 'rechts');
      r.tick(30);
      break;
  }
}

void main() {
  for (var mode = 0; mode < 8; mode++) {
    test(
      '${NeonstadtRules.titles[mode]} startet am Kern und ist abschließbar',
      () {
        final r = start(mode);
        complete(r, mode);
        expect(r.completed, contains(mode));
        expect(r.active, isNull);
      },
    );
  }
  test('Datenraub verlangt wirklich links/rechts im Wechsel', () {
    final r = start(0);
    r.hit('shot', 'rechts');
    expect(r.progress, 1);
    r.hit('shot', 'rechts');
    expect(r.progress, 1);
    r.hit('shot', 'links');
    expect(r.progress, 2);
  });
  test('Zeitüberschreitung, Wiederholung und wanderndes Licht', () {
    final r = start(3);
    expect(r.movingShot, 'umlauf_links');
    r.tick(4);
    expect(r.movingShot, 'links');
    r.hit('shot', 'umlauf_links');
    expect(r.progress, 0);
    r.tick(41);
    expect(r.active, isNull);
    expect(r.completed, isEmpty);
    r.hit('shot', 'kern');
    expect(r.active, 3);
  });
  test(
    'Stromausfall schaltet Feldlicht ab und zählt nur beleuchtete Schüsse',
    () {
      final r = start(5);
      expect(r.blackout, isTrue);
      r.hit('shot', 'rechts');
      expect(r.progress, 0);
      complete(r, 5);
      expect(r.blackout, isFalse);
    },
  );
  test('Datenupload: drei Locks, A-Jackpots und Kern-Super-Jackpot', () {
    final r = NeonstadtRules();
    for (var i = 0; i < 3; i++) {
      r.hit('shot', 'kern');
    }
    expect(r.multiball, 'Datenupload');
    expect(r.serve, 2);
    expect(r.locks, 0);
    r.hit('shot', 'links_innen');
    expect(r.jackpots, 0);
    for (var i = 0; i < 3; i++) {
      r.hit('shot', 'links');
    }
    expect(r.superLit, isTrue);
    final before = r.points;
    r.hit('shot', 'kern');
    expect(r.points - before, 100000);
    expect(r.superLit, isFalse);
  });
  test('Zielbank-Alarm: beide Bänke, zwei Kugeln, nur B-Jackpots', () {
    final r = NeonstadtRules();
    r.hit('bank', 'links');
    expect(r.multiball, isEmpty);
    r.hit('bank', 'rechts');
    expect(r.multiball, 'Zielbank-Alarm');
    expect(r.serve, 1);
    r.hit('shot', 'links');
    expect(r.jackpots, 0);
    r.hit('shot', 'links_innen');
    expect(r.jackpots, 1);
  });
  test('Beide Kombos haben drei Sekunden und steigenden Bonus', () {
    final r = NeonstadtRules();
    r.hit('shot', 'links');
    r.tick(3);
    r.hit('shot', 'rechts');
    expect(r.points, 2000);
    r.hit('shot', 'links_innen');
    r.tick(2);
    r.hit('shot', 'rechts_innen');
    expect(r.points, 6000);
    r.hit('shot', 'links');
    r.tick(3.01);
    r.hit('shot', 'rechts');
    expect(r.comboCount, 2);
  });
  test(
    'Extra-Kugel nach zehn B-Treffern leuchtet und wird am Kern abgeholt',
    () {
      final r = NeonstadtRules();
      for (var i = 0; i < 10; i++) {
        r.hit('shot', 'links_innen');
      }
      expect(r.extraLit, isTrue);
      expect(r.extras, 0);
      r.hit('shot', 'kern');
      expect(r.extras, 1);
      for (var i = 0; i < 10; i++) {
        r.hit('shot', 'links_innen');
      }
      expect(r.extraLit, isFalse);
    },
  );
  test('Extra-Kugel nach drei abgeschlossenen Modi', () {
    final r = NeonstadtRules();
    for (var m = 0; m < 3; m++) {
      r.nextMode = m;
      r.hit('shot', 'kern');
      complete(r, m);
    }
    expect(r.completed.length, 3);
    expect(r.extraLit, isTrue);
  });
  test('Alle acht Modi schalten Systemabsturz mit vier Kugeln frei', () {
    final r = NeonstadtRules();
    for (var m = 0; m < 8; m++) {
      r.endMultiball();
      r.nextMode = m;
      r.hit('shot', 'kern');
      complete(r, m);
    }
    r.endMultiball();
    r.serve = 0;
    r.hit('shot', 'kern');
    expect(r.completed.length, 8);
    expect(r.wizard, isTrue);
    expect(r.serve, 3);
    expect(r.litShots.length, 9);
    final before = r.points;
    for (final s in NeonstadtRules.shots) {
      r.hit('shot', s);
    }
    expect(r.jackpots, 7);
    expect(r.points - before, greaterThanOrEqualTo(175000));
    r.hit('target', 'links');
    r.hit('target', 'rechts');
    expect(r.jackpots, 9);
  });
  test('Neonrennen steigert Punkte je Rampe und endet nach 30 Sekunden', () {
    final r = start(7);
    final before = r.points;
    r.hit('shot', 'links');
    expect(r.points - before, 1000);
    r.hit('shot', 'links');
    expect(r.points - before, 3000);
    r.tick(29.9);
    expect(r.active, 7);
    r.tick(.1);
    expect(r.completed, contains(7));
  });
}
