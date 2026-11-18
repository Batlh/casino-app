import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import 'roulette_engine.dart';
import 'roulette_painters.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin, NetSharedTable {
  final _rng = math.Random.secure();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4400),
  );

  Map<BetSpot, int> _bets = {};
  Map<BetSpot, int> _lastBets = {};
  final List<int> _history = [];
  int _chip = 50;
  int? _result;
  String _message = 'Jeton wählen und auf den Tisch setzen';
  bool _big = false;

  double _wheelStart = 0;
  double _wheelEnd = 0;
  double _ballStart = 0;
  double _ballEnd = 0;
  bool _ballVisible = false;

  AppScope get _app => AppScope.of(context);
  bool get _spinning => _spin.isAnimating;
  int get _staked => _bets.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    _spin.dispose();
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'roulette';
  @override
  String get sharedTitle => 'Roulette';

  /// Kam ein Ergebnis, während das Rad noch lief, dreht es danach.
  int? _pending;

  @override
  void sharedResult(Object? outcome) {
    final n = (outcome as num?)?.toInt();
    if (n == null || n < 0 || n > 36) return;
    if (_spinning) {
      _pending = n;
      return;
    }
    _spinTo(n);
  }

  void _place(BetSpot spot) {
    if (_spinning) return;
    if (!_app.wallet.canAfford(_staked + _chip)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      if (_result != null) {
        _result = null;
        _message = '';
        _big = false;
      }
      _bets[spot] = (_bets[spot] ?? 0) + _chip;
    });
    sharedStake(_staked);
  }

  void _clear() {
    setState(() => _bets = {});
    sharedStake(0);
  }

  void _repeat() {
    final total = _lastBets.values.fold(0, (a, b) => a + b);
    if (!_app.wallet.canAfford(total)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      _bets = Map.of(_lastBets);
      _result = null;
      _message = '';
      _big = false;
    });
    sharedStake(_staked);
  }

  Future<void> _run() async {
    if (_spinning || sharedGuest) return;
    // Am Netztisch dreht der Gastgeber auch ohne eigenen Einsatz
    if (_staked == 0 && !sharedHost) return;
    if (_staked > 0 && !_app.wallet.canAfford(_staked)) return;
    final n = spinWheel(_rng);
    sharedSend(n);
    await _spinTo(n);
  }

  Future<void> _spinTo(int n) async {
    var stake = _staked;
    if (stake > 0 && !_app.wallet.spend(stake)) {
      _bets = {};
      stake = 0;
    }
    final index = wheelOrder.indexOf(n);
    final wallet = _app.wallet;
    final placed = Map.of(_bets);

    _wheelStart = _wheelEnd % (2 * math.pi);
    _wheelEnd = _wheelStart + 2 * math.pi * 2 + _rng.nextDouble() * 2 * math.pi;
    _ballStart = _rng.nextDouble() * 2 * math.pi;
    final target = _wheelEnd + pocketCenter(index);
    _ballEnd = target - 2 * math.pi * 6;
    setState(() {
      _ballVisible = true;
      _result = null;
      _message = 'Nichts geht mehr';
      _big = false;
    });
    _app.sfx.play(Sound.ball);
    try {
      await _spin.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Bildschirm wurde verlassen. Die Abrechnung folgt unten trotzdem.
    }

    final back = resolveBets(placed, n);
    wallet.credit(back);
    if (!mounted) {
      wallet.refillIfBroke();
      return;
    }
    setState(() {
      _result = n;
      _history.insert(0, n);
      if (_history.length > 12) _history.removeLast();
      if (placed.isNotEmpty) _lastBets = placed;
      _bets = {};
      final net = back - stake;
      if (stake == 0) {
        _message = '$n';
      } else if (net > 0) {
        _message = '$n: Gewonnen +${formatCoins(net)}';
        _big = true;
        _app.sfx.play(net >= stake * 10 ? Sound.bigWin : Sound.win);
      } else if (net == 0) {
        _message = '$n: Einsatz zurück';
      } else {
        _message = '$n: Verloren -${formatCoins(-net)}';
        _app.sfx.play(Sound.lose);
      }
    });
    wallet.refillIfBroke();
    if (!wallet.canAfford(_chip)) setState(() => _chip = 10);
    sharedStake(0);
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _spinTo(next);
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      guide: rouletteGuide,
      title: 'Roulette',
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.2;
          if (wide) return _wideLayout(box);
          return _tallLayout(box);
        },
      ),
    );
  }

  Widget _wheel(double size) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final t = _spin.value;
          final wheel = _wheelStart +
              (_wheelEnd - _wheelStart) * Curves.easeOutCubic.transform(t);
          final ball = _ballStart +
              (_ballEnd - _ballStart) * Curves.easeOutQuart.transform(t);
          // Kugel läuft außen, fällt ab 70 Prozent der Zeit in die Tasche
          final fall = Curves.easeIn.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));
          final radius = 0.95 + (0.72 - 0.95) * fall;
          return CustomPaint(
            painter: WheelPainter(
              wheelAngle: wheel,
              ballAngle: ball,
              ballRadius: radius,
              showBall: _ballVisible,
            ),
          );
        },
      ),
    );
  }

  Widget _history2() {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        children: [
          for (final n in _history)
            Container(
              width: 30,
              margin: const EdgeInsets.only(right: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pocketColor(n),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$n',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBanner(text: _message, highlight: _big),
        sharedStakesBar(),
        BetPicker(
          value: _chip,
          size: 42,
          enabled: !_spinning,
          onChanged: (v) => setState(() => _chip = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton(
              primary: true,
              label: sharedGuest ? 'Der Gastgeber dreht' : (_staked > 0 ? 'Drehen: ${formatCoins(_staked)}' : 'Drehen'),
              onPressed: !sharedGuest && (_staked > 0 || sharedHost) && !_spinning ? _run : null,
            ),
            if (_staked > 0)
              ActionButton(
                label: 'Einsätze löschen',
                onPressed: _spinning ? null : _clear,
              )
            else
              ActionButton(
                label: 'Wiederholen',
                onPressed: _lastBets.isNotEmpty && !_spinning ? _repeat : null,
              ),
            if (!sharedActive && MediaQuery.sizeOf(context).width < 420)
              ActionButton(label: 'Im Netzwerk', onPressed: sharedOpenPanel),
          ],
        ),
      ],
    );
  }

  Widget _table({required bool horizontal}) => _BetTable(
        horizontal: horizontal,
        bets: _bets,
        result: _result,
        onTap: _place,
      );

  Widget _tallLayout(BoxConstraints box) {
    final wheel = math.min(box.maxWidth * 0.5, box.maxHeight * 0.24);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              _wheel(wheel),
              const SizedBox(width: 12),
              Expanded(child: _history2()),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: LayoutBuilder(
              builder: (context, area) {
                // Vierzehn Reihen brauchen Platz zum Tippen, sonst wird gescrollt
                const minHeight = 14 * 30.0;
                if (area.maxHeight >= minHeight) {
                  return _table(horizontal: false);
                }
                return SingleChildScrollView(
                  child: SizedBox(
                    height: minHeight,
                    child: _table(horizontal: false),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: _controls(),
        ),
      ],
    );
  }

  Widget _wideLayout(BoxConstraints box) {
    final side = math.min(box.maxHeight * 0.62, box.maxWidth * 0.34);
    return Row(
      children: [
        SizedBox(
          width: side + 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _wheel(side),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _history2(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(child: _table(horizontal: true)),
                _controls(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tischfelder. Hochkant zwölf Reihen, im Querformat zwölf Spalten.
class _BetTable extends StatelessWidget {
  const _BetTable({
    required this.horizontal,
    required this.bets,
    required this.result,
    required this.onTap,
  });

  final bool horizontal;
  final Map<BetSpot, int> bets;
  final int? result;
  final ValueChanged<BetSpot> onTap;

  Widget _cell(
    BetSpot spot,
    String label, {
    Color? color,
    int flex = 1,
    Widget? icon,
  }) {
    return Expanded(
      flex: flex,
      child: _BetCell(
        label: label,
        color: color,
        icon: icon,
        stake: bets[spot] ?? 0,
        winning: result != null && spot.wins(result!),
        onTap: () => onTap(spot),
      ),
    );
  }

  Widget _number(int n) =>
      _cell(BetSpot(BetType.straight, n), '$n', color: pocketColor(n));

  List<Widget> _outside() => [
        _cell(const BetSpot(BetType.low), '1 bis 18'),
        _cell(const BetSpot(BetType.even), 'Gerade'),
        _cell(const BetSpot(BetType.red), 'Rot', color: rouletteRed),
        _cell(const BetSpot(BetType.black), 'Schwarz', color: rouletteBlack),
        _cell(const BetSpot(BetType.odd), 'Ungerade'),
        _cell(const BetSpot(BetType.high), '19 bis 36'),
      ];

  List<Widget> _dozens() => [
        for (var d = 0; d < 3; d++)
          _cell(BetSpot(BetType.dozen, d), '${d * 12 + 1} bis ${d * 12 + 12}'),
      ];

  @override
  Widget build(BuildContext context) {
    return horizontal ? _buildHorizontal() : _buildVertical();
  }

  Widget _buildHorizontal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _number(0),
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in [2, 1, 0])
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var col = 0; col < 12; col++)
                              _number(col * 3 + c + 1),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in [2, 1, 0])
                      _cell(BetSpot(BetType.column, c), '2:1'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _dozens(),
        )),
        Expanded(child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _outside(),
        )),
      ],
    );
  }

  Widget _buildVertical() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _outside(),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _dozens(),
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [_number(0)],
              )),
              for (var row = 0; row < 12; row++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < 3; c++) _number(row * 3 + c + 1),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < 3; c++)
                      _cell(BetSpot(BetType.column, c), '2:1'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BetCell extends StatelessWidget {
  const _BetCell({
    required this.label,
    required this.stake,
    required this.winning,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final int stake;
  final bool winning;
  final VoidCallback onTap;
  final Color? color;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: stake > 0 ? '$label, gesetzt ${formatCoins(stake)}' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            border: Border.all(
              color: winning
                  ? const Color(0xFFFFC95C)
                  : p.onFelt.withValues(alpha: 0.45),
              width: winning ? 2.5 : 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFFFF7E2),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (stake > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC95C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatCoins(stake),
                      style: const TextStyle(
                        color: Color(0xFF2A160E),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
