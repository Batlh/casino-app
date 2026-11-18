import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/saves.dart';
import 'package:gluckspfennig/games/arschloch/ah_engine.dart';
import 'package:gluckspfennig/games/arschloch/ah_net.dart';

AhGame _make(int seed) => AhGame(rng: Random(seed), names: const ['A', 'B', 'C', 'D'], humans: const [true, false, true, false])..start();

String _state(AhGame g) => [
      g.phase.name,
      g.round,
      g.current,
      g.finished.join(','),
      for (final p in g.players) '${(p.hand.map(cardCode).toList()..sort()).join()}/${p.points}',
    ].join('|');

void main() {
  test('Arschloch: Gastgeber und Mitspieler bleiben über ein ganzes Spiel gleich', () {
    for (var seed = 1; seed <= 3; seed++) {
      final host = _make(seed);
      final guest = _make(seed);
      var sent = 0;
      var steps = 0;
      while (host.phase != AhPhase.gameOver && steps < 5000) {
        switch (host.phase) {
          case AhPhase.exchange:
            final p = host.pendingGive.first;
            host.giveBack(p, sortAh(host.players[p].hand).take(host.gives(p)).toList());
          case AhPhase.play:
            final p = host.current;
            final m = ahBotMove(host, p);
            if (m == null) {
              host.pass(p);
            } else {
              host.play(p, m);
            }
          case AhPhase.roundOver:
            host.nextRound();
          case AhPhase.gameOver:
            break;
        }
        for (final a in host.actionLog.sublist(sent)) {
          ahApply(guest, a);
        }
        sent = host.actionLog.length;
        expect(_state(guest), _state(host), reason: 'Schritt $steps');
        steps++;
      }
      expect(host.phase, AhPhase.gameOver);
    }
  });

  test('Arschloch: Züge von Mitspielern nur, wenn sie dran sind', () {
    final g = _make(4);
    final c = g.current;
    if (c != 0) {
      final m = ahBotMove(g, c) ?? [g.players[c].hand.first];
      expect(ahAllowed(g, c, ['p', c, for (final x in m) cardCode(x)]), g.canPlay(c, m));
      expect(ahAllowed(g, c, ['x', c]), isFalse, reason: 'Ausspielen ist Pflicht');
    }
    final other = (c + 1) % 4;
    if (other != 0) expect(ahAllowed(g, other, ['p', other, cardCode(g.players[other].hand.first)]), isFalse);
    expect(ahAllowed(g, 0, ['p', 0, cardCode(g.players[0].hand.first)]), isFalse, reason: 'Platz 0 ist der Gastgeber');
    expect(ahAllowed(g, 2, ['n']), isFalse);
  });
}
