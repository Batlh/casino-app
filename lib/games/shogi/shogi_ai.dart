import 'dart:math';

import 'shogi_engine.dart';

enum ShogiLevel {
  beginner('Anfänger', 50),
  easy('Leicht', 100),
  medium('Mittel', 200),
  hard('Schwer', 400);

  const ShogiLevel(this.label, this.reward);
  final String label;
  final int reward;
}

const _value = [0, 100, 300, 350, 500, 550, 800, 950, 0, 550, 500, 500, 550, 0, 1050, 1250];

/// Bewertung aus Sicht der Seite am Zug: Material, Handfiguren, Vorrücken und Schutz des Königs.
int shogiEvaluate(ShogiGame g) {
  var score = 0;
  final kings = {sente: g.kingSquare(sente), gote: g.kingSquare(gote)};
  for (var sq = 0; sq < 81; sq++) {
    final p = g.board[sq];
    if (p == 0) continue;
    final c = p.sign;
    final t = p.abs();
    var v = _value[t];
    // Vorgerückte kleine Figuren sind etwas mehr wert
    if (t <= sSilver || (t >= sTokin && t <= 12)) {
      final advance = c == sente ? 8 - rowOf(sq) : rowOf(sq);
      v += advance * 4;
    }
    // Generäle neben dem eigenen König schützen ihn
    final k = kings[c]!;
    if (k >= 0 && (t == sGold || t == sSilver) && (rowOf(k) - rowOf(sq)).abs() <= 1 && (colOf(k) - colOf(sq)).abs() <= 1) {
      v += 30;
    }
    score += v * c;
  }
  for (var t = sPawn; t <= sRook; t++) {
    score += ((g.handSente[t] - g.handGote[t]) * _value[t] * 1.1).round();
  }
  return score * g.side;
}

const _mate = 100000;

class _Search {
  _Search(this.g, this.deadline);
  final ShogiGame g;
  final DateTime? deadline;
  int nodes = 0;
  bool stopped = false;

  bool get _timeUp {
    if (deadline == null || (nodes & 255) != 0) return stopped;
    if (DateTime.now().isAfter(deadline!)) stopped = true;
    return stopped;
  }

  int _order(ShogiMove m) {
    if (m.isDrop) return 0;
    final victim = g.board[m.to].abs();
    var s = victim == 0 ? 0 : 10 * _value[victim] - _value[g.board[m.from].abs()];
    if (m.promote) s += 300;
    return s;
  }

  List<ShogiMove> sorted(List<ShogiMove> moves) {
    final scored = [for (final m in moves) (m, _order(m))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }

  int quiesce(int alpha, int beta, int depth) {
    nodes++;
    final stand = shogiEvaluate(g);
    if (stand >= beta) return beta;
    if (alpha < stand) alpha = stand;
    if (depth <= 0 || _timeUp) return alpha;
    final us = g.side;
    for (final m in sorted(g.pseudoMoves(capturesOnly: true))) {
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
    if (depth <= 0) return quiet ? quiesce(alpha, beta, 4) : shogiEvaluate(g);
    final moves = g.legalMoves();
    if (moves.isEmpty) return -_mate + ply;
    var best = -_mate * 2;
    for (final m in sorted(moves)) {
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

ShogiMove? shogiBestMove(String sfen, ShogiLevel level, {int? seed}) {
  final g = ShogiGame.fromSfen(sfen);
  return shogiBestMoveFor(g, level, seed: seed);
}

ShogiMove? shogiBestMoveFor(ShogiGame g, ShogiLevel level, {int? seed}) {
  final rng = Random(seed);
  final moves = g.legalMoves();
  if (moves.isEmpty) return null;
  if (moves.length == 1) return moves.first;
  final (maxDepth, noise, blunder, ms) = switch (level) {
    ShogiLevel.beginner => (1, 160, 0.15, 0),
    ShogiLevel.easy => (2, 60, 0.03, 0),
    ShogiLevel.medium => (2, 15, 0.0, 0),
    ShogiLevel.hard => (4, 0, 0.0, 2500),
  };
  if (rng.nextDouble() < blunder) return moves[rng.nextInt(moves.length)];
  final s = _Search(g, ms > 0 ? DateTime.now().add(Duration(milliseconds: ms)) : null);
  var order = s.sorted(moves);
  var best = order.first;
  final quiet = level != ShogiLevel.beginner;
  for (var depth = ms > 0 ? 1 : maxDepth; depth <= maxDepth; depth++) {
    final scores = <ShogiMove, int>{};
    var alpha = -_mate * 2;
    ShogiMove? bestThis;
    for (final m in order) {
      g.make(m, track: false);
      final score = -s.search(depth - 1, -_mate * 2, noise > 0 ? _mate * 2 : -alpha, 1, quiet);
      g.unmake(track: false);
      if (s.stopped) break;
      final noisy = score + (noise > 0 ? rng.nextInt(noise + 1) : 0);
      scores[m] = noisy;
      if (noisy > alpha) {
        alpha = noisy;
        bestThis = m;
      }
    }
    if (s.stopped) break;
    if (bestThis != null) best = bestThis;
    order = [...order]..sort((a, b) => (scores[b] ?? -_mate * 2).compareTo(scores[a] ?? -_mate * 2));
    if (alpha > _mate - 100) break;
  }
  return best;
}
