import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/skat/skat_bot.dart';
import 'package:gluckspfennig/games/skat/skat_engine.dart';

const j = 11;
PlayingCard c(int r, Suit s) => PlayingCard(r, s);

/// Ein ganzes Spiel nur mit Computern.
void botStep(SkatGame g, Random rng) {
  switch (g.phase) {
    case SkatPhase.bidding:
      final p = g.bidTurn;
      if (skatMaxBid(g.players[p].hand) >= g.askedValue) {
        g.bidYes(p);
      } else {
        g.bidPass(p);
      }
    case SkatPhase.skatChoice:
      g.takeSkat();
    case SkatPhase.discard:
      final cards = g.players[g.declarer].hand;
      final t = skatChooseGame(g, cards);
      g.discard(skatDiscard(cards, t));
    case SkatPhase.declare:
      g.declare(skatChooseGame(g, [...g.players[g.declarer].hand, ...g.skat]));
    case SkatPhase.playing:
      g.play(g.current, skatBotCard(g, g.current, rng));
    case SkatPhase.dealOver:
      g.nextDeal();
    case SkatPhase.matchOver:
      break;
  }
}

void main() {
  test('Reizwerte', () {
    expect(bidValues.take(8), [18, 20, 22, 23, 24, 27, 30, 33]);
    expect(nextBid(18), 20);
  });

  test('Buben stechen, Kreuz Bube ist der höchste', () {
    final trick = [c(14, Suit.hearts), c(j, Suit.diamonds), c(j, Suit.clubs)];
    expect(trickWinner(trick, SkatType.hearts), 2);
    expect(trickWinner([c(10, Suit.spades), c(14, Suit.spades), c(13, Suit.spades)], SkatType.grand), 1);
    // Null: Bube ist eine normale Karte unter der Dame
    expect(trickWinner([c(j, Suit.spades), c(12, Suit.spades), c(7, Suit.spades)], SkatType.nullGame), 1);
  });

  test('Spitzen mit und ohne', () {
    final mit2 = [c(j, Suit.clubs), c(j, Suit.spades), c(7, Suit.hearts)];
    expect(spitzen(mit2, SkatType.hearts), 2);
    final ohne1 = [c(j, Suit.spades), c(7, Suit.hearts)];
    expect(spitzen(ohne1, SkatType.hearts), 1);
  });

  test('Bedienen: Buben gehören zum Trumpf', () {
    final g = SkatGame(rng: Random(1))..start();
    g.type = SkatType.hearts;
    g.phase = SkatPhase.playing;
    g.current = 1;
    g.players[1].hand = [c(j, Suit.spades), c(7, Suit.spades), c(8, Suit.clubs)];
    g.trick = [c(9, Suit.hearts)];
    g.trickStarter = 0;
    expect(g.legalCards(1), [c(j, Suit.spades)]);
    g.trick = [c(10, Suit.spades)];
    expect(g.legalCards(1), [c(7, Suit.spades)]);
  });

  test('Ganze Listen laufen durch', () {
    for (var seed = 0; seed < 6; seed++) {
      final rng = Random(seed);
      final g = SkatGame(rng: Random(seed + 20))..start();
      var steps = 0;
      var games = 0;
      var passedOut = 0;
      while (g.phase != SkatPhase.matchOver && steps < 20000) {
        if (g.phase == SkatPhase.playing) {
          final total = g.players.fold(0, (a, p) => a + p.hand.length + p.won.length) + g.trick.length + g.skat.length;
          expect(total, 32, reason: 'Schritt $steps');
        }
        final before = g.dealsPlayed;
        botStep(g, rng);
        if (g.dealsPlayed != before) {
          if (g.result!.declarer < 0) {
            passedOut++;
          } else {
            games++;
            if (g.type != SkatType.nullGame && g.players.every((p) => p.hand.isEmpty)) {
              final opp = g.players.where((p) => p != g.players[g.declarer]).fold(0, (a, p) => a + p.won.fold(0, (x, c) => x + cardPoints(c)));
              expect(g.declarerPoints() + opp, 120);
            }
          }
        }
        steps++;
      }
      expect(g.phase, SkatPhase.matchOver);
      // ignore: avoid_print
      print('Skat Seed $seed: $games Spiele, $passedOut eingepasst, ${g.players.map((p) => p.score).join('/')}');
    }
  });
}
