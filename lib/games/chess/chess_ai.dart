import 'dart:math';

import 'chess_engine.dart';

/// Computergegner: Alpha-Beta-Suche mit Schlagzug-Verlängerung.
/// Die Stufen unterscheiden sich in Suchtiefe und eingestreuten Ungenauigkeiten.
enum ChessLevel {
  beginner('Anfänger', 50),
  easy('Leicht', 100),
  medium('Mittel', 200),
  hard('Schwer', 400);

  const ChessLevel(this.label, this.reward);
  final String label;

  /// Münzen für einen Sieg, ein Remis bringt die Hälfte.
  final int reward;
}

const _value = [0, 100, 320, 330, 500, 900, 0];

// Felderwerte aus Sicht von Weiß, Reihe 8 zuerst
const _pst = <List<int>>[
  [],
  [
    0, 0, 0, 0, 0, 0, 0, 0, //
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ],
  [
    -50, -40, -30, -30, -30, -30, -40, -50, //
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ],
  [
    -20, -10, -10, -10, -10, -10, -10, -20, //
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ],
  [
    0, 0, 0, 0, 0, 0, 0, 0, //
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ],
  [
    -20, -10, -10, -5, -5, -10, -10, -20, //
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ],
  [
    -30, -40, -40, -50, -50, -40, -40, -30, //
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ],
];

// König im Endspiel: lieber in die Mitte
const _kingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];

/// Bewertung aus Sicht der Seite am Zug.
int evaluate(ChessGame g) {
  var score = 0;
  var heavy = 0;
  for (final p in g.board) {
    final t = p.abs();
    if (t == queen) heavy += 2;
    if (t == rook || t == bishop || t == knight) heavy++;
  }
  final endgame = heavy <= 4;
  for (var sq = 0; sq < 64; sq++) {
    final p = g.board[sq];
    if (p == 0) continue;
    final t = p.abs();
    final idx = p > 0 ? (7 - rankOf(sq)) * 8 + fileOf(sq) : rankOf(sq) * 8 + fileOf(sq);
    final table = t == king && endgame ? _kingEnd : _pst[t];
    final v = _value[t] + table[idx];
    score += p > 0 ? v : -v;
  }
  return score * g.side;
}

const _mate = 100000;

class _Search {
  _Search(this.g, this.deadline);
  final ChessGame g;
  final DateTime? deadline;
  int nodes = 0;
  bool stopped = false;

  bool get _timeUp {
    if (deadline == null || (nodes & 1023) != 0) return stopped;
    if (DateTime.now().isAfter(deadline!)) stopped = true;
    return stopped;
  }

  int _order(ChessMove m) {
    final victim = g.board[m.to].abs();
    final attacker = g.board[m.from].abs();
    var s = 0;
    if (victim != 0) s += 10 * _value[victim] - _value[attacker];
    if (m.enPassant) s += 900;
    if (m.promo != 0) s += _value[m.promo] * 2;
    return s;
  }

  List<ChessMove> _sorted(List<ChessMove> moves) {
    final scored = [for (final m in moves) (m, _order(m))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }

  int quiesce(int alpha, int beta, int depth) {
    nodes++;
    final stand = evaluate(g);
    if (stand >= beta) return beta;
    if (alpha < stand) alpha = stand;
    if (depth <= 0 || _timeUp) return alpha;
    final us = g.side;
    for (final m in _sorted(g.pseudoMoves(capturesOnly: true))) {
      g.make(m, track: false);
      if (g.inCheck(us)) {
        g.unmake(track: false);
        continue;
      }
      final score = -quiesce(-beta, -alpha, depth - 1);
      g.unmake(track: false);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int search(int depth, int alpha, int beta, int ply, bool quiet) {
    nodes++;
    if (_timeUp) return 0;
    if (depth <= 0) return quiet ? quiesce(alpha, beta, 6) : evaluate(g);
    final moves = g.legalMoves();
    if (moves.isEmpty) return g.inCheck() ? -_mate + ply : 0;
    if (g.halfmove >= 100) return 0;
    var best = -_mate * 2;
    for (final m in _sorted(moves)) {
      g.make(m, track: false);
      final score = -search(depth - 1, -beta, -alpha, ply + 1, quiet);
      g.unmake(track: false);
      if (stopped) return 0;
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }
}

/// Wählt einen Zug für die Seite am Zug. Läuft ohne Oberfläche, auch in einem Isolate.
ChessMove? chessBestMove(String fen, ChessLevel level, {int? seed}) {
  final g = ChessGame.fromFen(fen);
  final rng = Random(seed);
  final moves = g.legalMoves();
  if (moves.isEmpty) return null;
  if (moves.length == 1) return moves.first;

  switch (level) {
    case ChessLevel.hard:
      final deadline = DateTime.now().add(const Duration(milliseconds: 2500));
      final s = _Search(g, deadline);
      var order = s._sorted(moves);
      ChessMove best = order.first;
      for (var depth = 1; depth <= 6; depth++) {
        var alpha = -_mate * 2;
        ChessMove? bestThis;
        final scores = <ChessMove, int>{};
        for (final m in order) {
          g.make(m, track: false);
          final score = -s.search(depth - 1, -_mate * 2, -alpha, 1, true);
          g.unmake(track: false);
          if (s.stopped) break;
          scores[m] = score;
          if (score > alpha) {
            alpha = score;
            bestThis = m;
          }
        }
        if (s.stopped) break;
        if (bestThis != null) best = bestThis;
        // Bester Zug zuerst für die nächste Runde
        order = [...order]..sort((a, b) => (scores[b] ?? -_mate * 2).compareTo(scores[a] ?? -_mate * 2));
        if (alpha > _mate - 100) break;
      }
      return best;
    default:
      final (depth, noise, blunder) = switch (level) {
        ChessLevel.beginner => (1, 150, 0.2),
        ChessLevel.easy => (2, 60, 0.05),
        _ => (3, 15, 0.0),
      };
      if (rng.nextDouble() < blunder) return moves[rng.nextInt(moves.length)];
      final s = _Search(g, null);
      final scored = <(ChessMove, int)>[];
      for (final m in moves) {
        g.make(m, track: false);
        final score = -s.search(depth - 1, -_mate * 2, _mate * 2, 1, level != ChessLevel.beginner);
        g.unmake(track: false);
        scored.add((m, score + rng.nextInt(noise + 1)));
      }
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.first.$1;
  }
}
