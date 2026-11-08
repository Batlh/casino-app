import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'shogi_board.dart';
import 'shogi_engine.dart';

class ShogiLesson {
  const ShogiLesson(this.title, this.text, this.sfen,
      {this.solutions = const [], this.anyDrop = false, this.mate = false, required this.done});
  final String title;
  final String text;
  final String sfen;

  /// Züge in USI-Schreibweise wie 7g7f oder P*5e.
  final List<String> solutions;
  final bool anyDrop;
  final bool mate;
  final String done;
}

const shogiLessons = [
  ShogiLesson(
    'Der Bauer 歩',
    'Shogi spielt man auf 9 mal 9 Feldern. Deine Steine zeigen nach oben, die des Gegners nach unten; Farben gibt es nicht. '
        'Der Bauer zieht genau ein Feld geradeaus und schlägt auch geradeaus. Zieh ihn ein Feld vor.',
    '4k4/9/9/9/9/9/4P4/9/4K4 b - 1',
    solutions: ['5g5f'],
    done: 'Gut! Anders als im Schach schlägt der Shogi-Bauer nicht schräg.',
  ),
  ShogiLesson(
    'Die Lanze 香',
    'Die Lanze zieht beliebig weit geradeaus nach vorn, aber nie zurück oder zur Seite. Schlag den Bauern ganz oben.',
    '4k4/p8/9/9/9/9/9/9/L3K4 b - 1',
    solutions: ['9i9b', '9i9b+'],
    done: 'Getroffen! Geschlagene Steine wandern in deine Hand.',
  ),
  ShogiLesson(
    'Der Springer 桂',
    'Der Springer springt nur nach vorn: zwei Felder vor und eins zur Seite, auch über andere Steine. Schlag den Bauern.',
    '4k4/9/9/9/9/2p6/9/1N7/4K4 b - 1',
    solutions: ['8h7f'],
    done: 'Gesprungen! Rückwärts oder seitlich kann der Springer nicht.',
  ),
  ShogiLesson(
    'Der Silbergeneral 銀',
    'Der Silbergeneral zieht ein Feld nach vorn oder schräg, nach hinten nur schräg. Schlag den Bauern schräg vor ihm.',
    '4k4/9/9/9/9/9/5p3/4S4/4K4 b - 1',
    solutions: ['5h4g'],
    done: 'Sehr gut!',
  ),
  ShogiLesson(
    'Der Goldgeneral 金',
    'Der Goldgeneral zieht ein Feld in jede Richtung, nur nicht schräg nach hinten. Schlag den Bauern neben ihm.',
    '4k4/9/9/9/9/9/9/3pG4/4K4 b - 1',
    solutions: ['5h6h'],
    done: 'Gold ist der beste Beschützer deines Königs.',
  ),
  ShogiLesson(
    'Läufer 角 und Turm 飛',
    'Läufer ziehen beliebig weit schräg, Türme beliebig weit gerade, genau wie im Schach. Schlag den Bauern mit dem Läufer.',
    '4k4/9/9/9/4p4/9/9/1B5R1/4K4 b - 1',
    solutions: ['8h5e'],
    done: 'Treffer!',
  ),
  ShogiLesson(
    'Beförderung',
    'Die obersten drei Reihen sind die gegnerische Zone. Zieht ein Stein hinein, heraus oder darin, darf er befördert werden '
        'und wird umgedreht: rot beschriftet und meist stärker. Bauer, Lanze, Springer und Silber ziehen dann wie Gold, '
        'Läufer und Turm bekommen zusätzlich die Schritte des Königs. Zieh den Bauern vor und befördere ihn.',
    '4k4/9/9/4P4/9/9/9/9/4K4 b - 1',
    solutions: ['5d5c+'],
    done: 'Aus dem Bauern wurde ein Tokin と, der zieht wie Gold.',
  ),
  ShogiLesson(
    'Einsetzen',
    'Das Besondere am Shogi: Geschlagene Steine gehören dir. Statt zu ziehen, darfst du einen Stein aus deiner Hand auf '
        'ein freies Feld setzen. Tipp den Bauern unter dem Brett an und setz ihn auf das markierte Feld 5e.',
    '4k4/9/9/9/9/9/9/9/4K4 b P 1',
    solutions: ['P*5e'],
    done: 'Eingesetzt! Er kommt immer unbefördert aufs Brett.',
  ),
  ShogiLesson(
    'Kein zweiter Bauer',
    'Zwei eigene unbeförderte Bauern dürfen nie in derselben Linie stehen (Nifu). Die Linie 5 ist deshalb gesperrt. '
        'Setz den Bauern aus der Hand in irgendeine andere Linie.',
    '4k4/9/9/9/9/9/4P4/9/4K4 b P 1',
    anyDrop: true,
    done: 'Richtig. Außerdem darf ein eingesetzter Bauer nicht sofort mattsetzen.',
  ),
  ShogiLesson(
    'Matt mit Gold',
    'Gewonnen hat, wer den gegnerischen König mattsetzt. Setz den Goldgeneral aus deiner Hand so ein, dass der König nicht '
        'mehr entkommt. Dein Bauer schützt ihn.',
    '4k4/9/4P4/9/9/9/9/9/4K4 b G 1',
    mate: true,
    done: 'Kopf-Gold! Das berühmteste Matt im Shogi.',
  ),
];

class ShogiTutorialScreen extends StatefulWidget {
  const ShogiTutorialScreen({super.key});

  @override
  State<ShogiTutorialScreen> createState() => _ShogiTutorialScreenState();
}

class _ShogiTutorialScreenState extends State<ShogiTutorialScreen> {
  int _index = 0;
  late ShogiGame _g = ShogiGame.fromSfen(shogiLessons[0].sfen);
  int? _selected;
  int? _dropType;
  List<ShogiMove> _targets = [];
  bool _solved = false;
  String _feedback = '';
  Set<int> _marks = {};

  ShogiLesson get _lesson => shogiLessons[_index];

  void _load(int i) {
    setState(() {
      _index = i;
      _g = ShogiGame.fromSfen(shogiLessons[i].sfen);
      _selected = null;
      _dropType = null;
      _targets = [];
      _solved = false;
      _feedback = '';
      _marks = shogiLessons[i].solutions.isNotEmpty && shogiLessons[i].solutions.first.contains('*')
          ? {shogiSquareFromName(shogiLessons[i].solutions.first.substring(2))}
          : {};
    });
  }

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  void _tapBoard(int sq) {
    if (_solved) return;
    final hits = _targets.where((m) => m.to == sq).toList();
    if (hits.isNotEmpty) {
      _choose(hits);
      return;
    }
    final p = _g.board[sq];
    setState(() {
      _dropType = null;
      if (p != 0 && p.sign == _g.side) {
        _selected = sq;
        _targets = _g.movesFrom(sq);
      } else {
        _selected = null;
        _targets = [];
      }
    });
  }

  void _tapHand(int t) {
    if (_solved) return;
    setState(() {
      _selected = null;
      _dropType = t;
      _targets = _g.dropsOf(t);
    });
  }

  Future<void> _choose(List<ShogiMove> hits) async {
    var m = hits.first;
    if (hits.length > 1) {
      final t = _g.board[m.from].abs();
      final i = await showChoiceSheet(
        context,
        title: '${shogiPieceName(t)} befördern?',
        options: ['Ja, zu ${shogiPieceName(t + promoted)}', 'Nein, so lassen'],
      );
      if (i == null || !mounted) return;
      m = hits.firstWhere((h) => h.promote == (i == 0));
    }
    _g.make(m);
    final l = _lesson;
    final ok = l.mate
        ? _g.result == ShogiResult.senteWins
        : l.anyDrop
            ? m.isDrop
            : l.solutions.contains(m.usi);
    final sfx = AppScope.of(context).sfx;
    if (ok) {
      sfx.play(Sound.win);
      setState(() {
        _solved = true;
        _selected = null;
        _dropType = null;
        _targets = [];
        _marks = {};
        _feedback = l.done;
      });
      return;
    }
    _g.unmake();
    sfx.play(Sound.lose);
    setState(() {
      _selected = null;
      _dropType = null;
      _targets = [];
      _feedback = l.mate ? 'Das ist noch kein Matt. Versuch es noch einmal.' : 'Nicht ganz. Lies die Aufgabe noch einmal.';
      if (l.solutions.isNotEmpty && !l.solutions.first.contains('*')) {
        _marks = {shogiSquareFromName(l.solutions.first.substring(0, 2))};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final last = _index == shogiLessons.length - 1;
    return GameFrame(
      title: 'Shogi lernen',
      background: const BoxDecoration(color: Color(0xFF3A2116)),
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight * 1.2;
          final boardBlock = Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ShogiBoardView(
                      game: _g,
                      selected: _selected,
                      targets: {for (final m in _targets) m.to},
                      marks: _marks,
                      onTap: _tapBoard,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ShogiHandView(hand: _g.hand(sente), color: sente, size: 38, selected: _dropType, onTap: _tapHand),
                ],
              ),
            ),
          );
          final panel = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Übung ${_index + 1} von ${shogiLessons.length}: ${_lesson.title}',
                style: const TextStyle(
                  fontFamilyFallback: [kanjiFont],
                  color: Color(0xFFFFC95C),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _lesson.text,
                style: TextStyle(fontFamilyFallback: const [kanjiFont], color: p.onFelt, fontSize: 15, height: 1.3),
              ),
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback,
                  style: TextStyle(
                    fontFamilyFallback: const [kanjiFont],
                    color: _solved ? const Color(0xFF7CE0A8) : const Color(0xFFFF8A80),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_index > 0) ActionButton(label: 'Zurück', onPressed: () => _load(_index - 1)),
                  ActionButton(label: 'Nochmal', onPressed: () => _load(_index)),
                  if (_solved && !last) ActionButton(primary: true, label: 'Weiter', onPressed: () => _load(_index + 1)),
                  if (_solved && last)
                    ActionButton(primary: true, label: 'Fertig', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ],
          );
          if (landscape) {
            return Row(
              children: [
                Expanded(child: boardBlock),
                SizedBox(
                  width: (box.maxWidth * 0.4).clamp(240.0, 420.0),
                  child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: panel),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: boardBlock),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: panel),
              ),
            ],
          );
        },
      ),
    );
  }
}
