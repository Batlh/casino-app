import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/backgammon/bg_engine.dart';
import 'package:gluckspfennig/games/kniffel/kniffel_engine.dart';
import 'package:gluckspfennig/games/madn/madn_engine.dart';

/// Würfelspiele im Netz: Mit demselben Startwert und denselben Zügen würfeln alle Geräte dasselbe.
void main() {
  test('Kniffel: zwei Geräte, gleiche Würfe', () {
    final a = KniffelGame(3, rng: Random(9));
    final b = KniffelGame(3, rng: Random(9));
    while (!a.over) {
      while (!a.rolled || (!a.botStop() && a.rollsLeft > 0)) {
        if (a.rolled) {
          a.held = a.botHolds();
          b.held = [...a.held];
        }
        a.roll();
        b.roll();
        expect(b.dice, a.dice);
      }
      final cat = a.botCategory();
      a.score(cat);
      b.score(cat);
    }
    expect([for (var p = 0; p < 3; p++) b.total(p)], [for (var p = 0; p < 3; p++) a.total(p)]);
  });

  test('Mensch ärgere dich nicht: zwei Geräte, gleiche Partie', () {
    final a = MadnGame(4, rng: Random(3));
    final b = MadnGame(4, rng: Random(3));
    var steps = 0;
    while (a.phase != MadnPhase.over && steps < 5000) {
      if (a.phase == MadnPhase.roll) {
        expect(b.roll(), a.roll());
      } else {
        final k = a.botChoice();
        a.move(k);
        b.move(k);
      }
      expect(b.pieces.toString(), a.pieces.toString());
      expect(b.current, a.current);
      steps++;
    }
    expect(a.phase, MadnPhase.over);
    expect(b.winner, a.winner);
  });

  test('Backgammon: gleicher Startwert, jeder Zug einmal gewürfelt, gleiche Partie', () {
    final a = BgGame(rng: Random(12))..start();
    final b = BgGame(rng: Random(12))..start();
    expect(b.dice, a.dice);
    expect(b.current, a.current);
    final rng = Random(1);
    var turns = 0;
    while (!a.over && turns < 500) {
      if (!a.rolled) a.roll();
      if (!b.rolled) b.roll();
      expect(b.dice, a.dice, reason: 'Zug $turns');
      final seqs = a.sequences();
      final seq = seqs.isEmpty ? const <BgStep>[] : seqs[rng.nextInt(seqs.length)];
      for (final st in seq) {
        a.apply(st);
        b.apply(b.stepFor(st.from, st.die)!);
      }
      if (!a.over) {
        a.endTurn();
        b.endTurn();
      }
      expect(b.pips(0), a.pips(0));
      expect(b.pips(1), a.pips(1));
      turns++;
    }
    expect(a.over, isTrue);
    expect(b.winner, a.winner);
  });
}
