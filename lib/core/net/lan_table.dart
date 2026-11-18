import 'dart:async';

import '../debug_log.dart';
import 'lan.dart';

/// Allgemeiner Spieltisch im lokalen Netz für Runden-Spiele (Karten, Brett).
///
/// Der Gastgeber führt das Spiel. Mitspieler melden sich mit Namen an, bekommen nach jedem Zug ihre Sicht
/// ('view') und schicken ihre Züge als Nachrichten. Was in einer Sicht oder einem Zug steht, bestimmt das Spiel.

/// Ein Mitspieler im Netz, wie der Gastgeber ihn kennt.
class NetSeat {
  NetSeat(this.id, this.name);
  final int id;
  String name;

  /// Platz im laufenden Spiel, -1 solange er nur wartet.
  int index = -1;
}

class NetTableHost {
  NetTableHost({required String game, required this.hostName, required this.info}) : lan = LanHost(game: game, name: hostName);

  final String hostName;
  String info;
  final LanHost lan;
  final Map<int, NetSeat> seats = {};
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;
  final List<StreamSubscription<Object?>> _subs = [];

  /// Zug eines Mitspielers; das Spiel prüft ihn.
  void Function(NetSeat seat, LanMessage m)? onMove;

  /// Ein Mitspieler hat den Tisch verlassen.
  void Function(NetSeat seat)? onLeave;

  Future<void> open() async {
    lan.info = info;
    await lan.start();
    _subs.add(lan.messages.listen((e) {
      final (id, m) = e;
      switch (m['t']) {
        case 'join':
          final name = '${m['name']}'.trim();
          seats.putIfAbsent(id, () => NetSeat(id, name)).name = name.isEmpty ? 'Gast $id' : name;
          lobby();
        case 'leave':
          _drop(id);
        default:
          final s = seats[id];
          if (s != null) onMove?.call(s, m);
      }
    }));
    _subs.add(lan.leaves.listen(_drop));
  }

  void _drop(int id) {
    final s = seats.remove(id);
    if (s != null) {
      debugLog.info('netz', '${s.name} hat den Tisch verlassen');
      onLeave?.call(s);
    }
    lobby();
  }

  /// Warteraum an alle: Name des Tischs, Infos, wer da ist.
  void lobby() {
    lan.info = '$info · ${seats.length + 1} Spieler';
    lan.broadcast({
      't': 'lobby',
      'info': info,
      'players': [hostName, for (final s in seats.values) s.name],
    });
    if (!_changed.isClosed) _changed.add(null);
  }

  void send(NetSeat s, LanMessage m) => lan.send(s.id, m);

  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await lan.close();
    await _changed.close();
  }
}

class NetTableGuest {
  NetTableGuest(this.name);
  final String name;
  final LanClient lan = LanClient();
  List<String> lobby = [];
  String info = '';

  /// Letzte Sicht vom Gastgeber.
  LanMessage? view;
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;

  /// Andere Nachrichten des Spiels (alles außer lobby und view).
  void Function(LanMessage m)? onMessage;

  Future<void> join(String address, int port) async {
    await lan.connect(address, port);
    lan.messages.listen((m) {
      switch (m['t']) {
        case 'lobby':
          lobby = [for (final p in m['players'] as List) '$p'];
          info = '${m['info']}';
        case 'view':
          view = m;
        default:
          onMessage?.call(m);
      }
      if (!_changed.isClosed) _changed.add(null);
    });
    unawaited(lan.done.then((_) {
      if (!_changed.isClosed) _changed.add(null);
    }));
    lan.send({'t': 'join', 'name': name});
  }

  void send(LanMessage m) => lan.send(m);

  Future<void> close() async {
    lan.send({'t': 'leave'});
    await lan.close();
    await _changed.close();
  }
}
