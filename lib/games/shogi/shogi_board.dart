import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'shogi_engine.dart';

const kanjiFont = 'Kanji';

/// Fünfeckiger Holzstein mit Schriftzeichen. Steine von Gote stehen auf dem Kopf.
void paintShogiPiece(Canvas canvas, Rect r, int piece, {bool flipped = false, bool highlight = false}) {
  if (piece == 0) return;
  final t = piece.abs();
  final upside = (piece < 0) != flipped;
  canvas.save();
  canvas.translate(r.center.dx, r.center.dy);
  if (upside) canvas.rotate(math.pi);
  final w = r.width * 0.84;
  final h = r.height * 0.9;
  final path = Path()
    ..moveTo(0, -h / 2)
    ..lineTo(w * 0.36, -h * 0.32)
    ..lineTo(w / 2, h / 2)
    ..lineTo(-w / 2, h / 2)
    ..lineTo(-w * 0.36, -h * 0.32)
    ..close();
  canvas.drawPath(path.shift(const Offset(1, 1.5)), Paint()..color = const Color(0x55000000));
  canvas.drawPath(
    path,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8E2AE), Color(0xFFE2B86E)],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: w, height: h)),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r.width * 0.03)
      ..color = highlight ? const Color(0xFF1E7A5A) : const Color(0xFF6B3E1E),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: shogiKanji(t, gote: piece < 0),
      style: TextStyle(
        fontFamily: kanjiFont,
        fontSize: r.width * 0.5,
        height: 1,
        color: t > promoted ? const Color(0xFFC0281C) : const Color(0xFF1E120D),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2 + h * 0.06));
  canvas.restore();
}

class ShogiPieceView extends StatelessWidget {
  const ShogiPieceView({super.key, required this.piece, required this.size, this.highlight = false});
  final int piece;
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _PiecePainter(piece, highlight),
      );
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.piece, this.highlight);
  final int piece;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) =>
      paintShogiPiece(canvas, Offset.zero & size, piece, highlight: highlight);

  @override
  bool shouldRepaint(covariant _PiecePainter old) => old.piece != piece || old.highlight != highlight;
}

/// Das 9x9-Brett. Oben stehen die Linien 9 bis 1, rechts die Reihen.
class ShogiBoardView extends StatelessWidget {
  const ShogiBoardView({
    super.key,
    required this.game,
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.marks = const {},
    this.onTap,
  });

  final ShogiGame game;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Set<int> marks;
  final ValueChanged<int>? onTap;

  int squareAt(Offset local, double size) {
    final cell = size / 9;
    final vc = (local.dx / cell).floor().clamp(0, 8);
    final vr = (local.dy / cell).floor().clamp(0, 8);
    return flipped ? (8 - vr) * 9 + (8 - vc) : vr * 9 + vc;
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
              label: 'Shogi-Brett',
              child: CustomPaint(
                size: Size.square(size),
                painter: _BoardPainter(game.board.toList(), flipped, selected, targets, marks, game.lastMove,
                    game.inCheck() ? game.kingSquare(game.side) : -1),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.board, this.flipped, this.selected, this.targets, this.marks, this.last, this.check);
  final List<int> board;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Set<int> marks;
  final ShogiMove? last;
  final int check;

  Rect rectOf(int sq, double cell) {
    final r = rowOf(sq);
    final c = colOf(sq);
    final vr = flipped ? 8 - r : r;
    final vc = flipped ? 8 - c : c;
    return Rect.fromLTWH(vc * cell, vr * cell, cell, cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.1)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBC787), Color(0xFFD9A85E)],
        ).createShader(Offset.zero & size),
    );
    for (var sq = 0; sq < 81; sq++) {
      final r = rectOf(sq, cell);
      if (last != null && (sq == last!.to || sq == last!.from)) {
        canvas.drawRect(r, Paint()..color = const Color(0x66F4D35E));
      }
      if (sq == selected) canvas.drawRect(r, Paint()..color = const Color(0x9963E6FF));
      if (sq == check) canvas.drawRect(r, Paint()..color = const Color(0x88FF3B30));
      if (marks.contains(sq)) {
        canvas.drawRect(
          r.deflate(cell * 0.05),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = const Color(0xFF1E9AC0),
        );
      }
    }
    final line = Paint()
      ..color = const Color(0xFF4A2A14)
      ..strokeWidth = math.max(1, cell * 0.02);
    for (var i = 0; i <= 9; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    // Sternpunkte
    for (final p in const [Offset(3, 3), Offset(6, 3), Offset(3, 6), Offset(6, 6)]) {
      canvas.drawCircle(p * cell, cell * 0.06, Paint()..color = const Color(0xFF4A2A14));
    }
    for (var sq = 0; sq < 81; sq++) {
      if (board[sq] == 0) continue;
      paintShogiPiece(canvas, rectOf(sq, cell), board[sq], flipped: flipped);
    }
    for (final t in targets) {
      final r = rectOf(t, cell);
      canvas.drawCircle(
        r.center,
        board[t] == 0 ? cell * 0.14 : cell * 0.42,
        board[t] == 0
            ? (Paint()..color = const Color(0xCC1E7A5A))
            : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.07
              ..color = const Color(0xCC1E7A5A)),
      );
    }
    // Koordinaten klein in die Ecken
    for (var i = 0; i < 9; i++) {
      final file = flipped ? i + 1 : 9 - i;
      final rank = flipped ? 8 - i : i;
      _label(canvas, '$file', Offset(i * cell + cell * 0.88, cell * 0.12), cell);
      _label(canvas, 'abcdefghi'[rank], Offset(size.width - cell * 0.1, i * cell + cell * 0.88), cell);
    }
  }

  void _label(Canvas canvas, String text, Offset center, double cell) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: bodyFont, fontSize: cell * 0.16, color: const Color(0xAA4A2A14)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}

/// Figuren in der Hand einer Seite, antippbar zum Einsetzen.
class ShogiHandView extends StatelessWidget {
  const ShogiHandView({
    super.key,
    required this.hand,
    required this.color,
    required this.size,
    this.selected,
    this.onTap,
    this.upsideDown = false,
  });

  final List<int> hand;
  final int color;
  final double size;
  final int? selected;
  final ValueChanged<int>? onTap;
  final bool upsideDown;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pieces = [for (var t = sRook; t >= sPawn; t--) if (hand[t] > 0) t];
    return SizedBox(
      height: size + 6,
      child: pieces.isEmpty
          ? Center(child: Text('Keine Figuren in der Hand', style: TextStyle(color: p.onFelt, fontSize: 13)))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in pieces)
                  GestureDetector(
                    onTap: onTap == null ? null : () => onTap!(t),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: selected == t ? const Color(0x9963E6FF) : Colors.transparent,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Transform.rotate(
                            angle: upsideDown ? math.pi : 0,
                            child: ShogiPieceView(piece: t, size: size),
                          ),
                          if (hand[t] > 1)
                            Positioned(
                              right: -4,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(8)),
                                child: Text('${hand[t]}',
                                    style: TextStyle(color: p.onAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            ),
    );
  }
}
