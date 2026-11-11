import 'dart:math';

import 'package:forge2d/forge2d.dart';

import '../../core/debug_log.dart';

/// Pachinko-Brett auf Basis der Physik-Engine Forge2D. Die Datei kennt keine
/// Oberfläche, damit sich das Brett in Tests ohne Bildschirm simulieren lässt.
/// Einheiten: Das Brett ist zehn Einheiten breit und sechzehn hoch, y zeigt nach unten.
class Point2 {
  const Point2(this.x, this.y);
  final double x;
  final double y;
}

class Pocket {
  const Pocket(this.left, this.top, this.right, this.bottom, this.payout, this.kind);
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int payout;
  final PocketKind kind;

  bool contains(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;
}

enum PocketKind { tulip, start, gate }

enum PachinkoEventKind { tulip, start, gate, fever, lost, refund, stuck, reelsDone }

class PachinkoEvent {
  const PachinkoEvent(this.kind, this.payout);
  final PachinkoEventKind kind;
  final int payout;
}

class PachinkoBoard {
  PachinkoBoard({Random? rng}) : _rng = rng ?? Random.secure() {
    _build();
  }

  static const double boardWidth = 10;
  static const double boardHeight = 16;
  static const double ballRadius = 0.14;
  static const double pegRadius = 0.065;
  static const double laneX = 9.2;
  static const int ballCost = 10;
  static const int tulipPay = 25;
  static const int startPay = 30;
  static const int gatePay = 150;
  static const double feverSeconds = 14;
  static const double reelSeconds = 1.8;
  static const int maxQueuedSpins = 4;

  static const int reelSymbols = 7;

  /// Chance je Ziffernlauf auf drei gleiche Ziffern.
  static const double feverChance = 0.04;

  /// Chance auf zwei gleiche Ziffern ohne Fieber, für die Spannung.
  static const double nearMissChance = 0.25;

  final Random _rng;
  final World _world = World(Vector2(0, 11));
  final List<Body> _balls = [];
  final List<Body> _spinners = [];

  /// Wie lange ein Ball schon fast stillsteht.
  final Map<Body, double> _still = {};

  final List<Point2> pegs = [];
  final List<Point2> arc = [];
  final List<Pocket> pockets = [];

  /// Mitte des Anzeigefelds.
  static const double lcdLeft = 3.2;
  static const double lcdTop = 3.3;
  static const double lcdRight = 6.2;
  static const double lcdBottom = 6.3;

  /// Steiles Spitzdach über dem Anzeigefeld (gut 45 Grad), damit kein Ball oben liegen bleibt.
  static const double lcdRoof = 1.6;

  /// Abstand der Nägel zum Anzeigefeld: breit genug, dass sich keine Kugel verkeilt.
  static const double lcdClear = 0.55;

  List<int> reels = [7, 7, 7];
  bool reelsSpinning = false;
  double _reelTimer = 0;
  int queuedSpins = 0;
  double feverLeft = 0;
  bool get feverActive => feverLeft > 0;

  /// Fortschritt der laufenden Ziffern von 0 bis 1.
  double get reelProgress => 1 - _reelTimer / reelSeconds;

  final List<PachinkoEvent> events = [];

  int get ballsInPlay => _balls.length;
  Iterable<Point2> get balls =>
      _balls.map((b) => Point2(b.position.x, b.position.y));
  Iterable<({double x, double y, double angle})> get spinners =>
      _spinners.map((b) => (x: b.position.x, y: b.position.y, angle: b.angle));

  void _edge(Body body, double x1, double y1, double x2, double y2, {double bounce = 0.3}) {
    final shape = EdgeShape()..set(Vector2(x1, y1), Vector2(x2, y2));
    body.createFixture(FixtureDef(shape, friction: 0.02, restitution: bounce));
  }

  void _peg(Body ground, double x, double y) {
    pegs.add(Point2(x, y));
    final shape = CircleShape()
      ..radius = pegRadius
      ..position.setValues(x, y);
    ground.createFixture(FixtureDef(shape, friction: 0.05, restitution: 0.55));
  }

  bool _freeForPeg(double x, double y) {
    if (_lcdDistance(x, y) < lcdClear) return false;
    for (final s in _spinnerSpots) {
      if ((x - s.x) * (x - s.x) + (y - s.y) * (y - s.y) < 0.95 * 0.95) return false;
    }
    for (final p in pockets) {
      if (x > p.left - 0.3 && x < p.right + 0.3 && y > p.top - 0.5 && y < p.bottom + 0.3) {
        return false;
      }
    }
    return true;
  }

  static const _lcdShape = [
    Point2(lcdLeft, lcdBottom),
    Point2(lcdRight, lcdBottom),
    Point2(lcdRight, lcdTop),
    Point2((lcdLeft + lcdRight) / 2, lcdTop - lcdRoof),
    Point2(lcdLeft, lcdTop),
  ];

  /// Abstand eines Punkts zum Anzeigefeld, 0 innerhalb.
  static double _lcdDistance(double x, double y) {
    var inside = false;
    var best = double.infinity;
    for (var i = 0; i < _lcdShape.length; i++) {
      final a = _lcdShape[i];
      final b = _lcdShape[(i + 1) % _lcdShape.length];
      if ((a.y > y) != (b.y > y) && x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) inside = !inside;
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final t = (((x - a.x) * dx + (y - a.y) * dy) / (dx * dx + dy * dy)).clamp(0.0, 1.0);
      final px = a.x + dx * t - x;
      final py = a.y + dy * t - y;
      best = min(best, sqrt(px * px + py * py));
    }
    return inside ? 0 : best;
  }

  static const _spinnerSpots = [Point2(2.2, 7.6), Point2(7.2, 7.6)];

  void _build() {
    final ground = _world.createBody(BodyDef());

    // Außenkante und Bogen, der den Ball von rechts nach links führt
    const steps = 40;
    const cx = 5.0;
    const cy = 4.6;
    const rx = 4.8;
    const ry = 4.4;
    for (var i = 0; i <= steps; i++) {
      final a = -pi * 0.97 * i / steps;
      arc.add(Point2(cx + rx * cos(a), cy + ry * sin(a)));
    }
    for (var i = 0; i < steps; i++) {
      _edge(ground, arc[i].x, arc[i].y, arc[i + 1].x, arc[i + 1].y, bounce: 0.05);
    }
    _edge(ground, 9.8, cy, 9.8, 16, bounce: 0.1);
    _edge(ground, arc.last.x, arc.last.y, 0.2, 16, bounce: 0.4);
    // Abschussbahn
    _edge(ground, laneX, 16, laneX, 3.4, bounce: 0.1);

    // Anzeigefeld als fester Block mit Spitzdach
    final lcd = PolygonShape()
      ..set([
        Vector2(lcdLeft, lcdBottom),
        Vector2(lcdRight, lcdBottom),
        Vector2(lcdRight, lcdTop),
        Vector2((lcdLeft + lcdRight) / 2, lcdTop - lcdRoof),
        Vector2(lcdLeft, lcdTop),
      ]);
    ground.createFixture(FixtureDef(lcd, friction: 0.05, restitution: 0.4));

    pockets
      ..add(const Pocket(1.1, 10.7, 2.1, 11.0, tulipPay, PocketKind.tulip))
      ..add(const Pocket(7.2, 10.7, 8.2, 11.0, tulipPay, PocketKind.tulip))
      ..add(const Pocket(4.2, 11.7, 5.2, 12.0, startPay, PocketKind.start))
      ..add(const Pocket(3.0, 13.6, 6.4, 14.1, gatePay, PocketKind.gate));

    // Tulpen und Starttasche haben seitliche Leitstifte
    for (final p in pockets.where((p) => p.kind != PocketKind.gate)) {
      _peg(ground, p.left - 0.02, p.top + 0.05);
      _peg(ground, p.right + 0.02, p.top + 0.05);
    }

    // Nägel
    for (var row = 0; row < 15; row++) {
      final y = 2.2 + row * 0.8;
      for (var col = 0; col < 10; col++) {
        final x = 0.75 + col * 0.92 + (row.isOdd ? 0.46 : 0);
        if (x > laneX - 0.35) continue;
        // Bogen freihalten
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        if (y < cy && dx * dx + dy * dy > 0.72) continue;
        if (_freeForPeg(x, y)) _peg(ground, x, y);
      }
    }

    // Windräder
    for (var i = 0; i < _spinnerSpots.length; i++) {
      final s = _spinnerSpots[i];
      final body = _world.createBody(
        BodyDef(type: BodyType.kinematic, position: Vector2(s.x, s.y)),
      );
      body.angularVelocity = i.isEven ? 2.4 : -2.4;
      body.createFixture(
        FixtureDef(
          PolygonShape()..setAsBox(0.72, 0.06, Vector2.zero(), 0),
          friction: 0.05,
          restitution: 0.5,
        ),
      );
      body.createFixture(
        FixtureDef(
          PolygonShape()..setAsBox(0.06, 0.72, Vector2.zero(), 0),
          friction: 0.05,
          restitution: 0.5,
        ),
      );
      _spinners.add(body);
    }
  }

  /// Schießt einen Ball. power: 0 bis 1.
  void launch(double power) {
    final body = _ball(9.5, 15.5);
    final jitter = (_rng.nextDouble() - 0.5) * 0.25;
    body.linearVelocity = Vector2(0, -(15.5 + power * 6 + jitter));
  }

  /// Legt einen ruhenden Ball an eine Stelle, für Tests.
  void dropAt(double x, double y) => _ball(x, y);

  Body _ball(double x, double y) {
    final body = _world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(x, y),
        bullet: true,
      ),
    );
    final shape = CircleShape()..radius = ballRadius;
    body.createFixture(
      FixtureDef(shape, density: 1, friction: 0.02, restitution: 0.35),
    );
    _balls.add(body);
    return body;
  }

  void _startReels() {
    if (reelsSpinning || queuedSpins == 0) return;
    queuedSpins--;
    reelsSpinning = true;
    _reelTimer = reelSeconds;
    final first = 1 + _rng.nextInt(reelSymbols);
    if (_rng.nextDouble() < feverChance) {
      reels = [first, first, first];
      return;
    }
    int other(int not) => 1 + (not + _rng.nextInt(reelSymbols - 1)) % reelSymbols;
    final second =
        _rng.nextDouble() < nearMissChance ? first : other(first);
    var third = 1 + _rng.nextInt(reelSymbols);
    if (first == second && third == first) third = other(first);
    reels = [first, second, third];
  }

  void step(double dt) {
    _world.stepDt(dt);
    if (feverLeft > 0) feverLeft = max(0, feverLeft - dt);
    if (reelsSpinning) {
      _reelTimer -= dt;
      if (_reelTimer <= 0) {
        reelsSpinning = false;
        if (reels[0] == reels[1] && reels[1] == reels[2]) {
          feverLeft = reels[0] == 7 ? feverSeconds * 1.5 : feverSeconds;
          events.add(const PachinkoEvent(PachinkoEventKind.fever, 0));
        } else {
          events.add(const PachinkoEvent(PachinkoEventKind.reelsDone, 0));
        }
      }
    } else {
      _startReels();
    }

    for (final b in _balls.toList()) {
      final x = b.position.x;
      final y = b.position.y;
      PachinkoEvent? ev;
      // Notlösung gegen hängende Bälle: erst anstupsen, später erstatten
      final still = b.linearVelocity.length < 0.25 ? (_still[b] ?? 0) + dt : 0.0;
      _still[b] = still;
      // Alle 0,8 Sekunden Stillstand ein Schubs, nach 3,5 Sekunden erstatten
      if (still > 0.8 && (still / 0.8).floor() != ((still - dt) / 0.8).floor()) {
        b.applyLinearImpulse(Vector2((_rng.nextBool() ? 1 : -1) * 0.04, -0.03));
        debugLog.detail('pachinko', 'Kugel steht bei (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}), Schubs');
      }
      if (still > 3.5) {
        debugLog.warn('pachinko', 'Kugel steckt fest bei (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}), erstattet');
        ev = const PachinkoEvent(PachinkoEventKind.stuck, ballCost);
      } else if (y > 15.8) {
        // Zu schwacher Schuss landet wieder in der Bahn und zählt nicht
        ev = x > laneX
            ? const PachinkoEvent(PachinkoEventKind.refund, ballCost)
            : const PachinkoEvent(PachinkoEventKind.lost, 0);
      } else {
        for (final p in pockets) {
          if (p.kind == PocketKind.gate && !feverActive) continue;
          if (p.contains(x, y)) {
            ev = PachinkoEvent(switch (p.kind) {
              PocketKind.tulip => PachinkoEventKind.tulip,
              PocketKind.start => PachinkoEventKind.start,
              PocketKind.gate => PachinkoEventKind.gate,
            }, p.payout);
            if (p.kind == PocketKind.start && queuedSpins < maxQueuedSpins) {
              queuedSpins++;
            }
            break;
          }
        }
      }
      if (ev != null) {
        events.add(ev);
        _world.destroyBody(b);
        _balls.remove(b);
        _still.remove(b);
      }
    }
  }
}
