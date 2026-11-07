import '../cards/playing_card.dart';

/// Rang mit Ass als Eins, wie bei Patiencen üblich.
int lowRank(PlayingCard c) => c.rank == 14 ? 1 : c.rank;

/// Karte auf dem Tisch, offen oder verdeckt.
class TableCard {
  TableCard(this.card, {this.up = false});

  final PlayingCard card;
  bool up;

  int get rank => lowRank(card);
  Suit get suit => card.suit;
  bool get red => card.isRed;

  TableCard copy() => TableCard(card, up: up);
}

enum PileKind { stock, waste, foundation, tableau }

class PileRef {
  const PileRef(this.kind, [this.index = 0]);

  final PileKind kind;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is PileRef && other.kind == kind && other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);

  @override
  String toString() => '${kind.name}$index';
}

List<TableCard> copyPile(List<TableCard> pile) => [for (final c in pile) c.copy()];

List<List<TableCard>> copyPiles(List<List<TableCard>> piles) =>
    [for (final p in piles) copyPile(p)];
