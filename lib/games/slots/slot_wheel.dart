import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'slot_engine.dart';
import 'slot_games.dart';

/// Eigener Bildschirm für das Glücksrad. Das Ergebnis steht schon fest (SlotEngine), das Rad dreht nur dorthin.
class BonusWheelScreen extends StatefulWidget {
  const BonusWheelScreen({super.key, required this.game, required this.wheel, required this.spin, required this.stake});

  final SlotGame game;
  final WheelRules wheel;
  final WheelSpin spin;
  final int stake;

  @override
  State<BonusWheelScreen> createState() => _BonusWheelScreenState();
}

class _BonusWheelScreenState extends State<BonusWheelScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  bool _started = false;
  bool _done = false;
  int _lastTick = -1;

  int get _count => widget.wheel.segments.length;

  /// Endwinkel: Segment index unter dem Zeiger oben, plus fünf volle Umdrehungen.
  double get _target {
    final seg = 2 * math.pi / _count;
    return 5 * 2 * math.pi + (2 * math.pi - (widget.spin.index + 0.5) * seg);
  }

  @override
  void initState() {
    super.initState();
    _turn.addListener(() {
      final angle = Curves.easeOutQuart.transform(_turn.value) * _target;
      final tick = (angle / (2 * math.pi / _count)).floor();
      if (tick != _lastTick) {
        _lastTick = tick;
        AppScope.of(context).sfx.play(Sound.tick);
      }
    });
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_started) return;
    setState(() => _started = true);
    await _turn.forward();
    if (!mounted) return;
    AppScope.of(context).sfx.play(Sound.bigWin);
    setState(() => _done = true);
  }

  String _result() {
    final s = widget.spin.segment;
    return switch (s.kind) {
      WheelKind.coins => '+${formatCoins(widget.spin.win)}',
      WheelKind.freeSpins => '${s.amount} Freispiele!',
      WheelKind.holdSpin => 'Hold & Spin mit ${s.amount} Münzen!',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Glücksrad',
      background: widget.game.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final side = math.min(box.maxWidth, MediaQuery.sizeOf(context).height * 0.55);
                  return SizedBox.square(
                    dimension: side,
                    child: AnimatedBuilder(
                      animation: _turn,
                      builder: (context, _) => CustomPaint(
                        painter: _WheelPainter(
                          segments: widget.wheel.segments,
                          stake: widget.stake,
                          angle: Curves.easeOutQuart.transform(_turn.value) * _target,
                          colors: widget.game.frame,
                          highlight: _done ? widget.spin.index : -1,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ResultBanner(text: _done ? _result() : (_started ? '' : 'Tippe auf Drehen'), highlight: _done),
              const SizedBox(height: 12),
              ActionButton(
                primary: true,
                label: _done ? 'Weiter' : 'Drehen',
                onPressed: !_started ? _start : (_done ? () => Navigator.of(context).pop() : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.segments, required this.stake, required this.angle, required this.colors, required this.highlight});

  final List<WheelSegment> segments;
  final int stake;
  final double angle;
  final List<Color> colors;
  final int highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    final n = segments.length;
    final seg = 2 * math.pi / n;
    canvas.drawCircle(c, r + 10, Paint()..color = const Color(0xFF3A2413));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    for (var i = 0; i < n; i++) {
      final s = segments[i];
      final base = switch (s.kind) {
        WheelKind.coins => i.isEven ? const Color(0xFFE8473C) : const Color(0xFFF6B93B),
        WheelKind.freeSpins => const Color(0xFF3C8CE8),
        WheelKind.holdSpin => const Color(0xFF8E44AD),
      };
      final start = -math.pi / 2 + i * seg;
      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), start, seg, false)
        ..close();
      canvas.drawPath(path, Paint()..color = i == highlight ? Color.lerp(base, Colors.white, 0.35)! : base);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFF4C2),
      );
      canvas.save();
      canvas.rotate(start + seg / 2);
      final label = switch (s.kind) {
        WheelKind.coins => formatCoins(s.amount * stake),
        WheelKind.freeSpins => '${s.amount} FREI',
        WheelKind.holdSpin => 'MÜNZEN',
      };
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: bodyFont,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: r * 0.1,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r * 0.6);
      tp.paint(canvas, Offset(r * 0.92 - tp.width, -tp.height / 2));
      canvas.restore();
    }
    canvas.restore();
    // Nabe
    canvas.drawCircle(c, r * 0.16, Paint()..shader = RadialGradient(colors: colors).createShader(Rect.fromCircle(center: c, radius: r * 0.16)));
    canvas.drawCircle(
      c,
      r * 0.16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFF4C2),
    );
    // Zeiger oben
    final pointer = Path()
      ..moveTo(c.dx, c.dy - r + 18)
      ..lineTo(c.dx - 16, c.dy - r - 14)
      ..lineTo(c.dx + 16, c.dy - r - 14)
      ..close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFFFFC95C));
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF3A2413),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.angle != angle || old.highlight != highlight;
}
