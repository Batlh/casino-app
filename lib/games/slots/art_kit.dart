import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gemeinsame Zeichenhilfen für die neuen Slots.

Paint fillOf(Color c) => Paint()..color = c;

Paint strokeOf(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..color = c;

/// Quadrat in der Mitte des Felds.
Rect squareIn(Rect rect) => Rect.fromCenter(center: rect.center, width: rect.shortestSide, height: rect.shortestSide);

/// Weicher Schein hinter einem Symbol.
void glow(Canvas canvas, Offset c, double r, Color color) {
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
  );
}

/// Pfad als Fläche mit Verlauf von hell (oben links) nach dunkel, dazu Kontur.
void shaded(Canvas canvas, Path path, Color light, Color dark, {Color outline = const Color(0xFF241410), double width = 2}) {
  final b = path.getBounds();
  canvas.drawPath(
    path,
    Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, dark]).createShader(b),
  );
  canvas.drawPath(path, strokeOf(outline, width));
}

/// Regelmäßiges Vieleck.
Path polygon(Offset c, double r, int n, {double rotation = -math.pi / 2, double squash = 1}) {
  final p = Path();
  for (var i = 0; i < n; i++) {
    final a = rotation + i * 2 * math.pi / n;
    final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a) * squash);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Stern mit n Zacken.
Path starPath(Offset c, double r, {int n = 5, double inner = 0.45}) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / n;
    final rr = i.isEven ? r : r * inner;
    final o = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Glanzpunkt.
void sparkle(Canvas canvas, Offset c, double r, [Color color = Colors.white]) {
  canvas.drawPath(starPath(c, r, n: 4, inner: 0.22), fillOf(color));
}

/// Kurzer Schriftzug, mittig.
void caption(Canvas canvas, Rect rect, String text, Color color, {double size = 0.2, double y = 0.78, Color shadow = Colors.black}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: rect.height * size,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        shadows: [Shadow(blurRadius: 3, color: shadow)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: rect.width);
  tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.top + rect.height * y - tp.height / 2));
}

/// Geschliffener Edelstein: Umriss, Tafel in der Mitte und Facettenlinien.
void gem(Canvas canvas, Rect rect, Color light, Color dark, {int sides = 8, double squash = 1, double rotation = -math.pi / 2}) {
  final c = rect.center;
  final r = rect.width * 0.42;
  glow(canvas, c, r * 1.25, light.withValues(alpha: 0.45));
  final outer = polygon(c, r, sides, rotation: rotation, squash: squash);
  shaded(canvas, outer, light, dark);
  final inner = polygon(c, r * 0.55, sides, rotation: rotation, squash: squash);
  canvas.drawPath(inner, fillOf(Color.lerp(light, Colors.white, 0.35)!.withValues(alpha: 0.8)));
  final facet = strokeOf(Colors.white.withValues(alpha: 0.55), 1.2);
  for (var i = 0; i < sides; i++) {
    final a = rotation + i * 2 * math.pi / sides;
    canvas.drawLine(
      Offset(c.dx + r * 0.55 * math.cos(a), c.dy + r * 0.55 * math.sin(a) * squash),
      Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a) * squash),
      facet,
    );
  }
  canvas.drawPath(inner, strokeOf(Colors.white.withValues(alpha: 0.6), 1.2));
  sparkle(canvas, c + Offset(-r * 0.32, -r * 0.3 * squash), r * 0.22);
}

/// Goldmünze mit Rand und Prägung.
void goldCoin(Canvas canvas, Rect rect, {String mark = '', Color light = const Color(0xFFFFE27A), Color dark = const Color(0xFFB8860B)}) {
  final c = rect.center;
  final r = rect.width * 0.42;
  glow(canvas, c, r * 1.3, const Color(0x88FFD54F));
  canvas.drawCircle(
    c,
    r,
    Paint()..shader = RadialGradient(center: const Alignment(-0.3, -0.4), colors: [light, dark]).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  canvas.drawCircle(c, r, strokeOf(const Color(0xFF7A5200), 2.2));
  canvas.drawCircle(c, r * 0.78, strokeOf(const Color(0xAA7A5200), 1.5));
  if (mark.isNotEmpty) {
    caption(canvas, Rect.fromCircle(center: c, radius: r), mark, const Color(0xFF7A5200), size: 0.5, y: 0.5, shadow: const Color(0x55FFFFFF));
  }
  sparkle(canvas, c + Offset(-r * 0.45, -r * 0.45), r * 0.2);
}
