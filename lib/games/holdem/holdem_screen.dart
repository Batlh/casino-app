import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/widgets.dart';
import 'holdem_engine.dart';

class HoldemTable {
  const HoldemTable(this.name, this.smallBlind, this.bigBlind, this.buyIn);
  final String name;
  final int smallBlind;
  final int bigBlind;
  final int buyIn;
}

const holdemTables = [
  HoldemTable('Kleiner Tisch', 5, 10, 1000),
  HoldemTable('Mittlerer Tisch', 25, 50, 5000),
  HoldemTable('Hoher Tisch', 100, 200, 20000),
];

const _botNames = [
  'Helga',
  'Otto',
  'Bärbel',
  'Klaus',
  'Rosi',
  'Horst',
  'Inge',
  'Dieter',
  'Gisela',
  'Manni',
];

class HoldemScreen extends StatefulWidget {
  const HoldemScreen({super.key});

  @override
  State<HoldemScreen> createState() => _HoldemScreenState();
}

class _HoldemScreenState extends State<HoldemScreen> {
  final _rng = math.Random.secure();
  late final Wallet _wallet = AppScope.of(context).wallet;
  HoldemEngine? _engine;
  HoldemTable _table = holdemTables.first;
  int _opponents = 4;
  int _raiseTo = 0;
  bool _botRunning = false;
  int _handNumber = 0;
  String _message = '';
  bool _big = false;
  int _botNameCursor = 0;

  AppScope get _app => AppScope.of(context);
  HoldemPlayer? get _me => _engine?.human;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet; // Beim ersten Aufbau festhalten, in dispose gibt es keinen Kontext mehr
  }

  @override
  void dispose() {
    final me = _me;
    if (me != null) {
      // Laufende Einsätze sind verloren, der Rest geht zurück ins Münzkonto
      _wallet.credit(me.stack);
      _wallet.refillIfBroke();
    }
    super.dispose();
  }

  HoldemPlayer _newBot(int stack) {
    final name = _botNames[_botNameCursor % _botNames.length];
    _botNameCursor++;
    final style = BotStyle.all[_rng.nextInt(BotStyle.all.length)];
    return HoldemPlayer(name, stack, style: style);
  }

  void _sit() {
    if (!_wallet.spend(_table.buyIn)) return;
    _botNameCursor = _rng.nextInt(_botNames.length);
    final players = [
      HoldemPlayer('Du', _table.buyIn, isHuman: true),
      for (var i = 0; i < _opponents; i++) _newBot(_table.buyIn),
    ];
    setState(() {
      _engine = HoldemEngine(
        players: players,
        smallBlind: _table.smallBlind,
        bigBlind: _table.bigBlind,
      );
    });
    _nextHand();
  }

  void _nextHand() {
    final e = _engine!;
    // Ausgeschiedene Gegner werden durch neue ersetzt
    for (var i = 0; i < e.players.length; i++) {
      final p = e.players[i];
      if (!p.isHuman && p.stack == 0) {
        final fresh = _newBot(_table.buyIn);
        p
          ..name = fresh.name
          ..style = fresh.style
          ..stack = fresh.stack;
      }
    }
    e.startHand();
    _app.sfx.play(Sound.card);
    setState(() {
      _handNumber++;
      _message = '';
      _big = false;
      _prepareRaise();
    });
    _pump();
  }

  void _prepareRaise() {
    final e = _engine!;
    if (e.handOver) return;
    if (e.actor.isHuman) _raiseTo = e.minRaiseTo;
  }

  /// Lässt Gegner spielen, bis du dran bist oder die Hand endet.
  Future<void> _pump() async {
    if (_botRunning) return;
    _botRunning = true;
    final e = _engine!;
    while (mounted && !e.handOver && !e.actor.isHuman) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted) break;
      final street = e.street;
      e.apply(botDecide(e, _rng));
      _app.sfx.play(Sound.chip);
      if (e.street != street) _app.sfx.play(Sound.card);
      setState(_prepareRaise);
    }
    _botRunning = false;
    if (mounted && e.handOver) _finishHand();
  }

  void _act(HoldemAction action) {
    final e = _engine!;
    if (e.handOver || !e.actor.isHuman) return;
    final street = e.street;
    e.apply(action);
    _app.sfx.play(action.kind == HoldemActionKind.fold ? Sound.card : Sound.chip);
    if (e.street != street) _app.sfx.play(Sound.card);
    setState(_prepareRaise);
    if (e.handOver) {
      _finishHand();
    } else {
      _pump();
    }
  }

  void _finishHand() {
    final e = _engine!;
    final parts = <String>[];
    for (final r in e.results) {
      final who = r.winners.map((w) => w.name).join(' und ');
      final hand = r.value == null ? '' : ' mit ${handName(r.value!)}';
      final verb = r.winners.length == 1 && r.winners.first.isHuman
          ? 'gewinnst'
          : r.winners.length == 1
              ? 'gewinnt'
              : 'teilen';
      parts.add('$who $verb ${formatCoins(r.amount)}$hand');
    }
    final iWon = e.results.any((r) => r.winners.any((w) => w.isHuman));
    setState(() {
      _message = parts.join('. ');
      _big = false;
    });
    _app.sfx.play(iWon ? Sound.win : Sound.lose);
  }

  void _rebuy() {
    final me = _me!;
    if (!_wallet.spend(_table.buyIn)) return;
    setState(() => me.stack = _table.buyIn);
    _nextHand();
  }

  void _leave() {
    final me = _me;
    if (me == null) return;
    _wallet.credit(me.stack);
    setState(() {
      me.stack = 0;
      _engine = null;
      _message = '';
    });
    _wallet.refillIfBroke();
  }

  @override
  Widget build(BuildContext context) {
    final e = _engine;
    return GameFrame(
      title: "Texas Hold'em",
      child: e == null ? _lobby() : _tableView(e),
    );
  }

  Widget _lobby() {
    final p = Palette.of(context);
    final style = TextStyle(color: p.onFelt, fontSize: 17);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListenableBuilder(
            listenable: _wallet,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'No-Limit gegen Computer-Gegner',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                for (final t in holdemTables)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TableChoice(
                      table: t,
                      selected: t == _table,
                      enabled: _wallet.canAfford(t.buyIn),
                      onTap: () => setState(() => _table = t),
                    ),
                  ),
                const SizedBox(height: 10),
                Text('Gegner am Tisch', textAlign: TextAlign.center, style: style),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (var n = 1; n <= 5; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: n == _opponents,
                        onSelected: (_) => setState(() => _opponents = n),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: ActionButton(
                    primary: true,
                    label: 'Hinsetzen: ${formatCoins(_table.buyIn)}',
                    onPressed: _wallet.canAfford(_table.buyIn) ? _sit : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Beim Verlassen des Tisches kommen deine Chips zurück ins Münzkonto.',
                  textAlign: TextAlign.center,
                  style: style.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableView(HoldemEngine e) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.2;
        final controls = _controls(e);
        final table = _Felt(engine: e, handNumber: _handNumber);
        if (wide) {
          return Row(
            children: [
              Expanded(child: table),
              SizedBox(
                width: math.min(300, box.maxWidth * 0.34),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: controls,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: table),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: controls,
            ),
          ],
        );
      },
    );
  }

  Widget _controls(HoldemEngine e) {
    final me = e.human!;
    final myTurn = !e.handOver && e.actor.isHuman;
    final p = Palette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _big ? const Color(0xFFFFC95C) : p.onFelt,
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.2,
              ),
            ),
          ),
        if (e.handOver) ..._betweenHands(e, me) else ..._turnButtons(e, myTurn),
      ],
    );
  }

  List<Widget> _betweenHands(HoldemEngine e, HoldemPlayer me) {
    final othersHaveChips = e.players.any((p) => !p.isHuman);
    return [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (me.stack > 0 && othersHaveChips)
            ActionButton(primary: true, label: 'Nächste Hand', onPressed: _nextHand)
          else
            ActionButton(
              primary: true,
              label: 'Nachkaufen: ${formatCoins(_table.buyIn)}',
              onPressed: _wallet.canAfford(_table.buyIn) ? _rebuy : null,
            ),
          ActionButton(label: 'Tisch verlassen', onPressed: _leave),
        ],
      ),
    ];
  }

  List<Widget> _turnButtons(HoldemEngine e, bool myTurn) {
    final p = Palette.of(context);
    final call = myTurn ? e.toCall : 0;
    final me = e.human!;
    final callLabel = !myTurn
        ? 'Warten'
        : call == 0
            ? 'Schieben'
            : call >= me.stack
                ? 'All-in: ${formatCoins(me.stack)}'
                : 'Mitgehen: ${formatCoins(call)}';
    final canRaise = myTurn && e.canRaise;
    final minTo = canRaise ? e.minRaiseTo : 0;
    final maxTo = canRaise ? e.maxRaiseTo : 1;
    final value = canRaise ? _raiseTo.clamp(minTo, maxTo) : 0;
    return [
      if (canRaise && maxTo > minTo)
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: minTo.toDouble(),
                max: maxTo.toDouble(),
                activeColor: p.accent,
                onChanged: (v) {
                  final step = _table.smallBlind;
                  final snapped = ((v / step).round() * step).clamp(minTo, maxTo);
                  setState(() => _raiseTo = snapped);
                },
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _raiseTo = maxTo),
              child: Text(
                'Alles',
                style: TextStyle(color: p.onFelt, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionButton(
            label: 'Passen',
            onPressed: myTurn && call > 0 ? () => _act(HoldemAction.fold) : null,
          ),
          ActionButton(
            label: callLabel,
            onPressed: myTurn
                ? () => _act(call == 0 ? HoldemAction.check : HoldemAction.call)
                : null,
          ),
          ActionButton(
            primary: true,
            label: canRaise
                ? (value >= maxTo
                    ? 'All-in'
                    : 'Erhöhen auf ${formatCoins(value)}')
                : 'Erhöhen',
            onPressed: canRaise
                ? () => _act(HoldemAction(HoldemActionKind.raise, value))
                : null,
          ),
        ],
      ),
    ];
  }
}

class _TableChoice extends StatelessWidget {
  const _TableChoice({
    required this.table,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final HoldemTable table;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? p.accent : p.panel,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    table.name,
                    style: TextStyle(
                      color: selected ? p.onAccent : p.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                Text(
                  'Blinds ${table.smallBlind}/${table.bigBlind}, Einstieg ${formatCoins(table.buyIn)}',
                  style: TextStyle(
                    color: selected ? p.onAccent : p.inkSoft,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ovaler Tisch mit Sitzen, Gemeinschaftskarten und Pot.
class _Felt extends StatelessWidget {
  const _Felt({required this.engine, required this.handNumber});
  final HoldemEngine engine;
  final int handNumber;

  @override
  Widget build(BuildContext context) {
    final e = engine;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final seats = e.players.length;
        final seatWidth = math.min(112.0, math.max(84.0, w / 4.4));
        final seatHeight = seatWidth * 0.98;
        final rx = (w - seatWidth) / 2;
        final ry = (h - seatHeight) / 2;
        final cardW = math.min((w * 0.52 - 16) / 5, h * 0.095).clamp(30.0, 76.0);
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _TablePainter())),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pot ${formatCoins(e.pot)}',
                    style: const TextStyle(
                      color: Color(0xFFFFE9A8),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: i < e.board.length
                              ? DealIn(
                                  key: ValueKey('$handNumber-b$i'),
                                  child: PlayingCardView(
                                    width: cardW,
                                    card: e.board[i],
                                  ),
                                )
                              : Container(
                                  width: cardW,
                                  height: cardW / cardAspect,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0x33FFFFFF)),
                                    borderRadius: BorderRadius.circular(cardW * 0.09),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < seats; i++)
              _positioned(
                i,
                seats,
                rx,
                ry,
                seatWidth,
                seatHeight,
                _Seat(
                  player: e.players[i],
                  acting: !e.handOver && e.toAct == i,
                  dealer: e.dealer == i,
                  reveal: e.players[i].isHuman ||
                      (e.handOver && e.players[i].shownValue != null),
                  width: seatWidth,
                  handNumber: handNumber,
                  seat: i,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _positioned(
    int i,
    int seats,
    double rx,
    double ry,
    double seatW,
    double seatH,
    Widget child,
  ) {
    // Sitz 0 unten in der Mitte, die anderen im Uhrzeigersinn
    final angle = math.pi / 2 + i * 2 * math.pi / seats;
    return Positioned(
      left: rx + rx * math.cos(angle),
      top: ry + ry * math.sin(angle),
      width: seatW,
      height: seatH,
      child: child,
    );
  }
}

class _TablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(math.min(size.shortestSide * 0.1, 44));
    final oval = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2),
    );
    canvas.drawRRect(oval.inflate(8), Paint()..color = const Color(0xFF5A3218));
    canvas.drawRRect(
      oval,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [Color(0xFF1B7A63), Color(0xFF0C4A3D)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.player,
    required this.acting,
    required this.dealer,
    required this.reveal,
    required this.width,
    required this.handNumber,
    required this.seat,
  });

  final HoldemPlayer player;
  final bool acting;
  final bool dealer;
  final bool reveal;
  final double width;
  final int handNumber;
  final int seat;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final faded = p.folded || !p.inHand;
    final cardW = width * 0.4;
    final status = p.shownValue != null
        ? handName(p.shownValue!)
        : p.lastAction.isNotEmpty
            ? p.lastAction
            : (p.style?.label ?? '');
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.inHand && p.hole.isNotEmpty)
            SizedBox(
              height: cardW / cardAspect * 0.62,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: cardW / cardAspect,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: DealIn(
                            key: ValueKey('$handNumber-s$seat-$i-$reveal'),
                            child: PlayingCardView(
                              width: cardW,
                              card: reveal && !p.folded ? p.hole[i] : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xE62A160E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: acting ? const Color(0xFFFFC95C) : const Color(0xFF6B3E1E),
                width: acting ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dealer) ...[
                      Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF6E7C8),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  formatCoins(p.stack),
                  style: const TextStyle(
                    color: Color(0xFFFFC95C),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
                Text(
                  p.streetBet > 0
                      ? 'Einsatz ${formatCoins(p.streetBet)}'
                      : (status.isEmpty ? ' ' : status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCDB48C),
                    fontSize: 13,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
