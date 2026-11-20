import 'dart:async';

import 'package:flutter/material.dart';

import '../core/debug_log.dart';
import '../core/net/lan.dart';
import '../core/net/lan_table.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../core/wallet.dart';
import 'net_chat.dart';
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

  // ---------------------------------------------------------------- Turnier
  /// Turnierchips, solange ein Turnier läuft; sonst null.
  Wallet? _tour;
  int _tourRounds = 0;
  int _tourLeft = 0;
  final Map<String, int> _tourBalances = {};

  /// Chips zu Beginn eines Turniers.
  static const tournamentChips = 1000;

  bool get sharedTournament => _tour != null;

  /// Die Münzen für Einsätze: im Turnier die Turnierchips, sonst das eigene Guthaben.
  Wallet get sharedWallet => _tour ?? AppScope.of(context).wallet;

  bool get sharedActive => _host != null || _guest != null;

  /// Als Gast: Gedreht wird nur beim Gastgeber.
  bool get sharedGuest => _guest != null;
  bool get sharedHost => _host != null;

  /// Am Tisch und das Spiel läuft (Gastgeber hat eröffnet, Gast ist drin).
  bool get sharedPlaying => (_host != null && _open) || (_guest != null && _guest!.lan.connected && _open);

  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  List<Widget> sharedActions(BuildContext context) => [
        if (sharedPlaying) quickChatButton(sharedChat),
        if (!sharedActive && !_panel && MediaQuery.sizeOf(context).width >= 420)
          IconButton(tooltip: 'Im Netzwerk spielen', icon: const Icon(Icons.wifi), onPressed: sharedOpenPanel),
      ];

  /// Schnellnachricht an alle am Tisch.
  void sharedChat(int index) {
    final h = _host;
    if (h != null) {
      h.lan.broadcast({'t': 'chat', 'from': h.hostName, 'm': index});
      showQuickMessage(context, 'Du', index);
    } else {
      _guest?.send({'t': 'chat', 'm': index});
    }
  }

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
    if (_tour != null) {
      _tourLeft--;
      _broadcastRanking();
      // Nach der letzten Runde kurz warten, bis alle abgerechnet haben
      if (_tourLeft <= 0) Future<void>.delayed(const Duration(seconds: 10), _endTournament);
    }
  }

  /// Gastgeber: Turnier starten. Alle bekommen dieselben Chips, nach [rounds] Runden gewinnt, wer am meisten hat.
  void sharedStartTournament(int rounds) {
    final h = _host;
    if (h == null || _tour != null) return;
    h.lan.broadcast({'t': 'tour', 'chips': tournamentChips, 'rounds': rounds});
    _beginTournament(tournamentChips, rounds);
    _tourBalances
      ..clear()
      ..[h.hostName] = tournamentChips;
    for (final s in h.seats.values) {
      _tourBalances[s.name] = tournamentChips;
    }
    _broadcastRanking();
  }

  void _beginTournament(int chips, int rounds) {
    _tour?.dispose();
    final w = Wallet.tournament(chips);
    w.addListener(_reportBalance);
    _tour = w;
    _tourRounds = rounds;
    _tourLeft = rounds;
    if (mounted) setState(() {});
  }

  void _reportBalance() {
    final w = _tour;
    if (w == null) return;
    final h = _host;
    if (h != null) {
      _tourBalances[h.hostName] = w.balance;
      _broadcastRanking();
    } else {
      _guest?.send({'t': 'tbal', 'b': w.balance});
    }
  }

  void _broadcastRanking() {
    final h = _host;
    if (h == null) return;
    h.lan.broadcast({'t': 'trank', 'left': _tourLeft, 'rounds': _tourRounds, 'list': [for (final e in _tourBalances.entries) [e.key, e.value]]});
    if (mounted) setState(() {});
  }

  void _endTournament() {
    if (_tour == null) return;
    final ranking = _ranking();
    _host?.lan.broadcast({'t': 'tend', 'list': [for (final e in ranking) [e.key, e.value]]});
    _finishTournament(ranking);
  }

  List<MapEntry<String, int>> _ranking() => _tourBalances.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  void _finishTournament(List<MapEntry<String, int>> ranking) {
    _tour?.removeListener(_reportBalance);
    _tour = null;
    if (!mounted) return;
    setState(() {});
    final me = _host?.hostName ?? _displayName;
    final place = ranking.indexWhere((e) => e.key == me) + 1;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place == 1 ? 'Turniersieg!' : 'Turnier vorbei'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, e) in ranking.indexed)
            Text('${i + 1}. ${e.key}: ${formatCoins(e.value)}', style: TextStyle(fontWeight: e.key == me ? FontWeight.w800 : FontWeight.w400)),
          const SizedBox(height: 8),
          const Text('Die Turnierchips verfallen, dein eigenes Guthaben ist unberührt.'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  /// Gastgeber: Dialog zum Turnierstart.
  Future<void> _askTournament() async {
    final rounds = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Turnier starten'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text('Alle bekommen $tournamentChips Turnierchips. Nach der letzten Runde gewinnt, wer am meisten hat. '
                'Eigene Münzen bleiben unberührt.'),
          ),
          for (final r in const [10, 20, 30])
            SimpleDialogOption(onPressed: () => Navigator.pop(context, r), child: Text('$r Runden')),
        ],
      ),
    );
    if (rounds != null) sharedStartTournament(rounds);
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
    final tour = _tour;
    final ranking = _ranking();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (tour != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0x33FFC95C), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFC95C))),
            child: Wrap(alignment: WrapAlignment.center, spacing: 10, children: [
              Text('Turnier: noch $_tourLeft von $_tourRounds Runden · deine Chips ${formatCoins(tour.balance)}',
                  style: style.copyWith(fontWeight: FontWeight.w800)),
              for (final (i, e) in ranking.take(5).indexed) Text('${i + 1}. ${e.key} ${formatCoins(e.value)}', style: style),
            ]),
          ),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
          Text('Am Tisch:', style: style.copyWith(fontWeight: FontWeight.w700)),
          for (final p in parts) Text(p, style: style),
          if (_host != null && tour == null) TextButton(onPressed: _askTournament, child: const Text('Turnier')),
          TextButton(onPressed: sharedClose, child: const Text('Tisch verlassen')),
        ]),
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
      if (m['t'] == 'tbal') {
        if (_tour != null && _tourBalances.containsKey(s.name)) {
          _tourBalances[s.name] = (m['b'] as num?)?.toInt() ?? 0;
          _broadcastRanking();
        }
      } else if (m['t'] == 'chat') {
        if (quickMessageText(m['m']) == null) return;
        h.lan.broadcast({'t': 'chat', 'from': s.name, 'm': m['m']});
        showQuickMessage(context, s.name, m['m']);
      } else if (m['t'] == 'stake') {
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
        case 'chat':
          final from = '${m['from']}';
          showQuickMessage(context, from == _displayName ? 'Du' : from, m['m']);
        case 'tour':
          _beginTournament((m['chips'] as num).toInt(), (m['rounds'] as num).toInt());
        case 'trank':
          _tourLeft = (m['left'] as num).toInt();
          _tourRounds = (m['rounds'] as num).toInt();
          _tourBalances
            ..clear()
            ..addEntries([for (final e in m['list'] as List) MapEntry('${(e as List)[0]}', (e[1] as num).toInt())]);
          setState(() {});
        case 'tend':
          _finishTournament([for (final e in m['list'] as List) MapEntry('${(e as List)[0]}', (e[1] as num).toInt())]);
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
    _tour?.removeListener(_reportBalance);
    _tour = null;
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
    _tour?.removeListener(_reportBalance);
    _tour = null;
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manual.dispose();
  }
}
