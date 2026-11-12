import 'dart:ui' show Color;

/// Bauplan eines Flippertisches. Einheiten: Spielfeld 0 bis 9,25 breit, rechts die Abschussbahn bis 9,95,
/// 18 hoch, y zeigt nach unten. Die Abschussbahn mit Feder und Klappe ist bei allen Tischen gleich.

class Pt {
  const Pt(this.x, this.y);
  final double x;
  final double y;
}

/// Bande als Linienzug.
class WallSpec {
  const WallSpec(this.points, {this.bounce = 0.35, this.visible = true});
  final List<Pt> points;
  final double bounce;

  /// Unsichtbare Banden liegen zum Beispiel unter einer gezeichneten Rampe.
  final bool visible;
}

class BumperSpec {
  const BumperSpec(this.x, this.y, {this.radius = 0.5, this.points = 100});
  final double x;
  final double y;
  final double radius;
  final int points;
}

/// Schleuder: Dreieck a, b, c; a nach b ist die federnde Seite.
class SlingSpec {
  const SlingSpec(this.a, this.b, this.c);
  final Pt a;
  final Pt b;
  final Pt c;
}

/// Flipper: dir 1 zeigt nach rechts (linker Flipper), -1 nach links. rest und up sind die Winkel in Ruhe und oben.
class FlipperSpec {
  const FlipperSpec(
    this.pivot,
    this.dir, {
    this.length = 1.75,
    this.rest = 0.5,
    this.up = -0.45,
    this.heelHalfWidth = .2,
    this.tipHalfWidth = .07,
  });
  final Pt pivot;
  final int dir;
  final double length;
  final double rest;
  final double up;
  final double heelHalfWidth;
  final double tipHalfWidth;
  bool get left => dir > 0;
}

/// Rollover-Gasse: Sensor an einer Stelle. Gassen derselben Gruppe ergeben zusammen einen Bonus.
class LaneSpec {
  const LaneSpec(
    this.x,
    this.y, {
    this.group = 'top',
    this.points = 50,
    this.halfWidth = 0.32,
  });
  final double x;
  final double y;
  final String group;
  final int points;
  final double halfWidth;
}

/// Reihe von Fallzielen; jedes Ziel ist eine kurze Bande mit Mitte, Winkel (Richtung der Bande) und Länge.
class DropBankSpec {
  const DropBankSpec(
    this.id,
    this.targets, {
    this.angle = 0,
    this.length = 0.55,
    this.points = 200,
    this.bonus = 2000,
  });
  final String id;
  final List<Pt> targets;
  final double angle;
  final double length;
  final int points;
  final int bonus;
}

/// Stehende Zielscheiben: zählen bei jedem Treffer, alle zusammen geben einen Bonus.
class TargetBankSpec {
  const TargetBankSpec(
    this.id,
    this.targets, {
    this.angle = 0,
    this.length = 0.5,
    this.points = 150,
    this.bonus = 1500,
  });
  final String id;
  final List<Pt> targets;
  final double angle;
  final double length;
  final int points;
  final int bonus;
}

/// Drehklappe: dreht sich, wenn die Kugel die Linie a–b kreuzt, jede Umdrehung zählt.
class SpinnerSpec {
  const SpinnerSpec(this.id, this.a, this.b, {this.points = 25});
  final String id;
  final Pt a;
  final Pt b;
  final int points;
}

/// Kickout-Loch: fängt die Kugel, hält sie kurz und wirft sie in Richtung (ex, ey) wieder aus.
class SaucerSpec {
  const SaucerSpec(
    this.id,
    this.x,
    this.y,
    this.ex,
    this.ey, {
    this.points = 500,
    this.lock = false,
  });
  final String id;
  final double x;
  final double y;
  final double ex;
  final double ey;
  final int points;

  /// Fängt Kugeln für den Multiball.
  final bool lock;
}

/// Rampe: Eingang ist die Linie a–b, die Kugel muss in Richtung (dx, dy) schnell genug sein.
/// Dann fährt sie die Bahn [path] ab (gezeichnet über dem Tisch) und kommt am letzten Punkt mit (vx, vy) heraus.
class RampSpec {
  const RampSpec(
    this.id,
    this.a,
    this.b,
    this.dx,
    this.dy,
    this.path,
    this.vx,
    this.vy, {
    this.points = 1000,
    this.minSpeed = 6,
    this.name = '',
    this.deckWidth = 0.62,
    this.sideHeight = 0.18,
    this.heights = const [],
    this.wireStart = 1.0,
  });
  final String id;
  final Pt a;
  final Pt b;
  final double dx;
  final double dy;
  final List<Pt> path;
  final double vx;
  final double vy;
  final int points;
  final double minSpeed;
  final String name;

  /// Gerenderte Fahrbahnbreite und Seitenwandhöhe in Welteinheiten.
  final double deckWidth;
  final double sideHeight;

  /// Höhe an jedem Pfadpunkt, getrennt von den x/y-Weltkoordinaten.
  /// Leere Liste erhält die alte, flache Darstellung anderer Tische.
  final List<double> heights;

  /// Anteil der Rampenlänge, ab dem ein offener Draht-Rücklauf beginnt.
  final double wireStart;
}

/// Tragpfosten mit tatsächlichem Boden-Kollisionskreis und grafischer Höhe.
class SupportSpec {
  const SupportSpec(this.x, this.y, this.height, {this.radius = 0.10});
  final double x;
  final double y;
  final double height;
  final double radius;
}

enum MissionKind {
  bumper,
  sling,
  lanes,
  drops,
  targets,
  spinner,
  saucer,
  ramp,
  anyRamp,
  lock,
}

/// Eine Aufgabe auf der Anzeige, zum Beispiel „Linke Rampe 3 mal“.
class MissionSpec {
  const MissionSpec(
    this.title,
    this.kind,
    this.count, {
    this.id,
    this.reward = 10000,
  });
  final String title;
  final MissionKind kind;
  final int count;

  /// Bestimmtes Teil (Rampe, Bank, Loch), sonst zählt jedes dieser Art.
  final String? id;
  final int reward;
}

/// Farben und Bildmotiv eines Tisches.
class TableTheme {
  const TableTheme({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.wall,
    required this.bumper,
    required this.sling,
    required this.flipper,
    required this.accent,
    required this.light,
    required this.ramp,
    required this.dmd,
    required this.art,
  });
  final Color top;
  final Color mid;
  final Color bottom;
  final Color wall;
  final Color bumper;
  final Color sling;
  final Color flipper;
  final Color accent;
  final Color light;
  final Color ramp;

  /// Farbe der Punktanzeige.
  final Color dmd;

  /// Welches Hintergrundbild gemalt wird (neon, space, pirate, haunted, racing, city).
  final String art;
}

class TableSpec {
  const TableSpec({
    required this.id,
    required this.name,
    required this.blurb,
    required this.theme,
    required this.walls,
    required this.flippers,
    this.playfieldHeight = 18,
    this.bumpers = const [],
    this.supports = const [],
    this.slings = const [],
    this.lanes = const [],
    this.drops = const [],
    this.targets = const [],
    this.spinners = const [],
    this.saucers = const [],
    this.ramps = const [],
    this.missions = const [],
    this.locksForMultiball = 3,
    this.jackpot = 25000,
    this.labels = const [],
  });
  final String id;
  final String name;
  final String blurb;
  final TableTheme theme;
  final List<WallSpec> walls;
  final double playfieldHeight;
  final List<FlipperSpec> flippers;
  final List<BumperSpec> bumpers;
  final List<SupportSpec> supports;
  final List<SlingSpec> slings;
  final List<LaneSpec> lanes;
  final List<DropBankSpec> drops;
  final List<TargetBankSpec> targets;
  final List<SpinnerSpec> spinners;
  final List<SaucerSpec> saucers;
  final List<RampSpec> ramps;
  final List<MissionSpec> missions;
  final int locksForMultiball;
  final int jackpot;

  /// Beschriftungen auf dem Spielfeld (Text, Mitte, Größe).
  final List<(String, Pt, double)> labels;
}
