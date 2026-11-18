import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/hand_eval.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/holdem/holdem_engine.dart';

PlayingCard c(int rank, [Suit suit = Suit.spades]) => PlayingCard(rank, suit);

HoldemEngine drawGame(List<HoldemPlayer> p, {List<PlayingCard>? deck, int seed = 1}) =>
    HoldemEngine(players: p, smallBlind: 5, bigBlind: 10, rng: Random(seed), stackedDeck: deck, draw: true);

void main() {
  test('Fünf Karten, kein Tisch, nach der ersten Setzrunde wird getauscht', () {
    final p = [HoldemPlayer('A', 1000), HoldemPlayer('B', 1000), HoldemPlayer('C', 1000)];
    final e = drawGame(p)..startHand();
    expect(p.every((x) => x.hole.length == 5), isTrue);
    expect(e.board, isEmpty);
    // Dealer A, Small Blind B, Big Blind C, A beginnt
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.check);
    expect(e.street, HoldemStreet.draw);
    expect(e.board, isEmpty);
    // Getauscht wird ab links vom Dealer
    expect(e.toAct, 1);
    expect(() => e.apply(HoldemAction.check), throwsStateError);
    final before = [...p[1].hole];
    e.discard([0, 4]);
    expect(p[1].drew, 2);
    expect(p[1].hole[1], before[1]);
    expect(p[1].hole.toSet().intersection({before[0], before[4]}), isEmpty);
    expect(p[1].lastAction, 'Tauscht 2');
    e.discard(const []);
    expect(p[2].lastAction, 'Behält alle');
    e.discard([1, 2, 3]);
    // Zweite Setzrunde beginnt links vom Dealer
    expect(e.street, HoldemStreet.river);
    expect(e.toAct, 1);
    e.apply(HoldemAction.check);
    e.apply(HoldemAction.check);
    e.apply(HoldemAction.check);
    expect(e.handOver, isTrue);
    expect(p.fold(0, (a, x) => a + x.stack), 3000);
    // Keine Karte doppelt im Spiel
    final all = [for (final x in p) ...x.hole];
    expect(all.toSet().length, 15);
  });

  test('Die Hand allein zählt', () {
    // Gezogen wird von hinten: Runde für Runde je eine Karte an B, dann A
    final deck = [
      ...List.generate(20, (i) => c(2 + i % 4, Suit.values[i % 4])),
      // B: Ass-Paar, A: Drilling Siebenen (von hinten gelesen)
      c(9, Suit.clubs), c(4, Suit.hearts),
      c(7, Suit.diamonds), c(5, Suit.clubs),
      c(7, Suit.hearts), c(13, Suit.diamonds),
      c(7, Suit.clubs), c(14, Suit.hearts),
      c(10, Suit.hearts), c(14, Suit.clubs),
    ];
    final p = [HoldemPlayer('A', 1000), HoldemPlayer('B', 1000)];
    final e = drawGame(p, deck: deck)..startHand();
    // Zu zweit: Dealer A ist Small Blind und beginnt
    e.apply(HoldemAction.call);
    e.apply(HoldemAction.check);
    expect(e.street, HoldemStreet.draw);
    e.discard(const []);
    e.discard(const []);
    e.apply(HoldemAction.check);
    e.apply(HoldemAction.check);
    expect(e.handOver, isTrue);
    expect(p[0].shownValue!.category, HandCategory.trips);
    expect(p[1].shownValue!.category, HandCategory.pair);
    expect(p[0].stack, 1010);
  });

  test('All-in vor dem Tauschen: getauscht wird trotzdem, dann aufgedeckt', () {
    final p = [HoldemPlayer('A', 1000), HoldemPlayer('B', 1000)];
    final e = drawGame(p, seed: 4)..startHand();
    e.apply(const HoldemAction(HoldemActionKind.raise, 1000));
    e.apply(HoldemAction.call);
    expect(e.street, HoldemStreet.draw);
    e.discard([0]);
    e.discard([0, 1]);
    expect(e.handOver, isTrue);
    expect(p[0].stack + p[1].stack, 2000);
  });

  test('Computer tauschen sinnvoll', () {
    // Paar behalten, drei tauschen
    expect(drawDiscards([c(9), c(9, Suit.hearts), c(2, Suit.clubs), c(5, Suit.diamonds), c(13, Suit.clubs)]).toSet(), {2, 3, 4});
    // Zwei Paare: nur den Beikarte tauschen
    expect(drawDiscards([c(9), c(9, Suit.hearts), c(4, Suit.clubs), c(4, Suit.diamonds), c(13, Suit.clubs)]), [4]);
    // Straße steht
    expect(drawDiscards([c(5), c(6, Suit.hearts), c(7, Suit.clubs), c(8, Suit.diamonds), c(9, Suit.clubs)]), isEmpty);
    // Vier zum Flush
    expect(drawDiscards([c(2, Suit.hearts), c(6, Suit.hearts), c(9, Suit.hearts), c(13, Suit.hearts), c(4, Suit.clubs)]), [4]);
    // Vier zur Straße
    expect(drawDiscards([c(5), c(6, Suit.hearts), c(7, Suit.clubs), c(8, Suit.diamonds), c(13, Suit.clubs)]), [4]);
    // Nichts: Ass und Dame behalten
    expect(drawDiscards([c(14), c(2, Suit.hearts), c(12, Suit.clubs), c(8, Suit.diamonds), c(4, Suit.clubs)]).toSet(), {1, 3, 4});
  });

  test('Mit Computern laufen viele Hände sauber durch, auch mit sechs Spielern', () {
    final rng = Random(3);
    final players = [for (var i = 0; i < 6; i++) HoldemPlayer('P$i', 1000, style: BotStyle.all[i % 4])];
    final e = HoldemEngine(players: players, smallBlind: 5, bigBlind: 10, rng: Random(1), draw: true);
    var draws = 0;
    for (var hand = 0; hand < 30; hand++) {
      if (players.where((p) => p.stack > 0).length < 2) break;
      e.startHand();
      var guard = 0;
      while (!e.handOver && guard++ < 300) {
        if (e.drawing) {
          e.discard(drawDiscards(e.actor.hole));
          draws++;
        } else {
          e.apply(botDecide(e, rng));
        }
      }
      expect(e.handOver, isTrue);
      expect(players.fold(0, (a, p) => a + p.stack), 6000);
      final cards = [for (final p in players.where((p) => p.inHand)) ...p.hole];
      expect(cards.toSet().length, cards.length, reason: 'keine Karte doppelt');
      expect(players.where((p) => p.inHand).every((p) => p.hole.length == 5), isTrue);
    }
    expect(draws, greaterThan(0));
  });

  test('Gewinnchance: Vierling schlägt fast immer, nichts selten', () {
    final rng = Random(5);
    final quads = estimateDrawEquity([c(9), c(9, Suit.hearts), c(9, Suit.clubs), c(9, Suit.diamonds), c(2)], 3, rng, drawn: true);
    final junk = estimateDrawEquity([c(2), c(5, Suit.hearts), c(7, Suit.clubs), c(9, Suit.diamonds), c(11)], 3, rng, drawn: true);
    expect(quads, greaterThan(0.95));
    expect(junk, lessThan(0.1));
  });
}
