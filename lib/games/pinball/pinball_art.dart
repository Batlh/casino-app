import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pinball_table.dart';
import 'neonstadt_assets.dart';

part 'neonstadt_art.dart';
part 'neonstadt_ramps.dart';

/// Funke nach einem Treffer.
class Spark {
  Spark(this.x, this.y, this.vx, this.vy, this.color);
  double x;
  double y;
  final double vx;
  double vy;
  final Color color;
  double life = 0.5;
}

/// Inhalt der Punktanzeige.
class DmdState {
  const DmdState(
    this.big,
    this.small,
    this.color, {
    this.blink = false,
    this.scroll = false,
    this.time = 0,
  });
  final String big;
  final String small;
  final Color color;
  final bool blink;
  final bool scroll;
  final double time;
}

/// Punktanzeige im Stil einer Punktmatrix: Text in Leuchtfarbe, darüber ein feines Raster.
class DmdPainter extends CustomPainter {
  DmdPainter(this.state, Listenable repaint, {this.industrial = false})
    : super(repaint: repaint);
  final bool industrial;
  final DmdState Function() state;

  @override
  void paint(Canvas canvas, Size size) {
    final s = state();
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFF070504));
    canvas.save();
    canvas.clipRRect(r);
    final on = !s.blink || (s.time * 3).floor().isEven;
    final c = s.color;
    if (on) {
      final bigSize = size.height * 0.46;
      final big = TextPainter(
        text: TextSpan(
          text: s.big,
          style: TextStyle(
            color: c,
            fontFamily: industrial ? 'Barlow' : null,
            fontSize: bigSize,
            fontWeight: FontWeight.w900,
            letterSpacing: bigSize * 0.08,
            shadows: [Shadow(color: c.withValues(alpha: 0.8), blurRadius: 8)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final scale = math.min(1.0, (size.width - 16) / big.width);
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.36);
      canvas.scale(scale);
      big.paint(canvas, Offset(-big.width / 2, -big.height / 2));
      canvas.restore();
    }
    final small = TextPainter(
      text: TextSpan(
        text: s.small,
        style: TextStyle(
          fontFamily: industrial ? 'Barlow' : null,
          color: c.withValues(alpha: 0.9),
          fontSize: size.height * 0.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final y = size.height * 0.78 - small.height / 2;
    if (s.scroll && small.width > size.width - 16) {
      final span = small.width + size.width * 0.6;
      final x = size.width - (s.time * 60) % span;
      small.paint(canvas, Offset(x, y));
    } else {
      final scale = math.min(1.0, (size.width - 16) / small.width);
      canvas.save();
      canvas.translate(size.width / 2, y + small.height / 2);
      canvas.scale(scale);
      small.paint(canvas, Offset(-small.width / 2, -small.height / 2));
      canvas.restore();
    }
    if (industrial) {
      // Dezente Aktivitätsleisten; die Punktzahl bleibt frei lesbar.
      for (var i = 0; i < 16; i++) {
        final active = (i + (s.time * 8).floor()) % 16 < 4;
        canvas.drawRect(
          Rect.fromLTWH(size.width - 5, 6 + i * (size.height - 12) / 16, 2, 2),
          Paint()..color = c.withValues(alpha: active ? 0.8 : 0.12),
        );
      }
    }
    // Punktraster
    final grid = Paint()
      ..color = const Color(0xFF070504)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 3) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var yy = 0.0; yy < size.height; yy += 3) {
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), grid);
    }
    canvas.restore();
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant DmdPainter old) => true;
}

/// Malt einen Tisch: Motiv, Lichter, Banden, Teile, Kugeln, Rampen und Funken.
class TablePainter extends CustomPainter {
  TablePainter(
    this.table,
    this.spec,
    this.time,
    this.sparks,
    Listenable repaint,
  ) : super(repaint: Listenable.merge([repaint, NeonstadtAssets.instance]));

  /// Standbild für die Tischauswahl.
  TablePainter.preview(TableSpec s)
    : table = (() => null),
      spec = (() => s),
      time = (() => 0.0),
      sparks = (() => const []),
      super(repaint: NeonstadtAssets.instance);

  final PinballTable? Function() table;
  final TableSpec Function() spec;
  final double Function() time;
  final List<Spark> Function() sparks;

  static final Map<String, PinballTable> _demos = {};

  static const cityHeaderHeight = 1.85;
  static double viewHeight(TableSpec spec) =>
      spec.playfieldHeight + (spec.theme.art == 'city' ? cityHeaderHeight : 0);

  @override
  void paint(Canvas canvas, Size size) {
    final sp = spec();
    final th = sp.theme;
    if (th.art == 'city' && !NeonstadtAssets.instance.isReady) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF080E19),
      );
      final failed = NeonstadtAssets.instance.hasError;
      _text(
        canvas,
        failed ? 'Grafiken nicht verfügbar' : 'Neonstadt wird geladen …',
        Offset(size.width / 2, size.height / 2),
        math.min(16, size.width / 18),
        th.accent,
      );
      return;
    }
    final t =
        table() ??
        _demos.putIfAbsent(
          sp.id,
          () => PinballTable(rng: math.Random(1), spec: sp),
        );
    final now = time();
    final idle = table() == null || t.gameOver;
    final s = math.min(
      size.width / PinballTable.width,
      size.height / viewHeight(sp),
    );
    canvas.save();
    canvas.translate(
      (size.width - PinballTable.width * s) / 2,
      (size.height - viewHeight(sp) * s) / 2,
    );
    canvas.scale(s);
    if (th.art == 'city') {
      _cityHeader(canvas, t);
      canvas.translate(0, cityHeaderHeight);
    }
    final field = Rect.fromLTWH(0, 0, PinballTable.width, sp.playfieldHeight);
    final rr = RRect.fromRectAndRadius(field, const Radius.circular(0.4));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      field,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.top, th.mid, th.bottom],
        ).createShader(field),
    );
    paintArt(canvas, th, now);
    for (final (text, p, sz) in sp.labels) {
      // Neonstadt trägt einen eigenen, in die Druckgrafik integrierten Schriftzug.
      if (th.art != 'city') {
        _text(
          canvas,
          text,
          Offset(p.x, p.y),
          sz,
          th.accent.withValues(alpha: 0.35),
          weight: FontWeight.w900,
        );
      }
    }
    if (th.art == 'city') {
      _cityGroundArchitecture(canvas, t);
    }
    _inserts(canvas, t, th, now, idle);
    if (th.art == 'city') _cityApron(canvas, th);

    // Banden
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = th.wall;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = th.wall.withValues(alpha: 0.2);
    void line(List<Pt> pts) {
      final path = Path()..moveTo(pts.first.x, pts.first.y);
      for (final p in pts.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      if (th.art == 'city') {
        _cityRail(canvas, path, pts);
      } else {
        canvas.drawPath(path, glow);
        canvas.drawPath(path, neon);
      }
    }

    line(const [
      Pt(PinballTable.fieldRight, 18.2),
      Pt(PinballTable.fieldRight, 4.6),
    ]);
    for (final w in t.walls) {
      if (w.visible) line(w.points);
    }
    if (t.gateClosed) line(t.gatePoints);

    // Gassenlichter
    for (var i = 0; i < t.lanes.length; i++) {
      final l = t.lanes[i];
      final chase = idle && ((now * 4).floor() % t.lanes.length) == i;
      final on = l.lit || chase || l.flash > 0.5;
      if (th.art == 'city') {
        _cityRollover(canvas, l, on, th);
        continue;
      }
      canvas.drawCircle(
        Offset(l.spec.x, l.spec.y + 0.85),
        0.18,
        Paint()..color = on ? th.light : th.light.withValues(alpha: 0.25),
      );
      if (on)
        canvas.drawCircle(
          Offset(l.spec.x, l.spec.y + 0.85),
          0.32,
          Paint()..color = th.light.withValues(alpha: 0.18),
        );
    }

    // Kickout-Löcher
    for (final sc in t.saucers) {
      if (th.art == 'city') {
        _citySocket(canvas, sc, th, now);
        continue;
      }
      final c = Offset(sc.spec.x, sc.spec.y);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4 + now * (sc.held != null ? 6 : 1.2);
        final on = sc.held != null || (k + (now * 6).floor()) % 4 == 0;
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * 0.48,
          0.06,
          Paint()..color = on ? th.accent : th.accent.withValues(alpha: 0.25),
        );
      }
      canvas.drawCircle(c, 0.34, Paint()..color = Colors.black);
      canvas.drawCircle(
        c,
        0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = Color.lerp(th.wall, Colors.white, sc.flash)!,
      );
      if (sc.spec.lock)
        _text(
          canvas,
          'LOCK',
          c + const Offset(0, 0.72),
          0.22,
          th.accent.withValues(alpha: 0.8),
        );
    }

    // Spinner
    for (final sn in t.spinners) {
      final a = Offset(sn.spec.a.x, sn.spec.a.y);
      final b = Offset(sn.spec.b.x, sn.spec.b.y);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = th.wall.withValues(alpha: 0.6)
          ..strokeWidth = 0.05,
      );
      final mid = (a + b) / 2;
      final half = (b - a).distance / 2 * 0.8;
      final dir = (b - a) / (b - a).distance;
      final thick = 0.03 + 0.12 * math.cos(sn.angle).abs();
      final n = Offset(-dir.dy, dir.dx) * thick;
      final p = Path()
        ..moveTo((mid - dir * half + n).dx, (mid - dir * half + n).dy)
        ..lineTo((mid + dir * half + n).dx, (mid + dir * half + n).dy)
        ..lineTo((mid + dir * half - n).dx, (mid + dir * half - n).dy)
        ..lineTo((mid - dir * half - n).dx, (mid - dir * half - n).dy)
        ..close();
      if (th.art == 'city') {
        canvas.save();
        canvas.clipPath(p);
        _cityImage(canvas, 'chrome', p.getBounds(), fit: BoxFit.cover);
        canvas.restore();
        _cityStroke(canvas, p, th.ramp.withValues(alpha: .5), .02);
      } else {
        canvas.drawPath(
          p,
          Paint()
            ..color = Color.lerp(
              th.light,
              Colors.white,
              math.min(1, sn.speed / 8),
            )!,
        );
      }
    }

    // Fallziele
    for (final bank in t.dropBanks) {
      for (final d in bank.targets) {
        final alpha = 1 - d.sink;
        if (alpha <= 0.02) {
          _bar(
            canvas,
            d.c,
            bank.spec.angle,
            bank.spec.length,
            0.06,
            th.accent.withValues(alpha: 0.25),
          );
          continue;
        }
        _bar(
          canvas,
          d.c,
          bank.spec.angle,
          bank.spec.length,
          0.16,
          Color.lerp(
            th.accent,
            Colors.white,
            bank.flash,
          )!.withValues(alpha: alpha),
        );
      }
    }
    // Stehende Ziele
    for (final bank in t.targetBanks) {
      if (th.art == 'city') {
        _cityTargetBank(canvas, bank);
        continue;
      }
      for (final d in bank.targets) {
        final c = d.lit ? th.light : th.light.withValues(alpha: 0.35);
        _bar(
          canvas,
          d.c,
          bank.spec.angle,
          bank.spec.length,
          0.14,
          Color.lerp(c, Colors.white, d.flash)!,
        );
      }
    }

    // Pilze
    for (final b in t.bumpers) {
      final c = Offset(b.x, b.y);
      final r = b.spec.radius;
      final pulse = idle ? 0.5 + 0.5 * math.sin(now * 2 + b.x) : b.glow;
      if (th.art == 'city') {
        _cityBumper(canvas, c, r, th, pulse, b.glow);
        continue;
      }
      canvas.drawCircle(
        c,
        r + 0.12 * pulse,
        Paint()
          ..color = Color.lerp(
            th.bumper.withValues(alpha: 0.35),
            th.bumper.withValues(alpha: 0.85),
            pulse,
          )!,
      );
      canvas.drawCircle(
        c,
        r * 0.84,
        Paint()..color = Color.lerp(th.bottom, Colors.black, 0.3)!,
      );
      canvas.drawCircle(
        c,
        r * 0.84,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08
          ..color = th.bumper,
      );
      canvas.drawCircle(
        c,
        r * 0.32,
        Paint()..color = Color.lerp(th.bumper, Colors.white, b.glow)!,
      );
    }
    // Schleudern
    for (final sl in t.slings) {
      final p = Path()
        ..moveTo(sl.a.x, sl.a.y)
        ..lineTo(sl.b.x, sl.b.y)
        ..lineTo(sl.c.x, sl.c.y)
        ..close();
      if (th.art == 'city') {
        _citySling(canvas, p, sl, th);
      } else {
        canvas.drawPath(
          p,
          Paint()
            ..color = Color.lerp(
              th.sling.withValues(alpha: 0.35),
              th.sling.withValues(alpha: 0.85),
              sl.glow,
            )!,
        );
      }
    }
    for (final f in t.flippers) {
      _flipper(canvas, f, th);
    }
    // Feder in der Bahn
    final springTop = 17.7 + 0.5 * t.charge;
    if (th.art == 'city') {
      _cityPlunger(canvas, 12.4566 + .14 * t.charge, t.charge, th);
    } else {
      canvas.drawRect(
        Rect.fromLTRB(9.35, springTop, 9.85, 18.0),
        Paint()
          ..color = Color.lerp(const Color(0xFF8A8A9A), th.accent, t.charge)!,
      );
    }

    // Kugeln auf dem Tisch
    for (final b in t.balls) {
      if (b.raised || (th.art == 'city' && b.saucer != null)) continue;
      final p = b.pos;
      _ball(
        canvas,
        Offset(p.x, p.y),
        PinballTable.ballRadius * (b.saucer != null ? 0.85 : 1),
      );
    }
    // Räumliche Rampen: Fahrbahn, Kugeln und Seitenwände werden nach Höhe sortiert.
    if (th.art == 'city') {
      _cityDrawRampLevels(
        canvas,
        t,
        now,
        (position, radius) => _ball(canvas, position, radius),
      );
    } else {
      // Rampen über dem Tisch
      for (final r in t.ramps) {
        _ramp(canvas, r, th, now);
      }
      for (final b in t.balls) {
        if (!b.raised) continue;
        final p = b.pos;
        canvas.drawCircle(
          Offset(p.x + 0.12, p.y + 0.18),
          PinballTable.ballRadius * 1.1,
          Paint()..color = Colors.black38,
        );
        _ball(canvas, Offset(p.x, p.y), PinballTable.ballRadius * 1.15);
      }
    }
    for (final sp in sparks()) {
      canvas.drawCircle(
        Offset(sp.x, sp.y),
        0.05 + 0.08 * sp.life,
        Paint()..color = sp.color.withValues(alpha: (sp.life * 2).clamp(0, 1)),
      );
    }
    // Multiball: Rand blinkt
    if (t.multiball) {
      final on = (now * 6).floor().isEven;
      canvas.drawRRect(
        rr.deflate(0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.16
          ..color = (on ? th.accent : th.wall).withValues(alpha: 0.7),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  void _ball(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Colors.white, Color(0xFFB8C2D6), Color(0xFF5A6478)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _bar(
    Canvas canvas,
    Pt c,
    double angle,
    double length,
    double thick,
    Color color,
  ) {
    canvas.save();
    canvas.translate(c.x, c.y);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: length, height: thick),
        const Radius.circular(0.04),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  void _ramp(Canvas canvas, Ramp r, TableTheme th, double now) {
    final pts = r.spec.path;
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.62
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(
          th.ramp.withValues(alpha: 0.16),
          th.ramp.withValues(alpha: 0.45),
          r.flash,
        )!,
    );
    // Schienen links und rechts
    for (final side in [-1.0, 1.0]) {
      final rail = Path();
      for (var i = 0; i < pts.length; i++) {
        final a = pts[math.max(0, i - 1)];
        final b = pts[math.min(pts.length - 1, i + 1)];
        final dx = b.x - a.x;
        final dy = b.y - a.y;
        final len = math.sqrt(dx * dx + dy * dy);
        final o = Offset(-dy / len, dx / len) * 0.3 * side;
        final p = Offset(pts[i].x, pts[i].y) + o;
        if (i == 0) {
          rail.moveTo(p.dx, p.dy);
        } else {
          rail.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        rail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..strokeJoin = StrokeJoin.round
          ..color = th.ramp.withValues(alpha: 0.85),
      );
    }
    // Lauflicht auf der Rampe
    final dot = r.at((now * 4) % math.max(0.1, r.length));
    canvas.drawCircle(Offset(dot.x, dot.y), 0.09, Paint()..color = th.ramp);
  }

  /// Pfeile zu Rampen und Löchern; sie blinken, wenn die Mission sie verlangt.
  void _inserts(
    Canvas canvas,
    PinballTable t,
    TableTheme th,
    double now,
    bool idle,
  ) {
    final m = t.mission;
    final blink = (now * 3).floor().isEven;
    for (final r in t.ramps) {
      final wanted =
          m != null &&
              ((m.kind == MissionKind.ramp && m.id == r.spec.id) ||
                  m.kind == MissionKind.anyRamp) ||
          t.multiball;
      final c = Offset(
        (r.spec.a.x + r.spec.b.x) / 2,
        r.spec.a.y + (th.art == 'city' ? 2.3 : 1.7),
      );
      final color = (wanted && blink) || (idle && blink)
          ? th.light
          : th.light.withValues(alpha: 0.25);
      if (th.art == 'city') {
        final left = r.spec.id == 'links';
        for (var i = 0; i < 3; i++) {
          final at = Offset(
            left ? 3.00 + i * .35 : 6.25 - i * .35,
            5.967 + i * .468,
          );
          _arrow(
            canvas,
            at,
            left ? -.65 * math.pi : -.35 * math.pi,
            color,
            size: .23,
          );
        }
      } else {
        _arrow(canvas, c, -math.pi / 2, color);
      }
    }
    for (final sc in t.saucers) {
      final wanted =
          m != null &&
          (m.kind == MissionKind.saucer || m.kind == MissionKind.lock);
      final c = Offset(sc.spec.x, sc.spec.y + (th.art == 'city' ? .50 : 1.0));
      _arrow(
        canvas,
        c,
        -math.pi / 2,
        wanted && blink ? th.accent : th.accent.withValues(alpha: 0.2),
        size: 0.28,
      );
    }
  }

  void _arrow(
    Canvas canvas,
    Offset c,
    double angle,
    Color color, {
    double size = 0.34,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle + math.pi / 2);
    final p = Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.8, size * 0.6)
      ..lineTo(0, size * 0.25)
      ..lineTo(-size * 0.8, size * 0.6)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.restore();
  }

  void _flipper(Canvas canvas, Flipper f, TableTheme th) {
    if (th.art == 'city') {
      _cityFlipper(canvas, f);
      return;
    }
    canvas.save();
    canvas.translate(f.spec.pivot.x, f.spec.pivot.y);
    canvas.rotate(f.angle);
    final l = f.spec.length * f.spec.dir;
    final path = Path()
      ..moveTo(0, -0.2)
      ..lineTo(l, -0.07)
      ..lineTo(l, 0.07)
      ..lineTo(0, 0.2)
      ..close();
    canvas.drawPath(path, Paint()..color = th.flipper);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04
        ..color = Colors.black54,
    );
    canvas.drawCircle(
      Offset.zero,
      0.2,
      Paint()..color = Color.lerp(th.flipper, Colors.white, 0.5)!,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TablePainter old) => true;
}

void _text(
  Canvas canvas,
  String text,
  Offset c,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: size * 0.1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

/// Motiv auf dem Spielfeld je nach Thema.
void paintArt(Canvas canvas, TableTheme th, double now) {
  switch (th.art) {
    case 'space':
      _space(canvas, th, now);
    case 'pirate':
      _pirate(canvas, th, now);
    case 'haunted':
      _haunted(canvas, th, now);
    case 'racing':
      _racing(canvas, th, now);
    case 'city':
      _city(canvas, th, now);
    default:
      _neon(canvas, th, now);
  }
}

void _neon(Canvas canvas, TableTheme th, double now) {
  final p = Paint()
    ..color = th.wall.withValues(alpha: 0.06)
    ..strokeWidth = 0.03;
  for (var x = -18.0; x < 12; x += 0.9) {
    canvas.drawLine(Offset(x, 18), Offset(x + 9, 0), p);
  }
  canvas.drawCircle(
    const Offset(4.6, 10.6),
    2.4,
    Paint()
      ..shader =
          RadialGradient(
            colors: [th.accent.withValues(alpha: 0.22), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: const Offset(4.6, 10.6), radius: 2.4),
          ),
  );
}

void _space(Canvas canvas, TableTheme th, double now) {
  final rng = math.Random(7);
  for (var i = 0; i < 140; i++) {
    final x = rng.nextDouble() * 9.95;
    final y = rng.nextDouble() * 18;
    final tw = 0.5 + 0.5 * math.sin(now * (1 + rng.nextDouble() * 3) + i);
    canvas.drawCircle(
      Offset(x, y),
      0.02 + rng.nextDouble() * 0.035,
      Paint()..color = Colors.white.withValues(alpha: 0.3 + 0.6 * tw),
    );
  }
  // Nebel
  canvas.drawCircle(
    const Offset(3.2, 7.5),
    3.5,
    Paint()
      ..shader =
          RadialGradient(
            colors: [th.sling.withValues(alpha: 0.18), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: const Offset(3.2, 7.5), radius: 3.5),
          ),
  );
  // Planet mit Ring
  const pc = Offset(5.9, 10.9);
  canvas.drawCircle(
    pc,
    1.0,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [th.accent, const Color(0xFF7A3B10)],
      ).createShader(Rect.fromCircle(center: pc, radius: 1.0)),
  );
  canvas.save();
  canvas.translate(pc.dx, pc.dy);
  canvas.rotate(-0.35);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 3.2, height: 0.7),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08
      ..color = th.light.withValues(alpha: 0.6),
  );
  canvas.restore();
  // Station: Ring um die Mitte
  canvas.drawCircle(
    const Offset(4.6, 5.4),
    2.3,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05
      ..color = th.wall.withValues(alpha: 0.25),
  );
}

void _pirate(Canvas canvas, TableTheme th, double now) {
  final wave = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.04
    ..color = Colors.white.withValues(alpha: 0.08);
  for (var row = 0.5; row < 18; row += 0.8) {
    final p = Path()..moveTo(0, row);
    for (var x = 0.0; x <= 9.95; x += 0.2) {
      p.lineTo(x, row + 0.12 * math.sin(x * 2.2 + now * 1.4 + row));
    }
    canvas.drawPath(p, wave);
  }
  // Insel und Kompass
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(4.6, 11.0), width: 3.6, height: 1.6),
    Paint()..color = const Color(0x55E8C98A),
  );
  const c = Offset(4.6, 11.0);
  final rose = Paint()..color = th.wall.withValues(alpha: 0.5);
  for (var k = 0; k < 4; k++) {
    final a = k * math.pi / 2 + now * 0.2;
    final p = Path()
      ..moveTo(c.dx + math.cos(a) * 0.75, c.dy + math.sin(a) * 0.75)
      ..lineTo(
        c.dx + math.cos(a + 0.35) * 0.18,
        c.dy + math.sin(a + 0.35) * 0.18,
      )
      ..lineTo(
        c.dx + math.cos(a - 0.35) * 0.18,
        c.dy + math.sin(a - 0.35) * 0.18,
      )
      ..close();
    canvas.drawPath(p, rose);
  }
  // Schatzkarte: gestrichelter Weg
  final dash = Paint()
    ..color = th.bumper.withValues(alpha: 0.5)
    ..strokeWidth = 0.05;
  for (var i = 0; i < 9; i++) {
    final t = i / 9;
    final a = Offset(1.6 + t * 2.4, 9.2 + math.sin(t * 5) * 0.4);
    canvas.drawLine(a, a + const Offset(0.15, 0.05), dash);
  }
  _text(
    canvas,
    'X',
    const Offset(4.15, 9.6),
    0.5,
    th.bumper.withValues(alpha: 0.7),
    weight: FontWeight.w900,
  );
}

void _haunted(Canvas canvas, TableTheme th, double now) {
  // Mond
  const moon = Offset(6.9, 10.6);
  canvas.drawCircle(
    moon,
    1.6,
    Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x55FFF4C2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: moon, radius: 1.6)),
  );
  canvas.drawCircle(moon, 0.85, Paint()..color = const Color(0xCCEFE6C2));
  canvas.drawCircle(
    moon + const Offset(0.3, -0.15),
    0.8,
    Paint()..color = th.mid.withValues(alpha: 0.6),
  );
  // Schloss
  final castle = Path()
    ..moveTo(1.4, 12.4)
    ..lineTo(1.4, 10.3)
    ..lineTo(1.9, 9.6)
    ..lineTo(2.4, 10.3)
    ..lineTo(2.4, 10.8)
    ..lineTo(3.2, 10.8)
    ..lineTo(3.2, 9.9)
    ..lineTo(3.7, 9.1)
    ..lineTo(4.2, 9.9)
    ..lineTo(4.2, 10.8)
    ..lineTo(5.0, 10.8)
    ..lineTo(5.0, 10.3)
    ..lineTo(5.4, 9.8)
    ..lineTo(5.8, 10.3)
    ..lineTo(5.8, 12.4)
    ..close();
  canvas.drawPath(castle, Paint()..color = const Color(0xAA0A0610));
  for (final w in const [
    Offset(1.9, 10.8),
    Offset(3.7, 10.2),
    Offset(5.4, 10.9),
  ]) {
    final on = (now * 0.8 + w.dx).floor().isEven;
    canvas.drawRect(
      Rect.fromCenter(center: w, width: 0.18, height: 0.28),
      Paint()..color = (on ? th.accent : th.light).withValues(alpha: 0.7),
    );
  }
  // Fledermäuse
  final bat = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.05
    ..color = Colors.black.withValues(alpha: 0.6);
  for (var i = 0; i < 4; i++) {
    final x = (1.5 + i * 2.1 + now * 0.4) % 9.0;
    final y = 7.8 + math.sin(now * 2 + i) * 0.4 + i * 0.3;
    final flap = 0.15 * math.sin(now * 10 + i);
    final p = Path()
      ..moveTo(x - 0.3, y - flap)
      ..quadraticBezierTo(x - 0.15, y + 0.1, x, y)
      ..quadraticBezierTo(x + 0.15, y + 0.1, x + 0.3, y - flap);
    canvas.drawPath(p, bat);
  }
}

void _racing(Canvas canvas, TableTheme th, double now) {
  // Fahrbahnmarkierung
  final dash = Paint()
    ..color = Colors.white.withValues(alpha: 0.14)
    ..strokeWidth = 0.08;
  for (var y = -1.0 + (now * 3) % 1.2; y < 18; y += 1.2) {
    canvas.drawLine(Offset(4.6, y), Offset(4.6, y + 0.6), dash);
  }
  // Zielflagge quer
  const sq = 0.35;
  for (var i = 0; i < 27; i++) {
    for (var j = 0; j < 2; j++) {
      if ((i + j).isEven) {
        canvas.drawRect(
          Rect.fromLTWH(i * sq, 10.9 + j * sq, sq, sq),
          Paint()..color = Colors.white.withValues(alpha: 0.16),
        );
      }
    }
  }
  // Randsteine
  for (var i = 0; i < 18; i++) {
    canvas.drawRect(
      Rect.fromLTWH(0, i * 1.0, 0.18, 0.5),
      Paint()
        ..color = (i.isEven ? th.bumper : Colors.white).withValues(alpha: 0.3),
    );
  }
}

void _city(Canvas canvas, TableTheme th, double now) {
  _paintNeonstadt(canvas, th, now);
}
