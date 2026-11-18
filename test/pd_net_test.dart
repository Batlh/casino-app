import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pikdame/pd_engine.dart';
import 'package:gluckspfennig/games/pikdame/pd_net.dart';

PdGame _make(int seed, int me, {int players = 3}) => PdGame(
      PdOptions(players: players, target: 500, jokerValue: 25, maxJokers: 1, firstMeld50: true),
      rng: Random(seed),
      names: const ['A', 'B', 'C', 'D'].sublist(0, players),
      humans: [for (var i = 0; i < players; i++) i == me],
    )..start();

String _state(PdGame g) => [
      g.phase.name,
      g.current,
      g.pile.length,
      g.melds.length,
      for (final p in g.players) '${p.hand.map((c) => c.id).join(',')}/${p.score}',
    ].join('|');

void main() {
  test('Pik Dame: Gastgeber und Mitspieler bleiben über ein ganzes Spiel gleich', () {
    for (var seed = 1; seed <= 3; seed++) {
      final host = _make(seed, 0);
      final guest = _make(seed, 1);
      final rng = Random(seed);
      var sent = 0;
      var steps = 0;
      while (host.phase != PdPhase.gameOver && steps < 3000) {
        if (host.phase == PdPhase.roundOver) {
          host.nextRound();
        } else {
          pdBotTurn(host, host.current, rng);
        }
        for (final a in host.actionLog.sublist(sent)) {
          pdApply(guest, a);
        }
        sent = host.actionLog.length;
        expect(_state(guest), _state(host), reason: 'Schritt $steps');
        steps++;
      }
      expect(host.phase, PdPhase.gameOver);
    }
  });

  test('Pik Dame: Züge von Mitspielern nur, wenn sie dran sind', () {
    final g = _make(4, 0);
    final c = g.current;
    final other = (c + 1) % g.n;
    expect(pdAllowed(g, c, ['s', c]), isTrue);
    expect(pdAllowed(g, other, ['s', other]), isFalse);
    expect(pdAllowed(g, c, ['s', other]), isFalse);
    expect(pdAllowed(g, c, ['d', c, g.players[c].hand.first.id]), isFalse, reason: 'erst ziehen');
    expect(pdAllowed(g, c, ['n']), isFalse);
  });
}
