import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Airbrush-Motive im Stil von Science-Fiction-Taschenbüchern der Siebziger.
/// Alle Symbole entstehen im Code und bleiben in jeder Auflösung scharf.

Paint _radial(Rect r, List<Color> colors, {Alignment center = Alignment.center, List<double>? stops}) =>
    Paint()
      ..shader = RadialGradient(center: center, colors: colors, stops: stops)
          .createShader(r);

Paint _linear(Rect r, List<Color> colors, {Alignment begin = Alignment.topCenter, Alignment end = Alignment.bottomCenter}) =>
    Paint()
      ..shader = LinearGradient(begin: begin, end: end, colors: colors)
          .createShader(r);

/// Nachthimmel in Violett und Magenta mit festem Sternenfeld.
void paintKosmosSky(Canvas canvas, Rect rect, double twinkle) {
  canvas.drawRect(
    rect,
    _linear(rect, const [
      Color(0xFF120A33),
      Color(0xFF3A1467),
      Color(0xFFA32A6E),
      Color(0xFFF08A3C),
    ]),
  );
  final rng = math.Random(78);
  final star = Paint()..color = const Color(0xFFFFF4D6);
  for (var i = 0; i < 90; i++) {
    final x = rect.left + rng.nextDouble() * rect.width;
    final y = rect.top + rng.nextDouble() * rect.height * 0.8;
    final base = rng.nextDouble();
    final radius = 0.5 + base * 1.3;
    star.color = const Color(0xFFFFF4D6).withValues(
      alpha: (0.45 + 0.55 * math.sin(twinkle * 2 * math.pi + i).abs()).clamp(0.0, 1.0),
    );
    canvas.drawCircle(Offset(x, y), radius, star);
  }
}

/// Hintergrund hinter den Walzen.
void paintKosmosBackdrop(Canvas canvas, Rect rect, double time) {
  // 12 Funkelzyklen je Durchlauf, damit die Schleife nahtlos ist
  paintKosmosSky(canvas, rect, time * 12);
  canvas.drawRect(rect, Paint()..color = const Color(0x55120A33));
}

/// Zeichnet ein Symbol in das Quadrat r.
void paintKosmosSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = Rect.fromCenter(
    center: rect.center,
    width: rect.shortestSide,
    height: rect.shortestSide,
  );
  canvas.save();
  canvas.translate(r.left, r.top);
  final s = r.width;
  canvas.scale(s / 100);
  const box = Rect.fromLTWH(0, 0, 100, 100);
  switch (symbol) {
    case 0:
      _mond(canvas, box);
    case 1:
      _stern(canvas, box);
    case 2:
      _komet(canvas, box);
    case 3:
      _planet(canvas, box);
    case 4:
      _ufo(canvas, box);
    case 5:
      _rakete(canvas, box);
    case 6:
      _sonne(canvas, box);
    case 7:
      _loch(canvas, box);
  }
  canvas.restore();
}

void _glow(Canvas c, Offset o, double radius, Color color) {
  final rect = Rect.fromCircle(center: o, radius: radius);
  c.drawCircle(o, radius, _radial(rect, [color, color.withValues(alpha: 0)]));
}

void _mond(Canvas c, Rect b) {
  _glow(c, const Offset(50, 50), 46, const Color(0x668FD6FF));
  final disc = Rect.fromCircle(center: const Offset(50, 50), radius: 34);
  final moon = Path.combine(
    PathOperation.difference,
    Path()..addOval(disc),
    Path()..addOval(Rect.fromCircle(center: const Offset(66, 42), radius: 29)),
  );
  c.drawPath(
    moon,
    _radial(disc, const [Color(0xFFF4FBFF), Color(0xFF9CC7E8), Color(0xFF4E6FB5)],
        center: const Alignment(-0.5, 0.1)),
  );
  final crater = Paint()..color = const Color(0x554E6FB5);
  c.drawCircle(const Offset(29, 46), 5, crater);
  c.drawCircle(const Offset(37, 66), 3.6, crater);
  c.drawCircle(const Offset(25, 61), 2.6, crater);
}

Path _starPath(Offset c, double outer, double inner, int points, double rot) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final radius = i.isEven ? outer : inner;
    final a = rot + i * math.pi / points;
    final o = c + Offset(math.cos(a), math.sin(a)) * radius;
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

void _stern(Canvas c, Rect b) {
  const o = Offset(50, 50);
  _glow(c, o, 46, const Color(0x88FFE27A));
  c.drawPath(
    _starPath(o, 38, 15, 5, -math.pi / 2),
    _radial(b, const [Color(0xFFFFFDE8), Color(0xFFFFD24A), Color(0xFFE5791F)]),
  );
  c.drawPath(
    _starPath(o, 15, 6, 4, math.pi / 4),
    Paint()..color = const Color(0xCCFFFFFF),
  );
}

void _komet(Canvas c, Rect b) {
  final tail = Path()
    ..moveTo(92, 8)
    ..quadraticBezierTo(62, 22, 38, 50)
    ..lineTo(50, 62)
    ..quadraticBezierTo(78, 38, 92, 8)
    ..close();
  c.drawPath(
    tail,
    _linear(b, const [Color(0x00FF5EA8), Color(0xFFFF8A3C)],
        begin: Alignment.topRight, end: Alignment.bottomLeft),
  );
  final tail2 = Path()
    ..moveTo(70, 10)
    ..quadraticBezierTo(50, 26, 34, 48)
    ..lineTo(42, 54)
    ..quadraticBezierTo(60, 32, 70, 10)
    ..close();
  c.drawPath(
    tail2,
    _linear(b, const [Color(0x00FFE27A), Color(0xFFFFE27A)],
        begin: Alignment.topRight, end: Alignment.bottomLeft),
  );
  const head = Offset(36, 64);
  _glow(c, head, 34, const Color(0xAAFF9F5A));
  final disc = Rect.fromCircle(center: head, radius: 20);
  c.drawCircle(
    head,
    20,
    _radial(disc, const [Color(0xFFFFFDE8), Color(0xFFFFB347), Color(0xFFC63B2C)],
        center: const Alignment(-0.3, -0.3)),
  );
}

void _planet(Canvas c, Rect b) {
  const o = Offset(50, 50);
  final disc = Rect.fromCircle(center: o, radius: 30);
  void ring(double start, double sweep) {
    c.save();
    c.translate(50, 50);
    c.rotate(-0.42);
    final rr = Rect.fromCenter(center: Offset.zero, width: 94, height: 26);
    c.drawArc(
      rr,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFFFD98A),
    );
    c.drawArc(
      rr.deflate(5),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFE06A9F),
    );
    c.restore();
  }

  ring(math.pi, math.pi);
  c.drawCircle(
    o,
    30,
    _radial(disc, const [Color(0xFFFFB7D5), Color(0xFFE0457F), Color(0xFF5A1B6E)],
        center: const Alignment(-0.45, -0.5)),
  );
  c.save();
  c.clipPath(Path()..addOval(disc));
  final band = Paint()..color = const Color(0x44FFE9A8);
  c.save();
  c.translate(50, 50);
  c.rotate(-0.42);
  c.drawRect(const Rect.fromLTWH(-40, -12, 80, 6), band);
  c.drawRect(const Rect.fromLTWH(-40, 4, 80, 9), band);
  c.restore();
  c.restore();
  ring(0, math.pi);
}

void _ufo(Canvas c, Rect b) {
  // Lichtkegel
  final beam = Path()
    ..moveTo(38, 60)
    ..lineTo(62, 60)
    ..lineTo(80, 97)
    ..lineTo(20, 97)
    ..close();
  c.drawPath(beam, _linear(b, const [Color(0xAA7DF7D9), Color(0x007DF7D9)]));
  // Kuppel
  final dome = Rect.fromCircle(center: const Offset(50, 44), radius: 20);
  c.drawArc(
    dome,
    math.pi,
    math.pi,
    true,
    _radial(dome, const [Color(0xFFE6FFF8), Color(0xFF52D6C4), Color(0xFF137C8A)],
        center: const Alignment(-0.4, -0.6)),
  );
  // Scheibe
  final body = Rect.fromCenter(center: const Offset(50, 50), width: 88, height: 26);
  c.drawOval(
    body,
    _linear(body, const [Color(0xFFF2F5FF), Color(0xFF8D93B8), Color(0xFF3B3D66)]),
  );
  for (var i = -2; i <= 2; i++) {
    final o = Offset(50 + i * 16.0, 53 - i.abs() * 1.4);
    _glow(c, o, 8, const Color(0xAAFFC95C));
    c.drawCircle(o, 3, Paint()..color = const Color(0xFFFFF4C2));
  }
}

void _rakete(Canvas c, Rect b) {
  c.save();
  c.translate(50, 50);
  c.rotate(0.5);
  c.translate(-50, -50);
  // Flamme
  final flame = Path()
    ..moveTo(40, 74)
    ..quadraticBezierTo(50, 112, 60, 74)
    ..close();
  c.drawPath(flame, _linear(b, const [Color(0xFFFFF4C2), Color(0xFFFF8A3C), Color(0xFFD8402B)]));
  // Flossen
  final fin = Paint()..color = const Color(0xFFD8402B);
  c.drawPath(
    Path()
      ..moveTo(36, 50)
      ..lineTo(18, 80)
      ..lineTo(38, 72)
      ..close(),
    fin,
  );
  c.drawPath(
    Path()
      ..moveTo(64, 50)
      ..lineTo(82, 80)
      ..lineTo(62, 72)
      ..close(),
    fin,
  );
  // Rumpf
  final hull = Path()
    ..moveTo(50, 4)
    ..cubicTo(72, 26, 68, 62, 62, 76)
    ..lineTo(38, 76)
    ..cubicTo(32, 62, 28, 26, 50, 4)
    ..close();
  c.drawPath(
    hull,
    _linear(b, const [Color(0xFF8D93B8), Color(0xFFFFFFFF), Color(0xFFC6C9DE), Color(0xFF6A6E96)],
        begin: Alignment.centerLeft, end: Alignment.centerRight),
  );
  c.save();
  c.clipPath(hull);
  c.drawRect(const Rect.fromLTWH(20, 0, 60, 19), Paint()..color = const Color(0xFFD8402B));
  c.restore();
  // Fenster
  final port = Rect.fromCircle(center: const Offset(50, 40), radius: 10);
  c.drawCircle(const Offset(50, 40), 12, Paint()..color = const Color(0xFF3B3D66));
  c.drawCircle(
    const Offset(50, 40),
    10,
    _radial(port, const [Color(0xFFD9FBFF), Color(0xFF3FA9D6)], center: const Alignment(-0.4, -0.4)),
  );
  c.restore();
}

/// Joker: Sonne mit Gesicht wie auf einem Albumcover von 1978.
void _sonne(Canvas c, Rect b) {
  const o = Offset(50, 50);
  _glow(c, o, 50, const Color(0xCCFFB347));
  c.drawPath(
    _starPath(o, 48, 31, 12, 0),
    _radial(b, const [Color(0xFFFFE27A), Color(0xFFFF8A3C), Color(0xFFD8402B)]),
  );
  final disc = Rect.fromCircle(center: o, radius: 31);
  c.drawCircle(
    o,
    31,
    _radial(disc, const [Color(0xFFFFFDE8), Color(0xFFFFD24A), Color(0xFFF08A3C)],
        center: const Alignment(-0.3, -0.35)),
  );
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF7A1F12);
  c.drawArc(const Rect.fromLTWH(32, 38, 14, 12), math.pi, math.pi, false, ink);
  c.drawArc(const Rect.fromLTWH(54, 38, 14, 12), math.pi, math.pi, false, ink);
  c.drawArc(const Rect.fromLTWH(34, 42, 32, 26), 0.25, math.pi - 0.5, false, ink);
}

/// Scatter: Schwarzes Loch mit glühender Akkretionsscheibe.
void _loch(Canvas c, Rect b) {
  c.save();
  c.translate(50, 50);
  c.rotate(-0.3);
  c.scale(1, 0.56);
  const disc = Rect.fromLTWH(-46, -46, 92, 92);
  c.drawCircle(
    Offset.zero,
    46,
    Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFFF4C2),
          Color(0xFFFF8A3C),
          Color(0xFFD12F7E),
          Color(0xFF5A1B9E),
          Color(0xFFD12F7E),
          Color(0xFFFF8A3C),
          Color(0xFFFFF4C2),
        ],
      ).createShader(disc),
  );
  c.drawCircle(
    Offset.zero,
    46,
    _radial(disc, const [Color(0x00000000), Color(0x00000000), Color(0xAA120A33)],
        stops: const [0, 0.7, 1]),
  );
  c.restore();
  c.drawCircle(const Offset(50, 50), 21, Paint()..color = const Color(0xFF05030F));
  c.drawCircle(
    const Offset(50, 50),
    22.5,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFFFFE9A8),
  );
}
