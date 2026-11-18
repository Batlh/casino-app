import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Jadetempel: rote Tempelhalle mit goldenen Mustern, Glückssymbole aus Jade und Gold.

const _ink = Color(0xFF2A1208);
const _gold = Color(0xFFFFD54F);
const _goldDark = Color(0xFFB8860B);

void paintJadeBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5A0F12), Color(0xFF8E1B1B), Color(0xFF3A0808)],
      ).createShader(rect),
  );
  // Wolkenmuster in Gold, ganz blass
  final cloud = strokeOf(const Color(0x22FFD54F), 2);
  for (var i = 0; i < 6; i++) {
    final c = Offset(rect.left + rect.width * ((i * 0.37) % 1), rect.top + rect.height * ((i * 0.53 + 0.1) % 1));
    for (var k = 0; k < 3; k++) {
      canvas.drawArc(Rect.fromCircle(center: c.translate(k * 14.0, 0), radius: 10), math.pi, math.pi, false, cloud);
    }
  }
  // Rote Laternen oben, sanft schwingend
  for (var i = 0; i < 4; i++) {
    final x = rect.left + rect.width * (0.12 + i * 0.25);
    final swing = math.sin(time * 2 * math.pi + i) * 0.08;
    canvas.save();
    canvas.translate(x, rect.top);
    canvas.rotate(swing);
    canvas.drawLine(Offset.zero, const Offset(0, 14), strokeOf(const Color(0x88FFD54F), 1));
    final lamp = Rect.fromCenter(center: const Offset(0, 24), width: 18, height: 20);
    glow(canvas, lamp.center, 18, const Color(0x55FF8A65));
    canvas.drawOval(lamp, fillOf(const Color(0xCCE53935)));
    canvas.restore();
  }
}

void paintJadeSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Bambus
      for (final (dx, h, tilt) in [(-0.14, 0.8, -0.08), (0.12, 0.7, 0.1)]) {
        canvas.save();
        canvas.translate(c.dx + w * dx, c.dy + w * 0.4);
        canvas.rotate(tilt);
        final stalk = Rect.fromLTWH(-w * 0.06, -w * h, w * 0.12, w * h);
        canvas.drawRect(stalk, Paint()..shader = const LinearGradient(colors: [Color(0xFFAED581), Color(0xFF33691E)]).createShader(stalk));
        for (var k = 1; k < 4; k++) {
          canvas.drawLine(Offset(-w * 0.07, -w * h * k / 4), Offset(w * 0.07, -w * h * k / 4), strokeOf(const Color(0xFF1B5E20), 2));
        }
        canvas.drawRect(stalk, strokeOf(_ink, 1.4));
        final leaf = Path()
          ..moveTo(w * 0.05, -w * h * 0.6)
          ..quadraticBezierTo(w * 0.22, -w * h * 0.75, w * 0.3, -w * h * 0.62)
          ..quadraticBezierTo(w * 0.2, -w * h * 0.58, w * 0.05, -w * h * 0.6)
          ..close();
        canvas.drawPath(leaf, fillOf(const Color(0xFF7CB342)));
        canvas.restore();
      }
    case 1: // Lotusblüte
      canvas.drawOval(Rect.fromCenter(center: c.translate(0, w * 0.28), width: w * 0.76, height: w * 0.18), fillOf(const Color(0xFF2E7D32)));
      for (final (a, s) in [(-1.1, 0.8), (1.1, 0.8), (-0.55, 0.95), (0.55, 0.95), (0.0, 1.0)]) {
        canvas.save();
        canvas.translate(c.dx, c.dy + w * 0.22);
        canvas.rotate(a);
        final petal = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-w * 0.14 * s, -w * 0.22 * s, 0, -w * 0.46 * s)
          ..quadraticBezierTo(w * 0.14 * s, -w * 0.22 * s, 0, 0)
          ..close();
        shaded(canvas, petal, const Color(0xFFFFFFFF), const Color(0xFFF06292), width: 1.4);
        canvas.restore();
      }
      canvas.drawCircle(c.translate(0, w * 0.06), w * 0.05, fillOf(const Color(0xFFFFD54F)));
    case 2: // Jadescheibe
      glow(canvas, c, w * 0.48, const Color(0x5566BB6A));
      final disc = Rect.fromCircle(center: c, radius: w * 0.38);
      canvas.drawCircle(
        c,
        w * 0.38,
        Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFB9F6CA), Color(0xFF2E7D32), Color(0xFF1B5E20)]).createShader(disc),
      );
      canvas.drawCircle(c, w * 0.12, fillOf(const Color(0xFF8E1B1B)));
      canvas.drawCircle(c, w * 0.38, strokeOf(_ink, 2));
      canvas.drawCircle(c, w * 0.12, strokeOf(_ink, 1.6));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.25, w * 0.03, fillOf(const Color(0x88E8F5E9)));
      }
      sparkle(canvas, c.translate(-w * 0.18, -w * 0.2), w * 0.06);
    case 3: // Rote Laterne mit Quaste
      canvas.drawLine(c.translate(0, -w * 0.46), c.translate(0, -w * 0.3), strokeOf(_gold, 2));
      final lamp = Rect.fromCenter(center: c.translate(0, -w * 0.02), width: w * 0.6, height: w * 0.5);
      glow(canvas, lamp.center, w * 0.45, const Color(0x55FF7043));
      canvas.drawOval(lamp, Paint()..shader = const RadialGradient(colors: [Color(0xFFFF8A65), Color(0xFFC62828)]).createShader(lamp));
      for (final f in [-0.6, -0.25, 0.25, 0.6]) {
        canvas.drawArc(
          Rect.fromCenter(center: lamp.center, width: lamp.width * (1 - f.abs()), height: lamp.height),
          -math.pi / 2,
          math.pi * (f > 0 ? 1 : -1),
          false,
          strokeOf(const Color(0x66FFD54F), 1.2),
        );
      }
      canvas.drawOval(lamp, strokeOf(_ink, 2));
      for (final y in [lamp.top, lamp.bottom]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(c.dx, y), width: w * 0.26, height: w * 0.06), fillOf(_gold));
      }
      for (var i = -2; i <= 2; i++) {
        canvas.drawLine(Offset(c.dx + i * w * 0.02, lamp.bottom + w * 0.03), Offset(c.dx + i * w * 0.03, lamp.bottom + w * 0.18), strokeOf(const Color(0xFFE53935), 1.6));
      }
    case 4: // Goldbarren
      glow(canvas, c, w * 0.48, const Color(0x66FFD54F));
      final boat = Path()
        ..moveTo(c.dx - w * 0.42, c.dy - w * 0.08)
        ..quadraticBezierTo(c.dx - w * 0.3, c.dy + w * 0.3, c.dx, c.dy + w * 0.3)
        ..quadraticBezierTo(c.dx + w * 0.3, c.dy + w * 0.3, c.dx + w * 0.42, c.dy - w * 0.08)
        ..quadraticBezierTo(c.dx + w * 0.22, c.dy + w * 0.02, c.dx, c.dy + w * 0.02)
        ..quadraticBezierTo(c.dx - w * 0.22, c.dy + w * 0.02, c.dx - w * 0.42, c.dy - w * 0.08)
        ..close();
      final dome = Rect.fromCenter(center: c.translate(0, -w * 0.02), width: w * 0.36, height: w * 0.36);
      canvas.drawOval(dome, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFF59D), _goldDark]).createShader(dome));
      canvas.drawOval(dome, strokeOf(_ink, 1.8));
      shaded(canvas, boat, const Color(0xFFFFF176), _goldDark, width: 2.2);
      sparkle(canvas, c.translate(-w * 0.08, -w * 0.12), w * 0.07);
    case 5: // Glücksfrosch mit Münze
      final body = Rect.fromCenter(center: c.translate(0, w * 0.1), width: w * 0.7, height: w * 0.52);
      shaded(canvas, Path()..addOval(body), const Color(0xFFFFE082), const Color(0xFFB8860B), width: 2.4);
      for (final dx in [-0.16, 0.16]) {
        final eye = c.translate(w * dx, -w * 0.16);
        canvas.drawCircle(eye, w * 0.1, fillOf(const Color(0xFFFFE082)));
        canvas.drawCircle(eye, w * 0.1, strokeOf(_ink, 1.8));
        canvas.drawCircle(eye, w * 0.045, fillOf(_ink));
      }
      canvas.drawArc(Rect.fromCenter(center: c.translate(0, w * 0.08), width: w * 0.3, height: w * 0.12), 0, math.pi, false, strokeOf(_ink, 2));
      // Münze im Maul
      final coin = c.translate(0, w * 0.22);
      canvas.drawCircle(coin, w * 0.1, fillOf(_gold));
      canvas.drawCircle(coin, w * 0.1, strokeOf(_ink, 1.4));
      canvas.drawRect(Rect.fromCenter(center: coin, width: w * 0.06, height: w * 0.06), fillOf(_ink));
      for (final o in [Offset(-0.18, 0.08), Offset(0.2, 0.18), Offset(0.02, 0.0)]) {
        canvas.drawCircle(c + o * w, w * 0.025, fillOf(const Color(0x8833691E)));
      }
    case 6: // Drachenperle, Joker
      glow(canvas, c, w * 0.52, const Color(0xAA00E5FF));
      // Flammen um die Perle
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final tip = c + Offset(math.cos(a), math.sin(a)) * w * 0.44;
        final side = Offset(-math.sin(a), math.cos(a)) * w * 0.1;
        canvas.drawPath(
          Path()
            ..moveTo((c + side).dx, (c + side).dy)
            ..quadraticBezierTo(tip.dx + side.dx, tip.dy + side.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(tip.dx - side.dx, tip.dy - side.dy, (c - side).dx, (c - side).dy)
            ..close(),
          fillOf(const Color(0xCCFF7043)),
        );
      }
      final pearl = Rect.fromCircle(center: c, radius: w * 0.26);
      canvas.drawCircle(
        c,
        w * 0.26,
        Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Colors.white, Color(0xFF80DEEA), Color(0xFF00838F)]).createShader(pearl),
      );
      canvas.drawCircle(c, w * 0.26, strokeOf(_ink, 1.8));
      caption(canvas, r, 'JOKER', const Color(0xFFFFE082), size: 0.17, y: 0.92);
    case 8: // Glücksmünze mit eckigem Loch
      goldCoin(canvas, r);
      canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.16, height: w * 0.16), fillOf(const Color(0xFF8E1B1B)));
      canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.16, height: w * 0.16), strokeOf(const Color(0xFF7A5200), 1.6));
      for (final o in [Offset(0, -0.22), Offset(0, 0.22), Offset(-0.22, 0), Offset(0.22, 0)]) {
        canvas.drawCircle(c + o * w, w * 0.035, fillOf(const Color(0xFF7A5200)));
      }
  }
}
