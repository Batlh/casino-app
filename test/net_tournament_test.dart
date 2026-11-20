import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/net/lan_table.dart';
import 'package:gluckspfennig/core/net/net_duel.dart';
import 'package:gluckspfennig/core/wallet.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('Turnierchips: kein Nachfüllen, kein Tagesbonus, nichts gespeichert', () {
    final w = Wallet.tournament(1000);
    var notified = 0;
    w.addListener(() => notified++);
    expect(w.balance, 1000);
    expect(w.spend(1000), isTrue);
    expect(w.refillIfBroke(), isFalse);
    expect(w.balance, 0);
    expect(w.bonusAvailable, isFalse);
    expect(w.claimBonus(), 0);
    w.credit(250);
    expect(w.balance, 250);
    expect(notified, 2);
  });

  test('Schnellnachricht im Zweierspiel kommt beim Gegner an', () async {
    final host = NetTableHost(game: 'test', hostName: 'Anna', info: 'Test');
    await host.open();
    final hostLink = NetDuelLink.host(host);
    Object? atHost;
    hostLink
      ..onChat = ((i) => atHost = i)
      ..attach();
    final guest = NetTableGuest('Ben');
    final guestLink = NetDuelLink.guest(guest);
    Object? atGuest;
    guestLink
      ..onChat = ((i) => atGuest = i)
      ..attach();
    await guest.join('127.0.0.1', host.lan.port);
    await _until(() => host.seats.length == 1);
    expect(hostLink.start('Anna', 0), isTrue);
    await _until(() => guestLink.playing);
    hostLink.sendChat(2);
    await _until(() => atGuest == 2);
    guestLink.sendChat(5);
    await _until(() => atHost == 5);
    await hostLink.close();
    await guestLink.close();
  });
}
