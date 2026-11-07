import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'hearts_engine.dart';

const heartsWinBonus = 500;
const heartsMoonReward = 250;

int heartsHandReward(int points) => math.max(0, 13 - points) * 10;

class HeartsScreen extends StatefulWidget {
  const HeartsScreen({super.key});

  @override
  State<HeartsScreen> createState() => _HeartsScreenState();
}

class _HeartsScreenState extends State<HeartsScreen> {
  final _e = HeartsEngine(
    seats: [
      HeartsSeat('Du', human: true),
      HeartsSeat('Helga'),
      HeartsSeat('Otto'),
      HeartsSeat('Bärbel'),
    ],
  );
  final Set<PlayingCard> _selected = {};
  bool _running = false;
  bool _showLast = false;
  String _note = '';
  int _reward = 0;
  bool _rewardDone = false;

  AppScope get _app => AppScope.of(context);
  HeartsSeat get _me => _e.seats.first;
  bool get _myTurn =>
      _e.phase == HeartsPhase.playing && _e.current == 0 && !_running && !_showLast;

  @override
  void initState() {
    super.initState();
    _e.newGame();
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
    if (_selected.length != 3 || _e.phase != HeartsPhase.passing) return;
    for (var s = 1; s < 4; s++) {
      _e.choosePass(s, heartsBotPass(_e.seats[s].hand));
    }
    _e.choosePass(0, _selected.toList());
    _selected.clear();
    final got = sortedHand(_e.received).map((c) => _cardName(c)).toList();
    setState(() => _note = 'Bekommen: ${got.join(', ')}');
    _app.sfx.play(Sound.card);
    _pump();
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
    if (!_myTurn || !_e.legalCards(0).contains(c)) return;
    final done = _e.play(c);
    _app.sfx.play(Sound.card);
    setState(() => _note = '');
    if (done) await _showTrick();
    if (!mounted) return;
    _pump();
  }

  Future<void> _showTrick() async {
    setState(() => _showLast = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _showLast = false);
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted && _e.phase == HeartsPhase.playing && _e.current != 0) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
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
    var reward = _e.moonShooter == 0 ? heartsMoonReward : heartsHandReward(_me.handPoints);
    if (_e.phase == HeartsPhase.gameOver && _e.leaders.contains(0)) {
      reward += heartsWinBonus;
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
    if (_e.phase == HeartsPhase.gameOver) {
      _e.newGame();
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
        return 'Drei Karten ${_e.passLabel} weitergeben (${_selected.length} von 3)';
      case HeartsPhase.handOver:
      case HeartsPhase.gameOver:
        final head = _e.phase == HeartsPhase.gameOver
            ? (_e.leaders.contains(0)
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
    final legal = _myTurn ? _e.legalCards(0).toSet() : <PlayingCard>{};
    final passing = _e.phase == HeartsPhase.passing;
    final over = _e.phase == HeartsPhase.handOver || _e.phase == HeartsPhase.gameOver;
    return GameFrame(
      title: 'Schwarze Dame',
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final handW = math.min(math.min(w / 5.6, h * 0.16 * cardAspect), 96.0);
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
                    if (over)
                      ActionButton(
                        primary: true,
                        label: _e.phase == HeartsPhase.gameOver ? 'Neues Spiel' : 'Nächste Runde',
                        onPressed: _next,
                      ),
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
            Align(alignment: Alignment.topCenter, child: _badge(2, badgeW)),
            Align(alignment: const Alignment(-1, 0.1), child: Padding(padding: const EdgeInsets.only(left: 6), child: _badge(1, badgeW))),
            Align(alignment: const Alignment(1, 0.1), child: Padding(padding: const EdgeInsets.only(right: 6), child: _badge(3, badgeW))),
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
            left: pos(t.seat).dx,
            top: pos(t.seat).dy,
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
