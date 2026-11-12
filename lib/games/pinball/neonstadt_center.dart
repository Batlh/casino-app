part of 'pinball_art.dart';

void _cityPlateau(
  Canvas c,
  PinballTable table,
  double now,
  void Function(Offset, double) paintBall,
) {
  // Lokale Plateaukoordinaten sind bereits auf die Schrägsicht projiziert.
  // Der Höhenversatz wird an den Auf- und Abfahrten genau einmal angewendet.
  final deck = Path()
    ..moveTo(3.05, .28)
    ..lineTo(7.6, .28)
    ..lineTo(7.6, 3.90)
    ..lineTo(6.4, 3.90)
    ..lineTo(6.4, 3.65)
    ..lineTo(5.25, 3.35)
    ..lineTo(4.1, 3.65)
    ..lineTo(4.1, 3.90)
    ..lineTo(3.05, 3.90)
    ..close();
  c.drawPath(
    deck.shift(const Offset(.12, .35)),
    Paint()
      ..color = const Color(0xB0000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .08),
  );
  c.drawPath(
    deck.shift(const Offset(0, .25)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF151E28), Color(0xFF6F8292)],
      ).createShader(deck.getBounds()),
  );
  c.drawPath(
    deck,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF53616B),
          Color(0xFF1C2C3C),
          Color(0xFF374654),
          Color(0xFF14222D),
        ],
      ).createShader(deck.getBounds()),
  );
  _cityStroke(c, deck, const Color(0xFF8096A4), .045);
  for (final line in PinballTable.cityPlateauRim) {
    final pts = [for (final p in line) Offset(p.x, p.y)];
    _cityStroke(c, _cityPolyline(pts), _steelDark, .07);
    _cityStroke(c, _cityPolyline(pts), _steelBright, .028);
  }
  for (final p in [
    const Offset(3.20, .42),
    const Offset(7.43, .42),
    const Offset(3.22, 2.80),
    const Offset(7.43, 2.80),
    const Offset(4.15, 3.50),
    const Offset(6.35, 3.50),
  ]) {
    _cityScrew(c, p, radius: .04);
  }
  for (final x in [3.65, 6.95]) {
    final start = Offset(x, 3.9), end = Offset(x < 5 ? 3.45 : 7.1, 4.70);
    final chute = Path()
      ..moveTo(start.dx - .28, start.dy)
      ..lineTo(end.dx - .28, end.dy)
      ..lineTo(end.dx + .28, end.dy)
      ..lineTo(start.dx + .28, start.dy)
      ..close();
    c.drawPath(
      chute,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF536572), Color(0xFF242F39), Color(0xFFA4B2BA)],
        ).createShader(chute.getBounds()),
    );
    _cityStroke(c, chute, _steelBright, .023);
    _cityMetalSegment(
      c,
      start - const Offset(.3, 0),
      start + const Offset(.3, 0),
      .09,
    );
  }
  final plate = RRect.fromRectAndRadius(
    const Rect.fromLTWH(3.95, .31, 2.0, .90),
    const Radius.circular(.1),
  );
  c.drawRRect(plate, Paint()..color = const Color(0xFF172631));
  c.drawRRect(
    plate,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .035
      ..color = _steelBright,
  );
  for (final x in [3.98, 5.92]) _cityScrew(c, Offset(x, .44), radius: .03);
  for (final x in [3.78, 6.08]) {
    final post = SupportSpec(x, 1.10, 1.40, radius: .065);
    _cityMountedRampPost(c, post, head: false);
    _cityMountedRampPost(c, post, head: true);
  }
  for (final ramp in table.ramps.where((r) => r.spec.id.endsWith('_innen'))) {
    final end = ramp.spec.path.last;
    final hole = Rect.fromCenter(
      center: Offset(end.x, end.y - PinballTable.cityPlateauHeight * .42),
      width: .49,
      height: .24,
    );
    c.drawOval(hole, Paint()..color = const Color(0xFF03080C));
    c.drawOval(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .025
        ..color = _steelBright,
    );
  }
  for (final bumper in table.bumpers) {
    _cityBumper(
      c,
      Offset(bumper.x, bumper.y),
      bumper.spec.radius,
      table.spec.theme,
      bumper.glow,
      bumper.glow,
    );
  }
  for (final b in table.balls.where((b) => b.onPlateau)) {
    final at = Offset(b.pos.x, b.pos.y);
    c.drawOval(
      Rect.fromCenter(
        center: at + const Offset(.06, .07),
        width: .43,
        height: .24,
      ),
      Paint()..color = const Color(0x66000000),
    );
    paintBall(at, PinballTable.ballRadius);
  }
}

void _cityCenterFloor(Canvas c, PinballTable table) {
  final x = table.saucers.first.spec.x;
  // Metallführungen bilden drei getrennte Durchlässe vor dem tieferen Sockel.
  for (final sign in [-1.0, 1.0]) {
    final lip = Path()
      ..moveTo(x + sign * .69, 5.15)
      ..lineTo(x + sign * .36, 4.45);
    _cityStroke(c, lip, _steelDark, .12);
    _cityStroke(c, lip, _steelBright, .05);
    final at = Offset(x + sign * .93, 5.0),
        post = SupportSpec(at.dx, at.dy, .9, radius: .075);
    _cityMountedRampPost(c, post, head: false);
    _cityMountedRampPost(c, post, head: true);
    _cityStroke(
      c,
      Path()
        ..moveTo(x + sign * .8, 4.7)
        ..lineTo(x + sign * 1.45, 5.18),
      const Color(0xFFFFD13E),
      .035,
    );
  }
  final grate = Rect.fromLTWH(x - .29, 4.68, .58, .40);
  c.drawRect(grate, Paint()..color = const Color(0xFF151B20));
  for (var i = 0; i < 5; i++)
    _cityMetalSegment(
      c,
      Offset(grate.left, grate.top + i * .09),
      Offset(grate.right, grate.top + i * .09),
      .022,
    );
  _cityGlow(c, grate.center, .6, table.spec.theme.light, .18);
  // Drucklinien ergänzen das verlängerte Mittelfeld; Hintergrund und Streifen bleiben unverändert.
  for (final right in [false, true]) {
    final sign = right ? -1.0 : 1.0, base = right ? 6.4 : 3.05;
    for (var i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(base + sign * i * .13, 5.65)
        ..lineTo(base + sign * i * .13, 6.65 + i * .2)
        ..lineTo(base + sign * (.45 + i * .13), 7.15 + i * .2)
        ..lineTo(base + sign * (.45 + i * .13), 10.55 - i * .12)
        ..lineTo(base + sign * (.85 + i * .13), 11.15 - i * .12);
      final color = i.isEven ? const Color(0xFF26E5F4) : _signalPink;
      _cityStroke(c, path, color.withValues(alpha: .18), .055);
      _cityStroke(c, path, color.withValues(alpha: .65), .012);
      c.drawCircle(
        Offset(base + sign * (.85 + i * .13), 11.15 - i * .12),
        .035,
        Paint()..color = color,
      );
    }
  }
}

void _cityInsertLamp(
  Canvas c,
  Offset at,
  String label,
  bool on,
  Color color, {
  double width = .9,
  bool blink = false,
  double now = 0,
}) {
  final lit = on && (!blink || (now * 6).floor().isEven);
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(center: at, width: width, height: .27),
    const Radius.circular(.07),
  );
  c.drawRRect(box, Paint()..color = const Color(0xFF080B11));
  c.drawRRect(
    box,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .027
      ..color = _steelBright,
  );
  final inner = box.deflate(.045);
  c.drawRRect(inner, Paint()..color = color.withValues(alpha: lit ? .72 : .10));
  if (lit) _cityGlow(c, at, width * .7, color, .20);
  _text(
    c,
    label,
    at,
    .082,
    lit ? const Color(0xFFFFF6D5) : const Color(0xFF849299),
    fontFamily: 'Barlow',
  );
}

void _cityModeInserts(Canvas c, PinballTable table, double now) {
  final r = table.city!;
  for (var i = 0; i < 8; i++) {
    final at = Offset(i.isEven ? 4.0 : 5.7, 7.35 + (i ~/ 2) * .62);
    final on =
        r.completed.contains(i) || (r.active == i && (now * 6).floor().isEven);
    final diamond = Path()
      ..moveTo(at.dx - .53, at.dy)
      ..lineTo(at.dx - .32, at.dy - .15)
      ..lineTo(at.dx + .32, at.dy - .15)
      ..lineTo(at.dx + .53, at.dy)
      ..lineTo(at.dx + .32, at.dy + .15)
      ..lineTo(at.dx - .32, at.dy + .15)
      ..close();
    c.drawPath(
      diamond,
      Paint()
        ..shader = RadialGradient(
          colors: [
            table.spec.theme.light.withValues(alpha: on ? .92 : .22),
            const Color(0xFF382E12),
          ],
        ).createShader(diamond.getBounds()),
    );
    _cityStroke(c, diamond, const Color(0xFFB4A66F), .024);
    _text(
      c,
      '${i + 1}',
      at,
      .13,
      on ? const Color(0xFF151A20) : const Color(0xFFB4A66F),
      fontFamily: 'Barlow',
    );
    _text(
      c,
      NeonstadtRules.titles[i].toUpperCase(),
      at + const Offset(0, .25),
      .085,
      const Color(0xFFC8D4D7),
      fontFamily: 'Barlow',
    );
    if (on) _cityGlow(c, at, .63, table.spec.theme.light, .15);
  }
  _cityInsertLamp(
    c,
    const Offset(4.85, 10.05),
    'SYSTEMABSTURZ',
    r.wizard || r.completed.length == 8,
    _signalPink,
    width: 2.0,
    blink: r.wizard,
    now: now,
  );
  _text(
    c,
    'LOCK',
    const Offset(5.22, 6.02),
    .09,
    _steelBright,
    fontFamily: 'Barlow',
  );
  for (var i = 0; i < 3; i++) {
    final at = Offset(4.4 + i * .82, 6.28), on = r.locks > i;
    c.drawCircle(
      at,
      .17,
      Paint()
        ..shader = RadialGradient(
          colors: [
            table.spec.theme.light.withValues(alpha: on ? .95 : .2),
            const Color(0xFF42361C),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: .17)),
    );
    c.drawCircle(
      at,
      .18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .022
        ..color = const Color(0xFF9D9270),
    );
    _text(
      c,
      '${i + 1}',
      at,
      .12,
      on ? const Color(0xFF18202A) : _steelBright,
      fontFamily: 'Barlow',
    );
  }
  _cityInsertLamp(
    c,
    const Offset(5.27, 5.73),
    'EXTRA-KUGEL',
    r.extraLit,
    _signalPink,
    width: 1.18,
    blink: r.extraLit,
    now: now,
  );
  _cityInsertLamp(
    c,
    const Offset(5.27, 6.74),
    'MODUS STARTEN',
    r.active == null && !r.wizard,
    table.spec.theme.light,
    width: 1.30,
  );
}

Color _cityShotColor(PinballTable table, String id, double now) {
  final state = table.city!.shotState(id);
  final on =
      state == NeonstadtLamp.an ||
      state == NeonstadtLamp.blinkend && (now * 6).floor().isEven;
  return table.spec.theme.light.withValues(alpha: on ? 1 : .13);
}

void _citySafetyAndKickback(Canvas c, PinballTable table, double now) {
  final y = 16.10 - table.cityKickbackFlash * .50;
  final housing = RRect.fromRectAndRadius(
    const Rect.fromLTWH(.37, 15.97, .32, .40),
    const Radius.circular(.035),
  );
  c.drawRRect(housing, Paint()..color = _steelDark);
  c.drawRRect(
    housing,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .03
      ..color = _steelBright,
  );
  _cityMetalSegment(c, const Offset(.53, 16.34), Offset(.53, y), .09);
  _cityMetalSegment(c, Offset(.39, y), Offset(.67, y), .11);
  for (final x in [.40, .66]) _cityScrew(c, Offset(x, 16.33), radius: .025);
  if (table.cityKickbackFlash > 0)
    _cityGlow(
      c,
      Offset(.53, y),
      .65,
      table.spec.theme.light,
      table.cityKickbackFlash * .4,
    );
  if (table.citySaveActive)
    _cityInsertLamp(
      c,
      const Offset(4.625, 16.62),
      'NOCHMAL SCHIESSEN',
      true,
      table.spec.theme.light,
      width: 2.0,
      blink: true,
      now: now,
    );
}

void _cityEntryArrows(Canvas c, PinballTable table, double now) {
  for (final ramp in table.ramps.where(
    (r) => [
      'links',
      'rechts',
      'umlauf_links',
      'umlauf_rechts',
    ].contains(r.spec.id),
  )) {
    final spec = ramp.spec;
    _cityShotArrow(
      c,
      Offset((spec.a.x + spec.b.x) / 2, spec.a.y + .42),
      -math.pi / 2,
      _cityShotColor(table, spec.id, now),
      size: .22,
    );
  }
}
