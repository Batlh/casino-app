import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'klondike_engine.dart';
import 'solitaire_board.dart';
import 'table_card.dart';

const klondikeRewards = {1: 200, 3: 400};

class KlondikeScreen extends StatefulWidget {
  const KlondikeScreen({super.key});

  @override
  State<KlondikeScreen> createState() => _KlondikeScreenState();
}

class _KlondikeScreenState extends State<KlondikeScreen> {
  int _drawCount = 1;
  late KlondikeEngine _e = KlondikeEngine(drawCount: _drawCount);
  Grab? _drag;
  String _message = '';
  bool _won = false;
  bool _auto = false;
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

  void _newGame(int draw) {
    setState(() {
      _drawCount = draw;
      _e = KlondikeEngine(drawCount: draw);
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
        '1 Karte ziehen, Sieg bringt ${klondikeRewards[1]} Münzen',
        '3 Karten ziehen, Sieg bringt ${klondikeRewards[3]} Münzen',
      ],
    );
    if (i != null && mounted) _newGame(i == 0 ? 1 : 3);
  }

  void _drawStock() {
    if (_won || _auto || !_e.canDraw) return;
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(() => _message = '');
  }

  void _tap(PileRef from, int index) {
    if (_won || _auto) return;
    final to = _e.autoTarget(from, index);
    if (to == null) {
      setState(() => _message = 'Für diese Karte gibt es gerade keinen Platz');
      return;
    }
    _move(from, index, to);
  }

  void _move(PileRef from, int index, PileRef to) {
    if (_won || _auto || !_e.move(from, index, to)) return;
    _app.sfx.play(Sound.card);
    setState(() => _message = '');
    if (_e.isWon) {
      _win();
    } else if (_e.canAutoFinish) {
      _autoFinish();
    }
  }

  Future<void> _autoFinish() async {
    if (_auto) return;
    _auto = true;
    while (mounted && _e.autoFinishStep()) {
      _app.sfx.play(Sound.tick);
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    _auto = false;
    if (mounted && _e.isWon) _win();
  }

  void _win() {
    if (_won) return;
    final reward = klondikeRewards[_drawCount]!;
    _clock.stop();
    _app.wallet.credit(reward);
    _app.sfx.play(Sound.bigWin);
    setState(() {
      _won = true;
      _message = 'Gewonnen! +${formatCoins(reward)} Münzen';
    });
  }

  void _undo() {
    if (_auto || _won || !_e.canUndo) return;
    _e.undo();
    setState(() => _message = '');
  }

  String get _status => _message.isNotEmpty
      ? _message
      : '${_e.moves} Züge, ${formatClock(_clock.elapsed)}';

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Solitaire',
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth > box.maxHeight * 1.5;
          final bar = SolitaireBar(
            message: _status,
            highlight: _won,
            onUndo: _e.canUndo && !_won && !_auto ? _undo : null,
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
    );
  }

  Widget _board(BuildContext context, BoxConstraints box) {
    const g = 6.0;
    final w = box.maxWidth;
    final h = box.maxHeight;
    final cw = math.min(
      math.min((w - 8 * g) / 7, h * cardAspect / 3.4),
      130.0,
    );
    final ch = cw / cardAspect;
    final boardW = 7 * cw + 6 * g;
    final ox = (w - boardW) / 2;
    double x(int col) => ox + col * (cw + g);
    final tabY = g + ch + 2 * g;
    final tabH = h - tabY - g;

    void startDrag(Grab grab) => setState(() => _drag = grab);
    void endDrag() => setState(() => _drag = null);

    // Ablagestapel: bis zu drei Karten aufgefächert, nur die oberste ist beweglich
    final waste = _e.waste;
    final shown = math.min(_drawCount == 3 ? 3 : 1, waste.length);
    final wasteStep = cw * 0.3;

    return Stack(
      children: [
        Positioned(
          left: x(0),
          top: g,
          child: GestureDetector(
            onTap: _drawStock,
            child: _e.stock.isEmpty
                ? CardSlot(width: cw, icon: waste.isEmpty ? null : Icons.refresh)
                : PlayingCardView(width: cw),
          ),
        ),
        for (var i = 0; i < shown; i++)
          Positioned(
            left: x(1) + i * wasteStep,
            top: g,
            child: () {
              final index = waste.length - shown + i;
              final view = PlayingCardView(width: cw, card: waste[index].card, strip: true);
              if (index != waste.length - 1) return view;
              const ref = PileRef(PileKind.waste);
              final grab = Grab(ref, index);
              return CardRunDraggable(
                grab: grab,
                run: [waste[index]],
                width: cw,
                step: 0,
                onTap: () => _tap(ref, index),
                onDragStarted: () => startDrag(grab),
                onDragEnd: endDrag,
                child: view,
              );
            }(),
          ),
        for (var f = 0; f < 4; f++)
          Positioned(left: x(3 + f), top: g, child: _foundation(f, cw, startDrag, endDrag)),
        for (var t = 0; t < 7; t++)
          Positioned(
            left: x(t),
            top: tabY,
            child: TableauColumn(
              ref: PileRef(PileKind.tableau, t),
              cards: _e.tableau[t],
              width: cw,
              height: tabH,
              emptyLabel: 'K',
              hideFrom: _drag?.from == PileRef(PileKind.tableau, t) ? _drag!.index : null,
              canPick: (i) => _e.canPick(PileRef(PileKind.tableau, t), i),
              onTap: (i) => _tap(PileRef(PileKind.tableau, t), i),
              canAccept: (grab) => _e.canDrop(grab.from, grab.index, PileRef(PileKind.tableau, t)),
              onAccept: (grab) => _move(grab.from, grab.index, PileRef(PileKind.tableau, t)),
              onDragStart: startDrag,
              onDragEnd: endDrag,
            ),
          ),
      ],
    );
  }

  Widget _foundation(
    int f,
    double cw,
    void Function(Grab) startDrag,
    VoidCallback endDrag,
  ) {
    final ref = PileRef(PileKind.foundation, f);
    final pile = _e.foundations[f];
    return DragTarget<Grab>(
      onWillAcceptWithDetails: (d) => _e.canDrop(d.data.from, d.data.index, ref),
      onAcceptWithDetails: (d) => _move(d.data.from, d.data.index, ref),
      builder: (context, candidates, _) {
        if (pile.isEmpty) {
          return CardSlot(width: cw, label: 'A', glow: candidates.isNotEmpty);
        }
        final index = pile.length - 1;
        final grab = Grab(ref, index);
        return Stack(
          children: [
            if (pile.length > 1)
              PlayingCardView(width: cw, card: pile[index - 1].card, strip: true),
            CardRunDraggable(
              grab: grab,
              run: [pile.last],
              width: cw,
              step: 0,
              onDragStarted: () => startDrag(grab),
              onDragEnd: endDrag,
              child: PlayingCardView(
                width: cw,
                card: pile.last.card,
                strip: true,
                highlighted: candidates.isNotEmpty,
              ),
            ),
          ],
        );
      },
    );
  }
}
