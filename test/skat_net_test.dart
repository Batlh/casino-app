import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/saves.dart';
import 'package:gluckspfennig/games/skat/skat_bot.dart';
import 'package:gluckspfennig/games/skat/skat_engine.dart';
import 'package:gluckspfennig/games/skat/skat_net.dart';

/// Ein Zug der Computer, wie im Bildschirm.
void _botStep(SkatGame g, Random rng) {
  switch (g.phase) {
    case SkatPhase.bidding:
      final p = g.bidTurn;
      if (skatMaxBid(g.players[p].hand) >= g.askedValue) {
        g.bidYes(p);
      } else {
        g.bidPass(p);
      }
    case SkatPhase.skatChoice:
      g.takeSkat();
    case SkatPhase.discard:
      final cards = g.players[g.declarer].hand;
      g.discard(skatDiscard(cards, skatChooseGame(g, cards)));
    case SkatPhase.declare:
      g.declare(skatChooseGame(g, [...g.players[g.declarer].hand, ...g.skat]));
    case SkatPhase.playing:
      g.play(g.current, skatBotCard(g, g.current, rng));
    case SkatPhase.dealOver:
      g.nextDeal();
    case SkatPhase.matchOver:
      break;
  }
}

String _state(SkatGame g) => [
      g.phase.name,
      g.dealsPlayed,
      g.bid,
      g.declarer,
      g.current,
      for (final p in g.players) '${p.hand.map(cardCode).join()}/${p.score}',
      g.trick.map(cardCode).join(),
    ].join('|');

void main() {
  test('Skat: Gastgeber und Mitspieler bleiben über eine ganze Liste gleich', () {
    for (var seed = 1; seed <= 3; seed++) {
      const names = ['Gastgeber', 'Anna', 'Horst'];
      final host = SkatGame(rng: Random(seed), names: names)..start();
      final guest = SkatGame(rng: Random(seed), names: names)
        ..me = 1
        ..start();
      final rng = Random(seed);
      var sent = 0;
      var steps = 0;
      while (host.phase != SkatPhase.matchOver && steps < 5000) {
        _botStep(host, rng);
        for (final a in host.actionLog.sublist(sent)) {
          skatApply(guest, a);
        }
        sent = host.actionLog.length;
        expect(_state(guest), _state(host), reason: 'Schritt $steps');
        steps++;
      }
      expect(host.phase, SkatPhase.matchOver);
      expect(guest.actionLog.length, host.actionLog.length);
    }
  });

  test('Skat: Züge von Mitspielern nur, wenn sie dran sind', () {
    final g = SkatGame(rng: Random(4), names: const ['A', 'B', 'C'])..start();
    final p = g.bidTurn;
    final other = (p + 1) % 3;
    expect(skatAllowed(g, p, ['y', p]), isTrue);
    expect(skatAllowed(g, other, ['y', other]), isFalse);
    expect(skatAllowed(g, p, ['y', other]), isFalse, reason: 'nicht im Namen eines anderen');
    expect(skatAllowed(g, p, ['s']), isFalse, reason: 'Skat erst nach dem Reizen');
    // Bis zum Ausspielen bringen
    final rng = Random(1);
    while (g.phase != SkatPhase.playing) {
      _botStep(g, rng);
    }
    final c = g.current;
    final legal = g.legalCards(c);
    expect(skatAllowed(g, c, ['p', c, cardCode(legal.first)]), isTrue);
    final illegal = g.players[c].hand.where((x) => !legal.contains(x)).firstOrNull;
    if (illegal != null) expect(skatAllowed(g, c, ['p', c, cardCode(illegal)]), isFalse);
    final foreign = g.players[(c + 1) % 3].hand.first;
    expect(skatAllowed(g, c, ['p', c, cardCode(foreign)]), isFalse);
  });
}
