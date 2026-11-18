import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Drachenhort: Höhle mit Goldberg, Schatzsymbole in Gold und Purpur.

const _ink = Color(0xFF241410);

void paintDrachenBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A0F2E), Color(0xFF3D1236), Color(0xFF1A0712)],
      ).createShader(rect),
  );
  // Goldberg unten
  final heap = Path()..moveTo(rect.left, rect.bottom);
  for (var i = 0; i <= 10; i++) {
    final x = rect.left + rect.width * i / 10;
    heap.lineTo(x, rect.bottom - rect.height * (0.12 + 0.05 * math.sin(i * 1.7)));
  }
  heap
    ..lineTo(rect.right, rect.bottom)
    ..close();
  canvas.drawPath(heap, fillOf(const Color(0x55E0A526)));
  // Glutfunken steigen auf
  final rng = math.Random(3);
  for (var i = 0; i < 18; i++) {
    final x = rect.left + rng.nextDouble() * rect.width;
    final speed = 0.5 + rng.nextDouble();
    final y = rect.bottom - ((time * speed + rng.nextDouble()) % 1) * rect.height;
    canvas.drawCircle(Offset(x, y), 1.5 + rng.nextDouble() * 2, fillOf(const Color(0x99FF9800)));
  }
}

void paintDrachenSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Schriftrolle
      final paper = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w * 0.56, height: w * 0.62), Radius.circular(w * 0.04));
      shaded(canvas, Path()..addRRect(paper), const Color(0xFFFFF3D6), const Color(0xFFD9B77E));
      for (final dy in [-0.31, 0.31]) {
        final roll = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, w * dy), width: w * 0.7, height: w * 0.1), Radius.circular(w * 0.05));
        shaded(canvas, Path()..addRRect(roll), const Color(0xFFC98A4B), const Color(0xFF7A4A1E));
      }
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(c.translate(-w * 0.18, -w * 0.14 + i * w * 0.09), c.translate(w * 0.18, -w * 0.14 + i * w * 0.09), strokeOf(const Color(0xFF8B5A2B), 1.4));
      }
      canvas.drawCircle(c.translate(0, w * 0.2), w * 0.05, fillOf(const Color(0xFFB71C1C)));
    case 1: // Kelch
      final cup = Path()
        ..moveTo(c.dx - w * 0.24, c.dy - w * 0.28)
        ..lineTo(c.dx + w * 0.24, c.dy - w * 0.28)
        ..quadraticBezierTo(c.dx + w * 0.22, c.dy + w * 0.06, c.dx, c.dy + w * 0.08)
        ..quadraticBezierTo(c.dx - w * 0.22, c.dy + w * 0.06, c.dx - w * 0.24, c.dy - w * 0.28)
        ..close();
      final foot = Path()
        ..moveTo(c.dx - w * 0.04, c.dy + w * 0.08)
        ..lineTo(c.dx + w * 0.04, c.dy + w * 0.08)
        ..lineTo(c.dx + w * 0.05, c.dy + w * 0.26)
        ..lineTo(c.dx + w * 0.2, c.dy + w * 0.34)
        ..lineTo(c.dx - w * 0.2, c.dy + w * 0.34)
        ..lineTo(c.dx - w * 0.05, c.dy + w * 0.26)
        ..close();
      shaded(canvas, foot, const Color(0xFFFFE082), const Color(0xFFB8860B));
      shaded(canvas, cup, const Color(0xFFFFE082), const Color(0xFFB8860B));
      canvas.drawCircle(c.translate(0, -w * 0.1), w * 0.06, fillOf(const Color(0xFF00897B)));
    case 2: // Schwert
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(-math.pi / 4);
      final blade = Path()
        ..moveTo(-w * 0.06, w * 0.12)
        ..lineTo(-w * 0.06, -w * 0.32)
        ..lineTo(0, -w * 0.42)
        ..lineTo(w * 0.06, -w * 0.32)
        ..lineTo(w * 0.06, w * 0.12)
        ..close();
      shaded(canvas, blade, const Color(0xFFF5F5F5), const Color(0xFF90A4AE));
      final guard = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, w * 0.14), width: w * 0.36, height: w * 0.07), Radius.circular(w * 0.03));
      shaded(canvas, Path()..addRRect(guard), const Color(0xFFFFE082), const Color(0xFFB8860B));
      canvas.drawRect(Rect.fromCenter(center: Offset(0, w * 0.27), width: w * 0.07, height: w * 0.2), fillOf(const Color(0xFF5D4037)));
      canvas.drawCircle(Offset(0, w * 0.4), w * 0.05, fillOf(const Color(0xFFFFC107)));
      canvas.restore();
    case 3: // Schild
      final shield = Path()
        ..moveTo(c.dx - w * 0.3, c.dy - w * 0.32)
        ..lineTo(c.dx + w * 0.3, c.dy - w * 0.32)
        ..quadraticBezierTo(c.dx + w * 0.32, c.dy + w * 0.18, c.dx, c.dy + w * 0.4)
        ..quadraticBezierTo(c.dx - w * 0.32, c.dy + w * 0.18, c.dx - w * 0.3, c.dy - w * 0.32)
        ..close();
      shaded(canvas, shield, const Color(0xFF5C6BC0), const Color(0xFF1A237E), width: 3);
      canvas.drawLine(c.translate(0, -w * 0.3), c.translate(0, w * 0.36), strokeOf(const Color(0xFFFFD54F), w * 0.06));
      canvas.drawLine(c.translate(-w * 0.28, -w * 0.06), c.translate(w * 0.28, -w * 0.06), strokeOf(const Color(0xFFFFD54F), w * 0.06));
    case 4: // Krone
      final crown = Path()
        ..moveTo(c.dx - w * 0.34, c.dy + w * 0.2)
        ..lineTo(c.dx - w * 0.38, c.dy - w * 0.2)
        ..lineTo(c.dx - w * 0.16, c.dy - w * 0.02)
        ..lineTo(c.dx, c.dy - w * 0.32)
        ..lineTo(c.dx + w * 0.16, c.dy - w * 0.02)
        ..lineTo(c.dx + w * 0.38, c.dy - w * 0.2)
        ..lineTo(c.dx + w * 0.34, c.dy + w * 0.2)
        ..close();
      shaded(canvas, crown, const Color(0xFFFFE082), const Color(0xFFB8860B), width: 2.5);
      canvas.drawRect(Rect.fromLTRB(c.dx - w * 0.34, c.dy + w * 0.14, c.dx + w * 0.34, c.dy + w * 0.26), fillOf(const Color(0xFFC62828)));
      for (final dx in [-0.2, 0.0, 0.2]) {
        canvas.drawCircle(c.translate(w * dx, w * 0.2), w * 0.035, fillOf(const Color(0xFFFFF59D)));
      }
      for (final p in [Offset(-w * 0.38, -w * 0.2), Offset(0, -w * 0.32), Offset(w * 0.38, -w * 0.2)]) {
        canvas.drawCircle(c + p, w * 0.045, fillOf(const Color(0xFF4FC3F7)));
      }
    case 5: // Drache
      _dragon(canvas, r);
    case 6: // Drachenei, Joker
      glow(canvas, c, w * 0.5, const Color(0x88E040FB));
      final egg = Rect.fromCenter(center: c.translate(0, -w * 0.02), width: w * 0.56, height: w * 0.72);
      canvas.drawOval(
        egg,
        Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF3E5F5), Color(0xFF8E24AA), Color(0xFF38006B)]).createShader(egg),
      );
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawPath(starPath(egg.center + Offset(math.cos(a) * w * 0.14, math.sin(a) * w * 0.2), w * 0.05, n: 3), fillOf(const Color(0x99FFD54F)));
      }
      canvas.drawOval(egg, strokeOf(_ink, 2));
      caption(canvas, r, 'JOKER', const Color(0xFFFFE082), size: 0.17, y: 0.92);
    case 8: // Goldmünze
      goldCoin(canvas, r, mark: '');
      _miniDragon(canvas, r.center, w * 0.16);
  }
}

void _dragon(Canvas canvas, Rect r) {
  final c = r.center;
  final w = r.width;
  glow(canvas, c, w * 0.5, const Color(0x66FF5722));
  final head = Path()
    ..moveTo(c.dx - w * 0.34, c.dy + w * 0.06)
    ..quadraticBezierTo(c.dx - w * 0.3, c.dy - w * 0.22, c.dx, c.dy - w * 0.2)
    ..lineTo(c.dx + w * 0.36, c.dy - w * 0.06)
    ..quadraticBezierTo(c.dx + w * 0.4, c.dy + w * 0.06, c.dx + w * 0.3, c.dy + w * 0.1)
    ..lineTo(c.dx + w * 0.02, c.dy + w * 0.12)
    ..quadraticBezierTo(c.dx - w * 0.04, c.dy + w * 0.36, c.dx - w * 0.3, c.dy + w * 0.36)
    ..close();
  // Hörner
  for (final dx in [-0.16, 0.0]) {
    final horn = Path()
      ..moveTo(c.dx + w * dx, c.dy - w * 0.18)
      ..quadraticBezierTo(c.dx + w * (dx - 0.06), c.dy - w * 0.38, c.dx + w * (dx - 0.14), c.dy - w * 0.42)
      ..quadraticBezierTo(c.dx + w * (dx + 0.02), c.dy - w * 0.32, c.dx + w * (dx + 0.08), c.dy - w * 0.17)
      ..close();
    shaded(canvas, horn, const Color(0xFFFFF8E1), const Color(0xFFBCAAA4));
  }
  shaded(canvas, head, const Color(0xFF66BB6A), const Color(0xFF1B5E20), width: 2.5);
  // Auge und Nüstern
  canvas.drawOval(Rect.fromCenter(center: c.translate(-w * 0.04, -w * 0.08), width: w * 0.12, height: w * 0.08), fillOf(const Color(0xFFFFEB3B)));
  canvas.drawOval(Rect.fromCenter(center: c.translate(-w * 0.04, -w * 0.08), width: w * 0.03, height: w * 0.07), fillOf(_ink));
  canvas.drawCircle(c.translate(w * 0.3, -w * 0.02), w * 0.02, fillOf(_ink));
  // Zähne
  for (var i = 0; i < 4; i++) {
    final x = c.dx + w * (0.06 + i * 0.06);
    canvas.drawPath(
      Path()
        ..moveTo(x, c.dy + w * 0.11)
        ..lineTo(x + w * 0.025, c.dy + w * 0.17)
        ..lineTo(x + w * 0.05, c.dy + w * 0.11)
        ..close(),
      fillOf(Colors.white),
    );
  }
}

void _miniDragon(Canvas canvas, Offset c, double s) {
  final p = Path()
    ..moveTo(c.dx - s, c.dy + s * 0.4)
    ..quadraticBezierTo(c.dx - s * 0.6, c.dy - s, c.dx + s * 0.2, c.dy - s * 0.6)
    ..lineTo(c.dx + s, c.dy - s * 0.2)
    ..lineTo(c.dx + s * 0.2, c.dy + s * 0.1)
    ..quadraticBezierTo(c.dx, c.dy + s, c.dx - s, c.dy + s * 0.4)
    ..close();
  canvas.drawPath(p, fillOf(const Color(0xAA7A5200)));
}
