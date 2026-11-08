import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/shogi/shogi_ai.dart';
import 'package:gluckspfennig/games/shogi/shogi_engine.dart';
import 'package:gluckspfennig/games/shogi/shogi_tutorial.dart';

void main() {
  test('Zuggenerierung: Perft der Grundstellung', () {
    final g = ShogiGame();
    expect(g.perft(1), 30);
    expect(g.perft(2), 900);
    expect(g.perft(3), 25470);
  });

  test('Beförderung ist Pflicht, wenn der Stein sonst nie mehr ziehen kann', () {
    final g = ShogiGame.fromSfen('4k4/9/4P4/9/9/9/9/9/4K4 b - 1');
    final moves = g.legalMoves().where((m) => m.from == shogiSquareFromName('5c')).toList();
    expect(moves.map((m) => m.usi), contains('5c5b+'));
    expect(moves.map((m) => m.usi), contains('5c5b'));
    final g2 = ShogiGame.fromSfen('4k4/4P4/9/9/9/9/9/9/4K4 b - 1');
    final up = g2.legalMoves().where((m) => m.from == shogiSquareFromName('5b')).map((m) => m.usi).toList();
    expect(up, isNot(contains('5b5a')), reason: 'König steht dort, aber die Regel wäre Pflicht');
  });

  test('Einsetzen: Nifu und Bauernmatt sind verboten', () {
    final g = ShogiGame.fromSfen('4k4/9/9/9/9/9/4P4/9/4K4 b P 1');
    final drops = g.dropsOf(sPawn).map((m) => colOf(m.to)).toSet();
    expect(drops, isNot(contains(4)), reason: 'Linie 5 hat schon einen Bauern');
    // Bauer vor den König, der nicht entkommen kann und den Bauern nicht schlagen darf
    final mate = ShogiGame.fromSfen('k8/2S6/1G7/9/9/9/9/9/4K4 b P 1');
    expect(mate.dropsOf(sPawn).map((m) => m.usi), isNot(contains('P*9b')));
  });

  test('Geschlagene Steine wandern unbefördert in die Hand', () {
    final g2 = ShogiGame.fromSfen('4k4/9/9/9/4+r4/9/9/4R4/4K4 b - 1');
    g2.make(g2.legalMoves().firstWhere((m) => m.usi == '5h5e'));
    expect(g2.handSente[sRook], 1);
    g2.unmake();
    expect(g2.handSente[sRook], 0);
    expect(g2.board[shogiSquareFromName('5e')], -sDragon);
  });

  test('Matt wird erkannt', () {
    final g = ShogiGame.fromSfen('4k4/4G4/4P4/9/9/9/9/9/4K4 w - 1');
    expect(g.result, ShogiResult.senteWins);
  });

  test('Computer setzt ein Matt in eins', () {
    final m = shogiBestMove('4k4/9/4P4/9/9/9/9/9/4K4 b G 1', ShogiLevel.medium, seed: 1);
    expect(m?.usi, 'G*5b');
  });

  test('Computerpartie läuft ohne Fehler', () {
    final g = ShogiGame();
    var plies = 0;
    while (g.result == ShogiResult.none && plies < 60) {
      final m = shogiBestMoveFor(g.copy(), plies.isEven ? ShogiLevel.easy : ShogiLevel.beginner, seed: plies)!;
      expect(g.legalMoves(), contains(m));
      g.make(m);
      plies++;
    }
  });

  test('Tutorial: jede Übung ist lösbar', () {
    for (final l in shogiLessons) {
      final g = ShogiGame.fromSfen(l.sfen);
      final moves = g.legalMoves();
      if (l.mate) {
        final ok = moves.any((m) {
          g.make(m);
          final r = g.result;
          g.unmake();
          return r == ShogiResult.senteWins;
        });
        expect(ok, isTrue, reason: l.title);
      } else if (l.anyDrop) {
        expect(moves.any((m) => m.isDrop), isTrue, reason: l.title);
      } else {
        for (final s in l.solutions) {
          expect(moves.map((m) => m.usi), contains(s), reason: l.title);
        }
      }
    }
  });
}
