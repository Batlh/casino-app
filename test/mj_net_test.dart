import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/american/am_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_bot.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';
import 'package:gluckspfennig/games/mahjong/riichi_bot.dart';
import 'package:gluckspfennig/games/mahjong/riichi_engine.dart';

/// Ein Schritt am Netztisch: Menschen tauschen und wählen einzeln, sonst wie die Computer.
void step(MjGame g, Random rng) {
  switch (g.phase) {
    case MjPhase.exchange:
      final p = [for (var i = 0; i < g.n; i++) if (g.players[i].exchange.length != 3) i].first;
      g.submitExchange(p, g.botExchange(p));
    case MjPhase.voidChoice:
      final p = [for (var i = 0; i < g.n; i++) if (g.players[i].voidSuit == null) i].first;
      g.chooseVoid(p, g.botVoid(p));
    case MjPhase.discard:
      final p = g.current;
      switch (mjBotTurn(g, p, rng)) {
        case MjBotWin():
          g.tsumo(p);
        case MjBotKan(:final tile):
          g.kan(p, tile);
        case MjBotJoker(:final tile):
          g.declareJoker(p, tile);
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

String state(MjGame g) => [
      g.phase.name,
      g.current,
      g.wall.length,
      for (final p in g.players) '${p.hand.join(',')}/${p.discards.length}/${p.melds.length}/${p.points}/${p.voidSuit}',
    ].join(' ');

void main() {
  riichiMain();
  amMain();
  for (final v in MjVariant.values) {
    test('Mahjong ${v.name} im Netz: alle Geräte bleiben gleich', () {
      final rules = mjRules[v]!;
      final humans = {0, rules.players - 1};
      final host = MjGame(rules, rng: Random(v.index + 7), humans: humans)..start();
      final guest = MjGame(rules, rng: Random(v.index + 7), humans: humans, me: rules.players - 1)..start();
      final rng = Random(v.index);
      var steps = 0;
      while (host.phase != MjPhase.gameOver && host.handsPlayed < 3 && steps < 6000) {
        step(host, rng);
        for (final a in host.actionLog.skip(guest.actionLog.length).toList()) {
          mjApply(guest, a);
        }
        expect(state(guest), state(host), reason: 'Schritt $steps');
        steps++;
      }
      expect(guest.actionLog.length, host.actionLog.length);
    });
  }
}

void riichiStep(RiichiGame g, Random rng) {
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
      g.nextHand();
    case RPhase.gameOver:
      break;
  }
}

String riichiState(RiichiGame g) => [
      g.phase.name,
      g.current,
      g.wall.length,
      for (final p in g.players) '${p.hand.join(',')}/${p.discards.length}/${p.melds.length}/${p.points}/${p.riichi}',
    ].join(' ');

void riichiMain() {
  test('Riichi im Netz: alle Geräte bleiben gleich', () {
    for (var seed = 1; seed <= 3; seed++) {
      final host = RiichiGame(rng: Random(seed), humans: {0, 2})..start();
      final guest = RiichiGame(rng: Random(seed), humans: {0, 2}, me: 2)..start();
      final rng = Random(seed * 11);
      var steps = 0;
      while (host.phase != RPhase.gameOver && steps < 8000) {
        riichiStep(host, rng);
        for (final a in host.actionLog.skip(guest.actionLog.length).toList()) {
          riichiApply(guest, a);
        }
        expect(riichiState(guest), riichiState(host), reason: 'Startwert $seed, Schritt $steps');
        steps++;
      }
    }
  });
}

void amStep(AmGame g, Random rng) {
  switch (g.phase) {
    case AmPhase.charleston:
      final p = [for (var i = 0; i < 4; i++) if (g.players[i].pass.length != 3) i].first;
      g.submitPass(p, g.botPass(p, rng));
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
      g.nextHand();
    case AmPhase.gameOver:
      break;
  }
}

String amState(AmGame g) => [
      g.phase.name,
      g.current,
      g.wall.length,
      for (final p in g.players) '${p.hand.join(',')}/${p.discards.length}/${p.exposed.length}/${p.points}',
    ].join(' ');

void amMain() {
  test('American Mahjong im Netz: alle Geräte bleiben gleich', () {
    for (var seed = 1; seed <= 2; seed++) {
      final host = AmGame(rng: Random(seed), humans: {0, 1})..start();
      final guest = AmGame(rng: Random(seed), humans: {0, 1}, me: 1)..start();
      final rng = Random(seed * 13);
      var steps = 0;
      while (host.phase != AmPhase.gameOver && steps < 8000) {
        amStep(host, rng);
        for (final a in host.actionLog.skip(guest.actionLog.length).toList()) {
          amApply(guest, a);
        }
        expect(amState(guest), amState(host), reason: 'Startwert $seed, Schritt $steps');
        steps++;
      }
    }
  });
}
