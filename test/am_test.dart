import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/american/am_card.dart';
import 'package:gluckspfennig/games/mahjong/american/am_engine.dart';
import 'package:gluckspfennig/games/mahjong/tiles.dart';

int total(AmGame g) {
  var n = g.wall.length;
  for (final p in g.players) {
    n += p.hand.length + p.discards.length;
    for (final e in p.exposed) {
      n += e.count;
    }
  }
  return n;
}

void main() {
  test('Karte hat viele Varianten', () {
    expect(amConcretes.length, greaterThan(100));
    for (final h in amCard) {
      expect(h.specs.fold(0, (a, s) => a + s.count), 14, reason: h.label);
    }
  });

  test('Gerade Zahlen in einer Farbe werden erkannt', () {
    // 222 4444 666 8888 Kreise
    final hand = [10, 10, 10, 12, 12, 12, 12, 14, 14, 14, 16, 16, 16, 16];
    final c = amWinning(hand, const []);
    expect(c, isNotNull);
    expect(c!.hand.category, '2468');
  });

  test('Joker füllen einen Pung, aber kein Paar', () {
    final hand = [10, 10, jokerKind, 12, 12, 12, 12, 14, 14, 14, 16, 16, 16, 16];
    expect(amWinning(hand, const []), isNotNull);
    // Paare-Hand mit Joker geht nicht
    final pairs = [firstFlower, firstFlower + 1, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, jokerKind];
    expect(amWinning(pairs, const []), isNull);
    final pairsOk = [firstFlower, firstFlower + 1, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5];
    expect(amWinning(pairsOk, const [])?.hand.category, 'Paare');
  });

  test('Aufgedeckte Gruppe muss zur Kartenhand passen', () {
    final hand = [12, 12, 12, 12, 14, 14, 14, 16, 16, 16, 16];
    final ok = amWinning(hand, [AmExposure(10, 3, 0)]);
    expect(ok, isNotNull);
    final bad = amWinning(hand, [AmExposure(11, 3, 0)]);
    expect(bad, isNull);
  });

  test('Ganze Spiele laufen durch', () {
    for (var seed = 0; seed < 4; seed++) {
      final rng = Random(seed);
      final g = AmGame(rng: Random(seed + 7))..start();
      var steps = 0;
      var wins = 0;
      while (g.phase != AmPhase.gameOver && steps < 20000) {
        switch (g.phase) {
          case AmPhase.charleston:
            g.submitPass(0, g.botPass(0));
          case AmPhase.discard:
            final p = g.current;
            switch (amBotTurn(g, p, rng)) {
              case AmBotMahjong():
                g.mahjong(p);
              case AmBotSwap(:final owner, :final index):
                g.swapJoker(p, owner, index);
              case AmBotDiscard(:final tile):
                g.discard(p, tile);
            }
          case AmPhase.claim:
            g.resolveClaims({for (final e in g.claims.entries) e.key: amBotClaim(g, e.key, e.value)});
          case AmPhase.handOver:
            if (g.result?.winner != null) wins++;
            g.nextHand();
          case AmPhase.gameOver:
            break;
        }
        if (g.phase != AmPhase.handOver && g.phase != AmPhase.gameOver) {
          expect(total(g), 152, reason: 'Schritt $steps');
        }
        steps++;
      }
      expect(g.phase, AmPhase.gameOver);
      expect(g.players.fold(0, (a, p) => a + p.points), 4000);
      // ignore: avoid_print
      print('Amerikanisch seed $seed: $wins Siege, ${g.players.map((p) => p.points).join('/')}');
    }
  });
}
