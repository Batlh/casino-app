import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'mahjong_tutorial.dart';
import 'shisen_engine.dart';
import 'tiles.dart';
import '../../ui/tap_catcher.dart';
import 'tile_legend.dart';

const shisenHintCost = 30;
const shisenShuffleCost = 50;

/// Brettgrößen: (Spalten, Zeilen, Belohnung).
const shisenSizes = <String, (int, int, int)>{
  'Klein (72 Steine)': (12, 6, 150),
  'Groß (144 Steine)': (18, 8, 300),
};

final shisenGuide = GameGuide(
  'Shisen-Sho',
  [
    GuideSection(
      'Ziel',
      'Räume alle Steine ab, immer zwei gleiche auf einmal. Blumen passen zu Blumen, Jahreszeiten zu Jahreszeiten.',
      picture: (_) => Wrap(spacing: 2, children: [for (final t in const [4, 4, 31, 31, 34, 36]) TileView(tile: t, width: 24)]),
    ),
    const GuideSection(
      'Verbinden',
      'Zwei gleiche Steine verschwinden, wenn man sie mit einer Linie aus höchstens drei geraden Stücken verbinden kann, also mit '
          'höchstens zwei Knicken. Die Linie darf nur über leere Felder laufen, auch außen um das Brett herum.',
    ),
    const GuideSection(
      'Hilfen',
      'Ein Tipp kostet $shisenHintCost, Mischen $shisenShuffleCost Münzen von der Belohnung. Rückgängig ist frei. '
          'Jedes Paar bringt 2 Münzen, ein leeres Brett 150 (klein) oder 300 (groß).',
    ),
  ],
  tutorial: (_) => const QuizTutorialScreen(title: 'Shisen-Sho lernen', lessons: shisenLessons),
  tutorialLabel: 'Übungen starten',
);

const shisenLessons = [
  QuizLesson(
    title: 'Gleiche Paare',
    text: 'Wie beim Mahjong Solitär räumst du gleiche Steine paarweise ab. Hier liegen alle Steine flach nebeneinander.',
    tiles: [4, 13, 4, 22],
    question: 'Welche zwei Steine bilden ein Paar?',
    textOptions: ['Erster und zweiter', 'Erster und dritter', 'Zweiter und vierter'],
    correct: 1,
    explain: 'Richtig, zweimal die 5 Zeichen.',
  ),
  QuizLesson(
    title: 'Höchstens zwei Knicke',
    text: 'Die Verbindung darf zweimal abbiegen, aber nicht öfter. Eine gerade Linie oder ein L geht immer, solange nichts im Weg liegt.',
    question: 'Wie viele Knicke darf die Linie haben?',
    textOptions: ['Keinen', 'Höchstens zwei', 'Beliebig viele'],
    correct: 1,
    explain: 'Genau. Drei gerade Stücke mit zwei Knicken sind das Maximum.',
  ),
  QuizLesson(
    title: 'Außen herum',
    text: 'Steine am Rand kannst du außen um das Brett herum verbinden: zwei Steine in der obersten Reihe passen fast immer zusammen.',
    question: 'Darf die Linie außerhalb des Bretts verlaufen?',
    textOptions: ['Ja', 'Nein'],
    correct: 0,
    explain: 'Richtig. Darum lohnt es sich, Steine am Rand für später aufzuheben.',
  ),
];

class ShisenScreen extends StatefulWidget {
  const ShisenScreen({super.key, this.seed});
  final int? seed;

  @override
  State<ShisenScreen> createState() => _ShisenScreenState();
}

class _ShisenScreenState extends State<ShisenScreen> {
  String _size = shisenSizes.keys.first;
  late ShisenSho _e = _make(widget.seed);
  int? _selected;
  (int, int)? _hint;
  List<math.Point<int>>? _line;
  Timer? _lineTimer;
  int _penalty = 0;
  int _paidPairs = 0;
  bool _won = false;
  String _message = '';

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  int get _baseReward => shisenSizes[_size]!.$3;

  static const _saveId = 'shisen';
  bool get _saving => widget.seed == null;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    if (!_saving) return;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return;
    try {
      final size = d['size'] as String;
      if (!shisenSizes.containsKey(size)) throw const FormatException();
      final cells = [for (final c in d['cells'] as List) c as int];
      final dims = shisenSizes[size]!;
      if (cells.length != dims.$1 * dims.$2) throw const FormatException();
      _size = size;
      _e = _make()..cells = cells;
      _penalty = d['penalty'] as int;
      _message = 'Spielstand geladen';
    } catch (e, st) {
      debugLog.error('shisen.spielstand', e, st);
      _app.settings.clearGame(_saveId);
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  void _persist() {
    if (!_saving) return;
    final s = _store;
    if (_won || _e.remaining == _e.cols * _e.rows) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'size': _size, 'cells': _e.cells, 'penalty': _penalty});
  }
  int get _reward => math.max(0, _baseReward - _penalty);

  ShisenSho _make([int? seed]) {
    final s = shisenSizes[_size]!;
    return ShisenSho(rng: seed == null ? null : math.Random(seed), cols: s.$1, rows: s.$2);
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _persist();
    super.dispose();
  }

  void _newGame() {
    setState(() {
      _e = _make();
      _selected = null;
      _hint = null;
      _line = null;
      _penalty = 0;
      _paidPairs = 0;
      _won = false;
      _message = '';
    });
    _app.sfx.play(Sound.card);
  }

  Future<void> _chooseSize() async {
    final keys = shisenSizes.keys.toList();
    final i = await showChoiceSheet(context, title: 'Welche Größe?', options: keys);
    if (i == null || !mounted) return;
    _size = keys[i];
    _newGame();
  }

  void _tap(int i) {
    if (_won || _e.cells[i] < 0) return;
    final sel = _selected;
    if (sel == null || sel == i) {
      setState(() => _selected = sel == i ? null : i);
      _app.sfx.play(Sound.tick);
      return;
    }
    final p = _e.remove(sel, i);
    if (p == null) {
      setState(() {
        _selected = i;
        _message = tilesSame(_e.cells[sel], _e.cells[i]) ? 'Keine Verbindung mit höchstens zwei Knicken frei' : '';
      });
      _app.sfx.play(Sound.tick);
      return;
    }
    _app.sfx.play(Sound.chip);
    if (_e.removedPairs > _paidPairs) {
      _paidPairs = _e.removedPairs;
      _app.wallet.credit(2);
    }
    _lineTimer?.cancel();
    _lineTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _line = null);
    });
    setState(() {
      _line = p;
      _selected = null;
      _hint = null;
      _message = '';
    });
    if (_e.won) {
      _won = true;
      if (_reward > 0) _app.wallet.credit(_reward);
      _app.sfx.play(Sound.bigWin);
      setState(() => _message = 'Alles abgeräumt! +${formatCoins(_reward)} Münzen');
    } else if (_e.stuck) {
      _app.sfx.play(Sound.lose);
      setState(() => _message = 'Kein Paar mehr verbindbar – mischen oder zurück');
    }
  }

  void _hintTap() {
    if (_won) return;
    final pairs = _e.freePairs();
    if (pairs.isEmpty) {
      setState(() => _message = 'Kein Paar frei. Mischen hilft');
      return;
    }
    setState(() {
      if (_hint == null) _penalty += shisenHintCost;
      _hint = pairs[math.Random().nextInt(pairs.length)];
      _message = 'Tipp: ${tileName(_e.cells[_hint!.$1])}';
    });
  }

  void _shuffle() {
    if (_won) return;
    _e.shuffle();
    _app.sfx.play(Sound.card);
    setState(() {
      _penalty += shisenShuffleCost;
      _selected = null;
      _hint = null;
      _message = 'Neu gemischt';
    });
  }

  void _undo() {
    if (_won || !_e.canUndo) return;
    _e.undo();
    setState(() {
      _selected = null;
      _hint = null;
      _message = '';
    });
  }

  String get _status {
    if (_message.isNotEmpty) return _message;
    return '${_e.remaining} Steine übrig. Sieg bringt ${formatCoins(_reward)}';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      actions: const [TileLegendButton()],
      title: 'Shisen-Sho',
      guide: shisenGuide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.1, colors: [Color(0xFF3B2A6B), Color(0xFF15102B)]),
      ),
      child: Column(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(6), child: LayoutBuilder(builder: (context, b) => _board(b)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ResultBanner(text: _status, highlight: _won, maxLines: 2)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionButton(label: 'Tipp (−$shisenHintCost)', onPressed: _won ? null : _hintTap),
                ActionButton(primary: _e.stuck, label: 'Mischen (−$shisenShuffleCost)', onPressed: _won ? null : _shuffle),
                ActionButton(label: 'Rückgängig', onPressed: _e.canUndo && !_won ? _undo : null),
                ActionButton(label: _size.split(' ').first, onPressed: _chooseSize),
                ActionButton(primary: _won, label: 'Neues Spiel', onPressed: _newGame),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _board(BoxConstraints b) {
    // Ein Feld Rand rundherum für Linien außen
    final tw = math.min(b.maxWidth / (_e.cols + 1), b.maxHeight / ((_e.rows + 1) / TileView.aspect));
    final th = tw / TileView.aspect;
    final w = tw * (_e.cols + 1);
    final h = th * (_e.rows + 1);
    Offset center(math.Point<int> p) => Offset((p.x + 1) * tw, (p.y + 1) * th);
    return Center(
      child: TapCatcher(
        area: 'shisen',
        onTap: (pos) {
          // Feld aus der Position, die Lücken zwischen den Steinen zählen mit
          final c = (pos.dx / tw - 0.5).floor();
          final r = (pos.dy / th - 0.5).floor();
          if (c < 0 || r < 0 || c >= _e.cols || r >= _e.rows) return;
          final i = r * _e.cols + c;
          debugLog.detail('shisen', 'Tippen Feld $c/$r: ${_e.cells[i] >= 0 ? 'Stein' : 'leer'}');
          if (_e.cells[i] >= 0) _tap(i);
        },
        child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            for (var i = 0; i < _e.cells.length; i++)
              if (_e.cells[i] >= 0)
                Positioned(
                  left: (i % _e.cols + 0.5) * tw,
                  top: (i ~/ _e.cols + 0.5) * th,
                  child: IgnorePointer(
                    child: TileView(
                      tile: _e.cells[i],
                      width: tw - 1,
                      selected: _selected == i || (_hint != null && (_hint!.$1 == i || _hint!.$2 == i)),
                    ),
                  ),
                ),
            if (_line != null)
              IgnorePointer(
                child: CustomPaint(size: Size(w, h), painter: _LinePainter([for (final p in _line!) center(p)])),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

bool tilesSame(int a, int b) => a == b || (a >= firstFlower && b >= firstFlower && (a < firstSeason) == (b < firstSeason));

class _LinePainter extends CustomPainter {
  _LinePainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFC95C),
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}
