import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/net/lan_table.dart';
import 'package:gluckspfennig/core/net/net_duel.dart';

Future<void> _until(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(ok(), isTrue);
}

void main() {
  test('Zweierspiel: Start, Züge in beide Richtungen, Abgleich nach einem ungültigen Zug', () async {
    final host = NetTableHost(game: 'test', hostName: 'Anna', info: 'Test');
    await host.open();
    final hostLink = NetDuelLink.host(host);
    final hostMoves = <Object?>[];
    var hostStart = <String>[];
    hostLink
      ..onStart = (n, s) {
        hostStart = n;
        hostMoves.clear();
      }
      ..onMove = (m) {
        hostMoves.add(m);
        return true;
      }
      ..attach();

    final guest = NetTableGuest('Ben');
    final guestLink = NetDuelLink.guest(guest);
    final guestMoves = <Object?>[];
    var guestSeat = -1;
    var refuse = false;
    guestLink
      ..onStart = (n, s) {
        guestSeat = s;
        guestMoves.clear();
      }
      ..onMove = (m) {
        if (refuse) {
          refuse = false;
          return false;
        }
        guestMoves.add(m);
        return true;
      }
      ..attach();
    await guest.join('127.0.0.1', host.lan.port);
    await _until(() => host.seats.length == 1);

    expect(hostLink.start('Anna', 0), isTrue);
    expect(hostStart, ['Anna', 'Ben']);
    expect(hostLink.seat, 0);
    await _until(() => guestSeat == 1);

    hostLink.sendMove(19);
    await _until(() => guestMoves.length == 1);
    guestLink.sendMove([2, 3]);
    await _until(() => hostMoves.length == 1);
    expect(hostMoves.single, [2, 3]);

    // Der Gast lehnt einen Zug ab: Er fordert die ganze Liste an und spielt sie nach
    refuse = true;
    hostLink.sendMove(26);
    await _until(() => guestMoves.length == 3);
    expect(guestMoves, [19, [2, 3], 26]);
    expect(guestLink.moves.length, 3);

    await guest.close();
    await host.close();
  });
}
