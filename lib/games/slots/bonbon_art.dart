import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Bonbonfabrik: 7 × 7 Süßigkeiten, Gruppen ab fünf gleichen.
/// 0 Himbeerbonbon, 1 Zitronendrops, 10 Minzwürfel, 2 Blaubeerherz, 11 Orangenring, 3 Gummistern,
/// 4 Lakritzschnecke, 5 Lutscher, 6 Zuckerkugel (Joker), 7 Bonbonglas (Streusymbol).

void paintBonbonBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A1942), Color(0xFF6B2459), Color(0xFF2E0F2A)],
      ).createShader(rect),
  );
  // Schräge Zuckerstreifen
  final stripe = fillOf(const Color(0x14FFFFFF));
  final step = rect.width / 6;
  for (var i = -6; i < 12; i++) {
    final x = rect.left + i * step;
    canvas.drawPath(
      Path()
        ..moveTo(x, rect.bottom)
        ..lineTo(x + step * 0.45, rect.bottom)
        ..lineTo(x + step * 0.45 + rect.height, rect.top)
        ..lineTo(x + rect.height, rect.top)
        ..close(),
      stripe,
    );
  }
  // Streusel, die sich langsam drehen und sinken; ganze Umläufe je Durchlauf
  const colors = [Color(0x66FF80AB), Color(0x66FFF176), Color(0x6680DEEA), Color(0x66B9F6CA), Color(0x66FFFFFF)];
  for (var i = 0; i < 30; i++) {
    final x = rect.left + rect.width * ((i * 0.618) % 1);
    final y = rect.top - 10 + (rect.height + 20) * ((time + i * 0.29) % 1);
    final a = (time * (1 + i % 3) + i * 0.1) * 2 * math.pi;
    final d = Offset(math.cos(a), math.sin(a)) * 4.0;
    canvas.drawLine(Offset(x, y) - d, Offset(x, y) + d, strokeOf(colors[i % colors.length], 2.6));
  }
}

void paintBonbonSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0: // Himbeerbonbon im Papier
      for (final s in [-1.0, 1.0]) {
        final end = Path()
          ..moveTo(c.dx + s * w * 0.2, c.dy)
          ..lineTo(c.dx + s * w * 0.44, c.dy - w * 0.16)
          ..quadraticBezierTo(c.dx + s * w * 0.38, c.dy, c.dx + s * w * 0.44, c.dy + w * 0.16)
          ..close();
        shaded(canvas, end, const Color(0xFFFFCDD2), const Color(0xFFE57373), width: 1.5);
      }
      final body = Rect.fromCenter(center: c, width: w * 0.5, height: w * 0.4);
      canvas.drawOval(body, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFF8A80), Color(0xFFC2185B)]).createShader(body));
      canvas.drawOval(body, strokeOf(const Color(0xFF6A0F2E), 2));
      for (var i = 0; i < 3; i++) {
        final x = body.left + body.width * (0.28 + i * 0.22);
        canvas.drawLine(Offset(x, body.top + w * 0.04), Offset(x - w * 0.06, body.bottom - w * 0.04), strokeOf(const Color(0x66FFFFFF), w * 0.035));
      }
      sparkle(canvas, body.topLeft.translate(w * 0.12, w * 0.08), w * 0.05);
    case 1: // Zitronendrops
      final o = Rect.fromCircle(center: c, radius: w * 0.32);
      canvas.drawOval(o, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFFFFDE7), Color(0xFFFFEB3B), Color(0xFFF9A825)]).createShader(o));
      canvas.drawOval(o, strokeOf(const Color(0xFF8D6E00), 2));
      final rng = math.Random(1);
      for (var i = 0; i < 14; i++) {
        final a = rng.nextDouble() * 2 * math.pi;
        final d = rng.nextDouble() * w * 0.26;
        canvas.drawRect(Rect.fromCenter(center: c + Offset(math.cos(a), math.sin(a)) * d, width: w * 0.025, height: w * 0.025), fillOf(const Color(0xCCFFFFFF)));
      }
      sparkle(canvas, c.translate(-w * 0.13, -w * 0.14), w * 0.06);
    case 10: // Minzwürfel
      final top = Path()
        ..moveTo(c.dx, c.dy - w * 0.34)
        ..lineTo(c.dx + w * 0.3, c.dy - w * 0.18)
        ..lineTo(c.dx, c.dy - w * 0.02)
        ..lineTo(c.dx - w * 0.3, c.dy - w * 0.18)
        ..close();
      final left = Path()
        ..moveTo(c.dx - w * 0.3, c.dy - w * 0.18)
        ..lineTo(c.dx, c.dy - w * 0.02)
        ..lineTo(c.dx, c.dy + w * 0.34)
        ..lineTo(c.dx - w * 0.3, c.dy + w * 0.18)
        ..close();
      final right = Path()
        ..moveTo(c.dx + w * 0.3, c.dy - w * 0.18)
        ..lineTo(c.dx, c.dy - w * 0.02)
        ..lineTo(c.dx, c.dy + w * 0.34)
        ..lineTo(c.dx + w * 0.3, c.dy + w * 0.18)
        ..close();
      shaded(canvas, top, const Color(0xFFE0F2F1), const Color(0xFF80CBC4), width: 1.6);
      shaded(canvas, left, const Color(0xFF80CBC4), const Color(0xFF00897B), width: 1.6);
      shaded(canvas, right, const Color(0xFF4DB6AC), const Color(0xFF00695C), width: 1.6);
      // Weiße Streifen auf der Oberseite
      canvas.drawLine(c.translate(-w * 0.15, -w * 0.26), c.translate(w * 0.15, -w * 0.1), strokeOf(const Color(0xCCFFFFFF), w * 0.04));
    case 2: // Blaubeerherz
      final heart = Path()
        ..moveTo(c.dx, c.dy + w * 0.32)
        ..cubicTo(c.dx - w * 0.5, c.dy, c.dx - w * 0.3, c.dy - w * 0.42, c.dx, c.dy - w * 0.16)
        ..cubicTo(c.dx + w * 0.3, c.dy - w * 0.42, c.dx + w * 0.5, c.dy, c.dx, c.dy + w * 0.32)
        ..close();
      shaded(canvas, heart, const Color(0xFF90CAF9), const Color(0xFF1A3C9C));
      canvas.drawCircle(c.translate(-w * 0.14, -w * 0.13), w * 0.05, fillOf(const Color(0x99FFFFFF)));
    case 11: // Orangenring
      final o = Rect.fromCircle(center: c, radius: w * 0.34);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(o)
        ..addOval(Rect.fromCircle(center: c, radius: w * 0.14));
      canvas.drawPath(ring, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFCC80), Color(0xFFF57C00)]).createShader(o));
      canvas.drawPath(ring, strokeOf(const Color(0xFF8A3B00), 2));
      final rng = math.Random(11);
      for (var i = 0; i < 16; i++) {
        final a = rng.nextDouble() * 2 * math.pi;
        final d = w * (0.18 + rng.nextDouble() * 0.13);
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, w * 0.012, fillOf(const Color(0xDDFFFFFF)));
      }
    case 3: // Gummistern
      final star = starPath(c, w * 0.4, inner: 0.5);
      shaded(canvas, star, const Color(0xFFE1BEE7), const Color(0xFF7B1FA2));
      canvas.drawPath(starPath(c.translate(-w * 0.02, -w * 0.03), w * 0.22, inner: 0.5), fillOf(const Color(0x44FFFFFF)));
    case 4: // Lakritzschnecke
      canvas.drawCircle(c, w * 0.36, fillOf(const Color(0xFF1B1B1B)));
      final spiral = Path();
      for (var i = 0; i <= 90; i++) {
        final a = i / 90 * 3.3 * 2 * math.pi;
        final rr = w * 0.04 + w * 0.3 * i / 90;
        final o = c + Offset(math.cos(a), math.sin(a)) * rr;
        i == 0 ? spiral.moveTo(o.dx, o.dy) : spiral.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(spiral, strokeOf(const Color(0xFF424242), w * 0.06));
      canvas.drawCircle(c, w * 0.08, fillOf(const Color(0xFFFF4081)));
      canvas.drawCircle(c, w * 0.36, strokeOf(const Color(0xFF000000), 2));
      sparkle(canvas, c.translate(-w * 0.2, -w * 0.2), w * 0.05);
    case 5: // Lutscher
      canvas.drawLine(c.translate(0, w * 0.1), c.translate(0, w * 0.46), strokeOf(const Color(0xFFF5F5F5), w * 0.06));
      final head = c.translate(0, -w * 0.08);
      final hr = w * 0.3;
      const swirl = [Color(0xFFFF5252), Color(0xFFFFEB3B), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFE040FB)];
      for (var k = 0; k < 5; k++) {
        final p = Path()..moveTo(head.dx, head.dy);
        for (var i = 0; i <= 30; i++) {
          final t = i / 30;
          final a = k * 2 * math.pi / 5 + t * 2.4;
          p.lineTo(head.dx + math.cos(a) * hr * t, head.dy + math.sin(a) * hr * t);
        }
        for (var i = 30; i >= 0; i--) {
          final t = i / 30;
          final a = (k + 1) * 2 * math.pi / 5 + t * 2.4;
          p.lineTo(head.dx + math.cos(a) * hr * t, head.dy + math.sin(a) * hr * t);
        }
        canvas.drawPath(p..close(), fillOf(swirl[k]));
      }
      canvas.drawCircle(head, hr, strokeOf(const Color(0xFF4A148C), 2));
      sparkle(canvas, head.translate(-hr * 0.45, -hr * 0.45), hr * 0.18);
    case 6: // Zuckerkugel, Joker
      glow(canvas, c, w * 0.5, const Color(0x88FFFFFF));
      final o = Rect.fromCircle(center: c, radius: w * 0.33);
      canvas.drawOval(
        o,
        Paint()
          ..shader = const SweepGradient(colors: [
            Color(0xFFFF80AB),
            Color(0xFFFFF59D),
            Color(0xFF80DEEA),
            Color(0xFFB388FF),
            Color(0xFFFF80AB),
          ]).createShader(o),
      );
      canvas.drawOval(o, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.35), colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)]).createShader(o));
      canvas.drawOval(o, strokeOf(const Color(0xFF4A148C), 2));
      caption(canvas, r, 'JOKER', Colors.white, size: 0.17, y: 0.5, shadow: const Color(0xFF4A148C));
    case 7: // Bonbonglas, Streusymbol
      glow(canvas, c, w * 0.5, const Color(0x88FFF59D));
      final jar = RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - w * 0.3, c.dy - w * 0.2, c.dx + w * 0.3, c.dy + w * 0.38), Radius.circular(w * 0.12));
      canvas.drawRRect(jar, fillOf(const Color(0x55E1F5FE)));
      canvas.save();
      canvas.clipRRect(jar);
      final rng = math.Random(7);
      const colors = [Color(0xFFFF5252), Color(0xFFFFEB3B), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFE040FB), Color(0xFFFF9800)];
      for (var i = 0; i < 22; i++) {
        final p = Offset(c.dx - w * 0.26 + rng.nextDouble() * w * 0.52, c.dy - w * 0.04 + rng.nextDouble() * w * 0.4);
        canvas.drawCircle(p, w * 0.055, fillOf(colors[i % colors.length]));
        canvas.drawCircle(p, w * 0.055, strokeOf(const Color(0x55000000), 1));
      }
      canvas.restore();
      canvas.drawRRect(jar, strokeOf(const Color(0xFFE1F5FE), 2));
      final lid = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -w * 0.26), width: w * 0.5, height: w * 0.12), Radius.circular(w * 0.04));
      shaded(canvas, Path()..addRRect(lid), const Color(0xFFFF80AB), const Color(0xFFC2185B), width: 1.6);
      sparkle(canvas, c.translate(-w * 0.2, -w * 0.08), w * 0.06);
      caption(canvas, r, 'SCATTER', const Color(0xFFFFF59D), size: 0.15, y: 0.95);
    default:
      canvas.drawCircle(c, w * 0.3, fillOf(Colors.pink));
  }
}
