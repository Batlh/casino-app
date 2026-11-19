import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import 'lose_art.dart';
import 'lose_engine.dart';

String _odds(List<LosPrize> t) => '1 zu ${(1 / winChance(t)).toStringAsFixed(1).replaceAll('.', ',')}';

GameGuide rubbelGuide() => GameGuide('Rubbellose', [
      const GuideSection(
        'So geht es',
        'Such dir eine Sorte aus und kauf ein Los. Dann rubbelst du die silberne Schicht mit dem Finger oder der Maus frei, '
            'oder tippst auf „Alles aufrubbeln“. Ist genug freigerubbelt, deckt sich der Rest von selbst auf und ein Gewinn wird '
            'gutgeschrieben.',
      ),
      const GuideSection(
        'Zufall',
        'Jedes Los wird erst beim Kauf ausgewürfelt. Es gibt keinen Stapel, der leer wird: Die Chancen sind bei jedem Los gleich, '
            'egal wie viele vorher gekauft wurden. Bei einer Niete sieht man manchmal zwei Gleiche, aber nie drei.',
      ),
      for (final s in rubbelSorten)
        GuideSection(
          '${s.name} (${losAmount(s.price)})',
          '${s.rule} Gewinnchance ${_odds(s.table)}, Hauptgewinn ${losAmount(s.topPrize)}. '
              'Gewinne: ${[for (final p in s.table) '${losAmount(p.amount)} (1 zu ${losAmount(p.oneIn)})'].join(', ')}.',
        ),
    ]);

GameGuide pullGuide() => GameGuide('Pull-Tabs', [
      const GuideSection(
        'So geht es',
        'Pull-Tabs sind Aufreißlose aus den USA. Auf der Rückseite sind fünf Fenster mit Laschen. Reiß sie einzeln auf '
            '(antippen) oder alle auf einmal. Zeigt ein Fenster drei gleiche Symbole, gewinnst du, was auf dem Los für dieses '
            'Symbol steht.',
      ),
      const GuideSection(
        'Zufall',
        'Jedes Los wird beim Kauf ausgewürfelt. Höchstens ein Fenster gewinnt; Nieten haben nie drei gleiche, manchmal aber zwei.',
      ),
      for (final s in pullSorten)
        GuideSection(
          '${s.name} (${losAmount(s.price)})',
          'Gewinnchance ${_odds(s.table)}. ${[for (final e in s.pays.entries) '3 × ${pullSymbole[e.key]}: ${losAmount(e.value.amount * s.price)} (1 zu ${losAmount(e.value.oneIn)})'].join(', ')}.',
        ),
    ]);

/// Gemeinsamer Rahmen: Sortenwahl, Los, Meldung, Knöpfe.
class _LosFrame extends StatelessWidget {
  const _LosFrame({required this.chooser, required this.ticket, required this.message, required this.big, required this.buttons});
  final Widget chooser;
  final Widget ticket;
  final String message;
  final bool big;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 4), child: chooser),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(fit: BoxFit.scaleDown, child: ticket),
              ),
            ),
          ),
          ResultBanner(text: message, highlight: big),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: buttons),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

Widget _chips<T>(List<T> items, T selected, String Function(T) label, void Function(T)? onSelect) => Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final s in items)
          ChoiceChip(label: Text(label(s)), selected: s == selected, onSelected: onSelect == null ? null : (_) => onSelect(s)),
      ],
    );

// ================================================================ Rubbellose

class RubbelScreen extends StatefulWidget {
  const RubbelScreen({super.key, this.seed});
  final int? seed;

  @override
  State<RubbelScreen> createState() => _RubbelScreenState();
}

class _RubbelScreenState extends State<RubbelScreen> {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  RubbelSorte _sorte = rubbelSorten.first;
  RubbelLos? _los;
  final List<Offset> _scratch = [];
  final Set<int> _cells = {};
  bool _revealed = false;
  String _message = 'Sorte wählen und Los kaufen';
  bool _big = false;

  static const _grid = 24;
  static const _radius = 0.075;

  AppScope get _app => AppScope.of(context);

  /// Beim ersten Aufbau festhalten: in dispose gibt es keinen Kontext mehr.
  late final Wallet _wallet = AppScope.of(context).wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet;
  }
  bool get _active => _los != null && !_revealed;

  void _buy() {
    if (!_app.wallet.spend(_sorte.price)) {
      setState(() => _message = 'Nicht genug Münzen');
      return;
    }
    _app.sfx.play(Sound.card);
    setState(() {
      _los = makeRubbelLos(_sorte, _rng);
      _scratch.clear();
      _cells.clear();
      _revealed = false;
      _big = false;
      _message = 'Rubbel frei!';
    });
  }

  void _rub(Offset p, Size size) {
    if (!_active) return;
    final n = Offset(p.dx / size.width, p.dy / size.height);
    setState(() {
      _scratch.add(n);
      for (var gx = 0; gx < _grid; gx++) {
        for (var gy = 0; gy < _grid; gy++) {
          final c = Offset((gx + 0.5) / _grid, (gy + 0.5) / _grid);
          final d = Offset((c.dx - n.dx), (c.dy - n.dy) * size.height / size.width);
          if (d.distance < _radius) _cells.add(gx * _grid + gy);
        }
      }
    });
    if (_cells.length > _grid * _grid * 0.7) _reveal();
  }

  void _reveal() {
    final los = _los;
    if (los == null || _revealed) return;
    final wallet = _app.wallet;
    wallet.credit(los.prize);
    debugLog.info('lose', '${los.sorte.name} für ${los.sorte.price}: ${los.prize > 0 ? 'Gewinn ${los.prize}' : 'Niete'} · Stand ${wallet.balance}');
    setState(() {
      _revealed = true;
      _big = los.prize > 0;
      _message = los.prize > 0 ? 'Gewonnen: +${formatCoins(los.prize)}' : 'Leider eine Niete';
    });
    _app.sfx.play(los.prize >= los.sorte.price * 10 ? Sound.bigWin : (los.prize > 0 ? Sound.win : Sound.lose));
    wallet.refillIfBroke(min: _sorte.price);
  }

  @override
  void dispose() {
    // Ein angefangenes Los wird beim Verlassen aufgedeckt, der Gewinn geht nicht verloren
    final los = _los;
    if (los != null && !_revealed) _wallet.credit(los.prize);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final los = _los;
    final s = los?.sorte ?? _sorte;
    return GameFrame(
      minStake: _sorte.price,
      title: 'Rubbellose',
      guide: rubbelGuide(),
      child: _LosFrame(
        chooser: _chips<RubbelSorte>(rubbelSorten, _sorte, (s) => '${s.name} · ${losAmount(s.price)}', _active ? null : (s) => setState(() {
              _sorte = s;
              _los = null;
              _scratch.clear();
              _cells.clear();
              _revealed = false;
              _big = false;
              _message = 'Sorte wählen und Los kaufen';
            })),
        ticket: SizedBox(
          width: 340,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [Color(s.colors[0]), Color(s.colors[1])], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x66000000))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.name, style: const TextStyle(fontFamily: displayFont, fontSize: 30, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
                  Text('Hauptgewinn ${losAmount(s.topPrize)} · Los ${losAmount(s.price)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(s.rule, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, box) {
                      final size = Size(box.maxWidth, box.maxWidth * (s.kind == RubbelKind.gewinnzahlen ? 0.95 : 0.8));
                      return GestureDetector(
                        onPanStart: (d) => _rub(d.localPosition, size),
                        onPanUpdate: (d) => _rub(d.localPosition, size),
                        onTapDown: (d) => _rub(d.localPosition, size),
                        child: CustomPaint(
                          size: size,
                          painter: _RubbelPainter(los, _scratch, covered: los != null && !_revealed, radius: _radius),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        message: _message,
        big: _big,
        buttons: [
          if (_active)
            ActionButton(primary: true, label: 'Alles aufrubbeln', onPressed: _reveal)
          else
            ActionButton(primary: true, label: 'Los kaufen: ${formatCoins(_sorte.price)}', onPressed: _buy),
        ],
      ),
    );
  }
}

class _RubbelPainter extends CustomPainter {
  _RubbelPainter(this.los, this.scratch, {required this.covered, required this.radius});
  final RubbelLos? los;
  final List<Offset> scratch;
  final bool covered;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(area, const Radius.circular(10)), Paint()..color = const Color(0xFFFFF8E7));
    final l = los;
    if (l == null) {
      losText(canvas, area, 'Los kaufen', const Color(0x66241410), size: 0.1);
      return;
    }
    const ink = Color(0xFF241410);
    const gold = Color(0xFFFFB300);
    void field(Rect r, RubbelFeld f, {bool showNumber = false}) {
      if (!covered && f.winning) {
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(8)), Paint()..color = const Color(0x55FFC107));
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(8)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = gold,
        );
      }
      if (showNumber) {
        losText(canvas, Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.6), '${f.number}', ink, size: 0.6);
        losText(canvas, Rect.fromLTWH(r.left, r.top + r.height * 0.58, r.width, r.height * 0.4), losAmount(f.amount), const Color(0xFF6D4C41), size: 0.55);
      } else if (f.symbol.isNotEmpty) {
        paintLosSymbol(canvas, Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.68), f.symbol);
        losText(canvas, Rect.fromLTWH(r.left, r.top + r.height * 0.66, r.width, r.height * 0.32), losAmount(f.amount), ink, size: 0.6);
      } else {
        losText(canvas, r, losAmount(f.amount), ink, size: 0.32);
      }
    }

    switch (l.sorte.kind) {
      case RubbelKind.dreiGleiche:
        final cw = size.width / 3, ch = size.height / 2;
        for (var i = 0; i < 6; i++) {
          field(Rect.fromLTWH((i % 3) * cw, (i ~/ 3) * ch, cw, ch).deflate(4), l.fields[i]);
        }
      case RubbelKind.gewinnzahlen:
        final top = size.height * 0.26;
        losText(canvas, Rect.fromLTWH(0, 0, size.width, top * 0.36), 'GEWINNZAHLEN', const Color(0xFF8D6E00), size: 0.8);
        for (var i = 0; i < 2; i++) {
          final c = Offset(size.width * (0.35 + i * 0.3), top * 0.66);
          canvas.drawCircle(c, top * 0.32, Paint()..color = const Color(0xFFFFE082));
          losText(canvas, Rect.fromCircle(center: c, radius: top * 0.32), '${l.winningNumbers[i]}', ink, size: 0.7);
        }
        canvas.drawLine(Offset(8, top), Offset(size.width - 8, top), Paint()..color = const Color(0x33241410));
        losText(canvas, Rect.fromLTWH(0, top, size.width, size.height * 0.08), 'DEINE ZAHLEN', const Color(0xFF8D6E00), size: 0.8);
        final y0 = top + size.height * 0.08;
        final cw = size.width / 4, ch = (size.height - y0) / 2;
        for (var i = 0; i < 8; i++) {
          field(Rect.fromLTWH((i % 4) * cw, y0 + (i ~/ 4) * ch, cw, ch).deflate(3), l.fields[i], showNumber: true);
        }
      case RubbelKind.symbolSuche:
        final cw = size.width / 3, ch = size.height / 3;
        for (var i = 0; i < 9; i++) {
          field(Rect.fromLTWH((i % 3) * cw, (i ~/ 3) * ch, cw, ch).deflate(3), l.fields[i]);
        }
    }

    if (!covered) return;
    // Silberne Rubbelschicht; freigerubbelte Stellen werden ausgestanzt
    canvas.saveLayer(area, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, const Radius.circular(10)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFFD6D6D6)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(area),
    );
    final rng = math.Random(7);
    for (var i = 0; i < 60; i++) {
      canvas.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 1.5, Paint()..color = const Color(0x55FFFFFF));
    }
    losText(canvas, area, 'HIER RUBBELN', const Color(0x88616161), size: 0.1);
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final p in scratch) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), radius * size.width, clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RubbelPainter old) => true;
}

// ================================================================ Pull-Tabs

class PullTabScreen extends StatefulWidget {
  const PullTabScreen({super.key, this.seed});
  final int? seed;

  @override
  State<PullTabScreen> createState() => _PullTabScreenState();
}

class _PullTabScreenState extends State<PullTabScreen> {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  PullSorte _sorte = pullSorten.first;
  PullTab? _tab;
  final Set<int> _open = {};
  bool _paid = false;
  String _message = 'Sorte wählen und Los kaufen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  /// Beim ersten Aufbau festhalten: in dispose gibt es keinen Kontext mehr.
  late final Wallet _wallet = AppScope.of(context).wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet;
  }
  bool get _active => _tab != null && !_paid;

  void _buy() {
    if (!_app.wallet.spend(_sorte.price)) {
      setState(() => _message = 'Nicht genug Münzen');
      return;
    }
    _app.sfx.play(Sound.card);
    setState(() {
      _tab = makePullTab(_sorte, _rng);
      _open.clear();
      _paid = false;
      _big = false;
      _message = 'Laschen aufreißen!';
    });
  }

  void _pull(int i) {
    if (!_active || _open.contains(i)) return;
    _app.sfx.play(Sound.tick);
    setState(() => _open.add(i));
    if (_open.length == 5) _settle();
  }

  void _all() {
    if (!_active) return;
    setState(() => _open.addAll([0, 1, 2, 3, 4]));
    _settle();
  }

  void _settle() {
    final t = _tab!;
    final wallet = _app.wallet;
    wallet.credit(t.prize);
    debugLog.info('lose', '${t.sorte.name} für ${t.sorte.price}: ${t.prize > 0 ? 'Gewinn ${t.prize}' : 'Niete'} · Stand ${wallet.balance}');
    setState(() {
      _paid = true;
      _big = t.prize > 0;
      _message = t.prize > 0 ? '3 × ${pullSymbole[t.rows[t.winRow].first]}: +${formatCoins(t.prize)}' : 'Leider eine Niete';
    });
    _app.sfx.play(t.prize >= t.sorte.price * 10 ? Sound.bigWin : (t.prize > 0 ? Sound.win : Sound.lose));
    wallet.refillIfBroke(min: _sorte.price);
  }

  @override
  void dispose() {
    final t = _tab;
    if (t != null && !_paid) _wallet.credit(t.prize);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _tab;
    final s = t?.sorte ?? _sorte;
    final light = Color(s.colors[1]);
    return GameFrame(
      minStake: _sorte.price,
      title: 'Pull-Tabs',
      guide: pullGuide(),
      child: _LosFrame(
        chooser: _chips<PullSorte>(pullSorten, _sorte, (s) => '${s.name} · ${losAmount(s.price)}', _active ? null : (s) => setState(() {
              _sorte = s;
              _tab = null;
              _open.clear();
              _paid = false;
              _big = false;
              _message = 'Sorte wählen und Los kaufen';
            })),
        ticket: Container(
          width: 340,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(s.colors[0]),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x66000000))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.name, style: const TextStyle(fontFamily: displayFont, fontSize: 28, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
              Text('Los ${losAmount(s.price)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              // Gewinnplan auf dem Los
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(6)),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final e in s.pays.entries.toList().reversed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var k = 0; k < 3; k++)
                            SizedBox.square(dimension: 16, child: CustomPaint(painter: _SymPainter(pullSymbole[e.key]))),
                          const SizedBox(width: 3),
                          Text(losAmount(e.value.amount * s.price), style: const TextStyle(color: Color(0xFF241410), fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: GestureDetector(
                    onTap: () => _pull(i),
                    child: SizedBox(
                      height: 62,
                      child: Stack(
                        children: [
                          // Fenster mit drei Symbolen
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: t != null && _paid && t.winRow == i ? const Color(0xFFFFB300) : const Color(0x33000000),
                                  width: t != null && _paid && t.winRow == i ? 3 : 1,
                                ),
                              ),
                              child: t == null || !_open.contains(i)
                                  ? null
                                  : Row(
                                      children: [
                                        for (final sym in t.rows[i])
                                          Expanded(child: CustomPaint(painter: _SymPainter(pullSymbole[sym]), child: const SizedBox.expand())),
                                      ],
                                    ),
                            ),
                          ),
                          // Lasche, die beim Aufreißen zur Seite gleitet
                          AnimatedPositioned(
                            // nur das Aufreißen ist animiert, beim neuen Los sitzt die Lasche sofort wieder
                            duration: Duration(milliseconds: t != null && _open.contains(i) ? 280 : 0),
                            curve: Curves.easeIn,
                            top: 0,
                            bottom: 0,
                            left: t != null && _open.contains(i) ? 320 : 0,
                            width: 316,
                            child: AnimatedOpacity(
                              duration: Duration(milliseconds: t != null && _open.contains(i) ? 280 : 0),
                              opacity: t != null && _open.contains(i) ? 0 : 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [light, Color.lerp(light, Colors.white, 0.4)!]),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x55000000)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(t == null ? '' : 'AUFREISSEN  ›', style: const TextStyle(color: Color(0xFF241410), fontWeight: FontWeight.w800, letterSpacing: 1)),
                                    // Perforation
                                    Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 6), color: const Color(0x55000000)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        message: _message,
        big: _big,
        buttons: [
          if (_active)
            ActionButton(primary: true, label: 'Alle aufreißen', onPressed: _all)
          else
            ActionButton(primary: true, label: 'Los kaufen: ${formatCoins(_sorte.price)}', onPressed: _buy),
        ],
      ),
    );
  }
}

class _SymPainter extends CustomPainter {
  _SymPainter(this.name);
  final String name;

  @override
  void paint(Canvas canvas, Size size) => paintLosSymbol(canvas, Offset.zero & size, name);

  @override
  bool shouldRepaint(_SymPainter old) => old.name != name;
}
