import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/debug_log.dart';
import '../core/net/lan.dart';
import '../core/net/lan_table.dart';
import '../core/scope.dart';
import 'net_panels.dart';
import 'widgets.dart';

/// Kartenspiele mit Aktionsprotokoll (ActionLog) im lokalen Netz.
///
/// Der Gastgeber schickt Startwert, Namen und Plätze; jedes Gerät baut daraus dieselbe Engine. Danach verteilt
/// der Gastgeber jeden neuen Protokolleintrag. Mitspieler schicken ihre Züge als Protokolleintrag an den Gastgeber,
/// der sie prüft und ausführt. Computer spielen nur beim Gastgeber.
mixin NetReplayScreen<T extends StatefulWidget> on State<T> {
  /// Kennung im Netz.
  String get replayGame;

  /// Name im Warteraum.
  String get replayTitle;

  /// Plätze am Tisch.
  int get replaySeats;

  /// Namen für Computerplätze.
  List<String> get replayBotNames;

  /// Aktionsprotokoll der laufenden Engine.
  List<List<Object?>> get replayLog;

  /// Neue Partie aus Startwert, Namen und Einstellungen des Gastgebers bauen (Engine starten, Ansicht zurücksetzen).
  /// [me] ist dein Platz.
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options);

  /// Einstellungen des Gastgebers, die alle für dieselbe Engine brauchen.
  Map<String, Object?> get replayOptions => const {};

  /// Einen Protokolleintrag ausführen.
  void replayApply(List<dynamic> a);

  /// Darf der Mitspieler an [seat] diesen Zug machen?
  bool replayAllowed(int seat, List<dynamic> a);

  /// Nach Zügen, die nicht hier entschieden wurden: Ton, Anzeige, Computer weiterspielen lassen.
  void replayAfterRemote(List<List<dynamic>> acts);

  NetTableHost? _host;
  NetTableGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manual = TextEditingController();
  bool _panel = false;
  bool _playing = false;
  String _msg = '';
  String _name = '';
  int _seed = 0;
  List<String> _names = const [];
  Map<String, Object?> _options = const {};
  int _sent = 0;

  /// Dein Platz (im Netz je Gerät verschieden).
  int replayMe = 0;

  /// Plätze, an denen Menschen sitzen; alle anderen spielt der Computer (nur beim Gastgeber).
  Set<int> replayHumans = {0};

  bool replayIsBot(int seat) => !replayHumans.contains(seat);
  bool get replayActive => _host != null || _guest != null;
  bool get replayPlaying => _playing;
  bool get replayIsGuest => _guest != null;
  bool get replayIsHost => _host != null;

  /// Als Mitspieler: Zug an den Gastgeber schicken. Liefert true, wenn er verschickt wurde (dann nicht selbst ausführen).
  bool replaySend(List<Object?> a) {
    final g = _guest;
    if (g == null) return false;
    g.send({'t': 'act', 'a': a});
    return true;
  }

  /// Gastgeber: neue Protokolleinträge verteilen. Nach jeder Änderung aufrufen (z. B. in setState).
  void replayBroadcast() {
    final h = _host;
    if (h == null || !_playing) return;
    final log = replayLog;
    if (log.length <= _sent) return;
    h.lan.broadcast({'t': 'acts', 'from': _sent, 'acts': log.sublist(_sent)});
    _sent = log.length;
  }

  List<Widget> replayActions(BuildContext context) => [
        if (!replayActive && !_panel && MediaQuery.sizeOf(context).width >= 420)
          IconButton(tooltip: 'Im Netzwerk spielen', icon: const Icon(Icons.wifi), onPressed: replayOpenPanel),
      ];

  void replayOpenPanel() {
    if (_name.isEmpty) {
      final st = AppScope.of(context).settings;
      _name = '${st.loadGame('netz')?['name'] ?? st.loadGame('poker')?['name'] ?? st.loadGame('bingo')?['name'] ?? ''}';
    }
    setState(() => _panel = true);
  }

  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  /// Knöpfe am Ende einer Runde im Netz. [next] ist die Aktion des Gastgebers (nächste Runde oder neues Spiel).
  List<Widget> replayButtons({required String label, required VoidCallback next}) => [
        if (replayIsGuest)
          const ActionButton(label: 'Warte auf den Gastgeber', onPressed: null)
        else
          ActionButton(primary: true, label: label, onPressed: next),
        ActionButton(label: 'Tisch verlassen', onPressed: replayClose),
      ];

  LanMessage _gameMessage(int me) =>
      {'t': 'game', 'seed': _seed, 'names': _names, 'humans': replayHumans.toList(), 'me': me, 'opt': _options, 'log': replayLog};

  /// Gastgeber: neue Partie mit allen Mitspielern (bis die Plätze voll sind), Rest Computer.
  void replayHostStart() {
    final h = _host!;
    final names = [_displayName];
    final humans = {0};
    for (final s in h.seats.values) {
      s.index = -1;
      if (names.length >= replaySeats) continue;
      s.index = names.length;
      humans.add(s.index);
      names.add(s.name);
    }
    for (final b in replayBotNames) {
      if (names.length >= replaySeats) break;
      names.add(b);
    }
    _seed = Random.secure().nextInt(1 << 31);
    _names = names;
    _options = replayOptions;
    replayHumans = humans;
    replayMe = 0;
    _playing = true;
    debugLog.info('netz', '$replayTitle startet mit ${humans.length - 1} Mitspielern');
    replayNewGame(_seed, names, 0, _options);
    _sent = replayLog.length;
    for (final s in h.seats.values) {
      h.send(s, _gameMessage(s.index));
    }
    if (mounted) setState(() {});
  }

  void _remoteMove(NetSeat seat, LanMessage m) {
    if (!_playing) return;
    if (m['t'] == 'sync') {
      _host?.send(seat, _gameMessage(seat.index));
      return;
    }
    if (m['t'] != 'act' || seat.index < 0 || !replayHumans.contains(seat.index)) return;
    final a = m['a'] as List;
    var ok = false;
    try {
      ok = replayAllowed(seat.index, a);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      _host?.send(seat, _gameMessage(seat.index));
      return;
    }
    try {
      replayApply(a);
    } catch (err) {
      debugLog.warn('netz', 'Ungültiger Zug von ${seat.name}: $err');
      return;
    }
    replayBroadcast();
    if (mounted) replayAfterRemote([a]);
  }

  void _remoteLeft(NetSeat seat) {
    if (!_playing || seat.index < 0) return;
    replayHumans.remove(seat.index);
    if (mounted) replayAfterRemote(const []);
  }

  void _guestMessage(LanMessage m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'game':
        final me = (m['me'] as num).toInt();
        if (me < 0) {
          setState(() => _msg = 'Der Tisch ist voll, warte auf die nächste Partie');
          return;
        }
        _seed = (m['seed'] as num).toInt();
        _names = [for (final n in m['names'] as List) '$n'];
        replayHumans = {for (final h in m['humans'] as List) (h as num).toInt()};
        replayMe = me;
        _playing = true;
        _options = ((m['opt'] as Map?) ?? const {}).cast<String, Object?>();
        replayNewGame(_seed, _names, me, _options);
        try {
          // Was die frische Engine schon protokolliert hat (z. B. den Spielstart), nicht doppelt ausführen
          final have = replayLog.length;
          for (final a in (m['log'] as List).skip(have)) {
            replayApply(a as List);
          }
        } catch (err) {
          debugLog.warn('netz', 'Nachspielen fehlgeschlagen: $err');
        }
        setState(() {});
        replayAfterRemote(const []);
      case 'acts':
        if (!_playing) return;
        final from = (m['from'] as num).toInt();
        final acts = m['acts'] as List;
        final have = replayLog.length;
        if (from > have) {
          _guest?.send({'t': 'sync'});
          return;
        }
        final applied = <List<dynamic>>[];
        try {
          for (final a in acts.skip(have - from)) {
            replayApply(a as List);
            applied.add(a);
          }
        } catch (err) {
          debugLog.warn('netz', 'Zug passt nicht: $err');
          _guest?.send({'t': 'sync'});
          return;
        }
        setState(() {});
        if (applied.isNotEmpty) replayAfterRemote(applied);
    }
  }

  /// Was statt des Tischs gezeigt wird, solange das Netz eingerichtet wird.
  Widget? replayScreen() {
    final g = _guest;
    if (g != null) {
      if (!_playing || !g.lan.connected) return NetGuestWaiting(guest: g, onLeave: replayClose, message: _msg);
      return null;
    }
    if (_browser != null) {
      return NetBrowsePanel(tables: _tables, manual: _manual, onJoin: _join, onBack: replayClose, message: _msg);
    }
    final h = _host;
    if (h != null && !_playing) {
      final free = replaySeats - 1 - h.seats.length;
      return NetHostLobby(
        host: h,
        addresses: _addresses,
        bots: free.clamp(0, replaySeats),
        maxBots: free.clamp(0, replaySeats),
        onBots: (_) {},
        onStart: replayHostStart,
        onClose: replayClose,
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
        hint: 'Alle Geräte im selben WLAN, $replaySeats Plätze. Freie Plätze spielen Computer.',
      );
    }
    return null;
  }

  Future<void> _openTable() async {
    final h = NetTableHost(game: replayGame, hostName: _displayName, info: replayTitle);
    h.onMove = _remoteMove;
    h.onLeave = _remoteLeft;
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
      if (mounted) setState(() {});
    });
    setState(() {
      _host = h;
      _msg = '';
    });
  }

  Future<void> _browse() async {
    final b = LanBrowser(replayGame);
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
    g.onMessage = _guestMessage;
    try {
      await g.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _msg = 'Tisch nicht erreichbar');
      await g.close();
      return;
    }
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
      _playing = false;
      _msg = '';
    });
  }

  Future<void> replayClose() async {
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
      _playing = false;
      _panel = false;
      _msg = '';
      replayMe = 0;
      replayHumans = {0};
    });
    replayClosed();
  }

  /// Nach dem Verlassen des Netzes: wieder allein gegen den Computer.
  void replayClosed() {}

  void replayDispose() {
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manual.dispose();
  }
}
