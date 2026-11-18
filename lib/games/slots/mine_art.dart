import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Edelsteinmine: dunkler Stollen mit Holzbalken, Edelsteine als geschliffene Steine.

void paintMineBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3B2A22), Color(0xFF1E1511), Color(0xFF120C09)],
      ).createShader(rect),
  );
  // Gesteinsflecken
  final rng = math.Random(7);
  final stone = fillOf(const Color(0x22FFFFFF));
  for (var i = 0; i < 40; i++) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height),
        width: 6 + rng.nextDouble() * 18,
        height: 4 + rng.nextDouble() * 10,
      ),
      stone,
    );
  }
  // Funkelnde Adern
  for (var i = 0; i < 14; i++) {
    final o = Offset(rect.left + rng.nextDouble() * rect.width, rect.top + rng.nextDouble() * rect.height);
    final a = (math.sin(time * 2 * math.pi + i) + 1) / 2;
    sparkle(canvas, o, 3 + 4 * a, Color.lerp(const Color(0x0000E5FF), const Color(0xCCB3F5FF), a)!);
  }
  // Laternenschein, leicht flackernd
  final flicker = 0.85 + 0.15 * math.sin(time * 2 * math.pi * 3);
  glow(canvas, Offset(rect.center.dx, rect.top), rect.width * 0.6 * flicker, const Color(0x55FFB74D));
}

void paintMineSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  switch (symbol) {
    case 0: // Quarz
      gem(canvas, r.deflate(r.width * 0.06), const Color(0xFFF5F7FA), const Color(0xFF9AA5B1), sides: 6);
    case 1: // Amethyst
      gem(canvas, r.deflate(r.width * 0.04), const Color(0xFFD7A6F5), const Color(0xFF5B2A86), sides: 5);
    case 2: // Topas
      gem(canvas, r, const Color(0xFFFFE08A), const Color(0xFFC77D10), sides: 10, squash: 0.78);
    case 3: // Smaragd
      gem(canvas, r, const Color(0xFF8CF2B0), const Color(0xFF0B6B3A), sides: 8, squash: 0.72, rotation: -math.pi / 8);
    case 4: // Saphir
      gem(canvas, r, const Color(0xFF8DB8FF), const Color(0xFF0D2E8A), sides: 12);
    case 5: // Rubin
      gem(canvas, r, const Color(0xFFFF8A8A), const Color(0xFF8B0012), sides: 16);
    case 6: // Diamant, Joker
      gem(canvas, r, const Color(0xFFFFFFFF), const Color(0xFF7FD3FF), sides: 8);
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + math.pi / 4;
        sparkle(canvas, r.center + Offset(math.cos(a), math.sin(a)) * r.width * 0.42, r.width * 0.09);
      }
      caption(canvas, r, 'JOKER', const Color(0xFF0D2E8A), size: 0.17, y: 0.9, shadow: Colors.white);
    case 7: // Grubenlampe, Scatter
      _lamp(canvas, r);
  }
}

void _lamp(Canvas canvas, Rect r) {
  final c = r.center;
  final w = r.width;
  glow(canvas, c, w * 0.5, const Color(0xAAFFC107));
  // Bügel
  canvas.drawArc(Rect.fromCenter(center: c.translate(0, -w * 0.28), width: w * 0.36, height: w * 0.3), math.pi, math.pi, false,
      strokeOf(const Color(0xFF3A2413), w * 0.05));
  // Gehäuse
  final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, w * 0.04), width: w * 0.44, height: w * 0.5), Radius.circular(w * 0.06));
  canvas.drawRRect(body, fillOf(const Color(0xFF5D4037)));
  final glass = Rect.fromCenter(center: c.translate(0, w * 0.04), width: w * 0.32, height: w * 0.36);
  canvas.drawRRect(
    RRect.fromRectAndRadius(glass, Radius.circular(w * 0.04)),
    Paint()..shader = const RadialGradient(colors: [Color(0xFFFFFDE7), Color(0xFFFFB300)]).createShader(glass),
  );
  // Flamme
  final flame = Path()
    ..moveTo(c.dx, c.dy - w * 0.08)
    ..quadraticBezierTo(c.dx + w * 0.08, c.dy + w * 0.06, c.dx, c.dy + w * 0.13)
    ..quadraticBezierTo(c.dx - w * 0.08, c.dy + w * 0.06, c.dx, c.dy - w * 0.08);
  canvas.drawPath(flame, fillOf(const Color(0xFFFF6F00)));
  canvas.drawRRect(body, strokeOf(const Color(0xFF241410), 2));
  canvas.drawLine(glass.topCenter, glass.bottomCenter, strokeOf(const Color(0xFF3A2413), 2));
  caption(canvas, r, 'SCATTER', Colors.white, size: 0.14, y: 0.93);
}
