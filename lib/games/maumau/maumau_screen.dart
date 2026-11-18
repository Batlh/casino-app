import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/net/lan.dart';
import '../../core/net/lan_table.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_panels.dart';
import '../../ui/settings_sheet.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import '../cards/rewards.dart';
import 'maumau_engine.dart';
import 'maumau_net.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const mauRewardPerOpponent = 50;

class MauMauScreen extends StatefulWidget {
  const MauMauScreen({super.key});

  @override
  State<MauMauScreen> createState() => _MauMauScreenState();
}

class _MauMauScreenState extends State<MauMauScreen> {
  final _rng = math.Random.secure();
  int get _opponents => _seats.length - 1;
  int _round = 0;
  late MauMauEngine _e;
  bool _running = false;
  bool _rewarded = false;

  /// Plätze am Tisch; mehrere Menschen geben das Gerät weiter.
  List<Seat> _seats = const [Seat('Du', human: true), Seat('Helga'), Seat('Otto')];

  /// Wessen Hand gezeigt wird, und ob sie gerade verdeckt ist (Gerät wird weitergegeben).
  int _viewer = 0;
  bool _covered = false;

  // Netzwerk
  bool _netPanel = false;
  String _name = '';
  String _netMessage = '';
  NetTableHost? _host;
  NetTableGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  StreamSubscription<Object?>? _sub;
  final _manual = TextEditingController();
  int _netBots = 1;
  bool _netPlaying = false;
  int _botCount = 0;
  List<Seat> _localSeats = const [];

  bool get _net => _host != null || _guest != null;
  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  AppScope get _app => AppScope.of(context);
  int get _humans => _seats.where((s) => s.human).length;
  bool get _myTurn => !_e.finished && _e.actor.human && !_running && !_covered && _e.current == _viewer;

  @override
  void initState() {
    super.initState();
    final saved = AppScope.of(context).settings.loadGame('seats.maumau');
    if (saved != null) {
      try {
        final list = [for (final j in saved['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
        if (list.length >= 2 && list.any((x) => x.human)) _seats = list;
      } catch (_) {
        // Standard behalten
      }
    }
    final s = AppScope.of(context).settings;
    _name = '${s.loadGame('netz')?['name'] ?? s.loadGame('poker')?['name'] ?? s.loadGame('bingo')?['name'] ?? ''}';
    _localSeats = _seats;
    _setup();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manual.dispose();
    super.dispose();
  }

  void _setup() {
    final offset = _rng.nextInt(_names.length);
    var bot = 0;
    _e = MauMauEngine(
      players: [
        for (final seat in _seats)
          seat.human ? MauPlayer(seat.name, human: true) : MauPlayer(_names[(offset + bot++) % _names.length]),
      ],
      rng: _rng,
    )..start(startPlayer: _round % _seats.length);
    _rewarded = false;
    _viewer = _seats.indexWhere((x) => x.human);
    _covered = false;
    _syncViewer();
  }

  /// Ist ein anderer Mensch dran, wird die Hand verdeckt, bis er das Gerät hat.
  void _syncViewer() {
    if (_e.finished || !_e.actor.human || _e.current == _viewer) return;
    _viewer = _e.current;
    _covered = _humans > 1;
  }

  void _newRound() {
    if (_guest != null) return;
    setState(() {
      _round++;
      if (_host != null) {
        _setupNet();
      } else {
        _setup();
      }
    });
    _app.sfx.play(Sound.card);
    _publish();
    _pump();
  }

  Future<void> _askOpponents() async {
    final seats = await showSeatSetup(context, gameId: 'maumau', title: 'Mau Mau', minSeats: 2, maxSeats: 4);
    if (seats == null || !mounted) return;
    _seats = seats;
    _localSeats = seats;
    _newRound();
  }

  Future<void> _play(PlayingCard c) async {
    if (!_myTurn || !_e.canPlay(c)) return;
    Suit? wish;
    if (c.rank == 11 && _e.actor.hand.length > 1) {
      wish = await showSuitPicker(context);
      if (wish == null || !mounted || !_myTurn) return;
    }
    final guest = _guest;
    if (guest != null) {
      guest.send(mauPlayMsg(c, wish, _round));
      _app.sfx.play(Sound.card);
      return;
    }
    _e.play(c, wishSuit: wish);
    _app.sfx.play(Sound.card);
    // „Mau!“: nur noch eine Karte
    if (!_net && !_e.finished && _e.players[_viewer].hand.length == 1 && vsComputer(_seats)) _app.wallet.credit(callReward);
    setState(_syncViewer);
    _publish();
    _after();
  }

  void _draw() {
    if (!_myTurn || _e.drewThisTurn) return;
    final guest = _guest;
    if (guest != null) {
      guest.send(mauDrawMsg(_round));
      _app.sfx.play(Sound.card);
      return;
    }
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(_syncViewer);
    _publish();
    _after();
  }

  void _keep() {
    if (!_myTurn) return;
    final guest = _guest;
    if (guest != null) {
      guest.send(mauKeepMsg(_round));
      return;
    }
    _e.pass();
    setState(_syncViewer);
    _publish();
    _after();
  }

  void _after() {
    if (_e.finished) {
      _finish();
    } else {
      _pump();
    }
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    final e = _e;
    while (mounted && _e == e && !_e.finished && !_e.actor.human) {
      // Mitspieler im Netz ziehen selbst; wer gegangen ist, für den spielt der Computer
      if (_e.actor.remote && !_e.actor.left) break;
      await Future<void>.delayed(_app.settings.botDelay(750));
      if (!mounted || _e != e) break;
      final choice = mauBotChoice(_e, _rng);
      if (choice.card != null) {
        _e.play(choice.card!, wishSuit: choice.wish);
        _app.sfx.play(Sound.card);
        setState(() {});
        _publish();
        continue;
      }
      _e.draw();
      _app.sfx.play(Sound.card);
      setState(() {});
      _publish();
      if (_e.drewThisTurn) {
        await Future<void>.delayed(_app.settings.botDelay(500));
        if (!mounted || _e != e) break;
        final again = mauBotChoice(_e, _rng);
        if (again.card != null) {
          _e.play(again.card!, wishSuit: again.wish);
          _app.sfx.play(Sound.card);
        } else {
          _e.pass();
        }
        setState(() {});
        _publish();
      }
    }
    _running = false;
    if (!mounted) return;
    setState(_syncViewer);
    if (_e.finished) _finish();
  }

  /// Trostpreis: je Gegner mit mehr Karten auf der Hand.
  int get _placeReward => !_net && _humans == 1
      ? placeReward(beatenCount([for (final p in _e.players) p.hand.length], _seats.indexWhere((x) => x.human)))
      : 0;

  /// Münzen gibt es nur gegen den Computer: je Computer-Gegner.
  int get _winReward => mauRewardPerOpponent * (_net ? _botCount : _seats.where((x) => !x.human).length);

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.winner!.human) {
      if (_winReward > 0) _app.wallet.credit(_winReward);
      _app.sfx.play(Sound.win);
    } else {
      if (_placeReward > 0) _app.wallet.credit(_placeReward);
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
    _publish();
  }

  // ---------------------------------------------------------------- Netzwerk: Gastgeber

  void _publish() {
    final host = _host;
    if (host == null || !_netPlaying) return;
    for (final s in host.seats.values) {
      if (s.index >= 0) host.send(s, mauView(_e, s.index, round: _round, bots: _botCount));
    }
  }

  Future<void> _openTable() async {
    final host = NetTableHost(game: mauNetGame, hostName: _displayName, info: 'Mau Mau');
    host.onMove = _remoteMove;
    host.onLeave = _remoteLeft;
    try {
      await host.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _netMessage = 'Tisch konnte nicht eröffnet werden');
      await host.close();
      return;
    }
    _addresses = await localAddresses();
    _sub = host.changed.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _host = host;
      _netMessage = '';
    });
  }

  void _hostStart() {
    final host = _host!;
    final guests = host.seats.values.take(3).toList();
    final bots = math.min(_netBots, 3 - guests.length);
    final offset = _rng.nextInt(_names.length);
    final players = [MauPlayer(_displayName, human: true)];
    for (final g in guests) {
      g.index = players.length;
      players.add(MauPlayer(g.name)..remote = true);
    }
    for (var i = 0; i < bots; i++) {
      players.add(MauPlayer(_names[(offset + i) % _names.length]));
    }
    _botCount = bots;
    debugLog.info('netz', 'Mau Mau startet mit ${guests.length} Mitspielern und $bots Computern');
    setState(() {
      _netPlaying = true;
      _round = 0;
      _startNet(players);
    });
    _app.sfx.play(Sound.card);
    _publish();
    _pump();
  }

  void _startNet(List<MauPlayer> players) {
    _e = MauMauEngine(players: players, rng: _rng)
      ..neutralText = true
      ..start(startPlayer: _round % players.length);
    _seats = [for (final p in players) Seat(p.name, human: p.human)];
    _rewarded = false;
    _viewer = 0;
    _covered = false;
  }

  /// Neue Runde am eigenen Tisch: Gegangene werden Computer, Neue übernehmen einen Computerplatz.
  void _setupNet() {
    final host = _host!;
    final offset = _rng.nextInt(_names.length);
    final players = <MauPlayer>[];
    for (final (i, p) in _e.players.indexed) {
      if (p.remote && p.left) {
        players.add(MauPlayer(_names[(offset + i) % _names.length]));
      } else {
        players.add(MauPlayer(p.name, human: p.human)..remote = p.remote);
      }
    }
    for (final s in host.seats.values.where((s) => s.index < 0)) {
      final bot = players.indexWhere((p) => !p.human && !p.remote);
      if (bot >= 0) {
        players[bot] = MauPlayer(s.name)..remote = true;
        s.index = bot;
      } else if (players.length < 4) {
        s.index = players.length;
        players.add(MauPlayer(s.name)..remote = true);
      }
    }
    _botCount = players.where((p) => !p.human && !p.remote).length;
    _startNet(players);
  }

  void _remoteMove(NetSeat seat, LanMessage m) {
    if (!_netPlaying || seat.index < 0 || (m['round'] as num?)?.toInt() != _round) return;
    if (!mauApplyRemote(_e, seat.index, m)) return;
    _app.sfx.play(Sound.card);
    if (!mounted) return;
    setState(_syncViewer);
    _publish();
    _after();
  }

  void _remoteLeft(NetSeat seat) {
    if (!_netPlaying || seat.index < 0 || seat.index >= _e.players.length) return;
    _e.players[seat.index].left = true;
    if (!_e.finished && _e.current == seat.index) _pump();
    if (mounted) setState(() {});
  }

  Future<void> _closeNet() async {
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
      _netPlaying = false;
      _netPanel = false;
      _netMessage = '';
      _seats = _localSeats;
      _setup();
    });
  }

  // ---------------------------------------------------------------- Netzwerk: Mitspieler

  Future<void> _browse() async {
    final b = LanBrowser(mauNetGame);
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _netMessage = '';
    });
  }

  Future<void> _join(String address, int port) async {
    final guest = NetTableGuest(_displayName);
    try {
      await guest.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _netMessage = 'Tisch nicht erreichbar');
      await guest.close();
      return;
    }
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    var lastRound = -1;
    var lastDiscard = -1;
    _sub = guest.changed.listen((_) {
      if (!mounted) return;
      final v = guest.view;
      if (v != null) {
        final round = (v['round'] as num).toInt();
        final e = mauMirror(v);
        final me = (v['me'] as num).toInt();
        if (round != lastRound) {
          lastRound = round;
          _rewarded = false;
          _app.sfx.play(Sound.card);
        } else if (e.discard.length != lastDiscard) {
          _app.sfx.play(Sound.card);
        }
        lastDiscard = e.discard.length;
        _e = e;
        _round = round;
        _botCount = (v['bots'] as num).toInt();
        _seats = [for (final (i, p) in e.players.indexed) Seat(p.name, human: i == me)];
        _viewer = me;
        _covered = false;
        if (e.finished) _finish();
      }
      if (!guest.lan.connected) _netMessage = 'Der Gastgeber hat den Tisch geschlossen';
      setState(() {});
    });
    setState(() {
      _guest = guest;
      _netMessage = '';
    });
  }

  void _saveName(String v) {
    _name = v;
    _app.settings.saveGame('netz', {'name': v});
  }

  /// Was statt des Tischs gezeigt wird, solange das Netzwerk eingerichtet wird.
  Widget? _netScreen() {
    final guest = _guest;
    if (guest != null) {
      if (guest.view == null || !guest.lan.connected) return NetGuestWaiting(guest: guest, onLeave: _closeNet, message: _netMessage);
      return null;
    }
    if (_browser != null) {
      return NetBrowsePanel(tables: _tables, manual: _manual, onJoin: _join, onBack: _closeNet, message: _netMessage);
    }
    final host = _host;
    if (host != null && !_netPlaying) {
      return NetHostLobby(
        host: host,
        addresses: _addresses,
        bots: _netBots,
        maxBots: math.max(0, 3 - host.seats.length),
        onBots: (n) => setState(() => _netBots = n),
        onStart: _hostStart,
        onClose: _closeNet,
        startLabel: 'Runde starten',
      );
    }
    if (_netPanel) {
      return NetStartPanel(
        name: _name,
        onName: _saveName,
        onHost: _openTable,
        onBrowse: _browse,
        onBack: () => setState(() => _netPanel = false),
        message: _netMessage,
        hint: 'Alle Geräte im selben WLAN, bis zu vier Spieler. Freie Plätze füllen Computer.',
      );
    }
    return null;
  }

  String get _status {
    if (_e.finished) {
      return _e.winner!.human
          ? (_humans > 1
              ? '${_e.winner!.name} gewinnt!${_winReward > 0 ? ' +${formatCoins(_winReward)} Münzen' : ''}'
              : 'Gewonnen! +${formatCoins(_winReward)} Münzen')
          : '${_e.winner!.name} gewinnt die Runde'
              '${_placeReward > 0 ? '. Trostpreis +${formatCoins(_placeReward)} Münzen' : ''}';
    }
    if (_e.actor.human && _covered) return 'Gib das Gerät an ${_e.actor.name}';
    if (_e.actor.human && _humans > 1) {
      if (_e.pendingDraw > 0) return '${_e.actor.name}: Lege eine Sieben oder zieh ${_e.pendingDraw}';
      if (_e.drewThisTurn) return '${_e.actor.name}: Gezogene Karte legen oder behalten';
      return '${_e.actor.name} ist dran';
    }
    if (_e.actor.human) {
      if (_e.pendingDraw > 0) return 'Lege eine Sieben oder zieh ${_e.pendingDraw}';
      if (_e.drewThisTurn) return 'Gezogene Karte legen oder behalten';
      if (_e.lastEvent.isNotEmpty) return '${_e.lastEvent}. Du bist dran';
      return 'Du bist dran';
    }
    return _e.lastEvent.isNotEmpty ? _e.lastEvent : '${_e.actor.name} ist dran';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _app.settings;
    final net = _netScreen();
    return GameFrame(
      settings: mauMauSettings,
      guide: mauGuide,
      title: 'Mau Mau',
      actions: [
        if (!_net && !_netPanel)
          IconButton(
            tooltip: 'Im Netzwerk spielen',
            icon: const Icon(Icons.wifi),
            onPressed: () => setState(() => _netPanel = true),
          ),
      ],
      child: net ?? ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          // Hausregeln gelten sofort, auch mitten in der Runde (beim Mitspieler gelten die des Gastgebers)
          if (_guest == null) {
            _e.penaltyEndsTurn = settings.penaltyEndsTurn;
            _e.jackOnJack = settings.jackOnJack;
          }
          return LayoutBuilder(
            builder: (context, box) => _layout(box, settings.cardScale),
          );
        },
      ),
    );
  }

  Widget _layout(BoxConstraints box, double scale) {
    final me = _e.players[_viewer];
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.3;
    final badge = math.min(110.0, (w - 24) / _opponents - 8);
    final handBase = landscape
        ? math.min(h * 0.3 * cardAspect, 110.0)
        : math.min(math.min(w / 5.2, h * 0.17 * cardAspect), 100.0);
    // Die Hand darf höchstens gut ein Drittel der Höhe belegen
    final handMax = h * (landscape ? 0.36 : 0.3) * cardAspect / 1.2;
    final handW = math.min((handBase * scale).clamp(30.0, 170.0), handMax);
    final pileBase = landscape
        ? math.min(h * 0.26 * cardAspect, 100.0)
        : math.min(math.min(w * 0.2, h * 0.2 * cardAspect), 100.0);
    final pileW = (pileBase * scale).clamp(30.0, 170.0);

    final opponents = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var k = 1; k < _e.players.length; k++)
          for (final i in [(_viewer + k) % _e.players.length])
          OpponentBadge(
            name: _e.players[i].name,
            cardCount: _e.players[i].hand.length,
            active: !_e.finished && _e.current == i,
            width: badge,
            detail: _e.players[i].hand.length == 1
                ? 'Mau!'
                : _e.players[i].hand.isEmpty
                    ? 'Mau Mau!'
                    : '',
          ),
      ],
    );
    final status = ResultBanner(text: _status, highlight: _e.finished && _e.winner!.human);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _e.finished
          ? [
              if (_guest != null)
                const ActionButton(label: 'Warte auf den Gastgeber', onPressed: null)
              else
                ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
              if (_net)
                ActionButton(label: 'Tisch verlassen', onPressed: _closeNet)
              else
                ActionButton(label: 'Mitspieler wählen', onPressed: _askOpponents),
            ]
          : [
              ActionButton(
                primary: _myTurn && _e.playableCards().isEmpty,
                label: _e.pendingDraw > 0 && _e.actor.human
                    ? '${_e.pendingDraw} Karten ziehen'
                    : 'Ziehen',
                onPressed: _myTurn && !_e.drewThisTurn ? _draw : null,
              ),
              if (_myTurn && _e.drewThisTurn)
                ActionButton(label: 'Behalten', onPressed: _keep),
            ],
    );
    final Widget hand = _covered
        ? HandCover(name: _e.actor.name, onReveal: () => setState(() => _covered = false))
        : HandFan(
            cards: sortedHand(me.hand),
            maxCardWidth: handW,
            isEnabled: (c) => !_myTurn || _e.canPlay(c),
            isRaised: (c) => _myTurn && _e.canPlay(c),
            onTap: _play,
          );
    final center = FittedBox(fit: BoxFit.scaleDown, child: _center(pileW));

    if (landscape) {
      // Meldung und Knöpfe sitzen direkt über der Hand und wandern mit ihr
      return Column(
        children: [
          const SizedBox(height: 6),
          opponents,
          Expanded(child: Center(child: center)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                SizedBox(width: math.min(440, w * 0.42), child: status),
                buttons,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: hand),
        ],
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        opponents,
        Expanded(child: Center(child: center)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: status),
        Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 6), child: buttons),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: hand),
      ],
    );
  }

  Widget _center(double pileW) {
    final onFelt = Palette.of(context).onFelt;
    final label = TextStyle(color: onFelt, fontWeight: FontWeight.w700, fontSize: 15);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _draw,
              child: _e.drawPile.isEmpty
                  ? CardSlot(width: pileW)
                  : PlayingCardView(width: pileW),
            ),
            const SizedBox(height: 4),
            Text('${_e.drawPile.length} im Stapel', style: label),
          ],
        ),
        SizedBox(width: pileW * 0.35),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: PlayingCardView(
                key: ValueKey(_e.discard.length),
                width: pileW,
                card: _e.top,
              ),
            ),
            const SizedBox(height: 4),
            if (_e.wish != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Gewünscht ', style: label),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SuitIcon(
                      suit: _e.wish!,
                      size: 18,
                      color: _e.wish == Suit.hearts || _e.wish == Suit.diamonds
                          ? const Color(0xFFC8321F)
                          : const Color(0xFF241410),
                    ),
                  ),
                ],
              )
            else if (_e.pendingDraw > 0)
              Text('+${_e.pendingDraw} ziehen', style: label.copyWith(color: const Color(0xFFFFC95C)))
            else
              Text(' ', style: label),
          ],
        ),
      ],
    );
  }
}
