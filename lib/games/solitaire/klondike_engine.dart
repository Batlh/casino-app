import 'dart:math';

import '../cards/playing_card.dart';
import 'table_card.dart';

class _Snapshot {
  _Snapshot(this.stock, this.waste, this.foundations, this.tableau, this.moves);
  final List<TableCard> stock;
  final List<TableCard> waste;
  final List<List<TableCard>> foundations;
  final List<List<TableCard>> tableau;
  final int moves;
}

/// Klassische Patience (Klondike) mit einer oder drei gezogenen Karten.
class KlondikeEngine {
  KlondikeEngine({this.drawCount = 1, Random? rng, List<PlayingCard>? deck}) {
    final cards = deck?.toList() ?? shuffledDeck(rng ?? Random.secure());
    for (var t = 0; t < 7; t++) {
      for (var i = 0; i <= t; i++) {
        tableau[t].add(TableCard(cards.removeLast(), up: i == t));
      }
    }
    stock = [for (final c in cards) TableCard(c)];
  }

  final int drawCount;
  List<TableCard> stock = [];
  List<TableCard> waste = [];
  List<List<TableCard>> foundations = List.generate(4, (_) => <TableCard>[]);
  List<List<TableCard>> tableau = List.generate(7, (_) => <TableCard>[]);
  int moves = 0;
  final List<_Snapshot> _history = [];

  List<TableCard> pile(PileRef r) => switch (r.kind) {
        PileKind.stock => stock,
        PileKind.waste => waste,
        PileKind.foundation => foundations[r.index],
        PileKind.tableau => tableau[r.index],
      };

  bool get isWon => foundations.every((f) => f.length == 13);
  bool get canUndo => _history.isNotEmpty;
  bool get canDraw => stock.isNotEmpty || waste.isNotEmpty;

  void _save() {
    _history.add(
      _Snapshot(
        copyPile(stock),
        copyPile(waste),
        copyPiles(foundations),
        copyPiles(tableau),
        moves,
      ),
    );
    if (_history.length > 1000) _history.removeAt(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    stock = s.stock;
    waste = s.waste;
    foundations = s.foundations;
    tableau = s.tableau;
    moves = s.moves;
  }

  bool canPick(PileRef from, int index) {
    final p = pile(from);
    if (index < 0 || index >= p.length) return false;
    return switch (from.kind) {
      PileKind.stock => false,
      PileKind.tableau => p[index].up,
      _ => index == p.length - 1,
    };
  }

  bool canDrop(PileRef from, int index, PileRef to) {
    if (from == to || !canPick(from, index)) return false;
    final src = pile(from);
    final first = src[index];
    final count = src.length - index;
    switch (to.kind) {
      case PileKind.foundation:
        if (count != 1) return false;
        final f = foundations[to.index];
        if (f.isEmpty) return first.rank == 1;
        return f.last.suit == first.suit && f.last.rank + 1 == first.rank;
      case PileKind.tableau:
        final t = tableau[to.index];
        if (t.isEmpty) return first.rank == 13;
        final top = t.last;
        return top.up && top.red != first.red && top.rank == first.rank + 1;
      case PileKind.stock:
      case PileKind.waste:
        return false;
    }
  }

  bool move(PileRef from, int index, PileRef to) {
    if (!canDrop(from, index, to)) return false;
    _save();
    final src = pile(from);
    final run = src.sublist(index);
    src.removeRange(index, src.length);
    pile(to).addAll(run);
    if (from.kind == PileKind.tableau && src.isNotEmpty && !src.last.up) {
      src.last.up = true;
    }
    moves++;
    return true;
  }

  /// Zieht vom Stapel oder legt den Ablagestapel zurück.
  void draw() {
    if (!canDraw) return;
    _save();
    if (stock.isEmpty) {
      stock = [for (final c in waste.reversed) c..up = false];
      waste = [];
    } else {
      for (var i = 0; i < drawCount && stock.isNotEmpty; i++) {
        waste.add(stock.removeLast()..up = true);
      }
    }
    moves++;
  }

  /// Bestes Ziel beim Antippen: erst die Ablage, dann eine belegte Spalte.
  PileRef? autoTarget(PileRef from, int index) {
    if (!canPick(from, index)) return null;
    final src = pile(from);
    if (index == src.length - 1 && from.kind != PileKind.foundation) {
      for (var f = 0; f < 4; f++) {
        final to = PileRef(PileKind.foundation, f);
        if (canDrop(from, index, to)) return to;
      }
    }
    PileRef? empty;
    for (var t = 0; t < 7; t++) {
      final to = PileRef(PileKind.tableau, t);
      if (!canDrop(from, index, to)) continue;
      if (tableau[t].isNotEmpty) return to;
      // Ein König ganz unten in einer Spalte gewinnt nichts durch den Umzug
      if (!(from.kind == PileKind.tableau && index == 0)) empty ??= to;
    }
    return empty;
  }

  /// Alles liegt offen, der Rest lässt sich automatisch ablegen.
  bool get canAutoFinish =>
      !isWon &&
      stock.isEmpty &&
      waste.isEmpty &&
      tableau.every((t) => t.every((c) => c.up));

  bool autoFinishStep() {
    var bestCol = -1;
    for (var t = 0; t < 7; t++) {
      final col = tableau[t];
      if (col.isEmpty) continue;
      if (bestCol < 0 || col.last.rank < tableau[bestCol].last.rank) bestCol = t;
    }
    if (bestCol < 0) return false;
    final from = PileRef(PileKind.tableau, bestCol);
    final index = tableau[bestCol].length - 1;
    for (var f = 0; f < 4; f++) {
      if (move(from, index, PileRef(PileKind.foundation, f))) return true;
    }
    return false;
  }

  int get cardCount =>
      stock.length +
      waste.length +
      foundations.fold(0, (s, f) => s + f.length) +
      tableau.fold(0, (s, t) => s + t.length);
}
