import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/wallet.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/playing_card.dart';
import 'three_card_engine.dart';

const threeCardGuide = GameGuide('Three Card Poker', [
  GuideSection(
    'So geht es',
    'Setze das Ante und auf Wunsch Paar Plus. Du und die Bank bekommen je drei Karten. Nach dem Blick auf deine Karten '
        'steigst du aus (Ante verloren) oder spielst weiter und setzt dafür noch einmal so viel wie das Ante.',
  ),
  GuideSection(
    'Die Bank',
    'Die Bank spielt erst ab Dame hoch. Spielt sie nicht, bekommst du das Ante 1 : 1 und den zweiten Einsatz zurück. '
        'Spielt sie, gewinnt die bessere Hand beide Einsätze 1 : 1.',
  ),
  GuideSection(
    'Rangfolge',
    'Straight Flush, Drilling, Straße, Flush, Paar, höchste Karte. Mit drei Karten ist eine Straße seltener als ein Flush, '
        'darum steht sie höher. A-2-3 ist die kleinste Straße.',
  ),
  GuideSection(
    'Boni',
    'Ante-Bonus, auch wenn die Bank gewinnt: Straße 1 : 1, Drilling 4 : 1, Straight Flush 5 : 1.\n'
        'Paar Plus zählt nur deine Hand: Paar 1 : 1, Flush 4 : 1, Straße 6 : 1, Drilling 30 : 1, Straight Flush 40 : 1.',
  ),
  GuideSection('Tipp', 'Weiterspielen lohnt sich ab Dame-6-4 oder besser. Der Knopf „Tipp“ zeigt es dir.'),
]);

class ThreeCardScreen extends StatefulWidget {
  const ThreeCardScreen({super.key, this.seed});
  final int? seed;

  @override
  State<ThreeCardScreen> createState() => _ThreeCardScreenState();
}

class _ThreeCardScreenState extends State<ThreeCardScreen> with NetSharedTable {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  int _ante = 10;
  bool _pairPlusOn = false;
  TcRound? _round;
  bool _deciding = false;
  bool _revealed = false;
  String _message = 'Ante wählen und austeilen';
  bool _big = false;
  int? _pending;

  AppScope get _app => AppScope.of(context);
  int get _pp => _pairPlusOn ? _ante : 0;

  /// Für dispose gemerkt (dort darf nicht mehr nach AppScope gesucht werden).
  Wallet? _wallet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet ??= _app.wallet;
  }

  @override
  void dispose() {
    // Mitten in der Entscheidung gehen gilt als Aussteigen
    if (_deciding) {
      final r = _round!.fold();
      if (r.paid > 0 && !sharedTournament) _wallet?.credit(r.paid);
    }
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'threecard';
  @override
  String get sharedTitle => 'Three Card Poker';

  /// Runde vom Gastgeber: Die Bank hat bei allen dieselben drei Karten.
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
    if (sharedGuest || !sharedWallet.canAfford(2 * _ante + _pp)) return;
    if (sharedHost) {
      final seed = _rng.nextInt(1 << 31);
      sharedSend(seed);
      _dealRound(seed);
      return;
    }
    _dealRound(null);
  }

  void _dealRound(int? seed) {
    if (!sharedWallet.canAfford(2 * _ante + _pp) || !sharedWallet.spend(_ante + _pp)) {
      setState(() => _message = 'Zu wenig Münzen, du setzt diese Runde aus');
      return;
    }
    // Am Netztisch: Bankkarten aus dem Startwert, die eigenen aus dem Rest
    final dealer = seed == null ? null : shuffledDeck(math.Random(seed)).sublist(0, 3);
    final round = TcRound.deal(_rng, ante: _ante, pairPlus: _pp, dealerCards: dealer);
    sharedStake(_ante + _pp);
    _app.sfx.play(Sound.card);
    setState(() {
      _round = round;
      _deciding = true;
      _revealed = false;
      _big = false;
      _message = 'Du hast ${tcRankNames[round.player.rank]}. Weiterspielen oder aussteigen?';
    });
  }

  void _fold() => _settle(_round!.fold(), folded: true);

  void _play() {
    if (!sharedWallet.spend(_ante)) return;
    _settle(_round!.play());
  }

  void _settle(TcResult r, {bool folded = false}) {
    final round = _round!;
    if (r.paid > 0) sharedWallet.credit(r.paid);
    final staked = round.ante + round.pairPlus + (folded ? 0 : round.ante);
    final net = r.paid - staked;
    debugLog.info('threecard', '${tcRankNames[round.player.rank]} gegen ${tcRankNames[round.dealer.rank]}: ${r.text}, Saldo $net');
    _app.sfx.play(net > 0 ? Sound.win : (net == 0 ? Sound.tick : Sound.lose));
    final pp = round.pairPlusPaid > 0 ? ' Paar Plus +${formatCoins(round.pairPlusPaid - round.pairPlus)}.' : '';
    setState(() {
      _deciding = false;
      _revealed = true;
      _big = net >= staked * 3 && net > 0;
      _message = folded
          ? 'Ausgestiegen. Die Bank hatte ${tcRankNames[round.dealer.rank]}.$pp'
          : '${r.text}: ${tcRankNames[round.player.rank]} gegen ${tcRankNames[round.dealer.rank]}'
              '${r.dealerQualifies ? '' : ' (spielt nicht)'}. ${net > 0 ? '+${formatCoins(net)}' : (net == 0 ? 'Einsatz zurück' : formatCoins(net))}.$pp';
    });
    sharedWallet.refillIfBroke();
    final next = _pending;
    _pending = null;
    if (next != null && mounted) _dealRound(next);
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    const ink = Color(0xFFF6E7C8);
    return GameFrame(
      title: 'Three Card Poker',
      guide: threeCardGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF5B1E3C), Color(0xFF220A16)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? LayoutBuilder(builder: (context, box) {
        final cw = math.min(100.0, (box.maxWidth - 40) / 3.6);
        Widget row(List<PlayingCard>? cards, {bool hidden = false}) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: PlayingCardView(width: cw, card: cards == null || hidden ? null : cards[i]),
                  ),
              ],
            );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const Text('Bank', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              row(round?.dealer.cards, hidden: !_revealed),
              SizedBox(
                height: 24,
                child: _revealed && round != null
                    ? Text(
                        '${tcRankNames[round.dealer.rank]}${round.dealer.qualifies ? '' : ' – spielt nicht'}',
                        style: const TextStyle(color: Color(0xFFFFC95C)),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              const Text('Du', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              row(round?.player.cards),
              SizedBox(
                height: 24,
                child: round != null ? Text(tcRankNames[round.player.rank]!, style: const TextStyle(color: Color(0xFFFFC95C))) : null,
              ),
              const SizedBox(height: 8),
              ResultBanner(text: _message, highlight: _big, maxLines: 3),
              sharedStakesBar(),
              const SizedBox(height: 10),
              if (_deciding)
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  ActionButton(label: 'Aussteigen', onPressed: _fold),
                  ActionButton(primary: true, label: 'Spielen: ${formatCoins(_ante)}', onPressed: sharedWallet.canAfford(_ante) ? _play : null),
                  ActionButton(
                    label: 'Tipp',
                    onPressed: () => setState(() => _message = tcShouldPlay(round!.player)
                        ? 'Tipp: weiterspielen, deine Hand ist mindestens Dame-6-4'
                        : 'Tipp: aussteigen, deine Hand ist schwächer als Dame-6-4'),
                  ),
                ])
              else ...[
                BetPicker(
                  value: _ante,
                  onChanged: (v) {
                    setState(() => _ante = v);
                    sharedStake(_ante + _pp);
                  },
                ),
                const SizedBox(height: 4),
                FilterChip(
                  label: Text('Paar Plus: ${formatCoins(_ante)}'),
                  selected: _pairPlusOn,
                  onSelected: (v) {
                    setState(() => _pairPlusOn = v);
                    sharedStake(_ante + _pp);
                  },
                ),
                const SizedBox(height: 6),
                Text('Du brauchst ${formatCoins(2 * _ante + _pp)} (Ante, Weiterspielen${_pairPlusOn ? ', Paar Plus' : ''})',
                    style: const TextStyle(color: ink)),
                const SizedBox(height: 8),
                ActionButton(
                  primary: true,
                  label: sharedGuest ? 'Der Gastgeber teilt aus' : 'Austeilen: ${formatCoins(_ante + _pp)}',
                  onPressed: !sharedGuest && sharedWallet.canAfford(2 * _ante + _pp) ? _deal : null,
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}
