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
  EinsColor.teal: Color(0xFF1FB5A8),
  EinsColor.orange: Color(0xFFF07A1A),
  EinsColor.pink: Color(0xFFE0479E),
  EinsColor.purple: Color(0xFF7B4FC9),
};
const Color einsWildColor = Color(0xFF2A160E);
const Color _cream = Color(0xFFFFF8E7);
const Color _night = Color(0xFF17101F);
const Color _gold = Color(0xFFFFC95C);

/// Zeichnet eine Kartenseite. face null zeigt den Rücken.
/// dark: Seite der dunklen Kehrseite, mit dunklem Rand.
void paintEinsCard(Canvas canvas, Rect rect, EinsFace? face, {bool dark = false}) {
  final w = rect.width;
  final radius = Radius.circular(w * 0.1);
  final outer = RRect.fromRectAndRadius(rect, radius);
  canvas.drawRRect(outer, Paint()..color = dark ? _night : _cream);
  final inner = RRect.fromRectAndRadius(rect.deflate(w * 0.05), Radius.circular(w * 0.07));
  canvas.save();
  canvas.clipRRect(inner);

  if (face == null) {
    _back(canvas, inner.outerRect);
    canvas.restore();
    return;
  }

  final base = face.color == null ? (dark ? const Color(0xFF0E0A14) : einsWildColor) : einsColors[face.color]!;
  canvas.drawRect(inner.outerRect, Paint()..color = base);
  // Regenbogenbögen unten rechts, das Markenzeichen dieser Karten
  final arcCenter = inner.outerRect.bottomRight;
  for (var i = 0; i < 3; i++) {
    canvas.drawCircle(
      arcCenter,
      w * (0.95 - i * 0.18),
      Paint()..color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.10 + i * 0.04),
    );
  }
  if (face.flexColor != null) {
    // Kraftkarten: zweite Farbe als Ecke unten rechts
    final r = inner.outerRect;
    final tri = Path()
      ..moveTo(r.right, r.bottom - r.height * 0.36)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - r.width * 0.62, r.bottom)
      ..close();
    canvas.drawPath(tri, Paint()..color = einsColors[face.flexColor]!);
    canvas.drawLine(
      Offset(r.right, r.bottom - r.height * 0.36),
      Offset(r.right - r.width * 0.62, r.bottom),
      _stroke(w * 0.025)..color = _cream,
    );
  }
  if (dark) {
    // Sterne für die dunkle Seite
    final star = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final r = inner.outerRect;
    for (final p in const [Offset(0.75, 0.12), Offset(0.2, 0.8), Offset(0.85, 0.55), Offset(0.4, 0.92)]) {
      canvas.drawCircle(Offset(r.left + r.width * p.dx, r.top + r.height * p.dy), w * 0.018, star);
    }
  }
  canvas.restore();

  final colors = dark ? darkColors : lightColors;
  _symbol(canvas, face, rect.center, w, big: true, colors: colors);
  // Ecke oben links
  final corner = rect.topLeft + Offset(w * 0.17, w * 0.2);
  _symbol(canvas, face, corner, w * 0.34, big: false, colors: colors);

  // Abzeichen unten
  final badgeAt = rect.bottomLeft + Offset(w * 0.2, -w * 0.2);
  if (face.spin) _spinBadge(canvas, badgeAt, w * 0.11);
  if (face.flipMark) {
    // Kraftwechsel: weißer Kreispfeil statt Blitz
    canvas.drawCircle(badgeAt, w * 0.14, Paint()..color = const Color(0xFF2A160E));
    canvas.drawCircle(badgeAt, w * 0.14, _stroke(w * 0.02));
    _flip(canvas, badgeAt, w * 0.075);
  }
  if (face.hasFlex) _boltBadge(canvas, badgeAt, w * 0.11);
}

void _symbol(Canvas c, EinsFace f, Offset o, double w, {required bool big, required List<EinsColor> colors}) {
  final shadow = big;
  const s = 1.0;
  void txt(String t, double size, {Offset shift = Offset.zero}) =>
      _text(c, t, o + shift, w * size * (big ? 1 : 1.25), shadow: shadow);
  // In der Ecke nur das Wichtigste: Farbrad ohne Aufdruck nur bei reiner Farbwahl
  void wheel(Offset at, double r, List<EinsColor> cs) {
    if (big || f.kind == EinsKind.wild || f.kind == EinsKind.wildAllFlip) _wheel(c, at, r, cs);
  }

  // Kleiner goldener Hinweis auf die Kraftseite, nur auf der großen Ansicht
  void flexNote(String t) {
    if (big) _text(c, t, o + Offset(0, w * 0.4), w * 0.11, shadow: false, color: _gold);
  }

  switch (f.kind) {
    case EinsKind.number:
      _text(c, '${f.number}', o, w * (big ? (f.number >= 10 ? 0.5 : 0.62) : 0.7),
          shadow: shadow, underline: f.number == 6 || f.number == 9);
    case EinsKind.drawOne:
      txt('+1', 0.5);
    case EinsKind.drawTwo:
      txt('+2', 0.46);
    case EinsKind.drawFour:
      txt('+4', 0.46);
    case EinsKind.drawFive:
      txt('+5', 0.46);
    case EinsKind.skip:
      _skip(c, o, w * 0.25 * s);
    case EinsKind.skipEveryone:
      _skip(c, o, w * 0.25 * s);
      _skip(c, o, w * 0.36 * s, stroke: 0.12);
    case EinsKind.reverse:
      _reverse(c, o, w * 0.25 * s);
    case EinsKind.flip:
      _flip(c, o, w * 0.24 * s);
    case EinsKind.discardAll:
      _discard(c, o, w * 0.26 * s);
    case EinsKind.hitTwo:
      txt('2×', 0.44);
    case EinsKind.flexSkip:
      _skip(c, o, w * 0.25 * s);
      flexNote('Alle aus');
    case EinsKind.flexReverse:
      _reverse(c, o, w * 0.25 * s);
      flexNote('+ Aussetzen');
    case EinsKind.flexDrawTwo:
      txt('+2', 0.46);
      flexNote('Alle +1');
    case EinsKind.wild:
      wheel(o, w * 0.28 * s, colors);
    case EinsKind.flexWildTargetDraw:
      wheel(o, w * 0.28 * s, colors);
      flexNote('Ziel +2');
    case EinsKind.flexWildAllDraw:
      wheel(o, w * 0.28 * s, colors);
      flexNote('Alle +2');
    case EinsKind.wildDrawTwo:
      wheel(o, w * 0.28 * s, colors);
      txt('+2', 0.36);
    case EinsKind.wildDrawFour:
      wheel(o, w * 0.28 * s, colors);
      txt('+4', 0.36);
    case EinsKind.flexWildDrawFour:
      wheel(o, w * 0.28 * s, colors);
      txt('+4', 0.36);
      flexNote('Ziel +4');
    case EinsKind.wildDrawSix:
      wheel(o, w * 0.28 * s, colors);
      txt('+6', 0.36);
    case EinsKind.wildDrawTen:
      wheel(o, w * 0.28 * s, colors);
      txt('+10', 0.3);
    case EinsKind.wildReverseDrawFour:
    case EinsKind.wildReverseDrawEight:
      wheel(o, w * 0.28 * s, colors);
      txt(f.kind == EinsKind.wildReverseDrawFour ? '+4' : '+8', 0.3, shift: Offset(0, w * 0.1 * s));
      _reverse(c, o - Offset(0, w * 0.1 * s), w * 0.1 * s);
    case EinsKind.wildDrawColor:
      wheel(o, w * 0.28 * s, colors);
      txt('+?', 0.36);
    case EinsKind.wildColorRoulette:
      wheel(o, w * 0.28 * s, colors);
      txt('?', 0.4);
    case EinsKind.wildDiscardAll:
      wheel(o, w * 0.28 * s, colors);
      if (big) _discard(c, o, w * 0.16 * s);
    case EinsKind.wildFinalAttack:
      wheel(o, w * 0.28 * s, colors);
      _flame(c, o, w * 0.15 * s);
    case EinsKind.wildSuddenDeath:
      wheel(o, w * 0.28 * s, colors);
      txt('24', 0.3);
    case EinsKind.extremeHit:
      wheel(o, w * 0.28 * s, colors);
      if (big) _target(c, o, w * 0.16 * s);
      txt('2×', big ? 0.2 : 0.36, shift: big ? Offset(0, w * 0.4) : Offset.zero);
    case EinsKind.wildAllFlip:
      wheel(o, w * 0.28 * s, colors);
      _bolt(c, o, w * 0.16 * s, Colors.white);
  }
}

/// Zielscheibe für den Extrem-Treffer.
void _target(Canvas c, Offset o, double r) {
  c.drawCircle(o, r, Paint()..color = Colors.white);
  c.drawCircle(o, r * 0.66, Paint()..color = einsColors[EinsColor.red]!);
  c.drawCircle(o, r * 0.33, Paint()..color = Colors.white);
}

void _text(
  Canvas c,
  String text,
  Offset center,
  double fontSize, {
  bool shadow = true,
  bool underline = false,
  Color color = Colors.white,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: displayFont,
        fontSize: fontSize,
        height: 1,
        color: color,
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

Paint _stroke(double width) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = Colors.white;

void _skip(Canvas c, Offset o, double r, {double stroke = 0.28}) {
  final p = _stroke(r * stroke);
  c.drawCircle(o, r, p);
  if (stroke > 0.2) {
    final d = r * 0.7;
    c.drawLine(o + Offset(-d, d), o + Offset(d, -d), p);
  }
}

void _reverse(Canvas c, Offset o, double r) {
  final p = _stroke(r * 0.24);
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

/// Kreisender Pfeil für Wenden.
void _flip(Canvas c, Offset o, double r) {
  final p = _stroke(r * 0.22);
  final rect = Rect.fromCircle(center: o, radius: r);
  for (final start in [-math.pi * 0.9, math.pi * 0.1]) {
    c.drawArc(rect, start, math.pi * 0.7, false, p);
    final a = start + math.pi * 0.7;
    final tip = o + Offset(math.cos(a), math.sin(a)) * r;
    final dir = Offset(-math.sin(a), math.cos(a));
    final side = Offset(math.cos(a), math.sin(a));
    c.drawLine(tip, tip - dir * r * 0.45 + side * r * 0.3, p);
    c.drawLine(tip, tip - dir * r * 0.45 - side * r * 0.3, p);
  }
}

/// Drei Karten mit Pfeil nach unten: alle abwerfen.
void _discard(Canvas c, Offset o, double r) {
  final fill = Paint()..color = Colors.white.withValues(alpha: 0.25);
  final p = _stroke(r * 0.12);
  for (var i = -1; i <= 1; i++) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: o + Offset(i * r * 0.45, -r * 0.2 + i.abs() * r * 0.1), width: r * 0.8, height: r * 1.15),
      Radius.circular(r * 0.12),
    );
    c.drawRRect(rr, fill);
    c.drawRRect(rr, p);
  }
  final a = o + Offset(0, r * 0.55);
  final b = o + Offset(0, r * 1.05);
  c.drawLine(a, b, p);
  c.drawLine(b, b + Offset(-r * 0.25, -r * 0.25), p);
  c.drawLine(b, b + Offset(r * 0.25, -r * 0.25), p);
}

void _flame(Canvas c, Offset o, double r) {
  final path = Path()
    ..moveTo(o.dx, o.dy - r * 1.2)
    ..cubicTo(o.dx + r * 1.1, o.dy - r * 0.2, o.dx + r * 0.9, o.dy + r, o.dx, o.dy + r)
    ..cubicTo(o.dx - r * 0.9, o.dy + r, o.dx - r * 1.0, o.dy, o.dx - r * 0.2, o.dy - r * 0.5)
    ..cubicTo(o.dx - r * 0.1, o.dy - r * 0.1, o.dx + r * 0.1, o.dy - r * 0.6, o.dx, o.dy - r * 1.2)
    ..close();
  c.drawPath(path, Paint()..color = const Color(0xFFFFE08A));
  c.drawPath(path, _stroke(r * 0.15)..color = const Color(0xFFD8402B));
}

void _bolt(Canvas c, Offset o, double r, Color color) {
  final path = Path()
    ..moveTo(o.dx + r * 0.25, o.dy - r)
    ..lineTo(o.dx - r * 0.55, o.dy + r * 0.15)
    ..lineTo(o.dx - r * 0.05, o.dy + r * 0.15)
    ..lineTo(o.dx - r * 0.25, o.dy + r)
    ..lineTo(o.dx + r * 0.55, o.dy - r * 0.15)
    ..lineTo(o.dx + r * 0.05, o.dy - r * 0.15)
    ..close();
  c.drawPath(path, Paint()..color = color);
  c.drawPath(path, _stroke(r * 0.1)..color = const Color(0xFF2A160E));
}

/// Kraftseite: goldener Blitz.
void _boltBadge(Canvas c, Offset o, double r) {
  c.drawCircle(o, r * 1.25, Paint()..color = const Color(0xFF2A160E));
  c.drawCircle(o, r * 1.25, _stroke(r * 0.18)..color = _gold);
  _bolt(c, o, r * 0.85, _gold);
}

void _spinBadge(Canvas c, Offset o, double r) {
  c.drawCircle(o, r * 1.25, Paint()..color = const Color(0xFF2A160E));
  for (var i = 0; i < 8; i++) {
    c.drawArc(
      Rect.fromCircle(center: o, radius: r),
      i * math.pi / 4,
      math.pi / 4,
      true,
      Paint()..color = i.isEven ? _gold : const Color(0xFFD8402B),
    );
  }
  c.drawCircle(o, r * 0.25, Paint()..color = Colors.white);
}

/// Vierfarbiges Rad für Farbwahl-Karten.
void _wheel(Canvas c, Offset o, double r, List<EinsColor> colors) {
  final rect = Rect.fromCircle(center: o, radius: r);
  for (var i = 0; i < 4; i++) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy)
        ..arcTo(rect, -math.pi / 2 + i * math.pi / 2, math.pi / 2, false)
        ..close(),
      Paint()..color = einsColors[colors[i]]!,
    );
  }
  c.drawCircle(o, r, _stroke(r * 0.1));
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
      Paint()..color = einsColors[lightColors[i]]!,
    );
  }
  c.restore();
  _text(c, 'Eins!', r.center, w * 0.3);
}

class EinsCardView extends StatelessWidget {
  const EinsCardView({
    super.key,
    required this.width,
    this.face,
    this.dark = false,
    this.highlighted = false,
  });

  final double width;
  final EinsFace? face;
  final bool dark;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final height = width / cardAspect;
    return Semantics(
      label: face?.spokenName ?? 'Verdeckte Karte',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.1),
          border: highlighted ? Border.all(color: _gold, width: 3) : null,
          boxShadow: const [
            BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x66000000)),
          ],
        ),
        child: CustomPaint(painter: _EinsPainter(face, dark)),
      ),
    );
  }
}

class _EinsPainter extends CustomPainter {
  _EinsPainter(this.face, this.dark);
  final EinsFace? face;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) => paintEinsCard(canvas, Offset.zero & size, face, dark: dark);

  @override
  bool shouldRepaint(_EinsPainter old) => old.face != face || old.dark != dark;
}

/// Farbwahl, nur die Farben der aktiven Seite.
Future<EinsColor?> showColorPicker(
  BuildContext context, {
  List<EinsColor> colors = lightColors,
  String title = 'Farbe wählen',
}) {
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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final c in colors)
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
                          border: Border.all(color: _cream, width: 3),
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

/// Glücksrad, dreht sich auf das Ergebnis.
class SpinWheel extends StatelessWidget {
  const SpinWheel({super.key, required this.size, required this.turns, this.spaces = wheel2005});

  final double size;

  /// Umdrehungen, 0 zeigt Feld 0 oben.
  final double turns;
  final List<SpinSpace> spaces;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Transform.rotate(
            angle: -turns * 2 * math.pi,
            child: CustomPaint(size: Size.square(size), painter: _WheelPainter(spaces)),
          ),
          CustomPaint(size: Size(size * 0.12, size * 0.12), painter: _PointerPainter()),
        ],
      ),
    );
  }
}

/// Winkel in Umdrehungen, bei dem das Feld oben steht.
double spinTurnsFor(SpinSpace s, List<SpinSpace> spaces) => (spaces.indexOf(s) + 0.5) / spaces.length;

Color _spaceColor(SpinSpace s, int i) => switch (s) {
      SpinSpace.colorDrawRed || SpinSpace.drawRed => einsColors[EinsColor.red]!,
      SpinSpace.colorDrawYellow => einsColors[EinsColor.yellow]!,
      SpinSpace.colorDrawGreen => einsColors[EinsColor.green]!,
      SpinSpace.colorDrawBlue || SpinSpace.drawBlue => einsColors[EinsColor.blue]!,
      _ => const [
          Color(0xFF8A5A2B),
          Color(0xFFF07A1A),
          Color(0xFF1FB5A8),
          Color(0xFFE0479E),
          Color(0xFF7B4FC9),
          Color(0xFF2E9C6A),
          Color(0xFFD9A441),
        ][i % 7],
    };

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.spaces);
  final List<SpinSpace> spaces;

  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero);
    final r = size.width / 2;
    final n = spaces.length;
    final sweep = 2 * math.pi / n;
    canvas.drawCircle(o, r, Paint()..color = einsWildColor);
    final rect = Rect.fromCircle(center: o, radius: r * 0.94);
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * sweep;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = _spaceColor(spaces[i], i));
      canvas.drawArc(rect, start, sweep, true, _stroke(r * 0.015)..color = _cream);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(start + sweep / 2 + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: spinName(spaces[i]).replaceFirst(' ', '\n'),
          style: TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w800,
            fontSize: r * 0.085,
            height: 1.05,
            color: Colors.white,
            shadows: const [Shadow(offset: Offset(1, 1), color: Color(0x99000000))],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.5);
      tp.paint(canvas, Offset(-tp.width / 2, -r * 0.82));
      canvas.restore();
    }
    canvas.drawCircle(o, r * 0.14, Paint()..color = _gold);
    canvas.drawCircle(o, r * 0.14, _stroke(r * 0.03)..color = einsWildColor);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.spaces != spaces;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = _cream);
    canvas.drawPath(path, _stroke(size.width * 0.08)..color = einsWildColor);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}

/// Kartenwerfer: ein Turm mit großem Knopf, ersetzt den Ziehstapel.
class LauncherView extends StatelessWidget {
  const LauncherView({super.key, required this.width, this.lastLaunch, this.enabled = true});

  final double width;
  final int? lastLaunch;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Kartenwerfer drücken',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width / cardAspect,
        child: CustomPaint(painter: _LauncherPainter(enabled, lastLaunch)),
      ),
    );
  }
}

class _LauncherPainter extends CustomPainter {
  _LauncherPainter(this.enabled, this.last);
  final bool enabled;
  final int? last;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.05, h * 0.18, w * 0.9, h * 0.8),
      topLeft: Radius.circular(w * 0.35),
      topRight: Radius.circular(w * 0.35),
      bottomLeft: Radius.circular(w * 0.08),
      bottomRight: Radius.circular(w * 0.08),
    );
    canvas.drawRRect(body, Paint()..color = einsWildColor);
    canvas.drawRRect(body, _stroke(w * 0.03)..color = _cream);
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(w * 0.05, h * (0.62 + i * 0.07), w * 0.9, h * 0.035),
        Paint()..color = einsColors[lightColors[i]]!,
      );
    }
    // Auswurfschlitz
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.2, h * 0.88, w * 0.6, h * 0.05), Radius.circular(w * 0.03)),
      Paint()..color = Colors.black,
    );
    // Knopf
    final o = Offset(w / 2, h * 0.36);
    canvas.drawCircle(o + Offset(0, w * 0.04), w * 0.26, Paint()..color = const Color(0xFF7A1C10));
    canvas.drawCircle(o, w * 0.26, Paint()..color = enabled ? einsColors[EinsColor.red]! : const Color(0xFF8C6A5E));
    canvas.drawCircle(o - Offset(w * 0.07, w * 0.07), w * 0.07, Paint()..color = Colors.white.withValues(alpha: 0.35));
    if (last != null) {
      _text(canvas, last == 0 ? '0' : '+$last', o, w * 0.24);
    }
  }

  @override
  bool shouldRepaint(_LauncherPainter old) => old.enabled != enabled || old.last != last;
}
