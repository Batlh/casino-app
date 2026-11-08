import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import '../board/board_setup.dart';
import '../cards/card_widgets.dart';
import 'shogi_ai.dart';
import 'shogi_board.dart';
import 'shogi_engine.dart';

String shogiResultText(ShogiResult r) => switch (r) {
      ShogiResult.none => '',
      ShogiResult.senteWins => 'Matt, Sente gewinnt',
      ShogiResult.goteWins => 'Matt, Gote gewinnt',
      ShogiResult.repetition => 'Remis durch vierfache Wiederholung',
    };

/// Rechnet in einem eigenen Isolate, damit die Oberfläche flüssig bleibt.
Future<ShogiMove?> _think(ShogiGame g, ShogiLevel level, int seed) =>
    Isolate.run(() => shogiBestMoveFor(g, level, seed: seed));

class ShogiScreen extends StatefulWidget {
  const ShogiScreen({super.key});

  @override
  State<ShogiScreen> createState() => _ShogiScreenState();
}

class _ShogiScreenState extends State<ShogiScreen> {
  ShogiGame _g = ShogiGame();
  BoardSetup _setup = const BoardSetup(level: 1);
  int? _selected;
  int? _dropType;
  List<ShogiMove> _targets = [];
  bool _thinking = false;
  bool _rewarded = false;
  int _reward = 0;
  bool _turnBoard = false;
  int _token = 0;

  AppScope get _app => AppScope.of(context);
  ShogiLevel? get _level => _setup.level == null ? null : ShogiLevel.values[_setup.level!];
  int get _humanColor => _setup.humanFirst ? sente : gote;
  ShogiResult get _result => _g.result;
  bool get _over => _result != ShogiResult.none;
  bool get _humanTurn => !_over && !_thinking && (_level == null || _g.side == _humanColor);
  bool get _flipped => _level != null ? _humanColor == gote : (_turnBoard && _g.side == gote);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeComputer());
  }

  Future<void> _newGame() async {
    final s = await showBoardSetup(
      context,
      levels: [for (final l in ShogiLevel.values) l.label],
      rewards: [for (final l in ShogiLevel.values) l.reward],
      firstSide: 'Sente (unten, zieht zuerst)',
      secondSide: 'Gote',
    );
    if (s == null || !mounted) return;
    setState(() {
      _token++;
      _setup = s;
      _g = ShogiGame();
      _clearSelection();
      _thinking = false;
      _rewarded = false;
      _reward = 0;
    });
    _app.sfx.play(Sound.card);
    _maybeComputer();
  }

  void _clearSelection() {
    _selected = null;
    _dropType = null;
    _targets = [];
  }

  void _tapBoard(int sq) {
    if (!_humanTurn) return;
    final hits = _targets.where((m) => m.to == sq).toList();
    if (hits.isNotEmpty) {
      _choose(hits);
      return;
    }
    final p = _g.board[sq];
    setState(() {
      _clearSelection();
      if (p != 0 && p.sign == _g.side) {
        _selected = sq;
        _targets = _g.movesFrom(sq);
      }
    });
    if (p != 0 && p.sign == _g.side) _app.sfx.play(Sound.tick);
  }

  void _tapHand(int color, int t) {
    if (!_humanTurn || color != _g.side) return;
    setState(() {
      if (_dropType == t) {
        _clearSelection();
      } else {
        _clearSelection();
        _dropType = t;
        _targets = _g.dropsOf(t);
      }
    });
    _app.sfx.play(Sound.tick);
  }

  Future<void> _choose(List<ShogiMove> hits) async {
    var m = hits.first;
    if (hits.length > 1) {
      final t = _g.board[m.from].abs();
      final i = await showChoiceSheet(
        context,
        title: '${shogiPieceName(t)} befördern?',
        options: ['Ja, zu ${shogiPieceName(t + promoted)}', 'Nein, so lassen'],
      );
      if (i == null || !mounted) return;
      m = hits.firstWhere((h) => h.promote == (i == 0));
    }
    _play(m);
    _maybeComputer();
  }

  void _play(ShogiMove m) {
    final capture = !m.isDrop && _g.board[m.to] != 0;
    _g.make(m);
    _app.sfx.play(capture ? Sound.chip : Sound.card);
    setState(_clearSelection);
    if (_over) _finish();
  }

  Future<void> _maybeComputer() async {
    final level = _level;
    if (level == null || _over || _g.side == _humanColor || _thinking) return;
    setState(() => _thinking = true);
    final token = _token;
    final copy = _g.copy();
    final seed = math.Random().nextInt(1 << 30);
    final wait = Future<void>.delayed(_app.settings.botDelay(500));
    ShogiMove? m;
    try {
      m = await _think(copy, level, seed);
    } catch (_) {
      m = shogiBestMoveFor(copy, level, seed: seed);
    }
    await wait;
    if (!mounted || token != _token) return;
    setState(() => _thinking = false);
    if (m != null) _play(m);
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    final r = _result;
    final level = _level;
    if (level == null) {
      _app.sfx.play(Sound.win);
      return;
    }
    final won = (r == ShogiResult.senteWins && _humanColor == sente) || (r == ShogiResult.goteWins && _humanColor == gote);
    final lost = r == ShogiResult.senteWins || r == ShogiResult.goteWins;
    _reward = won ? level.reward : (lost ? 0 : level.reward ~/ 2);
    if (_reward > 0) _app.wallet.credit(_reward);
    _app.sfx.play(won ? Sound.bigWin : (lost ? Sound.lose : Sound.coin));
    setState(() {});
  }

  void _undo() {
    if (_thinking || !_g.canUndo) return;
    setState(() {
      _token++;
      _g.unmake();
      if (_level != null && _g.side != _humanColor && _g.canUndo) _g.unmake();
      _clearSelection();
      _rewarded = false;
      _reward = 0;
    });
    _maybeComputer();
  }

  String get _status {
    final r = _result;
    if (r != ShogiResult.none) {
      final base = shogiResultText(r);
      return _reward > 0 ? '$base. +${formatCoins(_reward)} Münzen' : base;
    }
    final check = _g.inCheck() ? 'Ōte! Der König steht im Schach. ' : '';
    if (_thinking) return '${check}Der Computer überlegt …';
    if (_level != null) {
      if (_dropType != null) return 'Tipp ein freies Feld zum Einsetzen an';
      return '${check}Du bist am Zug';
    }
    return '$check${_g.side == sente ? 'Sente' : 'Gote'} ist am Zug';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Shogi',
      guide: shogiGuide,
      background: const BoxDecoration(color: Color(0xFF3A2116)),
      child: LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _layout(BoxConstraints box) {
    final p = Palette.of(context);
    final landscape = box.maxWidth > box.maxHeight * 1.2;
    final bottom = _flipped ? gote : sente;
    final pieceSize = landscape ? math.min(box.maxHeight * 0.07, 40.0) : math.min(box.maxWidth * 0.1, 40.0);
    Widget handOf(int color) => ShogiHandView(
          hand: _g.hand(color),
          color: color,
          size: pieceSize,
          selected: color == _g.side ? _dropType : null,
          upsideDown: color != bottom,
          onTap: (t) => _tapHand(color, t),
        );
    final board = ShogiBoardView(
      game: _g,
      flipped: _flipped,
      selected: _selected,
      targets: {for (final m in _targets) m.to},
      onTap: _tapBoard,
    );
    final boardBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [handOf(-bottom), const SizedBox(height: 4), Flexible(child: board), const SizedBox(height: 4), handOf(bottom)],
    );
    final status = ResultBanner(text: _status, highlight: _reward > 0, maxLines: 2);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ActionButton(primary: _over, label: 'Neues Spiel', onPressed: _thinking ? null : _newGame),
        ActionButton(label: 'Rückgängig', onPressed: _g.canUndo && !_thinking ? _undo : null),
        if (_level == null)
          ActionButton(
            label: _turnBoard ? 'Brett fest' : 'Brett mitdrehen',
            onPressed: () => setState(() => _turnBoard = !_turnBoard),
          ),
      ],
    );
    final info = Text(
      _level == null
          ? 'Zu zweit an einem Gerät'
          : 'Gegen den Computer: ${_level!.label}. Du spielst ${_humanColor == sente ? 'Sente' : 'Gote'}',
      textAlign: TextAlign.center,
      style: TextStyle(color: p.onFelt, fontSize: 14),
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(6), child: Center(child: boardBlock))),
          SizedBox(
            width: math.min(320, box.maxWidth * 0.36),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [info, const SizedBox(height: 8), status, const SizedBox(height: 8), buttons],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: info),
        Expanded(child: Padding(padding: const EdgeInsets.all(6), child: Center(child: boardBlock))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: status),
        Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 10), child: buttons),
      ],
    );
  }
}
