import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/holdem/holdem_engine.dart';
import 'package:gluckspfennig/games/holdem/holdem_net.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('Sicht und Spiegel: eigene Karten offen, fremde verdeckt, eigener Platz vorn', () {
    final players = [
      HoldemPlayer('Gastgeber', 1000, isHuman: true),
      HoldemPlayer('Anna', 1000)..remote = true,
      HoldemPlayer('Otto', 1000, style: BotStyle.fels),
    ];
    final e = HoldemEngine(players: players, smallBlind: 5, bigBlind: 10, rng: Random(3));
    e.startHand();
    final m = holdemView(e, 1, 1);
    final mirror = holdemMirror(m);
    expect(mirror.players.first.name, 'Anna');
    expect(mirror.players.first.isHuman, isTrue);
    expect(mirror.players.first.hole, players[1].hole);
    // Fremde Karten sind nicht in der Nachricht
    expect((m['players'] as List)[0], isNot(contains('hole')));
    expect(mirror.players[1].name, 'Otto');
    expect(mirror.players[1].style, BotStyle.fels);
    expect(mirror.players[2].name, 'Gastgeber');
    expect(mirror.pot, e.pot);
    // Wer dran ist, ist auf beiden Seiten derselbe Spieler
    expect(mirror.actor.name, e.actor.name);
    expect(mirror.toCall, e.toCall);
    expect(mirror.minRaiseTo, e.minRaiseTo);

    // Bis zum Ende spielen: aufgedeckte Hände sind sichtbar
    while (!e.handOver) {
      e.apply(e.toCall == 0 ? HoldemAction.check : HoldemAction.call);
    }
    final end = holdemMirror(holdemView(e, 1, 1));
    expect(end.handOver, isTrue);
    for (final p in end.players) {
      expect(p.shownValue, isNotNull);
      expect(p.hole.length, 2);
    }
    expect(end.results.map((r) => r.amount), e.results.map((r) => r.amount));
    expect(end.results.first.winners.map((w) => w.name), e.results.first.winners.map((w) => w.name));
  });

  test('Poker über das Netzwerk: Gast bezahlt den Einstieg, sieht seine Sicht und zieht', () async {
    final host = HoldemHost(hostName: 'Gastgeber', omaha: false, draw: false, buyIn: 1000, info: 'Kleiner Tisch');
    final moves = <(String, String)>[];
    host.onMove = (s, m) => moves.add((s.name, '${m['kind']}'));
    await host.open();
    final guest = HoldemGuest('Anna');
    var paid = 0;
    guest.onSeat = (cost) {
      paid = cost;
      return true;
    };
    await guest.join('127.0.0.1', host.lan.port);
    await _until(() => host.seats.length == 1 && guest.lobby.length == 2);
    expect(guest.lobby, ['Gastgeber', 'Anna']);
    expect(guest.buyIn, 1000);

    final seat = host.seats.values.single;
    final p = HoldemPlayer('Anna', 1000)..remote = true;
    host.seat(seat, p);
    await _until(() => paid == 1000 && guest.seated);

    final e = HoldemEngine(players: [HoldemPlayer('Gastgeber', 1000, isHuman: true), p], smallBlind: 5, bigBlind: 10, rng: Random(1));
    e.startHand();
    host.publish(e, 1);
    await _until(() => guest.engine != null);
    final mirror = guest.engine!;
    expect(mirror.players.first.hole, p.hole);
    expect(guest.hand, 1);

    guest.act(HoldemAction.call);
    await _until(() => moves.isNotEmpty);
    expect(moves.single, ('Anna', 'call'));

    var left = false;
    host.onLeave = (_) => left = true;
    await guest.close();
    await _until(() => left);
    await host.close();
  });
}
