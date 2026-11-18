import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import 'bingo_engine.dart';

const bingoGuide = GameGuide('Bingo', [
  GuideSection(
    'Ablauf',
    'Kauf eine bis vier Karten. Die Kugeln werden nacheinander gezogen; jede Zahl, die auf deiner Karte steht, wird markiert. '
        'Wer zuerst das Gewinnmuster voll hat, gewinnt den Pot. Haben mehrere es mit derselben Kugel, wird geteilt. '
        'Die Mitspieler kaufen ebenfalls Karten; 85 % aller Kartenpreise gehen in den Pot.',
  ),
  GuideSection(
    '75 Kugeln (USA)',
    'Karte 5 × 5, die Spalten stehen für B (1–15), I (16–30), N (31–45), G (46–60) und O (61–75). Die Mitte ist frei. '
        'Vor dem Spiel wählst du das Muster: Linie (Reihe, Spalte oder Diagonale), Vier Ecken, Großes X oder Volle Karte.',
  ),
  GuideSection(
    '90 Kugeln (UK)',
    'Karte 3 × 9 mit 15 Zahlen, jede Reihe hat fünf. Gespielt wird in drei Stufen: zuerst eine volle Reihe (15 % des Pots), '
        'dann zwei volle Reihen (25 %), dann die volle Karte (60 %).',
  ),
  GuideSection(
    'Selbst markieren',
    'Mit „Automatisch markieren“ aus tippst du die gezogenen Zahlen selbst an und rufst „Bingo!“. Das muss vor der nächsten '
        'Kugel passieren, sonst verfällt dein Anteil.',
  ),
]);

const _botNames = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst', 'Inge', 'Dieter', 'Gisela', 'Manni', 'Uschi', 'Erwin'];

class BingoScreen extends StatefulWidget {
  const BingoScreen({super.key, this.seed});
  final int? seed;

  @override
  State<BingoScreen> createState() => _BingoScreenState();
}

class _BingoScreenState extends State<BingoScreen> {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final Wallet _wallet = AppScope.of(context).wallet;

  BingoVariant _variant = BingoVariant.us75;
  BingoPattern _pattern = BingoPattern.line;
  int _cards = 2;
  int _bots = 5;
  int _price = 50;
  bool _autoDaub = true;
  int _speedMs = 1500;

  BingoGame? _game;
  BingoPlayer? _me;
  Timer? _timer;
  bool _paused = false;
  final Set<int> _marked = {};

  /// Selbst markieren: eigene Gewinne, die noch per „Bingo!“ gerufen werden müssen.
  List<BingoWin> _pending = [];
  final List<String> _log = [];
  int _earned = 0;
  String _message = '';

  AppScope get _app => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final cost = _cards * _price;
    if (!_wallet.spend(cost)) return;
    final names = [..._botNames]..shuffle(_rng);
    final me = BingoPlayer('Du', human: true)..cards.addAll(BingoGame.dealCards(_variant, _cards, _rng));
    final players = [
      me,
      for (var i = 0; i < _bots; i++) BingoPlayer(names[i])..cards.addAll(BingoGame.dealCards(_variant, 1 + _rng.nextInt(3), _rng)),
    ];
    setState(() {
      _game = BingoGame(variant: _variant, players: players, cardPrice: _price, pattern: _pattern, rng: _rng);
      _me = me;
      _marked.clear();
      _pending = [];
      _log.clear();
      _earned = 0;
      _paused = false;
      _message = 'Pot ${formatCoins(_game!.pot)} · los geht’s';
    });
    debugLog.info('bingo', '${_variant == BingoVariant.us75 ? '75' : '90'} Kugeln, $_cards Karten à $_price, ${players.length} Spieler, Pot ${_game!.pot}');
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _speedMs), (_) => _call());
  }

  void _call() {
    final g = _game;
    if (g == null || _paused) return;
    if (g.over) {
      _timer?.cancel();
      return;
    }
    // Nicht gerufene eigene Gewinne verfallen mit der nächsten Kugel
    if (_pending.isNotEmpty) {
      _log.add('Nicht „Bingo!“ gerufen – Anteil verfallen');
      _pending = [];
    }
    final wins = g.callNext();
    _app.sfx.play(Sound.tick);
    final ball = g.called.last;
    if (_autoDaub && _me!.cards.any((c) => c.numbers.contains(ball))) _marked.add(ball);
    for (final w in wins) {
      if (w.player.human && !_autoDaub) {
        _pending.add(w);
        continue;
      }
      _pay(w);
    }
    setState(() {
      _message = wins.isEmpty
          ? ''
          : wins.any((w) => w.player.human)
              ? (_autoDaub ? 'BINGO! ${g.stageName(wins.first.stage)}' : 'Du hast es! Schnell „Bingo!“ rufen')
              : 'Bingo bei ${wins.map((w) => w.player.name).toSet().join(' und ')}: ${g.stageName(wins.first.stage)}';
    });
    if (wins.isNotEmpty) _app.sfx.play(wins.any((w) => w.player.human) ? Sound.bigWin : Sound.lose);
    if (g.over) {
      _timer?.cancel();
      if (_pending.isEmpty) _finish();
    }
  }

  void _pay(BingoWin w) {
    final g = _game!;
    _log.add('${g.stageName(w.stage)}: ${w.player.name} ${formatCoins(w.amount)}');
    if (w.player.human) {
      _wallet.credit(w.amount);
      _earned += w.amount;
    }
  }

  void _claim() {
    if (_pending.isEmpty) {
      setState(() => _message = 'Noch kein Bingo');
      return;
    }
    for (final w in _pending) {
      _pay(w);
    }
    _pending = [];
    _app.sfx.play(Sound.bigWin);
    setState(() => _message = 'BINGO!');
    if (_game!.over) _finish();
  }

  void _finish() {
    debugLog.info('bingo', 'Ende nach ${_game!.called.length} Kugeln, du: +$_earned · ${_log.join('; ')}');
    _wallet.refillIfBroke();
    setState(() {});
  }

  void _quit() {
    _timer?.cancel();
    // Aussteigen: bereits gezahlte Karten sind weg, offene Gewinne verfallen
    setState(() {
      _game = null;
      _message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return GameFrame(
      title: 'Bingo',
      guide: bingoGuide,
      child: g == null ? _setup() : _table(g),
    );
  }

  Widget _setup() {
    final p = Palette.of(context);
    final style = TextStyle(color: p.onFelt, fontSize: 16);
    Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: style.copyWith(fontWeight: FontWeight.w700)));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListenableBuilder(
            listenable: _wallet,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label('Spielart'),
                SegmentedButton<BingoVariant>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: BingoVariant.us75, label: Text('75 Kugeln (USA)')),
                    ButtonSegment(value: BingoVariant.uk90, label: Text('90 Kugeln (UK)')),
                  ],
                  selected: {_variant},
                  onSelectionChanged: (s) => setState(() => _variant = s.first),
                ),
                if (_variant == BingoVariant.us75) ...[
                  label('Gewinnmuster'),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final pt in BingoPattern.values)
                      ChoiceChip(label: Text(bingoPatternNames[pt]!), selected: _pattern == pt, onSelected: (_) => setState(() => _pattern = pt)),
                  ]),
                ] else
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text('Eine Reihe, dann zwei Reihen, dann volle Karte', style: style)),
                label('Deine Karten'),
                Wrap(spacing: 8, children: [
                  for (var n = 1; n <= 4; n++) ChoiceChip(label: Text('$n'), selected: _cards == n, onSelected: (_) => setState(() => _cards = n)),
                ]),
                label('Preis je Karte'),
                Wrap(spacing: 8, children: [
                  for (final pr in const [10, 50, 100, 500])
                    ChoiceChip(label: Text(formatCoins(pr)), selected: _price == pr, onSelected: (_) => setState(() => _price = pr)),
                ]),
                label('Mitspieler (Computer)'),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  for (var n = 1; n <= 9; n++) ChoiceChip(label: Text('$n'), selected: _bots == n, onSelected: (_) => setState(() => _bots = n)),
                ]),
                label('Tempo'),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 2500, label: Text('Gemütlich')),
                    ButtonSegment(value: 1500, label: Text('Normal')),
                    ButtonSegment(value: 800, label: Text('Schnell')),
                  ],
                  selected: {_speedMs},
                  onSelectionChanged: (s) => setState(() => _speedMs = s.first),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Automatisch markieren', style: style),
                  subtitle: Text('Aus: selbst antippen und „Bingo!“ rufen', style: style.copyWith(fontSize: 14)),
                  value: _autoDaub,
                  onChanged: (v) => setState(() => _autoDaub = v),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ActionButton(
                    primary: true,
                    label: 'Spielen: ${formatCoins(_cards * _price)}',
                    onPressed: _wallet.canAfford(_cards * _price) ? _start : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _letter(int n) => _variant == BingoVariant.us75 ? 'BINGO'[(n - 1) ~/ 15] : '';

  Widget _ball(int n, double size, {bool latest = false}) {
    const colors = [Color(0xFF1E88E5), Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF8E24AA)];
    final c = _game!.variant == BingoVariant.us75 ? colors[(n - 1) ~/ 15] : colors[(n - 1) * 5 ~/ 91];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(c, Colors.white, 0.5)!, c]),
        border: Border.all(color: latest ? Colors.white : const Color(0x55000000), width: latest ? 3 : 1),
      ),
      child: Container(
        width: size * 0.62,
        height: size * 0.62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_letter(n).isNotEmpty) Text(_letter(n), style: const TextStyle(fontWeight: FontWeight.w800, height: 1, color: Color(0xFF241410))),
                Text('$n', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, height: 1.05, color: Color(0xFF241410))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(BingoGame g) {
    final p = Palette.of(context);
    final me = _me!;
    final d = g.drawn;
    final last = g.called.reversed.take(6).toList();
    final stageLine = g.over
        ? 'Spiel vorbei · du: +${formatCoins(_earned)}'
        : '${g.stageName(g.stage)} · ${formatCoins(g.prizeFor(g.stage))} · Kugel ${g.called.length}';
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.2;
        final cardW = math.min(wide ? box.maxWidth * 0.3 : box.maxWidth - 24, 360.0);
        final cards = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final c in me.cards)
              SizedBox(
                width: me.cards.length > 1 && !wide ? (box.maxWidth - 34) / 2 : cardW,
                child: _CardView(
                  card: c,
                  variant: g.variant,
                  isMarked: (n) => _autoDaub ? d.contains(n) : _marked.contains(n),
                  winning: c.winningCells(g.variant, d, pattern: g.pattern, stage: math.max(0, math.min(g.stage, g.stages) - 1)),
                  missing: g.over ? null : c.missing(g.variant, d, pattern: g.pattern, stage: g.stage),
                  onTap: _autoDaub
                      ? null
                      : (n) => setState(() {
                            if (d.contains(n)) _marked.add(n);
                          }),
                ),
              ),
          ],
        );
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (last.isNotEmpty) _ball(last.first, 76, latest: true) else const SizedBox(width: 76, height: 76),
                const SizedBox(width: 10),
                for (final n in last.skip(1)) Padding(padding: const EdgeInsets.only(right: 4), child: _ball(n, 36)),
              ],
            ),
            const SizedBox(height: 6),
            Text(stageLine, style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Pot ${formatCoins(g.pot)} · ${g.players.length} Spieler · ${g.players.fold(0, (a, p) => a + p.cards.length)} Karten',
                style: TextStyle(color: p.onFelt, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: [
                for (final pl in g.players.where((x) => !x.human))
                  Text(
                    '${pl.name} ${g.over ? '' : 'noch ${pl.cards.map((c) => c.missing(g.variant, d, pattern: g.pattern, stage: g.stage)).reduce(math.min)}'}',
                    style: TextStyle(color: p.onFelt.withValues(alpha: 0.8), fontSize: 13),
                  ),
              ],
            ),
          ],
        );
        final controls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResultBanner(text: _message, highlight: _message.startsWith('BINGO') || _message.startsWith('Du hast')),
            if (g.over) ...[
              for (final l in _log) Text(l, style: TextStyle(color: p.onFelt, fontSize: 14)),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: g.over && _pending.isEmpty
                  ? [
                      ActionButton(primary: true, label: 'Noch eine Runde: ${formatCoins(_cards * _price)}', onPressed: _wallet.canAfford(_cards * _price) ? _start : null),
                      ActionButton(label: 'Einstellungen', onPressed: _quit),
                    ]
                  : [
                      if (!_autoDaub) ActionButton(primary: true, label: 'Bingo!', onPressed: _claim),
                      if (g.over) ActionButton(label: 'Aufgeben', onPressed: () => setState(() {
                            _pending = [];
                            _finish();
                          })),
                      if (!g.over) ActionButton(label: _paused ? 'Weiter' : 'Pause', onPressed: () => setState(() => _paused = !_paused)),
                      ActionButton(label: 'Aussteigen', onPressed: _quit),
                    ],
            ),
          ],
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: cards))),
              SizedBox(
                width: math.min(360, box.maxWidth * 0.4),
                child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [header, const SizedBox(height: 10), controls]))),
              ),
            ],
          );
        }
        return Column(
          children: [
            Padding(padding: const EdgeInsets.only(top: 10), child: header),
            Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: cards))),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 12), child: controls),
          ],
        );
      },
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.variant, required this.isMarked, required this.winning, this.missing, this.onTap});
  final BingoCard card;
  final BingoVariant variant;
  final bool Function(int) isMarked;
  final Set<(int, int)> winning;
  final int? missing;
  final void Function(int)? onTap;

  @override
  Widget build(BuildContext context) {
    final us = variant == BingoVariant.us75;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: winning.isNotEmpty ? const Color(0xFFFFB300) : const Color(0xFF6B3E1E), width: winning.isNotEmpty ? 3 : 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (us)
            Row(children: [
              for (final l in 'BINGO'.split(''))
                Expanded(child: Center(child: Text(l, style: const TextStyle(fontFamily: displayFont, fontSize: 18, color: Color(0xFFC62828))))),
            ]),
          for (var r = 0; r < card.height; r++)
            Row(
              children: [
                for (var c = 0; c < card.width; c++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: us ? 1 : 0.85,
                      child: _cell(r, c),
                    ),
                  ),
              ],
            ),
          if (missing != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(missing == 0 ? 'BINGO!' : 'noch $missing', style: const TextStyle(color: Color(0xFF6D4C41), fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _cell(int r, int c) {
    final n = card.rows[r][c];
    final free = n == 0 && variant == BingoVariant.us75;
    final empty = n == 0 && !free;
    final marked = free || (n > 0 && isMarked(n));
    final win = winning.contains((r, c));
    return GestureDetector(
      onTap: onTap == null || n == 0 ? null : () => onTap!(n),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: empty ? const Color(0xFFE8DCC4) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!empty)
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: free
                      ? const Icon(Icons.star, color: Color(0xFFC62828))
                      : Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF241410))),
                ),
              ),
            if (marked)
              FractionallySizedBox(
                widthFactor: 0.82,
                heightFactor: 0.82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: win ? const Color(0xAAFFB300) : const Color(0x88E53935),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
