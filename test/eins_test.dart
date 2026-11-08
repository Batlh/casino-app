import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';

var _id = 1000;
EinsCard n(EinsColor c, int number) => EinsCard(_id++, EinsKind.number, color: c, number: number);
EinsCard k(EinsKind kind, [EinsColor? c]) => EinsCard(_id++, kind, color: c);
const red = EinsColor.red;
const blue = EinsColor.blue;
const green = EinsColor.green;

EinsEngine game(int players) => EinsEngine(
      players: [for (var i = 0; i < players; i++) EinsPlayer('P$i', human: i == 0)],
      rng: Random(1),
    )..start();

void setTop(EinsEngine e, EinsCard c) {
  e.discard = [c];
  e.color = c.color!;
}

void main() {
  test('Kartensatz: 108 Karten', () {
    final d = einsDeck();
    expect(d.length, 108);
    expect(d.toSet().length, 108);
    expect(d.where((c) => c.kind == EinsKind.wildDrawFour).length, 4);
    expect(d.where((c) => c.kind == EinsKind.number && c.number == 0).length, 4);
    expect(d.where((c) => c.kind == EinsKind.drawTwo).length, 8);
  });

  test('Austeilen: sieben Karten, Zahl als erste Karte', () {
    for (var seed = 0; seed < 40; seed++) {
      final e = EinsEngine(players: [EinsPlayer('A'), EinsPlayer('B')], rng: Random(seed))..start();
      expect(e.players.every((p) => p.hand.length == 7), isTrue);
      expect(e.top.kind, EinsKind.number);
      expect(e.cardCount, 108);
    }
  });

  test('Passt: gleiche Farbe, gleiche Zahl, gleiches Symbol, Farbwahl', () {
    final e = game(3);
    setTop(e, n(red, 5));
    expect(e.canPlay(n(red, 9)), isTrue);
    expect(e.canPlay(n(blue, 5)), isTrue);
    expect(e.canPlay(n(blue, 6)), isFalse);
    expect(e.canPlay(k(EinsKind.wild)), isTrue);
    setTop(e, k(EinsKind.skip, red));
    expect(e.canPlay(k(EinsKind.skip, blue)), isTrue);
    expect(e.canPlay(k(EinsKind.reverse, blue)), isFalse);
  });

  test('Aussetzen und Richtungswechsel', () {
    final e = game(4);
    setTop(e, n(red, 5));
    final skip = k(EinsKind.skip, red);
    final rev = k(EinsKind.reverse, red);
    e.players[0].hand = [skip, rev, n(green, 1)];
    e.play(skip);
    expect(e.current, 2);
    e.current = 0;
    e.play(rev);
    expect(e.direction, -1);
    expect(e.current, 3);
  });

  test('Richtungswechsel zu zweit wirkt wie Aussetzen', () {
    final e = game(2);
    setTop(e, n(red, 5));
    final rev = k(EinsKind.reverse, red);
    e.players[0].hand = [rev, n(green, 1), n(green, 2)];
    e.play(rev);
    expect(e.current, 0);
  });

  test('Plus-Karten stapeln: +2 auf +2, +4 auf +2, auf +4 nur +4', () {
    final e = game(3);
    setTop(e, n(red, 5));
    final a = k(EinsKind.drawTwo, red);
    final b = k(EinsKind.drawTwo, blue);
    final four = k(EinsKind.wildDrawFour);
    e.players[0].hand = [a, n(green, 1), n(green, 2)];
    e.players[1].hand = [b, n(blue, 3), n(blue, 4)];
    e.players[2].hand = [four, n(red, 8), n(red, 9)];
    e.play(a);
    expect(e.pendingDraw, 2);
    expect(e.canPlay(n(blue, 3)), isFalse);
    e.play(b);
    expect(e.pendingDraw, 4);
    e.play(four, chosen: green);
    expect(e.pendingDraw, 8);
    expect(e.canPlay(k(EinsKind.drawTwo, green)), isFalse, reason: 'Auf +4 nur +4');
    e.draw();
    expect(e.players[0].hand.length, 2 + 8);
    expect(e.current, 1, reason: 'Wer zieht, setzt aus');
    expect(e.color, green);
  });

  test('Ohne Stapeln muss gezogen werden', () {
    final e = game(2)..stackDraws = false;
    setTop(e, n(red, 5));
    final a = k(EinsKind.drawTwo, red);
    final b = k(EinsKind.drawTwo, blue);
    e.players[0].hand = [a, n(green, 1), n(green, 2)];
    e.players[1].hand = [b, n(blue, 3)];
    e.play(a);
    expect(e.canPlay(b), isFalse);
    e.draw();
    expect(e.players[1].hand.length, 4);
    expect(e.current, 0);
  });

  test('Eins! vergessen kostet zwei Karten', () {
    final e = game(2);
    setTop(e, n(red, 5));
    final a = n(red, 7);
    e.players[0].hand = [a, n(green, 1)];
    e.play(a, called: false);
    expect(e.players[0].hand.length, 3);
    final e2 = game(2);
    setTop(e2, n(red, 5));
    final b = n(red, 7);
    e2.players[0].hand = [b, n(green, 1)];
    e2.play(b, called: true);
    expect(e2.players[0].hand.length, 1);
    final e3 = game(2)..callRequired = false;
    setTop(e3, n(red, 5));
    final c = n(red, 7);
    e3.players[0].hand = [c, n(green, 1)];
    e3.play(c, called: false);
    expect(e3.players[0].hand.length, 1);
  });

  test('Computer-Partien enden und verlieren keine Karte', () {
    final rng = Random(8);
    for (var g = 0; g < 300; g++) {
      final e = EinsEngine(
        players: [for (var i = 0; i < 2 + g % 3; i++) EinsPlayer('P$i')],
        rng: rng,
        stackDraws: g.isEven,
        callRequired: g % 3 != 0,
      )..start(startPlayer: g % 2);
      var turns = 0;
      while (!e.finished) {
        einsBotTurn(e, rng);
        turns++;
        expect(e.cardCount, 108);
        expect(turns, lessThan(3000), reason: 'Partie endet nicht');
      }
    }
  });
}
