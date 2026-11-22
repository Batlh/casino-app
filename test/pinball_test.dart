import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';

void run(PinballTable t, double seconds, {void Function(double time)? each}) {
  var time = 0.0;
  while (time < seconds) {
    each?.call(time);
    t.step(1 / 120);
    time += 1 / 120;
  }
}

void main() {
  test('Kugel liegt zu Beginn in der Bahn und steigt beim Abschuss nach oben', () {
    final t = PinballTable(rng: Random(1));
    run(t, 0.5);
    expect(t.ballInLane, isTrue);
    expect(t.ball!.y, greaterThan(17));
    t.charge = 1;
    t.launch();
    var top = 99.0;
    run(t, 1.5, each: (_) => top = min(top, t.ball?.y ?? top));
    expect(top, lessThan(3), reason: 'Volle Feder bringt die Kugel bis oben');
    expect(t.ballInLane, isFalse);
  });

  test('Kurzer Tipper zwischen zwei Schritten hebt den Flipper trotzdem', () {
    final t = PinballTable(rng: Random(2));
    run(t, 0.3);
    final restL = t.leftAngle;
    final restR = t.rightAngle;
    t.press(left: true, down: true);
    t.press(left: true, down: false);
    t.press(left: false, down: true);
    t.press(left: false, down: false);
    var minL = restL, maxR = restR;
    run(t, 0.12, each: (_) {
      minL = min(minL, t.leftAngle);
      maxR = max(maxR, t.rightAngle);
    });
    expect(minL, lessThan(restL - 0.5), reason: 'Links schlägt aus');
    expect(maxR, greaterThan(restR + 0.5), reason: 'Rechts schlägt aus');
    run(t, 0.4);
    expect((t.leftAngle - restL).abs(), lessThan(0.1));
  });

  test('Abschuss gehalten, bevor die Kugel liegt, spannt danach die Feder', () {
    final t = PinballTable(rng: Random(1));
    run(t, 0.5);
    t.ballInLane = false;
    t.plungerHeld = true;
    run(t, 0.1);
    expect(t.charging, isFalse);
    t.ballInLane = true;
    run(t, 0.3);
    expect(t.charging, isTrue);
    expect(t.charge, greaterThan(0.2));
    t.plungerHeld = false;
    t.launch();
    expect(t.ballInLane, isFalse);
  });

  test('Flipper schwingen hoch und wieder herunter', () {
    final t = PinballTable(rng: Random(2));
    run(t, 0.3);
    final restL = t.leftAngle;
    final restR = t.rightAngle;
    t.leftPressed = true;
    t.rightPressed = true;
    run(t, 0.15);
    expect(t.leftAngle, lessThan(restL - 0.6), reason: 'Links hebt sich');
    expect(t.rightAngle, greaterThan(restR + 0.6), reason: 'Rechts hebt sich');
    t.leftPressed = false;
    t.rightPressed = false;
    run(t, 0.3);
    expect((t.leftAngle - restL).abs(), lessThan(0.1));
    expect((t.rightAngle - restR).abs(), lessThan(0.1));
  });

  test('Ohne Flippern geht die Kugel verloren, nach drei Kugeln ist Schluss', () {
    final t = PinballTable(rng: Random(3));
    var seconds = 0.0;
    while (!t.gameOver && seconds < 300) {
      if (t.ballInLane) {
        t.charge = 0.8;
        t.launch();
      }
      run(t, 0.5);
      seconds += 0.5;
      for (final e in t.events) {
        expect(e.points, greaterThanOrEqualTo(0));
      }
      t.events.clear();
    }
    expect(t.gameOver, isTrue);
    expect(t.ballsLeft, 0);
  });

  test('Wildes Flippern: Punkte steigen, keine Kugel fliegt aus dem Tisch', () {
    for (var seed = 0; seed < 8; seed++) {
      final rng = Random(seed);
      final t = PinballTable(rng: rng);
      var seconds = 0.0;
      var hold = 0.0;
      var left = true;
      while (!t.gameOver && seconds < 240) {
        if (t.ballInLane) {
          t.charge = 0.4 + rng.nextDouble() * 0.6;
          t.launch();
        }
        run(t, 0.1, each: (_) {
          final b = t.ball;
          // Kurz antippen, wenn die Kugel von oben auf die Flipper fällt
          if (b != null && b.y > 14.2 && b.x > 2.2 && b.x < 7.0 && hold <= 0) {
            hold = 0.14;
            left = b.x < 4.6;
          }
          hold -= 1 / 120;
          t.leftPressed = hold > 0 && left;
          t.rightPressed = hold > 0 && !left;
          if (b != null) {
            expect(b.x, inInclusiveRange(-0.5, PinballTable.width + 0.5));
            expect(b.y, greaterThan(-0.5));
          }
        });
        seconds += 0.1;
        t.events.clear();
      }
      expect(t.score, greaterThan(0), reason: 'Seed $seed');
    }
  });

  test('Klappe: Kugel rollt nicht zurück in die Abschussbahn', () {
    for (var seed = 0; seed < 6; seed++) {
      final rng = Random(seed + 40);
      final t = PinballTable(rng: rng);
      var seconds = 0.0;
      var closedSeen = false;
      while (!t.gameOver && seconds < 200) {
        if (t.ballInLane) {
          t.charge = 0.3 + rng.nextDouble() * 0.7;
          t.launch();
        }
        run(t, 0.1, each: (_) {
          final b = t.ball;
          t.leftPressed = b != null && b.y > 14.4 && b.x < 4.6;
          t.rightPressed = b != null && b.y > 14.4 && b.x >= 4.6;
          if (t.gateClosed) {
            closedSeen = true;
            expect(b == null || b.x < PinballTable.fieldRight + 0.05, isTrue, reason: 'seed $seed: Kugel in der Bahn bei x ${b?.x}, y ${b?.y}');
          }
        });
        seconds += 0.1;
      }
      expect(closedSeen, isTrue);
    }
  });
}
