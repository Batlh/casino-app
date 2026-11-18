import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Vulkaninsel: Abendhimmel, Vulkan mit Glut im Hintergrund, Inselsymbole.

const _ink = Color(0xFF241410);

void paintVulkanBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2B1036), Color(0xFF8A2B2B), Color(0xFFE0703A)],
      ).createShader(rect),
  );
  // Vulkan als Silhouette
  final base = rect.bottom;
  final mountain = Path()
    ..moveTo(rect.left, base)
    ..lineTo(rect.left + rect.width * 0.28, base - rect.height * 0.18)
    ..lineTo(rect.left + rect.width * 0.44, base - rect.height * 0.42)
    ..lineTo(rect.left + rect.width * 0.56, base - rect.height * 0.42)
    ..lineTo(rect.left + rect.width * 0.74, base - rect.height * 0.16)
    ..lineTo(rect.right, base)
    ..close();
  canvas.drawPath(mountain, fillOf(const Color(0xCC2A1410)));
  // Glut am Krater, pulsierend
  final pulse = 0.6 + 0.4 * math.sin(time * 2 * math.pi * 12);
  glow(canvas, Offset(rect.center.dx, base - rect.height * 0.42), rect.width * 0.18 * pulse, const Color(0x99FF7043));
  // Funken steigen aus dem Krater
  final rng = math.Random(11);
  for (var i = 0; i < 16; i++) {
    // Ganze Umläufe je Durchlauf: nahtlose Schleife
    final speed = 5 + rng.nextInt(11);
    final t = (time * speed + rng.nextDouble()) % 1;
    final x = rect.center.dx + (rng.nextDouble() - 0.5) * rect.width * 0.2 * (1 + t * 2);
    final y = base - rect.height * (0.42 + t * 0.55);
    canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 2, fillOf(Color.fromRGBO(255, 160, 60, 1 - t)));
  }
}

void paintVulkanSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Kokosnuss
      final nut = Rect.fromCenter(center: c.translate(0, w * 0.04), width: w * 0.62, height: w * 0.58);
      canvas.drawOval(
        nut,
        Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFA1765A), Color(0xFF4E2E1C)]).createShader(nut),
      );
      canvas.drawOval(nut, strokeOf(_ink, 2));
      for (final dx in [-0.08, 0.0, 0.08]) {
        canvas.drawCircle(c.translate(w * dx, -w * 0.12 + (dx == 0 ? w * 0.06 : 0)), w * 0.035, fillOf(const Color(0xFF2B160C)));
      }
      final rng = math.Random(5);
      for (var i = 0; i < 14; i++) {
        final a = rng.nextDouble() * 2 * math.pi;
        final o = c.translate(math.cos(a) * w * 0.22, w * 0.04 + math.sin(a) * w * 0.2);
        canvas.drawLine(o, o.translate(w * 0.04, w * 0.02), strokeOf(const Color(0x88D7B899), 1.2));
      }
    case 1: // Ananas
      for (var i = -2; i <= 2; i++) {
        final leaf = Path()
          ..moveTo(c.dx + i * w * 0.03, c.dy - w * 0.12)
          ..quadraticBezierTo(c.dx + i * w * 0.1, c.dy - w * 0.3, c.dx + i * w * 0.08, c.dy - w * 0.44)
          ..quadraticBezierTo(c.dx + i * w * 0.04, c.dy - w * 0.28, c.dx + i * w * 0.03 + w * 0.04, c.dy - w * 0.12)
          ..close();
        shaded(canvas, leaf, const Color(0xFF9CCC65), const Color(0xFF2E7D32), width: 1.4);
      }
      final body = Rect.fromCenter(center: c.translate(0, w * 0.14), width: w * 0.44, height: w * 0.56);
      shaded(canvas, Path()..addOval(body), const Color(0xFFFFE082), const Color(0xFFE09A1A), width: 2.2);
      canvas.save();
      canvas.clipPath(Path()..addOval(body));
      final grid = strokeOf(const Color(0x88A0611A), 1.4);
      for (var k = -4; k <= 4; k++) {
        canvas.drawLine(body.topLeft.translate(k * w * 0.1, 0), body.bottomLeft.translate(k * w * 0.1 + w * 0.44, 0), grid);
        canvas.drawLine(body.topRight.translate(k * w * 0.1, 0), body.bottomRight.translate(k * w * 0.1 - w * 0.44, 0), grid);
      }
      canvas.restore();
    case 2: // Hibiskusblüte
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        final petal = Rect.fromCenter(center: c + Offset(math.cos(a), math.sin(a)) * w * 0.2, width: w * 0.34, height: w * 0.34);
        canvas.drawOval(
          petal,
          Paint()..shader = const RadialGradient(colors: [Color(0xFFFF8A80), Color(0xFFD81B60)]).createShader(petal),
        );
        canvas.drawOval(petal, strokeOf(const Color(0xFF880E4F), 1.4));
      }
      canvas.drawCircle(c, w * 0.08, fillOf(const Color(0xFF880E4F)));
      canvas.drawLine(c, c.translate(w * 0.14, -w * 0.16), strokeOf(const Color(0xFFFFEB3B), w * 0.03));
      canvas.drawCircle(c.translate(w * 0.14, -w * 0.16), w * 0.03, fillOf(const Color(0xFFFFC107)));
    case 3: // Papagei
      final body = Path()
        ..moveTo(c.dx - w * 0.04, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.22, c.dy - w * 0.28, c.dx + w * 0.18, c.dy)
        ..quadraticBezierTo(c.dx + w * 0.12, c.dy + w * 0.24, c.dx - w * 0.02, c.dy + w * 0.44)
        ..lineTo(c.dx - w * 0.1, c.dy + w * 0.44)
        ..quadraticBezierTo(c.dx - w * 0.2, c.dy + w * 0.1, c.dx - w * 0.16, c.dy - w * 0.12)
        ..quadraticBezierTo(c.dx - w * 0.14, c.dy - w * 0.3, c.dx - w * 0.04, c.dy - w * 0.3)
        ..close();
      shaded(canvas, body, const Color(0xFFFF5252), const Color(0xFFB71C1C), width: 2.2);
      final wing = Path()
        ..moveTo(c.dx - w * 0.06, c.dy - w * 0.04)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy + w * 0.02, c.dx + w * 0.04, c.dy + w * 0.34)
        ..quadraticBezierTo(c.dx - w * 0.1, c.dy + w * 0.16, c.dx - w * 0.06, c.dy - w * 0.04)
        ..close();
      shaded(canvas, wing, const Color(0xFF4FC3F7), const Color(0xFF1565C0), width: 1.6);
      canvas.drawRect(Rect.fromLTWH(c.dx - w * 0.04, c.dy + w * 0.08, w * 0.08, w * 0.06), fillOf(const Color(0xFFFFEB3B)));
      final beak = Path()
        ..moveTo(c.dx + w * 0.14, c.dy - w * 0.22)
        ..quadraticBezierTo(c.dx + w * 0.32, c.dy - w * 0.2, c.dx + w * 0.22, c.dy - w * 0.04)
        ..lineTo(c.dx + w * 0.16, c.dy - w * 0.12)
        ..close();
      shaded(canvas, beak, const Color(0xFFFFF8E1), const Color(0xFF9E9E9E), width: 1.6);
      canvas.drawCircle(c.translate(w * 0.04, -w * 0.18), w * 0.05, fillOf(Colors.white));
      canvas.drawCircle(c.translate(w * 0.05, -w * 0.18), w * 0.025, fillOf(_ink));
    case 4: // Schildkröte
      for (final o in [Offset(-0.24, -0.16), Offset(0.24, -0.16), Offset(-0.24, 0.2), Offset(0.24, 0.2)]) {
        canvas.drawOval(Rect.fromCenter(center: c + o * w, width: w * 0.16, height: w * 0.12), fillOf(const Color(0xFF8BC34A)));
      }
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, -w * 0.34), width: w * 0.16, height: w * 0.16), fillOf(const Color(0xFF8BC34A)));
      canvas.drawCircle(c.translate(-w * 0.03, -w * 0.36), w * 0.015, fillOf(_ink));
      canvas.drawCircle(c.translate(w * 0.03, -w * 0.36), w * 0.015, fillOf(_ink));
      final shell = Rect.fromCenter(center: c.translate(0, w * 0.02), width: w * 0.54, height: w * 0.6);
      shaded(canvas, Path()..addOval(shell), const Color(0xFF66BB6A), const Color(0xFF1B5E20), width: 2.2);
      canvas.drawPath(polygon(c.translate(0, w * 0.02), w * 0.13, 6), fillOf(const Color(0x66C5E1A5)));
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final o = c.translate(0, w * 0.02) + Offset(math.cos(a), math.sin(a)) * w * 0.13;
        canvas.drawLine(o, c.translate(0, w * 0.02) + Offset(math.cos(a), math.sin(a)) * w * 0.27, strokeOf(const Color(0x991B5E20), 1.4));
      }
    case 5: // Tiki-Maske
      final face = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.52, height: w * 0.8), Radius.circular(w * 0.12));
      shaded(canvas, Path()..addRRect(face), const Color(0xFFBC8A5F), const Color(0xFF5D3A1A), width: 2.5);
      // Stirnband
      canvas.drawRect(Rect.fromLTWH(face.left, c.dy - w * 0.3, face.width, w * 0.07), fillOf(const Color(0xFF26A69A)));
      // Augen
      for (final dx in [-0.11, 0.11]) {
        canvas.drawOval(Rect.fromCenter(center: c.translate(w * dx, -w * 0.1), width: w * 0.14, height: w * 0.1), fillOf(const Color(0xFFFFF3E0)));
        canvas.drawCircle(c.translate(w * dx, -w * 0.1), w * 0.03, fillOf(_ink));
      }
      // Nase und Mund
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - w * 0.06)
          ..lineTo(c.dx - w * 0.06, c.dy + w * 0.08)
          ..lineTo(c.dx + w * 0.06, c.dy + w * 0.08)
          ..close(),
        fillOf(const Color(0xFF6D4C41)),
      );
      final mouth = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, w * 0.22), width: w * 0.32, height: w * 0.12), Radius.circular(w * 0.04));
      canvas.drawRRect(mouth, fillOf(_ink));
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(mouth.left + w * 0.02 + i * w * 0.075, mouth.top, w * 0.05, w * 0.04), fillOf(const Color(0xFFFFF3E0)));
      }
    case 6: // Lavastein, Joker
      glow(canvas, c, w * 0.5, const Color(0xAAFF5722));
      final rock = polygon(c.translate(0, -w * 0.03), w * 0.34, 7, rotation: -math.pi / 3, squash: 0.9);
      shaded(canvas, rock, const Color(0xFF5D4037), const Color(0xFF1B0F0B), width: 2.5);
      final crack = strokeOf(const Color(0xFFFFAB40), w * 0.035);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - w * 0.2, c.dy - w * 0.12)
          ..lineTo(c.dx - w * 0.04, c.dy - w * 0.02)
          ..lineTo(c.dx - w * 0.1, c.dy + w * 0.14)
          ..moveTo(c.dx - w * 0.04, c.dy - w * 0.02)
          ..lineTo(c.dx + w * 0.16, c.dy - w * 0.08)
          ..lineTo(c.dx + w * 0.22, c.dy + w * 0.08),
        crack,
      );
      caption(canvas, r, 'JOKER', const Color(0xFFFFE0B2), size: 0.17, y: 0.92);
    case 7: // Vulkan, Scatter
      glow(canvas, c, w * 0.5, const Color(0xAAFF9800));
      final cone = Path()
        ..moveTo(c.dx - w * 0.4, c.dy + w * 0.28)
        ..lineTo(c.dx - w * 0.1, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.1, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.4, c.dy + w * 0.28)
        ..close();
      shaded(canvas, cone, const Color(0xFF8D6E63), const Color(0xFF3E2723), width: 2.2);
      final lava = Path()
        ..moveTo(c.dx - w * 0.1, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.1, c.dy - w * 0.14)
        ..lineTo(c.dx + w * 0.06, c.dy + w * 0.02)
        ..lineTo(c.dx + w * 0.14, c.dy + w * 0.2)
        ..lineTo(c.dx + w * 0.02, c.dy + w * 0.06)
        ..lineTo(c.dx - w * 0.08, c.dy + w * 0.22)
        ..lineTo(c.dx - w * 0.04, c.dy)
        ..close();
      canvas.drawPath(lava, fillOf(const Color(0xFFFF6D00)));
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.35;
        canvas.drawCircle(c.translate(0, -w * 0.18) + Offset(math.cos(a), math.sin(a)) * w * (0.12 + (i % 2) * 0.06), w * 0.035,
            fillOf(const Color(0xFFFFAB40)));
      }
      caption(canvas, r, 'SCATTER', Colors.white, size: 0.14, y: 0.93);
  }
}
