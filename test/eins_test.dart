import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';

var _id = 1000;
EinsCard n(EinsColor c, int number) => EinsCard.simple(_id++, EinsKind.number, color: c, number: number);
EinsCard k(EinsKind kind, [EinsColor? c]) => EinsCard.simple(_id++, kind, color: c);
EinsCard two(EinsFace light, EinsFace dark) => EinsCard(_id++, light, dark);
const red = EinsColor.red;
const blue = EinsColor.blue;
const green = EinsColor.green;
const yellow = EinsColor.yellow;

EinsEngine game(int players, {EinsMode mode = EinsMode.classic, bool challenge = false, bool expansion = false}) =>
    EinsEngine(
      players: [for (var i = 0; i < players; i++) EinsPlayer('P$i', human: i == 0)],
      mode: mode,
      rng: Random(1),
      challengeRule: challenge,
      expansion: expansion,
    )..start();

void setTop(EinsEngine e, EinsCard c) {
  e.discard = [c];
  e.color = e.face(c).color!;
}

void main() {
  test('Kartensätze wie im Original', () {
    final rng = Random(1);
    expect(deckFor(EinsMode.classic, rng).length, 108);
    expect(deckFor(EinsMode.flip, rng).length, 112);
    expect(deckFor(EinsMode.noMercy, rng).length, 168);
    expect(deckFor(EinsMode.noMercy, rng, expansion: true).length, 192);
    expect(deckFor(EinsMode.extreme, rng).length, 112);
    expect(deckFor(EinsMode.spin, rng).length, 108);
    expect(deckFor(EinsMode.spinNew, rng).length, 112);
    expect(deckFor(EinsMode.flex, rng).length, 104);

    final spin = deckFor(EinsMode.spin, rng);
    expect(spin.where((c) => c.light.spin).length, 20);
    final spinNew = deckFor(EinsMode.spinNew, rng);
    expect(spinNew.where((c) => c.light.spin).length, 24);
    final flex = deckFor(EinsMode.flex, rng);
    expect(flex.where((c) => c.light.flexColor != null).length, 32);
    expect(flex.where((c) => c.light.flipMark).length, 16);
    expect(flexColorFor(yellow, 2), green);
    expect(flexColorFor(red, 8), yellow);
    final mercy = deckFor(EinsMode.noMercy, rng);
    expect(mercy.where((c) => c.light.kind == EinsKind.wildColorRoulette).length, 8);
    expect(mercy.where((c) => c.light.kind == EinsKind.wildReverseDrawFour).length, 8);
    final flip = deckFor(EinsMode.flip, rng);
    expect(flip.every((c) => c.dark != null), isTrue);
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
    final t = game(2);
    setTop(t, n(red, 5));
    final r2 = k(EinsKind.reverse, red);
    t.players[0].hand = [r2, n(green, 1), n(green, 2)];
    t.play(r2);
    expect(t.current, 0);
  });

  test('Stapeln: gleicher oder höherer Wert', () {
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
  });

  test('Eins! vergessen kostet zwei Karten', () {
    final e = game(2);
    setTop(e, n(red, 5));
    final a = n(red, 7);
    e.players[0].hand = [a, n(green, 1)];
    e.play(a, called: false);
    expect(e.players[0].hand.length, 3);
  });

  test('Anzweifeln: zu Recht trifft den Leger, zu Unrecht den Zweifler', () {
    final e = game(3, challenge: true);
    setTop(e, n(red, 5));
    final four = k(EinsKind.wildDrawFour);
    e.players[0].hand = [four, n(red, 1), n(blue, 2)];
    e.play(four, chosen: blue);
    expect(e.canChallenge, isTrue);
    e.challenge();
    expect(e.players[0].hand.length, 6, reason: 'Hatte Rot, zieht selbst vier');
    expect(e.current, 1, reason: 'Der Zweifler ist normal dran');
    expect(e.pendingDraw, 0);

    final f = game(3, challenge: true);
    setTop(f, n(red, 5));
    final four2 = k(EinsKind.wildDrawFour);
    f.players[0].hand = [four2, n(green, 1), n(blue, 2)];
    final before = f.players[1].hand.length;
    f.play(four2, chosen: blue);
    f.challenge();
    expect(f.players[1].hand.length, before + 6);
    expect(f.current, 2);
  });

  test('Kehrseite: Wenden dreht Ablage und Stapel um', () {
    final e = game(3, mode: EinsMode.flip);
    final bottom = two(
      const EinsFace(EinsKind.number, color: red, number: 5),
      const EinsFace(EinsKind.number, color: EinsColor.teal, number: 4),
    );
    setTop(e, bottom);
    final flipCard = two(
      const EinsFace(EinsKind.flip, color: red),
      const EinsFace(EinsKind.number, color: EinsColor.pink, number: 2),
    );
    expect(e.flipNewTop!.number, 4);
    e.players[0].hand = [flipCard, n(green, 1), n(green, 2)];
    e.play(flipCard);
    expect(e.darkSide, isTrue);
    expect(e.top, bottom, reason: 'Die unterste Karte liegt jetzt oben');
    expect(e.color, EinsColor.teal);
    final skipAll = two(
      const EinsFace(EinsKind.number, color: red, number: 1),
      const EinsFace(EinsKind.skipEveryone, color: EinsColor.teal),
    );
    e.current = 1;
    e.players[1].hand = [skipAll, n(blue, 2), n(blue, 3)];
    e.play(skipAll);
    expect(e.current, 1, reason: 'Alle setzen aus');
  });

  test('Kehrseite: Ziehen bis zur Farbe, Farbwahl zählt nicht', () {
    final e = game(2, mode: EinsMode.flip);
    e.darkSide = true;
    setTop(
        e,
        two(const EinsFace(EinsKind.number, color: red, number: 1),
            const EinsFace(EinsKind.number, color: EinsColor.pink, number: 3)));
    final card = two(const EinsFace(EinsKind.wild), const EinsFace(EinsKind.wildDrawColor));
    e.players[0].hand = [card, n(green, 1), n(green, 2)];
    e.play(card, chosen: EinsColor.orange);
    expect(e.forcedColorDraw, EinsColor.orange);
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
    e.players[1].hand.add(zero);
    setTop(e, n(red, 4));
    final p1Hand = e.players[1].hand.where((c) => c != zero).toList();
    e.play(zero);
    expect(e.players[2].hand.toSet(), p1Hand.toSet());

    final m = game(2, mode: EinsMode.noMercy);
    setTop(m, n(red, 5));
    final ten = k(EinsKind.wildDrawTen);
    m.players[0].hand = [ten, n(blue, 1)];
    m.players[1].hand = [for (var i = 0; i < 16; i++) n(blue, 2)];
    final total = m.cardCount;
    m.play(ten, chosen: red);
    m.draw();
    expect(m.out[1], isTrue);
    expect(m.setAside.length, 26);
    expect(m.cardCount, total);
    expect(m.winner, m.players[0]);
  });

  test('Gnadenlos: Richtungswechsel plus vier zu zweit trifft den Leger', () {
    final e = game(2, mode: EinsMode.noMercy);
    setTop(e, n(red, 5));
    final card = k(EinsKind.wildReverseDrawFour);
    e.players[0].hand = [card, n(blue, 1), n(blue, 2)];
    e.play(card, chosen: blue);
    expect(e.current, 0);
    expect(e.pendingDraw, 4);
    expect(e.canPlay(k(EinsKind.drawTwo, blue)), isFalse);
    expect(e.canPlay(k(EinsKind.wildDrawSix)), isTrue);
  });

  test('Gnadenlos: Farbroulette setzt die angesagte Farbe', () {
    final e = game(3, mode: EinsMode.noMercy);
    setTop(e, n(red, 5));
    final card = k(EinsKind.wildColorRoulette);
    e.players[0].hand = [card, n(blue, 1), n(blue, 2)];
    e.play(card, chosen: blue);
    expect(e.mustChooseRoulette, isTrue);
    e.resolveRoulette(green);
    expect(e.color, green);
    expect(e.current, 2);
  });

  test('Gnadenlos-Erweiterung: Münzen', () {
    final e = EinsEngine(
      players: [EinsPlayer('Du', human: true), EinsPlayer('B')],
      mode: EinsMode.noMercy,
      rng: Random(2),
      expansion: true,
    )..start(coinChoice: [EinsCoin.noMercy, EinsCoin.mercy]);
    setTop(e, n(red, 5));
    final two = k(EinsKind.drawTwo, red);
    e.players[0].hand = [two, n(blue, 1), n(blue, 2)];
    e.play(two, coin: true);
    expect(e.pendingDraw, 4);
    expect(e.coins[0], isNull);
    e.players[1].hand = [for (var i = 0; i < 22; i++) n(blue, 3)];
    final total = e.cardCount;
    e.draw();
    expect(e.out[1], isFalse, reason: 'Die Gnade-Münze rettet');
    expect(e.players[1].hand.length, 7);
    expect(e.coins[1], isNull);
    expect(e.cardCount, total);
  });

  test('Kartenwerfer: Drücken beendet den Zug, Extrem-Treffer trifft das Ziel', () {
    final e = game(3, mode: EinsMode.extreme);
    final before = e.players[0].hand.length;
    e.draw();
    expect(e.current, 1);
    expect(e.players[0].hand.length, before + e.lastLaunch!);
    final f = game(3, mode: EinsMode.extreme);
    setTop(f, n(red, 5));
    final hit = k(EinsKind.extremeHit);
    f.players[0].hand = [hit, n(blue, 1), n(blue, 2)];
    final total = f.cardCount;
    f.play(hit, target: 2, chosen: blue);
    expect(f.current, 1);
    expect(f.cardCount, total);
  });

  test('Glücksrad 2005: Der Nächste dreht, alle Felder', () {
    for (final space in wheel2005) {
      final e = game(3, mode: EinsMode.spin);
      setTop(e, n(red, 5));
      final spinCard = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 3, spin: true));
      e.players[0].hand = [spinCard, n(green, 1), n(green, 2)];
      e.play(spinCard);
      expect(e.current, 1);
      expect(e.mustSpin, isTrue);
      final total = e.cardCount;
      e.spin(forced: space);
      if (e.raceOpen) e.resolveRace(2);
      expect(e.cardCount, total, reason: '$space');
      expect(e.mustSpin, isFalse);
    }
  });

  test('Glücksrad 2005: Abgeworfene Karte liegt oben', () {
    final e = game(2, mode: EinsMode.spin);
    setTop(e, n(red, 5));
    final spinCard = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 3, spin: true));
    e.players[0].hand = [spinCard, n(green, 1), n(green, 2)];
    e.play(spinCard);
    final blue7 = n(blue, 7);
    e.players[1].hand = [n(yellow, 7), blue7, n(green, 2)];
    e.spin(forced: SpinSpace.discardNumber, choice: SpinChoice(number: 7, topId: blue7.id));
    expect(e.top, blue7);
    expect(e.color, blue);
    expect(e.players[1].hand.length, 1);
  });

  test('Glücksrad neu: Selbst drehen und zwei Karten', () {
    for (final space in wheel2025) {
      final e = game(3, mode: EinsMode.spinNew);
      setTop(e, n(red, 5));
      final spinCard = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 3, spin: true));
      e.players[0].hand = [spinCard, n(green, 1), n(green, 2)];
      e.play(spinCard);
      expect(e.current, 0);
      expect(e.mustSpin, isTrue);
      final total = e.cardCount;
      e.spin(forced: space);
      expect(e.cardCount, total, reason: '$space');
    }
    final e = game(2, mode: EinsMode.spinNew);
    setTop(e, n(red, 5));
    e.doublePlay = true;
    final a = n(red, 2);
    final b = n(red, 3);
    e.players[0].hand = [a, b, n(green, 1)];
    e.play(a);
    expect(e.extraPlay, isTrue);
    expect(e.current, 0);
    e.play(b);
    expect(e.current, 1);
  });

  test('Kraftkarten: zweite Farbe, Kraftseite und Kraftwechsel', () {
    final e = game(3, mode: EinsMode.flex);
    setTop(e, n(green, 9));
    final flexCard = EinsCard(_id++, EinsFace(EinsKind.number, color: yellow, number: 2, flexColor: flexColorFor(yellow, 2)));
    expect(e.canPlayNormal(flexCard), isFalse);
    expect(e.canPlayFlex(flexCard), isTrue);
    e.players[0].hand = [flexCard, n(blue, 1), n(blue, 2)];
    e.play(flexCard);
    expect(e.color, yellow, reason: 'Weiter geht es mit der Grundfarbe');
    expect(e.power[0], isFalse);

    final f = game(3, mode: EinsMode.flex);
    setTop(f, n(red, 5));
    final fs = k(EinsKind.flexSkip, red);
    f.players[0].hand = [fs, n(green, 1), n(green, 2)];
    f.play(fs, flex: true);
    expect(f.current, 0, reason: 'Kraft: alle setzen aus');
    expect(f.power[0], isFalse);
    final marked = EinsCard(_id++, const EinsFace(EinsKind.number, color: red, number: 2, flipMark: true));
    f.players[0].hand.add(marked);
    f.play(marked);
    expect(f.power[0], isTrue);
  });

  for (final mode in EinsMode.values) {
    for (final expansion in mode == EinsMode.noMercy ? [false, true] : [false]) {
      test('${modeName(mode)}${expansion ? ' mit Erweiterung' : ''}: Computer-Partien enden ohne Kartenverlust', () {
        final rng = Random(8 + mode.index);
        for (var g = 0; g < 100; g++) {
          final e = EinsEngine(
            players: [for (var i = 0; i < 2 + g % 3; i++) EinsPlayer('P$i')],
            mode: mode,
            rng: rng,
            stackDraws: g.isEven,
            callRequired: g % 3 != 0,
            challengeRule: g % 4 != 1,
            expansion: expansion,
          )..start(startPlayer: g % 2);
          final total = e.cardCount;
          var turns = 0;
          while (!e.finished) {
            einsBotTurn(e, rng);
            turns++;
            expect(e.cardCount, total);
            expect(turns, lessThan(5000), reason: 'Partie endet nicht');
          }
        }
      });
    }
  }

  test('Mehrere Menschen: Meldungen nennen Namen statt „Du“', () {
    for (final humans in [1, 2]) {
      final e = EinsEngine(
        players: [for (var i = 0; i < 3; i++) EinsPlayer('P$i', human: i < humans)],
        mode: EinsMode.noMercy,
        rng: Random(1),
        challengeRule: false,
      )..start();
      setTop(e, n(red, 5));
      final seven = n(red, 7);
      e.players[0].hand = [seven, n(blue, 3), n(green, 4)];
      e.play(seven, target: 1);
      expect(e.lastEvent, humans == 1 ? 'Du tauschst die Hand mit P1' : 'P0 tauscht die Hand mit P1');
    }
  });
}
