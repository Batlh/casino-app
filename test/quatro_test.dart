import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';
import 'package:gluckspfennig/games/quatro/quatro_engine.dart';

var _id = 500;
QTile n(EinsColor c, int number) => QTile(_id++, c, number);
QTile s(TileKind k, EinsColor c, [int number = 5]) => QTile(_id++, c, number, k);
const red = EinsColor.red;
const blue = EinsColor.blue;
const green = EinsColor.green;
const yellow = EinsColor.yellow;

QuatroEngine game() => QuatroEngine(players: [QPlayer('Du', human: true), QPlayer('B')], rng: Random(3))..start();

void main() {
  test('Beutel wie im Original: 44 Steine, 0 bis 5', () {
    final bag = quatroBag();
    expect(bag.length, 44);
    expect(bag.where((t) => t.kind == TileKind.swap).length, 12);
    expect(bag.where((t) => t.kind == TileKind.push).length, 8);
    expect(bag.where((t) => t.kind == TileKind.minusTwo).length, 8);
    for (final c in [red, yellow, green, blue]) {
      expect(bag.where((t) => t.color == c).length, 11);
      expect(bag.where((t) => t.color == c && t.number == 0).length, 1);
      for (var k = 1; k <= 5; k++) {
        expect(bag.where((t) => t.color == c && t.number == k).length, 2);
      }
    }
    expect(game().tileCount, 44);
  });

  test('Anlegen nur passend zu einem Nachbarn', () {
    final e = game();
    e.board[3].add(n(red, 4));
    expect(e.canPlace(n(blue, 4), 3), isTrue, reason: 'gleiche Zahl');
    expect(e.canPlace(n(red, 1), 4), isTrue, reason: 'gleiche Farbe daneben');
    expect(e.canPlace(n(blue, 1), 4), isFalse);
    expect(e.canPlace(n(blue, 1), 0), isTrue, reason: 'ohne Nachbarn frei');
    expect(e.canPlace(s(TileKind.swap, blue, 4), 4), isTrue, reason: 'Aktionssteine haben auch Zahlen');
  });

  test('Vier gleiche Farben oder Zahlen gewinnen', () {
    final e = game();
    for (var c = 0; c < 3; c++) {
      e.board[c].add(n(red, c));
    }
    final t = n(red, 5);
    e.players[0].hand = [t];
    e.place(t, 3);
    expect(e.winner, e.players[0]);
    expect(e.winLine.length, 4);

    final f = game();
    f.board[0].addAll([n(red, 5), n(blue, 5), n(green, 5)]);
    final last = n(yellow, 5);
    f.players[0].hand = [last];
    f.place(last, 0);
    expect(f.winner, f.players[0]);
  });

  test('Schieber: unterster Stein zurück in den Beutel, auch in volle Spalten', () {
    final e = game();
    final bottom = n(red, 1);
    e.board[2].addAll([bottom, n(red, 2), n(red, 3), n(blue, 3), n(blue, 4), n(blue, 2)]);
    final push = s(TileKind.push, blue, 2);
    e.players[0].hand.add(push);
    final total = e.tileCount;
    expect(e.canPlace(push, 2), isTrue);
    expect(e.canPlace(n(blue, 2), 2), isFalse, reason: 'Spalte voll');
    e.place(push, 2);
    expect(e.board[2].length, 6);
    expect(e.board[2].last, push);
    expect(e.bag.first, bottom);
    expect(e.tileCount, total);

    final g = game();
    final p2 = s(TileKind.push, green, 3);
    g.players[0].hand.add(p2);
    g.place(p2, 4);
    expect(g.board[4], [p2], reason: 'In leerer Spalte bleibt der Schieber liegen');
  });

  test('Spaltentausch und Minus zwei', () {
    final g = game();
    g.board[0].add(n(red, 1));
    final swap = s(TileKind.swap, red, 3);
    g.players[0].hand.add(swap);
    g.place(swap, 0);
    expect(g.swapPending, isTrue);
    g.swapColumns(0, 6);
    expect(g.board[6].length, 2);
    expect(g.current, 1);

    final m = game();
    final minus = s(TileKind.minusTwo, blue, 1);
    m.players[0].hand.add(minus);
    m.place(minus, 0);
    expect(m.players[1].hand.length, 1);
    expect(m.players[0].hand.length, 3);
  });

  test('Tauschen mit dem Beutel: Passt der neue Stein, darf er sofort gelegt werden', () {
    final e = game();
    for (var c = 0; c < 7; c++) {
      e.board[c].add(n(red, 0));
    }
    e.players[0].hand = [n(blue, 3), n(blue, 4), n(green, 5)];
    expect(e.canMove, isFalse);
    final fresh = n(red, 2);
    e.bag.add(fresh);
    e.exchange(e.players[0].hand.first);
    expect(e.exchanged, fresh);
    expect(e.current, 0);
    expect(e.canPlace(e.players[0].hand.first, 0), isFalse, reason: 'Nur der neue Stein');
    e.place(fresh, 0);
    expect(e.current, 1);
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
