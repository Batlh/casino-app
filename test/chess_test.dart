import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/chess/chess_ai.dart';
import 'package:gluckspfennig/games/chess/chess_engine.dart';
import 'package:gluckspfennig/games/chess/chess_tutorial.dart';

void main() {
  test('Zuggenerierung: Perft der Grundstellung', () {
    final g = ChessGame();
    expect(g.perft(1), 20);
    expect(g.perft(2), 400);
    expect(g.perft(3), 8902);
    expect(g.perft(4), 197281);
    expect(g.fen, ChessGame.startFen, reason: 'Ziehen und Zurücknehmen ändern nichts');
  });

  test('Zuggenerierung: Kiwipete mit Rochade, en passant, Umwandlung', () {
    final g = ChessGame.fromFen('r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1');
    expect(g.perft(1), 48);
    expect(g.perft(2), 2039);
    expect(g.perft(3), 97862);
  });

  test('Zuggenerierung: Endspiel mit en passant und Fesselungen', () {
    final g = ChessGame.fromFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');
    expect(g.perft(1), 14);
    expect(g.perft(2), 191);
    expect(g.perft(3), 2812);
    expect(g.perft(4), 43238);
  });

  test('Zuggenerierung: Umwandlungen mit Schlagen', () {
    final g = ChessGame.fromFen('r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1');
    expect(g.perft(1), 6);
    expect(g.perft(2), 264);
    expect(g.perft(3), 9467);
  });

  test('Matt, Patt und Remis werden erkannt', () {
    expect(ChessGame.fromFen('R5k1/5ppp/8/8/8/8/8/6K1 b - - 0 1').result, ChessResult.whiteMates);
    expect(ChessGame.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1').result, ChessResult.stalemate);
    expect(ChessGame.fromFen('8/8/4k3/8/8/3BK3/8/8 w - - 0 1').result, ChessResult.material);
    final g = ChessGame();
    for (var i = 0; i < 2; i++) {
      for (final m in ['g1f3', 'g8f6', 'f3g1', 'f6g8']) {
        g.make(g.legalMoves().firstWhere((x) => x.uci == m));
      }
    }
    expect(g.result, ChessResult.repetition);
  });

  test('Computer findet ein Matt in eins auf jeder Stufe außer Anfänger', () {
    for (final level in [ChessLevel.easy, ChessLevel.medium, ChessLevel.hard]) {
      final m = chessBestMove('6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1', level, seed: 1);
      expect(m?.uci, 'a1a8', reason: level.label);
    }
  });

  test('Computer schlägt eine hängende Dame', () {
    final m = chessBestMove('4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1', ChessLevel.medium, seed: 2);
    expect(m?.uci, 'd1d5');
  });

  test('Computerpartie endet ohne Fehler', () {
    final g = ChessGame();
    var plies = 0;
    while (g.result == ChessResult.none && plies < 120) {
      final m = chessBestMove(g.fen, plies.isEven ? ChessLevel.easy : ChessLevel.beginner, seed: plies)!;
      expect(g.legalMoves(), contains(m));
      g.make(m);
      plies++;
    }
  });

  test('Tutorial: jede Übung ist lösbar', () {
    for (final l in chessLessons) {
      final g = ChessGame.fromFen(l.fen);
      final moves = g.legalMoves();
      if (l.mate) {
        final mates = moves.where((m) {
          g.make(m);
          final r = g.result;
          g.unmake();
          return r == ChessResult.whiteMates;
        });
        expect(mates, isNotEmpty, reason: l.title);
      } else {
        for (final s in l.solutions) {
          expect(moves.map((m) => m.uci), contains(s), reason: l.title);
        }
      }
    }
  });
}
