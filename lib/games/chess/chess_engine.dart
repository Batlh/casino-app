/// Schachregeln ohne Oberfläche: Züge, Schach, Matt, Patt und Remis.
///
/// Felder 0 bis 63, a1 = 0, h1 = 7, a8 = 56. Figuren als Zahlen: Weiß positiv,
/// Schwarz negativ, 1 Bauer, 2 Springer, 3 Läufer, 4 Turm, 5 Dame, 6 König.
library;

const pawn = 1;
const knight = 2;
const bishop = 3;
const rook = 4;
const queen = 5;
const king = 6;

const white = 1;
const black = -1;

const _castleWK = 1;
const _castleWQ = 2;
const _castleBK = 4;
const _castleBQ = 8;

int fileOf(int sq) => sq & 7;
int rankOf(int sq) => sq >> 3;

String squareName(int sq) => '${'abcdefgh'[fileOf(sq)]}${rankOf(sq) + 1}';

int squareFromName(String s) => (s.codeUnitAt(0) - 97) + (s.codeUnitAt(1) - 49) * 8;

class ChessMove {
  const ChessMove(this.from, this.to, {this.promo = 0, this.castle = false, this.enPassant = false});

  final int from;
  final int to;

  /// Figur, in die ein Bauer umgewandelt wird, sonst 0.
  final int promo;
  final bool castle;
  final bool enPassant;

  @override
  bool operator ==(Object other) =>
      other is ChessMove && other.from == from && other.to == to && other.promo == promo;

  @override
  int get hashCode => Object.hash(from, to, promo);

  /// Langschreibweise wie e2e4 oder e7e8q.
  String get uci => '${squareName(from)}${squareName(to)}${promo == 0 ? '' : ' nbrqk'[promo]}';

  @override
  String toString() => uci;
}

class _Undo {
  _Undo(this.move, this.captured, this.castling, this.ep, this.halfmove);
  final ChessMove move;
  final int captured;
  final int castling;
  final int ep;
  final int halfmove;
}

enum ChessResult { none, whiteMates, blackMates, stalemate, fiftyMoves, repetition, material }

const _knightSteps = [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2],
];
const _kingSteps = [
  [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1],
];
const _rookDirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const _bishopDirs = [[1, 1], [1, -1], [-1, 1], [-1, -1]];

class ChessGame {
  ChessGame() {
    loadFen(startFen);
  }

  ChessGame.fromFen(String fen) {
    loadFen(fen);
  }

  static const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  List<int> board = List.filled(64, 0);
  int side = white;
  int castling = 0;
  int ep = -1;
  int halfmove = 0;
  int fullmove = 1;
  final List<_Undo> _undo = [];
  final Map<String, int> _seen = {};

  /// Gespielte Züge, für die Anzeige.
  List<ChessMove> get moves => [for (final u in _undo) u.move];
  ChessMove? get lastMove => _undo.isEmpty ? null : _undo.last.move;

  /// Zuletzt geschlagene Figuren beider Seiten.
  List<int> get captured => [for (final u in _undo) if (u.captured != 0) u.captured];

  ChessGame copy() {
    final g = ChessGame._empty()
      ..board = board.toList()
      ..side = side
      ..castling = castling
      ..ep = ep
      ..halfmove = halfmove
      ..fullmove = fullmove;
    g._undo.addAll(_undo);
    g._seen.addAll(_seen);
    return g;
  }

  ChessGame._empty();

  void loadFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    board = List.filled(64, 0);
    var rank = 7;
    var file = 0;
    for (final ch in parts[0].split('')) {
      if (ch == '/') {
        rank--;
        file = 0;
      } else if (RegExp(r'\d').hasMatch(ch)) {
        file += int.parse(ch);
      } else {
        final type = ' pnbrqk'.indexOf(ch.toLowerCase());
        board[rank * 8 + file] = ch == ch.toUpperCase() ? type : -type;
        file++;
      }
    }
    side = parts.length > 1 && parts[1] == 'b' ? black : white;
    castling = 0;
    final c = parts.length > 2 ? parts[2] : '-';
    if (c.contains('K')) castling |= _castleWK;
    if (c.contains('Q')) castling |= _castleWQ;
    if (c.contains('k')) castling |= _castleBK;
    if (c.contains('q')) castling |= _castleBQ;
    ep = parts.length > 3 && parts[3] != '-' ? squareFromName(parts[3]) : -1;
    halfmove = parts.length > 4 ? int.parse(parts[4]) : 0;
    fullmove = parts.length > 5 ? int.parse(parts[5]) : 1;
    _undo.clear();
    _seen
      ..clear()
      ..[_key] = 1;
  }

  String get fen {
    final b = StringBuffer();
    for (var r = 7; r >= 0; r--) {
      var empty = 0;
      for (var f = 0; f < 8; f++) {
        final p = board[r * 8 + f];
        if (p == 0) {
          empty++;
          continue;
        }
        if (empty > 0) b.write(empty);
        empty = 0;
        final ch = ' pnbrqk'[p.abs()];
        b.write(p > 0 ? ch.toUpperCase() : ch);
      }
      if (empty > 0) b.write(empty);
      if (r > 0) b.write('/');
    }
    var c = '';
    if (castling & _castleWK != 0) c += 'K';
    if (castling & _castleWQ != 0) c += 'Q';
    if (castling & _castleBK != 0) c += 'k';
    if (castling & _castleBQ != 0) c += 'q';
    return '$b ${side == white ? 'w' : 'b'} ${c.isEmpty ? '-' : c} '
        '${ep < 0 ? '-' : squareName(ep)} $halfmove $fullmove';
  }

  /// Stellung ohne Zugzähler, für die dreifache Wiederholung.
  String get _key => '${board.join(',')}|$side|$castling|$ep';

  int kingSquare(int color) => board.indexOf(king * color);

  /// Greift eine Figur der Farbe [by] das Feld an?
  bool attacked(int sq, int by) {
    final f = fileOf(sq);
    final r = rankOf(sq);
    bool at(int df, int dr, int piece) {
      final ff = f + df;
      final rr = r + dr;
      return ff >= 0 && ff < 8 && rr >= 0 && rr < 8 && board[rr * 8 + ff] == piece;
    }

    // Bauern greifen schräg nach vorn an
    if (at(-1, -by, pawn * by) || at(1, -by, pawn * by)) return true;
    for (final s in _knightSteps) {
      if (at(s[0], s[1], knight * by)) return true;
    }
    for (final s in _kingSteps) {
      if (at(s[0], s[1], king * by)) return true;
    }
    for (final d in _rookDirs) {
      if (_slideHits(f, r, d[0], d[1], by, rook)) return true;
    }
    for (final d in _bishopDirs) {
      if (_slideHits(f, r, d[0], d[1], by, bishop)) return true;
    }
    return false;
  }

  bool _slideHits(int f, int r, int df, int dr, int by, int type) {
    var ff = f + df;
    var rr = r + dr;
    while (ff >= 0 && ff < 8 && rr >= 0 && rr < 8) {
      final p = board[rr * 8 + ff];
      if (p != 0) return p == type * by || p == queen * by;
      ff += df;
      rr += dr;
    }
    return false;
  }

  bool inCheck([int? color]) {
    final c = color ?? side;
    final k = kingSquare(c);
    return k >= 0 && attacked(k, -c);
  }

  /// Alle Züge ohne Rücksicht auf den eigenen König.
  List<ChessMove> pseudoMoves({bool capturesOnly = false}) {
    final out = <ChessMove>[];
    final us = side;
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0 || p.sign != us) continue;
      final f = fileOf(sq);
      final r = rankOf(sq);
      switch (p.abs()) {
        case pawn:
          final fwd = r + us;
          final lastRank = us == white ? 7 : 0;
          void add(int to) {
            if (rankOf(to) == lastRank) {
              for (final pr in [queen, rook, bishop, knight]) {
                out.add(ChessMove(sq, to, promo: pr));
              }
            } else {
              out.add(ChessMove(sq, to));
            }
          }

          if (fwd >= 0 && fwd < 8) {
            final one = fwd * 8 + f;
            if (!capturesOnly && board[one] == 0) {
              add(one);
              final startRank = us == white ? 1 : 6;
              final two = (r + 2 * us) * 8 + f;
              if (r == startRank && board[two] == 0) out.add(ChessMove(sq, two));
            } else if (capturesOnly && board[one] == 0 && fwd == lastRank) {
              add(one);
            }
            for (final df in [-1, 1]) {
              final ff = f + df;
              if (ff < 0 || ff > 7) continue;
              final to = fwd * 8 + ff;
              if (board[to] != 0 && board[to].sign == -us) {
                add(to);
              } else if (to == ep) {
                out.add(ChessMove(sq, to, enPassant: true));
              }
            }
          }
        case knight:
          _steps(sq, f, r, _knightSteps, out, capturesOnly);
        case king:
          _steps(sq, f, r, _kingSteps, out, capturesOnly);
          if (!capturesOnly) _castles(sq, out);
        case bishop:
          _slides(sq, f, r, _bishopDirs, out, capturesOnly);
        case rook:
          _slides(sq, f, r, _rookDirs, out, capturesOnly);
        case queen:
          _slides(sq, f, r, _bishopDirs, out, capturesOnly);
          _slides(sq, f, r, _rookDirs, out, capturesOnly);
      }
    }
    return out;
  }

  void _steps(int sq, int f, int r, List<List<int>> steps, List<ChessMove> out, bool capturesOnly) {
    for (final s in steps) {
      final ff = f + s[0];
      final rr = r + s[1];
      if (ff < 0 || ff > 7 || rr < 0 || rr > 7) continue;
      final to = rr * 8 + ff;
      final t = board[to];
      if (t == 0 ? !capturesOnly : t.sign != side) out.add(ChessMove(sq, to));
    }
  }

  void _slides(int sq, int f, int r, List<List<int>> dirs, List<ChessMove> out, bool capturesOnly) {
    for (final d in dirs) {
      var ff = f + d[0];
      var rr = r + d[1];
      while (ff >= 0 && ff < 8 && rr >= 0 && rr < 8) {
        final to = rr * 8 + ff;
        final t = board[to];
        if (t == 0) {
          if (!capturesOnly) out.add(ChessMove(sq, to));
        } else {
          if (t.sign != side) out.add(ChessMove(sq, to));
          break;
        }
        ff += d[0];
        rr += d[1];
      }
    }
  }

  void _castles(int sq, List<ChessMove> out) {
    final us = side;
    final home = us == white ? 4 : 60;
    if (sq != home || attacked(home, -us)) return;
    final kSide = us == white ? _castleWK : _castleBK;
    final qSide = us == white ? _castleWQ : _castleBQ;
    if (castling & kSide != 0 &&
        board[home + 1] == 0 &&
        board[home + 2] == 0 &&
        board[home + 3] == rook * us &&
        !attacked(home + 1, -us) &&
        !attacked(home + 2, -us)) {
      out.add(ChessMove(home, home + 2, castle: true));
    }
    if (castling & qSide != 0 &&
        board[home - 1] == 0 &&
        board[home - 2] == 0 &&
        board[home - 3] == 0 &&
        board[home - 4] == rook * us &&
        !attacked(home - 1, -us) &&
        !attacked(home - 2, -us)) {
      out.add(ChessMove(home, home - 2, castle: true));
    }
  }

  /// Alle erlaubten Züge der Seite am Zug.
  List<ChessMove> legalMoves({bool capturesOnly = false}) {
    final us = side;
    final out = <ChessMove>[];
    for (final m in pseudoMoves(capturesOnly: capturesOnly)) {
      make(m, track: false);
      if (!inCheck(us)) out.add(m);
      unmake(track: false);
    }
    return out;
  }

  List<ChessMove> movesFrom(int sq) => [for (final m in legalMoves()) if (m.from == sq) m];

  void make(ChessMove m, {bool track = true}) {
    final p = board[m.from];
    var captured = board[m.to];
    _undo.add(_Undo(m, captured, castling, ep, halfmove));
    board[m.to] = m.promo != 0 ? m.promo * side : p;
    board[m.from] = 0;
    if (m.enPassant) {
      final capSq = m.to - 8 * side;
      captured = board[capSq];
      board[capSq] = 0;
      _undo[_undo.length - 1] = _Undo(m, captured, castling, ep, halfmove);
    }
    if (m.castle) {
      if (m.to > m.from) {
        board[m.from + 1] = board[m.from + 3];
        board[m.from + 3] = 0;
      } else {
        board[m.from - 1] = board[m.from - 4];
        board[m.from - 4] = 0;
      }
    }
    // Rochaderechte gehen verloren, sobald König oder Turm ziehen oder ein Turm fällt
    for (final sq in [m.from, m.to]) {
      switch (sq) {
        case 4:
          castling &= ~(_castleWK | _castleWQ);
        case 60:
          castling &= ~(_castleBK | _castleBQ);
        case 0:
          castling &= ~_castleWQ;
        case 7:
          castling &= ~_castleWK;
        case 56:
          castling &= ~_castleBQ;
        case 63:
          castling &= ~_castleBK;
      }
    }
    ep = p.abs() == pawn && (m.to - m.from).abs() == 16 ? (m.from + m.to) ~/ 2 : -1;
    halfmove = p.abs() == pawn || captured != 0 ? 0 : halfmove + 1;
    if (side == black) fullmove++;
    side = -side;
    if (track) _seen[_key] = (_seen[_key] ?? 0) + 1;
  }

  void unmake({bool track = true}) {
    if (_undo.isEmpty) return;
    if (track) {
      final k = _key;
      final n = (_seen[k] ?? 1) - 1;
      if (n <= 0) {
        _seen.remove(k);
      } else {
        _seen[k] = n;
      }
    }
    final u = _undo.removeLast();
    final m = u.move;
    side = -side;
    if (side == black) fullmove--;
    final moved = m.promo != 0 ? pawn * side : board[m.to];
    board[m.from] = moved;
    if (m.enPassant) {
      board[m.to] = 0;
      board[m.to - 8 * side] = u.captured;
    } else {
      board[m.to] = u.captured;
    }
    if (m.castle) {
      if (m.to > m.from) {
        board[m.from + 3] = board[m.from + 1];
        board[m.from + 1] = 0;
      } else {
        board[m.from - 4] = board[m.from - 1];
        board[m.from - 1] = 0;
      }
    }
    castling = u.castling;
    ep = u.ep;
    halfmove = u.halfmove;
  }

  bool get canUndo => _undo.isNotEmpty;

  bool _insufficient() {
    final rest = <int>[];
    final bishopColors = <int>{};
    for (var sq = 0; sq < 64; sq++) {
      final t = board[sq].abs();
      if (t == 0 || t == king) continue;
      if (t == pawn || t == rook || t == queen) return false;
      rest.add(t);
      if (t == bishop) bishopColors.add((fileOf(sq) + rankOf(sq)) % 2);
    }
    if (rest.length <= 1) return true;
    // Nur Läufer auf Feldern einer Farbe
    return rest.every((t) => t == bishop) && bishopColors.length == 1;
  }

  ChessResult get result {
    if (legalMoves().isEmpty) {
      if (inCheck()) return side == white ? ChessResult.blackMates : ChessResult.whiteMates;
      return ChessResult.stalemate;
    }
    if (halfmove >= 100) return ChessResult.fiftyMoves;
    if ((_seen[_key] ?? 0) >= 3) return ChessResult.repetition;
    if (_insufficient()) return ChessResult.material;
    return ChessResult.none;
  }

  /// Zählt alle Zugfolgen bis zur Tiefe, zum Prüfen der Zuggenerierung.
  int perft(int depth) {
    if (depth == 0) return 1;
    final moves = legalMoves();
    if (depth == 1) return moves.length;
    var n = 0;
    for (final m in moves) {
      make(m, track: false);
      n += perft(depth - 1);
      unmake(track: false);
    }
    return n;
  }
}

String resultText(ChessResult r) => switch (r) {
      ChessResult.none => '',
      ChessResult.whiteMates => 'Schachmatt, Weiß gewinnt',
      ChessResult.blackMates => 'Schachmatt, Schwarz gewinnt',
      ChessResult.stalemate => 'Patt, Remis',
      ChessResult.fiftyMoves => 'Remis nach 50 Zügen ohne Schlagen oder Bauernzug',
      ChessResult.repetition => 'Remis durch dreifache Wiederholung',
      ChessResult.material => 'Remis, zu wenig Material zum Mattsetzen',
    };
