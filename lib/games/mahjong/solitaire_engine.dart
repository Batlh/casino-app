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

enum SolitaireLayout { turtle, pyramid, fortress, dragon, cross }

const solitaireLayoutNames = {
  SolitaireLayout.turtle: 'Schildkröte',
  SolitaireLayout.pyramid: 'Pyramide',
  SolitaireLayout.fortress: 'Festung',
  SolitaireLayout.dragon: 'Drache',
  SolitaireLayout.cross: 'Kreuz',
};

void _rect(List<Slot> out, int x0, int y0, int cols, int rows, int z) {
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      out.add(Slot(x0 + 2 * c, y0 + 2 * r, z));
    }
  }
}

/// Pyramide: vier quadratische Ebenen, 120 Steine.
List<Slot> pyramidLayout() {
  final out = <Slot>[];
  for (var k = 0; k < 4; k++) {
    final n = 8 - 2 * k;
    _rect(out, 2 * k, 2 * k, n, n, k);
  }
  return out;
}

/// Festung: Grundfläche, Mauerring, Ecktürme, 124 Steine.
List<Slot> fortressLayout() {
  final out = <Slot>[];
  _rect(out, 0, 0, 12, 6, 0);
  for (var c = 0; c < 12; c++) {
    out.add(Slot(2 * c, 0, 1));
    out.add(Slot(2 * c, 10, 1));
  }
  for (var r = 1; r < 5; r++) {
    out.add(Slot(0, 2 * r, 1));
    out.add(Slot(22, 2 * r, 1));
  }
  for (final (x, y) in const [(0, 0), (20, 0), (0, 8), (20, 8)]) {
    _rect(out, x, y, 2, 2, 2);
    out.add(Slot(x + 1, y + 1, 3));
  }
  return out;
}

/// Drache: langer Körper mit Kopf und Schwanz, 114 Steine.
List<Slot> dragonLayout() {
  final out = <Slot>[];
  for (final y in const [2, 4, 6, 8]) {
    for (var x = 4; x <= 28; x += 2) {
      out.add(Slot(x, y, 0));
    }
  }
  for (final y in const [3, 5, 7]) {
    out
      ..add(Slot(30, y, 0))
      ..add(Slot(32, y, 0));
  }
  out
    ..add(const Slot(0, 5, 0))
    ..add(const Slot(2, 5, 0));
  for (final y in const [3, 5, 7]) {
    for (var x = 6; x <= 24; x += 2) {
      out.add(Slot(x, y, 1));
    }
  }
  for (final y in const [4, 6]) {
    for (var x = 8; x <= 22; x += 2) {
      out.add(Slot(x, y, 2));
    }
  }
  for (var x = 10; x <= 20; x += 2) {
    out.add(Slot(x, 5, 3));
  }
  out
    ..add(const Slot(14, 5, 4))
    ..add(const Slot(16, 5, 4));
  return out;
}

/// Kreuz: zwei gekreuzte Balken in drei Ebenen, 72 Steine.
List<Slot> crossLayout() {
  final out = <Slot>[];
  final used = <String>{};
  void add(int x, int y, int z) {
    if (used.add('$x,$y,$z')) out.add(Slot(x, y, z));
  }

  for (final y in const [6, 8]) {
    for (var x = 0; x <= 24; x += 2) {
      add(x, y, 0);
    }
  }
  for (final x in const [10, 12, 14]) {
    for (var y = 0; y <= 14; y += 2) {
      add(x, y, 0);
    }
  }
  for (var x = 2; x <= 22; x += 2) {
    add(x, 7, 1);
  }
  for (var y = 1; y <= 13; y += 2) {
    add(12, y, 1);
  }
  for (var x = 6; x <= 18; x += 2) {
    add(x, 7, 2);
  }
  for (final y in const [3, 5, 9, 11]) {
    add(12, y, 2);
  }
  return out;
}

List<Slot> layoutSlots(SolitaireLayout l) => switch (l) {
      SolitaireLayout.turtle => turtleLayout(),
      SolitaireLayout.pyramid => pyramidLayout(),
      SolitaireLayout.fortress => fortressLayout(),
      SolitaireLayout.dragon => dragonLayout(),
      SolitaireLayout.cross => crossLayout(),
    };

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
  MahjongSolitaire({Random? rng, this.layout = SolitaireLayout.turtle}) : _rng = rng ?? Random.secure() {
    slots = layoutSlots(layout);
    present = List.filled(slots.length, true);
    tiles = List.filled(slots.length, 0);
    _deal(List.generate(slots.length, (i) => i), _pool(slots.length));
  }

  final Random _rng;
  final SolitaireLayout layout;

  /// Für kleinere Formen: zufällige passende Paare aus dem vollen Satz.
  List<int> _pool(int n) {
    final all = solitaireTileSet();
    if (n >= all.length) return all;
    final pairs = <List<int>>[];
    final byKind = <int, List<int>>{};
    for (final t in all) {
      final key = t >= firstSeason ? firstSeason : (t >= firstFlower ? firstFlower : t);
      byKind.putIfAbsent(key, () => []).add(t);
    }
    for (final list in byKind.values) {
      for (var i = 0; i + 1 < list.length; i += 2) {
        pairs.add([list[i], list[i + 1]]);
      }
    }
    pairs.shuffle(_rng);
    return [for (final p in pairs.take(n ~/ 2)) ...p];
  }
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
