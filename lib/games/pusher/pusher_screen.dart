import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import 'pusher_table.dart';

const pusherGuide = GameGuide('Münzschieber', [
  GuideSection(
    'So geht es',
    'Tippe oben auf die Rinne oder nimm „Einwerfen“: Die Münze fällt vor den Schieber. Der Schieber fährt vor und zurück '
        'und drückt die Münzen nach vorn. Was vorne über die Kante fällt, gehört dir. Was vorne links oder rechts in die '
        'Rinnen rutscht, behält der Automat.',
  ),
  GuideSection(
    'Münzwert',
    'Jede Münze ist so viel wert, wie sie beim Einwurf gekostet hat. Die Münzen vom Start sind je 1 wert. Ab und zu bringt '
        'ein Einwurf eine Goldmünze mit, die zählt zehnfach.',
  ),
  GuideSection(
    'Der Tisch bleibt',
    'Wenn du gehst, bleiben alle Münzen genau so liegen und warten auf dich. Wer zielt, schiebt Münzen gezielt an die '
        'Kante, wo schon viele überstehen.',
  ),
]);

const _values = [1, 5, 10, 25];

class PusherScreen extends StatefulWidget {
  const PusherScreen({super.key, this.seed});
  final int? seed;

  @override
  State<PusherScreen> createState() => _PusherScreenState();
}

class _PusherScreenState extends State<PusherScreen> with SingleTickerProviderStateMixin {
  PusherTable? _table;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _acc = 0;
  double _saveIn = 5;
  double _autoIn = 0;
  double _dropX = PusherTable.width / 2;
  int _value = 1;
  bool _auto = false;
  int _session = 0;
  String _message = 'Münze einwerfen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_table != null) return;
    final s = _app.settings.loadGame('pusher');
    final raw = s?['coins'];
    List<PusherCoin>? coins;
    if (raw is List) {
      coins = [
        for (final c in raw)
          if (c is List && c.length == 4) PusherCoin((c[0] as num).toDouble(), (c[1] as num).toDouble(), (c[2] as num).toInt(), c[3] == 1),
      ];
    }
    _value = _values.contains(s?['value']) ? s!['value'] as int : 1;
    _table = PusherTable(rng: widget.seed == null ? null : math.Random(widget.seed), coins: coins);
    final q = s?['queue'];
    if (q is List) {
      for (final e in q) {
        if (e is List && e.length == 2) _table!.enqueue((e[0] as num).toDouble(), (e[1] as num).toInt());
      }
    }
    _ticker.start();
  }

  void _save() {
    final t = _table;
    if (t == null) return;
    _app.settings.saveGame('pusher', {
      'value': _value,
      'coins': [
        for (final c in t.coins) [double.parse(c.x.toStringAsFixed(3)), double.parse(c.y.toStringAsFixed(3)), c.value, c.gold ? 1 : 0],
      ],
      'queue': [for (final (x, v) in t.pending) [x, v]],
    });
  }

  @override
  void deactivate() {
    _save();
    super.deactivate();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = math.min(0.1, (now - _last).inMicroseconds / 1e6);
    _last = now;
    final t = _table!;
    _acc += dt;
    while (_acc >= 1 / 60) {
      t.step(1 / 60);
      _acc -= 1 / 60;
    }
    if (t.events.isNotEmpty) {
      var won = 0;
      var gold = false;
      for (final e in t.events) {
        if (e.won) {
          won += e.value;
          gold |= e.gold;
        }
      }
      t.events.clear();
      if (won > 0) {
        _app.wallet.credit(won);
        _session += won;
        _app.sfx.play(gold ? Sound.bigWin : Sound.coin);
        _message = gold ? 'Goldmünze! +${formatCoins(won)}' : '+${formatCoins(won)}';
        _big = gold;
      }
    }
    if (_auto) {
      _autoIn -= dt;
      if (_autoIn <= 0) {
        _autoIn = 1.1;
        _drop(_dropX + (math.Random().nextDouble() - 0.5) * 0.3);
      }
    }
    _saveIn -= dt;
    if (_saveIn <= 0) {
      _saveIn = 5;
      _save();
    }
    setState(() {});
  }

  void _drop(double x) {
    if (!_app.wallet.spend(_value)) {
      _auto = false;
      _message = 'Zu wenig Münzen';
      return;
    }
    _table!.drop(x, _value);
    _session -= _value;
    _app.sfx.play(Sound.chip);
  }

  @override
  Widget build(BuildContext context) {
    final t = _table!;
    const ink = Color(0xFFFFF1D6);
    return GameFrame(
      title: 'Münzschieber',
      guide: pusherGuide,
      minStake: 1,
      background: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E2A3A), Color(0xFF06131C)])),
      child: LayoutBuilder(builder: (context, box) {
        final w = math.min(box.maxWidth - 24, (box.maxHeight - 230) * PusherTable.width / (PusherTable.length + 1.2));
        final scale = w / PusherTable.width;
        final h = (PusherTable.length + 1.2) * scale;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              GestureDetector(
                onTapDown: (d) {
                  setState(() => _dropX = (d.localPosition.dx / scale).clamp(0, PusherTable.width));
                  _drop(_dropX);
                },
                onHorizontalDragUpdate: (d) => setState(() => _dropX = (d.localPosition.dx / scale).clamp(0, PusherTable.width)),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: CustomPaint(painter: _TablePainter(t, scale, _dropX)),
                ),
              ),
              const SizedBox(height: 8),
              ResultBanner(text: _message, highlight: _big, maxLines: 1),
              Text(
                'Diese Runde: ${_session >= 0 ? '+' : ''}${formatCoins(_session)} · auf dem Tisch ${t.coins.length} Münzen',
                style: TextStyle(color: ink.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                ActionButton(primary: true, label: 'Einwerfen: ${formatCoins(_value)}', onPressed: _app.wallet.canAfford(_value) ? () => _drop(_dropX) : null),
                FilterChip(label: const Text('Automatik'), selected: _auto, onSelected: (v) => setState(() => _auto = v)),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
                for (final v in _values)
                  ChoiceChip(
                    label: Text('Münzwert $v'),
                    selected: _value == v,
                    onSelected: (_) => setState(() => _value = v),
                  ),
              ]),
            ],
          ),
        );
      }),
    );
  }
}

class _TablePainter extends CustomPainter {
  _TablePainter(this.t, this.scale, this.dropX);
  final PusherTable t;
  final double scale;
  final double dropX;

  @override
  void paint(Canvas canvas, Size size) {
    final top = 1.2 * scale; // Platz für die Einwurfrinne
    Offset at(double x, double y) => Offset(x * scale, top + y * scale);
    final table = Rect.fromLTWH(0, top, PusherTable.width * scale, PusherTable.length * scale);
    // Rinne oben mit Zielmarke
    final chute = Rect.fromLTWH(0, 0, size.width, top * 0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(chute, const Radius.circular(10)), Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(Offset(dropX * scale, top * 0.4), PusherTable.coinRadius * scale * 0.8, Paint()..color = const Color(0x88FFD54F));
    canvas.drawLine(Offset(dropX * scale, top * 0.8), at(dropX, t.pusherFront), Paint()
      ..color = const Color(0x44FFD54F)
      ..strokeWidth = 2);
    // Spielfläche
    canvas.drawRect(
      table,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7A1B2B), Color(0xFFA62639)])
            .createShader(table),
    );
    // Seitliche Rinnen vorne
    final gutterTop = top + PusherTable.wallEnd * scale;
    for (final x in [0.0, size.width - 0.35 * scale]) {
      canvas.drawRect(Rect.fromLTWH(x, gutterTop, 0.35 * scale, (PusherTable.length - PusherTable.wallEnd) * scale), Paint()..color = const Color(0xCC000000));
    }
    // Vorderkante mit Lichtern
    canvas.drawRect(Rect.fromLTWH(0, top + PusherTable.length * scale - 3, size.width, 6), Paint()..color = const Color(0xFFFFD54F));
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(Offset((i + 0.5) * size.width / 12, top + PusherTable.length * scale + 8), 3, Paint()..color = const Color(0xFFFFF59D));
    }
    // Schieber
    final front = t.pusherFront;
    final pusher = Rect.fromLTRB(0, top - 0.2 * scale, size.width, top + front * scale);
    canvas.drawRect(
      pusher,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF90A4AE), Color(0xFFECEFF1), Color(0xFF78909C)])
            .createShader(pusher),
    );
    canvas.drawLine(Offset(0, pusher.bottom), Offset(size.width, pusher.bottom), Paint()
      ..color = const Color(0xFF37474F)
      ..strokeWidth = 3);
    // Münzen
    final r = PusherTable.coinRadius * scale;
    for (final c in t.coins) {
      final o = at(c.x, c.y);
      canvas.drawCircle(o.translate(1.5, 2), r, Paint()..color = const Color(0x66000000));
      final colors = c.gold
          ? const [Color(0xFFFFF9C4), Color(0xFFFFC107), Color(0xFFB8860B)]
          : (c.value >= 10 ? const [Color(0xFFFFFFFF), Color(0xFFB0BEC5), Color(0xFF607D8B)] : const [Color(0xFFFFE0B2), Color(0xFFD4A04C), Color(0xFF8D6E2C)]);
      canvas.drawCircle(o, r, Paint()..shader = RadialGradient(center: const Alignment(-0.35, -0.4), colors: colors).createShader(Rect.fromCircle(center: o, radius: r)));
      canvas.drawCircle(o, r * 0.78, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55000000));
      if (c.gold) {
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rr = i.isEven ? r * 0.5 : r * 0.22;
          final p = o + Offset(math.cos(a), math.sin(a)) * rr;
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFFF59D));
      }
    }
  }

  @override
  bool shouldRepaint(_TablePainter old) => true;
}
