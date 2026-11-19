import 'dart:math';

import '../cards/playing_card.dart';

enum BjPhase { betting, playerTurn, dealerTurn, settled }

enum BjOutcome { blackjack, win, push, lose }

class BjScore {
  const BjScore(this.total, this.soft);
  final int total;
  final bool soft;
}

BjScore scoreCards(List<PlayingCard> cards) {
  var sum = 0;
  var aces = 0;
  for (final c in cards) {
    if (c.rank == 14) {
      aces++;
      sum += 1;
    } else {
      sum += min(c.rank, 10);
    }
  }
  if (aces > 0 && sum + 10 <= 21) return BjScore(sum + 10, true);
  return BjScore(sum, false);
}

class BjHand {
  BjHand(this.cards, this.bet, {this.fromSplit = false});

  final List<PlayingCard> cards;
  int bet;
  final bool fromSplit;
  bool finished = false;
  BjOutcome? outcome;
  int payout = 0;

  BjScore get score => scoreCards(cards);
  bool get busted => score.total > 21;
  bool get isBlackjack =>
      cards.length == 2 && score.total == 21 && !fromSplit;
}

/// Regeln: sechs Decks, Bank steht auf allen 17, Black Jack zahlt 3:2,
/// Verdoppeln auf zwei Karten, einmal Teilen, geteilte Asse erhalten je eine Karte.
class BlackjackEngine {
  BlackjackEngine({Random? rng, List<PlayingCard>? stackedShoe})
      : _rng = rng ?? Random.secure(),
        _stacked = stackedShoe != null {
    _shoe = stackedShoe?.toList() ?? shuffledDeck(_rng, decks: 6);
  }

  final Random _rng;
  final bool _stacked;
  late List<PlayingCard> _shoe;

  BjPhase phase = BjPhase.betting;
  List<BjHand> hands = [];
  List<PlayingCard> dealer = [];
  int activeIndex = 0;

  BjHand get active => hands[activeIndex];
  BjScore get dealerScore => scoreCards(dealer);
  int get totalPayout => hands.fold(0, (sum, h) => sum + h.payout);
  int get totalBet => hands.fold(0, (sum, h) => sum + h.bet);

  bool get holeHidden =>
      phase == BjPhase.playerTurn && dealer.length == 2;

  PlayingCard _draw() => _shoe.removeLast();

  /// Karten des Gebers am Netztisch: für alle gleich, vom Gastgeber vorgegeben.
  List<PlayingCard>? _dealerQueue;

  PlayingCard _dealerDraw() {
    final q = _dealerQueue;
    return q != null && q.isNotEmpty ? q.removeAt(0) : _draw();
  }

  /// Neue Runde. [dealerCards]: feste Reihenfolge der Geberkarten (Netztisch), sonst aus dem eigenen Schuh.
  void deal(int bet, {List<PlayingCard>? dealerCards}) {
    if (!_stacked && _shoe.length < 52) {
      _shoe = shuffledDeck(_rng, decks: 6);
    }
    _dealerQueue = dealerCards?.toList();
    final first = _draw();
    final hole = _dealerDraw();
    final second = _draw();
    final up = _dealerDraw();
    hands = [BjHand([first, second], bet)];
    dealer = [hole, up];
    activeIndex = 0;
    phase = BjPhase.playerTurn;
    if (hands.first.isBlackjack || dealerScore.total == 21) {
      _settle();
    }
  }

  bool get canDouble =>
      phase == BjPhase.playerTurn && active.cards.length == 2;

  bool get canSplit =>
      phase == BjPhase.playerTurn &&
      hands.length == 1 &&
      active.cards.length == 2 &&
      min(active.cards[0].rank, 10) == min(active.cards[1].rank, 10) &&
      (active.cards[0].rank == 14) == (active.cards[1].rank == 14);

  void hit() {
    active.cards.add(_draw());
    if (active.score.total >= 21) _advance();
  }

  void stand() => _advance();

  /// Der Einsatz muss vorher zusätzlich abgebucht worden sein.
  void doubleDown() {
    active.bet *= 2;
    active.cards.add(_draw());
    _advance();
  }

  /// Der zweite Einsatz muss vorher zusätzlich abgebucht worden sein.
  void split() {
    final original = active;
    final isAces = original.cards.first.rank == 14;
    final a = BjHand([original.cards[0], _draw()], original.bet, fromSplit: true);
    final b = BjHand([original.cards[1], _draw()], original.bet, fromSplit: true);
    hands = [a, b];
    activeIndex = 0;
    if (isAces) {
      a.finished = true;
      b.finished = true;
      _finishPlayer();
    } else if (a.score.total == 21) {
      _advance();
    }
  }

  void _advance() {
    active.finished = true;
    while (activeIndex + 1 < hands.length) {
      activeIndex++;
      if (active.score.total == 21) {
        active.finished = true;
      } else {
        return;
      }
    }
    _finishPlayer();
  }

  void _finishPlayer() {
    if (hands.every((h) => h.busted)) {
      _settle();
    } else {
      phase = BjPhase.dealerTurn;
    }
  }

  /// Zieht eine Karte für die Bank. Liefert false, sobald die Runde abgerechnet ist.
  bool dealerStep() {
    if (phase != BjPhase.dealerTurn) return false;
    if (dealerScore.total < 17) {
      dealer.add(_dealerDraw());
      return true;
    }
    _settle();
    return false;
  }

  void _settle() {
    final dealerBj = dealer.length == 2 && dealerScore.total == 21;
    final d = dealerScore.total;
    for (final h in hands) {
      final p = h.score.total;
      if (h.busted) {
        h.outcome = BjOutcome.lose;
      } else if (h.isBlackjack && !dealerBj) {
        h.outcome = BjOutcome.blackjack;
      } else if (dealerBj) {
        h.outcome = h.isBlackjack ? BjOutcome.push : BjOutcome.lose;
      } else if (d > 21 || p > d) {
        h.outcome = BjOutcome.win;
      } else if (p == d) {
        h.outcome = BjOutcome.push;
      } else {
        h.outcome = BjOutcome.lose;
      }
      h.payout = switch (h.outcome!) {
        BjOutcome.blackjack => h.bet * 5 ~/ 2,
        BjOutcome.win => h.bet * 2,
        BjOutcome.push => h.bet,
        BjOutcome.lose => 0,
      };
    }
    phase = BjPhase.settled;
  }
}

/// Geberkarten einer Netzrunde aus dem Startwert des Gastgebers (reicht für jede Geberhand).
List<PlayingCard> bjDealerCards(int seed) => shuffledDeck(Random(seed), decks: 6).sublist(0, 16);
