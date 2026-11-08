import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/riichi_bot.dart';
import 'package:gluckspfennig/games/mahjong/riichi_engine.dart';
import 'package:gluckspfennig/games/mahjong/riichi_hand.dart';
import 'package:gluckspfennig/games/mahjong/solitaire_engine.dart';

List<int> h(String s) {
  // Kurzschreibweise wie 123m456p789s11z: m Zeichen, p Kreise, s Bambus, z Ehren (1 bis 7)
  final out = <int>[];
  var digits = <int>[];
  for (final ch in s.split('')) {
    if (RegExp(r'\d').hasMatch(ch)) {
      digits.add(int.parse(ch));
      continue;
    }
    final base = {'m': 0, 'p': 9, 's': 18, 'z': 27}[ch]!;
    out.addAll(digits.map((d) => base + d - 1));
    digits = [];
  }
  return out;
}

void main() {
  test('Mahjong Solitär: Schildkröte mit 144 Steinen, lösbar ausgeteilt', () {
    expect(turtleLayout().length, 144);
    for (var seed = 0; seed < 20; seed++) {
      final g = MahjongSolitaire(rng: Random(seed));
      expect(g.tiles.where((t) => t >= 34).length, 8);
      // Gierig abräumen geht nicht immer, aber Paare müssen am Anfang frei sein
      expect(g.freePairs(), isNotEmpty);
    }
  });

  test('Mahjong Solitär: Mischen hält das Spiel lösbar', () {
    final g = MahjongSolitaire(rng: Random(4));
    var steps = 0;
    while (!g.won && steps < 200) {
      final pairs = g.freePairs();
      if (pairs.isEmpty) {
        g.shuffle();
        continue;
      }
      expect(g.remove(pairs.first.$1, pairs.first.$2), isTrue);
      steps++;
    }
    expect(g.won, isTrue);
  });

  test('Shanten und Wartesteine', () {
    expect(shanten(countsOf(h('123m456p789s11z222z')), 0), -1);
    expect(shanten(countsOf(h('123m456p789s1z222z')), 0), 0);
    expect(waitsOf(countsOf(h('123m456p789s1z222z')), 0), [27]);
    expect(waitsOf(countsOf(h('23m456p789s11z222z')), 0)..sort(), [0, 3]);
    expect(shanten(countsOf(h('1133557799m11p2s')), 0), 0, reason: 'Sieben Paare fast fertig');
    expect(shanten(countsOf(h('19m19p19s1234567z')), 0), 0, reason: 'Dreizehn Waisen wartet auf 13 Seiten');
  });

  test('Wertung: Riichi, Pinfu, Tanyao, Dora', () {
    final hand = h('234m345p456s66m78p');
    final closed = [...hand, 14]; // 6 Kreise macht 678p
    final s = scoreHand(
      closed,
      [],
      const WinContext(winTile: 14, tsumo: false, seatWind: 28, roundWind: 27, riichi: true),
    )!;
    final names = s.yaku.map((y) => y.name).join(',');
    expect(names, contains('Riichi'));
    expect(names, contains('Pinfu'));
    expect(names, contains('Tanyao'));
    expect(s.fu, 30);
    expect(s.han, 3);
  });

  test('Wertung: offene Hand ohne Yaku gewinnt nicht', () {
    final closed = h('123m456p78s11z');
    final s = scoreHand(
      [...closed, 26],
      [Meld(MeldKind.pon, h('999m'))],
      const WinContext(winTile: 26, tsumo: false, seatWind: 28, roundWind: 27),
    );
    expect(s, isNull);
  });

  test('Wertung: Drachen-Pon ist Yakuhai, Yakuman werden erkannt', () {
    final s = scoreHand(
      [...h('123m456p11s'), ...h('78s'), 26],
      [Meld(MeldKind.pon, h('555z'))],
      const WinContext(winTile: 26, tsumo: false, seatWind: 28, roundWind: 27),
    )!;
    expect(s.yaku.any((y) => y.name.startsWith('Drache')), isTrue);
    final k = scoreHand(
      h('19m19p19s12345677z'),
      [],
      const WinContext(winTile: 33, tsumo: true, seatWind: 27, roundWind: 27),
    )!;
    expect(k.yakuman, greaterThanOrEqualTo(1));
    expect(k.basePoints, greaterThanOrEqualTo(8000));
  });

  test('Punkte: 1 Han 30 Fu Ron ist 1.000, Mangan 8.000', () {
    expect(roundUp100(HandScore(const [Yaku('x', 1)], 1, 30, 0).basePoints * 4), 1000);
    expect(roundUp100(HandScore(const [Yaku('x', 5)], 5, 30, 0).basePoints * 4), 8000);
    expect(roundUp100(HandScore(const [Yaku('x', 3)], 3, 30, 0).basePoints * 4), 3900);
  });

  test('Ganze Ostrunden mit vier Computern laufen durch, Punkte bleiben erhalten', () {
    for (var seed = 0; seed < 6; seed++) {
      final rng = Random(seed);
      final g = RiichiGame(rng: rng)..start();
      var steps = 0;
      while (g.phase != RPhase.gameOver && steps < 20000) {
        steps++;
        switch (g.phase) {
          case RPhase.discard:
            final p = g.current;
            switch (botTurn(g, p, rng)) {
              case BotTsumo():
                g.tsumo(p);
              case BotKan(:final tile):
                g.kan(p, tile);
              case BotDiscard(:final tile, :final riichi):
                g.discard(p, tile, riichi: riichi);
            }
          case RPhase.claim:
            g.resolveClaims({for (final e in g.claims.entries) e.key: botClaim(g, e.key, e.value)});
          case RPhase.handOver:
            final total = g.players.fold<int>(0, (s, p) => s + p.points) + g.riichiSticks * 1000;
            expect(total, 100000);
            g.nextHand();
          case RPhase.gameOver:
            break;
        }
        for (final p in g.players) {
          expect(p.hand.length + p.melds.length * 3, inInclusiveRange(13, 14));
        }
      }
      expect(g.phase, RPhase.gameOver, reason: 'Seed $seed');
      expect(g.handsPlayed, greaterThanOrEqualTo(4));
    }
  });
}
