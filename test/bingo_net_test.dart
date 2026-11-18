import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/bingo/bingo_engine.dart';
import 'package:gluckspfennig/games/bingo/bingo_net.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('Bingo über das Netzwerk: Gast sieht seine Karten, Kugeln und bekommt seine Gewinne', () async {
    final host = BingoHost(hostName: 'Gastgeber', variant: BingoVariant.uk90, pattern: BingoPattern.line, cardPrice: 50, bots: 2, rng: Random(7));
    await host.open();
    final guest = BingoGuest('Gast', 3);
    var paidCost = 0;
    var won = 0;
    guest.onStart = (cost) {
      paidCost = cost;
      return true;
    };
    guest.onPay = (amount, _) => won += amount;
    await guest.join('127.0.0.1', host.lan.port);
    await _until(() => host.seats.length == 1 && guest.lobby.length == 2);
    expect(guest.lobby, ['Gastgeber', 'Gast']);

    final (g, me) = host.startRound(1, ['Bot A', 'Bot B']);
    expect(g.players.length, 4);
    final guestPlayer = host.seats.values.single.player!;
    expect(guestPlayer.cards.length, 3);
    await _until(() => paidCost == 150);

    final allWins = <BingoWin>[];
    while (!g.over) {
      final w = g.callNext();
      allWins.addAll(w);
      host.publish(g, w, const []);
    }
    await _until(() => guest.view?.over == true && guest.view!.called.length == g.called.length);
    final v = guest.view!;
    expect(v.called, g.called);
    expect([for (final c in v.myCards) c.rows], [for (final c in guestPlayer.cards) c.rows]);
    expect(v.others.map((o) => o.$1), containsAll(['Gastgeber', 'Bot A', 'Bot B']));
    final expected = allWins.where((w) => w.player == guestPlayer).fold(0, (a, w) => a + w.amount);
    await _until(() => won == expected);
    expect(me.cards.length, 1);

    await guest.close();
    await host.close();
  });
}
