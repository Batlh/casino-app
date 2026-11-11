import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/ladder/ladder_engine.dart';
import 'package:gluckspfennig/games/madn/madn_engine.dart';
import 'package:gluckspfennig/games/memory/memory_engine.dart';
import 'package:gluckspfennig/games/reversi/reversi_engine.dart';

Map<String, dynamic> viaJson(Map<String, Object?> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void main() {
  group('Leiterspiel', () {
    test('Klassisches Brett: Leitern hoch, Schlangen runter, zurückprallen', () {
      final g = LadderGame(2, rng: Random(1));
      final m = g.roll(1);
      expect(m.ladder, isTrue);
      expect(g.positions[0], 38);
      g.positions[1] = 97;
      final b = g.roll(5);
      expect(b.bounced, isTrue);
      expect(b.landed, 98);
      expect(g.positions[1], 78, reason: '98 ist eine Schlange');
    });

    test('Zufällige Bretter sind gültig und Partien enden', () {
      for (var seed = 0; seed < 40; seed++) {
        final rng = Random(seed);
        final jumps = LadderGame.randomJumps(rng);
        expect(jumps.length, 16);
        for (final e in jumps.entries) {
          expect(e.key, inInclusiveRange(2, 99));
          expect(e.value, inInclusiveRange(2, 99));
          expect(jumps.containsKey(e.value), isFalse, reason: 'keine Ketten');
        }
        final g = LadderGame(4, randomBoard: true, rng: rng);
        var steps = 0;
        while (!g.over && steps++ < 5000) {
          g.roll();
        }
        expect(g.over, isTrue);
        final r = LadderGame.fromJson(viaJson(g.toJson()));
        expect(r.positions, g.positions);
        expect(r.jumps, g.jumps);
      }
    });
  });

  group('Memory', () {
    test('Paare und Spielerwechsel', () {
      final g = MemoryGame(8, 2, rng: Random(3));
      final a = 0;
      final b = g.cards.indexOf(g.cards[0], 1);
      expect(g.flip(a), isTrue);
      expect(g.flip(a), isFalse);
      expect(g.flip(b), isTrue);
      expect(g.resolve(), isTrue);
      expect(g.current, 0, reason: 'Paar: nochmal dran');
      expect(g.scores[0], 1);
      final c = g.owner.indexOf(-1);
      final d = [for (var i = 0; i < g.cards.length; i++) i].firstWhere((i) => g.owner[i] < 0 && g.cards[i] != g.cards[c]);
      g
        ..flip(c)
        ..flip(d)
        ..resolve();
      expect(g.current, 1);
    });

    test('Computer spielen bis zum Ende', () {
      for (var seed = 0; seed < 10; seed++) {
        final g = MemoryGame(18, 3, rng: Random(seed));
        var steps = 0;
        while (!g.over && steps++ < 2000) {
          final p = g.current;
          g.flip(g.botPick(p), bots: [0, 1, 2]);
          g.flip(g.botPick(p), bots: [0, 1, 2]);
          g.resolve();
        }
        expect(g.over, isTrue);
        expect(g.scores.reduce((a, b) => a + b), 18);
        expect(steps, lessThan(150), reason: 'Gutes Gedächtnis');
      }
      final g = MemoryGame(8, 1, rng: Random(1));
      final r = MemoryGame.fromJson(viaJson(g.toJson()));
      expect(r.cards, g.cards);
    });
  });

  group('Reversi', () {
    test('Startstellung und Umdrehen', () {
      final g = ReversiGame();
      expect(g.moves()..sort(), [19, 26, 37, 44]);
      expect(g.play(19), isTrue);
      expect(g.board[27], 1);
      expect(g.count(1), 4);
      expect(g.count(2), 1);
      expect(g.current, 2);
    });

    test('Computer gegen Computer spielt bis zum Ende, schwer schlägt leicht', () {
      var hardWins = 0;
      for (var seed = 0; seed < 6; seed++) {
        final rng = Random(seed);
        final g = ReversiGame();
        final hard = seed.isEven ? 1 : 2;
        var steps = 0;
        while (!g.over && steps++ < 100) {
          final level = g.current == hard ? 2 : 0;
          expect(g.play(reversiBotMove(g.copy(), level, rng)), isTrue);
        }
        expect(g.over, isTrue);
        if (g.winner == hard) hardWins++;
        final r = ReversiGame.fromJson(viaJson(g.toJson()));
        expect(r.board, g.board);
      }
      expect(hardWins, greaterThanOrEqualTo(5));
    });
  });

  group('Mensch ärgere dich nicht', () {
    test('Brett: 40 Felder, Startfelder an den richtigen Stellen', () {
      expect(madnTrack.length, 40);
      expect(madnTrack.toSet().length, 40);
      expect(madnTrack[0], (0, 4));
      expect(madnTrack[10], (6, 0));
      expect(madnTrack[20], (10, 6));
      expect(madnTrack[30], (4, 10));
    });

    test('Drei Versuche, Herauskommen, Startfeld räumen, Schlagen', () {
      final g = MadnGame(2, rng: Random(1));
      g.roll(3);
      expect(g.current, 0, reason: 'erster Fehlversuch');
      g.roll(2);
      g.roll(4);
      expect(g.current, 1, reason: 'nach drei Versuchen ist der Nächste dran');
      g.roll(6);
      expect(g.movable, [0, 1, 2, 3]);
      g.move(0);
      expect(g.pieces[1][0], 0);
      expect(g.current, 1, reason: '6 = nochmal');
      g.roll(6);
      expect(g.movable, [0], reason: 'Startfeld muss geräumt werden');
      g.move(0);
      expect(g.pieces[1][0], 6);
      g.roll(2);
      expect(g.movable.contains(1), isFalse);
      g.move(0);
      expect(g.current, 0);
      // Rot kommt raus und schlägt später
      g.pieces[0][0] = 7;
      g.roll(1);
      expect(g.movable, [0]);
      final m = g.move(0);
      expect(m.captured, isNull);
      g.pieces[1][0] = 6;
      expect(g.absolute(1, 6), 16);
      g.pieces[0][1] = 14;
      g.current = 0;
      g.phase = MadnPhase.roll;
      g.roll(2);
      expect(g.movable, [1], reason: 'Schlagzwang');
      expect(g.move(1).captured, (1, 0));
      expect(g.pieces[1][0], -1);
    });

    test('Computer spielen Partien zu Ende, alle Regeln', () {
      for (var seed = 0; seed < 12; seed++) {
        final rules = MadnRules(
          threeTries: seed % 2 == 0,
          sixAgain: seed % 3 != 0,
          mustLeaveStart: seed % 4 != 1,
          captureForced: seed % 5 != 2,
        );
        final g = MadnGame(2 + seed % 3, rules: rules, rng: Random(seed));
        var steps = 0;
        while (g.phase != MadnPhase.over && steps++ < 20000) {
          if (g.phase == MadnPhase.roll) {
            g.roll();
          } else {
            g.move(g.botChoice());
          }
          for (var s = 0; s < g.players; s++) {
            for (final p in g.pieces[s]) {
              expect(p, inInclusiveRange(-1, 43));
            }
          }
        }
        expect(g.phase, MadnPhase.over, reason: 'seed $seed');
        final r = MadnGame.fromJson(viaJson(g.toJson()));
        expect(r.pieces, g.pieces);
      }
    });
  });
}
