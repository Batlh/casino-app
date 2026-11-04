import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Flache Plakatfarben wie auf einer Samentüte: klare Flächen, dunkle Kontur.

const _ink = Color(0xFF3A2413);

Paint _fill(Color c) => Paint()..color = c;

Paint _line([double w = 3]) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = _ink;

void _shape(Canvas c, Path p, Color color, [double w = 3]) {
  c.drawPath(p, _fill(color));
  c.drawPath(p, _line(w));
}

void paintGartenBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(rect, _fill(const Color(0xFFFFF1C9)));
  // Gartenzaun
  final fence = _fill(const Color(0xFFFBE3A8));
  final slat = rect.width / 12;
  for (var i = 0; i < 12; i++) {
    final x = rect.left + i * slat;
    canvas.drawRect(
      Rect.fromLTWH(x + slat * 0.14, rect.top, slat * 0.72, rect.height),
      fence,
    );
  }
}

void paintGartenSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = Rect.fromCenter(
    center: rect.center,
    width: rect.shortestSide,
    height: rect.shortestSide,
  );
  canvas.save();
  canvas.translate(r.left, r.top);
  canvas.scale(r.width / 100);
  switch (symbol) {
    case 0:
      _radieschen(canvas);
    case 1:
      _tomate(canvas);
    case 2:
      _sonnenblume(canvas);
    case 3:
      _giesskanne(canvas);
    case 4:
      _bratwurst(canvas);
    case 5:
      _bier(canvas);
    case 6:
      _zwerg(canvas);
  }
  canvas.restore();
}

void _leaf(Canvas c, double x, double y, double angle, double size) {
  c.save();
  c.translate(x, y);
  c.rotate(angle);
  _shape(
    c,
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size * 0.4, -size * 0.8, 0, -size)
      ..quadraticBezierTo(-size * 0.4, -size * 0.8, 0, 0)
      ..close(),
    const Color(0xFF5E9A3E),
  );
  c.restore();
}

void _radieschen(Canvas c) {
  _leaf(c, 50, 42, -0.5, 34);
  _leaf(c, 50, 42, 0.5, 34);
  _leaf(c, 50, 42, 0, 38);
  _shape(
    c,
    Path()
      ..moveTo(50, 40)
      ..cubicTo(84, 38, 80, 74, 52, 82)
      ..lineTo(50, 96)
      ..lineTo(48, 82)
      ..cubicTo(20, 74, 16, 38, 50, 40)
      ..close(),
    const Color(0xFFD8335E),
  );
  c.drawArc(
    const Rect.fromLTWH(32, 52, 18, 20),
    2.2,
    1.6,
    false,
    _line(3)..color = const Color(0xFFFFD6E0),
  );
}

void _tomate(Canvas c) {
  _shape(
    c,
    Path()..addOval(const Rect.fromLTWH(12, 26, 76, 66)),
    const Color(0xFFD8402B),
  );
  c.drawArc(
    const Rect.fromLTWH(24, 38, 30, 34),
    2.6,
    1.4,
    false,
    _line(4)..color = const Color(0xFFFFB8A8),
  );
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? 24.0 : 8.0;
    final a = -math.pi / 2 + i * math.pi / 5;
    final x = 50 + math.cos(a) * radius;
    final y = 28 + math.sin(a) * radius * 0.7;
    i == 0 ? star.moveTo(x, y) : star.lineTo(x, y);
  }
  _shape(c, star..close(), const Color(0xFF5E9A3E));
  c.drawLine(const Offset(50, 26), const Offset(52, 10), _line(4));
}

void _sonnenblume(Canvas c) {
  const o = Offset(50, 50);
  for (var i = 0; i < 14; i++) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(i * 2 * math.pi / 14);
    _shape(
      c,
      Path()
        ..moveTo(-8, -20)
        ..quadraticBezierTo(0, -56, 8, -20)
        ..close(),
      const Color(0xFFF7C325),
      2.2,
    );
    c.restore();
  }
  c.drawCircle(o, 22, _fill(const Color(0xFF6B3E1E)));
  c.drawCircle(o, 22, _line());
  final seed = _fill(const Color(0xFF3A2113));
  for (var i = 0; i < 40; i++) {
    final a = i * 2.39996;
    final d = 2.9 * math.sqrt(i.toDouble());
    c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * d, 1.2, seed);
  }
}

void _giesskanne(Canvas c) {
  // Griff
  c.drawArc(
    const Rect.fromLTWH(44, 14, 44, 50),
    -math.pi * 0.9,
    math.pi * 1.1,
    false,
    _line(7)..color = const Color(0xFF2E7D6B),
  );
  // Tülle und Brause
  _shape(
    c,
    Path()
      ..moveTo(38, 66)
      ..lineTo(14, 34)
      ..lineTo(21, 29)
      ..lineTo(40, 50)
      ..close(),
    const Color(0xFF3FA88F),
  );
  _shape(
    c,
    Path()
      ..moveTo(4, 36)
      ..lineTo(24, 20)
      ..lineTo(28, 30)
      ..lineTo(14, 44)
      ..close(),
    const Color(0xFF2E7D6B),
  );
  // Körper
  _shape(
    c,
    Path()
      ..moveTo(36, 36)
      ..lineTo(80, 36)
      ..lineTo(84, 88)
      ..lineTo(32, 88)
      ..close(),
    const Color(0xFF3FA88F),
  );
  c.drawLine(const Offset(44, 46), const Offset(42, 78), _line(4)..color = const Color(0xFFA8E6D6));
  // Tropfen
  final drop = _fill(const Color(0xFF4AA3DF));
  c.drawCircle(const Offset(4, 56), 2.6, drop);
  c.drawCircle(const Offset(11, 66), 2.6, drop);
  c.drawCircle(const Offset(3, 74), 2.6, drop);
}

void _bratwurst(Canvas c) {
  c.save();
  c.translate(50, 54);
  c.rotate(-0.3);
  // Pappschale
  _shape(
    c,
    Path()
      ..moveTo(-46, 8)
      ..lineTo(46, 8)
      ..lineTo(36, 32)
      ..lineTo(-36, 32)
      ..close(),
    const Color(0xFFF2EAD3),
  );
  _shape(
    c,
    Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-46, -18, 92, 32),
          const Radius.circular(16),
        ),
      ),
    const Color(0xFFA85F1C),
  );
  final grill = _line(4)..color = const Color(0xFF5A3218);
  for (var i = -2; i <= 2; i++) {
    final x = i * 15.0;
    c.drawLine(Offset(x - 5, -14), Offset(x + 5, 10), grill);
  }
  // Senf
  final mustard = Path()..moveTo(-38, -4);
  for (var i = 0; i < 8; i++) {
    mustard.relativeQuadraticBezierTo(5, i.isEven ? -12 : 12, 10.5, 0);
  }
  c.drawPath(mustard, _line(4)..color = const Color(0xFFF7C325));
  c.restore();
}

void _bier(Canvas c) {
  // Henkel
  c.drawArc(
    const Rect.fromLTWH(62, 36, 30, 38),
    -math.pi / 2,
    math.pi,
    false,
    _line(7),
  );
  // Glas
  _shape(
    c,
    Path()
      ..moveTo(18, 26)
      ..lineTo(74, 26)
      ..lineTo(70, 92)
      ..lineTo(22, 92)
      ..close(),
    const Color(0xFFF2A33A),
  );
  final bubble = _fill(const Color(0xFFFFD98A));
  c.drawCircle(const Offset(36, 72), 2.6, bubble);
  c.drawCircle(const Offset(50, 56), 2.2, bubble);
  c.drawCircle(const Offset(58, 76), 3, bubble);
  c.drawCircle(const Offset(40, 48), 2.2, bubble);
  // Schaum
  _shape(
    c,
    Path()
      ..moveTo(14, 34)
      ..cubicTo(6, 14, 28, 8, 36, 16)
      ..cubicTo(44, 2, 64, 6, 66, 16)
      ..cubicTo(82, 12, 86, 32, 74, 36)
      ..quadraticBezierTo(70, 46, 60, 38)
      ..quadraticBezierTo(46, 46, 34, 38)
      ..quadraticBezierTo(22, 44, 14, 34)
      ..close(),
    const Color(0xFFFFF8E7),
  );
}

/// Joker: der Gartenzwerg, Herr über die Parzelle.
void _zwerg(Canvas c) {
  // Stiefel und Körper
  _shape(c, Path()..addOval(const Rect.fromLTWH(26, 82, 22, 13)), _ink);
  _shape(c, Path()..addOval(const Rect.fromLTWH(52, 82, 22, 13)), _ink);
  _shape(
    c,
    Path()
      ..moveTo(26, 88)
      ..cubicTo(22, 62, 36, 54, 50, 54)
      ..cubicTo(64, 54, 78, 62, 74, 88)
      ..close(),
    const Color(0xFF2F6FB5),
  );
  // Gürtel
  c.drawLine(const Offset(26, 76), const Offset(74, 76), _line(5));
  c.drawRect(const Rect.fromLTWH(44, 71, 12, 10), _fill(const Color(0xFFF7C325)));
  // Bart
  _shape(
    c,
    Path()
      ..moveTo(28, 42)
      ..quadraticBezierTo(30, 76, 50, 76)
      ..quadraticBezierTo(70, 76, 72, 42)
      ..close(),
    const Color(0xFFFFFDF5),
  );
  // Gesicht
  _shape(c, Path()..addOval(const Rect.fromLTWH(32, 30, 36, 24)), const Color(0xFFF7C9A0));
  c.drawCircle(const Offset(50, 47), 6.4, _fill(const Color(0xFFE5705A)));
  c.drawCircle(const Offset(42, 39), 2.6, _fill(_ink));
  c.drawCircle(const Offset(58, 39), 2.6, _fill(_ink));
  // Mütze
  _shape(
    c,
    Path()
      ..moveTo(24, 36)
      ..quadraticBezierTo(38, 12, 54, 2)
      ..quadraticBezierTo(70, 18, 76, 36)
      ..quadraticBezierTo(50, 26, 24, 36)
      ..close(),
    const Color(0xFFD8402B),
  );
}
