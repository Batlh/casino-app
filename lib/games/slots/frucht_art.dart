import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../lose/lose_art.dart';
import 'art_kit.dart';

/// Früchtekorb: klassischer Früchte-Automat mit drei Walzen, Lauflichter am Rand.

void paintFruchtBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7F0000), Color(0xFFB71C1C), Color(0xFF4A0000)],
      ).createShader(rect),
  );
  // Rautenmuster
  final dia = Paint()..color = const Color(0x14FFD54F);
  const step = 28.0;
  for (var y = rect.top; y < rect.bottom + step; y += step) {
    for (var x = rect.left; x < rect.right + step; x += step) {
      final o = Offset(x + ((y - rect.top) / step).floor() % 2 * step / 2, y);
      canvas.drawPath(polygon(o, step * 0.3, 4), dia);
    }
  }
  // Lauflichter oben und unten: 120 Schritte je Durchlauf, durch 3 teilbar, darum nahtlos
  const n = 14;
  for (final y in [rect.top + 6, rect.bottom - 6]) {
    for (var i = 0; i < n; i++) {
      final x = rect.left + rect.width * (i + 0.5) / n;
      final on = ((time * 120).floor() + i) % 3 == 0;
      if (on) glow(canvas, Offset(x, y), 8, const Color(0x99FFEB3B));
      canvas.drawCircle(Offset(x, y), 2.5, fillOf(on ? const Color(0xFFFFF59D) : const Color(0x66FFD54F)));
    }
  }
}

void paintFruchtSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  const ink = Color(0xFF241410);
  switch (symbol) {
    case 0:
      paintLosSymbol(canvas, rect, 'Kirsche');
    case 1:
      paintLosSymbol(canvas, rect, 'Zitrone');
    case 2: // Orange
      final o = Rect.fromCircle(center: c.translate(0, w * 0.04), radius: w * 0.32);
      canvas.drawOval(o, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFFFCC80), Color(0xFFEF6C00)]).createShader(o));
      canvas.drawOval(o, strokeOf(ink, 2));
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5;
        canvas.drawCircle(c.translate(math.cos(a) * w * 0.18, w * 0.04 + math.sin(a) * w * 0.18), w * 0.012, fillOf(const Color(0x66BF360C)));
      }
      final leaf = Path()
        ..moveTo(c.dx, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy - w * 0.42, c.dx + w * 0.26, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.12, c.dy - w * 0.22, c.dx, c.dy - w * 0.26)
        ..close();
      canvas.drawPath(leaf, fillOf(const Color(0xFF43A047)));
    case 3: // Pflaume
      final o = Rect.fromCenter(center: c.translate(0, w * 0.04), width: w * 0.56, height: w * 0.64);
      canvas.drawOval(o, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFCE93D8), Color(0xFF4A148C)]).createShader(o));
      canvas.drawOval(o, strokeOf(ink, 2));
      canvas.drawArc(Rect.fromCenter(center: c.translate(w * 0.06, w * 0.04), width: w * 0.2, height: w * 0.56), -math.pi / 2, math.pi, false, strokeOf(const Color(0x664A148C), 1.5));
      canvas.drawLine(c.translate(0, -w * 0.28), c.translate(w * 0.06, -w * 0.4), strokeOf(const Color(0xFF5D4037), w * 0.04));
    case 4: // Melone
      final slice = Path()
        ..moveTo(c.dx - w * 0.4, c.dy - w * 0.08)
        ..arcToPoint(Offset(c.dx + w * 0.4, c.dy - w * 0.08), radius: Radius.circular(w * 0.4), clockwise: false)
        ..close();
      canvas.drawPath(slice, fillOf(const Color(0xFF2E7D32)));
      final flesh = Path()
        ..moveTo(c.dx - w * 0.34, c.dy - w * 0.08)
        ..arcToPoint(Offset(c.dx + w * 0.34, c.dy - w * 0.08), radius: Radius.circular(w * 0.34), clockwise: false)
        ..close();
      canvas.drawPath(flesh, fillOf(const Color(0xFFEF5350)));
      for (var i = -2; i <= 2; i++) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(i * w * 0.11, w * 0.06 + (i.abs() == 1 ? w * 0.06 : 0)), width: w * 0.04, height: w * 0.07), fillOf(ink));
      }
      canvas.drawPath(slice, strokeOf(ink, 2));
    case 5:
      paintLosSymbol(canvas, rect, 'Glocke');
    case 6: // Sieben als Joker
      glow(canvas, c, w * 0.5, const Color(0x99FFEB3B));
      paintLosSymbol(canvas, Rect.fromCenter(center: c.translate(0, -w * 0.04), width: w * 0.92, height: w * 0.92), 'Sieben');
      caption(canvas, r, 'JOKER', const Color(0xFFFFEB3B), size: 0.16, y: 0.93);
  }
}
