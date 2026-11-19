import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Goldgräber: Wüstencanyon zur Abendzeit.
/// Niedrig: 0 Hufeisen, 1 Laterne, 10 Spitzhacke, 11 Waschpfanne, 2 Kaktus.
/// Hoch: 3 Sheriffstern, 4 Goldsack, 5 Goldklumpen. 6 Hut (Joker), 7 Schatzkarte (Streusymbol).

const _ink = Color(0xFF2A160A);

void paintGoldBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3B1C4A), Color(0xFFB4502A), Color(0xFFE59A4B), Color(0xFF6E3518)],
        stops: [0, 0.45, 0.62, 1],
      ).createShader(rect),
  );
  // Sonne hinter den Felsen
  final sun = Offset(rect.left + rect.width * 0.7, rect.top + rect.height * 0.55);
  glow(canvas, sun, rect.width * 0.25, const Color(0x66FFD54F));
  canvas.drawCircle(sun, rect.width * 0.07, fillOf(const Color(0xFFFFE082)));
  // Tafelberge
  final mesa = Path()
    ..moveTo(rect.left, rect.top + rect.height * 0.62)
    ..lineTo(rect.left + rect.width * 0.08, rect.top + rect.height * 0.62)
    ..lineTo(rect.left + rect.width * 0.12, rect.top + rect.height * 0.44)
    ..lineTo(rect.left + rect.width * 0.32, rect.top + rect.height * 0.44)
    ..lineTo(rect.left + rect.width * 0.36, rect.top + rect.height * 0.58)
    ..lineTo(rect.left + rect.width * 0.58, rect.top + rect.height * 0.6)
    ..lineTo(rect.left + rect.width * 0.62, rect.top + rect.height * 0.5)
    ..lineTo(rect.left + rect.width * 0.78, rect.top + rect.height * 0.5)
    ..lineTo(rect.left + rect.width * 0.8, rect.top + rect.height * 0.62)
    ..lineTo(rect.right, rect.top + rect.height * 0.64)
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();
  canvas.drawPath(mesa, fillOf(const Color(0xFF5A2410)));
  canvas.drawRect(Rect.fromLTRB(rect.left, rect.top + rect.height * 0.78, rect.right, rect.bottom), fillOf(const Color(0x33000000)));
  // Wehender Staub; jede Wolke zieht eine ganze Zahl von Malen durchs Bild
  for (var i = 0; i < 14; i++) {
    final turns = 1 + i % 2;
    final x = rect.left - 30 + (rect.width + 60) * ((time * turns + i * 0.31) % 1);
    final y = rect.top + rect.height * (0.66 + (i * 0.073) % 0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 26.0 + (i % 3) * 10, height: 6), fillOf(const Color(0x22FFE0B2)));
  }
}

void paintGoldSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Hufeisen
      canvas.drawArc(
        Rect.fromCircle(center: c.translate(0, -w * 0.02), radius: w * 0.25),
        math.pi * 0.78,
        math.pi * 1.44,
        false,
        strokeOf(const Color(0xFF424242), w * 0.16)..strokeCap = StrokeCap.butt,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c.translate(0, -w * 0.02), radius: w * 0.25),
        math.pi * 0.78,
        math.pi * 1.44,
        false,
        strokeOf(const Color(0xFFB0BEC5), w * 0.1)..strokeCap = StrokeCap.butt,
      );
      for (var i = 0; i < 6; i++) {
        final a = math.pi * (0.9 + i * 0.24);
        canvas.drawCircle(c.translate(math.cos(a) * w * 0.25, -w * 0.02 + math.sin(a) * w * 0.25), w * 0.022, fillOf(_ink));
      }
    case 1: // Laterne
      glow(canvas, c.translate(0, w * 0.05), w * 0.32, const Color(0x88FFB300));
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.3), width: w * 0.24, height: w * 0.2), math.pi, math.pi, false, strokeOf(const Color(0xFF3E2723), w * 0.03));
      final cap = Path()
        ..moveTo(c.dx - w * 0.18, c.dy - w * 0.16)
        ..lineTo(c.dx - w * 0.1, c.dy - w * 0.28)
        ..lineTo(c.dx + w * 0.1, c.dy - w * 0.28)
        ..lineTo(c.dx + w * 0.18, c.dy - w * 0.16)
        ..close();
      shaded(canvas, cap, const Color(0xFF8D6E63), const Color(0xFF3E2723), width: 1.5);
      final glass = Rect.fromLTRB(c.dx - w * 0.15, c.dy - w * 0.16, c.dx + w * 0.15, c.dy + w * 0.24);
      canvas.drawRect(glass, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF59D), Color(0xFFFF8F00)]).createShader(glass));
      final flame = Path()
        ..moveTo(c.dx, c.dy - w * 0.06)
        ..quadraticBezierTo(c.dx + w * 0.06, c.dy + w * 0.06, c.dx, c.dy + w * 0.1)
        ..quadraticBezierTo(c.dx - w * 0.06, c.dy + w * 0.06, c.dx, c.dy - w * 0.06)
        ..close();
      canvas.drawPath(flame, fillOf(Colors.white));
      for (final x in [glass.left, glass.center.dx, glass.right]) {
        canvas.drawLine(Offset(x, glass.top), Offset(x, glass.bottom), strokeOf(const Color(0xFF3E2723), w * 0.025));
      }
      final base = Rect.fromCenter(center: c.translate(0, w * 0.28), width: w * 0.4, height: w * 0.08);
      shaded(canvas, Path()..addRect(base), const Color(0xFF8D6E63), const Color(0xFF3E2723), width: 1.5);
    case 10: // Spitzhacke
      canvas.drawLine(c.translate(-w * 0.22, w * 0.34), c.translate(w * 0.14, -w * 0.18), strokeOf(const Color(0xFF3E2723), w * 0.09));
      canvas.drawLine(c.translate(-w * 0.22, w * 0.34), c.translate(w * 0.14, -w * 0.18), strokeOf(const Color(0xFFA1887F), w * 0.05));
      final head = Path()
        ..moveTo(c.dx - w * 0.2, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.12, c.dy - w * 0.32, c.dx + w * 0.38, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx + w * 0.12, c.dy - w * 0.18, c.dx - w * 0.2, c.dy - w * 0.22)
        ..close();
      shaded(canvas, head, const Color(0xFFECEFF1), const Color(0xFF546E7A));
    case 11: // Waschpfanne mit Goldkörnern
      final pan = Rect.fromCenter(center: c.translate(0, w * 0.05), width: w * 0.8, height: w * 0.48);
      canvas.drawOval(pan, Paint()..shader = const RadialGradient(colors: [Color(0xFF90A4AE), Color(0xFF37474F)]).createShader(pan));
      canvas.drawOval(pan, strokeOf(const Color(0xFF263238), 2));
      final inner = pan.deflate(w * 0.08);
      canvas.drawOval(inner, fillOf(const Color(0xFF795548)));
      final rng = math.Random(11);
      for (var i = 0; i < 9; i++) {
        final p = Offset(inner.center.dx + (rng.nextDouble() - 0.5) * inner.width * 0.7, inner.center.dy + (rng.nextDouble() - 0.5) * inner.height * 0.6);
        canvas.drawCircle(p, w * (0.02 + rng.nextDouble() * 0.02), fillOf(const Color(0xFFFFD54F)));
      }
      sparkle(canvas, inner.center.translate(w * 0.08, -w * 0.04), w * 0.06);
    case 2: // Kaktus
      final stem = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, w * 0.02), width: w * 0.2, height: w * 0.7), Radius.circular(w * 0.1));
      final arms = Path()
        ..addRRect(stem)
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - w * 0.3, c.dy - w * 0.16, w * 0.12, w * 0.3), Radius.circular(w * 0.06)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - w * 0.3, c.dy + w * 0.04, w * 0.24, w * 0.1), Radius.circular(w * 0.05)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + w * 0.18, c.dy - w * 0.26, w * 0.12, w * 0.28), Radius.circular(w * 0.06)))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + w * 0.06, c.dy - w * 0.06, w * 0.24, w * 0.1), Radius.circular(w * 0.05)));
      shaded(canvas, arms, const Color(0xFF81C784), const Color(0xFF1B5E20));
      canvas.drawLine(c.translate(0, -w * 0.28), c.translate(0, w * 0.34), strokeOf(const Color(0x552E7D32), 1.5));
      canvas.drawCircle(c.translate(0, -w * 0.34), w * 0.05, fillOf(const Color(0xFFFF4081)));
    case 3: // Sheriffstern
      final star = starPath(c, w * 0.4, n: 6, inner: 0.55);
      shaded(canvas, star, const Color(0xFFFFF59D), const Color(0xFFB8860B));
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.4, w * 0.04, fillOf(const Color(0xFFFFE082)));
      }
      canvas.drawCircle(c, w * 0.14, strokeOf(const Color(0xFF8D6E00), 2));
      sparkle(canvas, c.translate(-w * 0.12, -w * 0.16), w * 0.06);
    case 4: // Goldsack
      final bag = Path()
        ..moveTo(c.dx - w * 0.1, c.dy - w * 0.22)
        ..cubicTo(c.dx - w * 0.44, c.dy - w * 0.05, c.dx - w * 0.4, c.dy + w * 0.38, c.dx, c.dy + w * 0.38)
        ..cubicTo(c.dx + w * 0.4, c.dy + w * 0.38, c.dx + w * 0.44, c.dy - w * 0.05, c.dx + w * 0.1, c.dy - w * 0.22)
        ..close();
      shaded(canvas, bag, const Color(0xFFD7B98E), const Color(0xFF6D4C41));
      final top = Path()
        ..moveTo(c.dx - w * 0.1, c.dy - w * 0.22)
        ..lineTo(c.dx - w * 0.18, c.dy - w * 0.36)
        ..lineTo(c.dx + w * 0.18, c.dy - w * 0.36)
        ..lineTo(c.dx + w * 0.1, c.dy - w * 0.22)
        ..close();
      shaded(canvas, top, const Color(0xFFD7B98E), const Color(0xFF8D6E63), width: 1.5);
      canvas.drawLine(c.translate(-w * 0.12, -w * 0.22), c.translate(w * 0.12, -w * 0.22), strokeOf(const Color(0xFF3E2723), w * 0.04));
      caption(canvas, Rect.fromCenter(center: c.translate(0, w * 0.1), width: w, height: w * 0.5), 'GOLD', const Color(0xFFFFD54F), size: 0.36, y: 0.5, shadow: _ink);
    case 5: // Goldklumpen
      glow(canvas, c, w * 0.5, const Color(0x88FFD54F));
      final nug = Path()
        ..moveTo(c.dx - w * 0.34, c.dy + w * 0.06)
        ..quadraticBezierTo(c.dx - w * 0.36, c.dy - w * 0.2, c.dx - w * 0.12, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.04, c.dy - w * 0.36, c.dx + w * 0.22, c.dy - w * 0.22)
        ..quadraticBezierTo(c.dx + w * 0.4, c.dy - w * 0.1, c.dx + w * 0.34, c.dy + w * 0.12)
        ..quadraticBezierTo(c.dx + w * 0.28, c.dy + w * 0.32, c.dx + w * 0.02, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx - w * 0.26, c.dy + w * 0.32, c.dx - w * 0.34, c.dy + w * 0.06)
        ..close();
      shaded(canvas, nug, const Color(0xFFFFF59D), const Color(0xFFB8860B), outline: const Color(0xFF6D4C00));
      for (final (dx, dy, rr) in [(-0.12, -0.08, 0.06), (0.1, 0.04, 0.05), (0.02, -0.16, 0.04), (-0.04, 0.14, 0.05)]) {
        canvas.drawCircle(c.translate(dx * w, dy * w), rr * w, fillOf(const Color(0x33FFFFFF)));
      }
      sparkle(canvas, c.translate(-w * 0.16, -w * 0.18), w * 0.08);
      sparkle(canvas, c.translate(w * 0.18, w * 0.1), w * 0.05);
    case 6: // Hut, Joker
      glow(canvas, c, w * 0.5, const Color(0x66FFFFFF));
      final brim = Path()
        ..moveTo(c.dx - w * 0.44, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.2, c.dx, c.dy + w * 0.18)
        ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.2, c.dx + w * 0.44, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.1, c.dx, c.dy + w * 0.08)
        ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.1, c.dx - w * 0.44, c.dy + w * 0.02)
        ..close();
      final crown = Path()
        ..moveTo(c.dx - w * 0.22, c.dy + w * 0.08)
        ..quadraticBezierTo(c.dx - w * 0.26, c.dy - w * 0.26, c.dx - w * 0.1, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.18, c.dx + w * 0.1, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.26, c.dy - w * 0.26, c.dx + w * 0.22, c.dy + w * 0.08)
        ..close();
      shaded(canvas, crown, const Color(0xFFA1887F), const Color(0xFF4E342E));
      canvas.drawRect(Rect.fromLTRB(c.dx - w * 0.22, c.dy - w * 0.02, c.dx + w * 0.22, c.dy + w * 0.06), fillOf(const Color(0xFFC62828)));
      shaded(canvas, brim, const Color(0xFF8D6E63), const Color(0xFF3E2723));
      caption(canvas, r, 'JOKER', Colors.white, size: 0.17, y: 0.86, shadow: _ink);
    case 7: // Schatzkarte, Streusymbol
      glow(canvas, c, w * 0.5, const Color(0x88FFF59D));
      final map = Path()
        ..moveTo(c.dx - w * 0.36, c.dy - w * 0.26)
        ..lineTo(c.dx - w * 0.12, c.dy - w * 0.3)
        ..lineTo(c.dx + w * 0.12, c.dy - w * 0.24)
        ..lineTo(c.dx + w * 0.36, c.dy - w * 0.3)
        ..lineTo(c.dx + w * 0.36, c.dy + w * 0.24)
        ..lineTo(c.dx + w * 0.12, c.dy + w * 0.3)
        ..lineTo(c.dx - w * 0.12, c.dy + w * 0.24)
        ..lineTo(c.dx - w * 0.36, c.dy + w * 0.3)
        ..close();
      shaded(canvas, map, const Color(0xFFFFF3D6), const Color(0xFFD7B98E));
      for (final x in [-0.12, 0.12]) {
        canvas.drawLine(c.translate(x * w, -w * 0.27), c.translate(x * w, w * 0.27), strokeOf(const Color(0x558D6E63), 1.2));
      }
      final trail = Path()
        ..moveTo(c.dx - w * 0.28, c.dy + w * 0.16)
        ..quadraticBezierTo(c.dx - w * 0.1, c.dy - w * 0.2, c.dx + w * 0.04, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx + w * 0.14, c.dy + w * 0.14, c.dx + w * 0.2, c.dy - w * 0.1);
      final dash = strokeOf(const Color(0xFF8D6E63), 1.8);
      for (final m in trail.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 7) {
          canvas.drawPath(m.extractPath(d, d + 4), dash);
        }
      }
      final x = c.translate(w * 0.2, -w * 0.12);
      canvas.drawLine(x.translate(-w * 0.06, -w * 0.06), x.translate(w * 0.06, w * 0.06), strokeOf(const Color(0xFFC62828), w * 0.04));
      canvas.drawLine(x.translate(w * 0.06, -w * 0.06), x.translate(-w * 0.06, w * 0.06), strokeOf(const Color(0xFFC62828), w * 0.04));
      caption(canvas, r, 'SCATTER', const Color(0xFFFFF59D), size: 0.15, y: 0.95);
    default:
      canvas.drawCircle(c, w * 0.3, fillOf(Colors.brown));
  }
}
