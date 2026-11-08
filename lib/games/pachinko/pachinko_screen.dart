import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/widgets.dart';
import 'pachinko_board.dart';

class PachinkoScreen extends StatefulWidget {
  const PachinkoScreen({super.key});

  @override
  State<PachinkoScreen> createState() => _PachinkoScreenState();
}

class _PachinkoScreenState extends State<PachinkoScreen>
    with SingleTickerProviderStateMixin {
  final _board = PachinkoBoard();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  late final Wallet _wallet = AppScope.of(context).wallet;
  late final Sfx _sfx = AppScope.of(context).sfx;

  Duration _last = Duration.zero;
  double _carry = 0;
  double _sinceShot = 0;
  double _time = 0;
  double _power = 0.5;
  bool _firing = false;
  int _won = 0;
  int _spent = 0;
  String _message = 'Stärke einstellen und schießen';
  bool _big = false;

  static const _dt = 1 / 60;
  static const _shotInterval = 0.6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _carry += math.min(delta, 0.1);
    var steps = 0;
    while (_carry >= _dt && steps < 6) {
      _carry -= _dt;
      steps++;
      _sinceShot += _dt;
      if (_firing && _sinceShot >= _shotInterval) _shoot();
      _board.step(_dt);
    }
    _time += delta;
    _handleEvents();
    _frame.value++;
  }

  void _shoot() {
    if (!_wallet.spend(PachinkoBoard.ballCost)) {
      setState(() {
        _firing = false;
        _message = 'Münzen reichen nicht für einen Ball';
      });
      _wallet.refillIfBroke();
      return;
    }
    _sinceShot = 0;
    _spent += PachinkoBoard.ballCost;
    _board.launch(_power);
    _sfx.play(Sound.tick);
  }

  void _handleEvents() {
    if (_board.events.isEmpty) return;
    var paid = 0;
    String? text;
    var big = false;
    for (final e in _board.events) {
      paid += e.payout;
      switch (e.kind) {
        case PachinkoEventKind.tulip:
          text = 'Tulpe: +${formatCoins(e.payout)}';
          _sfx.play(Sound.coin);
        case PachinkoEventKind.start:
          text = 'Start: +${formatCoins(e.payout)}, die Ziffern drehen';
          _sfx.play(Sound.chip);
        case PachinkoEventKind.gate:
          text = 'Fieber-Tor: +${formatCoins(e.payout)}';
          big = true;
          _sfx.play(Sound.win);
        case PachinkoEventKind.fever:
          text = 'Fieber! Das Tor ist offen';
          big = true;
          _sfx.play(Sound.bigWin);
        case PachinkoEventKind.refund:
          text = 'Schuss zu schwach, Ball zurück';
        case PachinkoEventKind.stuck:
          text = 'Ball hing fest, Einsatz zurück';
        case PachinkoEventKind.reelsDone:
        case PachinkoEventKind.lost:
          break;
      }
    }
    _board.events.clear();
    if (paid > 0) {
      _wallet.credit(paid);
      _won += paid;
    }
    if (text != null) {
      setState(() {
        _message = text!;
        _big = big;
      });
    } else if (paid > 0) {
      setState(() {});
    }
    if (_board.ballsInPlay == 0 && !_firing) _wallet.refillIfBroke();
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Neon Pachinko',
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16082E), Color(0xFF2B0B45), Color(0xFF0B0620)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 0.95;
          final controlsSpace = wide ? 0.0 : 178.0;
          final h = box.maxHeight - controlsSpace - 12;
          final w = box.maxWidth - (wide ? math.min(300.0, box.maxWidth * 0.4) : 0) - 12;
          final scale = math.min(
            w / PachinkoBoard.boardWidth,
            h / PachinkoBoard.boardHeight,
          );
          final view = Center(
            child: SizedBox(
              width: scale * PachinkoBoard.boardWidth,
              height: scale * PachinkoBoard.boardHeight,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BoardPainter(_board, _frame, () => _time),
                ),
              ),
            ),
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: view),
                SizedBox(
                  width: math.min(300, box.maxWidth * 0.4),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: _controls(),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: view),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _controls(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _controls() {
    const light = TextStyle(
      color: Color(0xFFF6E7C8),
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBanner(text: _message, highlight: _big),
        Row(
          children: [
            const Text('Stärke', style: light),
            Expanded(
              child: Slider(
                value: _power,
                activeColor: const Color(0xFFFF5EA8),
                onChanged: (v) => setState(() => _power = v),
              ),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton(
              primary: true,
              label: _firing ? 'Stoppen' : 'Dauerfeuer',
              onPressed: () => setState(() {
                _firing = !_firing;
                _sinceShot = _shotInterval;
              }),
            ),
            ActionButton(
              label: 'Ein Ball: ${PachinkoBoard.ballCost}',
              onPressed: _firing ? null : _shoot,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Eingesetzt ${formatCoins(_spent)}, gewonnen ${formatCoins(_won)}',
          style: light.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.board, Listenable frame, this.time) : super(repaint: frame);

  final PachinkoBoard board;
  final double Function() time;

  void _text(
    Canvas c,
    String text,
    Offset center,
    double size,
    Color color, {
    String font = displayFont,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: font, fontSize: size, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = time();
    final s = size.width / PachinkoBoard.boardWidth;
    canvas.save();
    canvas.scale(s);
    const rect = Rect.fromLTWH(0, 0, PachinkoBoard.boardWidth, PachinkoBoard.boardHeight);

    // Gehäuse und Nachthimmel
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(0.5)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1140), Color(0xFF4A1466), Color(0xFFB02A7E), Color(0xFF2B0B45)],
          stops: [0, 0.45, 0.75, 1],
        ).createShader(rect),
    );
    _skyline(canvas);

    // Bogen und Bahn
    final arc = Path()..moveTo(board.arc.first.x, board.arc.first.y);
    for (final p in board.arc.skip(1)) {
      arc.lineTo(p.x, p.y);
    }
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..color = const Color(0xFF63E6FF);
    canvas.drawPath(arc, neon);
    canvas.drawLine(
      const Offset(PachinkoBoard.laneX, 3.4),
      const Offset(PachinkoBoard.laneX, 16),
      neon,
    );

    // Anzeigefeld
    const lcd = Rect.fromLTRB(
      PachinkoBoard.lcdLeft,
      PachinkoBoard.lcdTop,
      PachinkoBoard.lcdRight,
      PachinkoBoard.lcdBottom,
    );
    final roof = Path()
      ..moveTo(lcd.left + 0.05, lcd.top + 0.1)
      ..lineTo(lcd.center.dx, lcd.top - PachinkoBoard.lcdRoof)
      ..lineTo(lcd.right - 0.05, lcd.top + 0.1)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF0A0618));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = board.feverActive ? const Color(0xFFFF5EA8) : const Color(0xFFFFC95C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lcd, const Radius.circular(0.25)),
      Paint()..color = const Color(0xFF0A0618),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lcd, const Radius.circular(0.25)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..color = board.feverActive ? const Color(0xFFFF5EA8) : const Color(0xFFFFC95C),
    );
    final cellW = lcd.width / 3;
    for (var i = 0; i < 3; i++) {
      final center = Offset(lcd.left + cellW * (i + 0.5), lcd.center.dy - 0.2);
      // Die Ziffern halten von links nach rechts an
      final spinningNow = board.reelsSpinning && board.reelProgress < (i + 1) / 3;
      final value = spinningNow ? 1 + ((t * 14 + i * 3).floor() % 7) : board.reels[i];
      _text(canvas, '$value', center, 1.15, const Color(0xFFFFE9A8));
    }
    _text(
      canvas,
      board.feverActive
          ? 'Fieber ${board.feverLeft.ceil()}'
          : (board.queuedSpins > 0 ? 'Vorrat ${board.queuedSpins}' : 'Drei gleiche: Fieber'),
      Offset(lcd.center.dx, lcd.bottom - 0.45),
      0.34,
      const Color(0xFF63E6FF),
      font: bodyFont,
    );

    // Taschen
    for (final p in board.pockets) {
      final r = Rect.fromLTRB(p.left, p.top, p.right, p.bottom);
      switch (p.kind) {
        case PocketKind.tulip:
          _tulip(canvas, r);
        case PocketKind.start:
          canvas.drawRRect(
            RRect.fromRectAndRadius(r.inflate(0.12), const Radius.circular(0.1)),
            Paint()..color = const Color(0xFFFFC95C),
          );
          _text(canvas, 'Start', r.center, 0.32, const Color(0xFF2A160E), font: bodyFont);
        case PocketKind.gate:
          final open = board.feverActive;
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(0.1)),
            Paint()
              ..color = open
                  ? Color.lerp(
                      const Color(0xFFFF5EA8),
                      const Color(0xFFFFC95C),
                      (math.sin(t * 8) + 1) / 2,
                    )!
                  : const Color(0x663A2116),
          );
          _text(
            canvas,
            open ? 'Offen: ${p.payout}' : 'Fieber-Tor',
            r.center,
            0.32,
            open ? const Color(0xFF2A160E) : const Color(0x99FFE9A8),
            font: bodyFont,
          );
      }
    }

    // Nägel
    final peg = Paint()..color = const Color(0xFFE9C271);
    for (final p in board.pegs) {
      canvas.drawCircle(Offset(p.x, p.y), PachinkoBoard.pegRadius, peg);
    }

    // Windräder
    for (final w in board.spinners) {
      canvas.save();
      canvas.translate(w.x, w.y);
      canvas.rotate(w.angle);
      for (var i = 0; i < 4; i++) {
        canvas.rotate(math.pi / 2);
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(0.72, -0.1)
            ..lineTo(0.72, 0.1)
            ..close(),
          Paint()..color = i.isEven ? const Color(0xFFFF5EA8) : const Color(0xFF63E6FF),
        );
      }
      canvas.drawCircle(Offset.zero, 0.12, Paint()..color = const Color(0xFFFFE9A8));
      canvas.restore();
    }

    // Bälle
    for (final b in board.balls) {
      final o = Offset(b.x, b.y);
      canvas.drawCircle(
        o,
        PachinkoBoard.ballRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: const [Colors.white, Color(0xFFB9C2D6), Color(0xFF5A6480)],
          ).createShader(Rect.fromCircle(center: o, radius: PachinkoBoard.ballRadius)),
      );
    }
    canvas.restore();
  }

  void _skyline(Canvas c) {
    final rng = math.Random(23);
    final tower = Paint()..color = const Color(0x882B0B45);
    final window = Paint()..color = const Color(0x88FFC95C);
    var x = 0.3;
    while (x < 9.2) {
      final w = 0.5 + rng.nextDouble() * 0.7;
      final top = 8.6 + rng.nextDouble() * 3.4;
      c.drawRect(Rect.fromLTRB(x, top, x + w, 16), tower);
      for (var wy = top + 0.3; wy < 15.6; wy += 0.5) {
        for (var wx = x + 0.12; wx < x + w - 0.12; wx += 0.28) {
          if (rng.nextDouble() < 0.3) {
            c.drawRect(Rect.fromLTWH(wx, wy, 0.1, 0.16), window);
          }
        }
      }
      x += w + 0.08;
    }
  }

  void _tulip(Canvas c, Rect r) {
    final petals = Path()
      ..moveTo(r.left, r.top - 0.3)
      ..lineTo(r.left + r.width * 0.25, r.bottom)
      ..lineTo(r.right - r.width * 0.25, r.bottom)
      ..lineTo(r.right, r.top - 0.3)
      ..quadraticBezierTo(r.center.dx, r.top + 0.3, r.left, r.top - 0.3)
      ..close();
    c.drawPath(petals, Paint()..color = const Color(0xFFFF5EA8));
    _text(c, '${PachinkoBoard.tulipPay}', r.center, 0.3, Colors.white, font: bodyFont);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => false;
}
