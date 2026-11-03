import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'kosmos_art.dart';
import 'slot_data.dart';
import 'slot_engine.dart';

const List<int> slotStakes = [10, 20, 50, 100, 200, 500];

const Map<int, String> symbolNames = {
  symMond: 'Mond',
  symStern: 'Stern',
  symKomet: 'Komet',
  symPlanet: 'Planet',
  symUfo: 'Ufo',
  symRakete: 'Rakete',
  symSonne: 'Sonne',
  symLoch: 'Schwarzes Loch',
};

class SlotScreen extends StatefulWidget {
  const SlotScreen({super.key});

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

class _SlotScreenState extends State<SlotScreen> with TickerProviderStateMixin {
  final _engine = SlotEngine();
  final _rng = math.Random();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  int _stake = 50;
  int _freeSpins = 0;
  int _freeTotal = 0;
  bool _spinning = false;
  bool _auto = false;
  String _message = 'Einsatz wählen und drehen';
  bool _big = false;
  SpinResult? _result;
  int _reelsStopped = reelCount;

  /// Sichtbare Symbole vor dem Dreh und die Bänder, die durchlaufen.
  late List<List<int>> _tapes = [
    for (var r = 0; r < reelCount; r++) kosmosStrips[r].take(rowCount).toList(),
  ];

  AppScope get _app => AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _spin.addListener(_onTick);
  }

  @override
  void dispose() {
    _auto = false;
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onTick() {
    var stopped = 0;
    for (var r = 0; r < reelCount; r++) {
      if (reelProgress(_spin.value, r) >= 1) stopped++;
    }
    if (stopped != _reelsStopped) {
      if (stopped > _reelsStopped) _app.sfx.play(Sound.reelStop);
      _reelsStopped = stopped;
    }
  }

  List<int> _buildTape(List<int> finalSymbols, int reel) {
    final strip = kosmosStrips[reel];
    final filler = 14 + reel * 4;
    final start = _rng.nextInt(strip.length);
    return [
      ...finalSymbols,
      for (var i = 0; i < filler; i++) strip[(start + i) % strip.length],
      ..._tapes[reel].take(rowCount),
    ];
  }

  Future<void> _go() async {
    if (_spinning) return;
    final free = _freeSpins > 0;
    if (!free && !_app.wallet.spend(_stake)) {
      setState(() => _auto = false);
      return;
    }
    final wallet = _app.wallet;
    final result = _engine.spin(
      _stake,
      multiplier: free ? freeSpinMultiplier : 1,
    );
    setState(() {
      if (free) _freeSpins--;
      _spinning = true;
      _result = null;
      _big = false;
      _message = free ? 'Freispiel, alle Gewinne doppelt' : '';
      _reelsStopped = 0;
      _tapes = [
        for (var r = 0; r < reelCount; r++) _buildTape(result.grid[r], r),
      ];
    });
    _app.sfx.play(Sound.tick);
    try {
      await _spin.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Bildschirm wurde verlassen, der Gewinn zählt trotzdem.
    }
    wallet.credit(result.total);
    if (!mounted) {
      wallet.refillIfBroke();
      return;
    }
    setState(() {
      _spinning = false;
      _result = result;
      _freeSpins += result.freeSpinsWon;
      if (free || result.freeSpinsWon > 0) _freeTotal += result.total;
      _message = _describe(result);
      _big = result.total > 0 || result.freeSpinsWon > 0;
    });
    if (result.freeSpinsWon > 0 || result.total >= _stake * 10) {
      _app.sfx.play(Sound.bigWin);
    } else if (result.total > 0) {
      _app.sfx.play(Sound.win);
    }
    if (_freeSpins == 0 && free) {
      setState(() {
        _message = 'Freispiele vorbei: +${formatCoins(_freeTotal)}';
        _freeTotal = 0;
      });
    }
    wallet.refillIfBroke();
    if (_stake > wallet.balance && _freeSpins == 0) {
      setState(() => _stake = 10);
    }
    if (_freeSpins > 0 || _auto) {
      await Future<void>.delayed(
        Duration(milliseconds: result.total > 0 ? 1600 : 700),
      );
      if (mounted && (_freeSpins > 0 || _auto)) _go();
    }
  }

  String _describe(SpinResult r) {
    if (r.freeSpinsWon > 0) {
      return '$freeSpinsAward Freispiele! +${formatCoins(r.total)}';
    }
    if (r.total == 0) return _freeSpins > 0 ? 'Noch $_freeSpins Freispiele' : '';
    return 'Gewonnen: +${formatCoins(r.total)}';
  }

  void _showPayTable() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PayTableSheet(stake: _stake),
    );
  }

  static const _sky = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF120A33), Color(0xFF3A1467), Color(0xFFA32A6E)],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Kosmos 78',
      background: _sky,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.3;
          final controlsHeight = wide ? 0.0 : 190.0;
          final maxW = box.maxWidth - (wide ? math.min(300.0, box.maxWidth * 0.32) : 0) - 24;
          final maxH = box.maxHeight - controlsHeight - 24;
          // Fünf Walzen zu drei Reihen plus Rahmen
          final cell = math.min(maxW / reelCount, maxH / rowCount);
          final reels = _ReelWindow(
            cell: cell,
            spin: _spin,
            pulse: _pulse,
            tapes: _tapes,
            result: _result,
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: Center(child: reels)),
                SizedBox(
                  width: math.min(300, box.maxWidth * 0.32),
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
              Expanded(child: Center(child: reels)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _controls(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _controls() {
    final locked = _spinning || _freeSpins > 0 || _auto;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBanner(text: _message, highlight: _big),
        if (_freeSpins > 0)
          Text(
            'Noch $_freeSpins Freispiele',
            style: const TextStyle(
              color: Color(0xFFFFE9A8),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: 'Einsatz senken',
              onPressed: locked || _stake == slotStakes.first
                  ? null
                  : () => setState(() {
                        _stake = slotStakes[slotStakes.indexOf(_stake) - 1];
                      }),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 120,
              child: Text(
                'Einsatz ${formatCoins(_stake)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Einsatz erhöhen',
              onPressed: locked ||
                      _stake == slotStakes.last ||
                      !_app.wallet.canAfford(
                        slotStakes[slotStakes.indexOf(_stake) + 1],
                      )
                  ? null
                  : () => setState(() {
                        _stake = slotStakes[slotStakes.indexOf(_stake) + 1];
                      }),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionButton(
              primary: true,
              label: 'Drehen',
              onPressed: locked ? null : _go,
            ),
            ActionButton(
              label: _auto ? 'Automatik stoppen' : 'Automatik',
              onPressed: _freeSpins > 0
                  ? null
                  : () {
                      setState(() => _auto = !_auto);
                      if (_auto && !_spinning) _go();
                    },
            ),
            ActionButton(label: 'Gewinnplan', onPressed: _showPayTable),
          ],
        ),
      ],
    );
  }
}

/// Fortschritt einer Walze bei Gesamtzeit t. Walzen halten nacheinander.
double reelProgress(double t, int reel) {
  final end = 0.55 + 0.45 * reel / (reelCount - 1);
  return (t / end).clamp(0.0, 1.0);
}

class _ReelWindow extends StatelessWidget {
  const _ReelWindow({
    required this.cell,
    required this.spin,
    required this.pulse,
    required this.tapes,
    required this.result,
  });

  final double cell;
  final Animation<double> spin;
  final Animation<double> pulse;
  final List<List<int>> tapes;
  final SpinResult? result;

  @override
  Widget build(BuildContext context) {
    final width = cell * reelCount;
    final height = cell * rowCount;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD98A), Color(0xFFC4391F), Color(0xFF5A1B6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _ReelPainter(
              spin: spin,
              pulse: pulse,
              tapes: tapes,
              result: result,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelPainter extends CustomPainter {
  _ReelPainter({
    required this.spin,
    required this.pulse,
    required this.tapes,
    required this.result,
  }) : super(repaint: Listenable.merge([spin, pulse]));

  final Animation<double> spin;
  final Animation<double> pulse;
  final List<List<int>> tapes;
  final SpinResult? result;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    paintKosmosSky(canvas, rect, pulse.value);
    canvas.drawRect(rect, Paint()..color = const Color(0x55120A33));
    final cell = size.width / reelCount;

    for (var r = 0; r < reelCount; r++) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(r * cell, 0, cell, size.height));
      final tape = tapes[r];
      final travel = (tape.length - rowCount).toDouble();
      final p = reelProgress(spin.value, r);
      // Band läuft vom alten Bild am Ende zum neuen Bild am Anfang
      final eased = p >= 1 ? 1.0 : Curves.easeOutCubic.transform(p);
      final offset = travel * (1 - eased);
      final first = offset.floor();
      for (var i = math.max(0, first - 1); i < tape.length && i <= first + rowCount; i++) {
        final y = (i - offset) * cell;
        final box = Rect.fromLTWH(r * cell, y, cell, cell).deflate(cell * 0.07);
        paintKosmosSymbol(canvas, box, tape[i]);
      }
      canvas.restore();
      if (r > 0) {
        canvas.drawLine(
          Offset(r * cell, 0),
          Offset(r * cell, size.height),
          Paint()
            ..color = const Color(0x44FFE9A8)
            ..strokeWidth = 1,
        );
      }
    }

    final res = result;
    if (res != null && res.lineWins.isNotEmpty) {
      final index = (pulse.value * res.lineWins.length).floor() % res.lineWins.length;
      final win = res.lineWins[index];
      _paintLine(canvas, win, cell);
    }
    if (res != null && res.scatterCount >= 3) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFE9A8);
      for (var r = 0; r < reelCount; r++) {
        for (var row = 0; row < rowCount; row++) {
          if (res.grid[r][row] == symLoch) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(r * cell, row * cell, cell, cell).deflate(3),
                const Radius.circular(10),
              ),
              ringPaint,
            );
          }
        }
      }
    }
  }

  void _paintLine(Canvas canvas, LineWin win, double cell) {
    final rows = paylines[win.line];
    final path = Path();
    for (var r = 0; r < reelCount; r++) {
      final c = Offset((r + 0.5) * cell, (rows[r] + 0.5) * cell);
      r == 0 ? path.moveTo(c.dx, c.dy) : path.lineTo(c.dx, c.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x77FFC95C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF4C2),
    );
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFC95C);
    for (var r = 0; r < win.count; r++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r * cell, rows[r] * cell, cell, cell).deflate(3),
          const Radius.circular(10),
        ),
        frame,
      );
    }
  }

  @override
  bool shouldRepaint(_ReelPainter old) =>
      old.tapes != tapes || old.result != result;
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.symbol);
  final int symbol;

  @override
  void paint(Canvas canvas, Size size) =>
      paintKosmosSymbol(canvas, Offset.zero & size, symbol);

  @override
  bool shouldRepaint(_SymbolPainter old) => old.symbol != symbol;
}

class _PayTableSheet extends StatelessWidget {
  const _PayTableSheet({required this.stake});
  final int stake;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final lineBet = stake ~/ lineCount;
    final style = TextStyle(color: p.ink, fontSize: 16);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          maxWidth: 560,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Gewinnplan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Einsatz ${formatCoins(stake)} auf zehn Linien. Gewertet wird von links nach rechts.',
              style: TextStyle(color: p.inkSoft, fontSize: 15),
            ),
            const SizedBox(height: 10),
            for (final sym in [symSonne, symRakete, symUfo, symPlanet, symKomet, symStern, symMond])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 46,
                      child: CustomPaint(painter: _SymbolPainter(sym)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbolNames[sym]!,
                            style: style.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              for (var i = 0; i < 3; i++)
                                '${i + 3} gleiche: ${formatCoins(linePays[sym]![i] * lineBet)}',
                            ].join(', '),
                            style: style.copyWith(fontSize: 14, color: p.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: 46,
                  child: CustomPaint(painter: _SymbolPainter(symLoch)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Drei oder mehr Schwarze Löcher zahlen das ${scatterPays[0]}-, ${scatterPays[1]}- oder ${scatterPays[2]}-Fache des Einsatzes und starten $freeSpinsAward Freispiele. In Freispielen zählt jeder Gewinn doppelt.',
                    style: style,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Die Sonne ersetzt jedes Symbol außer dem Schwarzen Loch.',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
