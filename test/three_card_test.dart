import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/threecard/three_card_engine.dart';

TcHand h(List<(int, Suit)> c) => TcHand([for (final (r, s) in c) PlayingCard(r, s)]);

void main() {
  test('Rangfolge mit drei Karten', () {
    final sf = h([(5, Suit.hearts), (6, Suit.hearts), (7, Suit.hearts)]);
    final trips = h([(9, Suit.hearts), (9, Suit.spades), (9, Suit.clubs)]);
    final str = h([(14, Suit.hearts), (2, Suit.spades), (3, Suit.clubs)]);
    final str2 = h([(2, Suit.hearts), (3, Suit.spades), (4, Suit.clubs)]);
    final fl = h([(2, Suit.clubs), (9, Suit.clubs), (13, Suit.clubs)]);
    final pair = h([(13, Suit.clubs), (13, Suit.hearts), (2, Suit.spades)]);
    final qHigh = h([(12, Suit.clubs), (6, Suit.hearts), (4, Suit.spades)]);
    final jHigh = h([(11, Suit.clubs), (9, Suit.hearts), (4, Suit.spades)]);
    expect(sf.rank, TcRank.straightFlush);
    expect(trips.rank, TcRank.trips);
    expect(str.rank, TcRank.straight);
    expect(fl.rank, TcRank.flush);
    expect(pair.rank, TcRank.pair);
    expect(sf.compareTo(trips) > 0 && trips.compareTo(str) > 0 && str.compareTo(fl) > 0 && fl.compareTo(pair) > 0, isTrue);
    expect(str2.compareTo(str) > 0, isTrue, reason: 'A-2-3 ist die kleinste Straße');
    expect(qHigh.qualifies, isTrue);
    expect(jHigh.qualifies, isFalse);
    expect(tcShouldPlay(qHigh), isTrue);
    expect(tcShouldPlay(h([(12, Suit.clubs), (6, Suit.hearts), (3, Suit.spades)])), isFalse);
  });

  test('Quoten: Ante-Hausvorteil etwa 3,4 %, Paar Plus etwa 97,7 %', () {
    final rng = Random(3);
    var anteIn = 0, anteOut = 0, ppIn = 0, ppOut = 0;
    for (var i = 0; i < 400000; i++) {
      final r = TcRound.deal(rng, ante: 10, pairPlus: 10);
      ppIn += 10;
      ppOut += r.pairPlusPaid;
      final res = tcShouldPlay(r.player) ? r.play() : r.fold();
      anteIn += tcShouldPlay(r.player) ? 20 : 10;
      anteOut += res.paid - r.pairPlusPaid;
    }
    // Hausvorteil auf das Ante bezogen: (Einsatz - Rückzahlung) / Ante-Summe ≈ 3,4 %
    final edgePerAnte = (anteIn - anteOut) / (400000 * 10);
    expect(edgePerAnte, inInclusiveRange(0.025, 0.045));
    // Tabelle 1-4-6-30-40: etwa 97,7 %
    expect(ppOut / ppIn, inInclusiveRange(0.96, 0.99));
  });

  test('Gemeinsamer Geber: Spielerkarten nie gleich den Bankkarten', () {
    final dealer = shuffledDeck(Random(7)).sublist(0, 3);
    for (var i = 0; i < 200; i++) {
      final r = TcRound.deal(Random(i), ante: 10, dealerCards: dealer);
      for (final c in r.player.cards) {
        expect(dealer.any((d) => d.rank == c.rank && d.suit == c.suit), isFalse);
      }
      expect(r.dealer.cards.map((c) => '${c.rank}${c.suit}'), dealer.map((c) => '${c.rank}${c.suit}'));
    }
  });
}
