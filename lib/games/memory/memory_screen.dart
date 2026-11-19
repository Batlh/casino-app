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
import '../cards/card_widgets.dart';
import '../mahjong/tiles.dart';
import 'memory_engine.dart';

const memoryWinReward = 100;

enum MemoryMotif { tiles, symbols, cats }

const memoryMotifNames = {
  MemoryMotif.tiles: 'Mahjong-Steine',
  MemoryMotif.symbols: 'Symbole',
  MemoryMotif.cats: 'Katzen',
};

final memoryGuide = GameGuide('Memory', const [
  GuideSection(
    'Ziel',
    'Alle Karten liegen verdeckt. Wer am Zug ist, deckt zwei auf. Zeigen beide dasselbe Motiv, darf er das Paar '
        'behalten und gleich nochmal. Sonst werden sie wieder umgedreht und der Nächste ist dran.',
  ),
  GuideSection(
    'Gewinnen',
    'Sind alle Paare vergeben, gewinnt, wer die meisten hat. Allein spielst du gegen die Uhr der Züge: '
        'Je weniger Züge du brauchst, desto mehr Münzen gibt es. Gegen den Computer bringt ein Sieg $memoryWinReward Münzen.',
  ),
  GuideSection(
    'Einstellungen',
    'Vor dem Spiel wählst du 8, 12 oder 18 Paare und die Motive: Mahjong-Steine, Symbole oder Katzen. '
        'Die Computer merken sich das meiste, aber nicht alles.',
  ),
]);

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> with NetReplayScreen {
  static const _saveId = 'memory';
  late final Settings _store;
  MemoryGame? _g;
  List<Seat> _seats = const [];
  MemoryMotif _motif = MemoryMotif.tiles;
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
        _g = MemoryGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _motif = MemoryMotif.values[d['motif'] as int];
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _botLoop());
      } catch (e, st) {
        debugLog.error('memory.spielstand', e, st);
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
    replayDispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- Netzwerk

  final List<List<Object?>> _log = [];

  @override
  String get replayGame => 'memory';
  @override
  String get replayTitle => 'Memory';
  @override
  int get replaySeats => 4;
  @override
  List<String> get replayBotNames => const [];
  @override
  List<List<Object?>> get replayLog => _log;
  @override
  Map<String, Object?> get replayOptions => {'pairs': _g?.pairs ?? 12, 'motif': _motif.index};

  @override
  void replayNewGame(int seed, List<String> names, int me, Map<String, Object?> options) {
    _token++;
    _log.clear();
    final pairs = ((options['pairs'] as num?)?.toInt() ?? 12).clamp(4, 18);
    _seats = [for (final (i, n) in names.indexed) Seat(n, human: replayHumans.contains(i))];
    _motif = MemoryMotif.values[((options['motif'] as num?)?.toInt() ?? 0).clamp(0, MemoryMotif.values.length - 1)];
    _g = MemoryGame(pairs, names.length, rng: math.Random(seed));
    _paid = false;
    _busy = false;
    _msg = '${names[0]} beginnt';
  }

  @override
  void replayApply(List<dynamic> a) => _apply(a);

  @override
  bool replayAllowed(int seat, List<dynamic> a) {
    final g = _g;
    if (g == null || g.over || seat != g.current || a[0] != 'f') return false;
    return g.canFlip((a[1] as num).toInt());
  }

  @override
  void replayAfterRemote(List<List<dynamic>> acts) {
    if (acts.any((a) => a[0] == 'f')) AppScope.of(context).sfx.play(Sound.card);
    setState(() {});
    final g = _g;
    if (g == null || replayIsGuest) return;
    if (g.waiting && !_busy) {
      _afterPair();
    } else {
      _botLoop();
    }
  }

  @override
  void replayClosed() => _newGame();

  /// Zug ausführen: allein und beim Gastgeber sofort, als Mitspieler über den Gastgeber.
  void _do(List<Object?> a) {
    if (replaySend(a)) return;
    _apply(a);
    replayBroadcast();
  }

  void _apply(List<dynamic> a) {
    final g = _g!;
    switch (a[0]) {
      case 'f':
        if (!g.flip((a[1] as num).toInt(), bots: _bots)) throw StateError('Karte nicht frei');
      case 'r':
        if (!g.waiting) throw StateError('Nichts aufgedeckt');
        final match = g.cards[g.open[0]] == g.cards[g.open[1]];
        final who = g.current;
        g.resolve();
        if (match) AppScope.of(context).sfx.play(Sound.chip);
        _msg = match
            ? (_seats.length == 1 ? 'Paar gefunden!' : '${_seats[who].name} findet ein Paar und ist nochmal dran')
            : (_seats.length == 1 ? 'Leider kein Paar' : '${_seats[g.current].name} ist dran');
        if (g.over) _msg = _finish(g);
      default:
        throw StateError('Unbekannter Zug $a');
    }
    _log.add(a);
  }

  /// Ist dieser Platz am Zug und wird hier bedient (Mensch an diesem Gerät)?
  bool _mineToPlay(int seat) => replayActive ? seat == replayMe : _seats[seat].human;

  /// Spielt hier der Computer (im Netz nur beim Gastgeber)?
  bool _botHere(int seat) => replayActive ? replayIsHost && replayIsBot(seat) : !_seats[seat].human;

  void _persist() {
    final g = _g;
    if (replayActive) return;
    if (g == null || g.over) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {
      'game': g.toJson(),
      'seats': [for (final s in _seats) s.toJson()],
      'motif': _motif.index,
      'paid': _paid,
    });
  }

  List<int> get _bots => [for (var i = 0; i < _seats.length; i++) if (!_seats[i].human) i];

  Future<void> _newGame() async {
    _token++;
    void leave() {
      if (_g == null && mounted) Navigator.of(context).pop();
    }

    final seats = await showSeatSetup(context, gameId: _saveId, title: 'Memory', minSeats: 1, maxSeats: 4);
    if (seats == null || !mounted) {
      leave();
      return;
    }
    final size = await showChoiceSheet(context, title: 'Wie viele Paare?', options: const ['8 Paare', '12 Paare', '18 Paare']);
    if (size == null || !mounted) {
      leave();
      return;
    }
    final motif = await showChoiceSheet(
      context,
      title: 'Welche Motive?',
      options: [for (final m in MemoryMotif.values) memoryMotifNames[m]!],
    );
    if (motif == null || !mounted) {
      leave();
      return;
    }
    setState(() {
      _seats = seats;
      _motif = MemoryMotif.values[motif];
      _g = MemoryGame(const [8, 12, 18][size], seats.length);
      _paid = false;
      _busy = false;
      _msg = seats.length == 1 ? 'Finde alle Paare' : '${seats[0].name} beginnt';
    });
    _botLoop();
  }

  void _tap(int i) {
    final g = _g;
    if (g == null || g.over || _busy || !_mineToPlay(g.current) || !g.canFlip(i)) return;
    _do(['f', i]);
    AppScope.of(context).sfx.play(Sound.card);
    setState(() {});
    if (g.waiting && !replayIsGuest) _afterPair();
  }

  Future<void> _afterPair() async {
    final g = _g!;
    final token = ++_token;
    setState(() => _busy = true);
    final match = g.cards[g.open[0]] == g.cards[g.open[1]];
    await Future<void>.delayed(Duration(milliseconds: match ? 600 : 1100));
    if (!mounted || token != _token || !identical(g, _g)) return;
    _do(['r']);
    setState(() => _busy = false);
    _botLoop();
  }

  String _finish(MemoryGame g) {
    final wallet = AppScope.of(context).wallet;
    final sfx = AppScope.of(context).sfx;
    if (_seats.length == 1) {
      final extra = g.turns[0] - g.pairs;
      final reward = math.max(10, g.pairs * 15 - extra * 5);
      if (!_paid) {
        _paid = true;
        wallet.credit(reward);
      }
      sfx.play(Sound.win);
      return 'Geschafft in ${g.turns[0]} Zügen! +$reward Münzen';
    }
    final best = g.scores.reduce(math.max);
    final winners = [for (var i = 0; i < g.players; i++) if (g.scores[i] == best) i];
    if (winners.length > 1) return 'Unentschieden: ${winners.map((w) => _seats[w].name).join(' und ')}';
    final w = winners.first;
    final reward = replayActive ? (w == replayMe ? memoryWinReward : 0) : seatReward(_seats, w, memoryWinReward);
    if (reward > 0 && !_paid) {
      _paid = true;
      wallet.credit(reward);
    }
    sfx.play((replayActive ? w == replayMe : _seats[w].human) ? Sound.win : Sound.lose);
    return '${_seats[w].name} gewinnt mit $best Paaren!${reward > 0 ? ' +$reward Münzen' : ''}';
  }

  Future<void> _botLoop() async {
    final g = _g;
    if (g == null || g.over || !_botHere(g.current) || _busy) return;
    final token = ++_token;
    setState(() => _busy = true);
    final p = g.current;
    for (var k = 0; k < 2; k++) {
      await Future<void>.delayed(_store.botDelay(650));
      if (!mounted || token != _token) return;
      _do(['f', g.botPick(p)]);
      AppScope.of(context).sfx.play(Sound.card);
      setState(() {});
    }
    _busy = false;
    _afterPair();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Memory',
      guide: memoryGuide,
      actions: replayActions(context),
      network: replayActive ? null : replayOpenPanel,
      child: replayScreen() ?? (g == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Wrap(
                    spacing: 10,
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
                              _seats.length == 1
                                  ? 'Züge: ${g.turns[0]} · Paare: ${g.scores[0]}/${g.pairs}'
                                  : '${_seats[i].name} · ${g.scores[i]}',
                              style: TextStyle(color: i == g.current && !g.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(child: LayoutBuilder(builder: (context, box) => _grid(g, box))),
                ResultBanner(text: _msg, highlight: g.over, maxLines: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: replayActive
                      ? Wrap(spacing: 8, alignment: WrapAlignment.center, children: replayButtons(label: 'Neues Spiel', next: replayHostStart))
                      : ActionButton(primary: g.over, label: 'Neues Spiel', onPressed: _newGame),
                ),
              ],
            )),
    );
  }

  Widget _grid(MemoryGame g, BoxConstraints box) {
    final n = g.cards.length;
    // Spaltenzahl so wählen, dass die Karten möglichst groß werden
    var bestCols = 4;
    var bestSize = 0.0;
    for (var cols = 3; cols <= 9; cols++) {
      final rows = (n / cols).ceil();
      final s = math.min((box.maxWidth - 16) / cols, (box.maxHeight - 16) / (rows * 1.25));
      if (s > bestSize) {
        bestSize = s;
        bestCols = cols;
      }
    }
    final w = bestSize - 6;
    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < n; i++)
            SizedBox(
              width: w,
              height: w * 1.25,
              child: g.owner[i] >= 0
                  ? Opacity(opacity: 0.18, child: _face(g.cards[i], w))
                  : TapCatcher(
                      area: 'memory',
                      onTap: (_) => _tap(i),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                        child: g.open.contains(i)
                            ? SizedBox.expand(key: ValueKey('f$i'), child: _face(g.cards[i], w))
                            : SizedBox.expand(key: ValueKey('b$i'), child: _back(w)),
                      ),
                    ),
            ),
        ],
      ),
    ).withCols(bestCols, w);
  }

  Widget _back(double w) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(w * 0.1),
          gradient: const LinearGradient(colors: [Color(0xFF7A1F12), Color(0xFFB8452A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: const Color(0xFFF6E7C8), width: 2),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38, offset: Offset(1, 2))],
        ),
        child: Center(child: Icon(Icons.auto_awesome, color: const Color(0x66F6E7C8), size: w * 0.4)),
      );

  Widget _face(int v, double w) {
    final inner = switch (_motif) {
      MemoryMotif.tiles => Center(child: TileView(tile: _memoryTiles[v % _memoryTiles.length], width: w * 0.62)),
      MemoryMotif.symbols => Center(
          child: Icon(_symbols[v % _symbols.length].$1, color: _symbols[v % _symbols.length].$2, size: w * 0.62),
        ),
      MemoryMotif.cats => Padding(padding: EdgeInsets.all(w * 0.08), child: CustomPaint(painter: CatFacePainter(v))),
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(w * 0.1),
        border: Border.all(color: const Color(0xFFE2C98E), width: 2),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38, offset: Offset(1, 2))],
      ),
      child: inner,
    );
  }
}

extension on Widget {
  /// Begrenzt die Breite so, dass genau [cols] Karten nebeneinander passen.
  Widget withCols(int cols, double w) => Center(child: SizedBox(width: cols * (w + 6), child: this));
}

const _memoryTiles = [0, 4, 8, 9, 13, 17, 18, 22, 26, 27, 28, 29, 30, 31, 32, 33, 34, 38];

const _symbols = <(IconData, Color)>[
  (Icons.star, Color(0xFFE8B923)),
  (Icons.favorite, Color(0xFFD8402B)),
  (Icons.local_florist, Color(0xFFD45A9A)),
  (Icons.wb_sunny, Color(0xFFEE7F2D)),
  (Icons.nightlight_round, Color(0xFF3B4FA0)),
  (Icons.ac_unit, Color(0xFF2FA6D0)),
  (Icons.music_note, Color(0xFF8E4FC9)),
  (Icons.anchor, Color(0xFF1F3F6B)),
  (Icons.eco, Color(0xFF2E9E57)),
  (Icons.cake, Color(0xFFC1663A)),
  (Icons.diamond, Color(0xFF2FB5A5)),
  (Icons.rocket_launch, Color(0xFF6B6B7A)),
  (Icons.pets, Color(0xFF7A4A2A)),
  (Icons.bolt, Color(0xFFE0A030)),
  (Icons.cloud, Color(0xFF7FA6C8)),
  (Icons.local_cafe, Color(0xFF5A3420)),
  (Icons.sailing, Color(0xFF2F7FD0)),
  (Icons.emoji_nature, Color(0xFF9AB22F)),
];

/// Katzengesicht in 18 Varianten: sechs Fellfarben, je einfarbig, gestreift oder mit Fleck.
class CatFacePainter extends CustomPainter {
  CatFacePainter(this.variant);
  final int variant;

  static const _fur = [
    Color(0xFFE8963A), // rot getigert
    Color(0xFF6E6E78), // grau
    Color(0xFF2B2B30), // schwarz
    Color(0xFFF2EEE6), // weiß
    Color(0xFFC9A57A), // creme
    Color(0xFF8A5A3A), // braun
  ];
  static const _eyes = [Color(0xFF3FA34D), Color(0xFFE8B923), Color(0xFF2F7FD0)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final fur = _fur[variant % 6];
    final pattern = (variant ~/ 6) % 3;
    final dark = fur.computeLuminance() < 0.2;
    final line = dark ? const Color(0xFFBDBDBD) : const Color(0xFF3A2116);
    final furPaint = Paint()..color = fur;
    // Ohren
    for (final dir in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * (0.5 + dir * 0.36), s * 0.42)
        ..lineTo(s * (0.5 + dir * 0.34), s * 0.08)
        ..lineTo(s * (0.5 + dir * 0.1), s * 0.3)
        ..close();
      canvas.drawPath(ear, furPaint);
      final inner = Path()
        ..moveTo(s * (0.5 + dir * 0.31), s * 0.36)
        ..lineTo(s * (0.5 + dir * 0.31), s * 0.16)
        ..lineTo(s * (0.5 + dir * 0.17), s * 0.3)
        ..close();
      canvas.drawPath(inner, Paint()..color = const Color(0xFFF2A5B0));
    }
    // Kopf
    final head = Rect.fromCenter(center: Offset(s * 0.5, s * 0.56), width: s * 0.8, height: s * 0.66);
    canvas.drawOval(head, furPaint);
    canvas.save();
    canvas.clipPath(Path()..addOval(head));
    if (pattern == 1) {
      final stripe = Paint()
        ..color = Color.lerp(fur, Colors.black, 0.35)!
        ..strokeWidth = s * 0.045
        ..strokeCap = StrokeCap.round;
      for (final dx in [-0.08, 0.0, 0.08]) {
        canvas.drawLine(Offset(s * (0.5 + dx), s * 0.24), Offset(s * (0.5 + dx), s * 0.38), stripe);
      }
      for (final dir in [-1.0, 1.0]) {
        canvas.drawLine(Offset(s * (0.5 + dir * 0.4), s * 0.5), Offset(s * (0.5 + dir * 0.28), s * 0.53), stripe);
        canvas.drawLine(Offset(s * (0.5 + dir * 0.4), s * 0.6), Offset(s * (0.5 + dir * 0.29), s * 0.61), stripe);
      }
    } else if (pattern == 2) {
      final spot = Color.lerp(fur, dark ? Colors.white : const Color(0xFF3A2116), 0.45)!;
      canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.34, s * 0.4), width: s * 0.3, height: s * 0.26), Paint()..color = spot);
    }
    canvas.restore();
    // Schnauze
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.5, s * 0.7), width: s * 0.3, height: s * 0.18),
      Paint()..color = Color.lerp(fur, Colors.white, 0.55)!,
    );
    // Augen
    final eye = _eyes[variant % 3];
    for (final dir in [-1.0, 1.0]) {
      final c = Offset(s * (0.5 + dir * 0.16), s * 0.52);
      canvas.drawOval(Rect.fromCenter(center: c, width: s * 0.15, height: s * 0.13), Paint()..color = eye);
      canvas.drawOval(Rect.fromCenter(center: c, width: s * 0.04, height: s * 0.11), Paint()..color = Colors.black);
      canvas.drawCircle(c + Offset(-s * 0.025, -s * 0.025), s * 0.015, Paint()..color = Colors.white);
    }
    // Nase und Mund
    final nose = Path()
      ..moveTo(s * 0.46, s * 0.64)
      ..lineTo(s * 0.54, s * 0.64)
      ..lineTo(s * 0.5, s * 0.69)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFE07A8A));
    final mouth = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round
      ..color = line;
    canvas.drawArc(Rect.fromCenter(center: Offset(s * 0.46, s * 0.71), width: s * 0.08, height: s * 0.06), 0, math.pi, false, mouth);
    canvas.drawArc(Rect.fromCenter(center: Offset(s * 0.54, s * 0.71), width: s * 0.08, height: s * 0.06), 0, math.pi, false, mouth);
    // Schnurrhaare
    final whisker = Paint()
      ..strokeWidth = s * 0.012
      ..color = line.withValues(alpha: 0.7);
    for (final dir in [-1.0, 1.0]) {
      for (final dy in [-0.02, 0.02]) {
        canvas.drawLine(Offset(s * (0.5 + dir * 0.12), s * (0.69 + dy)), Offset(s * (0.5 + dir * 0.42), s * (0.66 + dy * 2.5)), whisker);
      }
    }
  }

  @override
  bool shouldRepaint(CatFacePainter old) => old.variant != variant;
}
