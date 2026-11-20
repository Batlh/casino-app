import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../slots/art_kit.dart';
import 'claw_engine.dart';

final clawGuide = GameGuide('Greifautomat', [
  const GuideSection(
    'So geht es',
    'Einsatz zahlen, dann die Taste „Fahren“ gedrückt halten: Der Greifer fährt nach rechts. Lässt du los, fährt er '
        'hinunter und greift. Schafft er den Preis bis in den Schacht links, bekommst du den Preis in Münzen. Nach zehn '
        'Sekunden greift er von selbst.',
  ),
  GuideSection(
    'Preise (mal Einsatz)',
    [for (final k in prizeKinds) '${k.name} ${k.value}'].join(', '),
  ),
  const GuideSection(
    'Zielen und Glück',
    'Sitzt der Greifer genau über der Mitte eines Preises, packt er am besten zu, am Rand rutscht er eher ab. Oben '
        'aufliegende Preise greift er zuerst. Ob er wirklich festhält, ist auch Glück: Teure Preise rutschen öfter heraus. '
        'Auf lange Sicht bringt selbst perfektes Zielen 95 % der Einsätze zurück, egal welchen Preis du anpeilst.',
  ),
]);

enum _Phase { idle, ready, moving, down, close, up, back, release }

class ClawScreen extends StatefulWidget {
  const ClawScreen({super.key, this.seed});
  final int? seed;

  @override
  State<ClawScreen> createState() => _ClawScreenState();
}

class _ClawScreenState extends State<ClawScreen> with SingleTickerProviderStateMixin {
  late final ClawMachine _m = ClawMachine(rng: widget.seed == null ? null : math.Random(widget.seed));
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  static const double _restX = chuteWidth / 2;
  static const double _restY = 1.0;
  double _x = _restX;
  double _y = _restY;
  double _open = 1; // 1 offen, 0 zu
  double _timer = 10;
  _Phase _phase = _Phase.idle;
  ClawResult? _result;
  Prize? _carried;
  double _grabX = 0;
  bool _holding = false;
  int _bet = 10;
  int _paidBet = 10;
  String _message = 'Einsatz zahlen und den Greifer fahren';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _pay() {
    if (_phase != _Phase.idle || !_app.wallet.spend(_bet)) return;
    _paidBet = _bet;
    _app.sfx.play(Sound.coin);
    setState(() {
      _phase = _Phase.ready;
      _timer = 10;
      _big = false;
      _message = '„Fahren“ halten, loslassen zum Greifen';
    });
    _start();
  }

  void _start() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _press(bool down) {
    if (down && _phase == _Phase.ready) {
      _holding = true;
      _phase = _Phase.moving;
    } else if (!down && _phase == _Phase.moving) {
      _holding = false;
      _phase = _Phase.down;
    }
    _start();
  }

  double _prizeY(Prize p) => p.layer == 0 ? 7.1 : 6.2;

  void _tick(Duration now) {
    final dt = math.min(0.05, (now - _last).inMicroseconds / 1e6);
    _last = now;
    switch (_phase) {
      case _Phase.idle:
        _ticker.stop();
      case _Phase.ready:
        _timer -= dt;
        if (_timer <= 0) _phase = _Phase.down;
      case _Phase.moving:
        _timer -= dt;
        _x = math.min(clawBoxWidth - 0.6, _x + dt * 1.6);
        if (!_holding || _timer <= 0 || _x >= clawBoxWidth - 0.6) _phase = _Phase.down;
      case _Phase.down:
        final target = _m.prizeAt(_x);
        final bottom = target == null ? 7.2 : _prizeY(target) - 0.55;
        _y = math.min(bottom, _y + dt * 3);
        if (_y >= bottom) {
          _phase = _Phase.close;
          _grabX = _x;
          _result = _m.grab(_x);
          debugLog.info('greifer', 'x ${_x.toStringAsFixed(2)}: ${_result!.prize?.info.name ?? 'leer'}, '
              'Ziel ${(_result!.quality * 100).round()} %, ${_result!.won ? 'gewonnen' : (_result!.grabbed ? 'rutscht' : 'verfehlt')}');
          _carried = _result!.grabbed ? _result!.prize : null;
        }
      case _Phase.close:
        _open = math.max(0, _open - dt * 2.5);
        if (_open <= 0) _phase = _Phase.up;
      case _Phase.up:
        _y = math.max(_restY, _y - dt * 2.2);
        if (_y <= _restY) _phase = _Phase.back;
      case _Phase.back:
        final startX = _grabX;
        _x = math.max(_restX, _x - dt * 1.8);
        final r = _result;
        if (_carried != null && r != null && !r.won) {
          final done = (startX - _x) / math.max(0.01, startX - _restX);
          if (done >= r.dropAt) {
            _carried = null;
            _app.sfx.play(Sound.lose);
          }
        }
        if (_x <= _restX) _phase = _Phase.release;
      case _Phase.release:
        _open = math.min(1, _open + dt * 2.5);
        if (_open >= 1) _finish();
    }
    setState(() {});
  }

  void _finish() {
    final r = _result;
    _phase = _Phase.idle;
    _carried = null;
    if (r != null && r.won) {
      final win = r.prize!.info.value * _paidBet;
      _app.wallet.credit(win);
      _app.sfx.play(r.prize!.info.value >= 10 ? Sound.bigWin : Sound.win);
      _message = '${r.prize!.info.name}! +${formatCoins(win)}';
      _big = r.prize!.info.value >= 10;
    } else if (r?.prize == null) {
      _message = 'Daneben gegriffen';
    } else {
      _message = r!.grabbed ? '${r.prize!.info.name} ist herausgerutscht' : 'Der Greifer ist abgerutscht';
    }
    _result = null;
    _x = _restX;
    _y = _restY;
    _app.wallet.refillIfBroke();
  }

  @override
  Widget build(BuildContext context) {
    final idle = _phase == _Phase.idle;
    return GameFrame(
      title: 'Greifautomat',
      guide: clawGuide,
      background: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B0A45), Color(0xFF14031A)])),
      child: LayoutBuilder(builder: (context, box) {
        final w = math.min(box.maxWidth - 24, (box.maxHeight - 230) * clawBoxWidth / 8);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                width: w,
                height: w * 0.8,
                child: CustomPaint(
                  painter: _BoxPainter(
                    prizes: [for (final p in _m.prizes) if (p != _carried) p],
                    clawX: _x,
                    clawY: _y,
                    open: _open,
                    carried: _carried,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ResultBanner(text: _message, highlight: _big, maxLines: 2),
              if (_phase == _Phase.ready || _phase == _Phase.moving)
                Text('Noch ${_timer.ceil()} s', style: const TextStyle(color: Color(0xFFFFC95C))),
              const SizedBox(height: 10),
              if (idle) ...[
                BetPicker(value: _bet, onChanged: (v) => setState(() => _bet = v)),
                const SizedBox(height: 8),
                ActionButton(primary: true, label: 'Einsatz: ${formatCoins(_bet)}', onPressed: _app.wallet.canAfford(_bet) ? _pay : null),
              ] else
                Listener(
                  onPointerDown: (_) => _press(true),
                  onPointerUp: (_) => _press(false),
                  onPointerCancel: (_) => _press(false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 180,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        colors: _phase == _Phase.ready || _phase == _Phase.moving
                            ? const [Color(0xFF69F0AE), Color(0xFF00897B)]
                            : const [Color(0xFF616161), Color(0xFF303030)],
                      ),
                      border: Border.all(color: Colors.black54, width: 2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_phase == _Phase.moving ? 'Loslassen = greifen' : 'Fahren',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      if (_phase != _Phase.moving) const Icon(Icons.arrow_right, color: Colors.white, size: 30),
                    ]),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter({required this.prizes, required this.clawX, required this.clawY, required this.open, required this.carried});
  final List<Prize> prizes;
  final double clawX;
  final double clawY;
  final double open;
  final Prize? carried;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / clawBoxWidth;
    Offset at(double x, double y) => Offset(x * s, y * s);
    final box = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(12)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1E0F2E), Color(0xFF4A1A5E)]).createShader(box),
    );
    // Schacht links
    final chute = Rect.fromLTRB(0, 5.2 * s, chuteWidth * s, size.height);
    canvas.drawRect(chute, Paint()..color = const Color(0xFF0A0410));
    canvas.drawRect(Rect.fromLTWH(chuteWidth * s - 4, 5.2 * s, 6, size.height - 5.2 * s), Paint()..color = const Color(0xFFB0BEC5));
    // Boden
    canvas.drawRect(Rect.fromLTRB(chuteWidth * s, 7.7 * s, size.width, size.height), Paint()..color = const Color(0xFF2B1238));
    // Preise
    for (final layer in [0, 1]) {
      for (final p in prizes.where((p) => p.layer == layer)) {
        _paintPrize(canvas, at(p.x, p.layer == 0 ? 7.1 : 6.2), s, p.kind);
      }
    }
    // Schiene und Greifer
    canvas.drawRect(Rect.fromLTWH(0, 0.25 * s, size.width, 0.18 * s), Paint()..color = const Color(0xFF90A4AE));
    final top = at(clawX, 0.4);
    final head = at(clawX, clawY);
    canvas.drawLine(top, head, Paint()
      ..color = const Color(0xFFCFD8DC)
      ..strokeWidth = 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top, width: 0.8 * s, height: 0.35 * s), const Radius.circular(4)), Paint()..color = const Color(0xFFFFC107));
    final c = carried;
    if (c != null) _paintPrize(canvas, head.translate(0, 0.55 * s), s, c.kind);
    canvas.drawCircle(head, 0.22 * s, Paint()..color = const Color(0xFFB0BEC5));
    final arm = Paint()
      ..color = const Color(0xFFECEFF1)
      ..strokeWidth = 0.1 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final side in [-1.0, 0.0, 1.0]) {
      final spread = (0.15 + 0.4 * open) * side;
      final elbow = head + Offset(spread * s * 1.2, 0.45 * s);
      final tip = head + Offset(spread * s * 0.6, 0.9 * s);
      canvas.drawPath(Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(tip.dx, tip.dy), arm);
    }
    // Glas
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFC107));
    canvas.drawLine(at(1, 0.8), at(3.5, 3.2), Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 10);
  }

  void _paintPrize(Canvas canvas, Offset c, double s, int kind) {
    final r = prizeKinds[kind].width * s / 2;
    switch (kind) {
      case 0: // Entchen
        shaded(canvas, Path()..addOval(Rect.fromCenter(center: c.translate(0, r * 0.15), width: r * 1.9, height: r * 1.3)), const Color(0xFFFFF59D), const Color(0xFFF9A825));
        shaded(canvas, Path()..addOval(Rect.fromCircle(center: c.translate(r * 0.45, -r * 0.55), radius: r * 0.5)), const Color(0xFFFFF59D), const Color(0xFFF9A825));
        canvas.drawPath(
            Path()
              ..moveTo(c.dx + r * 0.85, c.dy - r * 0.6)
              ..lineTo(c.dx + r * 1.25, c.dy - r * 0.45)
              ..lineTo(c.dx + r * 0.85, c.dy - r * 0.35)
              ..close(),
            fillOf(const Color(0xFFFF7043)));
        canvas.drawCircle(c.translate(r * 0.55, -r * 0.65), r * 0.08, fillOf(Colors.black));
      case 1: // Bärchen
        for (final dx in [-0.55, 0.55]) {
          canvas.drawCircle(c.translate(dx * r, -r * 0.75), r * 0.28, fillOf(const Color(0xFF8D6E63)));
        }
        shaded(canvas, Path()..addOval(Rect.fromCircle(center: c.translate(0, -r * 0.3), radius: r * 0.6)), const Color(0xFFBCAAA4), const Color(0xFF6D4C41));
        shaded(canvas, Path()..addOval(Rect.fromCenter(center: c.translate(0, r * 0.5), width: r * 1.5, height: r * 1.0)), const Color(0xFFBCAAA4), const Color(0xFF6D4C41));
        for (final dx in [-0.2, 0.2]) {
          canvas.drawCircle(c.translate(dx * r, -r * 0.4), r * 0.07, fillOf(Colors.black));
        }
        canvas.drawCircle(c.translate(0, -r * 0.18), r * 0.1, fillOf(const Color(0xFF3E2723)));
      case 2: // Häschen
        for (final dx in [-0.25, 0.25]) {
          shaded(canvas, Path()..addOval(Rect.fromCenter(center: c.translate(dx * r, -r * 1.05), width: r * 0.35, height: r * 0.9)), const Color(0xFFFCE4EC), const Color(0xFFF48FB1), width: 1);
        }
        shaded(canvas, Path()..addOval(Rect.fromCircle(center: c.translate(0, -r * 0.35), radius: r * 0.5)), const Color(0xFFFCE4EC), const Color(0xFFF48FB1));
        shaded(canvas, Path()..addOval(Rect.fromCenter(center: c.translate(0, r * 0.45), width: r * 1.4, height: r * 1.0)), const Color(0xFFFCE4EC), const Color(0xFFF48FB1));
        for (final dx in [-0.18, 0.18]) {
          canvas.drawCircle(c.translate(dx * r, -r * 0.42), r * 0.07, fillOf(Colors.black));
        }
      case 3: // Stern
        shaded(canvas, starPath(c, r * 1.05), const Color(0xFFFFF176), const Color(0xFFF9A825));
        for (final dx in [-0.2, 0.2]) {
          canvas.drawCircle(c.translate(dx * r, -r * 0.05), r * 0.08, fillOf(Colors.black));
        }
      default: // Krone
        final crown = Path()
          ..moveTo(c.dx - r, c.dy + r * 0.5)
          ..lineTo(c.dx - r, c.dy - r * 0.5)
          ..lineTo(c.dx - r * 0.5, c.dy)
          ..lineTo(c.dx, c.dy - r * 0.75)
          ..lineTo(c.dx + r * 0.5, c.dy)
          ..lineTo(c.dx + r, c.dy - r * 0.5)
          ..lineTo(c.dx + r, c.dy + r * 0.5)
          ..close();
        glow(canvas, c, r * 1.4, const Color(0x66FFD54F));
        shaded(canvas, crown, const Color(0xFFFFF59D), const Color(0xFFB8860B));
        canvas.drawCircle(c.translate(0, r * 0.15), r * 0.15, fillOf(const Color(0xFFE53935)));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => true;
}
