import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';

/// Joker-Stein (für die Varianten mit Jokern).
const jokerTile = jokerKind;

bool isBonusTile(int t) => t >= firstFlower && t < jokerTile;

/// Zählt die normalen Steine 0 bis 33; Joker und Bonussteine bleiben außen vor.
List<int> countsPlain(Iterable<int> tiles) {
  final c = List.filled(tileKinds, 0);
  for (final t in tiles) {
    if (t < tileKinds) c[t]++;
  }
  return c;
}

int jokersIn(Iterable<int> tiles) => tiles.where((t) => t == jokerTile).length;

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
List<(int, List<Group>, List<int>)> decompositionsJ(List<int> counts, int jokers, {int limit = 300}) {
  final out = <(int, List<Group>, List<int>)>[];
  final c = counts.toList();
  final groups = <Group>[];
  final subs = <int>[];
  var j = jokers;

  void sets(int i, int pair) {
    if (out.length >= limit) return;
    while (i < tileKinds && c[i] == 0) {
      i++;
    }
    if (i >= tileKinds) {
      if (j % 3 != 0) return;
      // Übrige Joker bilden eigene Drillinge (stellvertretend als Drilling des Paares)
      final extra = j ~/ 3;
      final g = [...groups, for (var k = 0; k < extra; k++) Group(false, pair)];
      out.add((pair, g, [...subs, for (var k = 0; k < extra * 3; k++) pair]));
      return;
    }
    // Drilling mit Jokern
    for (var real = min(3, c[i]); real >= 1; real--) {
      final need = 3 - real;
      if (need > j) continue;
      c[i] -= real;
      j -= need;
      groups.add(Group(false, i));
      for (var k = 0; k < need; k++) {
        subs.add(i);
      }
      sets(i, pair);
      for (var k = 0; k < need; k++) {
        subs.removeLast();
      }
      groups.removeLast();
      j += need;
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
        j -= need;
        groups.add(Group(true, base));
        subs.addAll(filled);
        sets(i, pair);
        subs.length -= filled.length;
        groups.removeLast();
        j += need;
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
      c[p] -= 1;
      j -= 1;
      subs.add(p);
      sets(0, p);
      subs.removeLast();
      j += 1;
      c[p] += 1;
    }
  }
  if (j >= 2) {
    // Paar nur aus Jokern: stellvertretend als Roter Drache
    j -= 2;
    subs
      ..add(33)
      ..add(33);
    sets(0, 33);
    subs.length -= 2;
    j += 2;
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
