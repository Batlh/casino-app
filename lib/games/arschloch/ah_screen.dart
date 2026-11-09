import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'ah_engine.dart';

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

class _ArschlochScreenState extends State<ArschlochScreen> {
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
    _g = _restore() ?? _make();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  late int _seed;
  static const _saveId = 'arschloch';
  bool get _saving => widget.seed == null;

  AhGame _make() => AhGame(rng: math.Random(_seed))..start();

  /// Gespeicherte Partie nachspielen.
  AhGame? _restore() {
    if (!_saving) return null;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return null;
    try {
      _seed = d['seed'] as int;
      final g = _make();
      for (final a in d['log'] as List) {
        ahApply(g, a as List);
      }
      _earned = d['earned'] as int;
      _paidRound = g.phase == AhPhase.roundOver && d['paid'] == g.actionLog.length;
      return g;
    } catch (_) {
      _app.settings.clearGame(_saveId);
      _seed = math.Random.secure().nextInt(1 << 31);
      return null;
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  @override
  void dispose() {
    _persist();
    super.dispose();
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_g.phase == AhPhase.gameOver || _g.actionLog.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'seed': _seed, 'log': _g.actionLog, 'earned': _earned, 'paid': _paidRound ? _g.actionLog.length : -1});
  }

  bool get _myTurn => !_running && _g.phase == AhPhase.play && _g.current == 0;

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      if (_g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver) {
        _pay();
        break;
      }
      if (_g.phase != AhPhase.play || _g.current == 0) break;
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
    if (mounted) setState(() {});
  }

  void _pay() {
    if (!_paidRound) {
      _paidRound = true;
      final place = _g.finished.indexOf(0);
      final coins = ahRoundCoins[place];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(place == 0 ? Sound.win : Sound.coin);
      }
    }
    if (_g.phase == AhPhase.gameOver && !_paidGame) {
      _paidGame = true;
      final coins = ahGameCoins[_g.ranking().indexOf(0)];
      if (coins > 0) {
        _earned += coins;
        _app.wallet.credit(coins);
        _app.sfx.play(Sound.bigWin);
      }
    }
  }

  void _toggle(PlayingCard c) {
    final exchange = _g.phase == AhPhase.exchange;
    if (!_myTurn && !exchange) return;
    setState(() {
      if (_sel.remove(c)) return;
      if (exchange) {
        if (_sel.length < _g.humanGives) _sel.add(c);
        return;
      }
      // Nur gleiche Werte zusammen auswählen
      if (_sel.isNotEmpty && _sel.first.rank != c.rank) _sel.clear();
      _sel.add(c);
    });
  }

  void _play() {
    final cards = _sel.toList();
    if (!_g.canPlay(0, cards)) return;
    _g.play(0, cards);
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
    _pump();
  }

  void _pass() {
    _g.pass(0);
    _app.sfx.play(Sound.tick);
    setState(_sel.clear);
    _pump();
  }

  void _giveBack() {
    _g.humanGiveBack(_sel.toList());
    _app.sfx.play(Sound.card);
    setState(_sel.clear);
    _pump();
  }

  void _next() {
    _g.nextRound();
    setState(() {
      _paidRound = false;
      _sel.clear();
    });
    _pump();
  }

  void _newGame() {
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() {
      _g = _make();
      _paidRound = false;
      _paidGame = false;
      _earned = 0;
      _sel.clear();
    });
    _pump();
  }

  String get _status {
    if (_g.phase == AhPhase.exchange) {
      final got = _g.received.map((c) => c.spokenName).join(', ');
      return 'Du hast $got bekommen. Gib ${_g.humanGives} Karte${_g.humanGives > 1 ? 'n' : ''} zurück.';
    }
    if (_g.phase == AhPhase.roundOver || _g.phase == AhPhase.gameOver) {
      final place = _g.finished.indexOf(0);
      return 'Du bist ${ahTitles[place]}';
    }
    if (_myTurn) {
      if (_g.leading) return 'Du spielst aus: eine Karte oder mehrere gleiche';
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
      child: LayoutBuilder(builder: (context, box) {
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
                      for (final p in [1, 2, 3])
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
                                _g.topPlayer == 0 ? 'von dir' : 'von ${_g.players[_g.topPlayer].name}',
                                style: const TextStyle(color: Color(0xFFF6E7C8)),
                              ),
                            ],
                          ),
                  ),
                ),
                Text('Runde ${_g.round} von ${_g.rounds} · Du: ${_detail(0)}', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, maxLines: 2)),
                SizedBox(
                  height: 46,
                  child: Center(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        if (_g.phase == AhPhase.exchange)
                          ActionButton(primary: true, label: 'Zurückgeben', onPressed: _sel.length == _g.humanGives ? _giveBack : null),
                        if (_myTurn) ...[
                          ActionButton(primary: true, label: 'Spielen', onPressed: _g.canPlay(0, _sel.toList()) ? _play : null),
                          if (!_g.leading) ActionButton(label: 'Passen', onPressed: _pass),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                  child: HandFan(
                    cards: _g.players[0].hand,
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
                              style: TextStyle(color: pal.ink, fontWeight: _g.finished[i] == 0 ? FontWeight.w800 : FontWeight.w500),
                            ),
                          const SizedBox(height: 6),
                          Text('Punkte: ${[for (final p in _g.players) '${p.name} ${p.points}'].join(' · ')}', textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoft)),
                          if (_earned > 0) Text('Verdient: $_earned Münzen', style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          ActionButton(
                            primary: true,
                            label: _g.phase == AhPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde',
                            onPressed: _g.phase == AhPhase.gameOver ? _newGame : _next,
                          ),
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
