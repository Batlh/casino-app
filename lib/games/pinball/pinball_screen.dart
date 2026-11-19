import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/progress.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import 'pinball_art.dart';
import 'pinball_table.dart';
import 'pinball_tables.dart';

/// Ein Spiel mit drei Kugeln kostet so viel, ausgezahlt wird nach Punkten.
const pinballGameCost = 20;
const pinballPointsPerCoin = 100;

/// Höchstens so viele Münzen gibt ein einzelnes Spiel.
const pinballMaxPayout = 400;

int pinballPayout(int score) => math.min(pinballMaxPayout, score ~/ pinballPointsPerCoin);

class PinballScreen extends StatefulWidget {
  const PinballScreen({super.key, this.seed});
  final int? seed;

  @override
  State<PinballScreen> createState() => _PinballScreenState();
}

/// Laufschrift-Meldung auf der Anzeige.
class _DmdMessage {
  _DmdMessage(this.big, this.small, this.seconds, {this.blink = false});
  final String big;
  final String small;
  double seconds;
  final bool blink;
}

class _PinballScreenState extends State<PinballScreen> with SingleTickerProviderStateMixin {
  PinballTable? _table;
  TableSpec _spec = neonNightTable;
  bool _choosing = false;
  final _frame = ValueNotifier<int>(0);
  final _focus = FocusNode();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _carry = 0;
  double _time = 0;
  String _message = 'Spiel starten: 3 Kugeln für $pinballGameCost Münzen';
  int _lastScore = 0;
  int _paid = 0;
  final List<_DmdMessage> _dmd = [];
  final List<Spark> _sparks = [];
  final _rng = math.Random();

  static const _dt = 1 / 120;

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final saved = _app.settings.loadGame('pinball')?['table'];
    for (final t in pinballTables) {
      if (t.id == saved) _spec = t;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _high(TableSpec t) {
    if (t.id == 'neon') return _app.settings.pinballHigh;
    final m = _app.settings.loadGame('pinball')?['high'];
    return m is Map ? (m[t.id] as int? ?? 0) : 0;
  }

  void _setHigh(TableSpec t, int v) {
    if (t.id == 'neon') {
      _app.settings.pinballHigh = v;
      return;
    }
    final data = Map<String, dynamic>.from(_app.settings.loadGame('pinball') ?? {});
    final high = Map<String, dynamic>.from((data['high'] as Map?) ?? {});
    high[t.id] = v;
    data['high'] = high;
    _app.settings.saveGame('pinball', data);
  }

  void _choose(TableSpec t) {
    final data = Map<String, dynamic>.from(_app.settings.loadGame('pinball') ?? {});
    data['table'] = t.id;
    _app.settings.saveGame('pinball', data);
    setState(() {
      _spec = t;
      _choosing = false;
      _table = null;
      _paid = 0;
      _lastScore = 0;
      _message = '${t.name}: ${t.blurb}';
    });
    _focus.requestFocus();
  }

  void _start() {
    if (_table != null && !_table!.gameOver) return;
    if (!_app.wallet.spend(pinballGameCost)) {
      _app.wallet.refillIfBroke(min: pinballGameCost);
      setState(() => _message = 'Münzen reichen nicht für ein Spiel');
      return;
    }
    setState(() {
      _table = PinballTable(rng: widget.seed == null ? null : math.Random(widget.seed), spec: _spec);
      _message = 'Leertaste oder Abschuss gedrückt halten und loslassen';
      _paid = 0;
      _dmd
        ..clear()
        ..add(_DmdMessage(_spec.name.toUpperCase(), 'Kugel 1', 2.5));
    });
    _app.sfx.play(Sound.card);
    _focus.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final t = _table;
    final delta = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final d = math.min(delta, 0.05);
    _time += d;
    for (final m in _dmd) {
      m.seconds -= d;
    }
    _dmd.removeWhere((m) => m.seconds <= 0);
    for (final s in _sparks) {
      s.life -= d;
      s.x += s.vx * d;
      s.y += s.vy * d;
      s.vy += 6 * d;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    if (t != null) {
      _carry += d;
      var steps = 0;
      while (_carry >= _dt && steps < 12) {
        _carry -= _dt;
        steps++;
        t.step(_dt);
      }
      _handleEvents(t);
    }
    _frame.value++;
  }

  void _burst(double x, double y, Color color, [int n = 8]) {
    if (_sparks.length > 160) return;
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * math.pi;
      final v = 1.5 + _rng.nextDouble() * 3;
      _sparks.add(Spark(x, y, math.cos(a) * v, math.sin(a) * v - 1, color));
    }
  }

  void _say(String big, [String small = '', double seconds = 2.2, bool blink = false]) {
    _dmd.add(_DmdMessage(big, small, seconds, blink: blink));
    if (_dmd.length > 4) _dmd.removeAt(0);
  }

  void _handleEvents(PinballTable t) {
    if (t.events.isEmpty) return;
    String? text;
    final th = _spec.theme;
    for (final e in t.events) {
      switch (e.kind) {
        case PinballEventKind.bumper:
          _app.sfx.play(Sound.chip);
          _burst(e.x, e.y, th.bumper);
        case PinballEventKind.sling:
          _app.sfx.play(Sound.tick);
          _burst(e.x, e.y, th.sling, 5);
        case PinballEventKind.lane:
          _app.sfx.play(Sound.coin);
        case PinballEventKind.laneBonus:
          text = 'Alle Gassen! +${formatCoins(e.points)}, Multiplikator ×${t.multiplier}';
          _say('GASSEN', '×${t.multiplier}');
          _app.sfx.play(Sound.win);
        case PinballEventKind.drop:
          _app.sfx.play(Sound.chip);
          _burst(e.x, e.y, th.accent, 6);
        case PinballEventKind.dropBank:
          _say('FALLZIELE', '+${formatCoins(e.points)}');
          _app.sfx.play(Sound.win);
        case PinballEventKind.target:
          _app.sfx.play(Sound.tick);
          _burst(e.x, e.y, th.light, 5);
        case PinballEventKind.targetBank:
          _say('ZIELBANK', '+${formatCoins(e.points)}');
          _app.sfx.play(Sound.win);
        case PinballEventKind.spinner:
          _app.sfx.play(Sound.tick);
        case PinballEventKind.saucer:
          _app.sfx.play(Sound.chip);
          _burst(e.x, e.y, th.accent, 10);
        case PinballEventKind.lock:
          _say('KUGEL GEFANGEN', '${e.text} von ${_spec.locksForMultiball}', 2.2, true);
          _app.sfx.play(Sound.win);
        case PinballEventKind.ramp:
          _say(e.text.isEmpty ? 'RAMPE' : e.text.toUpperCase(), '+${formatCoins(e.points)}');
          _app.sfx.play(Sound.coin);
          _burst(e.x, e.y, th.ramp, 12);
        case PinballEventKind.multiball:
          text = 'Multiball! Rampen geben jetzt den Jackpot';
          _say('MULTIBALL', 'Rampen = Jackpot', 3, true);
          _app.sfx.play(Sound.bigWin);
        case PinballEventKind.multiballEnd:
          _say('MULTIBALL VORBEI', '', 1.6);
        case PinballEventKind.jackpot:
          text = 'Jackpot! +${formatCoins(e.points)}';
          _say('JACKPOT', '+${formatCoins(e.points)}', 2.6, true);
          _app.sfx.play(Sound.bigWin);
          _burst(e.x, e.y, th.accent, 24);
        case PinballEventKind.mission:
          text = 'Mission erfüllt: ${e.text} (+${formatCoins(e.points)})';
          _say('MISSION ERFÜLLT', e.text, 2.8, true);
          _app.sfx.play(Sound.win);
        case PinballEventKind.missionsDone:
          _say('ALLE MISSIONEN', 'Neue Runde, doppelte Punkte', 3, true);
        case PinballEventKind.extraBall:
          text = 'Extra-Kugel!';
          _say('EXTRA-KUGEL', '', 2.4, true);
          _app.sfx.play(Sound.bigWin);
        case PinballEventKind.launch:
          text = '';
        case PinballEventKind.saved:
          text = 'Ballrettung! Die Kugel kommt zurück';
          _say('BALLRETTUNG', '', 2);
          _app.sfx.play(Sound.coin);
        case PinballEventKind.drain:
          text = t.ballsLeft > 0 ? 'Kugel verloren. Noch ${t.ballsLeft}' : '';
          if (t.ballsLeft > 0) _say('KUGEL VERLOREN', 'Noch ${t.ballsLeft}', 2);
          _app.sfx.play(Sound.lose);
        case PinballEventKind.nudge:
          break;
        case PinballEventKind.kickback:
          text = 'Rückschuss! Die Kugel ist wieder im Spiel';
          _say('RÜCKSCHUSS', '', 1.8);
          _app.sfx.play(Sound.coin);
          _burst(e.x, e.y, th.light, 12);
        case PinballEventKind.kickbackLit:
          _say('RÜCKSCHUSS BEREIT', '', 1.8);
          _app.sfx.play(Sound.win);
        case PinballEventKind.gateOpen:
          text = 'Das Tor ist offen!';
          _say('TOR OFFEN', '+${formatCoins(e.points)}', 2.2, true);
          _app.sfx.play(Sound.win);
          _burst(e.x, e.y, th.accent, 14);
        case PinballEventKind.gateClosed:
          _say('TOR ZU', '', 1.4);
        case PinballEventKind.captive:
          _app.sfx.play(Sound.chip);
          _burst(e.x, e.y, th.light, 8);
        case PinballEventKind.captiveBonus:
          text = '${e.text.isEmpty ? 'Volltreffer' : e.text}! +${formatCoins(e.points)}';
          _say(e.text.isEmpty ? 'VOLLTREFFER' : e.text.toUpperCase(), '+${formatCoins(e.points)}', 2.6, true);
          _app.sfx.play(Sound.bigWin);
          _burst(e.x, e.y, th.accent, 20);
        case PinballEventKind.wheel:
          text = 'Glücksrad: ${e.text}';
          _say('GLÜCKSRAD', e.text, 2.6, true);
          _app.sfx.play(Sound.win);
          _burst(e.x, e.y, th.accent, 16);
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
    if (t.score >= 1000000) progress.event('flipper_million');
    final best = _high(_spec);
    final record = t.score > best;
    if (record) _setHigh(_spec, t.score);
    _app.sfx.play(_paid > pinballGameCost ? Sound.bigWin : Sound.coin);
    _say(record ? 'NEUER REKORD' : 'SPIEL VORBEI', formatCoins(t.score), 6, record);
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
    if (_choosing) return KeyEventResult.ignored;
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
    final th = _spec.theme;
    return GameFrame(
      minStake: pinballGameCost,
      title: _choosing ? 'Flipper: Tisch wählen' : _spec.name,
      guide: pinballGuide,
      background: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(th.top, Colors.black, 0.35)!, Color.lerp(th.mid, Colors.black, 0.45)!, Color.lerp(th.bottom, Colors.black, 0.3)!],
        ),
      ),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: _choosing ? _chooser() : LayoutBuilder(builder: (context, box) => _layout(box)),
        ),
      ),
    );
  }

  Widget _chooser() {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = math.max(2, math.min(6, (box.maxWidth / 190).floor()));
        return GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
          children: [
            for (final t in pinballTables)
              GestureDetector(
                onTap: () => _choose(t),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t == _spec ? t.theme.accent : t.theme.wall.withValues(alpha: 0.5), width: 2),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: PinballTable.width / PinballTable.height,
                          child: CustomPaint(painter: TablePainter.preview(t)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(t.name, style: TextStyle(color: t.theme.accent, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(
                        'Rekord ${formatCoins(_high(t))}',
                        style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 12),
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

  Widget _layout(BoxConstraints box) {
    final wide = box.maxWidth > box.maxHeight * 0.9;
    final sideW = wide ? math.min(320.0, box.maxWidth * 0.38) : 0.0;
    final view = LayoutBuilder(
      builder: (context, b) {
        final scale = math.min((b.maxWidth - 10) / PinballTable.width, (b.maxHeight - 6) / PinballTable.height);
        return Center(
          child: SizedBox(
            width: scale * PinballTable.width,
            height: scale * PinballTable.height,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: TablePainter(() => _table, () => _spec, () => _time, () => _sparks, _frame),
              ),
            ),
          ),
        );
      },
    );
    final dmd = SizedBox(
      height: wide ? 96 : 70,
      child: RepaintBoundary(
        child: CustomPaint(painter: DmdPainter(_dmdState, _frame), size: Size.infinite),
      ),
    );
    final idle = _table == null || _table!.gameOver;
    final status = ResultBanner(text: _message, highlight: _paid > pinballGameCost, maxLines: 2);
    final startButton = Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        ActionButton(
          primary: true,
          label: _table == null ? 'Spiel starten (−$pinballGameCost)' : 'Nochmal (−$pinballGameCost)',
          onPressed: _start,
        ),
        ActionButton(label: 'Tisch wechseln', onPressed: () => setState(() => _choosing = true)),
      ],
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
                  dmd,
                  const SizedBox(height: 8),
                  _missionCard(),
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
        Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 2), child: dmd),
        Expanded(child: view),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: status),
        SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: idle ? Center(child: startButton) : _touchControls(),
          ),
        ),
      ],
    );
  }

  /// Was die Laufschrift gerade zeigt.
  DmdState _dmdState() {
    final t = _table;
    if (_dmd.isNotEmpty) {
      final m = _dmd.first;
      return DmdState(m.big, m.small, _spec.theme.dmd, blink: m.blink, time: _time);
    }
    if (t == null || t.gameOver) {
      final score = t?.score ?? _lastScore;
      return DmdState(
        score > 0 ? formatCoins(score) : _spec.name.toUpperCase(),
        'Rekord ${formatCoins(_high(_spec))} · Münze rein und los',
        _spec.theme.dmd,
        scroll: true,
        time: _time,
      );
    }
    final m = t.mission;
    final status = t.multiball
        ? 'MULTIBALL · Rampen = Jackpot'
        : m == null
            ? 'Kugel ${t.ballNumber}'
            : '${m.title} ${t.missionProgress}/${m.count}';
    return DmdState(formatCoins(t.score), status, _spec.theme.dmd, time: _time, scroll: status.length > 26);
  }

  Widget _missionCard() {
    return ValueListenableBuilder<int>(
      valueListenable: _frame,
      builder: (context, _, __) {
        final t = _table;
        final th = _spec.theme;
        final idx = t?.missionIndex ?? 0;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: th.wall.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t == null || t.gameOver
                    ? 'Missionen'
                    : 'Kugel ${t.ballNumber} · ×${t.multiplier}${t.locks > 0 ? ' · ${t.locks} gefangen' : ''}'
                        '${t.ballSaveActive ? ' · Rettung' : ''}',
                style: TextStyle(color: th.accent, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < _spec.missions.length; i++)
                Text(
                  '${i < idx % math.max(1, _spec.missions.length) ? '✓' : i == idx % _spec.missions.length && t != null && !t.gameOver ? '▶' : '·'} '
                  '${_spec.missions[i].title}',
                  style: TextStyle(
                    color: i == idx % _spec.missions.length && t != null && !t.gameOver
                        ? th.light
                        : const Color(0xFFF6E7C8).withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _touchButton(String label, IconData icon, void Function(bool) onChange, {double flex = 1}) {
    final th = _spec.theme;
    return Expanded(
      flex: (flex * 10).round(),
      child: Listener(
        onPointerDown: (_) => onChange(true),
        onPointerUp: (_) => onChange(false),
        onPointerCancel: (_) => onChange(false),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: th.wall.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: th.wall.withValues(alpha: 0.7), width: 2),
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
