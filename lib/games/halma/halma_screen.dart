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
import 'halma_engine.dart';

const halmaWinReward = 120;

final halmaGuide = GameGuide('Halma', const [
  GuideSection(
    'Ziel',
    'Gespielt wird Stern-Halma: Jeder hat zehn Figuren in einer Zacke des Sterns. Wer zuerst alle zehn in die '
        'gegenüberliegende Zacke bringt, gewinnt.',
  ),
  GuideSection(
    'Ziehen',
    'Du ziehst eine Figur auf ein freies Nachbarloch. Oder du springst über eine Figur (egal welche Farbe) direkt '
        'dahinter auf ein freies Loch. Sprünge lassen sich beliebig aneinanderreihen, auch im Zickzack. '
        'Geschlagen wird nicht.',
  ),
  GuideSection(
    'Bedienung',
    'Tippe eine eigene Figur an, dann eines der markierten Ziele. Bei Sprungketten genügt das Endziel. '
        'Eine Figur, die schon im Ziel steht, darf das Ziel nicht mehr verlassen.',
  ),
  GuideSection(
    'Tipps',
    'Baue dir Leitern: Steht eine eigene Figur zwei Löcher vor einer anderen, kann die hintere weit springen. '
        'Vergiss die letzten Figuren im Startlager nicht.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Zwei bis sechs spielen mit, an einem Gerät oder gegen den Computer. Gewinnst du gegen den Computer, '
        'gibt es $halmaWinReward Münzen.',
  ),
]);

class HalmaScreen extends StatefulWidget {
  const HalmaScreen({super.key});

  @override
  State<HalmaScreen> createState() => _HalmaScreenState();
}

class _HalmaScreenState extends State<HalmaScreen> with NetReplayScreen {
  static const _saveId = 'halma';
  late final Settings _store;
  HalmaGame? _g;
  List<Seat> _seats = const [];
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;
  int? _sel;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = HalmaGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('halma.spielstand', e, st);
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

  /// Züge: ['m', von, nach] und ['x'] aussetzen. Wer nicht ziehen kann, setzt auf allen Geräten gleich aus.
  final List<List<Object?>> _log = [];

  @override
  String get replayGame => 'halma';
  @override
  String get replayTitle => 'Halma';
  @override
  int get replaySeats => 6;
  @override
  List<String> get replayBotNames => const [];
  @override
  List<List<Object?>> get replayLog => _log;

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _token++;
    _log.clear();
    _seats = [for (final (i, n) in names.indexed) Seat(n, human: replayHumans.contains(i))];
    _g = HalmaGame(names.length);
    _paid = false;
    _busy = false;
    _sel = null;
    _msg = '${names[0]} beginnt';
  }

  @override
  void replayApply(List<dynamic> a) {
    final g = _g!;
    if (a[0] == 'm') {
      g.play(a[1] as int, a[2] as int);
      _log.add(a);
      _skipBlocked();
    } else {
      g.pass();
      _log.add(a);
    }
  }

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    final g = _g;
    if (g == null || g.over || g.current != seat || a.isEmpty || a[0] != 'm' || a.length != 3) return false;
    return g.legalMoves().any((m) => m.$1 == a[1] && m.$2 == a[2]);
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    final g = _g;
    if (g != null && acts.isNotEmpty) {
      AppScope.of(context).sfx.play(Sound.chip);
      if (g.over) {
        _msg = 'Gewonnen hat ${_winnerName(g)}';
        if (_inTarget(g, replayMe) == 10) AppScope.of(context).sfx.play(Sound.win);
      } else if (!_msg.contains('setzt aus')) {
        _msg = '${_seats[g.current].name} ist dran';
      }
    }
    setState(() => _sel = null);
    _bot();
  }

  String _winnerName(HalmaGame g) {
    for (var i = 0; i < _seats.length; i++) {
      if (_inTarget(g, i) == 10) return _seats[i].name;
    }
    return '';
  }

  @override
  void replayClosed() => _newGame();

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
    final seats = await showSeatSetup(context, gameId: _saveId, title: 'Halma', minSeats: 2, maxSeats: 6);
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _seats = seats;
      _g = HalmaGame(seats.length);
      _paid = false;
      _busy = false;
      _sel = null;
      _msg = '${seats[0].name} beginnt';
    });
    _bot();
  }

  bool get _humanTurn {
    final g = _g;
    if (g == null || g.over || _busy) return false;
    return replayActive ? g.current == replayMe : _seats[g.current].human;
  }

  void _tap(Offset pos, double unit, Offset center) {
    final g = _g;
    if (g == null || !_humanTurn) return;
    int? hit;
    var best = double.infinity;
    for (var i = 0; i < g.board.length; i++) {
      final p = HalmaBoard.pos(i);
      final c = center + Offset(p.x * unit, p.y * unit);
      final d = (c - pos).distance;
      if (d < best) {
        best = d;
        hit = i;
      }
    }
    if (hit == null || best > unit * 0.8) return;
    if (g.board[hit] == g.current) {
      setState(() => _sel = hit);
      return;
    }
    final sel = _sel;
    if (sel == null) return;
    final ok = g.legalMoves().any((m) => m.$1 == sel && m.$2 == hit);
    if (!ok) return;
    _play(sel, hit);
  }

  void _play(int from, int to) {
    final g = _g!;
    final who = g.current;
    if (replaySend(['m', from, to])) {
      setState(() => _sel = null);
      return;
    }
    if (!g.play(from, to)) {
      debugLog.warn('halma', 'Ungültiger Zug $from → $to');
      return;
    }
    _log.add(['m', from, to]);
    final sfx = AppScope.of(context).sfx;
    sfx.play(Sound.chip);
    var text = '${_seats[g.current].name} ist dran';
    if (g.over) {
      final reward = replayActive && who != replayMe ? 0 : seatReward(_seats, who, halmaWinReward);
      if (reward > 0 && !_paid) {
        _paid = true;
        AppScope.of(context).wallet.credit(reward);
      }
      sfx.play(_seats[who].human ? Sound.win : Sound.lose);
      text = '${_seats[who].name} hat alle Figuren im Ziel und gewinnt!${reward > 0 ? ' +$reward Münzen' : ''}';
    }
    setState(() {
      _msg = text;
      _sel = null;
    });
    _skipBlocked();
    _bot();
  }

  /// Wer gar nicht ziehen kann, setzt aus.
  void _skipBlocked() {
    final g = _g!;
    var guard = 0;
    while (!g.over && g.legalMoves().isEmpty && guard++ < g.players) {
      _msg = '${_seats[g.current].name} kann nicht ziehen und setzt aus';
      g.pass();
    }
  }

  Future<void> _bot() async {
    final g = _g;
    if (replayIsGuest) return;
    if (g == null || g.over || (_seats[g.current].human && !(replayActive && replayIsBot(g.current)))) return;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(450));
    if (!mounted || token != _token) return;
    final m = g.botMove(_rng);
    _busy = false;
    if (m == null) {
      g.pass();
      _log.add(['x']);
      setState(() {});
      _bot();
      return;
    }
    _play(m.$1, m.$2);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Halma',
      guide: halmaGuide,
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? (g == null
          ? const SizedBox.shrink()
          : LayoutBuilder(builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.1;
              final chips = Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _seats.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: i == g.current && !g.over ? p.accent : Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: i == g.current && !g.over ? p.accent : p.panelEdge),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(radius: 8, backgroundColor: seatColors[i]),
                        const SizedBox(width: 6),
                        Text(
                          '${_seats[i].name} · ${_inTarget(g, i)}/10',
                          style: TextStyle(color: i == g.current && !g.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                ],
              );
              final side = Column(mainAxisSize: MainAxisSize.min, children: [
                chips,
                ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  if (replayActive)
                    ...replayButtons(label: 'Neues Spiel', next: replayHostStart)
                  else ...[
                    ActionButton(primary: g.over, label: 'Neues Spiel', onPressed: _newGame),
                    if (g.over || MediaQuery.sizeOf(context).width < 420) ActionButton(label: 'Im Netzwerk', onPressed: replayOpenPanel),
                  ],
                ]),
              ]);
              final bw = landscape ? box.maxWidth - 300 : box.maxWidth;
              final bh = landscape ? box.maxHeight : box.maxHeight - 170;
              // Stern: y von -12 bis 12, x von gut -10,4 bis 10,4 (in Lochabständen)
              final unit = math.max(4.0, math.min(bw / 21.8, bh / 25) - 0.3);
              final size = Size(unit * 21.8, unit * 25);
              final targets = <int>{};
              final sel = _sel;
              if (sel != null && _humanTurn) {
                for (final m in g.legalMoves()) {
                  if (m.$1 == sel) targets.add(m.$2);
                }
              }
              final board = TapCatcher(
                area: 'halma',
                onTap: (pos) => _tap(pos, unit, Offset(size.width / 2, size.height / 2)),
                child: CustomPaint(size: size, painter: _HalmaPainter(g, unit, sel, targets)),
              );
              return landscape
                  ? Row(children: [
                      Expanded(child: Center(child: board)),
                      SizedBox(width: 290, child: Padding(padding: const EdgeInsets.all(8), child: side)),
                    ])
                  : Column(children: [
                      Expanded(child: Center(child: board)),
                      Padding(padding: const EdgeInsets.all(8), child: side),
                    ]);
            })),
    );
  }

  int _inTarget(HalmaGame g, int p) {
    final t = g.target(p);
    var n = 0;
    for (var i = 0; i < g.board.length; i++) {
      if (g.board[i] == p && HalmaBoard.instance.camp[i] == t) n++;
    }
    return n;
  }
}

class _HalmaPainter extends CustomPainter {
  _HalmaPainter(this.g, this.unit, this.sel, this.targets);
  final HalmaGame g;
  final double unit;
  final int? sel;
  final Set<int> targets;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final b = HalmaBoard.instance;
    Offset at(int i) {
      final p = HalmaBoard.pos(i);
      return center + Offset(p.x * unit, p.y * unit);
    }

    // Sternfläche
    canvas.drawCircle(center, unit * 12.6, Paint()..color = const Color(0x22000000));
    // Lagerfarben: Startlager blass in Spielerfarbe, Ziele mit Rand
    final campOwner = <int, int>{};
    for (var p = 0; p < g.players; p++) {
      campOwner[g.home(p)] = p;
    }
    for (var i = 0; i < b.cells.length; i++) {
      final c = at(i);
      final camp = b.camp[i];
      var hole = const Color(0xFFE9D7B0);
      final owner = campOwner[camp];
      if (owner != null) hole = Color.lerp(hole, seatColors[owner], 0.35)!;
      canvas.drawCircle(c, unit * 0.42, Paint()..color = hole);
      canvas.drawCircle(c, unit * 0.42, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.06
        ..color = const Color(0x553A2116));
      if (targets.contains(i)) {
        canvas.drawCircle(c, unit * 0.22, Paint()..color = const Color(0xFFE8B923));
      }
      final v = g.board[i];
      if (v < 0) continue;
      canvas.drawCircle(c + Offset(unit * 0.05, unit * 0.08), unit * 0.4, Paint()..color = Colors.black38);
      canvas.drawCircle(c, unit * 0.4, Paint()..color = seatColors[v]);
      canvas.drawCircle(c - Offset(unit * 0.12, unit * 0.12), unit * 0.12, Paint()..color = Colors.white54);
      if (i == sel) {
        canvas.drawCircle(c, unit * 0.5, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.1
          ..color = const Color(0xFFE8B923));
      }
    }
    final last = g.lastMove;
    if (last != null) {
      canvas.drawCircle(at(last.$1), unit * 0.16, Paint()..color = const Color(0x88FFFFFF));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
