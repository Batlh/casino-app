import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../lose/lose_art.dart';
import '../slots/art_kit.dart';
import '../slots/frucht_art.dart';
import 'arcade_engine.dart';

const arcadeGuide = GameGuide('Goldene Sieben', [
  GuideSection(
    'So geht es',
    'Drei Walzen, gewonnen wird auf der Linie in der Mitte. Drei Sieben zahlen 100-mal den Einsatz, drei Glocken 40, '
        'drei Melonen 20, drei Pflaumen 12, drei Orangen 10, drei Zitronen 6, drei Kirschen 5. Zwei Kirschen vorn zahlen 3, '
        'eine Kirsche auf der ersten Walze bringt den Einsatz zurück.',
  ),
  GuideSection('Sonderspiele', 'Drei Sterne auf der Linie bringen 10 Sonderspiele. Sie kosten nichts und zahlen doppelt.'),
  GuideSection(
    'Risikoleiter',
    'Nach jedem Gewinn entscheidest du: „Annehmen“ bucht ihn gut, „Risiko“ verdoppelt ihn mit halber Chance – oder er ist weg. '
        'Bis zu sechsmal hintereinander. Die Leiter ist fair, sie ändert die Quote nicht, nur das Auf und Ab.',
  ),
  GuideSection(
    'Halten und Nachschieben',
    'Nach einer Drehung ohne Gewinn leuchtet manchmal „Halten“: Tippe Walzen an, die bei der nächsten Drehung stehen bleiben. '
        'Oder „Nachschieben“: Rücke eine Walze um ein Feld hoch oder runter. Die Vorschläge sind hell markiert.',
  ),
  GuideSection('Quote', 'Wer den Vorschlägen folgt, bekommt auf lange Sicht etwa 96 % zurück.'),
]);

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key, this.seed});
  final int? seed;

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> with SingleTickerProviderStateMixin {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final ArcadeMachine _m = ArcadeMachine(rng: _rng);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  List<int> _from = [0, 7, 3];
  bool _spinning = false;

  /// Gewinn auf der Risikoleiter (0 = keine Leiter offen) und erreichte Stufe.
  int _ladder = 0;
  int _step = 0;
  bool _gambling = false;
  int _flash = 0;
  String _message = 'Einsatz wählen und drehen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  @override
  void dispose() {
    // Offene Leiter wird beim Gehen angenommen
    if (_ladder > 0) _app.wallet.credit(_ladder);
    _spin.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_spinning || _ladder > 0) return;
    final free = _m.freeSpins > 0;
    if (!free && !_app.wallet.spend(_m.bet)) return;
    _from = [..._m.pos];
    final win = _m.spin();
    setState(() {
      _spinning = true;
      _message = free ? 'Sonderspiel, noch ${_m.freeSpins}' : '';
      _big = false;
    });
    _app.sfx.play(Sound.tick);
    await _spin.forward(from: 0);
    if (!mounted) return;
    _spinning = false;
    debugLog.info('spielhalle', 'Linie ${_m.line.map((s) => arcadeSymbols[s]).join('/')}, Gewinn $win');
    _afterWin(win);
  }

  void _afterWin(int win) {
    final starsHit = arcadeStars(_m.line);
    if (win > 0) {
      _app.sfx.play(win >= _m.bet * 20 ? Sound.bigWin : Sound.win);
      setState(() {
        _ladder = win;
        _step = 0;
        _message = 'Gewinn ${formatCoins(win)}! Annehmen oder Risiko?';
        _big = true;
      });
      return;
    }
    if (starsHit) _app.sfx.play(Sound.bigWin);
    setState(() {
      _message = starsHit
          ? '$arcadeFreeSpins Sonderspiele mit doppeltem Gewinn!'
          : switch (_m.offer) {
              ArcadeOffer.hold => 'HALTEN! Walzen antippen, die stehen bleiben sollen',
              ArcadeOffer.nudge => 'NACHSCHIEBEN! Eine Walze um ein Feld rücken',
              ArcadeOffer.none => _m.freeSpins > 0 ? 'Noch ${_m.freeSpins} Sonderspiele' : 'Leider nichts',
            };
      if (_m.offer == ArcadeOffer.hold) _m.held.addAll(_m.suggestHold());
    });
    if (_m.freeSpins == 0) _app.wallet.refillIfBroke(min: _m.bet);
  }

  void _nudge(int reel, int dir) {
    _from = [..._m.pos];
    final win = _m.nudge(reel, dir);
    _app.sfx.play(Sound.chip);
    _afterWin(win);
  }

  void _skipNudge() => setState(() {
        _m.offer = ArcadeOffer.none;
        _message = 'Weiter geht es';
      });

  void _collect() {
    if (_ladder <= 0 || _gambling) return;
    final w = _ladder;
    _app.wallet.credit(w);
    _app.sfx.play(Sound.coin);
    setState(() {
      _ladder = 0;
      _message = '+${formatCoins(w)} angenommen${_m.freeSpins > 0 ? '. Noch ${_m.freeSpins} Sonderspiele' : ''}';
      _big = false;
    });
  }

  Future<void> _risk() async {
    if (_ladder <= 0 || _gambling || _step >= arcadeLadderSteps) return;
    setState(() => _gambling = true);
    // Die beiden Stufen blinken abwechselnd, dann steht das Ergebnis fest
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted) return;
      _app.sfx.play(Sound.tick);
      setState(() => _flash = i);
    }
    final up = _rng.nextBool();
    debugLog.info('spielhalle', 'Risiko bei ${_ladder}: ${up ? 'hoch' : 'weg'}');
    setState(() {
      _gambling = false;
      _flash = 0;
      if (up) {
        _ladder *= 2;
        _step++;
        _message = _step >= arcadeLadderSteps ? 'Ganz oben! ${formatCoins(_ladder)} – bitte annehmen' : 'Hoch auf ${formatCoins(_ladder)}!';
        _big = true;
      } else {
        _message = 'Abgestürzt – ${formatCoins(_ladder)} sind weg';
        _ladder = 0;
        _big = false;
      }
    });
    _app.sfx.play(up ? Sound.win : Sound.lose);
    if (!up && _m.freeSpins == 0) _app.wallet.refillIfBroke(min: _m.bet);
  }

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFFFFC95C);
    final offer = _spinning ? ArcadeOffer.none : _m.offer;
    final hint = offer == ArcadeOffer.nudge ? _m.suggestNudge() : null;
    return GameFrame(
      title: 'Goldene Sieben',
      guide: arcadeGuide,
      minStake: 10,
      background: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A0D2E), Color(0xFF12030F)]),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final reelW = math.min(120.0, (box.maxWidth - 120) / 3);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('GOLDENE SIEBEN',
                  style: TextStyle(color: neon, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: Color(0xFFFF4081), blurRadius: 12)])),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _LadderView(base: _ladder > 0 ? _ladder ~/ (1 << _step) : 0, step: _step, active: _ladder > 0, flash: _gambling ? _flash : -1, height: reelW * 3),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B0716),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: neon, width: 3),
                    ),
                    child: AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var r = 0; r < 3; r++)
                            _Reel(
                              width: reelW,
                              symbols: _visible(r),
                              shift: _shift(r),
                              held: _m.held.contains(r) && offer == ArcadeOffer.hold,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Halten / Nachschieben unter den Walzen
              if (offer == ArcadeOffer.hold)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 60),
                  for (var r = 0; r < 3; r++)
                    SizedBox(
                      width: reelW,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: const Text('Halten'),
                          selected: _m.held.contains(r),
                          onSelected: (_) => setState(() => _m.toggleHold(r)),
                        ),
                      ),
                    ),
                ]),
              if (offer == ArcadeOffer.nudge)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 60),
                  for (var r = 0; r < 3; r++)
                    SizedBox(
                      width: reelW,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (final d in const [-1, 1])
                          IconButton.filledTonal(
                            tooltip: d < 0 ? 'Walze ${r + 1} hoch' : 'Walze ${r + 1} runter',
                            isSelected: hint == (r, d),
                            icon: Icon(d < 0 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            onPressed: () => _nudge(r, d),
                          ),
                      ]),
                    ),
                ]),
              const SizedBox(height: 6),
              ResultBanner(text: _message, highlight: _big, maxLines: 2),
              if (_m.freeSpins > 0)
                Text('Sonderspiele: ${_m.freeSpins} (doppelter Gewinn)', style: const TextStyle(color: neon, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_ladder > 0)
                Wrap(spacing: 10, children: [
                  ActionButton(primary: true, label: 'Annehmen: ${formatCoins(_ladder)}', onPressed: _gambling ? null : _collect),
                  ActionButton(
                    label: _step >= arcadeLadderSteps ? 'Leiter voll' : 'Risiko: ${formatCoins(_ladder * 2)}',
                    onPressed: _gambling || _step >= arcadeLadderSteps ? null : _risk,
                  ),
                ])
              else ...[
                Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                  for (final b in const [10, 20, 50, 100])
                    ChoiceChip(
                      label: Text(formatCoins(b)),
                      selected: _m.bet == b,
                      onSelected: _spinning || _m.freeSpins > 0 ? null : (_) => setState(() => _m.bet = b),
                    ),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 10, children: [
                  ActionButton(
                    primary: true,
                    label: _m.freeSpins > 0 ? 'Sonderspiel' : (offer == ArcadeOffer.hold && _m.held.isNotEmpty ? 'Mit Halten drehen: ${formatCoins(_m.bet)}' : 'Drehen: ${formatCoins(_m.bet)}'),
                    onPressed: _spinning || (_m.freeSpins == 0 && !_app.wallet.canAfford(_m.bet)) ? null : _go,
                  ),
                  if (offer == ArcadeOffer.nudge) ActionButton(label: 'Nicht schieben', onPressed: _skipNudge),
                ]),
              ],
            ],
          ),
        );
      }),
    );
  }

  /// Sichtbare Symbole einer Walze (oben, Linie, unten) und eins darunter für die Bewegung.
  List<int> _visible(int r) {
    final strip = arcadeStrips[r];
    final n = strip.length;
    final base = _spinning ? _rolling(r) : _m.pos[r];
    return [for (var k = -1; k <= 2; k++) strip[((base.floor() + k) % n + n) % n]];
  }

  /// Walze r läuft und hält gestaffelt an.
  double _rolling(int r) {
    if (_m.held.contains(r)) return _m.pos[r].toDouble();
    final stop = 0.55 + r * 0.2;
    final t = (_spin.value / stop).clamp(0.0, 1.0);
    final n = arcadeStrips[r].length;
    // Rückwärts von der Endstellung aus gerechnet, damit sie genau dort stehen bleibt
    final travel = (2 + r) * n + ((_m.pos[r] - _from[r]) % n + n) % n;
    final eased = Curves.easeOut.transform(t);
    return _from[r] + eased * travel;
  }

  double _shift(int r) => _spinning ? _rolling(r) - _rolling(r).floor() : 0;
}

class _Reel extends StatelessWidget {
  const _Reel({required this.width, required this.symbols, required this.shift, required this.held});
  final double width;
  final List<int> symbols;
  final double shift;
  final bool held;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 3,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: held ? const Color(0xFF00E5FF) : const Color(0xFF5D4037), width: held ? 4 : 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _ReelPainter(symbols, shift)),
    );
  }
}

class _ReelPainter extends CustomPainter {
  _ReelPainter(this.symbols, this.shift);
  final List<int> symbols;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height / 3;
    for (var i = 0; i < symbols.length; i++) {
      final top = (i - shift) * h;
      paintArcadeSymbol(canvas, Rect.fromLTWH(0, top, size.width, h).deflate(h * 0.08), symbols[i]);
    }
    // Gewinnlinie
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
      ..color = const Color(0x99D32F2F)
      ..strokeWidth = 2);
    // Oben und unten abdunkeln
    final shade = Paint()..color = const Color(0x33000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, h * 0.9), shade);
    canvas.drawRect(Rect.fromLTWH(0, size.height - h * 0.9, size.width, h * 0.9), shade);
  }

  @override
  bool shouldRepaint(_ReelPainter old) => old.shift != shift || old.symbols.join() != symbols.join();
}

/// Symbole des Automaten: Früchte wie im Früchtekorb, dazu Stern und Sieben.
void paintArcadeSymbol(Canvas canvas, Rect rect, int symbol) {
  switch (symbol) {
    case arcadeStar:
      final r = squareIn(rect);
      shaded(canvas, starPath(r.center, r.width * 0.42), const Color(0xFFFFF176), const Color(0xFFF9A825));
    case arcadeSeven:
      paintLosSymbol(canvas, rect, 'Sieben');
    default:
      paintFruchtSymbol(canvas, rect, symbol);
  }
}

/// Risikoleiter: Gewinn × 2 je Stufe.
class _LadderView extends StatelessWidget {
  const _LadderView({required this.base, required this.step, required this.active, required this.flash, required this.height});
  final int base;
  final int step;
  final bool active;
  final int flash;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: height,
      child: Column(
        children: [
          for (var i = arcadeLadderSteps; i >= 0; i--)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !active
                      ? const Color(0xFF2A0A22)
                      : i == step || (flash >= 0 && i == step + 1 && flash.isOdd)
                          ? const Color(0xFFFFC95C)
                          : (i < step ? const Color(0xFF6D4C41) : const Color(0xFF2A0A22)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF8D6E63)),
                ),
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(active ? formatCoins(base << i) : '×${1 << i}',
                        style: TextStyle(color: active && i == step ? Colors.black : const Color(0xFFF6E7C8), fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
