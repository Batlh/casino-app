part of 'pinball_art.dart';

// Dieselben Mittellinien und Höhen bestimmen Acryl, Draht und Kugelfahrt.
const _cityHeightProjection = .42;
Offset _cityProject(Offset p, double height) =>
    p - Offset(0, height * _cityHeightProjection);

Path _cityPolyline(List<Offset> points) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

({List<Offset> centers, List<Offset> normals, int wire}) _cityRampGeometry(
  Ramp ramp,
) {
  final s = ramp.spec;
  final centers = <Offset>[], normals = <Offset>[];
  var distance = 0.0, wire = s.path.length;
  for (var i = 0; i < s.path.length; i++) {
    final p = s.path[i];
    if (i > 0)
      distance += (Offset(p.x, p.y) - Offset(s.path[i - 1].x, s.path[i - 1].y))
          .distance;
    if (s.wireStart < 1 &&
        wire == s.path.length &&
        distance + .00001 >= ramp.length * s.wireStart)
      wire = i;
    centers.add(
      _cityProject(Offset(p.x, p.y), s.heights.isEmpty ? 0 : s.heights[i]),
    );
  }
  for (var i = 0; i < centers.length; i++) {
    final delta =
        centers[math.min(i + 1, centers.length - 1)] -
        centers[math.max(0, i - 1)];
    normals.add(
      delta.distance < .00001
          ? const Offset(1, 0)
          : Offset(-delta.dy, delta.dx) / delta.distance,
    );
  }
  return (centers: centers, normals: normals, wire: wire);
}

void _cityGroundArchitecture(Canvas c, PinballTable table) {
  // Die Umläufe sind Bodenkanäle; nur L1s Eckstück und R1s Bogen steigen an.
  for (final ramp in table.ramps) {
    final s = ramp.spec;
    if (s.id.startsWith('umlauf_')) {
      final pts = [
        for (final p in s.path.take(s.acrylicStart + 1)) Offset(p.x, p.y),
      ];
      final path = _cityPolyline(pts);
      _cityStroke(c, path, const Color(0x55393D46), s.deckWidth);
      _cityStroke(c, path, const Color(0x30E9C941), s.deckWidth - .13);
      for (final sign in [-1.0, 1.0]) {
        final edge = [
          for (var i = 0; i < pts.length; i++)
            pts[i] + Offset(sign * (s.deckWidth / 2 + .04), 0),
        ];
        _cityStroke(c, _cityPolyline(edge), _steelDark, .085);
        _cityStroke(c, _cityPolyline(edge), const Color(0xFFFFCA35), .028);
      }
      for (var i = 5; i < pts.length; i += 10) {
        for (final sign in [-1.0, 1.0]) {
          final p = pts[i] + Offset(sign * (s.deckWidth / 2 + .12), 0);
          _cityMountedRampPost(c, SupportSpec(p.dx, p.dy, .38), head: false);
          _cityMountedRampPost(c, SupportSpec(p.dx, p.dy, .38), head: true);
        }
      }
    }
    if (s.skillBand > 0 || s.id == 'umlauf_rechts') continue;
    final geom = _cityRampGeometry(ramp);
    final pts = geom.centers.sublist(
      s.acrylicStart,
      s.renderEnd < 0 ? geom.centers.length : s.renderEnd + 1,
    );
    c.save();
    c.translate(.10, .17);
    _cityStroke(
      c,
      _cityPolyline(pts),
      const Color(0x24000000),
      s.deckWidth + .12,
    );
    c.restore();
  }
  _cityEntryCollars(c, table);
}

void _cityAcrylic(
  Canvas c,
  RampSpec s,
  List<Offset> centers,
  List<Offset> normals,
  int start,
  int end,
) {
  if (end - start < 2) return;
  final inner = s.id.endsWith('_innen');
  final edge = inner
      ? (s.id.startsWith('links') ? _signalPink : const Color(0xFF43F4FF))
      : const Color(0xFFFFD33D);
  final left = <Offset>[], right = <Offset>[];
  for (var i = start; i < end; i++) {
    final headT = ((i - start) / (end - start) - .38) / .28;
    final u = headT.clamp(0.0, 1.0), narrow = u * u * (3 - 2 * u);
    final half = s.wireStart < 1
        ? (s.deckWidth + (.64 - s.deckWidth) * narrow) / 2
        : s.deckWidth / 2;
    left.add(centers[i] + normals[i] * half);
    right.add(centers[i] - normals[i] * half);
  }
  final bed = _cityPolyline(left);
  for (final p in right.reversed) {
    bed.lineTo(p.dx, p.dy);
  }
  bed.close();
  c.drawPath(
    bed.shift(const Offset(0, .065)),
    Paint()..color = edge.withValues(alpha: .12),
  );
  c.drawPath(
    bed,
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: .22),
          edge.withValues(alpha: .10),
          Colors.white.withValues(alpha: .045),
          _signalPink.withValues(alpha: inner ? .07 : .12),
          Colors.white.withValues(alpha: .23),
        ],
        stops: const [0, .18, .50, .82, 1],
      ).createShader(bed.getBounds()),
  );
  for (final pts in [left, right]) {
    final top = [
      for (var i = 0; i < pts.length; i++)
        pts[i] -
            Offset(
              0,
              s.sideHeight *
                  _cityHeightProjection *
                  (s.acrylicStart > 0 ? 1 : ((start + i) / 5).clamp(0.0, 1.0)),
            ),
    ];
    final wall = _cityPolyline(pts);
    for (final p in top.reversed) {
      wall.lineTo(p.dx, p.dy);
    }
    wall.close();
    c.drawPath(
      wall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .55),
            edge.withValues(alpha: .26),
            _signalPink.withValues(alpha: .08),
            Colors.white.withValues(alpha: .33),
          ],
          stops: const [0, .18, .74, 1],
        ).createShader(wall.getBounds()),
    );
    _cityStroke(c, _cityPolyline(pts), const Color(0xAFC4E4ED), .038);
    _cityStroke(
      c,
      _cityPolyline([for (final p in pts) p + const Offset(0, .065)]),
      const Color(0x7F8096A0),
      .023,
    );
    _cityStroke(c, _cityPolyline(top), edge.withValues(alpha: .23), .12);
    _cityStroke(c, _cityPolyline(top), edge, .035);
    _cityStroke(c, _cityPolyline(top), const Color(0xDDFFFFFF), .012);
  }
  c.save();
  c.clipPath(bed);
  _cityStroke(
    c,
    _cityPolyline([
      for (var i = start; i < end; i++)
        centers[i] + normals[i] * s.deckWidth * .27,
    ]),
    const Color(0x4FFFFFFF),
    .075,
  );
  c.restore();
  // Die Zunge liegt flach auf dem Boden, die Seitenwände steigen dahinter an.
  if (start == 0) {
    final at = centers.first, n = normals.first;
    final tongue = Path()
      ..moveTo(
        (at - n * s.deckWidth * .48).dx,
        (at - n * s.deckWidth * .48).dy + .08,
      )
      ..lineTo(
        (at + n * s.deckWidth * .48).dx,
        (at + n * s.deckWidth * .48).dy + .08,
      )
      ..lineTo(
        (centers[2] + normals[2] * s.deckWidth * .48).dx,
        (centers[2] + normals[2] * s.deckWidth * .48).dy,
      )
      ..lineTo(
        (centers[2] - normals[2] * s.deckWidth * .48).dx,
        (centers[2] - normals[2] * s.deckWidth * .48).dy,
      )
      ..close();
    c.drawPath(
      tongue,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF677A85), Color(0xFFE8F4F6), Color(0xFF8297A1)],
        ).createShader(tongue.getBounds()),
    );
    _cityMetalSegment(
      c,
      at - n * s.deckWidth * .48,
      at + n * s.deckWidth * .48,
      .045,
    );
    for (final sign in [-1.0, 1.0]) {
      c.drawCircle(
        at + n * s.deckWidth * .36 * sign,
        .025,
        Paint()..color = _steelDark,
      );
    }
  }
}

void _cityWire(
  Canvas c,
  List<Offset> centers,
  List<Offset> normals,
  int start,
) {
  for (final offset in [-.32, -.11, .11, .32]) {
    final path = _cityPolyline([
      for (var i = start; i < centers.length; i++)
        centers[i] + normals[i] * offset,
    ]);
    _cityStroke(c, path, _steelDark, .085);
    _cityStroke(c, path, const Color(0xFFB8C4CE), .055);
    _cityStroke(c, path, const Color(0xFFFAFFFF), .016);
  }
  for (final fraction in [0.0, .20, .43, .65, .86, 1.0]) {
    final i = start + ((centers.length - 1 - start) * fraction).round(),
        at = centers[i],
        n = normals[i];
    _cityMetalSegment(c, at - n * .36, at + n * .36, .065);
    for (final sign in [-1.0, 1.0]) {
      final clamp = at + n * .32 * sign;
      c.drawOval(
        Rect.fromCenter(center: clamp, width: .10, height: .12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .025
          ..color = _steelBright,
      );
    }
  }
  final i = start + ((centers.length - start) * .22).round();
  final switchAt = centers[i];
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: switchAt + normals[i] * .38,
        width: .18,
        height: .30,
      ),
      const Radius.circular(.035),
    ),
    Paint()..color = const Color(0xFF118DDF),
  );
  _cityMetalSegment(
    c,
    switchAt + normals[i] * .38,
    switchAt - normals[i] * .16,
    .026,
  );
  for (final at in [
    centers.firstWhere((p) => p == centers[start]),
    centers.last,
  ]) {
    c.drawCircle(at, .025, Paint()..color = _steelBright);
  }
}

void _cityDrawRampLevels(
  Canvas c,
  PinballTable table,
  double now,
  void Function(Offset, double) paintBall,
) {
  // Zuerst sämtliche Acrylkörper, danach sämtliche überquerenden Drahtbündel.
  for (final ramp in table.ramps) {
    final s = ramp.spec;
    if (s.skillBand > 0 || s.id == 'umlauf_rechts') continue;
    final geom = _cityRampGeometry(ramp);
    for (final post in table.spec.supports.where((p) => p.rampId == s.id)) {
      _cityMountedRampPost(c, post, head: false);
    }
    final end = s.renderEnd >= 0
        ? s.renderEnd + 1
        : math.min(geom.wire + 1, geom.centers.length);
    _cityAcrylic(c, s, geom.centers, geom.normals, s.acrylicStart, end);
    for (final post in table.spec.supports.where((p) => p.rampId == s.id)) {
      _cityMountedRampPost(c, post, head: true);
      if (post.baseHeight == 0) {
        final cap = _cityProject(Offset(post.x, post.y), post.height);
        var nearest = geom.centers.first, best = double.infinity;
        for (var i = 0; i < end; i++) {
          final delta = cap - geom.centers[i],
              edge =
                  geom.centers[i] +
                  geom.normals[i] *
                      ((delta.dx * geom.normals[i].dx +
                                  delta.dy * geom.normals[i].dy) >=
                              0
                          ? 1.0
                          : -1.0) *
                      s.deckWidth /
                      2;
          final distance = (cap - edge).distanceSquared;
          if (distance < best) {
            best = distance;
            nearest = edge;
          }
        }
        _cityMetalSegment(c, cap, nearest, .055);
      }
    }
    if (ramp.flash > .01)
      _cityGlow(
        c,
        geom.centers.first,
        .6,
        const Color(0xFFFFD33D),
        ramp.flash * .2,
      );
  }
  for (final ramp in table.ramps.where((r) => r.spec.wireStart < 1)) {
    final geom = _cityRampGeometry(ramp);
    _cityWire(c, geom.centers, geom.normals, geom.wire);
    final end = ramp.spec.path.last;
    final post = SupportSpec(end.x + .37, end.y, .45, rampId: ramp.spec.id);
    _cityMountedRampPost(c, post, head: false);
    _cityMountedRampPost(c, post, head: true);
    _cityMetalSegment(
      c,
      geom.centers.last,
      Offset(post.x, post.y - .45 * .42),
      .075,
    );
  }
  // Winkel und Schrauben verbinden R1 sichtbar mit dem Abschussgehäuse.
  final r1 = table.ramps.firstWhere((r) => r.spec.skillBand == 0);
  final geom = _cityRampGeometry(r1);
  for (final i in [3, 10, 18, 25]) {
    final at = geom.centers[i], n = geom.normals[i];
    _cityMetalSegment(c, at - n * .44, at + n * .44, .06);
    for (final sign in [-1.0, 1.0]) {
      c.drawCircle(at + n * .4 * sign, .05, Paint()..color = _steelBright);
      c.drawCircle(at + n * .4 * sign, .018, Paint()..color = _steelDark);
    }
  }
  for (final ball in table.balls.where((b) => b.raised && !b.onPlateau)) {
    final p = ball.pos;
    paintBall(
      _cityProject(Offset(p.x, p.y), ball.elevation),
      PinballTable.ballRadius,
    );
  }
}

void _cityTargetBank(
  Canvas c,
  TargetBank bank, {
  bool lit = false,
  double now = 0,
}) {
  final center =
      bank.targets.fold<Offset>(
        Offset.zero,
        (p, target) => p + Offset(target.c.x, target.c.y),
      ) /
      bank.targets.length.toDouble();
  c.save();
  final shadow = Rect.fromCenter(
    center: center + const Offset(.07, .14),
    width: 1.75,
    height: .75,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(shadow, const Radius.circular(.10)),
    Paint()
      ..color = Colors.black.withValues(alpha: .42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .06),
  );
  c.translate(center.dx, center.dy);
  c.rotate(bank.spec.angle);
  _cityImage(
    c,
    bank.spec.id == 'links' ? 'target_panel_red' : 'target_panel',
    const Rect.fromLTWH(-.825, -.50, 1.65, .78),
  );
  final faceColor = bank.spec.id == 'links'
      ? const Color(0xFFFF203C)
      : const Color(0xFF16E9FF);
  for (var i = 0; i < 3; i++) {
    final x = (i - 1) * .47;
    final on = bank.completedUntil > 0
        ? (now * 8).floor().isEven
        : bank.targets[i].lit;
    final level = on ? .9 : .45;
    final face = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - .205, -.33, .41, .44),
      const Radius.circular(.035),
    );
    _cityGlow(c, Offset(x, -.10), .43, faceColor, .24);
    c.drawRRect(
      face,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            faceColor.withValues(alpha: level),
            faceColor.withValues(alpha: level * .48),
          ],
        ).createShader(face.outerRect),
    );
    c.drawRRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .020
        ..color = faceColor,
    );
    if (bank.spec.id == 'links') {
      final arrow = Path()
        ..moveTo(x, .045)
        ..lineTo(x, -.15)
        ..lineTo(x - .105, -.245)
        ..moveTo(x, -.15)
        ..lineTo(x + .105, -.245)
        ..moveTo(x, -.15)
        ..lineTo(x, -.27);
      _cityStroke(c, arrow, const Color(0xAAFF405D), .065);
      _cityStroke(c, arrow, const Color(0xFFFFF6E6), .022);
    }
  }
  c.restore();
  final accent = bank.spec.id == 'links'
      ? _signalPink
      : const Color(0xFF43F4FF);
  _cityGlow(c, center + const Offset(0, .37), .85, accent, lit ? .55 : .10);
  c.drawLine(
    center + const Offset(-.84, .37),
    center + const Offset(.84, .37),
    Paint()
      ..color = accent
      ..strokeWidth = .035,
  );
  c.drawLine(
    center + const Offset(-.84, .49),
    center + const Offset(.84, .49),
    Paint()
      ..color = accent
      ..strokeWidth = .028,
  );
  for (final sign in [-1.0, 1.0]) {
    final post = SupportSpec(
      center.dx + sign * .94,
      center.dy - .08,
      .65,
      radius: .045,
    );
    _cityMountedRampPost(c, post, head: false);
    _cityMountedRampPost(c, post, head: true);
  }
  for (final target in bank.targets) {
    if (target.flash > .01) {
      _cityGlow(
        c,
        Offset(target.c.x, target.c.y),
        .42,
        bank.spec.id == 'links' ? _signalPink : const Color(0xFF43F4FF),
        target.flash * .45,
      );
    }
  }
}

void _cityMountedRampPost(Canvas c, SupportSpec post, {required bool head}) {
  final foot = _cityProject(Offset(post.x, post.y), post.baseHeight),
      top = _cityProject(Offset(post.x, post.y), post.height);
  if (!head) {
    c.drawOval(
      Rect.fromCenter(
        center: foot + const Offset(.09, .08),
        width: .25,
        height: .13,
      ),
      Paint()..color = const Color(0x55000000),
    );
    final shaft = Rect.fromLTRB(top.dx - .062, top.dy, top.dx + .062, foot.dy);
    c.drawRRect(
      RRect.fromRectAndRadius(shaft, const Radius.circular(.025)),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF45525D),
            Color(0xFFFFF3A8),
            Color(0xFFFFD22D),
            Color(0xFFB97909),
            Color(0xFFE3F0F4),
          ],
          stops: [0, .25, .48, .75, 1],
        ).createShader(shaft),
    );
    c.drawOval(
      Rect.fromCenter(center: foot, width: .18, height: .09),
      Paint()..color = _steelDark,
    );
    _cityMetalSegment(c, top, top + const Offset(.10, 0), .065);
  } else {
    c.drawOval(
      Rect.fromCenter(center: top, width: .18, height: .105),
      Paint()..color = const Color(0xFFB9CCD4),
    );
    c.drawCircle(top, .043, Paint()..color = const Color(0xFFECF5F8));
    _cityStroke(
      c,
      Path()
        ..moveTo(top.dx - .028, top.dy)
        ..lineTo(top.dx + .028, top.dy),
      _steelDark,
      .014,
    );
    _cityStroke(
      c,
      Path()
        ..moveTo(top.dx, top.dy - .023)
        ..lineTo(top.dx, top.dy + .023),
      _steelDark,
      .014,
    );
  }
}
