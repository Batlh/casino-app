import 'dart:math';

/// Reversi auf 8×8. Feld: 0 leer, 1 Schwarz (beginnt), 2 Weiß.
class ReversiGame {
  ReversiGame() : board = List.filled(64, 0) {
    board[27] = 2;
    board[28] = 1;
    board[35] = 1;
    board[36] = 2;
  }

  ReversiGame._(this.board, this.current, this.passed);

  final List<int> board;
  int current = 1;

  /// Der letzte Spieler musste passen.
  bool passed = false;
  int? lastMove;

  static const _dirs = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)];

  ReversiGame copy() => ReversiGame._(List.of(board), current, passed)..lastMove = lastMove;

  int count(int who) => board.where((c) => c == who).length;

  /// Steine, die ein Zug auf [i] umdreht.
  List<int> flips(int i, int who) {
    if (board[i] != 0) return const [];
    final out = <int>[];
    final r0 = i ~/ 8;
    final c0 = i % 8;
    for (final (dr, dc) in _dirs) {
      final line = <int>[];
      var r = r0 + dr;
      var c = c0 + dc;
      while (r >= 0 && r < 8 && c >= 0 && c < 8 && board[r * 8 + c] == 3 - who) {
        line.add(r * 8 + c);
        r += dr;
        c += dc;
      }
      if (line.isNotEmpty && r >= 0 && r < 8 && c >= 0 && c < 8 && board[r * 8 + c] == who) out.addAll(line);
    }
    return out;
  }

  List<int> moves([int? who]) {
    final w = who ?? current;
    return [for (var i = 0; i < 64; i++) if (board[i] == 0 && flips(i, w).isNotEmpty) i];
  }

  bool get over => moves(1).isEmpty && moves(2).isEmpty;

  /// Gewinner 1 oder 2, 0 bei Gleichstand; null solange gespielt wird.
  int? get winner {
    if (!over) return null;
    final b = count(1);
    final w = count(2);
    return b == w ? 0 : (b > w ? 1 : 2);
  }

  bool play(int i) {
    final f = flips(i, current);
    if (f.isEmpty) return false;
    board[i] = current;
    for (final x in f) {
      board[x] = current;
    }
    lastMove = i;
    current = 3 - current;
    passed = false;
    if (moves().isEmpty && !over) {
      // Der andere kann nicht ziehen und muss passen
      current = 3 - current;
      passed = true;
    }
    return true;
  }

  Map<String, Object?> toJson() => {'board': board, 'current': current, 'passed': passed, 'last': lastMove};

  static ReversiGame fromJson(Map<String, dynamic> j) =>
      ReversiGame._([for (final v in j['board'] as List) v as int], j['current'] as int, j['passed'] as bool)
        ..lastMove = j['last'] as int?;
}

/// Feldwerte: Ecken stark, Felder neben den Ecken gefährlich.
const _weights = [
  100, -20, 10, 5, 5, 10, -20, 100, //
  -20, -50, -2, -2, -2, -2, -50, -20,
  10, -2, 1, 1, 1, 1, -2, 10,
  5, -2, 1, 0, 0, 1, -2, 5,
  5, -2, 1, 0, 0, 1, -2, 5,
  10, -2, 1, 1, 1, 1, -2, 10,
  -20, -50, -2, -2, -2, -2, -50, -20,
  100, -20, 10, 5, 5, 10, -20, 100,
];

int _eval(ReversiGame g, int me) {
  final w = g.winner;
  if (w != null) return w == 0 ? 0 : (w == me ? 100000 : -100000);
  var s = 0;
  for (var i = 0; i < 64; i++) {
    if (g.board[i] == me) {
      s += _weights[i];
    } else if (g.board[i] == 3 - me) {
      s -= _weights[i];
    }
  }
  s += 4 * (g.moves(me).length - g.moves(3 - me).length);
  return s;
}

int _search(ReversiGame g, int depth, int alpha, int beta, int me) {
  if (depth == 0 || g.over) return _eval(g, me);
  final ms = g.moves();
  final maximize = g.current == me;
  var best = maximize ? -1 << 30 : 1 << 30;
  for (final m in ms) {
    final c = g.copy()..play(m);
    final v = _search(c, depth - 1, alpha, beta, me);
    if (maximize) {
      best = max(best, v);
      alpha = max(alpha, v);
    } else {
      best = min(best, v);
      beta = min(beta, v);
    }
    if (beta <= alpha) break;
  }
  return best;
}

/// Stufen: 0 leicht (zufällig mit Vorliebe für Ecken), 1 mittel (Tiefe 2), 2 schwer (Tiefe 4).
int reversiBotMove(ReversiGame g, int level, Random rng) {
  final ms = g.moves();
  if (ms.length == 1) return ms.first;
  if (level == 0) {
    final corners = ms.where((m) => _weights[m] == 100).toList();
    if (corners.isNotEmpty) return corners.first;
    return ms[rng.nextInt(ms.length)];
  }
  final depth = level == 1 ? 2 : 4;
  final me = g.current;
  var best = ms.first;
  var bestV = -1 << 30;
  for (final m in ms..shuffle(rng)) {
    final c = g.copy()..play(m);
    final v = _search(c, depth - 1, -1 << 30, 1 << 30, me);
    if (v > bestV) {
      bestV = v;
      best = m;
    }
  }
  return best;
}
