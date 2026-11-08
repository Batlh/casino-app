import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'solitaire_board.dart';
import 'spider_engine.dart';
import 'table_card.dart';

const spiderRewards = {1: 250, 2: 500, 4: 1000};

class SpiderScreen extends StatefulWidget {
  const SpiderScreen({super.key});

  @override
  State<SpiderScreen> createState() => _SpiderScreenState();
}

class _SpiderScreenState extends State<SpiderScreen> {
  int _suits = 1;
  late SpiderEngine _e = SpiderEngine(suits: _suits);
  Grab? _drag;
  String _message = '';
  bool _won = false;
  final _clock = Stopwatch()..start();
  Timer? _timer;

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_won) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newGame(int suits) {
    setState(() {
      _suits = suits;
      _e = SpiderEngine(suits: suits);
      _won = false;
      _message = '';
      _drag = null;
      _clock
        ..reset()
        ..start();
    });
  }

  Future<void> _askNew() async {
    final i = await showChoiceSheet(
      context,
      title: 'Neues Spiel',
      options: [
        for (final s in [1, 2, 4])
          '${s == 1 ? 'Eine Farbe' : '$s Farben'}, Sieg bringt ${formatCoins(spiderRewards[s]!)} Münzen',
      ],
    );
    if (i != null && mounted) _newGame(const [1, 2, 4][i]);
  }

  void _deal() {
    if (_won) return;
    if (_e.stock.isEmpty) return;
    if (_e.hasEmptyColumn) {
      setState(() => _message = 'Vor dem Austeilen muss jede Spalte belegt sein');
      return;
    }
    final before = _e.completed.length;
    _e.deal();
    _app.sfx.play(Sound.card);
    setState(() => _message = '');
    _afterMove(before);
  }

  void _tap(int col, int index) {
    if (_won) return;
    final to = _e.autoTarget(col, index);
    if (to == null) {
      setState(() => _message = _e.canPick(col, index)
          ? 'Für diese Reihe gibt es gerade keinen Platz'
          : 'Bewegen lassen sich nur gleichfarbige Reihen');
      return;
    }
    _move(col, index, to);
  }

  void _move(int from, int index, int to) {
    final before = _e.completed.length;
    if (_won || !_e.move(from, index, to)) return;
    _app.sfx.play(Sound.card);
    setState(() => _message = '');
    _afterMove(before);
  }

  void _afterMove(int completedBefore) {
    if (_e.completed.length > completedBefore) _app.sfx.play(Sound.coin);
    if (_e.isWon) {
      final reward = spiderRewards[_suits]!;
      _clock.stop();
      _app.wallet.credit(reward);
      _app.sfx.play(Sound.bigWin);
      setState(() {
        _won = true;
        _message = 'Gewonnen! +${formatCoins(reward)} Münzen';
      });
    }
  }

  void _undo() {
    if (_won || !_e.canUndo) return;
    _e.undo();
    setState(() => _message = '');
  }

  String get _status => _message.isNotEmpty
      ? _message
      : '${_e.moves} Züge, ${formatClock(_clock.elapsed)}, ${_e.completed.length} von 8 Reihen';

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Spider Solitaire',
      child: ListenableBuilder(
        listenable: _app.settings,
        builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth > box.maxHeight * 1.5;
          final bar = SolitaireBar(
            message: _status,
            highlight: _won,
            onUndo: _e.canUndo && !_won ? _undo : null,
            onNew: _askNew,
            vertical: side,
          );
          if (side) {
            return Row(
              children: [
                Expanded(child: LayoutBuilder(builder: _board)),
                SizedBox(width: 190, child: Padding(padding: const EdgeInsets.all(8), child: bar)),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: LayoutBuilder(builder: _board)),
              Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: bar),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _board(BuildContext context, BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final g = w < 500 ? 2.0 : 4.0;
    final fit = math.min(
      math.min((w - 11 * g) / 10, h * cardAspect / 4.0),
      110.0,
    );
    final cw = (fit * _app.settings.cardScale).clamp(24.0, 170.0);
    final ch = cw / cardAspect;
    final boardW = 10 * cw + 9 * g;
    final scroll = boardW + 2 * g > w;
    final ox = scroll ? g : (w - boardW) / 2;
    double x(int col) => ox + col * (cw + g);
    final tabY = g + ch + 2 * g;
    final tabH = h - tabY - g;

    void startDrag(Grab grab) => setState(() => _drag = grab);
    void endDrag() => setState(() => _drag = null);

    final board = Stack(
      children: [
        // Fertige Reihen links oben, je ein König
        for (var i = 0; i < _e.completed.length; i++)
          Positioned(
            left: x(0) + i * cw * 0.22,
            top: g,
            child: PlayingCardView(
              width: cw,
              card: PlayingCard(13, _e.completed[i]),
              strip: true,
            ),
          ),
        if (_e.completed.isEmpty)
          Positioned(left: x(0), top: g, child: CardSlot(width: cw, label: 'K')),
        // Stapel rechts oben, je Austeilrunde eine Karte
        for (var i = 0; i < _e.dealsLeft; i++)
          Positioned(
            left: x(9) - i * cw * 0.18,
            top: g,
            child: GestureDetector(
              onTap: _deal,
              child: PlayingCardView(width: cw),
            ),
          ),
        for (var t = 0; t < 10; t++)
          Positioned(
            left: x(t),
            top: tabY,
            child: TableauColumn(
              ref: PileRef(PileKind.tableau, t),
              cards: _e.tableau[t],
              width: cw,
              height: tabH,
              hideFrom: _drag?.from.index == t ? _drag!.index : null,
              canPick: (i) => _e.canPick(t, i),
              onTap: (i) => _tap(t, i),
              canAccept: (grab) => _e.canDrop(grab.from.index, grab.index, t),
              onAccept: (grab) => _move(grab.from.index, grab.index, t),
              onDragStart: startDrag,
              onDragEnd: endDrag,
              longPress: scroll,
            ),
          ),
      ],
    );
    return scrollable(board, boardW + 2 * g, w, h, scroll);
  }
}
