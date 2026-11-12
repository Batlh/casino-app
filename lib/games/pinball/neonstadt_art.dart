part of 'pinball_art.dart';

// Bildbasierte Darstellung. Vektorpfade dienen nur der korrekten Positionierung,
// Maskierung und Beleuchtung der Grafiken auf den unveränderten Physikkörpern.
const _steelDark = Color(0xFF24313D);
const _steelBright = Color(0xFFD9E7EB);
const _signalPink = Color(0xFFFF397E);

void _cityStroke(Canvas c, Path p, Color color, double width) {
  c.drawPath(
    p,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

void _cityGlow(Canvas c, Offset at, double radius, Color color, double alpha) {
  c.drawCircle(
    at,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: at, radius: radius)),
  );
}

/// Bilder werden proportional eingepasst; transparente Außenränder sind im
/// Manifest vermessen. Cover beschneidet nur Dekoration, niemals die Physik.
void _cityImage(
  Canvas c,
  String key,
  Rect destination, {
  BoxFit fit = BoxFit.contain,
  double opacity = 1,
}) {
  final assets = NeonstadtAssets.instance;
  final image = assets.image(key);
  final source = assets.source(key);
  final fitted = applyBoxFit(fit, source.size, destination.size);
  final crop = Alignment.center.inscribe(fitted.source, source);
  final target = Alignment.center.inscribe(fitted.destination, destination);
  c.drawImageRect(
    image,
    crop,
    target,
    Paint()
      ..filterQuality = FilterQuality.high
      ..color = Colors.white.withValues(alpha: opacity),
  );
}

void _paintNeonstadt(Canvas c, TableTheme th, double now) {
  _cityBackground(c);
  c.drawRect(
    const Rect.fromLTWH(9.29, 3.627, .62, 14.373),
    Paint()..color = const Color(0xFF070C12),
  );
  for (final x in [9.31, 9.89])
    _cityMetalSegment(c, Offset(x, 3.666), Offset(x, 17.922), .055);
  for (var i = 0; i < 6; i++) {
    final y = i < 3 ? 4.3 + i * .50 : 10.7 + (i - 3) * .50;
    final on = (i + (now * 5).floor()) % 6 < 2;
    c.save();
    c.translate(9.60, y);
    if (i >= 3) c.rotate(math.pi);
    _cityLaneArrow(
      c,
      Offset.zero,
      th.light.withValues(alpha: on ? 1 : .20),
      size: .14,
    );
    c.restore();
  }
  _cityStroke(
    c,
    Path()
      ..moveTo(9.86, 4.0)
      ..lineTo(9.86, 16.0),
    th.light.withValues(alpha: .7),
    .025,
  );
}

/// Material-UV entlang einer geraden Schiene. Nur die Chromtextur wird auf die
/// Länge der Mechanik gelegt; Spielwelt und Bauteilsprites bleiben proportional.
void _cityMetalSegment(Canvas c, Offset a, Offset b, double width) {
  final d = b - a;
  if (d.distance < .0001) return;
  c.save();
  c.translate(a.dx, a.dy);
  c.rotate(math.atan2(d.dy, d.dx));
  c.drawImageRect(
    NeonstadtAssets.instance.image('chrome'),
    NeonstadtAssets.instance.source('chrome'),
    Rect.fromLTWH(-.015, -width / 2, d.distance + .03, width),
    Paint()..filterQuality = FilterQuality.medium,
  );
  c.restore();
}

void _cityRail(Canvas c, Path path, List<Pt> points) {
  c.save();
  c.translate(.025, .045);
  _cityStroke(c, path, Colors.black.withValues(alpha: .75), .16);
  c.restore();
  _cityStroke(c, path, _steelDark, .13);
  for (var i = 1; i < points.length; i++) {
    _cityMetalSegment(
      c,
      Offset(points[i - 1].x, points[i - 1].y),
      Offset(points[i].x, points[i].y),
      .10,
    );
  }
}

void _cityBumper(
  Canvas c,
  Offset at,
  double radius,
  TableTheme th,
  double pulse,
  double hit,
) {
  _cityGlow(c, at, radius * 1.8, th.bumper, .10 + pulse * .20);
  c.drawOval(
    Rect.fromCenter(
      center: at + const Offset(.04, .07),
      width: radius * 2,
      height: radius * 2,
    ),
    Paint()..color = Colors.black.withValues(alpha: .65),
  );
  final cap = at - Offset(0, hit * .025);
  _cityImage(
    c,
    'bumper',
    Rect.fromCenter(
      center: cap + const Offset(0, .08),
      width: radius * 2.1,
      height: radius * 2.3,
    ),
  );
  if (hit > .01) {
    _cityGlow(c, cap, radius * .8, th.bumper, hit * .35);
    c.drawCircle(
      cap,
      radius * .77,
      Paint()
        ..color = Colors.white.withValues(alpha: hit * .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .035,
    );
  }
}

Path _cityRoundedTriangle(List<Offset> pts) {
  final p = Path();
  for (var i = 0; i < 3; i++) {
    final at = pts[i],
        before = Offset.lerp(at, pts[(i + 2) % 3], .075)!,
        after = Offset.lerp(at, pts[(i + 1) % 3], .075)!;
    if (i == 0)
      p.moveTo(before.dx, before.dy);
    else
      p.lineTo(before.dx, before.dy);
    p.quadraticBezierTo(at.dx, at.dy, after.dx, after.dy);
  }
  return p..close();
}

void _cityScrew(Canvas c, Offset p, {double radius = .045}) {
  c.drawCircle(p, radius * 1.4, Paint()..color = _steelDark);
  c.drawCircle(p, radius, Paint()..color = _steelBright);
  _cityStroke(
    c,
    Path()
      ..moveTo(p.dx - radius * .6, p.dy)
      ..lineTo(p.dx + radius * .6, p.dy),
    _steelDark,
    .014,
  );
}

void _citySling(Canvas c, Path unused, Sling sling, TableTheme th) {
  final floor = [
    Offset(sling.a.x, sling.a.y),
    Offset(sling.b.x, sling.b.y),
    Offset(sling.c.x, sling.c.y),
  ];
  final pts = [for (final p in floor) p - const Offset(0, .15)],
      shape = _cityRoundedTriangle(pts);
  c.drawPath(
    shape.shift(const Offset(.09, .22)),
    Paint()
      ..color = const Color(0x77000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .055),
  );
  for (final p in floor) {
    _cityMountedRampPost(c, SupportSpec(p.dx, p.dy, .36), head: false);
  }
  c.drawPath(
    shape.shift(const Offset(0, .065)),
    Paint()..color = const Color(0x66D6346B),
  );
  c.drawPath(
    shape,
    Paint()
      ..shader = LinearGradient(
        colors: const [Color(0x55394559), Color(0x32202835), Color(0x60FF3584)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(shape.getBounds()),
  );
  _cityStroke(c, shape, const Color(0xAAEBFFFF), .035);
  // Geschlossener Gummiring; die innere aktive Kante schnellt beim Treffer aus.
  _cityStroke(
    c,
    shape.shift(const Offset(0, .055)),
    const Color(0xFFE4DEC6),
    .055,
  );
  final kick = Offset(sling.nx, sling.ny) * sling.glow * .10;
  final edge = Path()
    ..moveTo((pts[0] + kick).dx, (pts[0] + kick).dy)
    ..lineTo((pts[1] + kick).dx, (pts[1] + kick).dy);
  _cityStroke(
    c,
    edge,
    _signalPink.withValues(alpha: .25 + sling.glow * .5),
    .16,
  );
  _cityStroke(c, edge, const Color(0xFFFF66AC), .045);
  final center = (pts[0] + pts[1] + pts[2]) / 3;
  final right = sling.a.x > 4.6, sign = right ? -1.0 : 1.0;
  for (var i = 0; i < 3; i++) {
    final at = center + Offset(0, (i - 1) * .12);
    final stripe = Path()
      ..moveTo(at.dx - sign * .22, at.dy - .11)
      ..lineTo(at.dx + sign * .24, at.dy + .05)
      ..lineTo(at.dx - sign * .20, at.dy + .025);
    _cityStroke(c, stripe, const Color(0x77FF397E), .11);
    _cityStroke(c, stripe, const Color(0xFFFF6AAE), .035);
  }
  for (final p in floor) {
    _cityMountedRampPost(c, SupportSpec(p.dx, p.dy, .36), head: true);
  }
  if (sling.glow > .01)
    c.drawPath(
      shape,
      Paint()..color = Colors.white.withValues(alpha: sling.glow * .20),
    );
}

void _cityFlipper(Canvas c, Flipper f) {
  c.save();
  c.translate(f.spec.pivot.x, f.spec.pivot.y);
  c.rotate(f.spec.left ? .36 : -.36);
  c.scale(f.spec.dir.toDouble(), 1);
  final bowl = RRect.fromRectAndRadius(
    Rect.fromLTWH(-.33, -.39, f.spec.length + .62, .78),
    const Radius.circular(.30),
  );
  c.drawRRect(bowl, Paint()..color = const Color(0xB5070C13));
  c.drawRRect(
    bowl,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .035
      ..color = const Color(0xFFFFD43B),
  );
  c.drawOval(
    const Rect.fromLTWH(-.25, -.25, .5, .5),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF526775), Color(0xFFDAE7EB), Color(0xFF405560)],
      ).createShader(const Rect.fromLTWH(-.25, -.25, .5, .5)),
  );
  for (final p in [const Offset(-.13, -.17), const Offset(-.13, .17)]) {
    _cityScrew(c, p, radius: .026);
  }
  c.restore();
  final assets = NeonstadtAssets.instance;
  final source = assets.source('flipper');
  final pivot = assets.anchor('flipper', 'pivot');
  final tip = assets.anchor('flipper', 'tip');
  final delta = Offset(
    (tip.dx - pivot.dx) * source.width,
    (tip.dy - pivot.dy) * source.height,
  );
  final scale = f.spec.length / delta.distance;
  final intrinsic = math.atan2(delta.dy, delta.dx);
  c.save();
  c.translate(f.spec.pivot.x, f.spec.pivot.y);
  c.rotate(f.angle);
  c.scale(f.spec.dir.toDouble(), 1);
  c.rotate(-intrinsic);
  final target = Rect.fromLTWH(
    -pivot.dx * source.width * scale,
    -pivot.dy * source.height * scale,
    source.width * scale,
    source.height * scale,
  );
  c.drawImageRect(
    assets.image('flipper'),
    source,
    target,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.restore();
}

void _cityPlunger(Canvas c, double top, double charge, TableTheme th) {
  final housing = RRect.fromRectAndRadius(
    const Rect.fromLTWH(9.30, 16.23, .61, 1.72),
    const Radius.circular(.06),
  );
  c.drawRRect(housing, Paint()..color = const Color(0xFF131B26));
  c.drawRRect(
    housing,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .035
      ..color = _steelBright,
  );
  for (final x in [9.34, 9.87])
    for (final y in [16.30, 17.87]) _cityScrew(c, Offset(x, y), radius: .025);
  c.save();
  c.translate(0, 3.96);
  final assets = NeonstadtAssets.instance;
  final src = assets.source('plunger');
  // Bild in drei mechanische Teile aufgeteilt: Kopf, komprimierte Feder, Knauf.
  void piece(double a, double b, Rect dst) {
    c.drawImageRect(
      assets.image('plunger'),
      Rect.fromLTRB(
        src.left,
        src.top + src.height * a,
        src.right,
        src.top + src.height * b,
      ),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  final pull = charge * .25;
  piece(0, .10, Rect.fromLTWH(9.34, 12.40 + pull, .52, .18));
  piece(.10, .78, Rect.fromLTWH(9.34, 12.58 + pull, .52, 1.03 - pull));
  piece(.78, 1, Rect.fromLTWH(9.34, 13.61, .52, .39));
  c.restore();
}

/// Rundes Projektorgehäuse und schmaler Dateneinlass an dessen Front.
void _citySocket(
  Canvas c,
  Saucer saucer,
  TableTheme th,
  double now,
  PinballTable table,
) {
  final x = saucer.spec.x;
  final held = saucer.held != null;
  final box = Rect.fromLTWH(x - 1.3, saucer.spec.y - 3.0, 2.587, 3.10);
  _cityGlow(
    c,
    Offset(x, saucer.spec.y - .65),
    1.35,
    th.accent,
    held ? .28 : .10,
  );
  c.drawOval(
    Rect.fromCenter(
      center: Offset(x + .08, saucer.spec.y - .50),
      width: 2.65,
      height: 1.10,
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: .40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .08),
  );
  c.save();
  c.clipRect(Rect.fromLTRB(box.left, box.top + 1.72, box.right, box.bottom));
  _cityImage(c, 'hologram', box);
  c.restore();
  c.save();
  final turn =
      table.city != null && table.city!.clock < table.city!.hologramUntil;
  c.translate(x, 0);
  c.scale(turn ? .25 + .75 * math.cos(table.city!.clock * 7).abs() : 1.0, 1);
  c.translate(-x, 0);
  c.clipRect(Rect.fromLTWH(box.left, box.top, box.width, 1.72));
  _cityImage(c, 'hologram', box);
  c.restore();
  if (turn) _cityGlow(c, Offset(x, box.top + 1), 1.4, th.ramp, .5);
  // Nur die holographische obere Hälfte pulsiert; das Metall steht fest.
  c.save();
  c.clipRect(Rect.fromLTWH(x - 1.3, box.top, 2.6, 1.72));
  _cityImage(c, 'hologram', box, opacity: .08 + .06 * math.sin(now * 2.4));
  c.drawLine(
    Offset(x - 1.05, box.top + (now * .6) % 1.65),
    Offset(x + 1.05, box.top + (now * .6) % 1.65),
    Paint()
      ..color = th.ramp.withValues(alpha: .18)
      ..strokeWidth = .025,
  );
  c.restore();
  for (var i = 0; i < 3; i++) {
    final on = (table.city?.multiball == 'Datenupload' ? 3 : table.locks) > i;
    c.drawCircle(
      Offset(x - .35 + i * .35, saucer.spec.y + .24),
      .065,
      Paint()..color = on ? th.light : const Color(0xFF34352B),
    );
  }
  c.drawOval(
    Rect.fromCenter(center: Offset(x, saucer.spec.y), width: .65, height: .30),
    Paint()..color = const Color(0xFF010203),
  );
  final mouth = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(x, saucer.spec.y), width: .65, height: .12),
    const Radius.circular(.04),
  );
  c.drawRRect(mouth, Paint()..color = const Color(0xFF03070B));
  c.drawRRect(
    mouth,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .025
      ..color = held ? th.ramp : th.accent,
  );
  if (held || saucer.flash > .01)
    _cityGlow(
      c,
      Offset(x, saucer.spec.y),
      .45,
      th.ramp,
      held ? .35 : saucer.flash * .35,
    );
}

void _cityRollover(Canvas c, Lane lane, bool on, TableTheme th) {
  final x = lane.spec.x;
  c.drawRect(
    Rect.fromLTWH(x - .26, .36, .52, .77),
    Paint()..color = const Color(0x22090C11),
  );
  for (final xx in [x - .30, x + .30])
    _cityMetalSegment(c, Offset(xx, .35), Offset(xx, 1.12), .075);
  final arch = Path()
    ..moveTo(x - .28, .80)
    ..lineTo(x - .28, .35)
    ..quadraticBezierTo(x - .28, .22, x, .22)
    ..quadraticBezierTo(x + .28, .22, x + .28, .35)
    ..lineTo(x + .28, .80);
  _cityStroke(c, arch, _steelDark, .11);
  _cityStroke(c, arch, _steelBright, .055);
  _cityLaneArrow(
    c,
    Offset(x, .60),
    on ? th.light : th.light.withValues(alpha: .28),
    size: .19,
  );
}

void _cityApron(Canvas c, TableTheme th) {
  final frame = Path()
    ..moveTo(.12, 16.65)
    ..lineTo(4.10, 17.73)
    ..lineTo(4.16, 18)
    ..lineTo(.12, 18)
    ..close()
    ..moveTo(9.13, 16.65)
    ..lineTo(5.15, 17.73)
    ..lineTo(5.09, 18)
    ..lineTo(9.13, 18)
    ..close();
  c.drawPath(frame, Paint()..color = const Color(0x33161C26));
  _cityStroke(c, frame, _steelDark, .10);
  _cityStroke(c, frame, const Color(0xFFFFCC37), .035);
  for (final right in [false, true]) {
    final x = right ? 9.05 : .20, end = right ? 5.15 : 4.1;
    final neon = Path()
      ..moveTo(x, 16.40)
      ..lineTo(right ? 7.2 : 2.05, 17.10)
      ..lineTo(end, 17.78);
    _cityStroke(c, neon, _signalPink.withValues(alpha: .20), .14);
    _cityStroke(c, neon, _signalPink, .038);
    final yellow = Path()
      ..moveTo(right ? 7.1 : 2.15, 16.56)
      ..lineTo(right ? 5.14 : 4.11, 17.33);
    _cityStroke(c, yellow, th.light, .032);
    for (final t in [.12, .55, .93])
      _cityScrew(c, Offset(x + (end - x) * t, 16.72 + 1.07 * t));
  }
  final drain = Path()
    ..moveTo(4.35, 18)
    ..lineTo(4.35, 17.28)
    ..quadraticBezierTo(4.35, 16.96, 4.625, 16.96)
    ..quadraticBezierTo(4.90, 16.96, 4.90, 17.28)
    ..lineTo(4.90, 18)
    ..close();
  c.drawPath(drain, Paint()..color = const Color(0xFF030406));
  _cityStroke(c, drain, _steelBright, .045);
  _cityMetalSegment(
    c,
    const Offset(.12, 17.91),
    const Offset(9.13, 17.91),
    .11,
  );
  for (final x in [.25, 2.0, 7.25, 9.0]) _cityScrew(c, Offset(x, 17.91));
}

void _cityHeader(Canvas c, PinballTable table) {
  _cityImage(c, 'header', const Rect.fromLTWH(0, 0, 9.95, 1.80));
  _text(
    c,
    table.score.toString(),
    const Offset(4.98, .31),
    .23,
    const Color(0xFFFFB33F),
    fontFamily: 'Barlow',
  );
}

void _cityLaneArrow(Canvas c, Offset at, Color color, {double size = .16}) {
  final p = Path()
    ..moveTo(at.dx, at.dy - size)
    ..lineTo(at.dx + size * .7, at.dy + size * .6)
    ..lineTo(at.dx - size * .7, at.dy + size * .6)
    ..close();
  c.drawPath(p, Paint()..color = color);
  _cityStroke(c, p, _steelBright.withValues(alpha: .5), .02);
}

void _citySideLanes(Canvas c, PinballTable table, double now) {
  for (final lane in table.lanes.where((l) => l.spec.group != 'top')) {
    final x = lane.spec.x,
        out = lane.spec.group.startsWith('outlane_'),
        y = out ? 13.12 : 12.95;
    final slot = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - .19, y, .38, (out ? 16.25 : 14.55) - y),
      const Radius.circular(.18),
    );
    c.drawRRect(slot, Paint()..color = const Color(0xF0080A10));
    c.drawRRect(
      slot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .085
        ..color = _steelDark,
    );
    c.drawRRect(
      slot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .032
        ..color = _steelBright,
    );
    final on = lane.flash > .1 ? (now * 7).floor().isEven : lane.lit,
        color = table.spec.theme.light.withValues(alpha: on ? 1 : .20);
    _cityStroke(
      c,
      Path()
        ..moveTo(x, y + .34)
        ..lineTo(x, y + (out ? 1.12 : .75)),
      color,
      .045,
    );
    for (var i = 0; i < 2; i++)
      _cityLaneArrow(
        c,
        Offset(x, (out ? 14.85 : 13.9) + i * (out ? .70 : .42)),
        color,
        size: .13,
      );
    _cityScrew(c, Offset(x, y - .14), radius: .035);
    if (out) {
      final left = x < 4.6,
          lit = left
              ? (table.city?.kickbackLit ?? false)
              : (table.city?.specialLit ?? false);
      final lamp = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - .18, 12.43, .36, .46),
        const Radius.circular(.10),
      );
      c.drawRRect(
        lamp,
        Paint()
          ..color = table.spec.theme.light.withValues(alpha: lit ? .8 : .12),
      );
      c.drawRRect(
        lamp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .025
          ..color = _steelBright,
      );
      _text(
        c,
        left ? 'RÜCKSTOSS' : 'SPEZIAL',
        Offset(x, 12.31),
        .075,
        lit ? table.spec.theme.light : _steelBright,
        fontFamily: 'Barlow',
      );
    }
  }
}

/// 32: Seitenprofile des Gehäuses, getrennt von der Spielphysik.
void _cityCabinetRails(Canvas c, PinballTable table, double now) {
  final flash =
      table.city != null && table.city!.clock < table.city!.sideWallUntil;
  if (flash && (now * 12).floor().isEven)
    for (final x in [.16, 9.78])
      for (final y in [2.0, 5.0, 8.0, 11.0, 14.0, 17.0])
        _cityGlow(c, Offset(x, y), 1.1, _signalPink, .45);
  for (final x in [.055, 9.895]) {
    _cityMetalSegment(c, Offset(x, .30), Offset(x, 17.87), .105);
  }
}

/// 23: Trichterlippen an vier getrennten Schussmündungen.
void _cityEntryCollars(Canvas c, PinballTable table) {
  for (final r in table.ramps) {
    if (r.spec.skillBand >= 0) continue;
    final a = Offset(r.spec.a.x, r.spec.a.y),
        b = Offset(r.spec.b.x, r.spec.b.y);
    _cityMetalSegment(c, a, b, .060);
    for (final p in [a, b]) {
      c.drawCircle(
        p + const Offset(0, .06),
        .085,
        Paint()..color = const Color(0xFFBE922C),
      );
      c.drawCircle(p, .055, Paint()..color = _steelBright);
    }
  }
}

/// Schaltbare GI-Lichtebene: Motivdatei und Farbdaten bleiben unverändert.
void _cityLightLayer(Canvas c, PinballTable table, double now, bool idle) {
  if (!table.neonLighting || (table.city?.blackout ?? false)) return;
  final amount = table.multiball
      ? .24
      : table.skillArmed
      ? .18
      : .10;
  for (final p in [
    const Offset(.65, 4.6),
    const Offset(8.6, 4.6),
    const Offset(2.1, 4.9),
    const Offset(7.15, 4.9),
    const Offset(4.625, 5.35),
  ]) {
    _cityGlow(
      c,
      p,
      1.25,
      const Color(0xFFFFCF45),
      amount * (.92 + .08 * math.sin(now * 2.0)),
    );
  }
  for (final p in table.spec.supports)
    _cityGlow(c, Offset(p.x, p.y), .40, const Color(0xFFFFD347), .24);
}

const _cityCut = 5.484375;
void _cityBackground(Canvas c) {
  final assets = NeonstadtAssets.instance;
  final image = assets.image('playfield');
  final source = assets.source('playfield');
  const factor = 14.04 / 1024;
  const w = 528 * factor;
  const x = (9.25 - w) / 2;
  final cut = source.top + source.height * 400 / 1024;
  final paint = Paint()..filterQuality = FilterQuality.high;
  c.drawImageRect(
    image,
    Rect.fromLTRB(source.left, source.top, source.right, cut),
    const Rect.fromLTWH(x, 0, w, _cityCut),
    paint,
  );
  c.drawImageRect(
    assets.image('playfield_strip'),
    assets.source('playfield_strip'),
    const Rect.fromLTWH(x, _cityCut, w, 3.96),
    paint,
  );
  c.drawImageRect(
    image,
    Rect.fromLTRB(source.left, cut, source.right, source.bottom),
    const Rect.fromLTWH(x, _cityCut + 3.96, w, 14.04 - _cityCut),
    paint,
  );
}

/// Dreieckiger Leuchteinsatz entsprechend der Konzeptgrafik.
void _cityShotArrow(
  Canvas c,
  Offset at,
  double angle,
  Color color, {
  double size = .30,
}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle + math.pi / 2);
  _cityLaneArrow(c, Offset.zero, color, size: size);
  c.restore();
}
