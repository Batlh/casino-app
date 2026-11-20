import 'dart:math';

import 'package:forge2d/forge2d.dart';

/// Münzschieber, von oben gesehen, mit der Physik-Engine Forge2D. Kennt keine Oberfläche, damit sich der Tisch in
/// Tests simulieren lässt.
///
/// Einheiten: Der Tisch ist [width] breit und [length] lang, y zeigt zum Spieler. Hinten fährt der Schieber vor und
/// zurück. Münzen, die vorne über die Kante fallen, gewinnt man; die an den offenen Seiten vorne in die Rinnen fallen,
/// gehören dem Automaten.
class PusherCoin {
  const PusherCoin(this.x, this.y, this.value, this.gold);
  final double x;
  final double y;

  /// Münzwert beim Einwurf; Goldmünzen zahlen das Zehnfache davon.
  final int value;
  final bool gold;
}

class PusherEvent {
  const PusherEvent(this.won, this.value, this.gold, this.x);
  final bool won;
  final int value;
  final bool gold;
  final double x;
}

class PusherTable {
  PusherTable({Random? rng, List<PusherCoin>? coins}) : _rng = rng ?? Random() {
    _build();
    if (coins == null) {
      _fill();
    } else {
      for (final c in coins) {
        _addCoin(c.x, c.y, c.value, c.gold);
      }
    }
  }

  static const double width = 8;
  static const double length = 10;
  static const double coinRadius = 0.42;

  /// Bis hierhin haben die Seiten Wände; davor sind sie offen (Rinnen).
  static const double wallEnd = 8.0;

  /// Schieber: Vorderkante pendelt zwischen [pusherMin] und [pusherMax].
  static const double pusherMin = 1.2;
  static const double pusherMax = 2.9;
  static const double pusherPeriod = 3.2;

  /// Chance, dass ein Einwurf eine Goldmünze (zehnfacher Wert) mit auf den Tisch bringt.
  static const double goldChance = 1 / 250;

  final Random _rng;
  final World _world = World(Vector2.zero());
  late final Body _pusher;
  final List<Body> _coins = [];
  final List<PusherEvent> events = [];
  double _time = 0;

  /// Wartende Einwürfe (x-Position, Wert).
  final List<(double, int)> _queue = [];

  double get pusherFront => pusherMin + (pusherMax - pusherMin) * (0.5 - 0.5 * cos(2 * pi * _time / pusherPeriod));
  int get queued => _queue.length;

  /// Wartende Einwürfe zum Speichern (negativer Wert: Goldmünze).
  List<(double, int)> get pending => List.unmodifiable(_queue);

  /// Gespeicherten wartenden Einwurf wiederherstellen.
  void enqueue(double x, int value) => _queue.add((x, value));

  Iterable<PusherCoin> get coins => _coins.map((b) {
        final d = b.userData! as _CoinData;
        return PusherCoin(b.position.x, b.position.y, d.value, d.gold);
      });

  void _build() {
    final walls = _world.createBody(BodyDef());
    void edge(double x1, double y1, double x2, double y2) {
      walls.createFixture(FixtureDef(EdgeShape()..set(Vector2(x1, y1), Vector2(x2, y2)), friction: 0.2, restitution: 0.1));
    }

    edge(0, -2, 0, wallEnd);
    edge(width, -2, width, wallEnd);
    edge(0, -2, width, -2);
    _pusher = _world.createBody(BodyDef(type: BodyType.kinematic, position: Vector2(width / 2, pusherFront - 1.5)));
    _pusher.createFixture(FixtureDef(PolygonShape()..setAsBoxXY(width / 2 - 0.02, 1.5), friction: 0.3, restitution: 0));
  }

  /// Startfüllung: dicht gepackte Reihen vor dem Schieber, die vordersten mit Abstand zur Kante.
  void _fill() {
    var row = 0;
    for (var y = pusherMax + coinRadius + 0.05; y < length - 1.6; y += coinRadius * 1.75) {
      final off = row.isOdd ? coinRadius : 0.0;
      for (var x = coinRadius + 0.05 + off; x < width - coinRadius - 0.05; x += coinRadius * 2.05) {
        if (_rng.nextDouble() < 0.82) _addCoin(x, y, 1, _rng.nextDouble() < 0.03);
      }
      row++;
    }
  }

  void _addCoin(double x, double y, int value, bool gold) {
    final b = _world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: Vector2(x, y),
      linearDamping: 5.5,
      angularDamping: 8,
      bullet: false,
    ));
    b.createFixture(FixtureDef(CircleShape()..radius = coinRadius, density: 1, friction: 0.35, restitution: 0.05));
    b.userData = _CoinData(value, gold);
    _coins.add(b);
  }

  /// Wirft eine Münze an der Stelle [x] (0 … width) ein. Sie landet vor dem Schieber, sobald dort Platz ist.
  void drop(double x, int value) {
    _queue.add((x.clamp(coinRadius + 0.02, width - coinRadius - 0.02), value));
    if (_rng.nextDouble() < goldChance) {
      _queue.add(((_rng.nextDouble() * (width - 2 * coinRadius)) + coinRadius, -value));
    }
  }

  bool _free(double x, double y) {
    for (final b in _coins) {
      final dx = b.position.x - x, dy = b.position.y - y;
      if (dx * dx + dy * dy < (2 * coinRadius + 0.02) * (2 * coinRadius + 0.02)) return false;
    }
    return true;
  }

  /// Ein Schritt der Simulation.
  void step(double dt) {
    final before = pusherFront;
    _time += dt;
    final front = pusherFront;
    _pusher.linearVelocity = Vector2(0, (front - before) / dt);
    _world.stepDt(dt);
    // Einwürfe landen vor dem Schieber, wenn dort Platz ist (sonst ein Stück weiter vorn)
    if (_queue.isNotEmpty) {
      final (x, v) = _queue.first;
      for (var y = front + coinRadius + 0.03; y < front + 3; y += 0.25) {
        if (_free(x, y)) {
          _addCoin(x, y, v.abs(), v < 0);
          _queue.removeAt(0);
          break;
        }
      }
    }
    // Münzen an den Kanten
    for (final b in [..._coins]) {
      final p = b.position;
      final d = b.userData! as _CoinData;
      if (p.y > length) {
        events.add(PusherEvent(true, d.gold ? d.value * 10 : d.value, d.gold, p.x));
      } else if (p.x < -coinRadius * 0.2 || p.x > width + coinRadius * 0.2) {
        events.add(PusherEvent(false, d.gold ? d.value * 10 : d.value, d.gold, p.x));
      } else if (p.y < front - coinRadius * 0.5) {
        // In den Schieber gedrückt (Physik zu grob): zurück vor die Kante setzen
        b.setTransform(Vector2(p.x, front + coinRadius), 0);
        continue;
      } else {
        continue;
      }
      _world.destroyBody(b);
      _coins.remove(b);
    }
  }
}

class _CoinData {
  _CoinData(this.value, this.gold);
  final int value;
  final bool gold;
}
