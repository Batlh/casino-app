import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'video_poker_engine.dart';

class VideoPokerScreen extends StatefulWidget {
  const VideoPokerScreen({super.key});

  @override
  State<VideoPokerScreen> createState() => _VideoPokerScreenState();
}

class _VideoPokerScreenState extends State<VideoPokerScreen> {
  final _engine = VideoPokerEngine();
  int _bet = 50;
  final _cardGeneration = List<int>.filled(5, 0);
  String _message = 'Einsatz wählen und Karten geben';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  void _deal() {
    if (!_app.wallet.spend(_bet)) return;
    _engine.deal(_bet);
    _app.sfx.play(Sound.card);
    setState(() {
      for (var i = 0; i < 5; i++) {
        _cardGeneration[i]++;
      }
      _message = 'Tippe die Karten an, die du behalten willst';
      _big = false;
    });
  }

  void _draw() {
    final replaced = [for (var i = 0; i < 5; i++) !_engine.held[i]];
    _engine.draw();
    _app.sfx.play(Sound.card);
    final paid = _engine.payout;
    _app.wallet.credit(paid);
    setState(() {
      for (var i = 0; i < 5; i++) {
        if (replaced[i]) _cardGeneration[i]++;
      }
      if (_engine.payIndex != null) {
        _message =
            '${vpPayTable[_engine.payIndex!].name}: +${formatCoins(paid)}';
        _big = true;
        _app.sfx.play(paid >= _engine.bet * 9 ? Sound.bigWin : Sound.win);
      } else {
        _message = 'Kein Gewinn';
        _big = false;
        _app.sfx.play(Sound.lose);
      }
    });
    _app.wallet.refillIfBroke();
    if (!_app.wallet.canAfford(_bet)) setState(() => _bet = 10);
  }

  void _toggle(int i) {
    if (_engine.phase != VpPhase.holding) return;
    _app.sfx.play(Sound.tick);
    setState(() => _engine.toggleHold(i));
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Video Poker',
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14506E), Color(0xFF0B2F42)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.15;
          final payTable = _PayTable(
            bet: _bet,
            hit: _engine.phase == VpPhase.betting ? null : _engine.payIndex,
            columns: wide ? 1 : 2,
          );
          if (wide) {
            return Row(
              children: [
                SizedBox(
                  width: min(280, box.maxWidth * 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: payTable,
                  ),
                ),
                Expanded(child: _play(box.maxWidth * 0.68, box.maxHeight)),
              ],
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(height: 118, child: payTable),
              ),
              Expanded(child: _play(box.maxWidth, box.maxHeight - 138)),
            ],
          );
        },
      ),
    );
  }

  Widget _play(double width, double height) {
    final cardWidth = min((width - 40) / 5, (height - 200) * 0.55).clamp(48.0, 150.0);
    final holding = _engine.phase == VpPhase.holding;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _Slot(
                  width: cardWidth,
                  held: _engine.hand.isNotEmpty && _engine.held[i],
                  onTap: () => _toggle(i),
                  child: DealIn(
                    key: ValueKey('$i-${_cardGeneration[i]}'),
                    child: PlayingCardView(
                      width: cardWidth,
                      card: _engine.hand.isEmpty ? null : _engine.hand[i],
                      highlighted: _engine.held[i],
                    ),
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResultBanner(text: _message, highlight: _big),
              const SizedBox(height: 4),
              if (holding)
                ActionButton(primary: true, label: 'Karten tauschen', onPressed: _draw)
              else ...[
                BetPicker(
                  value: _bet,
                  onChanged: (v) => setState(() => _bet = v),
                ),
                const SizedBox(height: 10),
                ActionButton(
                  primary: true,
                  label: 'Karten geben: ${formatCoins(_bet)}',
                  onPressed: _app.wallet.canAfford(_bet) ? _deal : null,
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.width,
    required this.held,
    required this.onTap,
    required this.child,
  });

  final double width;
  final bool held;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 22,
            child: held
                ? const Text(
                    'Halten',
                    style: TextStyle(
                      color: Color(0xFFFFC95C),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : null,
          ),
          child,
        ],
      ),
    );
  }
}

class _PayTable extends StatelessWidget {
  const _PayTable({required this.bet, required this.hit, required this.columns});
  final int bet;
  final int? hit;
  final int columns;

  Widget _row(int i, Palette p) {
    final entry = vpPayTable[i];
    final active = i == hit;
    final style = TextStyle(
      color: active ? const Color(0xFF2A160E) : const Color(0xFFFFE9A8),
      fontWeight: FontWeight.w700,
      fontSize: 15,
      height: 1.15,
    );
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFC95C) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(entry.name, style: style),
              ),
            ),
            const SizedBox(width: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatCoins(entry.multiplier * bet), style: style),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final frame = BoxDecoration(
      color: const Color(0x33000000),
      border: Border.all(color: const Color(0x66FFE9A8), width: 2),
      borderRadius: BorderRadius.circular(6),
    );
    if (columns == 1) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: frame,
        child: Column(children: [for (var i = 0; i < 9; i++) _row(i, p)]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: frame,
      child: Row(
        children: [
          Expanded(
            child: Column(children: [for (var i = 0; i < 5; i++) _row(i, p)]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (var i = 5; i < 9; i++) _row(i, p),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
