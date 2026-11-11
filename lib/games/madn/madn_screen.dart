import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/settings.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guide.dart';
import '../../ui/settings_sheet.dart';
import '../../ui/tap_catcher.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../sicbo/sicbo_screen.dart' show DieFace;
import 'madn_engine.dart';

const madnWinReward = 150;

final madnGuide = GameGuide('Mensch ärgere dich nicht', const [
  GuideSection(
    'Ziel',
    'Bringe alle vier Figuren einmal rund ums Brett in dein Ziel in der Mitte. Wer das zuerst schafft, gewinnt.',
  ),
  GuideSection(
    'Herauskommen',
    'Alle Figuren starten im Haus in deiner Ecke. Mit einer 6 setzt du eine Figur auf dein Startfeld. '
        'Steht dort schon eine eigene Figur, musst du sie zuerst weiterziehen.',
  ),
  GuideSection(
    'Schlagen',
    'Landest du genau auf einer gegnerischen Figur, wird sie geschlagen und muss zurück ins Haus. '
        'Auf eine eigene Figur darfst du nicht ziehen. Im Ziel wird nicht übersprungen.',
  ),
  GuideSection(
    'Hausregeln',
    'Hinter dem Zahnrad oben stellst du jede Regel einzeln ein: drei Versuche, wenn keine Figur draußen ist; '
        'nach einer 6 nochmal würfeln; Rausmuss-Pflicht bei einer 6; Schlagzwang. Standard: alle an.',
  ),
  GuideSection(
    'Mitspieler',
    'Zwei bis vier spielen mit, an einem Gerät oder gegen den Computer. Gewinnst du gegen den Computer, '
        'gibt es $madnWinReward Münzen.',
  ),
]);

class MadnScreen extends StatefulWidget {
  const MadnScreen({super.key});

  @override
  State<MadnScreen> createState() => _MadnScreenState();
}

class _MadnScreenState extends State<MadnScreen> {
  static const _saveId = 'madn';
  late final Settings _store;
  MadnGame? _g;
  List<Seat> _seats = const [];
  MadnRules _rules = const MadnRules();
  String _msg = '';
  bool _paid = false;
  bool _busy = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _store = AppScope.of(context).settings;
    _rules = MadnRules.fromJson(_store.loadGame('rules.madn'));
    final d = _store.loadGame(_saveId);
    if (d != null) {
      try {
        _g = MadnGame.fromJson(d['game'] as Map<String, dynamic>)..rules = _rules;
        _seats = [for (final s in d['seats'] as List) Seat.fromJson(s as Map<String, dynamic>)];
        _paid = d['paid'] as bool? ?? false;
        _msg = 'Spielstand geladen';
        WidgetsBinding.instance.addPostFrameCallback((_) => _bot());
      } catch (e, st) {
        debugLog.error('madn.spielstand', e, st);
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
    super.dispose();
  }

  void _persist() {
    final g = _g;
    if (g == null || g.phase == MadnPhase.over) {
      _store.clearGame(_saveId);
      return;
    }
    _store.saveGame(_saveId, {
      'game': g.toJson(),
      'seats': [for (final s in _seats) s.toJson()],
      'paid': _paid,
    });
  }

  void _setRules(MadnRules r) {
    _store.saveGame('rules.madn', r.toJson());
    setState(() {
      _rules = r;
      _g?.rules = r;
      final g = _g;
      if (g != null && g.phase == MadnPhase.move) g.movable = g.legalMoves();
    });
  }

  Future<void> _newGame() async {
    _token++;
    final seats = await showSeatSetup(context, gameId: _saveId, title: 'Mensch ärgere dich nicht', minSeats: 2, maxSeats: 4);
    if (seats == null || !mounted) {
      if (_g == null && mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _seats = seats;
      _g = MadnGame(seats.length, rules: _rules);
      _paid = false;
      _busy = false;
      _msg = '${seats[0].name} beginnt';
    });
    _bot();
  }

  bool get _humanTurn {
    final g = _g;
    return g != null && g.phase != MadnPhase.over && _seats[g.current].human && !_busy;
  }

  void _roll() {
    final g = _g;
    if (g == null || g.phase != MadnPhase.roll) return;
    final who = g.current;
    final d = g.roll();
    AppScope.of(context).sfx.play(Sound.tick);
    final name = _seats[who].name;
    String text;
    if (g.phase == MadnPhase.move) {
      text = g.movable.length == 1 && !_seats[who].human ? '$name würfelt $d' : '$name würfelt $d: Figur wählen';
    } else if (g.current == who) {
      text = d == 6 ? '$name würfelt 6, kann nicht ziehen und würfelt nochmal' : '$name würfelt $d, noch ${g.triesLeft} Versuch${g.triesLeft == 1 ? '' : 'e'}';
    } else {
      text = '$name würfelt $d und kann nicht ziehen. ${_seats[g.current].name} ist dran';
    }
    setState(() => _msg = text);
    // Nur eine Figur möglich: bei Menschen trotzdem antippen lassen, damit man sieht, was passiert
    _bot();
  }

  void _move(int k) {
    final g = _g!;
    final who = g.current;
    final m = g.move(k);
    final sfx = AppScope.of(context).sfx;
    final name = _seats[who].name;
    var text = '$name zieht';
    if (m.captured != null) {
      text = '$name schlägt ${_seats[m.captured!.$1].name}!';
      sfx.play(Sound.lose);
    } else {
      sfx.play(Sound.chip);
    }
    if (g.phase == MadnPhase.over) {
      final reward = seatReward(_seats, who, madnWinReward);
      if (reward > 0 && !_paid) {
        _paid = true;
        AppScope.of(context).wallet.credit(reward);
      }
      sfx.play(_seats[who].human ? Sound.win : Sound.lose);
      text = '$name hat alle Figuren im Ziel und gewinnt!${reward > 0 ? ' +$reward Münzen' : ''}';
    } else if (g.current == who) {
      text += ' und würfelt nochmal';
    } else {
      text += '. ${_seats[g.current].name} ist dran';
    }
    debugLog.detail('madn', '$name: Figur $k von ${m.from} nach ${m.to}');
    setState(() => _msg = text);
    _bot();
  }

  Future<void> _bot() async {
    final g = _g;
    if (g == null || g.phase == MadnPhase.over || _seats[g.current].human) return;
    final token = ++_token;
    setState(() => _busy = true);
    await Future<void>.delayed(_store.botDelay(g.phase == MadnPhase.roll ? 600 : 500));
    if (!mounted || token != _token) return;
    _busy = false;
    if (g.phase == MadnPhase.roll) {
      _roll();
    } else {
      _move(g.botChoice());
    }
  }

  void _tapBoard(Offset pos, double u) {
    final g = _g;
    if (g == null || !_humanTurn) return;
    if (g.phase == MadnPhase.roll) {
      _roll();
      return;
    }
    final cx = (pos.dx / u).floor();
    final cy = (pos.dy / u).floor();
    for (final k in g.movable) {
      final c = madnCell(g, g.current, k);
      if (c.$1 == cx && c.$2 == cy) {
        _move(k);
        return;
      }
    }
    // Danebengetippt: bei nur einer Möglichkeit genügt das
    if (g.movable.length == 1) _move(g.movable.first);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final p = Palette.of(context);
    return GameFrame(
      title: 'Mensch ärgere dich nicht',
      guide: madnGuide,
      settings: GameSettings('Mensch ärgere dich nicht', (context) => _RulesPanel(rules: _rules, onChanged: _setRules)),
      child: g == null
          ? const SizedBox.shrink()
          : LayoutBuilder(builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.1;
              final side = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < _seats.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == g.current && g.phase != MadnPhase.over ? p.accent : Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: i == g.current && g.phase != MadnPhase.over ? p.accent : p.panelEdge),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 8, backgroundColor: seatColors[i]),
                            const SizedBox(width: 6),
                            Text(
                              '${_seats[i].name} · ${g.pieces[i].where((x) => x >= MadnGame.goalStart).length}/4',
                              style: TextStyle(color: i == g.current && g.phase != MadnPhase.over ? p.onAccent : p.onFelt, fontWeight: FontWeight.w700),
                            ),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (g.dice != null) DieFace(value: g.dice!, size: 48),
                  ResultBanner(text: _msg, highlight: g.phase == MadnPhase.over, maxLines: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionButton(
                        primary: true,
                        label: g.phase == MadnPhase.over
                            ? 'Fertig'
                            : _seats[g.current].human
                                ? (g.phase == MadnPhase.roll ? '${_seats[g.current].name}: Würfeln' : 'Figur antippen')
                                : '${_seats[g.current].name} ist dran',
                        onPressed: _humanTurn && g.phase == MadnPhase.roll ? _roll : null,
                      ),
                      ActionButton(label: 'Neues Spiel', onPressed: _newGame),
                    ],
                  ),
                ],
              );
              final boardSize = math.max(
                100.0,
                landscape ? math.min(box.maxWidth - 300, box.maxHeight) - 16 : math.min(box.maxWidth, box.maxHeight - 200) - 16,
              );
              final board = TapCatcher(
                area: 'madn',
                onTap: (pos) => _tapBoard(pos, boardSize / 11),
                child: CustomPaint(
                  size: Size.square(boardSize),
                  painter: _MadnPainter(g, _humanTurn && g.phase == MadnPhase.move ? g.movable : const []),
                ),
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
            }),
    );
  }
}

class _RulesPanel extends StatefulWidget {
  const _RulesPanel({required this.rules, required this.onChanged});
  final MadnRules rules;
  final ValueChanged<MadnRules> onChanged;

  @override
  State<_RulesPanel> createState() => _RulesPanelState();
}

class _RulesPanelState extends State<_RulesPanel> {
  late MadnRules _r = widget.rules;

  void _set(MadnRules r) {
    setState(() => _r = r);
    widget.onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget sw(String title, String sub, bool v, ValueChanged<bool> on) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: TextStyle(color: p.ink, fontSize: 16)),
          subtitle: Text(sub, style: TextStyle(color: p.inkSoft, fontSize: 14)),
          value: v,
          onChanged: on,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sw('Drei Versuche', 'Ohne Figur draußen dreimal würfeln, um eine 6 zu bekommen', _r.threeTries,
            (v) => _set(_r.copyWith(threeTries: v))),
        sw('6 = nochmal', 'Nach einer 6 wird nochmal gewürfelt', _r.sixAgain, (v) => _set(_r.copyWith(sixAgain: v))),
        sw('Rausmuss-Pflicht', 'Bei einer 6 muss eine Figur raus, das Startfeld wird frei gemacht', _r.mustLeaveStart,
            (v) => _set(_r.copyWith(mustLeaveStart: v))),
        sw('Schlagzwang', 'Wer schlagen kann, muss schlagen', _r.captureForced,
            (v) => _set(_r.copyWith(captureForced: v))),
      ],
    );
  }
}

class _MadnPainter extends CustomPainter {
  _MadnPainter(this.g, this.highlight);
  final MadnGame g;
  final List<int> highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 11;
    Offset at((int, int) c) => Offset((c.$1 + 0.5) * u, (c.$2 + 0.5) * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 0.4)),
      Paint()..color = const Color(0xFFF3E3B8),
    );
    // Laufweg
    final path = Paint()
      ..color = const Color(0xFF6B4A2A)
      ..strokeWidth = u * 0.06;
    for (var i = 0; i < madnTrack.length; i++) {
      canvas.drawLine(at(madnTrack[i]), at(madnTrack[(i + 1) % madnTrack.length]), path);
    }
    void field((int, int) c, Color fill, {double r = 0.38}) {
      canvas.drawCircle(at(c), u * r, Paint()..color = fill);
      canvas.drawCircle(at(c), u * r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.05
        ..color = const Color(0xFF6B4A2A));
    }

    for (var i = 0; i < madnTrack.length; i++) {
      final start = i % 10 == 0 && i ~/ 10 < 4;
      field(madnTrack[i], start ? seatColors[i ~/ 10] : const Color(0xFFFFFBF0));
    }
    for (var s = 0; s < 4; s++) {
      final light = Color.lerp(seatColors[s], Colors.white, 0.55)!;
      for (final c in madnHomes[s]) {
        field(c, light);
      }
      for (final c in madnGoals[s]) {
        field(c, light);
      }
    }
    // Figuren
    for (var s = 0; s < g.players; s++) {
      for (var k = 0; k < 4; k++) {
        final c = at(madnCell(g, s, k));
        final hi = s == g.current && highlight.contains(k);
        if (hi) {
          canvas.drawCircle(c, u * 0.46, Paint()..color = const Color(0xCCFFE066));
        }
        canvas.drawCircle(c + Offset(u * 0.04, u * 0.06), u * 0.28, Paint()..color = Colors.black38);
        canvas.drawCircle(c, u * 0.28, Paint()..color = seatColors[s]);
        canvas.drawCircle(c - Offset(u * 0.08, u * 0.08), u * 0.09, Paint()..color = Colors.white54);
        canvas.drawCircle(c, u * 0.28, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.04
          ..color = Colors.black54);
      }
    }
    // Zielfeld des Zugs für hervorgehobene Figuren
    if (highlight.isNotEmpty && g.dice != null) {
      for (final k in highlight) {
        final t = g.target(k, g.dice!);
        if (t == null) continue;
        final cell = t >= MadnGame.goalStart ? madnGoals[g.current][t - MadnGame.goalStart] : madnTrack[g.absolute(g.current, t)];
        canvas.drawCircle(at(cell), u * 0.16, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.06
          ..color = const Color(0xFFE8B923));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
