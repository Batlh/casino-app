import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/wallet.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../cards/playing_card.dart';
import '../maumau/maumau_engine.dart' show suitName;
import 'hilo_engine.dart';

const hiloGuide = GameGuide('Höher oder Tiefer', [
  GuideSection(
    'So geht es',
    'Setze und zieh die erste Karte. Dann rätst du: Ist die nächste Karte höher oder tiefer? Jeder Treffer '
        'erhöht deinen Gewinn um den Faktor auf dem Knopf. Nach jedem Treffer kannst du aussteigen und den '
        'Gewinn mitnehmen oder weiter raten. Ein Fehler, und die ganze Leiter ist weg.',
  ),
  GuideSection(
    'Faktoren',
    'Gespielt wird aus sechs Decks. Der Faktor hängt davon ab, wie viele höhere oder tiefere Karten noch im Schuh '
        'sind: Je unwahrscheinlicher, desto mehr. Gleich hoch zählt als verloren, das Ass ist die höchste Karte. '
        'Auf lange Sicht gehen 97 % der Einsätze zurück.',
  ),
  GuideSection('Grenzen', 'Nach $hiloMaxSteps Treffern oder beim $hiloMaxFactor-fachen Einsatz wird automatisch ausgezahlt.'),
]);

class HiloScreen extends StatefulWidget {
  const HiloScreen({super.key, this.seed});
  final int? seed;

  @override
  State<HiloScreen> createState() => _HiloScreenState();
}

class _HiloScreenState extends State<HiloScreen> {
  late final HiloGame _g = HiloGame(rng: widget.seed == null ? null : math.Random(widget.seed));
  int _bet = 10;
  String _message = 'Einsatz wählen und die erste Karte ziehen';
  bool _big = false;
  int _deal = 0;

  AppScope get _app => AppScope.of(context);

  /// Für dispose gemerkt (dort darf nicht mehr nach AppScope gesucht werden).
  Wallet? _wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet ??= _app.wallet;
  }

  @override
  void dispose() {
    // Wer mitten in der Leiter geht, nimmt den bisherigen Gewinn mit
    if (_g.canCashOut) {
      final w = _g.cashOut();
      if (w > 0) _wallet?.credit(w);
    }
    super.dispose();
  }

  static String factor(int f100) => '×${(f100 / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  void _start() {
    if (!_app.wallet.spend(_bet)) return;
    _g.start(_bet);
    _deal++;
    _app.sfx.play(Sound.card);
    setState(() {
      _message = 'Höher oder tiefer als ${_name(_g.card!)}?';
      _big = false;
    });
  }

  void _guess(HiloGuess g) {
    final prev = _g.card!;
    _g.guess(g);
    _deal++;
    final next = _g.card!;
    debugLog.info('hilo', '${_name(prev)} → ${_name(next)}, ${g.name}, Stufe ${_g.steps}, ${_g.phase.name}');
    if (_g.phase == HiloPhase.lost) {
      _app.sfx.play(Sound.lose);
      _app.wallet.refillIfBroke();
      setState(() {
        _message = '${_name(next)} – daneben. ${formatCoins(_g.bet)} sind weg';
        _big = false;
      });
      return;
    }
    if (_g.phase == HiloPhase.cashed) {
      final w = _g.cashOut();
      _app.wallet.credit(w);
      _app.sfx.play(Sound.bigWin);
      setState(() {
        _message = 'Leiter oben! +${formatCoins(w)}';
        _big = true;
        _g.phase = HiloPhase.idle;
      });
      return;
    }
    _app.sfx.play(Sound.chip);
    setState(() => _message = '${_name(next)} – richtig! Gewinn ${formatCoins(_g.win)}. Weiter oder aussteigen?');
  }

  void _cash() {
    final w = _g.cashOut();
    if (w <= 0) return;
    _app.wallet.credit(w);
    _app.sfx.play(w >= _g.bet * 10 ? Sound.bigWin : Sound.win);
    setState(() {
      _message = 'Ausgestiegen nach ${_g.steps} ${_g.steps == 1 ? 'Treffer' : 'Treffern'}: +${formatCoins(w)}';
      _big = w >= _g.bet * 5;
      _g.phase = HiloPhase.idle;
    });
  }

  String _name(PlayingCard c) => '${suitName(c.suit)} ${c.rankLabel(_app.settings.cardNames)}';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final running = _g.phase == HiloPhase.running;
    return GameFrame(
      title: 'Höher oder Tiefer',
      guide: hiloGuide,
      child: LayoutBuilder(builder: (context, box) {
        final cardW = math.min(150.0, math.min(box.maxWidth * 0.36, box.maxHeight * 0.26));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bisherige Karten
                SizedBox(
                  height: cardW * 0.45 / cardAspect,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    children: [
                      for (final c in _g.history.reversed.take(12).toList().reversed)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: PlayingCardView(width: cardW * 0.45, card: c)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Ladder(steps: _g.steps, height: cardW / cardAspect, lost: _g.phase == HiloPhase.lost),
                    const SizedBox(width: 18),
                    DealIn(
                      key: ValueKey(_deal),
                      child: PlayingCardView(width: cardW, card: _g.card),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (running)
                  Text(
                    _g.steps == 0 ? 'Einsatz ${formatCoins(_g.bet)}' : 'Gewinn ${formatCoins(_g.win)}',
                    style: TextStyle(color: p.onFelt, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                const SizedBox(height: 6),
                ResultBanner(text: _message, highlight: _big, maxLines: 2),
                const SizedBox(height: 10),
                if (running)
                  Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final g in HiloGuess.values)
                      ActionButton(
                        primary: true,
                        label: _g.factor100(g) == 0
                            ? (g == HiloGuess.higher ? 'Höher geht nicht' : 'Tiefer geht nicht')
                            : '${g == HiloGuess.higher ? 'Höher' : 'Tiefer'} ${factor(_g.factor100(g))}',
                        onPressed: _g.factor100(g) == 0 ? null : () => _guess(g),
                      ),
                    ActionButton(label: _g.canCashOut ? 'Aussteigen: ${formatCoins(_g.win)}' : 'Aussteigen', onPressed: _g.canCashOut ? _cash : null),
                  ])
                else ...[
                  BetPicker(value: _bet, onChanged: (v) => setState(() => _bet = v)),
                  const SizedBox(height: 10),
                  ActionButton(primary: true, label: 'Erste Karte: ${formatCoins(_bet)}', onPressed: _app.wallet.canAfford(_bet) ? _start : null),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Leiter mit den Treffern als Sprossen.
class _Ladder extends StatelessWidget {
  const _Ladder({required this.steps, required this.height, required this.lost});
  final int steps;
  final double height;
  final bool lost;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 34,
      height: height,
      child: Column(
        children: [
          for (var i = hiloMaxSteps; i >= 1; i--)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                decoration: BoxDecoration(
                  color: i <= steps ? (lost ? const Color(0xFFE53935) : p.accent) : p.panel,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: p.panelEdge),
                ),
                alignment: Alignment.center,
                child: Text('$i', style: TextStyle(fontSize: 11, color: i <= steps ? Colors.black : p.inkSoft, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
