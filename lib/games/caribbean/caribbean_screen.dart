import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/hand_eval.dart';
import '../cards/playing_card.dart';
import '../holdem/holdem_engine.dart' show handName;

/// Caribbean Stud Poker gegen die Bank: Ante, fünf Karten, aussteigen oder erhöhen.

const caribbeanPays = {
  HandCategory.highCard: 1,
  HandCategory.pair: 1,
  HandCategory.twoPair: 2,
  HandCategory.trips: 3,
  HandCategory.straight: 4,
  HandCategory.flush: 5,
  HandCategory.fullHouse: 7,
  HandCategory.quads: 20,
  HandCategory.straightFlush: 50,
  HandCategory.royalFlush: 100,
};

/// Die Bank spielt mit Ass und König oder besser.
bool dealerQualifies(HandValue v) {
  if (v.category != HandCategory.highCard) return true;
  return v.ranks.isNotEmpty && v.ranks[0] == 14 && v.ranks.length > 1 && v.ranks[1] == 13;
}

/// Ergebnis mit Einsatz: (Auszahlung, Text). ante: Einsatz, raise = 2 × ante.
(int, String) caribbeanSettle(HandValue me, HandValue dealer, int ante) {
  final raise = 2 * ante;
  if (!dealerQualifies(dealer)) return (ante * 2 + raise, 'Die Bank spielt nicht mit: Ante 1 : 1, Erhöhung zurück');
  final c = me.compareTo(dealer);
  if (c > 0) {
    final pay = caribbeanPays[me.category]!;
    return (ante * 2 + raise + raise * pay, 'Gewonnen mit ${handName(me)}: Erhöhung $pay : 1');
  }
  if (c == 0) return (ante + raise, 'Gleichstand: Einsätze zurück');
  return (0, 'Die Bank gewinnt mit ${handName(dealer)}');
}

const caribbeanGuide = GameGuide('Caribbean Stud', [
  GuideSection(
    'Ziel',
    'Du spielst Fünf-Karten-Poker gegen die Bank. Du setzt das Ante und bekommst fünf Karten, die Bank auch, eine davon offen.',
  ),
  GuideSection(
    'Entscheiden',
    'Aussteigen kostet das Ante. Spielst du weiter, setzt du das Doppelte des Ante dazu. Die Bank braucht mindestens Ass und König; '
        'hat sie das nicht, bekommst du das Ante 1 : 1 und die Erhöhung zurück.',
  ),
  GuideSection(
    'Auszahlung der Erhöhung',
    'Ein Paar oder weniger 1 : 1, zwei Paare 2 : 1, Drilling 3 : 1, Straße 4 : 1, Flush 5 : 1, Full House 7 : 1, Vierling 20 : 1, '
        'Straight Flush 50 : 1, Royal Flush 100 : 1. Das Ante zahlt 1 : 1.',
  ),
]);

class CaribbeanScreen extends StatefulWidget {
  const CaribbeanScreen({super.key});

  @override
  State<CaribbeanScreen> createState() => _CaribbeanScreenState();
}

class _CaribbeanScreenState extends State<CaribbeanScreen> with NetSharedTable {
  final _rng = math.Random.secure();
  int _ante = 10;
  List<PlayingCard> _me = [];
  List<PlayingCard> _dealer = [];
  bool _deciding = false;
  bool _revealed = false;
  String _message = 'Setze dein Ante';
  bool _big = false;

  AppScope get _app => AppScope.of(context);

  @override
  void dispose() {
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'caribbean';
  @override
  String get sharedTitle => 'Caribbean Stud';
  int? _pending;

  /// Runde vom Gastgeber: Die Bank hat bei allen dieselben fünf Karten, jeder bekommt eigene.
  @override
  void sharedResult(Object? outcome) {
    final seed = (outcome as num?)?.toInt();
    if (seed == null) return;
    if (_deciding) {
      _pending = seed;
      return;
    }
    _dealRound(seed);
  }

  void _deal() {
    if (sharedGuest || !_app.wallet.canAfford(3 * _ante)) return;
    if (sharedHost) {
      final seed = _rng.nextInt(1 << 31);
      sharedSend(seed);
      _dealRound(seed);
      return;
    }
    _dealRound(null);
  }

  void _nextPending() {
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _dealRound(next);
  }

  void _dealRound(int? seed) {
    if (!_app.wallet.canAfford(3 * _ante) || !_app.wallet.spend(_ante)) {
      setState(() => _message = 'Zu wenig Münzen, du setzt diese Runde aus');
      return;
    }
    // Am Netztisch: Bankkarten aus dem Startwert, die eigenen aus dem Rest des Spiels
    final deck = shuffledDeck(seed == null ? _rng : math.Random(seed));
    final dealer = deck.sublist(5, 10);
    final rest = [...deck.sublist(0, 5), ...deck.sublist(10)];
    if (seed != null) rest.shuffle(_rng);
    sharedStake(_ante);
    _app.sfx.play(Sound.card);
    setState(() {
      _me = rest.sublist(0, 5);
      _dealer = dealer;
      _deciding = true;
      _revealed = false;
      _big = false;
      _message = 'Du hast ${handName(bestHand(_me))}. Weiterspielen für ${formatCoins(2 * _ante)}?';
    });
  }

  void _fold() {
    _app.sfx.play(Sound.lose);
    setState(() {
      _deciding = false;
      _revealed = true;
      _message = 'Ausgestiegen, das Ante ist weg. Die Bank hatte ${handName(bestHand(_dealer))}';
    });
    _app.wallet.refillIfBroke();
    _nextPending();
  }

  void _raise() {
    if (!_app.wallet.spend(2 * _ante)) return;
    final (paid, text) = caribbeanSettle(bestHand(_me), bestHand(_dealer), _ante);
    if (paid > 0) _app.wallet.credit(paid);
    _app.wallet.refillIfBroke();
    _app.sfx.play(paid > 3 * _ante ? Sound.win : (paid > 0 ? Sound.coin : Sound.lose));
    setState(() {
      _deciding = false;
      _revealed = true;
      _big = paid >= 20 * _ante;
      _message = '$text${paid > 3 * _ante ? ' · +${formatCoins(paid - 3 * _ante)}' : ''}';
    });
    _nextPending();
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Caribbean Stud',
      guide: caribbeanGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF0E5E6B), Color(0xFF05262B)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? LayoutBuilder(builder: (context, box) {
        final cw = math.min(84.0, (box.maxWidth - 40) / 5.6);
        Widget row(List<PlayingCard> cards, {bool hideAfterFirst = false}) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: PlayingCardView(width: cw, card: hideAfterFirst && i > 0 ? null : cards[i]),
                  ),
              ],
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Bank', style: TextStyle(color: Color(0xFFF6E7C8), fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              if (_dealer.isNotEmpty) row(_dealer, hideAfterFirst: !_revealed) else SizedBox(height: cw / cardAspect),
              if (_revealed) Text(handName(bestHand(_dealer)), style: const TextStyle(color: Color(0xFFFFC95C))),
              const SizedBox(height: 18),
              const Text('Du', style: TextStyle(color: Color(0xFFF6E7C8), fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              if (_me.isNotEmpty) row(_me) else SizedBox(height: cw / cardAspect),
              const SizedBox(height: 12),
              ResultBanner(text: _message, highlight: _big, maxLines: 2),
              sharedStakesBar(),
              const SizedBox(height: 10),
              if (_deciding)
                Wrap(spacing: 8, children: [
                  ActionButton(label: 'Aussteigen', onPressed: _fold),
                  ActionButton(primary: true, label: 'Erhöhen: ${formatCoins(2 * _ante)}', onPressed: _app.wallet.canAfford(2 * _ante) ? _raise : null),
                ])
              else ...[
                BetPicker(
                  value: _ante,
                  onChanged: (v) {
                    setState(() => _ante = v);
                    sharedStake(_ante);
                  },
                ),
                const SizedBox(height: 8),
                Text('Du brauchst Ante plus das Doppelte: ${formatCoins(3 * _ante)}', style: const TextStyle(color: Color(0xFFF6E7C8))),
                const SizedBox(height: 8),
                ActionButton(
                  primary: true,
                  label: sharedGuest ? 'Der Gastgeber teilt aus' : 'Austeilen: ${formatCoins(_ante)}',
                  onPressed: !sharedGuest && _app.wallet.canAfford(3 * _ante) ? _deal : null,
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
