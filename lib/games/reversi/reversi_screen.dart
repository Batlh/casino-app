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
import 'reversi_engine.dart';

const reversiLevels = ['Leicht', 'Mittel', 'Schwer'];
const reversiRewards = [50, 100, 200];

final reversiGuide = GameGuide('Reversi', const [
  GuideSection(
    'Ziel',
    'Am Ende sollen mehr Steine deine Farbe zeigen. Schwarz beginnt, dann wird abgewechselt.',
  ),
  GuideSection(
    'Ziehen',
    'Du setzt einen Stein so, dass zwischen ihm und einem deiner Steine eine ununterbrochene Reihe gegnerischer '
        'Steine liegt, waagrecht, senkrecht oder schräg. Diese Steine werden umgedreht. Mögliche Felder sind mit '
        'einem Punkt markiert. Kannst du nicht ziehen, musst du passen.',
  ),
  GuideSection(
    'Tipps',
    'Ecken lassen sich nie wieder umdrehen und sind Gold wert. Die Felder direkt neben einer leeren Ecke '
        'schenken sie oft dem Gegner. Viele Steine früh im Spiel helfen wenig, viele Zugmöglichkeiten dagegen sehr.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Gegen den Computer in drei Stufen (Sieg: 50, 100 oder 200 Münzen) oder zu zweit an einem Gerät.',
  ),
]);

class ReversiScreen extends StatefulWidget {
  const ReversiScreen({super.key});

  @override
  State<ReversiScreen> createState() => _ReversiScreenState();
}

class _ReversiScreenState extends State<ReversiScreen> with NetDuelScreen {
  static const _saveId = 'reversi';
  late final Settings _store;
  ReversiGame? _g;
  List<Seat> _seats = const [];
  int _level = 1;
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = ReversiGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _level = d['level'] as int;
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _botTurn());
      } catch (e, st) {
        debugLog.error('reversi.spielstand', e, st);
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
  String get duelGame => 'reversi';
  @override
  String get duelTitle => 'Reversi';
  @override
  List<String> get duelSides => const ['Schwarz', 'Weiß'];

  @override
  void duelStart(List<String> names, int mySeat, Map<String, Object?> options) {
    _token++;
    setState(() {
      _seats = [Seat(names[0], human: mySeat == 0), Seat(names[1], human: mySeat == 1)];
      _g = ReversiGame();
      _paid = true;
      _busy = false;
      _msg = '${names[0]} (Schwarz) beginnt';
    });
  }

  @override
  bool duelApply(Object? move) {
    final g = _g;
    if (g == null || g.over || move is! int || !g.moves().contains(move)) return false;
    _play(move, remote: true);
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

  /// Platz 0 spielt Schwarz, Platz 1 Weiß.
  int _seatOf(int color) => color - 1;

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(
      context,
      gameId: _saveId,
      title: 'Reversi',
      minSeats: 2,
      maxSeats: 2,
      colorNames: const ['Schwarz', 'Weiß'],
      colors: const [Color(0xFF1A1A1A), Color(0xFFF2F2F2)],
    );
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    var level = _level;
    if (vsComputer(seats)) {
      final l = await showChoiceSheet(
        context,
        title: 'Wie stark ist der Computer?',
        options: [for (var i = 0; i < 3; i++) '${reversiLevels[i]}: Sieg bringt ${reversiRewards[i]} Münzen'],
      );
      if (l == null || !mounted) {
        if (_g == null && mounted) Navigator.of(context).pop();
        return;
      }
      level = l;
    }
    setState(() {
      _seats = seats;
      _level = level;
      _g = ReversiGame();
      _paid = false;
      _busy = false;
      _msg = '${seats[0].name} (Schwarz) beginnt';
    });
    _botTurn();
  }

  void _tap(Offset pos, double cell) {
    final g = _g;
    if (g == null || g.over || _busy || !_seats[_seatOf(g.current)].human) return;
    final c = (pos.dx / cell).floor();
    final r = (pos.dy / cell).floor();
    if (c < 0 || c > 7 || r < 0 || r > 7) return;
    _play(r * 8 + c);
  }

  void _play(int i, {bool remote = false}) {
    final g = _g!;
    final who = g.current;
    if (!g.play(i)) return;
    if (!remote) duelSendMove(i);
    AppScope.of(context).sfx.play(Sound.chip);
    var text = '${_seats[_seatOf(g.current)].name} ist dran';
    if (g.passed) text = '${_seats[_seatOf(3 - g.current)].name} kann nicht ziehen und passt. ${_seats[_seatOf(g.current)].name} ist nochmal dran';
    if (g.over) text = _finish(g);
    debugLog.detail('reversi', '${who == 1 ? 'Schwarz' : 'Weiß'} setzt auf $i');
    setState(() => _msg = text);
    _botTurn();
  }

  String _finish(ReversiGame g) {
    final w = g.winner!;
    final b = g.count(1);
    final wh = g.count(2);
    final sfx = AppScope.of(context).sfx;
    if (w == 0) return 'Unentschieden, $b zu $wh';
    final seat = _seatOf(w);
    final reward = duelPlaying ? 0 : seatReward(_seats, seat, reversiRewards[_level]);
    if (reward > 0 && !_paid) {
      _paid = true;
      AppScope.of(context).wallet.credit(reward);
    }
    sfx.play(_seats[seat].human ? Sound.win : Sound.lose);
    return '${_seats[seat].name} gewinnt ${math.max(b, wh)} zu ${math.min(b, wh)}!${reward > 0 ? ' +$reward Münzen' : ''}';
  }

  Future<void> _botTurn() async {
    final g = _g;
    if (g == null || g.over || _seats[_seatOf(g.current)].human || duelRemote(_seatOf(g.current))) return;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(600));
    if (!mounted || token != _token) return;
    final m = reversiBotMove(g.copy(), _level, _rng);
    _busy = false;
    _play(m);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    final net = duelScreen();
    return GameFrame(
      title: 'Reversi',
      guide: reversiGuide,
      actions: duelActions(context),
      network: duelActive ? null : duelOpenPanel,
      child: net ?? (g == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final color in [1, 2])
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: g.current == color && !g.over ? p.accent : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: g.current == color && !g.over ? p.accent : p.panelEdge),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 8, backgroundColor: color == 1 ? Colors.black : Colors.white),
                            const SizedBox(width: 6),
                            Text('${_seats[_seatOf(color)].name} · ${g.count(color)}',
                                style: TextStyle(color: g.current == color && !g.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final size = math.min(box.maxWidth, box.maxHeight) - 16;
                    final human = !g.over && _seats[_seatOf(g.current)].human && !_busy;
                    return Center(
                      child: TapCatcher(
                        area: 'reversi',
                        onTap: (pos) => _tap(pos, size / 8),
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: _ReversiPainter(g, human ? g.moves() : const []),
                        ),
                      ),
                    );
                  }),
                ),
                ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
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

class _ReversiPainter extends CustomPainter {
  _ReversiPainter(this.g, this.hints);
  final ReversiGame g;
  final List<int> hints;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 8;
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(8)), Paint()..color = const Color(0xFF3A2116));
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1E7A4A));
    final line = Paint()
      ..color = const Color(0xFF0E4A2C)
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 8; i++) {
      canvas.drawLine(Offset(i * u, 0), Offset(i * u, size.height), line);
      canvas.drawLine(Offset(0, i * u), Offset(size.width, i * u), line);
    }
    for (final (r, c) in [(2, 2), (2, 6), (6, 2), (6, 6)]) {
      canvas.drawCircle(Offset(c * u, r * u), u * 0.06, Paint()..color = const Color(0xFF0E4A2C));
    }
    for (var i = 0; i < 64; i++) {
      final center = Offset((i % 8 + 0.5) * u, (i ~/ 8 + 0.5) * u);
      final v = g.board[i];
      if (v != 0) {
        canvas.drawCircle(center + Offset(u * 0.03, u * 0.05), u * 0.4, Paint()..color = Colors.black45);
        canvas.drawCircle(center, u * 0.4, Paint()..color = v == 1 ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2));
        canvas.drawCircle(
          center - Offset(u * 0.1, u * 0.1),
          u * 0.14,
          Paint()..color = v == 1 ? const Color(0x33FFFFFF) : const Color(0x88FFFFFF),
        );
        if (i == g.lastMove) {
          canvas.drawCircle(center, u * 0.08, Paint()..color = const Color(0xFFE8B923));
        }
      }
    }
    for (final i in hints) {
      final center = Offset((i % 8 + 0.5) * u, (i ~/ 8 + 0.5) * u);
      canvas.drawCircle(center, u * 0.12, Paint()..color = g.current == 1 ? const Color(0x88000000) : const Color(0xAAFFFFFF));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
