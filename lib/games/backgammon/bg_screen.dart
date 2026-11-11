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
import '../sicbo/sicbo_screen.dart' show DieFace;
import 'bg_engine.dart';

const bgLevels = ['Leicht', 'Normal'];
const bgRewards = [60, 120];

final bgGuide = GameGuide('Backgammon', const [
  GuideSection(
    'Ziel',
    'Jeder hat 15 Steine. Bringe alle in dein Heimfeld (bei Weiß unten rechts) und trage sie dann vom Brett. '
        'Wer zuerst alle abgetragen hat, gewinnt. Weiß läuft gegen den Uhrzeigersinn, Schwarz andersherum.',
  ),
  GuideSection(
    'Ziehen',
    'Du würfelst mit zwei Würfeln und ziehst einen Stein um die eine Zahl und einen (auch denselben) um die andere. '
        'Bei einem Pasch ziehst du viermal. Du darfst nicht auf einen Punkt mit zwei oder mehr gegnerischen Steinen. '
        'Wenn möglich, musst du beide Würfel nutzen; geht nur einer, dann der höhere.',
  ),
  GuideSection(
    'Schlagen',
    'Ein einzelner Stein ist ungeschützt. Landest du auf ihm, kommt er auf die Bar in der Mitte. Wer Steine auf der Bar '
        'hat, muss sie zuerst wieder ins gegnerische Heimfeld einwürfeln, bevor er etwas anderes zieht.',
  ),
  GuideSection(
    'Abtragen',
    'Sind alle deine Steine im Heimfeld, trägst du sie mit passenden Würfen ab. Mit einer höheren Zahl darfst du '
        'den Stein vom höchsten besetzten Punkt abtragen.',
  ),
  GuideSection(
    'Bedienung und Münzen',
    'Tippe einen Stein (oder die Bar) an, dann das Ziel. Abtragen: auf das Fach rechts tippen. Mit „Rückgängig“ '
        'nimmst du Züge dieser Runde zurück. Gegen den Computer bringt ein Sieg 60 oder 120 Münzen, ein Gammon '
        '(Gegner hat noch nichts abgetragen) das Doppelte, ein Backgammon das Dreifache.',
  ),
]);

class BgScreen extends StatefulWidget {
  const BgScreen({super.key});

  @override
  State<BgScreen> createState() => _BgScreenState();
}

class _BgScreenState extends State<BgScreen> {
  static const _saveId = 'backgammon';
  late final Settings _store;
  BgGame? _g;
  List<Seat> _seats = const [];
  int _level = 1;
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;
  final _rng = math.Random();

  /// Stand zu Beginn des Zugs (für Rückgängig) und die gespielten Schritte.
  BgGame? _turnStart;
  final List<BgStep> _played = [];
  List<List<BgStep>> _seqs = const [];
  int? _sel;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        // Gespeichert wird immer der Stand zu Beginn eines Zugs
        _g = BgGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _level = d['level'] as int;
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _beginTurn());
      } catch (e, st) {
        debugLog.error('backgammon.spielstand', e, st);
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
    final g = _turnStart ?? _g;
    if (g == null || (_g?.over ?? true)) {
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

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(
      context,
      gameId: _saveId,
      title: 'Backgammon',
      minSeats: 2,
      maxSeats: 2,
      colorNames: const ['Weiß', 'Schwarz'],
      colors: const [Color(0xFFF2EEE6), Color(0xFF2A2A30)],
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
        options: [for (var i = 0; i < 2; i++) '${bgLevels[i]}: Sieg bringt ${bgRewards[i]} Münzen'],
      );
      if (l == null || !mounted) {
        if (_g == null && mounted) Navigator.of(context).pop();
        return;
      }
      level = l;
    }
    final g = BgGame()..start();
    setState(() {
      _seats = seats;
      _level = level;
      _g = g;
      _paid = false;
      _busy = false;
      _msg = '${seats[g.current].name} hat beim Auswürfeln gewonnen und beginnt mit ${g.dice[0]} und ${g.dice[1]}';
    });
    _beginTurn();
  }

  /// Beginn eines Zugs: Stand merken, Folgen berechnen, Computer ziehen lassen.
  void _beginTurn() {
    final g = _g;
    if (g == null || g.over) return;
    _turnStart = g.copy();
    _played.clear();
    _sel = null;
    _seqs = g.rolled ? g.sequences() : const [];
    setState(() {});
    if (!_seats[g.current].human) {
      _botTurn();
    } else if (g.rolled && _seqs.isEmpty) {
      _noMoves();
    }
  }

  void _roll() {
    final g = _g;
    if (g == null || g.rolled || g.over) return;
    g.roll();
    AppScope.of(context).sfx.play(Sound.tick);
    _seqs = g.sequences();
    setState(() => _msg = '${_seats[g.current].name} würfelt ${g.dice[0]} und ${g.dice[1]}');
    if (_seqs.isEmpty) _noMoves();
  }

  Future<void> _noMoves() async {
    final g = _g!;
    final token = ++_token;
    setState(() {
      _busy = true;
      _msg = '${_seats[g.current].name} würfelt ${g.dice[0]} und ${g.dice[1]} und kann nicht ziehen';
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted || token != _token) return;
    _busy = false;
    _endTurn();
  }

  void _endTurn() {
    final g = _g!;
    if (g.over) {
      _finish(g);
      return;
    }
    g.endTurn();
    _turnStart = null;
    _msg = '${_seats[g.current].name} ist dran';
    _beginTurn();
    if (_seats[g.current].human && !g.rolled) {
      setState(() => _msg = '${_seats[g.current].name}: Würfeln');
    }
  }

  void _finish(BgGame g) {
    final w = g.winner!;
    final kind = ['', '', ' mit Gammon', ' mit Backgammon'][g.winKind];
    final reward = seatReward(_seats, w, bgRewards[_level] * g.winKind);
    if (reward > 0 && !_paid) {
      _paid = true;
      AppScope.of(context).wallet.credit(reward);
    }
    AppScope.of(context).sfx.play(_seats[w].human ? Sound.win : Sound.lose);
    setState(() {
      _turnStart = null;
      _msg = '${_seats[w].name} gewinnt$kind!${reward > 0 ? ' +$reward Münzen' : ''}';
    });
  }

  /// Folgen, die mit den bisher gespielten Schritten beginnen.
  List<List<BgStep>> get _open {
    return [
      for (final s in _seqs)
        if (s.length > _played.length && _prefix(s)) s,
    ];
  }

  bool _prefix(List<BgStep> s) {
    for (var i = 0; i < _played.length; i++) {
      if (!s[i].same(_played[i])) return false;
    }
    return true;
  }

  bool get _turnComplete => _played.isNotEmpty && _open.isEmpty;

  List<BgStep> get _nextSteps {
    final seen = <String>{};
    return [
      for (final s in _open)
        if (seen.add('${s[_played.length].from}/${s[_played.length].to}/${s[_played.length].die}')) s[_played.length],
    ];
  }

  void _step(BgStep s) {
    final g = _g!;
    g.apply(s);
    _played.add(s);
    AppScope.of(context).sfx.play(s.hit ? Sound.lose : Sound.chip);
    _sel = null;
    if (g.over) {
      _finish(g);
      return;
    }
    setState(() => _msg = _turnComplete ? 'Zug fertig: bestätigen oder zurücknehmen' : '${_seats[g.current].name} zieht weiter');
  }

  void _undo() {
    final start = _turnStart;
    if (start == null || _played.isEmpty) return;
    setState(() {
      _g = start.copy();
      _played.clear();
      _sel = null;
      _msg = 'Zurückgenommen';
    });
  }

  Future<void> _botTurn() async {
    final g = _g!;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(600));
    if (!mounted || token != _token) return;
    if (!g.rolled) {
      g.roll();
      AppScope.of(context).sfx.play(Sound.tick);
      setState(() => _msg = '${_seats[g.current].name} würfelt ${g.dice[0]} und ${g.dice[1]}');
      await Future<void>.delayed(_store.botDelay(600));
      if (!mounted || token != _token) return;
    }
    final seq = bgBotSequence(g, _level, _rng);
    if (seq.isEmpty) {
      setState(() => _msg = '${_seats[g.current].name} kann nicht ziehen');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }
    for (final s in seq) {
      if (!mounted || token != _token) return;
      g.apply(s);
      AppScope.of(context).sfx.play(s.hit ? Sound.lose : Sound.chip);
      setState(() {});
      await Future<void>.delayed(_store.botDelay(450));
    }
    if (!mounted || token != _token) return;
    _busy = false;
    _endTurn();
  }

  // Brett: 14 Spalten (6 Punkte, Bar, 6 Punkte, Ablage), zwei Reihen. Absolut aus Sicht von Weiß.
  int _rel(int abs) => _g!.current == 0 ? abs : 23 - abs;

  void _tap(Offset pos, Size size) {
    final g = _g;
    if (g == null || g.over || _busy || !_seats[g.current].human || !g.rolled) return;
    final cw = size.width / 14;
    final col = (pos.dx / cw).floor();
    final top = pos.dy < size.height / 2;
    final steps = _nextSteps;
    if (col == 13) {
      // Ablage
      final off = steps.where((s) => s.to == bgOff && (_sel == null || s.from == _sel)).toList();
      if (off.isNotEmpty) _step(off.first);
      return;
    }
    if (col == 6) {
      if (steps.any((s) => s.from == bgBar)) setState(() => _sel = bgBar);
      return;
    }
    final abs = _absAt(col, top);
    if (abs == null) return;
    final rel = _rel(abs);
    final sel = _sel;
    if (sel != null) {
      final hit = steps.where((s) => s.from == sel && s.to == rel).toList();
      if (hit.isNotEmpty) {
        _step(hit.first);
        return;
      }
    }
    if (steps.any((s) => s.from == rel)) {
      setState(() => _sel = rel);
    }
  }

  static int? _absAt(int col, bool top) {
    if (top) {
      if (col < 6) return 12 + col;
      if (col > 6 && col < 13) return 18 + (col - 7);
    } else {
      if (col < 6) return 11 - col;
      if (col > 6 && col < 13) return 5 - (col - 7);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Backgammon',
      guide: bgGuide,
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
                      for (final side in [0, 1])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: g.current == side && !g.over ? p.accent : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: g.current == side && !g.over ? p.accent : p.panelEdge),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 8, backgroundColor: side == 0 ? const Color(0xFFF2EEE6) : const Color(0xFF2A2A30)),
                            const SizedBox(width: 6),
                            Text(
                              '${_seats[side].name} · ${g.pips(side)} Augen · ${g.off[side]} ab',
                              style: TextStyle(
                                color: g.current == side && !g.over ? p.onAccent : p.onFelt,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final w = math.min(box.maxWidth - 16, (box.maxHeight - 16) * 1.4);
                    final size = Size(w, w / 1.4);
                    final human = !g.over && _seats[g.current].human && !_busy && g.rolled;
                    final steps = human ? _nextSteps : const <BgStep>[];
                    return Center(
                      child: TapCatcher(
                        area: 'backgammon',
                        onTap: (pos) => _tap(pos, size),
                        child: CustomPaint(
                          size: size,
                          painter: _BgPainter(g, sel: _sel, steps: steps),
                        ),
                      ),
                    );
                  }),
                ),
                if (g.rolled)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final d in g.dice)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(
                          opacity: g.remaining.contains(d) ? 1 : 0.35,
                          child: DieFace(value: d, size: 40),
                        ),
                      ),
                  ]),
                ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!g.over && _seats[g.current].human && !g.rolled)
                        ActionButton(primary: true, label: '${_seats[g.current].name}: Würfeln', onPressed: _busy ? null : _roll),
                      if (!g.over && _seats[g.current].human && g.rolled) ...[
                        ActionButton(label: 'Rückgängig', onPressed: _played.isEmpty || _busy ? null : _undo),
                        ActionButton(primary: true, label: 'Zug beenden', onPressed: _turnComplete && !_busy ? _endTurn : null),
                      ],
                      ActionButton(label: 'Neues Spiel', onPressed: _newGame),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter(this.g, {required this.sel, required this.steps});
  final BgGame g;
  final int? sel;
  final List<BgStep> steps;

  static const _white = Color(0xFFF2EEE6);
  static const _black = Color(0xFF2A2A30);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 14;
    final h = size.height;
    final r = math.min(cw * 0.46, h / 22);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), Paint()..color = const Color(0xFF5A3420));
    final felt = Rect.fromLTWH(cw * 0.08, h * 0.03, cw * 12.84, h * 0.94);
    canvas.drawRect(felt, Paint()..color = const Color(0xFF1E6B45));
    // Bar und Ablage
    canvas.drawRect(Rect.fromLTWH(cw * 6, 0, cw, h), Paint()..color = const Color(0xFF4A2A18));
    canvas.drawRect(Rect.fromLTWH(cw * 13.1, h * 0.03, cw * 0.82, h * 0.94), Paint()..color = const Color(0xFF3A2116));

    int colOf(int abs) {
      if (abs >= 12 && abs < 18) return abs - 12;
      if (abs >= 18) return 7 + abs - 18;
      if (abs >= 6) return 11 - abs;
      return 7 + (5 - abs);
    }

    final relSel = sel;
    final cur = g.current;
    final targets = {
      for (final s in steps)
        if (relSel != null && s.from == relSel) s.to,
    };
    final sources = {for (final s in steps) s.from};

    for (var abs = 0; abs < 24; abs++) {
      final col = colOf(abs);
      final top = abs >= 12;
      final x = col * cw;
      final tri = Path();
      if (top) {
        tri
          ..moveTo(x + cw * 0.05, h * 0.03)
          ..lineTo(x + cw * 0.95, h * 0.03)
          ..lineTo(x + cw / 2, h * 0.44);
      } else {
        tri
          ..moveTo(x + cw * 0.05, h * 0.97)
          ..lineTo(x + cw * 0.95, h * 0.97)
          ..lineTo(x + cw / 2, h * 0.56);
      }
      tri.close();
      final rel = cur == 0 ? abs : 23 - abs;
      var color = abs.isEven ? const Color(0xFFC9A57A) : const Color(0xFF9C3B2A);
      if (targets.contains(rel)) color = const Color(0xFFE8B923);
      canvas.drawPath(tri, Paint()..color = color);
      // Steine
      final w = g.counts[0][abs];
      final b = g.counts[1][23 - abs];
      final n = w > 0 ? w : b;
      if (n == 0) continue;
      final fill = w > 0 ? _white : _black;
      final owner = w > 0 ? 0 : 1;
      for (var k = 0; k < math.min(n, 5); k++) {
        final cy = top ? h * 0.03 + r + k * r * 2 : h * 0.97 - r - k * r * 2;
        _checker(canvas, Offset(x + cw / 2, cy), r, fill);
      }
      if (n > 5) {
        final cy = top ? h * 0.03 + r + 4 * r * 2 : h * 0.97 - r - 4 * r * 2;
        _label(canvas, Offset(x + cw / 2, cy), '$n', fill == _white ? Colors.black : Colors.white, r);
      }
      if (owner == cur && sources.contains(rel)) {
        final k = math.min(n, 5) - 1;
        final cy = top ? h * 0.03 + r + k * r * 2 : h * 0.97 - r - k * r * 2;
        canvas.drawCircle(Offset(x + cw / 2, cy), r * 1.08, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (rel == relSel ? 0.3 : 0.15)
          ..color = const Color(0xFFE8B923));
      }
    }
    // Bar: Weiß unten, Schwarz oben
    for (final p in [0, 1]) {
      final n = g.bar[p];
      for (var k = 0; k < math.min(n, 4); k++) {
        final cy = p == 0 ? h * 0.62 + k * r * 2 : h * 0.38 - k * r * 2;
        _checker(canvas, Offset(cw * 6.5, cy), r, p == 0 ? _white : _black);
      }
      if (n > 4) _label(canvas, Offset(cw * 6.5, p == 0 ? h * 0.62 : h * 0.38), '$n', p == 0 ? Colors.black : Colors.white, r);
      if (p == cur && sources.contains(bgBar) && n > 0) {
        canvas.drawCircle(Offset(cw * 6.5, p == 0 ? h * 0.62 : h * 0.38), r * 1.08, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (relSel == bgBar ? 0.3 : 0.15)
          ..color = const Color(0xFFE8B923));
      }
    }
    // Ablage: Weiß unten, Schwarz oben, als Scheiben
    for (final p in [0, 1]) {
      for (var k = 0; k < g.off[p]; k++) {
        final y = p == 0 ? h * 0.96 - k * h * 0.028 : h * 0.04 + k * h * 0.028;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cw * 13.5, y), width: cw * 0.66, height: h * 0.022), const Radius.circular(2)),
          Paint()..color = p == 0 ? _white : _black,
        );
      }
    }
    if (relSel != null && targets.contains(bgOff)) {
      canvas.drawRect(
        Rect.fromLTWH(cw * 13.1, cur == 0 ? h * 0.5 : h * 0.03, cw * 0.82, h * 0.47),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE8B923),
      );
    }
  }

  void _checker(Canvas canvas, Offset c, double r, Color fill) {
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.12), r, Paint()..color = Colors.black38);
    canvas.drawCircle(c, r, Paint()..color = fill);
    canvas.drawCircle(c, r * 0.65, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..color = fill == _white ? const Color(0x22000000) : const Color(0x33FFFFFF));
  }

  void _label(Canvas canvas, Offset c, String t, Color color, double r) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: r * 1.1, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
