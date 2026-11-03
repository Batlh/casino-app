import 'dart:math';

enum Suit { spades, hearts, diamonds, clubs }

/// Spielkarte. rank: 2 bis 10, Bube 11, Dame 12, König 13, Ass 14.
class PlayingCard {
  const PlayingCard(this.rank, this.suit);

  final int rank;
  final Suit suit;

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;

  String get rankLabel => switch (rank) {
        14 => 'A',
        13 => 'K',
        12 => 'D',
        11 => 'B',
        _ => '$rank',
      };

  String get spokenName {
    final s = switch (suit) {
      Suit.spades => 'Pik',
      Suit.hearts => 'Herz',
      Suit.diamonds => 'Karo',
      Suit.clubs => 'Kreuz',
    };
    final r = switch (rank) {
      14 => 'Ass',
      13 => 'König',
      12 => 'Dame',
      11 => 'Bube',
      _ => '$rank',
    };
    return '$s $r';
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '$rankLabel${suit.name[0]}';
}

List<PlayingCard> freshDeck({int decks = 1}) => [
      for (var d = 0; d < decks; d++)
        for (final s in Suit.values)
          for (var r = 2; r <= 14; r++) PlayingCard(r, s),
    ];

List<PlayingCard> shuffledDeck(Random rng, {int decks = 1}) =>
    freshDeck(decks: decks)..shuffle(rng);
