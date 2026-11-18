import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Pharaonengold: Wüstennacht mit Pyramiden. Symbole: 0 Skarabäus, 1 Krug, 2 Auge, 3 Henkelkreuz, 4 Katze,
/// 5 Goldmaske, 6 Pyramide (Joker), 7 Flügelsonne (Streusymbol), 8 Goldmünze, 9 Sonnenrad (Bonus).

const _ink = Color(0xFF241410);
const _gold = Color(0xFFFFD54F);
const _goldDark = Color(0xFFB8860B);
const _lapis = Color(0xFF1E4FA8);

void paintPharaoBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1033), Color(0xFF2A1B4A), Color(0xFF8A4B1E)],
      ).createShader(rect),
  );
  // Sterne funkeln; jeder in einer ganzen Zahl von Takten je Durchlauf, darum nahtlos
  for (var i = 0; i < 40; i++) {
    final x = rect.left + rect.width * ((i * 0.618034) % 1);
    final y = rect.top + rect.height * 0.55 * ((i * 0.381966 + 0.13) % 1);
    final a = 0.35 + 0.35 * math.sin(2 * math.pi * (time * (1 + i % 4) + i * 0.17));
    canvas.drawCircle(Offset(x, y), 1 + (i % 3) * 0.5, fillOf(Colors.white.withValues(alpha: a.clamp(0, 1))));
  }
  // Mond
  final moon = Offset(rect.left + rect.width * 0.82, rect.top + rect.height * 0.12);
  glow(canvas, moon, rect.shortestSide * 0.12, const Color(0x44FFF8E1));
  canvas.drawCircle(moon, rect.shortestSide * 0.05, fillOf(const Color(0xFFFFF8E1)));
  // Pyramiden und Dünen
  final ground = rect.top + rect.height * 0.78;
  for (final (cx, h, shade) in [(0.22, 0.32, 0xFF5D3A1A), (0.5, 0.42, 0xFF6D4420), (0.78, 0.28, 0xFF4E3016)]) {
    final x = rect.left + rect.width * cx;
    final top = ground - rect.height * h;
    final half = rect.height * h * 0.95;
    canvas.drawPath(
      Path()
        ..moveTo(x - half, ground)
        ..lineTo(x, top)
        ..lineTo(x + half, ground)
        ..close(),
      fillOf(Color(shade)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, top)
        ..lineTo(x + half, ground)
        ..lineTo(x + half * 0.35, ground)
        ..close(),
      fillOf(const Color(0x33000000)),
    );
  }
  final dunes = Path()..moveTo(rect.left, ground);
  for (var i = 0; i <= 8; i++) {
    final x = rect.left + rect.width * i / 8;
    dunes.quadraticBezierTo(x - rect.width / 16, ground - 10 * ((i % 2) + 1), x, ground);
  }
  dunes
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();
  canvas.drawPath(dunes, fillOf(const Color(0xFF9C5B24)));
}

void paintPharaoSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Skarabäus
      final body = Rect.fromCenter(center: c.translate(0, w * 0.06), width: w * 0.46, height: w * 0.56);
      for (final s in [-1, 1]) {
        for (final (y, len) in [(-0.04, 0.3), (0.1, 0.32), (0.24, 0.28)]) {
          canvas.drawLine(c.translate(s * w * 0.18, w * y), c.translate(s * w * len, w * (y + 0.08)), strokeOf(_ink, w * 0.03));
        }
      }
      canvas.drawOval(body, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFF80DEEA), Color(0xFF00695C)]).createShader(body));
      canvas.drawOval(body, strokeOf(_ink, 2));
      canvas.drawLine(c.translate(0, -w * 0.08), c.translate(0, w * 0.34), strokeOf(_ink, 1.6));
      final head = Rect.fromCenter(center: c.translate(0, -w * 0.25), width: w * 0.24, height: w * 0.14);
      canvas.drawOval(head, fillOf(const Color(0xFF004D40)));
      canvas.drawOval(head, strokeOf(_ink, 1.6));
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.33), width: w * 0.3, height: w * 0.16), math.pi, math.pi, false, strokeOf(_gold, w * 0.035));
    case 1: // Krug
      final jar = Path()
        ..moveTo(c.dx - w * 0.12, c.dy - w * 0.3)
        ..lineTo(c.dx + w * 0.12, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.1, c.dy - w * 0.18, c.dx + w * 0.26, c.dy)
        ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.3, c.dx, c.dy + w * 0.36)
        ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.3, c.dx - w * 0.26, c.dy)
        ..quadraticBezierTo(c.dx - w * 0.1, c.dy - w * 0.18, c.dx - w * 0.12, c.dy - w * 0.3)
        ..close();
      shaded(canvas, jar, const Color(0xFFFFAB91), const Color(0xFFBF5B2A));
      canvas.drawLine(c.translate(-w * 0.27, w * 0.04), c.translate(w * 0.27, w * 0.04), strokeOf(_lapis, w * 0.05));
      canvas.drawLine(c.translate(-w * 0.25, w * 0.14), c.translate(w * 0.25, w * 0.14), strokeOf(_gold, w * 0.03));
    case 2: // Auge
      final eye = Path()
        ..moveTo(c.dx - w * 0.36, c.dy - w * 0.04)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.3, c.dx + w * 0.36, c.dy - w * 0.04)
        ..quadraticBezierTo(c.dx, c.dy + w * 0.18, c.dx - w * 0.36, c.dy - w * 0.04)
        ..close();
      canvas.drawPath(eye, fillOf(const Color(0xFFFFF8E7)));
      canvas.drawCircle(c.translate(0, -w * 0.06), w * 0.1, fillOf(_lapis));
      canvas.drawCircle(c.translate(0, -w * 0.06), w * 0.045, fillOf(_ink));
      canvas.drawPath(eye, strokeOf(_ink, w * 0.035));
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.18), width: w * 0.7, height: w * 0.28), math.pi * 1.1, math.pi * 0.8, false, strokeOf(_ink, w * 0.045));
      final tear = Path()
        ..moveTo(c.dx - w * 0.04, c.dy + w * 0.06)
        ..lineTo(c.dx - w * 0.06, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx - w * 0.16, c.dy + w * 0.4, c.dx - w * 0.24, c.dy + w * 0.3);
      canvas.drawPath(tear, strokeOf(_ink, w * 0.04));
      final curl = Path()
        ..moveTo(c.dx + w * 0.06, c.dy + w * 0.08)
        ..quadraticBezierTo(c.dx + w * 0.28, c.dy + w * 0.14, c.dx + w * 0.34, c.dy + w * 0.34);
      canvas.drawPath(curl, strokeOf(_ink, w * 0.035));
    case 3: // Henkelkreuz
      final paint = Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFFF59D), _goldDark]).createShader(r)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.2), width: w * 0.26, height: w * 0.3), paint);
      canvas.drawLine(c.translate(-w * 0.26, w * 0.0), c.translate(w * 0.26, w * 0.0), paint);
      canvas.drawLine(c.translate(0, -w * 0.04), c.translate(0, w * 0.4), paint);
    case 4: // Katze
      final cat = Path()
        ..moveTo(c.dx - w * 0.2, c.dy + w * 0.4)
        ..quadraticBezierTo(c.dx - w * 0.26, c.dy + w * 0.02, c.dx - w * 0.1, c.dy - w * 0.12)
        ..lineTo(c.dx - w * 0.14, c.dy - w * 0.38)
        ..lineTo(c.dx - w * 0.03, c.dy - w * 0.26)
        ..lineTo(c.dx + w * 0.07, c.dy - w * 0.26)
        ..lineTo(c.dx + w * 0.16, c.dy - w * 0.38)
        ..lineTo(c.dx + w * 0.13, c.dy - w * 0.1)
        ..quadraticBezierTo(c.dx + w * 0.26, c.dy + w * 0.06, c.dx + w * 0.2, c.dy + w * 0.4)
        ..close();
      shaded(canvas, cat, const Color(0xFF616161), const Color(0xFF1B1B1B));
      canvas.drawArc(Rect.fromCenter(center: c.translate(0.01 * w, -w * 0.1), width: w * 0.26, height: w * 0.12), 0.2, math.pi - 0.4, false, strokeOf(_gold, w * 0.04));
      for (final s in [-1, 1]) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(w * (0.02 + s * 0.06), -w * 0.19), width: w * 0.05, height: w * 0.035), fillOf(const Color(0xFF76FF03)));
      }
      final tail = Path()
        ..moveTo(c.dx + w * 0.18, c.dy + w * 0.36)
        ..quadraticBezierTo(c.dx + w * 0.38, c.dy + w * 0.36, c.dx + w * 0.34, c.dy + w * 0.14);
      canvas.drawPath(tail, strokeOf(const Color(0xFF1B1B1B), w * 0.05));
    case 5: // Goldmaske
      final mask = Path()
        ..moveTo(c.dx - w * 0.36, c.dy + w * 0.34)
        ..lineTo(c.dx - w * 0.3, c.dy - w * 0.22)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.46, c.dx + w * 0.3, c.dy - w * 0.22)
        ..lineTo(c.dx + w * 0.36, c.dy + w * 0.34)
        ..close();
      shaded(canvas, mask, const Color(0xFF64B5F6), _lapis);
      for (var i = 1; i < 6; i++) {
        final y = c.dy - w * 0.2 + i * w * 0.1;
        canvas.drawLine(Offset(c.dx - w * 0.33, y), Offset(c.dx + w * 0.33, y), strokeOf(_gold, w * 0.03));
      }
      final face = Rect.fromCenter(center: c.translate(0, w * 0.02), width: w * 0.36, height: w * 0.44);
      canvas.drawOval(face, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFF59D), _goldDark]).createShader(face));
      canvas.drawOval(face, strokeOf(_ink, 1.8));
      for (final s in [-1, 1]) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(s * w * 0.08, -w * 0.04), width: w * 0.09, height: w * 0.04), fillOf(_ink));
      }
      canvas.drawLine(c.translate(-w * 0.05, w * 0.14), c.translate(w * 0.05, w * 0.14), strokeOf(const Color(0xFF8D2B0B), w * 0.025));
      canvas.drawRect(Rect.fromCenter(center: c.translate(0, w * 0.3), width: w * 0.06, height: w * 0.12), fillOf(_lapis));
    case 6: // Pyramide als Joker
      glow(canvas, c, w * 0.5, const Color(0x99FFD54F));
      final pyr = Path()
        ..moveTo(c.dx, c.dy - w * 0.36)
        ..lineTo(c.dx + w * 0.4, c.dy + w * 0.24)
        ..lineTo(c.dx - w * 0.4, c.dy + w * 0.24)
        ..close();
      shaded(canvas, pyr, const Color(0xFFFFF59D), _goldDark);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - w * 0.36)
          ..lineTo(c.dx + w * 0.4, c.dy + w * 0.24)
          ..lineTo(c.dx + w * 0.1, c.dy + w * 0.24)
          ..close(),
        fillOf(const Color(0x33000000)),
      );
      canvas.drawCircle(c.translate(0, -w * 0.06), w * 0.06, fillOf(_lapis));
      sparkle(canvas, c.translate(0, -w * 0.36), w * 0.1);
      caption(canvas, r, 'JOKER', _gold, size: 0.16, y: 0.93);
    case 7: // Flügelsonne als Streusymbol
      glow(canvas, c, w * 0.5, const Color(0x88FF7043));
      for (final s in [-1, 1]) {
        for (var k = 0; k < 4; k++) {
          final y = c.dy - w * 0.06 + k * w * 0.06;
          final len = w * (0.42 - k * 0.06);
          final feather = Path()
            ..moveTo(c.dx + s * w * 0.12, y)
            ..lineTo(c.dx + s * len, y - w * 0.04)
            ..lineTo(c.dx + s * len, y + w * 0.02)
            ..lineTo(c.dx + s * w * 0.12, y + w * 0.05)
            ..close();
          canvas.drawPath(feather, fillOf(k.isEven ? _lapis : const Color(0xFF26A69A)));
          canvas.drawPath(feather, strokeOf(_ink, 1));
        }
      }
      final sun = Rect.fromCircle(center: c.translate(0, -w * 0.06), radius: w * 0.15);
      canvas.drawOval(sun, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFEB3B), Color(0xFFE64A19)]).createShader(sun));
      canvas.drawOval(sun, strokeOf(_ink, 1.8));
      caption(canvas, r, 'SCATTER', const Color(0xFFFFAB40), size: 0.16, y: 0.93);
    case 8: // Goldmünze mit Henkelkreuz
      goldCoin(canvas, r);
      final p = strokeOf(const Color(0xFF7A5200), w * 0.045)..strokeCap = StrokeCap.round;
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.1), width: w * 0.12, height: w * 0.14), p);
      canvas.drawLine(c.translate(-w * 0.12, 0), c.translate(w * 0.12, 0), p);
      canvas.drawLine(c.translate(0, -w * 0.02), c.translate(0, w * 0.2), p);
    case 9: // Sonnenrad als Bonus
      final wheel = Rect.fromCircle(center: c.translate(0, -w * 0.04), radius: w * 0.36);
      const cols = [_lapis, _gold, Color(0xFF26A69A), Color(0xFFE64A19)];
      for (var i = 0; i < 12; i++) {
        canvas.drawArc(wheel, -math.pi / 2 + i * math.pi / 6, math.pi / 6, true, fillOf(cols[i % cols.length]));
      }
      canvas.drawOval(wheel, strokeOf(_goldDark, w * 0.04));
      canvas.drawCircle(wheel.center, w * 0.08, fillOf(_gold));
      canvas.drawCircle(wheel.center, w * 0.08, strokeOf(_ink, 1.5));
      canvas.drawPath(
        Path()
          ..moveTo(wheel.center.dx, wheel.top + w * 0.06)
          ..lineTo(wheel.center.dx - w * 0.05, wheel.top - w * 0.04)
          ..lineTo(wheel.center.dx + w * 0.05, wheel.top - w * 0.04)
          ..close(),
        fillOf(Colors.white),
      );
      caption(canvas, r, 'BONUS', Colors.white, size: 0.16, y: 0.93);
  }
}
