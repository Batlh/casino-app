import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_replay_mixin.dart';
import '../../ui/tap_catcher.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../sicbo/sicbo_screen.dart' show DieFace;
import 'kniffel_engine.dart';

const kniffelWinReward = 120;

final kniffelGuide = GameGuide('Kniffel', const [
  GuideSection(
    'Ablauf',
    'Wer dran ist, würfelt bis zu dreimal mit fünf Würfeln. Würfel, die du behalten willst, tippst du an, '
        'dann rollen nur die anderen. Danach trägst du das Ergebnis in eine freie Zeile ein, notfalls mit 0 Punkten. '
        'Nach 13 Runden sind alle Zeilen voll und die meisten Punkte gewinnen.',
  ),
  GuideSection(
    'Oben',
    'Einer bis Sechser: Es zählen nur die Würfel mit dieser Zahl. Kommst du oben auf mindestens 63 Punkte '
        '(dreimal jede Zahl), gibt es 35 Punkte Bonus.',
  ),
  GuideSection(
    'Unten',
    'Dreierpasch und Viererpasch: mindestens drei bzw. vier gleiche, es zählt die Summe aller Würfel. '
        'Full House (drei gleiche und zwei gleiche) 25, kleine Straße (vier in Folge) 30, große Straße (fünf in Folge) 40, '
        'Kniffel (fünf gleiche) 50, Chance: die Summe. Jeder weitere Kniffel bringt 50 Punkte extra.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Allein, zu mehreren an einem Gerät oder gegen den Computer. Gewinnst du gegen den Computer, gibt es '
        '$kniffelWinReward Münzen. Allein gibt es Münzen nach Punkten: ein Zehntel der Endsumme.',
  ),
]);

class KniffelScreen extends StatefulWidget {
  const KniffelScreen({super.key});

  @override
  State<KniffelScreen> createState() => _KniffelScreenState();
}

class _KniffelScreenState extends State<KniffelScreen> with NetReplayScreen {
  static const _saveId = 'kniffel';
  late final Settings _store;
  KniffelGame? _g;
  List<Seat> _seats = const [];
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = KniffelGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('kniffel.spielstand', e, st);
        _g = null;
        _store.clearGame(_saveId);
      }
    }
    if (_g == null) WidgetsBinding.instance.addPostFrameCallback((_) => _newGame());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _persist();
    replayBroadcast();
  }

  @override
  void dispose() {
    _token++;
    _persist();
    replayDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  /// Züge dieser Partie: ['r', Halten je Würfel] würfeln, ['t', i] Würfel halten, ['s', Zeile] eintragen.
  final List<List<Object?>> _log = [];

  @override
  String get replayGame => 'kniffel';
  @override
  String get replayTitle => 'Kniffel';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const [];
  @override
  List<List<Object?>> get replayLog => _log;

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _token++;
    _log.clear();
    _seats = [for (final (i, n) in names.indexed) Seat(n, human: replayHumans.contains(i))];
    _g = KniffelGame(names.length, rng: math.Random(seed));
    _paid = false;
    _busy = false;
    _msg = '${names[0]} würfelt zuerst';
  }

  @override
  void replayApply(List<dynamic> a) => _apply(a);

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    final g = _g;
    if (g == null || g.over || g.current != seat || a.isEmpty) return false;
    return switch (a[0]) {
      'r' => g.rollsLeft > 0 && a.length == 2 && (a[1] as List).length == 5,
      't' => g.rolled && g.rollsLeft > 0 && a.length == 2 && a[1] is int && (a[1] as int) >= 0 && (a[1] as int) < 5,
      's' => g.rolled && a.length == 2 && a[1] is int && (a[1] as int) >= 0 && (a[1] as int) < 13 && g.scores[seat][a[1] as int] == null,
      _ => false,
    };
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    final g = _g;
    if (g == null || acts.isEmpty) {
      setState(() {});
      _bot();
      return;
    }
    final last = acts.last;
    if (last.first == 'r') {
      AppScope.of(context).sfx.play(Sound.tick);
      _msg = g.rollsLeft == 0 ? '${_seats[g.current].name}: Zeile wählen' : '${_seats[g.current].name} würfelt';
    } else if (last.first == 's') {
      final who = (g.current - 1 + g.players) % g.players;
      final cat = last[1] as int;
      final pts = g.scores[who][cat] ?? 0;
      AppScope.of(context).sfx.play(pts > 0 ? Sound.chip : Sound.lose);
      _msg = g.over ? _finish(g) : '${_seats[who].name}: ${kniffelCategories[cat]} für $pts. ${_seats[g.current].name} ist dran';
    }
    setState(() {});
    _bot();
  }

  @override
  void replayClosed() => _newGame();

  void _apply(List<dynamic> a) {
    final g = _g!;
    switch (a[0]) {
      case 'r':
        if (g.rolled) g.held = [for (final h in a[1] as List) h == true];
        g.roll();
      case 't':
        g.toggle(a[1] as int);
      case 's':
        g.score(a[1] as int);
    }
    _log.add(a);
  }

  /// Allein oder als Gastgeber ausführen, als Mitspieler an den Gastgeber schicken. true, wenn hier ausgeführt.
  bool _act(List<Object?> a) {
    if (replaySend(a)) return false;
    _apply(a);
    return true;
  }

  void _persist() {
    if (replayActive) return;
    final g = _g;
    if (g == null || g.over) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {
      'game': g.toJson(),
      'seats': [for (final s in _seats) s.toJson()],
      'paid': _paid,
    });
  }

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(context, gameId: _saveId, title: 'Kniffel', minSeats: 1, maxSeats: 4);
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _seats = seats;
      _g = KniffelGame(seats.length);
      _paid = false;
      _busy = false;
      _msg = '${seats[0].name} würfelt zuerst';
    });
    _bot();
  }

  bool get _humanTurn {
    final g = _g;
    if (g == null || g.over || _busy) return false;
    return replayActive ? g.current == replayMe : _seats[g.current].human;
  }

  void _roll() {
    final g = _g;
    if (g == null || g.rollsLeft == 0 || g.over) return;
    if (!_act(['r', g.held.toList()])) return;
    AppScope.of(context).sfx.play(Sound.tick);
    setState(() => _msg = g.rollsLeft == 0
        ? '${_seats[g.current].name}: Zeile wählen'
        : '${_seats[g.current].name}: noch ${g.rollsLeft} Wurf${g.rollsLeft == 1 ? '' : 'e'}. Würfel antippen zum Behalten');
  }

  void _score(int cat) {
    final g = _g;
    if (g == null) return;
    final who = g.current;
    final pts = kniffelScore(cat, g.dice);
    if (!g.rolled || g.scores[who][cat] != null) return;
    if (!_act(['s', cat])) return;
    AppScope.of(context).sfx.play(pts > 0 ? Sound.chip : Sound.lose);
    var text = '${_seats[who].name}: ${kniffelCategories[cat]} für $pts. ${_seats[g.current].name} ist dran';
    if (g.over) text = _finish(g);
    setState(() => _msg = text);
    _bot();
  }

  String _finish(KniffelGame g) {
    final totals = [for (var p = 0; p < g.players; p++) g.total(p)];
    final wallet = AppScope.of(context).wallet;
    final sfx = AppScope.of(context).sfx;
    if (_seats.length == 1) {
      final reward = math.max(10, totals[0] ~/ 10);
      if (!_paid) {
        _paid = true;
        wallet.credit(reward);
      }
      sfx.play(Sound.win);
      return '${totals[0]} Punkte! +$reward Münzen';
    }
    final best = totals.reduce(math.max);
    final winners = [for (var p = 0; p < g.players; p++) if (totals[p] == best) p];
    if (winners.length > 1) return 'Gleichstand mit $best Punkten';
    final w = winners.first;
    final reward = replayActive && w != replayMe ? 0 : seatReward(_seats, w, kniffelWinReward);
    if (reward > 0 && !_paid) {
      _paid = true;
      wallet.credit(reward);
    }
    sfx.play(_seats[w].human ? Sound.win : Sound.lose);
    return '${_seats[w].name} gewinnt mit $best Punkten!${reward > 0 ? ' +$reward Münzen' : ''}';
  }

  Future<void> _bot() async {
    final g = _g;
    if (replayIsGuest) return;
    if (g == null || g.over || (_seats[g.current].human && !(replayActive && replayIsBot(g.current)))) return;
    final token = ++_token;
    setState(() => _busy = true);
    while (true) {
      await Future<void>.delayed(_store.botDelay(700));
      if (!mounted || token != _token) return;
      if (!g.rolled || (!g.botStop() && g.rollsLeft > 0)) {
        if (g.rolled) g.held = g.botHolds();
        _roll();
        continue;
      }
      break;
    }
    _busy = false;
    _score(g.botCategory());
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return GameFrame(
      title: 'Kniffel',
      guide: kniffelGuide,
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? (g == null
          ? const SizedBox.shrink()
          : LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth > 760;
              final table = _table(g);
              final dice = _dice(g);
              return wide
                  ? Row(children: [
                      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(8), child: table)),
                      SizedBox(width: 360, child: Center(child: dice)),
                    ])
                  : Column(children: [
                      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(8), child: table)),
                      dice,
                    ]);
            })),
    );
  }

  Widget _dice(KniffelGame g) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                TapCatcher(
                  area: 'kniffel',
                  onTap: (_) {
                    if (!_humanTurn || !g.rolled || g.rollsLeft == 0) return;
                    if (!_act(['t', i])) return;
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(3),
                    margin: EdgeInsets.only(top: g.held[i] ? 0 : 10, bottom: g.held[i] ? 10 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: g.held[i] ? const Color(0xFFE8B923) : Colors.transparent, width: 3),
                    ),
                    child: Opacity(opacity: g.rolled ? 1 : 0.35, child: DieFace(value: g.dice[i], size: 50)),
                  ),
                ),
            ],
          ),
          ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionButton(
                primary: true,
                label: g.over
                    ? 'Fertig'
                    : _humanTurn || (!replayActive && _seats[g.current].human)
                        ? (g.rollsLeft == 0 ? 'Zeile wählen' : 'Würfeln (${g.rollsLeft})')
                        : '${_seats[g.current].name} ist dran',
                onPressed: _humanTurn && g.rollsLeft > 0 ? _roll : null,
              ),
              if (replayActive)
                ...replayButtons(label: 'Neues Spiel', next: replayHostStart)
              else ...[
                ActionButton(label: 'Neues Spiel', onPressed: _newGame),
                if (g.over || MediaQuery.sizeOf(context).width < 420) ActionButton(label: 'Im Netzwerk', onPressed: replayOpenPanel),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _table(KniffelGame g) {
    final p = Palette.of(context);
    final style = TextStyle(color: p.ink, fontSize: 15);
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    TableRow row(String label, List<Widget> cells, {Color? bg}) => TableRow(
          decoration: BoxDecoration(color: bg),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: Text(label, style: style)),
            ...cells,
          ],
        );
    Widget cell(String t, {TextStyle? s, VoidCallback? onTap, bool hint = false}) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Text(t, textAlign: TextAlign.center, style: (s ?? style).copyWith(color: hint ? p.accent : null)),
      );
      return onTap == null ? child : TapCatcher(area: 'kniffel', onTap: (_) => onTap(), child: child);
    }

    final rows = <TableRow>[
      row('', [
        for (var i = 0; i < g.players; i++)
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 6, backgroundColor: seatColors[i]),
              const SizedBox(width: 4),
              Flexible(child: Text(_seats[i].name, overflow: TextOverflow.ellipsis, style: bold)),
            ]),
          ),
      ]),
    ];
    for (var c = 0; c < 13; c++) {
      if (c == 6) {
        rows.add(row('Bonus (ab 63)', [
          for (var i = 0; i < g.players; i++) cell('${g.upper(i)} · ${g.bonus(i)}', s: style.copyWith(color: p.inkSoft)),
        ]));
      }
      rows.add(row(kniffelCategories[c], [
        for (var i = 0; i < g.players; i++)
          if (g.scores[i][c] != null)
            cell('${g.scores[i][c]}')
          else if (i == g.current && _humanTurn && g.rolled)
            cell('${kniffelScore(c, g.dice)}', hint: true, s: bold, onTap: () => _score(c))
          else
            cell(''),
      ], bg: c.isEven ? p.panel.withValues(alpha: 0.35) : null));
    }
    rows.add(row('Summe', [for (var i = 0; i < g.players; i++) cell('${g.total(i)}', s: bold)]));
    return Container(
      decoration: BoxDecoration(
        color: p.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.panelEdge, width: 2),
      ),
      child: Table(
        columnWidths: const {0: IntrinsicColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: rows,
      ),
    );
  }
}
