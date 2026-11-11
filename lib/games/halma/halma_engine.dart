import 'dart:math';

/// Stern-Halma auf dem Sternbrett mit 121 Löchern, 2 bis 6 Spieler mit je 10 Figuren.
/// Würfelkoordinaten (x, y, z) mit x + y + z = 0. Das Brett ist die Vereinigung zweier Dreiecke:
/// alle Koordinaten ≥ -4 oder alle ≤ 4. Die sechs Zacken sind die Lager.
class HalmaBoard {
  HalmaBoard._() {
    for (var x = -8; x <= 8; x++) {
      for (var y = -8; y <= 8; y++) {
        final z = -x - y;
        final a = x >= -4 && y >= -4 && z >= -4;
        final b = x <= 4 && y <= 4 && z <= 4;
        if (a || b) {
          index[(x, y, z)] = cells.length;
          cells.add((x, y, z));
        }
      }
    }
    for (final c in cells) {
      neighbors.add([
        for (final d in dirs) index[(c.$1 + d.$1, c.$2 + d.$2, c.$3 + d.$3)] ?? -1,
      ]);
      camp.add(_campOf(c));
    }
  }

  static final HalmaBoard instance = HalmaBoard._();

  static const dirs = [(1, -1, 0), (1, 0, -1), (0, 1, -1), (-1, 1, 0), (-1, 0, 1), (0, -1, 1)];

  final List<(int, int, int)> cells = [];
  final Map<(int, int, int), int> index = {};

  /// Nachbar in Richtung d, -1 am Rand.
  final List<List<int>> neighbors = [];

  /// Lager 0 bis 5 oder -1 in der Mitte. Reihenfolge rund um den Stern: x+, z-, y+, x-, z+, y-.
  final List<int> camp = [];

  static int _campOf((int, int, int) c) {
    if (c.$1 > 4) return 0;
    if (c.$3 < -4) return 1;
    if (c.$2 > 4) return 2;
    if (c.$1 < -4) return 3;
    if (c.$3 > 4) return 4;
    if (c.$2 < -4) return 5;
    return -1;
  }

  List<int> campCells(int c) => [for (var i = 0; i < cells.length; i++) if (camp[i] == c) i];

  static int dist(int a, int b) {
    final p = instance.cells[a];
    final q = instance.cells[b];
    return ((p.$1 - q.$1).abs() + (p.$2 - q.$2).abs() + (p.$3 - q.$3).abs()) ~/ 2;
  }

  /// Bildschirmlage (Einheit: Lochabstand), Mitte bei 0.
  static Point<double> pos(int i) {
    final c = instance.cells[i];
    final q = c.$1.toDouble();
    final r = c.$3.toDouble();
    return Point(sqrt(3) * (q + r / 2), 1.5 * r);
  }
}

/// Startlager je Spielerzahl; das Ziel ist jeweils das gegenüberliegende Lager.
const halmaCamps = {
  2: [0, 3],
  3: [0, 2, 4],
  4: [0, 1, 3, 4],
  5: [0, 1, 2, 3, 4],
  6: [0, 1, 2, 3, 4, 5],
};

class HalmaGame {
  HalmaGame(this.players) : board = List.filled(HalmaBoard.instance.cells.length, -1) {
    for (var p = 0; p < players; p++) {
      for (final c in HalmaBoard.instance.campCells(home(p))) {
        board[c] = p;
      }
    }
  }

  HalmaGame._(this.players, this.board);

  final int players;

  /// Wer steht auf dem Loch: Spieler oder -1.
  final List<int> board;
  int current = 0;
  int? winner;
  int moves = 0;
  (int, int)? lastMove;

  bool get over => winner != null;

  int home(int p) => halmaCamps[players]![p];
  int target(int p) => (home(p) + 3) % 6;

  HalmaGame copy() => HalmaGame._(players, List.of(board))
    ..current = current
    ..winner = winner
    ..moves = moves
    ..lastMove = lastMove;

  /// Ziele von Loch [from]: ein Schritt auf ein freies Nachbarloch oder eine Kette von Sprüngen.
  Set<int> targets(int from) {
    final b = HalmaBoard.instance;
    final out = <int>{};
    for (final n in b.neighbors[from]) {
      if (n >= 0 && board[n] < 0) out.add(n);
    }
    final seen = <int>{from};
    final queue = [from];
    while (queue.isNotEmpty) {
      final a = queue.removeLast();
      for (var d = 0; d < 6; d++) {
        final mid = b.neighbors[a][d];
        if (mid < 0 || board[mid] < 0 || mid == from) continue;
        final land = b.neighbors[mid][d];
        if (land < 0 || (board[land] >= 0 && land != from) || !seen.add(land)) continue;
        out.add(land);
        queue.add(land);
      }
    }
    out.remove(from);
    return out;
  }

  List<(int, int)> legalMoves([int? who]) {
    final p = who ?? current;
    return [
      for (var i = 0; i < board.length; i++)
        if (board[i] == p)
          for (final t in targets(i))
            // Wer im Ziel steht, verlässt es nicht wieder
            if (!(HalmaBoard.instance.camp[i] == target(p) && HalmaBoard.instance.camp[t] != target(p))) (i, t),
    ];
  }

  bool play(int from, int to) {
    if (over || board[from] != current || !targets(from).contains(to)) return false;
    board[to] = current;
    board[from] = -1;
    lastMove = (from, to);
    moves++;
    if (_won(current)) {
      winner = current;
      return true;
    }
    current = (current + 1) % players;
    return true;
  }

  /// Gewonnen, wenn alle zehn eigenen Figuren im Ziellager stehen.
  bool _won(int p) {
    final t = target(p);
    for (var i = 0; i < board.length; i++) {
      if (board[i] == p && HalmaBoard.instance.camp[i] != t) return false;
    }
    return true;
  }

  /// Wie weit sind die eigenen Figuren noch vom Ziel weg (Summe der Abstände zum nächsten freien Ziel-Loch)?
  int distance(int p) {
    final t = HalmaBoard.instance.campCells(target(p));
    final free = t.where((c) => board[c] < 0).toList();
    final goal = free.isEmpty ? t : free;
    var s = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != p || HalmaBoard.instance.camp[i] == target(p)) continue;
      var best = 99;
      for (final g in goal) {
        best = min(best, HalmaBoard.dist(i, g));
      }
      s += best;
    }
    return s;
  }

  /// Gieriger Computer: der Zug, nach dem die eigenen Figuren dem Ziel am nächsten sind.
  (int, int)? botMove(Random rng) {
    final ms = legalMoves();
    if (ms.isEmpty) return null;
    final p = current;
    final tCamp = target(p);
    final apex = HalmaBoard.instance.campCells(tCamp);
    (int, int)? best;
    var bestV = double.infinity;
    for (final m in ms) {
      final c = copy();
      c.board[m.$2] = p;
      c.board[m.$1] = -1;
      var v = c.distance(p).toDouble();
      // Hintere Figuren zuerst nachholen, damit keine zurückbleibt
      var far = 0;
      for (final a in apex) {
        far = max(far, HalmaBoard.dist(m.$1, a));
      }
      v -= far * 0.05;
      v += rng.nextDouble() * 0.3;
      if (v < bestV) {
        bestV = v;
        best = m;
      }
    }
    return best;
  }

  /// Wer nicht ziehen kann, setzt aus.
  void pass() => current = (current + 1) % players;

  Map<String, Object?> toJson() => {
        'players': players,
        'board': board,
        'current': current,
        'winner': winner,
        'moves': moves,
        'last': lastMove == null ? null : [lastMove!.$1, lastMove!.$2],
      };

  static HalmaGame fromJson(Map<String, dynamic> j) {
    final last = j['last'] as List?;
    return HalmaGame._(j['players'] as int, [for (final v in j['board'] as List) v as int])
      ..current = j['current'] as int
      ..winner = j['winner'] as int?
      ..moves = j['moves'] as int
      ..lastMove = last == null ? null : (last[0] as int, last[1] as int);
  }
}
