import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'solitaire_engine.dart';
import 'tiles.dart';
import '../../ui/tap_catcher.dart';

const mahjongSolitaireReward = 300;
const mahjongHintCost = 30;
const mahjongShuffleCost = 50;

class MahjongSolitaireScreen extends StatefulWidget {
  const MahjongSolitaireScreen({super.key, this.seed, this.layout = SolitaireLayout.turtle});
  final SolitaireLayout layout;

  /// Fester Zufall für Tests und Bilder.
  final int? seed;

  @override
  State<MahjongSolitaireScreen> createState() => _MahjongSolitaireScreenState();
}

class _MahjongSolitaireScreenState extends State<MahjongSolitaireScreen> {
  late SolitaireLayout _layout = widget.layout;
  late MahjongSolitaire _e = MahjongSolitaire(rng: widget.seed == null ? null : math.Random(widget.seed), layout: widget.layout);
  int? _selected;
  (int, int)? _hint;
  int _penalty = 0;
  int _paidPairs = 0;
  bool _won = false;
  String _message = '';

  /// Für Spielstände; auch beim Schließen noch erreichbar.
  late final Settings _store;

  AppScope get _app => AppScope.of(context);
  int get _reward => math.max(0, mahjongSolitaireReward - _penalty);

  static const _saveId = 'mahjongSolitaire';
  bool get _saving => widget.seed == null;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    if (!_saving) return;
    final d = _app.settings.loadGame(_saveId);
    if (d == null) return;
    try {
      _layout = SolitaireLayout.values.byName(d['layout'] as String);
      final e = MahjongSolitaire(layout: _layout);
      final tiles = [for (final t in d['tiles'] as List) t as int];
      final present = [for (final p in d['present'] as List) p as bool];
      if (tiles.length != e.slots.length || present.length != e.slots.length) throw const FormatException();
      e
        ..tiles = tiles
        ..present = present;
      _e = e;
      _penalty = d['penalty'] as int;
      _message = 'Spielstand geladen';
    } catch (e, st) {
      debugLog.error('mahjong.solitaer.spielstand', e, st);
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
    if (!_saving) return;
    final s = _store;
    if (_won || _e.present.every((p) => p)) {
      s.clearGame(_saveId);
      return;
    }
    s.saveGame(_saveId, {'layout': _layout.name, 'tiles': _e.tiles, 'present': _e.present, 'penalty': _penalty});
  }

  Future<void> _chooseLayout() async {
    final opts = SolitaireLayout.values;
    final i = await showChoiceSheet(
      context,
      title: 'Welche Form?',
      options: [for (final l in opts) '${solitaireLayoutNames[l]} (${layoutSlots(l).length} Steine)'],
    );
    if (i == null || !mounted) return;
    _layout = opts[i];
    _newGame();
  }

  void _newGame() {
    setState(() {
      _e = MahjongSolitaire(layout: _layout);
      _selected = null;
      _hint = null;
      _penalty = 0;
      _paidPairs = 0;
      _won = false;
      _message = '';
    });
    _app.sfx.play(Sound.card);
  }

  void _tap(int i) {
    if (_won) return;
    if (!_e.isFree(i)) {
      _app.sfx.play(Sound.tick);
      setState(() => _message = 'Nicht frei: links oder rechts muss Platz sein, oben nichts drauf');
      return;
    }
    final sel = _selected;
    if (sel == null || sel == i) {
      setState(() {
        _selected = sel == i ? null : i;
        _message = '';
      });
      _app.sfx.play(Sound.tick);
      return;
    }
    if (_e.remove(sel, i)) {
      _app.sfx.play(Sound.chip);
      if (_e.removedPairs > _paidPairs) {
        _paidPairs = _e.removedPairs;
        _app.wallet.credit(2);
      }
      setState(() {
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
        setState(() => _message = 'Kein Paar mehr frei – mischen oder zurück');
      }
    } else {
      setState(() {
        _selected = i;
        _message = '';
      });
      _app.sfx.play(Sound.tick);
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
      if (_hint == null) _penalty += mahjongHintCost;
      _hint = pairs[math.Random().nextInt(pairs.length)];
      _message = 'Tipp: ${tileName(_e.tiles[_hint!.$1])}';
    });
  }

  void _shuffle() {
    if (_won) return;
    _e.shuffle();
    _app.sfx.play(Sound.card);
    setState(() {
      _penalty += mahjongShuffleCost;
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
    final pairs = _e.freePairs().length;
    return '${_e.remaining} Steine übrig, $pairs ${pairs == 1 ? 'Paar' : 'Paare'} frei. Sieg bringt ${formatCoins(_reward)}';
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Mahjong Solitär',
      guide: mahjongSolitaireGuide,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.1, colors: [Color(0xFF1F5E4A), Color(0xFF0E2E24)]),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight * 1.2;
          final board = InteractiveViewer(
            maxScale: 3,
            child: LayoutBuilder(builder: (context, b) => _board(b)),
          );
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionButton(label: 'Tipp (−$mahjongHintCost)', onPressed: _won ? null : _hintTap),
              ActionButton(
                primary: _e.stuck,
                label: 'Mischen (−$mahjongShuffleCost)',
                onPressed: _won ? null : _shuffle,
              ),
              ActionButton(label: 'Rückgängig', onPressed: _e.canUndo && !_won ? _undo : null),
              ActionButton(label: 'Form: ${solitaireLayoutNames[_layout]}', onPressed: _chooseLayout),
              ActionButton(primary: _won, label: 'Neues Spiel', onPressed: _newGame),
            ],
          );
          final status = ResultBanner(text: _status, highlight: _won, maxLines: 2);
          if (landscape && box.maxWidth > 900) {
            return Row(
              children: [
                Expanded(child: board),
                SizedBox(
                  width: 240,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [status, const SizedBox(height: 8), buttons],
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: board),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: status),
              Padding(padding: const EdgeInsets.fromLTRB(8, 2, 8, 8), child: buttons),
            ],
          );
        },
      ),
    );
  }

  Widget _board(BoxConstraints b) {
    final m = _Metrics.fit(b.maxWidth, b.maxHeight, _e.slots);
    return TapCatcher(
      area: 'mahjong.solitaer',
      onTap: (pos) {
        final i = m.hit(_e, pos);
        debugLog.detail('mahjong.solitaer', 'Tippen bei (${pos.dx.round()}, ${pos.dy.round()}): ${i == null ? 'kein Stein' : 'Stein $i, ${_e.isFree(i) ? 'frei' : 'nicht frei'}'}');
        if (i != null) _tap(i);
      },
      child: CustomPaint(
        size: Size(b.maxWidth, b.maxHeight),
        painter: _SolitairePainter(_e, m, _selected, _hint),
      ),
    );
  }
}

class _Metrics {
  _Metrics(this.ux, this.ox, this.oy);

  factory _Metrics.fit(double w, double h, List<Slot> slots) {
    // Größe aus der Form: Breite und Höhe in Einheiten, dazu Ebenenversatz und Kante
    var maxX = 0;
    var maxY = 0;
    for (final s in slots) {
      maxX = math.max(maxX, s.x + 2);
      maxY = math.max(maxY, s.y + 2);
    }
    final units = maxX.toDouble();
    final rows = maxY.toDouble();
    final byW = w / (units + 4 * 0.35 + 0.3);
    final byH = h / (rows / TileView.aspect + 4 * 0.35 + 0.3);
    final ux = math.min(byW, byH) * 0.97;
    final bw = ux * (units + 4 * 0.35 + 0.3);
    final bh = ux * (rows / TileView.aspect + 4 * 0.35 + 0.3);
    return _Metrics(ux, (w - bw) / 2, (h - bh) / 2);
  }

  final double ux;
  final double ox;
  final double oy;

  double get uy => ux / TileView.aspect;
  double get dz => ux * 0.35;
  double get depth => ux * 0.3;

  Rect face(Slot s) => Rect.fromLTWH(
        ox + 4 * dz + s.x * ux - s.z * dz,
        oy + 4 * dz + s.y * uy - s.z * dz,
        2 * ux,
        2 * uy,
      );

  int? hit(MahjongSolitaire e, Offset p) {
    final order = drawOrder(e).reversed.toList();
    for (final i in order) {
      if (face(e.slots[i]).contains(p)) return i;
    }
    // Daneben getippt, etwa auf die Kante: der nächste Stein, wenn er nah genug ist
    int? best;
    var bestD = double.infinity;
    for (final i in order) {
      final r = face(e.slots[i]).inflate(depth);
      if (!r.contains(p)) continue;
      final d = (r.center - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  List<int> drawOrder(MahjongSolitaire e) {
    final idx = [for (var i = 0; i < e.slots.length; i++) if (e.present[i]) i];
    idx.sort((a, b) {
      final sa = e.slots[a];
      final sb = e.slots[b];
      if (sa.z != sb.z) return sa.z - sb.z;
      if (sa.y != sb.y) return sa.y - sb.y;
      return sa.x - sb.x;
    });
    return idx;
  }
}

class _SolitairePainter extends CustomPainter {
  _SolitairePainter(this.e, this.m, this.selected, this.hint);
  final MahjongSolitaire e;
  final _Metrics m;
  final int? selected;
  final (int, int)? hint;

  @override
  void paint(Canvas canvas, Size size) {
    for (final i in m.drawOrder(e)) {
      final free = e.isFree(i);
      paintTile(
        canvas,
        m.face(e.slots[i]),
        e.tiles[i],
        depth: m.depth,
        selected: i == selected,
        hint: hint != null && (hint!.$1 == i || hint!.$2 == i),
        dim: !free,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SolitairePainter old) => true;
}
