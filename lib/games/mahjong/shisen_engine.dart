import 'dart:collection';
import 'dart:math';

import 'solitaire_engine.dart';
import 'tiles.dart';

/// Shisen-Sho: gleiche Steine verbinden, wenn eine Linie mit höchstens zwei Knicken durch freie Felder passt.
/// Die Linie darf auch außen um das Brett herum laufen.
class ShisenSho {
  ShisenSho({Random? rng, this.cols = 18, this.rows = 8}) : _rng = rng ?? Random.secure() {
    cells = List.filled(cols * rows, -1);
    _deal();
  }

  final Random _rng;
  final int cols;
  final int rows;

  /// Stein je Feld, -1 heißt leer.
  late List<int> cells;

  /// Eine Lösung aus dem Aufbau: Paare in der Reihenfolge, in der man sie abräumen kann (leer nach Notfall-Mischen).
  List<(int, int)> solution = [];
  final List<(int, int, int, int)> _history = [];

  int get remaining => cells.where((c) => c >= 0).length;
  bool get won => remaining == 0;
  bool get canUndo => _history.isNotEmpty;
  int get removedPairs => _history.length;

  int _idx(int x, int y) => y * cols + x;

  bool _emptyAt(List<int> board, int x, int y) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return x >= -1 && y >= -1 && x <= cols && y <= rows;
    return board[_idx(x, y)] < 0;
  }

  /// Weg zwischen zwei Feldern mit höchstens zwei Knicken, als Eckpunkte in Brettkoordinaten (außen ist -1 bzw. cols/rows).
  List<Point<int>>? path(int a, int b, [List<int>? board]) {
    board ??= cells;
    if (a == b) return null;
    final ax = a % cols, ay = a ~/ cols, bx = b % cols, by = b ~/ cols;
    const dirs = [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)];
    // Breitensuche über (Feld, Richtung) mit Anzahl der Knicke
    final best = <String, int>{};
    final queue = Queue<(int, int, int, int, List<Point<int>>)>();
    for (var d = 0; d < 4; d++) {
      queue.add((ax, ay, d, 0, [Point(ax, ay)]));
    }
    while (queue.isNotEmpty) {
      final (x, y, d, turns, pts) = queue.removeFirst();
      final nx = x + dirs[d].x, ny = y + dirs[d].y;
      if (nx == bx && ny == by) return [...pts, Point(bx, by)];
      if (!_emptyAt(board, nx, ny)) continue;
      for (var nd = 0; nd < 4; nd++) {
        if (dirs[nd].x == -dirs[d].x && dirs[nd].y == -dirs[d].y) continue;
        final nt = turns + (nd == d ? 0 : 1);
        if (nt > 2) continue;
        final key = '$nx,$ny,$nd';
        if ((best[key] ?? 9) <= nt) continue;
        best[key] = nt;
        final np = nd == d ? pts : [...pts, Point(nx, ny)];
        if (nd == d) {
          queue.addFirst((nx, ny, nd, nt, np));
        } else {
          queue.add((nx, ny, nd, nt, np));
        }
      }
    }
    return null;
  }

  /// Alle Felder, die von a aus mit höchstens zwei Knicken erreichbar sind: freie Felder unterwegs
  /// und belegte Felder, an denen die Linie endet.
  Set<int> reachable(int a, [List<int>? board]) {
    board ??= cells;
    final ax = a % cols, ay = a ~/ cols;
    const dx = [1, -1, 0, 0];
    const dy = [0, 0, 1, -1];
    final out = <int>{};
    // Kleinste Knickzahl je (Feld mit Rand, Richtung)
    final w = cols + 2;
    final best = List.filled(w * (rows + 2) * 4, 9);
    final queue = Queue<(int, int, int, int)>();
    for (var d = 0; d < 4; d++) {
      queue.add((ax, ay, d, 0));
    }
    while (queue.isNotEmpty) {
      final (x, y, d, t) = queue.removeFirst();
      final nx = x + dx[d], ny = y + dy[d];
      if (nx < -1 || ny < -1 || nx > cols || ny > rows) continue;
      final inside = nx >= 0 && ny >= 0 && nx < cols && ny < rows;
      if (inside) {
        final i = ny * cols + nx;
        if (i == a) continue;
        out.add(i);
        if (board[i] >= 0) continue;
      }
      for (var nd = 0; nd < 4; nd++) {
        if (dx[nd] == -dx[d] && dy[nd] == -dy[d]) continue;
        final nt = t + (nd == d ? 0 : 1);
        if (nt > 2) continue;
        final key = ((ny + 1) * w + (nx + 1)) * 4 + nd;
        if (best[key] <= nt) continue;
        best[key] = nt;
        if (nd == d) {
          queue.addFirst((nx, ny, nd, nt));
        } else {
          queue.add((nx, ny, nd, nt));
        }
      }
    }
    return out;
  }

  bool canRemove(int a, int b) =>
      a != b && cells[a] >= 0 && cells[b] >= 0 && tilesMatch(cells[a], cells[b]) && path(a, b) != null;

  List<Point<int>>? remove(int a, int b) {
    if (!canRemove(a, b)) return null;
    final p = path(a, b)!;
    _history.add((a, cells[a], b, cells[b]));
    cells[a] = -1;
    cells[b] = -1;
    return p;
  }

  void undo() {
    if (_history.isEmpty) return;
    final (a, ta, b, tb) = _history.removeLast();
    cells[a] = ta;
    cells[b] = tb;
  }

  List<(int, int)> freePairs() {
    final out = <(int, int)>[];
    for (var a = 0; a < cells.length; a++) {
      if (cells[a] < 0) continue;
      for (final b in reachable(a)) {
        if (b > a && cells[b] >= 0 && tilesMatch(cells[a], cells[b])) out.add((a, b));
      }
    }
    return out;
  }

  bool get stuck => !won && freePairs().isEmpty;

  /// Steinpaare für die Brettgröße.
  List<List<int>> _pairs(int count) {
    final byKind = <int, List<int>>{};
    for (final t in solitaireTileSet()) {
      final key = t >= firstSeason ? firstSeason : (t >= firstFlower ? firstFlower : t);
      byKind.putIfAbsent(key, () => []).add(t);
    }
    final pairs = <List<int>>[];
    for (final list in byKind.values) {
      list.shuffle(_rng);
      for (var i = 0; i + 1 < list.length; i += 2) {
        pairs.add([list[i], list[i + 1]]);
      }
    }
    pairs.shuffle(_rng);
    return pairs.take(count).toList();
  }

  /// Zufällig legen und mit einem schnellen Löser prüfen, bis eine lösbare Lage gefunden ist.
  void _deal([List<int>? positions]) {
    final pos = positions ?? List.generate(cols * rows, (i) => i);
    final pool = positions == null ? _pairs(pos.length ~/ 2) : _regroup([for (final p in pos) cells[p]]);
    final tiles = [for (final pr in pool) ...pr];
    for (var attempt = 0; attempt < 40; attempt++) {
      tiles.shuffle(_rng);
      final board = List.filled(cols * rows, -1);
      for (var i = 0; i < pos.length; i++) {
        board[pos[i]] = tiles[i];
      }
      for (var run = 0; run < 3; run++) {
        final sol = _solve([...board]);
        if (sol != null) {
          cells = board;
          solution = sol;
          return;
        }
      }
    }
    // Notfall: die letzte Lage nehmen, Mischen hilft dann weiter
    solution = [];
    for (var i = 0; i < pos.length; i++) {
      cells[pos[i]] = tiles[i];
    }
  }

  /// Gieriger Löser mit Zufall: nimmt immer ein zufälliges verbindbares Paar.
  List<(int, int)>? _solve(List<int> board) {
    final out = <(int, int)>[];
    var left = board.where((c) => c >= 0).length;
    while (left > 0) {
      final order = [for (var i = 0; i < board.length; i++) if (board[i] >= 0) i]..shuffle(_rng);
      (int, int)? pick;
      for (final a in order) {
        final m = [for (final b in reachable(a, board)) if (board[b] >= 0 && tilesMatch(board[a], board[b])) b];
        if (m.isNotEmpty) {
          pick = (a, m[_rng.nextInt(m.length)]);
          break;
        }
      }
      if (pick == null) return null;
      board[pick.$1] = -1;
      board[pick.$2] = -1;
      out.add(pick);
      left -= 2;
    }
    return out;
  }

  List<List<int>> _regroup(List<int> tiles) {
    final byKind = <int, List<int>>{};
    for (final t in tiles) {
      final key = t >= firstSeason ? firstSeason : (t >= firstFlower ? firstFlower : t);
      byKind.putIfAbsent(key, () => []).add(t);
    }
    final out = <List<int>>[];
    for (final l in byKind.values) {
      for (var i = 0; i + 1 < l.length; i += 2) {
        out.add([l[i], l[i + 1]]);
      }
    }
    out.shuffle(_rng);
    return out;
  }

  /// Übrige Steine neu legen, wieder lösbar.
  void shuffle() {
    final pos = [for (var i = 0; i < cells.length; i++) if (cells[i] >= 0) i];
    _deal(pos);
    _history.clear();
  }
}
