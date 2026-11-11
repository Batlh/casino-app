import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/ladder/ladder_engine.dart';
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
}
