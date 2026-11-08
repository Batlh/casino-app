import 'dart:math';

import '../eins/eins_engine.dart' show EinsColor, lightColors, colorName;

/// Viererkette: Steine in Spalten fallen lassen, vier gleiche Farben oder
/// Zahlen in einer Reihe gewinnen. Angelehnt an das Legespiel Quatro.
enum TileKind { number, swap, push, minusTwo }

class QTile {
  QTile(this.id, this.kind, this.color, [this.number = -1]);

  final int id;
  final TileKind kind;
  final EinsColor color;
  final int number;

  String get label => switch (kind) {
        TileKind.number => '${colorName(color)} $number',
        TileKind.swap => '${colorName(color)} Spaltentausch',
        TileKind.push => '${colorName(color)} Schieber',
        TileKind.minusTwo => '${colorName(color)} Minus zwei',
      };

  @override
  bool operator ==(Object other) => other is QTile && other.id == id;

  @override
  int get hashCode => id;
}

List<QTile> quatroBag() {
  var id = 0;
  return [
    for (final c in lightColors) ...[
      for (var n = 0; n <= 7; n++) QTile(id++, TileKind.number, c, n),
      QTile(id++, TileKind.swap, c),
      QTile(id++, TileKind.push, c),
      QTile(id++, TileKind.minusTwo, c),
    ],
  ];
}

class QPlayer {
  QPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<QTile> hand = [];

  /// Minus zwei: Erst nach dem eigenen Zug wird wieder aufgefüllt.
  bool short = false;
}

class QuatroEngine {
  QuatroEngine({required this.players, Random? rng, this.cols = 7, this.rows = 6})
      : _rng = rng ?? Random.secure();

  final List<QPlayer> players;
  final int cols;
  final int rows;
  final Random _rng;
  static const handSize = 3;

  /// Spalten von unten nach oben.
  late List<List<QTile>> board;
  List<QTile> bag = [];
  int current = 0;
  QPlayer? winner;
  bool draw = false;
  String lastEvent = '';

  /// Nach einem Spaltentausch-Stein wählt der Spieler zwei Spalten.
  bool swapPending = false;

  /// Felder der Gewinnreihe.
  List<(int, int)> winLine = [];
  int _passes = 0;

  QPlayer get actor => players[current];
  bool get finished => winner != null || draw;

  void start({int startPlayer = 0}) {
    board = List.generate(cols, (_) => <QTile>[]);
    bag = quatroBag()..shuffle(_rng);
    for (final p in players) {
      p.hand = [for (var i = 0; i < handSize; i++) bag.removeLast()];
      p.short = false;
    }
    current = startPlayer;
    winner = null;
    draw = false;
    lastEvent = '';
    swapPending = false;
    winLine = [];
    _passes = 0;
  }

  QTile? at(int col, int row) => row >= 0 && row < board[col].length ? board[col][row] : null;

  static const _dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];

  bool _matches(QTile a, QTile b) =>
      a.color == b.color || (a.kind == TileKind.number && b.kind == TileKind.number && a.number == b.number);

  /// Darf der Stein in diese Spalte?
  bool canPlace(QTile t, int col) {
    if (finished || swapPending) return false;
    if (col < 0 || col >= cols) return false;
    final column = board[col];
    if (t.kind == TileKind.push) return column.isNotEmpty;
    if (column.length >= rows) return false;
    final row = column.length;
    var hasNeighbor = false;
    for (var dc = -1; dc <= 1; dc++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (dc == 0 && dr == 0) continue;
        final c = col + dc;
        if (c < 0 || c >= cols) continue;
        final n = at(c, row + dr);
        if (n == null) continue;
        hasNeighbor = true;
        if (_matches(t, n)) return true;
      }
    }
    return !hasNeighbor;
  }

  List<int> columnsFor(QTile t) => [for (var c = 0; c < cols; c++) if (canPlace(t, c)) c];

  bool get canMove => actor.hand.any((t) => columnsFor(t).isNotEmpty);

  String _who(QPlayer p, String du, String er) => p.human ? 'Du $du' : '${p.name} $er';

  /// Stein legen. Bei einem Spaltentausch folgt [swapColumns].
  void place(QTile t, int col) {
    if (!actor.hand.contains(t) || !canPlace(t, col)) throw StateError('Zug nicht erlaubt');
    final p = actor;
    p.hand.remove(t);
    _passes = 0;
    switch (t.kind) {
      case TileKind.push:
        final out = board[col].removeAt(0);
        bag.insert(0, out);
        board[col].add(t);
        lastEvent = _who(p, 'schiebst Spalte ${col + 1}', 'schiebt Spalte ${col + 1}');
      case TileKind.swap:
        board[col].add(t);
        if (findLine() != null) break;
        swapPending = true;
        lastEvent = _who(p, 'darfst zwei Spalten tauschen', 'tauscht zwei Spalten');
        return;
      case TileKind.minusTwo:
        board[col].add(t);
        final victim = players[(current + 1) % players.length];
        var k = 0;
        while (k < 2 && victim.hand.isNotEmpty) {
          final lost = victim.hand.removeAt(_rng.nextInt(victim.hand.length));
          bag.insert(0, lost);
          k++;
        }
        victim.short = true;
        lastEvent = victim.human ? 'Du verlierst $k Steine' : '${victim.name} verliert $k Steine';
      case TileKind.number:
        board[col].add(t);
        lastEvent = '';
    }
    _endMove();
  }

  void swapColumns(int a, int b) {
    if (!swapPending || a == b) return;
    final tmp = board[a];
    board[a] = board[b];
    board[b] = tmp;
    swapPending = false;
    lastEvent = _who(actor, 'tauschst Spalte ${a + 1} und ${b + 1}', 'tauscht Spalte ${a + 1} und ${b + 1}');
    _endMove();
  }

  /// Kein Zug möglich: einen Stein mit dem Beutel tauschen, oder passen.
  void exchange([QTile? t]) {
    if (finished || swapPending) return;
    final p = actor;
    if (t != null && p.hand.contains(t) && bag.isNotEmpty) {
      p.hand.remove(t);
      bag.insert(0, t);
      p.hand.add(bag.removeLast());
      lastEvent = _who(p, 'tauschst einen Stein', 'tauscht einen Stein');
    } else {
      lastEvent = _who(p, 'passt', 'passt');
    }
    _passes++;
    _refill(p);
    if (_passes >= players.length * 3) {
      draw = true;
      lastEvent = 'Niemand kommt weiter: unentschieden';
      return;
    }
    current = (current + 1) % players.length;
  }

  void _refill(QPlayer p) {
    p.short = false;
    while (p.hand.length < handSize && bag.isNotEmpty) {
      p.hand.add(bag.removeLast());
    }
  }

  void _endMove() {
    final line = findLine();
    if (line != null) {
      winLine = line;
      winner = actor;
      lastEvent = _who(actor, 'hast vier in einer Reihe', 'hat vier in einer Reihe');
      return;
    }
    _refill(actor);
    if (board.every((c) => c.length >= rows) && players.every((p) => !p.hand.any((t) => t.kind == TileKind.push))) {
      draw = true;
      lastEvent = 'Das Brett ist voll: unentschieden';
      return;
    }
    current = (current + 1) % players.length;
  }

  /// Vier gleiche Farben oder Zahlen in einer Reihe.
  List<(int, int)>? findLine() {
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < board[c].length; r++) {
        final t = board[c][r];
        for (final (dc, dr) in _dirs) {
          final cells = <(int, int)>[(c, r)];
          var sameColor = true;
          var sameNumber = t.kind == TileKind.number;
          for (var k = 1; k < 4; k++) {
            final cc = c + dc * k;
            final rr = r + dr * k;
            if (cc < 0 || cc >= cols) break;
            final n = at(cc, rr);
            if (n == null) break;
            if (n.color != t.color) sameColor = false;
            if (n.kind != TileKind.number || n.number != t.number) sameNumber = false;
            if (!sameColor && !sameNumber) break;
            cells.add((cc, rr));
          }
          if (cells.length == 4 && (sameColor || sameNumber)) return cells;
        }
      }
    }
    return null;
  }

  int get tileCount =>
      bag.length + board.fold<int>(0, (s, c) => s + c.length) + players.fold<int>(0, (s, p) => s + p.hand.length);

  /// Für die Computer: Brett nach einem Zug, ohne den Zustand zu ändern.
  bool wouldWin(QTile t, int col) {
    final saved = [for (final c in board) c.toList()];
    if (t.kind == TileKind.push) {
      board[col].removeAt(0);
    }
    board[col].add(t);
    final win = findLine() != null;
    board = saved;
    return win;
  }

  /// Länge der längsten gleichen Reihe durch das Feld, nach dem Legen.
  int lineScore(QTile t, int col) {
    final saved = [for (final c in board) c.toList()];
    if (t.kind == TileKind.push) board[col].removeAt(0);
    board[col].add(t);
    final row = board[col].length - 1;
    var best = 1;
    for (final (dc, dr) in _dirs) {
      for (final byColor in [true, false]) {
        if (!byColor && t.kind != TileKind.number) continue;
        bool same(QTile? n) =>
            n != null && (byColor ? n.color == t.color : n.kind == TileKind.number && n.number == t.number);
        var len = 1;
        for (final sign in [1, -1]) {
          for (var k = 1; k < 4; k++) {
            final cc = col + dc * k * sign;
            if (cc < 0 || cc >= cols) break;
            if (!same(at(cc, row + dr * k * sign))) break;
            len++;
          }
        }
        best = max(best, len);
      }
    }
    board = saved;
    return best;
  }
}

typedef QuatroMove = ({QTile? tile, int col});

QuatroMove quatroBotChoice(QuatroEngine e, Random rng) {
  QuatroMove? best;
  var bestScore = -1e9;
  final nextPlayer = e.players[(e.current + 1) % e.players.length];
  // Spalten, in denen der Nächste sofort gewinnen könnte: dort lieber selbst legen
  final threats = <int>{
    for (final t in nextPlayer.hand)
      for (final c in e.columnsFor(t))
        if (t.kind != TileKind.push && e.wouldWin(t, c)) c,
  };
  for (final t in e.actor.hand) {
    for (final c in e.columnsFor(t)) {
      if (e.wouldWin(t, c)) return (tile: t, col: c);
      var s = e.lineScore(t, c) * 10.0 + rng.nextDouble() * 3;
      if (threats.contains(c)) s += 25;
      if (t.kind == TileKind.minusTwo) s += nextPlayer.hand.length >= 3 ? 8 : 0;
      if (t.kind == TileKind.swap) s += 4;
      if (t.kind == TileKind.push) s -= 6;
      if (s > bestScore) {
        bestScore = s;
        best = (tile: t, col: c);
      }
    }
  }
  return best ?? (tile: null, col: -1);
}

/// Spaltenwahl nach einem Spaltentausch: gewinnen, wenn möglich.
(int, int) quatroBotSwap(QuatroEngine e, Random rng) {
  for (var a = 0; a < e.cols; a++) {
    for (var b = a + 1; b < e.cols; b++) {
      final tmp = e.board[a];
      e.board[a] = e.board[b];
      e.board[b] = tmp;
      final win = e.findLine() != null;
      e.board[b] = e.board[a];
      e.board[a] = tmp;
      if (win) return (a, b);
    }
  }
  final a = rng.nextInt(e.cols);
  var b = rng.nextInt(e.cols - 1);
  if (b >= a) b++;
  return (a, b);
}

/// Ganzer Computerzug ohne Pausen. Für Tests.
void quatroBotTurn(QuatroEngine e, Random rng) {
  if (e.finished) return;
  if (e.swapPending) {
    final (a, b) = quatroBotSwap(e, rng);
    e.swapColumns(a, b);
    return;
  }
  final m = quatroBotChoice(e, rng);
  if (m.tile == null) {
    final hand = e.actor.hand;
    e.exchange(hand.isEmpty ? null : hand[rng.nextInt(hand.length)]);
    return;
  }
  e.place(m.tile!, m.col);
  if (e.swapPending) {
    final (a, b) = quatroBotSwap(e, rng);
    e.swapColumns(a, b);
  }
}
