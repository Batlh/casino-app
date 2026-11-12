import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pinball/pinball_table.dart';
import 'package:gluckspfennig/games/pinball/pinball_tables.dart';

void main() {
  test('9,95 × 18; Bumper, Sockel und Bänke entsprechen Freigabe A', () {
    expect(cityTable.playfieldHeight, 18);
    final expected = [
      [.54, .08],
      [.42, .14],
      [.65, .15],
    ];
    for (var i = 0; i < 3; i++) {
      expect(cityTable.bumpers[i].x, closeTo(expected[i][0] * 9.95, .00001));
      expect(cityTable.bumpers[i].y, closeTo(expected[i][1] * 14.04, .00001));
    }
    expect(cityTable.saucers.first.x, closeTo(.53 * 9.95, .00001));
    for (var i = 0; i < 2; i++) {
      expect(
        cityTable.targets[i].targets[1].x,
        closeTo([.26, .81][i] * 9.95, .00001),
      );
      expect(cityTable.targets[i].targets[1].y, closeTo(.30 * 14.04, .00001));
    }
    final socketTop = .27 * 14.04 - .6;
    for (final b in cityTable.bumpers) {
      expect(b.y + b.radius, lessThan(socketTop));
    }
  });
  test('Flipperarme unverändert; Spitzenspalt wie beim klassischen Tisch', () {
    final f = cityTable.flippers;
    for (final a in f) {
      expect(a.length, 1.85);
      expect(a.heelHalfWidth, .25);
      expect(a.tipHalfWidth, .10);
      expect(a.rest, .36);
      expect(a.up, -.47);
    }
    final gap = f[1].pivot.x - f[0].pivot.x - 2 * 1.85 * cos(.36);
    final ref = neonNightTable.flippers;
    final classic =
        ref[1].pivot.x - ref[0].pivot.x - 2 * ref[0].length * cos(ref[0].rest);
    expect(gap, closeTo(classic, .00001));
  });
  test(
    'Alle Rampen: stetige bodengleiche Übergaben und passierbare Breite',
    () {
      for (final spec in cityTable.ramps) {
        final r = Ramp(spec);
        expect(spec.heights.length, spec.path.length);
        expect(r.heightAt(0), 0);
        expect(r.heightAt(r.length), spec.id.endsWith('_innen') ? .85 : 0);
        expect(spec.deckWidth, greaterThan(PinballTable.ballRadius * 2 + .15));
        expect(spec.path.first.x, closeTo((spec.a.x + spec.b.x) / 2, .001));
        expect(spec.path.first.y, spec.a.y);
      }
    },
  );
  for (final id in ['links', 'rechts']) {
    test('$id: Übergabe A → C liegt am oberen Rampenkopf', () {
      final s = cityTable.ramps.firstWhere((r) => r.id == id), r = Ramp(s);
      final p = r.at(r.length * s.wireStart);
      expect(p.y - r.heightAt(r.length * s.wireStart) * .42, closeTo(2.26955596, .002));
      expect(r.heightAt(r.length * s.wireStart), greaterThan(1));
      expect(s.path.last.y, closeTo(12.00914079, .002));
      expect(r.heightAt(r.length), 0);
    });
  }
}
