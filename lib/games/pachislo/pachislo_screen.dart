import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/debug_log.dart';
import '../../core/progress.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../lose/lose_art.dart';
import '../slots/art_kit.dart';
import '../slots/frucht_art.dart';
import 'pachislo_engine.dart';

const pachisloGuide = GameGuide('Pachislo', [
  GuideSection(
    'So geht es',
    'Hebel ziehen: Das Spiel kostet drei Münzen mal Münzwert, alle drei Walzen laufen los. Du stoppst jede Walze mit '
        'ihrer Taste, in beliebiger Reihenfolge. Gewertet wird nur die Mittellinie.',
  ),
  GuideSection(
    'Die Auslosung',
    'Beim Hebelziehen lost der Automat aus, was in diesem Spiel möglich ist. Nach dem Drücken rutscht eine Walze höchstens '
        'vier Felder weiter: Ist ein Gewinn ausgelost und liegt er in Reichweite, rückt sie ihn in die Mitte. Was nicht '
        'ausgelost ist, kommt nie. Pflaume, Replay und Kirsche liegen so dicht, dass sie immer klappen, egal wann du drückst.',
  ),
  GuideSection(
    'Gewinne (mal Münzwert)',
    'Pflaume-Pflaume-Pflaume: 7. Kirsche in der Mitte von Walze 1: 2. Glocke-Glocke-Glocke: 14, die Glocke muss man treffen. '
        'Replay-Replay-Replay: Das nächste Spiel ist gratis.',
  ),
  GuideSection(
    'Bonus und Glückslampe',
    'Ist ein Bonus ausgelost, leuchtet die Glückslampe. Sie bleibt an, bis du ihn ausrichtest. Dafür musst du die Sieben '
        'treffen: Drücke, kurz bevor sie in die Mitte kommt (bis zu vier Felder vorher). Sieben-Sieben-Sieben startet den BIG '
        'mit $psBigGames Spielen, Sieben-Sieben-Balken den REG mit $psRegGames Spielen. Im Bonus zahlt jede Pflaume $psBonusPay. '
        'Solange die Lampe leuchtet, gibt es keine anderen Gewinne, und der Münzwert bleibt fest.',
  ),
  GuideSection(
    'Zielen lohnt sich',
    'Wer Sieben und Glocke trifft, holt auf lange Sicht etwa 99 % der Einsätze zurück, wer blind drückt etwa 91 %. Mit '
        '„Langsam“ laufen die Walzen halb so schnell.',
  ),
]);

const _coins = [1, 2, 5, 10, 20];

class PachisloScreen extends StatefulWidget {
  const PachisloScreen({super.key, this.seed});
  final int? seed;

  @override
  State<PachisloScreen> createState() => _PachisloScreenState();
}

class _PachisloScreenState extends State<PachisloScreen> with SingleTickerProviderStateMixin {
  late final PachisloMachine _m = PachisloMachine(rng: widget.seed == null ? null : math.Random(widget.seed));
  late final math.Random _rng = widget.seed == null ? math.Random() : math.Random(widget.seed! + 1);
  late final Ticker _ticker = createTicker(_tick);

  /// Walzenstellung in Feldern (wächst beim Laufen), Ziel nach dem Stoppen.
  final List<double> _pos = [0, 7, 14];
  final List<double?> _target = [null, null, null];
  final List<bool> _spinning = [false, false, false];
  Duration _last = Duration.zero;

  int _coin = 1;
  bool _slow = false;
  bool _autoStop = false;
  String _message = 'Hebel ziehen';
  bool _big = false;
  int _lastWin = 0;
  bool _loaded = false;

  AppScope get _app => AppScope.of(context);
  int get _cost => psBet * _coin;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = _app.settings.loadGame('pachislo') ?? const {};
    _slow = s['slow'] == true;
    _coin = _coins.contains(s['coin']) ? s['coin'] as int : 1;
    PsFlag? flagOf(Object? v) => PsFlag.values.where((f) => f.name == v).firstOrNull;
    _m.held = flagOf(s['held']);
    _m.bonus = flagOf(s['bonus']);
    _m.bonusLeft = (s['left'] as num?)?.toInt() ?? 0;
    _m.freeGame = s['free'] == true;
    if (_m.bonus != null) _message = '${_m.bonus == PsFlag.big ? 'BIG' : 'REG'}: noch ${_m.bonusLeft} Spiele';
    if (_m.held != null) _message = 'Die Glückslampe leuchtet! Triff die Sieben.';
  }

  void _save() => _app.settings.saveGame('pachislo', {
        'slow': _slow,
        'coin': _coin,
        'held': _m.held?.name,
        'bonus': _m.bonus?.name,
        'left': _m.bonusLeft,
        'free': _m.freeGame,
      });

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Münzwert ist fest, solange Lampe, Bonus oder Replay laufen.
  bool get _coinLocked => _m.held != null || _m.bonus != null || _m.freeGame || _m.running;

  double get _speed => (_slow ? 8.0 : 16.0); // Felder je Sekunde

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    var any = false;
    for (var r = 0; r < 3; r++) {
      final t = _target[r];
      if (t != null) {
        _pos[r] = math.min(t, _pos[r] + dt * _speed * 0.8);
        if (_pos[r] >= t) {
          _target[r] = null;
          _spinning[r] = false;
          _app.sfx.play(Sound.reelStop);
          if (_m.allStopped && !_spinning.contains(true)) _finish();
        } else {
          any = true;
        }
      } else if (_spinning[r]) {
        _pos[r] += dt * _speed;
        any = true;
      }
    }
    if (!any) _ticker.stop();
    setState(() {});
  }

  void _pull() {
    if (_m.running) return;
    final free = _m.freeGame;
    if (!free && !_app.wallet.spend(_cost)) {
      setState(() => _message = 'Zu wenig Münzen');
      return;
    }
    if (!free) progress.event('pachislo');
    _m.start();
    debugLog.info('pachislo', 'Auslosung ${_m.flag.name}${free ? ' (Replay)' : ''}');
    _app.sfx.play(Sound.coin);
    for (var r = 0; r < 3; r++) {
      _spinning[r] = true;
      _target[r] = null;
    }
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    setState(() {
      _big = false;
      _lastWin = 0;
      _message = _m.bonus != null
          ? '${_m.bonus == PsFlag.big ? 'BIG' : 'REG'}: noch ${_m.bonusLeft} Spiele'
          : (_m.lamp ? 'Die Glückslampe leuchtet! Triff die Sieben.' : (free ? 'Replay: dieses Spiel ist gratis' : 'Walzen stoppen'));
    });
    if (_autoStop) _autoStops();
  }

  Future<void> _autoStops() async {
    for (final r in [0, 1, 2]) {
      await Future<void>.delayed(Duration(milliseconds: 350 + _rng.nextInt(450)));
      if (!mounted || !_m.running) return;
      if (_m.stops[r] == null) _stop(r);
    }
  }

  void _stop(int reel) {
    if (!_m.running || _m.stops[reel] != null || !_spinning[reel]) return;
    final x = _pos[reel];
    final press = x.ceil() % psLength;
    final s = _m.stop(reel, press);
    final d = (s - press) % psLength;
    _target[reel] = x.ceil() + d.toDouble();
    setState(() {});
  }

  void _finish() {
    final r = _m.finish();
    final paid = r.paid * _coin;
    if (paid > 0) _app.wallet.credit(paid);
    debugLog.info('pachislo', 'Rolle ${r.role.name}, Auszahlung $paid');
    String msg;
    if (r.bonusStarted != null) {
      msg = r.bonusStarted == PsFlag.big ? 'BIG BONUS! $psBigGames Spiele' : 'REG BONUS! $psRegGames Spiele';
      _app.sfx.play(Sound.bigWin);
      progress.event(r.bonusStarted == PsFlag.big ? 'pachislo_big' : 'pachislo_reg');
      _big = true;
    } else if (r.replay) {
      msg = 'Replay! Das nächste Spiel ist gratis';
      _app.sfx.play(Sound.chip);
    } else if (paid > 0) {
      msg = '${psSymbolNames[_roleSymbol(r.role)]}: +${formatCoins(paid)}';
      if (_m.bonus != null) msg += ' · noch ${_m.bonusLeft}';
      _app.sfx.play(Sound.win);
    } else if (_m.held != null) {
      msg = 'Die Glückslampe leuchtet! Triff die Sieben.';
    } else if (r.missed && r.flag == PsFlag.bell) {
      msg = 'Glocke verpasst';
    } else {
      msg = 'Nichts';
    }
    if (r.flag == PsFlag.plum && _m.bonus == null && r.paid == psBonusPay) {
      msg = 'Bonus vorbei: +${formatCoins(paid)}';
    }
    _lastWin = paid;
    _save();
    _app.wallet.refillIfBroke(min: psBet);
    setState(() => _message = msg);
  }

  static int _roleSymbol(PsFlag f) => switch (f) {
        PsFlag.plum => psPlum,
        PsFlag.cherry => psCherry,
        PsFlag.bell => psBell,
        PsFlag.replay => psReplay,
        _ => psSeven,
      };

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFF1D6);
    final running = _m.running;
    return GameFrame(
      title: 'Pachislo',
      guide: pachisloGuide,
      minStake: psBet,
      background: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B0B2E), Color(0xFF0B0414)])),
      child: LayoutBuilder(builder: (context, box) {
        final reelW = math.min(130.0, (box.maxWidth - 64) / 3);
        final cell = reelW * 0.8;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _Panel(lamp: _m.lamp, bonus: _m.bonus, left: _m.bonusLeft, free: _m.freeGame, win: _lastWin),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFB0BEC5), Color(0xFF546E7A), Color(0xFFB0BEC5)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
                ),
                child: Stack(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var r = 0; r < 3; r++)
                          Container(
                            width: reelW,
                            height: cell * 3,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFFFBF0), borderRadius: BorderRadius.circular(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CustomPaint(painter: _ReelPainter(reel: r, pos: _pos[r], cell: cell)),
                            ),
                          ),
                      ],
                    ),
                    // Mittellinie
                    Positioned(
                      left: 0,
                      right: 0,
                      top: cell * 1.5 - 1.5,
                      child: IgnorePointer(child: Container(height: 3, color: const Color(0xCCE53935))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < 3; r++)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3 + (reelW - 64) / 2),
                      child: _StopButton(
                        active: running && _m.stops[r] == null,
                        onPressed: () => _stop(r),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ResultBanner(text: _message, highlight: _big, maxLines: 2),
              const SizedBox(height: 10),
              ActionButton(
                primary: true,
                label: running
                    ? 'Walzen laufen'
                    : (_m.freeGame ? 'Hebel: Replay gratis' : 'Hebel: ${formatCoins(_cost)}'),
                onPressed: running || (!_m.freeGame && !_app.wallet.canAfford(_cost)) ? null : _pull,
              ),
              const SizedBox(height: 10),
              Text('Münzwert (ein Spiel kostet das Dreifache)', style: TextStyle(color: ink.withValues(alpha: 0.8))),
              const SizedBox(height: 4),
              Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                for (final c in _coins)
                  ChoiceChip(
                    label: Text('$c'),
                    selected: _coin == c,
                    onSelected: _coinLocked
                        ? null
                        : (_) {
                            setState(() => _coin = c);
                            _save();
                          },
                  ),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                FilterChip(
                  label: const Text('Langsam'),
                  selected: _slow,
                  onSelected: (v) {
                    setState(() => _slow = v);
                    _save();
                  },
                ),
                FilterChip(
                  label: const Text('Automatisch stoppen'),
                  selected: _autoStop,
                  onSelected: (v) => setState(() => _autoStop = v),
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }
}

/// Anzeige oben: Glückslampe, Bonus, Replay, letzter Gewinn.
class _Panel extends StatelessWidget {
  const _Panel({required this.lamp, required this.bonus, required this.left, required this.free, required this.win});
  final bool lamp;
  final PsFlag? bonus;
  final int left;
  final bool free;
  final int win;

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF3A2A12);
    Widget box(String label, String value, {Color color = const Color(0xFFFF5252)}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF555555))),
          child: Column(children: [
            Text(label, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: lamp ? const [Color(0xFFFFFDE7), Color(0xFFFFC107), Color(0xFFFF6F00)] : const [Color(0xFF5D4A22), dim]),
            boxShadow: lamp ? const [BoxShadow(color: Color(0xAAFFC107), blurRadius: 24, spreadRadius: 4)] : const [],
            border: Border.all(color: const Color(0xFF8D6E63), width: 2),
          ),
          child: Text('GLÜCK', style: TextStyle(color: lamp ? const Color(0xFF7F2700) : const Color(0xFF8D7B5A), fontWeight: FontWeight.w900, fontSize: 12)),
        ),
        box('BONUS', bonus == null ? '–' : '${bonus == PsFlag.big ? 'BIG' : 'REG'} $left'),
        box('REPLAY', free ? 'JA' : '–', color: const Color(0xFF40C4FF)),
        box('GEWINN', win > 0 ? formatCoins(win) : '0', color: const Color(0xFFFFD54F)),
      ],
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.active, required this.onPressed});
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: active ? (_) => onPressed() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 64,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active ? const [Color(0xFFFF8A80), Color(0xFFC62828)] : const [Color(0xFF616161), Color(0xFF303030)],
          ),
          border: Border.all(color: Colors.black54, width: 2),
          boxShadow: active ? const [BoxShadow(color: Color(0x88FF5252), blurRadius: 10)] : const [],
        ),
        child: Text('STOPP', style: TextStyle(color: active ? Colors.white : const Color(0xFF9E9E9E), fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// Walze: Felder s, s + 1, s + 2 stehen unten, Mitte, oben; beim Laufen wandern die Symbole nach unten.
class _ReelPainter extends CustomPainter {
  _ReelPainter({required this.reel, required this.pos, required this.cell});
  final int reel;
  final double pos;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final s = pos.floor();
    final f = pos - s;
    final strip = psStrips[reel];
    for (var k = -1; k <= 3; k++) {
      final sym = strip[((s + 2 - k) % psLength + psLength) % psLength];
      final top = (k + f) * cell;
      paintPsSymbol(canvas, Rect.fromLTWH(0, top, size.width, cell).deflate(cell * 0.08), sym);
    }
    final shade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x66000000)],
        stops: [0, 0.25, 0.75, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shade);
  }

  @override
  bool shouldRepaint(_ReelPainter old) => old.pos != pos || old.cell != cell;
}

/// Symbole: Sieben, Balken, Glocke, Kirsche, Replay, Pflaume.
void paintPsSymbol(Canvas canvas, Rect rect, int symbol) {
  switch (symbol) {
    case psSeven:
      paintLosSymbol(canvas, rect, 'Sieben');
    case psBar:
      final r = squareIn(rect);
      final bar = RRect.fromRectAndRadius(Rect.fromCenter(center: r.center, width: r.width * 0.9, height: r.height * 0.42), Radius.circular(r.width * 0.08));
      canvas.drawRRect(bar, fillOf(const Color(0xFF212121)));
      canvas.drawRRect(bar.deflate(r.width * 0.04), strokeOf(const Color(0xFFFFD54F), 2));
      caption(canvas, r, 'BAR', const Color(0xFFFFD54F), size: 0.3, y: 0.5);
    case psBell:
      paintLosSymbol(canvas, rect, 'Glocke');
    case psCherry:
      paintLosSymbol(canvas, rect, 'Kirsche');
    case psReplay:
      final r = squareIn(rect);
      final c = r.center;
      final w = r.width;
      canvas.drawArc(Rect.fromCircle(center: c, radius: w * 0.3), -math.pi * 0.9, math.pi * 1.6, false, strokeOf(const Color(0xFF1E88E5), w * 0.08));
      final tip = c + Offset(math.cos(math.pi * 0.7), math.sin(math.pi * 0.7)) * w * 0.3;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx - w * 0.1, tip.dy - w * 0.04)
          ..lineTo(tip.dx + w * 0.08, tip.dy - w * 0.1)
          ..lineTo(tip.dx + w * 0.02, tip.dy + w * 0.1)
          ..close(),
        fillOf(const Color(0xFF1E88E5)),
      );
      caption(canvas, r, 'REPLAY', const Color(0xFF0D47A1), size: 0.2, y: 0.5, shadow: Colors.white);
    case psPlum:
      paintFruchtSymbol(canvas, rect, 3);
  }
}
