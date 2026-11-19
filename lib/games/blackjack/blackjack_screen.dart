import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/progress.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/playing_card.dart';
import 'blackjack_engine.dart';

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({super.key});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> with NetSharedTable {
  final _engine = BlackjackEngine();
  int _bet = 50;
  bool _busy = false;
  int _round = 0;
  String _message = 'Einsatz wählen und austeilen';
  bool _big = false;

  AppScope get _app => AppScope.of(context);
  bool get _inRound => _busy || _engine.phase == BjPhase.playerTurn || _engine.phase == BjPhase.dealerTurn;

  @override
  void dispose() {
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'blackjack';
  @override
  String get sharedTitle => 'Black Jack';
  int? _pending;

  /// Neue Runde vom Gastgeber: Der Geber hat bei allen dieselben Karten, jeder spielt seine Hand selbst.
  @override
  void sharedResult(Object? outcome) {
    final seed = (outcome as num?)?.toInt();
    if (seed == null) return;
    if (_inRound) {
      _pending = seed;
      return;
    }
    _dealRound(seed);
  }

  void _deal() {
    if (sharedGuest) return;
    if (!_app.wallet.canAfford(_bet)) return;
    if (sharedHost) {
      final seed = Random.secure().nextInt(1 << 31);
      sharedSend(seed);
      _dealRound(seed);
      return;
    }
    _dealRound(null);
  }

  void _dealRound(int? seed) {
    if (!_app.wallet.spend(_bet)) {
      setState(() => _message = 'Zu wenig Münzen, du setzt diese Runde aus');
      return;
    }
    _round++;
    _engine.deal(_bet, dealerCards: seed == null ? null : bjDealerCards(seed));
    sharedStake(_bet);
    _app.sfx.play(Sound.card);
    setState(() {
      _message = '';
      _big = false;
    });
    if (_engine.phase == BjPhase.settled) _finish();
  }

  void _nextPending() {
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _dealRound(next);
  }

  void _act(void Function() action) {
    if (_busy) return;
    action();
    _app.sfx.play(Sound.card);
    setState(() {});
    if (_engine.phase == BjPhase.dealerTurn) {
      _runDealer();
    } else if (_engine.phase == BjPhase.settled) {
      _finish();
    }
  }

  void _double() {
    if (!_app.wallet.spend(_engine.active.bet)) return;
    _act(_engine.doubleDown);
  }

  void _split() {
    if (!_app.wallet.spend(_engine.active.bet)) return;
    _act(_engine.split);
  }

  Future<void> _runDealer() async {
    final wallet = _app.wallet;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    while (mounted && _engine.dealerStep()) {
      _app.sfx.play(Sound.card);
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    if (!mounted) {
      // Die Runde läuft ohne Bildschirm zu Ende, damit kein Gewinn verloren geht.
      while (_engine.dealerStep()) {}
      wallet.credit(_engine.totalPayout);
      wallet.refillIfBroke();
      return;
    }
    _busy = false;
    _finish();
  }

  void _finish() {
    final paid = _engine.totalPayout;
    final bet = _engine.totalBet;
    _app.wallet.credit(paid);
    final bj = _engine.hands.any((h) => h.outcome == BjOutcome.blackjack);
    if (bj) progress.event('black_jack');
    setState(() {
      if (bj) {
        _message = 'Black Jack! +${formatCoins(paid - bet)}';
        _big = true;
        _app.sfx.play(Sound.bigWin);
      } else if (paid > bet) {
        _message = 'Gewonnen: +${formatCoins(paid - bet)}';
        _big = true;
        _app.sfx.play(Sound.win);
      } else if (paid == bet) {
        _message = 'Unentschieden, Einsatz zurück';
      } else if (paid > 0) {
        _message = 'Verloren: -${formatCoins(bet - paid)}';
        _app.sfx.play(Sound.lose);
      } else {
        _message = 'Die Bank gewinnt: -${formatCoins(bet)}';
        _app.sfx.play(Sound.lose);
      }
    });
    _app.wallet.refillIfBroke();
    if (!_app.wallet.canAfford(_bet)) {
      setState(() => _bet = 10);
    }
    _nextPending();
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      guide: blackjackGuide,
      title: 'Black Jack',
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > box.maxHeight * 1.15;
          final cardWidth = wide
              ? min(box.maxHeight * 0.26, 118.0).clamp(46.0, 118.0)
              : min(box.maxWidth / 5.2, box.maxHeight * 0.13).clamp(44.0, 118.0);
          final table = _Table(engine: _engine, cardWidth: cardWidth, round: _round);
          final controls = _controls(wide);
          if (wide) {
            return Row(
              children: [
                Expanded(child: table),
                SizedBox(
                  width: min(320, box.maxWidth * 0.36),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: controls,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _controls(bool wide) {
    final playing = _engine.phase == BjPhase.playerTurn && !_busy;
    final idle = _engine.phase == BjPhase.betting || _engine.phase == BjPhase.settled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBanner(text: _message, highlight: _big),
        sharedStakesBar(),
        const SizedBox(height: 4),
        if (idle) ...[
          BetPicker(
            value: _bet,
            onChanged: (v) {
              setState(() => _bet = v);
              sharedStake(_bet);
            },
          ),
          const SizedBox(height: 10),
          ActionButton(
            primary: true,
            label: sharedGuest ? 'Der Gastgeber teilt aus' : 'Austeilen: ${formatCoins(_bet)}',
            onPressed: !sharedGuest && _app.wallet.canAfford(_bet) ? _deal : null,
          ),
        ] else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionButton(
                primary: true,
                label: 'Karte',
                onPressed: playing ? () => _act(_engine.hit) : null,
              ),
              ActionButton(
                label: 'Halten',
                onPressed: playing ? () => _act(_engine.stand) : null,
              ),
              ActionButton(
                label: 'Verdoppeln',
                onPressed: playing &&
                        _engine.canDouble &&
                        _app.wallet.canAfford(_engine.active.bet)
                    ? _double
                    : null,
              ),
              ActionButton(
                label: 'Teilen',
                onPressed: playing &&
                        _engine.canSplit &&
                        _app.wallet.canAfford(_engine.active.bet)
                    ? _split
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.engine, required this.cardWidth, required this.round});
  final BlackjackEngine engine;
  final double cardWidth;
  final int round;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final labelStyle = TextStyle(
      color: p.onFelt,
      fontWeight: FontWeight.w700,
      fontSize: 17,
    );
    if (engine.hands.isEmpty) {
      return Center(
        child: Text(
          'Bank zieht bis 16\nund steht auf allen 17',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: 24,
            color: p.onFelt.withValues(alpha: 0.28),
          ),
        ),
      );
    }
    final hidden = engine.holeHidden;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hidden
                  ? 'Bank'
                  : 'Bank: ${engine.dealerScore.total}',
              style: labelStyle,
            ),
            const SizedBox(height: 6),
            _CardRow(
              cards: engine.dealer,
              hideIndex: hidden ? 0 : null,
              width: cardWidth,
              round: round,
              tag: 'bank',
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < engine.hands.length; i++)
              Flexible(
                child: _PlayerHand(
                  hand: engine.hands[i],
                  active: engine.phase == BjPhase.playerTurn &&
                      i == engine.activeIndex &&
                      engine.hands.length > 1,
                  width: engine.hands.length > 1 ? cardWidth * 0.85 : cardWidth,
                  round: round,
                  tag: 'hand$i',
                  style: labelStyle,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerHand extends StatelessWidget {
  const _PlayerHand({
    required this.hand,
    required this.active,
    required this.width,
    required this.round,
    required this.tag,
    required this.style,
  });

  final BjHand hand;
  final bool active;
  final double width;
  final int round;
  final String tag;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final score = hand.score;
    final state = switch (hand.outcome) {
      BjOutcome.blackjack => 'Black Jack',
      BjOutcome.win => 'Gewonnen',
      BjOutcome.push => 'Unentschieden',
      BjOutcome.lose => hand.busted ? 'Überkauft' : 'Verloren',
      null => hand.busted ? 'Überkauft' : null,
    };
    final soft = score.soft && score.total < 21 && hand.outcome == null;
    final total = soft ? '${score.total - 10} oder ${score.total}' : '${score.total}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CardRow(cards: hand.cards, width: width, round: round, tag: tag),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: active ? const Color(0x55FFC95C) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            state == null ? total : '$total, $state',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Karten leicht überlappend, Überlappung wächst mit der Kartenzahl.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.cards,
    required this.width,
    required this.round,
    required this.tag,
    this.hideIndex,
  });

  final List<PlayingCard> cards;
  final double width;
  final int round;
  final String tag;
  final int? hideIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final n = cards.length;
        final available = box.maxWidth.isFinite ? box.maxWidth - 8 : 500.0;
        final step = n <= 1
            ? width
            : min(width * 0.62, (available - width) / (n - 1)).clamp(10.0, width);
        final rowWidth = width + step * (n - 1);
        return SizedBox(
          width: rowWidth,
          height: width / cardAspect,
          child: Stack(
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: i * step,
                  child: DealIn(
                    key: ValueKey('$round-$tag-$i'),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: PlayingCardView(
                        key: ValueKey(i == hideIndex),
                        width: width,
                        card: i == hideIndex ? null : cards[i],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
