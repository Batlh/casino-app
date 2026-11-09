import 'package:flutter/material.dart';

import '../../../ui/guide.dart';
import '../mahjong_tutorial.dart';
import '../tiles.dart';
import 'am_screen.dart';

Widget _row(List<int> tiles) => Wrap(
      spacing: 2,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [for (final t in tiles) t < 0 ? const SizedBox(width: 12) : TileView(tile: t, width: 24)],
    );

const amLessons = [
  QuizLesson(
    title: 'Die Karte',
    text: 'Beim American Mahjong gewinnst du nur mit einer Hand, die genau auf der Karte steht. Unsere Glückskarte hat 24 Hände '
        'in Gruppen wie 2468, Folgen, Gleiche Zahlen oder Winde und Drachen. Tippe im Spiel auf „Karte“, um sie zu sehen.',
    tiles: [10, 10, 10, 12, 12, 12, 12, 14, 14, 14, 16, 16, 16, 16],
    question: 'Zu welcher Kartengruppe passt diese Hand?',
    textOptions: ['13579', '2468', 'Folgen'],
    correct: 1,
    explain: 'Richtig: 222 4444 666 8888 in einer Farbe. Das sind 25 Punkte.',
  ),
  QuizLesson(
    title: 'Joker',
    text: 'Acht Joker ersetzen jeden Stein, aber nur in Gruppen ab drei gleichen Steinen: Pung, Kong oder Fünfling. '
        'In Paaren und einzelnen Steinen sind Joker verboten. Einen Fünfling schaffst du nur mit Joker.',
    tiles: [10, 10, 46, -1, 33, 33],
    question: 'Darf ein Joker ein Paar vervollständigen?',
    textOptions: ['Ja', 'Nein'],
    correct: 1,
    explain: 'Genau, nur Gruppen ab drei Steinen. Eine Hand ganz ohne Joker zählt doppelt.',
  ),
  QuizLesson(
    title: 'Charleston',
    text: 'Vor dem Spiel tauschen alle dreimal je drei Steine: erst nach rechts, dann über den Tisch, dann nach links. '
        'Joker gibt man nicht weg. Behalte, was zu einer Kartenhand passt.',
    question: 'In welche Richtung geht der erste Tausch?',
    textOptions: ['Nach links', 'Nach rechts', 'Über den Tisch'],
    correct: 1,
    explain: 'Richtig. Danach über den Tisch und zum Schluss nach links.',
  ),
  QuizLesson(
    title: 'Aufdecken',
    text: 'Chi gibt es nicht. Einen fremden Abwurf darfst du nur nehmen, um eine Gruppe ab drei Steinen für deine Kartenhand '
        'aufzudecken, oder für Mahjong. Hände mit C auf der Karte müssen verdeckt bleiben.',
    question: 'Darfst du einen Abwurf für ein Paar nehmen?',
    textOptions: ['Ja, immer', 'Nur für Mahjong', 'Nie'],
    correct: 1,
    explain: 'Genau. Für ein Paar oder einen einzelnen Stein geht das nur mit dem letzten Stein zum Mahjong.',
  ),
  QuizLesson(
    title: 'Joker holen',
    text: 'Liegt in einer aufgedeckten Gruppe ein Joker und du hast den echten Stein, darfst du am Zug tauschen: '
        'Du legst den echten Stein hin und nimmst den Joker auf die Hand.',
    tiles: [12, 12, 46, -1, 12],
    question: 'Was bekommst du für deine 4 Kreise?',
    textOptions: ['Den Joker', 'Nichts', 'Einen neuen Stein von der Mauer'],
    correct: 0,
    explain: 'Richtig. Joker sind das Wertvollste im Spiel.',
  ),
];

final amGuide = GameGuide(
  'American Mahjong',
  [
    GuideSection(
      'Ziel',
      'Amerikanische Spielweise mit 152 Steinen: alle Farben, Winde, Drachen, acht Blumen und acht Joker. '
          'Gewonnen wird nur mit einer Hand von der Karte. Die echte Jahreskarte des US-Verbands ist geschützt, '
          'deshalb spielen wir mit einer eigenen Glückskarte im selben Stil.',
      picture: (_) => _row(const [46, 46, -1, 34, 35, -1, 10, 12, 14, 16]),
    ),
    const GuideSection(
      'Charleston',
      'Zu Beginn gibst du dreimal drei Steine weiter: nach rechts, über den Tisch, nach links. Tippe die Steine an oder nimm den '
          'Vorschlag. Joker bleiben bei dir.',
    ),
    const GuideSection(
      'Ein Zug',
      'Ziehen, dann einen Stein abwerfen (zweimal antippen). Auf einen fremden Abwurf darfst du nur einen Pung, Kong oder Fünfling '
          'für eine Kartenhand aufdecken oder Mahjong rufen. Mit „Joker holen“ tauschst du einen echten Stein gegen einen Joker '
          'aus einer aufgedeckten Gruppe.',
    ),
    const GuideSection(
      'Die Karte lesen',
      'Gleiche Schriftfarbe heißt gleiche Mahjong-Farbe, verschiedene Schriftfarben heißen verschiedene. n ist eine Zahl deiner Wahl, '
          'n+1 die nächste. D ist der Drache der Farbe: Zeichen rot, Kreise weiß, Bambus grün. 0 ist der Weiße Drache, F eine Blume. '
          'X heißt aufdecken erlaubt, C nur verdeckt.',
    ),
    const GuideSection(
      'Punkte und Münzen',
      'Jede Kartenhand hat einen Wert von 25 bis 50, ohne Joker doppelt. Bei einem Abwurf zahlt der Werfende doppelt, die anderen '
          'einfach. Selbst gezogen zahlen alle doppelt. Gespielt werden vier Hände. Ein eigener Sieg bringt 20 Münzen plus das '
          'Doppelte des Werts, am Ende 300, 120 oder 40 Münzen für Platz 1 bis 3.',
    ),
  ],
  tutorial: (_) => const QuizTutorialScreen(title: 'American Mahjong lernen', lessons: amLessons),
  tutorialLabel: 'Übungen starten',
);

Widget amScreen() => AmScreen(guide: amGuide);
