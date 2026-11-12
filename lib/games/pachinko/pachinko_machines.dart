import 'dart:ui' show Color;

/// Bauplan einer Pachinko-Maschine. Brett 10 breit, 16 hoch, rechts die Abschussbahn.

enum PocketKind { tulip, start, gate }

class Pocket {
  const Pocket(this.left, this.top, this.right, this.bottom, this.payout, this.kind);
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int payout;
  final PocketKind kind;

  bool contains(double x, double y) => x >= left && x <= right && y >= top && y <= bottom;
}

class MachineTheme {
  const MachineTheme({
    required this.top,
    required this.bottom,
    required this.peg,
    required this.accent,
    required this.fever,
    required this.lcd,
    required this.art,
  });
  final Color top;
  final Color bottom;
  final Color peg;
  final Color accent;
  final Color fever;

  /// Hintergrund des Anzeigefelds.
  final Color lcd;

  /// Motiv und Animation (classic, sea, dragon, blossom, retro).
  final String art;
}

class MachineSpec {
  const MachineSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.theme,
    required this.pockets,
    this.lcdLeft = 3.2,
    this.lcdTop = 3.3,
    this.lcdRight = 6.2,
    this.lcdBottom = 6.3,
    this.lcdRoof = 1.2,
    this.spinners = const [(2.2, 7.6), (7.2, 7.6)],
    this.pattern = 'classic',
    this.feverChance = 0.04,
    this.feverSeconds = 14,
  });
  final String id;
  final String name;
  final String blurb;
  final MachineTheme theme;
  final List<Pocket> pockets;
  final double lcdLeft;
  final double lcdTop;
  final double lcdRight;
  final double lcdBottom;

  /// Höhe des Spitzdachs über dem Anzeigefeld.
  final double lcdRoof;

  /// Windräder (Mitte).
  final List<(double, double)> spinners;

  /// Nagelbild: classic, wave, temple, blossom, retro.
  final String pattern;
  final double feverChance;
  final double feverSeconds;
}

const classicMachine = MachineSpec(
  id: 'classic',
  name: 'Neon Pachinko',
  blurb: 'Die Klassische: zwei Windräder, zwei Tulpen, Fieber-Tor',
  theme: MachineTheme(
    top: Color(0xFF2A1048),
    bottom: Color(0xFF0E0620),
    peg: Color(0xFFE8D9B0),
    accent: Color(0xFFFFC95C),
    fever: Color(0xFFFF5EA8),
    lcd: Color(0xFF120726),
    art: 'classic',
  ),
  pockets: [
    Pocket(1.1, 10.7, 2.1, 11.0, 25, PocketKind.tulip),
    Pocket(7.2, 10.7, 8.2, 11.0, 25, PocketKind.tulip),
    Pocket(4.2, 11.7, 5.2, 12.0, 30, PocketKind.start),
    Pocket(3.0, 13.6, 6.4, 14.1, 150, PocketKind.gate),
  ],
);

const seaMachine = MachineSpec(
  id: 'sea',
  name: 'Meer und Fische',
  blurb: 'Wellen im Nagelbild, Wasserräder und Fische auf dem Bildschirm',
  theme: MachineTheme(
    top: Color(0xFF0B4F7A),
    bottom: Color(0xFF04213A),
    peg: Color(0xFFD8F3FF),
    accent: Color(0xFF7FE7FF),
    fever: Color(0xFFFFB347),
    lcd: Color(0xFF032A45),
    art: 'sea',
  ),
  pattern: 'wave',
  feverChance: 0.035,
  pockets: [
    Pocket(1.0, 10.6, 2.0, 10.9, 25, PocketKind.tulip),
    Pocket(7.3, 10.6, 8.3, 10.9, 25, PocketKind.tulip),
    Pocket(4.2, 11.7, 5.2, 12.0, 30, PocketKind.start),
    Pocket(3.0, 13.6, 6.4, 14.1, 150, PocketKind.gate),
  ],
);

const dragonMachine = MachineSpec(
  id: 'dragon',
  name: 'Drache und Tempel',
  blurb: 'Großer Tempel in der Mitte, ein Drachenrad und lange Fieberzeit',
  theme: MachineTheme(
    top: Color(0xFF5A0E0E),
    bottom: Color(0xFF1E0505),
    peg: Color(0xFFF5D88A),
    accent: Color(0xFFFFC43D),
    fever: Color(0xFFFF4D2E),
    lcd: Color(0xFF2A0606),
    art: 'dragon',
  ),
  lcdLeft: 3.0,
  lcdTop: 3.4,
  lcdRight: 6.4,
  lcdBottom: 6.6,
  lcdRoof: 1.3,
  spinners: [(4.7, 8.6)],
  pattern: 'temple',
  feverChance: 0.035,
  feverSeconds: 17,
  pockets: [
    Pocket(0.9, 10.2, 1.9, 10.5, 25, PocketKind.tulip),
    Pocket(7.4, 10.2, 8.4, 10.5, 25, PocketKind.tulip),
    Pocket(4.2, 11.9, 5.2, 12.2, 30, PocketKind.start),
    Pocket(3.0, 13.6, 6.4, 14.1, 150, PocketKind.gate),
  ],
);

const blossomMachine = MachineSpec(
  id: 'blossom',
  name: 'Kirschblüten',
  blurb: 'Ruhige Maschine ohne Windräder, dafür fünf Tulpen',
  theme: MachineTheme(
    top: Color(0xFF6E3A5C),
    bottom: Color(0xFF2A1426),
    peg: Color(0xFFFFE3EE),
    accent: Color(0xFFFF9EC4),
    fever: Color(0xFFFFE066),
    lcd: Color(0xFF3A1C30),
    art: 'blossom',
  ),
  spinners: [],
  pattern: 'blossom',
  feverChance: 0.03,
  pockets: [
    Pocket(0.8, 9.4, 1.8, 9.7, 18, PocketKind.tulip),
    Pocket(2.4, 10.8, 3.4, 11.1, 18, PocketKind.tulip),
    Pocket(6.0, 10.8, 7.0, 11.1, 18, PocketKind.tulip),
    Pocket(7.6, 9.4, 8.6, 9.7, 18, PocketKind.tulip),
    Pocket(4.2, 11.9, 5.2, 12.2, 30, PocketKind.start),
    Pocket(3.0, 13.6, 6.4, 14.1, 150, PocketKind.gate),
  ],
);

const retroMachine = MachineSpec(
  id: 'retro',
  name: 'Retro-Spielhalle',
  blurb: 'Pixel-Look, Walzen wie am Automaten und kurzes Fieber',
  theme: MachineTheme(
    top: Color(0xFF151515),
    bottom: Color(0xFF050505),
    peg: Color(0xFF7CFF6B),
    accent: Color(0xFFFFE14D),
    fever: Color(0xFFFF3DF2),
    lcd: Color(0xFF000000),
    art: 'retro',
  ),
  spinners: [(2.0, 8.0), (7.4, 8.0)],
  pattern: 'retro',
  feverChance: 0.03,
  feverSeconds: 10,
  pockets: [
    Pocket(1.1, 10.7, 2.1, 11.0, 25, PocketKind.tulip),
    Pocket(7.2, 10.7, 8.2, 11.0, 25, PocketKind.tulip),
    Pocket(4.2, 11.7, 5.2, 12.0, 30, PocketKind.start),
    Pocket(3.0, 13.6, 6.4, 14.1, 150, PocketKind.gate),
  ],
);

const pachinkoMachines = [classicMachine, seaMachine, dragonMachine, blossomMachine, retroMachine];
