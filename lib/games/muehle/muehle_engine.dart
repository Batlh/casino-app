import 'dart:math';

/// Mühle (Neunermühle). 24 Punkte auf drei Ringen; 0 leer, 1 Weiß (beginnt), 2 Schwarz.
/// Ring r: Punkte 8r bis 8r+7 im Uhrzeigersinn ab der linken oberen Ecke.

const muehlePoints = <(int, int)>[
  (0, 0), (3, 0), (6, 0), (6, 3), (6, 6), (3, 6), (0, 6), (0, 3), //
  (1, 1), (3, 1), (5, 1), (5, 3), (5, 5), (3, 5), (1, 5), (1, 3),
  (2, 2), (3, 2), (4, 2), (4, 3), (4, 4), (3, 4), (2, 4), (2, 3),
];

final List<List<int>> muehleNeighbors = () {
  final n = List.generate(24, (_) => <int>[]);
  for (var r = 0; r < 3; r++) {
    for (var k = 0; k < 8; k++) {
      final a = r * 8 + k;
      final b = r * 8 + (k + 1) % 8;
      n[a].add(b);
      n[b].add(a);
    }
  }
  for (final k in [1, 3, 5, 7]) {
    for (var r = 0; r < 2; r++) {
      n[r * 8 + k].add((r + 1) * 8 + k);
      n[(r + 1) * 8 + k].add(r * 8 + k);
    }
  }
  return n;
}();

final List<List<int>> muehleMills = () {
  final m = <List<int>>[];
  for (var r = 0; r < 3; r++) {
    for (final k in [0, 2, 4, 6]) {
      m.add([r * 8 + k, r * 8 + k + 1, r * 8 + (k + 2) % 8]);
    }
  }
  for (final k in [1, 3, 5, 7]) {
    m.add([k, 8 + k, 16 + k]);
  }
  return m;
}();

/// Ein vollständiger Zug: setzen (from null) oder ziehen, dazu ein geschlagener Stein bei einer Mühle.
class MuehleMove {
  const MuehleMove(this.from, this.to, [this.remove]);
  final int? from;
  final int to;
  final int? remove;

  @override
  String toString() => '${from ?? '+'}>$to${remove == null ? '' : 'x$remove'}';
}

class MuehleGame {
  MuehleGame() : board = List.filled(24, 0);

  MuehleGame._(this.board, this.toPlace, this.current, this.quiet, this.winner);

  /// Züge ohne Schlagen, nach denen es unentschieden endet.
  static const drawAfter = 60;

  final List<int> board;
  List<int> toPlace = [9, 9];
  int current = 1;
  int quiet = 0;

  /// 1 oder 2; 0 bei Unentschieden; null solange gespielt wird.
  int? winner;

  bool get over => winner != null;

  MuehleGame copy() => MuehleGame._(List.of(board), List.of(toPlace), current, quiet, winner);

  int count(int who) => board.where((b) => b == who).length;
  bool placing(int who) => toPlace[who - 1] > 0;
  bool flying(int who) => !placing(who) && count(who) == 3;

  bool inMill(int p, [List<int>? b]) {
    final bd = b ?? board;
    final who = bd[p];
    if (who == 0) return false;
    for (final m in muehleMills) {
      if (m.contains(p) && m.every((x) => bd[x] == who)) return true;
    }
    return false;
  }

  /// Steine des Gegners, die geschlagen werden dürfen: nicht in einer Mühle, außer alle sind es.
  List<int> removable(int opp, [List<int>? b]) {
    final bd = b ?? board;
    final all = [for (var i = 0; i < 24; i++) if (bd[i] == opp) i];
    final free = all.where((p) => !inMill(p, bd)).toList();
    return free.isEmpty ? all : free;
  }

  /// Einfache Schritte ohne Schlagen: (von, nach), von null beim Setzen.
  List<(int?, int)> steps([int? who]) {
    final w = who ?? current;
    final empty = [for (var i = 0; i < 24; i++) if (board[i] == 0) i];
    if (placing(w)) return [for (final e in empty) (null, e)];
    final out = <(int?, int)>[];
    final fly = flying(w);
    for (var i = 0; i < 24; i++) {
      if (board[i] != w) continue;
      for (final t in fly ? empty : muehleNeighbors[i]) {
        if (board[t] == 0) out.add((i, t));
      }
    }
    return out;
  }

  /// Schließt der Schritt eine Mühle?
  bool closesMill(int? from, int to, int who) {
    final b = List.of(board);
    if (from != null) b[from] = 0;
    b[to] = who;
    return inMill(to, b);
  }

  /// Alle vollständigen Züge (für den Computer).
  List<MuehleMove> moves() {
    final out = <MuehleMove>[];
    final opp = 3 - current;
    for (final (f, t) in steps()) {
      if (closesMill(f, t, current)) {
        final b = List.of(board);
        if (f != null) b[f] = 0;
        b[t] = current;
        for (final r in removable(opp, b)) {
          out.add(MuehleMove(f, t, r));
        }
      } else {
        out.add(MuehleMove(f, t));
      }
    }
    return out;
  }

  bool play(MuehleMove m) {
    if (over) return false;
    final who = current;
    if (m.from == null) {
      if (!placing(who) || board[m.to] != 0) return false;
      toPlace[who - 1]--;
    } else {
      if (placing(who) || board[m.from!] != who || board[m.to] != 0) return false;
      if (!flying(who) && !muehleNeighbors[m.from!].contains(m.to)) return false;
      board[m.from!] = 0;
    }
    board[m.to] = who;
    final mill = inMill(m.to);
    if (mill) {
      final r = m.remove;
      if (r == null || !removable(3 - who).contains(r)) {
        // Ungültig: zurücknehmen
        board[m.to] = 0;
        if (m.from != null) {
          board[m.from!] = who;
        } else {
          toPlace[who - 1]++;
        }
        return false;
      }
      board[r] = 0;
      quiet = 0;
    } else {
      if (m.remove != null) {
        board[m.to] = 0;
        if (m.from != null) {
          board[m.from!] = who;
        } else {
          toPlace[who - 1]++;
        }
        return false;
      }
      quiet++;
    }
    current = 3 - who;
    _checkEnd();
    return true;
  }

  void _checkEnd() {
    final opp = current;
    if (!placing(opp) && count(opp) < 3) {
      winner = 3 - opp;
    } else if (steps(opp).isEmpty) {
      winner = 3 - opp;
    } else if (quiet >= drawAfter) {
      winner = 0;
    }
  }

  Map<String, Object?> toJson() => {'board': board, 'place': toPlace, 'current': current, 'quiet': quiet, 'winner': winner};

  static MuehleGame fromJson(Map<String, dynamic> j) => MuehleGame._(
        [for (final v in j['board'] as List) v as int],
        [for (final v in j['place'] as List) v as int],
        j['current'] as int,
        j['quiet'] as int,
        j['winner'] as int?,
      );
}

int _eval(MuehleGame g, int me) {
  final w = g.winner;
  if (w != null) return w == 0 ? 0 : (w == me ? 100000 : -100000);
  final opp = 3 - me;
  var s = 0;
  s += 100 * ((g.count(me) + g.toPlace[me - 1]) - (g.count(opp) + g.toPlace[opp - 1]));
  for (final m in muehleMills) {
    final mine = m.where((x) => g.board[x] == me).length;
    final theirs = m.where((x) => g.board[x] == opp).length;
    if (mine == 3) s += 30;
    if (theirs == 3) s -= 30;
    if (mine == 2 && theirs == 0) s += 12;
    if (theirs == 2 && mine == 0) s -= 12;
  }
  s += 3 * (g.steps(me).length - g.steps(opp).length);
  return s;
}

int _search(MuehleGame g, int depth, int alpha, int beta, int me) {
  if (depth == 0 || g.over) return _eval(g, me);
  final ms = g.moves();
  final maximize = g.current == me;
  var best = maximize ? -1 << 30 : 1 << 30;
  for (final m in ms) {
    final c = g.copy()..play(m);
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

/// Stufen: 0 leicht (Tiefe 1), 1 mittel (Tiefe 2), 2 schwer (Tiefe 3).
MuehleMove muehleBotMove(MuehleGame g, int level, Random rng) {
  final ms = g.moves()..shuffle(rng);
  if (level == 0 && rng.nextDouble() < 0.3) return ms.first;
  final depth = [1, 2, 3][level];
  final me = g.current;
  var best = ms.first;
  var bestV = -1 << 30;
  for (final m in ms) {
    final c = g.copy()..play(m);
    final v = _search(c, depth - 1, -1 << 30, 1 << 30, me);
    if (v > bestV) {
      bestV = v;
      best = m;
    }
  }
  return best;
}
