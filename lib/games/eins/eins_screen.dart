import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'eins_card.dart';
import 'eins_engine.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const einsRewardPerOpponent = 50;

/// Reihenfolge auf der Hand: nach Farbe, dann Zahl, Sonderkarten am Ende.
List<EinsCard> sortedEins(List<EinsCard> cards) {
  int key(EinsCard c) =>
      (c.color?.index ?? 4) * 100 + (c.kind == EinsKind.number ? c.number : 20 + c.kind.index);
  return cards.toList()..sort((a, b) => key(a).compareTo(key(b)));
}

class EinsScreen extends StatefulWidget {
  const EinsScreen({super.key});

  @override
  State<EinsScreen> createState() => _EinsScreenState();
}

class _EinsScreenState extends State<EinsScreen> {
  final _rng = math.Random.secure();
  int _opponents = 2;
  int _round = 0;
  late EinsEngine _e;
  bool _running = false;
  bool _rewarded = false;
  bool _called = false;

  AppScope get _app => AppScope.of(context);
  bool get _myTurn => !_e.finished && _e.actor.human && !_running;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final offset = _rng.nextInt(_names.length);
    _e = EinsEngine(
      players: [
        EinsPlayer('Du', human: true),
        for (var i = 0; i < _opponents; i++) EinsPlayer(_names[(offset + i) % _names.length]),
      ],
      rng: _rng,
    )..start(startPlayer: _round % (_opponents + 1));
    _rewarded = false;
    _called = false;
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

  Future<void> _play(EinsCard c) async {
    if (!_myTurn || !_e.canPlay(c)) return;
    EinsColor? chosen;
    if (c.isWild && _e.actor.hand.length > 1) {
      chosen = await showColorPicker(context);
      if (chosen == null || !mounted || !_myTurn) return;
    }
    _e.play(c, chosen: chosen, called: _called);
    _called = false;
    _app.sfx.play(Sound.card);
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

  void _call() {
    if (!_myTurn) return;
    _app.sfx.play(Sound.tick);
    setState(() => _called = true);
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
      final choice = einsBotChoice(_e, _rng);
      if (choice.card != null) {
        _e.play(choice.card!, chosen: choice.color);
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
        final again = einsBotChoice(_e, _rng);
        if (again.card != null) {
          _e.play(again.card!, chosen: again.color);
          _app.sfx.play(Sound.card);
        } else {
          _e.pass();
        }
        setState(() {});
      }
    }
    _running = false;
    if (!mounted) return;
    setState(() => _called = false);
    if (_e.finished) _finish();
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.winner!.human) {
      _app.wallet.credit(einsRewardPerOpponent * _opponents);
      _app.sfx.play(Sound.win);
    } else {
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    if (_e.finished) {
      return _e.winner!.human
          ? 'Gewonnen! +${formatCoins(einsRewardPerOpponent * _opponents)} Münzen'
          : '${_e.winner!.name} gewinnt die Runde';
    }
    if (_e.actor.human) {
      if (_e.pendingDraw > 0) {
        return _e.stackDraws
            ? 'Lege eine Plus-Karte oder zieh ${_e.pendingDraw}'
            : 'Du musst ${_e.pendingDraw} ziehen';
      }
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
      title: 'Eins!',
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          _e.stackDraws = settings.einsStackDraws;
          _e.callRequired = settings.einsCallRequired;
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
            backBuilder: (cw) => EinsCardView(width: cw),
            detail: _e.players[i].hand.length == 1 ? 'Eins!' : '',
          ),
      ],
    );
    final canCall = _myTurn && me.hand.length == 2 && _e.callRequired;
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
              if (canCall)
                ActionButton(
                  primary: !_called,
                  label: _called ? 'Gerufen' : 'Eins! rufen',
                  onPressed: _called ? null : _call,
                ),
            ],
    );
    final hand = CardFan<EinsCard>(
      items: sortedEins(me.hand),
      maxCardWidth: handW,
      cardBuilder: (c, width, raised) => EinsCardView(width: width, card: c, highlighted: raised),
      isEnabled: (c) => !_myTurn || _e.canPlay(c),
      isRaised: (c) => _myTurn && _e.canPlay(c),
      onTap: _play,
    );
    final center = FittedBox(fit: BoxFit.scaleDown, child: _center(pileW));

    if (landscape) {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
                      : EinsCardView(width: pileW),
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
                  child: EinsCardView(
                    key: ValueKey(_e.discard.length),
                    width: pileW,
                    card: _e.top,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: einsColors[_e.color],
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFF8E7), width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _e.pendingDraw > 0 ? '+${_e.pendingDraw} ziehen' : colorName(_e.color),
                      style: _e.pendingDraw > 0
                          ? label.copyWith(color: const Color(0xFFFFC95C))
                          : label,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Icon(
          _e.direction == 1 ? Icons.rotate_right : Icons.rotate_left,
          color: onFelt.withValues(alpha: 0.7),
          semanticLabel: _e.direction == 1 ? 'Im Uhrzeigersinn' : 'Gegen den Uhrzeigersinn',
        ),
      ],
    );
  }
}
