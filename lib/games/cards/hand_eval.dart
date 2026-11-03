import 'playing_card.dart';

enum HandCategory {
  highCard,
  pair,
  twoPair,
  trips,
  straight,
  flush,
  fullHouse,
  quads,
  straightFlush,
  royalFlush,
}

/// Wert einer Fünf-Karten-Hand. Vergleichbar, damit spätere Poker-Varianten
/// Hände direkt gegeneinander werten können.
class HandValue implements Comparable<HandValue> {
  const HandValue(this.category, this.ranks);

  final HandCategory category;

  /// Ränge in Wertungsreihenfolge, zum Beispiel Drilling vor Beikarten.
  final List<int> ranks;

  @override
  int compareTo(HandValue other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c;
    for (var i = 0; i < ranks.length && i < other.ranks.length; i++) {
      final r = ranks[i].compareTo(other.ranks[i]);
      if (r != 0) return r;
    }
    return 0;
  }
}

HandValue evaluateFive(List<PlayingCard> cards) {
  assert(cards.length == 5);
  final counts = <int, int>{};
  for (final c in cards) {
    counts[c.rank] = (counts[c.rank] ?? 0) + 1;
  }
  // Nach Häufigkeit, dann nach Rang sortiert
  final groups = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : b.compareTo(a);
    });
  final pattern = groups.map((r) => counts[r]!).toList();

  final flush = cards.every((c) => c.suit == cards.first.suit);
  final sorted = cards.map((c) => c.rank).toList()
    ..sort((a, b) => b.compareTo(a));

  int? straightHigh;
  if (counts.length == 5) {
    if (sorted.first - sorted.last == 4) {
      straightHigh = sorted.first;
    } else if (sorted.first == 14 && sorted[1] == 5) {
      straightHigh = 5; // A-2-3-4-5
    }
  }

  if (flush && straightHigh == 14) {
    return const HandValue(HandCategory.royalFlush, [14]);
  }
  if (flush && straightHigh != null) {
    return HandValue(HandCategory.straightFlush, [straightHigh]);
  }
  if (pattern.first == 4) return HandValue(HandCategory.quads, groups);
  if (pattern.first == 3 && pattern[1] == 2) {
    return HandValue(HandCategory.fullHouse, groups);
  }
  if (flush) return HandValue(HandCategory.flush, sorted);
  if (straightHigh != null) {
    return HandValue(HandCategory.straight, [straightHigh]);
  }
  if (pattern.first == 3) return HandValue(HandCategory.trips, groups);
  if (pattern.first == 2 && pattern[1] == 2) {
    return HandValue(HandCategory.twoPair, groups);
  }
  if (pattern.first == 2) return HandValue(HandCategory.pair, groups);
  return HandValue(HandCategory.highCard, sorted);
}

/// Beste Fünf-Karten-Hand aus fünf bis sieben Karten.
HandValue bestHand(List<PlayingCard> cards) {
  assert(cards.length >= 5 && cards.length <= 7);
  HandValue? best;
  final n = cards.length;
  for (var a = 0; a < n; a++) {
    for (var b = a + 1; b < n; b++) {
      for (var c = b + 1; c < n; c++) {
        for (var d = c + 1; d < n; d++) {
          for (var e = d + 1; e < n; e++) {
            final v =
                evaluateFive([cards[a], cards[b], cards[c], cards[d], cards[e]]);
            if (best == null || v.compareTo(best) > 0) best = v;
          }
        }
      }
    }
  }
  return best!;
}
