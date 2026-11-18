import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../slots/art_kit.dart';

/// Symbole für Rubbellose und Pull-Tabs, alles im Code gezeichnet.
void paintLosSymbol(Canvas canvas, Rect rect, String name) {
  final r = squareIn(rect).deflate(rect.shortestSide * 0.08);
  final c = r.center;
  final w = r.width;
  const ink = Color(0xFF241410);
  switch (name) {
    case 'Kirsche':
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - w * 0.16, c.dy + w * 0.1)
          ..quadraticBezierTo(c.dx - w * 0.05, c.dy - w * 0.3, c.dx + w * 0.12, c.dy - w * 0.38)
          ..moveTo(c.dx + w * 0.18, c.dy + w * 0.12)
          ..quadraticBezierTo(c.dx + w * 0.16, c.dy - w * 0.2, c.dx + w * 0.12, c.dy - w * 0.38),
        strokeOf(const Color(0xFF2E7D32), w * 0.05),
      );
      for (final dx in [-0.18, 0.18]) {
        final o = c.translate(w * dx, w * 0.2);
        canvas.drawCircle(o, w * 0.18, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)]).createShader(Rect.fromCircle(center: o, radius: w * 0.18)));
        canvas.drawCircle(o, w * 0.18, strokeOf(ink, 1.5));
      }
    case 'Zitrone':
      final o = Rect.fromCenter(center: c, width: w * 0.8, height: w * 0.56);
      shaded(canvas, Path()..addOval(o), const Color(0xFFFFF59D), const Color(0xFFF9A825));
    case 'Glocke':
      final bell = Path()
        ..moveTo(c.dx - w * 0.34, c.dy + w * 0.22)
        ..quadraticBezierTo(c.dx - w * 0.26, c.dy + w * 0.1, c.dx - w * 0.24, c.dy - w * 0.1)
        ..quadraticBezierTo(c.dx - w * 0.22, c.dy - w * 0.38, c.dx, c.dy - w * 0.38)
        ..quadraticBezierTo(c.dx + w * 0.22, c.dy - w * 0.38, c.dx + w * 0.24, c.dy - w * 0.1)
        ..quadraticBezierTo(c.dx + w * 0.26, c.dy + w * 0.1, c.dx + w * 0.34, c.dy + w * 0.22)
        ..close();
      shaded(canvas, bell, const Color(0xFFFFE082), const Color(0xFFB8860B));
      canvas.drawCircle(c.translate(0, w * 0.3), w * 0.07, fillOf(const Color(0xFFB8860B)));
    case 'Hufeisen':
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.04), width: w * 0.62, height: w * 0.7), math.pi * 0.95, -math.pi * 1.9, false,
          strokeOf(const Color(0xFF90A4AE), w * 0.14));
      for (var i = 0; i < 6; i++) {
        final a = math.pi * 0.9 - i * math.pi * 1.8 / 5;
        canvas.drawCircle(c.translate(math.cos(a) * w * 0.31, -w * 0.04 - math.sin(a) * w * 0.35), w * 0.02, fillOf(ink));
      }
    case 'Sieben':
      caption(canvas, r, '7', const Color(0xFFD32F2F), size: 0.9, y: 0.5, shadow: const Color(0xFFFFEB3B));
    case 'Krone':
      final crown = Path()
        ..moveTo(c.dx - w * 0.36, c.dy + w * 0.22)
        ..lineTo(c.dx - w * 0.4, c.dy - w * 0.2)
        ..lineTo(c.dx - w * 0.16, c.dy)
        ..lineTo(c.dx, c.dy - w * 0.32)
        ..lineTo(c.dx + w * 0.16, c.dy)
        ..lineTo(c.dx + w * 0.4, c.dy - w * 0.2)
        ..lineTo(c.dx + w * 0.36, c.dy + w * 0.22)
        ..close();
      shaded(canvas, crown, const Color(0xFFFFE082), const Color(0xFFB8860B));
      canvas.drawRect(Rect.fromLTRB(c.dx - w * 0.36, c.dy + w * 0.14, c.dx + w * 0.36, c.dy + w * 0.26), fillOf(const Color(0xFFC62828)));
    case 'Diamant':
      gem(canvas, r, const Color(0xFFE1F5FE), const Color(0xFF0288D1), sides: 8);
    case 'Goldbarren':
      final bar = Path()
        ..moveTo(c.dx - w * 0.28, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.28, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.42, c.dy + w * 0.18)
        ..lineTo(c.dx - w * 0.42, c.dy + w * 0.18)
        ..close();
      shaded(canvas, bar, const Color(0xFFFFF176), const Color(0xFFB8860B));
      sparkle(canvas, c.translate(-w * 0.12, -w * 0.04), w * 0.08);
    case 'Kohle':
      shaded(canvas, polygon(c, w * 0.32, 7, squash: 0.8), const Color(0xFF616161), const Color(0xFF111111));
    case 'Stein':
      shaded(canvas, polygon(c, w * 0.34, 9, squash: 0.7, rotation: 0.3), const Color(0xFFBDBDBD), const Color(0xFF616161));
    case 'Spitzhacke':
      canvas.drawLine(c.translate(-w * 0.26, w * 0.34), c.translate(w * 0.14, -w * 0.18), strokeOf(const Color(0xFF8D6E63), w * 0.07));
      canvas.drawArc(Rect.fromCenter(center: c.translate(w * 0.16, -w * 0.2), width: w * 0.7, height: w * 0.36), math.pi * 1.05, math.pi * 0.9, false,
          strokeOf(const Color(0xFF90A4AE), w * 0.08));
    case 'Laterne':
      final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.42, height: w * 0.56), Radius.circular(w * 0.06));
      canvas.drawRRect(body, fillOf(const Color(0xFF5D4037)));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.3, height: w * 0.4), Radius.circular(w * 0.04)), fillOf(const Color(0xFFFFE082)));
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.3), width: w * 0.3, height: w * 0.22), math.pi, math.pi, false, strokeOf(ink, 2));
  }
}

/// Betrag als kurzer Text: 25.000 → „25.000“, 1.000.000 → „1 Mio.“
String losAmount(int v) => v >= 1000000 ? '${v ~/ 1000000} Mio.' : _dots(v);

String _dots(int v) {
  final s = '$v';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Text mittig in ein Rechteck, in der App-Schrift.
void losText(Canvas canvas, Rect rect, String text, Color color, {double size = 0.3, FontWeight weight = FontWeight.w800}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontFamily: bodyFont, color: color, fontSize: rect.height * size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: rect.width);
  tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
}
