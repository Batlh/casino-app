import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Jahrmarkt: Nachthimmel mit Lichterkette, bunte Buden-Symbole.

const _ink = Color(0xFF241410);

void paintJahrmarktBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B1446), Color(0xFF3B1E5E), Color(0xFF5E2A55)],
      ).createShader(rect),
  );
  // Zeltstreifen unten
  final stripe = rect.width / 10;
  for (var i = 0; i < 10; i++) {
    canvas.drawRect(
      Rect.fromLTWH(rect.left + i * stripe, rect.bottom - rect.height * 0.08, stripe, rect.height * 0.08),
      fillOf(i.isEven ? const Color(0x44E53935) : const Color(0x44FFFFFF)),
    );
  }
  // Lichterkette, Lampen leuchten nacheinander auf
  for (var row = 0; row < 2; row++) {
    final y0 = rect.top + rect.height * (0.04 + row * 0.5);
    const n = 12;
    for (var i = 0; i < n; i++) {
      final x = rect.left + rect.width * (i + 0.5) / n;
      final sag = math.sin(i / (n - 1) * math.pi) * rect.height * 0.04;
      final on = ((time * n).floor() + i + row) % 3 == 0;
      final color = [const Color(0xFFFFEB3B), const Color(0xFFFF5252), const Color(0xFF69F0AE)][i % 3];
      if (on) glow(canvas, Offset(x, y0 + sag), 9, color.withValues(alpha: 0.6));
      canvas.drawCircle(Offset(x, y0 + sag), 2.5, fillOf(on ? color : color.withValues(alpha: 0.35)));
    }
  }
}

void paintJahrmarktSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Popcorn
      final cup = Path()
        ..moveTo(c.dx - w * 0.24, c.dy - w * 0.06)
        ..lineTo(c.dx + w * 0.24, c.dy - w * 0.06)
        ..lineTo(c.dx + w * 0.17, c.dy + w * 0.38)
        ..lineTo(c.dx - w * 0.17, c.dy + w * 0.38)
        ..close();
      for (var i = 0; i < 9; i++) {
        final o = c + Offset((i % 5 - 2) * w * 0.1, -w * (0.1 + (i ~/ 5) * 0.12 + (i % 2) * 0.03));
        canvas.drawCircle(o, w * 0.08, fillOf(const Color(0xFFFFF8E1)));
        canvas.drawCircle(o, w * 0.08, strokeOf(const Color(0xFFE0B04B), 1.2));
      }
      canvas.save();
      canvas.clipPath(cup);
      canvas.drawPath(cup, fillOf(Colors.white));
      for (var i = -3; i <= 3; i += 2) {
        canvas.drawRect(Rect.fromLTWH(c.dx + i * w * 0.06, c.dy - w * 0.1, w * 0.06, w * 0.5), fillOf(const Color(0xFFE53935)));
      }
      canvas.restore();
      canvas.drawPath(cup, strokeOf(_ink, 2));
    case 1: // Lebkuchenherz
      final heart = Path()
        ..moveTo(c.dx, c.dy + w * 0.34)
        ..cubicTo(c.dx - w * 0.5, c.dy, c.dx - w * 0.3, c.dy - w * 0.4, c.dx, c.dy - w * 0.16)
        ..cubicTo(c.dx + w * 0.3, c.dy - w * 0.4, c.dx + w * 0.5, c.dy, c.dx, c.dy + w * 0.34)
        ..close();
      shaded(canvas, heart, const Color(0xFFC68642), const Color(0xFF7B4A1E), width: 2.5);
      final icing = Path()
        ..moveTo(c.dx, c.dy + w * 0.26)
        ..cubicTo(c.dx - w * 0.4, c.dy, c.dx - w * 0.24, c.dy - w * 0.3, c.dx, c.dy - w * 0.1)
        ..cubicTo(c.dx + w * 0.24, c.dy - w * 0.3, c.dx + w * 0.4, c.dy, c.dx, c.dy + w * 0.26);
      canvas.drawPath(icing, strokeOf(Colors.white, w * 0.025));
      canvas.drawCircle(c.translate(-w * 0.1, -w * 0.02), w * 0.04, fillOf(const Color(0xFFE53935)));
      canvas.drawCircle(c.translate(w * 0.1, -w * 0.02), w * 0.04, fillOf(const Color(0xFF43A047)));
    case 2: // Zuckerwatte
      canvas.drawLine(c.translate(0, w * 0.05), c.translate(0, w * 0.42), strokeOf(const Color(0xFFD7CCC8), w * 0.04));
      for (final o in [Offset(-0.13, -0.08), Offset(0.13, -0.08), Offset(0, -0.2), Offset(0, 0.02), Offset(-0.06, -0.14), Offset(0.07, -0.13)]) {
        canvas.drawCircle(c + o * w, w * 0.15, fillOf(const Color(0xFFF8BBD0)));
      }
      canvas.drawCircle(c.translate(-w * 0.08, -w * 0.16), w * 0.06, fillOf(const Color(0x88FFFFFF)));
    case 3: // Luftballon
      final b = Rect.fromCenter(center: c.translate(0, -w * 0.08), width: w * 0.5, height: w * 0.6);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy + w * 0.22)
          ..quadraticBezierTo(c.dx + w * 0.08, c.dy + w * 0.32, c.dx, c.dy + w * 0.44),
        strokeOf(_ink, 1.5),
      );
      canvas.drawOval(
        b,
        Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFF82B1FF), Color(0xFF1565C0)]).createShader(b),
      );
      canvas.drawOval(b, strokeOf(_ink, 2));
      canvas.drawOval(Rect.fromCenter(center: b.center.translate(-w * 0.1, -w * 0.12), width: w * 0.08, height: w * 0.14), fillOf(const Color(0x99FFFFFF)));
    case 4: // Karussellpferd
      canvas.drawLine(c.translate(0, -w * 0.44), c.translate(0, w * 0.44), strokeOf(const Color(0xFFFFD54F), w * 0.04));
      final horse = Path()
        ..moveTo(c.dx - w * 0.3, c.dy + w * 0.12)
        ..lineTo(c.dx - w * 0.28, c.dy - w * 0.06)
        ..quadraticBezierTo(c.dx - w * 0.1, c.dy - w * 0.1, c.dx + w * 0.08, c.dy - w * 0.08)
        ..lineTo(c.dx + w * 0.14, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.28, c.dy - w * 0.34, c.dx + w * 0.34, c.dy - w * 0.2)
        ..lineTo(c.dx + w * 0.26, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.24, c.dy + w * 0.1)
        ..lineTo(c.dx + w * 0.2, c.dy + w * 0.3)
        ..lineTo(c.dx + w * 0.14, c.dy + w * 0.12)
        ..lineTo(c.dx - w * 0.16, c.dy + w * 0.14)
        ..lineTo(c.dx - w * 0.24, c.dy + w * 0.32)
        ..close();
      shaded(canvas, horse, Colors.white, const Color(0xFFE0E0E0), width: 2.2);
      canvas.drawRect(Rect.fromCenter(center: c.translate(-w * 0.04, -w * 0.05), width: w * 0.18, height: w * 0.08), fillOf(const Color(0xFFE53935)));
      canvas.drawCircle(c.translate(w * 0.22, -w * 0.24), w * 0.02, fillOf(_ink));
    case 5: // Riesenrad
      final rr = w * 0.34;
      final hub = c.translate(0, -w * 0.04);
      canvas.drawLine(hub, c.translate(-w * 0.22, w * 0.42), strokeOf(const Color(0xFF90A4AE), w * 0.04));
      canvas.drawLine(hub, c.translate(w * 0.22, w * 0.42), strokeOf(const Color(0xFF90A4AE), w * 0.04));
      canvas.drawCircle(hub, rr, strokeOf(const Color(0xFFFFD54F), w * 0.035));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final o = hub + Offset(math.cos(a), math.sin(a)) * rr;
        canvas.drawLine(hub, o, strokeOf(const Color(0xFFFFE082), 1.5));
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: o.translate(0, w * 0.04), width: w * 0.1, height: w * 0.08), Radius.circular(w * 0.02)),
          fillOf([const Color(0xFFE53935), const Color(0xFF43A047), const Color(0xFF1E88E5), const Color(0xFFFFB300)][i % 4]),
        );
      }
      canvas.drawCircle(hub, w * 0.05, fillOf(const Color(0xFFFFD54F)));
    case 6: // Glücksstern, Joker
      glow(canvas, c, w * 0.5, const Color(0x99FFEB3B));
      shaded(canvas, starPath(c.translate(0, -w * 0.04), w * 0.4), const Color(0xFFFFF59D), const Color(0xFFF9A825), width: 2.5);
      caption(canvas, r, 'JOKER', const Color(0xFFB71C1C), size: 0.17, y: 0.92, shadow: Colors.white);
    case 8: // Münze
      goldCoin(canvas, r);
      canvas.drawPath(starPath(c, w * 0.2), fillOf(const Color(0xFF7A5200)));
    case 9: // Glücksrad, Bonus
      glow(canvas, c, w * 0.5, const Color(0x88FF4081));
      final wr = w * 0.38;
      for (var i = 0; i < 8; i++) {
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(Rect.fromCircle(center: c, radius: wr), i * math.pi / 4, math.pi / 4, false)
          ..close();
        canvas.drawPath(path, fillOf([const Color(0xFFE53935), const Color(0xFFFFB300), const Color(0xFF1E88E5), const Color(0xFF8E24AA)][i % 4]));
      }
      canvas.drawCircle(c, wr, strokeOf(const Color(0xFFFFF4C2), 3));
      canvas.drawCircle(c, w * 0.07, fillOf(const Color(0xFFFFF4C2)));
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - wr + w * 0.06)
          ..lineTo(c.dx - w * 0.07, c.dy - wr - w * 0.07)
          ..lineTo(c.dx + w * 0.07, c.dy - wr - w * 0.07)
          ..close(),
        fillOf(Colors.white),
      );
      caption(canvas, r, 'BONUS', Colors.white, size: 0.16, y: 0.94);
  }
}
