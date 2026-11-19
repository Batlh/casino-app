import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../debug_log.dart';
import '../progress.dart';
import '../version.dart';

/// Mehrspieler im lokalen Netzwerk, ohne Internet und ohne fremden Server.
///
/// Ein Gerät eröffnet einen Tisch (LanHost): Es wartet per WebSocket auf Mitspieler und meldet sich
/// jede Sekunde per UDP-Rundruf im Netz, damit andere den Tisch finden (LanBrowser). Mitspieler verbinden
/// sich mit LanClient. Nachrichten sind kleine JSON-Objekte mit einem Feld "t" für die Art.
/// Was ein Spiel damit macht, bestimmt das Spiel selbst; der Gastgeber führt immer die Regeln.

const lanDiscoveryPort = 47321;
const _app = 'gluckspfennig';
const _netChannel = MethodChannel('gluckspfennig/net');

typedef LanMessage = Map<String, Object?>;

/// Ein gefundener Tisch.
class LanTable {
  LanTable({required this.game, required this.name, required this.address, required this.port, required this.players, required this.info, required this.seen});
  final String game;
  final String name;
  final String address;
  final int port;
  final int players;
  final String info;
  final DateTime seen;
  String get key => '$address:$port';
}

/// Android filtert Rundrufe im WLAN, solange keine Multicast-Sperre gehalten wird.
Future<void> _multicastLock(bool on) async {
  if (!Platform.isAndroid) return;
  try {
    await _netChannel.invokeMethod<void>(on ? 'lockMulticast' : 'unlockMulticast');
  } catch (e) {
    debugLog.warn('netz', 'Multicast-Sperre: $e');
  }
}

/// Eigene IPv4-Adressen im lokalen Netz (zum Anzeigen für die Eingabe von Hand).
Future<List<String>> localAddresses() async {
  final out = <String>[];
  try {
    for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in nic.addresses) {
        if (!a.isLoopback) out.add(a.address);
      }
    }
  } catch (e) {
    debugLog.warn('netz', 'Adressen: $e');
  }
  return out;
}

class LanHost {
  LanHost({required this.game, required this.name});

  final String game;

  /// Name des Tischs, meist der Name des Gastgebers.
  final String name;

  HttpServer? _server;
  RawDatagramSocket? _udp;
  Timer? _beacon;
  final Map<int, WebSocket> _clients = {};
  int _nextId = 1;

  /// Wird bei jedem Rundruf mitgeschickt (z. B. „75 Kugeln · 3 Spieler“).
  String info = '';
  int get port => _server?.port ?? 0;
  Iterable<int> get clientIds => _clients.keys;

  final _joins = StreamController<int>.broadcast();
  final _leaves = StreamController<int>.broadcast();
  final _messages = StreamController<(int, LanMessage)>.broadcast();
  Stream<int> get joins => _joins.stream;
  Stream<int> get leaves => _leaves.stream;
  Stream<(int, LanMessage)> get messages => _messages.stream;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    server.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response
          ..statusCode = HttpStatus.badRequest
          ..close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      final id = _nextId++;
      _clients[id] = ws;
      debugLog.info('netz', 'Mitspieler $id verbunden von ${req.connectionInfo?.remoteAddress.address}');
      progress.event('netz');
      _joins.add(id);
      ws.listen(
        (data) {
          try {
            _messages.add((id, jsonDecode(data as String) as LanMessage));
          } catch (e) {
            debugLog.warn('netz', 'Ungültige Nachricht von $id: $e');
          }
        },
        onDone: () => _drop(id),
        onError: (_) => _drop(id),
        cancelOnError: true,
      );
    });
    final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    udp.broadcastEnabled = true;
    _udp = udp;
    final targets = {InternetAddress('255.255.255.255')};
    for (final a in await localAddresses()) {
      final parts = a.split('.');
      if (parts.length == 4) targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
    }
    void announce() {
      final msg = utf8.encode(jsonEncode({'app': _app, 'v': appVersion, 'game': game, 'name': name, 'port': port, 'players': _clients.length + 1, 'info': info}));
      for (final t in targets) {
        try {
          udp.send(msg, t, lanDiscoveryPort);
        } catch (_) {}
      }
    }

    announce();
    _beacon = Timer.periodic(const Duration(seconds: 1), (_) => announce());
    debugLog.info('netz', 'Tisch „$name“ ($game) offen auf Port $port');
  }

  void _drop(int id) {
    if (_clients.remove(id) != null) {
      debugLog.info('netz', 'Mitspieler $id getrennt');
      _leaves.add(id);
    }
  }

  void send(int id, LanMessage msg) {
    try {
      _clients[id]?.add(jsonEncode(msg));
    } catch (e) {
      debugLog.warn('netz', 'Senden an $id: $e');
    }
  }

  void broadcast(LanMessage msg) {
    final text = jsonEncode(msg);
    for (final ws in _clients.values) {
      try {
        ws.add(text);
      } catch (_) {}
    }
  }

  /// Rundruf beenden, aber verbunden bleiben (z. B. wenn das Spiel läuft).
  void stopAnnouncing() {
    _beacon?.cancel();
    _beacon = null;
  }

  Future<void> close() async {
    _beacon?.cancel();
    _udp?.close();
    for (final ws in _clients.values.toList()) {
      await ws.close();
    }
    _clients.clear();
    await _server?.close(force: true);
    await _joins.close();
    await _leaves.close();
    await _messages.close();
  }
}

/// Sucht offene Tische eines Spiels im Netz.
class LanBrowser {
  LanBrowser(this.game);
  final String game;
  RawDatagramSocket? _udp;
  Timer? _sweep;
  final Map<String, LanTable> _tables = {};
  final _updates = StreamController<List<LanTable>>.broadcast();
  Stream<List<LanTable>> get tables => _updates.stream;
  List<LanTable> get current => _tables.values.toList();

  Future<void> start() async {
    await _multicastLock(true);
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, lanDiscoveryPort, reuseAddress: true, reusePort: !Platform.isWindows && !Platform.isAndroid);
      _udp = udp;
      udp.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = udp.receive();
        if (d == null) return;
        try {
          final m = jsonDecode(utf8.decode(d.data)) as LanMessage;
          if (m['app'] != _app || m['game'] != game) return;
          final t = LanTable(
            game: game,
            name: '${m['name']}',
            address: d.address.address,
            port: (m['port'] as num).toInt(),
            players: (m['players'] as num?)?.toInt() ?? 1,
            info: '${m['info'] ?? ''}',
            seen: DateTime.now(),
          );
          _tables[t.key] = t;
          _updates.add(current);
        } catch (_) {}
      });
    } catch (e) {
      debugLog.warn('netz', 'Suche nicht möglich: $e');
    }
    // Tische, die sich nicht mehr melden, verschwinden nach vier Sekunden
    _sweep = Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _tables.length;
      _tables.removeWhere((_, t) => DateTime.now().difference(t.seen) > const Duration(seconds: 4));
      if (_tables.length != before) _updates.add(current);
    });
  }

  Future<void> close() async {
    _sweep?.cancel();
    _udp?.close();
    await _updates.close();
    await _multicastLock(false);
  }
}

class LanClient {
  WebSocket? _ws;
  final _messages = StreamController<LanMessage>.broadcast();
  final _closed = Completer<void>();
  Stream<LanMessage> get messages => _messages.stream;
  Future<void> get done => _closed.future;
  bool get connected => _ws != null && !_closed.isCompleted;

  Future<void> connect(String address, int port) async {
    final ws = await WebSocket.connect('ws://$address:$port').timeout(const Duration(seconds: 6));
    _ws = ws;
    debugLog.info('netz', 'Verbunden mit $address:$port');
    progress.event('netz');
    ws.listen(
      (data) {
        try {
          _messages.add(jsonDecode(data as String) as LanMessage);
        } catch (_) {}
      },
      onDone: _end,
      onError: (_) => _end(),
      cancelOnError: true,
    );
  }

  void _end() {
    if (!_closed.isCompleted) {
      debugLog.info('netz', 'Verbindung zum Tisch beendet');
      _closed.complete();
    }
  }

  void send(LanMessage msg) {
    try {
      _ws?.add(jsonEncode(msg));
    } catch (_) {}
  }

  Future<void> close() async {
    await _ws?.close();
    _end();
    await _messages.close();
  }
}
