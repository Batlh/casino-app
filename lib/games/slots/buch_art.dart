import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Zauberbibliothek: alte Bibliothek mit Kerzenlicht.
/// Niedrig: 0 Feder, 1 Kerze, 2 Sanduhr, 10 Schlüssel, 11 Tintenfass.
/// Hoch: 3 Schriftrolle, 12 Trank, 4 Kristallkugel, 5 Eule. 7 Zauberbuch (Joker und Streusymbol).

const _ink = Color(0xFF241410);

void paintBuchBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A1A12), Color(0xFF3B2416), Color(0xFF1A0F0A)],
      ).createShader(rect),
  );
  // Regalbretter mit Buchrücken
  final shelf = fillOf(const Color(0xFF4E3121));
  const spines = [Color(0x557B1F1F), Color(0x55224A2E), Color(0x55223A6B), Color(0x556B5320), Color(0x55502A5E)];
  for (var s = 0; s < 3; s++) {
    final y = rect.top + rect.height * (0.3 + s * 0.33);
    var x = rect.left;
    var i = s * 7;
    while (x < rect.right) {
      final bw = rect.width * (0.025 + (i * 37 % 11) / 400);
      final bh = rect.height * (0.17 + (i * 13 % 7) / 100);
      canvas.drawRect(Rect.fromLTWH(x, y - bh, bw, bh), fillOf(spines[i % spines.length]));
      x += bw + 1.5;
      i++;
    }
    canvas.drawRect(Rect.fromLTWH(rect.left, y, rect.width, rect.height * 0.018), shelf);
  }
  // Schwebender Staub im Kerzenlicht; jede Bahn macht ganze Runden je Durchlauf
  for (var i = 0; i < 26; i++) {
    final turns = 1 + i % 2;
    final a = (time * turns + i * 0.173) * 2 * math.pi;
    final x = rect.left + rect.width * ((i * 0.618) % 1) + math.sin(a) * rect.width * 0.03;
    final y = rect.top + rect.height * ((i * 0.381) % 1) + math.cos(a) * rect.height * 0.04;
    canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.6, fillOf(const Color(0x55FFE0A0)));
  }
  // Warmes Licht von oben
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -1.1),
        radius: 1.1,
        colors: [const Color(0x40FFB74D), const Color(0x00FFB74D)],
      ).createShader(rect),
  );
}

void paintBuchSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Feder
      final vane = Path()
        ..moveTo(c.dx + w * 0.3, c.dy - w * 0.38)
        ..quadraticBezierTo(c.dx - w * 0.12, c.dy - w * 0.32, c.dx - w * 0.2, c.dy + w * 0.18)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy + w * 0.02, c.dx + w * 0.3, c.dy - w * 0.38)
        ..close();
      shaded(canvas, vane, const Color(0xFFF5F5F5), const Color(0xFF90A4AE));
      for (var i = 1; i < 6; i++) {
        final t = i / 6;
        final p = Offset.lerp(c.translate(w * 0.3, -w * 0.38), c.translate(-w * 0.2, w * 0.18), t)!;
        canvas.drawLine(p, p.translate(-w * 0.1, -w * 0.06), strokeOf(const Color(0x8890A4AE), 1.2));
      }
      canvas.drawLine(c.translate(w * 0.3, -w * 0.38), c.translate(-w * 0.3, w * 0.38), strokeOf(const Color(0xFF5D4037), w * 0.03));
      canvas.drawLine(c.translate(-w * 0.27, w * 0.33), c.translate(-w * 0.32, w * 0.41), strokeOf(_ink, w * 0.045));
    case 1: // Kerze
      final body = Rect.fromLTWH(c.dx - w * 0.12, c.dy - w * 0.12, w * 0.24, w * 0.44);
      shaded(canvas, Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(w * 0.03))), const Color(0xFFFFF8E1), const Color(0xFFD7B98E));
      final drip = Path()
        ..moveTo(body.left, body.top + w * 0.02)
        ..quadraticBezierTo(body.left + w * 0.04, body.top + w * 0.12, body.left + w * 0.07, body.top + w * 0.02)
        ..close();
      canvas.drawPath(drip, fillOf(const Color(0xFFFFFDF5)));
      canvas.drawLine(c.translate(0, -w * 0.12), c.translate(0, -w * 0.17), strokeOf(_ink, w * 0.02));
      glow(canvas, c.translate(0, -w * 0.25), w * 0.2, const Color(0x88FFB300));
      final flame = Path()
        ..moveTo(c.dx, c.dy - w * 0.38)
        ..quadraticBezierTo(c.dx + w * 0.08, c.dy - w * 0.22, c.dx, c.dy - w * 0.16)
        ..quadraticBezierTo(c.dx - w * 0.08, c.dy - w * 0.22, c.dx, c.dy - w * 0.38)
        ..close();
      shaded(canvas, flame, const Color(0xFFFFF59D), const Color(0xFFFF6F00), outline: const Color(0xAAE65100), width: 1);
      final dish = Rect.fromCenter(center: c.translate(0, w * 0.33), width: w * 0.5, height: w * 0.1);
      shaded(canvas, Path()..addOval(dish), const Color(0xFFFFE082), const Color(0xFF8D6E00));
    case 2: // Sanduhr
      final top = Rect.fromCenter(center: c.translate(0, -w * 0.34), width: w * 0.5, height: w * 0.07);
      final bottom = Rect.fromCenter(center: c.translate(0, w * 0.34), width: w * 0.5, height: w * 0.07);
      final glass = Path()
        ..moveTo(c.dx - w * 0.19, c.dy - w * 0.3)
        ..quadraticBezierTo(c.dx - w * 0.19, c.dy - w * 0.06, c.dx - w * 0.03, c.dy)
        ..quadraticBezierTo(c.dx - w * 0.19, c.dy + w * 0.06, c.dx - w * 0.19, c.dy + w * 0.3)
        ..lineTo(c.dx + w * 0.19, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.19, c.dy + w * 0.06, c.dx + w * 0.03, c.dy)
        ..quadraticBezierTo(c.dx + w * 0.19, c.dy - w * 0.06, c.dx + w * 0.19, c.dy - w * 0.3)
        ..close();
      canvas.drawPath(glass, fillOf(const Color(0x55B3E5FC)));
      final sandTop = Path()
        ..moveTo(c.dx - w * 0.14, c.dy - w * 0.16)
        ..lineTo(c.dx + w * 0.14, c.dy - w * 0.16)
        ..lineTo(c.dx, c.dy - w * 0.01)
        ..close();
      canvas.drawPath(sandTop, fillOf(const Color(0xFFFFCA28)));
      final sandBottom = Path()
        ..moveTo(c.dx - w * 0.18, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx, c.dy + w * 0.1, c.dx + w * 0.18, c.dy + w * 0.3)
        ..close();
      canvas.drawPath(sandBottom, fillOf(const Color(0xFFFFB300)));
      canvas.drawLine(c, c.translate(0, w * 0.22), strokeOf(const Color(0xFFFFCA28), 1.5));
      canvas.drawPath(glass, strokeOf(const Color(0xCCE1F5FE), 1.6));
      for (final b in [top, bottom]) {
        shaded(canvas, Path()..addRRect(RRect.fromRectAndRadius(b, Radius.circular(w * 0.02))), const Color(0xFFA1887F), const Color(0xFF4E342E));
      }
      for (final dx in [-0.22, 0.22]) {
        canvas.drawLine(c.translate(dx * w, -w * 0.31), c.translate(dx * w, w * 0.31), strokeOf(const Color(0xFF5D4037), w * 0.035));
      }
    case 10: // Schlüssel
      final ring = c.translate(-w * 0.2, -w * 0.18);
      canvas.drawCircle(ring, w * 0.15, strokeOf(const Color(0xFF8D6E00), w * 0.1));
      canvas.drawCircle(ring, w * 0.15, strokeOf(const Color(0xFFFFD54F), w * 0.06));
      final shaft = Path()
        ..moveTo(ring.dx + w * 0.09, ring.dy + w * 0.09)
        ..lineTo(c.dx + w * 0.3, c.dy + w * 0.3)
        ..lineTo(c.dx + w * 0.25, c.dy + w * 0.35)
        ..lineTo(ring.dx + w * 0.04, ring.dy + w * 0.14)
        ..close();
      shaded(canvas, shaft, const Color(0xFFFFE082), const Color(0xFF8D6E00), width: 1.5);
      for (final t in [0.62, 0.8]) {
        final p = Offset.lerp(ring, c.translate(w * 0.3, w * 0.3), t)!;
        final bit = Path()
          ..moveTo(p.dx, p.dy)
          ..lineTo(p.dx + w * 0.1, p.dy - w * 0.04)
          ..lineTo(p.dx + w * 0.13, p.dy + w * 0.0)
          ..lineTo(p.dx + w * 0.04, p.dy + w * 0.05)
          ..close();
        shaded(canvas, bit, const Color(0xFFFFE082), const Color(0xFF8D6E00), width: 1.2);
      }
      sparkle(canvas, ring.translate(-w * 0.08, -w * 0.1), w * 0.05);
    case 11: // Tintenfass mit Feder
      final pot = Path()
        ..moveTo(c.dx - w * 0.24, c.dy + w * 0.34)
        ..lineTo(c.dx - w * 0.28, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx, c.dy - w * 0.06, c.dx + w * 0.28, c.dy + w * 0.02)
        ..lineTo(c.dx + w * 0.24, c.dy + w * 0.34)
        ..close();
      shaded(canvas, pot, const Color(0xFF5C6BC0), const Color(0xFF1A237E));
      final neck = Rect.fromCenter(center: c.translate(0, -w * 0.06), width: w * 0.2, height: w * 0.1);
      shaded(canvas, Path()..addRect(neck), const Color(0xFF3949AB), const Color(0xFF1A237E));
      canvas.drawOval(Rect.fromCenter(center: neck.topCenter, width: w * 0.2, height: w * 0.05), fillOf(const Color(0xFF0D0D1A)));
      canvas.drawLine(neck.topCenter, c.translate(w * 0.3, -w * 0.42), strokeOf(const Color(0xFF5D4037), w * 0.025));
      final vane = Path()
        ..moveTo(c.dx + w * 0.3, c.dy - w * 0.42)
        ..quadraticBezierTo(c.dx + w * 0.02, c.dy - w * 0.3, c.dx + w * 0.06, c.dy - w * 0.14)
        ..quadraticBezierTo(c.dx + w * 0.22, c.dy - w * 0.22, c.dx + w * 0.3, c.dy - w * 0.42)
        ..close();
      shaded(canvas, vane, const Color(0xFFFFFFFF), const Color(0xFFB0BEC5), width: 1.2);
      sparkle(canvas, c.translate(-w * 0.16, w * 0.1), w * 0.05);
    case 3: // Schriftrolle mit Siegel
      final paper = Rect.fromCenter(center: c, width: w * 0.62, height: w * 0.5);
      shaded(canvas, Path()..addRect(paper), const Color(0xFFFFF3D6), const Color(0xFFD7B98E));
      for (final y in [paper.top, paper.bottom]) {
        final roll = Rect.fromCenter(center: Offset(c.dx, y), width: w * 0.72, height: w * 0.1);
        shaded(canvas, Path()..addRRect(RRect.fromRectAndRadius(roll, Radius.circular(w * 0.05))), const Color(0xFFFFE8B5), const Color(0xFFB08850));
      }
      for (var i = 0; i < 4; i++) {
        final y = paper.top + w * (0.1 + i * 0.075);
        canvas.drawLine(Offset(paper.left + w * 0.06, y), Offset(paper.right - w * (i == 3 ? 0.25 : 0.06), y), strokeOf(const Color(0x885D4037), 1.4));
      }
      final seal = c.translate(w * 0.17, w * 0.14);
      canvas.drawCircle(seal, w * 0.09, fillOf(const Color(0xFFC62828)));
      canvas.drawCircle(seal, w * 0.09, strokeOf(const Color(0xFF7F0000), 1.5));
      canvas.drawPath(starPath(seal, w * 0.05), fillOf(const Color(0xFFFF8A80)));
    case 12: // Zaubertrank
      final bottle = Path()
        ..moveTo(c.dx - w * 0.06, c.dy - w * 0.22)
        ..lineTo(c.dx - w * 0.06, c.dy - w * 0.08)
        ..cubicTo(c.dx - w * 0.36, c.dy + w * 0.0, c.dx - w * 0.32, c.dy + w * 0.4, c.dx, c.dy + w * 0.38)
        ..cubicTo(c.dx + w * 0.32, c.dy + w * 0.4, c.dx + w * 0.36, c.dy + w * 0.0, c.dx + w * 0.06, c.dy - w * 0.08)
        ..lineTo(c.dx + w * 0.06, c.dy - w * 0.22)
        ..close();
      glow(canvas, c.translate(0, w * 0.15), w * 0.38, const Color(0x6600E676));
      canvas.drawPath(bottle, fillOf(const Color(0x44E0F7FA)));
      canvas.save();
      canvas.clipPath(bottle);
      canvas.drawRect(
        Rect.fromLTRB(c.dx - w * 0.4, c.dy + w * 0.04, c.dx + w * 0.4, c.dy + w * 0.42),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF69F0AE), Color(0xFF00695C)]).createShader(r),
      );
      for (final (dx, dy, rr) in [(-0.1, 0.18, 0.03), (0.06, 0.26, 0.022), (0.1, 0.12, 0.018)]) {
        canvas.drawCircle(c.translate(dx * w, dy * w), rr * w, strokeOf(const Color(0xAAE0F2F1), 1.2));
      }
      canvas.restore();
      canvas.drawPath(bottle, strokeOf(const Color(0xFFB2EBF2), 1.8));
      final cork = Rect.fromCenter(center: c.translate(0, -w * 0.27), width: w * 0.14, height: w * 0.1);
      shaded(canvas, Path()..addRRect(RRect.fromRectAndRadius(cork, Radius.circular(w * 0.02))), const Color(0xFFBCAAA4), const Color(0xFF6D4C41));
      sparkle(canvas, c.translate(-w * 0.12, w * 0.02), w * 0.05);
    case 4: // Kristallkugel
      final ball = c.translate(0, -w * 0.06);
      final br = w * 0.3;
      glow(canvas, ball, br * 1.4, const Color(0x667C4DFF));
      canvas.drawCircle(
        ball,
        br,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFE1BEE7), Color(0xFF7E57C2), Color(0xFF311B92)])
              .createShader(Rect.fromCircle(center: ball, radius: br)),
      );
      canvas.drawCircle(ball, br, strokeOf(const Color(0xFF1A0F3A), 2));
      // Nebel im Inneren
      for (var i = 0; i < 3; i++) {
        final a = i * 2.1;
        canvas.drawCircle(ball.translate(math.cos(a) * br * 0.35, math.sin(a) * br * 0.3), br * 0.25, fillOf(const Color(0x33FFFFFF)));
      }
      sparkle(canvas, ball.translate(-br * 0.4, -br * 0.42), br * 0.2);
      final stand = Path()
        ..moveTo(c.dx - w * 0.2, c.dy + w * 0.38)
        ..lineTo(c.dx - w * 0.13, c.dy + w * 0.2)
        ..lineTo(c.dx + w * 0.13, c.dy + w * 0.2)
        ..lineTo(c.dx + w * 0.2, c.dy + w * 0.38)
        ..close();
      shaded(canvas, stand, const Color(0xFFFFE082), const Color(0xFF8D6E00));
    case 5: // Eule
      final body = Rect.fromCenter(center: c.translate(0, w * 0.06), width: w * 0.62, height: w * 0.72);
      shaded(canvas, Path()..addOval(body), const Color(0xFFBCAAA4), const Color(0xFF4E342E));
      final belly = Rect.fromCenter(center: c.translate(0, w * 0.2), width: w * 0.36, height: w * 0.36);
      canvas.drawOval(belly, fillOf(const Color(0xFFEFEBE9)));
      for (var i = 0; i < 3; i++) {
        for (var j = -1; j <= 1; j++) {
          final p = belly.center.translate(j * w * 0.08, -w * 0.08 + i * w * 0.08);
          canvas.drawArc(Rect.fromCenter(center: p, width: w * 0.06, height: w * 0.05), 0, math.pi, false, strokeOf(const Color(0xFF8D6E63), 1.2));
        }
      }
      // Ohrbüschel
      for (final s in [-1.0, 1.0]) {
        final tuft = Path()
          ..moveTo(c.dx + s * w * 0.12, c.dy - w * 0.24)
          ..lineTo(c.dx + s * w * 0.3, c.dy - w * 0.42)
          ..lineTo(c.dx + s * w * 0.27, c.dy - w * 0.18)
          ..close();
        shaded(canvas, tuft, const Color(0xFFA1887F), const Color(0xFF4E342E), width: 1.5);
      }
      for (final s in [-1.0, 1.0]) {
        final eye = c.translate(s * w * 0.13, -w * 0.12);
        canvas.drawCircle(eye, w * 0.11, fillOf(const Color(0xFFFFF8E1)));
        canvas.drawCircle(eye, w * 0.11, strokeOf(const Color(0xFF3E2723), 1.5));
        canvas.drawCircle(eye, w * 0.07, fillOf(const Color(0xFFFFB300)));
        canvas.drawCircle(eye, w * 0.04, fillOf(_ink));
        canvas.drawCircle(eye.translate(-w * 0.015, -w * 0.02), w * 0.012, fillOf(Colors.white));
      }
      final beak = Path()
        ..moveTo(c.dx - w * 0.04, c.dy - w * 0.04)
        ..lineTo(c.dx + w * 0.04, c.dy - w * 0.04)
        ..lineTo(c.dx, c.dy + w * 0.05)
        ..close();
      canvas.drawPath(beak, fillOf(const Color(0xFFFFA000)));
      // Kleiner Gelehrtenhut
      final cap = Path()
        ..moveTo(c.dx - w * 0.2, c.dy - w * 0.3)
        ..lineTo(c.dx, c.dy - w * 0.38)
        ..lineTo(c.dx + w * 0.2, c.dy - w * 0.3)
        ..lineTo(c.dx, c.dy - w * 0.23)
        ..close();
      shaded(canvas, cap, const Color(0xFF455A64), const Color(0xFF15202B), width: 1.2);
      canvas.drawLine(c.translate(w * 0.02, -w * 0.31), c.translate(w * 0.17, -w * 0.22), strokeOf(const Color(0xFFFFC107), 1.6));
    case 7: // Zauberbuch, Joker und Streusymbol
      glow(canvas, c, w * 0.55, const Color(0x99FFD54F));
      final cover = Path()
        ..moveTo(c.dx - w * 0.38, c.dy - w * 0.28)
        ..quadraticBezierTo(c.dx - w * 0.18, c.dy - w * 0.34, c.dx, c.dy - w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.18, c.dy - w * 0.34, c.dx + w * 0.38, c.dy - w * 0.28)
        ..lineTo(c.dx + w * 0.38, c.dy + w * 0.26)
        ..quadraticBezierTo(c.dx + w * 0.18, c.dy + w * 0.2, c.dx, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx - w * 0.18, c.dy + w * 0.2, c.dx - w * 0.38, c.dy + w * 0.26)
        ..close();
      shaded(canvas, cover, const Color(0xFFB71C1C), const Color(0xFF4A0000));
      final pages = Path()
        ..moveTo(c.dx - w * 0.34, c.dy - w * 0.25)
        ..quadraticBezierTo(c.dx - w * 0.16, c.dy - w * 0.3, c.dx, c.dy - w * 0.22)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy - w * 0.3, c.dx + w * 0.34, c.dy - w * 0.25)
        ..lineTo(c.dx + w * 0.34, c.dy + w * 0.2)
        ..quadraticBezierTo(c.dx + w * 0.16, c.dy + w * 0.15, c.dx, c.dy + w * 0.25)
        ..quadraticBezierTo(c.dx - w * 0.16, c.dy + w * 0.15, c.dx - w * 0.34, c.dy + w * 0.2)
        ..close();
      shaded(canvas, pages, const Color(0xFFFFF8E1), const Color(0xFFE0C38C), width: 1.4);
      canvas.drawLine(c.translate(0, -w * 0.22), c.translate(0, w * 0.25), strokeOf(const Color(0xFFB08850), 1.4));
      // Runen auf beiden Seiten
      for (final s in [-1.0, 1.0]) {
        for (var i = 0; i < 4; i++) {
          final y = c.dy - w * 0.12 + i * w * 0.08;
          canvas.drawLine(Offset(c.dx + s * w * 0.06, y), Offset(c.dx + s * w * (i == 3 ? 0.18 : 0.28), y), strokeOf(const Color(0x995D4037), 1.3));
        }
      }
      final star = starPath(c.translate(0, -w * 0.02), w * 0.13, n: 8, inner: 0.4);
      canvas.drawPath(star, fillOf(const Color(0xCCFFC107)));
      sparkle(canvas, c.translate(-w * 0.3, -w * 0.36), w * 0.07);
      sparkle(canvas, c.translate(w * 0.32, -w * 0.33), w * 0.05);
      caption(canvas, r, 'BUCH', const Color(0xFFFFE082), size: 0.17, y: 0.93);
    default:
      canvas.drawCircle(c, w * 0.3, fillOf(const Color(0xFF795548)));
  }
}
