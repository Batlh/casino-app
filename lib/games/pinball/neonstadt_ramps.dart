part of 'pinball_art.dart';

// Echte Fahrbahnflächen mit Texturkoordinaten, extrudierten Acrylwänden und
// Höhenprofil. Alle Punkte stammen aus demselben RampSpec wie die Kugelfahrt.
const _cityHeightStep = .08;
const _cityHeightProjection = .42;
Offset _cityProject(Offset p, double height) =>
    p - Offset(0, height * _cityHeightProjection);

class _CityMeshBatch {
  _CityMeshBatch(this.texture, this.role, this.vertices);
  final String texture;
  final int role; // 0: hintere Wand, 1: Fahrbahn, 2: vordere Wand, 3: Geländer
  final ui.Vertices vertices;
}

class _CityMeshData {
  final positions = <Offset>[];
  final uv = <Offset>[];
  final colors = <Color>[];
}

class _CityRampScene {
  _CityRampScene(PinballTable table) {
    final parts = <(int, int, String, double), _CityMeshData>{};
    final assets = NeonstadtAssets.instance;
    void quad(
      String texture,
      int role,
      double height,
      double alpha,
      List<Offset> corners,
      double u0,
      double u1, {
      bool reverseV = false,
    }) {
      final level = math.max(0, (height / _cityHeightStep).floor());
      maxLevel = math.max(maxLevel, level);
      final data = parts.putIfAbsent((
        level,
        role,
        texture,
        alpha,
      ), _CityMeshData.new);
      final source = assets.source(texture);
      final v0 = reverseV ? source.bottom : source.top;
      final v1 = reverseV ? source.top : source.bottom;
      final tex = [
        Offset(u0, v0),
        Offset(u1, v0),
        Offset(u1, v1),
        Offset(u0, v1),
      ];
      for (final i in [0, 1, 2, 0, 2, 3]) {
        data.positions.add(corners[i]);
        data.uv.add(tex[i]);
        data.colors.add(Colors.white.withValues(alpha: alpha));
      }
    }

    for (final ramp in table.ramps) {
      final spec = ramp.spec;
      final pts = spec.path;
      final normals = <Offset>[];
      for (var i = 0; i < pts.length; i++) {
        final a = pts[math.max(0, i - 1)];
        final b = pts[math.min(pts.length - 1, i + 1)];
        final d = Offset(b.x - a.x, b.y - a.y);
        normals.add(
          d.distance == 0
              ? const Offset(1, 0)
              : Offset(-d.dy, d.dx) / d.distance,
        );
      }
      var distance = 0.0;
      for (var i = 1; i < pts.length; i++) {
        final a = Offset(pts[i - 1].x, pts[i - 1].y);
        final b = Offset(pts[i].x, pts[i].y);
        final length = (b - a).distance;
        final h0 = spec.heights.isEmpty ? 0.0 : spec.heights[i - 1];
        final h1 = spec.heights.isEmpty ? 0.0 : spec.heights[i];
        final height = (h0 + h1) / 2;
        final wire = distance >= ramp.length * spec.wireStart - .001;
        // Der Acrylboden verjüngt sich vor der Übergabe auf die Drahtbreite.
        // Gleiche Breite an gemeinsamen Stützpunkten verhindert Spalten.
        double widthAt(double d) =>
            .66 +
            (spec.deckWidth - .66) *
                ((ramp.length * spec.wireStart - d) / .6).clamp(0.0, 1.0);
        final w0 = widthAt(distance), w1 = widthAt(distance + length);
        final width = (w0 + w1) / 2;
        final n0 = normals[i - 1], n1 = normals[i];
        final l0 = _cityProject(a + n0 * w0 / 2, h0);
        final l1 = _cityProject(b + n1 * w1 / 2, h1);
        final r0 = _cityProject(a - n0 * w0 / 2, h0);
        final r1 = _cityProject(b - n1 * w1 / 2, h1);
        final u0 = distance * 128, u1 = (distance + length) * 128;
        if (!wire) {
          quad('ramp_bed', 1, height, .36, [l0, l1, r1, r0], u0, u1);
          final wallHeight = spec.sideHeight;
          for (final side in [-1.0, 1.0]) {
            final p0 = side > 0 ? l0 : r0;
            final p1 = side > 0 ? l1 : r1;
            final t0 = p0 - Offset(0, wallHeight * _cityHeightProjection);
            final t1 = p1 - Offset(0, wallHeight * _cityHeightProjection);
            final near = (n0.dy + n1.dy) * side >= 0;
            quad(
              'ramp_wall',
              near ? 2 : 0,
              height,
              near ? .88 : .68,
              [p0, p1, t1, t0],
              u0,
              u1,
              reverseV: true,
            );
            quad(
              'chrome',
              3,
              height + wallHeight * .2,
              1,
              [t0 + n0 * .035, t1 + n1 * .035, t1 - n1 * .035, t0 - n0 * .035],
              u0,
              u1,
            );
          }
        } else {
          for (final side in [-1.0, 1.0]) {
            final p0 = side > 0 ? l0 : r0;
            final p1 = side > 0 ? l1 : r1;
            quad(
              'chrome',
              3,
              height,
              1,
              [p0 + n0 * .045, p1 + n1 * .045, p1 - n1 * .045, p0 - n0 * .045],
              u0,
              u1,
            );
            // Zweite Schiene macht die räumliche Drahtwanne erkennbar.
            final low0 = p0 + const Offset(0, .09),
                low1 = p1 + const Offset(0, .09);
            quad(
              'chrome',
              0,
              math.max(0, height - .12),
              .9,
              [
                low0 + n0 * .025,
                low1 + n1 * .025,
                low1 - n1 * .025,
                low0 - n0 * .025,
              ],
              u0,
              u1,
            );
          }
          if (i % 4 == 0) {
            final tangent = length == 0 ? const Offset(0, 1) : (b - a) / length;
            quad(
              'chrome',
              1,
              height,
              .9,
              [
                l0 - tangent * .02,
                r0 - tangent * .02,
                r0 + tangent * .02,
                l0 + tangent * .02,
              ],
              0,
              width * 128,
            );
          }
        }
        distance += length;
      }
    }
    for (final entry in parts.entries) {
      final (level, role, texture, _) = entry.key;
      final data = entry.value;
      levels
          .putIfAbsent(level, () => [])
          .add(
            _CityMeshBatch(
              texture,
              role,
              ui.Vertices(
                ui.VertexMode.triangles,
                data.positions,
                textureCoordinates: data.uv,
                colors: data.colors,
              ),
            ),
          );
    }
    for (final batches in levels.values) {
      batches.sort((a, b) => a.role.compareTo(b.role));
    }
    for (final texture in ['ramp_bed', 'ramp_wall', 'chrome']) {
      shaders[texture] = ui.ImageShader(
        assets.image(texture),
        TileMode.repeated,
        TileMode.clamp,
        Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      );
    }
  }
  final levels = <int, List<_CityMeshBatch>>{};
  final shaders = <String, ui.ImageShader>{};
  int maxLevel = 0;
}

final _cityRampScenes = <TableSpec, _CityRampScene>{};

void _cityGroundArchitecture(Canvas c, PinballTable table) {
  for (final ramp in table.ramps) {
    final path = Path()..moveTo(ramp.spec.path.first.x, ramp.spec.path.first.y);
    for (final p in ramp.spec.path.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    c.save();
    c.translate(.10, .14);
    _cityStroke(
      c,
      path,
      Colors.black.withValues(alpha: .28),
      ramp.spec.deckWidth + .12,
    );
    c.restore();
  }
  for (final support in table.spec.supports) {
    final height = support.height * _cityHeightProjection + .15;
    _cityImage(
      c,
      'support',
      Rect.fromLTWH(support.x - .17, support.y - height, .34, height + .06),
    );
    final foot = Offset(support.x, support.y);
    var nearest = const Offset(0, 0);
    var nearestHeight = support.height;
    var best = double.infinity;
    for (final ramp in table.ramps) {
      for (var i = 0; i < ramp.spec.path.length; i++) {
        final p = ramp.spec.path[i];
        final point = Offset(p.x, p.y);
        final distance = (point - foot).distanceSquared;
        if (distance >= best) continue;
        best = distance;
        final toward = foot - point;
        final edge = toward.distance == 0
            ? point
            : point + toward / toward.distance * ramp.spec.deckWidth / 2;
        nearestHeight = ramp.spec.heights.isEmpty ? 0 : ramp.spec.heights[i];
        nearest = _cityProject(edge, nearestHeight);
      }
    }
    _cityMetalSegment(c, _cityProject(foot, support.height), nearest, .085);
  }
}

void _cityDrawRampLevels(
  Canvas c,
  PinballTable table,
  double now,
  void Function(Offset, double) paintBall,
) {
  final scene = _cityRampScenes.putIfAbsent(
    table.spec,
    () => _CityRampScene(table),
  );
  final paint = Paint()..filterQuality = FilterQuality.high;
  final last = math.max(
    scene.maxLevel,
    table.balls.fold<int>(
      0,
      (m, b) => math.max(m, (b.elevation / _cityHeightStep).floor()),
    ),
  );
  for (var level = 0; level <= last; level++) {
    final batches = scene.levels[level] ?? const <_CityMeshBatch>[];
    void draw(_CityMeshBatch batch) {
      paint.shader = scene.shaders[batch.texture];
      c.drawVertices(batch.vertices, BlendMode.modulate, paint);
    }

    for (final batch in batches) {
      if (batch.role <= 1) draw(batch);
    }
    for (final ball in table.balls) {
      if (!ball.raised || (ball.elevation / _cityHeightStep).floor() != level)
        continue;
      final p = ball.pos;
      final projected = _cityProject(Offset(p.x, p.y), ball.elevation);
      c.drawCircle(
        Offset(p.x + .1, p.y + .12),
        PinballTable.ballRadius,
        Paint()..color = Colors.black.withValues(alpha: .28),
      );
      paintBall(projected, PinballTable.ballRadius);
    }
    for (final ramp in table.ramps) {
      if (level == 0 && ramp.flash > .01) {
        final entry = ramp.spec.path.first;
        _cityGlow(
          c,
          Offset(entry.x, entry.y),
          .8,
          table.spec.theme.ramp,
          ramp.flash * .25,
        );
      }
      for (var i = 0; i < 3; i++) {
        final distance = (now * 3 + i * ramp.length / 3) % ramp.length;
        final height = ramp.heightAt(distance);
        if ((height / _cityHeightStep).floor() != level) continue;
        final p = ramp.at(distance);
        final position = _cityProject(Offset(p.x, p.y), height);
        c.drawCircle(
          position,
          .035,
          Paint()..color = table.spec.theme.ramp.withValues(alpha: .75),
        );
      }
    }
    for (final batch in batches) {
      if (batch.role > 1) draw(batch);
    }
  }
}

void _cityTargetBank(Canvas c, TargetBank bank) {
  final center =
      bank.targets.fold<Offset>(
        Offset.zero,
        (p, target) => p + Offset(target.c.x, target.c.y),
      ) /
      bank.targets.length.toDouble();
  c.save();
  c.translate(center.dx, center.dy);
  c.rotate(bank.spec.angle);
  _cityImage(
    c,
    bank.spec.id == 'links' ? 'target_panel_red' : 'target_panel',
    const Rect.fromLTWH(-.90, -.36, 1.80, .72),
  );
  c.restore();
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
