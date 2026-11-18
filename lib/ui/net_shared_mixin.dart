import 'dart:async';

import 'package:flutter/material.dart';

import '../core/debug_log.dart';
import '../core/net/lan.dart';
import '../core/net/lan_table.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import 'net_panels.dart';

/// Casino-Tische im lokalen Netz: Alle setzen mit ihren eigenen Münzen, nur der Gastgeber dreht oder würfelt.
/// Sein Ergebnis geht an alle; jedes Gerät rechnet seine Einsätze selbst ab. Einsätze der anderen werden angezeigt.
mixin NetSharedTable<T extends StatefulWidget> on State<T> {
  String get sharedGame;
  String get sharedTitle;

  /// Ergebnis vom Gastgeber: Rad, Kugel oder Würfel genau so laufen lassen.
  void sharedResult(Object? outcome);

  NetTableHost? _host;
  NetTableGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manual = TextEditingController();
  bool _panel = false;
  bool _open = false;
  String _msg = '';
  String _name = '';
  int _round = 0;
  final Map<String, int> _stakes = {};

  bool get sharedActive => _host != null || _guest != null;

  /// Als Gast: Gedreht wird nur beim Gastgeber.
  bool get sharedGuest => _guest != null;
  bool get sharedHost => _host != null;

  /// Am Tisch und das Spiel läuft (Gastgeber hat eröffnet, Gast ist drin).
  bool get sharedPlaying => (_host != null && _open) || (_guest != null && _guest!.lan.connected && _open);

  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  List<Widget> sharedActions(BuildContext context) => [
        if (!sharedActive && !_panel && MediaQuery.sizeOf(context).width >= 420)
          IconButton(tooltip: 'Im Netzwerk spielen', icon: const Icon(Icons.wifi), onPressed: sharedOpenPanel),
      ];

  void sharedOpenPanel() {
    if (_name.isEmpty) {
      final st = AppScope.of(context).settings;
      _name = '${st.loadGame('netz')?['name'] ?? st.loadGame('poker')?['name'] ?? st.loadGame('bingo')?['name'] ?? ''}';
    }
    setState(() => _panel = true);
  }

  /// Gastgeber: Ergebnis an alle schicken (vor der eigenen Animation aufrufen).
  void sharedSend(Object? outcome) {
    final h = _host;
    if (h == null) return;
    _round++;
    h.lan.broadcast({'t': 'result', 'n': _round, 'o': outcome});
  }

  /// Eigener Einsatz für die Anzeige bei den anderen.
  void sharedStake(int amount) {
    if (!sharedActive) return;
    final h = _host;
    if (h != null) {
      _stakes[h.hostName] = amount;
      _broadcastStakes();
    } else {
      _guest?.send({'t': 'stake', 'amount': amount});
    }
  }

  void _broadcastStakes() {
    _host?.lan.broadcast({'t': 'stakes', 'list': [for (final e in _stakes.entries) [e.key, e.value]]});
    if (mounted) setState(() {});
  }

  /// Zeile mit den Einsätzen am Tisch.
  Widget sharedStakesBar() {
    if (!sharedPlaying) return const SizedBox.shrink();
    final style = TextStyle(color: Palette.of(context).onFelt, fontSize: 14);
    final parts = [for (final e in _stakes.entries) '${e.key} ${e.value > 0 ? formatCoins(e.value) : '–'}'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
        Text('Am Tisch:', style: style.copyWith(fontWeight: FontWeight.w700)),
        for (final p in parts) Text(p, style: style),
        TextButton(onPressed: sharedClose, child: const Text('Tisch verlassen')),
      ]),
    );
  }

  /// Was statt des Tischs gezeigt wird, solange das Netz eingerichtet wird.
  Widget? sharedScreen() {
    final g = _guest;
    if (g != null) {
      if (!_open || !g.lan.connected) return NetGuestWaiting(guest: g, onLeave: sharedClose, message: _msg);
      return null;
    }
    if (_browser != null) {
      return NetBrowsePanel(tables: _tables, manual: _manual, onJoin: _join, onBack: sharedClose, message: _msg);
    }
    final h = _host;
    if (h != null && !_open) {
      return NetHostLobby(
        host: h,
        addresses: _addresses,
        bots: 0,
        maxBots: 0,
        onBots: (_) {},
        onStart: () {
          setState(() => _open = true);
          h.lan.broadcast({'t': 'open'});
          _stakes[h.hostName] = 0;
          for (final s in h.seats.values) {
            _stakes[s.name] = 0;
          }
          _broadcastStakes();
        },
        onClose: sharedClose,
        startLabel: 'Tisch eröffnen',
        minPlayers: 1,
      );
    }
    if (_panel) {
      return NetStartPanel(
        name: _name,
        onName: (v) {
          _name = v;
          AppScope.of(context).settings.saveGame('netz', {'name': v});
        },
        onHost: _openTable,
        onBrowse: _browse,
        onBack: () => setState(() => _panel = false),
        message: _msg,
        hint: 'Alle Geräte im selben WLAN. Jeder setzt mit seinen eigenen Münzen, der Gastgeber dreht für alle.',
      );
    }
    return null;
  }

  Future<void> _openTable() async {
    final h = NetTableHost(game: sharedGame, hostName: _displayName, info: sharedTitle);
    h.onMove = (s, m) {
      if (m['t'] == 'stake') {
        _stakes[s.name] = (m['amount'] as num?)?.toInt() ?? 0;
        _broadcastStakes();
      } else if (m['t'] == 'hello' && _open) {
        h.send(s, {'t': 'open'});
        _stakes[s.name] = 0;
        _broadcastStakes();
      }
    };
    h.onLeave = (s) {
      _stakes.remove(s.name);
      _broadcastStakes();
    };
    try {
      await h.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _msg = 'Tisch konnte nicht eröffnet werden');
      await h.close();
      return;
    }
    _addresses = await localAddresses();
    _sub = h.changed.listen((_) {
      // Wer später kommt, sitzt sofort mit am Tisch
      if (_open) {
        for (final s in h.seats.values) {
          if (!_stakes.containsKey(s.name)) {
            h.send(s, {'t': 'open'});
            _stakes[s.name] = 0;
            _broadcastStakes();
          }
        }
      }
      if (mounted) setState(() {});
    });
    setState(() {
      _host = h;
      _msg = '';
    });
  }

  Future<void> _browse() async {
    final b = LanBrowser(sharedGame);
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _msg = '';
    });
  }

  Future<void> _join(String address, int port) async {
    final g = NetTableGuest(_displayName);
    var last = 0;
    g.onMessage = (m) {
      if (!mounted) return;
      switch (m['t']) {
        case 'open':
          setState(() => _open = true);
        case 'stakes':
          _stakes
            ..clear()
            ..addEntries([for (final e in m['list'] as List) MapEntry('${(e as List)[0]}', (e[1] as num).toInt())]);
          setState(() {});
        case 'result':
          final n = (m['n'] as num).toInt();
          if (n <= last) return;
          last = n;
          _open = true;
          sharedResult(m['o']);
      }
    };
    try {
      await g.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _msg = 'Tisch nicht erreichbar');
      await g.close();
      return;
    }
    g.send({'t': 'hello'});
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    _sub = g.changed.listen((_) {
      if (!mounted) return;
      if (!g.lan.connected) _msg = 'Der Gastgeber hat den Tisch geschlossen';
      setState(() {});
    });
    setState(() {
      _guest = g;
      _open = false;
      _msg = '';
    });
  }

  Future<void> sharedClose() async {
    await _sub?.cancel();
    _sub = null;
    await _host?.close();
    await _guest?.close();
    await _browser?.close();
    if (!mounted) return;
    setState(() {
      _host = null;
      _guest = null;
      _browser = null;
      _open = false;
      _panel = false;
      _msg = '';
      _stakes.clear();
    });
  }

  void sharedDispose() {
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manual.dispose();
  }
}
