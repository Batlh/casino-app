import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_bot.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_hand.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_scoring.dart' show vietBonusPhan;
import 'package:gluckspfennig/games/mahjong/classic/mj_shape.dart';
import 'package:gluckspfennig/games/mahjong/riichi_hand.dart';
import 'package:gluckspfennig/games/mahjong/tiles.dart';

/// Kurzschrift wie im Riichi-Test: 123m 456p 789s 1234z (z = Ehrensteine 1 bis 7).
List<int> h(String s) {
  final out = <int>[];
  final digits = <int>[];
  for (final ch in s.split('')) {
    if (ch == ' ') continue;
    final d = int.tryParse(ch);
    if (d != null) {
      digits.add(d);
      continue;
    }
    final base = switch (ch) { 'm' => 0, 'p' => 9, 's' => 18, 'z' => 27, 'j' => -1, _ => throw ch };
    for (final d in digits) {
      out.add(base < 0 ? jokerTile : base + d - 1);
    }
    digits.clear();
  }
  return out;
}

MjScore? score(MjVariant v, String closed, int win, {bool tsumo = false, List<Meld> melds = const [], List<int> bonus = const []}) {
  final r = mjRules[v]!;
  return r.evaluate(
    h(closed),
    melds,
    WinInfo(winTile: win, tsumo: tsumo, seatWind: 27, roundWind: 27, seat: 0, bonus: bonus),
  );
}

int total(MjGame g) {
  var n = g.wall.length;
  for (final p in g.players) {
    n += p.hand.length + p.bonus.length + p.wonTiles.length - p.sharedWins;
    n += p.discards.where((d) => !d.called).length;
    for (final m in p.melds) {
      n += m.tiles.length;
    }
  }
  return n;
}

void step(MjGame g, Random rng) {
  switch (g.phase) {
    case MjPhase.exchange:
      g.submitExchange(0, g.botExchange(0));
    case MjPhase.voidChoice:
      g.chooseVoid(0, g.botVoid(0));
    case MjPhase.discard:
      final p = g.current;
      switch (mjBotTurn(g, p, rng)) {
        case MjBotWin():
          g.tsumo(p);
        case MjBotKan(:final tile):
          g.kan(p, tile);
        case MjBotDiscard(:final tile):
          g.discard(p, tile);
      }
    case MjPhase.claim:
      g.resolveClaims({for (final e in g.claims.entries) e.key: mjBotClaim(g, e.key, e.value)});
    case MjPhase.handOver:
      g.nextHand();
    case MjPhase.gameOver:
      break;
  }
}

void main() {
  group('Hand mit Jokern', () {
    test('Fertige Hand ohne Joker', () {
      final c = countsPlain(h('123m456p789s11122z'));
      expect(isCompleteJ(c, 0, 4, 0), isTrue);
    });
    test('Joker füllen Folge und Paar', () {
      final hand = h('12m456p789s111z5p') + [jokerTile, jokerTile];
      // 12m+J, 456p, 789s, 111z, 5p+J
      final c = countsPlain(hand);
      expect(isCompleteJ(c, 2, 4, 0), isTrue);
    });
    test('16er-Hand mit fünf Gruppen', () {
      final c = countsPlain(h('123m456m789m123p456p55s'));
      expect(isCompleteJ(c, 0, 5, 0), isTrue);
      expect(isCompleteJ(c, 0, 4, 0), isFalse);
    });
    test('Zerlegung mit Joker nennt den ersetzten Stein', () {
      final d = decompositionsJ(countsPlain(h('13m')), 1);
      expect(d, isEmpty, reason: 'Ohne Paar ist das nichts');
      final d2 = decompositionsJ(countsPlain(h('13m55p')), 1);
      expect(d2.any((e) => e.$3.contains(1)), isTrue);
    });
  });

  group('Wertungen', () {
    test('Sichuan: Sieben Paare und reine Farbe', () {
      final s = score(MjVariant.sichuanBattle, '11223344556677m', 6)!;
      expect(s.fans.map((f) => f.name), containsAll(['Sieben Paare', 'Reine Farbe']));
      expect(s.points, 4);
    });
    test('Sichuan: Drachen-Sieben-Paare', () {
      final s = score(MjVariant.sichuanBattle, '11112233445566m', 5)!;
      expect(s.fans.first.name, 'Drachen-Sieben-Paare');
    });
    test('Hongkong: nur Pungs mit Drache', () {
      final s = score(MjVariant.hongKong, '111m999p555s66677z', 32)!;
      expect(s.fans.map((f) => f.name), containsAll(['Nur Pungs']));
      expect(s.points, greaterThanOrEqualTo(4));
    });
    test('Hongkong: Dreizehn Waisen ist Limit', () {
      final s = score(MjVariant.hongKong, '19m19p19s12345677z', 33)!;
      expect(s.limit, isTrue);
    });
    test('MCR: Hühnerhand zählt 8', () {
      final s = score(MjVariant.mcr, '678s11z', 25, melds: [
        Meld(MeldKind.chi, [0, 1, 2]),
        Meld(MeldKind.chi, [13, 14, 15]),
        Meld(MeldKind.pon, [21, 21, 21]),
      ])!;
      expect(s.fans.first.name, 'Hühnerhand');
      expect(s.points, 8);
    });
    test('MCR: Reine Farbe 24', () {
      final s = score(MjVariant.mcr, '11123456789999m', 0)!;
      expect(s.fans.map((f) => f.name), contains('Neun Tore'));
    });
    test('MCR: Gleiche Folge in drei Farben', () {
      final s = score(MjVariant.mcr, '234m234p234s789s55p', 13, tsumo: true)!;
      expect(s.fans.map((f) => f.name), contains('Gleiche Folge in drei Farben'));
    });
    test('MCR: Große Ehren und Verbundene', () {
      final s = score(MjVariant.mcr, '147m25p36s1234567z', 33);
      expect(s, isNotNull);
      expect(s!.fans.first.name, 'Große Ehren und Verbundene');
    });
    test('MCR: Verbundene Straße mit Drachen-Pung', () {
      final s = score(MjVariant.mcr, '147m258p369s55511z', 0)!;
      expect(s.fans.map((f) => f.name), containsAll(['Verbundene Straße', 'Drachen-Pung']));
    });
    test('MCR: Verbundene Straße mit aufgedecktem Pung', () {
      final s = score(MjVariant.mcr, '147m258p369s11z', 27, melds: [Meld(MeldKind.pon, h('555z'))]);
      expect(s, isNotNull);
      expect(s!.fans.map((f) => f.name), contains('Verbundene Straße'));
    });
    test('MCR: Kleine Ehren mit kompletter Straße zählen beides', () {
      final s = score(MjVariant.mcr, '147m258p369s12345z', 31)!;
      expect(s.fans.map((f) => f.name), containsAll(['Kleine Ehren und Verbundene', 'Verbundene Straße']));
      expect(s.core, 24);
    });
    test('MCR: Wartung zählt nur, wenn sie die einzige war', () {
      final one = score(MjVariant.mcr, '123m456p789s123s11z', 19)!;
      expect(one.fans.map((f) => f.name), contains('Mittelwartung'));
      final two = score(MjVariant.mcr, '123m456p789s23455s', 22)!;
      expect(two.fans.map((f) => f.name), isNot(contains('Einzelwartung')));
    });
    test('MCR: Sieben Paare selbst gezogen behält „Selbst gezogen“', () {
      final s = score(MjVariant.mcr, '1133m2277p4499s11z', 27, tsumo: true)!;
      final names = s.fans.map((f) => f.name);
      expect(names, containsAll(['Sieben Paare', 'Selbst gezogen']));
      expect(names, isNot(contains('Ganz verdeckt')));
    });
    test('Korea: Bambus 1 und 9 geben zusammen 6', () {
      final s = score(MjVariant.korean, '111s999s123m456m11p', 0)!;
      final names = s.fans.map((f) => f.name);
      expect(names, contains('Bambus 1 und 9'));
      expect(s.core, greaterThanOrEqualTo(6));
    });
    test('Korea: kleine Drachen sind die halbe Grenze', () {
      final s = score(MjVariant.korean, '555z666z77z123m456m', 0)!;
      expect(s.limit, isTrue);
      expect(s.core, 20);
    });
    test('Philippinen: Todas und Escalera in Vierteln', () {
      final s = score(MjVariant.filipino, '123m456m789m123p456p55s', 4, tsumo: true)!;
      final names = s.fans.map((f) => f.name);
      expect(names, containsAll(['Todas (Sieg)', 'Escalera (1 bis 9)']));
      expect(s.points, greaterThanOrEqualTo(8));
    });
    test('Philippinen: Winde und Drachen landen bei den Blumen', () {
      final g = MjGame(mjRules[MjVariant.filipino]!, rng: Random(5))..start();
      for (final p in g.players) {
        expect(p.hand.where((t) => t >= 27), isEmpty);
      }
      expect(g.players.expand((p) => p.bonus).where((t) => t >= 27 && t < 34), isNotEmpty);
    });
    test('Taiwan: 17 Steine mit fünf Gruppen', () {
      final s = score(MjVariant.taiwan, '123m456m789m123p456p55s', 4)!;
      expect(s.fans.map((f) => f.name), contains('Verdeckte Hand'));
    });
    test('Taiwan: Sieben Paare und ein Pung', () {
      final s = score(MjVariant.taiwan, '11223344556677m999p', 17);
      expect(s, isNotNull);
    });
    test('Zung Jung: Hühnerhand 1 Punkt', () {
      final s = score(MjVariant.zungJung, '123m456p789s11z', 0, melds: [
        Meld(MeldKind.pon, h('222z')),
      ])!;
      expect(s.points, greaterThan(0));
    });
    test('Westlich: Pungs geben Grundpunkte', () {
      final s = score(MjVariant.western, '111m999p555s66677z', 32)!;
      expect(s.points, greaterThan(20));
    });
    test('Vietnam: Joker im Pung', () {
      final hand = h('11m999p555s66677z') + [firstVietJoker];
      final s = mjRules[MjVariant.vietnam]!
          .evaluate(hand, const [], const WinInfo(winTile: 32, tsumo: false, seatWind: 27, roundWind: 27, seat: 0));
      expect(s, isNotNull);
    });
  });

  group('Vietnam', () {
    MjScore? viet(List<int> tiles, int win, {List<int> bonus = const []}) => mjRules[MjVariant.vietnam]!
        .evaluate(tiles, const [], WinInfo(winTile: win, tsumo: false, seatWind: 27, roundWind: 27, seat: 0, bonus: bonus));
    test('176 Steine', () {
      expect(mjRules[MjVariant.vietnam]!.buildWall().length, 176);
    });
    test('Bambus-Joker nur in Bambus', () {
      expect(viet([...h('123m456m789m11z'), 18, 49, 20], 18), isNotNull);
      expect(viet([...h('123m456m789m11z'), 9, 49, 11], 9), isNull);
    });
    test('Wind-Joker im Wind-Pung, Drachen-Joker nicht', () {
      expect(viet([...h('123m456m789m11p'), 27, 27, 52], 27), isNotNull);
      expect(viet([...h('123m456m789m11p'), 27, 27, 53], 27), isNull);
    });
    test('Zwei Joker als Paar', () {
      expect(viet([...h('123m456m789m123p'), 52, 52], 0), isNotNull);
      expect(viet([...h('123m456m789m123p'), 48, 49], 0), isNull);
    });
    test('Allgemeiner und Farb-Joker zusammen', () {
      expect(viet([...h('123m456m789m11z'), 47, 54, 20], 20), isNotNull);
    });
    test('Phán verdoppeln die Auszahlung', () {
      // Nur Folgen mit Ehren-Paar 3 Phán, Blume 1 passt zu Ost 1 Phán: 4 Phán zahlen 8
      final s = viet(h('123m456p789s234s11z'), 0, bonus: const [34])!;
      expect(s.points, 8);
    });
    test('Große Hand in Mủn', () {
      final s = viet(h('123456789m22m555m'), 4)!;
      expect(s.fans.map((f) => f.name), contains('Straße 1 bis 9'));
      expect(s.points, greaterThanOrEqualTo(32 * 5));
    });
    test('Phán fürs Ablegen', () {
      expect(vietBonusPhan(47, 0), 3);
      expect(vietBonusPhan(54, 3), 3);
      expect(vietBonusPhan(48, 0), 1);
      expect(vietBonusPhan(emperorTile, 0), 0);
      expect(vietBonusPhan(35, 1), 1);
    });
    test('Joker ablegen gibt Ersatz', () {
      final g = MjGame(mjRules[MjVariant.vietnam]!, rng: Random(3))..start();
      for (var tries = 0; tries < 200 && g.declarableJokers(g.current).isEmpty; tries++) {
        g.discard(g.current, g.players[g.current].hand.firstWhere((t) => !isJokerTile(t)));
        if (g.phase == MjPhase.claim) g.resolveClaims({});
        if (g.phase != MjPhase.discard) break;
      }
      final p = g.current;
      final js = g.declarableJokers(p);
      if (js.isEmpty) return;
      final before = g.players[p].hand.length;
      g.declareJoker(p, js.first);
      expect(g.players[p].hand.length, before);
      expect(g.players[p].bonus, contains(js.first));
    });
  });

  group('Ganze Spiele mit Computern', () {
    for (final v in MjVariant.values) {
      test('${v.name} läuft durch', () {
        for (var seed = 0; seed < 3; seed++) {
          final rng = Random(seed * 31 + v.index);
          final g = MjGame(mjRules[v]!, rng: Random(seed + 100 * v.index))..start();
          final start = g.players.fold(0, (a, p) => a + p.points);
          var tiles = total(g);
          var steps = 0;
          var wins = 0;
          var lastHands = 0;
          while (g.phase != MjPhase.gameOver && steps < 40000) {
            if (g.handsPlayed != lastHands) {
              lastHands = g.handsPlayed;
              wins += g.result?.wins.length ?? 0;
            }
            if (g.phase == MjPhase.exchange || g.phase == MjPhase.handOver) {
              step(g, rng);
              tiles = total(g);
              steps++;
              continue;
            }
            step(g, rng);
            expect(total(g), tiles, reason: 'Steine verschwunden bei ${g.phase}, Schritt $steps');
            steps++;
          }
          expect(g.phase, MjPhase.gameOver, reason: 'Spiel endet nicht');
          expect(g.players.fold(0, (a, p) => a + p.points), start, reason: 'Punkte gehen nicht auf');
          // ignore: avoid_print
          print('${v.name} seed $seed: ${g.handsPlayed} Hände, $wins Siege, Punkte ${g.players.map((p) => p.points).join('/')}');
        }
      });
    }
  });
}
