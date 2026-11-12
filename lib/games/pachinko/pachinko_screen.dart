import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import 'pachinko_board.dart';

class PachinkoScreen extends StatefulWidget {
  const PachinkoScreen({super.key});

  @override
  State<PachinkoScreen> createState() => _PachinkoScreenState();
}

class _PachinkoScreenState extends State<PachinkoScreen>
    with SingleTickerProviderStateMixin {
  PachinkoBoard _board = PachinkoBoard();
  bool _choosing = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final saved = AppScope.of(context).settings.loadGame('pachinko')?['machine'];
    for (final m in pachinkoMachines) {
      if (m.id == saved && _board.spec.id != m.id) _board = PachinkoBoard(spec: m);
    }
  }

  void _choose(MachineSpec m) {
    AppScope.of(context).settings.saveGame('pachinko', {'machine': m.id});
    setState(() {
      _board = PachinkoBoard(spec: m);
      _choosing = false;
      _firing = false;
      _message = '${m.name}: ${m.blurb}';
      _big = false;
    });
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

  Widget _chooser() {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = math.max(2, math.min(5, (box.maxWidth / 200).floor()));
        return GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.58,
          children: [
            for (final m in pachinkoMachines)
              GestureDetector(
                onTap: () => _choose(m),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: m.id == _board.spec.id ? m.theme.accent : m.theme.peg.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: PachinkoBoard.boardWidth / PachinkoBoard.boardHeight,
                          child: CustomPaint(painter: _BoardPainter.preview(m)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(m.name, style: TextStyle(color: m.theme.accent, fontSize: 15, fontWeight: FontWeight.w800)),
                      Text(
                        m.blurb,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = _board.spec.theme;
    return GameFrame(
      guide: pachinkoGuide,
      title: _choosing ? 'Pachinko: Maschine wählen' : _board.spec.name,
      background: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(th.top, Colors.black, 0.5)!, Color.lerp(th.bottom, Colors.black, 0.3)!],
        ),
      ),
      child: _choosing ? _chooser() : LayoutBuilder(
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
                  painter: _BoardPainter(() => _board, _frame, () => _time),
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
                activeColor: _board.spec.theme.fever,
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
            ActionButton(
              label: 'Maschine wechseln',
              onPressed: _firing || _board.ballsInPlay > 0 ? null : () => setState(() => _choosing = true),
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
  _BoardPainter(this.boardOf, Listenable frame, this.time) : super(repaint: frame);

  /// Standbild für die Maschinenauswahl.
  _BoardPainter.preview(MachineSpec m)
      : boardOf = (() => _demos.putIfAbsent(m.id, () => PachinkoBoard(rng: math.Random(1), spec: m))),
        time = (() => 0.0);

  static final Map<String, PachinkoBoard> _demos = {};

  final PachinkoBoard Function() boardOf;
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
    final board = boardOf();
    final th = board.spec.theme;
    final t = time();
    final s = size.width / PachinkoBoard.boardWidth;
    canvas.save();
    canvas.scale(s);
    const rect = Rect.fromLTWH(0, 0, PachinkoBoard.boardWidth, PachinkoBoard.boardHeight);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(0.5));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [th.top, Color.lerp(th.top, th.bottom, 0.5)!, th.bottom],
        ).createShader(rect),
    );
    _art(canvas, board, t);

    // Bogen und Bahn
    final arc = Path()..moveTo(board.arc.first.x, board.arc.first.y);
    for (final p in board.arc.skip(1)) {
      arc.lineTo(p.x, p.y);
    }
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..color = th.accent;
    canvas.drawPath(arc, neon);
    canvas.drawLine(const Offset(PachinkoBoard.laneX, 3.4), const Offset(PachinkoBoard.laneX, 16), neon);

    _lcd(canvas, board, t);

    // Taschen
    for (final p in board.pockets) {
      final r = Rect.fromLTRB(p.left, p.top, p.right, p.bottom);
      switch (p.kind) {
        case PocketKind.tulip:
          _tulip(canvas, r, p.payout, th);
        case PocketKind.start:
          canvas.drawRRect(
            RRect.fromRectAndRadius(r.inflate(0.12), const Radius.circular(0.1)),
            Paint()..color = th.accent,
          );
          _text(canvas, 'Start', r.center, 0.32, const Color(0xFF2A160E), font: bodyFont);
        case PocketKind.gate:
          final open = board.feverActive;
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(0.1)),
            Paint()
              ..color = open
                  ? Color.lerp(th.fever, th.accent, (math.sin(t * 8) + 1) / 2)!
                  : Colors.black.withValues(alpha: 0.35),
          );
          _text(
            canvas,
            open ? 'Offen: ${p.payout}' : 'Fieber-Tor',
            r.center,
            0.32,
            open ? const Color(0xFF2A160E) : th.peg.withValues(alpha: 0.6),
            font: bodyFont,
          );
      }
    }

    // Nägel
    final peg = Paint()..color = th.peg;
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
          Paint()..color = i.isEven ? th.fever : th.accent,
        );
      }
      canvas.drawCircle(Offset.zero, 0.12, Paint()..color = th.peg);
      canvas.restore();
    }

    // Bälle
    for (final b in board.balls) {
      final o = Offset(b.x, b.y);
      canvas.drawCircle(
        o,
        PachinkoBoard.ballRadius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Colors.white, Color(0xFFB9C2D6), Color(0xFF5A6480)],
          ).createShader(Rect.fromCircle(center: o, radius: PachinkoBoard.ballRadius)),
      );
    }
    if (board.feverActive) {
      canvas.drawRRect(
        rr.deflate(0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.14
          ..color = ((t * 6).floor().isEven ? th.fever : th.accent).withValues(alpha: 0.8),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  // ---------- Anzeigefeld ----------

  void _lcd(Canvas canvas, PachinkoBoard board, double t) {
    final th = board.spec.theme;
    final l = board.lcd;
    final lcd = Rect.fromLTRB(l.left, l.top, l.right, l.bottom);
    final edge = board.feverActive ? th.fever : th.accent;
    final roof = Path()
      ..moveTo(lcd.left + 0.05, lcd.top + 0.1)
      ..lineTo(lcd.center.dx, lcd.top - l.roof)
      ..lineTo(lcd.right - 0.05, lcd.top + 0.1)
      ..close();
    canvas.drawPath(roof, Paint()..color = th.lcd);
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
    final box = RRect.fromRectAndRadius(lcd, const Radius.circular(0.25));
    canvas.drawRRect(box, Paint()..color = th.lcd);
    canvas.save();
    canvas.clipRRect(box);
    _lcdAnimation(canvas, board, lcd, t);
    final cellW = lcd.width / 3;
    for (var i = 0; i < 3; i++) {
      final center = Offset(lcd.left + cellW * (i + 0.5), lcd.center.dy - 0.2);
      // Die Walzen halten von links nach rechts an
      final spinningNow = board.reelsSpinning && board.reelProgress < (i + 1) / 3;
      final value = spinningNow ? 1 + ((t * 14 + i * 3).floor() % 7) : board.reels[i];
      _symbol(canvas, board.spec.theme.art, value, center, cellW * 0.42, th, spinningNow);
    }
    _text(
      canvas,
      board.feverActive
          ? 'Fieber ${board.feverLeft.ceil()}'
          : (board.queuedSpins > 0 ? 'Vorrat ${board.queuedSpins}' : 'Drei gleiche: Fieber'),
      Offset(lcd.center.dx, lcd.bottom - 0.45),
      0.34,
      th.accent,
      font: bodyFont,
    );
    if (th.art == 'retro') {
      final scan = Paint()..color = Colors.black.withValues(alpha: 0.35);
      for (var y = lcd.top; y < lcd.bottom; y += 0.12) {
        canvas.drawRect(Rect.fromLTWH(lcd.left, y, lcd.width, 0.04), scan);
      }
    }
    canvas.restore();
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..color = edge,
    );
  }

  /// Bewegte Bilder im Anzeigefeld; beim Drehen und im Fieber lebhafter.
  void _lcdAnimation(Canvas canvas, PachinkoBoard board, Rect lcd, double t) {
    final th = board.spec.theme;
    final busy = board.reelsSpinning || board.feverActive;
    switch (th.art) {
      case 'sea':
        // Fische schwimmen durch, Blasen steigen
        for (var k = 0; k < (busy ? 6 : 3); k++) {
          final speed = 0.6 + k * 0.15;
          final x = lcd.left + ((t * speed + k * 0.37) % 1.4) * lcd.width / 1.2 - 0.3;
          final y = lcd.top + 0.5 + (k * 0.61 % 1) * (lcd.height - 1.0);
          _fish(canvas, Offset(x, y), 0.32, k.isEven ? th.accent : th.fever, k.isOdd);
        }
        for (var k = 0; k < 8; k++) {
          final y = lcd.bottom - ((t * 0.8 + k * 0.23) % 1) * lcd.height;
          final x = lcd.left + 0.2 + (k * 0.37 % 1) * (lcd.width - 0.4) + 0.08 * math.sin(t * 3 + k);
          canvas.drawCircle(
            Offset(x, y),
            0.05 + (k % 3) * 0.02,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.02
              ..color = Colors.white.withValues(alpha: 0.5),
          );
        }
      case 'dragon':
        if (!busy) {
          // Ruhende Glut
          canvas.drawCircle(
            lcd.center,
            lcd.width * 0.45,
            Paint()
              ..shader = RadialGradient(colors: [th.fever.withValues(alpha: 0.25), Colors.transparent])
                  .createShader(Rect.fromCircle(center: lcd.center, radius: lcd.width * 0.45)),
          );
          break;
        }
        // Drache fliegt als Wellenlinie aus Schuppen durchs Bild
        final head = lcd.left + ((t * 0.5) % 1.5) * lcd.width - 0.3;
        for (var i = 0; i < 14; i++) {
          final x = head - i * 0.22;
          final y = lcd.center.dy + 0.5 * math.sin(t * 4 - i * 0.5);
          final r = i == 0 ? 0.22 : 0.17 - i * 0.008;
          canvas.drawCircle(Offset(x, y), r, Paint()..color = (i.isEven ? th.accent : th.fever).withValues(alpha: 0.75));
        }
        if (board.feverActive) {
          for (var k = 0; k < 6; k++) {
            final f = (t * 2 + k * 0.17) % 1;
            canvas.drawCircle(
              Offset(head + 0.25 + f * 0.9, lcd.center.dy + 0.5 * math.sin(t * 4) + (k - 3) * 0.05),
              0.12 * (1 - f),
              Paint()..color = Color.lerp(th.accent, th.fever, f)!.withValues(alpha: 1 - f),
            );
          }
        }
      case 'blossom':
        for (var k = 0; k < (busy ? 14 : 7); k++) {
          final fall = (t * (0.2 + (k % 4) * 0.05) + k * 0.13) % 1;
          final x = lcd.left + (k * 0.29 % 1) * lcd.width + 0.25 * math.sin(t * 1.5 + k);
          final y = lcd.top + fall * lcd.height;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(t * 2 + k);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 0.18, height: 0.11),
            Paint()..color = th.accent.withValues(alpha: 0.7),
          );
          canvas.restore();
        }
      case 'retro':
        // Pixel-Eindringlinge wandern hin und her
        final dir = (t * 0.5).floor().isEven ? 1 : -1;
        final shift = ((t * 0.5) % 1) * 0.6 * dir + (dir < 0 ? 0.6 : 0);
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 5; col++) {
            final x = lcd.left + 0.35 + col * 0.5 + shift;
            final y = lcd.top + 0.35 + row * 0.4;
            _invader(canvas, Offset(x, y), 0.05, (row.isEven ? th.peg : th.fever).withValues(alpha: busy ? 0.8 : 0.35), (t * 2).floor().isEven);
          }
        }
      default:
        break;
    }
  }

  void _symbol(Canvas canvas, String art, int value, Offset c, double size, MachineTheme th, bool spinning) {
    final alpha = spinning ? 0.7 : 1.0;
    switch (art) {
      case 'sea':
        const colors = [
          Color(0xFFFF8A65), Color(0xFFFFD54F), Color(0xFF4FC3F7), Color(0xFF81C784),
          Color(0xFFBA68C8), Color(0xFFF06292), Color(0xFFFFFFFF),
        ];
        _fish(canvas, c, size * 0.9, colors[value - 1].withValues(alpha: alpha), false);
        _text(canvas, '$value', c + Offset(0, size * 0.75), size * 0.45, Colors.white.withValues(alpha: alpha), font: bodyFont);
      case 'dragon':
        const kanji = ['一', '二', '三', '四', '五', '六', '七'];
        _text(canvas, kanji[value - 1], c, size * 1.5, th.accent.withValues(alpha: alpha));
        _text(canvas, '$value', c + Offset(size * 0.8, size * 0.7), size * 0.4, th.peg.withValues(alpha: alpha), font: bodyFont);
      case 'blossom':
        // Blüte mit so vielen Blättern wie die Zahl
        for (var k = 0; k < value; k++) {
          final a = -math.pi / 2 + k * 2 * math.pi / value;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * size * 0.45,
            size * (value == 1 ? 0.45 : 0.3),
            Paint()..color = th.accent.withValues(alpha: alpha * 0.9),
          );
        }
        canvas.drawCircle(c, size * 0.22, Paint()..color = th.fever.withValues(alpha: alpha));
        _text(canvas, '$value', c, size * 0.32, const Color(0xFF5A2A40), font: bodyFont);
      case 'retro':
        _pixelDigit(canvas, value, c, size * 0.16, th.peg.withValues(alpha: alpha));
      default:
        _text(canvas, '$value', c, 1.15, const Color(0xFFFFE9A8).withValues(alpha: alpha));
    }
  }

  void _fish(Canvas canvas, Offset c, double size, Color color, bool left) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (left) canvas.scale(-1, 1);
    final body = Path()
      ..moveTo(size * 0.6, 0)
      ..quadraticBezierTo(0, -size * 0.45, -size * 0.45, 0)
      ..quadraticBezierTo(0, size * 0.45, size * 0.6, 0)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    final tail = Path()
      ..moveTo(-size * 0.4, 0)
      ..lineTo(-size * 0.75, -size * 0.3)
      ..lineTo(-size * 0.75, size * 0.3)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);
    canvas.drawCircle(Offset(size * 0.3, -size * 0.08), size * 0.06, Paint()..color = Colors.black);
    canvas.restore();
  }

  static const _invaderBits = ['0010000100', '0001111000', '0011011100', '0111111110', '0101111010', '0100000010'];

  void _invader(Canvas canvas, Offset c, double px, Color color, bool frame) {
    final p = Paint()..color = color;
    for (var y = 0; y < _invaderBits.length; y++) {
      final row = y == 5 && frame ? '1000000001' : _invaderBits[y];
      for (var x = 0; x < row.length; x++) {
        if (row[x] == '1') canvas.drawRect(Rect.fromLTWH(c.dx + (x - 5) * px, c.dy + (y - 3) * px, px, px), p);
      }
    }
  }

  /// Ziffer aus Pixeln (5 × 7).
  static const _digits = {
    1: ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    2: ['01110', '10001', '00001', '00110', '01000', '10000', '11111'],
    3: ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
    4: ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    5: ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    6: ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    7: ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  };

  void _pixelDigit(Canvas canvas, int value, Offset c, double px, Color color) {
    final rows = _digits[value]!;
    final p = Paint()..color = color;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < 5; x++) {
        if (rows[y][x] == '1') {
          canvas.drawRect(Rect.fromLTWH(c.dx + (x - 2.5) * px, c.dy + (y - 3.5) * px, px * 0.9, px * 0.9), p);
        }
      }
    }
  }

  // ---------- Motive auf dem Brett ----------

  void _art(Canvas canvas, PachinkoBoard board, double t) {
    final th = board.spec.theme;
    switch (th.art) {
      case 'sea':
        // Lichtstrahlen, Seegras, aufsteigende Blasen
        for (var k = 0; k < 5; k++) {
          final x = 1 + k * 2.0 + math.sin(t * 0.3 + k) * 0.3;
          final ray = Path()
            ..moveTo(x, 0)
            ..lineTo(x + 0.6, 0)
            ..lineTo(x + 1.6, 16)
            ..lineTo(x + 0.6, 16)
            ..close();
          canvas.drawPath(ray, Paint()..color = Colors.white.withValues(alpha: 0.04));
        }
        final weed = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.12
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x6630A060);
        for (var k = 0; k < 9; k++) {
          final x = 0.5 + k * 1.0;
          final p = Path()..moveTo(x, 16);
          for (var y = 16.0; y > 14.2; y -= 0.2) {
            p.lineTo(x + 0.15 * math.sin(t * 1.5 + y * 2 + k), y);
          }
          canvas.drawPath(p, weed);
        }
        for (var k = 0; k < 12; k++) {
          final y = 16 - ((t * 0.5 + k * 0.29) % 1) * 15;
          canvas.drawCircle(
            Offset(0.6 + (k * 0.41 % 1) * 8.4, y),
            0.06,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.02
              ..color = Colors.white.withValues(alpha: 0.35),
          );
        }
      case 'dragon':
        // Laternen und Tempeldächer
        for (var k = 0; k < 4; k++) {
          final c = Offset(1.0 + k * 2.4, 14.8 + (k.isEven ? 0 : 0.3));
          final glow = 0.6 + 0.4 * math.sin(t * 2 + k);
          canvas.drawCircle(c, 0.6, Paint()..color = th.fever.withValues(alpha: 0.12 * glow));
          canvas.drawOval(Rect.fromCenter(center: c, width: 0.5, height: 0.65), Paint()..color = th.fever.withValues(alpha: 0.7));
          canvas.drawLine(c + const Offset(0, -0.33), c + const Offset(0, -0.8), Paint()
            ..color = th.peg.withValues(alpha: 0.5)
            ..strokeWidth = 0.03);
        }
        final roof = Path()
          ..moveTo(0.4, 13.2)
          ..quadraticBezierTo(2.2, 12.6, 2.6, 12.0)
          ..lineTo(7.0, 12.0)
          ..quadraticBezierTo(7.4, 12.6, 9.0, 13.2)
          ..close();
        canvas.drawPath(roof, Paint()..color = Colors.black.withValues(alpha: 0.25));
      case 'blossom':
        // Ast mit Blüten, fallende Blätter
        final branch = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.14
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x664A2A1A);
        canvas.drawPath(
          Path()
            ..moveTo(0, 1.5)
            ..quadraticBezierTo(1.5, 2.2, 2.4, 1.6)
            ..moveTo(1.2, 1.9)
            ..quadraticBezierTo(1.6, 2.8, 1.1, 3.4),
          branch,
        );
        final rng = math.Random(4);
        for (var k = 0; k < 10; k++) {
          canvas.drawCircle(
            Offset(0.3 + rng.nextDouble() * 2.2, 1.3 + rng.nextDouble() * 2),
            0.12,
            Paint()..color = th.accent.withValues(alpha: 0.5),
          );
        }
        for (var k = 0; k < 16; k++) {
          final fall = (t * (0.05 + (k % 5) * 0.012) + k * 0.07) % 1;
          final x = (k * 0.61 % 1) * 9 + 0.6 * math.sin(t * 0.8 + k);
          canvas.save();
          canvas.translate(x, fall * 16);
          canvas.rotate(t + k);
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: 0.2, height: 0.12),
            Paint()..color = th.accent.withValues(alpha: 0.35),
          );
          canvas.restore();
        }
      case 'retro':
        // Gitterboden mit Fluchtpunkt und Sterne
        final grid = Paint()
          ..color = th.fever.withValues(alpha: 0.18)
          ..strokeWidth = 0.03;
        for (var k = -8; k <= 8; k++) {
          canvas.drawLine(Offset(5 + k * 0.3, 11.5), Offset(5 + k * 1.6, 16), grid);
        }
        for (var k = 0; k < 6; k++) {
          final f = ((k + (t * 0.6) % 1) / 6);
          final y = 11.5 + f * f * 4.5;
          canvas.drawLine(Offset(0, y), Offset(10, y), grid);
        }
        final rng = math.Random(9);
        for (var k = 0; k < 40; k++) {
          canvas.drawRect(
            Rect.fromLTWH(rng.nextDouble() * 10, rng.nextDouble() * 11, 0.05, 0.05),
            Paint()..color = Colors.white.withValues(alpha: 0.3 + 0.3 * rng.nextDouble()),
          );
        }
      default:
        _skyline(canvas, th);
    }
  }

  void _skyline(Canvas c, MachineTheme th) {
    final rng = math.Random(23);
    final tower = Paint()..color = const Color(0x882B0B45);
    final window = Paint()..color = th.accent.withValues(alpha: 0.5);
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

  void _tulip(Canvas c, Rect r, int payout, MachineTheme th) {
    final petals = Path()
      ..moveTo(r.left, r.top - 0.3)
      ..lineTo(r.left + r.width * 0.25, r.bottom)
      ..lineTo(r.right - r.width * 0.25, r.bottom)
      ..lineTo(r.right, r.top - 0.3)
      ..quadraticBezierTo(r.center.dx, r.top + 0.3, r.left, r.top - 0.3)
      ..close();
    c.drawPath(petals, Paint()..color = th.fever);
    _text(c, '$payout', r.center, 0.3, Colors.white, font: bodyFont);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => false;
}
