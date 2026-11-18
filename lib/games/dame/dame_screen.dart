import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/net_duel_mixin.dart';
import '../../ui/tap_catcher.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import 'dame_engine.dart';

const dameLevels = ['Leicht', 'Mittel', 'Schwer'];
const dameRewards = [50, 120, 250];

final dameGuide = GameGuide('Dame', const [
  GuideSection(
    'Ziel',
    'Schlage alle Steine des Gegners oder setze ihn so fest, dass er nicht mehr ziehen kann. Weiß beginnt. '
        'Gespielt wird nur auf den dunklen Feldern.',
  ),
  GuideSection(
    'Ziehen',
    'Ein Stein zieht ein Feld schräg nach vorn. Erreicht er die gegnerische Grundreihe, wird er zur Dame '
        '(mit Krone). Eine Dame zieht beliebig weit schräg, vorwärts und rückwärts.',
  ),
  GuideSection(
    'Schlagen',
    'Steht schräg vor dir ein gegnerischer Stein und dahinter ist frei, springst du darüber und schlägt ihn. '
        'Steine dürfen auch rückwärts schlagen. Kannst du danach weiter schlagen, musst du weitermachen. '
        'Schlagen ist Pflicht. Eine Dame schlägt aus der Ferne und landet auf einem beliebigen freien Feld dahinter.',
  ),
  GuideSection(
    'Deutsch oder international',
    'Deutsche Dame: 8×8 Felder, je 12 Steine; von mehreren Schlagmöglichkeiten darfst du dir eine aussuchen. '
        'Internationale Dame: 10×10 Felder, je 20 Steine; du musst die Folge wählen, die die meisten Steine schlägt.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Gegen den Computer in drei Stufen (Sieg: 50, 120 oder 250 Münzen) oder zu zweit an einem Gerät. '
        'Nach 50 Damenzügen ohne Schlagen endet das Spiel unentschieden.',
  ),
]);

class DameScreen extends StatefulWidget {
  const DameScreen({super.key});

  @override
  State<DameScreen> createState() => _DameScreenState();
}

class _DameScreenState extends State<DameScreen> with NetDuelScreen {
  static const _saveId = 'dame';
  late final Settings _store;
  DameGame? _g;
  List<Seat> _seats = const [];
  int _level = 1;
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;
  int? _sel;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = DameGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _level = d['level'] as int;
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('dame.spielstand', e, st);
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
  }

  @override
  void dispose() {
    _token++;
    _persist();
    duelDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  @override
  String get duelGame => 'dame';
  @override
  String get duelTitle => 'Dame';
  @override
  List<String> get duelSides => const ['Weiß', 'Schwarz'];

  int _netVariant = 0;

  @override
  Map<String, Object?> get duelOptions => {'v': _netVariant};

  @override
  List<Widget> duelLobbyExtras() => [
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          ChoiceChip(label: const Text('Deutsch 8×8'), selected: _netVariant == 0, onSelected: (_) => setState(() => _netVariant = 0)),
          ChoiceChip(label: const Text('International 10×10'), selected: _netVariant == 1, onSelected: (_) => setState(() => _netVariant = 1)),
        ]),
      ];

  @override
  void duelStart(List<String> names, int mySeat, Map<String, Object?> options) {
    _token++;
    setState(() {
      _seats = [Seat(names[0], human: mySeat == 0), Seat(names[1], human: mySeat == 1)];
      _paid = true;
      _busy = false;
      _g = DameGame(DameVariant.values[((options['v'] as num?)?.toInt() ?? 0).clamp(0, DameVariant.values.length - 1)]);
      _sel = null;
      _msg = '${names[0]} (Weiß) beginnt';
    });
  }

  @override
  bool duelApply(Object? move) {
    final g = _g;
    if (g == null || g.over || move is! List) return false;
    final DameMove m;
    try {
      m = DameMove.fromJson(move);
    } catch (_) {
      return false;
    }
    final legal = g.moves().where((x) => x.path.join(',') == m.path.join(',') && x.captured.join(',') == m.captured.join(',')).firstOrNull;
    if (legal == null) return false;
    _play(legal, remote: true);
    return true;
  }

  @override
  void duelClosed() => _newGame();

  void _persist() {
    if (duelActive) return;
    final g = _g;
    if (g == null || g.over) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {
      'game': g.toJson(),
      'seats': [for (final s in _seats) s.toJson()],
      'level': _level,
      'paid': _paid,
    });
  }

  /// Platz 0 spielt Weiß (1), Platz 1 Schwarz (-1).
  int _seatOf(int side) => side == 1 ? 0 : 1;
  String _name(int side) => _seats[_seatOf(side)].name;

  Future<void> _newGame() async {
    _token++;
    void leave() {
      if (_g == null && mounted) Navigator.of(context).pop();
    }

    final variant = await showChoiceSheet(
      context,
      title: 'Welche Dame?',
      options: const ['Deutsche Dame: 8×8, je 12 Steine', 'Internationale Dame: 10×10, je 20 Steine'],
    );
    if (variant == null || !mounted) {
      leave();
      return;
    }
    final seats = await showSeatSetup(
      context,
      gameId: _saveId,
      title: 'Dame',
      minSeats: 2,
      maxSeats: 2,
      colorNames: const ['Weiß', 'Schwarz'],
      colors: const [Color(0xFFF2F2F2), Color(0xFF1A1A1A)],
    );
    if (seats == null || !mounted) {
      leave();
      return;
    }
    var level = _level;
    if (vsComputer(seats)) {
      final l = await showChoiceSheet(
        context,
        title: 'Wie stark ist der Computer?',
        options: [for (var i = 0; i < 3; i++) '${dameLevels[i]}: Sieg bringt ${dameRewards[i]} Münzen'],
      );
      if (l == null || !mounted) {
        leave();
        return;
      }
      level = l;
    }
    setState(() {
      _seats = seats;
      _level = level;
      _g = DameGame(DameVariant.values[variant]);
      _paid = false;
      _busy = false;
      _sel = null;
      _msg = '${seats[0].name} (Weiß) beginnt';
    });
    _bot();
  }

  bool get _humanTurn {
    final g = _g;
    return g != null && !g.over && _seats[_seatOf(g.current)].human && !_busy;
  }

  void _tap(Offset pos, double u) {
    final g = _g;
    if (g == null || !_humanTurn) return;
    final c = (pos.dx / u).floor();
    final r = (pos.dy / u).floor();
    if (c < 0 || r < 0 || c >= g.n || r >= g.n) return;
    final sq = r * g.n + c;
    final moves = g.moves();
    if (g.board[sq] != 0 && g.board[sq].sign == g.current) {
      final own = moves.where((m) => m.from == sq).toList();
      setState(() {
        _sel = own.isEmpty ? null : sq;
        if (own.isEmpty) {
          _msg = moves.any((m) => m.captured.isNotEmpty) ? 'Schlagen ist Pflicht: ein anderer Stein muss schlagen' : 'Dieser Stein kann nicht ziehen';
        }
      });
      return;
    }
    final sel = _sel;
    if (sel == null) return;
    final options = moves.where((m) => m.from == sel && m.to == sq).toList();
    if (options.isEmpty) return;
    // Mehrere Wege zum selben Ziel: den mit den meisten geschlagenen Steinen
    options.sort((a, b) => b.captured.length - a.captured.length);
    _play(options.first);
  }

  void _play(DameMove m, {bool remote = false}) {
    final g = _g!;
    final who = g.current;
    if (!g.play(m)) {
      debugLog.warn('dame', 'Ungültiger Zug $m');
      return;
    }
    if (!remote) duelSendMove(m.toJson());
    final sfx = AppScope.of(context).sfx;
    sfx.play(m.captured.isNotEmpty ? Sound.lose : Sound.chip);
    var text = m.captured.isEmpty
        ? '${_name(g.current)} ist dran'
        : '${_name(who)} schlägt ${m.captured.length == 1 ? 'einen Stein' : '${m.captured.length} Steine'}. ${_name(g.current)} ist dran';
    if (g.over) {
      final w = g.winner!;
      if (w == 0) {
        text = 'Unentschieden: 50 Damenzüge ohne Schlagen';
      } else {
        final reward = duelPlaying ? 0 : seatReward(_seats, _seatOf(w), dameRewards[_level]);
        if (reward > 0 && !_paid) {
          _paid = true;
          AppScope.of(context).wallet.credit(reward);
        }
        sfx.play(_seats[_seatOf(w)].human ? Sound.win : Sound.lose);
        text = '${_name(w)} gewinnt!${reward > 0 ? ' +$reward Münzen' : ''}';
      }
    }
    setState(() {
      _msg = text;
      _sel = null;
    });
    _bot();
  }

  Future<void> _bot() async {
    final g = _g;
    if (g == null || g.over || _seats[_seatOf(g.current)].human || duelRemote(_seatOf(g.current))) return;
    final token = ++_token;
    setState(() => _busy = true);
    final copy = g.copy();
    final level = _level;
    final seed = math.Random().nextInt(1 << 30);
    final wait = Future<void>.delayed(_store.botDelay(500));
    DameMove m;
    try {
      m = await Isolate.run(() => dameBotMove(copy, level, math.Random(seed)));
    } catch (e, st) {
      debugLog.error('dame.bot', e, st);
      m = dameBotMove(copy, 0, math.Random(seed));
    }
    await wait;
    if (!mounted || token != _token) return;
    _busy = false;
    _play(m);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Dame',
      guide: dameGuide,
      actions: duelActions(context),
      child: duelScreen() ?? (g == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final side in [1, -1])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: g.current == side && !g.over ? p.accent : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: g.current == side && !g.over ? p.accent : p.panelEdge),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 8, backgroundColor: side == 1 ? Colors.white : Colors.black),
                            const SizedBox(width: 6),
                            Text('${_name(side)} · ${g.count(side)} Steine',
                                style: TextStyle(color: g.current == side && !g.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final size = math.min(box.maxWidth, box.maxHeight) - 16;
                    final moves = _humanTurn ? g.moves() : const <DameMove>[];
                    final from = {for (final m in moves) m.from};
                    final targets = [for (final m in moves) if (m.from == _sel) m.to];
                    return Center(
                      child: TapCatcher(
                        area: 'dame',
                        onTap: (pos) => _tap(pos, size / g.n),
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _DamePainter(g, _sel, from, targets),
                        ),
                      ),
                    );
                  }),
                ),
                ResultBanner(text: _busy ? '${_name(g.current)} überlegt …' : _msg, highlight: g.over, maxLines: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    if (duelPlaying)
                      ...duelButtons(over: g.over)
                    else ...[
                      ActionButton(primary: g.over, label: 'Neues Spiel', onPressed: _newGame),
                      if (g.over || MediaQuery.sizeOf(context).width < 420) ActionButton(label: 'Im Netzwerk', onPressed: duelOpenPanel),
                    ],
                  ]),
                ),
              ],
            )),
    );
  }
}

class _DamePainter extends CustomPainter {
  _DamePainter(this.g, this.sel, this.movable, this.targets);
  final DameGame g;
  final int? sel;
  final Set<int> movable;
  final List<int> targets;

  @override
  void paint(Canvas canvas, Size size) {
    final n = g.n;
    final u = size.width / n;
    canvas.drawRect((Offset.zero & size).inflate(5), Paint()..color = const Color(0xFF3A2116));
    final last = g.lastMove;
    for (var i = 0; i < n * n; i++) {
      final r = i ~/ n;
      final c = i % n;
      final rect = Rect.fromLTWH(c * u, r * u, u, u);
      final dark = (r + c).isOdd;
      var color = dark ? const Color(0xFF7A4A2A) : const Color(0xFFF0DDB8);
      if (last != null && (last.path.contains(i))) color = Color.lerp(color, const Color(0xFFE8B923), 0.35)!;
      canvas.drawRect(rect, Paint()..color = color);
      if (targets.contains(i)) {
        canvas.drawCircle(rect.center, u * 0.16, Paint()..color = const Color(0xCCE8B923));
      }
      final v = g.board[i];
      if (v == 0) continue;
      final center = rect.center;
      final white = v > 0;
      canvas.drawCircle(center + Offset(u * 0.03, u * 0.06), u * 0.38, Paint()..color = Colors.black45);
      canvas.drawCircle(center, u * 0.38, Paint()..color = white ? const Color(0xFFF4F1EA) : const Color(0xFF1E1E22));
      canvas.drawCircle(center, u * 0.27, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.04
        ..color = white ? const Color(0x33000000) : const Color(0x44FFFFFF));
      if (v.abs() == 2) {
        // Krone
        final k = Path()
          ..moveTo(center.dx - u * 0.2, center.dy + u * 0.1)
          ..lineTo(center.dx - u * 0.22, center.dy - u * 0.12)
          ..lineTo(center.dx - u * 0.1, center.dy)
          ..lineTo(center.dx, center.dy - u * 0.16)
          ..lineTo(center.dx + u * 0.1, center.dy)
          ..lineTo(center.dx + u * 0.22, center.dy - u * 0.12)
          ..lineTo(center.dx + u * 0.2, center.dy + u * 0.1)
          ..close();
        canvas.drawPath(k, Paint()..color = const Color(0xFFE8B923));
      }
      if (i == sel || (sel == null && movable.contains(i))) {
        canvas.drawCircle(center, u * 0.44, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * (i == sel ? 0.08 : 0.04)
          ..color = const Color(0xFFE8B923));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
