import 'dart:math';

/// Dame: deutsche Dame 8×8 oder internationale Dame 10×10.
/// Feld: 0 leer, 1 weißer Stein, 2 weiße Dame, -1 schwarzer Stein, -2 schwarze Dame.
/// Weiß steht unten und beginnt. Gespielt wird auf den dunklen Feldern ((Reihe + Spalte) ungerade).
enum DameVariant { german, international }

class DameMove {
  const DameMove(this.path, this.captured);

  /// Start, Zwischenfelder und Ziel.
  final List<int> path;
  final List<int> captured;

  int get from => path.first;
  int get to => path.last;

  List<Object> toJson() => [path, captured];
  static DameMove fromJson(List<dynamic> j) =>
      DameMove([for (final v in j[0] as List) v as int], [for (final v in j[1] as List) v as int]);

  @override
  String toString() => path.join(captured.isEmpty ? '-' : 'x');
}

class DameGame {
  DameGame(this.variant)
      : n = variant == DameVariant.german ? 8 : 10,
        board = _start(variant);

  static List<int> _start(DameVariant variant) {
    final n = variant == DameVariant.german ? 8 : 10;
    final rows = variant == DameVariant.german ? 3 : 4;
    final b = List.filled(n * n, 0);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if ((r + c).isEven) continue;
        if (r < rows) b[r * n + c] = -1;
        if (r >= n - rows) b[r * n + c] = 1;
      }
    }
    return b;
  }

  DameGame._(this.variant, this.n, this.board, this.current, this.quiet, this.winner);

  /// Züge nur mit Damen und ohne Schlagen, nach denen es unentschieden endet.
  static const drawAfter = 50;

  final DameVariant variant;
  final int n;
  final List<int> board;

  /// 1 Weiß, -1 Schwarz.
  int current = 1;
  int quiet = 0;

  /// 1 oder -1 für den Sieger, 0 bei Unentschieden, null solange gespielt wird.
  int? winner;
  DameMove? lastMove;

  bool get over => winner != null;

  DameGame copy() => DameGame._(variant, n, List.of(board), current, quiet, winner)..lastMove = lastMove;

  int count(int side) => board.where((v) => v != 0 && v.sign == side).length;

  static const _dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

  bool _in(int r, int c) => r >= 0 && r < n && c >= 0 && c < n;

  List<DameMove> moves() {
    final caps = <DameMove>[];
    final simple = <DameMove>[];
    for (var i = 0; i < n * n; i++) {
      final v = board[i];
      if (v == 0 || v.sign != current) continue;
      _captures(i, v, i, [i], [], caps);
      if (caps.isEmpty) _simple(i, v, simple);
    }
    if (caps.isEmpty) return simple;
    if (variant == DameVariant.international) {
      final most = caps.map((m) => m.captured.length).reduce(max);
      return caps.where((m) => m.captured.length == most).toList();
    }
    return caps;
  }

  void _simple(int i, int v, List<DameMove> out) {
    final r = i ~/ n;
    final c = i % n;
    final king = v.abs() == 2;
    for (final (dr, dc) in _dirs) {
      if (!king && dr != -current) continue;
      var rr = r + dr;
      var cc = c + dc;
      while (_in(rr, cc) && board[rr * n + cc] == 0) {
        out.add(DameMove([i, rr * n + cc], const []));
        if (!king) break;
        rr += dr;
        cc += dc;
      }
    }
  }

  /// Tiefensuche über alle Schlagfolgen; geschlagene Steine bleiben bis zum Ende liegen (türkischer Schlag verboten).
  void _captures(int origin, int v, int pos, List<int> path, List<int> taken, List<DameMove> out) {
    final r = pos ~/ n;
    final c = pos % n;
    final king = v.abs() == 2;
    var extended = false;
    bool empty(int sq) => board[sq] == 0 || sq == origin;
    for (final (dr, dc) in _dirs) {
      var rr = r + dr;
      var cc = c + dc;
      if (king) {
        while (_in(rr, cc) && empty(rr * n + cc)) {
          rr += dr;
          cc += dc;
        }
      }
      if (!_in(rr, cc)) continue;
      final victim = rr * n + cc;
      final vv = board[victim];
      if (vv == 0 || vv.sign == current || taken.contains(victim)) continue;
      var lr = rr + dr;
      var lc = cc + dc;
      while (_in(lr, lc) && empty(lr * n + lc)) {
        final land = lr * n + lc;
        extended = true;
        _captures(origin, v, land, [...path, land], [...taken, victim], out);
        if (!king) break;
        lr += dr;
        lc += dc;
      }
    }
    if (!extended && taken.isNotEmpty) out.add(DameMove(path, taken));
  }

  bool play(DameMove m) {
    if (over) return false;
    final legal = moves().any((x) => x.from == m.from && x.to == m.to && _same(x.captured, m.captured));
    if (!legal) return false;
    apply(m);
    return true;
  }

  /// Zug ohne Prüfung ausführen (für die Suche des Computers).
  void apply(DameMove m) {
    final orig = board[m.from];
    var v = orig;
    board[m.from] = 0;
    for (final x in m.captured) {
      board[x] = 0;
    }
    final row = m.to ~/ n;
    if (v.abs() == 1 && ((v == 1 && row == 0) || (v == -1 && row == n - 1))) v *= 2;
    board[m.to] = v;
    quiet = m.captured.isEmpty && orig.abs() == 2 ? quiet + 1 : 0;
    lastMove = m;
    current = -current;
    if (moves().isEmpty) {
      winner = -current;
    } else if (quiet >= drawAfter) {
      winner = 0;
    }
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    final sa = [...a]..sort();
    final sb = [...b]..sort();
    for (var i = 0; i < sa.length; i++) {
      if (sa[i] != sb[i]) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
        'variant': variant.index,
        'board': board,
        'current': current,
        'quiet': quiet,
        'winner': winner,
        'last': lastMove?.toJson(),
      };

  static DameGame fromJson(Map<String, dynamic> j) {
    final v = DameVariant.values[j['variant'] as int];
    return DameGame._(v, v == DameVariant.german ? 8 : 10, [for (final x in j['board'] as List) x as int],
        j['current'] as int, j['quiet'] as int, j['winner'] as int?)
      ..lastMove = j['last'] == null ? null : DameMove.fromJson(j['last'] as List);
  }
}

int _eval(DameGame g, int me) {
  final w = g.winner;
  if (w != null) return w == 0 ? 0 : (w == me ? 100000 : -100000);
  var s = 0;
  for (var i = 0; i < g.n * g.n; i++) {
    final v = g.board[i];
    if (v == 0) continue;
    final r = i ~/ g.n;
    final c = i % g.n;
    var val = v.abs() == 2 ? 320 : 100;
    if (v.abs() == 1) {
      // Vorwärts gekommen und in der Mitte ist besser
      final adv = v > 0 ? (g.n - 1 - r) : r;
      val += adv * 4;
      if (c > 0 && c < g.n - 1) val += 3;
    }
    s += v.sign == me ? val : -val;
  }
  return s;
}

int _search(DameGame g, int depth, int alpha, int beta, int me) {
  if (depth == 0 || g.over) return _eval(g, me);
  final maximize = g.current == me;
  var best = maximize ? -1 << 30 : 1 << 30;
  for (final m in g.moves()) {
    final c = g.copy()..apply(m);
    final v = _search(c, depth - 1, alpha, beta, me);
    if (maximize) {
      if (v > best) best = v;
      if (v > alpha) alpha = v;
    } else {
      if (v < best) best = v;
      if (v < beta) beta = v;
    }
    if (beta <= alpha) break;
  }
  return best;
}

/// Stufen 0 bis 2: Suchtiefe 1, 3 und 4 Halbzüge.
DameMove dameBotMove(DameGame g, int level, Random rng) {
  final ms = g.moves()..shuffle(rng);
  if (ms.length == 1) return ms.first;
  final depth = [1, 3, 4][level];
  final me = g.current;
  var best = ms.first;
  var bestV = -1 << 30;
  for (final m in ms) {
    final c = g.copy()..apply(m);
    final v = _search(c, depth - 1, -1 << 30, 1 << 30, me);
    if (v > bestV) {
      bestV = v;
      best = m;
    }
  }
  return best;
}
