import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';

var _id = 1000;
EinsCard n(EinsColor c, int number) => EinsCard.simple(_id++, EinsKind.number, color: c, number: number);
EinsCard k(EinsKind kind, [EinsColor? c]) => EinsCard.simple(_id++, kind, color: c);
const red = EinsColor.red;
const blue = EinsColor.blue;
const green = EinsColor.green;

EinsEngine game(int players, {EinsMode mode = EinsMode.classic}) => EinsEngine(
      players: [for (var i = 0; i < players; i++) EinsPlayer('P$i', human: i == 0)],
      mode: mode,
      rng: Random(1),
    )..start();

void setTop(EinsEngine e, EinsCard c) {
  e.discard = [c];
  e.color = e.face(c).color!;
}

void main() {
  test('Kartensätze haben die richtige Größe', () {
    final rng = Random(1);
    expect(deckFor(EinsMode.classic, rng).length, 108);
    expect(deckFor(EinsMode.flip, rng).length, 112);
    expect(deckFor(EinsMode.noMercy, rng).length, 168);
    expect(deckFor(EinsMode.extreme, rng).length, 112);
    expect(deckFor(EinsMode.spin, rng).length, 112);
    expect(deckFor(EinsMode.flex, rng).length, 104);
    final flip = deckFor(EinsMode.flip, rng);
    expect(flip.every((c) => c.dark != null), isTrue);
    expect(flip.where((c) => c.light.kind == EinsKind.flip).length, 8);
    expect(flip.where((c) => c.dark!.kind == EinsKind.flip).length, 8);
    expect(flip.where((c) => c.dark!.color != null).every((c) => darkColors.contains(c.dark!.color)), isTrue);
  });

  test('Klassisch: Passt nach Farbe, Zahl, Symbol, Farbwahl', () {
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

  test('Aussetzen und Richtungswechsel, zu zweit wie Aussetzen', () {
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
    final two = game(2);
    setTop(two, n(red, 5));
    final r2 = k(EinsKind.reverse, red);
    two.players[0].hand = [r2, n(green, 1), n(green, 2)];
    two.play(r2);
    expect(two.current, 0);
  });

  test('Stapeln: gleicher oder höherer Wert, sonst ziehen und aussetzen', () {
    final e = game(3);
    setTop(e, n(red, 5));
    final a = k(EinsKind.drawTwo, red);
    final b = k(EinsKind.drawTwo, blue);
    final four = k(EinsKind.wildDrawFour);
    e.players[0].hand = [a, n(green, 1), n(green, 2)];
    e.players[1].hand = [b, n(blue, 3), n(blue, 4)];
    e.players[2].hand = [four, n(red, 8), n(red, 9)];
    e.play(a);
    expect(e.canPlay(n(blue, 3)), isFalse);
    e.play(b);
    e.play(four, chosen: green);
    expect(e.pendingDraw, 8);
    expect(e.canPlay(k(EinsKind.drawTwo, green)), isFalse);
    e.draw();
    expect(e.players[0].hand.length, 10);
    expect(e.current, 1);
    expect(e.color, green);
    final off = game(2)..stackDraws = false;
    setTop(off, n(red, 5));
    final c = k(EinsKind.drawTwo, red);
    off.players[0].hand = [c, n(green, 1), n(green, 2)];
    off.play(c);
    expect(off.canPlay(k(EinsKind.drawTwo, blue)), isFalse);
  });

  test('Eins! vergessen kostet zwei Karten', () {
    final e = game(2);
    setTop(e, n(red, 5));
    final a = n(red, 7);
    e.players[0].hand = [a, n(green, 1)];
    e.play(a, called: false);
    expect(e.players[0].hand.length, 3);
    final e3 = game(2)..callRequired = false;
    setTop(e3, n(red, 5));
    final c = n(red, 7);
    e3.players[0].hand = [c, n(green, 1)];
    e3.play(c, called: false);
    expect(e3.players[0].hand.length, 1);
  });

  test('Kehrseite: Wenden dreht alle Karten und die Farbe', () {
    final e = game(3, mode: EinsMode.flip);
    final flipCard = EinsCard(_id++, const EinsFace(EinsKind.flip, color: EinsColor.red),
        const EinsFace(EinsKind.number, color: EinsColor.teal, number: 4));
    setTop(e, n(red, 5));
    e.players[0].hand = [flipCard, n(green, 1), n(green, 2)];
    e.play(flipCard);
    expect(e.darkSide, isTrue);
    expect(e.color, EinsColor.teal);
    expect(e.topFace.number, 4);
    final skipAll = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 1),
        const EinsFace(EinsKind.skipEveryone, color: EinsColor.teal));
    e.current = 1;
    e.players[1].hand = [skipAll, n(blue, 2), n(blue, 3)];
    e.play(skipAll);
    expect(e.current, 1, reason: 'Alle setzen aus');
  });

  test('Kehrseite: Ziehen bis zur Farbe', () {
    final e = game(2, mode: EinsMode.flip);
    e.darkSide = true;
    setTop(e, EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 1),
        const EinsFace(EinsKind.number, color: EinsColor.pink, number: 3)));
    final card = EinsCard(_id++, const EinsFace(EinsKind.wild), const EinsFace(EinsKind.wildDrawColor));
    e.players[0].hand = [card, n(green, 1), n(green, 2)];
    e.play(card, chosen: EinsColor.orange);
    expect(e.forcedColorDraw, EinsColor.orange);
    expect(e.canPlay(e.players[1].hand.first), isFalse);
    e.draw();
    expect(e.face(e.players[1].hand.last).color == EinsColor.orange || e.drawPile.isEmpty, isTrue);
    expect(e.current, 0);
  });

  test('Gnadenlos: Sieben tauscht, Null gibt weiter, ab 25 Karten raus', () {
    final e = game(3, mode: EinsMode.noMercy);
    setTop(e, n(red, 5));
    final seven = n(red, 7);
    e.players[0].hand = [seven, n(green, 1), n(green, 2), n(green, 3)];
    e.players[2].hand = [n(blue, 9)];
    e.play(seven, target: 2);
    expect(e.players[0].hand.length, 1);
    expect(e.players[2].hand.length, 3);
    final zero = n(red, 0);
    e.current = 1;
    final before = [for (final p in e.players) p.hand.length];
    e.players[1].hand.add(zero);
    e.color = red;
    setTop(e, n(red, 4));
    final p1Hand = e.players[1].hand.where((c) => c != zero).toList();
    e.play(zero);
    expect(e.players[2].hand.toSet(), p1Hand.toSet());
    expect(before.length, 3);
    final m = game(2, mode: EinsMode.noMercy);
    setTop(m, n(red, 5));
    final ten = k(EinsKind.wildDrawTen);
    m.players[0].hand = [ten, n(blue, 1)];
    m.players[1].hand = [for (var i = 0; i < 16; i++) n(blue, 2)];
    m.play(ten, chosen: red);
    m.draw();
    expect(m.out[1], isTrue);
    expect(m.winner, m.players[0]);
  });

  test('Gnadenlos: Stapeln nur mit gleichem oder höherem Wert', () {
    final e = game(3, mode: EinsMode.noMercy);
    setTop(e, n(red, 5));
    final four = k(EinsKind.drawFour, red);
    e.players[0].hand = [four, n(green, 1), n(green, 2)];
    e.play(four);
    expect(e.canPlay(k(EinsKind.drawTwo, red)), isFalse);
    expect(e.canPlay(k(EinsKind.wildDrawSix)), isTrue);
    expect(e.canPlay(k(EinsKind.wildReverseDrawFour)), isTrue);
  });

  test('Kartenwerfer: Drücken beendet den Zug', () {
    final e = game(3, mode: EinsMode.extreme);
    final before = e.players[0].hand.length;
    e.draw();
    expect(e.current, 1);
    expect(e.players[0].hand.length, before + e.lastLaunch!);
  });

  test('Glücksrad: Drehkarte lässt den Nächsten drehen, alle Felder funktionieren', () {
    for (final space in SpinSpace.values) {
      final e = game(3, mode: EinsMode.spin);
      setTop(e, n(red, 5));
      final spinCard = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 3, spin: true));
      e.players[0].hand = [spinCard, n(green, 1), n(green, 2)];
      e.play(spinCard);
      expect(e.current, 1);
      expect(e.mustSpin, isTrue);
      expect(e.canPlay(e.players[1].hand.first), isFalse);
      final total = e.cardCount;
      e.spin(forced: space);
      if (e.raceOpen) e.resolveRace(2);
      expect(e.cardCount, total, reason: '$space');
      expect(e.mustSpin, isFalse);
    }
  });

  test('Kraftkarten: Kraft nutzen schaltet sie aus, alle aus macht alle an', () {
    final e = game(3, mode: EinsMode.flex);
    setTop(e, n(red, 5));
    final fs = k(EinsKind.flexSkip, red);
    e.players[0].hand = [fs, n(green, 1), n(green, 2)];
    e.play(fs, flex: true);
    expect(e.current, 0, reason: 'Kraft: alle setzen aus');
    expect(e.power[0], isFalse);
    final fs2 = k(EinsKind.flexSkip, red);
    e.players[0].hand.add(fs2);
    e.play(fs2, flex: true);
    expect(e.current, 2, reason: 'Ohne Kraft normales Aussetzen');
    final marked = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 2, flipMark: true));
    e.current = 0;
    e.players[0].hand.add(marked);
    e.play(marked);
    expect(e.power[0], isTrue);
  });

  for (final mode in EinsMode.values) {
    test('${modeName(mode)}: Computer-Partien enden und verlieren keine Karte', () {
      final rng = Random(8 + mode.index);
      for (var g = 0; g < 120; g++) {
        final e = EinsEngine(
          players: [for (var i = 0; i < 2 + g % 3; i++) EinsPlayer('P$i')],
          mode: mode,
          rng: rng,
          stackDraws: g.isEven,
          callRequired: g % 3 != 0,
        )..start(startPlayer: g % 2);
        final total = e.cardCount;
        var turns = 0;
        while (!e.finished) {
          einsBotTurn(e, rng);
          turns++;
          expect(e.cardCount, total);
          expect(turns, lessThan(4000), reason: 'Partie endet nicht');
        }
      }
    });
  }
}
