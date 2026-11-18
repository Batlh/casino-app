import 'package:flutter/material.dart';

import 'drachen_art.dart';
import 'garten_art.dart';
import 'jahrmarkt_art.dart';
import 'kosmos_art.dart';
import 'mine_art.dart';
import 'slot_data.dart';
import 'slot_data_neu.dart';
import 'slot_engine.dart';
import 'tiefsee_art.dart';
import 'vulkan_art.dart';

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
  blurb: 'Vier Reihen, 1024 Wege, Gewinne überall',
  rules: SlotRules(
    rows: 4,
    mode: PayMode.ways,
    waysAnywhere: true,
    waysDivisor: 100,
    strips: tiefseeStrips,
    // Abgestimmt mit tool/sim_slots.py auf rund 95 % Auszahlung
    linePays: {
      0: [1, 3, 8],
      1: [1, 4, 12],
      2: [2, 6, 17],
      3: [3, 10, 30],
      4: [5, 17, 60],
      5: [8, 30, 150],
    },
    scatterPays: [2, 6, 25],
    freeSpins: 10,
    expandWildInFree: true,
  ),
  stakes: [100, 200, 300, 500, 1000, 2000],
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

const _holdCoins = HoldSpinRules(
  trigger: 6,
  respins: 3,
  landChance: 0.03,
  values: [5, 10, 15, 20, 25, 50, 100, 200, 500, 2000],
  weights: [300, 250, 180, 120, 80, 40, 15, 8, 3, 1],
  jackpots: {200: 'Mini', 500: 'Minor', 2000: 'Major'},
  grand: 10000,
);

// Die Beträge der drei folgenden Slots sind mit tool/tune_new_slots.py auf rund 95 % abgestimmt.

const edelsteinmine = SlotGame(
  name: 'Edelsteinmine',
  blurb: '243 Wege, Kaskaden bis ×10',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysDivisor: 100,
    strips: mineStrips,
    linePays: {
      0: [3, 5, 14],
      1: [3, 8, 16],
      2: [5, 11, 22],
      3: [5, 14, 27],
      4: [8, 22, 54],
      5: [14, 32, 108],
    },
    cascade: [1, 2, 3, 5],
    freeCascade: [2, 4, 6, 10],
    scatterPays: [2, 5, 20],
    freeSpins: 10,
  ),
  stakes: [100, 200, 300, 500, 1000, 2000],
  symbolNames: ['Quarz', 'Amethyst', 'Topas', 'Smaragd', 'Saphir', 'Rubin', 'Diamant', 'Grubenlampe', '', ''],
  paintSymbol: paintMineSymbol,
  paintBackdrop: paintMineBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4E342E), Color(0xFF2B1B14), Color(0xFF120C09)],
    ),
  ),
  frame: [Color(0xFFFFD180), Color(0xFF8D6E63), Color(0xFF3E2723)],
  lobbyColor: Color(0xFF3E2723),
  featureText:
      'Drei oder mehr Grubenlampen zahlen das 2-, 5- oder 20-Fache des Einsatzes und starten 10 Freispiele. In Freispielen steigen die Kaskaden bis ×10.',
  wildText: 'Der Diamant ersetzt jeden Edelstein, aber nicht die Grubenlampe.',
  freeSpinLine: 'Freispiel, Kaskaden ab ×2',
);

const drachenhort = SlotGame(
  name: 'Drachenhort',
  blurb: 'Hold & Spin mit vier Jackpots',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysAnywhere: true,
    waysDivisor: 50,
    strips: drachenStrips,
    linePays: {
      0: [6, 16, 40],
      1: [8, 20, 50],
      2: [10, 25, 65],
      3: [14, 33, 85],
      4: [20, 50, 170],
      5: [33, 85, 340],
    },
    holdSpin: _holdCoins,
  ),
  stakes: [50, 100, 200, 500, 1000, 2000],
  symbolNames: ['Schriftrolle', 'Kelch', 'Schwert', 'Schild', 'Krone', 'Drache', 'Drachenei', '', 'Goldmünzen', ''],
  paintSymbol: paintDrachenSymbol,
  paintBackdrop: paintDrachenBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4A148C), Color(0xFF2A0F2E), Color(0xFF12040F)],
    ),
  ),
  frame: [Color(0xFFFFE082), Color(0xFFB8860B), Color(0xFF4A148C)],
  lobbyColor: Color(0xFF2A0F2E),
  featureText:
      'Sechs oder mehr Goldmünzen starten Hold & Spin. Gewinne zählen überall: drei oder mehr nebeneinanderliegende Walzen, egal in welcher Reihe.',
  wildText: 'Das Drachenei ersetzt jedes Symbol außer der Goldmünze.',
);

const jahrmarkt = SlotGame(
  name: 'Jahrmarkt',
  blurb: 'Glücksrad mit Freispielen und Münzregen',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysAnywhere: true,
    waysDivisor: 50,
    strips: jahrmarktStrips,
    linePays: {
      0: [3, 9, 22],
      1: [4, 11, 27],
      2: [5, 13, 32],
      3: [7, 16, 43],
      4: [11, 27, 86],
      5: [16, 43, 160],
    },
    expandWildInFree: true,
    holdSpin: _holdCoins,
    wheel: WheelRules(
      segments: [
        WheelSegment(WheelKind.coins, 5, 6),
        WheelSegment(WheelKind.coins, 10, 5),
        WheelSegment(WheelKind.coins, 15, 4),
        WheelSegment(WheelKind.freeSpins, 8, 4),
        WheelSegment(WheelKind.coins, 25, 3),
        WheelSegment(WheelKind.holdSpin, 6, 3),
        WheelSegment(WheelKind.coins, 50, 1),
        WheelSegment(WheelKind.freeSpins, 12, 2),
      ],
    ),
  ),
  stakes: [50, 100, 200, 500, 1000, 2000],
  symbolNames: [
    'Popcorn',
    'Lebkuchenherz',
    'Zuckerwatte',
    'Luftballon',
    'Karussellpferd',
    'Riesenrad',
    'Glücksstern',
    '',
    'Münzen',
    'Glücksräder',
  ],
  paintSymbol: paintJahrmarktSymbol,
  paintBackdrop: paintJahrmarktBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF311B92), Color(0xFF4A148C), Color(0xFF1A0B2E)],
    ),
  ),
  frame: [Color(0xFFFF80AB), Color(0xFFFFD54F), Color(0xFF7C4DFF)],
  lobbyColor: Color(0xFF3B1E5E),
  featureText:
      'Drei Glücksräder auf den Walzen 1, 3 und 5 drehen das Glücksrad: Münzgewinne, Freispiele oder Hold & Spin. '
      'In Freispielen füllt ein Glücksstern auf den drei mittleren Walzen die ganze Walze.',
  wildText: 'Der Glücksstern ersetzt jedes Symbol außer dem Glücksrad.',
  freeSpinLine: 'Freispiel, Sterne füllen die Walze',
);

/// Sechs Walzen, jede Drehung mit neuer Höhe je Walze (2 bis 5 Symbole), dazu Kaskaden.
const vulkaninsel = SlotGame(
  name: 'Vulkaninsel',
  blurb: 'Wechselnde Walzen, bis zu 4.096 Wege',
  rules: SlotRules(
    rows: 5,
    heights: [2, 3, 4, 5],
    mode: PayMode.ways,
    waysDivisor: 500,
    strips: vulkanStrips,
    linePays: {
      0: [1, 3, 6, 12],
      1: [2, 4, 8, 15],
      2: [2, 5, 9, 20],
      3: [3, 6, 12, 27],
      4: [5, 9, 19, 46],
      5: [8, 15, 38, 92],
    },
    cascade: [1, 2, 3, 4, 5],
    freeCascade: [2, 4, 6, 8, 10, 15],
    scatterPays: [2, 5, 20],
    freeSpins: 12,
  ),
  stakes: [500, 1000, 1500, 2000, 3000, 5000],
  symbolNames: ['Kokosnuss', 'Ananas', 'Hibiskus', 'Papagei', 'Schildkröte', 'Tiki-Maske', 'Lavastein', 'Vulkan', '', ''],
  paintSymbol: paintVulkanSymbol,
  paintBackdrop: paintVulkanBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2B1036), Color(0xFF5E1F24), Color(0xFF1A0B0B)],
    ),
  ),
  frame: [Color(0xFFFFAB40), Color(0xFFBF360C), Color(0xFF3E1A10)],
  lobbyColor: Color(0xFF6B1F14),
  featureText:
      'Jede Walze zeigt bei jeder Drehung 2 bis 5 Symbole, das ergibt bis zu 4.096 Wege. Gewinnsymbole verschwinden, neue fallen nach, '
      'jede Kaskade erhöht den Multiplikator bis ×5. Drei oder mehr Vulkane zahlen das 2-, 5- oder 20-Fache des Einsatzes und '
      'starten 12 Freispiele, dort steigt der Multiplikator bis ×15.',
  wildText: 'Der Lavastein ersetzt jedes Symbol außer dem Vulkan.',
  freeSpinLine: 'Freispiel, Kaskaden ab ×2',
);

const allSlots = [kosmos78, tiefsee, schrebergarten, edelsteinmine, drachenhort, jahrmarkt, vulkaninsel];
