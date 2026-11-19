import 'dart:math';

import '../cards/playing_card.dart';

/// Three Card Poker gegen die Bank, wie im Casino.
///
/// Du setzt das Ante (und wahlweise Paar Plus), bekommst drei Karten und spielst weiter (Play = Ante) oder steigst
/// aus. Die Bank spielt ab Dame hoch. Spielt sie nicht, zahlt das Ante 1:1 und Play geht zurück. Spielt sie,
/// gewinnt die bessere Hand Ante und Play 1:1. Ante-Bonus und Paar Plus zahlen unabhängig von der Bank.
enum TcRank { highCard, pair, flush, straight, trips, straightFlush }

const tcRankNames = {
  TcRank.highCard: 'Höchste Karte',
  TcRank.pair: 'Paar',
  TcRank.flush: 'Flush',
  TcRank.straight: 'Straße',
  TcRank.trips: 'Drilling',
  TcRank.straightFlush: 'Straight Flush',
};

/// Ante-Bonus (zahlt auch, wenn die Bank gewinnt).
const tcAnteBonus = {TcRank.straight: 1, TcRank.trips: 4, TcRank.straightFlush: 5};

/// Paar Plus: Auszahlung zu 1.
const tcPairPlus = {TcRank.pair: 1, TcRank.flush: 4, TcRank.straight: 6, TcRank.trips: 30, TcRank.straightFlush: 40};

class TcHand implements Comparable<TcHand> {
  TcHand(List<PlayingCard> cards) : cards = List.unmodifiable(cards) {
    final r = [for (final c in cards) c.rank]..sort((a, b) => b - a);
    final flush = cards.every((c) => c.suit == cards.first.suit);
    var straight = r[0] - r[1] == 1 && r[1] - r[2] == 1;
    var order = r;
    // A-2-3 ist die kleinste Straße
    if (r[0] == 14 && r[1] == 3 && r[2] == 2) {
      straight = true;
      order = [3, 2, 1];
    }
    if (r[0] == r[1] && r[1] == r[2]) {
      rank = TcRank.trips;
    } else if (straight && flush) {
      rank = TcRank.straightFlush;
    } else if (straight) {
      rank = TcRank.straight;
    } else if (flush) {
      rank = TcRank.flush;
    } else if (r[0] == r[1] || r[1] == r[2]) {
      rank = TcRank.pair;
      final pair = r[1];
      final kicker = r[0] == r[1] ? r[2] : r[0];
      order = [pair, pair, kicker];
    } else {
      rank = TcRank.highCard;
    }
    tiebreak = order;
  }

  final List<PlayingCard> cards;
  late final TcRank rank;
  late final List<int> tiebreak;

  /// Bank spielt ab Dame hoch.
  bool get qualifies => rank != TcRank.highCard || tiebreak[0] >= 12;

  @override
  int compareTo(TcHand o) {
    if (rank != o.rank) return rank.index - o.rank.index;
    for (var i = 0; i < 3; i++) {
      if (tiebreak[i] != o.tiebreak[i]) return tiebreak[i] - o.tiebreak[i];
    }
    return 0;
  }
}

/// Einfache gute Strategie: spielen ab Dame-6-4.
bool tcShouldPlay(TcHand h) {
  if (h.rank != TcRank.highCard) return true;
  final t = h.tiebreak;
  if (t[0] != 12) return t[0] > 12;
  if (t[1] != 6) return t[1] > 6;
  return t[2] >= 4;
}

class TcResult {
  TcResult({required this.paid, required this.text, required this.dealerQualifies, required this.outcome});
  final int paid; // gesamte Rückzahlung inklusive Einsätze
  final String text;
  final bool dealerQualifies;
  final int outcome; // 1 gewonnen, 0 unentschieden/zurück, -1 verloren
}

class TcRound {
  TcRound({required this.ante, required this.pairPlus, required this.player, required this.dealer});

  factory TcRound.deal(Random rng, {required int ante, int pairPlus = 0, List<PlayingCard>? dealerCards}) {
    final deck = shuffledDeck(rng);
    final dealer = dealerCards ?? deck.sublist(3, 6);
    final rest = [for (final c in deck) if (!dealer.any((d) => d.rank == c.rank && d.suit == c.suit)) c];
    return TcRound(ante: ante, pairPlus: pairPlus, player: TcHand(rest.sublist(0, 3)), dealer: TcHand(dealer));
  }

  final int ante;
  final int pairPlus;
  final TcHand player;
  final TcHand dealer;

  /// Paar Plus allein (wird gleich nach dem Austeilen abgerechnet).
  int get pairPlusPaid {
    final m = tcPairPlus[player.rank];
    return pairPlus == 0 || m == null ? 0 : pairPlus * (m + 1);
  }

  /// Aussteigen: Ante (und Play) verloren, Paar Plus zählt trotzdem.
  TcResult fold() => TcResult(paid: pairPlusPaid, text: 'Ausgestiegen', dealerQualifies: dealer.qualifies, outcome: -1);

  /// Weiterspielen mit Play = Ante.
  TcResult play() {
    var paid = pairPlusPaid;
    final bonus = tcAnteBonus[player.rank];
    if (bonus != null) paid += ante * bonus;
    final String text;
    final int outcome;
    if (!dealer.qualifies) {
      paid += ante * 2 + ante; // Ante 1:1, Play zurück
      text = 'Bank spielt nicht';
      outcome = 1;
    } else {
      final c = player.compareTo(dealer);
      if (c > 0) {
        paid += ante * 4;
        text = 'Gewonnen';
        outcome = 1;
      } else if (c == 0) {
        paid += ante * 2;
        text = 'Unentschieden';
        outcome = 0;
      } else {
        text = 'Bank gewinnt';
        outcome = -1;
      }
    }
    return TcResult(paid: paid, text: text, dealerQualifies: dealer.qualifies, outcome: outcome);
  }
}
