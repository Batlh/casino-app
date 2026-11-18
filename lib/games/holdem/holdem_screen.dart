import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/net/lan.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import 'holdem_engine.dart';
import 'holdem_net.dart';

class HoldemTable {
  const HoldemTable(this.name, this.smallBlind, this.bigBlind, this.buyIn);
  final String name;
  final int smallBlind;
  final int bigBlind;
  final int buyIn;
}

const holdemTables = [
  HoldemTable('Kleiner Tisch', 5, 10, 1000),
  HoldemTable('Mittlerer Tisch', 25, 50, 5000),
  HoldemTable('Hoher Tisch', 100, 200, 20000),
];

const _botNames = [
  'Helga',
  'Otto',
  'Bärbel',
  'Klaus',
  'Rosi',
  'Horst',
  'Inge',
  'Dieter',
  'Gisela',
  'Manni',
];

class HoldemScreen extends StatefulWidget {
  const HoldemScreen({super.key, this.omaha = false, this.draw = false});

  /// Omaha statt Texas Hold'em.
  final bool omaha;

  /// Five Card Draw: fünf Karten, einmal tauschen, kein Tisch.
  final bool draw;

  @override
  State<HoldemScreen> createState() => _HoldemScreenState();
}

class _HoldemScreenState extends State<HoldemScreen> {
  final _rng = math.Random.secure();
  late final Wallet _wallet = AppScope.of(context).wallet;
  HoldemEngine? _engine;
  HoldemTable _table = holdemTables.first;
  int _opponents = 4;
  int _raiseTo = 0;
  bool _botRunning = false;
  int _handNumber = 0;
  String _message = '';
  bool _big = false;
  int _botNameCursor = 0;

  /// Five Card Draw: Stellen der Karten, die du ablegen willst.
  final Set<int> _discard = {};

  // Netzwerk
  String _name = '';
  HoldemHost? _host;
  HoldemGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manualAddress = TextEditingController();
  int _netBots = 2;

  /// Als Mitspieler: Chips schon zurück ins Münzkonto gebucht.
  bool _guestPaidOut = false;
  bool _rebuyAsked = false;
  String _guestTurnKey = '';

  AppScope get _app => AppScope.of(context);
  HoldemPlayer? get _me => _engine?.human;
  String get _gameId => holdemNetGame(omaha: widget.omaha, draw: widget.draw);
  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet; // Beim ersten Aufbau festhalten, in dispose gibt es keinen Kontext mehr
    if (_name.isEmpty) {
      final s = AppScope.of(context).settings;
      _name = '${s.loadGame('poker')?['name'] ?? s.loadGame('bingo')?['name'] ?? ''}';
    }
  }

  @override
  void dispose() {
    final me = _me;
    if (me != null) {
      // Laufende Einsätze sind verloren, der Rest geht zurück ins Münzkonto
      _wallet.credit(me.stack);
      _wallet.refillIfBroke();
    }
    _guestPayOut();
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manualAddress.dispose();
    super.dispose();
  }

  void _saveName(String v) {
    _name = v;
    AppScope.of(context).settings.saveGame('poker', {'name': v});
  }

  HoldemPlayer _newBot(int stack) {
    final name = _botNames[_botNameCursor % _botNames.length];
    _botNameCursor++;
    final style = BotStyle.all[_rng.nextInt(BotStyle.all.length)];
    return HoldemPlayer(name, stack, style: style);
  }

  void _sit() {
    if (!_wallet.spend(_table.buyIn)) return;
    _botNameCursor = _rng.nextInt(_botNames.length);
    final players = [
      HoldemPlayer('Du', _table.buyIn, isHuman: true),
      for (var i = 0; i < _opponents; i++) _newBot(_table.buyIn),
    ];
    setState(() {
      _engine = HoldemEngine(
        players: players,
        smallBlind: _table.smallBlind,
        bigBlind: _table.bigBlind,
        omaha: widget.omaha,
        draw: widget.draw,
      );
    });
    _nextHand();
  }

  void _nextHand() {
    final e = _engine!;
    final host = _host;
    if (host != null) _hostSeats(e, host);
    // Ausgeschiedene Gegner werden durch neue ersetzt
    for (var i = 0; i < e.players.length; i++) {
      final p = e.players[i];
      if (!p.isHuman && !p.remote && p.stack == 0) {
        final fresh = _newBot(_table.buyIn);
        p
          ..name = fresh.name
          ..style = fresh.style
          ..stack = fresh.stack;
      }
    }
    if (e.players.where((p) => p.stack > 0).length < 2) {
      setState(() => _message = 'Zu wenige Spieler mit Chips');
      return;
    }
    e.startHand();
    _app.sfx.play(Sound.card);
    setState(() {
      _handNumber++;
      _discard.clear();
      _message = '';
      _big = false;
      _prepareRaise();
    });
    _publish();
    _pump();
  }

  void _prepareRaise() {
    final e = _engine!;
    if (e.handOver || e.drawing) return;
    if (e.actor.isHuman) _raiseTo = e.minRaiseTo;
  }

  /// Lässt Gegner spielen, bis du dran bist oder die Hand endet.
  Future<void> _pump() async {
    if (_botRunning) return;
    _botRunning = true;
    final e = _engine!;
    while (mounted && _engine == e && !e.handOver && !e.actor.isHuman) {
      final a = e.actor;
      // Mitspieler im Netz ziehen selbst; wer gegangen ist, passt
      if (a.remote && !a.left) break;
      await Future<void>.delayed(a.left ? const Duration(milliseconds: 300) : _app.settings.botDelay(750));
      if (!mounted || _engine != e || e.handOver || e.actor != a) break;
      final street = e.street;
      if (e.drawing) {
        e.discard(a.left ? const <int>[] : drawDiscards(a.hole));
        _app.sfx.play(Sound.card);
      } else {
        e.apply(a.left ? (e.toCall == 0 ? HoldemAction.check : HoldemAction.fold) : botDecide(e, _rng));
        _app.sfx.play(Sound.chip);
        if (e.street != street) _app.sfx.play(Sound.card);
      }
      setState(_prepareRaise);
      _publish();
    }
    _botRunning = false;
    if (mounted && e.handOver) _finishHand();
  }

  void _act(HoldemAction action) {
    final guest = _guest;
    if (guest != null) {
      final e = guest.engine;
      if (e == null || e.handOver || !e.actor.isHuman) return;
      guest.act(action);
      _app.sfx.play(action.kind == HoldemActionKind.fold ? Sound.card : Sound.chip);
      return;
    }
    final e = _engine!;
    if (e.handOver || !e.actor.isHuman) return;
    final street = e.street;
    e.apply(action);
    _app.sfx.play(action.kind == HoldemActionKind.fold ? Sound.card : Sound.chip);
    if (e.street != street) _app.sfx.play(Sound.card);
    setState(_prepareRaise);
    _publish();
    if (e.handOver) {
      _finishHand();
    } else {
      _pump();
    }
  }

  /// Five Card Draw: deine markierten Karten ablegen und neue ziehen.
  void _swap() {
    final guest = _guest;
    if (guest != null) {
      final e = guest.engine;
      if (e == null || !e.drawing || !e.actor.isHuman) return;
      guest.discard(_discard);
      _app.sfx.play(Sound.card);
      setState(_discard.clear);
      return;
    }
    final e = _engine!;
    if (!e.drawing || !e.actor.isHuman) return;
    e.discard(_discard);
    _app.sfx.play(Sound.card);
    setState(() {
      _discard.clear();
      _prepareRaise();
    });
    _publish();
    if (e.handOver) {
      _finishHand();
    } else {
      _pump();
    }
  }

  void _toggleDiscard(int i) {
    final e = _guest?.engine ?? _engine!;
    if (!e.drawing || !e.actor.isHuman) return;
    setState(() => _discard.contains(i) ? _discard.remove(i) : _discard.add(i));
  }

  void _finishHand([HoldemEngine? mirror]) {
    final e = mirror ?? _engine!;
    final parts = <String>[];
    for (final r in e.results) {
      final who = r.winners.map((w) => w.isHuman ? 'Du' : w.name).join(' und ');
      final hand = r.value == null ? '' : ' mit ${handName(r.value!)}';
      final verb = r.winners.length == 1 && r.winners.first.isHuman
          ? 'gewinnst'
          : r.winners.length == 1
              ? 'gewinnt'
              : 'teilen';
      parts.add('$who $verb ${formatCoins(r.amount)}$hand');
    }
    final iWon = e.results.any((r) => r.winners.any((w) => w.isHuman));
    setState(() {
      _message = parts.join('. ');
      _big = false;
    });
    _app.sfx.play(iWon ? Sound.win : Sound.lose);
    if (mirror == null) _publish();
  }

  void _rebuy() {
    final guest = _guest;
    if (guest != null) {
      if (_rebuyAsked || !_wallet.spend(guest.buyIn)) return;
      guest.rebuy();
      setState(() => _rebuyAsked = true);
      return;
    }
    final me = _me!;
    if (!_wallet.spend(_table.buyIn)) return;
    setState(() => me.stack = _table.buyIn);
    _nextHand();
  }

  void _leave() {
    if (_guest != null) {
      _closeNet();
      return;
    }
    final me = _me;
    if (me == null) return;
    _wallet.credit(me.stack);
    setState(() {
      me.stack = 0;
      _engine = null;
      _message = '';
    });
    _wallet.refillIfBroke();
    if (_host != null) _closeNet();
  }

  // ---------------------------------------------------------------- Netzwerk: Gastgeber

  void _publish() {
    final e = _engine;
    if (e != null) _host?.publish(e, _handNumber);
  }

  Future<void> _openTable() async {
    final t = _table;
    final host = HoldemHost(
      hostName: _displayName,
      omaha: widget.omaha,
      draw: widget.draw,
      buyIn: t.buyIn,
      info: '${t.name} · Blinds ${t.smallBlind}/${t.bigBlind} · Einstieg ${formatCoins(t.buyIn)}',
    );
    host.onMove = _remoteMove;
    host.onLeave = _remoteLeft;
    try {
      await host.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _message = 'Tisch konnte nicht eröffnet werden');
      await host.close();
      return;
    }
    _addresses = await localAddresses();
    _sub = host.changed.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _host = host;
      _message = '';
    });
  }

  /// Startet das Spiel am eigenen Tisch: du, alle Mitspieler, dazu Computer bis zur gewählten Zahl.
  void _hostStart() {
    final host = _host!;
    if (!_wallet.spend(_table.buyIn)) return;
    _botNameCursor = _rng.nextInt(_botNames.length);
    final guests = host.seats.values.take(5).toList();
    final players = [HoldemPlayer(_displayName, _table.buyIn, isHuman: true)];
    for (final s in guests) {
      final p = HoldemPlayer(s.name, _table.buyIn)..remote = true;
      host.seat(s, p);
      players.add(p);
    }
    for (var i = 0; i < math.min(_netBots, 6 - players.length); i++) {
      players.add(_newBot(_table.buyIn));
    }
    debugLog.info('netz', 'Poker ($_gameId) startet mit ${guests.length} Mitspielern und ${players.length - guests.length - 1} Computern');
    setState(() {
      _engine = HoldemEngine(
        players: players,
        smallBlind: _table.smallBlind,
        bigBlind: _table.bigBlind,
        omaha: widget.omaha,
        draw: widget.draw,
      );
    });
    _nextHand();
  }

  /// Zwischen zwei Händen: Gegangene durch Computer ersetzen, Nachkäufe, neue Mitspieler auf freie Plätze.
  void _hostSeats(HoldemEngine e, HoldemHost host) {
    for (final p in e.players) {
      if (p.remote && p.left) {
        final fresh = _newBot(_table.buyIn);
        p
          ..remote = false
          ..left = false
          ..name = fresh.name
          ..style = fresh.style
          ..stack = fresh.stack;
      }
    }
    for (final s in host.seats.values) {
      final p = s.player;
      if (p != null && s.rebuy) {
        if (p.stack == 0) p.stack = _table.buyIn;
        s.rebuy = false;
      }
      if (p == null) {
        // Neuer Mitspieler übernimmt den Platz eines Computers, sonst einen neuen Platz bis sechs
        final bot = e.players.where((q) => !q.isHuman && !q.remote).firstOrNull;
        if (bot != null) {
          bot
            ..name = s.name
            ..style = null
            ..remote = true
            ..stack = _table.buyIn;
          host.seat(s, bot);
        } else if (e.players.length < 6) {
          final q = HoldemPlayer(s.name, _table.buyIn)..remote = true;
          e.players.add(q);
          host.seat(s, q);
        }
      }
    }
  }

  void _remoteMove(HoldemSeat seat, LanMessage m) {
    final e = _engine;
    final p = seat.player;
    if (e == null || p == null || e.handOver || e.actor != p) return;
    if ((m['hand'] as num?)?.toInt() != _handNumber) return;
    final street = e.street;
    try {
      if (m['t'] == 'discard') {
        if (!e.drawing) return;
        final cards = {for (final c in m['cards'] as List) (c as num).toInt()}.where((c) => c >= 0 && c < p.hole.length);
        e.discard(cards);
        _app.sfx.play(Sound.card);
      } else {
        final a = holdemActionOf(m);
        if (a == null || e.drawing) return;
        if (a.kind == HoldemActionKind.check && e.toCall > 0) return;
        if (a.kind == HoldemActionKind.raise && !e.canRaise) return;
        e.apply(a);
        _app.sfx.play(a.kind == HoldemActionKind.fold ? Sound.card : Sound.chip);
      }
    } catch (err) {
      debugLog.warn('netz', 'Ungültiger Zug von ${seat.name}: $err');
      return;
    }
    if (e.street != street) _app.sfx.play(Sound.card);
    if (!mounted) return;
    setState(_prepareRaise);
    _publish();
    if (e.handOver) {
      _finishHand();
    } else {
      _pump();
    }
  }

  void _remoteLeft(HoldemSeat seat) {
    final p = seat.player;
    if (p == null) return;
    p.left = true;
    debugLog.info('netz', '${seat.name} hat den Tisch verlassen');
    final e = _engine;
    if (e != null && !e.handOver && e.actor == p) _pump();
    if (mounted) setState(() {});
  }

  Future<void> _closeNet() async {
    _guestPayOut();
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
      _message = '';
    });
  }

  // ---------------------------------------------------------------- Netzwerk: Mitspieler

  Future<void> _browse() async {
    final b = LanBrowser(_gameId);
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _message = '';
    });
  }

  Future<void> _join(String address, int port) async {
    final guest = HoldemGuest(_displayName);
    guest.onSeat = (cost) {
      if (!_wallet.spend(cost)) {
        if (mounted) setState(() => _message = 'Nicht genug Münzen für den Einstieg');
        return false;
      }
      _guestPaidOut = false;
      return true;
    };
    try {
      await guest.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _message = 'Tisch nicht erreichbar');
      await guest.close();
      return;
    }
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    var wasOver = true;
    var lastHand = 0;
    _sub = guest.changed.listen((_) {
      if (!mounted) return;
      final e = guest.engine;
      if (e != null) {
        if (guest.hand != lastHand) {
          lastHand = guest.hand;
          _handNumber = guest.hand;
          _discard.clear();
          _message = '';
          _rebuyAsked = false;
          _app.sfx.play(Sound.card);
        }
        if (e.handOver && !wasOver) _finishHand(e);
        wasOver = e.handOver;
        // Regler für das Erhöhen erst setzen, wenn du neu dran bist
        final key = '${guest.hand}-${e.street.name}-${e.toAct}';
        if (!e.handOver && !e.drawing && e.actor.isHuman && key != _guestTurnKey) {
          _guestTurnKey = key;
          _raiseTo = e.minRaiseTo;
        }
      }
      if (!guest.lan.connected) {
        _guestPayOut();
        _message = 'Der Gastgeber hat den Tisch geschlossen';
      }
      setState(() {});
    });
    setState(() {
      _guest = guest;
      _message = '';
    });
  }

  /// Chips des Mitspielers zurück ins Münzkonto (einmal, beim Gehen oder wenn der Tisch schließt).
  void _guestPayOut() {
    final guest = _guest;
    if (guest == null || _guestPaidOut || !guest.seated) return;
    _guestPaidOut = true;
    final me = guest.engine?.human;
    // Ohne Sicht hat noch keine Hand begonnen: der volle Einstieg kommt zurück
    final chips = (me == null ? guest.buyIn : me.stack) + (_rebuyAsked ? guest.buyIn : 0);
    _wallet.credit(chips);
    _wallet.refillIfBroke();
    debugLog.info('netz', 'Poker verlassen, $chips Chips zurück');
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    return GameFrame(
      guide: widget.draw ? fiveCardDrawGuide : (widget.omaha ? omahaGuide : holdemGuide),
      title: widget.draw ? 'Five Card Draw' : (widget.omaha ? 'Omaha' : "Texas Hold'em"),
      child: _guest != null
          ? _guestView()
          : _browser != null
              ? _browseView()
              : e == null
                  ? (_host != null ? _hostLobby() : _lobby())
                  : _tableView(e),
    );
  }

  Widget _lobby() {
    final p = Palette.of(context);
    final style = TextStyle(color: p.onFelt, fontSize: 17);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListenableBuilder(
            listenable: _wallet,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No-Limit gegen Computer-Gegner',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                for (final t in holdemTables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TableChoice(
                      table: t,
                      selected: t == _table,
                      enabled: _wallet.canAfford(t.buyIn),
                      onTap: () => setState(() => _table = t),
                    ),
                  ),
                const SizedBox(height: 10),
                Text('Gegner am Tisch', textAlign: TextAlign.center, style: style),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (var n = 1; n <= 5; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: n == _opponents,
                        onSelected: (_) => setState(() => _opponents = n),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: ActionButton(
                    primary: true,
                    label: 'Hinsetzen: ${formatCoins(_table.buyIn)}',
                    onPressed: _wallet.canAfford(_table.buyIn) ? _sit : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Beim Verlassen des Tisches kommen deine Chips zurück ins Münzkonto.',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 18),
                Text('Im lokalen Netzwerk', textAlign: TextAlign.center, style: style.copyWith(fontWeight: FontWeight.w700)),
                TextFormField(
                  initialValue: _name,
                  maxLength: 16,
                  decoration: const InputDecoration(labelText: 'Dein Name am Tisch', counterText: ''),
                  onChanged: _saveName,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionButton(label: 'Tisch eröffnen', onPressed: _openTable),
                    ActionButton(label: 'Tisch beitreten', onPressed: _browse),
                  ],
                ),
                if (_message.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message, textAlign: TextAlign.center, style: style)),
                const SizedBox(height: 6),
                Text(
                  'Alle Geräte im selben WLAN. Der gewählte Tisch oben gilt für alle; freie Plätze füllen Computer.',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _netPanel(List<Widget> children) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );

  TextStyle get _netStyle => TextStyle(color: Palette.of(context).onFelt, fontSize: 16);

  Widget _hostLobby() {
    final host = _host!;
    final style = _netStyle;
    final guests = host.seats.length;
    final maxBots = math.max(0, 5 - guests);
    return _netPanel([
      Text('Dein Tisch ist offen', textAlign: TextAlign.center, style: style.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(host.info, textAlign: TextAlign.center, style: style),
      Text('Von Hand beitreten: ${_addresses.isEmpty ? '–' : _addresses.map((a) => '$a:${host.lan.port}').join(' oder ')}',
          textAlign: TextAlign.center, style: style.copyWith(fontSize: 14)),
      const SizedBox(height: 12),
      Text('Am Tisch', style: style.copyWith(fontWeight: FontWeight.w700)),
      Text('• $_displayName (du)', style: style),
      for (final s in host.seats.values) Text('• ${s.name}', style: style),
      const SizedBox(height: 12),
      Text('Computer-Gegner dazu', style: style.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (var n = 0; n <= maxBots; n++)
            ChoiceChip(label: Text('$n'), selected: math.min(_netBots, maxBots) == n, onSelected: (_) => setState(() => _netBots = n)),
        ],
      ),
      const SizedBox(height: 14),
      Center(
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          ActionButton(
            primary: true,
            label: 'Spiel starten: ${formatCoins(_table.buyIn)}',
            onPressed: _wallet.canAfford(_table.buyIn) && (guests > 0 || _netBots > 0) ? _hostStart : null,
          ),
          ActionButton(label: 'Tisch schließen', onPressed: _closeNet),
        ]),
      ),
      const SizedBox(height: 8),
      Text('Wer später beitritt, übernimmt ab der nächsten Hand den Platz eines Computers.',
          textAlign: TextAlign.center, style: style.copyWith(fontSize: 14)),
    ]);
  }

  Widget _browseView() {
    final style = _netStyle;
    return _netPanel([
      Text('Offene Tische', textAlign: TextAlign.center, style: style.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (_tables.isEmpty)
        Text('Suche im WLAN …', textAlign: TextAlign.center, style: style)
      else
        for (final t in _tables)
          Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text('${t.info}\n${t.address}'),
              isThreeLine: true,
              trailing: const Icon(Icons.login),
              onTap: () => _join(t.address, t.port),
            ),
          ),
      const SizedBox(height: 12),
      TextField(
        controller: _manualAddress,
        decoration: const InputDecoration(labelText: 'Von Hand: Adresse:Port, z. B. 192.168.1.20:41234'),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 10),
      Center(
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          ActionButton(
            label: 'Verbinden',
            onPressed: () {
              final parts = _manualAddress.text.trim().split(':');
              final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
              if (port != null) _join(parts[0], port);
            },
          ),
          ActionButton(label: 'Zurück', onPressed: _closeNet),
        ]),
      ),
      if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message, textAlign: TextAlign.center, style: style)),
    ]);
  }

  Widget _guestView() {
    final guest = _guest!;
    final style = _netStyle;
    final e = guest.engine;
    if (!guest.lan.connected) {
      return _netPanel([
        Text(_message.isEmpty ? 'Verbindung beendet' : _message, textAlign: TextAlign.center, style: style.copyWith(fontSize: 18)),
        const SizedBox(height: 12),
        Center(child: ActionButton(primary: true, label: 'Zurück', onPressed: _closeNet)),
      ]);
    }
    if (e == null) {
      return _netPanel([
        Text(guest.info.isEmpty ? 'Verbunden' : guest.info, textAlign: TextAlign.center, style: style.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Am Tisch', style: style.copyWith(fontWeight: FontWeight.w700)),
        for (final p in guest.lobby) Text('• $p', style: style),
        const SizedBox(height: 12),
        Text(
          guest.seated ? 'Einstieg bezahlt, gleich geht es los …' : 'Warte, bis der Gastgeber das Spiel startet …',
          textAlign: TextAlign.center,
          style: style,
        ),
        if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message, textAlign: TextAlign.center, style: style)),
        const SizedBox(height: 12),
        Center(child: ActionButton(label: 'Tisch verlassen', onPressed: _closeNet)),
      ]);
    }
    return _tableView(e);
  }

  Widget _tableView(HoldemEngine e) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.2;
        final controls = _controls(e);
        final table = _Felt(engine: e, handNumber: _handNumber, discard: _discard, onTapCard: _toggleDiscard);
        if (wide) {
          return Row(
            children: [
              Expanded(child: table),
              SizedBox(
                width: math.min(300, box.maxWidth * 0.34),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: controls,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: table),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: controls,
            ),
          ],
        );
      },
    );
  }

  Widget _controls(HoldemEngine e) {
    final me = e.human!;
    final myTurn = !e.handOver && e.actor.isHuman;
    final p = Palette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _big ? const Color(0xFFFFC95C) : p.onFelt,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.2,
              ),
            ),
          ),
        if (e.handOver)
          ..._betweenHands(e, me)
        else if (e.drawing)
          ..._drawButtons(e, myTurn)
        else
          ..._turnButtons(e, myTurn),
      ],
    );
  }

  List<Widget> _betweenHands(HoldemEngine e, HoldemPlayer me) {
    final guest = _guest;
    if (guest != null) {
      return [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (me.stack == 0)
              ActionButton(
                primary: true,
                label: _rebuyAsked ? 'Nachkauf angemeldet' : 'Nachkaufen: ${formatCoins(guest.buyIn)}',
                onPressed: !_rebuyAsked && _wallet.canAfford(guest.buyIn) ? _rebuy : null,
              )
            else
              const ActionButton(label: 'Warte auf den Gastgeber', onPressed: null),
            ActionButton(label: 'Tisch verlassen', onPressed: _leave),
          ],
        ),
      ];
    }
    final othersHaveChips = e.players.any((p) => !p.isHuman);
    return [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (me.stack > 0 && othersHaveChips)
            ActionButton(primary: true, label: 'Nächste Hand', onPressed: _nextHand)
          else
            ActionButton(
              primary: true,
              label: 'Nachkaufen: ${formatCoins(_table.buyIn)}',
              onPressed: _wallet.canAfford(_table.buyIn) ? _rebuy : null,
            ),
          ActionButton(label: 'Tisch verlassen', onPressed: _leave),
        ],
      ),
    ];
  }

  List<Widget> _drawButtons(HoldemEngine e, bool myTurn) {
    final p = Palette.of(context);
    final n = _discard.length;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          myTurn
              ? 'Tippe die Karten an, die du ablegen willst.'
              : (e.human!.drew == null ? 'Die anderen tauschen …' : 'Du hast getauscht, die anderen sind dran.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: p.onFelt, fontSize: 15),
        ),
      ),
      ActionButton(
        primary: true,
        label: !myTurn
            ? 'Warten'
            : n == 0
                ? 'Alle behalten'
                : 'Tauschen: $n ${n == 1 ? 'Karte' : 'Karten'}',
        onPressed: myTurn ? _swap : null,
      ),
    ];
  }

  List<Widget> _turnButtons(HoldemEngine e, bool myTurn) {
    final p = Palette.of(context);
    final call = myTurn ? e.toCall : 0;
    final me = e.human!;
    final callLabel = !myTurn
        ? 'Warten'
        : call == 0
            ? 'Schieben'
            : call >= me.stack
                ? 'All-in: ${formatCoins(me.stack)}'
                : 'Mitgehen: ${formatCoins(call)}';
    final canRaise = myTurn && e.canRaise;
    final minTo = canRaise ? e.minRaiseTo : 0;
    final maxTo = canRaise ? e.maxRaiseTo : 1;
    final value = canRaise ? _raiseTo.clamp(minTo, maxTo) : 0;
    return [
      if (canRaise && maxTo > minTo)
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: minTo.toDouble(),
                max: maxTo.toDouble(),
                activeColor: p.accent,
                onChanged: (v) {
                  final step = e.smallBlind;
                  final snapped = ((v / step).round() * step).clamp(minTo, maxTo);
                  setState(() => _raiseTo = snapped);
                },
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _raiseTo = maxTo),
              child: Text(
                'Alles',
                style: TextStyle(color: p.onFelt, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionButton(
            label: 'Passen',
            onPressed: myTurn && call > 0 ? () => _act(HoldemAction.fold) : null,
          ),
          ActionButton(
            label: callLabel,
            onPressed: myTurn
                ? () => _act(call == 0 ? HoldemAction.check : HoldemAction.call)
                : null,
          ),
          ActionButton(
            primary: true,
            label: canRaise
                ? (value >= maxTo
                    ? 'All-in'
                    : e.currentBet == 0
                        ? 'Setzen: ${formatCoins(value)}'
                        : 'Erhöhen auf ${formatCoins(value)}')
                : 'Erhöhen',
            onPressed: canRaise
                ? () => _act(HoldemAction(HoldemActionKind.raise, value))
                : null,
          ),
        ],
      ),
    ];
  }
}

class _TableChoice extends StatelessWidget {
  const _TableChoice({
    required this.table,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final HoldemTable table;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? p.accent : p.panel,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.name,
                  style: TextStyle(
                    color: selected ? p.onAccent : p.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Blinds ${table.smallBlind}/${table.bigBlind}, Einstieg ${formatCoins(table.buyIn)}',
                  style: TextStyle(
                    color: selected ? p.onAccent : p.inkSoft,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ovaler Tisch mit Sitzen, Gemeinschaftskarten und Pot.
class _Felt extends StatelessWidget {
  const _Felt({required this.engine, required this.handNumber, required this.discard, required this.onTapCard});
  final HoldemEngine engine;
  final int handNumber;
  final Set<int> discard;
  final void Function(int) onTapCard;

  String _phase(HoldemEngine e) => switch (e.street) {
        HoldemStreet.preflop => 'Erste Setzrunde',
        HoldemStreet.draw => 'Tauschen',
        HoldemStreet.river => 'Zweite Setzrunde',
        _ => '',
      };

  /// Five Card Draw: deine Hand groß in der Tischmitte, antippen markiert zum Ablegen.
  Widget _myHand(HoldemEngine e, double cardW) {
    final me = e.human!;
    final tappable = e.drawing && e.actor.isHuman;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < me.hole.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              key: ValueKey('hand-$i'),
              onTap: tappable ? () => onTapCard(i) : null,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                offset: Offset(0, discard.contains(i) ? -0.14 : 0),
                child: Opacity(
                  opacity: me.folded ? 0.5 : (discard.contains(i) ? 0.55 : 1),
                  child: DealIn(
                    key: ValueKey('$handNumber-m$i-${me.hole[i].rank}-${me.hole[i].suit.index}'),
                    child: PlayingCardView(width: cardW, card: me.hole[i], highlighted: discard.contains(i)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final seats = e.players.length;
        final seatWidth = math.min(112.0, math.max(84.0, w / 4.4));
        final seatHeight = seatWidth * 0.36 + 62;
        final rx = (w - seatWidth) / 2;
        final ry = (h - seatHeight) / 2;
        final cardW = math.min((w * 0.52 - 16) / 5, h * 0.095).clamp(30.0, 76.0);
        final handW = math.min((w * 0.62 - 30) / 5, h * 0.11).clamp(34.0, 90.0);
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _TablePainter())),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pot ${formatCoins(e.pot)}',
                    style: const TextStyle(
                      color: Color(0xFFFFE9A8),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if (e.draw && !e.handOver)
                    Text(_phase(e), style: const TextStyle(color: Color(0xFFCDB48C), fontSize: 14)),
                  const SizedBox(height: 6),
                  if (e.draw && e.human!.hole.isNotEmpty)
                    _myHand(e, handW)
                  else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: i < e.board.length
                              ? DealIn(
                                  key: ValueKey('$handNumber-b$i'),
                                  child: PlayingCardView(
                                    width: cardW,
                                    card: e.board[i],
                                  ),
                                )
                              : Container(
                                  width: cardW,
                                  height: cardW / cardAspect,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0x33FFFFFF)),
                                    borderRadius: BorderRadius.circular(cardW * 0.09),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < seats; i++)
              _positioned(
                i,
                seats,
                rx,
                ry,
                seatWidth,
                seatHeight,
                _Seat(
                  player: e.players[i],
                  acting: !e.handOver && e.toAct == i,
                  dealer: e.dealer == i,
                  hideCards: e.draw && e.players[i].isHuman,
                  reveal: e.players[i].isHuman ||
                      (e.handOver && e.players[i].shownValue != null),
                  width: seatWidth,
                  handNumber: handNumber,
                  seat: i,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positioned(
    int i,
    int seats,
    double rx,
    double ry,
    double seatW,
    double seatH,
    Widget child,
  ) {
    // Sitz 0 unten in der Mitte, die anderen im Uhrzeigersinn
    final angle = math.pi / 2 + i * 2 * math.pi / seats;
    // Dein Platz zeigt die Karten ganz und braucht mehr Höhe
    final height = i == 0 ? seatW * 0.66 + 62 : seatH;
    return Positioned(
      left: rx + rx * math.cos(angle),
      top: ry + ry * math.sin(angle) + seatH - height,
      width: seatW,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: seatW, child: child),
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(math.min(size.shortestSide * 0.1, 44));
    canvas.drawPath(_stadium(rect.inflate(8)), Paint()..color = const Color(0xFF5A3218));
    canvas.drawPath(
      _stadium(rect),
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [Color(0xFF1B7A63), Color(0xFF0C4A3D)],
        ).createShader(rect),
    );
  }

  /// Als Vieleck, weil abgerundete Rechtecke dieser Größe mit Impeller fehlten.
  Path _stadium(Rect r) {
    final radius = r.shortestSide / 2;
    final centers = [
      Offset(r.right - radius, r.top + radius),
      Offset(r.right - radius, r.bottom - radius),
      Offset(r.left + radius, r.bottom - radius),
      Offset(r.left + radius, r.top + radius),
    ];
    final path = Path();
    for (var corner = 0; corner < 4; corner++) {
      for (var i = 0; i <= 40; i++) {
        final a = -math.pi / 2 + (corner + i / 40) * math.pi / 2;
        final o = centers[corner] + Offset(math.cos(a), math.sin(a)) * radius;
        if (corner == 0 && i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.player,
    required this.acting,
    required this.dealer,
    required this.reveal,
    required this.width,
    required this.handNumber,
    required this.seat,
    this.hideCards = false,
  });

  /// Five Card Draw: deine Karten liegen groß in der Mitte, nicht am Platz.
  final bool hideCards;
  final HoldemPlayer player;
  final bool acting;
  final bool dealer;
  final bool reveal;
  final double width;
  final int handNumber;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final faded = p.folded || !p.inHand;
    final cardW = width * (p.isHuman ? 0.47 : 0.4);
    final shown = p.isHuman ? 1.0 : 0.62;
    final status = p.shownValue != null
        ? handName(p.shownValue!)
        : p.lastAction.isNotEmpty
            ? p.lastAction
            : (p.style?.label ?? '');
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.inHand && p.hole.isNotEmpty && !hideCards)
            SizedBox(
              height: cardW / cardAspect * shown,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: cardW / cardAspect,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < p.hole.length; i++)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: p.hole.length > 4 ? 0.5 : 1),
                          child: DealIn(
                            key: ValueKey('$handNumber-s$seat-$i-$reveal'),
                            child: PlayingCardView(
                              width: p.hole.length > 4 ? cardW * 0.46 : (p.hole.length > 2 ? cardW * 0.62 : cardW),
                              card: reveal && !p.folded ? p.hole[i] : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xE62A160E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: acting ? const Color(0xFFFFC95C) : const Color(0xFF6B3E1E),
                width: acting ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dealer) ...[
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF6E7C8),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  formatCoins(p.stack),
                  style: const TextStyle(
                    color: Color(0xFFFFC95C),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
                Text(
                  p.streetBet > 0
                      ? 'Einsatz ${formatCoins(p.streetBet)}'
                      : (status.isEmpty ? ' ' : status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCDB48C),
                    fontSize: 13,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
