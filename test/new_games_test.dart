import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/dame/dame_engine.dart';
import 'package:gluckspfennig/games/ladder/ladder_engine.dart';
import 'package:gluckspfennig/games/madn/madn_engine.dart';
import 'package:gluckspfennig/games/memory/memory_engine.dart';
import 'package:gluckspfennig/games/muehle/muehle_engine.dart';
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

  group('Mühle', () {
    test('Nachbarn und Mühlen', () {
      expect(muehleMills.length, 16);
      for (var i = 0; i < 24; i++) {
        expect(muehleNeighbors[i].length, i % 2 == 0 ? 2 : (i >= 8 && i < 16 ? 4 : 3));
        for (final n in muehleNeighbors[i]) {
          expect(muehleNeighbors[n], contains(i));
        }
      }
    });

    test('Mühle schließen verlangt Schlagen, geschützte Steine', () {
      final g = MuehleGame();
      expect(g.play(const MuehleMove(null, 0)), isTrue);
      expect(g.play(const MuehleMove(null, 8)), isTrue);
      expect(g.play(const MuehleMove(null, 1)), isTrue);
      expect(g.play(const MuehleMove(null, 9)), isTrue);
      expect(g.play(const MuehleMove(null, 2)), isFalse, reason: 'Mühle ohne Schlagen');
      expect(g.play(const MuehleMove(null, 2, 8)), isTrue);
      expect(g.board[8], 0);
      expect(g.count(2), 1);
      expect(g.toPlace, [6, 7]);
    });

    test('Computer gegen Computer endet, stark schlägt schwach', () {
      var strongWins = 0;
      for (var seed = 0; seed < 4; seed++) {
        final rng = Random(seed);
        final g = MuehleGame();
        final strong = seed.isEven ? 1 : 2;
        var steps = 0;
        while (!g.over && steps++ < 400) {
          final m = muehleBotMove(g.copy(), g.current == strong ? 2 : 0, rng);
          expect(g.play(m), isTrue, reason: 'Zug $m');
        }
        expect(g.over, isTrue);
        if (g.winner == strong) strongWins++;
        final r = MuehleGame.fromJson(viaJson(g.toJson()));
        expect(r.board, g.board);
      }
      expect(strongWins, greaterThanOrEqualTo(2));
    });
  });

  group('Dame', () {
    test('Aufstellung und erste Züge', () {
      final de = DameGame(DameVariant.german);
      expect(de.count(1), 12);
      expect(de.count(-1), 12);
      expect(de.moves().length, 7);
      final intl = DameGame(DameVariant.international);
      expect(intl.count(1), 20);
      expect(intl.moves().length, 9);
    });

    test('Schlagpflicht, Mehrfachschlag, Mehrheit international', () {
      final g = DameGame(DameVariant.international);
      g.board.fillRange(0, 100, 0);
      // Weißer Stein auf 6/1 (Reihe 6, Spalte 1), schwarze Steine schräg davor
      g.board[6 * 10 + 1] = 1;
      g.board[5 * 10 + 2] = -1;
      g.board[3 * 10 + 4] = -1;
      g.board[5 * 10 + 0] = -1;
      g.board[9 * 10 + 0] = -1;
      final ms = g.moves();
      expect(ms, isNotEmpty);
      expect(ms.every((m) => m.captured.length == 2), isTrue, reason: 'Mehrheit: Doppelsprung');
      expect(g.play(ms.first), isTrue);
      expect(g.count(-1), 2);
    });

    test('Dame zieht weit und wird beim Erreichen der Grundreihe gekrönt', () {
      final g = DameGame(DameVariant.german);
      g.board.fillRange(0, 64, 0);
      g.board[1 * 8 + 2] = 1;
      g.board[7 * 8 + 6] = -1;
      final m = g.moves().firstWhere((m) => m.to == 0 * 8 + 1);
      expect(g.play(m), isTrue);
      expect(g.board[1], 2);
      g.current = 1;
      final far = g.moves().where((m) => m.from == 1).map((m) => m.to).toList();
      expect(far.length, greaterThan(2), reason: 'fliegende Dame');
    });

    test('Computer gegen Computer endet', () {
      for (final v in DameVariant.values) {
        for (var seed = 0; seed < 2; seed++) {
          final rng = Random(seed);
          final g = DameGame(v);
          var steps = 0;
          while (!g.over && steps++ < 300) {
            final m = dameBotMove(g.copy(), steps.isEven ? 1 : 0, rng);
            expect(g.play(m), isTrue, reason: '$v Zug $m');
          }
          final r = DameGame.fromJson(viaJson(g.toJson()));
          expect(r.board, g.board);
        }
      }
    });
  });
}
