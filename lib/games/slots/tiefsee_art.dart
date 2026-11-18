import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Biolumineszenz: Alles leuchtet aus dem Dunkel heraus.

void _glow(Canvas c, Offset o, double radius, Color color) {
  final rect = Rect.fromCircle(center: o, radius: radius);
  c.drawCircle(
    o,
    radius,
    Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(rect),
  );
}

Paint _radial(Rect r, List<Color> colors, {Alignment center = Alignment.center}) =>
    Paint()..shader = RadialGradient(center: center, colors: colors).createShader(r);

Paint _linear(Rect r, List<Color> colors) => Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
  ).createShader(r);

void paintTiefseeBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    _linear(rect, const [Color(0xFF0B4A63), Color(0xFF052238), Color(0xFF020A18)]),
  );
  // Lichtstrahlen von oben
  for (var i = 0; i < 4; i++) {
    final x = rect.left + rect.width * (0.15 + i * 0.25);
    final ray = Path()
      ..moveTo(x, rect.top)
      ..lineTo(x + rect.width * 0.08, rect.top)
      ..lineTo(x - rect.width * 0.1, rect.bottom * 0.75)
      ..lineTo(x - rect.width * 0.22, rect.bottom * 0.75)
      ..close();
    canvas.drawPath(ray, Paint()..color = const Color(0x0C9CF0FF));
  }
  // Aufsteigende Bläschen und Schwebeteilchen
  final rng = math.Random(3000);
  for (var i = 0; i < 46; i++) {
    final x = rect.left + rng.nextDouble() * rect.width;
    // Ganze Umläufe je Durchlauf: nahtlose Schleife
    final speed = 6 + rng.nextInt(13);
    final y0 = rng.nextDouble();
    final y = rect.top + ((y0 - time * speed) % 1.0) * rect.height;
    final r = 0.8 + rng.nextDouble() * 2.2;
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()..color = const Color(0x557DF7D9),
    );
  }
}

void paintTiefseeSymbol(Canvas canvas, Rect rect, int symbol) {
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
      _seestern(canvas);
    case 1:
      _muschel(canvas);
    case 2:
      _seepferdchen(canvas);
    case 3:
      _kugelfisch(canvas);
    case 4:
      _krake(canvas);
    case 5:
      _angler(canvas);
    case 6:
      _qualle(canvas);
    case 7:
      _perle(canvas);
  }
  canvas.restore();
}

void _seestern(Canvas c) {
  const o = Offset(50, 52);
  _glow(c, o, 46, const Color(0x55FF6FA3));
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? 40.0 : 15.0;
    final a = -math.pi / 2 + i * math.pi / 5;
    final q = o + Offset(math.cos(a), math.sin(a)) * radius;
    i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
  }
  p.close();
  c.drawPath(
    p,
    Paint()
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFFE5457E),
  );
  c.drawPath(
    p,
    _radial(
      const Rect.fromLTWH(0, 0, 100, 100),
      const [Color(0xFFFFC1D6), Color(0xFFFF6FA3), Color(0xFFD12F7E)],
    ),
  );
  final dot = Paint()..color = const Color(0xCCFFF1F6);
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    for (final d in [10.0, 18.0, 26.0]) {
      c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * d, 2.2, dot);
    }
  }
}

void _muschel(Canvas c) {
  _glow(c, const Offset(50, 54), 44, const Color(0x55FFD9A8));
  const bottom = Offset(50, 88);
  final shell = Path()
    ..moveTo(bottom.dx, bottom.dy)
    ..cubicTo(6, 66, 8, 22, 50, 14)
    ..cubicTo(92, 22, 94, 66, bottom.dx, bottom.dy)
    ..close();
  c.drawPath(
    shell,
    _radial(
      const Rect.fromLTWH(0, 0, 100, 100),
      const [Color(0xFFFFF4E0), Color(0xFFFFC48A), Color(0xFFE5705A)],
      center: const Alignment(0, -0.5),
    ),
  );
  final rib = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xAAB5453A);
  for (var i = -3; i <= 3; i++) {
    c.drawLine(
      bottom,
      Offset(50 + i * 12.5, 22 + i.abs() * i.abs() * 2.4),
      rib,
    );
  }
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(38, 82, 24, 10),
      const Radius.circular(4),
    ),
    Paint()..color = const Color(0xFFE5705A),
  );
}

void _seepferdchen(Canvas c) {
  _glow(c, const Offset(50, 50), 46, const Color(0x55FFE27A));
  final body = Path()
    ..moveTo(44, 24)
    ..cubicTo(68, 20, 72, 44, 60, 56)
    ..cubicTo(52, 66, 58, 74, 64, 78)
    ..cubicTo(70, 84, 62, 94, 52, 90)
    ..cubicTo(40, 84, 40, 70, 44, 60)
    ..cubicTo(36, 50, 34, 36, 44, 24)
    ..close();
  c.drawPath(
    body,
    _linear(
      const Rect.fromLTWH(0, 10, 100, 85),
      const [Color(0xFFFFE27A), Color(0xFFFF9F3C), Color(0xFFD8402B)],
    ),
  );
  // Schnauze
  c.drawPath(
    Path()
      ..moveTo(46, 24)
      ..quadraticBezierTo(30, 24, 20, 32)
      ..lineTo(23, 37)
      ..quadraticBezierTo(36, 34, 44, 36)
      ..close(),
    Paint()..color = const Color(0xFFFFC95C),
  );
  // Rückenflosse
  c.drawPath(
    Path()
      ..moveTo(62, 40)
      ..quadraticBezierTo(82, 44, 74, 58)
      ..quadraticBezierTo(70, 56, 60, 56)
      ..close(),
    Paint()..color = const Color(0xCC7DF7D9),
  );
  // Krönchen
  c.drawPath(
    Path()
      ..moveTo(44, 24)
      ..lineTo(46, 12)
      ..lineTo(51, 20)
      ..lineTo(56, 11)
      ..lineTo(58, 22)
      ..close(),
    Paint()..color = const Color(0xFFD8402B),
  );
  final band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..color = const Color(0x88A32A1E);
  for (var i = 0; i < 5; i++) {
    final y = 40.0 + i * 8.5;
    c.drawLine(Offset(44, y), Offset(60 - i.toDouble(), y + 2), band);
  }
  c.drawCircle(const Offset(49, 30), 4.4, Paint()..color = Colors.white);
  c.drawCircle(const Offset(48, 30), 2.4, Paint()..color = const Color(0xFF12203A));
}

void _kugelfisch(Canvas c) {
  const o = Offset(50, 52);
  _glow(c, o, 48, const Color(0x5563E6FF));
  // Stacheln
  final spike = Paint()..color = const Color(0xFFB9772A);
  for (var i = 0; i < 18; i++) {
    final a = i * 2 * math.pi / 18;
    final d = Offset(math.cos(a), math.sin(a));
    final n = Offset(-d.dy, d.dx);
    c.drawPath(
      Path()
        ..moveTo((o + d * 42).dx, (o + d * 42).dy)
        ..lineTo((o + d * 28 + n * 5).dx, (o + d * 28 + n * 5).dy)
        ..lineTo((o + d * 28 - n * 5).dx, (o + d * 28 - n * 5).dy)
        ..close(),
      spike,
    );
  }
  final disc = Rect.fromCircle(center: o, radius: 33);
  c.drawCircle(
    o,
    33,
    _radial(
      disc,
      const [Color(0xFFFFF4C2), Color(0xFFFFC95C), Color(0xFFD99A2B)],
      center: const Alignment(0, 0.5),
    ),
  );
  c.drawArc(
    disc,
    math.pi * 0.95,
    math.pi * 1.1,
    true,
    Paint()..color = const Color(0x99A85F1C),
  );
  for (final x in [36.0, 64.0]) {
    c.drawCircle(Offset(x, 44), 9, Paint()..color = Colors.white);
    c.drawCircle(Offset(x, 45), 5, Paint()..color = const Color(0xFF12203A));
  }
  c.drawOval(
    const Rect.fromLTWH(43, 60, 14, 10),
    Paint()..color = const Color(0xFFA32A1E),
  );
}

void _krake(Canvas c) {
  _glow(c, const Offset(50, 46), 48, const Color(0x66C86BFF));
  final arm = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF8E3FC4);
  for (var i = 0; i < 6; i++) {
    final x = 24.0 + i * 10.4;
    final dir = i < 3 ? -1.0 : 1.0;
    c.drawPath(
      Path()
        ..moveTo(x, 52)
        ..cubicTo(x + dir * 2, 72, x - dir * 16, 72, x + dir * 6, 90),
      arm,
    );
  }
  final head = Path()
    ..moveTo(20, 56)
    ..cubicTo(14, 12, 86, 12, 80, 56)
    ..cubicTo(70, 64, 30, 64, 20, 56)
    ..close();
  c.drawPath(
    head,
    _radial(
      const Rect.fromLTWH(10, 10, 80, 60),
      const [Color(0xFFF0B5FF), Color(0xFFB45CE8), Color(0xFF6A2BA3)],
      center: const Alignment(-0.3, -0.5),
    ),
  );
  for (final x in [38.0, 62.0]) {
    c.drawCircle(Offset(x, 42), 7.5, Paint()..color = const Color(0xFFFFF4C2));
    c.drawRect(
      Rect.fromCenter(center: Offset(x, 42), width: 9, height: 4),
      Paint()..color = const Color(0xFF1B0B2E),
    );
  }
}

void _angler(Canvas c) {
  // Lockstab
  c.drawPath(
    Path()
      ..moveTo(42, 34)
      ..quadraticBezierTo(44, 6, 68, 12),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = const Color(0xFF7A8FA6),
  );
  _glow(c, const Offset(70, 14), 20, const Color(0xEEB6FFEE));
  c.drawCircle(const Offset(70, 14), 5, Paint()..color = const Color(0xFFF2FFFB));

  final body = Path()
    ..moveTo(10, 62)
    ..cubicTo(14, 26, 62, 22, 82, 48)
    ..lineTo(96, 34)
    ..lineTo(92, 62)
    ..lineTo(98, 86)
    ..lineTo(80, 70)
    ..cubicTo(60, 92, 16, 92, 10, 62)
    ..close();
  c.drawPath(
    body,
    _radial(
      const Rect.fromLTWH(0, 20, 100, 75),
      const [Color(0xFF4F7D9C), Color(0xFF23425E), Color(0xFF0C1C33)],
      center: const Alignment(-0.3, -0.4),
    ),
  );
  // Maul mit Zähnen
  final mouth = Path()
    ..moveTo(10, 62)
    ..quadraticBezierTo(30, 56, 46, 68)
    ..quadraticBezierTo(28, 84, 14, 74)
    ..close();
  c.drawPath(mouth, Paint()..color = const Color(0xFF05070F));
  final tooth = Paint()..color = const Color(0xFFF2FFFB);
  for (var i = 0; i < 5; i++) {
    final x = 15.0 + i * 6.2;
    c.drawPath(
      Path()
        ..moveTo(x, 60.5 + i * 0.6)
        ..lineTo(x + 4.5, 60.5 + i * 0.6)
        ..lineTo(x + 2.2, 69)
        ..close(),
      tooth,
    );
    c.drawPath(
      Path()
        ..moveTo(x + 2, 79 - i * 1.4)
        ..lineTo(x + 6, 78 - i * 1.4)
        ..lineTo(x + 4, 71 - i * 1.0)
        ..close(),
      tooth,
    );
  }
  c.drawCircle(const Offset(36, 46), 7, Paint()..color = const Color(0xFFFFC95C));
  c.drawCircle(const Offset(35, 46), 3.4, Paint()..color = const Color(0xFF05070F));
}

/// Joker: Qualle, die aus sich heraus leuchtet.
void _qualle(Canvas c) {
  _glow(c, const Offset(50, 42), 50, const Color(0x8863E6FF));
  final tentacle = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xCC8FF3FF);
  for (var i = 0; i < 6; i++) {
    final x = 26.0 + i * 9.6;
    final s = i.isEven ? 1.0 : -1.0;
    c.drawPath(
      Path()
        ..moveTo(x, 50)
        ..cubicTo(x + s * 9, 62, x - s * 9, 74, x + s * 3, 94),
      tentacle,
    );
  }
  final bell = Path()
    ..moveTo(14, 52)
    ..cubicTo(12, 4, 88, 4, 86, 52)
    ..quadraticBezierTo(77, 44, 68, 52)
    ..quadraticBezierTo(59, 44, 50, 52)
    ..quadraticBezierTo(41, 44, 32, 52)
    ..quadraticBezierTo(23, 44, 14, 52)
    ..close();
  c.drawPath(
    bell,
    _radial(
      const Rect.fromLTWH(10, 8, 80, 50),
      const [Color(0xFFF2FFFB), Color(0xFF8FF3FF), Color(0xFF3AA9E0)],
      center: const Alignment(-0.25, -0.5),
    ),
  );
  c.drawOval(
    const Rect.fromLTWH(32, 18, 36, 18),
    Paint()..color = const Color(0x77FF9FD8),
  );
}

/// Scatter: Perle in der offenen Schale.
void _perle(Canvas c) {
  const o = Offset(50, 46);
  _glow(c, o, 48, const Color(0x99FFF1FF));
  final lower = Path()
    ..moveTo(8, 56)
    ..quadraticBezierTo(50, 112, 92, 56)
    ..quadraticBezierTo(50, 72, 8, 56)
    ..close();
  c.drawPath(
    lower,
    _linear(
      const Rect.fromLTWH(0, 50, 100, 45),
      const [Color(0xFF2B7FA8), Color(0xFF0F3D63)],
    ),
  );
  final disc = Rect.fromCircle(center: o, radius: 25);
  c.drawCircle(
    o,
    25,
    _radial(
      disc,
      const [Colors.white, Color(0xFFF7D9F2), Color(0xFFB9A3E8), Color(0xFF7D6BC2)],
      center: const Alignment(-0.4, -0.45),
    ),
  );
  c.drawCircle(const Offset(41, 36), 5, Paint()..color = const Color(0xCCFFFFFF));
}
