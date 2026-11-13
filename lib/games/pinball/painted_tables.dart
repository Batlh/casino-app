// Erzeugt von gen.py aus den gemalten Konzeptpaketen. Nicht von Hand ändern.
import 'dart:ui' show Color;

import 'pinball_layout.dart';

const paintedEifelringTable = TableSpec(
  id: 'eifelring',
  name: 'Eifelring',
  blurb: 'Nordschleife und Grand-Prix-Kurs, Boxengasse und Turbo-Motor',
  theme: TableTheme(
    top: Color(0xFF1B2A1F),
    mid: Color(0xFF243526),
    bottom: Color(0xFF101510),
    wall: Color(0xFFF4F4F4),
    bumper: Color(0xFFFFB300),
    sling: Color(0xFFE53935),
    flipper: Color(0xFFFFD54F),
    accent: Color(0xFFFFD600),
    light: Color(0xFFFFD600),
    ramp: Color(0xFFE53935),
    dmd: Color(0xFFFFB300),
    art: 'painted:eifelring',
  ),
  walls: [
    WallSpec([Pt(0.000, 13.200), Pt(0.000, 2.400), Pt(2.200, 0.000), Pt(5.000, 0.000), Pt(5.324, 0.009), Pt(5.646, 0.034), Pt(5.966, 0.077), Pt(6.281, 0.136), Pt(6.591, 0.212), Pt(6.894, 0.304), Pt(7.189, 0.413), Pt(7.475, 0.536), Pt(7.750, 0.674), Pt(8.013, 0.827), Pt(8.264, 0.993), Pt(8.500, 1.172), Pt(8.722, 1.363), Pt(8.927, 1.565), Pt(9.116, 1.778), Pt(9.287, 2.000), Pt(9.440, 2.231), Pt(9.573, 2.469), Pt(9.687, 2.714), Pt(9.781, 2.965), Pt(9.855, 3.220), Pt(9.908, 3.478), Pt(9.939, 3.738), Pt(9.950, 4.000), Pt(9.950, 18.200)], visible: false),
    WallSpec([Pt(0.900, 12.000), Pt(0.900, 14.000), Pt(2.350, 15.450)], visible: false),
    WallSpec([Pt(8.300, 12.000), Pt(8.300, 14.000), Pt(6.850, 15.450)], visible: false),
    WallSpec([Pt(2.250, 15.800), Pt(1.550, 18.200)], visible: false),
    WallSpec([Pt(6.950, 15.800), Pt(7.650, 18.200)], visible: false),
    WallSpec([Pt(4.550, 0.550), Pt(4.550, 1.700)], visible: false),
    WallSpec([Pt(5.300, 0.550), Pt(5.300, 1.700)], visible: false),
    WallSpec([Pt(6.050, 0.600), Pt(6.050, 1.700)], visible: false),
    WallSpec([Pt(6.800, 0.700), Pt(6.800, 1.700)], visible: false),
    WallSpec([Pt(2.700, 4.550), Pt(3.050, 3.800), Pt(7.000, 3.800), Pt(7.300, 4.550), Pt(6.950, 5.300), Pt(3.050, 5.300), Pt(2.700, 4.550)], bounce: 0.45, visible: false),
    WallSpec([Pt(7.350, 5.750), Pt(8.750, 5.750), Pt(8.750, 8.000), Pt(8.250, 8.150), Pt(7.350, 8.000), Pt(7.350, 5.750)], visible: false),
    WallSpec([Pt(2.850, 7.300), Pt(2.950, 7.700)], visible: false),
    WallSpec([Pt(6.950, 7.300), Pt(6.850, 7.700)], visible: false),
  ],
  flippers: [
    FlipperSpec(Pt(2.450, 15.600), 1, length: 1.6),
    FlipperSpec(Pt(6.750, 15.600), -1, length: 1.6),
  ],
  bumpers: [BumperSpec(5.150, 2.350, radius: 0.420), BumperSpec(4.200, 3.050, radius: 0.420), BumperSpec(6.150, 3.100, radius: 0.420)],
  slings: [SlingSpec(Pt(1.800, 11.750), Pt(2.650, 13.800), Pt(1.800, 13.250)), SlingSpec(Pt(7.450, 11.750), Pt(6.600, 13.800), Pt(7.450, 13.250))],
  lanes: [
    LaneSpec(4.920, 1.150, group: 'top', halfWidth: 0.300),
    LaneSpec(5.670, 1.150, group: 'top', halfWidth: 0.300),
    LaneSpec(6.420, 1.150, group: 'top', halfWidth: 0.300),
    LaneSpec(0.500, 12.600, group: 'out', halfWidth: 0.300),
    LaneSpec(1.300, 12.600, group: 'in', halfWidth: 0.300),
    LaneSpec(7.900, 12.600, group: 'in', halfWidth: 0.300),
    LaneSpec(8.750, 12.600, group: 'out', halfWidth: 0.300),
  ],
  drops: [
    DropBankSpec('kurven', [Pt(3.850, 10.400), Pt(4.650, 10.400), Pt(5.450, 10.400)], angle: 0.000, length: 0.500),
  ],
  targets: [
  ],
  spinners: [],
  saucers: [
    SaucerSpec('box', 7.850, 8.550, -2.200, 3.400, lock: true),
  ],
  ramps: [
    RampSpec('nord', Pt(0.350, 9.900), Pt(1.400, 9.900), 0.000, -1.000, [Pt(0.900, 9.600), Pt(0.950, 8.000), Pt(1.200, 6.200), Pt(1.550, 4.600), Pt(1.300, 3.200), Pt(1.500, 2.200), Pt(2.600, 1.500), Pt(4.800, 1.250), Pt(7.400, 1.400), Pt(8.600, 2.600), Pt(8.900, 4.800), Pt(8.800, 7.300), Pt(8.400, 9.300), Pt(7.950, 10.900)], -0.200, 3.000, points: 1000, minSpeed: 5, name: 'Nordschleife'),
    RampSpec('fuchs', Pt(1.500, 9.900), Pt(2.450, 9.900), 0.000, -1.000, [Pt(2.000, 9.600), Pt(2.100, 7.600), Pt(2.300, 5.900), Pt(1.900, 4.400), Pt(1.600, 3.200), Pt(1.150, 4.600), Pt(0.800, 7.000), Pt(0.750, 9.500), Pt(1.300, 11.000)], 0.000, 3.000, points: 1000, minSpeed: 5, name: 'Fuchsröhre'),
    RampSpec('gp', Pt(2.500, 8.600), Pt(3.250, 8.600), 0.000, -1.000, [Pt(2.850, 8.300), Pt(2.550, 7.300), Pt(2.750, 6.350), Pt(4.700, 6.200), Pt(7.000, 6.350), Pt(7.300, 7.050), Pt(7.200, 8.200), Pt(7.100, 8.800)], -0.600, 2.800, points: 1000, minSpeed: 5, name: 'Grand-Prix-Kurs'),
    RampSpec('motor', Pt(3.900, 7.950), Pt(5.500, 7.950), 0.000, -1.000, [Pt(4.700, 7.700), Pt(4.500, 6.700), Pt(3.300, 6.000), Pt(2.300, 5.400), Pt(1.700, 3.600), Pt(1.400, 1.800), Pt(1.250, 1.050), Pt(2.400, 0.900), Pt(3.800, 1.400), Pt(4.400, 2.100)], 0.800, 1.200, points: 1000, minSpeed: 5, name: 'Motor'),
    RampSpec('bruen', Pt(7.950, 9.950), Pt(8.900, 9.950), 0.000, -1.000, [Pt(8.400, 9.600), Pt(8.600, 7.400), Pt(8.850, 5.200), Pt(8.450, 3.600), Pt(7.700, 3.200), Pt(6.900, 2.500)], -1.200, 1.000, points: 1000, minSpeed: 5, name: 'Brünnchen'),
  ],
  missions: [
    MissionSpec('Qualifikation: 3 Rampen', MissionKind.anyRamp, 3),
    MissionSpec('Regenrennen: Kurvenziele', MissionKind.drops, 3),
    MissionSpec('Überholmanöver: Grand-Prix-Kurs 2 mal', MissionKind.ramp, 2, id: 'gp'),
    MissionSpec('Boxenstopp: Boxengasse 2 mal', MissionKind.saucer, 2),
    MissionSpec('Nachtrennen: 25 Reifen-Treffer', MissionKind.bumper, 25),
    MissionSpec('Safety-Car: Gassen P-1-T', MissionKind.lanes, 1, id: 'top'),
    MissionSpec('Rekordrunde: Nordschleife 2 mal', MissionKind.ramp, 2, id: 'nord'),
    MissionSpec('Karussell-Duell: Fuchsröhre und Brünnchen', MissionKind.anyRamp, 4),
  ],
  locksForMultiball: 3,
);

/// Spielfeldbild je gemaltem Tisch (848 × 1536 px = 9,95 × 18 Einheiten).
const paintedBackgrounds = <String, String>{
  'eifelring': 'assets/pinball/painted/eifelring.webp',
};

const paintedTables = [paintedEifelringTable];
