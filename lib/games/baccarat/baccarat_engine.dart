import 'dart:math';

import '../cards/playing_card.dart';

/// Punto Banco mit sechs Kartenspielen. Spieler und Bank ziehen nach festen Regeln.

enum BacBet { player, banker, tie, playerPair, bankerPair }

const bacBetNames = {
  BacBet.player: 'Spieler',
  BacBet.banker: 'Bank',
  BacBet.tie: 'Unentschieden',
  BacBet.playerPair: 'Spieler-Paar',
  BacBet.bankerPair: 'Bank-Paar',
};

int bacValue(PlayingCard c) => c.rank == 14 ? 1 : (c.rank >= 10 ? 0 : c.rank);

int bacTotal(List<PlayingCard> cards) => cards.fold(0, (a, c) => a + bacValue(c)) % 10;

enum BacWinner { player, banker, tie }

class BacRound {
  BacRound(this.player, this.banker);
  final List<PlayingCard> player;
  final List<PlayingCard> banker;

  int get playerTotal => bacTotal(player);
  int get bankerTotal => bacTotal(banker);
  BacWinner get winner => playerTotal > bankerTotal
      ? BacWinner.player
      : (bankerTotal > playerTotal ? BacWinner.banker : BacWinner.tie);
  bool get playerPair => player[0].rank == player[1].rank;
  bool get bankerPair => banker[0].rank == banker[1].rank;

  /// Gesamtauszahlung (mit Einsatz) für einen Einsatz.
  int payout(BacBet bet, int amount) {
    final w = winner;
    switch (bet) {
      case BacBet.player:
        if (w == BacWinner.tie) return amount;
        return w == BacWinner.player ? amount * 2 : 0;
      case BacBet.banker:
        if (w == BacWinner.tie) return amount;
        return w == BacWinner.banker ? (amount * 19) ~/ 10 : 0;
      case BacBet.tie:
        return w == BacWinner.tie ? amount * 9 : 0;
      case BacBet.playerPair:
        return playerPair ? amount * 12 : 0;
      case BacBet.bankerPair:
        return bankerPair ? amount * 12 : 0;
    }
  }
}

/// Die Ziehregeln der Bank, wenn der Spieler eine dritte Karte gezogen hat.
bool bankerDraws(int bankerTotal, int? playerThird) {
  if (playerThird == null) return bankerTotal <= 5;
  final p = playerThird;
  return switch (bankerTotal) {
    0 || 1 || 2 => true,
    3 => p != 8,
    4 => p >= 2 && p <= 7,
    5 => p >= 4 && p <= 7,
    6 => p == 6 || p == 7,
    _ => false,
  };
}

class BaccaratShoe {
  BaccaratShoe({Random? rng}) : _rng = rng ?? Random.secure() {
    _fill();
  }

  final Random _rng;
  List<PlayingCard> _cards = [];
  final List<BacWinner> history = [];

  void _fill() => _cards = shuffledDeck(_rng, decks: 6);

  int get left => _cards.length;

  PlayingCard _draw() {
    if (_cards.length < 6) _fill();
    return _cards.removeLast();
  }

  BacRound play() {
    if (_cards.length < 20) _fill();
    final p = [_draw()];
    final b = [_draw()];
    p.add(_draw());
    b.add(_draw());
    final pt = bacTotal(p);
    final bt = bacTotal(b);
    if (pt < 8 && bt < 8) {
      int? third;
      if (pt <= 5) {
        p.add(_draw());
        third = bacValue(p.last);
      }
      if (bankerDraws(bt, third)) b.add(_draw());
    }
    final r = BacRound(p, b);
    record(r);
    return r;
  }

  /// Runde in die Verlaufsanzeige eintragen (auch für Runden vom Gastgeber im Netz).
  void record(BacRound r) {
    history.add(r.winner);
    if (history.length > 60) history.removeAt(0);
  }
}

/// Karten einer Runde für das Netz: [[Rang, Farbe], …] je Seite.
List<List<List<int>>> bacRoundToJson(BacRound r) => [
      for (final side in [r.player, r.banker]) [for (final c in side) [c.rank, c.suit.index]],
    ];

/// Runde vom Gastgeber; null, wenn die Daten nicht passen.
BacRound? bacRoundFromJson(Object? o) {
  try {
    final sides = o as List;
    if (sides.length != 2) return null;
    List<PlayingCard> cards(Object? side) => [
          for (final c in side as List)
            PlayingCard(((c as List)[0] as num).toInt(), Suit.values[(c[1] as num).toInt()]),
        ];
    final p = cards(sides[0]);
    final b = cards(sides[1]);
    bool ok(List<PlayingCard> x) => x.length >= 2 && x.length <= 3 && x.every((c) => c.rank >= 2 && c.rank <= 14);
    if (!ok(p) || !ok(b)) return null;
    return BacRound(p, b);
  } catch (_) {
    return null;
  }
}
