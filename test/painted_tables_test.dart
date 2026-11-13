import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/painted_tables.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';

/// Für jeden gemalten Tisch: Jede Rampe bzw. Umlaufbahn und jedes Loch wird
/// beim Spielen mit einfachen Flipperschlägen mindestens einmal getroffen.
void main() {
  for (final spec in paintedTables) {
    test('${spec.name}: alle Rampen und Löcher sind erreichbar', () {
      final hits = {
        for (final r in spec.ramps)
          if (!r.id.startsWith('_')) r.id: 0,
      };
      var saucers = 0;
      var drops = 0;
      var bumpers = 0;
      final ends = <String, int>{};
      for (var trial = 0; trial < 300; trial++) {
        final rng = Random(1000 + trial);
        final t = PinballTable(rng: rng, spec: spec);
        t.charge = 0.3 + rng.nextDouble() * 0.7;
        t.launch();
        var hold = 0.0;
        var rest = 0.0;
        var left = true;
        final timing = 0.08 + rng.nextDouble() * 0.3;
        for (var i = 0; i < 120 * 20 && !t.gameOver; i++) {
          final p = t.ball;
          if (p == null) break;
          if (p.y > spec.flippers.first.pivot.y - 1.0 - timing &&
              p.x > 2.0 &&
              p.x < 7.2 &&
              hold <= 0 &&
              rest <= 0) {
            hold = 0.12 + rng.nextDouble() * 0.2;
            rest = hold + 0.35;
            left = p.x < 4.6;
          }
          hold -= 1 / 120;
          rest -= 1 / 120;
          t.leftPressed = hold > 0 && left;
          t.rightPressed = hold > 0 && !left;
          t.step(1 / 120);
          for (final e in t.events) {
            if (e.kind == PinballEventKind.ramp) {
              for (final r in spec.ramps) {
                if (r.name == e.text && hits.containsKey(r.id)) {
                  hits[r.id] = hits[r.id]! + 1;
                }
              }
            }
            if (e.kind == PinballEventKind.saucer) saucers++;
            if (e.kind == PinballEventKind.drop) drops++;
            if (e.kind == PinballEventKind.bumper) bumpers++;
          }
          t.events.clear();
          if (t.ballInLane) break;
        }
        final q = t.ball;
        if (q != null && !t.gameOver) {
          final key = '(${q.x.toStringAsFixed(0)},${q.y.toStringAsFixed(0)})';
          ends[key] = (ends[key] ?? 0) + 1;
        }
      }
      final top = ends.entries.toList()..sort((a, b) => b.value - a.value);
      // ignore: avoid_print
      print('${spec.name}: Kugel nach 20 s noch bei ${top.take(6).map((e) => '${e.key}×${e.value}').join(' ')}');
      // ignore: avoid_print
      print(
        '${spec.name}: Rampen $hits, Löcher $saucers, Fallziele $drops, Bumper $bumpers',
      );
      for (final e in hits.entries) {
        expect(e.value, greaterThan(0), reason: '${e.key} nie getroffen');
      }
      if (spec.saucers.isNotEmpty) expect(saucers, greaterThan(0));
    });
  }
}
