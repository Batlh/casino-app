import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import '../sicbo/sicbo_screen.dart' show DieFace;
import 'ladder_engine.dart';

const ladderWinReward = 100;

final ladderGuide = GameGuide('Leiterspiel', const [
  GuideSection(
    'Ziel',
    'Wer zuerst genau auf Feld 100 kommt, gewinnt. Alle starten vor Feld 1 und würfeln reihum.',
  ),
  GuideSection(
    'Leitern und Schlangen',
    'Landet deine Figur am Fuß einer Leiter, klettert sie sofort hinauf. Landet sie auf dem Kopf einer Schlange, '
        'rutscht sie bis zum Schwanz hinunter.',
  ),
  GuideSection(
    'Genau ins Ziel',
    'Wer über Feld 100 hinaus würfelt, läuft die übrigen Augen wieder zurück. Mit 97 und einer 5 landest du also auf 98.',
  ),
  GuideSection(
    'Brett und Mitspieler',
    'Vor dem Spiel wählst du das klassische Brett oder ein Brett mit zufällig verteilten Leitern und Schlangen. '
        'Bis zu vier spielen mit, an einem Gerät oder gegen den Computer. Gewinnst du gegen den Computer, '
        'gibt es $ladderWinReward Münzen.',
  ),
]);

class LadderScreen extends StatefulWidget {
  const LadderScreen({super.key});

  @override
  State<LadderScreen> createState() => _LadderScreenState();
}

class _LadderScreenState extends State<LadderScreen> {
  static const _saveId = 'ladder';
  late final Settings _store;
  LadderGame? _g;
  List<Seat> _seats = const [];
  String _msg = '';
  bool _busy = false;
  bool _paid = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = LadderGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _next());
      } catch (e, st) {
        debugLog.error('leiterspiel.spielstand', e, st);
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
      'paid': _paid,
    });
  }

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(context, gameId: _saveId, title: 'Leiterspiel', minSeats: 2, maxSeats: 4);
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    final board = await showChoiceSheet(
      context,
      title: 'Welches Brett?',
      options: const ['Klassisch: feste Leitern und Schlangen', 'Zufällig: jedes Mal neu verteilt'],
    );
    if (board == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _seats = seats;
      _g = LadderGame(seats.length, randomBoard: board == 1);
      _paid = false;
      _busy = false;
      _msg = '${seats[0].name} beginnt';
    });
    _next();
  }

  bool get _humanTurn {
    final g = _g;
    return g != null && !g.over && _seats[g.current].human;
  }

  /// Computer würfeln von selbst.
  Future<void> _next() async {
    final g = _g;
    if (g == null || g.over || _seats[g.current].human) return;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(700));
    if (!mounted || token != _token) return;
    _roll();
  }

  void _roll() {
    final g = _g;
    if (g == null || g.over) return;
    final m = g.roll();
    final name = _seats[m.player].name;
    final sfx = AppScope.of(context).sfx;
    var text = '$name würfelt ${m.roll}';
    if (m.bounced) text += ', prallt zurück';
    if (m.ladder) {
      text += ': Leiter von ${m.landed} auf ${m.to}!';
      sfx.play(Sound.coin);
    } else if (m.snake) {
      text += ': Schlange von ${m.landed} auf ${m.to}';
      sfx.play(Sound.lose);
    } else {
      text += ': Feld ${m.to}';
      sfx.play(Sound.tick);
    }
    if (g.over) {
      final reward = seatReward(_seats, m.player, ladderWinReward);
      text = '$name gewinnt!';
      if (reward > 0 && !_paid) {
        _paid = true;
        AppScope.of(context).wallet.credit(reward);
        text += ' +$reward Münzen';
      }
      sfx.play(Sound.win);
    }
    setState(() {
      _msg = text;
      _busy = false;
    });
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return GameFrame(
      title: 'Leiterspiel',
      guide: ladderGuide,
      child: g == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, box) {
                final landscape = box.maxWidth > box.maxHeight * 1.1;
                final board = Padding(
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(painter: _LadderPainter(g, Palette.of(context))),
                  ),
                );
                final side = _side(g);
                return landscape
                    ? Row(children: [Expanded(child: Center(child: board)), SizedBox(width: 280, child: side)])
                    : Column(children: [Expanded(child: Center(child: board)), side]);
              },
            ),
    );
  }

  Widget _side(LadderGame g) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _seats.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: i == g.current && !g.over ? p.panel : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: i == g.current && !g.over ? p.accent : p.panelEdge),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(radius: 8, backgroundColor: seatColors[i]),
                    const SizedBox(width: 6),
                    Text('${_seats[i].name} · ${g.positions[i]}', style: TextStyle(color: p.onFelt, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (g.lastRoll != null) DieFace(value: g.lastRoll!, size: 48),
          ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionButton(
                primary: true,
                label: g.over ? 'Fertig' : (_humanTurn ? '${_seats[g.current].name}: Würfeln' : 'Computer ist dran'),
                onPressed: _humanTurn && !_busy ? _roll : null,
              ),
              ActionButton(label: 'Neues Spiel', onPressed: _newGame),
            ],
          ),
        ],
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter(this.g, this.p);
  final LadderGame g;
  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 10;
    Offset at(int n) {
      final c = ladderCell(n);
      return Offset(c.x * u, c.y * u);
    }

    // Felder
    for (var n = 1; n <= 100; n++) {
      final c = ladderCell(n);
      final r = Rect.fromLTWH((c.x - 0.5) * u, (c.y - 0.5) * u, u, u);
      final light = ((c.x - 0.5).round() + (c.y - 0.5).round()).isEven;
      canvas.drawRect(r, Paint()..color = light ? const Color(0xFFF3E3B8) : const Color(0xFFE2C98E));
      final tp = TextPainter(
        text: TextSpan(text: '$n', style: TextStyle(color: const Color(0xFF6B4A2A), fontSize: u * 0.24, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, r.topLeft + Offset(u * 0.06, u * 0.04));
    }
    canvas.drawRect(Offset.zero & size, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.06
      ..color = const Color(0xFF6B4A2A));

    // Leitern und Schlangen
    for (final e in g.jumps.entries) {
      final a = at(e.key);
      final b = at(e.value);
      if (e.value > e.key) {
        _ladder(canvas, a, b, u);
      } else {
        _snake(canvas, a, b, u);
      }
    }

    // Figuren
    for (var i = 0; i < g.players; i++) {
      final pos = g.positions[i];
      // Vor dem Start stehen die Figuren klein auf Feld 1
      final base = at(pos == 0 ? 1 : pos);
      final shift = Offset((i % 2 - 0.5) * u * 0.36, (i ~/ 2 - 0.5) * u * 0.36);
      final c = base + shift;
      canvas.drawCircle(c + Offset(u * 0.03, u * 0.05), u * 0.2, Paint()..color = Colors.black38);
      canvas.drawCircle(c, u * 0.2, Paint()..color = seatColors[i]);
      canvas.drawCircle(c, u * 0.2, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.04
        ..color = i == g.current && !g.over ? Colors.white : Colors.black54);
    }
  }

  void _ladder(Canvas canvas, Offset a, Offset b, double u) {
    final d = b - a;
    final len = d.distance;
    final n = Offset(-d.dy / len, d.dx / len) * (u * 0.16);
    final rail = Paint()
      ..strokeWidth = u * 0.07
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8A5A2B);
    canvas.drawLine(a + n, b + n, rail);
    canvas.drawLine(a - n, b - n, rail);
    final steps = math.max(2, (len / (u * 0.35)).floor());
    final rung = Paint()
      ..strokeWidth = u * 0.05
      ..color = const Color(0xFFB07A3F);
    for (var i = 1; i < steps; i++) {
      final m = Offset.lerp(a, b, i / steps)!;
      canvas.drawLine(m + n, m - n, rung);
    }
  }

  void _snake(Canvas canvas, Offset head, Offset tail, double u) {
    final d = tail - head;
    final len = d.distance;
    final n = Offset(-d.dy / len, d.dx / len);
    final path = Path()..moveTo(head.dx, head.dy);
    const waves = 3;
    for (var i = 1; i <= waves * 2; i++) {
      final t0 = (i - 0.5) / (waves * 2);
      final t1 = i / (waves * 2);
      final ctrl = Offset.lerp(head, tail, t0)! + n * (u * 0.45 * (i.isOdd ? 1 : -1));
      final end = Offset.lerp(head, tail, t1)!;
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    }
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E7D3A));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.07
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8BD17C));
    canvas.drawCircle(head, u * 0.17, Paint()..color = const Color(0xFF2E7D3A));
    canvas.drawCircle(head + n * (u * 0.07), u * 0.04, Paint()..color = Colors.white);
    canvas.drawCircle(head - n * (u * 0.07), u * 0.04, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
