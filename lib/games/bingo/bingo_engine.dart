import 'dart:math';

/// Bingo mit 75 Kugeln (USA, 5×5 mit freiem Feld und Mustern) und 90 Kugeln (UK, 3×9, eine Reihe, zwei Reihen,
/// volle Karte). Reine Regeln ohne Oberfläche, damit das Spiel später auch über das Netzwerk laufen kann:
/// Der Gastgeber führt diese Klasse, alle anderen bekommen nur Kugeln und Ergebnisse.

enum BingoVariant { us75, uk90 }

/// Gewinnmuster bei 75 Kugeln.
enum BingoPattern { line, corners, x, full }

const bingoPatternNames = {
  BingoPattern.line: 'Linie',
  BingoPattern.corners: 'Vier Ecken',
  BingoPattern.x: 'Großes X',
  BingoPattern.full: 'Volle Karte',
};

/// Eine Karte. Zellen als Liste von Zeilen; 0 ist leer (90er) bzw. das freie Feld in der Mitte (75er).
class BingoCard {
  BingoCard(this.rows);
  final List<List<int>> rows;

  int get height => rows.length;
  int get width => rows.first.length;
  Iterable<int> get numbers => rows.expand((r) => r).where((n) => n > 0);

  bool covered(int row, int col, Set<int> drawn) {
    final n = rows[row][col];
    return n == 0 ? true : drawn.contains(n);
  }

  /// Fehlende Zahlen bis zum nächsten Gewinn (für die Anzeige „noch 2“).
  int missing(BingoVariant v, Set<int> drawn, {BingoPattern pattern = BingoPattern.line, int stage = 0}) {
    if (v == BingoVariant.us75) {
      return _patterns75(pattern).map((cells) => cells.where((c) => !covered(c.$1, c.$2, drawn)).length).reduce(min);
    }
    // 90: Stufe 0 eine Reihe, 1 zwei Reihen, 2 alle drei
    final perRow = [for (final r in rows) r.where((n) => n > 0 && !drawn.contains(n)).length]..sort();
    return perRow.take(stage + 1).fold(0, (a, b) => a + b);
  }

  bool wins(BingoVariant v, Set<int> drawn, {BingoPattern pattern = BingoPattern.line, int stage = 0}) =>
      missing(v, drawn, pattern: pattern, stage: stage) == 0;

  /// Felder (Zeile, Spalte) der möglichen Gewinnmuster bei 75 Kugeln.
  List<List<(int, int)>> _patterns75(BingoPattern p) {
    const n = 5;
    switch (p) {
      case BingoPattern.line:
        return [
          for (var r = 0; r < n; r++) [for (var c = 0; c < n; c++) (r, c)],
          for (var c = 0; c < n; c++) [for (var r = 0; r < n; r++) (r, c)],
          [for (var i = 0; i < n; i++) (i, i)],
          [for (var i = 0; i < n; i++) (i, n - 1 - i)],
        ];
      case BingoPattern.corners:
        return [
          [(0, 0), (0, 4), (4, 0), (4, 4)],
        ];
      case BingoPattern.x:
        return [
          {for (var i = 0; i < n; i++) (i, i), for (var i = 0; i < n; i++) (i, n - 1 - i)}.toList(),
        ];
      case BingoPattern.full:
        return [
          [for (var r = 0; r < n; r++) for (var c = 0; c < n; c++) (r, c)],
        ];
    }
  }

  /// Felder, die zum Gewinn gehören (zum Hervorheben), leer wenn nicht gewonnen.
  Set<(int, int)> winningCells(BingoVariant v, Set<int> drawn, {BingoPattern pattern = BingoPattern.line, int stage = 0}) {
    if (v == BingoVariant.us75) {
      for (final cells in _patterns75(pattern)) {
        if (cells.every((c) => covered(c.$1, c.$2, drawn))) return cells.toSet();
      }
      return {};
    }
    final full = [
      for (var r = 0; r < height; r++)
        if (rows[r].every((n) => n == 0 || drawn.contains(n))) r,
    ];
    if (full.length < stage + 1) return {};
    return {
      for (final r in full.take(stage + 1))
        for (var c = 0; c < width; c++)
          if (rows[r][c] > 0) (r, c),
    };
  }
}

/// Karte mit 75 Kugeln: Spalten B 1–15, I 16–30, N 31–45, G 46–60, O 61–75, Mitte frei.
BingoCard makeCard75(Random rng) {
  final cols = [
    for (var c = 0; c < 5; c++) ([for (var i = 1; i <= 15; i++) c * 15 + i]..shuffle(rng)).take(5).toList(),
  ];
  return BingoCard([
    for (var r = 0; r < 5; r++) [for (var c = 0; c < 5; c++) r == 2 && c == 2 ? 0 : cols[c][r]],
  ]);
}

/// Karte mit 90 Kugeln: 3 Reihen × 9 Spalten, je Reihe 5 Zahlen, Spalte 1 hat 1–9, Spalte 9 hat 80–90.
BingoCard makeCard90(Random rng) {
  while (true) {
    // Jede Reihe wählt 5 von 9 Spalten; jede Spalte braucht mindestens eine Zahl
    final layout = [for (var r = 0; r < 3; r++) ([for (var c = 0; c < 9; c++) c]..shuffle(rng)).take(5).toSet()];
    if (List.generate(9, (c) => layout.any((row) => row.contains(c))).contains(false)) continue;
    final rows = List.generate(3, (_) => List.filled(9, 0));
    for (var c = 0; c < 9; c++) {
      final lo = c == 0 ? 1 : c * 10;
      final hi = c == 8 ? 90 : c * 10 + 9;
      final used = [for (var r = 0; r < 3; r++) if (layout[r].contains(c)) r];
      final nums = ([for (var n = lo; n <= hi; n++) n]..shuffle(rng)).take(used.length).toList()..sort();
      for (var k = 0; k < used.length; k++) {
        rows[used[k]][c] = nums[k];
      }
    }
    return BingoCard(rows);
  }
}

class BingoPlayer {
  BingoPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  final List<BingoCard> cards = [];
}

/// Ein Gewinn: wer, mit welcher Karte, in welcher Stufe, wie viel.
class BingoWin {
  const BingoWin(this.player, this.card, this.stage, this.amount);
  final BingoPlayer player;
  final BingoCard card;
  final int stage;
  final int amount;
}

class BingoGame {
  BingoGame({
    required this.variant,
    required this.players,
    required this.cardPrice,
    this.pattern = BingoPattern.line,
    this.payout = 0.85,
    Random? rng,
  }) : _rng = rng ?? Random.secure() {
    final max = variant == BingoVariant.us75 ? 75 : 90;
    _balls = [for (var i = 1; i <= max; i++) i]..shuffle(_rng);
    pot = (players.fold(0, (a, p) => a + p.cards.length) * cardPrice * payout).floor();
  }

  final BingoVariant variant;
  final List<BingoPlayer> players;
  final int cardPrice;
  final BingoPattern pattern;
  final double payout;
  final Random _rng;
  late final List<int> _balls;
  late final int pot;

  final List<int> called = [];
  Set<int> get drawn => called.toSet();
  final List<BingoWin> wins = [];

  /// 90 Kugeln: 0 eine Reihe, 1 zwei Reihen, 2 volle Karte. 75 Kugeln: immer 0.
  int stage = 0;
  bool get over => variant == BingoVariant.us75 ? wins.isNotEmpty : stage > 2;

  int get stages => variant == BingoVariant.us75 ? 1 : 3;

  /// Anteil des Pots je Stufe.
  List<double> get stageShares => variant == BingoVariant.us75 ? const [1.0] : const [0.15, 0.25, 0.6];

  int prizeFor(int s) => (pot * stageShares[s]).floor();

  String stageName(int s) => variant == BingoVariant.us75
      ? bingoPatternNames[pattern]!
      : const ['Eine Reihe', 'Zwei Reihen', 'Volle Karte'][s];

  static List<BingoCard> dealCards(BingoVariant v, int count, Random rng) =>
      [for (var i = 0; i < count; i++) v == BingoVariant.us75 ? makeCard75(rng) : makeCard90(rng)];

  /// Zieht die nächste Kugel und wertet aus. Liefert die neuen Gewinne (mehrere bei Gleichstand).
  List<BingoWin> callNext() {
    if (over || called.length >= _balls.length) return const [];
    called.add(_balls[called.length]);
    return _evaluate();
  }

  List<BingoWin> _evaluate() {
    final out = <BingoWin>[];
    // Bei 90 Kugeln kann eine Kugel mehrere Stufen auf einmal abschließen
    while (!over) {
      final d = drawn;
      final hits = [
        for (final p in players)
          for (final c in p.cards)
            if (c.wins(variant, d, pattern: pattern, stage: stage)) (p, c),
      ];
      if (hits.isEmpty) break;
      final share = prizeFor(stage) ~/ hits.length;
      for (final (p, c) in hits) {
        out.add(BingoWin(p, c, stage, share));
      }
      stage++;
      if (variant == BingoVariant.us75) break;
    }
    wins.addAll(out);
    return out;
  }
}
