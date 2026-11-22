import 'dart:math';

import 'chess_engine.dart';

/// Computergegner: Alpha-Beta-Suche mit Schlagzug-Verlängerung.
/// Die Stufen unterscheiden sich in Suchtiefe und eingestreuten Ungenauigkeiten.
/// Ab „Schwer“ rechnet eine stärkere Suche mit Zugumstellungstabelle, Nullzug, Killerzügen
/// und einer ausführlicheren Stellungsbewertung; Profi und Meister bekommen mehr Bedenkzeit.
enum ChessLevel {
  beginner('Anfänger', 50),
  easy('Leicht', 100),
  medium('Mittel', 200),
  hard('Schwer', 400),
  expert('Profi', 600),
  master('Meister', 800);

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
    case ChessLevel.expert:
    case ChessLevel.master:
      final (ms, maxDepth) = switch (level) {
        ChessLevel.hard => (1200, 5),
        ChessLevel.expert => (3000, 64),
        _ => (6000, 64),
      };
      return _Strong(g, DateTime.now().add(Duration(milliseconds: ms))).best(moves, maxDepth);
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

// ---------- Starke Suche ab „Schwer“ ----------

final _zRng = Random(20261122);
int _z() => (_zRng.nextInt(1 << 30) << 32) ^ (_zRng.nextInt(1 << 30) << 12) ^ _zRng.nextInt(1 << 30);
final _zPiece = List<int>.generate(13 * 64, (_) => _z());
final _zSide = _z();
final _zCastle = List<int>.generate(16, (_) => _z());
final _zEp = List<int>.generate(8, (_) => _z());

int _hash(ChessGame g) {
  var h = g.side == white ? _zSide : 0;
  for (var sq = 0; sq < 64; sq++) {
    final p = g.board[sq];
    if (p != 0) h ^= _zPiece[(p + 6) * 64 + sq];
  }
  h ^= _zCastle[g.castling & 15];
  if (g.ep >= 0) h ^= _zEp[fileOf(g.ep)];
  return h;
}

int _enc(ChessMove m) => m.from | (m.to << 6) | (m.promo << 12);

const _passed = [0, 5, 10, 20, 35, 60, 100, 0];
const _knightJumps = [[1, 2], [2, 1], [-1, 2], [-2, 1], [1, -2], [2, -1], [-1, -2], [-2, -1]];
const _diag = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
const _straight = [[1, 0], [-1, 0], [0, 1], [0, -1]];

int _slide(List<int> b, int sq, List<List<int>> dirs, int color) {
  var n = 0;
  final f0 = fileOf(sq), r0 = rankOf(sq);
  for (final d in dirs) {
    var f = f0 + d[0], r = r0 + d[1];
    while (f >= 0 && f < 8 && r >= 0 && r < 8) {
      final q = b[r * 8 + f];
      if (q == 0) {
        n++;
      } else {
        if (q.sign != color) n++;
        break;
      }
      f += d[0];
      r += d[1];
    }
  }
  return n;
}

/// Ausführlichere Bewertung aus Sicht der Seite am Zug: Mittel- und Endspiel gleitend,
/// Bauernstruktur, Freibauern, Läuferpaar, offene Linien, Beweglichkeit und Königsschutz.
int evaluateStrong(ChessGame g) {
  final b = g.board;
  final pawnsW = List<int>.filled(8, 0), pawnsB = List<int>.filled(8, 0);
  var phase = 0, bishopsW = 0, bishopsB = 0;
  for (var sq = 0; sq < 64; sq++) {
    final p = b[sq];
    switch (p.abs()) {
      case pawn:
        if (p > 0) {
          pawnsW[fileOf(sq)]++;
        } else {
          pawnsB[fileOf(sq)]++;
        }
      case knight:
        phase += 1;
      case bishop:
        phase += 1;
        if (p > 0) {
          bishopsW++;
        } else {
          bishopsB++;
        }
      case rook:
        phase += 2;
      case queen:
        phase += 4;
    }
  }
  if (phase > 24) phase = 24;
  var mg = 0, eg = 0;
  for (var sq = 0; sq < 64; sq++) {
    final p = b[sq];
    if (p == 0) continue;
    final t = p.abs();
    final c = p.sign;
    final f = fileOf(sq), r = rankOf(sq);
    final idx = c > 0 ? (7 - r) * 8 + f : r * 8 + f;
    var m = _value[t], e = _value[t];
    if (t == king) {
      m += _pst[king][idx];
      e += _kingEnd[idx];
      // Bauernschild vor dem König
      final fwd = c;
      for (var df = -1; df <= 1; df++) {
        final ff = f + df;
        if (ff < 0 || ff > 7) continue;
        final r1 = r + fwd, r2 = r + 2 * fwd;
        if (r1 >= 0 && r1 < 8 && b[r1 * 8 + ff] == pawn * c) {
          m += 12;
        } else if (r2 >= 0 && r2 < 8 && b[r2 * 8 + ff] == pawn * c) {
          m += 6;
        } else {
          m -= 8;
        }
      }
    } else {
      m += _pst[t][idx];
      e += _pst[t][idx];
    }
    final own = c > 0 ? pawnsW : pawnsB;
    final opp = c > 0 ? pawnsB : pawnsW;
    switch (t) {
      case pawn:
        if (own[f] > 1) {
          m -= 10;
          e -= 20;
        }
        if ((f == 0 || own[f - 1] == 0) && (f == 7 || own[f + 1] == 0)) {
          m -= 10;
          e -= 15;
        }
        // Freibauer: kein gegnerischer Bauer davor auf eigener oder Nachbarlinie
        var free = true;
        for (var df = -1; df <= 1 && free; df++) {
          final ff = f + df;
          if (ff < 0 || ff > 7) continue;
          for (var rr = r + c; rr >= 0 && rr < 8; rr += c) {
            if (b[rr * 8 + ff] == -pawn * c) {
              free = false;
              break;
            }
          }
        }
        if (free) {
          final adv = c > 0 ? r : 7 - r;
          m += _passed[adv] ~/ 2;
          e += _passed[adv];
        }
      case knight:
        var n = 0;
        for (final j in _knightJumps) {
          final ff = f + j[0], rr = r + j[1];
          if (ff >= 0 && ff < 8 && rr >= 0 && rr < 8 && b[rr * 8 + ff].sign != c) n++;
        }
        m += 4 * (n - 4);
        e += 4 * (n - 4);
      case bishop:
        final n = _slide(b, sq, _diag, c);
        m += 4 * (n - 6);
        e += 4 * (n - 6);
      case rook:
        final n = _slide(b, sq, _straight, c);
        m += 2 * (n - 7);
        e += 4 * (n - 7);
        if (own[f] == 0) {
          m += opp[f] == 0 ? 20 : 10;
          e += opp[f] == 0 ? 10 : 5;
        }
      case queen:
        final n = _slide(b, sq, _straight, c) + _slide(b, sq, _diag, c);
        m += n - 13;
        e += 2 * (n - 13);
    }
    if (c > 0) {
      mg += m;
      eg += e;
    } else {
      mg -= m;
      eg -= e;
    }
  }
  if (bishopsW >= 2) {
    mg += 30;
    eg += 50;
  }
  if (bishopsB >= 2) {
    mg -= 30;
    eg -= 50;
  }
  final score = (mg * phase + eg * (24 - phase)) ~/ 24;
  return score * g.side + 10;
}

const _ttSize = 1 << 18;
const _exact = 0, _lower = 1, _upper = 2;

class _Strong {
  _Strong(this.g, this.deadline);
  final ChessGame g;
  final DateTime deadline;
  int nodes = 0;
  bool stopped = false;
  final _ttKey = List<int>.filled(_ttSize, 0);
  final _ttScore = List<int>.filled(_ttSize, 0);
  final _ttDepth = List<int>.filled(_ttSize, -1);
  final _ttFlag = List<int>.filled(_ttSize, 0);
  final _ttMove = List<int>.filled(_ttSize, 0);
  final _killers = List<int>.filled(256, 0);
  final _history = List<int>.filled(64 * 64, 0);
  final _path = <int>[];

  void _tick() {
    if ((++nodes & 2047) == 0 && DateTime.now().isAfter(deadline)) stopped = true;
  }

  int _score(ChessMove m, int ttMove, int ply) {
    final e = _enc(m);
    if (e == ttMove) return 10000000;
    final victim = m.enPassant ? pawn : g.board[m.to].abs();
    if (victim != 0) return 1000000 + 10 * _value[victim] - _value[g.board[m.from].abs()];
    if (m.promo != 0) return 900000 + _value[m.promo];
    if (ply < 128) {
      if (_killers[ply * 2] == e) return 800000;
      if (_killers[ply * 2 + 1] == e) return 700000;
    }
    return _history[m.from * 64 + m.to];
  }

  List<ChessMove> _order(List<ChessMove> moves, int ttMove, int ply) {
    final scored = [for (final m in moves) (m, _score(m, ttMove, ply))];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final s in scored) s.$1];
  }

  bool _hasPieces(int color) {
    for (final p in g.board) {
      if (p.sign == color && p.abs() != pawn && p.abs() != king) return true;
    }
    return false;
  }

  int _quiesce(int alpha, int beta, int depth) {
    _tick();
    if (stopped) return 0;
    final stand = evaluateStrong(g);
    if (stand >= beta) return stand;
    if (alpha < stand) alpha = stand;
    if (depth <= 0) return alpha;
    final us = g.side;
    for (final m in _order(g.pseudoMoves(capturesOnly: true), 0, 200)) {
      final victim = m.enPassant ? pawn : g.board[m.to].abs();
      if (m.promo == 0 && stand + _value[victim] + 200 < alpha) continue;
      g.make(m, track: false);
      if (g.inCheck(us)) {
        g.unmake(track: false);
        continue;
      }
      final score = -_quiesce(-beta, -alpha, depth - 1);
      g.unmake(track: false);
      if (stopped) return 0;
      if (score >= beta) return score;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int _search(int depth, int alpha, int beta, int ply, bool allowNull) {
    _tick();
    if (stopped) return 0;
    final key = _hash(g);
    if (ply > 0) {
      if (g.halfmove >= 100) return 0;
      final n = _path.length;
      for (var i = n - 2; i >= 0 && i >= n - g.halfmove; i -= 2) {
        if (_path[i] == key) return 0;
      }
    }
    final check = g.inCheck();
    if (check) depth++;
    if (depth <= 0) return _quiesce(alpha, beta, 8);

    final slot = key & (_ttSize - 1);
    var ttMove = 0;
    if (_ttKey[slot] == key) {
      ttMove = _ttMove[slot];
      if (ply > 0 && _ttDepth[slot] >= depth) {
        var s = _ttScore[slot];
        if (s > _mate - 1000) s -= ply;
        if (s < -_mate + 1000) s += ply;
        final flag = _ttFlag[slot];
        if (flag == _exact || (flag == _lower && s >= beta) || (flag == _upper && s <= alpha)) return s;
      }
    }

    final pv = beta - alpha > 1;
    if (allowNull && !check && !pv && depth >= 3 && _hasPieces(g.side) && evaluateStrong(g) >= beta) {
      final ep = g.ep;
      g.side = -g.side;
      g.ep = -1;
      _path.add(key);
      final s = -_search(depth - 3, -beta, -beta + 1, ply + 1, false);
      _path.removeLast();
      g.side = -g.side;
      g.ep = ep;
      if (stopped) return 0;
      if (s >= beta) return s;
    }

    final moves = g.legalMoves();
    if (moves.isEmpty) return check ? -_mate + ply : 0;
    final alpha0 = alpha;
    var best = -_mate * 2;
    var bestMove = 0;
    var i = 0;
    _path.add(key);
    for (final m in _order(moves, ttMove, ply)) {
      final quiet = g.board[m.to] == 0 && !m.enPassant && m.promo == 0;
      g.make(m, track: false);
      int score;
      if (i == 0) {
        score = -_search(depth - 1, -beta, -alpha, ply + 1, true);
      } else {
        final red = depth >= 3 && i >= 3 && quiet && !check ? (i >= 8 ? 2 : 1) : 0;
        score = -_search(depth - 1 - red, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && red > 0) score = -_search(depth - 1, -alpha - 1, -alpha, ply + 1, true);
        if (score > alpha && score < beta) score = -_search(depth - 1, -beta, -alpha, ply + 1, true);
      }
      g.unmake(track: false);
      if (stopped) {
        _path.removeLast();
        return 0;
      }
      if (score > best) {
        best = score;
        bestMove = _enc(m);
      }
      if (score > alpha) alpha = score;
      if (alpha >= beta) {
        if (quiet) {
          if (ply < 128 && _killers[ply * 2] != bestMove) {
            _killers[ply * 2 + 1] = _killers[ply * 2];
            _killers[ply * 2] = bestMove;
          }
          _history[m.from * 64 + m.to] += depth * depth;
        }
        break;
      }
      i++;
    }
    _path.removeLast();
    var stored = best;
    if (stored > _mate - 1000) stored += ply;
    if (stored < -_mate + 1000) stored -= ply;
    _ttKey[slot] = key;
    _ttScore[slot] = stored;
    _ttDepth[slot] = depth;
    _ttMove[slot] = bestMove;
    _ttFlag[slot] = best >= beta ? _lower : (best > alpha0 ? _exact : _upper);
    return best;
  }

  /// Iterative Vertiefung; liefert den besten Zug der letzten vollständigen Runde.
  ChessMove best(List<ChessMove> moves, int maxDepth) {
    var order = _order(moves, 0, 0);
    var choice = order.first;
    final key = _hash(g);
    for (var depth = 1; depth <= maxDepth; depth++) {
      var alpha = -_mate * 2;
      ChessMove? bestThis;
      var i = 0;
      _path.add(key);
      for (final m in order) {
        g.make(m, track: false);
        int score;
        if (i == 0) {
          score = -_search(depth - 1, -_mate * 2, -alpha, 1, true);
        } else {
          score = -_search(depth - 1, -alpha - 1, -alpha, 1, true);
          if (score > alpha && !stopped) score = -_search(depth - 1, -_mate * 2, -alpha, 1, true);
        }
        g.unmake(track: false);
        if (stopped) break;
        if (score > alpha) {
          alpha = score;
          bestThis = m;
        }
        i++;
      }
      _path.removeLast();
      // Auch eine abgebrochene Runde zählt, wenn ihr Zug schon besser bewertet war
      if (bestThis != null) choice = bestThis;
      if (stopped) break;
      order = [choice, for (final m in order) if (m != choice) m];
      if (alpha > _mate - 1000 || alpha < -_mate + 1000) break;
    }
    return choice;
  }
}
