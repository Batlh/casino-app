import 'package:flutter/material.dart';

import 'garten_art.dart';
import 'kosmos_art.dart';
import 'slot_data.dart';
import 'slot_engine.dart';
import 'tiefsee_art.dart';

/// Ein Slot: Regeln plus eigene Grafik und Texte.
class SlotGame {
  const SlotGame({
    required this.name,
    required this.blurb,
    required this.rules,
    required this.stakes,
    required this.symbolNames,
    required this.paintSymbol,
    required this.paintBackdrop,
    required this.background,
    required this.frame,
    required this.lobbyColor,
    required this.featureText,
    required this.wildText,
    this.freeSpinLine = '',
  });

  final String name;
  final String blurb;
  final SlotRules rules;
  final List<int> stakes;
  final List<String> symbolNames;
  final void Function(Canvas canvas, Rect rect, int symbol) paintSymbol;
  final void Function(Canvas canvas, Rect rect, double time) paintBackdrop;
  final BoxDecoration background;
  final List<Color> frame;
  final Color lobbyColor;
  final String featureText;
  final String wildText;
  final String freeSpinLine;
}

const _lines10 = <List<int>>[
  [1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0],
  [2, 2, 2, 2, 2],
  [0, 1, 2, 1, 0],
  [2, 1, 0, 1, 2],
  [0, 0, 1, 2, 2],
  [2, 2, 1, 0, 0],
  [1, 0, 0, 0, 1],
  [1, 2, 2, 2, 1],
  [1, 0, 1, 2, 1],
];

const _lines20 = <List<int>>[
  [1, 1, 1, 1, 1],
  [2, 2, 2, 2, 2],
  [0, 0, 0, 0, 0],
  [3, 3, 3, 3, 3],
  [0, 1, 2, 1, 0],
  [3, 2, 1, 2, 3],
  [1, 2, 3, 2, 1],
  [2, 1, 0, 1, 2],
  [0, 1, 0, 1, 0],
  [3, 2, 3, 2, 3],
  [1, 0, 1, 0, 1],
  [2, 3, 2, 3, 2],
  [0, 0, 1, 2, 3],
  [3, 3, 2, 1, 0],
  [1, 1, 2, 3, 3],
  [2, 2, 1, 0, 0],
  [0, 1, 1, 1, 0],
  [3, 2, 2, 2, 3],
  [1, 2, 2, 2, 1],
  [2, 1, 1, 1, 2],
];

const _lines5 = <List<int>>[
  [1, 1, 1],
  [0, 0, 0],
  [2, 2, 2],
  [0, 1, 2],
  [2, 1, 0],
];

const kosmos78 = SlotGame(
  name: 'Kosmos 78',
  blurb: 'Fünf Walzen, zehn Linien und Freispiele',
  rules: SlotRules(
    rows: 3,
    lines: _lines10,
    strips: kosmosStrips,
    linePays: {
      0: [3, 8, 25],
      1: [4, 10, 30],
      2: [5, 15, 50],
      3: [8, 25, 100],
      4: [12, 50, 200],
      5: [20, 100, 500],
      6: [50, 250, 1000],
    },
    scatterPays: [2, 5, 20],
    freeSpins: 8,
    freeMultiplier: 2,
  ),
  stakes: [10, 20, 50, 100, 200, 500],
  symbolNames: [
    'Mond',
    'Stern',
    'Komet',
    'Planet',
    'Ufo',
    'Rakete',
    'Sonne',
    'Schwarzes Loch',
  ],
  paintSymbol: paintKosmosSymbol,
  paintBackdrop: paintKosmosBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF120A33), Color(0xFF3A1467), Color(0xFFA32A6E)],
    ),
  ),
  frame: [Color(0xFFFFD98A), Color(0xFFC4391F), Color(0xFF5A1B6E)],
  lobbyColor: Color(0xFF2B1B5A),
  featureText:
      'Drei oder mehr Schwarze Löcher zahlen das 2-, 5- oder 20-Fache des Einsatzes und starten 8 Freispiele. In Freispielen zählt jeder Gewinn doppelt.',
  wildText: 'Die Sonne ersetzt jedes Symbol außer dem Schwarzen Loch.',
  freeSpinLine: 'Freispiel, alle Gewinne doppelt',
);

const tiefsee = SlotGame(
  name: 'Tiefsee',
  blurb: 'Vier Reihen und leuchtende Quallen',
  rules: SlotRules(
    rows: 4,
    lines: _lines20,
    strips: tiefseeStrips,
    linePays: {
      0: [5, 10, 25],
      1: [5, 15, 40],
      2: [8, 20, 60],
      3: [10, 30, 100],
      4: [15, 60, 200],
      5: [25, 100, 500],
      6: [30, 150, 750],
    },
    scatterPays: [2, 6, 25],
    freeSpins: 10,
    expandWildInFree: true,
  ),
  stakes: [20, 40, 100, 200, 400, 1000],
  symbolNames: [
    'Seestern',
    'Muschel',
    'Seepferdchen',
    'Kugelfisch',
    'Krake',
    'Anglerfisch',
    'Qualle',
    'Perle',
  ],
  paintSymbol: paintTiefseeSymbol,
  paintBackdrop: paintTiefseeBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0C5A73), Color(0xFF062B45), Color(0xFF020B1C)],
    ),
  ),
  frame: [Color(0xFF7DF7D9), Color(0xFF137C8A), Color(0xFF3A1467)],
  lobbyColor: Color(0xFF062B45),
  featureText:
      'Drei oder mehr Perlen zahlen das 2-, 6- oder 25-Fache des Einsatzes und starten 10 Freispiele. In Freispielen füllt eine Qualle auf den drei mittleren Walzen die ganze Walze.',
  wildText: 'Die Qualle ersetzt jedes Symbol außer der Perle.',
  freeSpinLine: 'Freispiel, Quallen füllen die Walze',
);

const schrebergarten = SlotGame(
  name: 'Schrebergarten',
  blurb: 'Drei Walzen, und jeder Zwerg verdoppelt',
  rules: SlotRules(
    rows: 3,
    lines: _lines5,
    strips: gartenStrips,
    linePays: {
      0: [4],
      1: [6],
      2: [12],
      3: [25],
      4: [50],
      5: [100],
      6: [500],
    },
    wildDoubles: true,
  ),
  stakes: [10, 20, 50, 100, 200, 500],
  symbolNames: [
    'Radieschen',
    'Tomate',
    'Sonnenblume',
    'Gießkanne',
    'Bratwurst',
    'Bier',
    'Gartenzwerg',
    '',
  ],
  paintSymbol: paintGartenSymbol,
  paintBackdrop: paintGartenBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF8FD3E8), Color(0xFF7FB65A), Color(0xFF2F5E22)],
    ),
  ),
  frame: [Color(0xFF8A5A2B), Color(0xFFD9A441), Color(0xFF5E3B1A)],
  lobbyColor: Color(0xFF8FD3E8),
  featureText: 'Fünf Linien, gewertet werden drei Gleiche.',
  wildText:
      'Der Gartenzwerg ersetzt jedes Symbol. Jeder Zwerg in einer Gewinnlinie verdoppelt ihren Gewinn.',
);

const allSlots = [kosmos78, tiefsee, schrebergarten];
