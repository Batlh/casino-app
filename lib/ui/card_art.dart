import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../games/cards/playing_card.dart';
import 'widgets.dart' show paintSuit;

const _red = Color(0xFFC8321F);
const _black = Color(0xFF241410);
const _blue = Color(0xFF23408E);
const _gold = Color(0xFFE2B33C);
const _skin = Color(0xFFF6D7B0);
const _cream = Color(0xFFFFF3D6);

/// Lage der Symbole auf Zahlenkarten (x, y jeweils von 0 bis 1 im Symbolfeld).
const _pips = <int, List<(double, double)>>{
  2: [(0.5, 0), (0.5, 1)],
  3: [(0.5, 0), (0.5, 0.5), (0.5, 1)],
  4: [(0, 0), (1, 0), (0, 1), (1, 1)],
  5: [(0, 0), (1, 0), (0.5, 0.5), (0, 1), (1, 1)],
  6: [(0, 0), (1, 0), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
  7: [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
  8: [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0.5, 0.75), (0, 1), (1, 1)],
  9: [(0, 0), (1, 0), (0, 1 / 3), (1, 1 / 3), (0.5, 0.5), (0, 2 / 3), (1, 2 / 3), (0, 1), (1, 1)],
  10: [(0, 0), (1, 0), (0.5, 1 / 6), (0, 1 / 3), (1, 1 / 3), (0, 2 / 3), (1, 2 / 3), (0.5, 5 / 6), (0, 1), (1, 1)],
};

/// Vorderseite einer Karte: Eckzeichen, Symbolbild, Ass mit Schmuckring, Bildkarten mit Figur.
class CardFacePainter extends CustomPainter {
  CardFacePainter(this.card, this.label, {this.strip = false});
  final PlayingCard card;
  final String label;

  /// Rang und Farbe groß oben, für überlappende Patiencen-Spalten.
  final bool strip;

  Color get _ink => card.isRed ? _red : _black;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (strip) {
      _paintStrip(canvas, w, h);
      return;
    }
    final small = w < 46;
    _corner(canvas, w, h, small);
    canvas.save();
    canvas.translate(w, h);
    canvas.rotate(math.pi);
    _corner(canvas, w, h, small);
    canvas.restore();

    final rank = card.rank;
    if (rank >= 11 && rank <= 13) {
      _court(canvas, Rect.fromLTRB(w * 0.2, h * 0.1, w * 0.8, h * 0.9), rank);
    } else if (rank == 1 || rank == 14 || small) {
      _ace(canvas, w, h, rank == 1 || rank == 14);
    } else {
      _pipsLayout(canvas, w, h, rank);
    }
  }

  void _text(Canvas canvas, String text, Offset topLeft, double size, Color color, {String font = bodyFont, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: font, fontWeight: FontWeight.w700, fontSize: size, height: 1, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? topLeft - Offset(tp.width / 2, tp.height / 2) : topLeft);
  }

  void _suit(Canvas canvas, Offset c, double size, {bool flip = false, Color? color}) {
    final r = Rect.fromCenter(center: c, width: size, height: size);
    if (!flip) {
      paintSuit(canvas, r, card.suit, color ?? _ink);
      return;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi);
    paintSuit(canvas, Rect.fromCenter(center: Offset.zero, width: size, height: size), card.suit, color ?? _ink);
    canvas.restore();
  }

  void _corner(Canvas canvas, double w, double h, bool small) {
    final size = w * (small ? 0.3 : 0.22);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: size, height: 1, color: _ink),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final cx = w * (small ? 0.2 : 0.14);
    tp.paint(canvas, Offset(cx - tp.width / 2, w * 0.06));
    _suit(canvas, Offset(cx, w * 0.06 + tp.height + w * 0.1), w * (small ? 0.2 : 0.15));
  }

  void _pipsLayout(Canvas canvas, double w, double h, int rank) {
    final area = Rect.fromLTRB(w * 0.36, h * 0.2, w * 0.64, h * 0.8);
    final size = w * (rank >= 9 ? 0.17 : 0.19);
    for (final (x, y) in _pips[rank]!) {
      final c = Offset(area.left + x * area.width, area.top + y * area.height);
      _suit(canvas, c, size, flip: y > 0.5);
    }
  }

  void _ace(Canvas canvas, double w, double h, bool ace) {
    final c = Offset(w / 2, h / 2);
    if (ace) {
      canvas.drawCircle(
        c,
        w * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = _ink.withValues(alpha: 0.35),
      );
      for (var k = 0; k < 12; k++) {
        final a = k * math.pi / 6;
        canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.34, w * 0.018, Paint()..color = _gold);
      }
    }
    _suit(canvas, c, w * (ace ? 0.42 : 0.5));
  }

  /// Bube, Dame, König: Rahmen und eine gespiegelte Figur wie auf echten Karten.
  void _court(Canvas canvas, Rect fr, int rank) {
    canvas.drawRect(fr, Paint()..color = _cream);
    canvas.save();
    canvas.clipRect(fr);
    _figure(canvas, Rect.fromLTRB(fr.left, fr.top, fr.right, fr.center.dy), rank);
    canvas.save();
    canvas.translate(fr.center.dx, fr.center.dy);
    canvas.rotate(math.pi);
    canvas.translate(-fr.center.dx, -fr.center.dy);
    _figure(canvas, Rect.fromLTRB(fr.left, fr.top, fr.right, fr.center.dy), rank);
    canvas.restore();
    canvas.restore();
    // Trennlinie und Rahmen
    canvas.drawLine(
      Offset(fr.left, fr.center.dy),
      Offset(fr.right, fr.center.dy),
      Paint()
        ..color = _gold
        ..strokeWidth = fr.width * 0.025,
    );
    canvas.drawRect(
      fr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fr.width * 0.035
        ..color = _gold,
    );
    canvas.drawRect(
      fr.deflate(fr.width * 0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fr.width * 0.012
        ..color = _ink,
    );
  }

  void _figure(Canvas canvas, Rect r, int rank) {
    final w = r.width;
    final h = r.height;
    Offset at(double x, double y) => Offset(r.left + x * w, r.top + y * h);
    final robe = card.isRed ? _red : _blue;
    final second = card.isRed ? _blue : _red;
    // Gewand
    final body = Path()
      ..moveTo(at(0.26, 0.62).dx, at(0.26, 0.62).dy)
      ..lineTo(at(0.74, 0.62).dx, at(0.74, 0.62).dy)
      ..lineTo(at(0.98, 1.0).dx, at(0.98, 1.0).dy)
      ..lineTo(at(0.02, 1.0).dx, at(0.02, 1.0).dy)
      ..close();
    canvas.drawPath(body, Paint()..color = robe);
    // Kragen und Mittelband
    canvas.drawRect(Rect.fromPoints(at(0.44, 0.62), at(0.56, 1.0)), Paint()..color = _gold);
    canvas.drawPath(
      Path()
        ..moveTo(at(0.26, 0.62).dx, at(0.26, 0.62).dy)
        ..lineTo(at(0.5, 0.78).dx, at(0.5, 0.78).dy)
        ..lineTo(at(0.74, 0.62).dx, at(0.74, 0.62).dy)
        ..close(),
      Paint()..color = second,
    );
    for (var k = 0; k < 3; k++) {
      canvas.drawCircle(at(0.5, 0.82 + k * 0.06), w * 0.025, Paint()..color = robe);
    }
    // Kopf
    final head = at(0.5, 0.44);
    final hr = w * 0.15;
    // Haar oder Schleier hinter dem Kopf
    if (rank == 12) {
      canvas.drawOval(Rect.fromCenter(center: head + Offset(0, h * 0.06), width: hr * 2.8, height: hr * 3.0), Paint()..color = second.withValues(alpha: 0.85));
    } else {
      canvas.drawCircle(head + Offset(0, -hr * 0.15), hr * 1.1, Paint()..color = const Color(0xFF8A5A2B));
    }
    canvas.drawCircle(head, hr, Paint()..color = _skin);
    canvas.drawCircle(
      head,
      hr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = _black.withValues(alpha: 0.5),
    );
    // Augen
    canvas.drawCircle(head + Offset(-hr * 0.35, -hr * 0.05), hr * 0.09, Paint()..color = _black);
    canvas.drawCircle(head + Offset(hr * 0.35, -hr * 0.05), hr * 0.09, Paint()..color = _black);
    if (rank == 13) {
      // Bart
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - hr * 0.8, head.dy + hr * 0.3)
          ..quadraticBezierTo(head.dx, head.dy + hr * 1.9, head.dx + hr * 0.8, head.dy + hr * 0.3)
          ..quadraticBezierTo(head.dx, head.dy + hr * 0.8, head.dx - hr * 0.8, head.dy + hr * 0.3)
          ..close(),
        Paint()..color = const Color(0xFF8A5A2B),
      );
    }
    // Kopfbedeckung
    final top = head.dy - hr * 0.75;
    switch (rank) {
      case 13:
        final crown = Path()..moveTo(head.dx - hr * 1.0, top);
        for (var k = 0; k <= 4; k++) {
          final x = head.dx - hr + k * hr * 0.5;
          crown.lineTo(x, top - (k.isEven ? hr * 0.9 : hr * 0.45));
        }
        crown
          ..lineTo(head.dx + hr * 1.0, top)
          ..close();
        canvas.drawPath(crown, Paint()..color = _gold);
        for (final dx in [-0.5, 0.0, 0.5]) {
          canvas.drawCircle(Offset(head.dx + dx * hr, top - hr * 0.2), hr * 0.12, Paint()..color = second);
        }
      case 12:
        final tiara = Path()
          ..moveTo(head.dx - hr * 0.8, top + hr * 0.1)
          ..lineTo(head.dx - hr * 0.4, top - hr * 0.35)
          ..lineTo(head.dx, top - hr * 0.6)
          ..lineTo(head.dx + hr * 0.4, top - hr * 0.35)
          ..lineTo(head.dx + hr * 0.8, top + hr * 0.1)
          ..close();
        canvas.drawPath(tiara, Paint()..color = _gold);
        canvas.drawCircle(Offset(head.dx, top - hr * 0.25), hr * 0.13, Paint()..color = second);
      default:
        // Bube: Mütze mit Feder
        canvas.drawOval(Rect.fromCenter(center: Offset(head.dx, top + hr * 0.05), width: hr * 2.3, height: hr * 0.9), Paint()..color = second);
        canvas.drawPath(
          Path()
            ..moveTo(head.dx + hr * 0.6, top)
            ..quadraticBezierTo(head.dx + hr * 1.8, top - hr * 1.0, head.dx + hr * 1.3, top - hr * 1.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.035
            ..strokeCap = StrokeCap.round
            ..color = _gold,
        );
    }
    // Gegenstand: Schwert, Blume oder Stab
    switch (rank) {
      case 13:
        canvas.drawLine(at(0.14, 0.95), at(0.14, 0.35), Paint()
          ..color = const Color(0xFF9AA3B5)
          ..strokeWidth = w * 0.04);
        canvas.drawLine(at(0.06, 0.8), at(0.22, 0.8), Paint()
          ..color = _gold
          ..strokeWidth = w * 0.04);
      case 12:
        final f = at(0.84, 0.66);
        for (var k = 0; k < 5; k++) {
          final a = k * 2 * math.pi / 5;
          canvas.drawCircle(f + Offset(math.cos(a), math.sin(a)) * w * 0.05, w * 0.04, Paint()..color = _red);
        }
        canvas.drawCircle(f, w * 0.03, Paint()..color = _gold);
      default:
        canvas.drawLine(at(0.86, 0.98), at(0.86, 0.3), Paint()
          ..color = const Color(0xFF8A5A2B)
          ..strokeWidth = w * 0.03);
        canvas.drawPath(
          Path()
            ..moveTo(at(0.86, 0.22).dx, at(0.86, 0.22).dy)
            ..lineTo(at(0.95, 0.34).dx, at(0.95, 0.34).dy)
            ..lineTo(at(0.77, 0.34).dx, at(0.77, 0.34).dy)
            ..close(),
          Paint()..color = const Color(0xFF9AA3B5),
        );
    }
    // Farbe und Rang klein im Bild
    _suit(canvas, at(0.15, 0.14), w * 0.17);
    _text(canvas, label, at(0.85, 0.14), w * 0.2, _ink, font: displayFont, center: true);
  }

  void _paintStrip(Canvas canvas, double w, double h) {
    final narrow = w < 48;
    _text(canvas, label, Offset(w * (narrow ? 0.05 : 0.07), w * 0.02), w * (narrow ? 0.42 : 0.36), _ink);
    final s = w * (narrow ? 0.24 : 0.26);
    _suit(canvas, Offset(w - w * 0.07 - s / 2, w * 0.08 + s / 2), s);
    final rank = card.rank;
    if (rank >= 11 && rank <= 13) {
      _court(canvas, Rect.fromLTRB(w * 0.18, h * 0.3, w * 0.82, h * 0.92), rank);
    } else {
      _suit(canvas, Offset(w / 2, h * 0.62), w * 0.44);
    }
  }

  @override
  bool shouldRepaint(CardFacePainter old) => old.card != card || old.label != label || old.strip != strip;
}

/// Kartenrücken: 0 Siebziger-Tapete, 1 klassisch blau mit Rauten, 2 Neon.
class CardBackPainter extends CustomPainter {
  const CardBackPainter(this.style);
  final int style;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case 1:
        _classic(canvas, size);
      case 2:
        _neon(canvas, size);
      default:
        _seventies(canvas, size);
    }
  }

  void _seventies(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFC4391F));
    final step = size.width / 2.6;
    const rings = [Color(0xFFF2A33A), Color(0xFF6B3E1E), Color(0xFFFFF1C9)];
    for (var ix = 0; ix < 4; ix++) {
      for (var iy = 0; iy < 6; iy++) {
        final c = Offset(step * 0.2 + ix * step + (iy.isOdd ? step / 2 : 0), iy * step * 0.8);
        for (var i = 0; i < rings.length; i++) {
          canvas.drawCircle(c, step * (0.5 - i * 0.14), Paint()..color = rings[i]);
        }
      }
    }
    _border(canvas, size, const Color(0xFFFFF1C9));
  }

  void _classic(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1F3F8F));
    final inner = (Offset.zero & size).deflate(size.width * 0.09);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, size.width * 0.012)
      ..color = const Color(0xCCE8EEFF);
    canvas.save();
    canvas.clipRect(inner);
    final step = size.width / 7;
    for (var k = -12; k < 20; k++) {
      canvas.drawLine(Offset(k * step, 0), Offset(k * step + size.height, size.height), line);
      canvas.drawLine(Offset(k * step, size.height), Offset(k * step + size.height, 0), line);
    }
    canvas.restore();
    canvas.drawRect(inner, line..strokeWidth = math.max(1, size.width * 0.02));
    // Rosette in der Mitte
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width * 0.17, Paint()..color = const Color(0xFF1F3F8F));
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * size.width * 0.1, size.width * 0.05, Paint()..color = const Color(0xFFE8EEFF));
    }
    canvas.drawCircle(c, size.width * 0.05, Paint()..color = _gold);
    _border(canvas, size, Colors.white);
  }

  void _neon(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0B33), Color(0xFF0B0620)],
        ).createShader(rect),
    );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.025);
    final c = size.center(Offset.zero);
    for (var k = 0; k < 4; k++) {
      final r = size.width * (0.12 + k * 0.1);
      glow.color = (k.isEven ? const Color(0xFFFF5EA8) : const Color(0xFF63E6FF)).withValues(alpha: 0.85 - k * 0.15);
      final p = Path()
        ..moveTo(c.dx, c.dy - r * 1.3)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx, c.dy + r * 1.3)
        ..lineTo(c.dx - r, c.dy)
        ..close();
      canvas.drawPath(p, glow);
    }
    _border(canvas, size, const Color(0xFF63E6FF));
  }

  void _border(Canvas canvas, Size size, Color color) {
    canvas.drawRect(
      (Offset.zero & size).deflate(size.width * 0.04),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(CardBackPainter old) => old.style != style;
}

/// Filz des Spieltisches: Verlauf, feine Fasern und ein dunkler Rand.
class FeltPainter extends CustomPainter {
  const FeltPainter(this.felt, this.edge);
  final Color felt;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = RadialGradient(radius: 1.1, colors: [felt, edge]).createShader(rect));
    final rng = math.Random(17);
    final light = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.025);
    final dark = Paint()
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.03);
    final n = (size.width * size.height / 900).clamp(200, 2500).toInt();
    for (var i = 0; i < n; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final a = rng.nextDouble() * math.pi;
      final l = 2 + rng.nextDouble() * 4;
      canvas.drawLine(Offset(x, y), Offset(x + math.cos(a) * l, y + math.sin(a) * l), i.isEven ? light : dark);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
          stops: const [0.7, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(FeltPainter old) => old.felt != felt || old.edge != edge;
}

/// Dreht eine Karte um, wenn sie von verdeckt auf offen wechselt (oder umgekehrt).
Widget flipTransition(Widget child, Animation<double> anim) {
  final rotate = Tween(begin: math.pi, end: 0.0).animate(anim);
  return AnimatedBuilder(
    animation: rotate,
    child: child,
    builder: (context, child) {
      final v = rotate.value;
      // In der ersten Hälfte ist die neue Seite noch unsichtbar
      if (v > math.pi / 2) return const SizedBox.shrink();
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(v),
        child: child,
      );
    },
  );
}
