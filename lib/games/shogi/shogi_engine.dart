/// Shogi-Regeln ohne Oberfläche.
///
/// Felder 0 bis 80, Reihe 0 oben (Seite von Gote), Spalte 0 links (Linie 9).
/// Sente (+1) zieht nach oben, Gote (-1) nach unten. Figuren als Zahlen mit Vorzeichen der Farbe.
library;

const sPawn = 1;
const sLance = 2;
const sKnight = 3;
const sSilver = 4;
const sGold = 5;
const sBishop = 6;
const sRook = 7;
const sKing = 8;

/// Beförderte Figuren: Grundtyp plus 8.
const promoted = 8;
const sTokin = 9;
const sHorse = 14;
const sDragon = 15;

const sente = 1;
const gote = -1;

int rowOf(int sq) => sq ~/ 9;
int colOf(int sq) => sq % 9;

bool canPromoteType(int t) => t >= sPawn && t <= sRook && t != sGold;
int baseType(int t) => t > promoted ? t - promoted : t;

/// Zielschreibweise wie 7g oder 5e.
String shogiSquareName(int sq) => '${9 - colOf(sq)}${'abcdefghi'[rowOf(sq)]}';
int shogiSquareFromName(String s) => (s.codeUnitAt(1) - 97) * 9 + (9 - int.parse(s[0]));

class ShogiMove {
  const ShogiMove(this.from, this.to, {this.promote = false}) : drop = 0;
  const ShogiMove.drop(this.drop, this.to)
      : from = -1,
        promote = false;

  /// Startfeld, -1 beim Einsetzen.
  final int from;
  final int to;

  /// Eingesetzte Figur, sonst 0.
  final int drop;
  final bool promote;

  bool get isDrop => from < 0;

  @override
  bool operator ==(Object other) =>
      other is ShogiMove && other.from == from && other.to == to && other.drop == drop && other.promote == promote;

  @override
  int get hashCode => Object.hash(from, to, drop, promote);

  /// USI-Schreibweise wie 7g7f, 8h2b+ oder P*5e.
  String get usi => isDrop
      ? '${' PLNSGBR'[drop]}*${shogiSquareName(to)}'
      : '${shogiSquareName(from)}${shogiSquareName(to)}${promote ? '+' : ''}';

  @override
  String toString() => usi;
}

class _Undo {
  _Undo(this.move, this.captured, this.moved);
  final ShogiMove move;
  final int captured;
  final int moved;
}

enum ShogiResult { none, senteWins, goteWins, repetition }

const _orth = [(-1, 0), (1, 0), (0, -1), (0, 1)];
const _diag = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

/// Einzelschritte einer Figur der Farbe c als (Zeile, Spalte).
List<(int, int)> stepsOf(int t, int c) {
  final f = -c;
  switch (t) {
    case sPawn:
      return [(f, 0)];
    case sKnight:
      return [(2 * f, -1), (2 * f, 1)];
    case sSilver:
      return [(f, -1), (f, 0), (f, 1), (-f, -1), (-f, 1)];
    case sGold:
    case sTokin:
    case 10:
    case 11:
    case 12:
      return [(f, -1), (f, 0), (f, 1), (0, -1), (0, 1), (-f, 0)];
    case sKing:
      return [..._orth, ..._diag];
    case sHorse:
      return _orth;
    case sDragon:
      return _diag;
  }
  return const [];
}

/// Richtungen, in die eine Figur beliebig weit zieht.
List<(int, int)> slidesOf(int t, int c) {
  switch (t) {
    case sLance:
      return [(-c, 0)];
    case sBishop:
    case sHorse:
      return _diag;
    case sRook:
    case sDragon:
      return _orth;
  }
  return const [];
}

class ShogiGame {
  ShogiGame() {
    loadSfen(startSfen);
  }

  ShogiGame.fromSfen(String sfen) {
    loadSfen(sfen);
  }

  ShogiGame._empty();

  static const startSfen = 'lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1';

  List<int> board = List.filled(81, 0);
  int side = sente;

  /// Figuren in der Hand, Index ist der Grundtyp 1 bis 7.
  List<int> handSente = List.filled(9, 0);
  List<int> handGote = List.filled(9, 0);
  final List<_Undo> _undo = [];
  final Map<String, int> _seen = {};

  List<int> hand(int c) => c == sente ? handSente : handGote;
  ShogiMove? get lastMove => _undo.isEmpty ? null : _undo.last.move;
  bool get canUndo => _undo.isNotEmpty;
  List<ShogiMove> get moves => [for (final u in _undo) u.move];
  int get plies => _undo.length;

  ShogiGame copy() {
    final g = ShogiGame._empty()
      ..board = board.toList()
      ..side = side
      ..handSente = handSente.toList()
      ..handGote = handGote.toList();
    g._undo.addAll(_undo);
    g._seen.addAll(_seen);
    return g;
  }

  void loadSfen(String sfen) {
    final parts = sfen.trim().split(RegExp(r'\s+'));
    board = List.filled(81, 0);
    handSente = List.filled(9, 0);
    handGote = List.filled(9, 0);
    var row = 0;
    var col = 0;
    var plus = false;
    for (final ch in parts[0].split('')) {
      if (ch == '/') {
        row++;
        col = 0;
      } else if (ch == '+') {
        plus = true;
      } else if (RegExp(r'\d').hasMatch(ch)) {
        col += int.parse(ch);
      } else {
        var t = ' plnsgbrk'.indexOf(ch.toLowerCase());
        t = const [0, sPawn, sLance, sKnight, sSilver, sGold, sBishop, sRook, sKing][t];
        if (plus) t += promoted;
        plus = false;
        board[row * 9 + col] = ch == ch.toUpperCase() ? t : -t;
        col++;
      }
    }
    side = parts.length > 1 && parts[1] == 'w' ? gote : sente;
    if (parts.length > 2 && parts[2] != '-') {
      var n = 0;
      for (final ch in parts[2].split('')) {
        if (RegExp(r'\d').hasMatch(ch)) {
          n = n * 10 + int.parse(ch);
          continue;
        }
        final t = const [0, sPawn, sLance, sKnight, sSilver, sGold, sBishop, sRook][' plnsgbr'.indexOf(ch.toLowerCase())];
        (ch == ch.toUpperCase() ? handSente : handGote)[t] += n == 0 ? 1 : n;
        n = 0;
      }
    }
    _undo.clear();
    _seen
      ..clear()
      ..[_key] = 1;
  }

  String get _key => '${board.join(',')}|$side|${handSente.join(',')}|${handGote.join(',')}';

  int kingSquare(int c) => board.indexOf(sKing * c);

  bool _on(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;

  /// Greift eine Figur der Farbe [by] das Feld an?
  bool attacked(int sq, int by) {
    final r = rowOf(sq);
    final c = colOf(sq);
    for (final t in const [sPawn, sKnight, sSilver, sGold, sTokin, 10, 11, 12, sKing, sHorse, sDragon]) {
      for (final (dr, dc) in stepsOf(t, by)) {
        final rr = r - dr;
        final cc = c - dc;
        if (_on(rr, cc) && board[rr * 9 + cc] == t * by) return true;
      }
    }
    for (final (dr, dc) in [..._orth, ..._diag]) {
      var rr = r - dr;
      var cc = c - dc;
      while (_on(rr, cc)) {
        final p = board[rr * 9 + cc];
        if (p != 0) {
          if (p.sign == by && slidesOf(p.abs(), by).contains((dr, dc))) return true;
          break;
        }
        rr -= dr;
        cc -= dc;
      }
    }
    return false;
  }

  bool inCheck([int? color]) {
    final c = color ?? side;
    final k = kingSquare(c);
    return k >= 0 && attacked(k, -c);
  }

  bool _inZone(int sq, int c) => c == sente ? rowOf(sq) <= 2 : rowOf(sq) >= 6;

  /// Muss die Figur auf diesem Feld befördert werden, weil sie sonst nie mehr ziehen könnte?
  bool mustPromote(int t, int to, int c) {
    final r = c == sente ? rowOf(to) : 8 - rowOf(to);
    if (t == sPawn || t == sLance) return r == 0;
    if (t == sKnight) return r <= 1;
    return false;
  }

  void _addBoardMove(List<ShogiMove> out, int from, int to, int t, int c) {
    final canPromote = canPromoteType(t) && (_inZone(from, c) || _inZone(to, c));
    if (canPromote) out.add(ShogiMove(from, to, promote: true));
    if (!mustPromote(t, to, c)) out.add(ShogiMove(from, to));
  }

  List<ShogiMove> pseudoMoves({bool capturesOnly = false}) {
    final out = <ShogiMove>[];
    final us = side;
    for (var sq = 0; sq < 81; sq++) {
      final p = board[sq];
      if (p == 0 || p.sign != us) continue;
      final t = p.abs();
      final r = rowOf(sq);
      final c = colOf(sq);
      for (final (dr, dc) in stepsOf(t, us)) {
        final rr = r + dr;
        final cc = c + dc;
        if (!_on(rr, cc)) continue;
        final to = rr * 9 + cc;
        final q = board[to];
        if (q == 0 ? capturesOnly : q.sign == us) continue;
        _addBoardMove(out, sq, to, t, us);
      }
      for (final (dr, dc) in slidesOf(t, us)) {
        var rr = r + dr;
        var cc = c + dc;
        while (_on(rr, cc)) {
          final to = rr * 9 + cc;
          final q = board[to];
          if (q == 0) {
            if (!capturesOnly) _addBoardMove(out, sq, to, t, us);
          } else {
            if (q.sign != us) _addBoardMove(out, sq, to, t, us);
            break;
          }
          rr += dr;
          cc += dc;
        }
      }
    }
    if (capturesOnly) return out;
    final h = hand(us);
    for (var t = sPawn; t <= sRook; t++) {
      if (h[t] == 0) continue;
      for (var to = 0; to < 81; to++) {
        if (board[to] != 0 || mustPromote(t, to, us)) continue;
        if (t == sPawn && _pawnOnColumn(colOf(to), us)) continue;
        out.add(ShogiMove.drop(t, to));
      }
    }
    return out;
  }

  bool _pawnOnColumn(int col, int c) {
    for (var r = 0; r < 9; r++) {
      if (board[r * 9 + col] == sPawn * c) return true;
    }
    return false;
  }

  List<ShogiMove> legalMoves({bool capturesOnly = false}) {
    final us = side;
    final out = <ShogiMove>[];
    for (final m in pseudoMoves(capturesOnly: capturesOnly)) {
      make(m, track: false);
      var ok = !inCheck(us);
      // Mit einem eingesetzten Bauern darf man nicht mattsetzen
      if (ok && m.isDrop && m.drop == sPawn && inCheck(-us) && _noMoves()) ok = false;
      unmake(track: false);
      if (ok) out.add(m);
    }
    return out;
  }

  bool _noMoves() {
    final us = side;
    for (final m in pseudoMoves()) {
      make(m, track: false);
      final ok = !inCheck(us);
      unmake(track: false);
      if (ok) return false;
    }
    return true;
  }

  List<ShogiMove> movesFrom(int sq) => [for (final m in legalMoves()) if (!m.isDrop && m.from == sq) m];
  List<ShogiMove> dropsOf(int t) => [for (final m in legalMoves()) if (m.isDrop && m.drop == t) m];

  void make(ShogiMove m, {bool track = true}) {
    final us = side;
    if (m.isDrop) {
      _undo.add(_Undo(m, 0, m.drop * us));
      hand(us)[m.drop]--;
      board[m.to] = m.drop * us;
    } else {
      final moved = board[m.from];
      final captured = board[m.to];
      _undo.add(_Undo(m, captured, moved));
      if (captured != 0) hand(us)[baseType(captured.abs())]++;
      board[m.to] = m.promote ? (moved.abs() + promoted) * us : moved;
      board[m.from] = 0;
    }
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
    side = -side;
    final m = u.move;
    if (m.isDrop) {
      board[m.to] = 0;
      hand(side)[m.drop]++;
    } else {
      board[m.from] = u.moved;
      board[m.to] = u.captured;
      if (u.captured != 0) hand(side)[baseType(u.captured.abs())]--;
    }
  }

  ShogiResult get result {
    if (legalMoves().isEmpty) return side == sente ? ShogiResult.goteWins : ShogiResult.senteWins;
    if ((_seen[_key] ?? 0) >= 4) return ShogiResult.repetition;
    return ShogiResult.none;
  }

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

/// Deutsche Namen der Figuren.
String shogiPieceName(int t) => switch (t) {
      sPawn => 'Bauer',
      sLance => 'Lanze',
      sKnight => 'Springer',
      sSilver => 'Silbergeneral',
      sGold => 'Goldgeneral',
      sBishop => 'Läufer',
      sRook => 'Turm',
      sKing => 'König',
      sTokin => 'Tokin',
      10 => 'Beförderte Lanze',
      11 => 'Beförderter Springer',
      12 => 'Beförderter Silbergeneral',
      sHorse => 'Drachenpferd',
      sDragon => 'Drachenkönig',
      _ => '',
    };

/// Schriftzeichen auf den Steinen.
String shogiKanji(int t, {bool gote = false}) => switch (t) {
      sPawn => '歩',
      sLance => '香',
      sKnight => '桂',
      sSilver => '銀',
      sGold => '金',
      sBishop => '角',
      sRook => '飛',
      sKing => gote ? '玉' : '王',
      sTokin => 'と',
      10 => '杏',
      11 => '圭',
      12 => '全',
      sHorse => '馬',
      sDragon => '龍',
      _ => '',
    };
