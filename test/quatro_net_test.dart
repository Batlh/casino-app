import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/quatro/quatro_engine.dart';

/// Wie im Bildschirm: Züge als Protokolleinträge, auf jedem Gerät eine Engine mit demselben Startwert.
void apply(QuatroEngine e, List<Object?> a) {
  switch (a[0]) {
    case 'p':
      e.place(e.actor.hand.firstWhere((t) => t.id == a[1]), a[2]! as int);
    case 's':
      e.swapColumns(a[1]! as int, a[2]! as int);
    case 'x':
      final id = a[1]! as int;
      e.exchange(id < 0 ? null : e.actor.hand.firstWhere((t) => t.id == id));
    case 'e':
      e.endTurn();
  }
}

List<Object?> botAct(QuatroEngine e, Random rng) {
  if (e.swapPending) {
    final (a, b) = quatroBotSwap(e, rng);
    return ['s', a, b];
  }
  final m = quatroBotChoice(e, rng);
  if (m.tile != null) return ['p', m.tile!.id, m.col];
  if (e.exchanged != null) return ['e'];
  final hand = e.actor.hand;
  return ['x', hand.isEmpty ? -1 : hand[rng.nextInt(hand.length)].id];
}

QuatroEngine engine(int seed, int players) =>
    QuatroEngine(players: [for (var i = 0; i < players; i++) QPlayer('P$i', human: i == 0)], rng: Random(seed))
      ..start(startPlayer: seed % players);

String state(QuatroEngine e) =>
    '${e.board.map((c) => c.map((t) => t.id).join(',')).join('|')} ${e.players.map((p) => p.hand.map((t) => t.id).join(',')).join('|')} '
    '${e.bag.length} ${e.current} ${e.winner?.name} ${e.draw}';

void main() {
  test('Viererkette: Gastgeber und Mitspieler bleiben gleich', () {
    for (var seed = 1; seed <= 30; seed++) {
      final players = 2 + seed % 3;
      final host = engine(seed, players);
      final guest = engine(seed, players);
      final rng = Random(seed * 7);
      var n = 0;
      while (!host.finished && n < 400) {
        final a = botAct(host, rng);
        apply(host, a);
        apply(guest, a);
        expect(state(guest), state(host), reason: 'Startwert $seed, Zug $n');
        n++;
      }
      expect(host.finished, isTrue);
    }
  });
}
