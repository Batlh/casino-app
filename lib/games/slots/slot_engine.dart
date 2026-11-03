import 'dart:math';

import 'slot_data.dart';

const int reelCount = 5;
const int rowCount = 3;
const int lineCount = 10;

/// Symbolnummern entsprechen tool/tune_slot.py.
const int symMond = 0;
const int symStern = 1;
const int symKomet = 2;
const int symPlanet = 3;
const int symUfo = 4;
const int symRakete = 5;
const int symSonne = 6; // Joker
const int symLoch = 7; // Scatter

const List<List<int>> paylines = [
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

/// Vielfaches des Linieneinsatzes für 3, 4 und 5 gleiche Symbole.
const Map<int, List<int>> linePays = {
  symMond: [3, 8, 25],
  symStern: [4, 10, 30],
  symKomet: [5, 15, 50],
  symPlanet: [8, 25, 100],
  symUfo: [12, 50, 200],
  symRakete: [20, 100, 500],
  symSonne: [50, 250, 1000],
};

/// Vielfaches des Gesamteinsatzes für 3, 4 und 5 Schwarze Löcher.
const List<int> scatterPays = [2, 5, 20];
const int freeSpinsAward = 8;
const int freeSpinMultiplier = 2;

class LineWin {
  const LineWin(this.line, this.symbol, this.count, this.payout);
  final int line;
  final int symbol;
  final int count;
  final int payout;
}

class SpinResult {
  const SpinResult({
    required this.grid,
    required this.lineWins,
    required this.scatterCount,
    required this.scatterWin,
    required this.freeSpinsWon,
    required this.total,
  });

  /// grid[Walze][Reihe]
  final List<List<int>> grid;
  final List<LineWin> lineWins;
  final int scatterCount;
  final int scatterWin;
  final int freeSpinsWon;
  final int total;
}

/// Bewertet eine Linie. Liefert Symbol und Anzahl oder null.
({int symbol, int count, int multiplier})? evaluateLine(List<int> sym) {
  if (sym.first == symLoch) return null;
  var first = symSonne;
  for (final s in sym) {
    if (s != symSonne) {
      first = s;
      break;
    }
  }
  if (first == symLoch) first = symSonne;

  var count = 0;
  for (final s in sym) {
    if (s == first || s == symSonne) {
      count++;
    } else {
      break;
    }
  }
  var wildRun = 0;
  for (final s in sym) {
    if (s == symSonne) {
      wildRun++;
    } else {
      break;
    }
  }

  int pay(int symbol, int n) => n >= 3 ? linePays[symbol]![n - 3] : 0;
  final normal = pay(first, count);
  final wild = pay(symSonne, wildRun);
  if (normal == 0 && wild == 0) return null;
  return wild > normal
      ? (symbol: symSonne, count: wildRun, multiplier: wild)
      : (symbol: first, count: count, multiplier: normal);
}

class SlotEngine {
  SlotEngine({Random? rng}) : _rng = rng ?? Random.secure();

  final Random _rng;

  /// stake: Gesamteinsatz, durch 10 teilbar. multiplier: 2 in Freispielen.
  SpinResult spin(int stake, {int multiplier = 1}) {
    final grid = <List<int>>[];
    for (final strip in kosmosStrips) {
      final stop = _rng.nextInt(strip.length);
      grid.add([
        for (var row = 0; row < rowCount; row++)
          strip[(stop + row) % strip.length],
      ]);
    }
    return evaluateGrid(grid, stake, multiplier: multiplier);
  }

  static SpinResult evaluateGrid(
    List<List<int>> grid,
    int stake, {
    int multiplier = 1,
  }) {
    final lineBet = stake ~/ lineCount;
    final wins = <LineWin>[];
    var total = 0;
    for (var l = 0; l < paylines.length; l++) {
      final symbols = [
        for (var r = 0; r < reelCount; r++) grid[r][paylines[l][r]],
      ];
      final hit = evaluateLine(symbols);
      if (hit != null) {
        final payout = hit.multiplier * lineBet * multiplier;
        wins.add(LineWin(l, hit.symbol, hit.count, payout));
        total += payout;
      }
    }
    final scatters = grid.expand((c) => c).where((s) => s == symLoch).length;
    var scatterWin = 0;
    if (scatters >= 3) {
      scatterWin = scatterPays[min(scatters, 5) - 3] * stake * multiplier;
      total += scatterWin;
    }
    return SpinResult(
      grid: grid,
      lineWins: wins,
      scatterCount: scatters,
      scatterWin: scatterWin,
      freeSpinsWon: scatters >= 3 ? freeSpinsAward : 0,
      total: total,
    );
  }
}
