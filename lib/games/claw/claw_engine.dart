import 'dart:math';

/// Greifautomat von der Seite: Der Greifer fährt nach rechts, solange man hält, und greift beim Loslassen.
///
/// Wie gut man zielt, entscheidet, ob der Greifer überhaupt richtig sitzt. Ob er dann festhält, ist Glück: Die Chance
/// ist so gewählt, dass selbst perfektes Zielen auf lange Sicht [clawReturn] des Einsatzes zurückbringt, egal welchen
/// Preis man anpeilt. Teure Preise rutschen also öfter heraus.
const clawReturn = 0.95;

/// Breite der Kiste in Einheiten; links (0 … [chuteWidth]) liegt der Ausgabeschacht.
const clawBoxWidth = 10.0;
const chuteWidth = 1.8;

/// So weit darf der Greifer neben der Preismitte sitzen und noch greifen.
const clawReach = 0.55;

class PrizeKind {
  const PrizeKind(this.name, this.value, this.width);
  final String name;

  /// Gewinn in Einsätzen.
  final int value;
  final double width;
}

const prizeKinds = [
  PrizeKind('Entchen', 2, 1.1),
  PrizeKind('Bärchen', 4, 1.3),
  PrizeKind('Häschen', 6, 1.2),
  PrizeKind('Stern', 10, 1.1),
  PrizeKind('Krone', 25, 1.0),
];

/// Wie oft eine Sorte im Haufen liegt (Gewichte).
const prizeWeights = [30, 26, 20, 16, 8];

class Prize {
  Prize(this.kind, this.x, this.layer);
  final int kind;
  double x;

  /// 0 unten, 1 oben aufliegend.
  final int layer;
  PrizeKind get info => prizeKinds[kind];
}

class ClawResult {
  const ClawResult({required this.prize, required this.grabbed, required this.won, required this.dropAt, required this.quality});

  /// Gegriffener Preis (oder null, wenn der Greifer ins Leere ging).
  final Prize? prize;

  /// Greifer hat den Preis hochgehoben.
  final bool grabbed;

  /// Preis bis in den Schacht gebracht.
  final bool won;

  /// Anteil des Rückwegs (0 … 1), an dem der Preis herausrutscht.
  final double dropAt;

  /// Zielgenauigkeit 0 … 1.
  final double quality;
}

class ClawMachine {
  ClawMachine({Random? rng}) : _rng = rng ?? Random.secure() {
    while (prizes.length < 14) {
      _addPrize();
    }
  }

  final Random _rng;
  final List<Prize> prizes = [];

  int _pickKind() {
    var v = _rng.nextInt(prizeWeights.reduce((a, b) => a + b));
    for (var i = 0; i < prizeWeights.length; i++) {
      if (v < prizeWeights[i]) return i;
      v -= prizeWeights[i];
    }
    return 0;
  }

  void _addPrize() {
    final bottom = prizes.where((p) => p.layer == 0).length;
    final layer = bottom < 7 ? 0 : 1;
    // Freie Stelle suchen, nicht im Schacht
    for (var tries = 0; tries < 60; tries++) {
      final x = chuteWidth + 0.8 + _rng.nextDouble() * (clawBoxWidth - chuteWidth - 1.6);
      if (prizes.where((p) => p.layer == layer).every((p) => (p.x - x).abs() > 1.15)) {
        prizes.add(Prize(_pickKind(), x, layer));
        return;
      }
    }
    prizes.add(Prize(_pickKind(), chuteWidth + 0.8 + _rng.nextDouble() * (clawBoxWidth - chuteWidth - 1.6), layer));
  }

  /// Preis unter dem Greifer: oben aufliegende zuerst, sonst der nächste unten.
  Prize? prizeAt(double x) {
    Prize? best;
    var bestD = double.infinity;
    for (final layer in [1, 0]) {
      for (final p in prizes.where((p) => p.layer == layer)) {
        final d = (p.x - x).abs();
        if (d < clawReach && d < bestD) {
          best = p;
          bestD = d;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  /// Chance, dass der Greifer festhält, bei Zielgenauigkeit [quality].
  static double holdChance(PrizeKind k, double quality) => clawReturn / k.value * quality;

  /// Greift bei [x].
  ClawResult grab(double x) {
    final p = prizeAt(x);
    if (p == null) return ClawResult(prize: null, grabbed: false, won: false, dropAt: 0, quality: 0);
    final quality = 1 - ((p.x - x).abs() / clawReach) * ((p.x - x).abs() / clawReach);
    final win = _rng.nextDouble() < holdChance(p.info, quality);
    // Verlierer rutschen entweder gleich beim Anheben oder auf dem Weg heraus (das sieht spannender aus)
    final grabbed = win || _rng.nextDouble() < 0.6;
    final dropAt = win ? 1.0 : (grabbed ? 0.15 + _rng.nextDouble() * 0.7 : 0.0);
    if (win) {
      prizes.remove(p);
      _addPrize();
    } else if (grabbed) {
      // Herausgerutscht landet er etwas weiter links
      p.x = (p.x - (p.x - chuteWidth) * dropAt).clamp(chuteWidth + 0.8, clawBoxWidth - 0.8);
    }
    return ClawResult(prize: p, grabbed: grabbed, won: win, dropAt: dropAt, quality: quality);
  }
}
