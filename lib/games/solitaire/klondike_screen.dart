import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/progress.dart';
import '../../core/saves.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/playing_card.dart';
import 'hints.dart';
import 'klondike_engine.dart';
import 'solitaire_board.dart';
import 'table_card.dart';

const klondikeRewards = {1: 200, 3: 400};

/// Münzen je Karte, die zum ersten Mal auf die Ablage kommt.
const klondikeCardRewards = {1: 2, 3: 4};

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
  int _hints = 0;
  bool _lost = false;
  SolitaireHint? _hint;
  final Set<PlayingCard> _paidCards = {};
  final _clock = Stopwatch()..start();
  Duration _clockBase = Duration.zero;
  Timer? _timer;

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  Duration get _elapsed => _clockBase + _clock.elapsed;

  static const _saveId = 'klondike';

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _restore();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_won) setState(() {});
      _persist();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persist();
    super.dispose();
  }

  /// Spielstand sichern, nach einem Sieg löschen.
  void _persist() {
    final s = _store;
    if (_won) {
      s.clearGame(_saveId);
      return;
    }
    if (_e.moves == 0) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {
      'draw': _drawCount,
      'stock': tableCodes(_e.stock),
      'waste': tableCodes(_e.waste),
      'found': [for (final f in _e.foundations) tableCodes(f)],
      'tab': [for (final t in _e.tableau) tableCodes(t)],
      'moves': _e.moves,
      'hints': _hints,
      'paid': cardCodes(_paidCards),
      'secs': _elapsed.inSeconds,
    });
  }

  void _restore() {
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return;
    try {
      _drawCount = d['draw'] as int;
      _e = KlondikeEngine(drawCount: _drawCount)
        ..stock = tableFromCodes(d['stock'] as List)
        ..waste = tableFromCodes(d['waste'] as List)
        ..foundations = [for (final f in d['found'] as List) tableFromCodes(f as List)]
        ..tableau = [for (final t in d['tab'] as List) tableFromCodes(t as List)]
        ..moves = d['moves'] as int;
      _hints = d['hints'] as int;
      _paidCards.addAll(cardsFromCodes(d['paid'] as List));
      _clockBase = Duration(seconds: d['secs'] as int);
      _message = 'Spielstand geladen';
    } catch (e, st) {
      debugLog.error('klondike.spielstand', e, st);
      _app.settings.clearGame(_saveId);
      _e = KlondikeEngine(drawCount: _drawCount);
    }
  }

  void _newGame(int draw) {
    setState(() {
      _drawCount = draw;
      _e = KlondikeEngine(drawCount: draw);
      _won = false;
      _message = '';
      _drag = null;
      _hints = 0;
      _hint = null;
      _lost = false;
      _paidCards.clear();
      _clockBase = Duration.zero;
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

  int get _cost => hintCost(klondikeRewards[_drawCount]!);
  int get _reward => math.max(0, klondikeRewards[_drawCount]! - _hints * _cost);

  void _drawStock() {
    if (_won || _auto || !_e.canDraw) return;
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(() {
      _message = '';
      _hint = null;
      _checkLost();
    });
  }

  /// Zahlt für jede Karte, die zum ersten Mal auf der Ablage liegt.
  void _payFoundations() {
    var n = 0;
    for (final f in _e.foundations) {
      for (final c in f) {
        if (_paidCards.add(c.card)) n++;
      }
    }
    if (n > 0) _app.wallet.credit(n * klondikeCardRewards[_drawCount]!);
  }

  void _hintTap() {
    if (_won || _auto || _hint != null) return;
    final h = klondikeHint(_e);
    if (h == null) {
      setState(() => _message = 'Keine sinnvollen Züge mehr. Rückgängig oder neues Spiel');
      return;
    }
    _app.sfx.play(Sound.tick);
    setState(() {
      _hints++;
      _hint = h;
      _message = h.draw
          ? (_e.stock.isEmpty ? 'Tipp: Stapel wieder umdrehen' : 'Tipp: Karte vom Stapel ziehen')
          : 'Tipp: ${describeHint(h, _e.pile)}';
    });
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
    if (to.kind == PileKind.foundation) _payFoundations();
    setState(() {
      _message = '';
      _hint = null;
      _checkLost();
    });
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
    if (!mounted) return;
    _payFoundations();
    if (_e.isWon) _win();
  }

  void _win() {
    if (_won) return;
    final reward = _reward;
    _clock.stop();
    _payFoundations();
    if (reward > 0) _app.wallet.credit(reward);
    progress.event('solitaire_sieg');
    _app.sfx.play(Sound.bigWin);
    final tips = _hints == 0 ? '' : ' (${_hints == 1 ? 'ein Tipp' : '$_hints Tipps'} abgezogen)';
    setState(() {
      _won = true;
      _app.settings.clearGame(_saveId);
      _hint = null;
      _message = 'Gewonnen! +${formatCoins(reward)} Münzen$tips';
    });
  }

  void _undo() {
    if (_auto || _won || !_e.canUndo) return;
    _e.undo();
    setState(() {
      _message = '';
      _hint = null;
      _checkLost();
    });
  }

  /// Prüft nach jedem Zug, ob es noch weitergeht.
  void _checkLost() {
    final lost = !_won && klondikeStuck(_e);
    if (lost && !_lost) _app.sfx.play(Sound.lose);
    _lost = lost;
  }

  String get _status => _lost && !_won
      ? 'Keine Züge mehr möglich. Leider verloren, Rückgängig oder neues Spiel'
      : _message.isNotEmpty
      ? _message
      : '${_e.moves} Züge, ${formatClock(_elapsed)}';

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      guide: klondikeGuide,
      title: 'Solitaire',
      child: ListenableBuilder(
        listenable: _app.settings,
        builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth > box.maxHeight * 1.5;
          final bar = SolitaireBar(
            message: _status,
            highlight: _won,
            onUndo: _e.canUndo && !_won && !_auto ? _undo : null,
            onNew: _askNew,
            vertical: side,
            onHint: _won || _auto ? null : _hintTap,
            hintLabel: 'Tipp (−${formatCoins(_cost)})',
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
    const g = 6.0;
    final w = box.maxWidth;
    final h = box.maxHeight;
    final fit = math.min(
      math.min((w - 8 * g) / 7, h * cardAspect / 3.4),
      130.0,
    );
    final cw = fitCardWidth(_e.tableau, (fit * _app.settings.cardScale).clamp(24.0, 190.0), h, g)
        .clamp(24.0, 190.0);
    final ch = cw / cardAspect;
    final boardW = 7 * cw + 6 * g;
    final scroll = boardW + 2 * g > w;
    final ox = scroll ? g : (w - boardW) / 2;
    double x(int col) => ox + col * (cw + g);
    final tabY = g + ch + 2 * g;
    final tabH = h - tabY - g;

    void startDrag(Grab grab) => setState(() => _drag = grab);
    void endDrag() => setState(() => _drag = null);

    // Ablagestapel: bis zu drei Karten aufgefächert, nur die oberste ist beweglich
    final waste = _e.waste;
    final shown = math.min(_drawCount == 3 ? 3 : 1, waste.length);
    final wasteStep = cw * 0.3;

    final board = Stack(
      children: [
        Positioned(
          left: x(0),
          top: g,
          child: GestureDetector(
            onTap: _drawStock,
            child: _e.stock.isEmpty
                ? CardSlot(width: cw, icon: waste.isEmpty ? null : Icons.refresh, glow: _hint?.draw ?? false)
                : PlayingCardView(width: cw, highlighted: _hint?.draw ?? false),
          ),
        ),
        for (var i = 0; i < shown; i++)
          Positioned(
            left: x(1) + i * wasteStep,
            top: g,
            child: () {
              final index = waste.length - shown + i;
              final view = PlayingCardView(
                width: cw,
                card: waste[index].card,
                strip: true,
                highlighted: index == waste.length - 1 && _hint?.from?.kind == PileKind.waste,
              );
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
                longPress: scroll,
                child: view,
              );
            }(),
          ),
        for (var f = 0; f < 4; f++)
          Positioned(left: x(3 + f), top: g, child: _foundation(f, cw, startDrag, endDrag, scroll)),
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
              hintFrom: _hint?.from == PileRef(PileKind.tableau, t) ? _hint!.index : null,
              hintTarget: _hint?.to == PileRef(PileKind.tableau, t),
              canPick: (i) => _e.canPick(PileRef(PileKind.tableau, t), i),
              onTap: (i) => _tap(PileRef(PileKind.tableau, t), i),
              canAccept: (grab) => _e.canDrop(grab.from, grab.index, PileRef(PileKind.tableau, t)),
              onAccept: (grab) => _move(grab.from, grab.index, PileRef(PileKind.tableau, t)),
              onDragStart: startDrag,
              onDragEnd: endDrag,
              longPress: scroll,
            ),
          ),
      ],
    );
    return scrollable(board, boardW + 2 * g, w, h, scroll);
  }

  Widget _foundation(
    int f,
    double cw,
    void Function(Grab) startDrag,
    VoidCallback endDrag,
    bool longPress,
  ) {
    final ref = PileRef(PileKind.foundation, f);
    final pile = _e.foundations[f];
    return DragTarget<Grab>(
      onWillAcceptWithDetails: (d) => _e.canDrop(d.data.from, d.data.index, ref),
      onAcceptWithDetails: (d) => _move(d.data.from, d.data.index, ref),
      builder: (context, candidates, _) {
        if (pile.isEmpty) {
          return CardSlot(width: cw, label: 'A', glow: candidates.isNotEmpty || _hint?.to == ref);
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
              longPress: longPress,
              child: PlayingCardView(
                width: cw,
                card: pile.last.card,
                strip: true,
                highlighted: candidates.isNotEmpty || _hint?.to == ref,
              ),
            ),
          ],
        );
      },
    );
  }
}
