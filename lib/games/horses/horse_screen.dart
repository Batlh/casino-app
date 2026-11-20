import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/wallet.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import 'horse_engine.dart';

const horseGuide = GameGuide('Pferderennen', [
  GuideSection(
    'So geht es',
    'Wähle den Einsatz und tippe bei einem Pferd auf „Sieg“ oder „Platz“. Du kannst mehrere Wetten setzen. Dann startet '
        'das Rennen. Sieg gewinnt, wenn das Pferd Erster wird, Platz, wenn es unter den ersten zwei ist.',
  ),
  GuideSection(
    'Quoten',
    'Jedes Rennen hat neue Stärken. Die Quote auf dem Knopf ist die Auszahlung je Münze, der Einsatz ist schon drin: '
        '3,5 heißt, aus 10 Münzen werden 35. Starke Pferde haben kleine Quoten. Auf lange Sicht fließen 95 % der Einsätze zurück.',
  ),
  GuideSection(
    'Im Netzwerk',
    'Der Gastgeber startet das Rennen, alle sehen dasselbe Rennen mit denselben Quoten. Jeder wettet für sich.',
  ),
]);

const horseColors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFFB300), Color(0xFF43A047), Color(0xFF8E24AA), Color(0xFFECEFF1)];

class HorseScreen extends StatefulWidget {
  const HorseScreen({super.key, this.seed});
  final int? seed;

  @override
  State<HorseScreen> createState() => _HorseScreenState();
}

class _HorseScreenState extends State<HorseScreen> with SingleTickerProviderStateMixin, NetSharedTable {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final AnimationController _run = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  late int _cardSeed = _rng.nextInt(1 << 31);
  late RaceCard _card = RaceCard.fromSeed(_cardSeed);
  List<int>? _order;
  int _raceSeed = 0;
  final List<HorseBet> _bets = [];
  int _bet = 10;
  String _message = 'Wetten setzen, dann starten';
  bool _big = false;

  AppScope get _app => AppScope.of(context);
  bool get _racing => _run.isAnimating;
  int get _staked => _bets.fold(0, (a, b) => a + b.amount);

  @override
  void initState() {
    super.initState();
    _run.addListener(() => setState(() {}));
    _run.addStatusListener((s) {
      if (s == AnimationStatus.completed) _settle();
    });
  }

  /// Für dispose gemerkt (dort darf nicht mehr nach AppScope gesucht werden).
  Wallet? _wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet ??= _app.wallet;
  }

  @override
  void dispose() {
    // Laufendes Rennen gleich abrechnen, nicht gestartete Wetten zurückgeben
    final o = _order;
    if (_racing && o != null) {
      final won = _bets.fold(0, (a, b) => a + _card.payout(b, o));
      if (won > 0 && !sharedTournament) _wallet?.credit(won);
    } else if (_bets.isNotEmpty && !sharedTournament) {
      _wallet?.credit(_staked);
    }
    _run.dispose();
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'pferde';
  @override
  String get sharedTitle => 'Pferderennen';

  @override
  void sharedResult(Object? outcome) {
    if (outcome is! Map) return;
    final c = (outcome['c'] as num?)?.toInt();
    final r = (outcome['r'] as num?)?.toInt();
    if (c != null && !_racing) {
      setState(() {
        _cardSeed = c;
        _card = RaceCard.fromSeed(c);
        _message = 'Neue Rennkarte: Wetten setzen';
      });
    }
    if (r != null && !_racing) _startRace(r);
  }

  void _addBet(int horse, BetKind kind) {
    if (_racing || !sharedWallet.spend(_bet)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      _bets.add(HorseBet(horse, kind, _bet));
      _message = 'Einsatz gesamt ${formatCoins(_staked)}';
    });
    sharedStake(_staked);
  }

  void _clearBets() {
    if (_racing) return;
    sharedWallet.credit(_staked);
    setState(() => _bets.clear());
    sharedStake(0);
  }

  void _start() {
    if (_racing || sharedGuest) return;
    final seed = _rng.nextInt(1 << 31);
    if (sharedHost) sharedSend({'r': seed});
    _startRace(seed);
  }

  void _startRace(int seed) {
    _raceSeed = seed;
    _order = _card.race(seed);
    debugLog.info('pferde', 'Karte $_cardSeed, Einlauf ${_order!.map((i) => horseNames[i]).join(', ')}');
    _app.sfx.play(Sound.ball);
    setState(() {
      _big = false;
      _message = 'Und los!';
    });
    _run.forward(from: 0);
  }

  void _settle() {
    final order = _order!;
    var won = 0;
    for (final b in _bets) {
      won += _card.payout(b, order);
    }
    if (won > 0) sharedWallet.credit(won);
    final staked = _staked;
    _bets.clear();
    sharedStake(0);
    _app.sfx.play(won > staked ? Sound.win : (staked > 0 ? Sound.lose : Sound.tick));
    _big = won >= staked * 4 && won > 0;
    _message = 'Sieger ${horseNames[order[0]]}, Zweiter ${horseNames[order[1]]}'
        '${staked > 0 ? (won > 0 ? ' · +${formatCoins(won)}' : ' · leider nichts') : ''}';
    // Neue Karte für das nächste Rennen
    if (!sharedGuest) {
      _cardSeed = _rng.nextInt(1 << 31);
      _card = RaceCard.fromSeed(_cardSeed);
      if (sharedHost) sharedSend({'c': _cardSeed});
    }
    sharedWallet.refillIfBroke();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFF6F1E1);
    return GameFrame(
      title: 'Pferderennen',
      guide: horseGuide,
      background: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B5E20), Color(0xFF0B2E10)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ??
          LayoutBuilder(builder: (context, box) {
            final trackH = math.min(300.0, box.maxHeight * 0.38);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(
                    height: trackH,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrackPainter(order: _order, t: _order == null ? 0 : _run.value, seed: _raceSeed),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ResultBanner(text: _message, highlight: _big, maxLines: 2),
                  sharedStakesBar(),
                  const SizedBox(height: 6),
                  for (var i = 0; i < horseNames.length; i++) _horseRow(i, ink),
                  const SizedBox(height: 8),
                  BetPicker(value: _bet, enabled: !_racing, onChanged: (v) => setState(() => _bet = v)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    ActionButton(
                      primary: true,
                      label: sharedGuest ? 'Der Gastgeber startet' : 'Rennen starten',
                      onPressed: _racing || sharedGuest ? null : _start,
                    ),
                    ActionButton(label: 'Wetten zurück', onPressed: _racing || _bets.isEmpty ? null : _clearBets),
                  ]),
                ],
              ),
            );
          }),
    );
  }

  Widget _horseRow(int i, Color ink) {
    String odds(BetKind k) => (_card.odds10(i, k) / 10).toStringAsFixed(1).replaceAll('.', ',');
    final mine = _bets.where((b) => b.horse == i).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: horseColors[i], shape: BoxShape.circle, border: Border.all(color: Colors.black54))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${i + 1} ${horseNames[i]}${mine.isEmpty ? '' : ' · ${formatCoins(mine.fold(0, (a, b) => a + b.amount))}'}',
            style: TextStyle(color: ink, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final k in BetKind.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Material(
              color: mine.any((b) => b.kind == k) ? const Color(0x33FFC95C) : const Color(0x22000000),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _racing ? null : () => _addBet(i, k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: mine.any((b) => b.kind == k) ? const Color(0xFFFFC95C) : const Color(0x66FFFFFF), width: 1.5),
                  ),
                  child: Text('${k == BetKind.win ? 'Sieg' : 'Platz'} ${odds(k)}',
                      style: TextStyle(color: _racing ? ink.withValues(alpha: 0.5) : ink, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({required this.order, required this.t, required this.seed});
  final List<int>? order;
  final double t;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)), Paint()..color = const Color(0xFF8D6E4A));
    final lane = size.height / horseNames.length;
    for (var i = 0; i <= horseNames.length; i++) {
      canvas.drawLine(Offset(0, i * lane), Offset(size.width, i * lane), Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1);
    }
    const startX = 30.0;
    final finishX = size.width - 24;
    // Ziellinie kariert
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawRect(Rect.fromLTWH(finishX + ((y ~/ 8).isEven ? 0 : 4), y, 4, 8), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(finishX + ((y ~/ 8).isEven ? 4 : 0), y, 4, 8), Paint()..color = Colors.black);
    }
    final o = order;
    for (var i = 0; i < horseNames.length; i++) {
      final p = o == null ? 0.0 : horseProgress(o, i, t, seed);
      final x = startX + (finishX - startX - 20) * p;
      final y = (i + 0.5) * lane;
      _paintHorse(canvas, Offset(x, y), lane * 0.42, horseColors[i], o == null ? 0 : t * 40 + i);
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(6, y - tp.height / 2));
    }
  }

  void _paintHorse(Canvas canvas, Offset c, double s, Color silk, double phase) {
    final body = Paint()..color = const Color(0xFF5D3A1A);
    canvas.drawOval(Rect.fromCenter(center: c, width: s * 2.2, height: s * 0.9), body);
    // Hals und Kopf
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + s * 0.7, c.dy - s * 0.2)
        ..lineTo(c.dx + s * 1.25, c.dy - s * 0.85)
        ..lineTo(c.dx + s * 1.6, c.dy - s * 0.7)
        ..lineTo(c.dx + s * 1.0, c.dy + s * 0.1)
        ..close(),
      body,
    );
    // Beine im Galopp
    final leg = Paint()
      ..color = const Color(0xFF3E2410)
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final bx = c.dx + (k < 2 ? -s * 0.7 : s * 0.6) + (k.isEven ? 0 : s * 0.2);
      final a = math.sin(phase + k * 1.6) * 0.6;
      canvas.drawLine(Offset(bx, c.dy + s * 0.3), Offset(bx + math.sin(a) * s * 0.6, c.dy + s * 0.3 + math.cos(a) * s * 0.6), leg);
    }
    canvas.drawLine(Offset(c.dx - s * 1.05, c.dy - s * 0.1), Offset(c.dx - s * 1.5, c.dy + s * 0.3), leg);
    // Reiter
    canvas.drawCircle(c.translate(-s * 0.1, -s * 0.75), s * 0.38, Paint()..color = silk);
    canvas.drawCircle(c.translate(-s * 0.05, -s * 1.2), s * 0.2, Paint()..color = const Color(0xFFFFE0B2));
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t || old.order != order;
}
