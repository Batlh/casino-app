import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_bot.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';

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
