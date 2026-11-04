import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/hand_eval.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/holdem/holdem_engine.dart';

PlayingCard c(int rank, [Suit suit = Suit.spades]) => PlayingCard(rank, suit);

List<HoldemPlayer> seats(List<int> stacks) => [
      for (var i = 0; i < stacks.length; i++) HoldemPlayer('P$i', stacks[i]),
    ];

HoldemEngine engine(List<HoldemPlayer> p, {List<PlayingCard>? deck, int seed = 1}) =>
    HoldemEngine(
      players: p,
      smallBlind: 5,
      bigBlind: 10,
      rng: Random(seed),
      stackedDeck: deck,
    );

void main() {
  test('Blinds und erste Aktion bei drei Spielern', () {
    final p = seats([1000, 1000, 1000]);
    final e = engine(p)..startHand();
    expect(e.dealer, 0);
    expect(p[1].streetBet, 5);
    expect(p[2].streetBet, 10);
    expect(e.toAct, 0);
    expect(e.toCall, 10);
    expect(e.minRaiseTo, 20);
  });

  test('Zu zweit ist der Dealer Small Blind und beginnt', () {
    final p = seats([1000, 1000]);
    final e = engine(p)..startHand();
    expect(e.dealer, 0);
    expect(p[0].streetBet, 5);
    expect(p[1].streetBet, 10);
    expect(e.toAct, 0);
    e.apply(HoldemAction.call);
    expect(e.toAct, 1, reason: 'Big Blind darf noch handeln');
    e.apply(HoldemAction.check);
    expect(e.street, HoldemStreet.flop);
    expect(e.board.length, 3);
    expect(e.toAct, 1, reason: 'Nach dem Flop beginnt der Big Blind');
  });

  test('Alle passen: Rest gewinnt ohne Karten zu zeigen', () {
    final p = seats([1000, 1000, 1000]);
    final e = engine(p)..startHand();
    e.apply(HoldemAction.fold);
    e.apply(HoldemAction.fold);
    expect(e.handOver, isTrue);
    expect(p[2].stack, 1005);
    expect(p[1].stack, 995);
    expect(e.results.single.value, isNull);
  });

  test('Erhöhung erzwingt erneute Runde und Mindest-Reraise', () {
    final p = seats([1000, 1000, 1000]);
    final e = engine(p)..startHand();
    e.apply(const HoldemAction(HoldemActionKind.raise, 40));
    expect(e.currentBet, 40);
    expect(e.minRaise, 30);
    expect(e.toAct, 1);
    expect(e.minRaiseTo, 70);
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.call);
    expect(e.street, HoldemStreet.flop);
    expect(e.pot, 120);
  });

  test('Nebentopf: Kurzer All-in gewinnt nur den Haupttopf', () {
    // Ziehreihenfolge: je zwei Karten für P1, P2, P0, dann Board
    final deck = [
      // Erste Runde P1, P2, P0
      c(14), c(13), c(2, Suit.clubs),
      // Zweite Runde P1, P2, P0
      c(14, Suit.hearts), c(13, Suit.hearts), c(3, Suit.diamonds),
      // Board
      c(7, Suit.diamonds), c(8, Suit.clubs), c(9, Suit.hearts),
      c(4, Suit.spades), c(5, Suit.clubs),
    ].reversed.toList();
    final p = seats([1000, 100, 500]);
    final e = engine(p, deck: deck)..startHand();
    // P0 geht All-in mit 1000, P1 und P2 gehen mit
    e.apply(const HoldemAction(HoldemActionKind.raise, 1000));
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.call);
    expect(e.handOver, isTrue);
    expect(e.board.length, 5);
    // P1 mit Assen gewinnt 3 x 100, P2 mit Königen den Nebentopf 2 x 400,
    // P0 bekommt seinen Überschuss von 500 zurück
    expect(p[1].stack, 300);
    expect(p[2].stack, 800);
    expect(p[0].stack, 500);
    expect(p[0].stack + p[1].stack + p[2].stack, 1600);
  });

  test('Split-Pot teilt gleichmäßig, Rest an den ersten links vom Dealer', () {
    final deck = [
      c(2, Suit.clubs), c(2, Suit.hearts), c(3, Suit.clubs), c(3, Suit.hearts),
      c(14), c(13), c(12), c(11), c(10),
    ].reversed.toList();
    final p = seats([1000, 1000]);
    final e = engine(p, deck: deck)..startHand();
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.check);
    for (var i = 0; i < 6; i++) {
      e.apply(HoldemAction.check);
    }
    expect(e.handOver, isTrue);
    expect(e.board.length, 5);
    expect(evaluateFive(e.board).category, HandCategory.royalFlush);
    expect(p[0].stack, 1000);
    expect(p[1].stack, 1000);
  });

  test('Viele Zufallshände: Chips bleiben erhalten, nichts bleibt hängen', () {
    final rng = Random(7);
    final p = seats([500, 800, 1200, 300, 2000]);
    final total = p.fold(0, (s, x) => s + x.stack);
    for (final x in p) {
      x.style = BotStyle.all[rng.nextInt(BotStyle.all.length)];
    }
    final e = HoldemEngine(players: p, smallBlind: 5, bigBlind: 10, rng: rng);
    for (var hand = 0; hand < 400; hand++) {
      if (p.where((x) => x.stack > 0).length < 2) {
        for (final x in p) {
          x.stack = 0;
        }
        p.first.stack = total ~/ 2;
        p.last.stack = total - total ~/ 2;
      }
      e.startHand();
      var guard = 0;
      while (!e.handOver) {
        e.apply(botDecide(e, rng));
        guard++;
        expect(guard, lessThan(200), reason: 'Hand endet nicht');
      }
      expect(p.fold(0, (s, x) => s + x.stack), total, reason: 'Hand $hand');
      expect(p.every((x) => x.stack >= 0), isTrue);
    }
  });

  test('Gewinnchance: Asse sind stark, 7-2 schwach', () {
    final rng = Random(3);
    final aces = estimateEquity(
      [c(14), c(14, Suit.hearts)], [], 1, rng, iterations: 600);
    final junk = estimateEquity(
      [c(7), c(2, Suit.hearts)], [], 1, rng, iterations: 600);
    expect(aces, greaterThan(0.75));
    expect(junk, lessThan(0.45));
  });
}
