import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'chess_board.dart';
import 'chess_engine.dart';

/// Eine Übung: Stellung, Aufgabe und die Züge, die sie lösen.
class ChessLesson {
  const ChessLesson(this.title, this.text, this.fen, {this.solutions = const [], this.mate = false, required this.done});
  final String title;
  final String text;
  final String fen;

  /// Züge in Langschreibweise wie e2e4.
  final List<String> solutions;

  /// Jedes Matt löst die Aufgabe.
  final bool mate;
  final String done;
}

const chessLessons = [
  ChessLesson(
    'Der Bauer',
    'Bauern ziehen geradeaus nach vorn, ein Feld weit. Beim allerersten Zug dürfen sie auch zwei Felder gehen. '
        'Tipp den weißen Bauern an und zieh ihn zwei Felder vor.',
    '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1',
    solutions: ['e2e4'],
    done: 'Genau! Zurück dürfen Bauern nie.',
  ),
  ChessLesson(
    'Bauern schlagen schräg',
    'Geradeaus schlagen Bauern nicht. Sie schlagen nur schräg nach vorn. Schlag den schwarzen Bauern.',
    '4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1',
    solutions: ['e4d5'],
    done: 'Richtig! Die geschlagene Figur verschwindet vom Brett.',
  ),
  ChessLesson(
    'Der Turm',
    'Der Turm zieht beliebig weit gerade: nach vorn, hinten oder zur Seite, aber nicht über andere Figuren. '
        'Schlag den schwarzen Turm.',
    'r3k3/8/8/8/8/8/8/R3K3 w - - 0 1',
    solutions: ['a1a8'],
    done: 'Sehr gut, und nebenbei steht der schwarze König jetzt im Schach.',
  ),
  ChessLesson(
    'Der Läufer',
    'Der Läufer zieht beliebig weit schräg und bleibt deshalb immer auf Feldern einer Farbe. Schlag den schwarzen Läufer.',
    '4k3/8/8/8/8/2b5/8/B3K3 w - - 0 1',
    solutions: ['a1c3'],
    done: 'Prima!',
  ),
  ChessLesson(
    'Die Dame',
    'Die Dame ist die stärkste Figur: Sie zieht wie Turm und Läufer zusammen. Schlag die schwarze Dame.',
    '4k3/8/8/8/q7/8/8/3QK3 w - - 0 1',
    solutions: ['d1a4'],
    done: 'Damentausch gewonnen!',
  ),
  ChessLesson(
    'Der Springer',
    'Der Springer springt wie ein L: zwei Felder in eine Richtung und eins zur Seite. Als einzige Figur darf er '
        'über andere hinweg. Schlag den schwarzen Bauern.',
    '4k3/8/8/8/8/5p2/8/4K1N1 w - - 0 1',
    solutions: ['g1f3'],
    done: 'Hopp, gesprungen!',
  ),
  ChessLesson(
    'Der König und die Rochade',
    'Der König zieht ein Feld in jede Richtung. Einmal pro Partie darf er mit einem Turm rochieren: Er geht zwei Felder '
        'zur Seite, der Turm springt über ihn. Das geht nur, wenn beide noch nie gezogen haben, nichts dazwischen steht '
        'und der König nicht durch ein angegriffenes Feld muss. Tipp den König an und zieh ihn zwei Felder nach rechts.',
    '4k3/8/8/8/8/8/8/4K2R w K - 0 1',
    solutions: ['e1g1'],
    done: 'Kurze Rochade! Der König steht jetzt sicher in der Ecke.',
  ),
  ChessLesson(
    'Schlagen im Vorbeigehen',
    'Zieht ein Bauer zwei Felder vor und landet neben deinem Bauern, darfst du ihn im nächsten Zug so schlagen, '
        'als wäre er nur ein Feld gegangen. Schwarz hat gerade d7 nach d5 gezogen. Schlag ihn en passant.',
    '4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1',
    solutions: ['e5d6'],
    done: 'Diese Regel kennen viele nicht, du jetzt schon!',
  ),
  ChessLesson(
    'Umwandlung',
    'Erreicht ein Bauer die letzte Reihe, wird er zu einer Dame, einem Turm, Läufer oder Springer. '
        'Zieh den Bauern nach vorn und mach eine Dame daraus.',
    '8/4P1k1/8/8/8/8/8/4K3 w - - 0 1',
    solutions: ['e7e8q'],
    done: 'Eine neue Dame!',
  ),
  ChessLesson(
    'Schach abwehren',
    'Wird dein König angegriffen, steht er im Schach. Dann musst du sofort etwas tun: ausweichen, dazwischenziehen '
        'oder den Angreifer schlagen. Hier geht das Schlagen. Schlag den Turm, der Schach gibt.',
    '4k3/R7/8/8/8/8/8/r3K3 w - - 0 1',
    solutions: ['a7a1'],
    done: 'Gefahr gebannt!',
  ),
  ChessLesson(
    'Schachmatt',
    'Kann der König dem Schach nicht mehr entkommen, ist er matt, und die Partie ist gewonnen. Setz den schwarzen '
        'König mit einem Zug matt. Kleiner Tipp: Die Bauern versperren ihm die Flucht.',
    '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
    mate: true,
    done: 'Grundreihenmatt! So endet manche echte Partie.',
  ),
  ChessLesson(
    'Matt mit der Dame',
    'Noch einmal: Finde das Matt in einem Zug. Dein König hilft mit.',
    'k7/8/1K6/8/8/8/8/7Q w - - 0 1',
    mate: true,
    done: 'Geschafft! Achtung: Hat der Gegner keinen Zug mehr, steht aber nicht im Schach, ist es Patt und nur ein Remis.',
  ),
];

class ChessTutorialScreen extends StatefulWidget {
  const ChessTutorialScreen({super.key});

  @override
  State<ChessTutorialScreen> createState() => _ChessTutorialScreenState();
}

class _ChessTutorialScreenState extends State<ChessTutorialScreen> {
  int _index = 0;
  late ChessGame _g = ChessGame.fromFen(chessLessons[0].fen);
  int? _selected;
  List<ChessMove> _targets = [];
  bool _solved = false;
  String _feedback = '';
  Set<int> _marks = {};

  ChessLesson get _lesson => chessLessons[_index];

  void _load(int i) {
    setState(() {
      _index = i;
      _g = ChessGame.fromFen(chessLessons[i].fen);
      _selected = null;
      _targets = [];
      _solved = false;
      _feedback = '';
      _marks = {};
    });
  }

  void _tap(int sq) {
    if (_solved) return;
    final hits = _targets.where((m) => m.to == sq).toList();
    if (_selected != null && hits.isNotEmpty) {
      _choose(hits);
      return;
    }
    final p = _g.board[sq];
    setState(() {
      if (p != 0 && p.sign == _g.side) {
        _selected = sq;
        _targets = _g.movesFrom(sq);
      } else {
        _selected = null;
        _targets = [];
      }
    });
  }

  Future<void> _choose(List<ChessMove> hits) async {
    var m = hits.first;
    if (hits.length > 1) {
      const order = [queen, rook, bishop, knight];
      final i = await showChoiceSheet(
        context,
        title: 'Bauer wird zu …',
        options: const ['Dame', 'Turm', 'Läufer', 'Springer'],
      );
      if (i == null || !mounted) return;
      m = hits.firstWhere((h) => h.promo == order[i]);
    }
    _g.make(m);
    final ok = _lesson.mate
        ? _g.result == ChessResult.whiteMates
        : _lesson.solutions.contains(m.uci);
    final sfx = AppScope.of(context).sfx;
    if (ok) {
      sfx.play(Sound.win);
      setState(() {
        _solved = true;
        _selected = null;
        _targets = [];
        _marks = {};
        _feedback = _lesson.done;
      });
      return;
    }
    // Falscher Zug: zurücknehmen und das Startfeld der Lösung zeigen
    _g.unmake();
    sfx.play(Sound.lose);
    setState(() {
      _selected = null;
      _targets = [];
      _feedback = _lesson.mate ? 'Das ist noch kein Matt. Versuch es noch einmal.' : 'Nicht ganz. Die markierte Figur ist dran.';
      if (_lesson.solutions.isNotEmpty) _marks = {squareFromName(_lesson.solutions.first.substring(0, 2))};
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final last = _index == chessLessons.length - 1;
    return GameFrame(
      title: 'Schach lernen',
      background: const BoxDecoration(color: Color(0xFF2A1A12)),
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight * 1.2;
          final board = Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: ChessBoardView(
                game: _g,
                selected: _selected,
                targets: {for (final m in _targets) m.to},
                marks: _marks,
                onTap: _tap,
              ),
            ),
          );
          final panel = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Übung ${_index + 1} von ${chessLessons.length}: ${_lesson.title}',
                style: TextStyle(color: const Color(0xFFFFC95C), fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(_lesson.text, style: TextStyle(color: p.onFelt, fontSize: 15, height: 1.3)),
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback,
                  style: TextStyle(
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
                Expanded(child: board),
                SizedBox(
                  width: (box.maxWidth * 0.4).clamp(240.0, 420.0),
                  child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: panel),
                ),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: board),
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
