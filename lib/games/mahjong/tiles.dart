import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mahjong-Steine als Zahlen: 0 bis 8 Zeichen (Man), 9 bis 17 Kreise (Pin),
/// 18 bis 26 Bambus (Sou), 27 bis 30 Winde Ost, Süd, West, Nord,
/// 31 bis 33 Drachen Weiß, Grün, Rot. Für das Solitär zusätzlich
/// 34 bis 37 Blumen und 38 bis 41 Jahreszeiten, 42 bis 45 Tiere (Katze, Maus, Hahn, Tausendfüßer)
/// und 46 der Joker.
const tileKinds = 34;
const firstWind = 27;
const firstDragon = 31;
const firstFlower = 34;
const firstSeason = 38;
const firstAnimal = 42;
const jokerKind = 46;

/// Vietnam: acht Joker-Arten (grün: Allgemein, Kreise, Bambus, Zeichen; rot: Blume, Wind, Drache, Farbe),
/// dazu Kaiser und Kaiserin als Blumen.
const firstVietJoker = 47;
const flowerJoker = 51;
const emperorTile = 55;
const empressTile = 56;
const vietJokerKanji = ['縂', '筒', '索', '萬', '花', '喜', '元', '合'];
const vietJokerNames = ['Allgemein', 'Kreise', 'Bambus', 'Zeichen', 'Blume', 'Wind', 'Drache', 'Farbe'];

/// Welche Steine ein Joker ersetzen kann (46 und 47 alles, der Blumen-Joker nichts in der Hand).
bool jokerCovers(int joker, int t) {
  if (t >= tileKinds) return false;
  return switch (joker) {
    46 || 47 => true,
    48 => t >= 9 && t < 18,
    49 => t >= 18 && t < 27,
    50 => t < 9,
    52 => t >= 27 && t < 31,
    53 => t >= 31 && t < 34,
    54 => t < 27,
    _ => false,
  };
}

/// Wie viele Steinsorten ein Joker abdeckt (je kleiner, desto lieber wird er verbraucht).
int jokerReach(int joker) => switch (joker) {
      46 || 47 => 34,
      54 => 27,
      48 || 49 || 50 => 9,
      52 => 4,
      53 => 3,
      _ => 0,
    };

/// Joker in der Hand (der Blumen-Joker zählt wie eine Blume).
bool isJokerTile(int t) => t == jokerKind || (t >= firstVietJoker && t < emperorTile && t != flowerJoker);
const animalNames = ['Katze', 'Maus', 'Hahn', 'Tausendfüßer'];
const _animalKanji = ['貓', '鼠', '雞', '蜈'];

int suitOf(int t) => t < 27 ? t ~/ 9 : 3;
int numberOf(int t) => t < 27 ? t % 9 + 1 : 0;
bool isHonor(int t) => t >= 27 && t < 34;
bool isTerminal(int t) => t < 27 && (t % 9 == 0 || t % 9 == 8);
bool isTerminalOrHonor(int t) => isHonor(t) || isTerminal(t);
bool isSimple(int t) => t < 27 && !isTerminal(t);

const _numerals = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
const windKanji = ['東', '南', '西', '北'];
const windNames = ['Ost', 'Süd', 'West', 'Nord'];

String tileName(int t) {
  if (t < 9) return '${t + 1} Zeichen';
  if (t < 18) return '${t - 8} Kreise';
  if (t < 27) return '${t - 17} Bambus';
  if (t < 31) return '${windNames[t - 27]}wind';
  if (t < 34) return const ['Weißer Drache', 'Grüner Drache', 'Roter Drache'][t - 31];
  if (t < 38) return 'Blume ${t - 33}';
  if (t < 42) return 'Jahreszeit ${t - 37}';
  if (t < 46) return animalNames[t - 42];
  if (t == 46) return 'Joker';
  if (t < emperorTile) return 'Joker ${vietJokerNames[t - firstVietJoker]}';
  return t == emperorTile ? 'Kaiser' : 'Kaiserin';
}

const _ivory = Color(0xFFFBF5E6);
const _red = Color(0xFFC62828);
const _green = Color(0xFF1B7A3E);
const _blue = Color(0xFF1F4E9A);
const _ink = Color(0xFF1E120D);

/// Zeichnet einen Stein in das Rechteck der Vorderseite. depth: Dicke nach rechts unten.
/// Hilfszahlen auf den Steinen (Einstellung „Hilfszahlen auf Mahjong-Steinen“).
final tileHints = ValueNotifier<bool>(false);

/// Kurze Beschriftung für die Hilfszahlen: Zahl, Windrichtung oder Drachenfarbe.
String? tileHintLabel(int t) {
  if (t < 27) return '${t % 9 + 1}';
  if (t < 31) return const ['O', 'S', 'W', 'N'][t - 27];
  if (t < 34) return const ['Weiß', 'Grün', 'Rot'][t - 31];
  if (t > jokerKind && t < emperorTile) return vietJokerNames[t - firstVietJoker];
  return null;
}

void paintTile(
  Canvas canvas,
  Rect face,
  int tile, {
  double depth = 0,
  bool selected = false,
  bool dim = false,
  bool hint = false,
  bool back = false,
}) {
  _paintTileBody(canvas, face, tile, depth: depth, selected: selected, dim: dim, hint: hint, back: back);
  if (back || !tileHints.value) return;
  final label = tileHintLabel(tile);
  if (label == null) return;
  final fs = face.width * (label.length > 1 ? 0.2 : 0.26);
  final tp = TextPainter(
    text: TextSpan(text: label, style: TextStyle(color: Colors.white, fontSize: fs, fontWeight: FontWeight.w800, height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();
  final box = Rect.fromLTWH(
    face.right - tp.width - face.width * 0.1,
    face.bottom - tp.height - face.width * 0.08,
    tp.width + face.width * 0.06,
    tp.height + face.width * 0.04,
  );
  canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(face.width * 0.06)), Paint()..color = const Color(0xCC1E120D));
  tp.paint(canvas, box.topLeft + Offset(face.width * 0.03, face.width * 0.02));
}

void _paintTileBody(
  Canvas canvas,
  Rect face,
  int tile, {
  double depth = 0,
  bool selected = false,
  bool dim = false,
  bool hint = false,
  bool back = false,
}) {
  final radius = Radius.circular(face.width * 0.12);
  if (depth > 0) {
    final side = RRect.fromRectAndRadius(face.shift(Offset(depth, depth)), radius);
    canvas.drawRRect(side, Paint()..color = const Color(0xFF2E7D5B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(face.shift(Offset(depth * 0.5, depth * 0.5)), radius),
      Paint()..color = const Color(0xFFE9DCC0),
    );
  }
  final rr = RRect.fromRectAndRadius(face, radius);
  if (back) {
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF2E7D5B));
    canvas.drawRRect(
      rr.deflate(face.width * 0.08),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = face.width * 0.04
        ..color = const Color(0xFF7CC4A0),
    );
    return;
  }
  canvas.drawRRect(
    rr,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFDF6), _ivory, Color(0xFFEDE3CC)],
      ).createShader(face),
  );
  canvas.drawRRect(
    rr,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, face.width * 0.03)
      ..color = const Color(0x55000000),
  );
  final inner = face.deflate(face.width * 0.1);
  _paintFace(canvas, inner, tile);
  if (dim) canvas.drawRRect(rr, Paint()..color = const Color(0x55000000));
  if (selected || hint) {
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, face.width * 0.09)
        ..color = selected ? const Color(0xFFFFB300) : const Color(0xFF29B6F6),
    );
  }
}

void _text(Canvas canvas, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Kanji', fontSize: size, height: 1, color: color, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

const _pinSpots = <List<Offset>>[
  [Offset(0.5, 0.5)],
  [Offset(0.5, 0.27), Offset(0.5, 0.73)],
  [Offset(0.27, 0.22), Offset(0.5, 0.5), Offset(0.73, 0.78)],
  [Offset(0.3, 0.27), Offset(0.7, 0.27), Offset(0.3, 0.73), Offset(0.7, 0.73)],
  [Offset(0.28, 0.24), Offset(0.72, 0.24), Offset(0.5, 0.5), Offset(0.28, 0.76), Offset(0.72, 0.76)],
  [Offset(0.3, 0.2), Offset(0.7, 0.2), Offset(0.3, 0.52), Offset(0.7, 0.52), Offset(0.3, 0.82), Offset(0.7, 0.82)],
  [
    Offset(0.24, 0.14), Offset(0.5, 0.26), Offset(0.76, 0.38), //
    Offset(0.3, 0.6), Offset(0.7, 0.6), Offset(0.3, 0.84), Offset(0.7, 0.84),
  ],
  [
    Offset(0.3, 0.14), Offset(0.7, 0.14), Offset(0.3, 0.38), Offset(0.7, 0.38), //
    Offset(0.3, 0.62), Offset(0.7, 0.62), Offset(0.3, 0.86), Offset(0.7, 0.86),
  ],
  [
    Offset(0.2, 0.18), Offset(0.5, 0.18), Offset(0.8, 0.18), //
    Offset(0.2, 0.5), Offset(0.5, 0.5), Offset(0.8, 0.5),
    Offset(0.2, 0.82), Offset(0.5, 0.82), Offset(0.8, 0.82),
  ],
];

void _paintFace(Canvas canvas, Rect r, int t) {
  final w = r.width;
  final h = r.height;
  Offset at(Offset o) => Offset(r.left + o.dx * w, r.top + o.dy * h);
  if (t < 9) {
    _text(canvas, _numerals[t], Offset(r.center.dx, r.top + h * 0.27), w * 0.62, _ink);
    _text(canvas, '萬', Offset(r.center.dx, r.top + h * 0.72), w * 0.66, _red);
    return;
  }
  if (t < 18) {
    final n = t - 9;
    final spots = _pinSpots[n];
    final radius = n == 0 ? w * 0.38 : (n < 4 ? w * 0.2 : (n < 6 ? w * 0.17 : w * 0.14));
    for (var i = 0; i < spots.length; i++) {
      final c = at(spots[i]);
      final color = n == 0
          ? _red
          : (n == 4 && i == 2) || (n == 6 && i < 3) || (n == 8 && i >= 3 && i < 6)
              ? _red
              : (i.isEven ? _blue : _green);
      canvas.drawCircle(c, radius, Paint()..color = color);
      canvas.drawCircle(c, radius * 0.55, Paint()..color = _ivory);
      canvas.drawCircle(c, radius * 0.3, Paint()..color = color);
    }
    return;
  }
  if (t < 27) {
    final n = t - 18;
    if (n == 0) {
      // Eins Bambus: ein kleiner Vogel
      final body = Path()
        ..addOval(Rect.fromCenter(center: at(const Offset(0.5, 0.55)), width: w * 0.5, height: h * 0.38));
      canvas.drawPath(body, Paint()..color = _green);
      canvas.drawCircle(at(const Offset(0.5, 0.28)), w * 0.15, Paint()..color = _red);
      final tail = Path()
        ..moveTo(at(const Offset(0.45, 0.7)).dx, at(const Offset(0.45, 0.7)).dy)
        ..lineTo(at(const Offset(0.2, 0.95)).dx, at(const Offset(0.2, 0.95)).dy)
        ..lineTo(at(const Offset(0.6, 0.85)).dx, at(const Offset(0.6, 0.85)).dy)
        ..close();
      canvas.drawPath(tail, Paint()..color = _blue);
      canvas.drawCircle(at(const Offset(0.56, 0.26)), w * 0.035, Paint()..color = _ivory);
      return;
    }
    final spots = _pinSpots[n];
    final stickW = w * (n < 6 ? 0.14 : 0.12);
    final stickH = h * (n < 3 ? 0.36 : (n < 6 ? 0.3 : 0.2));
    for (var i = 0; i < spots.length; i++) {
      final c = at(spots[i]);
      final red = (n == 4 && i == 2) || (n == 8 && (i == 1 || i == 4 || i == 7)) || (n == 6 && i == 0);
      final color = red ? _red : _green;
      final stick = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: stickW, height: stickH),
        Radius.circular(stickW * 0.4),
      );
      canvas.drawRRect(stick, Paint()..color = color);
      canvas.drawLine(
        Offset(c.dx - stickW / 2, c.dy),
        Offset(c.dx + stickW / 2, c.dy),
        Paint()
          ..color = _ivory
          ..strokeWidth = math.max(1, stickW * 0.18),
      );
    }
    return;
  }
  if (t < 31) {
    _text(canvas, windKanji[t - 27], r.center, w * 0.8, _ink);
    return;
  }
  if (t == 31) {
    final frame = r.deflate(w * 0.12);
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.07
        ..color = _blue,
    );
    return;
  }
  if (t == 32) {
    _text(canvas, '發', r.center, w * 0.8, _green);
    return;
  }
  if (t == 33) {
    _text(canvas, '中', r.center, w * 0.8, _red);
    return;
  }
  if (t >= firstAnimal && t < jokerKind) {
    final k = t - firstAnimal;
    const colors = [Color(0xFF6D4C41), Color(0xFF546E7A), Color(0xFFC62828), Color(0xFF2E7D32)];
    canvas.drawCircle(at(const Offset(0.5, 0.42)), w * 0.4, Paint()..color = colors[k].withValues(alpha: 0.15));
    _text(canvas, _animalKanji[k], at(const Offset(0.5, 0.42)), w * 0.72, colors[k]);
    _text(canvas, '${k + 1}', at(const Offset(0.5, 0.9)), w * 0.28, _ink);
    return;
  }
  if (t == jokerKind) {
    final c = at(const Offset(0.5, 0.42));
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? w * 0.42 : w * 0.18;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        star.moveTo(pt.dx, pt.dy);
      } else {
        star.lineTo(pt.dx, pt.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFB300));
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = _red,
    );
    _text(canvas, 'JOKER', at(const Offset(0.5, 0.88)), w * 0.24, _red);
    return;
  }
  if (t >= firstVietJoker && t < emperorTile) {
    // Grüne Joker: Allgemein, Kreise, Bambus, Zeichen; rote: Blume, Wind, Drache, Farbe
    final k = t - firstVietJoker;
    final color = k < 4 ? _green : _red;
    final c = at(const Offset(0.5, 0.42));
    canvas.drawCircle(c, w * 0.38, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawCircle(
      c,
      w * 0.38,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..color = color,
    );
    _text(canvas, vietJokerKanji[k], c, w * 0.56, color);
    _text(canvas, 'JOKER', at(const Offset(0.5, 0.88)), w * 0.22, color);
    return;
  }
  if (t == emperorTile || t == empressTile) {
    final c = at(const Offset(0.5, 0.42));
    const gold = Color(0xFFB8860B);
    canvas.drawCircle(c, w * 0.36, Paint()..color = gold.withValues(alpha: 0.18));
    _text(canvas, t == emperorTile ? '皇' : '后', c, w * 0.6, t == emperorTile ? gold : _red);
    _text(canvas, t == emperorTile ? 'Kaiser' : 'Kaiserin', at(const Offset(0.5, 0.88)), w * 0.18, _ink);
    return;
  }
  // Blumen und Jahreszeiten
  final flower = t < firstSeason;
  final k = flower ? t - firstFlower : t - firstSeason;
  final colors = flower
      ? const [Color(0xFFE91E63), Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFF2196F3)]
      : const [Color(0xFF66BB6A), Color(0xFFFFC107), Color(0xFFFF7043), Color(0xFF90CAF9)];
  final c = at(const Offset(0.5, 0.42));
  if (flower) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * w * 0.2, w * 0.14, Paint()..color = colors[k]);
    }
    canvas.drawCircle(c, w * 0.1, Paint()..color = const Color(0xFFFFEB3B));
  } else {
    canvas.drawCircle(c, w * 0.24, Paint()..color = colors[k]);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * w * 0.3,
        c + Offset(math.cos(a), math.sin(a)) * w * 0.42,
        Paint()
          ..color = colors[k]
          ..strokeWidth = w * 0.06,
      );
    }
  }
  _text(canvas, '${k + 1}', at(const Offset(0.5, 0.88)), w * 0.3, _ink);
}

/// Einzelner Stein als Widget.
class TileView extends StatelessWidget {
  const TileView({
    super.key,
    required this.tile,
    required this.width,
    this.selected = false,
    this.dim = false,
    this.back = false,
    this.depth = 0,
  });

  final int tile;
  final double width;
  final bool selected;
  final bool dim;
  final bool back;
  final double depth;

  static const aspect = 0.76;

  @override
  Widget build(BuildContext context) {
    final h = width / aspect;
    return Semantics(
      label: back ? 'verdeckter Stein' : tileName(tile),
      child: ValueListenableBuilder<bool>(
        valueListenable: tileHints,
        builder: (context, hints, _) => CustomPaint(
          size: Size(width + depth, h + depth),
          painter: _TilePainter(tile, selected, dim, back, depth, hints),
        ),
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.tile, this.selected, this.dim, this.back, this.depth, this.hints);
  final bool hints;
  final int tile;
  final bool selected;
  final bool dim;
  final bool back;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    paintTile(
      canvas,
      Rect.fromLTWH(0, 0, size.width - depth, size.height - depth),
      tile,
      depth: depth,
      selected: selected,
      dim: dim,
      back: back,
    );
  }

  @override
  bool shouldRepaint(covariant _TilePainter o) =>
      o.tile != tile || o.selected != selected || o.dim != dim || o.back != back || o.depth != depth || o.hints != hints;
}
