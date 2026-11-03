import 'dart:math';

import '../cards/hand_eval.dart';
import '../cards/playing_card.dart';

enum VpPhase { betting, holding, done }

class VpPay {
  const VpPay(this.name, this.multiplier);
  final String name;
  final int multiplier;
}

/// Gewinntabelle Jacks or Better 9/6, höchste Hand zuerst.
const List<VpPay> vpPayTable = [
  VpPay('Royal Flush', 800),
  VpPay('Straight Flush', 50),
  VpPay('Vierling', 25),
  VpPay('Full House', 9),
  VpPay('Flush', 6),
  VpPay('Straße', 4),
  VpPay('Drilling', 3),
  VpPay('Zwei Paare', 2),
  VpPay('Paar ab Bube', 1),
];

/// Tabellenzeile einer Hand oder null, wenn sie nichts gewinnt.
int? vpPayIndex(List<PlayingCard> hand) {
  final v = evaluateFive(hand);
  return switch (v.category) {
    HandCategory.royalFlush => 0,
    HandCategory.straightFlush => 1,
    HandCategory.quads => 2,
    HandCategory.fullHouse => 3,
    HandCategory.flush => 4,
    HandCategory.straight => 5,
    HandCategory.trips => 6,
    HandCategory.twoPair => 7,
    HandCategory.pair => v.ranks.first >= 11 ? 8 : null,
    HandCategory.highCard => null,
  };
}

class VideoPokerEngine {
  VideoPokerEngine({Random? rng}) : _rng = rng ?? Random.secure();

  final Random _rng;
  List<PlayingCard> _deck = [];
  List<PlayingCard> hand = [];
  List<bool> held = List.filled(5, false);
  VpPhase phase = VpPhase.betting;
  int bet = 0;
  int payout = 0;
  int? payIndex;

  void deal(int stake, {List<PlayingCard>? stacked}) {
    bet = stake;
    _deck = stacked?.toList() ?? shuffledDeck(_rng);
    hand = [for (var i = 0; i < 5; i++) _deck.removeLast()];
    held = List.filled(5, false);
    payout = 0;
    payIndex = vpPayIndex(hand);
    phase = VpPhase.holding;
  }

  void toggleHold(int i) {
    if (phase == VpPhase.holding) held[i] = !held[i];
  }

  void draw() {
    for (var i = 0; i < 5; i++) {
      if (!held[i]) hand[i] = _deck.removeLast();
    }
    payIndex = vpPayIndex(hand);
    payout = payIndex == null ? 0 : bet * vpPayTable[payIndex!].multiplier;
    phase = VpPhase.done;
  }
}
