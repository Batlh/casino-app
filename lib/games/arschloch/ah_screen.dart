import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/saves.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_replay_mixin.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'ah_engine.dart';
import 'ah_net.dart';

/// Münzen je Runde nach Platz.
const ahRoundCoins = [30, 15, 5, 0];

/// Münzen am Ende nach Gesamtplatz.
const ahGameCoins = [150, 60, 20, 0];

const arschlochGuide = GameGuide(
  'Arschloch',
  [
    GuideSection(
      'Ziel',
      'Werde deine Karten als Erster los. Wer zuerst fertig ist, wird König, dann Vize-König und Vize-Arschloch. '
          'Wer übrig bleibt, ist das Arschloch. Gespielt wird mit 32 Karten von 7 bis Ass zu viert, sechs Runden lang.',
    ),
    GuideSection(
      'Ausspielen',
      'Wer dran ist, legt eine Karte oder mehrere gleiche (bis vier). Die anderen müssen genauso viele Karten mit höherem Wert '
          'legen oder passen. Wer passt, darf später im selben Stich wieder mitspielen. Passen alle anderen, räumt der Letzte ab '
          'und spielt neu aus. Das Ass ist am höchsten.',
    ),
    GuideSection(
      'Tauschen',
      'Ab der zweiten Runde gibt das Arschloch seine zwei besten Karten dem König, der zwei beliebige zurückgibt. '
          'Das Vize-Arschloch gibt seine beste Karte dem Vize-König und bekommt eine zurück. Das Arschloch spielt zuerst aus.',
    ),
    GuideSection(
      'Punkte und Münzen',
      'König 3 Punkte, Vize-König 2, Vize-Arschloch 1. Je Runde gibt es 30, 15 oder 5 Münzen, am Ende 150, 60 oder 20 für die '
          'Plätze 1 bis 3.',
    ),
  ],
);

class ArschlochScreen extends StatefulWidget {
  const ArschlochScreen({super.key, this.seed});
  final int? seed;

  @override
  State<ArschlochScreen> createState() => _ArschlochScreenState();
}

class _ArschlochScreenState extends State<ArschlochScreen> with NetReplayScreen {
  late AhGame _g;
  final Set<PlayingCard> _sel = {};
  bool _running = false;
  bool _paidRound = false;
  bool _paidGame = false;
  int _earned = 0;

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _seed = widget.seed ?? math.Random.secure().nextInt(1 << 31);
    final saved = widget.seed == null ? _store.loadGame('seats.arschloch') : null;
    if (saved != null) {
      try {
        final list = [for (final j in saved['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
        if (list.length == 4 && list.any((x) => x.human)) _seats = list;
      } catch (_) {
        // Standard behalten
      }
    }
    _g = _restore() ?? _make();
    _viewer = _g.players.indexWhere((x) => x.human);
    _syncViewer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  late int _seed;
  static const _saveId = 'arschloch';
  bool get _saving => widget.seed == null && !replayActive;

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get replayGame => ahNetGame;
  @override
  String get replayTitle => 'Arschloch';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const ['Kalle', 'Uschi', 'Bernd'];
  @override
  List<List<Object?>> get replayLog => _g.actionLog;

  /// Die Engine lässt Computer beim Tausch selbst zurückgeben; darum kennen alle Geräte alle Menschen-Plätze.
  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _seed = seed;
    _g = AhGame(rng: math.Random(seed), names: names, humans: [for (var i = 0; i < 4; i++) replayHumans.contains(i)])..start();
    _viewer = me;
    _covered = false;
    _paidRound = false;
    _paidGame = false;
    _earned = 0;
    _sel.clear();
    _app.sfx.play(Sound.card);
    if (replayIsHost) WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  @override
  void replayApply(List<dynamic> a) => ahApply(_g, a);

  @override
  bool replayAllowed(int seat, List<dynamic> a) => ahAllowed(_g, seat, a);

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    if (acts.any((a) => a.first == 'n')) {
      _paidRound = false;
      _sel.clear();
    }
    if (acts.isNotEmpty) _app.sfx.play(acts.last.first == 'x' ? Sound.tick : Sound.card);
    setState(() {});
    _pump();
  }

  @override
  void replayClosed() {
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _viewer = _g.players.indexWhere((x) => x.human);
      _covered = false;
      _paidRound = false;
      _paidGame = false;
      _earned = 0;
      _sel.clear();
    });
    _pump();
  }

  bool _send(List<Object?> a) {
    if (!replaySend(a)) return false;
    setState(_sel.clear);
    return true;
  }

  /// Plätze am Tisch (immer vier); mehrere Menschen geben das Gerät weiter.
  List<Seat> _seats = const [Seat('Du', human: true), Seat('Kalle'), Seat('Uschi'), Seat('Bernd')];
  int _viewer = 0;
  bool _covered = false;

  AhGame _make() {
    const bots = ['Kalle', 'Uschi', 'Bernd', 'Gerda'];
    var b = 0;
    final single = _seats.where((x) => x.human).length == 1 && _seats[0].human;
    return AhGame(
      rng: math.Random(_seed),
      names: [for (final x in _seats) x.human ? (single ? 'Du' : x.name) : bots[b++]],
      humans: [for (final x in _seats) x.human],
    )..start();
  }

  int get _humans => _g.players.where((x) => x.human).length;
  bool get _vsComputer => replayActive ? replayHumans.length < 4 : _g.players.any((x) => !x.human);

  /// Wer muss gerade am Gerät sein? Beim Tausch der erste Mensch, der zurückgeben muss, sonst wer dran ist.
  int? get _actor {
    if (_g.phase == AhPhase.exchange) return _g.pendingGive.isEmpty ? null : (_g.pendingGive.toList()..sort()).first;
    if (_g.phase == AhPhase.play && _g.players[_g.current].human) return _g.current;
    return null;
  }

  void _syncViewer() {
    if (replayActive) return;
    final a = _actor;
    if (a == null || a == _viewer) return;
    _viewer = a;
    _covered = _humans > 1;
    _sel.clear();
  }

  /// Gespeicherte Partie nachspielen.
  AhGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      if (d['seats'] != null) _seats = [for (final j in d['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
      final g = _make();
      for (final a in d['log'] as List) {
        ahApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _paidRound = g.phase == AhPhase.roundOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (e, st) {
      debugLog.error('arschloch.spielstand', e, st);
      _app.settings.clearGame(_saveId);
      _seed = math.Random.secure().nextInt(1 << 31);
      return null;
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
    replayBroadcast();
  }

  @override
  void dispose() {
    _persist();
    replayDispose();
    super.dispose();
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_g.phase == AhPhase.gameOver || _g.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {
      'seed': _seed,
      'seats': [for (final x in _seats) x.toJson()],
      'log': _g.actionLog,
      'earned': _earned,
      'paid': _paidRound ? _g.actionLog.length : -1,
    });
  }

  bool get _myTurn => !_running && !_covered && _g.phase == AhPhase.play && _g.current == _viewer && _g.players[_viewer].human;
  bool get _myExchange => !_covered && _g.phase == AhPhase.exchange && _g.pendingGive.contains(_viewer);

  Future<void> _pump() async {
    if (_running) return;
    if (replayIsGuest) {
      if (_g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver) _pay();
      return;
    }
    // Wer im Netz gegangen ist: Der Computer gibt für ihn zurück
    if (replayActive && _g.phase == AhPhase.exchange) {
      for (final p in _g.pendingGive.toList()) {
        if (replayIsBot(p)) _g.giveBack(p, sortAh(_g.players[p].hand).take(_g.gives(p)).toList());
      }
    }
    _running = true;
    final game = _g;
    while (mounted && _g == game) {
      if (_g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver) {
        _pay();
        break;
      }
      if (_g.phase != AhPhase.play) break;
      // Menschen ziehen selbst, außer wer im Netz gegangen ist
      if (_g.players[_g.current].human && !(replayActive && replayIsBot(_g.current))) break;
      await Future<void>.delayed(_app.settings.botDelay(700));
      if (!mounted) return;
      final p = _g.current;
      final move = ahBotMove(_g, p);
      if (move == null) {
        _g.pass(p);
        _app.sfx.play(Sound.tick);
      } else {
        _g.play(p, move);
        _app.sfx.play(Sound.card);
      }
      setState(() {});
    }
    _running = false;
    if (mounted) setState(_syncViewer);
  }

  /// Bester Platz eines Menschen; Münzen gibt es nur, wenn ein Computer mitspielt.
  int _bestHumanPlace(List<int> order) {
    if (replayActive) return order.indexOf(_viewer);
    var best = 99;
    for (var p = 0; p < 4; p++) {
      if (_g.players[p].human) best = math.min(best, order.indexOf(p));
    }
    return best;
  }

  void _pay() {
    if (!_vsComputer) return;
    if (!_paidRound) {
      _paidRound = true;
      final place = _bestHumanPlace(_g.finished);
      final coins = ahRoundCoins[place];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(place == 0 ? Sound.win : Sound.coin);
      }
    }
    if (_g.phase == AhPhase.gameOver && !_paidGame) {
      _paidGame = true;
      final coins = ahGameCoins[_bestHumanPlace(_g.ranking())];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.bigWin);
      }
    }
  }

  void _toggle(PlayingCard c) {
    final exchange = _myExchange;
    if (!_myTurn && !exchange) return;
    setState(() {
      if (_sel.remove(c)) return;
      if (exchange) {
        if (_sel.length < _g.gives(_viewer)) _sel.add(c);
        return;
      }
      // Nur gleiche Werte zusammen auswählen
      if (_sel.isNotEmpty && _sel.first.rank != c.rank) _sel.clear();
      _sel.add(c);
    });
  }

  void _play() {
    final cards = _sel.toList();
    if (!_g.canPlay(_viewer, cards)) return;
    if (_send(['p', _viewer, for (final c in cards) cardCode(c)])) return;
    _g.play(_viewer, cards);
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
    _pump();
  }

  void _pass() {
    if (_send(['x', _viewer])) return;
    _g.pass(_viewer);
    _app.sfx.play(Sound.tick);
    setState(_sel.clear);
    _pump();
  }

  void _giveBack() {
    if (_send(['G', _viewer, for (final c in _sel) cardCode(c)])) return;
    _g.giveBack(_viewer, _sel.toList());
    _app.sfx.play(Sound.card);
    setState(() {
      _sel.clear();
      _syncViewer();
    });
    _pump();
  }

  void _next() {
    if (replayIsGuest) return;
    _g.nextRound();
    setState(() {
      _paidRound = false;
      _sel.clear();
      _syncViewer();
    });
    _pump();
  }

  Future<void> _newGame() async {
    final seats = await showSeatSetup(context, gameId: 'arschloch', title: 'Arschloch', minSeats: 4, maxSeats: 4);
    if (seats == null || !mounted) return;
    _seats = seats;
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _paidRound = false;
      _paidGame = false;
      _earned = 0;
      _sel.clear();
      _viewer = _g.players.indexWhere((x) => x.human);
      _covered = false;
      _syncViewer();
    });
    _pump();
  }

  String get _you => _humans > 1 && !replayActive ? _g.players[_viewer].name : 'Du';

  String get _status {
    if (_covered) return 'Gib das Gerät an ${_g.players[_viewer].name}';
    if (_g.phase == AhPhase.exchange) {
      if (!_myExchange) return 'Tausch läuft';
      final got = _g.receivedBy[_viewer].map((c) => c.spokenName).join(', ');
      final n = _g.gives(_viewer);
      return '$_you: $got bekommen. Gib $n Karte${n > 1 ? 'n' : ''} zurück.';
    }
    if (_g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver) {
      if (_humans > 1) return 'König: ${_g.players[_g.finished.first].name}';
      final place = _g.finished.indexOf(_viewer);
      return 'Du bist ${ahTitles[place]}';
    }
    if (_myTurn) {
      if (_g.leading) return '$_you: Spiel aus, eine Karte oder mehrere gleiche';
      return '${_g.lastEvent}. Lege ${_g.top.length} höhere oder passe';
    }
    return _g.lastEvent.isEmpty ? '${_g.players[_g.current].name} ist dran' : _g.lastEvent;
  }

  String _detail(int p) {
    final pl = _g.players[p];
    final t = pl.title == null ? '' : '${ahTitles[pl.title!]} · ';
    if (!_g.active(p)) return '${t}fertig';
    return '$t${pl.hand.length} Karten · ${pl.points} P.';
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return GameFrame(
      title: 'Arschloch',
      guide: arschlochGuide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF6B3A1F), Color(0xFF2A160B)]),
      ),
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final badge = math.min(130.0, w / 3.3);
        final over = _g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver;
        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final p in [for (var k = 1; k < 4; k++) (_viewer + k) % 4])
                        OpponentBadge(
                          name: _g.players[p].name,
                          cardCount: _g.players[p].hand.length,
                          active: _g.current == p && _g.phase == AhPhase.play,
                          detail: _detail(p),
                          width: badge,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _g.top.isEmpty
                        ? Text(_g.phase == AhPhase.play ? 'Neuer Stich' : '', style: const TextStyle(color: Color(0x99F6E7C8), fontSize: 18))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final c in _g.top)
                                    Padding(padding: const EdgeInsets.all(3), child: PlayingCardView(width: math.min(80, w / 6), card: c)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _g.topPlayer == _viewer && _humans == 1 ? 'von dir' : 'von ${_g.players[_g.topPlayer].name}',
                                style: const TextStyle(color: Color(0xFFF6E7C8)),
                              ),
                            ],
                          ),
                  ),
                ),
                Text('Runde ${_g.round} von ${_g.rounds} · $_you: ${_detail(_viewer)}', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
                SizedBox(
                  height: 46,
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_myExchange)
                          ActionButton(primary: true, label: 'Zurückgeben', onPressed: _sel.length == _g.gives(_viewer) ? _giveBack : null),
                        if (_myTurn) ...[
                          ActionButton(primary: true, label: 'Spielen', onPressed: _g.canPlay(_viewer, _sel.toList()) ? _play : null),
                          if (!_g.leading) ActionButton(label: 'Passen', onPressed: _pass),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                  child: _covered
                      ? HandCover(name: _g.players[_viewer].name, onReveal: () => setState(() => _covered = false))
                      : HandFan(
                          cards: _g.players[_viewer].hand,
                          maxCardWidth: math.min(80, w / 7),
                          isRaised: _sel.contains,
                          isEnabled: (c) => _g.phase == AhPhase.exchange || !_myTurn || _g.leading || c.rank > _g.top.first.rank,
                          onTap: _toggle,
                        ),
                ),
              ],
            ),
            if (over)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: pal.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: pal.panelEdge, width: 2)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_g.phase == AhPhase.gameOver ? 'Endstand' : 'Runde ${_g.round}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 6),
                          for (var i = 0; i < 4; i++)
                            Text(
                              '${ahTitles[i]}: ${_g.players[_g.finished[i]].name}',
                              style: TextStyle(color: pal.ink, fontWeight: _g.players[_g.finished[i]].human ? FontWeight.w800 : FontWeight.w500),
                            ),
                          const SizedBox(height: 6),
                          Text('Punkte: ${[for (final p in _g.players) '${p.name} ${p.points}'].join(' · ')}', textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoft)),
                          if (_earned > 0) Text('Verdient: $_earned Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          if (replayActive)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: replayButtons(
                                label: _g.phase == AhPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde',
                                next: _g.phase == AhPhase.gameOver ? replayHostStart : _next,
                              ),
                            )
                          else
                            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                              ActionButton(
                                primary: true,
                                label: _g.phase == AhPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde',
                                onPressed: _g.phase == AhPhase.gameOver ? _newGame : _next,
                              ),
                              ActionButton(label: 'Im Netzwerk', onPressed: replayOpenPanel),
                            ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
