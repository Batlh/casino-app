import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';
import 'package:gluckspfennig/games/quatro/quatro_engine.dart';

var _id = 500;
QTile n(EinsColor c, int number) => QTile(_id++, TileKind.number, c, number);
QTile s(TileKind k, EinsColor c) => QTile(_id++, k, c);
const red = EinsColor.red;
const blue = EinsColor.blue;
const green = EinsColor.green;

QuatroEngine game() => QuatroEngine(players: [QPlayer('Du', human: true), QPlayer('B')], rng: Random(3))..start();

void main() {
  test('Beutel hat 44 Steine', () {
    expect(quatroBag().length, 44);
    final e = game();
    expect(e.tileCount, 44);
  });

  test('Anlegen nur passend zu einem Nachbarn', () {
    final e = game();
    e.board[3].add(n(red, 4));
    expect(e.canPlace(n(blue, 4), 3), isTrue, reason: 'gleiche Zahl');
    expect(e.canPlace(n(red, 1), 4), isTrue, reason: 'gleiche Farbe daneben');
    expect(e.canPlace(n(blue, 1), 4), isFalse);
    expect(e.canPlace(n(blue, 1), 0), isTrue, reason: 'ohne Nachbarn frei');
    expect(e.canPlace(s(TileKind.push, blue), 0), isFalse, reason: 'Schieber braucht Steine');
    expect(e.canPlace(s(TileKind.push, blue), 3), isTrue);
  });

  test('Vier gleiche Farben oder Zahlen gewinnen', () {
    final e = game();
    for (var c = 0; c < 3; c++) {
      e.board[c].add(n(red, c));
    }
    final t = n(red, 6);
    e.players[0].hand = [t];
    e.place(t, 3);
    expect(e.winner, e.players[0]);
    expect(e.winLine.length, 4);

    final f = game();
    f.board[0].addAll([n(red, 5), n(blue, 5), n(green, 5)]);
    final last = n(EinsColor.yellow, 5);
    f.players[0].hand = [last];
    f.place(last, 0);
    expect(f.winner, f.players[0]);
  });

  test('Schieber, Spaltentausch und Minus zwei', () {
    final e = game();
    final bottom = n(red, 1);
    e.board[2].addAll([bottom, n(red, 2)]);
    final push = s(TileKind.push, red);
    e.players[0].hand.add(push);
    final total = e.tileCount;
    e.place(push, 2);
    expect(e.board[2].first.number, 2);
    expect(e.board[2].last, push);
    expect(e.bag.first, bottom);
    expect(e.tileCount, total);

    final g = game();
    g.board[0].add(n(red, 1));
    final swap = s(TileKind.swap, red);
    g.players[0].hand.add(swap);
    g.place(swap, 0);
    expect(g.swapPending, isTrue);
    g.swapColumns(0, 6);
    expect(g.board[6].length, 2);
    expect(g.current, 1);

    final m = game();
    final minus = s(TileKind.minusTwo, blue);
    m.players[0].hand.add(minus);
    m.place(minus, 0);
    expect(m.players[1].hand.length, 1);
    expect(m.players[0].hand.length, 3);
  });

  test('Computer-Partien enden und verlieren keinen Stein', () {
    final rng = Random(5);
    for (var g = 0; g < 200; g++) {
      final e = QuatroEngine(players: [for (var i = 0; i < 2 + g % 3; i++) QPlayer('P$i')], rng: rng)..start();
      var turns = 0;
      while (!e.finished) {
        quatroBotTurn(e, rng);
        turns++;
        expect(e.tileCount, 44);
        expect(turns, lessThan(2000));
      }
    }
  });
}
