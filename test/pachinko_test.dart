import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_board.dart';
import 'package:gluckspfennig/games/pachinko/pachinko_machines.dart';

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
        var steps = 0;
        while ((launched < balls || board.ballsInPlay > 0) && steps++ < 600000) {
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
        expect(board.ballsInPlay, 0, reason: 'Simulation endet nicht');
        final refund = counts[PachinkoEventKind.refund] ?? 0;
        final rtp = paid / spent;
        // ignore: avoid_print
        print('${m.name} Stärke $power: Quote ${(rtp * 100).toStringAsFixed(1)} % $counts');
        expect(rtp, inInclusiveRange(0.6, 1.2));
        expect(refund, lessThan(balls));
        expect(counts[PachinkoEventKind.stuck] ?? 0, lessThan(balls ~/ 100), reason: 'Kaum hängende Bälle');
      }
    });

    test('${m.name}: Zwischen zwei Nägeln bleibt keine Kugel liegen', () {
      final board = PachinkoBoard(rng: Random(1), spec: m);
      final pegs = board.pegs;
      const min = PachinkoBoard.minPegDistance - 1e-6;
      for (var i = 0; i < pegs.length; i++) {
        for (var j = i + 1; j < pegs.length; j++) {
          final d = sqrt(pow(pegs[i].x - pegs[j].x, 2) + pow(pegs[i].y - pegs[j].y, 2));
          expect(d, greaterThan(min),
              reason: 'Nägel (${pegs[i].x.toStringAsFixed(2)}, ${pegs[i].y.toStringAsFixed(2)}) und '
                  '(${pegs[j].x.toStringAsFixed(2)}, ${pegs[j].y.toStringAsFixed(2)}) zu eng');
        }
      }
    });

    test('${m.name}: Kugeln fallen über jeder Tulpe durch', () {
      // Über und neben jeder Tulpe fallen lassen: Nach 4 s darf keine Kugel mehr dort liegen.
      for (final p in m.pockets.where((p) => p.kind != PocketKind.gate)) {
        for (final dx in [-0.45, -0.25, 0.0, 0.25, 0.45]) {
          for (final x in [p.left + dx, p.right + dx]) {
            final board = PachinkoBoard(rng: Random(2), spec: m);
            board.dropAt(x, p.top - 0.9);
            for (var i = 0; i < 240; i++) {
              board.step(1 / 60);
            }
            if (board.ballsInPlay == 0) continue;
            final b = board.balls.first;
            final near = (b.x - x).abs() < 0.8 && (b.y - p.top).abs() < 0.8;
            expect(near, isFalse, reason: 'Kugel bei x=${x.toStringAsFixed(2)} hängt an der Tulpe (${b.x.toStringAsFixed(2)}, ${b.y.toStringAsFixed(2)})');
          }
        }
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
