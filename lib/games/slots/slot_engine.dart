import 'dart:math';

/// Symbolnummern gelten für alle Slots. Null bis fünf steigen im Wert,
/// sechs ist der Joker, sieben der Scatter, acht die Geldmünze (Hold & Spin),
/// neun das Bonus-Symbol (Glücksrad).
const int symWild = 6;
const int symScatter = 7;
const int symCoin = 8;
const int symBonus = 9;

/// Wie Gewinne gezählt werden.
enum PayMode {
  /// Feste Gewinnlinien, ab der ersten Walze.
  lines,

  /// Wege: gleiche Symbole auf nebeneinanderliegenden Walzen, egal in welcher Reihe.
  ways,
}

/// Hold & Spin: Münzen bleiben liegen, jede neue Münze setzt die Respins zurück.
class HoldSpinRules {
  const HoldSpinRules({
    this.trigger = 6,
    this.respins = 3,
    required this.landChance,
    required this.values,
    required this.weights,
    this.jackpots = const {},
    required this.grand,
  });

  /// So viele Münzen starten die Runde.
  final int trigger;
  final int respins;

  /// Wahrscheinlichkeit je freiem Feld und Respin, dass eine Münze landet.
  final double landChance;

  /// Münzwerte in Zehnteln des Einsatzes und ihre Häufigkeit.
  final List<int> values;
  final List<int> weights;

  /// Besondere Münzwerte mit Namen, z. B. {200: 'Mini'}.
  final Map<int, String> jackpots;

  /// Grand-Jackpot in Zehnteln des Einsatzes, wenn alle Felder voll sind.
  final int grand;
}

enum WheelKind { coins, freeSpins, holdSpin }

class WheelSegment {
  const WheelSegment(this.kind, this.amount, this.weight);
  final WheelKind kind;

  /// Bei coins: Vielfaches des Einsatzes, bei freeSpins: Anzahl, bei holdSpin: Startmünzen.
  final int amount;
  final int weight;

  String get label => switch (kind) {
        WheelKind.coins => '${amount}x',
        WheelKind.freeSpins => '$amount Frei',
        WheelKind.holdSpin => 'Münzen',
      };
}

/// Glücksrad: drei Bonus-Symbole starten es.
class WheelRules {
  const WheelRules({this.trigger = 3, required this.segments});
  final int trigger;
  final List<WheelSegment> segments;
}

/// Regeln eines Slots. Grafik und Texte stehen in slot_games.dart.
class SlotRules {
  const SlotRules({
    required this.rows,
    this.lines = const [],
    required this.strips,
    required this.linePays,
    this.scatterPays = const [],
    this.freeSpins = 0,
    this.freeMultiplier = 1,
    this.expandWildInFree = false,
    this.wildDoubles = false,
    this.mode = PayMode.lines,
    this.waysAnywhere = false,
    this.waysDivisor = 1,
    this.heights,
    this.cascade = const [],
    this.freeCascade = const [],
    this.holdSpin,
    this.wheel,
    this.stickyWildsInFree = false,
  });

  /// In Freispielen bleiben gelandete Joker bis zum Ende der Freispielserie liegen.
  final bool stickyWildsInFree;

  /// Reihen; bei wechselnder Höhe (heights) die größte.
  final int rows;
  final List<List<int>> lines;

  /// Eine Liste je Walze.
  final List<List<int>> strips;

  /// Vielfaches des Linieneinsatzes (bei Wegen: je Weg), Index null steht für drei Gleiche.
  final Map<int, List<int>> linePays;

  /// Vielfaches des Gesamteinsatzes, Index null steht für drei Scatter.
  final List<int> scatterPays;
  final int freeSpins;
  final int freeMultiplier;

  /// In Freispielen füllt ein Joker auf den inneren Walzen die ganze Walze.
  final bool expandWildInFree;

  /// Jeder Joker in einer Gewinnlinie verdoppelt deren Gewinn.
  final bool wildDoubles;

  final PayMode mode;

  /// Wege zählen auch, wenn sie nicht auf der ersten Walze beginnen.
  final bool waysAnywhere;

  /// Bei Wegen: Gesamteinsatz geteilt durch diese Zahl ist der Einsatz je Weg.
  final int waysDivisor;

  /// Mögliche Reihenzahl je Walze und Dreh (wechselnde Höhe), null für feste Höhe.
  final List<int>? heights;

  /// Kaskaden: Gewinnsymbole verschwinden, neue fallen nach. Multiplikator je Stufe, leer ohne Kaskaden.
  final List<int> cascade;

  /// Multiplikatoren der Kaskaden in Freispielen, leer für dieselben wie im Grundspiel.
  final List<int> freeCascade;

  final HoldSpinRules? holdSpin;
  final WheelRules? wheel;

  int get reels => strips.length;
  int get lineCount => lines.length;
  bool get hasScatter => scatterPays.isNotEmpty;
  bool get cascades => cascade.isNotEmpty;

  /// Einsatzteiler: Linienzahl oder Wege-Teiler.
  int get betDivisor => mode == PayMode.lines ? lines.length : waysDivisor;

  int _pay(int symbol, int count) {
    final pays = linePays[symbol];
    if (pays == null) return 0;
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
    if (!linePays.containsKey(first)) return null;

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

/// Ein Gewinn: auf einer Linie (line ≥ 0) oder über Wege (line = -1).
class LineWin {
  const LineWin(this.line, this.symbol, this.count, this.payout, {this.ways = 1, this.start = 0, this.cells = const []});
  final int line;
  final int symbol;

  /// Anzahl Walzen.
  final int count;
  final int payout;

  /// Anzahl Wege (bei Linien 1).
  final int ways;

  /// Erste Walze des Gewinns.
  final int start;

  /// Beteiligte Felder als (Walze, Reihe).
  final List<(int, int)> cells;
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

/// Eine Stufe einer Drehung: Raster, Gewinne und Multiplikator. Ohne Kaskaden gibt es genau eine Stufe.
class CascadeStep {
  const CascadeStep({required this.grid, required this.wins, required this.multiplier, required this.win, this.falls});

  final List<List<int>> grid;
  final List<LineWin> wins;
  final int multiplier;

  /// Summe dieser Stufe, Multiplikator eingerechnet.
  final int win;

  /// Wie viele Reihen jedes Feld beim Nachrutschen gefallen ist (null bei der ersten Stufe).
  final List<List<int>>? falls;
}

/// Ablauf einer Hold-&-Spin-Runde: Münzen je Feld (Walze * Reihen + Reihe) nach jedem Respin.
class HoldSpinRound {
  const HoldSpinRound({required this.boards, required this.respinsLeft, required this.total, required this.full});

  /// Erster Eintrag: Startmünzen. Werte in Zehnteln des Einsatzes.
  final List<Map<int, int>> boards;
  final List<int> respinsLeft;
  final int total;
  final bool full;
}

class WheelSpin {
  const WheelSpin(this.index, this.segment, this.win);
  final int index;
  final WheelSegment segment;
  final int win;
}

/// Vollständige Drehung mit allen Funktionen.
class SpinOutcome {
  const SpinOutcome({
    required this.stops,
    required this.heights,
    required this.steps,
    required this.coins,
    required this.scatterCount,
    required this.scatterWin,
    required this.bonusCount,
    required this.freeSpinsWon,
    required this.total,
    this.holdSpin,
    this.wheel,
  });

  final List<int> stops;
  final List<int> heights;
  final List<CascadeStep> steps;

  /// Münzwerte im ersten Raster (Feld = Walze * rows + Reihe), Zehntel des Einsatzes.
  final Map<int, int> coins;
  final int scatterCount;
  final int scatterWin;
  final int bonusCount;
  final int freeSpinsWon;
  final HoldSpinRound? holdSpin;
  final WheelSpin? wheel;
  final int total;

  List<List<int>> get firstGrid => steps.first.grid;
  List<List<int>> get lastGrid => steps.last.grid;
  int get reelWin => steps.fold(0, (a, s) => a + s.win);
}

class SlotEngine {
  SlotEngine(this.rules, {Random? rng}) : _rng = rng ?? Random.secure();

  final SlotRules rules;
  final Random _rng;

  /// Felder (Walze, Reihe) mit liegenbleibenden Jokern der laufenden Freispielserie.
  final Set<(int, int)> stickyWilds = {};

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

  List<List<int>> _expand(List<List<int>> grid, bool free) {
    final shown = [for (final c in grid) c.toList()];
    if (free && rules.expandWildInFree) {
      for (var r = 1; r < rules.reels - 1; r++) {
        if (shown[r].contains(symWild)) {
          shown[r] = List.filled(shown[r].length, symWild);
        }
      }
    }
    return shown;
  }

  SpinResult evaluateGrid(
    List<List<int>> grid,
    int stake, {
    bool free = false,
    List<int> stops = const [],
  }) {
    final scatters = grid.expand((c) => c).where((s) => s == symScatter).length;
    final shown = _expand(grid, free);
    final multiplier = free ? rules.freeMultiplier : 1;
    final wins = winsOf(shown, stake, multiplier);
    var total = wins.fold(0, (a, w) => a + w.payout);
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

  /// Alle Gewinne eines Rasters, Multiplikator eingerechnet.
  List<LineWin> winsOf(List<List<int>> shown, int stake, int multiplier) =>
      rules.mode == PayMode.lines ? _lineWins(shown, stake, multiplier) : _wayWins(shown, stake, multiplier);

  List<LineWin> _lineWins(List<List<int>> shown, int stake, int multiplier) {
    final lineBet = stake ~/ rules.lineCount;
    final wins = <LineWin>[];
    for (var l = 0; l < rules.lines.length; l++) {
      final line = rules.lines[l];
      final symbols = [for (var r = 0; r < rules.reels; r++) shown[r][line[r]]];
      final hit = rules.evaluateLine(symbols);
      if (hit != null) {
        final payout = hit.multiplier * lineBet * multiplier;
        wins.add(LineWin(l, hit.symbol, hit.count, payout, cells: [for (var r = 0; r < hit.count; r++) (r, line[r])]));
      }
    }
    return wins;
  }

  /// Wege: je Symbol jede längste Folge nebeneinanderliegender Walzen, auf denen es (oder ein Joker) liegt.
  /// Der Joker ersetzt nur, er zahlt bei Wegen nicht selbst. Eine Folge braucht mindestens ein echtes Symbol.
  List<LineWin> _wayWins(List<List<int>> shown, int stake, int multiplier) {
    final wins = <LineWin>[];
    final reels = rules.reels;
    for (final sym in rules.linePays.keys) {
      if (sym == symWild) continue;
      var r = 0;
      while (r < reels) {
        if (!_hasOrWild(shown[r], sym)) {
          if (!rules.waysAnywhere) break;
          r++;
          continue;
        }
        var end = r;
        while (end < reels && _hasOrWild(shown[end], sym)) {
          end++;
        }
        final n = end - r;
        final real = [for (var i = r; i < end; i++) ...shown[i]].contains(sym);
        final pay = rules._pay(sym, n);
        if (real && pay > 0) {
          var ways = 1;
          final cells = <(int, int)>[];
          for (var i = r; i < end; i++) {
            var c = 0;
            for (var row = 0; row < shown[i].length; row++) {
              if (shown[i][row] == sym || shown[i][row] == symWild) {
                c++;
                cells.add((i, row));
              }
            }
            ways *= c;
          }
          final payout = pay * ways * stake * multiplier ~/ rules.waysDivisor;
          wins.add(LineWin(-1, sym, n, payout, ways: ways, start: r, cells: cells));
        }
        if (!rules.waysAnywhere) break;
        r = end;
      }
    }
    return wins;
  }

  static bool _hasOrWild(List<int> reel, int sym) {
    for (final s in reel) {
      if (s == sym || s == symWild) return true;
    }
    return false;
  }

  int _coinValue() {
    final h = rules.holdSpin!;
    var x = _rng.nextInt(h.weights.fold(0, (a, b) => a + b));
    for (var i = 0; i < h.values.length; i++) {
      x -= h.weights[i];
      if (x < 0) return h.values[i];
    }
    return h.values.last;
  }

  /// Eine ganze Drehung mit Kaskaden, Hold & Spin und Glücksrad.
  SpinOutcome play(int stake, {bool free = false}) {
    final heights = <int>[];
    final stops = <int>[];
    final grid = <List<int>>[];
    for (final strip in rules.strips) {
      final hs = rules.heights;
      final h = hs == null ? rules.rows : hs[_rng.nextInt(hs.length)];
      final stop = _rng.nextInt(strip.length);
      heights.add(h);
      stops.add(stop);
      grid.add([for (var row = 0; row < h; row++) strip[(stop + row) % strip.length]]);
    }
    if (!free) {
      stickyWilds.clear();
    } else if (rules.stickyWildsInFree) {
      // Liegende Joker übernehmen, neue Joker kommen dazu
      for (final (r, row) in stickyWilds) {
        if (row < grid[r].length) grid[r][row] = symWild;
      }
      for (var r = 0; r < grid.length; r++) {
        for (var row = 0; row < grid[r].length; row++) {
          if (grid[r][row] == symWild) stickyWilds.add((r, row));
        }
      }
    }
    return playGrid(grid, stake, free: free, stops: stops);
  }

  /// Wertet ein vorgegebenes Raster mit allen Funktionen aus (für Tests und die Drehung selbst).
  SpinOutcome playGrid(List<List<int>> grid, int stake, {bool free = false, List<int> stops = const []}) {
    final reels = rules.reels;
    final heights = [for (final c in grid) c.length];
    final coins = <int, int>{};
    if (rules.holdSpin != null) {
      for (var r = 0; r < reels; r++) {
        for (var row = 0; row < grid[r].length; row++) {
          if (grid[r][row] == symCoin) coins[r * rules.rows + row] = _coinValue();
        }
      }
    }

    final ladder = free && rules.freeCascade.isNotEmpty ? rules.freeCascade : rules.cascade;
    final baseMult = free ? rules.freeMultiplier : 1;
    // Lesezeiger je Walze für nachrutschende Symbole: oberhalb des Stopps
    final above = [for (var r = 0; r < reels; r++) stops.isEmpty ? 0 : stops[r]];
    final steps = <CascadeStep>[];
    var shown = _expand(grid, free);
    List<List<int>>? falls;
    while (true) {
      final mult = ladder.isEmpty ? baseMult : baseMult * ladder[min(steps.length, ladder.length - 1)];
      final wins = winsOf(shown, stake, mult);
      final win = wins.fold(0, (a, w) => a + w.payout);
      steps.add(CascadeStep(grid: shown, wins: wins, multiplier: mult, win: win, falls: falls));
      if (ladder.isEmpty || wins.isEmpty || steps.length > 50) break;
      final hit = {for (final w in wins) ...w.cells};
      final next = <List<int>>[];
      final fall = <List<int>>[];
      for (var r = 0; r < reels; r++) {
        final col = shown[r];
        final kept = <int>[];
        final keptFall = <int>[];
        for (var row = 0; row < col.length; row++) {
          if (hit.contains((r, row))) continue;
          kept.add(col[row]);
          // fällt um die Zahl der entfernten Felder darunter
          var below = 0;
          for (var b = row + 1; b < col.length; b++) {
            if (hit.contains((r, b))) below++;
          }
          keptFall.add(below);
        }
        final k = col.length - kept.length;
        final strip = rules.strips[r];
        final fresh = <int>[];
        for (var i = 0; i < k; i++) {
          above[r] = (above[r] - 1) % strip.length;
          fresh.insert(0, strip[above[r]]);
        }
        next.add([...fresh, ...kept]);
        fall.add([for (var i = 0; i < k; i++) k, ...keptFall]);
      }
      shown = _expand(next, free);
      falls = fall;
    }

    var total = steps.fold(0, (a, s) => a + s.win);
    // Streu- und Bonussymbole verschwinden in Kaskaden nie, es können nur neue nachfallen.
    // Gezählt wird darum am Ende, was zuletzt zu sehen ist.
    final last = steps.last.grid.expand((c) => c);
    final scatters = last.where((s) => s == symScatter).length;
    final bonus = last.where((s) => s == symBonus).length;
    var scatterWin = 0;
    var freeWon = 0;
    if (rules.hasScatter && scatters >= 3) {
      final i = min(scatters - 3, rules.scatterPays.length - 1);
      scatterWin = rules.scatterPays[i] * stake * baseMult;
      total += scatterWin;
      freeWon = rules.freeSpins;
    }

    HoldSpinRound? hold;
    final h = rules.holdSpin;
    if (h != null && coins.length >= h.trigger) {
      hold = runHoldSpin(Map.of(coins), stake);
    }

    WheelSpin? wheel;
    final w = rules.wheel;
    if (w != null && bonus >= w.trigger) {
      final total = w.segments.fold(0, (a, s) => a + s.weight);
      var x = _rng.nextInt(total);
      var index = 0;
      while (x >= w.segments[index].weight) {
        x -= w.segments[index].weight;
        index++;
      }
      final seg = w.segments[index];
      var win = 0;
      switch (seg.kind) {
        case WheelKind.coins:
          win = seg.amount * stake;
        case WheelKind.freeSpins:
          freeWon += seg.amount;
        case WheelKind.holdSpin:
          final start = <int, int>{};
          final cells = [
            for (var r = 0; r < reels; r++)
              for (var row = 0; row < rules.rows; row++) r * rules.rows + row,
          ]..shuffle(_rng);
          for (final c in cells.take(seg.amount)) {
            start[c] = _coinValue();
          }
          hold = runHoldSpin(start, stake);
      }
      wheel = WheelSpin(index, seg, win);
    }

    total += (hold?.total ?? 0) + (wheel?.win ?? 0);
    return SpinOutcome(
      stops: stops,
      heights: heights,
      steps: steps,
      coins: coins,
      scatterCount: scatters,
      scatterWin: scatterWin,
      bonusCount: bonus,
      freeSpinsWon: freeWon,
      holdSpin: hold,
      wheel: wheel,
      total: total,
    );
  }

  /// Hold & Spin ab den Startmünzen. Werte in Zehnteln des Einsatzes.
  HoldSpinRound runHoldSpin(Map<int, int> start, int stake) {
    final h = rules.holdSpin!;
    final cells = rules.reels * rules.rows;
    final boards = [Map.of(start)];
    final left = [h.respins];
    var coins = Map.of(start);
    var respins = h.respins;
    while (respins > 0 && coins.length < cells) {
      var landed = false;
      final next = Map.of(coins);
      for (var c = 0; c < cells; c++) {
        if (next.containsKey(c)) continue;
        if (_rng.nextDouble() < h.landChance) {
          next[c] = _coinValue();
          landed = true;
        }
      }
      respins = landed ? h.respins : respins - 1;
      coins = next;
      boards.add(Map.of(coins));
      left.add(respins);
    }
    final full = coins.length >= cells;
    final tenths = coins.values.fold(0, (a, b) => a + b) + (full ? h.grand : 0);
    return HoldSpinRound(boards: boards, respinsLeft: left, total: tenths * stake ~/ 10, full: full);
  }
}
