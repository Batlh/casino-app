import 'dart:math';

import '../cards/playing_card.dart';
import 'table_card.dart';

/// 104 Karten mit einer, zwei oder vier Farben.
List<PlayingCard> spiderDeck(int suits) {
  final used = switch (suits) {
    1 => [Suit.spades],
    2 => [Suit.spades, Suit.hearts],
    _ => Suit.values,
  };
  final copies = 8 ~/ used.length;
  return [
    for (var c = 0; c < copies; c++)
      for (final s in used)
        for (var r = 2; r <= 14; r++) PlayingCard(r, s),
  ];
}

class _Snapshot {
  _Snapshot(this.stock, this.tableau, this.completed, this.moves);
  final List<TableCard> stock;
  final List<List<TableCard>> tableau;
  final List<Suit> completed;
  final int moves;
}

class SpiderEngine {
  SpiderEngine({this.suits = 1, Random? rng, List<PlayingCard>? deck}) {
    final List<PlayingCard> cards;
    if (deck != null) {
      cards = deck.toList();
    } else {
      cards = spiderDeck(suits)..shuffle(rng ?? Random.secure());
    }
    for (var t = 0; t < 10; t++) {
      final n = t < 4 ? 6 : 5;
      for (var i = 0; i < n; i++) {
        tableau[t].add(TableCard(cards.removeLast(), up: i == n - 1));
      }
    }
    stock = [for (final c in cards) TableCard(c)];
  }

  final int suits;
  List<TableCard> stock = [];
  List<List<TableCard>> tableau = List.generate(10, (_) => <TableCard>[]);

  /// Farben der fertig abgelegten Reihen.
  List<Suit> completed = [];
  int moves = 0;
  final List<_Snapshot> _history = [];

  bool get isWon => completed.length == 8;
  bool get canUndo => _history.isNotEmpty;
  int get dealsLeft => stock.length ~/ 10;
  bool get hasEmptyColumn => tableau.any((t) => t.isEmpty);
  bool get canDeal => stock.isNotEmpty && !hasEmptyColumn;

  void _save() {
    _history.add(
      _Snapshot(copyPile(stock), copyPiles(tableau), completed.toList(), moves),
    );
    if (_history.length > 1000) _history.removeAt(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    stock = s.stock;
    tableau = s.tableau;
    completed = s.completed;
    moves = s.moves;
  }

  /// Ab index liegt eine offene, gleichfarbige, absteigende Reihe.
  bool canPick(int column, int index) {
    final col = tableau[column];
    if (index < 0 || index >= col.length || !col[index].up) return false;
    for (var i = index + 1; i < col.length; i++) {
      final a = col[i - 1];
      final b = col[i];
      if (!b.up || b.suit != a.suit || b.rank != a.rank - 1) return false;
    }
    return true;
  }

  bool canDrop(int from, int index, int to) {
    if (from == to || !canPick(from, index)) return false;
    final target = tableau[to];
    if (target.isEmpty) return true;
    return target.last.up && target.last.rank == tableau[from][index].rank + 1;
  }

  bool move(int from, int index, int to) {
    if (!canDrop(from, index, to)) return false;
    _save();
    final src = tableau[from];
    final run = src.sublist(index);
    src.removeRange(index, src.length);
    tableau[to].addAll(run);
    _flip(from);
    _collect(to);
    moves++;
    return true;
  }

  void deal() {
    if (!canDeal) return;
    _save();
    for (var t = 0; t < 10; t++) {
      tableau[t].add(stock.removeLast()..up = true);
    }
    for (var t = 0; t < 10; t++) {
      _collect(t);
    }
    moves++;
  }

  void _flip(int t) {
    final col = tableau[t];
    if (col.isNotEmpty && !col.last.up) col.last.up = true;
  }

  /// Entfernt eine vollständige Reihe von König bis Ass.
  void _collect(int t) {
    final col = tableau[t];
    if (col.length < 13) return;
    final start = col.length - 13;
    if (col[start].rank != 13 || !canPick(t, start)) return;
    completed.add(col[start].suit);
    col.removeRange(start, col.length);
    _flip(t);
  }

  /// Bestes Ziel beim Antippen: gleiche Farbe, dann beliebige Farbe, dann leer.
  int? autoTarget(int from, int index) {
    if (!canPick(from, index)) return null;
    final first = tableau[from][index];
    int? anySuit;
    int? empty;
    for (var t = 0; t < 10; t++) {
      if (!canDrop(from, index, t)) continue;
      final target = tableau[t];
      if (target.isEmpty) {
        if (index > 0) empty ??= t;
      } else if (target.last.suit == first.suit) {
        return t;
      } else {
        anySuit ??= t;
      }
    }
    return anySuit ?? empty;
  }

  int get cardCount =>
      stock.length +
      completed.length * 13 +
      tableau.fold(0, (s, t) => s + t.length);
}
