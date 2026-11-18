import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/saves.dart';
import 'package:gluckspfennig/games/hearts/hearts_engine.dart';
import 'package:gluckspfennig/games/hearts/hearts_net.dart';

HeartsEngine _make(int seed, int me) => HeartsEngine(
      rng: Random(seed),
      seats: [for (final (i, n) in const ['A', 'B', 'C', 'D'].indexed) HeartsSeat(n, human: i == me)],
    )..newGame();

String _state(HeartsEngine e) => [
      e.phase.name,
      e.handNumber,
      e.current,
      for (final s in e.seats) '${s.hand.map(cardCode).join()}/${s.score}',
    ].join('|');

void main() {
  test('Schwarze Dame: Gastgeber und Mitspieler bleiben über ein ganzes Spiel gleich', () {
    for (var seed = 1; seed <= 3; seed++) {
      final host = _make(seed, 0);
      final guest = _make(seed, 2);
      expect(_state(guest), _state(host));
      var sent = host.actionLog.length;
      var steps = 0;
      while (host.phase != HeartsPhase.gameOver && steps < 20000) {
        switch (host.phase) {
          case HeartsPhase.passing:
            final s = [for (var i = 0; i < 4; i++) if (!host.hasPassed(i)) i].first;
            host.choosePass(s, heartsBotPass(host.seats[s].hand));
          case HeartsPhase.playing:
            host.play(heartsBotPlay(host));
          case HeartsPhase.handOver:
            host.startHand();
          case HeartsPhase.gameOver:
            break;
        }
        for (final a in host.actionLog.sublist(sent)) {
          heartsApply(guest, a);
        }
        sent = host.actionLog.length;
        expect(_state(guest), _state(host), reason: 'Schritt $steps');
        steps++;
      }
      expect(host.phase, HeartsPhase.gameOver);
    }
  });

  test('Schwarze Dame: Züge von Mitspielern nur, wenn sie erlaubt sind', () {
    final e = _make(5, 0);
    if (e.phase == HeartsPhase.passing) {
      final hand = e.seats[1].hand;
      expect(heartsAllowed(e, 1, ['p', 1, for (final c in hand.take(3)) cardCode(c)]), isTrue);
      expect(heartsAllowed(e, 1, ['p', 2, for (final c in hand.take(3)) cardCode(c)]), isFalse, reason: 'fremder Platz');
      expect(heartsAllowed(e, 1, ['p', 1, for (final c in e.seats[2].hand.take(3)) cardCode(c)]), isFalse, reason: 'fremde Karten');
      for (var s = 0; s < 4; s++) {
        e.choosePass(s, heartsBotPass(e.seats[s].hand));
      }
    }
    final c = e.current;
    expect(heartsAllowed(e, c, ['c', cardCode(e.legalCards(c).first)]), isTrue);
    expect(heartsAllowed(e, (c + 1) % 4, ['c', cardCode(e.seats[(c + 1) % 4].hand.first)]), isFalse);
    expect(heartsAllowed(e, c, ['g']), isFalse);
  });
}
