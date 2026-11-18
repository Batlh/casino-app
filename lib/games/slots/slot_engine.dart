import 'dart:math';

/// Symbolnummern gelten für alle Slots. Null bis fünf steigen im Wert,
/// sechs ist der Joker, sieben der Scatter.
const int symWild = 6;
const int symScatter = 7;

/// Regeln eines Slots. Grafik und Texte stehen in slot_games.dart.
class SlotRules {
  const SlotRules({
    required this.rows,
    required this.lines,
    required this.strips,
    required this.linePays,
    this.scatterPays = const [],
    this.freeSpins = 0,
    this.freeMultiplier = 1,
    this.expandWildInFree = false,
    this.wildDoubles = false,
  });

  final int rows;
  final List<List<int>> lines;

  /// Eine Liste je Walze.
  final List<List<int>> strips;

  /// Vielfaches des Linieneinsatzes, Index null steht für drei Gleiche.
  final Map<int, List<int>> linePays;

  /// Vielfaches des Gesamteinsatzes, Index null steht für drei Scatter.
  final List<int> scatterPays;
  final int freeSpins;
  final int freeMultiplier;

  /// In Freispielen füllt ein Joker auf den inneren Walzen die ganze Walze.
  final bool expandWildInFree;

  /// Jeder Joker in einer Gewinnlinie verdoppelt deren Gewinn.
  final bool wildDoubles;

  int get reels => strips.length;
  int get lineCount => lines.length;
  bool get hasScatter => scatterPays.isNotEmpty;

  int _pay(int symbol, int count) {
    final pays = linePays[symbol]!;
    final i = count - 3;
    return i >= 0 && i < pays.length ? pays[i] : 0;
  }

  /// Bewertet eine Linie. Liefert Symbol, Anzahl und Vielfaches oder null.
  ({int symbol, int count, int multiplier})? evaluateLine(List<int> sym) {
    if (sym.first == symScatter) return null;
    var first = symWild;
    for (final s in sym) {
      if (s != symWild) {
        first = s;
        break;
      }
    }
    if (first == symScatter) first = symWild;

    var count = 0;
    var wilds = 0;
    for (final s in sym) {
      if (s == first || s == symWild) {
        count++;
        if (s == symWild) wilds++;
      } else {
        break;
      }
    }
    var wildRun = 0;
    for (final s in sym) {
      if (s == symWild) {
        wildRun++;
      } else {
        break;
      }
    }

    var normal = _pay(first, count);
    if (wildDoubles && first != symWild) normal <<= wilds;
    final wild = _pay(symWild, wildRun);
    if (normal == 0 && wild == 0) return null;
    return wild > normal
        ? (symbol: symWild, count: wildRun, multiplier: wild)
        : (symbol: first, count: count, multiplier: normal);
  }
}

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
    this.stops = const [],
  });

  /// grid[Walze][Reihe], so wie gewertet (in Freispielen schon mit ausgefüllten Joker-Walzen).
  final List<List<int>> grid;

  /// Stopposition je Walze auf dem Walzenband (oberste sichtbare Reihe), leer bei vorgegebenem Raster.
  final List<int> stops;
  final List<LineWin> lineWins;
  final int scatterCount;
  final int scatterWin;
  final int freeSpinsWon;
  final int total;
}

class SlotEngine {
  SlotEngine(this.rules, {Random? rng}) : _rng = rng ?? Random.secure();

  final SlotRules rules;
  final Random _rng;

  /// stake: Gesamteinsatz, durch die Linienzahl teilbar.
  SpinResult spin(int stake, {bool free = false}) {
    final grid = <List<int>>[];
    final stops = <int>[];
    for (final strip in rules.strips) {
      final stop = _rng.nextInt(strip.length);
      stops.add(stop);
      grid.add([
        for (var row = 0; row < rules.rows; row++)
          strip[(stop + row) % strip.length],
      ]);
    }
    return evaluateGrid(grid, stake, free: free, stops: stops);
  }

  SpinResult evaluateGrid(
    List<List<int>> grid,
    int stake, {
    bool free = false,
    List<int> stops = const [],
  }) {
    final scatters = grid.expand((c) => c).where((s) => s == symScatter).length;
    final shown = [for (final c in grid) c.toList()];
    if (free && rules.expandWildInFree) {
      for (var r = 1; r < rules.reels - 1; r++) {
        if (shown[r].contains(symWild)) {
          shown[r] = List.filled(rules.rows, symWild);
        }
      }
    }

    final multiplier = free ? rules.freeMultiplier : 1;
    final lineBet = stake ~/ rules.lineCount;
    final wins = <LineWin>[];
    var total = 0;
    for (var l = 0; l < rules.lines.length; l++) {
      final symbols = [
        for (var r = 0; r < rules.reels; r++) shown[r][rules.lines[l][r]],
      ];
      final hit = rules.evaluateLine(symbols);
      if (hit != null) {
        final payout = hit.multiplier * lineBet * multiplier;
        wins.add(LineWin(l, hit.symbol, hit.count, payout));
        total += payout;
      }
    }
    var scatterWin = 0;
    var freeWon = 0;
    if (rules.hasScatter && scatters >= 3) {
      final i = min(scatters - 3, rules.scatterPays.length - 1);
      scatterWin = rules.scatterPays[i] * stake * multiplier;
      total += scatterWin;
      freeWon = rules.freeSpins;
    }
    return SpinResult(
      grid: shown,
      lineWins: wins,
      scatterCount: scatters,
      scatterWin: scatterWin,
      freeSpinsWon: freeWon,
      total: total,
      stops: stops,
    );
  }
}
