import 'dart:math';

import '../eins/eins_engine.dart' show EinsColor, colorName;

/// Viererkette: Steine in Spalten fallen lassen, vier gleiche Farben oder
/// Zahlen in einer Reihe gewinnen. Nach dem Legespiel Quatro.
enum TileKind { plain, swap, push, minusTwo }

class QTile {
  QTile(this.id, this.color, this.number, [this.kind = TileKind.plain]);

  final int id;
  final EinsColor color;

  /// Jeder Stein hat eine Zahl von 0 bis 5, auch Aktionssteine.
  final int number;
  final TileKind kind;

  String get label {
    final base = '${colorName(color)} $number';
    return switch (kind) {
      TileKind.plain => base,
      TileKind.swap => '$base, Spaltentausch',
      TileKind.push => '$base, Schieber',
      TileKind.minusTwo => '$base, Minus zwei',
    };
  }

  @override
  bool operator ==(Object other) => other is QTile && other.id == id;

  @override
  int get hashCode => id;
}

/// Die 44 Steine wie im Original: je Farbe eine 0 und 1 bis 5 doppelt, sieben davon mit Aktion.
List<QTile> quatroBag() {
  const s = TileKind.swap;
  const p = TileKind.push;
  const m = TileKind.minusTwo;
  const n = TileKind.plain;
  const table = <EinsColor, List<(int, TileKind)>>{
    EinsColor.blue: [(0, n), (1, n), (1, m), (2, s), (2, p), (3, n), (3, s), (4, p), (4, s), (5, n), (5, m)],
    EinsColor.green: [(0, m), (1, n), (1, s), (2, n), (2, s), (3, n), (3, p), (4, n), (4, m), (5, s), (5, p)],
    EinsColor.red: [(0, n), (1, p), (1, s), (2, n), (2, m), (3, p), (3, s), (4, n), (4, s), (5, n), (5, m)],
    EinsColor.yellow: [(0, s), (1, n), (1, m), (2, n), (2, p), (3, n), (3, m), (4, p), (4, s), (5, n), (5, s)],
  };
  var id = 0;
  return [
    for (final e in table.entries)
      for (final (nr, kind) in e.value) QTile(id++, e.key, nr, kind),
  ];
}

class QPlayer {
  QPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<QTile> hand = [];
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

  /// Nach dem Tauschen mit dem Beutel darf nur dieser Stein noch gelegt werden.
  QTile? exchanged;

  List<(int, int)> winLine = [];
  int _passes = 0;

  QPlayer get actor => players[current];
  bool get finished => winner != null || draw;

  void start({int startPlayer = 0}) {
    board = List.generate(cols, (_) => <QTile>[]);
    bag = quatroBag()..shuffle(_rng);
    for (final p in players) {
      p.hand = [for (var i = 0; i < handSize; i++) bag.removeLast()];
    }
    current = startPlayer;
    winner = null;
    draw = false;
    lastEvent = '';
    swapPending = false;
    exchanged = null;
    winLine = [];
    _passes = 0;
  }

  QTile? at(int col, int row) => row >= 0 && row < board[col].length ? board[col][row] : null;

  static const _dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];

  bool _matches(QTile a, QTile b) => a.color == b.color || a.number == b.number;

  /// Spalten nach dem Legen, ohne den Zustand zu ändern.
  List<List<QTile>> _after(QTile t, int col) {
    final next = [for (final c in board) c.toList()];
    if (t.kind == TileKind.push && next[col].isNotEmpty) next[col].removeAt(0);
    next[col].add(t);
    return next;
  }

  /// Darf der Stein in diese Spalte? Passen muss er an seinem Endplatz zu mindestens einem Nachbarn.
  bool canPlace(QTile t, int col) {
    if (finished || swapPending) return false;
    if (exchanged != null && t != exchanged) return false;
    if (col < 0 || col >= cols) return false;
    final column = board[col];
    // Der Schieber darf auch in eine volle Spalte
    if (column.length >= rows && t.kind != TileKind.push) return false;
    final next = _after(t, col);
    final row = next[col].length - 1;
    var hasNeighbor = false;
    for (var dc = -1; dc <= 1; dc++) {
      for (var dr = -1; dr <= 1; dr++) {
        if (dc == 0 && dr == 0) continue;
        final c = col + dc;
        final r = row + dr;
        if (c < 0 || c >= cols || r < 0 || r >= next[c].length) continue;
        hasNeighbor = true;
        if (_matches(t, next[c][r])) return true;
      }
    }
    return !hasNeighbor;
  }

  List<int> columnsFor(QTile t) => [
        for (var c = 0; c < cols; c++)
          if (canPlace(t, c)) c,
      ];

  bool get canMove => actor.hand.any((t) => columnsFor(t).isNotEmpty);

  String _who(QPlayer p, String du, String er) => p.human ? 'Du $du' : '${p.name} $er';

  /// Stein legen. Bei einem Spaltentausch folgt [swapColumns].
  void place(QTile t, int col) {
    if (!actor.hand.contains(t) || !canPlace(t, col)) throw StateError('Zug nicht erlaubt');
    final p = actor;
    p.hand.remove(t);
    exchanged = null;
    _passes = 0;
    final before = board;
    final pushes = t.kind == TileKind.push && board[col].isNotEmpty;
    board = _after(t, col);
    _collectPushed(before);
    lastEvent = '';
    switch (t.kind) {
      case TileKind.push:
        if (pushes) lastEvent = _who(p, 'schiebst Spalte ${col + 1}', 'schiebt Spalte ${col + 1}');
      case TileKind.swap:
        if (findLine() == null) {
          swapPending = true;
          lastEvent = _who(p, 'darfst zwei Spalten tauschen', 'tauscht zwei Spalten');
          return;
        }
      case TileKind.minusTwo:
        final victim = players[(current + 1) % players.length];
        var k = 0;
        while (k < 2 && victim.hand.length > 1) {
          final lost = victim.hand.removeAt(_rng.nextInt(victim.hand.length));
          bag.insert(0, lost);
          k++;
        }
        lastEvent = victim.human ? 'Du legst $k Steine zurück' : '${victim.name} legt $k Steine zurück';
      case TileKind.plain:
        break;
    }
    _endMove();
  }

  /// Der Schieber hat einen Stein aus der Spalte gedrückt: zurück in den Beutel.
  void _collectPushed(List<List<QTile>> before) {
    final onBoard = {for (final c in board) ...c};
    for (final c in before) {
      for (final x in c) {
        if (!onBoard.contains(x)) bag.insert(0, x);
      }
    }
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

  /// Kein Stein passt: einen gegen den Beutel tauschen. Passt der neue, darf er sofort gelegt werden.
  void exchange([QTile? t]) {
    if (finished || swapPending || exchanged != null) return;
    final p = actor;
    if (t != null && p.hand.contains(t) && bag.isNotEmpty) {
      p.hand.remove(t);
      bag.insert(0, t);
      final fresh = bag.removeLast();
      p.hand.add(fresh);
      if (columnsFor(fresh).isNotEmpty) {
        exchanged = fresh;
        lastEvent = _who(p, 'tauschst einen Stein, der neue passt', 'tauscht einen Stein');
        return;
      }
      lastEvent = _who(p, 'tauschst einen Stein', 'tauscht einen Stein');
    } else {
      lastEvent = _who(p, 'passt', 'passt');
    }
    endTurn();
  }

  /// Zug ohne Legen beenden, etwa wenn der getauschte Stein nicht gelegt werden soll.
  void endTurn() {
    if (finished || swapPending) return;
    exchanged = null;
    _passes++;
    _refill(actor);
    if (_passes >= players.length * 3) {
      draw = true;
      lastEvent = 'Niemand kommt weiter: unentschieden';
      return;
    }
    current = (current + 1) % players.length;
  }

  void _refill(QPlayer p) {
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
          var sameNumber = true;
          for (var k = 1; k < 4; k++) {
            final cc = c + dc * k;
            final rr = r + dr * k;
            if (cc < 0 || cc >= cols) break;
            final n = at(cc, rr);
            if (n == null) break;
            if (n.color != t.color) sameColor = false;
            if (n.number != t.number) sameNumber = false;
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

  bool wouldWin(QTile t, int col) {
    final saved = board;
    board = _after(t, col);
    final win = findLine() != null;
    board = saved;
    return win;
  }

  /// Länge der längsten gleichen Reihe durch den gelegten Stein.
  int lineScore(QTile t, int col) {
    final saved = board;
    board = _after(t, col);
    final row = board[col].length - 1;
    var best = 1;
    for (final (dc, dr) in _dirs) {
      for (final byColor in [true, false]) {
        bool same(QTile? n) => n != null && (byColor ? n.color == t.color : n.number == t.number);
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
  final candidates = e.exchanged != null ? [e.exchanged!] : e.actor.hand;
  for (final t in candidates) {
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
  var m = quatroBotChoice(e, rng);
  if (m.tile == null) {
    final hand = e.actor.hand;
    e.exchange(hand.isEmpty ? null : hand[rng.nextInt(hand.length)]);
    if (e.exchanged == null) return;
    m = quatroBotChoice(e, rng);
    if (m.tile == null) {
      e.endTurn();
      return;
    }
  }
  e.place(m.tile!, m.col);
  if (e.swapPending) {
    final (a, b) = quatroBotSwap(e, rng);
    e.swapColumns(a, b);
  }
}
