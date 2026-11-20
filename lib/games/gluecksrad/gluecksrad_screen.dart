import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/progress.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';

/// Geldrad wie im Casino („Big Six“): 54 Felder. Setzen auf einen Wert; bleibt das Rad dort stehen,
/// zahlt das Feld den Wert mal Einsatz, der Einsatz kommt zurück. Joker zahlt 40:1.
const radFelder = <int, int>{1: 24, 2: 15, 5: 7, 10: 4, 20: 2, 40: 2};

/// Reihenfolge auf dem Rad: Werte möglichst verteilt.
final List<int> radReihe = () {
  final pool = [for (final e in radFelder.entries) for (var i = 0; i < e.value; i++) e.key];
  final out = <int>[];
  final rng = math.Random(54);
  while (pool.isNotEmpty) {
    final last = out.isEmpty ? -1 : out.last;
    final options = pool.where((v) => v != last).toList();
    final v = (options.isEmpty ? pool : options)[rng.nextInt((options.isEmpty ? pool : options).length)];
    pool.remove(v);
    out.add(v);
  }
  return out;
}();

const _farben = {1: Color(0xFFFFF8E7), 2: Color(0xFF64B5F6), 5: Color(0xFF81C784), 10: Color(0xFFBA68C8), 20: Color(0xFFFFB74D), 40: Color(0xFFE53935)};

const gluecksradGuide = GameGuide('Glücksrad', [
  GuideSection(
    'So geht es',
    'Setze mit Jetons auf einen oder mehrere Werte und dreh das Rad. Bleibt es auf deinem Wert stehen, bekommst du den Einsatz '
        'mal dem Wert dazu und den Einsatz zurück. Das Rad hat 54 Felder: 24 × 1, 15 × 2, 7 × 5, 4 × 10, 2 × 20 und 2 Joker, '
        'die 40:1 zahlen.',
  ),
  GuideSection('Quote', 'Auf 1 gehen 88,9 % zurück, auf 2 83,3 %, auf 10 81,5 %, auf 5 und 20 je 77,8 %, auf den Joker 75,9 %.'),
]);

class GluecksradScreen extends StatefulWidget {
  const GluecksradScreen({super.key, this.seed});
  final int? seed;

  @override
  State<GluecksradScreen> createState() => _GluecksradScreenState();
}

class _GluecksradScreenState extends State<GluecksradScreen> with SingleTickerProviderStateMixin, NetSharedTable {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  final Map<int, int> _bets = {};
  Map<int, int> _lastBets = {};
  int _chip = 10;
  double _from = 0;
  double _to = 0;
  int _result = -1;
  String _message = 'Jeton wählen und auf Werte setzen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);
  int get _total => _bets.values.fold(0, (a, b) => a + b);
  double get _angle => _from + (_to - _from) * Curves.easeOutCubic.transform(_turn.value);

  /// Drehgeschwindigkeit in Bogenmaß pro Sekunde (Ableitung von easeOutCubic: 3·(1−t)²).
  double get _speed {
    final ms = _turn.duration!.inMilliseconds;
    if (!_turn.isAnimating || ms == 0) return 0;
    final u = 1 - _turn.value;
    return (_to - _from).abs() * 3 * u * u / (ms / 1000);
  }

  /// Bewegungsunschärfe: Ab etwa einem halben Feld pro Bild würden die Felder flackern (Stroboskop-Effekt),
  /// darum verschwimmen sie dann zu einer Mischfarbe. Wichtig für Menschen, die auf Flackern empfindlich sind.
  double get _blur => ((_speed - 2) / 6).clamp(0.0, 0.92);

  @override
  void dispose() {
    _turn.dispose();
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'gluecksrad';
  @override
  String get sharedTitle => 'Glücksrad';
  int? _pending;

  @override
  void sharedResult(Object? outcome) {
    final i = (outcome as num?)?.toInt();
    if (i == null || i < 0 || i >= radReihe.length) return;
    if (_turn.isAnimating) {
      _pending = i;
      return;
    }
    _spinTo(i);
  }

  void _bet(int v) {
    if (_turn.isAnimating) return;
    if (!sharedWallet.canAfford(_total + _chip)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      _bets[v] = (_bets[v] ?? 0) + _chip;
      _result = -1;
      _message = 'Einsatz ${formatCoins(_total)}';
    });
    sharedStake(_total);
  }

  Future<void> _spin() async {
    if (_turn.isAnimating || sharedGuest) return;
    if (_bets.isEmpty && _lastBets.isNotEmpty && sharedWallet.canAfford(_lastBets.values.fold(0, (a, b) => a + b))) {
      _bets.addAll(_lastBets);
    }
    // Am Netztisch dreht der Gastgeber auch ohne eigenen Einsatz
    if (_bets.isEmpty && !sharedHost) return;
    if (!sharedWallet.canAfford(_total)) return;
    final index = _rng.nextInt(radReihe.length);
    sharedSend(index);
    await _spinTo(index);
  }

  Future<void> _spinTo(int index) async {
    if (_bets.isNotEmpty && !sharedWallet.spend(_total)) _bets.clear();
    final n = radReihe.length;
    final seg = 2 * math.pi / n;
    // Feld index unter den Zeiger oben drehen, mindestens drei volle Umdrehungen. Ist in den Systemeinstellungen
    // „Animationen reduzieren“ an, nur kurz und ohne volle Umdrehungen.
    final calm = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _turn.duration = Duration(milliseconds: calm ? 1200 : 5200);
    final base = _angle % (2 * math.pi);
    var target = -(index + 0.5) * seg;
    while (target < base + (calm ? 0 : 6 * math.pi)) {
      target += 2 * math.pi;
    }
    setState(() {
      _from = _angle;
      _to = target - base + _angle;
      _message = '';
      _big = false;
    });
    _app.sfx.play(Sound.tick);
    await _turn.forward(from: 0);
    if (!mounted) return;
    final v = radReihe[index];
    final stake = _bets[v] ?? 0;
    final win = stake == 0 ? 0 : stake * (v + 1);
    sharedWallet.credit(win);
    if (v == 40 && win > 0) progress.event('rad_joker');
    debugLog.info('gluecksrad', 'Einsatz $_total auf ${_bets.keys.join('/')}, Feld $v, Auszahlung $win');
    final played = _bets.isNotEmpty;
    if (played || win > 0) _app.sfx.play(win > 0 ? (v >= 10 ? Sound.bigWin : Sound.win) : Sound.lose);
    setState(() {
      _result = v;
      _from = _to;
      if (played) _lastBets = Map.of(_bets);
      _bets.clear();
      final name = v == 40 ? 'Joker' : '$v';
      _message = win > 0 ? '$name! +${formatCoins(win)}' : (played ? '$name – nichts gewonnen' : name);
      _big = win > 0;
    });
    sharedWallet.refillIfBroke();
    sharedStake(0);
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _spinTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GameFrame(
      title: 'Glücksrad',
      guide: gluecksradGuide,
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedBuilder(
                  animation: _turn,
                  builder: (context, _) => CustomPaint(size: Size.infinite, painter: _RadPainter(_angle, _blur)),
                ),
              ),
            ),
            ResultBanner(text: _message, highlight: _big),
            sharedStakesBar(),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final v in radFelder.keys)
                  GestureDetector(
                    onTap: () => _bet(v),
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _farben[v],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _result == v ? const Color(0xFFFFC95C) : const Color(0x55000000), width: _result == v ? 3 : 1),
                      ),
                      child: Column(
                        children: [
                          Text(v == 40 ? 'Joker' : '$v', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF241410))),
                          Text('$v:1', style: const TextStyle(fontSize: 12, color: Color(0xFF4E342E))),
                          Text(_bets[v] == null ? ' ' : formatCoins(_bets[v]!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFB71C1C))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
              for (final c in const [10, 50, 100, 500])
                ChoiceChip(label: Text(formatCoins(c)), selected: _chip == c, onSelected: (_) => setState(() => _chip = c)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
              ActionButton(
                primary: true,
                label: sharedGuest ? 'Der Gastgeber dreht' : (_bets.isEmpty && _lastBets.isNotEmpty ? 'Wiederholen und drehen' : 'Drehen'),
                onPressed: _turn.isAnimating || sharedGuest ? null : _spin,
              ),
              ActionButton(
                label: 'Einsätze weg',
                onPressed: _bets.isEmpty || _turn.isAnimating
                    ? null
                    : () {
                        setState(_bets.clear);
                        sharedStake(0);
                      },
              ),

            ]),
            const SizedBox(height: 12),
            Text('Einsatz ${formatCoins(_total)}', style: TextStyle(color: p.onFelt)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Mischfarbe aller Felder, gewichtet nach Anzahl (für die Bewegungsunschärfe).
final Color _mischfarbe = () {
  var r = 0.0, g = 0.0, b = 0.0;
  for (final v in radReihe) {
    final c = _farben[v]!;
    r += c.r;
    g += c.g;
    b += c.b;
  }
  final n = radReihe.length;
  return Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
}();

class _RadPainter extends CustomPainter {
  _RadPainter(this.angle, [this.blur = 0]);
  final double angle;

  /// 0 = scharf, bis 1 = ganz verschwommen.
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 16;
    if (r < 20) return;
    final n = radReihe.length;
    final seg = 2 * math.pi / n;
    canvas.drawCircle(c, r + 12, Paint()..color = const Color(0xFF5D4037));
    // Lichter am Rand
    for (var i = 0; i < 27; i++) {
      final a = i * 2 * math.pi / 27;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * (r + 6), 2.5, Paint()..color = const Color(0xFFFFE082));
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    for (var i = 0; i < n; i++) {
      final v = radReihe[i];
      final start = -math.pi / 2 + i * seg;
      final path = Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), start, seg, false)
        ..close();
      canvas.drawPath(path, Paint()..color = _farben[v]!);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x88000000));
      canvas.save();
      canvas.rotate(start + seg / 2);
      final tp = TextPainter(
        text: TextSpan(text: v == 40 ? 'J' : '$v', style: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w900, fontSize: r * 0.075, color: const Color(0xFF241410))),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.translate(r * 0.86, 0);
      canvas.rotate(math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas.restore();
    if (blur > 0) {
      // Felder verschwimmen zur Mischfarbe, damit beim schnellen Drehen nichts flackert
      canvas.drawCircle(c, r, Paint()..color = _mischfarbe.withValues(alpha: blur));
      // Leichte Ringe als Bewegungsandeutung, ohne harte Kanten
      for (final f in const [0.45, 0.7, 0.86]) {
        canvas.drawCircle(c, r * f, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08 * blur));
      }
    }
    canvas.drawCircle(c, r * 0.18, Paint()..color = const Color(0xFFFFC95C));
    canvas.drawCircle(c, r * 0.18, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF5D4037));
    final pointer = Path()
      ..moveTo(c.dx, c.dy - r + 14)
      ..lineTo(c.dx - 12, c.dy - r - 14)
      ..lineTo(c.dx + 12, c.dy - r - 14)
      ..close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFFD32F2F));
  }

  @override
  bool shouldRepaint(_RadPainter old) => old.angle != angle || old.blur != blur;
}
