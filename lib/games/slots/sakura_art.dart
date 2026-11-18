import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Sakura: Abenddämmerung über einem Garten, fallende Kirschblüten, japanische Gartensymbole.

const _ink = Color(0xFF2A1A22);

/// Fünfblättrige Kirschblüte mit Kerbe in jedem Blatt.
void sakuraBlossom(Canvas canvas, Offset c, double r, {Color light = const Color(0xFFFFE4EE), Color dark = const Color(0xFFF48FB1), double turn = 0}) {
  for (var i = 0; i < 5; i++) {
    final a = turn - math.pi / 2 + i * 2 * math.pi / 5;
    final dir = Offset(math.cos(a), math.sin(a));
    final side = Offset(-dir.dy, dir.dx);
    final tip = c + dir * r;
    final petal = Path()
      ..moveTo(c.dx, c.dy)
      ..quadraticBezierTo((c + dir * r * 0.5 + side * r * 0.62).dx, (c + dir * r * 0.5 + side * r * 0.62).dy,
          (tip + side * r * 0.16).dx, (tip + side * r * 0.16).dy)
      ..lineTo((c + dir * r * 0.86).dx, (c + dir * r * 0.86).dy)
      ..lineTo((tip - side * r * 0.16).dx, (tip - side * r * 0.16).dy)
      ..quadraticBezierTo((c + dir * r * 0.5 - side * r * 0.62).dx, (c + dir * r * 0.5 - side * r * 0.62).dy, c.dx, c.dy)
      ..close();
    canvas.drawPath(
      petal,
      Paint()..shader = RadialGradient(colors: [dark, light]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(petal, strokeOf(const Color(0x66AD1457), math.max(0.8, r * 0.04)));
  }
  canvas.drawCircle(c, r * 0.16, fillOf(const Color(0xFFC2185B)));
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / 5 + turn;
    canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.3, r * 0.05, fillOf(const Color(0xFFFFD54F)));
  }
}

void paintSakuraBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A2253), Color(0xFF8E4A7A), Color(0xFFF2A9B8)],
      ).createShader(rect),
  );
  // Großer blasser Mond
  canvas.drawCircle(Offset(rect.left + rect.width * 0.78, rect.top + rect.height * 0.2), rect.shortestSide * 0.14, fillOf(const Color(0x33FFF8E1)));
  // Hügel unten
  final hill = Path()..moveTo(rect.left, rect.bottom);
  for (var i = 0; i <= 12; i++) {
    final x = rect.left + rect.width * i / 12;
    hill.lineTo(x, rect.bottom - rect.height * (0.08 + 0.03 * math.sin(i * 0.9)));
  }
  hill
    ..lineTo(rect.right, rect.bottom)
    ..close();
  canvas.drawPath(hill, fillOf(const Color(0x553A2253)));
  // Fallende Blüten, leicht pendelnd
  final rng = math.Random(26);
  for (var i = 0; i < 16; i++) {
    final speed = 0.3 + rng.nextDouble() * 0.5;
    final t = (time * speed + rng.nextDouble()) % 1;
    final x = rect.left + rng.nextDouble() * rect.width + math.sin((t + i) * 2 * math.pi) * 12;
    final y = rect.top + t * rect.height;
    sakuraBlossom(canvas, Offset(x, y), 3 + rng.nextDouble() * 4, light: const Color(0xCCFFE4EE), dark: const Color(0xCCF8BBD0), turn: t * 6);
  }
}

void paintSakuraSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Teeschale
      final bowl = Path()
        ..moveTo(c.dx - w * 0.34, c.dy - w * 0.06)
        ..lineTo(c.dx + w * 0.34, c.dy - w * 0.06)
        ..quadraticBezierTo(c.dx + w * 0.32, c.dy + w * 0.3, c.dx, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx - w * 0.32, c.dy + w * 0.3, c.dx - w * 0.34, c.dy - w * 0.06)
        ..close();
      canvas.drawRect(Rect.fromCenter(center: c.translate(0, w * 0.32), width: w * 0.24, height: w * 0.06), fillOf(const Color(0xFF4E342E)));
      shaded(canvas, bowl, const Color(0xFF80CBC4), const Color(0xFF00695C), width: 2.2);
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.06), width: w * 0.68, height: w * 0.14), fillOf(const Color(0xFF9CCC65)));
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.06), width: w * 0.68, height: w * 0.14), strokeOf(_ink, 1.6));
      // Dampf
      for (final dx in [-0.1, 0.06]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + w * dx, c.dy - w * 0.16)
            ..quadraticBezierTo(c.dx + w * (dx + 0.08), c.dy - w * 0.26, c.dx + w * dx, c.dy - w * 0.34)
            ..quadraticBezierTo(c.dx + w * (dx - 0.06), c.dy - w * 0.4, c.dx + w * dx, c.dy - w * 0.46),
          strokeOf(const Color(0xAAFFFFFF), w * 0.025),
        );
      }
    case 1: // Fächer
      final hub = c.translate(0, w * 0.26);
      const n = 9;
      for (var i = 0; i < n; i++) {
        final a0 = -math.pi * 0.86 + i * math.pi * 0.72 / n;
        final a1 = a0 + math.pi * 0.72 / n;
        final seg = Path()
          ..moveTo(hub.dx + math.cos(a0) * w * 0.1, hub.dy + math.sin(a0) * w * 0.1)
          ..lineTo(hub.dx + math.cos(a0) * w * 0.52, hub.dy + math.sin(a0) * w * 0.52)
          ..lineTo(hub.dx + math.cos(a1) * w * 0.52, hub.dy + math.sin(a1) * w * 0.52)
          ..lineTo(hub.dx + math.cos(a1) * w * 0.1, hub.dy + math.sin(a1) * w * 0.1)
          ..close();
        canvas.drawPath(seg, fillOf(i.isEven ? const Color(0xFFE53935) : const Color(0xFFC62828)));
        canvas.drawLine(hub, hub + Offset(math.cos(a0), math.sin(a0)) * w * 0.52, strokeOf(const Color(0xFF5D4037), 1.2));
      }
      canvas.drawArc(Rect.fromCircle(center: hub, radius: w * 0.52), -math.pi * 0.86, math.pi * 0.72, false, strokeOf(_ink, 2));
      sakuraBlossom(canvas, hub.translate(0, -w * 0.32), w * 0.1);
      canvas.drawCircle(hub, w * 0.04, fillOf(const Color(0xFF5D4037)));
    case 2: // Papierkranich
      final body = Path()
        ..moveTo(c.dx - w * 0.4, c.dy + w * 0.06)
        ..lineTo(c.dx - w * 0.06, c.dy + w * 0.02)
        ..lineTo(c.dx, c.dy - w * 0.36)
        ..lineTo(c.dx + w * 0.1, c.dy + w * 0.02)
        ..lineTo(c.dx + w * 0.3, c.dy - w * 0.2)
        ..lineTo(c.dx + w * 0.36, c.dy - w * 0.16)
        ..lineTo(c.dx + w * 0.16, c.dy + w * 0.14)
        ..lineTo(c.dx, c.dy + w * 0.3)
        ..lineTo(c.dx - w * 0.14, c.dy + w * 0.12)
        ..close();
      shaded(canvas, body, Colors.white, const Color(0xFFBBDEFB), width: 2);
      canvas.drawLine(c.translate(0, -w * 0.36), c.translate(0, w * 0.3), strokeOf(const Color(0x6690A4AE), 1.2));
      canvas.drawLine(c.translate(-w * 0.06, w * 0.02), c.translate(w * 0.1, w * 0.02), strokeOf(const Color(0x6690A4AE), 1.2));
      canvas.drawCircle(c.translate(w * 0.33, -w * 0.18), w * 0.025, fillOf(const Color(0xFFE53935)));
    case 3: // Papierlaterne
      canvas.drawLine(c.translate(0, -w * 0.46), c.translate(0, -w * 0.32), strokeOf(_ink, 2));
      final lamp = Rect.fromCenter(center: c, width: w * 0.5, height: w * 0.62);
      glow(canvas, c, w * 0.44, const Color(0x66FFCC80));
      canvas.drawOval(lamp, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFAB91)]).createShader(lamp));
      for (var i = 1; i < 5; i++) {
        final y = lamp.top + lamp.height * i / 5;
        final half = lamp.width / 2 * math.sqrt(1 - math.pow((y - c.dy) / (lamp.height / 2), 2));
        canvas.drawLine(Offset(c.dx - half, y), Offset(c.dx + half, y), strokeOf(const Color(0x88BF360C), 1.2));
      }
      canvas.drawOval(lamp, strokeOf(_ink, 2));
      for (final y in [lamp.top, lamp.bottom]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, y), width: w * 0.24, height: w * 0.06), fillOf(_ink));
      }
      sakuraBlossom(canvas, c, w * 0.12);
    case 4: // Koi
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-0.5);
      final fish = Path()
        ..moveTo(-w * 0.36, 0)
        ..quadraticBezierTo(-w * 0.1, -w * 0.2, w * 0.2, -w * 0.06)
        ..lineTo(w * 0.36, -w * 0.18)
        ..lineTo(w * 0.3, 0)
        ..lineTo(w * 0.36, w * 0.18)
        ..lineTo(w * 0.2, w * 0.06)
        ..quadraticBezierTo(-w * 0.1, w * 0.2, -w * 0.36, 0)
        ..close();
      shaded(canvas, fish, Colors.white, const Color(0xFFECEFF1), width: 2);
      canvas.save();
      canvas.clipPath(fish);
      canvas.drawCircle(Offset(-w * 0.12, -w * 0.06), w * 0.12, fillOf(const Color(0xFFFF7043)));
      canvas.drawCircle(Offset(w * 0.08, w * 0.06), w * 0.09, fillOf(const Color(0xFFFF7043)));
      canvas.drawCircle(Offset(w * 0.2, -w * 0.02), w * 0.05, fillOf(_ink));
      canvas.restore();
      canvas.drawCircle(Offset(-w * 0.26, -w * 0.03), w * 0.025, fillOf(_ink));
      canvas.drawPath(
        Path()
          ..moveTo(-w * 0.08, w * 0.1)
          ..lineTo(0, w * 0.22)
          ..lineTo(w * 0.04, w * 0.08)
          ..close(),
        fillOf(const Color(0xFFFFAB91)),
      );
      canvas.restore();
    case 5: // Pagode
      final roofs = [(0.36, -0.3), (0.3, -0.08), (0.24, 0.14)];
      canvas.drawRect(Rect.fromLTRB(c.dx - w * 0.16, c.dy - w * 0.3, c.dx + w * 0.16, c.dy + w * 0.4), fillOf(const Color(0xFFB71C1C)));
      for (final (half, y) in roofs.reversed) {
        final roof = Path()
          ..moveTo(c.dx - w * half, c.dy + w * (y + 0.06))
          ..quadraticBezierTo(c.dx - w * half * 0.6, c.dy + w * (y - 0.02), c.dx - w * 0.12, c.dy + w * (y - 0.08))
          ..lineTo(c.dx + w * 0.12, c.dy + w * (y - 0.08))
          ..quadraticBezierTo(c.dx + w * half * 0.6, c.dy + w * (y - 0.02), c.dx + w * half, c.dy + w * (y + 0.06))
          ..close();
        shaded(canvas, roof, const Color(0xFF5D4037), const Color(0xFF2B1B14), width: 1.6);
      }
      canvas.drawLine(c.translate(0, -w * 0.38), c.translate(0, -w * 0.48), strokeOf(const Color(0xFFFFD54F), w * 0.03));
      for (final y in [-0.2, 0.02, 0.24]) {
        canvas.drawRect(Rect.fromCenter(center: c.translate(0, w * (y + 0.04)), width: w * 0.08, height: w * 0.08), fillOf(const Color(0xFFFFE082)));
      }
    case 6: // Kirschblüte, Joker
      glow(canvas, c, w * 0.5, const Color(0x99FF80AB));
      sakuraBlossom(canvas, c.translate(0, -w * 0.05), w * 0.36);
      caption(canvas, r, 'JOKER', Colors.white, size: 0.17, y: 0.92, shadow: const Color(0xFF880E4F));
    case 7: // Torii, Scatter
      glow(canvas, c, w * 0.5, const Color(0x88FFAB40));
      const red = Color(0xFFD32F2F);
      for (final dx in [-0.22, 0.22]) {
        canvas.drawRect(Rect.fromCenter(center: c.translate(w * dx, w * 0.1), width: w * 0.08, height: w * 0.58), fillOf(red));
        canvas.drawRect(Rect.fromCenter(center: c.translate(w * dx, w * 0.38), width: w * 0.11, height: w * 0.05), fillOf(_ink));
      }
      final top = Path()
        ..moveTo(c.dx - w * 0.44, c.dy - w * 0.24)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.32, c.dx + w * 0.44, c.dy - w * 0.24)
        ..lineTo(c.dx + w * 0.46, c.dy - w * 0.32)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.42, c.dx - w * 0.46, c.dy - w * 0.32)
        ..close();
      canvas.drawPath(top, fillOf(_ink));
      canvas.drawRect(Rect.fromCenter(center: c.translate(0, -w * 0.2), width: w * 0.76, height: w * 0.06), fillOf(red));
      canvas.drawRect(Rect.fromCenter(center: c.translate(0, -w * 0.04), width: w * 0.6, height: w * 0.05), fillOf(red));
      caption(canvas, r, 'SCATTER', Colors.white, size: 0.14, y: 0.93);
  }
}
