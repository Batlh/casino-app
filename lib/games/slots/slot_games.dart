import 'package:flutter/material.dart';

import 'bonbon_art.dart';
import 'buch_art.dart';
import 'drachen_art.dart';
import 'gold_art.dart';
import 'frucht_art.dart';
import 'garten_art.dart';
import 'jahrmarkt_art.dart';
import 'kosmos_art.dart';
import 'lawine_art.dart';
import 'jade_art.dart';
import 'mine_art.dart';
import 'pharao_art.dart';
import 'slot_data.dart';
import 'slot_data_neu.dart';
import 'sakura_art.dart';
import 'slot_engine.dart';
import 'tiefsee_art.dart';
import 'vulkan_art.dart';

/// Dauer eines Hintergrund-Durchlaufs. paintBackdrop bekommt die Zeit als 0 bis 1 über diese Dauer;
/// jede Bewegung darin macht ganze Zyklen, damit der Übergang von 1 auf 0 nicht ruckelt.
const backdropLoop = Duration(seconds: 20);

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
      0: [3, 4, 12],
      1: [3, 7, 13],
      2: [4, 9, 18],
      3: [4, 12, 23],
      4: [7, 18, 45],
      5: [12, 27, 91],
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

/// Edelsteinmine mit der Einstellung „Grubenlampen fallen nach“: eigene, längere Walzen und Beträge.
const edelsteinmineB = SlotGame(
  name: 'Edelsteinmine',
  blurb: '243 Wege, Kaskaden bis ×10',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysDivisor: 100,
    strips: mineBStrips,
    scatterDrops: true,
    linePays: {
      0: [4, 5, 15],
      1: [4, 9, 18],
      2: [5, 12, 25],
      3: [5, 16, 31],
      4: [9, 25, 61],
      5: [16, 36, 124],
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
      'Grubenlampen fallen in Kaskaden nach und zählen mit: Liegen am Ende drei oder mehr, zahlen sie das 2-, 5- oder 20-Fache des Einsatzes und starten 10 Freispiele. In Freispielen steigen die Kaskaden bis ×10.',
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
  blurb: 'Wechselnde Walzen, bis zu 15.625 Wege',
  rules: SlotRules(
    rows: 5,
    heights: [2, 3, 4, 5],
    mode: PayMode.ways,
    waysDivisor: 500,
    strips: vulkanStrips,
    linePays: {
      0: [1, 2, 5, 9],
      1: [2, 3, 6, 12],
      2: [2, 4, 7, 15],
      3: [2, 5, 9, 21],
      4: [4, 7, 15, 35],
      5: [6, 12, 29, 71],
    },
    cascade: [1, 2, 2, 3, 3],
    freeCascade: [2, 3, 4, 5, 6, 8],
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
      'Jede Walze zeigt bei jeder Drehung 2 bis 5 Symbole, das ergibt bis zu 15.625 Wege. Gewinnsymbole verschwinden, neue fallen nach, '
      'jede Kaskade erhöht den Multiplikator bis ×3. Drei oder mehr Vulkane zahlen das 2-, 5- oder 20-Fache des Einsatzes und '
      'starten 12 Freispiele, dort steigt der Multiplikator bis ×8.',
  wildText: 'Der Lavastein ersetzt jedes Symbol außer dem Vulkan.',
  freeSpinLine: 'Freispiel, Kaskaden ab ×2',
);

/// 1024 Wege; in Freispielen bleiben Kirschblüten liegen.
const sakura = SlotGame(
  name: 'Sakura',
  blurb: '1024 Wege, Kirschblüten bleiben liegen',
  rules: SlotRules(
    rows: 4,
    mode: PayMode.ways,
    waysDivisor: 100,
    strips: sakuraStrips,
    linePays: {
      0: [3, 9, 25],
      1: [3, 12, 31],
      2: [6, 15, 37],
      3: [6, 18, 46],
      4: [12, 31, 93],
      5: [18, 49, 185],
    },
    scatterPays: [2, 5, 20],
    freeSpins: 8,
    stickyWildsInFree: true,
  ),
  stakes: [100, 200, 300, 500, 1000, 2000],
  symbolNames: ['Teeschale', 'Fächer', 'Kranich', 'Laterne', 'Koi', 'Pagode', 'Kirschblüte', 'Torii', '', ''],
  paintSymbol: paintSakuraSymbol,
  paintBackdrop: paintSakuraBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A2253), Color(0xFF6E3A66), Color(0xFF241433)],
    ),
  ),
  frame: [Color(0xFFFFCDD2), Color(0xFFF06292), Color(0xFF6A1B4D)],
  lobbyColor: Color(0xFF8E3A6B),
  featureText:
      'Drei oder mehr Torii zahlen das 2-, 5- oder 20-Fache des Einsatzes und starten 8 Freispiele. In den Freispielen bleibt '
      'jede Kirschblüte, die landet, bis zum Ende der Freispiele liegen.',
  wildText: 'Die Kirschblüte ersetzt jedes Symbol außer dem Torii. Sie liegt nur auf den Walzen 2 bis 4.',
  freeSpinLine: 'Freispiel, Kirschblüten bleiben liegen',
);

/// Sechs Walzen mit wechselnder Höhe, dazu Glücksmünzen für Hold & Spin.
const jadetempel = SlotGame(
  name: 'Jadetempel',
  blurb: 'Wechselnde Walzen, Glücksmünzen, Jackpots',
  rules: SlotRules(
    rows: 5,
    heights: [2, 3, 4, 5],
    mode: PayMode.ways,
    waysDivisor: 100,
    strips: jadeStrips,
    linePays: {
      0: [4, 12, 22, 45],
      1: [7, 15, 30, 57],
      2: [8, 18, 33, 75],
      3: [12, 22, 45, 100],
      4: [19, 33, 71, 172],
      5: [30, 57, 141, 343],
    },
    holdSpin: HoldSpinRules(
      trigger: 6,
      respins: 3,
      // 30 Felder: mit 4 % je Feld kommt der Grand etwa alle 1,6 Mio. Drehungen (mit 2 % praktisch nie)
      landChance: 0.04,
      values: [5, 10, 15, 20, 25, 50, 100, 200, 500, 2000],
      weights: [300, 250, 180, 120, 80, 40, 15, 8, 3, 1],
      jackpots: {200: 'Mini', 500: 'Minor', 2000: 'Major'},
      grand: 10000,
    ),
  ),
  stakes: [500, 1000, 1500, 2000, 3000, 5000],
  symbolNames: ['Bambus', 'Lotus', 'Jadescheibe', 'Laterne', 'Goldbarren', 'Glücksfrosch', 'Drachenperle', '', 'Glücksmünze', ''],
  paintSymbol: paintJadeSymbol,
  paintBackdrop: paintJadeBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF5A0F12), Color(0xFF3A0808), Color(0xFF1A0404)],
    ),
  ),
  frame: [Color(0xFFFFE082), Color(0xFF2E7D32), Color(0xFF1B3A1B)],
  lobbyColor: Color(0xFF1E5631),
  featureText:
      'Jede Walze zeigt bei jeder Drehung 2 bis 5 Symbole, das ergibt bis zu 15.625 Wege. Sechs oder mehr Glücksmünzen starten '
      'Hold & Spin auf 6 × 5 Feldern.',
  wildText: 'Die Drachenperle ersetzt jedes Symbol außer der Glücksmünze.',
);

/// Spielvarianten, die per Einstellung statt eines Automaten aus allSlots laufen.
const slotVariants = [edelsteinmineB];

/// Drei Walzen à drei Reihen, 27 Wege; Joker mit ×2, ×3 oder ×5 zählt als so viele Wege.
const fruechtekorb = SlotGame(
  name: 'Früchtekorb',
  blurb: '3 Walzen, 27 Wege, Joker bis ×5',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysDivisor: 20,
    strips: fruchtStrips,
    linePays: {
      0: [5],
      1: [8],
      2: [10],
      3: [15],
      4: [24],
      5: [58],
    },
    wildMultipliers: [2, 3, 5],
    wildMultiplierWeights: [6, 3, 1],
  ),
  stakes: [20, 40, 100, 200, 500, 1000],
  symbolNames: ['Kirsche', 'Zitrone', 'Orange', 'Pflaume', 'Melone', 'Glocke', 'Sieben', '', '', ''],
  paintSymbol: paintFruchtSymbol,
  paintBackdrop: paintFruchtBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF5A0000), Color(0xFF2B0000), Color(0xFF140000)],
    ),
  ),
  frame: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFF8D6E00)],
  lobbyColor: Color(0xFF8E1B1B),
  featureText:
      'Drei gleiche Früchte auf den drei Walzen nebeneinander gewinnen, egal in welcher Reihe: 3 × 3 × 3 = 27 Wege. '
      'Liegt eine Frucht auf einer Walze zweimal, zählt das doppelt.',
  wildText: 'Die Sieben liegt nur auf der mittleren Walze und ersetzt jede Frucht. Sie bekommt bei jeder Drehung ×2, ×3 oder ×5 '
      'und zählt dann als so viele Wege: Eine Sieben ×3 macht aus einem Weg drei.',
);

/// 3 × 3 mit 27 Wegen und Kaskaden; neun Fruchtsorten.
const fruchtlawine = SlotGame(
  name: 'Fruchtlawine',
  blurb: '3 Walzen, 27 Wege, Früchte fallen nach',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysDivisor: 20,
    strips: lawineStrips,
    linePays: {
      0: [15],
      1: [15],
      10: [18],
      2: [22],
      11: [26],
      3: [29],
      12: [36],
      4: [51],
      5: [110],
    },
    cascade: [1, 2, 3, 5],
    freeCascade: [2, 4, 6, 10],
    scatterPays: [3],
    freeSpins: 8,
  ),
  stakes: [20, 40, 100, 200, 500, 1000],
  symbolNames: ['Kirsche', 'Zitrone', 'Orange', 'Pflaume', 'Melone', 'Glocke', 'Sieben', 'Stern', '', '', 'Erdbeere', 'Banane', 'Traube'],
  paintSymbol: paintLawineSymbol,
  paintBackdrop: paintLawineBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF00382F), Color(0xFF00211C), Color(0xFF00110E)],
    ),
  ),
  frame: [Color(0xFFB9F6CA), Color(0xFF00C853), Color(0xFF1B5E20)],
  lobbyColor: Color(0xFF00695C),
  featureText:
      'Drei gleiche Früchte auf den drei Walzen nebeneinander gewinnen, egal in welcher Reihe: 27 Wege. Gewinnfrüchte verschwinden, '
      'neue fallen nach, jede Kaskade erhöht den Multiplikator: ×1, ×2, ×3, ×5. Drei Sterne zahlen das 3-Fache des Einsatzes und '
      'starten 8 Freispiele, dort geht die Leiter ×2, ×4, ×6, ×10.',
  wildText: 'Die Sieben liegt nur auf der mittleren Walze und ersetzt jede Frucht.',
  freeSpinLine: 'Freispiel, Kaskaden ab ×2',
);

/// Mega-Slot mit allen Bausteinen: wechselnde Höhe, Kaskaden, Joker mit Multiplikator, liegende Joker in Freispielen,
/// Glücksmünzen mit Hold & Spin und Bonusrad.
const pharaonengold = SlotGame(
  name: 'Pharaonengold',
  blurb: 'Alles in einem: Kaskaden, Münzen, Bonusrad',
  rules: SlotRules(
    rows: 5,
    heights: [2, 3, 4, 5],
    mode: PayMode.ways,
    waysDivisor: 500,
    strips: pharaoStrips,
    linePays: {
      0: [2, 5, 13, 24],
      1: [5, 8, 16, 32],
      2: [5, 11, 19, 40],
      3: [6, 13, 24, 55],
      4: [11, 19, 40, 92],
      5: [16, 32, 77, 187],
    },
    cascade: [1, 2, 3, 5],
    freeCascade: [2, 4, 6, 10],
    wildMultipliers: [2, 3],
    wildMultiplierWeights: [3, 1],
    stickyWildsInFree: true,
    scatterPays: [2, 5, 20],
    freeSpins: 10,
    holdSpin: HoldSpinRules(
      trigger: 6,
      respins: 3,
      landChance: 0.04,
      values: [10, 20, 30, 40, 50, 100, 200, 400, 1000, 4000],
      weights: [300, 250, 180, 120, 80, 40, 15, 8, 3, 1],
      jackpots: {400: 'Mini', 1000: 'Minor', 4000: 'Major'},
      grand: 10000,
    ),
    wheel: WheelRules(
      segments: [
        WheelSegment(WheelKind.coins, 50, 6),
        WheelSegment(WheelKind.coins, 100, 4),
        WheelSegment(WheelKind.freeSpins, 10, 4),
        WheelSegment(WheelKind.holdSpin, 6, 3),
        WheelSegment(WheelKind.coins, 200, 2),
        WheelSegment(WheelKind.freeSpins, 15, 2),
        WheelSegment(WheelKind.coins, 500, 1),
      ],
    ),
  ),
  stakes: [500, 1000, 1500, 2000, 3000, 5000],
  symbolNames: ['Skarabäus', 'Krug', 'Auge', 'Henkelkreuz', 'Katze', 'Goldmaske', 'Pyramide', 'Flügelsonne', 'Goldmünze', 'Sonnenrad'],
  paintSymbol: paintPharaoSymbol,
  paintBackdrop: paintPharaoBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0B1033), Color(0xFF1C1236), Color(0xFF120A06)],
    ),
  ),
  frame: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFF1E4FA8)],
  lobbyColor: Color(0xFF1E3A78),
  featureText:
      'Sechs Walzen mit 2 bis 5 Symbolen je Drehung, bis zu 15.625 Wege. Gewinnsymbole verschwinden, neue fallen nach, '
      'jede Kaskade erhöht den Multiplikator: ×1, ×2, ×3, ×5. Drei oder mehr Flügelsonnen zahlen das 2-, 5- oder 20-Fache '
      'und starten 10 Freispiele mit ×2, ×4, ×6, ×10; dort bleiben Pyramiden bis zum Ende liegen. Sechs Goldmünzen starten '
      'Hold & Spin mit Mini, Minor, Major und Grand. Drei Sonnenräder auf den Walzen 1, 3 und 5 drehen das Bonusrad.',
  wildText: 'Die Pyramide ersetzt jedes Symbol außer Flügelsonne, Goldmünze und Sonnenrad. Sie bekommt ×2 oder ×3 und zählt '
      'dann als so viele Wege.',
  freeSpinLine: 'Freispiel, Pyramiden bleiben liegen',
);

/// Buch-Slot: Das Zauberbuch ist Joker und Streusymbol, in Freispielen breitet sich ein Sondersymbol aus.
const zauberbibliothek = SlotGame(
  name: 'Zauberbibliothek',
  blurb: '10 Linien, Freispiele mit Sondersymbol',
  rules: SlotRules(
    rows: 3,
    lines: _lines10,
    strips: buchStrips,
    linePays: {
      0: [5, 25, 100],
      1: [5, 25, 100],
      2: [5, 25, 100],
      10: [5, 40, 150],
      11: [5, 40, 150],
      3: [10, 50, 250],
      12: [15, 60, 300],
      4: [20, 80, 500],
      5: [50, 250, 2000],
    },
    scatterWild: true,
    scatterPays: [2, 20, 200],
    freeSpins: 10,
    expandingInFree: true,
    expandingChoices: [0, 1, 2, 10, 11, 3, 12, 4, 5],
  ),
  stakes: [10, 20, 50, 100, 200, 500],
  symbolNames: ['Feder', 'Kerze', 'Sanduhr', 'Schriftrolle', 'Kristallkugel', 'Eule', '', 'Zauberbuch', '', '', 'Schlüssel', 'Tintenfass', 'Zaubertrank'],
  paintSymbol: paintBuchSymbol,
  paintBackdrop: paintBuchBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2B160C), Color(0xFF1A0D07), Color(0xFF0D0603)],
    ),
  ),
  frame: [Color(0xFFFFE0A0), Color(0xFFB8860B), Color(0xFF5D2E0C)],
  lobbyColor: Color(0xFF6D3B16),
  featureText:
      'Drei oder mehr Zauberbücher irgendwo zahlen das 2-, 20- oder 200-Fache des Einsatzes und starten 10 Freispiele. '
      'Vorher wird ein Sondersymbol gezogen. Liegt es in einem Freispiel auf mindestens drei Walzen, füllt es diese Walzen '
      'ganz und zahlt auf allen 10 Linien, auch wenn die Walzen nicht nebeneinander liegen. Neue Bücher in Freispielen '
      'bringen 10 weitere mit demselben Sondersymbol.',
  wildText: 'Das Zauberbuch ersetzt auf den Linien jedes Symbol. Selbst zahlt es nur als Streusymbol.',
  freeSpinLine: 'Freispiel mit Sondersymbol',
);

/// Gruppen-Slot: 7 × 7, Gruppen ab fünf gleichen, Kaskaden.
const bonbonfabrik = SlotGame(
  name: 'Bonbonfabrik',
  blurb: '7 × 7, Gruppen ab fünf, Kaskaden',
  rules: SlotRules(
    rows: 7,
    mode: PayMode.cluster,
    clusterMin: 5,
    waysDivisor: 100,
    strips: bonbonStrips,
    linePays: {
      0: [160, 200, 250, 330, 400, 600, 800, 1200, 2000, 3500, 8000],
      1: [160, 200, 250, 330, 400, 600, 800, 1200, 2000, 3500, 8000],
      10: [200, 250, 330, 400, 600, 800, 1200, 1600, 2500, 4000, 10000],
      2: [200, 250, 330, 400, 600, 800, 1200, 1600, 2500, 4000, 10000],
      11: [250, 330, 400, 600, 800, 1200, 1600, 2500, 3500, 6000, 12000],
      3: [330, 400, 600, 800, 1200, 1600, 2500, 3500, 5000, 8000, 20000],
      4: [400, 600, 800, 1200, 1600, 2500, 3500, 5000, 8000, 12000, 30000],
      5: [800, 1200, 1600, 2500, 3500, 5000, 8000, 12000, 20000, 40000, 80000],
    },
    cascade: [1, 2, 3, 4, 5],
    freeCascade: [2, 4, 6, 8, 10],
    scatterPays: [3, 10, 50],
    freeSpins: 10,
  ),
  stakes: [100, 200, 300, 500, 1000, 2000],
  symbolNames: ['Himbeerbonbon', 'Zitronendrops', 'Blaubeerherz', 'Gummistern', 'Lakritzschnecke', 'Lutscher', 'Zuckerkugel', 'Bonbonglas', '', '', 'Minzwürfel', 'Orangenring'],
  paintSymbol: paintBonbonSymbol,
  paintBackdrop: paintBonbonBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A1034), Color(0xFF250A22), Color(0xFF140512)],
    ),
  ),
  frame: [Color(0xFFFFC1E3), Color(0xFFFF4081), Color(0xFF7B1FA2)],
  lobbyColor: Color(0xFFAD1457),
  featureText:
      'Sieben Walzen mit je sieben Feldern. Fünf oder mehr gleiche Süßigkeiten, die waagrecht oder senkrecht aneinandergrenzen, '
      'gewinnen. Gewinngruppen verschwinden, neue Süßigkeiten fallen nach, jede Kaskade zählt mehr: ×1, ×2, ×3, ×4, ×5. '
      'Drei oder mehr Bonbongläser zahlen das 3-, 10- oder 50-Fache und starten 10 Freispiele, dort geht die Leiter ×2, ×4, ×6, ×8, ×10.',
  wildText: 'Die Zuckerkugel gehört zu jeder Gruppe, an die sie grenzt, auch zu mehreren auf einmal.',
  freeSpinLine: 'Freispiel, Kaskaden ab ×2',
);

/// Wandernde Joker im Grundspiel, Riesensymbol 3 × 3 in Freispielen.
const goldgraeber = SlotGame(
  name: 'Goldgräber',
  blurb: '243 Wege, wandernde Joker, Riesensymbole',
  rules: SlotRules(
    rows: 3,
    mode: PayMode.ways,
    waysDivisor: 20,
    strips: goldStrips,
    linePays: {
      0: [2, 5, 15],
      1: [2, 5, 15],
      10: [2, 6, 18],
      11: [2, 6, 18],
      2: [3, 8, 25],
      3: [4, 12, 40],
      4: [6, 16, 60],
      5: [12, 35, 125],
    },
    walkingWilds: true,
    giantInFree: 3,
    scatterPays: [2, 10, 50],
    freeSpins: 8,
  ),
  stakes: [20, 40, 100, 200, 400, 1000],
  symbolNames: ['Hufeisen', 'Laterne', 'Kaktus', 'Sheriffstern', 'Goldsack', 'Goldklumpen', 'Hut', 'Schatzkarte', '', '', 'Spitzhacke', 'Waschpfanne'],
  paintSymbol: paintGoldSymbol,
  paintBackdrop: paintGoldBackdrop,
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2B1433), Color(0xFF3A1A0C), Color(0xFF1A0B05)],
    ),
  ),
  frame: [Color(0xFFFFE0B2), Color(0xFFD2691E), Color(0xFF5A2410)],
  lobbyColor: Color(0xFF9C4A1A),
  featureText:
      'Fünf Walzen, 243 Wege. Landet im Grundspiel ein Hut, rückt er nach der Drehung eine Walze nach links und alle anderen '
      'Felder drehen gratis neu, bis er links hinauswandert. Drei Schatzkarten auf den Walzen 1, 3 und 5 zahlen das 2-Fache '
      'des Einsatzes und starten 8 Freispiele. Dort landet auf den drei mittleren Walzen in jedem Freispiel ein '
      'Riesensymbol, 3 × 3 Felder groß.',
  wildText: 'Der Hut ersetzt jedes Symbol außer der Schatzkarte und wandert im Grundspiel nach links.',
  freeSpinLine: 'Freispiel mit Riesensymbol',
);

const allSlots = [kosmos78, tiefsee, schrebergarten, edelsteinmine, drachenhort, jahrmarkt, vulkaninsel, sakura, jadetempel, fruechtekorb, fruchtlawine, pharaonengold, zauberbibliothek, bonbonfabrik, goldgraeber];
