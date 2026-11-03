import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/blackjack/blackjack_engine.dart';
import 'package:gluckspfennig/games/cards/hand_eval.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/roulette/roulette_engine.dart';
import 'package:gluckspfennig/games/videopoker/video_poker_engine.dart';

PlayingCard c(int rank, [Suit suit = Suit.spades]) => PlayingCard(rank, suit);

/// Der Stapel wird von hinten gezogen. Reihenfolge hier: Reihenfolge des Ziehens.
List<PlayingCard> shoe(List<PlayingCard> drawOrder) => drawOrder.reversed.toList();

void main() {
  group('Black Jack', () {
    test('Ass zählt 11 oder 1', () {
      expect(scoreCards([c(14), c(6)]).total, 17);
      expect(scoreCards([c(14), c(6)]).soft, isTrue);
      expect(scoreCards([c(14), c(6), c(10)]).total, 17);
      expect(scoreCards([c(14), c(6), c(10)]).soft, isFalse);
      expect(scoreCards([c(14), c(14), c(9)]).total, 21);
    });

    test('Black Jack zahlt 3:2', () {
      // Spieler A, K. Bank 9, 7
      final e = BlackjackEngine(stackedShoe: shoe([c(14), c(9), c(13), c(7)]));
      e.deal(100);
      expect(e.phase, BjPhase.settled);
      expect(e.hands.first.outcome, BjOutcome.blackjack);
      expect(e.totalPayout, 250);
    });

    test('Bank-Black-Jack schlägt 21 nicht, aber alles andere', () {
      final e = BlackjackEngine(stackedShoe: shoe([c(10), c(14), c(9), c(13)]));
      e.deal(100);
      expect(e.phase, BjPhase.settled);
      expect(e.totalPayout, 0);
    });

    test('Beide Black Jack ist Unentschieden', () {
      final e = BlackjackEngine(stackedShoe: shoe([c(14), c(14), c(13), c(13)]));
      e.deal(100);
      expect(e.hands.first.outcome, BjOutcome.push);
      expect(e.totalPayout, 100);
    });

    test('Überkauft verliert ohne Zug der Bank', () {
      final e = BlackjackEngine(
        stackedShoe: shoe([c(10), c(9), c(6), c(7), c(10)]),
      );
      e.deal(50);
      e.hit();
      expect(e.hands.first.busted, isTrue);
      expect(e.phase, BjPhase.settled);
      expect(e.totalPayout, 0);
    });

    test('Bank zieht bis 17 und überkauft sich', () {
      // Spieler 10, 8. Bank 10, 6, dann 10
      final e = BlackjackEngine(
        stackedShoe: shoe([c(10), c(10), c(8), c(6), c(10)]),
      );
      e.deal(50);
      e.stand();
      expect(e.phase, BjPhase.dealerTurn);
      while (e.dealerStep()) {}
      expect(e.phase, BjPhase.settled);
      expect(e.hands.first.outcome, BjOutcome.win);
      expect(e.totalPayout, 100);
    });

    test('Bank steht auf weichen 17', () {
      final e = BlackjackEngine(
        stackedShoe: shoe([c(10), c(14), c(9), c(6), c(5)]),
      );
      e.deal(50);
      e.stand();
      while (e.dealerStep()) {}
      expect(e.dealer.length, 2);
      expect(e.hands.first.outcome, BjOutcome.win);
    });

    test('Verdoppeln zieht eine Karte und verdoppelt den Einsatz', () {
      final e = BlackjackEngine(
        stackedShoe: shoe([c(6), c(10), c(5), c(7), c(10)]),
      );
      e.deal(50);
      expect(e.canDouble, isTrue);
      e.doubleDown();
      while (e.dealerStep()) {}
      expect(e.hands.first.bet, 100);
      expect(e.totalPayout, 200);
    });

    test('Teilen spielt zwei Hände, 21 danach ist kein Black Jack', () {
      // Spieler 8, 8. Bank 10, 9. Zieht Ass auf erste Hand? Hier 3 und 10
      final e = BlackjackEngine(
        stackedShoe: shoe([c(8), c(10), c(8), c(9), c(13), c(10), c(3)]),
      );
      e.deal(50);
      expect(e.canSplit, isTrue);
      e.split();
      expect(e.hands.length, 2);
      expect(e.hands[0].score.total, 18);
      expect(e.hands[1].score.total, 18);
      e.stand();
      e.stand();
      while (e.dealerStep()) {}
      expect(e.hands.every((h) => h.outcome == BjOutcome.lose), isTrue);
    });

    test('Geteilte Asse bekommen je eine Karte und zahlen einfach', () {
      final e = BlackjackEngine(
        stackedShoe: shoe([c(14), c(10), c(14), c(7), c(13), c(13)]),
      );
      e.deal(50);
      e.split();
      expect(e.phase, BjPhase.dealerTurn);
      while (e.dealerStep()) {}
      expect(e.hands.first.outcome, BjOutcome.win);
      expect(e.totalPayout, 200);
    });

    test('Ungleiche Karten lassen sich nicht teilen', () {
      final e = BlackjackEngine(
        stackedShoe: shoe([c(14), c(10), c(5), c(7), c(10)]),
      );
      e.deal(50);
      expect(e.hands.first.isBlackjack, isFalse);
      expect(e.canSplit, isFalse);
    });
  });

  group('Pokerhände', () {
    List<PlayingCard> hand(List<int> ranks, {bool flush = false}) => [
          for (var i = 0; i < ranks.length; i++)
            PlayingCard(ranks[i], flush ? Suit.hearts : Suit.values[i % 4]),
        ];

    test('erkennt jede Kategorie', () {
      HandCategory cat(List<PlayingCard> h) => evaluateFive(h).category;
      expect(cat(hand([14, 13, 12, 11, 10], flush: true)), HandCategory.royalFlush);
      expect(cat(hand([9, 8, 7, 6, 5], flush: true)), HandCategory.straightFlush);
      expect(cat(hand([14, 2, 3, 4, 5], flush: true)), HandCategory.straightFlush);
      expect(cat(hand([9, 9, 9, 9, 5])), HandCategory.quads);
      expect(cat(hand([9, 9, 9, 5, 5])), HandCategory.fullHouse);
      expect(cat(hand([2, 7, 9, 11, 13], flush: true)), HandCategory.flush);
      expect(cat(hand([14, 2, 3, 4, 5])), HandCategory.straight);
      expect(cat(hand([14, 13, 12, 11, 10])), HandCategory.straight);
      expect(cat(hand([9, 9, 9, 5, 4])), HandCategory.trips);
      expect(cat(hand([9, 9, 5, 5, 4])), HandCategory.twoPair);
      expect(cat(hand([9, 9, 5, 3, 2])), HandCategory.pair);
      expect(cat(hand([14, 9, 5, 3, 2])), HandCategory.highCard);
    });

    test('A-K-Q-J-9 ist keine Straße', () {
      expect(evaluateFive(hand([14, 13, 12, 11, 9])).category, HandCategory.highCard);
    });

    test('vergleicht Beikarten und niedrige Straße', () {
      final a = evaluateFive(hand([9, 9, 14, 3, 2]));
      final b = evaluateFive(hand([9, 9, 13, 12, 11]));
      expect(a.compareTo(b), greaterThan(0));
      final wheel = evaluateFive(hand([14, 2, 3, 4, 5]));
      final six = evaluateFive(hand([2, 3, 4, 5, 6]));
      expect(wheel.compareTo(six), lessThan(0));
    });

    test('beste Hand aus sieben Karten', () {
      final v = bestHand([
        c(14, Suit.hearts),
        c(13, Suit.hearts),
        c(12, Suit.hearts),
        c(11, Suit.hearts),
        c(10, Suit.hearts),
        c(2, Suit.clubs),
        c(2, Suit.spades),
      ]);
      expect(v.category, HandCategory.royalFlush);
    });
  });

  group('Video Poker', () {
    test('Paar unter Bube zahlt nichts, ab Bube schon', () {
      expect(
        vpPayIndex([c(10), c(10, Suit.hearts), c(3, Suit.clubs), c(5), c(7, Suit.diamonds)]),
        isNull,
      );
      expect(
        vpPayIndex([c(11), c(11, Suit.hearts), c(3, Suit.clubs), c(5), c(7, Suit.diamonds)]),
        8,
      );
    });

    test('gehaltene Karten bleiben', () {
      final e = VideoPokerEngine(rng: Random(1));
      e.deal(10);
      final kept = e.hand[2];
      e.toggleHold(2);
      e.draw();
      expect(e.hand[2], kept);
      expect(e.phase, VpPhase.done);
    });

    test('Tausch bringt keine doppelten Karten', () {
      final e = VideoPokerEngine(rng: Random(2));
      for (var i = 0; i < 300; i++) {
        e.deal(10);
        e.draw();
        expect(e.hand.toSet().length, 5);
      }
    });
  });

  group('Roulette', () {
    test('Kessel enthält jede Zahl genau einmal', () {
      expect(wheelOrder.toSet().length, 37);
      expect(wheelOrder.reduce(max), 36);
    });

    test('Quoten', () {
      expect(resolveBets({const BetSpot(BetType.straight, 17): 10}, 17), 360);
      expect(resolveBets({const BetSpot(BetType.red): 10}, 1), 20);
      expect(resolveBets({const BetSpot(BetType.red): 10}, 2), 0);
      expect(resolveBets({const BetSpot(BetType.dozen, 1): 10}, 13), 30);
      expect(resolveBets({const BetSpot(BetType.column, 2): 10}, 36), 30);
      expect(resolveBets({const BetSpot(BetType.column, 0): 10}, 34), 30);
    });

    test('Null verliert alle Außenwetten', () {
      for (final t in [BetType.red, BetType.black, BetType.even, BetType.odd, BetType.low, BetType.high]) {
        expect(BetSpot(t).wins(0), isFalse);
      }
      expect(const BetSpot(BetType.straight, 0).wins(0), isTrue);
    });

    test('Jede Wette hat denselben Hausvorteil von 1/37', () {
      for (final spot in [
        const BetSpot(BetType.straight, 5),
        const BetSpot(BetType.red),
        const BetSpot(BetType.even),
        const BetSpot(BetType.dozen, 2),
        const BetSpot(BetType.column, 1),
      ]) {
        var back = 0;
        for (var n = 0; n <= 36; n++) {
          back += resolveBets({spot: 1}, n);
        }
        expect(back, 36);
      }
    });
  });
}
