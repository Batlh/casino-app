import 'dart:math';

import 'package:forge2d/forge2d.dart';

/// Flippertisch „Neon Nacht“ mit Forge2D, ohne Oberfläche, damit er sich in Tests simulieren lässt.
/// Einheiten: Spielfeld 0 bis 9,25 breit, rechts daneben die Abschussbahn bis 9,95; 18 hoch, y zeigt nach unten.

enum PinballEventKind { bumper, sling, lane, laneBonus, launch, drain, saved, gameOver, nudge }

class PinballEvent {
  const PinballEvent(this.kind, [this.points = 0]);
  final PinballEventKind kind;
  final int points;
}

class Pt {
  const Pt(this.x, this.y);
  final double x;
  final double y;
}

class Bumper {
  Bumper(this.x, this.y);
  final double x;
  final double y;
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

class PinballTable {
  PinballTable({Random? rng}) : _rng = rng ?? Random.secure() {
    _build();
  }

  static const double width = 9.95;
  static const double fieldRight = 9.25;
  static const double height = 18;
  static const double ballRadius = 0.22;
  static const double flipperLength = 1.75;
  static const int ballsPerGame = 3;
  static const double saveSeconds = 6;
  static const leftPivot = Pt(2.6, 15.3);
  static const rightPivot = Pt(6.65, 15.3);
  static const laneX = [3.4, 4.6, 5.8];

  final Random _rng;
  final World _world = World(Vector2(0, 9));
  late final Body _leftFlipper;
  late final Body _rightFlipper;
  late final RevoluteJoint _leftJoint;
  late final RevoluteJoint _rightJoint;
  Body? _ball;

  final List<List<Pt>> walls = [];
  final List<Bumper> bumpers = [];
  final List<Sling> slings = [];
  final List<bool> lanes = [false, false, false];
  final List<PinballEvent> events = [];

  int score = 0;
  int ballsLeft = ballsPerGame;
  int multiplier = 1;
  bool gameOver = false;

  /// Der Ball liegt in der Abschussbahn und wartet.
  bool ballInLane = true;

  /// Spannung der Feder von 0 bis 1.
  double charge = 0;
  bool charging = false;
  bool leftPressed = false;
  bool rightPressed = false;
  double _saveLeft = 0;
  double _still = 0;
  double _laneCooldown = 0;

  bool get ballSaveActive => _saveLeft > 0;
  Pt? get ball => _ball == null ? null : Pt(_ball!.position.x, _ball!.position.y);

  /// Winkel der Flipper für die Anzeige.
  double get leftAngle => _leftFlipper.angle;
  double get rightAngle => _rightFlipper.angle;

  void _wall(Body ground, List<Pt> pts, {double bounce = 0.35}) {
    walls.add(pts);
    for (var i = 0; i + 1 < pts.length; i++) {
      final shape = EdgeShape()..set(Vector2(pts[i].x, pts[i].y), Vector2(pts[i + 1].x, pts[i + 1].y));
      ground.createFixture(FixtureDef(shape, friction: 0.1, restitution: bounce));
    }
  }

  void _build() {
    final ground = _world.createBody(BodyDef());

    // Außenrand mit Bogen oben, der den Ball aus der Bahn nach links lenkt
    final outer = <Pt>[const Pt(0, 13.2), const Pt(0, 4)];
    const cx = width / 2;
    const rx = width / 2;
    const ry = 4.0;
    for (var i = 1; i < 40; i++) {
      final a = pi + pi * i / 40;
      outer.add(Pt(cx + rx * cos(a), 4 + ry * sin(a)));
    }
    outer.add(const Pt(width, 4));
    outer.add(const Pt(width, 18.2));
    _wall(ground, outer);

    // Abschussbahn mit Feder
    _wall(ground, [const Pt(fieldRight, 18.2), const Pt(fieldRight, 4.6)]);
    _wall(ground, [const Pt(fieldRight, 17.7), const Pt(width, 17.7)], bounce: 0);

    // Führungsschienen zu den Flippern
    _wall(ground, [const Pt(0, 12.4), const Pt(2.45, 15.05)]);
    _wall(ground, [const Pt(fieldRight, 12.4), const Pt(6.8, 15.05)]);

    // Ablaufkanten unter den Flippern
    _wall(ground, [const Pt(0, 13.2), const Pt(0, 16.3), const Pt(1.2, 18.2)]);
    _wall(ground, [const Pt(fieldRight, 16.3), const Pt(8.05, 18.2)]);

    // Pfosten zwischen den oberen Gassen
    for (final x in [2.8, 4.0, 5.2, 6.4]) {
      _wall(ground, [Pt(x, 1.9), Pt(x, 2.9)], bounce: 0.4);
    }

    // Pilze
    for (final p in const [Pt(3.0, 4.8), Pt(6.2, 4.8), Pt(4.6, 6.8)]) {
      bumpers.add(Bumper(p.x, p.y));
      final shape = CircleShape()
        ..radius = 0.5
        ..position.setValues(p.x, p.y);
      ground.createFixture(FixtureDef(shape, restitution: 0.6));
    }

    // Schleudern über den Flippern
    void sling(Pt a, Pt b, Pt c) {
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
      _wall(ground, [a, b, c, a], bounce: 0.8);
    }

    sling(const Pt(2.0, 11.6), const Pt(2.9, 13.8), const Pt(2.0, 13.2));
    sling(const Pt(7.25, 11.6), const Pt(6.35, 13.8), const Pt(7.25, 13.2));

    _leftFlipper = _flipper(leftPivot, 1);
    _rightFlipper = _flipper(rightPivot, -1);
    _leftJoint = _joint(ground, _leftFlipper, leftPivot, -0.45, 0.5);
    _rightJoint = _joint(ground, _rightFlipper, rightPivot, -0.5, 0.45);
    _newBall();
  }

  Body _flipper(Pt pivot, int dir) {
    final body = _world.createBody(
      BodyDef(type: BodyType.dynamic, position: Vector2(pivot.x, pivot.y), bullet: true),
    );
    final l = flipperLength * dir;
    final shape = PolygonShape()
      ..set([
        Vector2(0, -0.2),
        Vector2(l, -0.07),
        Vector2(l, 0.07),
        Vector2(0, 0.2),
      ]);
    body.createFixture(FixtureDef(shape, density: 3, friction: 0.3, restitution: 0.1));
    // Rest: Spitze nach unten
    body.setTransform(Vector2(pivot.x, pivot.y), dir > 0 ? 0.5 : -0.5);
    return body;
  }

  RevoluteJoint _joint(Body ground, Body flipper, Pt pivot, double lower, double upper) {
    final def = RevoluteJointDef()
      ..initialize(ground, flipper, Vector2(pivot.x, pivot.y))
      ..enableLimit = true
      ..lowerAngle = lower
      ..upperAngle = upper
      ..enableMotor = true
      ..maxMotorTorque = 900
      ..motorSpeed = 0;
    // Grundwinkel: Startlage ist schon gedreht, Grenzen gelten absolut
    def.referenceAngle = 0;
    final j = RevoluteJoint(def);
    _world.createJoint(j);
    return j;
  }

  void _newBall() {
    final b = _world.createBody(
      BodyDef(type: BodyType.dynamic, position: Vector2(9.6, 17.7 - ballRadius - 0.01), bullet: true),
    );
    b.createFixture(
      FixtureDef(CircleShape()..radius = ballRadius, density: 1, friction: 0.08, restitution: 0.3),
    );
    _ball = b;
    ballInLane = true;
    charge = 0;
    _still = 0;
  }

  /// Ball abschießen, sofern er in der Bahn liegt.
  void launch() {
    final b = _ball;
    if (b == null || gameOver || !ballInLane) return;
    final strength = charge.clamp(0.15, 1.0);
    b.linearVelocity = Vector2(0, -(16.5 + 7 * strength));
    ballInLane = false;
    charging = false;
    charge = 0;
    _saveLeft = saveSeconds;
    events.add(const PinballEvent(PinballEventKind.launch));
  }

  /// Rüttelt den Tisch leicht, wenn der Ball festhängt.
  void nudge() {
    final b = _ball;
    if (b == null || ballInLane) return;
    b.applyLinearImpulse(Vector2((_rng.nextDouble() - 0.5) * 0.2, -0.25));
    events.add(const PinballEvent(PinballEventKind.nudge));
  }

  void _add(int points, PinballEventKind kind) {
    final p = points * multiplier;
    score += p;
    events.add(PinballEvent(kind, p));
  }

  void step(double dt) {
    if (charging && ballInLane) charge = min(1, charge + dt * 1.1);
    _leftJoint.motorSpeed = leftPressed ? -22 : 14;
    _rightJoint.motorSpeed = rightPressed ? 22 : -14;
    _world.stepDt(dt);
    if (_saveLeft > 0) _saveLeft = max(0, _saveLeft - dt);
    if (_laneCooldown > 0) _laneCooldown -= dt;
    for (final b in bumpers) {
      b.glow = max(0, b.glow - dt * 3);
    }
    for (final s in slings) {
      s.glow = max(0, s.glow - dt * 4);
    }
    final b = _ball;
    if (b == null || gameOver) return;
    final x = b.position.x;
    final y = b.position.y;

    // Liegt der Ball wieder in der Bahn, darf er neu abgeschossen werden
    if (!ballInLane && x > fieldRight && y > 16.8 && b.linearVelocity.length < 0.5) {
      ballInLane = true;
    }

    for (final bu in bumpers) {
      final dx = x - bu.x;
      final dy = y - bu.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < 0.5 + ballRadius + 0.04 && bu.glow < 0.6) {
        final v = Vector2(dx / d, dy / d)..scale(8);
        b.linearVelocity = v;
        bu.glow = 1;
        _add(100, PinballEventKind.bumper);
      }
    }
    for (final s in slings) {
      // Abstand des Balls zur federnden Seite
      final ax = s.b.x - s.a.x;
      final ay = s.b.y - s.a.y;
      final t = (((x - s.a.x) * ax + (y - s.a.y) * ay) / (ax * ax + ay * ay)).clamp(0.0, 1.0);
      final px = s.a.x + ax * t;
      final py = s.a.y + ay * t;
      final dist = sqrt((x - px) * (x - px) + (y - py) * (y - py));
      final toward = (x - px) * s.nx + (y - py) * s.ny > 0;
      if (dist < ballRadius + 0.05 && toward && t > 0.1 && t < 0.9 && s.glow < 0.5) {
        b.linearVelocity = b.linearVelocity + Vector2(s.nx, s.ny) * 6;
        s.glow = 1;
        _add(10, PinballEventKind.sling);
      }
    }
    // Obere Gassen
    if (y > 1.9 && y < 2.9 && _laneCooldown <= 0) {
      for (var i = 0; i < 3; i++) {
        if ((x - laneX[i]).abs() < 0.5 && !lanes[i]) {
          lanes[i] = true;
          _laneCooldown = 0.3;
          _add(50, PinballEventKind.lane);
          if (lanes.every((l) => l)) {
            _add(1000, PinballEventKind.laneBonus);
            multiplier = min(5, multiplier + 1);
            for (var k = 0; k < 3; k++) {
              lanes[k] = false;
            }
          }
        }
      }
    }

    // Festhängende Bälle bekommen einen Schubs
    if (!ballInLane && b.linearVelocity.length < 0.3) {
      _still += dt;
      if (_still > 3) {
        _still = 0;
        nudge();
      }
    } else {
      _still = 0;
    }

    if (y > height + 0.3 || x < -0.5 || x > width + 0.5 || !x.isFinite || !y.isFinite) {
      _world.destroyBody(b);
      _ball = null;
      if (_saveLeft > 0) {
        events.add(const PinballEvent(PinballEventKind.saved));
        _newBall();
        return;
      }
      ballsLeft--;
      multiplier = 1;
      events.add(const PinballEvent(PinballEventKind.drain));
      if (ballsLeft <= 0) {
        gameOver = true;
        events.add(const PinballEvent(PinballEventKind.gameOver));
      } else {
        _newBall();
      }
    }
  }

  /// Bälle, die noch kommen, einschließlich des aktuellen.
  int get ballNumber => ballsPerGame - ballsLeft + 1;
}
