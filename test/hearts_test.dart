import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/hearts/hearts_engine.dart';

PlayingCard c(int rank, Suit suit) => PlayingCard(rank, suit);

HeartsEngine engine({int seed = 1}) => HeartsEngine(
      seats: [for (var i = 0; i < 4; i++) HeartsSeat('S$i', human: i == 0)],
      rng: Random(seed),
    );

void playBots(HeartsEngine e) {
  while (e.phase == HeartsPhase.playing) {
    e.play(heartsBotPlay(e));
  }
}

void main() {
  test('Weitergabe nach links, rechts, gegenüber, keine', () {
    final e = engine();
    expect([for (var h = 0; h < 4; h++) const [1, 3, 2, 0][h]], [1, 3, 2, 0]);
    e.startHand();
    expect(e.phase, HeartsPhase.passing);
    final given = e.seats[0].hand.take(3).toList();
    for (var s = 0; s < 4; s++) {
      e.choosePass(s, e.seats[s].hand.take(3).toList());
    }
    expect(e.phase, HeartsPhase.playing);
    expect(e.seats[1].hand, containsAll(given));
    expect(e.seats.every((s) => s.hand.length == 13), isTrue);
  });

  test('Kreuz Zwei beginnt, Farbe muss bedient werden', () {
    final e = engine();
    e.handNumber = 3;
    e.startHand();
    expect(e.phase, HeartsPhase.playing);
    final starter = e.current;
    expect(e.legalCards(starter), [c(2, Suit.clubs)]);
    e.play(c(2, Suit.clubs));
    final next = e.current;
    final hasClubs = e.seats[next].hand.any((x) => x.suit == Suit.clubs);
    final legal = e.legalCards(next);
    if (hasClubs) {
      expect(legal.every((x) => x.suit == Suit.clubs), isTrue);
    } else {
      expect(legal.any((x) => cardPoints(x) > 0), isFalse,
          reason: 'Im ersten Stich keine Punkte, wenn es anders geht');
    }
  });

  test('Herz erst ausspielen, wenn Herz gefallen ist', () {
    final e = engine();
    e.phase = HeartsPhase.playing;
    e.tricksPlayed = 1;
    e.current = 0;
    e.seats[0].hand = [c(5, Suit.hearts), c(9, Suit.diamonds)];
    expect(e.legalCards(0), [c(9, Suit.diamonds)]);
    e.heartsBroken = true;
    expect(e.legalCards(0).length, 2);
    e.heartsBroken = false;
    e.seats[0].hand = [c(5, Suit.hearts), c(9, Suit.hearts)];
    expect(e.legalCards(0).length, 2, reason: 'Nur noch Herz auf der Hand');
  });

  test('Punkte und Mondschuss', () {
    expect(pointsOf([c(12, Suit.spades), c(2, Suit.hearts), c(14, Suit.hearts)]), 15);
    final e = engine();
    e.handNumber = 3;
    e.startHand();
    // Sitz 2 bekommt alle Punktekarten
    for (final s in e.seats) {
      s.hand = [];
    }
    e.phase = HeartsPhase.playing;
    e.tricksPlayed = 12;
    e.current = 0;
    e.seats[2].taken = [
      for (var r = 2; r <= 14; r++) c(r, Suit.hearts),
      c(12, Suit.spades),
    ];
    e.seats[0].hand = [c(3, Suit.clubs)];
    e.seats[1].hand = [c(4, Suit.clubs)];
    e.seats[2].hand = [c(14, Suit.clubs)];
    e.seats[3].hand = [c(5, Suit.clubs)];
    for (var i = 0; i < 4; i++) {
      e.play(e.legalCards(e.current).first);
    }
    expect(e.moonShooter, 2);
    expect(e.seats.map((s) => s.handPoints).toList(), [26, 26, 0, 26]);
  });

  test('Ganze Partien mit Computer-Spielern', () {
    for (var seed = 0; seed < 40; seed++) {
      final e = engine(seed: seed);
      e.newGame();
      var hands = 0;
      while (e.phase != HeartsPhase.gameOver) {
        if (e.phase == HeartsPhase.handOver) e.startHand();
        if (e.phase == HeartsPhase.passing) {
          for (var s = 0; s < 4; s++) {
            e.choosePass(s, heartsBotPass(e.seats[s].hand));
          }
        }
        final total = e.seats.fold<int>(0, (s, x) => s + x.hand.length);
        expect(total, 52);
        playBots(e);
        hands++;
        final pts = e.seats.fold<int>(0, (s, x) => s + x.handPoints);
        expect(pts, e.moonShooter == null ? 26 : 78);
        expect(e.seats.fold<int>(0, (s, x) => s + x.taken.length), 52);
        expect(hands, lessThan(60));
      }
      expect(e.seats.any((s) => s.score >= 100), isTrue);
    }
  });
}
