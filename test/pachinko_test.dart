import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_board.dart';

void main() {
  test('Simulation: Bälle erreichen das Brett, Auszahlung im Rahmen', () {
    for (final power in [0.2, 0.4, 0.6, 0.8, 1.0]) {
      final board = PachinkoBoard(rng: Random(5));
      final counts = <PachinkoEventKind, int>{};
      var paid = 0;
      var spent = 0;
      const dt = 1 / 60;
      const balls = 2500;
      var launched = 0;
      var t = 0.0;
      while (launched < balls || board.ballsInPlay > 0) {
        if (launched < balls && t >= 0.6) {
          t = 0;
          board.launch(power);
          launched++;
          spent += PachinkoBoard.ballCost;
        }
        board.step(dt);
        t += dt;
        for (final e in board.events) {
          counts[e.kind] = (counts[e.kind] ?? 0) + 1;
          paid += e.payout;
        }
        board.events.clear();
        expect(board.ballsInPlay, lessThan(60), reason: 'Bälle bleiben hängen');
      }
      final refund = counts[PachinkoEventKind.refund] ?? 0;
      final rtp = paid / spent;
      // ignore: avoid_print
      print('Pachinko Stärke $power: Quote ${(rtp * 100).toStringAsFixed(1)} % $counts');
      expect(rtp, inInclusiveRange(0.6, 1.2));
      expect(refund, lessThan(balls));
      expect(counts[PachinkoEventKind.stuck] ?? 0, lessThan(balls ~/ 100), reason: 'Kaum hängende Bälle');
    }
  });

  test('Auf dem Anzeigefeld bleibt kein Ball liegen', () {
    for (final x in [3.3, 3.6, 4.2, 4.69, 4.71, 5.2, 5.8, 6.1]) {
      final board = PachinkoBoard(rng: Random(1));
      board.dropAt(x, PachinkoBoard.lcdTop - PachinkoBoard.lcdRoof - 0.2);
      for (var i = 0; i < 120; i++) {
        board.step(1 / 60);
      }
      if (board.ballsInPlay == 0) continue;
      final b = board.balls.first;
      final onTop = b.x > PachinkoBoard.lcdLeft - 0.1 &&
          b.x < PachinkoBoard.lcdRight + 0.1 &&
          b.y < PachinkoBoard.lcdTop;
      expect(onTop, isFalse, reason: 'Ball bei x=$x liegt nach 2 s noch oben (${b.x}, ${b.y})');
    }
  });

  test('Ein festsitzender Ball wird angestupst oder erstattet', () {
    final board = PachinkoBoard(rng: Random(2));
    // Genau auf die Spitze gelegt
    board.dropAt((PachinkoBoard.lcdLeft + PachinkoBoard.lcdRight) / 2,
        PachinkoBoard.lcdTop - PachinkoBoard.lcdRoof - PachinkoBoard.ballRadius);
    for (var i = 0; i < 60 * 8 && board.ballsInPlay > 0; i++) {
      board.step(1 / 60);
      final b = board.balls.firstOrNull;
      if (b != null && b.y > PachinkoBoard.lcdTop) break;
    }
    final gone = board.ballsInPlay == 0 || board.balls.first.y > PachinkoBoard.lcdTop;
    expect(gone, isTrue);
  });
}
