import 'dart:math';

const kniffelCategories = [
  'Einer', 'Zweier', 'Dreier', 'Vierer', 'Fünfer', 'Sechser', //
  'Dreierpasch', 'Viererpasch', 'Full House', 'Kleine Straße', 'Große Straße', 'Kniffel', 'Chance',
];

const kniffelUpperBonus = 35;
const kniffelUpperNeeded = 63;
const kniffelExtraBonus = 50;

/// Punkte der Würfel [d] in Kategorie [cat].
int kniffelScore(int cat, List<int> d) {
  final counts = List.filled(7, 0);
  for (final v in d) {
    counts[v]++;
  }
  final sum = d.fold(0, (a, b) => a + b);
  bool run(int len) {
    var best = 0;
    var cur = 0;
    for (var v = 1; v <= 6; v++) {
      cur = counts[v] > 0 ? cur + 1 : 0;
      best = max(best, cur);
    }
    return best >= len;
  }

  if (cat < 6) return counts[cat + 1] * (cat + 1);
  final most = counts.reduce(max);
  return switch (cat) {
    6 => most >= 3 ? sum : 0,
    7 => most >= 4 ? sum : 0,
    8 => counts.contains(3) && counts.contains(2) ? 25 : 0,
    9 => run(4) ? 30 : 0,
    10 => run(5) ? 40 : 0,
    11 => most == 5 ? 50 : 0,
    _ => sum,
  };
}

class KniffelGame {
  KniffelGame(this.players, {Random? rng})
      : _rng = rng ?? Random(),
        scores = List.generate(players, (_) => List<int?>.filled(13, null)),
        extra = List.filled(players, 0);

  KniffelGame._(this.players, this.scores, this.extra, this._rng);

  final int players;
  final Random _rng;
  final List<List<int?>> scores;

  /// Zusätzliche Kniffel nach dem ersten (je 50).
  final List<int> extra;
  List<int> dice = [1, 1, 1, 1, 1];
  List<bool> held = List.filled(5, false);

  /// Würfe, die im Zug noch übrig sind. 3 heißt: noch nicht gewürfelt.
  int rollsLeft = 3;
  int current = 0;

  bool get over => scores.every((s) => s.every((v) => v != null));
  bool get rolled => rollsLeft < 3;

  bool roll() {
    if (rollsLeft == 0 || over) return false;
    for (var i = 0; i < 5; i++) {
      if (!held[i] || rollsLeft == 3) dice[i] = 1 + _rng.nextInt(6);
    }
    if (rollsLeft == 3) held = List.filled(5, false);
    rollsLeft--;
    return true;
  }

  void toggle(int i) {
    if (!rolled || rollsLeft == 0) return;
    held[i] = !held[i];
  }

  bool score(int cat) {
    if (!rolled || scores[current][cat] != null) return false;
    if (kniffelScore(11, dice) == 50 && scores[current][11] == 50) extra[current] += kniffelExtraBonus;
    scores[current][cat] = kniffelScore(cat, dice);
    current = (current + 1) % players;
    rollsLeft = 3;
    held = List.filled(5, false);
    return true;
  }

  int upper(int p) => [for (var c = 0; c < 6; c++) scores[p][c] ?? 0].fold(0, (a, b) => a + b);
  int bonus(int p) => upper(p) >= kniffelUpperNeeded ? kniffelUpperBonus : 0;
  int lower(int p) => [for (var c = 6; c < 13; c++) scores[p][c] ?? 0].fold(0, (a, b) => a + b);
  int total(int p) => upper(p) + bonus(p) + lower(p) + extra[p];

  // Computer -----------------------------------------------------------------

  static const _typical = [2, 5, 8, 11, 14, 17, 17, 9, 14, 20, 14, 8, 22];

  /// Welche Würfel behalten?
  List<bool> botHolds() {
    final counts = List.filled(7, 0);
    for (final v in dice) {
      counts[v]++;
    }
    final open = scores[current];
    // Straße in Reichweite?
    for (final run in const [
      [1, 2, 3, 4, 5],
      [2, 3, 4, 5, 6],
      [1, 2, 3, 4],
      [2, 3, 4, 5],
      [3, 4, 5, 6],
    ]) {
      final have = run.where((v) => counts[v] > 0).length;
      final need = run.length == 5 ? open[10] == null : open[9] == null || open[10] == null;
      if (need && have >= run.length - 1 && have >= 4) {
        final keep = List.filled(5, false);
        final used = <int>{};
        for (var i = 0; i < 5; i++) {
          if (run.contains(dice[i]) && used.add(dice[i])) keep[i] = true;
        }
        return keep;
      }
    }
    // Sonst den häufigsten Wert (bei Gleichstand den höheren), möglichst einen, der oben noch fehlt
    var best = 6;
    var bestScore = -1.0;
    for (var v = 1; v <= 6; v++) {
      final s = counts[v] * 10 + v + (open[v - 1] == null ? 4 : 0);
      if (counts[v] > 0 && s > bestScore) {
        bestScore = s.toDouble();
        best = v;
      }
    }
    return [for (final v in dice) v == best];
  }

  /// Beste offene Kategorie nach Punkten im Vergleich zum Üblichen.
  int botCategory() {
    var best = -1;
    var bestV = -1 << 30;
    for (var c = 0; c < 13; c++) {
      if (scores[current][c] != null) continue;
      final s = kniffelScore(c, dice);
      var v = s - _typical[c];
      if (c < 6 && s >= (c + 1) * 3) v += 6;
      if (c == 11 && s == 50) v += 100;
      if (c == 12) v -= 6;
      if (v > bestV) {
        bestV = v;
        best = c;
      }
    }
    return best;
  }

  /// Ist der Wurf gut genug, um sofort zu schreiben?
  bool botStop() {
    final c = botCategory();
    final s = kniffelScore(c, dice);
    return rollsLeft == 0 || (c >= 8 && c <= 11 && s > 0) || (c < 6 && s >= (c + 1) * 4);
  }

  Map<String, Object?> toJson() => {
        'players': players,
        'scores': scores,
        'extra': extra,
        'dice': dice,
        'held': held,
        'rolls': rollsLeft,
        'current': current,
      };

  static KniffelGame fromJson(Map<String, dynamic> j, {Random? rng}) => KniffelGame._(
        j['players'] as int,
        [for (final l in j['scores'] as List) [for (final v in l as List) v as int?]],
        [for (final v in j['extra'] as List) v as int],
        rng ?? Random(),
      )
        ..dice = [for (final v in j['dice'] as List) v as int]
        ..held = [for (final v in j['held'] as List) v as bool]
        ..rollsLeft = j['rolls'] as int
        ..current = j['current'] as int;
}
