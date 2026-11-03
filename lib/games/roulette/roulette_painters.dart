import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'roulette_engine.dart';

const Color rouletteRed = Color(0xFFB92C1B);
const Color rouletteBlack = Color(0xFF211410);
const Color rouletteGreen = Color(0xFF0F7A5C);

Color pocketColor(int n) =>
    n == 0 ? rouletteGreen : (isRed(n) ? rouletteRed : rouletteBlack);

double get pocketAngle => 2 * math.pi / wheelOrder.length;

/// Winkel einer Tasche auf dem Kessel, 0 zeigt nach oben.
double pocketCenter(int index) => -math.pi / 2 + index * pocketAngle;

/// Zeichnet den Kessel aus Holz, Taschen und Messingkreuz.
void paintWheel(
  Canvas canvas,
  Offset center,
  double radius,
  double angle, {
  bool labels = true,
}) {
  final rim = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF6B3E1E),
          Color(0xFFA9692F),
          Color(0xFF5A3218),
          Color(0xFFA9692F),
          Color(0xFF6B3E1E),
        ],
      ).createShader(rim),
  );
  canvas.drawCircle(
    center,
    radius * 0.9,
    Paint()..color = const Color(0xFF2A160E),
  );

  final outer = radius * 0.88;
  final inner = radius * 0.62;
  final sector = pocketAngle;
  final ring = (outer + inner) / 2;
  final stroke = outer - inner;
  final ringRect = Rect.fromCircle(center: center, radius: ring);
  for (var i = 0; i < wheelOrder.length; i++) {
    final n = wheelOrder[i];
    final mid = angle + pocketCenter(i);
    canvas.drawArc(
      ringRect,
      mid - sector / 2,
      sector,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = pocketColor(n),
    );
    final a = Offset(math.cos(mid - sector / 2), math.sin(mid - sector / 2));
    canvas.drawLine(
      center + a * inner,
      center + a * outer,
      Paint()
        ..strokeWidth = math.max(0.6, radius * 0.006)
        ..color = const Color(0xFFD6A65C),
    );
    if (labels) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.085,
            color: const Color(0xFFFFF1C9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(
        center.dx + math.cos(mid) * radius * 0.79,
        center.dy + math.sin(mid) * radius * 0.79,
      );
      canvas.rotate(mid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  // Innerer Teller mit Messingkreuz
  canvas.drawCircle(
    center,
    inner,
    Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFB9772A), Color(0xFF5A3218)],
      ).createShader(Rect.fromCircle(center: center, radius: inner)),
  );
  final brass = Paint()
    ..strokeWidth = radius * 0.035
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFE9C271);
  for (var i = 0; i < 4; i++) {
    final a = angle + i * math.pi / 2;
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(center, center + d * inner * 0.62, brass);
    canvas.drawCircle(center + d * inner * 0.62, radius * 0.03, brass);
  }
  canvas.drawCircle(center, radius * 0.07, Paint()..color = const Color(0xFFE9C271));
}

class WheelPainter extends CustomPainter {
  WheelPainter({
    required this.wheelAngle,
    required this.ballAngle,
    required this.ballRadius,
    required this.showBall,
  });

  final double wheelAngle;
  final double ballAngle;

  /// Bahn der Kugel als Anteil des Radius.
  final double ballRadius;
  final bool showBall;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2;
    paintWheel(canvas, c, r, wheelAngle);
    if (showBall) {
      final pos = c +
          Offset(math.cos(ballAngle), math.sin(ballAngle)) * (r * ballRadius);
      canvas.drawCircle(
        pos.translate(1, 1.5),
        r * 0.034,
        Paint()..color = const Color(0x88000000),
      );
      canvas.drawCircle(
        pos,
        r * 0.034,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Colors.white, Color(0xFFBDB6A6)],
          ).createShader(Rect.fromCircle(center: pos, radius: r * 0.034)),
      );
    }
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
      old.wheelAngle != wheelAngle ||
      old.ballAngle != ballAngle ||
      old.ballRadius != ballRadius ||
      old.showBall != showBall;
}
