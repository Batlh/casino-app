import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import '../board/board_setup.dart';
import '../cards/card_widgets.dart';
import 'chess_ai.dart';
import 'chess_board.dart';
import 'chess_engine.dart';
import 'chess_pieces.dart';

/// Rechnet in einem eigenen Isolate, damit die Oberfläche flüssig bleibt.
Future<ChessMove?> _think(String fen, ChessLevel level, int seed) =>
    Isolate.run(() => chessBestMove(fen, level, seed: seed));

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  ChessGame _g = ChessGame();
  BoardSetup _setup = const BoardSetup(level: 1);
  int? _selected;
  List<ChessMove> _targets = [];
  bool _thinking = false;
  bool _rewarded = false;
  int _reward = 0;
  bool _turnBoard = false;
  int _token = 0;

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  ChessLevel? get _level => _setup.level == null ? null : ChessLevel.values[_setup.level!];
  int get _humanColor => _setup.humanFirst ? white : black;
  bool get _over => _g.result != ChessResult.none;
  bool get _humanTurn => !_over && !_thinking && (_level == null || _g.side == _humanColor);

  /// Schwarz unten: gegen den Computer mit Schwarz, zu zweit wahlweise mitdrehen.
  bool get _flipped => _level != null ? _humanColor == black : (_turnBoard && _g.side == black);

  static const _saveId = 'chess';

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _restore();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeComputer());
  }

  /// Stellt die gespeicherte Partie wieder her, indem alle Züge nachgespielt werden.
  void _restore() {
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return;
    try {
      final level = d['level'] as int?;
      _setup = BoardSetup(level: level, humanFirst: d['first'] as bool);
      final g = ChessGame();
      for (final n in d['moves'] as List) {
        final m = g.legalMoves().firstWhere((x) => x.uci == n);
        g.make(m);
      }
      _g = g;
    } catch (e, st) {
      debugLog.error('schach.spielstand', e, st);
      _app.settings.clearGame(_saveId);
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  @override
  void dispose() {
    _persist();
    super.dispose();
  }

  void _persist() {
    final s = _store;
    if (_over || _g.moves.isEmpty) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {
      'level': _setup.level,
      'first': _setup.humanFirst,
      'moves': [for (final m in _g.moves) m.uci],
    });
  }

  Future<void> _newGame() async {
    final s = await showBoardSetup(
      context,
      levels: [for (final l in ChessLevel.values) l.label],
      rewards: [for (final l in ChessLevel.values) l.reward],
      firstSide: 'Weiß',
      secondSide: 'Schwarz',
    );
    if (s == null || !mounted) return;
    setState(() {
      _token++;
      _setup = s;
      _g = ChessGame();
      _selected = null;
      _targets = [];
      _thinking = false;
      _rewarded = false;
      _reward = 0;
    });
    _app.sfx.play(Sound.card);
    _maybeComputer();
  }

  void _tap(int sq) {
    if (!_humanTurn) return;
    final p = _g.board[sq];
    final hits = _targets.where((m) => m.to == sq).toList();
    if (_selected != null && hits.isNotEmpty) {
      _choose(hits);
      return;
    }
    if (p != 0 && p.sign == _g.side) {
      _app.sfx.play(Sound.tick);
      setState(() {
        _selected = sq;
        _targets = _g.movesFrom(sq);
      });
    } else {
      setState(() {
        _selected = null;
        _targets = [];
      });
    }
  }

  Future<void> _choose(List<ChessMove> hits) async {
    var m = hits.first;
    if (hits.length > 1) {
      const order = [queen, rook, bishop, knight];
      final i = await showChoiceSheet(
        context,
        title: 'Bauer wird zu …',
        options: const ['Dame', 'Turm', 'Läufer', 'Springer'],
      );
      if (i == null || !mounted) return;
      m = hits.firstWhere((h) => h.promo == order[i]);
    }
    _play(m);
    _maybeComputer();
  }

  void _play(ChessMove m) {
    final capture = _g.board[m.to] != 0 || m.enPassant;
    _g.make(m);
    _app.sfx.play(capture ? Sound.chip : Sound.card);
    setState(() {
      _selected = null;
      _targets = [];
    });
    if (_over) _finish();
  }

  Future<void> _maybeComputer() async {
    final level = _level;
    if (level == null || _over || _g.side == _humanColor || _thinking) return;
    setState(() => _thinking = true);
    final token = _token;
    final fen = _g.fen;
    final seed = math.Random().nextInt(1 << 30);
    final wait = Future<void>.delayed(_app.settings.botDelay(500));
    ChessMove? m;
    try {
      m = await _think(fen, level, seed);
    } catch (e, st) {
      debugLog.error('schach.bot', e, st);
      m = chessBestMove(fen, level, seed: seed);
    }
    await wait;
    if (!mounted || token != _token) return;
    setState(() => _thinking = false);
    if (m != null) _play(m);
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    final r = _g.result;
    final level = _level;
    if (level == null) {
      _app.sfx.play(Sound.win);
      return;
    }
    final won = (r == ChessResult.whiteMates && _humanColor == white) ||
        (r == ChessResult.blackMates && _humanColor == black);
    final lost = r == ChessResult.whiteMates || r == ChessResult.blackMates;
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
      // Gegen den Computer bis zum eigenen Zug zurück
      if (_level != null && _g.side != _humanColor && _g.canUndo) _g.unmake();
      _selected = null;
      _targets = [];
      _rewarded = false;
      _reward = 0;
    });
    _maybeComputer();
  }

  String get _status {
    final r = _g.result;
    if (r != ChessResult.none) {
      final base = resultText(r);
      return _reward > 0 ? '$base. +${formatCoins(_reward)} Münzen' : base;
    }
    final who = _g.side == white ? 'Weiß' : 'Schwarz';
    final check = _g.inCheck() ? 'Schach! ' : '';
    if (_thinking) return '${check}Der Computer überlegt …';
    if (_level != null) {
      return _g.inCheck() ? 'Schach! Schütze deinen König' : 'Du bist am Zug${_selected == null ? ', tipp eine Figur an' : ''}';
    }
    return '$check$who ist am Zug';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Schach',
      guide: chessGuide,
      background: const BoxDecoration(color: Color(0xFF2A1A12)),
      child: LayoutBuilder(builder: (context, box) => _layout(box)),
    );
  }

  Widget _captured(int color) {
    // Figuren, die diese Farbe geschlagen hat
    final taken = _g.captured.where((p) => p.sign == -color).toList()..sort((a, b) => b.abs() - a.abs());
    return SizedBox(
      height: 26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (final p in taken) ChessPieceView(piece: p, size: 22)],
      ),
    );
  }

  Widget _layout(BoxConstraints box) {
    final p = Palette.of(context);
    final landscape = box.maxWidth > box.maxHeight * 1.2;
    final bottomColor = _flipped ? black : white;
    final board = ChessBoardView(
      game: _g,
      flipped: _flipped,
      selected: _selected,
      targets: {for (final m in _targets) m.to},
      onTap: _tap,
    );
    final boardBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _captured(-bottomColor),
        Flexible(child: board),
        _captured(bottomColor),
      ],
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
      _level == null ? 'Zu zweit an einem Gerät' : 'Gegen den Computer: ${_level!.label}',
      textAlign: TextAlign.center,
      style: TextStyle(color: p.onFelt, fontSize: 14),
    );
    if (landscape) {
      return Row(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: boardBlock))),
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
        Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Center(child: boardBlock))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: status),
        Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 10), child: buttons),
      ],
    );
  }
}
