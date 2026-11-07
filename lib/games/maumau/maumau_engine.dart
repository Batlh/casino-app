import 'dart:math';

import '../cards/playing_card.dart';

/// 32 Karten von der Sieben bis zum Ass.
List<PlayingCard> skatDeck() => [
      for (final s in Suit.values)
        for (var r = 7; r <= 14; r++) PlayingCard(r, s),
    ];

class MauPlayer {
  MauPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<PlayingCard> hand = [];
}

/// Mau Mau. Sieben: Der Nächste zieht zwei, jede weitere Sieben erhöht um zwei.
/// Acht: Der Nächste setzt aus. Bube: darf auf jede Karte und wünscht eine Farbe.
class MauMauEngine {
  MauMauEngine({
    required this.players,
    Random? rng,
    this.handSize = 5,
  }) : _rng = rng ?? Random.secure();

  final List<MauPlayer> players;
  final int handSize;
  final Random _rng;

  List<PlayingCard> drawPile = [];
  List<PlayingCard> discard = [];
  int current = 0;
  int pendingDraw = 0;
  Suit? wish;
  bool drewThisTurn = false;
  PlayingCard? drawnCard;
  MauPlayer? winner;
  String lastEvent = '';

  PlayingCard get top => discard.last;
  MauPlayer get actor => players[current];
  bool get finished => winner != null;

  /// startPlayer: wer beginnt. stacked: feste Kartenfolge für Tests, gezogen wird von hinten.
  void start({int startPlayer = 0, List<PlayingCard>? stacked}) {
    drawPile = stacked?.toList() ?? (skatDeck()..shuffle(_rng));
    discard = [];
    for (final p in players) {
      p.hand = [];
    }
    for (var i = 0; i < handSize; i++) {
      for (final p in players) {
        p.hand.add(drawPile.removeLast());
      }
    }
    // Die erste offene Karte soll keine Sonderkarte sein
    var i = drawPile.length - 1;
    while (i > 0 && const [7, 8, 11].contains(drawPile[i].rank)) {
      i--;
    }
    discard.add(drawPile.removeAt(i));
    current = startPlayer;
    pendingDraw = 0;
    wish = null;
    drewThisTurn = false;
    drawnCard = null;
    winner = null;
    lastEvent = '';
  }

  bool canPlay(PlayingCard c) {
    if (finished) return false;
    if (drewThisTurn && c != drawnCard) return false;
    if (pendingDraw > 0) return c.rank == 7;
    if (c.rank == 11) return true;
    if (wish != null) return c.suit == wish;
    return c.suit == top.suit || c.rank == top.rank;
  }

  List<PlayingCard> playableCards() => actor.hand.where(canPlay).toList();

  void play(PlayingCard c, {Suit? wishSuit}) {
    if (!canPlay(c) || !actor.hand.contains(c)) {
      throw StateError('Karte nicht spielbar');
    }
    final p = actor;
    p.hand.remove(c);
    discard.add(c);
    wish = c.rank == 11 ? (wishSuit ?? c.suit) : null;
    var steps = 1;
    if (c.rank == 7) {
      pendingDraw += 2;
      lastEvent = '${p.name}: Sieben, der Nächste zieht $pendingDraw';
    } else if (c.rank == 8) {
      steps = 2;
      lastEvent = '${p.name}: Acht, ${players[(current + 1) % players.length].name} setzt aus';
    } else if (c.rank == 11) {
      lastEvent = '${p.name} wünscht sich ${suitName(wish!)}';
    } else {
      lastEvent = '';
    }
    if (p.hand.isEmpty) {
      winner = p;
      lastEvent = '${p.name} hat keine Karten mehr';
      return;
    }
    _advance(steps);
  }

  /// Ziehen: Strafkarten oder eine Karte. Passt die gezogene Karte nicht, ist der Nächste dran.
  void draw() {
    if (finished) return;
    final p = actor;
    if (pendingDraw > 0) {
      final n = pendingDraw;
      pendingDraw = 0;
      var got = 0;
      for (var i = 0; i < n; i++) {
        final c = _take();
        if (c == null) break;
        p.hand.add(c);
        got++;
      }
      lastEvent = '${p.name} zieht $got';
      _advance(1);
      return;
    }
    if (drewThisTurn) return;
    final c = _take();
    if (c == null) {
      lastEvent = '${p.name} kann nicht ziehen';
      _advance(1);
      return;
    }
    p.hand.add(c);
    drewThisTurn = true;
    drawnCard = c;
    if (!canPlay(c)) {
      lastEvent = '${p.name} zieht';
      _advance(1);
    }
  }

  /// Nach dem Ziehen die passende Karte doch behalten.
  void pass() {
    if (drewThisTurn) {
      lastEvent = '${actor.name} zieht';
      _advance(1);
    }
  }

  void _advance(int steps) {
    current = (current + steps) % players.length;
    drewThisTurn = false;
    drawnCard = null;
  }

  PlayingCard? _take() {
    if (drawPile.isEmpty && discard.length > 1) {
      final keep = discard.removeLast();
      drawPile = discard..shuffle(_rng);
      discard = [keep];
    }
    return drawPile.isEmpty ? null : drawPile.removeLast();
  }

  int get cardCount =>
      drawPile.length +
      discard.length +
      players.fold<int>(0, (s, p) => s + p.hand.length);
}

String suitName(Suit s) => switch (s) {
      Suit.spades => 'Pik',
      Suit.hearts => 'Herz',
      Suit.diamonds => 'Karo',
      Suit.clubs => 'Kreuz',
    };

Suit favoriteSuit(List<PlayingCard> hand, Random rng) {
  final counts = <Suit, int>{};
  for (final c in hand) {
    if (c.rank != 11) counts[c.suit] = (counts[c.suit] ?? 0) + 1;
  }
  if (counts.isEmpty) return Suit.values[rng.nextInt(4)];
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

/// Wahl eines Computer-Gegners. card ist null, wenn er ziehen muss.
({PlayingCard? card, Suit? wish}) mauBotChoice(MauMauEngine e, Random rng) {
  final hand = e.actor.hand;
  final options = e.playableCards();
  if (options.isEmpty) return (card: null, wish: null);
  final next = e.players[(e.current + 1) % e.players.length];
  double score(PlayingCard c) {
    var s = 0.0;
    if (c.rank == 11) s -= 50;
    if ((c.rank == 7 || c.rank == 8) && next.hand.length <= 2) s += 30;
    s += hand.where((h) => h.suit == c.suit && h != c).length * 3;
    s += rng.nextDouble();
    return s;
  }

  options.sort((a, b) => score(b).compareTo(score(a)));
  final card = options.first;
  final wish = card.rank == 11
      ? favoriteSuit(hand.where((h) => h != card).toList(), rng)
      : null;
  return (card: card, wish: wish);
}

/// Ein ganzer Zug eines Computer-Gegners, ohne Pausen.
void mauBotTurn(MauMauEngine e, Random rng) {
  final choice = mauBotChoice(e, rng);
  if (choice.card != null) {
    e.play(choice.card!, wishSuit: choice.wish);
    return;
  }
  e.draw();
  if (e.drewThisTurn) {
    final again = mauBotChoice(e, rng);
    if (again.card != null) {
      e.play(again.card!, wishSuit: again.wish);
    } else {
      e.pass();
    }
  }
}
