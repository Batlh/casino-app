import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/maumau/maumau_engine.dart';

PlayingCard c(int rank, Suit suit) => PlayingCard(rank, suit);

MauMauEngine game(int players) {
  final e = MauMauEngine(
    players: [for (var i = 0; i < players; i++) MauPlayer('P$i', human: i == 0)],
    rng: Random(1),
  );
  e.start();
  return e;
}

void main() {
  test('Austeilen: fünf Karten, erste Karte ohne Sonderwirkung', () {
    for (var seed = 0; seed < 50; seed++) {
      final e = MauMauEngine(
        players: [MauPlayer('A'), MauPlayer('B'), MauPlayer('C')],
        rng: Random(seed),
      )..start();
      expect(e.players.every((p) => p.hand.length == 5), isTrue);
      expect(const [7, 8, 11].contains(e.top.rank), isFalse);
      expect(e.cardCount, 32);
    }
  });

  test('Sieben auf Sieben: der Nächste zieht vier, wer zieht, ist fertig', () {
    final e = game(3);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(7, Suit.hearts), c(10, Suit.clubs)];
    e.players[1].hand = [c(7, Suit.spades), c(9, Suit.clubs)];
    e.players[2].hand = [c(12, Suit.spades), c(13, Suit.diamonds)];
    e.play(c(7, Suit.hearts));
    expect(e.pendingDraw, 2);
    expect(e.current, 1);
    expect(e.canPlay(c(9, Suit.clubs)), isFalse, reason: 'Nur eine Sieben hilft');
    e.play(c(7, Suit.spades));
    expect(e.pendingDraw, 4);
    expect(e.current, 2);
    e.draw();
    expect(e.players[2].hand.length, 6);
    expect(e.pendingDraw, 0);
    expect(e.current, 0);
  });

  test('Drei Siebenen hintereinander: sechs Karten', () {
    final e = game(3);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(7, Suit.hearts), c(10, Suit.clubs)];
    e.players[1].hand = [c(7, Suit.spades), c(9, Suit.clubs)];
    e.players[2].hand = [c(7, Suit.clubs), c(13, Suit.diamonds)];
    e.play(c(7, Suit.hearts));
    e.play(c(7, Suit.spades));
    e.play(c(7, Suit.clubs));
    expect(e.pendingDraw, 6);
    e.draw();
    expect(e.players[0].hand.length, 7);
  });

  test('Schalter: Nach Strafkarten darf weitergespielt werden', () {
    final e = game(2)..penaltyEndsTurn = false;
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(7, Suit.hearts), c(10, Suit.clubs)];
    e.players[1].hand = [c(9, Suit.clubs), c(13, Suit.hearts)];
    e.play(c(7, Suit.hearts));
    e.draw();
    expect(e.players[1].hand.length, 4);
    expect(e.current, 1, reason: 'Zug geht weiter');
    expect(e.drewThisTurn, isFalse);
    expect(e.canPlay(c(13, Suit.hearts)), isFalse, reason: 'Oben liegt die Sieben');
    expect(e.canPlay(c(9, Suit.clubs)), isFalse);
  });

  test('Schalter: Bube auf Bube verboten', () {
    final e = game(2)..jackOnJack = false;
    e.discard = [c(11, Suit.hearts)];
    e.wish = Suit.clubs;
    expect(e.canPlay(c(11, Suit.spades)), isFalse);
    expect(e.canPlay(c(9, Suit.clubs)), isTrue);
    e.jackOnJack = true;
    expect(e.canPlay(c(11, Suit.spades)), isTrue);
  });

  test('Acht lässt den Nächsten aussetzen', () {
    final e = game(3);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(8, Suit.hearts), c(10, Suit.clubs)];
    e.play(c(8, Suit.hearts));
    expect(e.current, 2);
  });

  test('Bube geht auf alles und bestimmt die Farbe', () {
    final e = game(2);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(11, Suit.clubs), c(10, Suit.clubs)];
    e.players[1].hand = [c(9, Suit.spades), c(10, Suit.diamonds)];
    expect(e.canPlay(c(11, Suit.clubs)), isTrue);
    e.play(c(11, Suit.clubs), wishSuit: Suit.diamonds);
    expect(e.wish, Suit.diamonds);
    expect(e.canPlay(c(9, Suit.spades)), isFalse);
    expect(e.canPlay(c(10, Suit.diamonds)), isTrue);
  });

  test('Gezogene Karte passt nicht: der Nächste ist dran', () {
    final e = game(2);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(10, Suit.clubs)];
    e.drawPile = [c(13, Suit.spades)];
    e.draw();
    expect(e.players[0].hand.length, 2);
    expect(e.current, 1);
  });

  test('Gezogene Karte passt: nur sie darf noch gespielt werden', () {
    final e = game(2);
    e.discard = [c(9, Suit.hearts)];
    e.players[0].hand = [c(10, Suit.clubs)];
    e.drawPile = [c(13, Suit.hearts)];
    e.draw();
    expect(e.current, 0);
    expect(e.drewThisTurn, isTrue);
    expect(e.canPlay(c(13, Suit.hearts)), isTrue);
    e.pass();
    expect(e.current, 1);
  });

  test('Computer-Partien enden und verlieren keine Karte', () {
    final rng = Random(4);
    for (var g = 0; g < 300; g++) {
      final e = MauMauEngine(
        players: [for (var i = 0; i < 2 + g % 3; i++) MauPlayer('P$i')],
        rng: rng,
        penaltyEndsTurn: g % 4 < 2,
        jackOnJack: g.isEven,
      )..start(startPlayer: g % 2);
      var turns = 0;
      while (!e.finished) {
        mauBotTurn(e, rng);
        turns++;
        expect(e.cardCount, 32);
        expect(turns, lessThan(2000), reason: 'Partie endet nicht');
      }
      expect(e.winner!.hand, isEmpty);
    }
  });
}
