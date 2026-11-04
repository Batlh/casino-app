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
    }
  });
}
