import 'dart:math';

import 'tiles.dart';

/// Platz eines Steins. Ein Stein ist zwei Einheiten breit und hoch, z ist die Ebene.
class Slot {
  const Slot(this.x, this.y, this.z);
  final int x;
  final int y;
  final int z;
}

/// Die klassische Schildkröte mit 144 Steinen auf fünf Ebenen.
List<Slot> turtleLayout() {
  final out = <Slot>[];
  void row(int y, int from, int to, int z) {
    for (var x = from; x <= to; x += 2) {
      out.add(Slot(x, y, z));
    }
  }

  // Ebene 0
  row(0, 2, 24, 0);
  row(2, 6, 20, 0);
  row(4, 4, 22, 0);
  row(6, 2, 24, 0);
  row(8, 2, 24, 0);
  row(10, 4, 22, 0);
  row(12, 6, 20, 0);
  row(14, 2, 24, 0);
  out.add(const Slot(0, 7, 0));
  out.add(const Slot(26, 7, 0));
  out.add(const Slot(28, 7, 0));
  // Ebenen 1 bis 3
  for (var y = 2; y <= 12; y += 2) {
    row(y, 8, 18, 1);
  }
  for (var y = 4; y <= 10; y += 2) {
    row(y, 10, 16, 2);
  }
  for (var y = 6; y <= 8; y += 2) {
    row(y, 12, 14, 3);
  }
  // Spitze
  out.add(const Slot(13, 7, 4));
  return out;
}

/// Passen zwei Steine zusammen? Blumen untereinander und Jahreszeiten untereinander immer.
bool tilesMatch(int a, int b) {
  if (a >= firstSeason && b >= firstSeason) return true;
  if (a >= firstFlower && a < firstSeason && b >= firstFlower && b < firstSeason) return true;
  return a == b;
}

/// Die 144 Steine: je vier von 34 Sorten, dazu vier Blumen und vier Jahreszeiten.
List<int> solitaireTileSet() => [
      for (var t = 0; t < tileKinds; t++) ...[t, t, t, t],
      for (var t = firstFlower; t < firstSeason + 4; t++) t,
    ];

class MahjongSolitaire {
  MahjongSolitaire({Random? rng}) : _rng = rng ?? Random.secure() {
    slots = turtleLayout();
    present = List.filled(slots.length, true);
    tiles = List.filled(slots.length, 0);
    _deal(List.generate(slots.length, (i) => i), solitaireTileSet());
  }

  final Random _rng;
  late final List<Slot> slots;
  late List<bool> present;
  late List<int> tiles;
  final List<(int, int)> _history = [];
  late final List<List<int>> _above;
  late final List<List<int>> _left;
  late final List<List<int>> _right;

  int get remaining => present.where((p) => p).length;
  bool get won => remaining == 0;
  bool get canUndo => _history.isNotEmpty;
  int get removedPairs => _history.length;

  void _computeNeighbors() {
    _neighborsReady = true;
    _above = List.generate(slots.length, (_) => <int>[]);
    _left = List.generate(slots.length, (_) => <int>[]);
    _right = List.generate(slots.length, (_) => <int>[]);
    for (var i = 0; i < slots.length; i++) {
      final a = slots[i];
      for (var j = 0; j < slots.length; j++) {
        if (i == j) continue;
        final b = slots[j];
        final overlapY = (a.y - b.y).abs() < 2;
        if (b.z == a.z + 1 && (a.x - b.x).abs() < 2 && overlapY) _above[i].add(j);
        if (b.z == a.z && overlapY && b.x == a.x - 2) _left[i].add(j);
        if (b.z == a.z && overlapY && b.x == a.x + 2) _right[i].add(j);
      }
    }
  }

  bool _freeIn(int i, List<bool> on) {
    if (!on[i]) return false;
    if (_above[i].any((j) => on[j])) return false;
    return !_left[i].any((j) => on[j]) || !_right[i].any((j) => on[j]);
  }

  bool isFree(int i) => _freeIn(i, present);

  /// Verteilt Steine so, dass das Spiel lösbar bleibt: Es wird rückwärts abgeräumt
  /// und jedes abgeräumte Paar bekommt passende Steine.
  void _deal(List<int> positions, List<int> pool) {
    // Nachbarn werden für die Simulation schon gebraucht
    if (!_neighborsReady) _computeNeighbors();
    for (var attempt = 0; attempt < 200; attempt++) {
      final on = List<bool>.filled(slots.length, false);
      for (final p in positions) {
        on[p] = true;
      }
      final pairs = <(int, int)>[];
      var ok = true;
      for (var k = 0; k < positions.length ~/ 2; k++) {
        final free = [for (final p in positions) if (_freeIn(p, on)) p];
        if (free.length < 2) {
          ok = false;
          break;
        }
        free.shuffle(_rng);
        final a = free[0];
        final b = free[1];
        on[a] = false;
        on[b] = false;
        pairs.add((a, b));
      }
      if (!ok) continue;
      // Steine paarweise zuordnen
      final groups = <List<int>>[];
      final byKind = <int, List<int>>{};
      for (final t in pool) {
        final key = t >= firstSeason ? firstSeason : (t >= firstFlower ? firstFlower : t);
        byKind.putIfAbsent(key, () => []).add(t);
      }
      for (final list in byKind.values) {
        list.shuffle(_rng);
        for (var i = 0; i + 1 < list.length; i += 2) {
          groups.add([list[i], list[i + 1]]);
        }
      }
      groups.shuffle(_rng);
      for (var k = 0; k < pairs.length; k++) {
        tiles[pairs[k].$1] = groups[k][0];
        tiles[pairs[k].$2] = groups[k][1];
      }
      return;
    }
  }

  bool _neighborsReady = false;

  /// Alle Paare freier, passender Steine.
  List<(int, int)> freePairs() {
    final free = [for (var i = 0; i < slots.length; i++) if (isFree(i)) i];
    final out = <(int, int)>[];
    for (var a = 0; a < free.length; a++) {
      for (var b = a + 1; b < free.length; b++) {
        if (tilesMatch(tiles[free[a]], tiles[free[b]])) out.add((free[a], free[b]));
      }
    }
    return out;
  }

  bool get stuck => !won && freePairs().isEmpty;

  bool remove(int a, int b) {
    if (a == b || !isFree(a) || !isFree(b) || !tilesMatch(tiles[a], tiles[b])) return false;
    present[a] = false;
    present[b] = false;
    _history.add((a, b));
    return true;
  }

  void undo() {
    if (_history.isEmpty) return;
    final (a, b) = _history.removeLast();
    present[a] = true;
    present[b] = true;
  }

  /// Mischt die verbliebenen Steine neu, wieder lösbar.
  void shuffle() {
    final positions = [for (var i = 0; i < slots.length; i++) if (present[i]) i];
    final pool = [for (final p in positions) tiles[p]];
    _deal(positions, pool);
    _history.clear();
  }
}
