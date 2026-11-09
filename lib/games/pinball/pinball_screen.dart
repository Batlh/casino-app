import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import 'pinball_table.dart';

/// Ein Spiel mit drei Kugeln kostet so viel, ausgezahlt wird nach Punkten.
const pinballGameCost = 20;
const pinballPointsPerCoin = 100;

int pinballPayout(int score) => score ~/ pinballPointsPerCoin;

class PinballScreen extends StatefulWidget {
  const PinballScreen({super.key, this.seed});
  final int? seed;

  @override
  State<PinballScreen> createState() => _PinballScreenState();
}

class _PinballScreenState extends State<PinballScreen> with SingleTickerProviderStateMixin {
  PinballTable? _table;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _carry = 0;
  String _message = 'Spiel starten: 3 Kugeln für $pinballGameCost Münzen';
  int _lastScore = 0;
  int _paid = 0;

  static const _dt = 1 / 120;

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (_table != null && !_table!.gameOver) return;
    if (!_app.wallet.spend(pinballGameCost)) {
      _app.wallet.refillIfBroke();
      setState(() => _message = 'Münzen reichen nicht für ein Spiel');
      return;
    }
    setState(() {
      _table = PinballTable(rng: widget.seed == null ? null : math.Random(widget.seed));
      _message = 'Leertaste oder Abschuss gedrückt halten und loslassen';
      _paid = 0;
    });
    _app.sfx.play(Sound.card);
    _focus.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final t = _table;
    final delta = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (t == null) return;
    _carry += math.min(delta, 0.05);
    var steps = 0;
    while (_carry >= _dt && steps < 12) {
      _carry -= _dt;
      steps++;
      t.step(_dt);
    }
    _handleEvents(t);
    _frame.value++;
  }

  void _handleEvents(PinballTable t) {
    if (t.events.isEmpty) return;
    String? text;
    for (final e in t.events) {
      switch (e.kind) {
        case PinballEventKind.bumper:
          _app.sfx.play(Sound.chip);
        case PinballEventKind.sling:
          _app.sfx.play(Sound.tick);
        case PinballEventKind.lane:
          _app.sfx.play(Sound.coin);
        case PinballEventKind.laneBonus:
          text = 'Alle Gassen! +${formatCoins(e.points)}, Multiplikator ×${t.multiplier}';
          _app.sfx.play(Sound.win);
        case PinballEventKind.launch:
          text = '';
        case PinballEventKind.saved:
          text = 'Ballrettung! Die Kugel kommt zurück';
          _app.sfx.play(Sound.coin);
        case PinballEventKind.drain:
          text = t.ballsLeft > 0 ? 'Kugel verloren. Noch ${t.ballsLeft}' : '';
          _app.sfx.play(Sound.lose);
        case PinballEventKind.nudge:
          break;
        case PinballEventKind.gameOver:
          _finish(t);
      }
    }
    t.events.clear();
    if (text != null && !t.gameOver) setState(() => _message = text!);
  }

  void _finish(PinballTable t) {
    _lastScore = t.score;
    _paid = pinballPayout(t.score);
    if (_paid > 0) _app.wallet.credit(_paid);
    final best = _app.settings.pinballHigh;
    final record = t.score > best;
    if (record) _app.settings.pinballHigh = t.score;
    _app.sfx.play(_paid > pinballGameCost ? Sound.bigWin : Sound.coin);
    setState(() {
      _message = 'Spiel vorbei: ${formatCoins(t.score)} Punkte, +${formatCoins(_paid)} Münzen'
          '${record ? '. Neuer Rekord!' : ''}';
    });
  }

  // ---------- Eingaben ----------

  static final _leftKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyY,
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.controlLeft,
  };
  static final _rightKeys = {
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.keyL,
    LogicalKeyboardKey.keyM,
    LogicalKeyboardKey.minus,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.controlRight,
  };
  static final _launchKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final down = e is KeyDownEvent || e is KeyRepeatEvent;
    final up = e is KeyUpEvent;
    final k = e.logicalKey;
    final t = _table;
    if (_launchKeys.contains(k) && (t == null || t.gameOver)) {
      if (e is KeyDownEvent) _start();
      return KeyEventResult.handled;
    }
    if (t == null) return KeyEventResult.ignored;
    if (_leftKeys.contains(k)) {
      _flip(left: true, down: down && !up);
      return KeyEventResult.handled;
    }
    if (_rightKeys.contains(k)) {
      _flip(left: false, down: down && !up);
      return KeyEventResult.handled;
    }
    if (_launchKeys.contains(k)) {
      _plunger(down && !up);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyT && e is KeyDownEvent) {
      t.nudge();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _flip({required bool left, required bool down}) {
    final t = _table;
    if (t == null) return;
    final was = left ? t.leftPressed : t.rightPressed;
    if (left) {
      t.leftPressed = down;
    } else {
      t.rightPressed = down;
    }
    if (down && !was) _app.sfx.play(Sound.tick);
  }

  void _plunger(bool down) {
    final t = _table;
    if (t == null || t.gameOver) return;
    if (down) {
      if (t.ballInLane) t.charging = true;
    } else if (t.charging) {
      t.launch();
      _app.sfx.play(Sound.chip);
    }
  }

  // ---------- Anzeige ----------

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Neon Flipper',
      guide: pinballGuide,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0620), Color(0xFF1A0B33), Color(0xFF07040F)],
        ),
      ),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: LayoutBuilder(builder: (context, box) => _layout(box)),
        ),
      ),
    );
  }

  Widget _layout(BoxConstraints box) {
    final wide = box.maxWidth > box.maxHeight * 0.9;
    final controlsH = wide ? 0.0 : 150.0;
    final sideW = wide ? math.min(300.0, box.maxWidth * 0.36) : 0.0;
    final view = LayoutBuilder(
      builder: (context, b) {
        final scale = math.min((b.maxWidth - 10) / PinballTable.width, (b.maxHeight - 6) / PinballTable.height);
        return Center(
          child: SizedBox(
            width: scale * PinballTable.width,
            height: scale * PinballTable.height,
            child: RepaintBoundary(
              child: CustomPaint(painter: _TablePainter(() => _table, _frame)),
            ),
          ),
        );
      },
    );
    final info = ValueListenableBuilder<int>(
      valueListenable: _frame,
      builder: (context, _, __) {
        final t = _table;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatCoins(t?.score ?? _lastScore),
              style: const TextStyle(color: Color(0xFFFF5EA8), fontSize: 34, fontWeight: FontWeight.w800),
            ),
            Text(
              t == null || t.gameOver
                  ? 'Rekord ${formatCoins(_app.settings.pinballHigh)}'
                  : 'Kugel ${t.ballNumber} von ${PinballTable.ballsPerGame} · ×${t.multiplier}'
                      '${t.ballSaveActive ? ' · Rettung aktiv' : ''}',
              style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 14),
            ),
          ],
        );
      },
    );
    final idle = _table == null || _table!.gameOver;
    final status = ResultBanner(text: _message, highlight: _paid > pinballGameCost, maxLines: 2);
    final startButton = ActionButton(
      primary: true,
      label: _table == null ? 'Spiel starten (−$pinballGameCost)' : 'Nochmal (−$pinballGameCost)',
      onPressed: _start,
    );
    final keysHelp = Text(
      'Tastatur: Links A, Y oder Shift links, Rechts L, M oder Shift rechts, Abschuss Leertaste halten, Rütteln T',
      textAlign: TextAlign.center,
      style: TextStyle(color: const Color(0xFFF6E7C8).withValues(alpha: 0.7), fontSize: 12),
    );
    if (wide) {
      return Row(
        children: [
          Expanded(child: view),
          SizedBox(
            width: sideW,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  info,
                  const SizedBox(height: 8),
                  status,
                  const SizedBox(height: 8),
                  if (idle) startButton else _touchControls(compact: true),
                  const SizedBox(height: 10),
                  keysHelp,
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(top: 4), child: info),
        Expanded(child: view),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: status),
        SizedBox(
          height: controlsH - 50,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: idle ? Center(child: startButton) : _touchControls(),
          ),
        ),
      ],
    );
  }

  Widget _touchButton(String label, IconData icon, void Function(bool) onChange, {double flex = 1}) {
    return Expanded(
      flex: (flex * 10).round(),
      child: Listener(
        onPointerDown: (_) => onChange(true),
        onPointerUp: (_) => onChange(false),
        onPointerCancel: (_) => onChange(false),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0x3363E6FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xAA63E6FF), width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _touchControls({bool compact = false}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _touchButton('Links', Icons.arrow_back, (d) => _flip(left: true, down: d), flex: 1.5),
        _touchButton('Abschuss', Icons.arrow_downward, _plunger),
        _touchButton('Rechts', Icons.arrow_forward, (d) => _flip(left: false, down: d), flex: 1.5),
      ],
    );
    return compact ? SizedBox(height: 110, child: row) : row;
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.table, Listenable repaint) : super(repaint: repaint);
  final PinballTable? Function() table;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / PinballTable.width;
    canvas.save();
    canvas.scale(s);
    final field = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, PinballTable.width, PinballTable.height),
      const Radius.circular(0.4),
    );
    canvas.drawRRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF241047), Color(0xFF3A0F55), Color(0xFF120726)],
        ).createShader(const Rect.fromLTWH(0, 0, PinballTable.width, PinballTable.height)),
    );
    final t = table() ?? _demo;
    final neon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF63E6FF);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.28
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x3363E6FF);
    for (final w in t.walls) {
      final path = Path()..moveTo(w.first.x, w.first.y);
      for (final p in w.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, neon);
    }
    // Gassenlichter
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(PinballTable.laneX[i], 3.25),
        0.18,
        Paint()..color = t.lanes[i] ? const Color(0xFFFFC95C) : const Color(0x55FFC95C),
      );
    }
    for (final b in t.bumpers) {
      final c = Offset(b.x, b.y);
      canvas.drawCircle(c, 0.5 + 0.12 * b.glow, Paint()..color = Color.lerp(const Color(0x66FF5EA8), const Color(0xCCFF5EA8), b.glow)!);
      canvas.drawCircle(c, 0.42, Paint()..color = const Color(0xFF2A0B3D));
      canvas.drawCircle(
        c,
        0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08
          ..color = const Color(0xFFFF5EA8),
      );
      canvas.drawCircle(c, 0.16, Paint()..color = Color.lerp(const Color(0xFFFF5EA8), Colors.white, b.glow)!);
    }
    for (final sl in t.slings) {
      final p = Path()
        ..moveTo(sl.a.x, sl.a.y)
        ..lineTo(sl.b.x, sl.b.y)
        ..lineTo(sl.c.x, sl.c.y)
        ..close();
      canvas.drawPath(p, Paint()..color = Color.lerp(const Color(0x5534E89E), const Color(0xCC34E89E), sl.glow)!);
    }
    _flipper(canvas, PinballTable.leftPivot, t.leftAngle, 1);
    _flipper(canvas, PinballTable.rightPivot, t.rightAngle, -1);
    // Feder in der Bahn
    final springTop = 17.7 + 0.5 * t.charge;
    canvas.drawRect(
      Rect.fromLTRB(9.35, springTop, 9.85, 18.0),
      Paint()..color = Color.lerp(const Color(0xFF8A8A9A), const Color(0xFFFF5EA8), t.charge)!,
    );
    final ball = t.ball;
    if (ball != null) {
      final c = Offset(ball.x, ball.y);
      canvas.drawCircle(
        c,
        PinballTable.ballRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: const [Colors.white, Color(0xFFB8C2D6), Color(0xFF5A6478)],
          ).createShader(Rect.fromCircle(center: c, radius: PinballTable.ballRadius)),
      );
    }
    canvas.restore();
  }

  void _flipper(Canvas canvas, Pt pivot, double angle, int dir) {
    canvas.save();
    canvas.translate(pivot.x, pivot.y);
    canvas.rotate(angle);
    final l = PinballTable.flipperLength * dir;
    final path = Path()
      ..moveTo(0, -0.2)
      ..lineTo(l, -0.07)
      ..lineTo(l, 0.07)
      ..lineTo(0, 0.2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC95C));
    canvas.drawCircle(Offset.zero, 0.2, Paint()..color = const Color(0xFFFFE9A8));
    canvas.restore();
  }

  static final PinballTable _demo = PinballTable(rng: math.Random(1));

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}
