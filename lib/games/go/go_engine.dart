import 'dart:math';

/// Go auf 9×9 oder 13×13 mit Flächenwertung (Steine plus umschlossene Punkte) und Komi.
/// Feld: 0 leer, 1 Schwarz (beginnt), 2 Weiß. Selbstmord ist verboten, Ko einfach geprüft.
class GoGame {
  GoGame(this.n, {this.komi = 7.5})
      : board = List.filled(n * n, 0),
        neighbors = _neighbors(n);

  GoGame._(this.n, this.komi, this.board, this.neighbors);

  final int n;
  final double komi;
  final List<int> board;
  final List<List<int>> neighbors;
  int current = 1;
  int passes = 0;
  bool over = false;

  /// Wer aufgegeben hat (1 oder 2), sonst null.
  int? resigned;
  final List<int> captures = [0, 0, 0];
  int? lastMove;

  /// Stellung vor dem letzten Zug (für Ko).
  List<int>? _previous;
  int moveCount = 0;

  static List<List<int>> _neighbors(int n) => [
        for (var i = 0; i < n * n; i++)
          [
            if (i ~/ n > 0) i - n,
            if (i ~/ n < n - 1) i + n,
            if (i % n > 0) i - 1,
            if (i % n < n - 1) i + 1,
          ],
      ];

  GoGame copy() => GoGame._(n, komi, List.of(board), neighbors)
    ..current = current
    ..passes = passes
    ..over = over
    ..resigned = resigned
    ..lastMove = lastMove
    .._previous = _previous == null ? null : List.of(_previous!)
    ..moveCount = moveCount
    ..captures.setAll(0, captures);

  /// Gruppe und ihre Freiheiten.
  (List<int>, Set<int>) group(int p, [List<int>? b]) {
    final bd = b ?? board;
    final color = bd[p];
    final stones = <int>[p];
    final seen = <int>{p};
    final libs = <int>{};
    for (var k = 0; k < stones.length; k++) {
      for (final q in neighbors[stones[k]]) {
        final v = bd[q];
        if (v == 0) {
          libs.add(q);
        } else if (v == color && seen.add(q)) {
          stones.add(q);
        }
      }
    }
    return (stones, libs);
  }

  /// Ergebnis eines Zugs auf [p] ohne Ko-Prüfung, oder null bei besetztem Feld/Selbstmord.
  (List<int>, int)? _tryPlace(int p, int color) {
    if (board[p] != 0) return null;
    final b = List.of(board);
    b[p] = color;
    var taken = 0;
    for (final q in neighbors[p]) {
      if (b[q] == 3 - color) {
        final (stones, libs) = group(q, b);
        if (libs.isEmpty) {
          for (final s in stones) {
            b[s] = 0;
          }
          taken += stones.length;
        }
      }
    }
    if (taken == 0 && group(p, b).$2.isEmpty) return null;
    return (b, taken);
  }

  bool isLegal(int p) {
    if (over) return false;
    final r = _tryPlace(p, current);
    if (r == null) return false;
    final prev = _previous;
    return prev == null || !_same(r.$1, prev);
  }

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool play(int p) {
    if (!isLegal(p)) return false;
    final (b, taken) = _tryPlace(p, current)!;
    _previous = List.of(board);
    board.setAll(0, b);
    captures[current] += taken;
    lastMove = p;
    passes = 0;
    moveCount++;
    current = 3 - current;
    return true;
  }

  void pass() {
    if (over) return;
    passes++;
    _previous = List.of(board);
    lastMove = null;
    moveCount++;
    current = 3 - current;
    if (passes >= 2) over = true;
  }

  void resign() {
    resigned = current;
    over = true;
  }

  /// Gebiet je Punkt: 1/2 für Schwarz/Weiß, 0 neutral (nur leere Punkte).
  List<int> territory() {
    final t = List.filled(n * n, 0);
    final seen = List.filled(n * n, false);
    for (var i = 0; i < n * n; i++) {
      if (board[i] != 0 || seen[i]) continue;
      final region = <int>[i];
      seen[i] = true;
      var touches = 0;
      for (var k = 0; k < region.length; k++) {
        for (final q in neighbors[region[k]]) {
          final v = board[q];
          if (v == 0) {
            if (!seen[q]) {
              seen[q] = true;
              region.add(q);
            }
          } else {
            touches |= v;
          }
        }
      }
      if (touches == 1 || touches == 2) {
        for (final r in region) {
          t[r] = touches;
        }
      }
    }
    return t;
  }

  /// Flächenwertung: Steine plus Gebiet, Weiß bekommt Komi. Positiv heißt Schwarz vorn.
  double score() {
    final t = territory();
    var b = 0;
    var w = 0;
    for (var i = 0; i < n * n; i++) {
      if (board[i] == 1 || t[i] == 1) b++;
      if (board[i] == 2 || t[i] == 2) w++;
    }
    return b - w - komi;
  }

  /// 1 Schwarz, 2 Weiß; nur wenn das Spiel vorbei ist.
  int? get winner {
    if (!over) return null;
    if (resigned != null) return 3 - resigned!;
    return score() > 0 ? 1 : 2;
  }

  /// Ein eigenes Auge: alle Nachbarn eigene Steine (für die Zufallspartien des Computers).
  bool isOwnEye(int p, int color) {
    if (board[p] != 0) return false;
    for (final q in neighbors[p]) {
      if (board[q] != color) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
        'n': n,
        'komi': komi,
        'board': board,
        'current': current,
        'passes': passes,
        'over': over,
        'resigned': resigned,
        'captures': captures,
        'last': lastMove,
        'prev': _previous,
        'count': moveCount,
      };

  static GoGame fromJson(Map<String, dynamic> j) {
    List<int> ints(Object? v) => [for (final x in v as List) x as int];
    final n = j['n'] as int;
    final g = GoGame._(n, (j['komi'] as num).toDouble(), ints(j['board']), _neighbors(n))
      ..current = j['current'] as int
      ..passes = j['passes'] as int
      ..over = j['over'] as bool
      ..resigned = j['resigned'] as int?
      ..lastMove = j['last'] as int?
      .._previous = j['prev'] == null ? null : ints(j['prev'])
      ..moveCount = j['count'] as int;
    g.captures.setAll(0, ints(j['captures']));
    return g;
  }

  /// Aus einem Text-Diagramm: Zeilen mit '.', 'X' (Schwarz), 'O' (Weiß), '*' (leer, richtige Antwort).
  static (GoGame, Set<int>) fromDiagram(List<String> rows) {
    final n = rows.length;
    final g = GoGame(n);
    final answers = <int>{};
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final ch = rows[r][c];
        final i = r * n + c;
        if (ch == 'X') g.board[i] = 1;
        if (ch == 'O') g.board[i] = 2;
        if (ch == '*') answers.add(i);
      }
    }
    return (g, answers);
  }
}

// Computer ----------------------------------------------------------------

/// Sinnvolle Züge: legal und kein eigenes Auge zuschütten.
List<int> goCandidates(GoGame g) => [
      for (var i = 0; i < g.n * g.n; i++)
        if (g.board[i] == 0 && !g.isOwnEye(i, g.current) && g.isLegal(i)) i,
    ];

/// Zufallspartie bis zum Ende, Ergebnis aus Sicht von [me]: 1 gewonnen, 0 verloren.
double _playout(GoGame start, int me, Random rng) {
  final g = start.copy();
  final limit = g.n * g.n * 3;
  var moves = 0;
  final empties = <int>[];
  while (!g.over && moves++ < limit) {
    empties
      ..clear()
      ..addAll([for (var i = 0; i < g.n * g.n; i++) if (g.board[i] == 0) i]);
    var played = false;
    while (empties.isNotEmpty) {
      final k = rng.nextInt(empties.length);
      final p = empties[k];
      empties[k] = empties.last;
      empties.removeLast();
      if (g.isOwnEye(p, g.current)) continue;
      // Ko wird in Zufallspartien vernachlässigt, nur Selbstmord geprüft
      final r = g._tryPlace(p, g.current);
      if (r == null) continue;
      g._previous = null;
      g.board.setAll(0, r.$1);
      g.passes = 0;
      g.current = 3 - g.current;
      played = true;
      break;
    }
    if (!played) g.pass();
  }
  final s = g.score();
  final blackWins = s > 0;
  return (blackWins == (me == 1)) ? 1 : 0;
}

/// Stufen: 0 leicht (Schlagen/Retten, sonst zufällig), 1 mittel, 2 schwer (Monte-Carlo mit mehr Partien).
/// Gibt -1 für Passen zurück.
int goBotMove(GoGame g, int level, Random rng) {
  final cands = goCandidates(g);
  if (cands.isEmpty) return -1;
  final me = g.current;
  // Gegner hat gepasst und wir liegen vorn: auch passen
  final lead = me == 1 ? g.score() : -g.score();
  if (g.passes > 0 && lead > 0) return -1;

  if (level == 0) {
    // Schlagen, sonst eigene Gruppe in Atari retten, sonst zufällig mit Vorliebe für die Mitte
    for (final c in cands) {
      for (final q in g.neighbors[c]) {
        if (g.board[q] == 3 - me && g.group(q).$2.length == 1) return c;
      }
    }
    for (final c in cands) {
      for (final q in g.neighbors[c]) {
        if (g.board[q] == me && g.group(q).$2.length == 1) {
          final t = g.copy()..play(c);
          if (t.group(c).$2.length >= 2) return c;
        }
      }
    }
    final mid = (g.n - 1) / 2;
    cands.sort((a, b) {
      double d(int p) => (p ~/ g.n - mid).abs() + (p % g.n - mid).abs();
      return (d(a) + rng.nextDouble() * 4).compareTo(d(b) + rng.nextDouble() * 4);
    });
    return cands.first;
  }

  // Flache Monte-Carlo-Suche mit UCB über die Kandidaten
  final budget = g.n == 9 ? (level == 1 ? 600 : 2400) : (level == 1 ? 250 : 900);
  final wins = List.filled(cands.length, 0.0);
  final visits = List.filled(cands.length, 0);
  final next = [for (final c in cands) g.copy()..play(c)];
  for (var t = 0; t < budget; t++) {
    var pick = 0;
    var bestU = -1.0;
    for (var k = 0; k < cands.length; k++) {
      final u = visits[k] == 0 ? 1e9 : wins[k] / visits[k] + 1.2 * sqrt(log(t + 1) / visits[k]);
      if (u > bestU) {
        bestU = u;
        pick = k;
      }
    }
    wins[pick] += _playout(next[pick], me, rng);
    visits[pick]++;
  }
  var best = 0;
  for (var k = 1; k < cands.length; k++) {
    if (visits[k] > visits[best]) best = k;
  }
  final rate = wins[best] / max(1, visits[best]);
  // Aussichtslos und Spielende nah: passen
  if (rate < 0.03 && g.moveCount > g.n * g.n) return -1;
  return cands[best];
}
