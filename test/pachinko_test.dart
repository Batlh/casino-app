import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_board.dart';

void main() {
  for (final m in pachinkoMachines) {
    test('${m.name}: Bälle erreichen das Brett, Auszahlung im Rahmen', () {
      final powers = m.id == 'classic' ? [0.2, 0.4, 0.6, 0.8, 1.0] : [0.3, 0.65, 1.0];
      for (final power in powers) {
        final board = PachinkoBoard(rng: Random(5), spec: m);
        final counts = <PachinkoEventKind, int>{};
        var paid = 0;
        var spent = 0;
        const dt = 1 / 60;
        final balls = m.id == 'classic' ? 2500 : 1600;
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
        print('${m.name} Stärke $power: Quote ${(rtp * 100).toStringAsFixed(1)} % $counts');
        expect(rtp, inInclusiveRange(0.6, 1.2));
        expect(refund, lessThan(balls));
        expect(counts[PachinkoEventKind.stuck] ?? 0, lessThan(balls ~/ 100), reason: 'Kaum hängende Bälle');
      }
    });

    test('${m.name}: Auf dem Anzeigefeld bleibt kein Ball liegen', () {
      final probe = PachinkoBoard(rng: Random(1), spec: m);
      final l = probe.lcd;
      for (var k = 0; k <= 8; k++) {
        final x = l.left + 0.1 + (l.right - l.left - 0.2) * k / 8 + (k == 4 ? 0.01 : 0);
        final board = PachinkoBoard(rng: Random(1), spec: m);
        board.dropAt(x, l.top - l.roof - 0.2);
        for (var i = 0; i < 120; i++) {
          board.step(1 / 60);
        }
        if (board.ballsInPlay == 0) continue;
        final b = board.balls.first;
        final onTop = b.x > l.left - 0.1 && b.x < l.right + 0.1 && b.y < l.top;
        expect(onTop, isFalse, reason: 'Ball bei x=$x liegt nach 2 s noch oben (${b.x}, ${b.y})');
      }
    });
  }

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
