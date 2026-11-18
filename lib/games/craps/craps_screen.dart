import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import '../sicbo/sicbo_screen.dart' show DieFace;

enum CrapsBet { pass, dontPass, field, anySeven, anyCraps }

const crapsNames = {
  CrapsBet.pass: 'Pass Line',
  CrapsBet.dontPass: "Don't Pass",
  CrapsBet.field: 'Field',
  CrapsBet.anySeven: 'Jede 7',
  CrapsBet.anyCraps: 'Jedes Craps',
};

const crapsOdds = {
  CrapsBet.pass: '1 : 1',
  CrapsBet.dontPass: '1 : 1',
  CrapsBet.field: '1 : 1, 2 und 12 doppelt',
  CrapsBet.anySeven: '4 : 1',
  CrapsBet.anyCraps: '7 : 1',
};

/// Ergebnis eines Wurfs für eine Wette: Auszahlung mit Einsatz, oder null wenn sie liegen bleibt.
int? crapsResolve(CrapsBet b, int sum, int? point, int amount) {
  switch (b) {
    case CrapsBet.field:
      if (sum == 2 || sum == 12) return amount * 3;
      return const {3, 4, 9, 10, 11}.contains(sum) ? amount * 2 : 0;
    case CrapsBet.anySeven:
      return sum == 7 ? amount * 5 : 0;
    case CrapsBet.anyCraps:
      return const {2, 3, 12}.contains(sum) ? amount * 8 : 0;
    case CrapsBet.pass:
      if (point == null) {
        if (sum == 7 || sum == 11) return amount * 2;
        if (const {2, 3, 12}.contains(sum)) return 0;
        return null;
      }
      if (sum == point) return amount * 2;
      if (sum == 7) return 0;
      return null;
    case CrapsBet.dontPass:
      if (point == null) {
        if (sum == 2 || sum == 3) return amount * 2;
        if (sum == 12) return amount;
        if (sum == 7 || sum == 11) return 0;
        return null;
      }
      if (sum == 7) return amount * 2;
      if (sum == point) return 0;
      return null;
  }
}

const crapsGuide = GameGuide('Craps', [
  GuideSection(
    'Der erste Wurf',
    'Mit zwei Würfeln. Beim ersten Wurf gewinnt Pass Line mit 7 oder 11 und verliert mit 2, 3 oder 12. Jede andere Zahl wird zum '
        'Punkt. Don’t Pass ist das Gegenteil (bei 12 gibt es den Einsatz zurück).',
  ),
  GuideSection(
    'Der Punkt',
    'Steht ein Punkt, wird weitergewürfelt: Kommt der Punkt wieder, gewinnt Pass Line. Kommt vorher eine 7, gewinnt Don’t Pass. '
        'Pass Line und Don’t Pass kannst du nur vor dem ersten Wurf setzen.',
  ),
  GuideSection(
    'Einmalwetten',
    'Field gewinnt bei 3, 4, 9, 10, 11 (1 : 1) und bei 2 oder 12 (2 : 1). Jede 7 zahlt 4 : 1, jedes Craps (2, 3 oder 12) 7 : 1. '
        'Sie gelten nur für den nächsten Wurf.',
  ),
]);

class CrapsScreen extends StatefulWidget {
  const CrapsScreen({super.key, this.seed});
  final int? seed;

  @override
  State<CrapsScreen> createState() => _CrapsScreenState();
}

class _CrapsScreenState extends State<CrapsScreen> with NetSharedTable {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  final Map<CrapsBet, int> _bets = {};
  int _chip = 10;
  int? _point;
  List<int> _dice = [3, 4];
  bool _rolling = false;
  String _message = 'Setze auf Pass Line oder Don’t Pass und würfle';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  bool _canPlace(CrapsBet b) => !_rolling && (_point == null || (b != CrapsBet.pass && b != CrapsBet.dontPass));

  int get _staked => _bets.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'craps';
  @override
  String get sharedTitle => 'Craps';
  Map<String, Object?>? _pending;

  /// Ergebnis vom Gastgeber: Würfel und Punkt vor dem Wurf (der Punkt gilt für den ganzen Tisch).
  @override
  void sharedResult(Object? outcome) {
    if (outcome is! Map) return;
    final m = outcome.cast<String, Object?>();
    if (_rolling) {
      _pending = m;
      return;
    }
    final d = [for (final v in m['d'] as List) ((v as num).toInt()).clamp(1, 6)];
    _point = (m['p'] as num?)?.toInt();
    _rollTo(d);
  }

  void _place(CrapsBet b) {
    if (!_canPlace(b) || !_app.wallet.spend(_chip)) return;
    _app.sfx.play(Sound.chip);
    setState(() => _bets[b] = (_bets[b] ?? 0) + _chip);
    sharedStake(_staked);
  }

  Future<void> _roll() async {
    if (_rolling || sharedGuest) return;
    // Am Netztisch würfelt der Gastgeber auch ohne eigenen Einsatz
    if (_bets.isEmpty && !sharedHost) return;
    final d = [1 + _rng.nextInt(6), 1 + _rng.nextInt(6)];
    sharedSend({'d': d, 'p': _point});
    await _rollTo(d);
  }

  Future<void> _rollTo(List<int> d) async {
    setState(() => _rolling = true);
    for (var i = 0; i < 7; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      _app.sfx.play(Sound.tick);
      setState(() => _dice = [1 + _rng.nextInt(6), 1 + _rng.nextInt(6)]);
    }
    final sum = d[0] + d[1];
    var paid = 0;
    var lost = 0;
    final left = <CrapsBet, int>{};
    for (final e in _bets.entries) {
      final r = crapsResolve(e.key, sum, _point, e.value);
      if (r == null) {
        left[e.key] = e.value;
      } else {
        paid += r;
        if (r == 0) lost += e.value;
      }
    }
    String pointText;
    if (_point == null) {
      _point = const {4, 5, 6, 8, 9, 10}.contains(sum) ? sum : null;
      pointText = _point == null ? '' : ' Punkt ist $_point.';
    } else if (sum == _point || sum == 7) {
      pointText = sum == 7 ? ' Sieben: der Punkt ist weg.' : ' Punkt getroffen!';
      _point = null;
    } else {
      pointText = '';
    }
    if (paid > 0) _app.wallet.credit(paid);
    _app.sfx.play(paid > 0 ? Sound.win : (lost > 0 ? Sound.lose : Sound.tick));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sharedStake(_staked);
      final next = _pending;
      _pending = null;
      if (next != null) sharedResult(next);
    });
    setState(() {
      _dice = d;
      _rolling = false;
      _bets
        ..clear()
        ..addAll(left);
      _big = paid >= 8 * _chip;
      _message = 'Gewürfelt: $sum.$pointText${paid > 0 ? ' Ausgezahlt: ${formatCoins(paid)}' : ''}${lost > 0 ? ' Verloren: ${formatCoins(lost)}' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return GameFrame(
      title: 'Craps',
      guide: crapsGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1B5E20), Color(0xFF07240A)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [for (final v in _dice) Padding(padding: const EdgeInsets.all(6), child: DieFace(value: v, size: 64))],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _point == null ? const Color(0x55000000) : const Color(0xFFFFC95C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _point == null ? 'Erster Wurf' : 'Punkt: $_point',
                    style: TextStyle(color: _point == null ? const Color(0xFFF6E7C8) : const Color(0xFF241410), fontWeight: FontWeight.w800),
                  ),
                ),
                ResultBanner(text: _message, highlight: _big, maxLines: 2),
                sharedStakesBar(),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final b in CrapsBet.values)
                      GestureDetector(
                        onTap: () => _place(b),
                        child: Opacity(
                          opacity: _canPlace(b) || (_bets[b] ?? 0) > 0 ? 1 : 0.45,
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pal.panel,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: (_bets[b] ?? 0) > 0 ? const Color(0xFFFFC95C) : pal.panelEdge, width: (_bets[b] ?? 0) > 0 ? 3 : 1.5),
                            ),
                            child: Column(
                              children: [
                                Text(crapsNames[b]!, style: TextStyle(color: pal.ink, fontWeight: FontWeight.w800)),
                                Text(crapsOdds[b]!, textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoft, fontSize: 12)),
                                if ((_bets[b] ?? 0) > 0)
                                  Text(formatCoins(_bets[b]!), style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                BetPicker(value: _chip, onChanged: (v) => setState(() => _chip = v), enabled: !_rolling),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  ActionButton(
                    primary: true,
                    label: sharedGuest ? 'Der Gastgeber würfelt' : 'Würfeln',
                    onPressed: _rolling || sharedGuest || (_bets.isEmpty && !sharedHost) ? null : _roll,
                  ),
                  if (!sharedActive && MediaQuery.sizeOf(context).width < 420) ActionButton(label: 'Im Netzwerk', onPressed: sharedOpenPanel),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
