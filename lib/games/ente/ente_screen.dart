import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../lose/lose_engine.dart';

/// Entchen angeln vom Jahrmarkt. Der Gewinn wird beim Angeln ausgewürfelt, egal welches Entchen.
/// Gewinne als Vielfaches des Preises.
const entenGewinne = [
  LosPrize(1, 4),
  LosPrize(2, 10),
  LosPrize(5, 40),
  LosPrize(20, 250),
  LosPrize(100, 2500),
];

const entenPreise = [20, 50, 100];

const entenGuide = GameGuide('Entchen angeln', [
  GuideSection(
    'So geht es',
    'Wähle den Preis pro Versuch und tippe ein Entchen an. Es wird aus dem Becken geangelt; unten am Entchen steht, was du '
        'gewinnst: Niete oder das 1-, 2-, 5-, 20- oder 100-Fache des Preises.',
  ),
  GuideSection(
    'Zufall',
    'Der Gewinn wird erst beim Angeln ausgewürfelt. Welches Entchen du nimmst, spielt keine Rolle. Gewinnchance 1 zu 2,6, '
        'Chancen: 1-fach 1 zu 4, 2-fach 1 zu 10, 5-fach 1 zu 40, 20-fach 1 zu 250, 100-fach 1 zu 2.500.',
  ),
]);

class EntenScreen extends StatefulWidget {
  const EntenScreen({super.key, this.seed});
  final int? seed;

  @override
  State<EntenScreen> createState() => _EntenScreenState();
}

class _EntenScreenState extends State<EntenScreen> with TickerProviderStateMixin {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final AnimationController _swim = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  late final AnimationController _lift = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _price = entenPreise.first;
  int _caught = -1;
  int _multiple = 0;
  String _message = 'Tippe ein Entchen an';
  bool _big = false;

  static const _ducks = 8;

  @override
  void dispose() {
    _swim.dispose();
    _lift.dispose();
    super.dispose();
  }

  /// Position eines Entchens im Becken (0..1), sie schwimmen im Kreis.
  Offset _pos(int i, double t) {
    final a = 2 * math.pi * (t + i / _ducks);
    return Offset(0.5 + 0.36 * math.cos(a), 0.5 + 0.3 * math.sin(a));
  }

  Future<void> _angle(int i) async {
    if (_lift.isAnimating) return;
    final app = AppScope.of(context);
    if (!app.wallet.spend(_price)) {
      setState(() => _message = 'Nicht genug Münzen');
      return;
    }
    final m = drawPrize(entenGewinne, _rng);
    setState(() {
      _caught = i;
      _multiple = m;
      _message = 'Angeln …';
      _big = false;
    });
    app.sfx.play(Sound.tick);
    await _lift.forward(from: 0);
    if (!mounted) return;
    final win = m * _price;
    app.wallet.credit(win);
    debugLog.info('enten', 'Preis $_price: ${m == 0 ? 'Niete' : '$m-fach = $win'} · Stand ${app.wallet.balance}');
    app.sfx.play(m >= 20 ? Sound.bigWin : (m > 0 ? Sound.win : Sound.lose));
    setState(() {
      _message = m == 0 ? 'Leider eine Niete' : '$m-fach: +${formatCoins(win)}';
      _big = m > 0;
    });
    app.wallet.refillIfBroke(min: entenPreise.first);
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      minStake: entenPreise.first,
      title: 'Entchen angeln',
      guide: entenGuide,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final p in entenPreise)
                ChoiceChip(label: Text('Versuch ${formatCoins(p)}'), selected: _price == p, onSelected: _lift.isAnimating ? null : (_) => setState(() => _price = p)),
            ]),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = Size(box.maxWidth, box.maxHeight);
                  return GestureDetector(
                    onTapDown: (d) {
                      // Das nächste Entchen zum Finger angeln
                      final t = _swim.value;
                      var best = -1;
                      var dist = double.infinity;
                      for (var i = 0; i < _ducks; i++) {
                        final p = _pos(i, t);
                        final dd = (Offset(p.dx * size.width, p.dy * size.height) - d.localPosition).distance;
                        if (dd < dist) {
                          dist = dd;
                          best = i;
                        }
                      }
                      if (dist < size.shortestSide * 0.15) _angle(best);
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_swim, _lift]),
                      builder: (context, _) => CustomPaint(
                        size: size,
                        painter: _PondPainter(this, _swim.value, _lift.value),
                      ),
                    ),
                  );
                },
              ),
            ),
            ResultBanner(text: _message, highlight: _big),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PondPainter extends CustomPainter {
  _PondPainter(this.s, this.t, this.lift);
  final _EntenScreenState s;
  final double t;
  final double lift;

  @override
  void paint(Canvas canvas, Size size) {
    final pond = Rect.fromCenter(center: size.center(Offset.zero), width: size.width * 0.96, height: size.height * 0.86);
    canvas.drawOval(pond.inflate(10), Paint()..color = const Color(0xFFE53935));
    canvas.drawOval(pond.inflate(4), Paint()..color = Colors.white);
    canvas.drawOval(pond, Paint()..shader = const RadialGradient(colors: [Color(0xFF4FC3F7), Color(0xFF0277BD)]).createShader(pond));
    // Wellen, nahtlos im Takt der Schwimmrunde
    for (var i = 0; i < 6; i++) {
      final a = 2 * math.pi * (t * 3 + i / 6);
      final o = Offset(pond.center.dx + pond.width * 0.2 * math.cos(i * 1.3), pond.center.dy + pond.height * 0.2 * math.sin(i * 2.1));
      canvas.drawArc(Rect.fromCenter(center: o, width: 30 + 6 * math.sin(a), height: 10), math.pi, math.pi, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x66FFFFFF));
    }
    final dw = size.shortestSide * 0.16;
    for (var i = 0; i < _EntenScreenState._ducks; i++) {
      final p = s._pos(i, t);
      var c = Offset(p.dx * size.width, p.dy * size.height);
      final bob = math.sin(2 * math.pi * (t * 12 + i * 0.37)) * 2;
      final caught = i == s._caught;
      if (caught) c = Offset(c.dx, c.dy - lift * size.height * 0.25);
      _duck(canvas, c.translate(0, bob), dw);
      if (caught && lift > 0.6) {
        // Unterseite mit Gewinn
        final m = s._multiple;
        final tp = TextPainter(
          text: TextSpan(
            text: m == 0 ? 'Niete' : '$m×',
            style: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w900, fontSize: dw * 0.32, color: m == 0 ? const Color(0xFF616161) : const Color(0xFFC62828)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final label = Rect.fromCenter(center: c.translate(0, dw * 0.55), width: tp.width + 14, height: tp.height + 6);
        canvas.drawRRect(RRect.fromRectAndRadius(label, const Radius.circular(6)), Paint()..color = Colors.white);
        tp.paint(canvas, label.center - Offset(tp.width / 2, tp.height / 2));
      }
      if (caught && lift > 0) {
        // Angelschnur
        canvas.drawLine(Offset(c.dx, 0), c.translate(0, -dw * 0.4), Paint()
          ..strokeWidth = 1.5
          ..color = const Color(0xFF3E2723));
      }
    }
  }

  void _duck(Canvas canvas, Offset c, double w) {
    final body = Rect.fromCenter(center: c.translate(0, w * 0.1), width: w, height: w * 0.62);
    canvas.drawOval(body, Paint()..shader = const RadialGradient(center: Alignment(-0.3, -0.5), colors: [Color(0xFFFFF59D), Color(0xFFFBC02D)]).createShader(body));
    final head = c.translate(w * 0.28, -w * 0.22);
    canvas.drawCircle(head, w * 0.24, Paint()..color = const Color(0xFFFFEE58));
    canvas.drawCircle(head.translate(w * 0.06, -w * 0.04), w * 0.04, Paint()..color = const Color(0xFF241410));
    final beak = Path()
      ..moveTo(head.dx + w * 0.18, head.dy)
      ..lineTo(head.dx + w * 0.38, head.dy + w * 0.05)
      ..lineTo(head.dx + w * 0.18, head.dy + w * 0.1)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF7043));
    // Öse für den Haken
    canvas.drawCircle(c.translate(0, -w * 0.24), w * 0.06, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF8D6E63));
  }

  @override
  bool shouldRepaint(_PondPainter old) => true;
}
