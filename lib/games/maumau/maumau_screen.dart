import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import '../cards/rewards.dart';
import 'maumau_engine.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const mauRewardPerOpponent = 50;

class MauMauScreen extends StatefulWidget {
  const MauMauScreen({super.key});

  @override
  State<MauMauScreen> createState() => _MauMauScreenState();
}

class _MauMauScreenState extends State<MauMauScreen> {
  final _rng = math.Random.secure();
  int _opponents = 2;
  int _round = 0;
  late MauMauEngine _e;
  bool _running = false;
  bool _rewarded = false;

  AppScope get _app => AppScope.of(context);
  bool get _myTurn => !_e.finished && _e.actor.human && !_running;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final offset = _rng.nextInt(_names.length);
    _e = MauMauEngine(
      players: [
        MauPlayer('Du', human: true),
        for (var i = 0; i < _opponents; i++) MauPlayer(_names[(offset + i) % _names.length]),
      ],
      rng: _rng,
    )..start(startPlayer: _round % (_opponents + 1));
    _rewarded = false;
  }

  void _newRound() {
    setState(() {
      _round++;
      _setup();
    });
    _app.sfx.play(Sound.card);
    _pump();
  }

  Future<void> _askOpponents() async {
    final i = await showChoiceSheet(
      context,
      title: 'Wie viele Gegner?',
      options: const ['Ein Gegner', 'Zwei Gegner', 'Drei Gegner'],
    );
    if (i == null || !mounted) return;
    _opponents = i + 1;
    _newRound();
  }

  Future<void> _play(PlayingCard c) async {
    if (!_myTurn || !_e.canPlay(c)) return;
    Suit? wish;
    if (c.rank == 11 && _e.actor.hand.length > 1) {
      wish = await showSuitPicker(context);
      if (wish == null || !mounted || !_myTurn) return;
    }
    _e.play(c, wishSuit: wish);
    _app.sfx.play(Sound.card);
    // „Mau!“: nur noch eine Karte
    if (!_e.finished && _e.players.first.hand.length == 1) _app.wallet.credit(callReward);
    setState(() {});
    _after();
  }

  void _draw() {
    if (!_myTurn || _e.drewThisTurn) return;
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(() {});
    _after();
  }

  void _keep() {
    if (!_myTurn) return;
    _e.pass();
    setState(() {});
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
    while (mounted && !_e.finished && !_e.actor.human) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      final choice = mauBotChoice(_e, _rng);
      if (choice.card != null) {
        _e.play(choice.card!, wishSuit: choice.wish);
        _app.sfx.play(Sound.card);
        setState(() {});
        continue;
      }
      _e.draw();
      _app.sfx.play(Sound.card);
      setState(() {});
      if (_e.drewThisTurn) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final again = mauBotChoice(_e, _rng);
        if (again.card != null) {
          _e.play(again.card!, wishSuit: again.wish);
          _app.sfx.play(Sound.card);
        } else {
          _e.pass();
        }
        setState(() {});
      }
    }
    _running = false;
    if (!mounted) return;
    setState(() {});
    if (_e.finished) _finish();
  }

  /// Trostpreis: je Gegner mit mehr Karten auf der Hand.
  int get _placeReward =>
      placeReward(beatenCount([for (final p in _e.players) p.hand.length], 0));

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.winner!.human) {
      _app.wallet.credit(mauRewardPerOpponent * _opponents);
      _app.sfx.play(Sound.win);
    } else {
      if (_placeReward > 0) _app.wallet.credit(_placeReward);
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    if (_e.finished) {
      return _e.winner!.human
          ? 'Gewonnen! +${formatCoins(mauRewardPerOpponent * _opponents)} Münzen'
          : '${_e.winner!.name} gewinnt die Runde'
              '${_placeReward > 0 ? '. Trostpreis +${formatCoins(_placeReward)} Münzen' : ''}';
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
    return GameFrame(
      title: 'Mau Mau',
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          // Hausregeln gelten sofort, auch mitten in der Runde
          _e.penaltyEndsTurn = settings.penaltyEndsTurn;
          _e.jackOnJack = settings.jackOnJack;
          return LayoutBuilder(
            builder: (context, box) => _layout(box, settings.cardScale),
          );
        },
      ),
    );
  }

  Widget _layout(BoxConstraints box, double scale) {
    final me = _e.players.first;
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
        for (var i = 1; i < _e.players.length; i++)
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
              ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
              ActionButton(label: 'Gegner wählen', onPressed: _askOpponents),
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
    final hand = HandFan(
      cards: sortedHand(me.hand),
      maxCardWidth: handW,
      isEnabled: (c) => !_myTurn || _e.canPlay(c),
      isRaised: (c) => _myTurn && _e.canPlay(c),
      onTap: _play,
    );
    final center = FittedBox(fit: BoxFit.scaleDown, child: _center(pileW));

    if (landscape) {
      // Querformat: Meldung und Knöpfe neben den Stapeln, damit die Hand Platz hat
      return Column(
        children: [
          const SizedBox(height: 6),
          opponents,
          Expanded(
            child: Row(
              children: [
                Expanded(child: Center(child: center)),
                SizedBox(
                  width: math.min(300, w * 0.36),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(300, w * 0.36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [status, buttons],
                      ),
                    ),
                  ),
                ),
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
