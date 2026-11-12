import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';

/// Joker-Stein (für die Varianten mit Jokern).
const jokerTile = jokerKind;

bool isBonusTile(int t) => (t >= firstFlower && t < jokerTile) || t == flowerJoker || t == emperorTile || t == empressTile;

/// Zählt die normalen Steine 0 bis 33; Joker und Bonussteine bleiben außen vor.
List<int> countsPlain(Iterable<int> tiles) {
  final c = List.filled(tileKinds, 0);
  for (final t in tiles) {
    if (t < tileKinds) c[t]++;
  }
  return c;
}

int jokersIn(Iterable<int> tiles) => tiles.where(isJokerTile).length;

/// Shanten für Hände mit [sets] Gruppen plus Paar (4 bei 13 Steinen, 5 bei 16).
/// Joker zählen als bester Stein, das ist für die Computer genau genug.
int shantenN(List<int> counts, int openMelds, int sets, {int jokers = 0, bool sevenPairs = false, bool orphans = false}) {
  final c = counts.toList();
  var best = 2 * sets;
  void search(int i, int s, int partials, int pair) {
    while (i < tileKinds && c[i] == 0) {
      i++;
    }
    if (i >= tileKinds) {
      final total = s + openMelds;
      var p = partials;
      if (total + p > sets) p = sets - total;
      final v = 2 * sets - 2 * total - p - pair;
      if (v < best) best = v;
      return;
    }
    if (c[i] >= 3) {
      c[i] -= 3;
      search(i, s + 1, partials, pair);
      c[i] += 3;
    }
    final seqOk = i < 27 && i % 9 <= 6;
    if (seqOk && c[i + 1] > 0 && c[i + 2] > 0) {
      c[i]--;
      c[i + 1]--;
      c[i + 2]--;
      search(i, s + 1, partials, pair);
      c[i]++;
      c[i + 1]++;
      c[i + 2]++;
    }
    if (c[i] >= 2) {
      c[i] -= 2;
      if (pair == 0) search(i, s, partials, 1);
      search(i, s, partials + 1, pair);
      c[i] += 2;
    }
    if (i < 27 && i % 9 <= 7 && c[i + 1] > 0) {
      c[i]--;
      c[i + 1]--;
      search(i, s, partials + 1, pair);
      c[i]++;
      c[i + 1]++;
    }
    if (seqOk && c[i + 2] > 0) {
      c[i]--;
      c[i + 2]--;
      search(i, s, partials + 1, pair);
      c[i]++;
      c[i + 2]++;
    }
    c[i]--;
    search(i, s, partials, pair);
    c[i]++;
  }

  search(0, 0, 0, 0);
  if (openMelds == 0 && sets == 4) {
    if (sevenPairs) best = min(best, shantenChiitoi(counts));
    if (orphans) best = min(best, shantenKokushi(counts));
  }
  return max(-1, best - jokers);
}

/// Alle Zerlegungen in Paar und Gruppen, Joker füllen Lücken.
/// Gibt (Paar, Gruppen, Joker-Ersatz) zurück; der Ersatz listet, welche Steine die Joker darstellen.
List<(int, List<Group>, List<int>)> decompositionsJ(List<int> counts, int jokers, {int limit = 300}) =>
    decompositionsT(counts, List.filled(jokers, jokerTile), limit: limit);

/// Wie [decompositionsJ], aber jeder Joker ersetzt nur die Steine seiner Art (Vietnam).
/// Gebraucht wird immer der Joker mit der kleinsten Reichweite, die allgemeinen bleiben für später.
List<(int, List<Group>, List<int>)> decompositionsT(List<int> counts, List<int> jokers, {int limit = 300}) {
  final out = <(int, List<Group>, List<int>)>[];
  final c = counts.toList();
  final groups = <Group>[];
  final subs = <int>[];
  final pool = [...jokers]..sort((a, b) => jokerReach(a) - jokerReach(b));
  var j = pool.length;

  /// Nimmt für jeden Stein in [tiles] einen passenden Joker; null, wenn es nicht geht.
  List<int>? take(List<int> tiles) {
    final taken = <int>[];
    for (final x in tiles) {
      final i = pool.indexWhere((k) => jokerCovers(k, x));
      if (i < 0) {
        pool.addAll(taken);
        pool.sort((a, b) => jokerReach(a) - jokerReach(b));
        return null;
      }
      taken.add(pool.removeAt(i));
    }
    j -= taken.length;
    return taken;
  }

  void giveBack(List<int> taken) {
    pool
      ..addAll(taken)
      ..sort((a, b) => jokerReach(a) - jokerReach(b));
    j += taken.length;
  }

  /// Ein Stein, den alle übrigen Joker darstellen können (für Gruppen nur aus Jokern).
  int? common(int not) {
    for (final t in [33, 32, 31, 27, 28, 29, 30, for (var x = 0; x < 27; x++) x]) {
      if (t != not && pool.every((k) => jokerCovers(k, t))) return t;
    }
    return null;
  }

  void sets(int i, int pair) {
    if (out.length >= limit) return;
    while (i < tileKinds && c[i] == 0) {
      i++;
    }
    if (i >= tileKinds) {
      if (j % 3 != 0) return;
      // Übrige Joker bilden eigene Drillinge (stellvertretend als Drilling eines Steins, den alle darstellen können)
      final extra = j ~/ 3;
      final rep = extra == 0 ? pair : (pool.every((k) => jokerCovers(k, pair)) ? pair : common(-1));
      if (rep == null) return;
      final g = [...groups, for (var k = 0; k < extra; k++) Group(false, rep)];
      out.add((pair, g, [...subs, for (var k = 0; k < extra * 3; k++) rep]));
      return;
    }
    // Drilling mit Jokern
    for (var real = min(3, c[i]); real >= 1; real--) {
      final need = 3 - real;
      if (need > j) continue;
      final taken = take(List.filled(need, i));
      if (taken == null) continue;
      c[i] -= real;
      groups.add(Group(false, i));
      for (var k = 0; k < need; k++) {
        subs.add(i);
      }
      sets(i, pair);
      for (var k = 0; k < need; k++) {
        subs.removeLast();
      }
      groups.removeLast();
      giveBack(taken);
      c[i] += real;
    }
    // Folgen, in denen i der kleinste echte Stein ist
    if (i < 27) {
      final n = i % 9;
      for (var start = max(0, n - 2); start <= min(n, 6); start++) {
        final base = i - n + start;
        final pos = [base, base + 1, base + 2];
        var need = 0;
        for (final x in pos) {
          if (x < i || c[x] == 0) need++;
        }
        if (need > j) continue;
        final used = <int>[];
        final filled = <int>[];
        for (final x in pos) {
          if (x >= i && c[x] > 0) {
            c[x]--;
            used.add(x);
          } else {
            filled.add(x);
          }
        }
        if (!used.contains(i)) {
          for (final x in used) {
            c[x]++;
          }
          continue;
        }
        final taken = take(filled);
        if (taken == null) {
          for (final x in used) {
            c[x]++;
          }
          continue;
        }
        groups.add(Group(true, base));
        subs.addAll(filled);
        sets(i, pair);
        subs.length -= filled.length;
        groups.removeLast();
        giveBack(taken);
        for (final x in used) {
          c[x]++;
        }
      }
    }
  }

  for (var p = 0; p < tileKinds; p++) {
    if (c[p] >= 2) {
      c[p] -= 2;
      sets(0, p);
      c[p] += 2;
    } else if (c[p] == 1 && j >= 1) {
      final taken = take([p]);
      if (taken == null) continue;
      c[p] -= 1;
      subs.add(p);
      sets(0, p);
      subs.removeLast();
      giveBack(taken);
      c[p] += 1;
    }
  }
  if (j >= 2) {
    // Paar nur aus Jokern: stellvertretend als Roter Drache oder ein anderer Stein, den zwei Joker darstellen können
    for (final t in [33, 32, 31, 27, 28, 29, 30, for (var x = 0; x < 27; x++) x]) {
      if (c[t] > 0) continue;
      final taken = take([t, t]);
      if (taken == null) continue;
      subs
        ..add(t)
        ..add(t);
      sets(0, t);
      subs.length -= 2;
      giveBack(taken);
      break;
    }
  }
  return out;
}

/// Ist die Hand fertig (Gruppen plus Paar)?
bool isCompleteJ(List<int> counts, int jokers, int sets, int openMelds) {
  final total = counts.fold(0, (a, b) => a + b) + jokers;
  if (total != (sets - openMelds) * 3 + 2) return false;
  return shantenN(counts, openMelds, sets, jokers: jokers) == -1 &&
      decompositionsJ(counts, jokers, limit: 1).isNotEmpty;
}

bool isSevenPairs(List<int> c, int jokers) {
  var singles = 0;
  var total = 0;
  for (final n in c) {
    total += n;
    if (n % 2 == 1) singles++;
  }
  return total + jokers == 14 && singles <= jokers && (jokers - singles).isEven;
}

bool isThirteenOrphans(List<int> c) => shantenKokushi(c) == -1 && c.fold(0, (a, b) => a + b) == 14;

/// Sieben Paare plus ein Drilling bei 17 Steinen (16er-Varianten).
bool isPairsPlusPung(List<int> c) {
  if (c.fold(0, (a, b) => a + b) != 17) return false;
  for (var t = 0; t < tileKinds; t++) {
    if (c[t] < 3) continue;
    c[t] -= 3;
    final ok = c.every((n) => n.isEven);
    c[t] += 3;
    if (ok) return true;
  }
  return false;
}

/// Verbundene Steine (MCR): 147, 258, 369 in drei verschiedenen Farben plus einzelne Ehrensteine, alles verschieden.
/// Gibt die Anzahl der Ehrensteine zurück oder -1.
int knittedHonors(List<int> c) {
  if (c.fold(0, (a, b) => a + b) != 14 || c.any((n) => n > 1)) return -1;
  final honors = [for (var t = 27; t < 34; t++) c[t]].fold(0, (a, b) => a + b);
  // Jede Farbe nur aus einer Gruppe 147, 258 oder 369, jede Gruppe in einer anderen Farbe
  final used = <int>{};
  for (var s = 0; s < 3; s++) {
    final nums = [for (var k = 0; k < 9; k++) if (c[s * 9 + k] > 0) k];
    if (nums.isEmpty) continue;
    final cls = nums.map((k) => k % 3).toSet();
    if (cls.length != 1) return -1;
    if (!used.add(cls.first)) return -1;
  }
  return honors;
}

const _knitPerms = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]];

/// Verbundene Straße (MCR, Knitted Straight): 1-4-7, 2-5-8 und 3-6-9 in je einer anderen Farbe.
/// Liefert für jede passende Farbverteilung die neun Steine.
List<List<int>> knittedStraights(List<int> c) => [
      for (final p in _knitPerms)
        if ([for (var k = 0; k < 3; k++) for (var n = k; n < 9; n += 3) p[k] * 9 + n].every((t) => c[t] > 0))
          [for (var k = 0; k < 3; k++) for (var n = k; n < 9; n += 3) p[k] * 9 + n],
    ];

/// Fertige Hand mit verbundener Straße: die neun Steine plus eine Figur (darf aufgedeckt sein) und ein Paar.
bool isKnittedStraightHand(List<int> c, int meldCount) {
  if (meldCount > 1) return false;
  for (final ks in knittedStraights(c)) {
    final rest = [...c];
    for (final t in ks) {
      rest[t]--;
    }
    if (decompositionsJ(rest, 0, limit: 20).any((d) => d.$2.length + meldCount == 1)) return true;
  }
  return false;
}
