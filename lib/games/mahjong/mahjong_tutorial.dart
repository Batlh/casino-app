import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import 'tiles.dart';

/// Eine Übung mit Frage. Antworten sind Steine oder Texte.
class QuizLesson {
  const QuizLesson({
    required this.title,
    required this.text,
    this.tiles = const [],
    this.picture,
    required this.question,
    this.tileOptions = const [],
    this.textOptions = const [],
    required this.correct,
    required this.explain,
  });

  final String title;
  final String text;

  /// Steine zur Anschauung, -1 macht eine Lücke.
  final List<int> tiles;
  final WidgetBuilder? picture;
  final String question;
  final List<int> tileOptions;
  final List<String> textOptions;
  final int correct;
  final String explain;
}

/// Kleiner Turm aus Steinen: (x, y, Ebene, Stein). Ein Stein ist zwei Einheiten breit.
Widget _stack(List<(int, int, int, int)> tiles, {double unit = 22}) {
  const aspect = TileView.aspect;
  var maxX = 0;
  var maxY = 0;
  for (final t in tiles) {
    if (t.$1 > maxX) maxX = t.$1;
    if (t.$2 > maxY) maxY = t.$2;
  }
  final dz = unit * 0.35;
  return SizedBox(
    width: (maxX + 2) * unit + 3 * dz,
    height: (maxY + 2) * unit / aspect + 3 * dz,
    child: Stack(
      children: [
        for (final t in [...tiles]..sort((a, b) => a.$3 != b.$3 ? a.$3 - b.$3 : a.$1 - b.$1))
          Positioned(
            left: t.$1 * unit - t.$3 * dz + 2 * dz,
            top: t.$2 * unit / aspect - t.$3 * dz + 2 * dz,
            child: TileView(tile: t.$4, width: unit * 2 - 1, depth: unit * 0.25),
          ),
      ],
    ),
  );
}

final riichiLessons = <QuizLesson>[
  const QuizLesson(
    title: 'Die Steine',
    text: 'Es gibt drei Farben mit den Zahlen 1 bis 9: Zeichen (rote Schrift 萬), Kreise und Bambus. Dazu kommen die '
        'Ehrensteine: vier Winde (Ost 東, Süd 南, West 西, Nord 北) und drei Drachen (Weiß, Grün 發, Rot 中). '
        'Jeden Stein gibt es viermal, zusammen 136 Steine.',
    tiles: [0, 4, 8, 9, 13, 17, 18, 22, 26, 27, 31, 32, 33],
    question: 'Welcher Stein ist die 3 Kreise?',
    tileOptions: [2, 11, 20, 12],
    correct: 1,
    explain: 'Richtig: Kreise erkennst du an den runden Münzen. Bambus hat grüne Stäbchen, Zeichen das rote 萬.',
  ),
  const QuizLesson(
    title: 'Gruppen',
    text: 'Eine fertige Hand hat 14 Steine: vier Gruppen und ein Paar. Eine Gruppe ist entweder eine Folge aus drei '
        'aufeinanderfolgenden Zahlen derselben Farbe (Chi) oder drei gleiche Steine (Pon).',
    tiles: [3, 4, -1, 22, 22, 22],
    question: 'Welcher Stein ergänzt 4 und 5 Zeichen zu einer Folge?',
    tileOptions: [5, 14, 23, 6],
    correct: 0,
    explain: 'Genau, 4-5-6 Zeichen. Folgen gehen nur innerhalb einer Farbe und nicht mit Ehrensteinen.',
  ),
  const QuizLesson(
    title: 'Fertig machen',
    text: 'Diese Hand hat 13 Steine und braucht nur noch einen: Sie ist Tenpai. Kommt der fehlende Stein durch eigenes '
        'Ziehen, sagst du Tsumo; wirft ihn ein anderer ab, sagst du Ron.',
    tiles: [0, 1, 2, 12, 13, 14, 19, 20, 21, 27, 27, 27, 33],
    question: 'Auf welchen Stein wartet die Hand?',
    tileOptions: [3, 33, 27, 22],
    correct: 1,
    explain: 'Der Rote Drache bildet mit dem einzelnen Roten Drachen das Paar. Dann sind es vier Gruppen und ein Paar.',
  ),
  const QuizLesson(
    title: 'Abwerfen',
    text: 'Am Zug ziehst du einen Stein und wirfst einen ab. Wirf ab, was am wenigsten zu deiner Hand passt, '
        'meist einzelne Ehrensteine oder einzelne Randsteine.',
    tiles: [1, 2, 3, 10, 11, 12, 13, 19, 20, 22, 23, 24, 24, 29],
    question: 'Welchen Stein wirfst du am besten ab?',
    tileOptions: [29, 13, 24, 1],
    correct: 0,
    explain: 'Der einzelne Westwind passt zu nichts. Die anderen Steine gehören zu Folgen oder zum Paar.',
  ),
  const QuizLesson(
    title: 'Ohne Yaku kein Sieg',
    text: 'Zum Gewinnen braucht die Hand mindestens ein Yaku, ein Wertungsmuster. Leicht zu bekommen sind: Riichi '
        '(geschlossene Hand ansagen), Menzen Tsumo (geschlossen selbst gezogen), Tanyao (nur Steine 2 bis 8) und '
        'Yakuhai (Drilling aus Drachen oder dem eigenen Wind). Dora-Steine bringen extra Punkte, zählen aber nicht als Yaku.',
    tiles: [1, 2, 3, 13, 14, 15, 21, 22, 23, 4, 4, 4, 6, 6],
    question: 'Welches Yaku hat diese Hand sicher, auch wenn sie offen ist?',
    textOptions: ['Tanyao: nur Steine 2 bis 8', 'Yakuhai: Drachen-Drilling', 'Reine Farbe', 'Kein Yaku'],
    correct: 0,
    explain: 'Alle Steine liegen zwischen 2 und 8, das ist Tanyao. Bei uns darf Tanyao auch offen gespielt werden.',
  ),
  const QuizLesson(
    title: 'Riichi',
    text: 'Ist deine Hand geschlossen (kein Pon, Chi oder offener Kan) und Tenpai, kannst du Riichi sagen: Du setzt '
        '1.000 Punkte und darfst die Hand danach nicht mehr ändern. Dafür ist Riichi ein Yaku, und gewinnst du sofort, '
        'gibt es Ippatsu obendrauf.',
    question: 'Wann darfst du Riichi sagen?',
    textOptions: [
      'Mit geschlossener Hand, die nur noch einen Stein braucht',
      'Immer, wenn ich will',
      'Nur nach einem Pon',
      'Erst ganz am Ende',
    ],
    correct: 0,
    explain: 'Genau. Im Spiel erscheint der Riichi-Knopf von selbst, sobald es geht.',
  ),
  const QuizLesson(
    title: 'Furiten',
    text: 'Vorsicht: Hast du selbst einen Stein abgeworfen, auf den deine Hand jetzt wartet, darfst du nicht mit Ron '
        'gewinnen, nur mit Tsumo. Das heißt Furiten. Auch wer ein Ron auslässt, ist bis zum nächsten eigenen Abwurf gesperrt.',
    question: 'Du wartest auf 3 oder 6 Bambus und hast früher 6 Bambus abgeworfen. Ein Gegner wirft 3 Bambus ab. Darfst du Ron sagen?',
    textOptions: ['Nein, ich bin Furiten', 'Ja, 3 Bambus ist ja nicht abgeworfen'],
    correct: 0,
    explain: 'Richtig. Furiten gilt für alle Wartesteine, sobald einer davon in deinen Abwürfen liegt.',
  ),
];

final solitaireLessons = <QuizLesson>[
  QuizLesson(
    title: 'Paare abräumen',
    text: 'Beim Mahjong Solitär räumst du immer zwei gleiche Steine ab, bis das Brett leer ist. '
        'Blumen passen zu jeder Blume, Jahreszeiten zu jeder Jahreszeit.',
    picture: (_) => _stack([(0, 0, 0, 34), (2, 0, 0, 13), (4, 0, 0, 37), (6, 0, 0, 13)], unit: 20),
    question: 'Welcher Stein passt zur Blume ganz links?',
    tileOptions: const [13, 37, 31],
    correct: 1,
    explain: 'Richtig, zwei Blumen sind immer ein Paar, auch wenn das Bild verschieden ist.',
  ),
  QuizLesson(
    title: 'Freie Steine',
    text: 'Abräumen darfst du nur freie Steine: Nichts liegt darauf, und links oder rechts ist mindestens eine Seite frei. '
        'Steine, die gerade nicht frei sind, zeigt das Spiel etwas dunkler.',
    picture: (_) => _stack([(0, 0, 0, 4), (2, 0, 0, 22), (4, 0, 0, 4), (2, 0, 1, 31)], unit: 22),
    question: 'Welcher Stein ist hier NICHT frei?',
    tileOptions: const [4, 22, 31],
    correct: 1,
    explain: 'Der Bambus in der Mitte hat links und rechts Nachbarn und den Weißen Drachen obendrauf.',
  ),
  const QuizLesson(
    title: 'Planen',
    text: 'Räum zuerst Steine ab, die andere blockieren: hohe Türme und lange Reihen. Wenn alle vier gleichen Steine '
        'frei sind, nimm sie gleich alle weg. Hilfe gibt der Tipp-Knopf, festgefahren hilft Mischen; beides kostet ein '
        'paar Münzen vom Gewinn.',
    question: 'Womit fängst du am besten an?',
    textOptions: ['Mit dem Stein ganz oben auf dem Turm', 'Mit einem Stein am Rand, der nichts blockiert', 'Egal'],
    correct: 0,
    explain: 'Genau, der oberste Stein blockiert gleich vier andere.',
  ),
];

class QuizTutorialScreen extends StatefulWidget {
  const QuizTutorialScreen({super.key, required this.title, required this.lessons});
  final String title;
  final List<QuizLesson> lessons;

  @override
  State<QuizTutorialScreen> createState() => _QuizTutorialScreenState();
}

class _QuizTutorialScreenState extends State<QuizTutorialScreen> {
  int _index = 0;
  int? _answer;

  QuizLesson get _l => widget.lessons[_index];
  bool get _solved => _answer == _l.correct;

  void _pick(int i) {
    if (_solved) return;
    AppScope.of(context).sfx.play(i == _l.correct ? Sound.win : Sound.lose);
    setState(() => _answer = i);
  }

  void _go(int i) => setState(() {
        _index = i;
        _answer = null;
      });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final last = _index == widget.lessons.length - 1;
    final style = TextStyle(color: p.onFelt, fontSize: 15, height: 1.3);
    return GameFrame(
      title: widget.title,
      background: const BoxDecoration(
        gradient: RadialGradient(radius: 1.2, colors: [Color(0xFF1F6B52), Color(0xFF0C2B21)]),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text(
                'Übung ${_index + 1} von ${widget.lessons.length}: ${_l.title}',
                style: const TextStyle(color: Color(0xFFFFC95C), fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_l.text, style: style),
              if (_l.tiles.isNotEmpty) ...[
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final t in _l.tiles)
                        t < 0
                            ? const SizedBox(width: 16)
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: TileView(tile: t, width: 40, depth: 3),
                              ),
                    ],
                  ),
                ),
              ],
              if (_l.picture != null) ...[
                const SizedBox(height: 10),
                Center(child: _l.picture!(context)),
              ],
              const SizedBox(height: 14),
              Text(_l.question, style: style.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (_l.tileOptions.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < _l.tileOptions.length; i++)
                      GestureDetector(
                        onTap: () => _pick(i),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _answer == i
                                ? (i == _l.correct ? const Color(0xAA2E7D32) : const Color(0xAAC62828))
                                : Colors.transparent,
                          ),
                          child: TileView(tile: _l.tileOptions[i], width: 50, depth: 4),
                        ),
                      ),
                  ],
                ),
              for (var i = 0; i < _l.textOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _answer == i
                          ? (i == _l.correct ? const Color(0xFF2E7D32) : const Color(0xFFC62828))
                          : p.panel,
                      foregroundColor: p.ink,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => _pick(i),
                    child: Text(_l.textOptions[i], textAlign: TextAlign.center),
                  ),
                ),
              if (_answer != null) ...[
                const SizedBox(height: 8),
                Text(
                  _solved ? _l.explain : 'Nicht ganz, versuch es noch einmal.',
                  style: style.copyWith(
                    color: _solved ? const Color(0xFF9EF0C0) : const Color(0xFFFF8A80),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (_index > 0) ActionButton(label: 'Zurück', onPressed: () => _go(_index - 1)),
                  if (_solved && !last) ActionButton(primary: true, label: 'Weiter', onPressed: () => _go(_index + 1)),
                  if (_solved && last)
                    ActionButton(primary: true, label: 'Fertig', onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
