import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_replay_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import '../cards/rewards.dart';
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

class _QuatroScreenState extends State<QuatroScreen> with NetReplayScreen {
  final _rng = math.Random.secure();
  int _opponents = 1;
  int _round = 0;
  late QuatroEngine _e;
  QTile? _selected;
  int? _swapFirst;
  bool _running = false;
  bool _rewarded = false;
  final List<List<Object?>> _log = [];

  AppScope get _app => AppScope.of(context);

  /// Dein Platz: allein immer 0, im Netz je Gerät verschieden.
  int get _me => replayActive ? replayMe : 0;
  QPlayer get _mine => _e.players[_me];
  bool get _myTurn => !_e.finished && _e.current == _me && !_running;

  /// Spielt der Computer diesen Platz (im Netz nur beim Gastgeber)?
  bool _bot(int seat) => replayActive ? replayIsHost && replayIsBot(seat) : seat != 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    replayDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get replayGame => 'viererkette';
  @override
  String get replayTitle => 'Viererkette';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const [];
  @override
  List<List<Object?>> get replayLog => _log;
  @override
  Map<String, Object?> get replayOptions => {'start': _rng.nextInt(4)};

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _log.clear();
    _e = QuatroEngine(
      players: [for (final (i, n) in names.indexed) QPlayer(n, human: i == me)],
      rng: math.Random(seed),
    )..start(startPlayer: ((options['start'] as num?)?.toInt() ?? 0) % names.length);
    _selected = null;
    _swapFirst = null;
    _rewarded = false;
    _running = false;
  }

  @override
  void replayApply(List<dynamic> a) => _apply(a);

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    if (_e.finished || seat != _e.current) return false;
    return switch (a[0]) {
      'p' => !_e.swapPending && _e.actor.hand.any((t) => t.id == a[1] && _e.canPlace(t, (a[2] as num).toInt())),
      's' => _e.swapPending && a[1] != a[2],
      'x' => !_e.swapPending && _e.exchanged == null && !_e.canMove,
      'e' => !_e.swapPending && _e.exchanged != null,
      _ => false,
    };
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    if (acts.isNotEmpty) _app.sfx.play(Sound.chip);
    if (_selected != null && !_mine.hand.contains(_selected)) _selected = null;
    setState(() {});
    _after();
  }

  @override
  void replayClosed() => _newRound();

  /// Zug ausführen: allein und beim Gastgeber sofort, als Mitspieler über den Gastgeber.
  void _do(List<Object?> a) {
    if (replaySend(a)) return;
    _apply(a);
    replayBroadcast();
  }

  void _apply(List<dynamic> a) {
    final seat = _e.current;
    switch (a[0]) {
      case 'p':
        final t = _e.actor.hand.firstWhere((t) => t.id == (a[1] as num).toInt());
        final col = (a[2] as num).toInt();
        final next = _e.players[(_e.current + 1) % _e.players.length];
        final threatsBefore = seat == _me ? _threats(next) : 0;
        _e.place(t, col);
        if (seat == _me && !_e.finished) {
          var bonus = t.kind == TileKind.plain ? 0 : actionTileReward;
          // Eine Viererreihe des Nächsten verhindert
          if (threatsBefore > 0 && _threats(next) < threatsBefore) bonus += blockReward;
          if (bonus > 0) _app.wallet.credit(bonus);
        }
      case 's':
        _e.swapColumns((a[1] as num).toInt(), (a[2] as num).toInt());
      case 'x':
        final id = (a[1] as num).toInt();
        _e.exchange(id < 0 ? null : _e.actor.hand.firstWhere((t) => t.id == id));
      case 'e':
        _e.endTurn();
      default:
        throw StateError('Unbekannter Zug $a');
    }
    _log.add(a);
  }

  void _setup() {
    _log.clear();
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
        final first = _swapFirst!;
        _swapFirst = null;
        _do(['s', first, col]);
        _app.sfx.play(Sound.chip);
        setState(() {});
        if (!replayIsGuest) _after();
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
    _selected = null;
    _do(['p', t.id, col]);
    _app.sfx.play(Sound.chip);
    setState(() {});
    if (!replayIsGuest && !_e.swapPending) _after();
  }

  /// In wie vielen Spalten dieser Spieler sofort gewinnen könnte.
  int _threats(QPlayer p) => {
        for (final h in p.hand)
          for (final c in _e.columnsFor(h))
            if (h.kind != TileKind.push && _e.wouldWin(h, c)) c,
      }.length;

  void _exchange() {
    if (!_myTurn) return;
    if (_e.exchanged != null) {
      _do(['e']);
    } else {
      if (_e.canMove) return;
      final t = _selected ?? (_e.actor.hand.isEmpty ? null : _e.actor.hand.first);
      _do(['x', t?.id ?? -1]);
      _selected = replayIsGuest ? null : _e.exchanged;
    }
    setState(() {});
    if (!replayIsGuest) _after();
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
    final engine = _e;
    while (mounted && identical(engine, _e) && !_e.finished && _bot(_e.current)) {
      await Future<void>.delayed(_app.settings.botDelay(800));
      if (!mounted || !identical(engine, _e) || _e.finished || !_bot(_e.current)) break;
      if (_e.swapPending) {
        final (a, b) = quatroBotSwap(_e, _rng);
        _do(['s', a, b]);
      } else {
        final m = quatroBotChoice(_e, _rng);
        if (m.tile != null) {
          _do(['p', m.tile!.id, m.col]);
        } else if (_e.exchanged != null) {
          _do(['e']);
        } else {
          final hand = _e.actor.hand;
          _do(['x', hand.isEmpty ? -1 : hand[_rng.nextInt(hand.length)].id]);
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
    if (_e.winner == _mine) {
      _app.wallet.credit(quatroRewardPerOpponent * (_e.players.length - 1));
      _app.sfx.play(Sound.win);
    } else {
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    if (_e.finished) {
      if (_e.draw) return _e.lastEvent;
      return _e.winner == _mine
          ? 'Vier in einer Reihe! +${formatCoins(quatroRewardPerOpponent * (_e.players.length - 1))} Münzen'
          : '${_e.winner!.name} hat vier in einer Reihe';
    }
    if (_e.current == _me) {
      if (_e.swapPending) {
        return _swapFirst == null ? 'Wähle zwei Spalten zum Tauschen' : 'Und jetzt die zweite Spalte';
      }
      final prefix = _e.lastEvent.isNotEmpty ? '${_e.lastEvent}. ' : '';
      if (_e.exchanged != null) return '${prefix}Leg den neuen Stein oder beende den Zug';
      if (!_e.canMove) return '${prefix}Kein Stein passt, tausch einen mit dem Beutel';
      if (_selected == null) return '${prefix}Stein wählen, dann Spalte antippen';
      return 'Spalte antippen';
    }
    return _e.lastEvent.isNotEmpty ? _e.lastEvent : '${_e.actor.name} ist dran';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      guide: quatroGuide,
      title: 'Viererkette',
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _layout(BoxConstraints box) {
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.25;
    final status = ResultBanner(text: _status, highlight: _e.winner != null && _e.winner == _mine, maxLines: 2);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _e.finished
          ? replayActive
              ? replayButtons(label: 'Neue Runde', next: replayHostStart)
              : [
                  ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
                  ActionButton(label: 'Gegner wählen', onPressed: _askOpponents),
                ]
          : [
              ActionButton(
                primary: _myTurn && (!_e.canMove || _e.exchanged != null),
                label: _e.exchanged != null ? 'Zug beenden' : (_e.bag.isEmpty ? 'Passen' : 'Stein tauschen'),
                onPressed: _myTurn && (!_e.canMove || _e.exchanged != null) && !_e.swapPending ? _exchange : null,
              ),
            ],
    );
    final opponents = Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _e.players.length; i++)
          if (i != _me) _opponentChip(i),
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
        for (final t in _mine.hand)
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
      '44 Steine in vier Farben mit den Zahlen 0 bis 5. Jeder hat drei Steine. Wähle einen Stein und tippe eine Spalte an, er fällt nach unten.',
      'Hat das Feld Nachbarn, auch schräg, muss der Stein zu mindestens einem passen: gleiche Farbe oder gleiche Zahl. Auch Aktionssteine haben eine Zahl.',
      'Vier gleiche Farben oder vier gleiche Zahlen in einer Reihe gewinnen, waagrecht, senkrecht oder schräg. Der Sieg bringt 50 Münzen pro Gegner.',
      'Spaltentausch: Danach tauschst du zwei ganze Spalten.',
      'Schieber: Darf auch in eine volle Spalte. Der unterste Stein fällt heraus und geht zurück in den Beutel. In einer leeren Spalte bleibt er einfach liegen.',
      'Minus zwei: Der Nächste legt zwei zufällige Steine zurück und spielt seinen Zug mit dem Rest.',
      'Passt kein Stein, tauschst du einen gegen den Beutel. Passt der neue, darfst du ihn sofort legen.',
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
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
    final icon = switch (tile.kind) {
      TileKind.plain => null,
      TileKind.swap => Icons.swap_horiz,
      TileKind.push => Icons.vertical_align_bottom,
      TileKind.minusTwo => Icons.exposure_neg_2,
    };
    final Widget face = Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: icon == null ? Alignment.center : const Alignment(-0.35, -0.3),
          child: Text(
          '${tile.number}',
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: size * (icon == null ? 0.52 : 0.42),
            height: 1,
            color: Colors.white,
            shadows: const [Shadow(offset: Offset(1, 1), color: Color(0x99000000))],
          ),
        ),
        ),
        if (icon != null)
          Positioned(
            right: size * 0.04,
            bottom: size * 0.02,
            child: Container(
              padding: EdgeInsets.all(size * 0.02),
              decoration: const BoxDecoration(color: Color(0xCC2A160E), shape: BoxShape.circle),
              child: Icon(icon, color: _gold, size: size * 0.28),
            ),
          ),
      ],
    );
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
