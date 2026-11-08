import 'package:flutter/material.dart';

import 'chess_engine.dart';

/// Gezeichnete Schachfiguren, ohne Schriftart, damit sie überall gleich aussehen.
class ChessPieceView extends StatelessWidget {
  const ChessPieceView({super.key, required this.piece, required this.size});

  /// Figur wie im Brett: Vorzeichen ist die Farbe.
  final int piece;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: ChessPiecePainter(piece));
}

class ChessPiecePainter extends CustomPainter {
  ChessPiecePainter(this.piece);
  final int piece;

  static const light = Color(0xFFFBF1DC);
  static const dark = Color(0xFF2A1A12);

  static Path pathFor(int type) {
    final p = Path();
    // Sockel
    p.addRRect(RRect.fromLTRBR(24, 80, 76, 90, const Radius.circular(3)));
    switch (type) {
      case pawn:
        p.addOval(Rect.fromCircle(center: const Offset(50, 30), radius: 13));
        p.moveTo(42, 42);
        p.lineTo(58, 42);
        p.lineTo(68, 80);
        p.lineTo(32, 80);
        p.close();
      case rook:
        p.moveTo(28, 16);
        p.lineTo(37, 16);
        p.lineTo(37, 24);
        p.lineTo(45, 24);
        p.lineTo(45, 16);
        p.lineTo(55, 16);
        p.lineTo(55, 24);
        p.lineTo(63, 24);
        p.lineTo(63, 16);
        p.lineTo(72, 16);
        p.lineTo(72, 34);
        p.lineTo(65, 38);
        p.lineTo(68, 80);
        p.lineTo(32, 80);
        p.lineTo(35, 38);
        p.lineTo(28, 34);
        p.close();
      case knight:
        p.moveTo(32, 80);
        p.lineTo(70, 80);
        p.cubicTo(72, 60, 68, 36, 58, 22);
        p.lineTo(56, 12);
        p.lineTo(49, 19);
        p.lineTo(44, 12);
        p.lineTo(41, 21);
        p.cubicTo(32, 26, 24, 38, 22, 50);
        p.cubicTo(22, 56, 28, 58, 32, 55);
        p.lineTo(40, 49);
        p.cubicTo(44, 49, 47, 47, 49, 44);
        p.cubicTo(48, 58, 34, 64, 32, 80);
        p.close();
      case bishop:
        p.addOval(Rect.fromCircle(center: const Offset(50, 11), radius: 6));
        p.moveTo(50, 17);
        p.cubicTo(66, 28, 70, 44, 60, 56);
        p.lineTo(40, 56);
        p.cubicTo(30, 44, 34, 28, 50, 17);
        p.close();
        p.moveTo(40, 60);
        p.lineTo(60, 60);
        p.lineTo(68, 80);
        p.lineTo(32, 80);
        p.close();
      case queen:
        for (final c in const [Offset(22, 26), Offset(36, 18), Offset(50, 14), Offset(64, 18), Offset(78, 26)]) {
          p.addOval(Rect.fromCircle(center: c, radius: 5));
        }
        p.moveTo(30, 80);
        p.lineTo(70, 80);
        p.lineTo(78, 30);
        p.lineTo(64, 50);
        p.lineTo(64, 22);
        p.lineTo(56, 48);
        p.lineTo(50, 18);
        p.lineTo(44, 48);
        p.lineTo(36, 22);
        p.lineTo(36, 50);
        p.lineTo(22, 30);
        p.close();
      case king:
        p.addRect(const Rect.fromLTRB(46, 6, 54, 30));
        p.addRect(const Rect.fromLTRB(38, 12, 62, 19));
        p.moveTo(32, 80);
        p.lineTo(68, 80);
        p.lineTo(74, 46);
        p.cubicTo(76, 34, 60, 30, 50, 40);
        p.cubicTo(40, 30, 24, 34, 26, 46);
        p.close();
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (piece == 0) return;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final path = pathFor(piece.abs());
    final isWhite = piece > 0;
    // Schatten
    canvas.drawPath(path.shift(const Offset(1.5, 2.5)), Paint()..color = const Color(0x55000000));
    canvas.drawPath(path, Paint()..color = isWhite ? light : dark);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..color = isWhite ? dark : light,
    );
    // Feine Zierlinie am Sockel und Läuferschlitz
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = isWhite ? dark : light;
    if (piece.abs() == bishop) canvas.drawLine(const Offset(46, 42), const Offset(56, 32), line);
    if (piece.abs() == knight) {
      canvas.drawCircle(const Offset(46, 28), 2.6, Paint()..color = isWhite ? dark : light);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChessPiecePainter old) => old.piece != piece;
}
