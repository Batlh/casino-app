import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/settings_sheet.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
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
    _setup();
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
    setState(() {
      _round++;
      _setup();
    });
    _app.sfx.play(Sound.card);
    _pump();
  }

  Future<void> _askOpponents() async {
    final seats = await showSeatSetup(context, gameId: 'maumau', title: 'Mau Mau', minSeats: 2, maxSeats: 4);
    if (seats == null || !mounted) return;
    _seats = seats;
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
    if (!_e.finished && _e.players[_viewer].hand.length == 1 && vsComputer(_seats)) _app.wallet.credit(callReward);
    setState(_syncViewer);
    _after();
  }

  void _draw() {
    if (!_myTurn || _e.drewThisTurn) return;
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(_syncViewer);
    _after();
  }

  void _keep() {
    if (!_myTurn) return;
    _e.pass();
    setState(_syncViewer);
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
      await Future<void>.delayed(_app.settings.botDelay(750));
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
        await Future<void>.delayed(_app.settings.botDelay(500));
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
    setState(_syncViewer);
    if (_e.finished) _finish();
  }

  /// Trostpreis: je Gegner mit mehr Karten auf der Hand.
  int get _placeReward => _humans == 1
      ? placeReward(beatenCount([for (final p in _e.players) p.hand.length], _seats.indexWhere((x) => x.human)))
      : 0;

  /// Münzen gibt es nur gegen den Computer: je Computer-Gegner.
  int get _winReward => mauRewardPerOpponent * _seats.where((x) => !x.human).length;

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
    return GameFrame(
      settings: mauMauSettings,
      guide: mauGuide,
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
              ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
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
