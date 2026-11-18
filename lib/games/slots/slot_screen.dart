import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/widgets.dart';
import 'slot_engine.dart';
import 'slot_games.dart';
import 'slot_log.dart';
import 'slot_wheel.dart';

class SlotScreen extends StatefulWidget {
  const SlotScreen({super.key, required this.game, this.seed});

  final SlotGame game;

  /// Fester Startwert für den Zufall (Tests und Vorschaubilder), sonst sicherer Zufall.
  final int? seed;

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

/// Was das Walzenfenster gerade zeigt, wenn die Walzen stehen.
class _Shown {
  const _Shown({required this.grid, required this.wins, this.falls, this.coins = const {}, this.multiplier = 1, this.sticky = const {}});
  final List<List<int>> grid;

  /// Liegenbleibende Joker der laufenden Freispiele.
  final Set<(int, int)> sticky;
  final List<LineWin> wins;
  final List<List<int>>? falls;
  final Map<int, int> coins;
  final int multiplier;
}

/// Stand einer Hold-&-Spin-Runde im Walzenfenster.
class _HoldView {
  const _HoldView(this.coins, this.respins, this.fresh);
  final Map<int, int> coins;
  final int respins;
  final Set<int> fresh;
}

class _SlotScreenState extends State<SlotScreen> with TickerProviderStateMixin {
  late final SlotEngine _engine = SlotEngine(_rules, rng: widget.seed == null ? null : math.Random(widget.seed));
  final _rng = math.Random();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  /// Zeitbasis der Hintergründe: ein Durchlauf dauert backdropLoop, alle Bewegungen darin sind ganze Zyklen.
  late final AnimationController _ambient = AnimationController(vsync: this, duration: backdropLoop)..repeat();
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  /// Welcher Gewinn gerade hervorgehoben ist. Wechselt im Takt der Einstellung „Gewinne wechseln alle“.
  final _winIndex = ValueNotifier<int>(0);
  Timer? _winTimer;

  late int _stake = widget.game.stakes[2];
  int _freeSpins = 0;
  int _freeTotal = 0;
  bool _spinning = false;
  bool _auto = false;
  String _message = 'Einsatz wählen und drehen';
  bool _big = false;
  _Shown? _shown;
  _HoldView? _hold;
  late int _reelsStopped = _rules.reels;

  /// Sichtbare Symbole vor dem Dreh und die Bänder, die durchlaufen.
  late List<List<int>> _tapes = [
    for (var r = 0; r < _rules.reels; r++) _rules.strips[r].take(_rules.rows).toList(),
  ];

  /// Reihen je Walze im Ergebnis (bei wechselnder Höhe verschieden).
  late List<int> _heights = List.filled(_rules.reels, _rules.rows);

  SlotRules get _rules => widget.game.rules;
  List<int> get _stakes => widget.game.stakes;

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
    _ambient.dispose();
    _winTimer?.cancel();
    _winIndex.dispose();
    _drop.dispose();
    super.dispose();
  }

  void _onTick() {
    var stopped = 0;
    for (var r = 0; r < _rules.reels; r++) {
      if (reelProgress(_spin.value, r, _rules.reels) >= 1) stopped++;
    }
    if (stopped != _reelsStopped) {
      if (stopped > _reelsStopped) _app.sfx.play(Sound.reelStop);
      _reelsStopped = stopped;
    }
  }

  List<int> _buildTape(List<int> finalSymbols, int reel) {
    final strip = _rules.strips[reel];
    final filler = 14 + reel * 4;
    final start = _rng.nextInt(strip.length);
    return [
      ...finalSymbols,
      for (var i = 0; i < filler; i++) strip[(start + i) % strip.length],
      ..._tapes[reel].take(_heights[reel]),
    ];
  }

  /// Beginnt die Gewinnanzeige wieder beim ersten Gewinn.
  void _restartWinCycle() {
    _winTimer?.cancel();
    _winIndex.value = 0;
    void tick() {
      _winTimer = Timer(Duration(milliseconds: _app.settings.slotWinMs), () {
        if (!mounted) return;
        _winIndex.value++;
        tick();
      });
    }

    tick();
  }

  Future<void> _pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _go() async {
    if (_spinning) return;
    final free = _freeSpins > 0;
    if (!free && !_app.wallet.spend(_stake)) {
      setState(() => _auto = false);
      return;
    }
    final wallet = _app.wallet;
    final stake = _stake;
    final out = _engine.play(stake, free: free);
    final first = out.steps.first;
    var credited = false;
    void credit() {
      if (credited) return;
      credited = true;
      wallet.credit(out.total);
      logSlotOutcome(widget.game, out, stake: stake, free: free, balance: wallet.balance);
    }

    setState(() {
      if (free) _freeSpins--;
      _spinning = true;
      _shown = null;
      _hold = null;
      _big = false;
      _message = free ? widget.game.freeSpinLine : '';
      _reelsStopped = 0;
      _tapes = [for (var r = 0; r < _rules.reels; r++) _buildTape(first.grid[r], r)];
      _heights = out.heights;
    });
    _app.sfx.play(Sound.tick);
    try {
      await _spin.forward(from: 0).orCancel;

      // Kaskaden Stufe für Stufe
      var running = 0;
      for (var i = 0; i < out.steps.length; i++) {
        final s = out.steps[i];
        if (!mounted) break;
        setState(() {
          _restartWinCycle();
          _shown = _Shown(
            grid: s.grid,
            wins: s.wins,
            falls: s.falls,
            coins: i == 0 ? out.coins : const {},
            multiplier: s.multiplier,
            sticky: free && _rules.stickyWildsInFree ? {..._engine.stickyWilds} : const {},
          );
        });
        if (i > 0) {
          await _drop.forward(from: 0).orCancel;
          _app.sfx.play(Sound.reelStop);
        }
        running += s.win;
        if (s.win > 0) {
          setState(() {
            _message = out.steps.length > 1
                ? 'Kaskade ${i + 1}${s.multiplier > 1 ? ' ×${s.multiplier}' : ''}: +${formatCoins(running)}'
                : 'Gewonnen: +${formatCoins(running)}';
            _big = true;
          });
          _app.sfx.play(Sound.win);
          if (i < out.steps.length - 1) await _pause(1100);
        }
      }

      // Glücksrad
      final wheel = out.wheel;
      if (wheel != null && mounted) {
        setState(() => _message = 'Glücksrad!');
        _app.sfx.play(Sound.bigWin);
        await _pause(700);
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BonusWheelScreen(game: widget.game, wheel: _rules.wheel!, spin: wheel, stake: stake),
            ),
          );
        }
      }

      // Hold & Spin
      final hold = out.holdSpin;
      if (hold != null && mounted) {
        setState(() => _message = 'Hold & Spin!');
        _app.sfx.play(Sound.bigWin);
        Map<int, int> prev = const {};
        for (var i = 0; i < hold.boards.length; i++) {
          if (!mounted) break;
          final board = hold.boards[i];
          setState(() {
            _hold = _HoldView(board, hold.respinsLeft[i], {for (final c in board.keys) if (!prev.containsKey(c)) c});
            final sum = board.values.fold(0, (a, b) => a + b) * stake ~/ 10;
            _message = 'Hold & Spin: ${formatCoins(sum)}  ·  Respins ${hold.respinsLeft[i]}';
          });
          if (i > 0 && board.length > prev.length) _app.sfx.play(Sound.win);
          prev = board;
          await _pause(i == 0 ? 1200 : 750);
        }
        if (mounted) {
          setState(() => _message = hold.full
              ? 'GRAND! Hold & Spin: +${formatCoins(hold.total)}'
              : 'Hold & Spin: +${formatCoins(hold.total)}');
          await _pause(1500);
        }
      }
    } on TickerCanceled {
      // Bildschirm wurde verlassen, der Gewinn zählt trotzdem.
    } finally {
      credit();
    }
    if (!mounted) {
      wallet.refillIfBroke();
      return;
    }
    setState(() {
      _spinning = false;
      _hold = null;
      _freeSpins += out.freeSpinsWon;
      if (free || out.freeSpinsWon > 0) _freeTotal += out.total;
      _message = _describe(out);
      _big = out.total > 0 || out.freeSpinsWon > 0;
    });
    if (out.freeSpinsWon > 0 || out.total >= stake * 10) {
      _app.sfx.play(Sound.bigWin);
    } else if (out.total > 0 && out.steps.length == 1) {
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
      setState(() => _stake = _stakes.first);
    }
    if (_freeSpins > 0 || _auto) {
      // Pause aus den Einstellungen; nach einem Gewinn so lange, bis jeder Gewinn einmal zu sehen war
      final shownWins = _shown?.wins.length ?? 0;
      final ms = math.max(_app.settings.slotAutoMs, math.min(shownWins * _app.settings.slotWinMs, 15000));
      await _pause(ms);
      if (mounted && (_freeSpins > 0 || _auto)) _go();
    }
  }

  String _describe(SpinOutcome r) {
    if (r.freeSpinsWon > 0) {
      return '${r.freeSpinsWon} Freispiele! +${formatCoins(r.total)}';
    }
    if (r.total == 0) return _freeSpins > 0 ? 'Noch $_freeSpins Freispiele' : '';
    return 'Gewonnen: +${formatCoins(r.total)}';
  }

  void _showPayTable() => showSlotPayTable(context, widget.game, _stake);

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      guide: slotGuide(widget.game),
      title: widget.game.name,
      background: widget.game.background,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.3;
          final controlsHeight = wide ? 0.0 : 190.0;
          final maxW = box.maxWidth - (wide ? math.min(300.0, box.maxWidth * 0.32) : 0) - 24;
          // Platz für die Zeile mit der gerade gezeigten Gewinnlinie
          final maxH = box.maxHeight - controlsHeight - 24 - 30;
          final cell = math.min(maxW / _rules.reels, maxH / _rules.rows);
          final reelWindow = _ReelWindow(
            cell: cell,
            spin: _spin,
            pulse: _pulse,
            ambient: _ambient,
            winIndex: _winIndex,
            drop: _drop,
            tapes: _tapes,
            heights: _heights,
            shown: _shown,
            hold: _hold,
            stake: _stake,
            game: widget.game,
          );
          final reels = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              reelWindow,
              const SizedBox(height: 6),
              _LineCaption(winIndex: _winIndex, shown: _hold == null ? _shown : null, game: widget.game),
            ],
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
              // Auf sehr kleinen Bildschirmen lieber etwas verkleinern als abschneiden
              Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: reels))),
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
              onPressed: locked || _stake == _stakes.first
                  ? null
                  : () => setState(() {
                        _stake = _stakes[_stakes.indexOf(_stake) - 1];
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
                      _stake == _stakes.last ||
                      !_app.wallet.canAfford(
                        _stakes[_stakes.indexOf(_stake) + 1],
                      )
                  ? null
                  : () => setState(() {
                        _stake = _stakes[_stakes.indexOf(_stake) + 1];
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

/// Gewinnplan eines Slots für den gewählten Einsatz.
void showSlotPayTable(BuildContext context, SlotGame game, int stake) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PayTableSheet(game: game, stake: stake),
  );
}

/// Fortschritt einer Walze bei Gesamtzeit t. Walzen halten nacheinander.
double reelProgress(double t, int reel, int reels) {
  final end = 0.55 + 0.45 * reel / (reels - 1);
  return (t / end).clamp(0.0, 1.0);
}

class _ReelWindow extends StatelessWidget {
  const _ReelWindow({
    required this.cell,
    required this.spin,
    required this.pulse,
    required this.ambient,
    required this.winIndex,
    required this.drop,
    required this.tapes,
    required this.heights,
    required this.shown,
    required this.hold,
    required this.stake,
    required this.game,
  });

  final SlotGame game;
  final double cell;
  final Animation<double> spin;
  final Animation<double> pulse;
  final Animation<double> ambient;
  final ValueListenable<int> winIndex;
  final Animation<double> drop;
  final List<List<int>> tapes;
  final List<int> heights;
  final _Shown? shown;
  final _HoldView? hold;
  final int stake;

  @override
  Widget build(BuildContext context) {
    final width = cell * game.rules.reels;
    final height = cell * game.rules.rows;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: game.frame,
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
              ambient: ambient,
              winIndex: winIndex,
              drop: drop,
              tapes: tapes,
              heights: heights,
              shown: shown,
              hold: hold,
              stake: stake,
              game: game,
            ),
          ),
        ),
      ),
    );
  }
}

const _gold = Color(0xFFFFC95C);

/// Wert einer Münze als Text: Jackpot-Name oder Betrag.
String coinLabel(SlotRules rules, int tenths, int stake) =>
    rules.holdSpin?.jackpots[tenths]?.toUpperCase() ?? formatCoins(tenths * stake ~/ 10);

void _paintLabel(Canvas canvas, Rect box, String text, {double scale = 0.24}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: bodyFont,
        color: Colors.white,
        fontSize: box.height * scale,
        fontWeight: FontWeight.w900,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: box.width * 1.1);
  tp.paint(canvas, Offset(box.center.dx - tp.width / 2, box.bottom - tp.height - box.height * 0.04));
}

class _ReelPainter extends CustomPainter {
  _ReelPainter({
    required this.spin,
    required this.pulse,
    required this.ambient,
    required this.winIndex,
    required this.drop,
    required this.tapes,
    required this.heights,
    required this.shown,
    required this.hold,
    required this.stake,
    required this.game,
  }) : super(repaint: Listenable.merge([spin, pulse, ambient, drop, winIndex]));

  final SlotGame game;
  final Animation<double> spin;
  final Animation<double> pulse;
  final Animation<double> ambient;
  final ValueListenable<int> winIndex;
  final Animation<double> drop;
  final List<List<int>> tapes;
  final List<int> heights;
  final _Shown? shown;
  final _HoldView? hold;
  final int stake;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rules = game.rules;
    final reels = rules.reels;
    game.paintBackdrop(canvas, rect, ambient.value);
    final cw = size.width / reels;

    final h = hold;
    if (h != null) {
      _paintHold(canvas, size, h);
      return;
    }

    final s = shown;
    for (var r = 0; r < reels; r++) {
      final rows = s?.grid[r].length ?? heights[r];
      final ch = size.height / rows;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(r * cw, 0, cw, size.height));
      if (s == null) {
        final tape = tapes[r];
        final travel = (tape.length - rows).toDouble();
        final p = reelProgress(spin.value, r, reels);
        // Band läuft vom alten Bild am Ende zum neuen Bild am Anfang
        final eased = p >= 1 ? 1.0 : Curves.easeOutCubic.transform(p);
        final offset = travel * (1 - eased);
        final first = offset.floor();
        for (var i = math.max(0, first - 1); i < tape.length && i <= first + rows; i++) {
          final y = (i - offset) * ch;
          game.paintSymbol(canvas, _cell(r * cw, y, cw, ch), tape[i]);
        }
      } else {
        final t = Curves.easeIn.transform(drop.value);
        for (var row = 0; row < rows; row++) {
          final fall = s.falls?[r][row] ?? 0;
          final y = (row - fall * (1 - t)) * ch;
          final box = _cell(r * cw, y, cw, ch);
          game.paintSymbol(canvas, box, s.grid[r][row]);
          final coin = s.coins[r * rules.rows + row];
          if (coin != null) _paintLabel(canvas, box, coinLabel(rules, coin, stake));
        }
      }
      canvas.restore();
      if (r > 0) {
        canvas.drawLine(
          Offset(r * cw, 0),
          Offset(r * cw, size.height),
          Paint()
            ..color = const Color(0x44FFE9A8)
            ..strokeWidth = 1,
        );
      }
    }

    if (s == null || drop.value < 1) return;
    if (s.wins.isNotEmpty) {
      final index = winIndex.value % s.wins.length;
      _paintWin(canvas, s, s.wins[index], cw, size.height);
    }
    // Liegende Joker in Freispielen rosa umranden
    final stickyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFFFF2E88);
    for (final (r, row) in s.sticky) {
      if (row >= s.grid[r].length) continue;
      final ch = size.height / s.grid[r].length;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(6), const Radius.circular(12)), stickyPaint);
    }
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFE9A8);
    // Streu- und Bonussymbole nur umranden, wenn genug für die Funktion liegen
    final flat = s.grid.expand((c) => c);
    final ringScatter = flat.where((x) => x == symScatter).length >= 3;
    final ringBonus = flat.where((x) => x == symBonus).length >= (game.rules.wheel?.trigger ?? 3);
    for (var r = 0; r < reels; r++) {
      final ch = size.height / s.grid[r].length;
      for (var row = 0; row < s.grid[r].length; row++) {
        final sym = s.grid[r][row];
        if ((sym == symScatter && ringScatter) || (sym == symBonus && ringBonus)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(3), const Radius.circular(10)),
            ringPaint,
          );
        }
      }
    }
  }

  /// Feld für ein Symbol: quadratisch in der Mitte der Zelle.
  Rect _cell(double x, double y, double cw, double ch) {
    final side = math.min(cw, ch);
    return Rect.fromCenter(center: Offset(x + cw / 2, y + ch / 2), width: side, height: side).deflate(side * 0.07);
  }

  void _paintHold(Canvas canvas, Size size, _HoldView h) {
    final rules = game.rules;
    final cw = size.width / rules.reels;
    final ch = size.height / rules.rows;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x99000000));
    final empty = Paint()..color = const Color(0x22FFFFFF);
    final pop = Curves.elasticOut.transform((pulse.value * 3).clamp(0.0, 1.0));
    for (var r = 0; r < rules.reels; r++) {
      for (var row = 0; row < rules.rows; row++) {
        final cell = Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(5);
        final v = h.coins[r * rules.rows + row];
        if (v == null) {
          canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(10)), empty);
          continue;
        }
        final box = h.fresh.contains(r * rules.rows + row)
            ? Rect.fromCenter(center: cell.center, width: cell.width * (0.7 + 0.3 * pop), height: cell.height * (0.7 + 0.3 * pop))
            : cell;
        game.paintSymbol(canvas, _cell(box.left, box.top, box.width, box.height), symCoin);
        _paintLabel(canvas, box, coinLabel(rules, v, stake));
      }
    }
    // Die Respins stehen in der Meldung unter dem Walzenfenster.
  }

  void _paintWin(Canvas canvas, _Shown s, LineWin win, double cw, double height) {
    final rules = game.rules;
    if (win.line >= 0) {
      final rows = rules.lines[win.line];
      final ch = height / rules.rows;
      final path = Path();
      for (var r = 0; r < rules.reels; r++) {
        final c = Offset((r + 0.5) * cw, (rows[r] + 0.5) * ch);
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
    }
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _gold;
    for (final (r, row) in win.cells) {
      final ch = height / s.grid[r].length;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(3), const Radius.circular(10)),
        frame,
      );
    }
  }

  @override
  bool shouldRepaint(_ReelPainter old) =>
      old.tapes != tapes || old.shown != shown || old.hold != hold || old.heights != heights;
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter(this.game, this.symbol);
  final SlotGame game;
  final int symbol;

  @override
  void paint(Canvas canvas, Size size) => game.paintSymbol(canvas, Offset.zero & size, symbol);

  @override
  bool shouldRepaint(_SymbolPainter old) => old.symbol != symbol;
}

/// Ein Gewinn als Text, z. B. „Linie 16: 3 × Seepferdchen = 40“ oder „3 × Seestern, 4 Wege = 12“.
String winText(SlotGame game, LineWin w, {int multiplier = 1}) {
  final head = w.line >= 0 ? 'Linie ${w.line + 1}: ' : '';
  final ways = w.line < 0 ? ', ${w.ways} ${w.ways == 1 ? 'Weg' : 'Wege'}' : '';
  final from = w.line < 0 && w.start > 0 ? ' ab Walze ${w.start + 1}' : '';
  final mult = multiplier > 1 ? ' ×$multiplier' : '';
  return '$head${w.count} × ${game.symbolNames[w.symbol]}$from$ways$mult = ${formatCoins(w.payout)}';
}

/// Text zum Gewinn, der gerade aufleuchtet.
class _LineCaption extends StatelessWidget {
  const _LineCaption({required this.winIndex, required this.shown, required this.game});

  final ValueListenable<int> winIndex;
  final _Shown? shown;
  final SlotGame game;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 24,
      child: AnimatedBuilder(
        animation: winIndex,
        builder: (context, _) {
          final s = shown;
          if (s == null || s.wins.isEmpty) return const SizedBox.shrink();
          // Gleiche Auswahl wie der aufleuchtende Gewinn im Walzenfenster
          final index = winIndex.value % s.wins.length;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${winText(game, s.wins[index], multiplier: s.multiplier)}'
              '${s.wins.length > 1 ? '   (${index + 1}/${s.wins.length})' : ''}',
              style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}

/// Kleines Bild einer Gewinnlinie: Raster aus Reihen und Walzen, die Linie hervorgehoben.
class _LineDiagramPainter extends CustomPainter {
  _LineDiagramPainter(this.line, this.rows, this.ink, this.accent);

  final List<int> line;
  final int rows;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final reels = line.length;
    final cw = size.width / reels;
    final ch = size.height / rows;
    final dim = Paint()..color = ink.withValues(alpha: 0.18);
    final hit = Paint()..color = accent;
    for (var r = 0; r < reels; r++) {
      for (var row = 0; row < rows; row++) {
        final cell = Rect.fromLTWH(r * cw, row * ch, cw, ch).deflate(1.5);
        canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(2)), line[r] == row ? hit : dim);
      }
    }
  }

  @override
  bool shouldRepaint(_LineDiagramPainter old) => old.line != line || old.ink != ink || old.accent != accent;
}

class _PayTableSheet extends StatelessWidget {
  const _PayTableSheet({required this.game, required this.stake});
  final SlotGame game;
  final int stake;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rules = game.rules;
    final ways = rules.mode == PayMode.ways;
    final style = TextStyle(color: p.ink, fontSize: 16);
    final soft = style.copyWith(fontSize: 14, color: p.inkSoft);
    String amount(int pay) {
      final v = pay * stake / rules.betDivisor;
      return v == v.roundToDouble() ? formatCoins(v.round()) : v.toStringAsFixed(1).replaceAll('.', ',');
    }

    Widget symbolRow(int sym, Widget text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox.square(dimension: 46, child: CustomPaint(painter: _SymbolPainter(game, sym))),
              const SizedBox(width: 10),
              Expanded(child: text),
            ],
          ),
        );

    final paySymbols = [
      if (!ways && rules.linePays.containsKey(symWild)) symWild,
      for (var s = 5; s >= 0; s--)
        if (rules.linePays.containsKey(s)) s,
    ];
    final hold = rules.holdSpin;
    final wheel = rules.wheel;
    final hasWild = rules.strips.any((s) => s.contains(symWild));
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
              ways
                  ? 'Einsatz ${formatCoins(stake)}. Beträge gelten je Weg: gleiche Symbole auf mindestens drei '
                      'nebeneinanderliegenden Walzen, egal in welcher Reihe'
                      '${rules.waysAnywhere ? ' und ab welcher Walze' : ', ab der ersten Walze'}. '
                      'Liegen auf einer Walze zwei passende Symbole, gibt es doppelt so viele Wege.'
                  : 'Einsatz ${formatCoins(stake)} auf ${rules.lineCount} Linien. Gewertet wird von links nach rechts.',
              style: TextStyle(color: p.inkSoft, fontSize: 15),
            ),
            const SizedBox(height: 10),
            for (final sym in paySymbols)
              symbolRow(
                sym,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.symbolNames[sym], style: style.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        for (var i = 0; i < rules.linePays[sym]!.length; i++)
                          '${i + 3} gleiche: ${amount(rules.linePays[sym]![i])}',
                      ].join(', '),
                      style: soft,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            if (rules.hasScatter)
              symbolRow(symScatter, Text(game.featureText, style: style))
            else
              Text(game.featureText, style: style),
            const SizedBox(height: 8),
            if (hasWild) symbolRow(symWild, Text(game.wildText, style: style)),
            if (rules.cascades) ...[
              const SizedBox(height: 12),
              Text('Kaskaden', style: style.copyWith(fontWeight: FontWeight.w700)),
              Text(
                'Gewinnsymbole verschwinden, neue fallen von oben nach. Jeder weitere Gewinn derselben Drehung zählt mehr: '
                '${rules.cascade.map((m) => '×$m').join(', ')}'
                '${rules.freeCascade.isNotEmpty ? ', in Freispielen ${rules.freeCascade.map((m) => '×$m').join(', ')}' : ''}.',
                style: soft,
              ),
            ],
            if (hold != null) ...[
              const SizedBox(height: 12),
              symbolRow(
                symCoin,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hold & Spin', style: style.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${hold.trigger} oder mehr ${game.symbolNames[symCoin]} starten die Runde. Münzen bleiben liegen, '
                      'es gibt ${hold.respins} Respins, jede neue Münze setzt sie zurück. Am Ende zählen alle Münzwerte. '
                      'Jackpots: ${[for (final e in hold.jackpots.entries) '${e.value} ${formatCoins(e.key * stake ~/ 10)}'].join(', ')}, '
                      'alle Felder voll: Grand ${formatCoins(hold.grand * stake ~/ 10)}.',
                      style: soft,
                    ),
                  ],
                ),
              ),
            ],
            if (wheel != null) ...[
              const SizedBox(height: 12),
              symbolRow(
                symBonus,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Glücksrad', style: style.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      '${wheel.trigger} ${game.symbolNames[symBonus]} drehen das Glücksrad. Felder: '
                      '${[
                        for (final s in wheel.segments)
                          switch (s.kind) {
                            WheelKind.coins => formatCoins(s.amount * stake),
                            WheelKind.freeSpins => '${s.amount} Freispiele',
                            WheelKind.holdSpin => 'Hold & Spin mit ${s.amount} Münzen',
                          },
                      ].toSet().join(', ')}.',
                      style: soft,
                    ),
                  ],
                ),
              ),
            ],
            if (!ways) ...[
              const SizedBox(height: 16),
              Text('Gewinnlinien', style: style.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Nur diese ${rules.lineCount} Linien zahlen. Die gleichen Symbole müssen auf der ersten Walze links beginnen '
                'und ohne Lücke nebeneinander liegen.',
                style: soft,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var l = 0; l < rules.lines.length; l++)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64 * rules.rows / rules.reels,
                          child: CustomPaint(
                            painter: _LineDiagramPainter(rules.lines[l], rules.rows, p.ink, p.accent),
                          ),
                        ),
                        Text('${l + 1}', style: soft.copyWith(fontSize: 13)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
