import 'dart:math';

/// Leiterspiel (Schlangen und Leitern) auf 100 Feldern. Feld 0 ist der Start vor dem Brett.
class LadderGame {
  factory LadderGame(int players, {bool randomBoard = false, Random? rng}) {
    final r = rng ?? Random();
    return LadderGame._(players, List.filled(players, 0), randomBoard ? randomJumps(r) : Map.of(classicJumps), r);
  }

  LadderGame._(this.players, this.positions, this.jumps, this._rng);

  static const goal = 100;

  /// Klassisches Brett: Leiter hoch (Start kleiner als Ziel), Schlange runter.
  static const classicJumps = {
    1: 38, 4: 14, 9: 31, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 80: 100, //
    16: 6, 47: 26, 49: 11, 56: 53, 62: 19, 64: 60, 87: 24, 93: 73, 95: 75, 98: 78,
  };

  final int players;
  final Random _rng;
  final List<int> positions;
  final Map<int, int> jumps;
  int current = 0;
  int? winner;
  int? lastRoll;

  bool get over => winner != null;

  /// Würfelt für den Spieler am Zug und zieht. Gibt das Ergebnis für die Anzeige zurück.
  LadderMove roll([int? fixed]) {
    if (over) throw StateError('Spiel ist vorbei');
    final p = current;
    final r = fixed ?? 1 + _rng.nextInt(6);
    lastRoll = r;
    final from = positions[p];
    var to = from + r;
    var bounced = false;
    if (to > goal) {
      to = goal - (to - goal);
      bounced = true;
    }
    final landed = to;
    final jump = jumps[to];
    if (jump != null) to = jump;
    positions[p] = to;
    if (to == goal) {
      winner = p;
    } else {
      current = (current + 1) % players;
    }
    return LadderMove(p, r, from, landed, to, bounced);
  }

  /// Zufälliges Brett: acht Leitern, acht Schlangen, keine Ketten, nichts auf Start oder Ziel.
  static Map<int, int> randomJumps(Random rng) {
    final out = <int, int>{};
    final used = <int>{goal};
    bool free(int a, int b) => !used.contains(a) && !used.contains(b) && a != b;
    var tries = 0;
    while (out.length < 8 && tries++ < 2000) {
      final a = 2 + rng.nextInt(80);
      final b = a + 10 + rng.nextInt(min(40, 99 - a - 9));
      if (b > 99 || !free(a, b)) continue;
      out[a] = b;
      used
        ..add(a)
        ..add(b);
    }
    tries = 0;
    var snakes = 0;
    while (snakes < 8 && tries++ < 2000) {
      final a = 15 + rng.nextInt(84);
      final b = a - 10 - rng.nextInt(min(40, a - 11));
      if (b < 2 || a >= goal || !free(a, b)) continue;
      out[a] = b;
      used
        ..add(a)
        ..add(b);
      snakes++;
    }
    return out;
  }

  Map<String, Object?> toJson() => {
        'players': players,
        'pos': positions,
        'jumps': {for (final e in jumps.entries) '${e.key}': e.value},
        'current': current,
        'winner': winner,
        'roll': lastRoll,
      };

  static LadderGame fromJson(Map<String, dynamic> j, {Random? rng}) => LadderGame._(
        j['players'] as int,
        [for (final v in j['pos'] as List) v as int],
        {for (final e in (j['jumps'] as Map).entries) int.parse(e.key as String): e.value as int},
        rng ?? Random(),
      )
        ..current = j['current'] as int
        ..winner = j['winner'] as int?
        ..lastRoll = j['roll'] as int?;
}

class LadderMove {
  const LadderMove(this.player, this.roll, this.from, this.landed, this.to, this.bounced);
  final int player;
  final int roll;
  final int from;

  /// Feld nach dem Würfeln, vor Leiter oder Schlange.
  final int landed;
  final int to;
  final bool bounced;

  bool get ladder => to > landed;
  bool get snake => to < landed;
}

/// Mitte eines Felds in Brettkoordinaten 0..10, Feld 1 unten links, Schlangenlinie nach oben.
Point<double> ladderCell(int n) {
  final i = n - 1;
  final row = i ~/ 10;
  final col = row.isEven ? i % 10 : 9 - i % 10;
  return Point(col + 0.5, 9 - row + 0.5);
}
