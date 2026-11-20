import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_shared_mixin.dart';
import '../../ui/widgets.dart';
import '../cards/playing_card.dart';
import 'baccarat_engine.dart';

const baccaratGuide = GameGuide('Baccarat', [
  GuideSection(
    'Ziel',
    'Du wettest, ob die Hand des Spielers oder der Bank näher an 9 kommt, oder auf Unentschieden. Du spielst die Karten nicht '
        'selbst, alles läuft nach festen Regeln.',
  ),
  GuideSection(
    'Kartenwerte',
    'Ass zählt 1, 2 bis 9 ihren Wert, Zehn und Bilder 0. Gezählt wird nur die Einerstelle: 7 und 8 ergeben 5.',
  ),
  GuideSection(
    'Dritte Karte',
    'Hat eine Seite mit zwei Karten 8 oder 9, ist Schluss. Sonst zieht der Spieler bei 0 bis 5 eine dritte Karte. Die Bank zieht '
        'nach einer Tabelle, die von ihrer Summe und der dritten Karte des Spielers abhängt.',
  ),
  GuideSection(
    'Auszahlung',
    'Spieler 1 : 1. Bank 0,95 : 1 (5 Prozent Gebühr). Unentschieden 8 : 1, dann bleiben Wetten auf Spieler und Bank stehen. '
        'Paar (die ersten zwei Karten gleich) 11 : 1. Tippe ein Feld an, um den gewählten Chip zu setzen.',
  ),
]);

class BaccaratScreen extends StatefulWidget {
  const BaccaratScreen({super.key});

  @override
  State<BaccaratScreen> createState() => _BaccaratScreenState();
}

class _BaccaratScreenState extends State<BaccaratScreen> with NetSharedTable {
  final _shoe = BaccaratShoe();
  final Map<BacBet, int> _bets = {};
  int _chip = 50;
  BacRound? _round;
  int _shownP = 0;
  int _shownB = 0;
  bool _dealing = false;
  String _message = 'Setze auf Spieler, Bank oder Unentschieden';
  bool _big = false;

  AppScope get _app => AppScope.of(context);
  int get _total => _bets.values.fold(0, (a, b) => a + b);

  @override
  void dispose() {
    sharedDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get sharedGame => 'baccarat';
  @override
  String get sharedTitle => 'Baccarat';
  BacRound? _pending;

  /// Runde vom Gastgeber: gleiche Karten für alle, jeder rechnet seine Einsätze selbst ab.
  @override
  void sharedResult(Object? outcome) {
    final r = bacRoundFromJson(outcome);
    if (r == null) return;
    if (_dealing) {
      _pending = r;
      return;
    }
    _shoe.record(r);
    _play(r);
  }

  void _place(BacBet b) {
    if (_dealing) return;
    if (!sharedWallet.canAfford(_total + _chip)) return;
    _app.sfx.play(Sound.chip);
    setState(() {
      _bets[b] = (_bets[b] ?? 0) + _chip;
      _round = null;
    });
    sharedStake(_total);
  }

  void _clear() {
    setState(_bets.clear);
    sharedStake(0);
  }

  Future<void> _deal() async {
    if (_dealing || sharedGuest) return;
    // Am Netztisch teilt der Gastgeber auch ohne eigenen Einsatz aus
    if (_total == 0 && !sharedHost) return;
    if (!sharedWallet.canAfford(_total)) return;
    final r = _shoe.play();
    sharedSend(bacRoundToJson(r));
    await _play(r);
  }

  Future<void> _play(BacRound r) async {
    // Wer sich den Einsatz nicht mehr leisten kann, schaut nur zu
    if (_total > 0 && !sharedWallet.spend(_total)) _bets.clear();
    final stake = _total;
    setState(() {
      _dealing = true;
      _round = r;
      _shownP = 0;
      _shownB = 0;
      _message = '';
      _big = false;
    });
    Future<void> step(void Function() f) async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      _app.sfx.play(Sound.card);
      setState(f);
    }

    await step(() => _shownP = 1);
    await step(() => _shownB = 1);
    await step(() => _shownP = 2);
    await step(() => _shownB = 2);
    if (r.player.length > 2) await step(() => _shownP = 3);
    if (r.banker.length > 2) await step(() => _shownB = 3);
    if (!mounted) return;
    if (stake == 0) {
      setState(() {
        _dealing = false;
        _message = '${_who(r)}, ${r.playerTotal} zu ${r.bankerTotal}';
      });
      _next();
      return;
    }
    var paid = 0;
    for (final e in _bets.entries) {
      paid += r.payout(e.key, e.value);
    }
    if (paid > 0) sharedWallet.credit(paid);
    final net = paid - stake;
    _app.sfx.play(net > 0 ? Sound.win : (net == 0 ? Sound.tick : Sound.lose));
    setState(() {
      _dealing = false;
      _big = net >= stake * 5 && net > 0;
      _message = '${_who(r)}, ${r.playerTotal} zu ${r.bankerTotal}. '
          '${net > 0 ? 'Du gewinnst ${formatCoins(net)}' : (net == 0 ? 'Einsatz zurück' : 'Verloren')}';
    });
    sharedWallet.refillIfBroke();
    _next();
  }

  String _who(BacRound r) => switch (r.winner) {
        BacWinner.player => 'Spieler gewinnt',
        BacWinner.banker => 'Bank gewinnt',
        BacWinner.tie => 'Unentschieden',
      };

  void _next() {
    final next = _pending;
    _pending = null;
    if (next != null && mounted) {
      _shoe.record(next);
      _play(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Baccarat',
      guide: baccaratGuide,
      background: const BoxDecoration(gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF14504A), Color(0xFF07211E)])),
      actions: sharedActions(context),
      network: sharedActive ? null : sharedOpenPanel,
      child: sharedScreen() ?? LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final cw = math.min(84.0, w / 8);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  _road(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _side('Spieler', _round?.player ?? const [], _shownP, cw, const Color(0xFF1F4E9A))),
                      const SizedBox(width: 8),
                      Expanded(child: _side('Bank', _round?.banker ?? const [], _shownB, cw, const Color(0xFFC62828))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ResultBanner(text: _message, highlight: _big, maxLines: 2),
                  sharedStakesBar(),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [for (final b in BacBet.values) _field(b)],
                  ),
                  const SizedBox(height: 10),
                  BetPicker(value: _chip, onChanged: (v) => setState(() => _chip = v), enabled: !_dealing),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionButton(label: 'Löschen', onPressed: _dealing || _bets.isEmpty ? null : _clear),
                      ActionButton(
                        primary: true,
                        label: sharedGuest ? 'Der Gastgeber teilt aus' : (_total == 0 ? 'Austeilen' : 'Austeilen: ${formatCoins(_total)}'),
                        onPressed: _dealing || sharedGuest || (_total == 0 && !sharedHost) || !sharedWallet.canAfford(_total) ? null : _deal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _side(String name, List<PlayingCard> cards, int shown, double cw, Color color) {
    final total = shown == 0 ? '' : ' · ${bacTotal(cards.take(shown).toList())}';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 2)),
      child: Column(
        children: [
          Text('$name$total', style: const TextStyle(color: Color(0xFFF6E7C8), fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SizedBox(
            height: cw / cardAspect,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < shown; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: DealIn(key: ValueKey('$name$i${_round.hashCode}'), child: PlayingCardView(width: cw * (i == 2 ? 0.9 : 1), card: cards[i])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BacBet b) {
    final pal = Palette.of(context);
    final amount = _bets[b] ?? 0;
    final odds = switch (b) {
      BacBet.player => '1 : 1',
      BacBet.banker => '0,95 : 1',
      BacBet.tie => '8 : 1',
      _ => '11 : 1',
    };
    return GestureDetector(
      onTap: () => _place(b),
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: pal.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: amount > 0 ? const Color(0xFFFFC95C) : pal.panelEdge, width: amount > 0 ? 3 : 1.5),
        ),
        child: Column(
          children: [
            Text(bacBetNames[b]!, style: TextStyle(color: pal.ink, fontWeight: FontWeight.w800)),
            Text(odds, style: TextStyle(color: pal.inkSoft, fontSize: 12)),
            if (amount > 0) Text(formatCoins(amount), style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  /// Verlauf der letzten Runden als farbige Punkte.
  Widget _road() {
    final h = _shoe.history.reversed.take(30).toList().reversed.toList();
    if (h.isEmpty) return const SizedBox(height: 18);
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: [
        for (final w in h)
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (w) {
                BacWinner.player => const Color(0xFF1F4E9A),
                BacWinner.banker => const Color(0xFFC62828),
                BacWinner.tie => const Color(0xFF2E7D32),
              },
            ),
            child: Text(
              switch (w) { BacWinner.player => 'S', BacWinner.banker => 'B', BacWinner.tie => 'U' },
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}
