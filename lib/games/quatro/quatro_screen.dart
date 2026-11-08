import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../eins/eins_card.dart' show einsColors;
import 'quatro_engine.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const quatroRewardPerOpponent = 50;
const _gold = Color(0xFFFFC95C);

class QuatroScreen extends StatefulWidget {
  const QuatroScreen({super.key});

  @override
  State<QuatroScreen> createState() => _QuatroScreenState();
}

class _QuatroScreenState extends State<QuatroScreen> {
  final _rng = math.Random.secure();
  int _opponents = 1;
  int _round = 0;
  late QuatroEngine _e;
  QTile? _selected;
  int? _swapFirst;
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
    _e = QuatroEngine(
      players: [
        QPlayer('Du', human: true),
        for (var i = 0; i < _opponents; i++) QPlayer(_names[(offset + i) % _names.length]),
      ],
      rng: _rng,
    )..start(startPlayer: _round % (_opponents + 1));
    _selected = null;
    _swapFirst = null;
    _rewarded = false;
  }

  void _newRound() {
    setState(() {
      _round++;
      _setup();
    });
    _app.sfx.play(Sound.chip);
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

  void _select(QTile t) {
    if (!_myTurn || _e.swapPending) return;
    setState(() => _selected = _selected == t ? null : t);
    _app.sfx.play(Sound.tick);
  }

  void _tapColumn(int col) {
    if (!_myTurn) return;
    if (_e.swapPending) {
      if (_swapFirst == null) {
        setState(() => _swapFirst = col);
      } else if (_swapFirst == col) {
        setState(() => _swapFirst = null);
      } else {
        _e.swapColumns(_swapFirst!, col);
        _swapFirst = null;
        _app.sfx.play(Sound.chip);
        setState(() {});
        _after();
      }
      return;
    }
    var t = _selected;
    if (t == null) {
      // Ohne Auswahl: der erste Stein, der in diese Spalte passt
      final fits = _e.actor.hand.where((h) => _e.canPlace(h, col));
      if (fits.isEmpty) return;
      t = fits.first;
    }
    if (!_e.canPlace(t, col)) return;
    _e.place(t, col);
    _selected = null;
    _app.sfx.play(Sound.chip);
    setState(() {});
    if (!_e.swapPending) _after();
  }

  void _exchange() {
    if (!_myTurn || _e.canMove) return;
    _e.exchange(_selected ?? (_e.actor.hand.isEmpty ? null : _e.actor.hand.first));
    _selected = null;
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
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (_e.swapPending) {
        final (a, b) = quatroBotSwap(_e, _rng);
        _e.swapColumns(a, b);
      } else {
        final m = quatroBotChoice(_e, _rng);
        if (m.tile == null) {
          final hand = _e.actor.hand;
          _e.exchange(hand.isEmpty ? null : hand[_rng.nextInt(hand.length)]);
        } else {
          _e.place(m.tile!, m.col);
        }
      }
      _app.sfx.play(Sound.chip);
      setState(() {});
    }
    _running = false;
    if (!mounted) return;
    setState(() {});
    if (_e.finished) _finish();
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.winner?.human ?? false) {
      _app.wallet.credit(quatroRewardPerOpponent * _opponents);
      _app.sfx.play(Sound.win);
    } else {
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    if (_e.finished) {
      if (_e.draw) return _e.lastEvent;
      return _e.winner!.human
          ? 'Vier in einer Reihe! +${formatCoins(quatroRewardPerOpponent * _opponents)} Münzen'
          : '${_e.winner!.name} hat vier in einer Reihe';
    }
    if (_e.actor.human) {
      if (_e.swapPending) {
        return _swapFirst == null ? 'Wähle zwei Spalten zum Tauschen' : 'Und jetzt die zweite Spalte';
      }
      final prefix = _e.lastEvent.isNotEmpty ? '${_e.lastEvent}. ' : '';
      if (!_e.canMove) return '${prefix}Kein Stein passt, tausch einen mit dem Beutel';
      if (_selected == null) return '${prefix}Stein wählen, dann Spalte antippen';
      return 'Spalte antippen';
    }
    return _e.lastEvent.isNotEmpty ? _e.lastEvent : '${_e.actor.name} ist dran';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Viererkette',
      child: LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.25;
    final status = ResultBanner(text: _status, highlight: _e.winner?.human ?? false);
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
                primary: _myTurn && !_e.canMove,
                label: _e.bag.isEmpty ? 'Passen' : 'Stein tauschen',
                onPressed: _myTurn && !_e.canMove && !_e.swapPending ? _exchange : null,
              ),
            ],
    );
    final opponents = Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 1; i < _e.players.length; i++) _opponentChip(i),
        _bagChip(),
        ActionChip(
          avatar: const Icon(Icons.help_outline, size: 18, color: _gold),
          label: const Text('Regeln'),
          labelStyle: const TextStyle(color: Color(0xFFF6E7C8), fontWeight: FontWeight.w700),
          backgroundColor: const Color(0xE62A160E),
          side: const BorderSide(color: Color(0xFF8A5A2B)),
          onPressed: _showRules,
        ),
      ],
    );
    final tileSize = landscape ? math.min(h * 0.16, 76.0) : math.min(math.min(w / 5, h * 0.1), 76.0);
    final hand = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final t in _e.players.first.hand)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: GestureDetector(
              onTap: () => _select(t),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 120),
                offset: Offset(0, _selected == t ? -0.15 : 0),
                child: Opacity(
                  opacity: !_myTurn || _e.columnsFor(t).isNotEmpty ? 1 : 0.45,
                  child: TileView(tile: t, size: tileSize, selected: _selected == t),
                ),
              ),
            ),
          ),
      ],
    );
    final board = Padding(padding: const EdgeInsets.all(6), child: _board());

    if (landscape) {
      return Row(
        children: [
          Expanded(flex: 3, child: board),
          SizedBox(
            width: math.min(340, w * 0.38),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                opponents,
                const SizedBox(height: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(340, w * 0.38),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [status, buttons]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                hand,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        const SizedBox(height: 6),
        opponents,
        Expanded(child: board),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: status),
        Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 6), child: buttons),
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 12), child: hand),
      ],
    );
  }

  void _showRules() {
    const rules = [
      'Jeder hat drei Steine. Wähle einen Stein und tippe eine Spalte an, er fällt nach unten.',
      'Hat das Feld Nachbarn, auch schräg, muss der Stein zu mindestens einem passen: gleiche Farbe oder gleiche Zahl.',
      'Vier gleiche Farben oder vier gleiche Zahlen in einer Reihe gewinnen, waagrecht, senkrecht oder schräg. Der Sieg bringt 50 Münzen pro Gegner.',
      'Spaltentausch: Danach tauschst du zwei ganze Spalten.',
      'Schieber: Passt auf jede Spalte mit Steinen. Der unterste Stein geht zurück in den Beutel, der Schieber landet oben.',
      'Minus zwei: Der Nächste legt zwei zufällige Steine zurück und spielt seinen Zug mit dem Rest.',
      'Passt kein Stein, tauschst du einen gegen den Beutel.',
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final p = Palette.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85, maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Viererkette', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final line in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('•  $line', style: TextStyle(color: p.ink, fontSize: 16, height: 1.3)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _opponentChip(int i) {
    final p = _e.players[i];
    final active = !_e.finished && _e.current == i;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE62A160E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? _gold : const Color(0xFF6B3E1E), width: active ? 3 : 1.5),
      ),
      child: Text(
        '${p.name} · ${p.hand.length} Steine',
        style: const TextStyle(color: Color(0xFFF6E7C8), fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  Widget _bagChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x662A160E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${_e.bag.length} im Beutel',
          style: TextStyle(color: Palette.of(context).onFelt, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      );

  Widget _board() {
    final valid = <int>{
      if (_myTurn && !_e.swapPending)
        for (final t in _selected == null ? _e.actor.hand : [_selected!]) ..._e.columnsFor(t),
    };
    final win = _e.winLine.toSet();
    return LayoutBuilder(
      builder: (context, box) {
        final cell = math.min(box.maxWidth / _e.cols, box.maxHeight / _e.rows).floorToDouble();
        return Center(
          child: Container(
            padding: EdgeInsets.all(cell * 0.06),
            decoration: BoxDecoration(
              color: const Color(0xFF2A160E),
              borderRadius: BorderRadius.circular(cell * 0.2),
              border: Border.all(color: const Color(0xFF8A5A2B), width: 3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < _e.cols; c++)
                  Semantics(
                    button: true,
                    label: 'Spalte ${c + 1}',
                    child: GestureDetector(
                      onTap: () => _tapColumn(c),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _swapFirst == c
                              ? _gold.withValues(alpha: 0.35)
                              : valid.contains(c)
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(cell * 0.15),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var r = _e.rows - 1; r >= 0; r--)
                              SizedBox(
                                width: cell * 0.88,
                                height: cell * 0.88,
                                child: Center(
                                  child: _e.at(c, r) == null
                                      ? Container(
                                          width: cell * 0.78,
                                          height: cell * 0.78,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF140A06),
                                            borderRadius: BorderRadius.circular(cell * 0.14),
                                          ),
                                        )
                                      : TileView(
                                          tile: _e.at(c, r)!,
                                          size: cell * 0.8,
                                          selected: win.contains((c, r)),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TileView extends StatelessWidget {
  const TileView({super.key, required this.tile, required this.size, this.selected = false});

  final QTile tile;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = einsColors[tile.color]!;
    final Widget face = switch (tile.kind) {
      TileKind.number => Text(
          '${tile.number}',
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: size * 0.52,
            height: 1,
            color: Colors.white,
            shadows: const [Shadow(offset: Offset(1, 1), color: Color(0x99000000))],
          ),
        ),
      TileKind.swap => Icon(Icons.swap_horiz, color: Colors.white, size: size * 0.6),
      TileKind.push => Icon(Icons.vertical_align_bottom, color: Colors.white, size: size * 0.6),
      TileKind.minusTwo => Text(
          '−2',
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: size * 0.42,
            height: 1,
            color: Colors.white,
            shadows: const [Shadow(offset: Offset(1, 1), color: Color(0x99000000))],
          ),
        ),
    };
    return Semantics(
      label: tile.label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(
            color: selected ? _gold : const Color(0xFFFFF8E7),
            width: selected ? math.max(3, size * 0.08) : math.max(1.5, size * 0.04),
          ),
          boxShadow: const [BoxShadow(blurRadius: 3, offset: Offset(0, 2), color: Color(0x66000000))],
        ),
        child: face,
      ),
    );
  }
}
