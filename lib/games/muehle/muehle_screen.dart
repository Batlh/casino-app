import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/tap_catcher.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import 'muehle_engine.dart';

const muehleLevels = ['Leicht', 'Mittel', 'Schwer'];
const muehleRewards = [50, 100, 200];

final muehleGuide = GameGuide('Mühle', const [
  GuideSection(
    'Ziel',
    'Drei eigene Steine in einer Linie sind eine Mühle. Wer eine Mühle schließt, nimmt dem Gegner einen Stein weg. '
        'Verloren hat, wer nur noch zwei Steine hat oder nicht mehr ziehen kann.',
  ),
  GuideSection(
    'Setzen',
    'Jeder hat neun Steine. Erst setzt ihr abwechselnd je einen Stein auf einen freien Punkt. Weiß beginnt.',
  ),
  GuideSection(
    'Ziehen und Springen',
    'Sind alle gesetzt, zieht ihr abwechselnd einen Stein entlang einer Linie auf einen freien Nachbarpunkt. '
        'Wer nur noch drei Steine hat, darf springen: auf jeden freien Punkt.',
  ),
  GuideSection(
    'Schlagen',
    'Nach einer Mühle tippst du einen gegnerischen Stein an. Steine in einer Mühle sind geschützt, außer der Gegner '
        'hat nur noch Mühlen. Nach 60 Zügen ohne Schlagen endet das Spiel unentschieden.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Gegen den Computer in drei Stufen (Sieg: 50, 100 oder 200 Münzen) oder zu zweit an einem Gerät.',
  ),
]);

class MuehleScreen extends StatefulWidget {
  const MuehleScreen({super.key});

  @override
  State<MuehleScreen> createState() => _MuehleScreenState();
}

class _MuehleScreenState extends State<MuehleScreen> {
  static const _saveId = 'muehle';
  late final Settings _store;
  MuehleGame? _g;
  List<Seat> _seats = const [];
  int _level = 1;
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;
  int? _sel;

  /// Schritt, nach dem noch ein Stein geschlagen werden muss.
  (int?, int)? _pending;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = MuehleGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _level = d['level'] as int;
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('muehle.spielstand', e, st);
        _g = null;
        _store.clearGame(_saveId);
      }
    }
    if (_g == null) WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
  }

  @override
  void dispose() {
    _token++;
    _persist();
    super.dispose();
  }

  void _persist() {
    final g = _g;
    if (g == null || g.over) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {
      'game': g.toJson(),
      'seats': [for (final s in _seats) s.toJson()],
      'level': _level,
      'paid': _paid,
    });
  }

  int _seatOf(int color) => color - 1;
  String _name(int color) => _seats[_seatOf(color)].name;

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(
      context,
      gameId: _saveId,
      title: 'Mühle',
      minSeats: 2,
      maxSeats: 2,
      colorNames: const ['Weiß', 'Schwarz'],
      colors: const [Color(0xFFF2F2F2), Color(0xFF1A1A1A)],
    );
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    var level = _level;
    if (vsComputer(seats)) {
      final l = await showChoiceSheet(
        context,
        title: 'Wie stark ist der Computer?',
        options: [for (var i = 0; i < 3; i++) '${muehleLevels[i]}: Sieg bringt ${muehleRewards[i]} Münzen'],
      );
      if (l == null || !mounted) {
        if (_g == null && mounted) Navigator.of(context).pop();
        return;
      }
      level = l;
    }
    setState(() {
      _seats = seats;
      _level = level;
      _g = MuehleGame();
      _paid = false;
      _busy = false;
      _sel = null;
      _pending = null;
      _msg = '${seats[0].name} (Weiß) setzt den ersten Stein';
    });
    _bot();
  }

  bool get _humanTurn {
    final g = _g;
    return g != null && !g.over && _seats[_seatOf(g.current)].human && !_busy;
  }

  void _tap(Offset pos, double u) {
    final g = _g;
    if (g == null || !_humanTurn) return;
    // Nächsten Punkt suchen
    int? hit;
    var best = double.infinity;
    for (var i = 0; i < 24; i++) {
      final c = Offset((muehlePoints[i].$1 + 0.5) * u, (muehlePoints[i].$2 + 0.5) * u);
      final d = (c - pos).distance;
      if (d < best) {
        best = d;
        hit = i;
      }
    }
    if (hit == null || best > u * 0.6) return;
    final who = g.current;
    final pending = _pending;
    if (pending != null) {
      if (!g.removable(3 - who, _after(g, pending)).contains(hit)) {
        setState(() => _msg = 'Diesen Stein darfst du nicht schlagen');
        return;
      }
      _play(MuehleMove(pending.$1, pending.$2, hit));
      return;
    }
    if (g.placing(who)) {
      if (g.board[hit] != 0) return;
      _step(null, hit);
      return;
    }
    if (g.board[hit] == who) {
      setState(() => _sel = hit);
      return;
    }
    final sel = _sel;
    if (sel == null || g.board[hit] != 0) return;
    if (!g.flying(who) && !muehleNeighbors[sel].contains(hit)) {
      setState(() => _msg = 'Nur auf einen freien Nachbarpunkt');
      return;
    }
    _step(sel, hit);
  }

  List<int> _after(MuehleGame g, (int?, int) s) {
    final b = List.of(g.board);
    if (s.$1 != null) b[s.$1!] = 0;
    b[s.$2] = g.current;
    return b;
  }

  void _step(int? from, int to) {
    final g = _g!;
    if (g.closesMill(from, to, g.current)) {
      AppScope.of(context).sfx.play(Sound.coin);
      setState(() {
        _pending = (from, to);
        _sel = null;
        _msg = 'Mühle! Tippe einen Stein von ${_name(3 - g.current)} an';
      });
      return;
    }
    _play(MuehleMove(from, to));
  }

  void _play(MuehleMove m) {
    final g = _g!;
    final who = g.current;
    if (!g.play(m)) {
      debugLog.warn('muehle', 'Ungültiger Zug $m');
      setState(() {
        _pending = null;
        _sel = null;
      });
      return;
    }
    final sfx = AppScope.of(context).sfx;
    sfx.play(m.remove != null ? Sound.lose : Sound.chip);
    var text = m.remove != null ? '${_name(who)} schließt eine Mühle und schlägt einen Stein' : '${_name(g.current)} ist dran';
    if (g.over) {
      final w = g.winner!;
      if (w == 0) {
        text = 'Unentschieden: 60 Züge ohne Schlagen';
      } else {
        final reward = seatReward(_seats, _seatOf(w), muehleRewards[_level]);
        if (reward > 0 && !_paid) {
          _paid = true;
          AppScope.of(context).wallet.credit(reward);
        }
        sfx.play(_seats[_seatOf(w)].human ? Sound.win : Sound.lose);
        text = '${_name(w)} gewinnt!${reward > 0 ? ' +$reward Münzen' : ''}';
      }
    } else if (g.flying(g.current)) {
      text += '. ${_name(g.current)} hat nur noch drei Steine und darf springen';
    }
    setState(() {
      _msg = text;
      _pending = null;
      _sel = null;
    });
    _bot();
  }

  Future<void> _bot() async {
    final g = _g;
    if (g == null || g.over || _seats[_seatOf(g.current)].human) return;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(600));
    if (!mounted || token != _token) return;
    final m = muehleBotMove(g.copy(), _level, _rng);
    _busy = false;
    _play(m);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Mühle',
      guide: muehleGuide,
      child: g == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final color in [1, 2])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: g.current == color && !g.over ? p.accent : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: g.current == color && !g.over ? p.accent : p.panelEdge),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 8, backgroundColor: color == 1 ? Colors.white : Colors.black),
                            const SizedBox(width: 6),
                            Text(
                              '${_name(color)} · ${g.count(color)} auf dem Brett'
                              '${g.toPlace[color - 1] > 0 ? ', ${g.toPlace[color - 1]} zu setzen' : ''}',
                              style: TextStyle(color: g.current == color && !g.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final size = math.min(box.maxWidth, box.maxHeight) - 16;
                    final targets = <int>[];
                    final removable = <int>[];
                    if (_humanTurn) {
                      final pending = _pending;
                      if (pending != null) {
                        removable.addAll(g.removable(3 - g.current, _after(g, pending)));
                      } else if (g.placing(g.current)) {
                        // Beim Setzen keine Markierung, jeder freie Punkt geht
                      } else if (_sel != null) {
                        for (final (f, t) in g.steps()) {
                          if (f == _sel) targets.add(t);
                        }
                      }
                    }
                    return Center(
                      child: TapCatcher(
                        area: 'muehle',
                        onTap: (pos) => _tap(pos, size / 7),
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _MuehlePainter(g, _sel, _pending, targets, removable),
                        ),
                      ),
                    );
                  }),
                ),
                ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: ActionButton(primary: g.over, label: 'Neues Spiel', onPressed: _newGame),
                ),
              ],
            ),
    );
  }
}

class _MuehlePainter extends CustomPainter {
  _MuehlePainter(this.g, this.sel, this.pending, this.targets, this.removable);
  final MuehleGame g;
  final int? sel;
  final (int?, int)? pending;
  final List<int> targets;
  final List<int> removable;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 7;
    Offset at(int i) => Offset((muehlePoints[i].$1 + 0.5) * u, (muehlePoints[i].$2 + 0.5) * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 0.3)),
      Paint()..color = const Color(0xFFD9B67A),
    );
    final line = Paint()
      ..color = const Color(0xFF4A2E18)
      ..strokeWidth = u * 0.07
      ..style = PaintingStyle.stroke;
    for (var r = 0; r < 3; r++) {
      canvas.drawRect(Rect.fromPoints(at(r * 8), at(r * 8 + 4)), line);
    }
    for (final k in [1, 3, 5, 7]) {
      canvas.drawLine(at(k), at(16 + k), line);
    }
    // Board nach dem anstehenden Schritt zeigen
    final b = List.of(g.board);
    final pend = pending;
    if (pend != null) {
      if (pend.$1 != null) b[pend.$1!] = 0;
      b[pend.$2] = g.current;
    }
    for (var i = 0; i < 24; i++) {
      final c = at(i);
      canvas.drawCircle(c, u * 0.12, Paint()..color = const Color(0xFF4A2E18));
      if (targets.contains(i)) {
        canvas.drawCircle(c, u * 0.2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06
          ..color = const Color(0xFFE8B923));
      }
      final v = b[i];
      if (v == 0) continue;
      canvas.drawCircle(c + Offset(u * 0.04, u * 0.06), u * 0.34, Paint()..color = Colors.black38);
      canvas.drawCircle(c, u * 0.34, Paint()..color = v == 1 ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22));
      canvas.drawCircle(c, u * 0.22, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.03
        ..color = v == 1 ? const Color(0x33000000) : const Color(0x33FFFFFF));
      if (i == sel) {
        canvas.drawCircle(c, u * 0.4, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.07
          ..color = const Color(0xFFE8B923));
      }
      if (removable.contains(i)) {
        canvas.drawCircle(c, u * 0.4, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.07
          ..color = const Color(0xFFD8402B));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
