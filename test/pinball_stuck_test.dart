import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

/// Sucht auf allen Tischen Stellen, an denen die Kugel liegen bleibt oder durch eine Bande rutscht.
void main() {
  for (final spec in pinballTables) {
    test('${spec.name}: Kugel bleibt nicht hängen und bleibt im Tisch', () {
      final stuck = <String>[];
      final escaped = <String>[];
      var ramps = 0;
      var saucers = 0;
      var spinners = 0;
      for (var trial = 0; trial < 240; trial++) {
        final rng = Random(trial);
        final t = PinballTable(rng: rng, spec: spec);
        t.charge = 0.2 + rng.nextDouble() * 0.8;
        t.launch();
        if (trial.isOdd) {
          // Von oben fallen lassen statt abschießen
          for (var i = 0; i < 30; i++) {
            t.step(1 / 120);
          }
          final tops = [
            for (final l in spec.lanes)
              if (l.group == 'top') l,
          ];
          if (spec.theme.art.startsWith('painted') && tops.isNotEmpty) {
            final l = tops[rng.nextInt(tops.length)];
            t.debugPlaceBall(
              l.x + (rng.nextDouble() - 0.5) * 0.1,
              l.y + 0.7,
              (rng.nextDouble() - 0.5) * 3,
              0,
            );
          } else {
            t.debugPlaceBall(
              2.5 + rng.nextDouble() * 4,
              0.6 + rng.nextDouble() * 0.6,
              (rng.nextDouble() - 0.5) * 6,
              0,
            );
          }
        }
        final mode = trial % 3;
        var hold = 0.0;
        var left = true;
        var slow = 0.0;
        for (var i = 0; i < 120 * 12 && !t.gameOver; i++) {
          final p = t.ball;
          if (p == null) break;
          if (mode != 0 &&
              p.y > spec.flippers.first.pivot.y - 1.1 &&
              p.x > 2.2 &&
              p.x < 7.0 &&
              hold <= 0) {
            hold = mode == 1 ? 0.14 : 0.3;
            left = p.x < 4.6;
          }
          hold -= 1 / 120;
          t.leftPressed = hold > 0 && left;
          t.rightPressed = hold > 0 && !left;
          t.step(1 / 120);
          for (final e in t.events) {
            if (e.kind == PinballEventKind.ramp) ramps++;
            if (e.kind == PinballEventKind.saucer) saucers++;
            if (e.kind == PinballEventKind.spinner) spinners++;
          }
          t.events.clear();
          if (t.ballInLane) break;
          for (final b in t.balls) {
            final q = b.pos;
            if (b.body != null &&
                (q.x < -0.1 || q.x > PinballTable.width + 0.1 || q.y < -0.1)) {
              escaped.add(
                'Versuch $trial: (${q.x.toStringAsFixed(2)}, ${q.y.toStringAsFixed(2)})',
              );
            }
          }
          final first = t.balls.isEmpty ? null : t.balls.first;
          final body = first?.body;
          if (body != null &&
              t.ballSpeed < 0.25 &&
              !t.leftPressed &&
              !t.rightPressed &&
              body.position.x < PinballTable.fieldRight) {
            slow += 1 / 120;
          } else {
            slow = 0;
          }
          if (slow > 1.5) {
            stuck.add(
              'Versuch $trial Modus $mode: (${p.x.toStringAsFixed(2)}, ${p.y.toStringAsFixed(2)})',
            );
            break;
          }
        }
      }
      // ignore: avoid_print
      print(
        '${spec.name}: Rampen $ramps, Löcher $saucers, Spinner $spinners, hängen ${stuck.length}, raus ${escaped.length}',
      );
      // ignore: avoid_print
      for (final s in [...stuck.take(15), ...escaped.take(10)]) print(s);
      expect(escaped, isEmpty, reason: '${escaped.length} Kugeln außerhalb');
      expect(stuck, isEmpty, reason: '${stuck.length} Kugeln hängen fest');
    });
  }
}
