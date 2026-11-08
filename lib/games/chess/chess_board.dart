import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'chess_engine.dart';
import 'chess_pieces.dart';

/// Schachbrett zum Antippen. Ein Feld antippen wählt die Figur, das Ziel antippen zieht.
class ChessBoardView extends StatelessWidget {
  const ChessBoardView({
    super.key,
    required this.game,
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.onTap,
    this.marks = const {},
  });

  final ChessGame game;

  /// Schwarz unten.
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final ValueChanged<int>? onTap;

  /// Zusätzlich hervorgehobene Felder, etwa im Tutorial.
  final Set<int> marks;

  int squareAt(Offset local, double size) {
    final cell = size / 8;
    final vf = (local.dx / cell).floor().clamp(0, 7);
    final vr = (local.dy / cell).floor().clamp(0, 7);
    return flipped ? vr * 8 + (7 - vf) : (7 - vr) * 8 + vf;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.maxWidth;
          return GestureDetector(
            onTapDown: onTap == null ? null : (d) => onTap!(squareAt(d.localPosition, size)),
            child: Semantics(
              label: 'Schachbrett',
              child: CustomPaint(
                size: Size.square(size),
                painter: _BoardPainter(game, flipped, selected, targets, marks),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.g, this.flipped, this.selected, this.targets, this.marks)
      : board = g.board.toList(),
        last = g.lastMove,
        check = g.inCheck() ? g.kingSquare(g.side) : -1;

  final ChessGame g;
  final List<int> board;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Set<int> marks;
  final ChessMove? last;
  final int check;

  static const lightSq = Color(0xFFF0DDB8);
  static const darkSq = Color(0xFFB27C52);

  Rect rectOf(int sq, double cell) {
    final f = fileOf(sq);
    final r = rankOf(sq);
    final vf = flipped ? 7 - f : f;
    final vr = flipped ? r : 7 - r;
    return Rect.fromLTWH(vf * cell, vr * cell, cell, cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.12)),
      Paint()..color = const Color(0xFF5A3420),
    );
    for (var sq = 0; sq < 64; sq++) {
      final r = rectOf(sq, cell);
      final lightSquare = (fileOf(sq) + rankOf(sq)).isOdd;
      canvas.drawRect(r, Paint()..color = lightSquare ? lightSq : darkSq);
      if (last != null && (sq == last!.from || sq == last!.to)) {
        canvas.drawRect(r, Paint()..color = const Color(0x88F4D35E));
      }
      if (sq == selected) canvas.drawRect(r, Paint()..color = const Color(0xAA63E6FF));
      if (marks.contains(sq)) {
        canvas.drawRect(
          r.deflate(cell * 0.04),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = const Color(0xFF63E6FF),
        );
      }
      if (sq == check) {
        canvas.drawRect(
          r,
          Paint()
            ..shader = RadialGradient(
              colors: const [Color(0xDDFF3B30), Color(0x00FF3B30)],
            ).createShader(r),
        );
      }
    }
    // Koordinaten am Rand
    for (var i = 0; i < 8; i++) {
      final fileSq = flipped ? 7 - i : i;
      final rankSq = flipped ? i : 7 - i;
      _label(canvas, 'abcdefgh'[fileSq], Offset(i * cell + cell - cell * 0.12, size.height - cell * 0.16), cell,
          (fileSq + (flipped ? 7 : 0)).isEven);
      _label(canvas, '${rankSq + 1}', Offset(cell * 0.1, i * cell + cell * 0.14), cell, (rankSq + (flipped ? 7 : 0)).isEven);
    }
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0) continue;
      final r = rectOf(sq, cell);
      canvas.save();
      canvas.translate(r.left + cell * 0.04, r.top + cell * 0.02);
      ChessPiecePainter(p).paint(canvas, Size.square(cell * 0.92));
      canvas.restore();
    }
    for (final t in targets) {
      final r = rectOf(t, cell);
      if (board[t] != 0) {
        canvas.drawCircle(
          r.center,
          cell * 0.44,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.07
            ..color = const Color(0xCC1E7A5A),
        );
      } else {
        canvas.drawCircle(r.center, cell * 0.15, Paint()..color = const Color(0xCC1E7A5A));
      }
    }
  }

  void _label(Canvas canvas, String text, Offset center, double cell, bool onDark) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          fontSize: cell * 0.18,
          color: onDark ? lightSq : darkSq,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
