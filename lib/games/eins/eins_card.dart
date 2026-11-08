import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'eins_engine.dart';

/// Farben im Ton der Siebziger, bewusst nicht die bekannten Grundfarben.
const Map<EinsColor, Color> einsColors = {
  EinsColor.red: Color(0xFFD8402B),
  EinsColor.yellow: Color(0xFFF2B12E),
  EinsColor.green: Color(0xFF2E9C6A),
  EinsColor.blue: Color(0xFF2F7FC1),
};
const Color einsWildColor = Color(0xFF2A160E);

/// Zeichnet eine Karte in das Rechteck. card null zeigt den Rücken.
void paintEinsCard(Canvas canvas, Rect rect, EinsCard? card) {
  final w = rect.width;
  final radius = Radius.circular(w * 0.1);
  final outer = RRect.fromRectAndRadius(rect, radius);
  canvas.drawRRect(outer, Paint()..color = const Color(0xFFFFF8E7));
  final inner = RRect.fromRectAndRadius(rect.deflate(w * 0.05), Radius.circular(w * 0.07));
  canvas.save();
  canvas.clipRRect(inner);

  if (card == null) {
    _back(canvas, inner.outerRect);
    canvas.restore();
    return;
  }

  final base = card.color == null ? einsWildColor : einsColors[card.color]!;
  canvas.drawRect(inner.outerRect, Paint()..color = base);
  // Regenbogenbögen unten rechts, das Markenzeichen dieser Karten
  final arcCenter = inner.outerRect.bottomRight;
  for (var i = 0; i < 3; i++) {
    canvas.drawCircle(
      arcCenter,
      w * (0.95 - i * 0.18),
      Paint()..color = Colors.white.withValues(alpha: 0.10 + i * 0.04),
    );
  }
  canvas.restore();

  final center = rect.center;
  final size = w * 0.5;
  switch (card.kind) {
    case EinsKind.number:
      _text(canvas, '${card.number}', center, w * 0.62, underline: card.number == 6 || card.number == 9);
    case EinsKind.drawTwo:
      _text(canvas, '+2', center, w * 0.46);
    case EinsKind.skip:
      _skip(canvas, center, size * 0.5);
    case EinsKind.reverse:
      _reverse(canvas, center, size * 0.5);
    case EinsKind.wild:
      _wheel(canvas, center, size * 0.55);
    case EinsKind.wildDrawFour:
      _wheel(canvas, center, size * 0.55);
      _text(canvas, '+4', center, w * 0.36);
  }
  // Ecke oben links
  final corner = rect.topLeft + Offset(w * 0.17, w * 0.2);
  final small = w * 0.2;
  switch (card.kind) {
    case EinsKind.number:
      _text(canvas, '${card.number}', corner, small * 1.2, shadow: false);
    case EinsKind.drawTwo:
      _text(canvas, '+2', corner, small, shadow: false);
    case EinsKind.wildDrawFour:
      _text(canvas, '+4', corner, small, shadow: false);
    case EinsKind.skip:
      _skip(canvas, corner, small * 0.42, stroke: 0.2);
    case EinsKind.reverse:
      _reverse(canvas, corner, small * 0.45);
    case EinsKind.wild:
      _wheel(canvas, corner, small * 0.45);
  }
}

void _text(
  Canvas c,
  String text,
  Offset center,
  double fontSize, {
  bool shadow = true,
  bool underline = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: displayFont,
        fontSize: fontSize,
        height: 1,
        color: Colors.white,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: Colors.white,
        shadows: shadow
            ? [Shadow(offset: Offset(fontSize * 0.05, fontSize * 0.05), color: const Color(0x99000000))]
            : null,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _skip(Canvas c, Offset o, double r, {double stroke = 0.28}) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * stroke
    ..strokeCap = StrokeCap.round
    ..color = Colors.white;
  c.drawCircle(o, r, p);
  final d = r * 0.7;
  c.drawLine(o + Offset(-d, d), o + Offset(d, -d), p);
}

void _reverse(Canvas c, Offset o, double r) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = r * 0.24
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Colors.white;
  void arrow(double sign) {
    final start = o + Offset(-r * 0.9 * sign, r * 0.25 * sign);
    final end = o + Offset(r * 0.9 * sign, -r * 0.25 * sign);
    c.drawLine(start, end, p);
    final back = Offset(-sign * r * 0.45, 0);
    c.drawLine(end, end + back + Offset(0, -sign * r * 0.35), p);
    c.drawLine(end, end + back + Offset(0, sign * r * 0.35), p);
  }

  c.save();
  c.translate(0, -r * 0.35);
  arrow(1);
  c.restore();
  c.save();
  c.translate(0, r * 0.35);
  arrow(-1);
  c.restore();
}

/// Vierfarbiges Rad für Farbwahl und Plus-Vier.
void _wheel(Canvas c, Offset o, double r) {
  final rect = Rect.fromCircle(center: o, radius: r);
  for (var i = 0; i < 4; i++) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy)
        ..arcTo(rect, -math.pi / 2 + i * math.pi / 2, math.pi / 2, false)
        ..close(),
      Paint()..color = einsColors[EinsColor.values[i]]!,
    );
  }
  c.drawCircle(
    o,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..color = Colors.white,
  );
}

void _back(Canvas c, Rect r) {
  c.drawRect(r, Paint()..color = einsWildColor);
  final w = r.width;
  final stripe = w * 0.16;
  c.save();
  c.translate(r.center.dx, r.center.dy);
  c.rotate(-0.5);
  for (var i = 0; i < 4; i++) {
    c.drawRect(
      Rect.fromLTWH(-w, (i - 2) * stripe, w * 2, stripe),
      Paint()..color = einsColors[EinsColor.values[i]]!,
    );
  }
  c.restore();
  _text(c, 'Eins!', r.center, w * 0.3);
}

class EinsCardView extends StatelessWidget {
  const EinsCardView({super.key, required this.width, this.card, this.highlighted = false});

  final double width;
  final EinsCard? card;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final height = width / cardAspect;
    return Semantics(
      label: card?.spokenName ?? 'Verdeckte Karte',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.1),
          border: highlighted
              ? Border.all(color: const Color(0xFFFFC95C), width: 3)
              : null,
          boxShadow: const [
            BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x66000000)),
          ],
        ),
        child: CustomPaint(painter: _EinsPainter(card)),
      ),
    );
  }
}

class _EinsPainter extends CustomPainter {
  _EinsPainter(this.card);
  final EinsCard? card;

  @override
  void paint(Canvas canvas, Size size) => paintEinsCard(canvas, Offset.zero & size, card);

  @override
  bool shouldRepaint(_EinsPainter old) => old.card != card;
}

/// Farbwahl für Farbwahl- und Plus-Vier-Karten.
Future<EinsColor?> showColorPicker(BuildContext context) {
  return showModalBottomSheet<EinsColor>(
    context: context,
    showDragHandle: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Farbe wählen', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final c in EinsColor.values)
                  Semantics(
                    button: true,
                    label: colorName(c),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(c),
                      child: Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: einsColors[c],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFF8E7), width: 3),
                        ),
                        child: Text(
                          colorName(c),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
