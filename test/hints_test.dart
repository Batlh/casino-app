import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/cards/rewards.dart';
import 'package:gluckspfennig/games/solitaire/hints.dart';
import 'package:gluckspfennig/games/solitaire/klondike_engine.dart';
import 'package:gluckspfennig/games/solitaire/spider_engine.dart';
import 'package:gluckspfennig/games/solitaire/table_card.dart';

/// Spielt nur nach Tipps, bis keiner mehr kommt oder das Spiel gewonnen ist.
int playKlondike(KlondikeEngine e, {int limit = 3000}) {
  var steps = 0;
  var draws = 0;
  while (!e.isWon && steps < limit) {
    if (e.canAutoFinish) {
      while (e.autoFinishStep()) {}
      break;
    }
    final h = klondikeHint(e);
    if (h == null) break;
    if (h.draw) {
      // Einmal komplett durch den Stapel ohne Zug: festgefahren
      if (++draws > e.stock.length + e.waste.length + 2) break;
      e.draw();
    } else {
      draws = 0;
      expect(e.move(h.from!, h.index, h.to!), isTrue, reason: 'Tipp muss ein gültiger Zug sein');
    }
    steps++;
    expect(e.cardCount, 52);
  }
  return steps;
}

void main() {
  test('Patience: Tipps sind gültig und gewinnen einen Teil der Spiele', () {
    var won = 0;
    for (var g = 0; g < 200; g++) {
      final e = KlondikeEngine(rng: Random(g));
      expect(klondikeHint(e), isNotNull);
      final steps = playKlondike(e);
      expect(steps, lessThan(3000), reason: 'Tipps dürfen nicht im Kreis laufen');
      if (e.isWon) won++;
    }
    // ignore: avoid_print
    print('Patience nach Tipps gewonnen: $won von 200');
    expect(won, greaterThan(3));
  });

  test('Patience: Karte auf die Ablage hat Vorrang', () {
    final e = KlondikeEngine(rng: Random(3));
    e.tableau[0] = [TableCard(const PlayingCard(14, Suit.hearts), up: true)];
    final h = klondikeHint(e)!;
    expect(h.to!.kind, PileKind.foundation);
    expect(describeHint(h, e.pile), endsWith('Ass nach oben auf die Ablage'));
  });

  test('Spider: Tipps sind gültig und laufen nicht im Kreis', () {
    for (final suits in [1, 2, 4]) {
      var won = 0;
      for (var g = 0; g < 60; g++) {
        final e = SpiderEngine(suits: suits, rng: Random(g));
        var steps = 0;
        while (!e.isWon && steps < 4000) {
          final h = spiderHint(e);
          if (h == null) break;
          if (h.draw) {
            e.deal();
          } else {
            expect(e.move(h.from!.index, h.index, h.to!.index), isTrue);
          }
          steps++;
          expect(e.cardCount, 104);
        }
        expect(steps, lessThan(4000), reason: 'Tipps dürfen nicht im Kreis laufen');
        if (e.isWon) won++;
      }
      // ignore: avoid_print
      print('Spider $suits Farben nach Tipps gewonnen: $won von 60');
    }
  });

  test('Tipps kosten ein Zehntel der Siegprämie', () {
    expect(hintCost(200), 20);
    expect(hintCost(1000), 100);
  });

  test('Trostpreis je geschlagenem Gegner', () {
    expect(beatenCount([3, 0, 5, 7], 0), 2);
    expect(beatenCount([3, 3, 1], 0), 0);
    expect(placeReward(2), 50);
    expect(placeReward(1, factor: 1.5), 38);
  });

  test('Verloren: Spider ohne Züge und ohne Stapel', () {
    final e = SpiderEngine(rng: Random(1));
    TableCard c(int r, [Suit s = Suit.spades]) => TableCard(PlayingCard(r == 1 ? 14 : r, s), up: true);
    e.stock.clear();
    for (var t = 0; t < 10; t++) {
      e.tableau[t] = [c(13), c(t % 2 == 0 ? 3 : 7, Suit.hearts)];
    }
    expect(spiderStuck(e), isTrue);
    e.tableau[0].add(c(6));
    expect(spiderStuck(e), isFalse, reason: 'Pik 6 passt auf Herz 7');
    expect(spiderStuck(SpiderEngine(rng: Random(2))), isFalse);
  });

  test('Verloren: Patience ohne Züge, frisches Spiel nie', () {
    for (var g = 0; g < 50; g++) {
      expect(klondikeStuck(KlondikeEngine(rng: Random(g))), isFalse);
    }
    final e = KlondikeEngine(rng: Random(1));
    e.stock.clear();
    e.waste.clear();
    TableCard c(int r, Suit s, {bool up = true}) => TableCard(PlayingCard(r == 1 ? 14 : r, s), up: up);
    e.tableau = [
      [c(5, Suit.spades, up: false), c(9, Suit.hearts)],
      [c(4, Suit.clubs)],
      [c(9, Suit.diamonds)],
      [c(12, Suit.hearts)],
      [c(7, Suit.hearts)],
      [c(3, Suit.spades)],
      [c(11, Suit.hearts)],
    ];
    expect(klondikeStuck(e), isTrue);
    e.waste.add(c(10, Suit.clubs));
    expect(klondikeStuck(e), isFalse, reason: 'Kreuz 10 passt auf Herz Bube');
  });

  test('Verloren wird nie gemeldet, solange ein Tipp einen Zug kennt', () {
    for (var g = 0; g < 100; g++) {
      final e = KlondikeEngine(rng: Random(g), drawCount: g.isEven ? 1 : 3);
      playKlondike(e);
      if (klondikeStuck(e)) expect(klondikeHint(e, allowDraw: false), isNull);
    }
  });
}
