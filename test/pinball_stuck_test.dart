import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';

/// Sucht Stellen bei den Flippern, an denen die Kugel liegen bleibt.
void main() {
  test('Kugel bleibt bei den Flippern nicht hängen', () {
    final stuck = <String>[];
    for (var trial = 0; trial < 900; trial++) {
      final rng = Random(trial);
      final t = PinballTable(rng: rng);
      t.launch();
      // Start über den Schleudern und unter den Pilzen
      t.debugPlaceBall(0.5 + rng.nextDouble() * 8.4, 9.4 + rng.nextDouble() * 1.9, (rng.nextDouble() - 0.5) * 8, rng.nextDouble() * 4);
      final mode = trial % 3;
      var hold = 0.0;
      var left = true;
      var slow = 0.0;
      for (var i = 0; i < 120 * 8 && t.ball != null && !t.ballInLane; i++) {
        final b = t.ball!;
        if (mode == 1 && b.y > 14.2 && b.x > 2.2 && b.x < 7.0 && hold <= 0) {
          hold = 0.14;
          left = b.x < 4.6;
        }
        if (mode == 2 && hold <= -0.3 && rng.nextDouble() < 0.02) {
          hold = 0.2 + rng.nextDouble() * 1.2;
          left = rng.nextBool();
        }
        hold -= 1 / 120;
        t.leftPressed = hold > 0 && left;
        t.rightPressed = hold > 0 && !left;
        t.step(1 / 120);
        final nb = t.ball;
        if (nb == null) break;
        final v = t.ballSpeed;
        if (v < 0.25 && nb.y > 12 && !t.leftPressed && !t.rightPressed) {
          slow += 1 / 120;
        } else {
          slow = 0;
        }
        if (slow > 1.5) {
          stuck.add('Versuch $trial Modus $mode: (${nb.x.toStringAsFixed(2)}, ${nb.y.toStringAsFixed(2)}) '
              'Winkel ${t.leftAngle.toStringAsFixed(2)} / ${t.rightAngle.toStringAsFixed(2)}');
          break;
        }
      }
    }
    // ignore: avoid_print
    for (final s in stuck.take(40)) print(s);
    expect(stuck, isEmpty, reason: '${stuck.length} Kugeln hängen fest');
  });
}
