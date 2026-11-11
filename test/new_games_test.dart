import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/arschloch/ah_engine.dart';
import 'package:gluckspfennig/games/backgammon/bg_engine.dart';
import 'package:gluckspfennig/games/dame/dame_engine.dart';
import 'package:gluckspfennig/games/go/go_engine.dart';
import 'package:gluckspfennig/games/go/go_screen.dart' show goLessons;
import 'package:gluckspfennig/games/halma/halma_engine.dart';
import 'package:gluckspfennig/games/kniffel/kniffel_engine.dart';
import 'package:gluckspfennig/games/ladder/ladder_engine.dart';
import 'package:gluckspfennig/games/madn/madn_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_guides.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';
import 'package:gluckspfennig/games/mahjong/mahjong_tutorial.dart';
import 'package:gluckspfennig/games/mahjong/tiles.dart';
import 'package:gluckspfennig/games/memory/memory_engine.dart';
import 'package:gluckspfennig/games/muehle/muehle_engine.dart';
import 'package:gluckspfennig/games/pikdame/pd_engine.dart';
import 'package:gluckspfennig/games/reversi/reversi_engine.dart';
import 'package:gluckspfennig/ui/widgets.dart' show fixDu;

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

  group('Kniffel', () {
    test('Wertung', () {
      expect(kniffelScore(5, [6, 6, 6, 2, 1]), 18);
      expect(kniffelScore(6, [6, 6, 6, 2, 1]), 21);
      expect(kniffelScore(7, [6, 6, 6, 2, 1]), 0);
      expect(kniffelScore(8, [3, 3, 2, 2, 2]), 25);
      expect(kniffelScore(8, [3, 3, 3, 3, 3]), 0);
      expect(kniffelScore(9, [1, 2, 3, 4, 6]), 30);
      expect(kniffelScore(9, [1, 2, 3, 5, 6]), 0);
      expect(kniffelScore(10, [2, 3, 4, 5, 6]), 40);
      expect(kniffelScore(11, [4, 4, 4, 4, 4]), 50);
      expect(kniffelScore(12, [1, 2, 3, 4, 6]), 16);
    });

    test('Computer spielen 13 Runden, Bonus und Summe stimmen', () {
      for (var seed = 0; seed < 8; seed++) {
        final g = KniffelGame(3, rng: Random(seed));
        var steps = 0;
        while (!g.over && steps++ < 1000) {
          if (!g.rolled || (!g.botStop() && g.rollsLeft > 0)) {
            if (g.rolled) g.held = g.botHolds();
            expect(g.roll(), isTrue);
          } else {
            expect(g.score(g.botCategory()), isTrue);
          }
        }
        expect(g.over, isTrue);
        for (var p = 0; p < 3; p++) {
          expect(g.total(p), g.upper(p) + g.bonus(p) + g.lower(p) + g.extra[p]);
          expect(g.total(p), greaterThan(100), reason: 'Computer spielt brauchbar');
        }
        final r = KniffelGame.fromJson(viaJson(g.toJson()));
        expect(r.scores, g.scores);
      }
    });
  });

  group('Backgammon', () {
    test('Aufstellung, Würfe, Pflicht zum höheren Würfel', () {
      final g = BgGame(rng: Random(1));
      expect(g.pips(0), 167);
      expect(g.pips(1), 167);
      g.roll(3, 1);
      final seqs = g.sequences();
      expect(seqs.every((s) => s.length == 2), isTrue);
      // 8/5 6/5: Punkt machen ist dabei
      expect(seqs.any((s) => s.any((x) => x.from == 7 && x.to == 4) && s.any((x) => x.from == 5 && x.to == 4)), isTrue);
      g.endTurn();
      g.roll(6, 6);
      expect(g.remaining.length, 4);
    });

    test('Schlagen, Bar zuerst, Abtragen', () {
      final g = BgGame(rng: Random(2));
      for (final p in [0, 1]) {
        g.counts[p].fillRange(0, 24, 0);
      }
      g.counts[0][10] = 1;
      g.counts[1][23 - 8] = 1; // schwarzer Einzelstein auf meinem Punkt 8
      g.roll(2, 5);
      final hit = g.stepFor(10, 2)!;
      expect(hit.hit, isTrue);
      g.apply(hit);
      expect(g.bar[1], 1);
      g.endTurn();
      g.roll(1, 2);
      final seqs = g.sequences();
      expect(seqs.every((s) => s.first.from == bgBar), isTrue);
      // Abtragen nur mit allen im Heimfeld
      final h = BgGame(rng: Random(3));
      for (final p in [0, 1]) {
        h.counts[p].fillRange(0, 24, 0);
      }
      h.counts[0][2] = 1;
      h.counts[0][0] = 14;
      h.counts[1][0] = 15;
      h.roll(6, 1);
      final s = h.sequences();
      expect(s.any((q) => q.any((x) => x.to == bgOff && x.die == 6 && x.from == 2)), isTrue);
    });

    test('Computer gegen Computer bis zum Ende', () {
      for (var seed = 0; seed < 6; seed++) {
        final rng = Random(seed);
        final g = BgGame(rng: rng)..start();
        var turns = 0;
        while (!g.over && turns++ < 600) {
          if (!g.rolled) g.roll();
          for (final st in bgBotSequence(g, seed.isEven ? 1 : 0, rng)) {
            g.apply(st);
          }
          if (!g.over) g.endTurn();
          var total = 0;
          for (final p in [0, 1]) {
            total += g.bar[p] + g.off[p] + g.counts[p].fold(0, (a, b) => a + b);
          }
          expect(total, 30);
        }
        expect(g.over, isTrue);
        expect(g.off[g.winner!], 15);
        final r = BgGame.fromJson(viaJson(g.toJson()));
        expect(r.counts, g.counts);
      }
    });
  });

  group('Halma', () {
    test('Sternbrett: 121 Löcher, sechs Lager zu je 10', () {
      final b = HalmaBoard.instance;
      expect(b.cells.length, 121);
      for (var c = 0; c < 6; c++) {
        expect(b.campCells(c).length, 10);
      }
      final g = HalmaGame(6);
      expect(g.board.where((v) => v >= 0).length, 60);
    });

    test('Springen über Figuren in Ketten', () {
      final g = HalmaGame(2);
      g.board.fillRange(0, g.board.length, -1);
      final b = HalmaBoard.instance;
      final a = b.index[(0, 0, 0)]!;
      final m1 = b.index[(1, -1, 0)]!;
      final m2 = b.index[(3, -3, 0)]!;
      g.board[a] = 0;
      g.board[m1] = 1;
      g.board[m2] = 1;
      final t = g.targets(a);
      expect(t.contains(b.index[(2, -2, 0)]), isTrue);
      expect(t.contains(b.index[(4, -4, 0)]), isTrue, reason: 'Doppelsprung');
      expect(t.contains(b.index[(1, 0, -1)]), isTrue, reason: 'Schritt');
    });

    test('Computer spielen Partien zu Ende', () {
      for (final n in [2, 3, 4, 6]) {
        final rng = Random(n);
        final g = HalmaGame(n);
        var steps = 0;
        while (!g.over && steps++ < 4000) {
          final m = g.botMove(rng);
          if (m == null) {
            g.pass();
          } else {
            expect(g.play(m.$1, m.$2), isTrue);
          }
        }
        expect(g.over, isTrue, reason: '$n Spieler nach $steps Zügen');
        final r = HalmaGame.fromJson(viaJson(g.toJson()));
        expect(r.board, g.board);
      }
    });
  });

  group('Go', () {
    test('Schlagen, Selbstmord, Ko', () {
      final (g, _) = GoGame.fromDiagram(const [
        '.........',
        '.........',
        '.........',
        '...XO....',
        '..XO.O...',
        '...XO....',
        '.........',
        '.........',
        '.........',
      ]);
      final ko = 4 * 9 + 4;
      expect(g.play(ko), isTrue, reason: 'Schwarz schlägt im Ko');
      expect(g.board[4 * 9 + 3], 0);
      expect(g.captures[1], 1);
      expect(g.isLegal(4 * 9 + 3), isFalse, reason: 'Weiß darf nicht sofort zurückschlagen');
      g.play(0);
      g.play(80);
      expect(g.isLegal(4 * 9 + 3), isTrue, reason: 'nach einem anderen Zug schon');
      // Selbstmord
      final (s, _) = GoGame.fromDiagram(const ['.X.', 'X..', '...']);
      s.current = 2;
      expect(s.isLegal(0), isFalse);
    });

    test('Flächenwertung', () {
      final (g, _) = GoGame.fromDiagram([for (var r = 0; r < 9; r++) '...XO....']);
      // Schwarz: 4 Spalten, Weiß: 5 Spalten, Komi 7,5
      expect(g.score(), 36 - 45 - 7.5);
    });

    test('Alle Aufgaben der Go-Schule sind lösbar', () {
      for (final l in goLessons) {
        final (g, answers) = GoGame.fromDiagram(l.diagram);
        expect(answers, isNotEmpty, reason: l.title);
        for (final a in answers) {
          expect(g.isLegal(a), isTrue, reason: '${l.title}: $a');
        }
      }
      final (cap, _) = GoGame.fromDiagram(goLessons[0].diagram);
      cap.play(4 * 9 + 5);
      expect(cap.board[4 * 9 + 4], 0, reason: 'Stein geschlagen');
    });

    test('Computer: leicht spielt zu Ende, mittel findet einen legalen Zug', () {
      final rng = Random(4);
      final g = GoGame(9);
      var steps = 0;
      while (!g.over && steps++ < 400) {
        final m = goBotMove(g, 0, rng);
        if (m < 0) {
          g.pass();
        } else {
          expect(g.play(m), isTrue);
        }
      }
      expect(g.over, isTrue);
      final r = GoGame.fromJson(viaJson(g.toJson()));
      expect(r.board, g.board);
      final (atari, _) = GoGame.fromDiagram(goLessons[0].diagram);
      final m = goBotMove(atari, 1, Random(1));
      expect(m < 0 || atari.isLegal(m), isTrue);
    });
  });

  group('Mehrere Menschen an einem Gerät', () {
    test('Arschloch: alle vier Menschen, Tausch durch die Menschen, Nachspielen', () {
      final g = AhGame(rng: Random(5), names: const ['A', 'B', 'C', 'D'], humans: const [true, true, true, true])..start();
      var steps = 0;
      while (g.phase != AhPhase.gameOver && steps++ < 2000) {
        switch (g.phase) {
          case AhPhase.exchange:
            expect(g.pendingGive, isNotEmpty);
            final p = (g.pendingGive.toList()..sort()).first;
            g.giveBack(p, sortAh(g.players[p].hand).take(g.gives(p)).toList());
          case AhPhase.roundOver:
            g.nextRound();
          case AhPhase.play:
            final m = ahBotMove(g, g.current);
            if (m == null) {
              g.pass(g.current);
            } else {
              g.play(g.current, m);
            }
          case AhPhase.gameOver:
            break;
        }
      }
      expect(g.phase, AhPhase.gameOver);
      expect(g.actionLog.any((a) => a.first == 'G'), isTrue, reason: 'auch andere Plätze tauschen');
      final r = AhGame(rng: Random(5), names: const ['A', 'B', 'C', 'D'], humans: const [true, true, true, true])..start();
      for (final a in viaJson2(g.actionLog)) {
        ahApply(r, a as List);
      }
      expect(r.phase, g.phase);
      for (var p = 0; p < 4; p++) {
        expect(r.players[p].points, g.players[p].points);
      }
    });

    test('Pik Dame: zwei Menschen werden mit Namen angesprochen', () {
      final g = PdGame(const PdOptions(players: 3), rng: Random(2), names: const ['Anna', 'Oma Erna', 'Ben'], humans: const [true, false, true])
        ..start();
      expect(g.players.where((x) => x.human).length, 2);
      expect(g.who(0), 'Anna');
      final solo = PdGame(const PdOptions(players: 3), rng: Random(2))..start();
      expect(solo.who(0), 'Du');
    });
  });

  group('Mahjong-Übungen', () {
    test('Jede Variante hat Grundlagen, eigene Übungen und den Übungsteil', () {
      for (final v in MjVariant.values) {
        final l = mjLessons(v);
        expect(l.length, greaterThanOrEqualTo(mahjongPractice.length + 4), reason: v.name);
        for (final q in l) {
          final n = q.tileOptions.isNotEmpty ? q.tileOptions.length : q.textOptions.length;
          expect(q.correct, inInclusiveRange(0, n - 1), reason: '${v.name}: ${q.title}');
        }
      }
    });

    test('Hilfszahlen für alle Grundsteine', () {
      for (var t = 0; t < 34; t++) {
        expect(tileHintLabel(t), isNotNull);
      }
      expect(tileHintLabel(3), '4');
      expect(tileHintLabel(30), 'N');
      expect(tileHintLabel(33), 'Rot');
    });
  });

  test('Meldungen mit „Du“ bekommen die richtige Verbform', () {
    expect(fixDu('Du ist dran'), 'Du bist dran');
    expect(fixDu('Ben würfelt 4. Du ist dran'), 'Ben würfelt 4. Du bist dran');
    expect(fixDu('Du hat beim Auswürfeln gewonnen und beginnt mit 3 und 2'), 'Du hast beim Auswürfeln gewonnen und beginnst mit 3 und 2');
    expect(fixDu('Du (Weiß) beginnt'), 'Du (Weiß) beginnst');
    expect(fixDu('Ben ist dran'), 'Ben ist dran');
    expect(fixDu('Du bist König'), 'Du bist König');
  });
}

List<dynamic> viaJson2(List<List<Object?>> log) => jsonDecode(jsonEncode(log)) as List<dynamic>;
