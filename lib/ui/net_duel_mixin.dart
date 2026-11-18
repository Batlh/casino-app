import 'dart:async';

import 'package:flutter/material.dart';

import '../core/debug_log.dart';
import '../core/net/lan.dart';
import '../core/net/lan_table.dart';
import '../core/net/net_duel.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import 'net_panels.dart';
import 'widgets.dart';

/// Zweierspiel im Netz für Brettspiel-Bildschirme: Knopf, Warteraum, Tischsuche und Zugaustausch.
/// Das Spiel ruft [duelSendMove] nach jedem eigenen Zug und setzt [duelStart] und [duelApply] um.
mixin NetDuelScreen<T extends StatefulWidget> on State<T> {
  /// Kennung im Netz, z. B. 'reversi'.
  String get duelGame;

  /// Name des Spiels für den Warteraum.
  String get duelTitle;

  /// Namen der beiden Seiten, z. B. Schwarz und Weiß. Seite 0 beginnt.
  List<String> get duelSides;

  /// Neue Partie im Netz: Namen je Platz, dein Platz.
  void duelStart(List<String> names, int mySeat);

  /// Zug der anderen Seite ausführen (auch beim Nachspielen eigener Züge). false, wenn er nicht passt.
  bool duelApply(Object? move);

  NetDuelLink? _link;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manual = TextEditingController();
  bool _panel = false;
  String _netMsg = '';
  String _name = '';
  int _side = 0;

  /// Läuft gerade eine Partie im Netz?
  bool get duelPlaying => _link?.playing ?? false;

  /// Im Netz verbunden (Gastgeber oder Gast), auch vor dem Start.
  bool get duelActive => _link != null;

  /// Dein Platz in der Netzpartie, sonst -1.
  int get duelSeat => _link?.seat ?? -1;

  /// Sitzt auf diesem Platz der Gegner im Netz?
  bool duelRemote(int seat) => duelPlaying && seat != duelSeat;

  bool get _isHost => _link?.host != null;

  void duelSendMove(Object? move) => _link?.sendMove(move);

  /// Knopf für die Titelleiste (nur auf breiten Bildschirmen, sonst ist die Leiste voll).
  List<Widget> duelActions(BuildContext context) => [
        if (!duelActive && !_panel && MediaQuery.sizeOf(context).width >= 420)
          IconButton(tooltip: 'Im Netzwerk spielen', icon: const Icon(Icons.wifi), onPressed: duelOpenPanel),
      ];

  void duelOpenPanel() {
    if (_name.isEmpty) {
      final st = AppScope.of(context).settings;
      _name = '${st.loadGame('netz')?['name'] ?? st.loadGame('poker')?['name'] ?? st.loadGame('bingo')?['name'] ?? ''}';
    }
    setState(() => _panel = true);
  }

  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  /// Knöpfe unter dem Brett im Netz: neue Partie (Gastgeber) und Verlassen.
  List<Widget> duelButtons({required bool over}) => [
        if (_isHost) ActionButton(primary: over, label: 'Neue Partie', onPressed: () => _startGame()),
        ActionButton(label: 'Tisch verlassen', onPressed: duelClose),
      ];

  /// Was statt des Bretts gezeigt wird, solange das Netz eingerichtet wird.
  Widget? duelScreen() {
    final link = _link;
    if (link != null) {
      final g = link.guest;
      if (g != null && (!link.playing || !g.lan.connected)) return NetGuestWaiting(guest: g, onLeave: duelClose, message: _netMsg);
      final h = link.host;
      if (h != null && !link.playing) return _hostLobby(h);
      return null;
    }
    if (_browser != null) {
      return NetBrowsePanel(tables: _tables, manual: _manual, onJoin: _join, onBack: duelClose, message: _netMsg);
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
        message: _netMsg,
        hint: 'Beide Geräte im selben WLAN. Im Netz gibt es keine Münzen, es geht um die Ehre.',
      );
    }
    return null;
  }

  Widget _hostLobby(NetTableHost h) {
    final style = TextStyle(color: Palette.of(context).onFelt, fontSize: 16);
    final opponent = h.seats.values.firstOrNull;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Dein Tisch ist offen', textAlign: TextAlign.center, style: style.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(h.info, textAlign: TextAlign.center, style: style),
            Text('Von Hand beitreten: ${_addresses.isEmpty ? '–' : _addresses.map((a) => '$a:${h.lan.port}').join(' oder ')}',
                textAlign: TextAlign.center, style: style.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            Text(opponent == null ? 'Warte auf einen Gegner …' : 'Gegner: ${opponent.name}', textAlign: TextAlign.center, style: style),
            const SizedBox(height: 12),
            Text('Deine Seite', textAlign: TextAlign.center, style: style.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
              ChoiceChip(label: Text('${duelSides[0]} (beginnt)'), selected: _side == 0, onSelected: (_) => setState(() => _side = 0)),
              ChoiceChip(label: Text(duelSides[1]), selected: _side == 1, onSelected: (_) => setState(() => _side = 1)),
              ChoiceChip(label: const Text('Zufällig'), selected: _side == 2, onSelected: (_) => setState(() => _side = 2)),
            ]),
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              ActionButton(primary: true, label: 'Partie starten', onPressed: opponent == null ? null : _startGame),
              ActionButton(label: 'Tisch schließen', onPressed: duelClose),
            ]),
          ]),
        ),
      ),
    );
  }

  void _startGame() {
    _link?.start(_displayName, _side);
  }

  void _wire(NetDuelLink link) {
    link
      ..onStart = (names, seat) {
        if (!mounted) return;
        setState(() => _netMsg = '');
        duelStart(names, seat);
      }
      ..onMove = (m) => mounted && duelApply(m)
      ..onGone = () {
        if (mounted) setState(() => _netMsg = 'Der Gegner hat den Tisch verlassen');
      };
    link.attach();
  }

  Future<void> _openTable() async {
    final host = NetTableHost(game: duelGame, hostName: _displayName, info: duelTitle);
    try {
      await host.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _netMsg = 'Tisch konnte nicht eröffnet werden');
      await host.close();
      return;
    }
    _addresses = await localAddresses();
    final link = NetDuelLink.host(host);
    _wire(link);
    _sub = host.changed.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _link = link;
      _netMsg = '';
    });
  }

  Future<void> _browse() async {
    final b = LanBrowser(duelGame);
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _netMsg = '';
    });
  }

  Future<void> _join(String address, int port) async {
    final guest = NetTableGuest(_displayName);
    final link = NetDuelLink.guest(guest);
    _wire(link);
    try {
      await guest.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _netMsg = 'Tisch nicht erreichbar');
      await guest.close();
      return;
    }
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    _sub = guest.changed.listen((_) {
      if (!mounted) return;
      if (!guest.lan.connected) _netMsg = 'Der Gastgeber hat den Tisch geschlossen';
      setState(() {});
    });
    setState(() {
      _link = link;
      _netMsg = '';
    });
  }

  /// Netz beenden; danach ruft das Spiel selbst eine neue Partie auf, falls nötig.
  Future<void> duelClose() async {
    await _sub?.cancel();
    _sub = null;
    await _link?.close();
    await _browser?.close();
    if (!mounted) return;
    setState(() {
      _link = null;
      _browser = null;
      _panel = false;
      _netMsg = '';
    });
    duelClosed();
  }

  /// Nach dem Verlassen des Netzes (z. B. neue Partie gegen den Computer).
  void duelClosed() {}

  void duelDispose() {
    _sub?.cancel();
    _link?.close();
    _browser?.close();
    _manual.dispose();
  }
}
