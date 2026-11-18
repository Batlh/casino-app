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
import 'go_engine.dart';

const goLevels = ['Leicht', 'Mittel', 'Schwer'];
const goRewards = [60, 150, 300];

final goGuide = GameGuide('Go', const [
  GuideSection(
    'Ziel',
    'Schwarz und Weiß setzen abwechselnd einen Stein auf einen freien Schnittpunkt. Steine bewegen sich nicht. '
        'Am Ende zählt, wer mehr vom Brett hat: eigene Steine plus leere Punkte, die nur von eigenen Steinen '
        'umschlossen sind. Weiß bekommt 7,5 Punkte Ausgleich (Komi), weil Schwarz anfängt.',
  ),
  GuideSection(
    'Freiheiten und Schlagen',
    'Die freien Nachbarpunkte (oben, unten, links, rechts) eines Steins sind seine Freiheiten. Verbundene Steine '
        'teilen sie sich. Nimmst du einer Gruppe die letzte Freiheit, ist sie geschlagen und verschwindet. '
        'Einen Stein ohne Freiheit zu setzen ist verboten, außer er schlägt dabei.',
  ),
  GuideSection(
    'Ko',
    'Wird ein einzelner Stein geschlagen und könnte sofort zurückgeschlagen werden, entstünde endlos dieselbe '
        'Stellung. Deshalb darfst du nicht sofort zurückschlagen, sondern musst erst woanders spielen.',
  ),
  GuideSection(
    'Leben und Tod',
    'Eine Gruppe mit zwei getrennten Augen (eingeschlossenen leeren Punkten) kann nie geschlagen werden. '
        'Wer zwei Augen bauen kann, lebt; wer es verhindert, tötet.',
  ),
  GuideSection(
    'Spielende',
    'Wenn beide nacheinander passen, ist Schluss. Gezählt wird mit Flächenwertung: Steine plus Gebiet. '
        'Tote gegnerische Steine in deinem Gebiet solltest du vorher schlagen, das kostet dich nichts. '
        'Mit der Go-Schule lernst du die Grundlagen an kleinen Aufgaben.',
  ),
  GuideSection(
    'Mitspieler und Münzen',
    'Gegen den Computer in drei Stufen (Sieg: 60, 150 oder 300 Münzen) oder zu zweit an einem Gerät. '
        'Jede Aufgabe der Go-Schule bringt beim ersten Lösen 20 Münzen.',
  ),
]);

class GoScreen extends StatefulWidget {
  const GoScreen({super.key});

  @override
  State<GoScreen> createState() => _GoScreenState();
}

class _GoScreenState extends State<GoScreen> with NetDuelScreen {
  static const _saveId = 'go';
  late final Settings _store;
  GoGame? _g;
  List<Seat> _seats = const [];
  int _level = 1;
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
        _g = GoGame.fromJson(d['game'] as Map<String, dynamic>);
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _level = d['level'] as int;
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('go.spielstand', e, st);
        _g = null;
        _store.clearGame(_saveId);
      }
    }
    if (_g == null) WidgetsBinding.instance.addPostFrameCallback((_) => _start());
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

  int _netSize = 9;

  @override
  String get duelGame => 'go';
  @override
  String get duelTitle => 'Go';
  @override
  List<String> get duelSides => const ['Schwarz', 'Weiß'];
  @override
  Map<String, Object?> get duelOptions => {'n': _netSize};

  @override
  List<Widget> duelLobbyExtras() => [
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          ChoiceChip(label: const Text('9×9'), selected: _netSize == 9, onSelected: (_) => setState(() => _netSize = 9)),
          ChoiceChip(label: const Text('13×13'), selected: _netSize == 13, onSelected: (_) => setState(() => _netSize = 13)),
        ]),
      ];

  @override
  void duelStart(List<String> names, int mySeat, Map<String, Object?> options) {
    _token++;
    setState(() {
      _seats = [Seat(names[0], human: mySeat == 0), Seat(names[1], human: mySeat == 1)];
      _g = GoGame((options['n'] as num?)?.toInt() == 13 ? 13 : 9);
      _paid = true;
      _busy = false;
      _msg = '${names[0]} (Schwarz) beginnt';
    });
  }

  /// Züge im Netz: Feld, -1 passen, -2 aufgeben.
  @override
  bool duelApply(Object? move) {
    final g = _g;
    if (g == null || g.over || move is! int) return false;
    if (move == -1) {
      _pass(remote: true);
    } else if (move == -2) {
      _resign(remote: true);
    } else {
      if (!g.isLegal(move)) return false;
      _play(move, remote: true);
    }
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

  /// Beim ersten Öffnen: Spielen oder Go-Schule.
  Future<void> _start() async {
    final c = await showChoiceSheet(
      context,
      title: 'Go',
      options: const ['Spielen', 'Go-Schule: Grundlagen mit Aufgaben'],
    );
    if (!mounted) return;
    if (c == 1) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoSchoolScreen()));
      if (!mounted) return;
      if (_g == null) {
        _start();
      }
      return;
    }
    if (c == null) {
      if (_g == null) Navigator.of(context).pop();
      return;
    }
    _newGame();
  }

  Future<void> _newGame() async {
    _token++;
    void leave() {
      if (_g == null && mounted) Navigator.of(context).pop();
    }

    final size = await showChoiceSheet(context, title: 'Brettgröße', options: const ['9×9: schnell, gut zum Lernen', '13×13']);
    if (size == null || !mounted) {
      leave();
      return;
    }
    final seats = await showSeatSetup(
      context,
      gameId: _saveId,
      title: 'Go',
      minSeats: 2,
      maxSeats: 2,
      colorNames: const ['Schwarz', 'Weiß'],
      colors: const [Color(0xFF1A1A1A), Color(0xFFF2F2F2)],
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
        options: [for (var i = 0; i < 3; i++) '${goLevels[i]}: Sieg bringt ${goRewards[i]} Münzen'],
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
      _g = GoGame(size == 0 ? 9 : 13);
      _paid = false;
      _busy = false;
      _msg = '${seats[0].name} (Schwarz) beginnt';
    });
    _bot();
  }

  String _name(int color) => _seats[color - 1].name;

  bool get _humanTurn {
    final g = _g;
    return g != null && !g.over && _seats[g.current - 1].human && !_busy;
  }

  void _tap(Offset pos, double cell) {
    final g = _g;
    if (g == null || !_humanTurn) return;
    final c = (pos.dx / cell).floor();
    final r = (pos.dy / cell).floor();
    if (c < 0 || r < 0 || c >= g.n || r >= g.n) return;
    final p = r * g.n + c;
    if (!g.isLegal(p)) {
      if (g.board[p] == 0) setState(() => _msg = 'Dort darfst du nicht setzen (keine Freiheit oder Ko)');
      return;
    }
    _play(p);
  }

  void _play(int p, {bool remote = false}) {
    final g = _g!;
    final who = g.current;
    final before = g.captures[who];
    g.play(p);
    if (!remote) duelSendMove(p);
    final taken = g.captures[who] - before;
    AppScope.of(context).sfx.play(taken > 0 ? Sound.lose : Sound.chip);
    setState(() => _msg = taken > 0
        ? '${_name(who)} schlägt $taken Stein${taken == 1 ? '' : 'e'}. ${_name(g.current)} ist dran'
        : '${_name(g.current)} ist dran');
    _bot();
  }

  void _pass({bool remote = false}) {
    final g = _g!;
    final who = g.current;
    g.pass();
    if (!remote) duelSendMove(-1);
    if (g.over) {
      _finish();
      return;
    }
    setState(() => _msg = '${_name(who)} passt. Passt ${_name(g.current)} auch, ist das Spiel aus');
    _bot();
  }

  void _resign({bool remote = false}) {
    final g = _g!;
    g.resign();
    if (!remote) duelSendMove(-2);
    _finish();
  }

  void _finish() {
    final g = _g!;
    final w = g.winner!;
    final s = g.score();
    final reward = duelPlaying ? 0 : seatReward(_seats, w - 1, goRewards[_level]);
    if (reward > 0 && !_paid) {
      _paid = true;
      AppScope.of(context).wallet.credit(reward);
    }
    AppScope.of(context).sfx.play(_seats[w - 1].human ? Sound.win : Sound.lose);
    final margin = s.abs().toStringAsFixed(1).replaceAll('.', ',');
    setState(() => _msg = g.resigned != null
        ? '${_name(g.resigned!)} gibt auf. ${_name(w)} gewinnt!${reward > 0 ? ' +$reward Münzen' : ''}'
        : '${_name(w)} gewinnt mit $margin Punkten!${reward > 0 ? ' +$reward Münzen' : ''}');
  }

  Future<void> _bot() async {
    final g = _g;
    if (g == null || g.over || _seats[g.current - 1].human || duelRemote(g.current - 1)) return;
    final token = ++_token;
    setState(() => _busy = true);
    final copy = g.copy();
    final level = _level;
    final seed = math.Random().nextInt(1 << 30);
    final wait = Future<void>.delayed(_store.botDelay(500));
    int m;
    try {
      m = await Isolate.run(() => goBotMove(copy, level, math.Random(seed)));
    } catch (e, st) {
      debugLog.error('go.bot', e, st);
      m = goBotMove(copy, 0, math.Random(seed));
    }
    await wait;
    if (!mounted || token != _token) return;
    _busy = false;
    if (m < 0) {
      _pass();
    } else {
      _play(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Go',
      guide: goGuide,
      actions: duelActions(context),
      network: duelActive ? null : duelOpenPanel,
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
                            Text(
                              '${_name(color)} · ${g.captures[color]} geschlagen',
                              style: TextStyle(
                                color: g.current == color && !g.over ? p.onAccent : p.onFelt,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final size = math.min(box.maxWidth, box.maxHeight) - 16;
                    return Center(
                      child: TapCatcher(
                        area: 'go',
                        onTap: (pos) => _tap(pos, size / g.n),
                        child: CustomPaint(
                          size: Size.square(size),
                          painter: GoPainter(g, showTerritory: g.over),
                        ),
                      ),
                    );
                  }),
                ),
                ResultBanner(text: _busy ? '${_name(g.current)} überlegt …' : _msg, highlight: g.over, maxLines: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!g.over) ...[
                        ActionButton(label: 'Passen', onPressed: _humanTurn ? _pass : null),
                        ActionButton(label: 'Aufgeben', onPressed: _humanTurn ? _resign : null),
                      ],
                      if (duelPlaying)
                        ...duelButtons(over: g.over)
                      else ...[
                        ActionButton(primary: g.over, label: 'Neues Spiel', onPressed: _newGame),
                        ActionButton(
                          label: 'Go-Schule',
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GoSchoolScreen())),
                        ),
                        if (g.over || MediaQuery.sizeOf(context).width < 420) ActionButton(label: 'Im Netzwerk', onPressed: duelOpenPanel),
                      ],
                    ],
                  ),
                ),
              ],
            )),
    );
  }
}

class GoPainter extends CustomPainter {
  GoPainter(this.g, {this.showTerritory = false, this.marks = const {}, this.wrong = const {}});
  final GoGame g;
  final bool showTerritory;

  /// Grün markierte Punkte (richtige Antwort) und rot markierte (falsch versucht).
  final Set<int> marks;
  final Set<int> wrong;

  @override
  void paint(Canvas canvas, Size size) {
    final n = g.n;
    final u = size.width / n;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 0.2)), Paint()..color = const Color(0xFFDDB46B));
    final line = Paint()
      ..color = const Color(0xFF3A2410)
      ..strokeWidth = math.max(1, u * 0.035);
    for (var i = 0; i < n; i++) {
      final a = (i + 0.5) * u;
      canvas.drawLine(Offset(u / 2, a), Offset(size.width - u / 2, a), line);
      canvas.drawLine(Offset(a, u / 2), Offset(a, size.height - u / 2), line);
    }
    // Sternpunkte
    final stars = n == 9 ? [2, 6] : (n == 13 ? [3, 9] : <int>[]);
    for (final r in stars) {
      for (final c in stars) {
        canvas.drawCircle(Offset((c + 0.5) * u, (r + 0.5) * u), u * 0.09, Paint()..color = const Color(0xFF3A2410));
      }
    }
    if (n == 9 || n == 13) {
      final m = (n - 1) / 2;
      canvas.drawCircle(Offset((m + 0.5) * u, (m + 0.5) * u), u * 0.09, Paint()..color = const Color(0xFF3A2410));
    }
    final terr = showTerritory ? g.territory() : null;
    for (var i = 0; i < n * n; i++) {
      final c = Offset((i % n + 0.5) * u, (i ~/ n + 0.5) * u);
      final v = g.board[i];
      if (v != 0) {
        canvas.drawCircle(c + Offset(u * 0.03, u * 0.05), u * 0.46, Paint()..color = Colors.black38);
        canvas.drawCircle(c, u * 0.46, Paint()..color = v == 1 ? const Color(0xFF1A1A1A) : const Color(0xFFF4F1EA));
        canvas.drawCircle(c - Offset(u * 0.14, u * 0.14), u * 0.12, Paint()..color = v == 1 ? const Color(0x33FFFFFF) : const Color(0x88FFFFFF));
        if (i == g.lastMove) {
          canvas.drawCircle(c, u * 0.16, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.06
            ..color = v == 1 ? Colors.white : Colors.black);
        }
      } else if (terr != null && terr[i] != 0) {
        canvas.drawRect(Rect.fromCenter(center: c, width: u * 0.3, height: u * 0.3), Paint()..color = terr[i] == 1 ? Colors.black : Colors.white);
      }
      if (marks.contains(i)) {
        canvas.drawCircle(c, u * 0.3, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.08
          ..color = const Color(0xFF2E9E57));
      }
      if (wrong.contains(i) && v == 0) {
        final d = u * 0.18;
        final x = Paint()
          ..strokeWidth = u * 0.08
          ..color = const Color(0xFFD8402B);
        canvas.drawLine(c - Offset(d, d), c + Offset(d, d), x);
        canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), x);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Go-Schule -----------------------------------------------------------------

class GoLesson {
  const GoLesson(this.title, this.text, this.task, this.diagram, this.success, {this.hint = ''});
  final String title;
  final String text;
  final String task;

  /// 9×9-Diagramm; '*' markiert die richtigen Züge für Schwarz.
  final List<String> diagram;
  final String success;
  final String hint;
}

const goLessons = [
  GoLesson(
    'Freiheiten',
    'Ein Stein atmet über seine freien Nachbarpunkte, die Freiheiten. Der weiße Stein in der Mitte hat nur noch eine.',
    'Nimm ihm die letzte Freiheit.',
    [
      '.........',
      '.........',
      '.........',
      '....X....',
      '...XO*...',
      '....X....',
      '.........',
      '.........',
      '.........',
    ],
    'Geschlagen! Ein Stein ohne Freiheit wird vom Brett genommen.',
    hint: 'Welcher Nachbarpunkt des weißen Steins ist noch frei?',
  ),
  GoLesson(
    'Gruppen schlagen',
    'Verbundene Steine teilen sich ihre Freiheiten. Am Rand haben Steine weniger davon.',
    'Schlage die beiden weißen Steine am unteren Rand.',
    [
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '...XX....',
      '..XOO*...',
    ],
    'Zwei auf einmal! Am Rand sind Gruppen schnell in Not.',
    hint: 'Zähle die Freiheiten der weißen Zweiergruppe.',
  ),
  GoLesson(
    'Retten',
    'Dein schwarzer Stein steht im Atari: Er hat nur noch eine Freiheit.',
    'Rette ihn, indem du verlängerst.',
    [
      '.........',
      '.........',
      '.........',
      '....O....',
      '...OX*...',
      '....O....',
      '.........',
      '.........',
      '.........',
    ],
    'Gerettet: Die Gruppe hat jetzt drei Freiheiten.',
    hint: 'Setze auf die letzte Freiheit deines Steins.',
  ),
  GoLesson(
    'Ko',
    'Hier kannst du einen weißen Stein schlagen. Danach dürfte Weiß sofort zurückschlagen und alles begänne von vorn. '
        'Das verbietet die Ko-Regel: Weiß muss erst woanders spielen.',
    'Schlage den weißen Stein.',
    [
      '.........',
      '.........',
      '.........',
      '...XO....',
      '..XO*O...',
      '...XO....',
      '.........',
      '.........',
      '.........',
    ],
    'Richtig. Weiß darf nicht sofort zurückschlagen.',
    hint: 'Dein neuer Stein hätte keine Freiheit, aber er schlägt dabei.',
  ),
  GoLesson(
    'Leben',
    'Eine Gruppe mit zwei getrennten Augen lebt für immer. Deine Gruppe unten hat drei freie Punkte in einer Reihe.',
    'Mache zwei Augen.',
    [
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.OOOOOOO.',
      '.OXXXXXO.',
      '.OX.*.XO.',
    ],
    'Zwei Augen, die Gruppe lebt!',
    hint: 'Der Punkt in der Mitte teilt den Raum.',
  ),
  GoLesson(
    'Töten',
    'Jetzt ist es umgekehrt: Die weiße Gruppe hat drei freie Punkte in einer Reihe.',
    'Verhindere zwei Augen.',
    [
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.........',
      '.XXXXXXX.',
      '.XOOOOOX.',
      '.XO.*.OX.',
    ],
    'Weiß kann nur noch ein Auge machen und ist tot.',
    hint: 'Der wichtigste Punkt ist für beide derselbe.',
  ),
  GoLesson(
    'Zählen',
    'Am Ende zählt jede Seite ihre Steine und die leeren Punkte, die nur sie umschließt. Hier sind die Gebiete schon '
        'klar. Schwarz hat links 4 Spalten mit Steinen und Gebiet, Weiß rechts. Weiß bekommt 7,5 Punkte Komi.',
    'Setze einen schwarzen Stein in dein eigenes Gebiet (das kostet bei Flächenwertung nichts).',
    [
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
      '***XO....',
    ],
    'Richtig: Bei Flächenwertung zählen Steine und Gebiet gleich. Im eigenen Gebiet zu setzen schadet nicht.',
    hint: 'Dein Gebiet liegt links der schwarzen Mauer.',
  ),
];

class GoSchoolScreen extends StatefulWidget {
  const GoSchoolScreen({super.key});

  @override
  State<GoSchoolScreen> createState() => _GoSchoolScreenState();
}

class _GoSchoolScreenState extends State<GoSchoolScreen> {
  int _lesson = 0;
  late GoGame _g;
  late Set<int> _answers;
  final Set<int> _wrong = {};
  bool _solved = false;
  String _msg = '';
  late final Settings _store;
  Set<int> _done = {};

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    final d = _store.loadGame('go.schule');
    _done = {for (final v in (d?['done'] as List?) ?? const []) v as int};
    _load(_done.length < goLessons.length ? _firstOpen() : 0);
  }

  int _firstOpen() {
    for (var i = 0; i < goLessons.length; i++) {
      if (!_done.contains(i)) return i;
    }
    return 0;
  }

  void _load(int i) {
    final (g, a) = GoGame.fromDiagram(goLessons[i].diagram);
    _lesson = i;
    _g = g;
    _answers = a;
    _wrong.clear();
    _solved = false;
    _msg = goLessons[i].task;
  }

  void _tap(Offset pos, double cell) {
    if (_solved) return;
    final c = (pos.dx / cell).floor();
    final r = (pos.dy / cell).floor();
    if (c < 0 || r < 0 || c >= _g.n || r >= _g.n) return;
    final p = r * _g.n + c;
    if (_g.board[p] != 0) return;
    final sfx = AppScope.of(context).sfx;
    if (_answers.contains(p) && _g.isLegal(p)) {
      _g.play(p);
      var text = goLessons[_lesson].success;
      if (_done.add(_lesson)) {
        AppScope.of(context).wallet.credit(20);
        _store.saveGame('go.schule', {'done': _done.toList()});
        text += ' +20 Münzen';
      }
      sfx.play(Sound.win);
      setState(() {
        _solved = true;
        _msg = text;
      });
    } else {
      sfx.play(Sound.lose);
      setState(() {
        _wrong.add(p);
        _msg = 'Noch nicht. Tipp: ${goLessons[_lesson].hint}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final l = goLessons[_lesson];
    return GameFrame(
      title: 'Go-Schule',
      guide: goGuide,
      child: LayoutBuilder(builder: (context, box) {
        final landscape = box.maxWidth > box.maxHeight * 1.1;
        final text = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < goLessons.length; i++)
                  ChoiceChip(
                    label: Text('${i + 1}${_done.contains(i) ? ' ✓' : ''}'),
                    selected: i == _lesson,
                    onSelected: (_) => setState(() => _load(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_lesson + 1}. ${l.title}', style: TextStyle(color: p.onFelt, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l.text, style: TextStyle(color: p.onFelt, fontSize: 16)),
            const SizedBox(height: 6),
            ResultBanner(text: _msg, highlight: _solved, maxLines: 3),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionButton(label: 'Nochmal', onPressed: () => setState(() => _load(_lesson))),
                ActionButton(
                  primary: _solved,
                  label: _lesson + 1 < goLessons.length ? 'Nächste Aufgabe' : 'Fertig',
                  onPressed: () {
                    if (_lesson + 1 < goLessons.length) {
                      setState(() => _load(_lesson + 1));
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ],
        );
        final boardSize = landscape ? math.min(box.maxHeight - 16, box.maxWidth - 380) : math.min(box.maxWidth - 16, box.maxHeight - 300);
        final board = TapCatcher(
          area: 'go.schule',
          onTap: (pos) => _tap(pos, boardSize / _g.n),
          child: CustomPaint(
            size: Size.square(math.max(120, boardSize)),
            painter: GoPainter(_g, marks: _solved ? _answers.where((a) => _g.board[a] != 0).toSet() : const {}, wrong: _wrong),
          ),
        );
        return landscape
            ? Row(children: [
                Expanded(child: Center(child: board)),
                SizedBox(width: 360, child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: text)),
              ])
            : Column(children: [
                Expanded(child: Center(child: board)),
                Padding(padding: const EdgeInsets.all(12), child: text),
              ]);
      }),
    );
  }
}
