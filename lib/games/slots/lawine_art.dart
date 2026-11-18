import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';
import 'frucht_art.dart';

/// Fruchtlawine: neun Früchte auf 3 × 3, Gewinne verschwinden und neue Früchte fallen nach.
/// Symbole 0–5 und 6 (Sieben) wie beim Früchtekorb, dazu 7 Stern (Streusymbol), 10 Erdbeere, 11 Banane, 12 Traube.

void paintLawineBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF004D40), Color(0xFF00796B), Color(0xFF002420)],
      ).createShader(rect),
  );
  // Fallende Fruchtkugeln; jede fällt eine ganze Zahl von Malen pro Durchlauf, darum nahtlos
  const colors = [Color(0x33E53935), Color(0x33FFEB3B), Color(0x33FF9800), Color(0x338E24AA), Color(0x3366BB6A)];
  for (var i = 0; i < 18; i++) {
    final x = rect.left + rect.width * ((i * 0.618) % 1);
    final turns = 1 + i % 3;
    final y = rect.top - 20 + (rect.height + 40) * ((time * turns + i * 0.37) % 1);
    final r = 6.0 + (i % 4) * 3;
    canvas.drawCircle(Offset(x, y), r, fillOf(colors[i % colors.length]));
  }
}

void paintLawineSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  const ink = Color(0xFF241410);
  switch (symbol) {
    case 7: // Stern als Streusymbol
      glow(canvas, c, w * 0.5, const Color(0x99FFF176));
      final star = starPath(c.translate(0, -w * 0.04), w * 0.38);
      shaded(canvas, star, const Color(0xFFFFF59D), const Color(0xFFFFA000));
      caption(canvas, r, 'SCATTER', const Color(0xFFFFF59D), size: 0.16, y: 0.93);
    case 10: // Erdbeere
      final body = Path()
        ..moveTo(c.dx, c.dy + w * 0.36)
        ..cubicTo(c.dx - w * 0.42, c.dy + w * 0.05, c.dx - w * 0.3, c.dy - w * 0.26, c.dx, c.dy - w * 0.2)
        ..cubicTo(c.dx + w * 0.3, c.dy - w * 0.26, c.dx + w * 0.42, c.dy + w * 0.05, c.dx, c.dy + w * 0.36)
        ..close();
      shaded(canvas, body, const Color(0xFFFF8A80), const Color(0xFFC62828));
      final rng = math.Random(10);
      for (var i = 0; i < 9; i++) {
        final p = c.translate((rng.nextDouble() - 0.5) * w * 0.36, -w * 0.08 + rng.nextDouble() * w * 0.3);
        canvas.drawOval(Rect.fromCenter(center: p, width: w * 0.03, height: w * 0.045), fillOf(const Color(0xFFFFF59D)));
      }
      for (var i = -2; i <= 2; i++) {
        final leaf = Path()
          ..moveTo(c.dx, c.dy - w * 0.2)
          ..lineTo(c.dx + i * w * 0.08 - w * 0.03, c.dy - w * 0.3 + i.abs() * w * 0.04)
          ..lineTo(c.dx + i * w * 0.08 + w * 0.03, c.dy - w * 0.3 + i.abs() * w * 0.04)
          ..close();
        canvas.drawPath(leaf, fillOf(const Color(0xFF2E7D32)));
      }
    case 11: // Banane
      final banana = Path()
        ..moveTo(c.dx - w * 0.36, c.dy - w * 0.16)
        ..quadraticBezierTo(c.dx - w * 0.1, c.dy + w * 0.42, c.dx + w * 0.36, c.dy - w * 0.08)
        ..quadraticBezierTo(c.dx - w * 0.06, c.dy + w * 0.1, c.dx - w * 0.3, c.dy - w * 0.22)
        ..close();
      shaded(canvas, banana, const Color(0xFFFFF59D), const Color(0xFFF9A825));
      canvas.drawLine(c.translate(-w * 0.33, -w * 0.19), c.translate(-w * 0.4, -w * 0.28), strokeOf(const Color(0xFF5D4037), w * 0.04));
      canvas.drawCircle(c.translate(w * 0.36, -w * 0.08), w * 0.025, fillOf(ink));
    case 12: // Traube
      for (final (dx, dy) in [(-0.16, -0.12), (0.0, -0.14), (0.16, -0.12), (-0.08, 0.02), (0.08, 0.02), (-0.16, 0.06), (0.16, 0.06), (0.0, 0.16), (-0.08, 0.26), (0.08, 0.26), (0.0, 0.36)]) {
        final o = Rect.fromCircle(center: c.translate(dx * w, dy * w * 0.85), radius: w * 0.09);
        canvas.drawOval(o, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFB39DDB), Color(0xFF4527A0)]).createShader(o));
        canvas.drawOval(o, strokeOf(const Color(0x88241410), 1));
      }
      canvas.drawLine(c.translate(0, -w * 0.2), c.translate(w * 0.04, -w * 0.34), strokeOf(const Color(0xFF5D4037), w * 0.035));
      final leaf = Path()
        ..moveTo(c.dx + w * 0.02, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.2, c.dy - w * 0.4, c.dx + w * 0.3, c.dy - w * 0.24)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy - w * 0.2, c.dx + w * 0.02, c.dy - w * 0.26)
        ..close();
      canvas.drawPath(leaf, fillOf(const Color(0xFF43A047)));
    default:
      paintFruchtSymbol(canvas, rect, symbol);
  }
}
