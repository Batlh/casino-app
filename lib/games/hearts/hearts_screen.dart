import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/saves.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_replay_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import '../cards/rewards.dart';
import 'hearts_engine.dart';
import 'hearts_net.dart';

const heartsWinBonus = 500;
const heartsMoonReward = 250;

int heartsHandReward(int points) => math.max(0, 13 - points) * 10;

class HeartsScreen extends StatefulWidget {
  const HeartsScreen({super.key});

  @override
  State<HeartsScreen> createState() => _HeartsScreenState();
}

class _HeartsScreenState extends State<HeartsScreen> with NetReplayScreen {
  late HeartsEngine _e;
  late int _seed;
  static const _saveId = 'hearts';

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  HeartsEngine _make([List<String> names = const ['Du', 'Helga', 'Otto', 'Bärbel'], int me = 0]) => HeartsEngine(
        rng: math.Random(_seed),
        seats: [for (final (i, n) in names.indexed) HeartsSeat(n, human: i == me)],
      );
  final Set<PlayingCard> _selected = {};
  bool _running = false;
  bool _showLast = false;
  String _note = '';
  int _reward = 0;
  bool _rewardDone = false;

  AppScope get _app => AppScope.of(context);
  int get _my => replayMe;
  HeartsSeat get _me => _e.seats[_my];
  bool get _myTurn =>
      _e.phase == HeartsPhase.playing && _e.current == _my && !_running && !_showLast;

  /// Sitz relativ zu dir: 0 unten, 1 links, 2 oben, 3 rechts.
  int _rel(int seat) => (seat - _my + 4) % 4;

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get replayGame => heartsNetGame;
  @override
  String get replayTitle => 'Schwarze Dame';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const ['Helga', 'Otto', 'Bärbel'];
  @override
  List<List<Object?>> get replayLog => _e.actionLog;

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _seed = seed;
    _e = _make(names, me)..newGame();
    _selected.clear();
    _rewardDone = false;
    _reward = 0;
    _note = '';
    _showLast = false;
    _app.sfx.play(Sound.card);
    if (replayIsHost) WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
  }

  @override
  void replayApply(List<dynamic> a) => heartsApply(_e, a);

  @override
  bool replayAllowed(int seat, List<dynamic> a) => heartsAllowed(_e, seat, a);

  @override
  Future<void> replayAfterRemote(List<List<dynamic>> acts) async {
    if (acts.any((a) => a.first == 'c')) _app.sfx.play(Sound.card);
    if (acts.any((a) => a.first == 'g' || a.first == 's')) {
      _selected.clear();
      _rewardDone = false;
      _reward = 0;
      _note = '';
    }
    if (acts.any((a) => a.first == 'p') && _e.phase == HeartsPhase.playing && _e.received.isNotEmpty) {
      _note = 'Bekommen: ${sortedHand(_e.received).map(_cardName).join(', ')}';
    }
    // Stich fertig: kurz zeigen
    if (acts.isNotEmpty && acts.last.first == 'c' && _e.trick.isEmpty && _e.lastTrick.length == 4) await _showTrick();
    if (!mounted) return;
    setState(() {});
    _pump();
  }

  @override
  void replayClosed() {
    _seed = math.Random.secure().nextInt(1 << 31);
    setState(() => _e = _make()..newGame());
    _selected.clear();
    _rewardDone = false;
    _reward = 0;
    _note = '';
    _pump();
  }

  @override
  void initState() {
    super.initState();
    _store = _app.settings;
    _seed = math.Random.secure().nextInt(1 << 31);
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _seed = d['seed'] as int;
        final e = _make();
        for (final a in d['log'] as List) {
          heartsApply(e, a as List);
        }
        _e = e;
        _rewardDone = d['paid'] == e.actionLog.length;
        WidgetsBinding.instance.addPostFrameCallback((_) => _pump());
        return;
      } catch (e, st) {
        debugLog.error('hearts.spielstand', e, st);
        _store.clearGame(_saveId);
      }
    }
    _e = _make()..newGame();
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
    if (replayActive) return;
    if (_e.phase == HeartsPhase.gameOver && _rewardDone) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {'seed': _seed, 'log': _e.actionLog, 'paid': _rewardDone ? _e.actionLog.length : -1});
  }

  void _tap(PlayingCard c) {
    if (_e.phase == HeartsPhase.passing) {
      setState(() {
        if (!_selected.remove(c) && _selected.length < 3) _selected.add(c);
      });
      _app.sfx.play(Sound.tick);
      return;
    }
    _play(c);
  }

  void _pass() {
    if (_selected.length != 3 || _e.phase != HeartsPhase.passing || _e.hasPassed(_my)) return;
    if (replaySend(['p', _my, for (final c in _selected) cardCode(c)])) {
      setState(_selected.clear);
      _app.sfx.play(Sound.card);
      return;
    }
    _passBots();
    _e.choosePass(_my, _selected.toList());
    _selected.clear();
    if (_e.phase == HeartsPhase.playing) {
      final got = sortedHand(_e.received).map((c) => _cardName(c)).toList();
      setState(() => _note = 'Bekommen: ${got.join(', ')}');
    } else {
      setState(() => _note = '');
    }
    _app.sfx.play(Sound.card);
    _pump();
  }

  /// Computer geben ihre Karten weiter (nur allein oder als Gastgeber).
  void _passBots() {
    if (_e.phase != HeartsPhase.passing) return;
    for (var s = 0; s < 4; s++) {
      if (_e.phase == HeartsPhase.passing && replayIsBot(s) && !_e.hasPassed(s)) _e.choosePass(s, heartsBotPass(_e.seats[s].hand));
    }
  }

  String _cardName(PlayingCard c) {
    final names = AppScope.of(context).settings.cardNames;
    final suit = switch (c.suit) {
      Suit.spades => 'Pik',
      Suit.hearts => 'Herz',
      Suit.diamonds => 'Karo',
      Suit.clubs => 'Kreuz',
    };
    return '$suit ${c.rankLabel(names)}';
  }

  Future<void> _play(PlayingCard c) async {
    if (!_myTurn || !_e.legalCards(_my).contains(c)) return;
    if (replaySend(['c', cardCode(c)])) return;
    final done = _e.play(c);
    _app.sfx.play(Sound.card);
    setState(() => _note = '');
    if (done) await _showTrick();
    if (!mounted) return;
    _pump();
  }

  Future<void> _showTrick() async {
    // Ein sauberer Stich ohne Strafpunkte bringt ein paar Münzen
    if (_e.lastTrickWinner == _my && pointsOf(_e.lastTrick.map((t) => t.card)) == 0) {
      _app.wallet.credit(cleanTrickReward);
    }
    setState(() => _showLast = true);
    await Future<void>.delayed(_app.settings.botDelay(1100));
    if (!mounted) return;
    setState(() => _showLast = false);
  }

  Future<void> _pump() async {
    if (_running) return;
    if (replayIsGuest) {
      _maybeReward();
      return;
    }
    if (_e.phase == HeartsPhase.passing && _e.hasPassed(_my)) {
      // Computer erst, wenn du weitergegeben hast (beim Gastgeber), sonst gleich beim Austeilen
      _passBots();
    } else if (_e.phase == HeartsPhase.passing && replayActive) {
      _passBots();
    }
    if (_e.phase == HeartsPhase.playing && _e.received.isNotEmpty && _note.isEmpty && _e.tricksPlayed == 0 && _e.trick.isEmpty) {
      _note = 'Bekommen: ${sortedHand(_e.received).map(_cardName).join(', ')}';
    }
    _running = true;
    final e = _e;
    while (mounted && _e == e && _e.phase == HeartsPhase.playing && replayIsBot(_e.current)) {
      await Future<void>.delayed(_app.settings.botDelay(600));
      if (!mounted) return;
      final done = _e.play(heartsBotPlay(_e));
      _app.sfx.play(Sound.card);
      setState(() {});
      if (done) await _showTrick();
    }
    _running = false;
    if (!mounted) return;
    setState(() {});
    _maybeReward();
  }

  void _maybeReward() {
    if (_rewardDone) return;
    if (_e.phase != HeartsPhase.handOver && _e.phase != HeartsPhase.gameOver) return;
    _rewardDone = true;
    var reward = _e.moonShooter == _my ? heartsMoonReward : heartsHandReward(_me.handPoints);
    if (_e.phase == HeartsPhase.gameOver) {
      if (_e.leaders.contains(_my)) {
        reward += heartsWinBonus;
      } else {
        // Trostpreis je Gegner mit mehr Punkten
        reward += placeReward(beatenCount([for (final s in _e.seats) s.score], _my), factor: 4);
      }
    }
    _reward = reward;
    if (reward > 0) {
      _app.wallet.credit(reward);
      _app.sfx.play(reward >= heartsWinBonus ? Sound.bigWin : Sound.coin);
    } else {
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  void _next() {
    if (replayIsGuest) return;
    if (replayIsHost && _e.phase == HeartsPhase.gameOver) {
      replayHostStart();
      return;
    }
    if (_e.phase == HeartsPhase.gameOver) {
      _seed = math.Random.secure().nextInt(1 << 31);
      _e = _make()..newGame();
    } else {
      _e.startHand();
    }
    _selected.clear();
    _rewardDone = false;
    _reward = 0;
    _note = '';
    _app.sfx.play(Sound.card);
    setState(() {});
    _pump();
  }

  String get _status {
    switch (_e.phase) {
      case HeartsPhase.passing:
        if (_e.hasPassed(_my)) return 'Warte, bis alle weitergegeben haben';
        return 'Drei Karten ${_e.passLabel} weitergeben (${_selected.length} von 3)';
      case HeartsPhase.handOver:
      case HeartsPhase.gameOver:
        final head = _e.phase == HeartsPhase.gameOver
            ? (_e.leaders.contains(_my)
                ? 'Spiel gewonnen'
                : '${_e.seats[_e.leaders.first].name} gewinnt das Spiel')
            : (_e.moonShooter != null
                ? '${_e.seats[_e.moonShooter!].name} schießt den Mond'
                : 'Runde vorbei');
        return _reward > 0 ? '$head. +${formatCoins(_reward)} Münzen' : head;
      case HeartsPhase.playing:
        if (_note.isNotEmpty) return _note;
        if (_myTurn) {
          if (_e.trick.isEmpty && _e.tricksPlayed == 0) return 'Du beginnst mit der Kreuz Zwei';
          return 'Du bist dran';
        }
        return '${_e.seats[_e.current].name} ist dran';
    }
  }

  @override
  Widget build(BuildContext context) {
    final legal = _myTurn ? _e.legalCards(_my).toSet() : <PlayingCard>{};
    final passing = _e.phase == HeartsPhase.passing && !_e.hasPassed(_my);
    final over = _e.phase == HeartsPhase.handOver || _e.phase == HeartsPhase.gameOver;
    return GameFrame(
      guide: heartsGuide,
      title: 'Schwarze Dame',
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? ListenableBuilder(
        listenable: _app.settings,
        builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final base = w > h * 1.3
              ? math.min(h * 0.24 * cardAspect, 100.0)
              : math.min(math.min(w / 5.6, h * 0.16 * cardAspect), 96.0);
          final handW = (base * _app.settings.cardScale).clamp(30.0, 170.0);
          return Column(
            children: [
              Expanded(child: _table(over)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ResultBanner(text: _status, highlight: over && _reward > 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (passing)
                      ActionButton(
                        primary: true,
                        label: 'Weitergeben',
                        onPressed: _selected.length == 3 ? _pass : null,
                      ),
                    if (over && replayActive)
                      ...replayButtons(label: _e.phase == HeartsPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde', next: _next)
                    else if (over) ...[
                      ActionButton(
                        primary: true,
                        label: _e.phase == HeartsPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde',
                        onPressed: _next,
                      ),
                      if (_e.phase == HeartsPhase.gameOver || MediaQuery.sizeOf(context).width < 420)
                        ActionButton(label: 'Im Netzwerk', onPressed: replayOpenPanel),
                    ],
                    if (!passing && !over)
                      Text(
                        'Dein Stand ${_me.score}, diese Runde ${pointsOf(_me.taken)}',
                        style: TextStyle(
                          color: Palette.of(context).onFelt,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: HandFan(
                  cards: sortedHand(_me.hand),
                  maxCardWidth: handW,
                  isEnabled: (c) => passing || !_myTurn || legal.contains(c),
                  isRaised: (c) => passing ? _selected.contains(c) : legal.contains(c),
                  onTap: _tap,
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _badge(int seat, double width) {
    final s = _e.seats[seat];
    return OpponentBadge(
      name: s.name,
      cardCount: s.hand.length,
      active: _e.phase == HeartsPhase.playing && _e.current == seat,
      width: width,
      detail: 'Stand ${s.score}',
    );
  }

  Widget _table(bool over) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final badgeW = math.min(104.0, w * 0.26);
        final badgeH = badgeW * 0.3 / cardAspect * 0.62 + 52;
        final size = math.max(
          120.0,
          math.min(math.min(w - 2 * badgeW - 16, h - badgeH - 8), 330.0),
        );
        return Stack(
          children: [
            Align(alignment: Alignment.topCenter, child: _badge((_my + 2) % 4, badgeW)),
            Align(alignment: const Alignment(-1, 0.1), child: Padding(padding: const EdgeInsets.only(left: 6), child: _badge((_my + 1) % 4, badgeW))),
            Align(alignment: const Alignment(1, 0.1), child: Padding(padding: const EdgeInsets.only(right: 6), child: _badge((_my + 3) % 4, badgeW))),
            Align(
              alignment: const Alignment(0, 0.6),
              child: SizedBox.square(
                dimension: size,
                child: over ? FittedBox(fit: BoxFit.scaleDown, child: _summary()) : _trick(size),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _trick(double size) {
    final cards = _showLast ? _e.lastTrick : _e.trick;
    final cw = size * 0.26;
    final ch = cw / cardAspect;
    Offset pos(int seat) => switch (seat) {
          0 => Offset((size - cw) / 2, size - ch),
          1 => Offset(0, (size - ch) / 2),
          2 => Offset((size - cw) / 2, 0),
          _ => Offset(size - cw, (size - ch) / 2),
        };
    return Stack(
      children: [
        for (final t in cards)
          Positioned(
            left: pos(_rel(t.seat)).dx,
            top: pos(_rel(t.seat)).dy,
            child: PlayingCardView(
              width: cw,
              card: t.card,
              highlighted: _showLast && t.seat == _e.lastTrickWinner,
            ),
          ),
      ],
    );
  }

  Widget _summary() {
    final style = TextStyle(
      color: Palette.of(context).onFelt,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xCC2A160E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                Text('', style: style),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Runde', style: style)),
                Text('Stand', style: style),
              ],
            ),
            for (final s in _e.seats)
              TableRow(
                children: [
                  Text(s.name, style: style),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('+${s.handPoints}', textAlign: TextAlign.right, style: style),
                  ),
                  Text('${s.score}', textAlign: TextAlign.right, style: style),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
