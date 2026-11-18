import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/net/lan_table.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/maumau/maumau_engine.dart';
import 'package:gluckspfennig/games/maumau/maumau_net.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('Sicht und Spiegel: eigene Hand offen, fremde nur als Anzahl', () {
    final e = MauMauEngine(
      players: [MauPlayer('Gastgeber', human: true), MauPlayer('Anna')..remote = true, MauPlayer('Otto')],
      rng: Random(3),
    )
      ..neutralText = true
      ..start(startPlayer: 1);
    final m = mauView(e, 1, round: 0, bots: 1);
    expect((m['players'] as List)[0], isNot(contains('hand')));
    final mirror = mauMirror(m);
    expect(mirror.players[1].human, isTrue);
    expect(mirror.players[1].hand, e.players[1].hand);
    expect(mirror.players[0].hand.length, e.players[0].hand.length);
    expect(mirror.top, e.top);
    expect(mirror.current, 1);
    expect(mirror.drawPile.length, e.drawPile.length);
    // Was die gespiegelte Engine für spielbar hält, nimmt der Gastgeber auch an
    final ok = mirror.playableCards();
    for (final c in mirror.players[1].hand) {
      expect(ok.contains(c), e.canPlay(c));
    }
  });

  test('Züge eines Mitspielers: nur wenn er dran ist und die Karte passt', () {
    final e = MauMauEngine(players: [MauPlayer('A', human: true), MauPlayer('B')..remote = true], rng: Random(5))..start(startPlayer: 1);
    expect(mauApplyRemote(e, 0, mauDrawMsg(0)), isFalse, reason: 'A ist nicht dran');
    final bad = e.players[1].hand.where((c) => !e.canPlay(c)).firstOrNull;
    if (bad != null) expect(mauApplyRemote(e, 1, mauPlayMsg(bad, null, 0)), isFalse);
    final good = e.players[1].hand.where(e.canPlay).firstOrNull;
    if (good != null) {
      expect(mauApplyRemote(e, 1, mauPlayMsg(good, Suit.hearts, 0)), isTrue);
      expect(e.top, good);
    } else {
      expect(mauApplyRemote(e, 1, mauDrawMsg(0)), isTrue);
    }
  });

  test('Mau Mau über das Netzwerk: Gast sieht seine Sicht, sein Zug kommt beim Gastgeber an', () async {
    final host = NetTableHost(game: mauNetGame, hostName: 'Gastgeber', info: 'Mau Mau');
    final moves = <String>[];
    host.onMove = (s, m) => moves.add('${s.name}:${m['t']}');
    await host.open();
    final guest = NetTableGuest('Anna');
    await guest.join('127.0.0.1', host.lan.port);
    await _until(() => host.seats.length == 1 && guest.lobby.length == 2);
    expect(guest.lobby, ['Gastgeber', 'Anna']);

    final seat = host.seats.values.single..index = 1;
    final e = MauMauEngine(players: [MauPlayer('Gastgeber', human: true), MauPlayer('Anna')..remote = true], rng: Random(1))
      ..neutralText = true
      ..start(startPlayer: 1);
    host.send(seat, mauView(e, 1, round: 0, bots: 0));
    await _until(() => guest.view != null);
    final mirror = mauMirror(guest.view!);
    expect(mirror.players[1].hand, e.players[1].hand);

    guest.send(mauDrawMsg(0));
    await _until(() => moves.isNotEmpty);
    expect(moves.single, 'Anna:draw');

    var left = false;
    host.onLeave = (_) => left = true;
    await guest.close();
    await _until(() => left);
    await host.close();
  });
}
