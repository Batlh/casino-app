import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';

/// Sic Bo: drei Würfel, viele Wetten.
sealed class SicBet {
  const SicBet();
  String get label;
  String get odds;

  /// Auszahlung mit Einsatz für diesen Wurf.
  int payout(List<int> dice, int amount);
}

bool _triple(List<int> d) => d[0] == d[1] && d[1] == d[2];
int _sum(List<int> d) => d.fold(0, (a, b) => a + b);

class SicSmall extends SicBet {
  const SicSmall();
  @override
  String get label => 'Klein 4–10';
  @override
  String get odds => '1 : 1';
  @override
  int payout(List<int> d, int a) => !_triple(d) && _sum(d) <= 10 ? 2 * a : 0;
}

class SicBig extends SicBet {
  const SicBig();
  @override
  String get label => 'Groß 11–17';
  @override
  String get odds => '1 : 1';
  @override
  int payout(List<int> d, int a) => !_triple(d) && _sum(d) >= 11 ? 2 * a : 0;
}

class SicOdd extends SicBet {
  const SicOdd(this.even);
  final bool even;
  @override
  String get label => even ? 'Gerade' : 'Ungerade';
  @override
  String get odds => '1 : 1';
  @override
  int payout(List<int> d, int a) => !_triple(d) && _sum(d).isEven == even ? 2 * a : 0;
}

class SicTotal extends SicBet {
  const SicTotal(this.total);
  final int total;
  static const table = {4: 50, 5: 18, 6: 14, 7: 12, 8: 8, 9: 6, 10: 6, 11: 6, 12: 6, 13: 8, 14: 12, 15: 14, 16: 18, 17: 50};
  @override
  String get label => 'Summe $total';
  @override
  String get odds => '${table[total]} : 1';
  @override
  int payout(List<int> d, int a) => _sum(d) == total ? a * (table[total]! + 1) : 0;
}

class SicSingle extends SicBet {
  const SicSingle(this.face);
  final int face;
  @override
  String get label => 'Zahl $face';
  @override
  String get odds => '1–3 : 1';
  @override
  int payout(List<int> d, int a) {
    final n = d.where((x) => x == face).length;
    return n == 0 ? 0 : a * (n + 1);
  }
}

class SicAnyTriple extends SicBet {
  const SicAnyTriple();
  @override
  String get label => 'Jeder Drilling';
  @override
  String get odds => '24 : 1';
  @override
  int payout(List<int> d, int a) => _triple(d) ? a * 25 : 0;
}

class SicTriple extends SicBet {
  const SicTriple(this.face);
  final int face;
  @override
  String get label => 'Drei $face';
  @override
  String get odds => '150 : 1';
  @override
  int payout(List<int> d, int a) => _triple(d) && d[0] == face ? a * 151 : 0;
}

class SicDouble extends SicBet {
  const SicDouble(this.face);
  final int face;
  @override
  String get label => 'Zwei $face';
  @override
  String get odds => '8 : 1';
  @override
  int payout(List<int> d, int a) => d.where((x) => x == face).length >= 2 ? a * 9 : 0;
}

final sicBets = <SicBet>[
  const SicSmall(),
  const SicBig(),
  const SicOdd(false),
  const SicOdd(true),
  const SicAnyTriple(),
  for (var f = 1; f <= 6; f++) SicSingle(f),
  for (var f = 1; f <= 6; f++) SicDouble(f),
  for (var f = 1; f <= 6; f++) SicTriple(f),
  for (var t = 4; t <= 17; t++) SicTotal(t),
];

const sicBoGuide = GameGuide('Sic Bo', [
  GuideSection(
    'Ziel',
    'Drei Würfel werden geworfen. Du setzt vorher auf das, was du erwartest. Tippe Felder an, um den gewählten Chip zu setzen; '
        'du kannst auf viele Felder zugleich setzen.',
  ),
  GuideSection(
    'Wetten',
    'Klein (Summe 4 bis 10) und Groß (11 bis 17) zahlen 1 : 1, verlieren aber bei jedem Drilling. Gerade und Ungerade ebenso. '
        'Eine Zahl zahlt 1 : 1 pro Würfel, der sie zeigt. Zwei gleiche 8 : 1, ein bestimmter Drilling 150 : 1, jeder Drilling 24 : 1. '
        'Summen zahlen je nach Wahrscheinlichkeit 6 : 1 bis 50 : 1.',
  ),
]);

class SicBoScreen extends StatefulWidget {
  const SicBoScreen({super.key, this.seed});
  final int? seed;

  @override
  State<SicBoScreen> createState() => _SicBoScreenState();
}

class _SicBoScreenState extends State<SicBoScreen> {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  final Map<SicBet, int> _bets = {};
  int _chip = 10;
  List<int> _dice = [1, 2, 3];
  bool _rolling = false;
  String _message = 'Setze und würfle';
  bool _big = false;
  Set<SicBet> _winners = {};

  AppScope get _app => AppScope.of(context);
  int get _total => _bets.values.fold(0, (a, b) => a + b);

  void _place(SicBet b) {
    if (_rolling || !_app.wallet.canAfford(_total + _chip)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      _bets[b] = (_bets[b] ?? 0) + _chip;
      _winners = {};
    });
  }

  Future<void> _roll() async {
    if (_rolling || _total == 0 || !_app.wallet.spend(_total)) return;
    setState(() {
      _rolling = true;
      _message = '';
    });
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      _app.sfx.play(Sound.tick);
      setState(() => _dice = [for (var k = 0; k < 3; k++) 1 + _rng.nextInt(6)]);
    }
    final d = [for (var k = 0; k < 3; k++) 1 + _rng.nextInt(6)];
    var paid = 0;
    final won = <SicBet>{};
    for (final e in _bets.entries) {
      final p = e.key.payout(d, e.value);
      if (p > 0) won.add(e.key);
      paid += p;
    }
    if (paid > 0) _app.wallet.credit(paid);
    final net = paid - _total;
    _app.sfx.play(net > 0 ? Sound.win : Sound.lose);
    setState(() {
      _dice = d;
      _rolling = false;
      _winners = won;
      _big = net >= 20 * _chip && net > 0;
      _message = 'Gewürfelt: ${d.join(' · ')} = ${_sum(d)}${_triple(d) ? ' (Drilling)' : ''}. '
          '${net > 0 ? 'Gewinn ${formatCoins(net)}' : (paid > 0 ? 'Zurück ${formatCoins(paid)}' : 'Verloren')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Sic Bo',
      guide: sicBoGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF6B1F1F), Color(0xFF240808)])),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final v in _dice) Padding(padding: const EdgeInsets.all(6), child: DieFace(value: v, size: 64))],
                ),
                const SizedBox(height: 8),
                ResultBanner(text: _message, highlight: _big, maxLines: 2),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final b in sicBets) _field(b)]),
                const SizedBox(height: 10),
                BetPicker(value: _chip, onChanged: (v) => setState(() => _chip = v), enabled: !_rolling),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionButton(label: 'Löschen', onPressed: _rolling || _bets.isEmpty ? null : () => setState(_bets.clear)),
                    ActionButton(
                      primary: true,
                      label: _total == 0 ? 'Würfeln' : 'Würfeln: ${formatCoins(_total)}',
                      onPressed: _rolling || _total == 0 || !_app.wallet.canAfford(_total) ? null : _roll,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(SicBet b) {
    final pal = Palette.of(context);
    final amount = _bets[b] ?? 0;
    final win = _winners.contains(b);
    return GestureDetector(
      onTap: () => _place(b),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: win ? const Color(0xFF2E7D32) : pal.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: amount > 0 ? const Color(0xFFFFC95C) : pal.panelEdge, width: amount > 0 ? 3 : 1),
        ),
        child: Column(
          children: [
            Text(b.label, style: TextStyle(color: win ? Colors.white : pal.ink, fontWeight: FontWeight.w800, fontSize: 13)),
            Text(b.odds, style: TextStyle(color: win ? Colors.white70 : pal.inkSoft, fontSize: 11)),
            if (amount > 0) Text(formatCoins(amount), style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Würfel mit Augen.
class DieFace extends StatelessWidget {
  const DieFace({super.key, required this.value, this.size = 56});
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Würfel $value',
        child: CustomPaint(size: Size.square(size), painter: _DiePainter(value)),
      );
}

class _DiePainter extends CustomPainter {
  _DiePainter(this.value);
  final int value;

  static const _spots = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.27, 0.27), Offset(0.73, 0.73)],
    3: [Offset(0.27, 0.27), Offset(0.5, 0.5), Offset(0.73, 0.73)],
    4: [Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.27, 0.73), Offset(0.73, 0.73)],
    5: [Offset(0.27, 0.27), Offset(0.73, 0.27), Offset(0.5, 0.5), Offset(0.27, 0.73), Offset(0.73, 0.73)],
    6: [Offset(0.27, 0.25), Offset(0.73, 0.25), Offset(0.27, 0.5), Offset(0.73, 0.5), Offset(0.27, 0.75), Offset(0.73, 0.75)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.18));
    canvas.drawRRect(r.shift(const Offset(0, 3)), Paint()..color = const Color(0x66000000));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFFFFBF2));
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33000000),
    );
    final red = value == 1 || value == 4;
    for (final o in _spots[value]!) {
      canvas.drawCircle(
        Offset(o.dx * size.width, o.dy * size.height),
        size.width * 0.09,
        Paint()..color = red ? const Color(0xFFC62828) : const Color(0xFF241410),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiePainter old) => old.value != value;
}
