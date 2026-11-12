import 'dart:math';

import 'package:forge2d/forge2d.dart';

import '../../core/debug_log.dart';
import 'pinball_layout.dart';
import 'pinball_tables.dart';

export 'pinball_layout.dart';

/// Flippertisch mit Forge2D, ohne Oberfläche, damit er sich in Tests simulieren lässt.
/// Der Aufbau kommt aus einem [TableSpec]; Abschussbahn, Feder und Klappe sind bei allen Tischen gleich.

enum PinballEventKind {
  bumper,
  sling,
  lane,
  laneBonus,
  launch,
  drain,
  saved,
  gameOver,
  nudge,
  drop,
  dropBank,
  target,
  targetBank,
  spinner,
  saucer,
  lock,
  ramp,
  multiball,
  multiballEnd,
  jackpot,
  mission,
  missionsDone,
  extraBall,
}

class PinballEvent {
  const PinballEvent(
    this.kind, [
    this.points = 0,
    this.x = 0,
    this.y = 0,
    this.text = '',
  ]);
  final PinballEventKind kind;
  final int points;

  /// Wo es passiert ist (für Funken und Lichter).
  final double x;
  final double y;
  final String text;
}

class Bumper {
  Bumper(this.spec);
  final BumperSpec spec;
  double get x => spec.x;
  double get y => spec.y;
  double glow = 0;
}

class Sling {
  Sling(this.a, this.b, this.c, this.nx, this.ny);

  /// Dreieck; a nach b ist die federnde Seite, (nx, ny) zeigt von ihr weg.
  final Pt a;
  final Pt b;
  final Pt c;
  final double nx;
  final double ny;
  double glow = 0;
}

class Lane {
  Lane(this.spec);
  final LaneSpec spec;
  bool lit = false;
  double cooldown = 0;
  double flash = 0;
}

class DropTarget {
  DropTarget(this.c);
  final Pt c;
  bool down = false;
  Fixture? fixture;

  /// 0 oben, 1 ganz unten (für die Anzeige).
  double sink = 0;
}

class DropBank {
  DropBank(this.spec) : targets = [for (final c in spec.targets) DropTarget(c)];
  final DropBankSpec spec;
  final List<DropTarget> targets;
  double resetIn = 0;
  double flash = 0;
}

class Target {
  Target(this.c);
  final Pt c;
  bool lit = false;
  double flash = 0;
  double cooldown = 0;
}

class TargetBank {
  TargetBank(this.spec) : targets = [for (final c in spec.targets) Target(c)];
  final TargetBankSpec spec;
  final List<Target> targets;
}

class Spinner {
  Spinner(this.spec);
  final SpinnerSpec spec;

  /// Drehwinkel für die Anzeige und Restschwung in Umdrehungen pro Sekunde.
  double angle = 0;
  double speed = 0;
  double _turns = 0;
}

class Saucer {
  Saucer(this.spec);
  final SaucerSpec spec;
  Ball? held;
  double hold = 0;
  double cooldown = 0;
  double flash = 0;
}

class Ramp {
  Ramp(this.spec) {
    assert(spec.heights.isEmpty || spec.heights.length == spec.path.length);
    for (var i = 1; i < spec.path.length; i++) {
      final a = spec.path[i - 1];
      final b = spec.path[i];
      length += sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
    }
  }
  final RampSpec spec;

  /// Höheninterpolation am selben Längenparameter wie die Kugelfahrt.
  double heightAt(double distance) {
    if (spec.heights.isEmpty) return 0;
    if (distance <= 0) return spec.heights.first;
    if (distance >= length) return spec.heights.last;
    var left = distance;
    for (var i = 1; i < spec.path.length; i++) {
      final a = spec.path[i - 1];
      final b = spec.path[i];
      final segment = sqrt(
        (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y),
      );
      if (left <= segment || i == spec.path.length - 1) {
        final t = segment == 0 ? 0.0 : (left / segment).clamp(0.0, 1.0);
        return spec.heights[i - 1] +
            (spec.heights[i] - spec.heights[i - 1]) * t;
      }
      left -= segment;
    }
    return spec.heights.last;
  }

  double length = 0;
  double flash = 0;

  Pt at(double d) {
    var left = d;
    for (var i = 1; i < spec.path.length; i++) {
      final a = spec.path[i - 1];
      final b = spec.path[i];
      final seg = sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y));
      if (left <= seg || i == spec.path.length - 1) {
        final f = seg == 0 ? 0.0 : (left / seg).clamp(0.0, 1.0);
        return Pt(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f);
      }
      left -= seg;
    }
    return spec.path.last;
  }
}

class Flipper {
  Flipper(this.spec, this.body, this.joint);
  final FlipperSpec spec;
  final Body body;
  final RevoluteJoint joint;
  double get angle => body.angle;
}

/// Eine Kugel: im Feld (body), auf einer Rampe oder in einem Kickout-Loch.
class Ball {
  Body? body;
  Ramp? ramp;
  double rampPos = 0;
  Saucer? saucer;
  double still = 0;
  final Map<Object, double> sides = {};

  Pt get pos {
    final b = body;
    if (b != null) return Pt(b.position.x, b.position.y);
    final r = ramp;
    if (r != null) return r.at(rampPos);
    final s = saucer!;
    return Pt(s.spec.x, s.spec.y);
  }

  /// Auf einer Rampe liegt die Kugel über dem Tisch.
  bool get raised => ramp != null;
  double get elevation => ramp?.heightAt(rampPos) ?? 0;
}

class PinballTable {
  PinballTable({Random? rng, TableSpec? spec})
    : _rng = rng ?? Random.secure(),
      spec = spec ?? neonNightTable {
    _build();
  }

  final TableSpec spec;

  static const double width = 9.95;
  static const double fieldRight = 9.25;
  static const double height = 18;
  static const double ballRadius = 0.22;
  static const int ballsPerGame = 3;
  static const double saveSeconds = 6;

  /// Klappe zwischen Abschussbahn und Spielfeld: von der Bahn ins Feld offen,
  /// zurück geschlossen, sobald alle Kugeln im Feld sind.
  static const gate = [Pt(fieldRight, 1.9), Pt(fieldRight, 4.6)];

  final Random _rng;
  final World _world = World(Vector2(0, 9));
  late final Body _ground;
  Fixture? _gate;
  bool get gateClosed => _gate != null;

  final List<WallSpec> walls = [];
  final List<Bumper> bumpers = [];
  final List<Sling> slings = [];
  final List<Lane> lanes = [];
  final List<DropBank> dropBanks = [];
  final List<TargetBank> targetBanks = [];
  final List<Spinner> spinners = [];
  final List<Saucer> saucers = [];
  final List<Ramp> ramps = [];
  final List<Flipper> flippers = [];
  final List<Ball> balls = [];
  final List<PinballEvent> events = [];

  int score = 0;
  int ballsLeft = ballsPerGame;
  int multiplier = 1;
  bool gameOver = false;

  /// Eine Kugel liegt in der Abschussbahn und wartet.
  bool ballInLane = true;

  /// Spannung der Feder von 0 bis 1.
  double charge = 0;
  bool charging = false;
  bool leftPressed = false;
  bool rightPressed = false;
  bool _leftWas = false;
  bool _rightWas = false;
  double _saveLeft = 0;

  /// Die Ballrettung greift nur einmal pro Kugel.
  bool _saveUsed = false;

  /// Kugeln, die noch für den Multiball in die Bahn kommen, und Zeit bis zum automatischen Abschuss.
  int _toServe = 0;
  double? _autoLaunch;

  /// Gefangene Kugeln für den Multiball.
  int locks = 0;
  bool get multiball => balls.length > 1;

  /// Missionen.
  int missionIndex = 0;
  int missionProgress = 0;
  int missionLevel = 0;
  MissionSpec? get mission => spec.missions.isEmpty
      ? null
      : spec.missions[missionIndex % spec.missions.length];

  bool get ballSaveActive => _saveLeft > 0;

  Ball? get _first => balls.isEmpty ? null : balls.first;

  /// Die erste Kugel (für Tests und einfache Anzeigen).
  Pt? get ball => _first?.pos;
  double get ballSpeed => _first?.body?.linearVelocity.length ?? 0;

  /// Winkel der ersten Flipper links und rechts.
  double get leftAngle => flippers.firstWhere((f) => f.spec.left).angle;
  double get rightAngle => flippers.firstWhere((f) => !f.spec.left).angle;

  void _wall(List<Pt> pts, {double bounce = 0.35, bool visible = true}) {
    walls.add(WallSpec(pts, bounce: bounce, visible: visible));
    for (var i = 0; i + 1 < pts.length; i++) {
      final shape = EdgeShape()
        ..set(Vector2(pts[i].x, pts[i].y), Vector2(pts[i + 1].x, pts[i + 1].y));
      _ground.createFixture(
        FixtureDef(shape, friction: 0.1, restitution: bounce),
      );
    }
  }

  Fixture _segment(Pt c, double angle, double length, {double bounce = 0.3}) {
    final dx = cos(angle) * length / 2;
    final dy = sin(angle) * length / 2;
    final shape = EdgeShape()
      ..set(Vector2(c.x - dx, c.y - dy), Vector2(c.x + dx, c.y + dy));
    return _ground.createFixture(
      FixtureDef(shape, friction: 0.1, restitution: bounce),
    );
  }

  double get _shooterFloor => spec.id == 'city' ? 12.402 : 17.70;
  double get playfieldHeight => spec.playfieldHeight;
  List<Pt> get gatePoints => spec.id == 'city'
      ? const [Pt(fieldRight, 1.482), Pt(fieldRight, 3.588)]
      : gate;
  double get _laneThreshold => spec.id == 'city' ? 11.7 : 15;

  void _build() {
    _ground = _world.createBody(BodyDef());

    // Abschussbahn mit Feder, gleich bei allen Tischen
    _wall([
      Pt(fieldRight, playfieldHeight + .2),
      Pt(fieldRight, spec.id == 'city' ? 3.588 : 4.6),
    ]);
    _wall([Pt(fieldRight, _shooterFloor), Pt(width, _shooterFloor)], bounce: 0);

    for (final w in spec.walls) {
      _wall(w.points, bounce: w.bounce, visible: w.visible);
    }
    for (final support in spec.supports) {
      final shape = CircleShape()
        ..radius = support.radius
        ..position.setValues(support.x, support.y);
      _ground.createFixture(FixtureDef(shape, friction: 0.1, restitution: 0.3));
    }
    for (final b in spec.bumpers) {
      bumpers.add(Bumper(b));
      final shape = CircleShape()
        ..radius = b.radius
        ..position.setValues(b.x, b.y);
      _ground.createFixture(FixtureDef(shape, restitution: 0.6));
    }
    for (final s in spec.slings) {
      final a = s.a;
      final b = s.b;
      final c = s.c;
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final len = sqrt(dx * dx + dy * dy);
      var nx = -dy / len;
      var ny = dx / len;
      // Normale zeigt vom dritten Punkt weg
      if ((c.x - a.x) * nx + (c.y - a.y) * ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      slings.add(Sling(a, b, c, nx, ny));
      _wall([a, b, c, a], bounce: 0.8);
    }
    for (final l in spec.lanes) {
      lanes.add(Lane(l));
    }
    for (final d in spec.drops) {
      final bank = DropBank(d);
      for (final t in bank.targets) {
        t.fixture = _segment(t.c, d.angle, d.length);
      }
      dropBanks.add(bank);
    }
    for (final d in spec.targets) {
      final bank = TargetBank(d);
      for (final t in bank.targets) {
        _segment(t.c, d.angle, d.length, bounce: 0.45);
      }
      targetBanks.add(bank);
    }
    for (final s in spec.spinners) {
      spinners.add(Spinner(s));
    }
    for (final s in spec.saucers) {
      saucers.add(Saucer(s));
    }
    for (final r in spec.ramps) {
      ramps.add(Ramp(r));
    }
    for (final f in spec.flippers) {
      final body = _flipperBody(f);
      final rest = f.dir > 0 ? f.rest : -f.rest;
      final up = f.dir > 0 ? f.up : -f.up;
      final def = RevoluteJointDef()
        ..initialize(_ground, body, Vector2(f.pivot.x, f.pivot.y))
        ..enableLimit = true
        ..lowerAngle = min(rest, up)
        ..upperAngle = max(rest, up)
        ..enableMotor = true
        ..maxMotorTorque = 900
        ..motorSpeed = 0;
      def.referenceAngle = 0;
      final j = RevoluteJoint(def);
      _world.createJoint(j);
      flippers.add(Flipper(f, body, j));
    }
    _newBall();
  }

  Body _flipperBody(FlipperSpec f) {
    final body = _world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(f.pivot.x, f.pivot.y),
        bullet: true,
      ),
    );
    final l = f.length * f.dir;
    final shape = PolygonShape()
      ..set([
        Vector2(0, -f.heelHalfWidth),
        Vector2(l, -f.tipHalfWidth),
        Vector2(l, f.tipHalfWidth),
        Vector2(0, f.heelHalfWidth),
      ]);
    body.createFixture(
      FixtureDef(shape, density: 3, friction: 0.3, restitution: 0.1),
    );
    body.setTransform(
      Vector2(f.pivot.x, f.pivot.y),
      f.dir > 0 ? f.rest : -f.rest,
    );
    return body;
  }

  Body _ballBody(double x, double y) {
    final b = _world.createBody(
      BodyDef(type: BodyType.dynamic, position: Vector2(x, y), bullet: true),
    );
    b.createFixture(
      FixtureDef(
        CircleShape()..radius = ballRadius,
        density: 1,
        friction: 0.08,
        restitution: 0.3,
      ),
    );
    return b;
  }

  /// Neue Kugel in der Abschussbahn.
  void _newBall() {
    final ball = Ball()
      ..body = _ballBody(9.6, _shooterFloor - ballRadius - 0.01);
    balls.add(ball);
    _openGate();
    ballInLane = true;
    charge = 0;
  }

  void _openGate() {
    final g = _gate;
    if (g != null) {
      _ground.destroyFixture(g);
      _gate = null;
    }
  }

  Ball? get _laneBall {
    for (final b in balls) {
      final body = b.body;
      if (body != null &&
          body.position.x > fieldRight &&
          body.position.y > _laneThreshold)
        return b;
    }
    return null;
  }

  /// Kugel abschießen, sofern eine in der Bahn liegt.
  void launch() {
    final lb = _laneBall;
    if (lb == null || gameOver || !ballInLane) return;
    final strength = charge.clamp(0.15, 1.0);
    lb.body!.linearVelocity = Vector2(0, -(16.5 + 7 * strength));
    ballInLane = false;
    charging = false;
    charge = 0;
    if (!multiball) _saveLeft = _saveUsed ? 0 : saveSeconds;
    events.add(const PinballEvent(PinballEventKind.launch));
  }

  /// Rüttelt den Tisch leicht, wenn eine Kugel festhängt.
  void nudge() {
    if (gameOver) return;
    for (final b in balls) {
      final body = b.body;
      if (body == null || body.position.x > fieldRight) continue;
      body.applyLinearImpulse(Vector2((_rng.nextDouble() - 0.5) * 0.3, -0.45));
    }
    events.add(const PinballEvent(PinballEventKind.nudge));
  }

  /// Nur für Tests: erste Kugel an eine Stelle setzen.
  void debugPlaceBall(double x, double y, double vx, double vy) {
    final b = _first?.body;
    if (b == null) return;
    b.setTransform(Vector2(x, y), 0);
    b.linearVelocity = Vector2(vx, vy);
    b.angularVelocity = 0;
    ballInLane = false;
    _first!.still = 0;
  }

  void _add(
    int points,
    PinballEventKind kind, [
    double x = 0,
    double y = 0,
    String text = '',
  ]) {
    final p = points * multiplier;
    score += p;
    events.add(PinballEvent(kind, p, x, y, text));
  }

  // ---------- Missionen ----------

  void _progress(MissionKind kind, String? id, [int amount = 1]) {
    final m = mission;
    if (m == null || gameOver) return;
    final matches =
        m.kind == kind ||
        (m.kind == MissionKind.anyRamp && kind == MissionKind.ramp);
    if (!matches) return;
    if (m.id != null && m.kind != MissionKind.anyRamp && m.id != id) return;
    missionProgress += amount;
    if (missionProgress < m.count) return;
    _add(
      m.reward * (missionLevel + 1),
      PinballEventKind.mission,
      4.6,
      9,
      m.title,
    );
    missionIndex++;
    missionProgress = 0;
    if (missionIndex % spec.missions.length == 0) {
      missionLevel++;
      ballsLeft++;
      events.add(const PinballEvent(PinballEventKind.missionsDone));
      events.add(const PinballEvent(PinballEventKind.extraBall));
    }
  }

  // ---------- Simulation ----------

  void step(double dt) {
    if (charging && ballInLane) charge = min(1, charge + dt * 1.1);
    for (final f in flippers) {
      final pressed = f.spec.left ? leftPressed : rightPressed;
      f.joint.motorSpeed = f.spec.left
          ? (pressed ? -22 : 14)
          : (pressed ? 22 : -14);
    }
    // Gassenwechsel mit den Flippern wie am echten Automaten
    if (leftPressed && !_leftWas) _rotateLanes(-1);
    if (rightPressed && !_rightWas) _rotateLanes(1);
    _leftWas = leftPressed;
    _rightWas = rightPressed;

    _world.stepDt(dt);
    if (_saveLeft > 0) _saveLeft = max(0, _saveLeft - dt);
    _decay(dt);
    if (gameOver) return;

    _serve(dt);
    _updateGate();
    _updateHeld(dt);
    _updateDrops(dt);

    for (final ball in [...balls]) {
      if (ball.ramp != null) {
        _rideRamp(ball, dt);
        continue;
      }
      final b = ball.body;
      if (b == null) continue;
      final x = b.position.x;
      final y = b.position.y;

      if (!ballInLane &&
          x > fieldRight &&
          y > _shooterFloor - .9 &&
          b.linearVelocity.length < 0.5 &&
          ball == _laneBall) {
        ballInLane = true;
        if (gateClosed)
          debugLog.warn(
            'flipper',
            'Kugel trotz Klappe wieder in der Abschussbahn',
          );
      }

      _hitBumpers(b, x, y);
      _hitSlings(b, x, y);
      _hitLanes(x, y);
      _hitDrops(x, y);
      _hitTargets(x, y);
      _crossSpinners(ball, b, x, y);
      if (_crossRamps(ball, b, x, y)) continue;
      if (_catchSaucer(ball, b, x, y)) continue;

      // Festhängende Kugeln bekommen einen Schubs
      final inLane = x > fieldRight && y > _laneThreshold;
      if (!inLane && b.linearVelocity.length < 0.3) {
        ball.still += dt;
        if (ball.still > 3) {
          ball.still = 0;
          debugLog.detail(
            'flipper',
            'Kugel steht bei (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}), Schubs',
          );
          b.applyLinearImpulse(Vector2((_rng.nextDouble() - 0.5) * 0.3, -0.45));
          events.add(const PinballEvent(PinballEventKind.nudge));
        }
      } else {
        ball.still = 0;
      }

      if (y > playfieldHeight + 0.3 ||
          x < -0.5 ||
          x > width + 0.5 ||
          !x.isFinite ||
          !y.isFinite) {
        if (y <= playfieldHeight + 0.3)
          debugLog.warn(
            'flipper',
            'Kugel hat den Tisch verlassen bei ($x, $y)',
          );
        _world.destroyBody(b);
        ball.body = null;
        balls.remove(ball);
        _lost();
        if (gameOver) return;
      }
    }
  }

  void _decay(double dt) {
    for (final b in bumpers) {
      b.glow = max(0, b.glow - dt * 3);
    }
    for (final s in slings) {
      s.glow = max(0, s.glow - dt * 4);
    }
    for (final l in lanes) {
      l.flash = max(0, l.flash - dt * 2);
      if (l.cooldown > 0) l.cooldown -= dt;
    }
    for (final bank in dropBanks) {
      bank.flash = max(0, bank.flash - dt * 1.5);
      for (final t in bank.targets) {
        t.sink = t.down ? min(1, t.sink + dt * 8) : max(0, t.sink - dt * 5);
      }
    }
    for (final bank in targetBanks) {
      for (final t in bank.targets) {
        t.flash = max(0, t.flash - dt * 3);
        if (t.cooldown > 0) t.cooldown -= dt;
      }
    }
    for (final s in spinners) {
      if (s.speed > 0) {
        s.angle += s.speed * dt * 2 * pi;
        s._turns += s.speed * dt;
        while (s._turns >= 1) {
          s._turns -= 1;
          _add(
            s.spec.points,
            PinballEventKind.spinner,
            (s.spec.a.x + s.spec.b.x) / 2,
            (s.spec.a.y + s.spec.b.y) / 2,
          );
          _progress(MissionKind.spinner, s.spec.id);
        }
        s.speed = max(0, s.speed - dt * (1.5 + s.speed * 0.6));
      }
    }
    for (final s in saucers) {
      s.flash = max(0, s.flash - dt * 2);
      if (s.cooldown > 0) s.cooldown -= dt;
    }
    for (final r in ramps) {
      r.flash = max(0, r.flash - dt * 1.5);
    }
  }

  /// Multiball: weitere Kugeln kommen in die Bahn und werden automatisch abgeschossen.
  void _serve(double dt) {
    final auto = _autoLaunch;
    if (auto != null) {
      final left = auto - dt;
      if (left <= 0) {
        _autoLaunch = null;
        charge = 0.55;
        ballInLane = true;
        launch();
      } else {
        _autoLaunch = left;
      }
      return;
    }
    if (_toServe > 0 && _laneBall == null) {
      _toServe--;
      final ball = Ball()
        ..body = _ballBody(9.6, _shooterFloor - ballRadius - 0.01);
      balls.add(ball);
      _openGate();
      _autoLaunch = 0.6;
    }
  }

  void _updateGate() {
    final inField = balls.every((b) {
      final body = b.body;
      return body == null || body.position.x < fieldRight - 0.6;
    });
    if (_gate == null &&
        inField &&
        _toServe == 0 &&
        _autoLaunch == null &&
        balls.any((b) => b.body != null)) {
      final shape = EdgeShape()
        ..set(
          Vector2(gatePoints[0].x, gatePoints[0].y),
          Vector2(gatePoints[1].x, gatePoints[1].y),
        );
      _gate = _ground.createFixture(
        FixtureDef(shape, friction: 0.1, restitution: 0.35),
      );
    }
  }

  void _lost() {
    if (balls.isNotEmpty) {
      if (balls.length == 1 && _toServe == 0)
        events.add(const PinballEvent(PinballEventKind.multiballEnd));
      return;
    }
    _toServe = 0;
    _autoLaunch = null;
    if (_saveLeft > 0) {
      _saveLeft = 0;
      _saveUsed = true;
      events.add(const PinballEvent(PinballEventKind.saved));
      _newBall();
      return;
    }
    ballsLeft--;
    multiplier = 1;
    _saveUsed = false;
    events.add(const PinballEvent(PinballEventKind.drain));
    if (ballsLeft <= 0) {
      gameOver = true;
      events.add(const PinballEvent(PinballEventKind.gameOver));
    } else {
      _newBall();
    }
  }

  void _hitBumpers(Body b, double x, double y) {
    for (final bu in bumpers) {
      final dx = x - bu.x;
      final dy = y - bu.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bu.spec.radius + ballRadius + 0.04 && bu.glow < 0.6) {
        b.linearVelocity = Vector2(dx / d, dy / d)..scale(8);
        bu.glow = 1;
        _add(bu.spec.points, PinballEventKind.bumper, bu.x, bu.y);
        _progress(MissionKind.bumper, null);
      }
    }
  }

  void _hitSlings(Body b, double x, double y) {
    for (final s in slings) {
      final ax = s.b.x - s.a.x;
      final ay = s.b.y - s.a.y;
      final t = (((x - s.a.x) * ax + (y - s.a.y) * ay) / (ax * ax + ay * ay))
          .clamp(0.0, 1.0);
      final px = s.a.x + ax * t;
      final py = s.a.y + ay * t;
      final dist = sqrt((x - px) * (x - px) + (y - py) * (y - py));
      final toward = (x - px) * s.nx + (y - py) * s.ny > 0;
      if (dist < ballRadius + 0.05 &&
          toward &&
          t > 0.1 &&
          t < 0.9 &&
          s.glow < 0.5) {
        b.linearVelocity = b.linearVelocity + Vector2(s.nx, s.ny) * 6;
        s.glow = 1;
        _add(10, PinballEventKind.sling, px, py);
        _progress(MissionKind.sling, null);
      }
    }
  }

  void _rotateLanes(int dir) {
    final top = lanes.where((l) => l.spec.group == 'top').toList();
    if (top.length < 2) return;
    final lit = [for (final l in top) l.lit];
    for (var i = 0; i < top.length; i++) {
      top[i].lit = lit[(i - dir + top.length) % top.length];
    }
  }

  void _hitLanes(double x, double y) {
    for (final l in lanes) {
      if (l.cooldown > 0) continue;
      if ((x - l.spec.x).abs() < l.spec.halfWidth &&
          (y - l.spec.y).abs() < 0.35) {
        l.cooldown = 0.4;
        l.flash = 1;
        if (l.lit) {
          _add(l.spec.points ~/ 5, PinballEventKind.lane, l.spec.x, l.spec.y);
          continue;
        }
        l.lit = true;
        _add(l.spec.points, PinballEventKind.lane, l.spec.x, l.spec.y);
        final group = lanes.where((o) => o.spec.group == l.spec.group).toList();
        if (group.every((o) => o.lit)) {
          for (final o in group) {
            o.lit = false;
          }
          if (l.spec.group == 'top') multiplier = min(5, multiplier + 1);
          _add(
            1000,
            PinballEventKind.laneBonus,
            l.spec.x,
            l.spec.y,
            l.spec.group,
          );
          _progress(MissionKind.lanes, l.spec.group);
        }
      }
    }
  }

  double _segDist(Pt c, double angle, double length, double x, double y) {
    final dx = cos(angle) * length / 2;
    final dy = sin(angle) * length / 2;
    final ax = c.x - dx;
    final ay = c.y - dy;
    final bx = c.x + dx;
    final by = c.y + dy;
    final vx = bx - ax;
    final vy = by - ay;
    final t = (((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy)).clamp(
      0.0,
      1.0,
    );
    final px = ax + vx * t;
    final py = ay + vy * t;
    return sqrt((x - px) * (x - px) + (y - py) * (y - py));
  }

  void _hitDrops(double x, double y) {
    for (final bank in dropBanks) {
      for (final t in bank.targets) {
        if (t.down) continue;
        if (_segDist(t.c, bank.spec.angle, bank.spec.length, x, y) <
            ballRadius + 0.06) {
          t.down = true;
          final f = t.fixture;
          if (f != null) _ground.destroyFixture(f);
          t.fixture = null;
          _add(bank.spec.points, PinballEventKind.drop, t.c.x, t.c.y);
          if (bank.targets.every((o) => o.down)) {
            bank.flash = 1;
            bank.resetIn = 1.6;
            _add(bank.spec.bonus, PinballEventKind.dropBank, t.c.x, t.c.y);
            _progress(MissionKind.drops, bank.spec.id);
          }
        }
      }
    }
  }

  void _updateDrops(double dt) {
    for (final bank in dropBanks) {
      if (bank.resetIn <= 0) continue;
      bank.resetIn -= dt;
      if (bank.resetIn > 0) continue;
      // Ziele nur hochfahren, wo keine Kugel liegt
      var waiting = false;
      for (final t in bank.targets) {
        if (!t.down) continue;
        final blocked = balls.any((b) {
          final body = b.body;
          return body != null &&
              _segDist(
                    t.c,
                    bank.spec.angle,
                    bank.spec.length,
                    body.position.x,
                    body.position.y,
                  ) <
                  ballRadius + 0.25;
        });
        if (blocked) {
          waiting = true;
          continue;
        }
        t.down = false;
        t.fixture = _segment(t.c, bank.spec.angle, bank.spec.length);
      }
      if (waiting) bank.resetIn = 0.2;
    }
  }

  void _hitTargets(double x, double y) {
    for (final bank in targetBanks) {
      for (final t in bank.targets) {
        if (t.cooldown > 0) continue;
        // Neonstadt-Zielbanken: nur die zum freien Spielfeld gerichtete Front
        // zählt. Passive Gehäuserückseiten lösen keine Treffer aus.
        if (spec.id == 'city' &&
            (x - t.c.x) * -sin(bank.spec.angle) +
                    (y - t.c.y) * cos(bank.spec.angle) <
                0)
          continue;
        if (_segDist(t.c, bank.spec.angle, bank.spec.length, x, y) <
            ballRadius + 0.07) {
          t.cooldown = 0.3;
          t.flash = 1;
          t.lit = true;
          _add(bank.spec.points, PinballEventKind.target, t.c.x, t.c.y);
          _progress(MissionKind.targets, bank.spec.id);
          if (bank.targets.every((o) => o.lit)) {
            for (final o in bank.targets) {
              o.lit = false;
            }
            _add(bank.spec.bonus, PinballEventKind.targetBank, t.c.x, t.c.y);
          }
        }
      }
    }
  }

  /// Seite einer Kugel zu einer Linie; null, wenn sie nicht auf Höhe der Linie ist.
  double? _side(Pt a, Pt b, double x, double y) {
    final vx = b.x - a.x;
    final vy = b.y - a.y;
    final t = ((x - a.x) * vx + (y - a.y) * vy) / (vx * vx + vy * vy);
    if (t < -0.05 || t > 1.05) return null;
    return vx * (y - a.y) - vy * (x - a.x);
  }

  void _crossSpinners(Ball ball, Body b, double x, double y) {
    for (final s in spinners) {
      final side = _side(s.spec.a, s.spec.b, x, y);
      final prev = ball.sides[s];
      if (side == null) {
        ball.sides.remove(s);
        continue;
      }
      ball.sides[s] = side;
      if (prev != null && prev * side < 0) {
        final v = b.linearVelocity.length;
        s.speed = min(12, s.speed + v * 0.9);
      }
    }
  }

  bool _crossRamps(Ball ball, Body b, double x, double y) {
    for (final r in ramps) {
      final side = _side(r.spec.a, r.spec.b, x, y);
      final prev = ball.sides[r];
      if (side == null) {
        ball.sides.remove(r);
        continue;
      }
      ball.sides[r] = side;
      if (prev == null || prev * side >= 0) continue;
      final d = sqrt(r.spec.dx * r.spec.dx + r.spec.dy * r.spec.dy);
      final along =
          (b.linearVelocity.x * r.spec.dx + b.linearVelocity.y * r.spec.dy) / d;
      if (along < r.spec.minSpeed) continue;
      // Auf die Rampe: die Kugel verlässt die Physik und fährt die Bahn ab
      _world.destroyBody(b);
      ball.body = null;
      ball.ramp = r;
      ball.rampPos = 0;
      ball.sides.clear();
      r.flash = 1;
      return true;
    }
    return false;
  }

  void _rideRamp(Ball ball, double dt) {
    final r = ball.ramp!;
    ball.rampPos += 11 * dt;
    if (ball.rampPos < r.length) return;
    final end = r.spec.path.last;
    ball.ramp = null;
    ball.body = _ballBody(end.x, end.y)
      ..linearVelocity = Vector2(r.spec.vx, r.spec.vy);
    ball.still = 0;
    _add(r.spec.points, PinballEventKind.ramp, end.x, end.y, r.spec.name);
    if (multiball) _add(spec.jackpot, PinballEventKind.jackpot, end.x, end.y);
    _progress(MissionKind.ramp, r.spec.id);
  }

  bool _catchSaucer(Ball ball, Body b, double x, double y) {
    for (final s in saucers) {
      if (s.held != null || s.cooldown > 0) continue;
      final dx = x - s.spec.x;
      final dy = y - s.spec.y;
      if (dx * dx + dy * dy > 0.3 * 0.3) continue;
      _world.destroyBody(b);
      ball.body = null;
      ball.saucer = s;
      ball.sides.clear();
      s.held = ball;
      s.hold = s.spec.lock ? 1.4 : 1.0;
      s.flash = 1;
      _add(s.spec.points, PinballEventKind.saucer, s.spec.x, s.spec.y);
      _progress(MissionKind.saucer, s.spec.id);
      if (s.spec.lock && !multiball) {
        locks++;
        _progress(MissionKind.lock, s.spec.id);
        if (locks >= spec.locksForMultiball) {
          locks = 0;
          _toServe = 2;
          events.add(
            PinballEvent(PinballEventKind.multiball, 0, s.spec.x, s.spec.y),
          );
        } else {
          events.add(
            PinballEvent(
              PinballEventKind.lock,
              0,
              s.spec.x,
              s.spec.y,
              '$locks',
            ),
          );
        }
      }
      return true;
    }
    return false;
  }

  void _updateHeld(double dt) {
    for (final s in saucers) {
      final ball = s.held;
      if (ball == null) continue;
      s.hold -= dt;
      if (s.hold > 0) continue;
      final len = sqrt(s.spec.ex * s.spec.ex + s.spec.ey * s.spec.ey);
      final ox = s.spec.ex / len * 0.15;
      final oy = s.spec.ey / len * 0.15;
      ball.saucer = null;
      ball.body = _ballBody(s.spec.x + ox, s.spec.y + oy)
        ..linearVelocity = Vector2(s.spec.ex, s.spec.ey);
      ball.still = 0;
      s.held = null;
      s.cooldown = 0.8;
    }
  }

  /// Kugeln, die noch kommen, einschließlich der aktuellen.
  int get ballNumber => max(1, ballsPerGame - ballsLeft + 1);
}
