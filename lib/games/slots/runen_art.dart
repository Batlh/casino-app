import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art_kit.dart';

/// Runenpfad: Nordlicht über verschneiten Bergen.
/// Niedrig: Runensteine 0 (blau), 1 (grün), 10 (rot), 11 (violett), dazu 2 Fackel.
/// Hoch: 3 Schild, 4 Trinkhorn, 5 Hammer. 6 Nordlicht (Joker), 7 Kompass (Streusymbol).

const _ink = Color(0xFF101820);

void paintRunenBackdrop(Canvas canvas, Rect rect, double time) {
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF040B1E), Color(0xFF0B2240), Color(0xFF14304F)],
      ).createShader(rect),
  );
  // Sterne
  for (var i = 0; i < 40; i++) {
    final p = Offset(rect.left + rect.width * ((i * 0.618) % 1), rect.top + rect.height * 0.6 * ((i * 0.377) % 1));
    canvas.drawCircle(p, 0.8 + (i % 3) * 0.4, fillOf(const Color(0x99FFFFFF)));
  }
  // Nordlicht: drei wehende Bänder, jedes schwingt ganze Male je Durchlauf
  const bands = [Color(0x3366FFB2), Color(0x2840C4FF), Color(0x22B388FF)];
  for (var b = 0; b < bands.length; b++) {
    final path = Path();
    final base = rect.top + rect.height * (0.18 + b * 0.09);
    for (var i = 0; i <= 40; i++) {
      final x = rect.left + rect.width * i / 40;
      final y = base + math.sin(i / 40 * 2 * math.pi * 1.5 + (time * (b + 1)) * 2 * math.pi + b) * rect.height * 0.05;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    for (var i = 40; i >= 0; i--) {
      final x = rect.left + rect.width * i / 40;
      final y = base + rect.height * 0.12 + math.sin(i / 40 * 2 * math.pi * 1.5 + (time * (b + 1)) * 2 * math.pi + b + 0.6) * rect.height * 0.04;
      path.lineTo(x, y);
    }
    canvas.drawPath(path..close(), Paint()..color = bands[b]..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  // Berge mit Schnee
  final hills = Path()..moveTo(rect.left, rect.bottom);
  const peaks = [0.0, 0.72, 0.12, 0.58, 0.28, 0.66, 0.45, 0.55, 0.62, 0.7, 0.8, 0.6, 1.0, 0.74];
  for (var i = 0; i < peaks.length; i += 2) {
    hills.lineTo(rect.left + rect.width * peaks[i], rect.top + rect.height * peaks[i + 1]);
  }
  hills
    ..lineTo(rect.right, rect.bottom)
    ..close();
  canvas.drawPath(hills, fillOf(const Color(0xFF1C3350)));
  canvas.drawPath(hills, strokeOf(const Color(0x66E3F2FD), 2));
}

void _runestone(Canvas canvas, Rect r, Color light, Color dark, int glyph) {
  final c = r.center;
  final w = r.width;
  final stone = Path()
    ..moveTo(c.dx - w * 0.26, c.dy + w * 0.36)
    ..quadraticBezierTo(c.dx - w * 0.34, c.dy - w * 0.1, c.dx - w * 0.16, c.dy - w * 0.36)
    ..quadraticBezierTo(c.dx + w * 0.08, c.dy - w * 0.44, c.dx + w * 0.26, c.dy - w * 0.28)
    ..quadraticBezierTo(c.dx + w * 0.36, c.dy + w * 0.04, c.dx + w * 0.28, c.dy + w * 0.36)
    ..close();
  shaded(canvas, stone, light, dark, outline: _ink);
  final glow = strokeOf(const Color(0xFFE0F7FA), w * 0.045);
  final top = c.translate(0, -w * 0.22);
  final bottom = c.translate(0, w * 0.24);
  switch (glyph) {
    case 0: // Stab mit zwei Ästen nach rechts oben
      canvas.drawLine(top.translate(-w * 0.06, 0), bottom.translate(-w * 0.06, 0), glow);
      canvas.drawLine(top.translate(-w * 0.06, w * 0.06), top.translate(w * 0.12, -w * 0.04), glow);
      canvas.drawLine(top.translate(-w * 0.06, w * 0.18), top.translate(w * 0.12, w * 0.08), glow);
    case 1: // Raute auf Stab
      canvas.drawLine(top, bottom, glow);
      canvas.drawPath(polygon(c.translate(0, -w * 0.02), w * 0.13, 4), glow);
    case 2: // Pfeil nach oben
      canvas.drawLine(top, bottom, glow);
      canvas.drawLine(top, top.translate(-w * 0.13, w * 0.13), glow);
      canvas.drawLine(top, top.translate(w * 0.13, w * 0.13), glow);
    default: // Zwei Stäbe mit Kreuz
      canvas.drawLine(top.translate(-w * 0.1, 0), bottom.translate(-w * 0.1, 0), glow);
      canvas.drawLine(top.translate(w * 0.1, 0), bottom.translate(w * 0.1, 0), glow);
      canvas.drawLine(top.translate(-w * 0.1, w * 0.06), bottom.translate(w * 0.1, -w * 0.12), glow);
      canvas.drawLine(top.translate(w * 0.1, w * 0.06), bottom.translate(-w * 0.1, -w * 0.12), glow);
  }
}

void paintRunenSymbol(Canvas canvas, Rect rect, int symbol) {
  final r = squareIn(rect);
  final c = r.center;
  final w = r.width;
  switch (symbol) {
    case 0:
      _runestone(canvas, r, const Color(0xFF90A4AE), const Color(0xFF37474F), 0);
      canvas.drawCircle(c.translate(w * 0.18, w * 0.2), w * 0.04, fillOf(const Color(0xFF4FC3F7)));
    case 1:
      _runestone(canvas, r, const Color(0xFF8FA98F), const Color(0xFF2E4A32), 1);
      canvas.drawCircle(c.translate(w * 0.18, w * 0.2), w * 0.04, fillOf(const Color(0xFF69F0AE)));
    case 10:
      _runestone(canvas, r, const Color(0xFFB0907F), const Color(0xFF4E2F25), 2);
      canvas.drawCircle(c.translate(w * 0.18, w * 0.2), w * 0.04, fillOf(const Color(0xFFFF8A65)));
    case 11:
      _runestone(canvas, r, const Color(0xFFA594B8), const Color(0xFF3B2C52), 3);
      canvas.drawCircle(c.translate(w * 0.18, w * 0.2), w * 0.04, fillOf(const Color(0xFFE040FB)));
    case 2: // Fackel
      glow(canvas, c.translate(0, -w * 0.18), w * 0.28, const Color(0x88FF9800));
      canvas.drawLine(c.translate(0, -w * 0.06), c.translate(0, w * 0.4), strokeOf(const Color(0xFF3E2723), w * 0.11));
      canvas.drawLine(c.translate(0, -w * 0.06), c.translate(0, w * 0.4), strokeOf(const Color(0xFF8D6E63), w * 0.06));
      for (final y in [0.0, 0.06]) {
        canvas.drawLine(c.translate(-w * 0.07, y * w - w * 0.02), c.translate(w * 0.07, y * w - w * 0.02), strokeOf(const Color(0xFF5D4037), w * 0.03));
      }
      final flame = Path()
        ..moveTo(c.dx, c.dy - w * 0.42)
        ..quadraticBezierTo(c.dx + w * 0.2, c.dy - w * 0.2, c.dx + w * 0.1, c.dy - w * 0.05)
        ..lineTo(c.dx - w * 0.1, c.dy - w * 0.05)
        ..quadraticBezierTo(c.dx - w * 0.2, c.dy - w * 0.24, c.dx, c.dy - w * 0.42)
        ..close();
      shaded(canvas, flame, const Color(0xFFFFF59D), const Color(0xFFE65100), outline: const Color(0xAABF360C), width: 1.2);
    case 3: // Rundschild
      final o = Rect.fromCircle(center: c, radius: w * 0.38);
      canvas.drawOval(o, Paint()..shader = const SweepGradient(colors: [Color(0xFF1565C0), Color(0xFFECEFF1), Color(0xFF1565C0), Color(0xFFECEFF1), Color(0xFF1565C0)]).createShader(o));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * w * 0.38, strokeOf(const Color(0x55000000), 1));
      }
      canvas.drawOval(o, strokeOf(const Color(0xFF8D6E63), w * 0.05));
      canvas.drawOval(o, strokeOf(_ink, 1.6));
      final boss = Rect.fromCircle(center: c, radius: w * 0.1);
      canvas.drawOval(boss, Paint()..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFFFFFFF), Color(0xFF90A4AE)]).createShader(boss));
      canvas.drawOval(boss, strokeOf(_ink, 1.5));
    case 4: // Trinkhorn
      final horn = Path()
        ..moveTo(c.dx - w * 0.36, c.dy - w * 0.2)
        ..quadraticBezierTo(c.dx - w * 0.2, c.dy + w * 0.36, c.dx + w * 0.34, c.dy + w * 0.2)
        ..lineTo(c.dx + w * 0.36, c.dy + w * 0.12)
        ..quadraticBezierTo(c.dx - w * 0.06, c.dy + w * 0.12, c.dx - w * 0.16, c.dy - w * 0.3)
        ..close();
      shaded(canvas, horn, const Color(0xFFFFF3E0), const Color(0xFFA1887F));
      for (final t in [0.25, 0.55]) {
        final a = Offset.lerp(c.translate(-w * 0.3, -w * 0.25), c.translate(-w * 0.1, -w * 0.28), 0)!;
        canvas.drawLine(a.translate(w * t * 0.5, w * t * 0.9), a.translate(w * (t * 0.5 + 0.2), w * t * 0.75), strokeOf(const Color(0xFFFFC107), w * 0.04));
      }
      canvas.drawOval(Rect.fromCenter(center: c.translate(-w * 0.26, -w * 0.25), width: w * 0.22, height: w * 0.1), fillOf(const Color(0xFFFFB300)));
      canvas.drawOval(Rect.fromCenter(center: c.translate(-w * 0.26, -w * 0.25), width: w * 0.22, height: w * 0.1), strokeOf(_ink, 1.4));
      canvas.drawCircle(c.translate(w * 0.36, w * 0.16), w * 0.04, fillOf(const Color(0xFFFFC107)));
    case 5: // Hammer
      glow(canvas, c, w * 0.5, const Color(0x6640C4FF));
      canvas.drawLine(c.translate(0, -w * 0.02), c.translate(0, w * 0.4), strokeOf(const Color(0xFF3E2723), w * 0.1));
      canvas.drawLine(c.translate(0, -w * 0.02), c.translate(0, w * 0.4), strokeOf(const Color(0xFF8D6E63), w * 0.055));
      final head = RRect.fromRectAndRadius(Rect.fromCenter(center: c.translate(0, -w * 0.16), width: w * 0.62, height: w * 0.26), Radius.circular(w * 0.05));
      shaded(canvas, Path()..addRRect(head), const Color(0xFFECEFF1), const Color(0xFF546E7A));
      canvas.drawPath(polygon(c.translate(0, -w * 0.16), w * 0.07, 4), strokeOf(const Color(0xFF40C4FF), w * 0.025));
      canvas.drawCircle(c.translate(0, w * 0.43), w * 0.04, fillOf(const Color(0xFFFFC107)));
      sparkle(canvas, c.translate(-w * 0.22, -w * 0.24), w * 0.05);
    case 6: // Nordlicht, Joker
      final o = Rect.fromCircle(center: c, radius: w * 0.36);
      canvas.drawOval(o, fillOf(const Color(0xFF071A33)));
      canvas.save();
      canvas.clipPath(Path()..addOval(o));
      const cols = [Color(0xAA69F0AE), Color(0x9940C4FF), Color(0x88B388FF)];
      for (var b = 0; b < 3; b++) {
        final p = Path();
        for (var i = 0; i <= 20; i++) {
          final x = o.left + o.width * i / 20;
          final y = o.top + o.height * (0.3 + b * 0.12) + math.sin(i / 20 * math.pi * 2 + b) * w * 0.06;
          i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
        }
        canvas.drawPath(p, strokeOf(cols[b], w * 0.1));
      }
      canvas.restore();
      canvas.drawOval(o, strokeOf(const Color(0xFFB2EBF2), 2));
      caption(canvas, r, 'JOKER', Colors.white, size: 0.17, y: 0.72, shadow: _ink);
    case 7: // Kompass, Streusymbol
      glow(canvas, c, w * 0.5, const Color(0x88FFF59D));
      final o = Rect.fromCircle(center: c.translate(0, -w * 0.03), radius: w * 0.34);
      canvas.drawOval(o, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF8E1), Color(0xFFD7B98E)]).createShader(o));
      canvas.drawOval(o, strokeOf(const Color(0xFFB8860B), w * 0.05));
      final n = o.center;
      canvas.drawPath(
        Path()
          ..moveTo(n.dx, n.dy - w * 0.26)
          ..lineTo(n.dx + w * 0.06, n.dy)
          ..lineTo(n.dx - w * 0.06, n.dy)
          ..close(),
        fillOf(const Color(0xFFC62828)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(n.dx, n.dy + w * 0.26)
          ..lineTo(n.dx + w * 0.06, n.dy)
          ..lineTo(n.dx - w * 0.06, n.dy)
          ..close(),
        fillOf(const Color(0xFF37474F)),
      );
      canvas.drawCircle(n, w * 0.03, fillOf(const Color(0xFFFFC107)));
      caption(canvas, r, 'SCATTER', const Color(0xFFFFF59D), size: 0.15, y: 0.95);
    default:
      canvas.drawCircle(c, w * 0.3, fillOf(Colors.blueGrey));
  }
}
