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
  // Eigene illustrierte Spielfeldgrafik statt generierter Rechteck-Skyline.
  const printArea = Rect.fromLTWH(0, 0, 9.25, 14.04);
  _cityImage(c, 'playfield', printArea, fit: BoxFit.cover);
  c.drawRect(
    const Rect.fromLTWH(9.29, 3.627, .62, 10.413),
    Paint()..color = const Color(0xFF070C12),
  );
  for (final x in [9.31, 9.89])
    _cityMetalSegment(c, Offset(x, 3.666), Offset(x, 13.962), .055);
  for (var i = 0; i < 12; i++) {
    final y = 3.90 + i * .6708;
    final on = (i + (now * 5).floor()) % 12 < 3;
    _cityLaneArrow(
      c,
      Offset(9.60, y),
      th.accent.withValues(alpha: on ? 1 : .42),
      size: .15,
    );
  }
  _citySideLanes(c, th, now);
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

void _citySling(Canvas c, Path shape, Sling sling, TableTheme th) {
  final assets = NeonstadtAssets.instance;
  final source = assets.source('sling');
  final target = [
    Offset(sling.a.x, sling.a.y),
    Offset(sling.b.x, sling.b.y),
    Offset(sling.c.x, sling.c.y),
  ];
  final uv = [
    source.topLeft,
    Offset(source.right, source.top + source.height * .70),
    source.bottomLeft,
  ];
  c.save();
  c.translate(.04, .07);
  c.drawPath(shape, Paint()..color = Colors.black87);
  c.restore();
  final vertices = ui.Vertices(
    ui.VertexMode.triangles,
    target,
    textureCoordinates: uv,
  );
  c.drawVertices(
    vertices,
    BlendMode.srcOver,
    Paint()
      ..filterQuality = FilterQuality.high
      ..shader = ui.ImageShader(
        assets.image('sling'),
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      ),
  );
  vertices.dispose();
  for (final (a, b) in [
    (sling.a, sling.b),
    (sling.b, sling.c),
    (sling.c, sling.a),
  ]) {
    _cityMetalSegment(c, Offset(a.x, a.y), Offset(b.x, b.y), .055);
  }
  if (sling.glow > .01)
    c.drawPath(
      shape,
      Paint()..color = th.sling.withValues(alpha: sling.glow * .38),
    );
}

void _cityFlipper(Canvas c, Flipper f) {
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
  _cityImage(
    c,
    'chrome',
    Rect.fromLTWH(9.38, top - .07, .43, .14),
    fit: BoxFit.cover,
  );
  final spring = Path()..moveTo(9.43, top + .05);
  for (var i = 1; i <= 10; i++) {
    spring.lineTo(
      i.isOdd ? 9.77 : 9.43,
      top + .05 + i * math.max(.02, (14.196 - top) / 10),
    );
  }
  _cityStroke(c, spring, _steelBright.withValues(alpha: .7), .035);
  c.drawRect(
    Rect.fromLTWH(9.32, 13.689 - charge * .8, .035, .08 + charge * .8),
    Paint()..color = th.accent,
  );
}

/// Rundes Projektorgehäuse und schmaler Dateneinlass an dessen Front.
void _citySocket(Canvas c, Saucer saucer, TableTheme th, double now) {
  final x = saucer.spec.x;
  final held = saucer.held != null;
  final box = Rect.fromLTWH(x - 1.3, saucer.spec.y - 3.0, 2.6, 3.10);
  _cityGlow(c, Offset(x, 4.797), 1.35, th.accent, held ? .28 : .10);
  _cityImage(c, 'hologram', box);
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
  final chamber = RRect.fromRectAndRadius(
    Rect.fromLTWH(x - .44, .3744, .88, 1.1544),
    const Radius.circular(.30),
  );
  c.drawRRect(chamber, Paint()..color = const Color(0xFF080C11));
  c.drawRRect(
    chamber,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .045
      ..color = _steelBright,
  );
  final at = Offset(x, 1.014);
  if (on) _cityGlow(c, at, .5, th.light, .25);
  final insert = Path()
    ..moveTo(x, .8424)
    ..lineTo(x + .21, 1.1856)
    ..lineTo(x - .21, 1.1856)
    ..close();
  c.drawPath(
    insert,
    Paint()..color = on ? th.light : th.light.withValues(alpha: .28),
  );
  _cityStroke(c, insert, _steelBright.withValues(alpha: .7), .025);
}

void _cityApron(Canvas c, TableTheme th) {
  final apron = Path()
    ..moveTo(.15, 12.948)
    ..lineTo(4.16, 13.377)
    ..lineTo(4.16, 14.04)
    ..lineTo(.15, 14.04)
    ..close()
    ..moveTo(5.09, 13.377)
    ..lineTo(9.10, 12.948)
    ..lineTo(9.10, 14.04)
    ..lineTo(5.09, 14.04)
    ..close();
  c.drawPath(apron, Paint()..color = const Color(0xD92A3036));
  _cityStroke(c, apron, _steelBright.withValues(alpha: .6), .035);
  final drain = RRect.fromRectAndCorners(
    const Rect.fromLTWH(4.18, 12.909, .89, 1.17),
    topLeft: const Radius.circular(.44),
    topRight: const Radius.circular(.44),
  );
  c.drawRRect(drain, Paint()..color = const Color(0xFF030406));
  c.drawRRect(
    drain,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .055
      ..color = _steelBright,
  );
}

void _cityHeader(Canvas c, PinballTable table) {
  _cityImage(c, 'header', const Rect.fromLTWH(0, 0, 9.95, 1.80));
  _text(
    c,
    table.score.toString(),
    const Offset(4.98, .31),
    .23,
    const Color(0xFFFFB33F),
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

void _citySideLanes(Canvas c, TableTheme th, double now) {
  for (final right in [false, true]) {
    final sign = right ? -1.0 : 1.0;
    final edge = right ? PinballTable.fieldRight : 0.0;
    final out = RRect.fromRectAndRadius(
      Rect.fromLTWH(edge + sign * .40 - (right ? .27 : 0), 10.062, .27, 2.535),
      const Radius.circular(.13),
    );
    c.drawRRect(out, Paint()..color = const Color(0xCC080B10));
    for (var i = 0; i < 3; i++) {
      _cityLaneArrow(
        c,
        Offset(edge + sign * .53, 11.115 + i * .3276),
        th.light.withValues(alpha: .85),
      );
      _cityLaneArrow(
        c,
        Offset(edge + sign * 1.32, 9.867 + i * .3276),
        th.light.withValues(alpha: .85),
      );
    }
    final post = Offset(edge + sign * .94, 9.672);
    c.drawCircle(post, .13, Paint()..color = _steelDark);
    c.drawCircle(post, .09, Paint()..color = _steelBright);
    c.drawCircle(post, .025, Paint()..color = Colors.black);
  }
}
