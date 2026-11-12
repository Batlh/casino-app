import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

void main() {
  test('Genau L1–L4 und R1–R5; keine zusätzliche linke Bahn', () {
    final ids = cityTable.ramps.map((r) => r.id).toSet();
    expect(ids, {
      'umlauf_links',
      'links',
      'links_innen',
      'umlauf_rechts',
      'rechts',
      'rechts_innen',
      'skill_0',
      'skill_1',
      'skill_2',
    });
    // C ist die übergebene Fortsetzung von A; drei Skill-Ausläufe gehören zu einem R1.
    for (final id in ['links', 'rechts']) {
      final r = cityTable.ramps.firstWhere((r) => r.id == id);
      expect(r.wireStart, allOf(greaterThan(.2), lessThan(.8)));
      expect(r.deckWidth, greaterThan(1));
      expect(r.sideHeight, greaterThan(.4));
    }
    final l1 = cityTable.ramps.firstWhere((r) => r.id == 'umlauf_links');
    expect(l1.acrylicStart, greaterThan(0));
    expect(
      l1.heights.take(l1.acrylicStart + 1).every((h) => h.abs() < .001),
      isTrue,
    );
    expect(l1.heights.reduce(max), greaterThan(1));
  });
  for (final id in ['umlauf_links', 'umlauf_rechts']) {
    test('$id erreicht eine obere Gasse über seinen vollständigen Weg', () {
      final t = PinballTable(rng: Random(3), spec: cityTable),
          r = cityTable.ramps.firstWhere((r) => r.id == id);
      t.debugPlaceBall((r.a.x + r.b.x) / 2, r.a.y + .35, 0, -12);
      var entered = false, exited = false, lane = false;
      for (var i = 0; i < 1000; i++) {
        t.step(1 / 120);
        entered |= t.balls.any((b) => b.ramp?.spec.id == id);
        exited |= entered && t.balls.any((b) => b.body != null && b.pos.y < 1);
        lane |=
            exited && t.lanes.any((l) => l.spec.group == 'top' && l.flash > 0);
        if (lane) break;
      }
      expect(entered, isTrue);
      expect(exited, isTrue);
      expect(lane, isTrue);
    });
  }
  for (final side in ['links', 'rechts']) {
    test(
      '$side: drei getrennte Anschlüsse; schwaches A kehrt ins freie Feld zurück',
      () {
        final a = cityTable.ramps.firstWhere((r) => r.id == side),
            o = cityTable.ramps.firstWhere((r) => r.id == 'umlauf_$side');
        final ax = (a.a.x + a.b.x) / 2, ox = (o.a.x + o.b.x) / 2;
        expect(
          sqrt(pow(a.a.y - o.a.y, 2) + pow(ax - ox, 2)),
          greaterThan(PinballTable.ballRadius * 2),
        );
        expect(side == 'links' ? ox < ax : ox > ax, isTrue);
        expect((a.path.last.x - ax).abs(), greaterThan(.2));
        final t = PinballTable(rng: Random(1), spec: cityTable);
        t.debugPlaceBall(ax, a.a.y + .3, 0, -3);
        var wrong = false, returned = false;
        for (var i = 0; i < 130; i++) {
          t.step(1 / 120);
          wrong |= t.balls.any((b) => b.ramp != null);
          returned |= t.balls.any(
            (b) =>
                b.body != null &&
                b.pos.y > a.a.y + .6 &&
                b.body!.linearVelocity.y > 0 &&
                b.pos.x > .8 &&
                b.pos.x < 8.5,
          );
        }
        expect(wrong, isFalse);
        expect(returned, isTrue);
      },
    );
  }
  test('R1 wird bis zum großen Bogen durchgehend als Acryl gezeigt', () {
    final r = cityTable.ramps.firstWhere((r) => r.skillBand == 0);
    expect(r.renderEnd, greaterThan(20));
    final visible = r.path.take(r.renderEnd + 1).toList();
    expect(visible.map((p) => p.x).reduce(min), lessThan(6.9));
    expect(visible.map((p) => p.x).reduce(max), greaterThan(9.3));
    for (var i = 0; i < visible.length; i++)
      expect(visible[i].y - r.heights[i] * .42, greaterThanOrEqualTo(.19));
  });

  for (final id in ['links', 'rechts']) {
    test(
      '$id: C kreuzt A mit mehr als einem Kugeldurchmesser Höhenfreiheit',
      () {
        final spec = cityTable.ramps.firstWhere((r) => r.id == id),
            r = Ramp(spec);
        final end = r.at(r.length * spec.wireStart);
        var wire = 0, best = double.infinity;
        for (var i = 0; i < spec.path.length; i++) {
          final p = spec.path[i], d = pow(p.x - end.x, 2) + pow(p.y - end.y, 2);
          if (d < best) {
            best = d.toDouble();
            wire = i;
          }
        }
        double cross(double ax, double ay, double bx, double by) =>
            ax * by - ay * bx;
        var crossings = 0;
        for (var i = 0; i < wire - 7; i++)
          for (var j = wire + 7; j < spec.path.length - 1; j++) {
            final a = spec.path[i],
                b = spec.path[i + 1],
                c = spec.path[j],
                d = spec.path[j + 1];
            final dx = b.x - a.x,
                dy = b.y - a.y,
                ex = d.x - c.x,
                ey = d.y - c.y,
                den = cross(dx, dy, ex, ey);
            if (den.abs() < 1e-9) continue;
            final t = cross(c.x - a.x, c.y - a.y, ex, ey) / den,
                u = cross(c.x - a.x, c.y - a.y, dx, dy) / den;
            if (t <= 0 || t >= 1 || u <= 0 || u >= 1) continue;
            crossings++;
            final ah =
                    spec.heights[i] +
                    (spec.heights[i + 1] - spec.heights[i]) * t,
                ch =
                    spec.heights[j] +
                    (spec.heights[j + 1] - spec.heights[j]) * u;
            expect(ch - ah, greaterThan(PinballTable.ballRadius * 2 + .15));
          }
        expect(crossings, greaterThan(0));
      },
    );
  }
}
