import 'dart:math';

import 'tiles.dart';

/// Offene oder verdeckte Figur: Chi (Folge), Pon (Drilling), Kan (Vierling).
enum MeldKind { chi, pon, kan }

class Meld {
  Meld(this.kind, this.tiles, {this.open = true, this.from = -1});
  final MeldKind kind;
  final List<int> tiles;

  /// Verdeckter Kan zählt als geschlossen.
  bool open;

  /// Von welchem Spieler der Stein kam, -1 bei verdecktem Kan.
  final int from;

  int get first => tiles.reduce(min);
  bool get isTriplet => kind != MeldKind.chi;
}

List<int> countsOf(Iterable<int> tiles) {
  final c = List.filled(tileKinds, 0);
  for (final t in tiles) {
    c[t]++;
  }
  return c;
}

/// Shanten: wie viele Steine bis Tenpai fehlen. -1 heißt fertig, 0 heißt Tenpai.
int shanten(List<int> counts, int openMelds) {
  var best = shantenRegular(counts, openMelds);
  if (openMelds == 0) {
    best = min(best, shantenChiitoi(counts));
    best = min(best, shantenKokushi(counts));
  }
  return best;
}

int shantenChiitoi(List<int> c) {
  var pairs = 0;
  var kinds = 0;
  for (final n in c) {
    if (n > 0) kinds++;
    if (n >= 2) pairs++;
  }
  return 6 - pairs + (kinds < 7 ? 7 - kinds : 0);
}

const _orphans = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33];

int shantenKokushi(List<int> c) {
  var kinds = 0;
  var pair = false;
  for (final t in _orphans) {
    if (c[t] > 0) kinds++;
    if (c[t] >= 2) pair = true;
  }
  return 13 - kinds - (pair ? 1 : 0);
}

int shantenRegular(List<int> counts, int openMelds) {
  final c = counts.toList();
  var best = 8;
  void search(int i, int sets, int partials, int pair) {
    while (i < tileKinds && c[i] == 0) {
      i++;
    }
    if (i >= tileKinds) {
      final s = sets + openMelds;
      var p = partials;
      if (s + p > 4) p = 4 - s;
      final v = 8 - 2 * s - p - pair;
      if (v < best) best = v;
      return;
    }
    if (c[i] >= 3) {
      c[i] -= 3;
      search(i, sets + 1, partials, pair);
      c[i] += 3;
    }
    final seqOk = i < 27 && i % 9 <= 6;
    if (seqOk && c[i + 1] > 0 && c[i + 2] > 0) {
      c[i]--;
      c[i + 1]--;
      c[i + 2]--;
      search(i, sets + 1, partials, pair);
      c[i]++;
      c[i + 1]++;
      c[i + 2]++;
    }
    if (c[i] >= 2) {
      c[i] -= 2;
      if (pair == 0) search(i, sets, partials, 1);
      search(i, sets, partials + 1, pair);
      c[i] += 2;
    }
    if (i < 27 && i % 9 <= 7 && c[i + 1] > 0) {
      c[i]--;
      c[i + 1]--;
      search(i, sets, partials + 1, pair);
      c[i]++;
      c[i + 1]++;
    }
    if (seqOk && c[i + 2] > 0) {
      c[i]--;
      c[i + 2]--;
      search(i, sets, partials + 1, pair);
      c[i]++;
      c[i + 2]++;
    }
    c[i]--;
    search(i, sets, partials, pair);
    c[i]++;
  }

  search(0, 0, 0, 0);
  return best;
}

/// Steine, auf die eine Hand mit 13 Steinen (plus Figuren) wartet.
List<int> waitsOf(List<int> counts, int openMelds) {
  final out = <int>[];
  for (var t = 0; t < tileKinds; t++) {
    if (counts[t] >= 4) continue;
    counts[t]++;
    if (shanten(counts, openMelds) == -1) out.add(t);
    counts[t]--;
  }
  return out;
}

/// Eine Gruppe in einer zerlegten Hand.
class Group {
  const Group(this.seq, this.first, {this.open = false, this.kan = false});
  final bool seq;
  final int first;
  final bool open;
  final bool kan;

  bool contains(int t) => seq ? t >= first && t <= first + 2 : t == first;
}

/// Alle Zerlegungen der geschlossenen Steine in Paar und Gruppen.
List<(int, List<Group>)> decompositions(List<int> counts) {
  final out = <(int, List<Group>)>[];
  final c = counts.toList();
  final groups = <Group>[];
  void sets(int i, int pair) {
    while (i < tileKinds && c[i] == 0) {
      i++;
    }
    if (i >= tileKinds) {
      out.add((pair, List.of(groups)));
      return;
    }
    if (c[i] >= 3) {
      c[i] -= 3;
      groups.add(Group(false, i));
      sets(i, pair);
      groups.removeLast();
      c[i] += 3;
    }
    if (i < 27 && i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
      c[i]--;
      c[i + 1]--;
      c[i + 2]--;
      groups.add(Group(true, i));
      sets(i, pair);
      groups.removeLast();
      c[i]++;
      c[i + 1]++;
      c[i + 2]++;
    }
  }

  for (var p = 0; p < tileKinds; p++) {
    if (c[p] < 2) continue;
    c[p] -= 2;
    sets(0, p);
    c[p] += 2;
  }
  return out;
}

/// Lage am Tisch, die für die Wertung zählt.
class WinContext {
  const WinContext({
    required this.winTile,
    required this.tsumo,
    required this.seatWind,
    required this.roundWind,
    this.riichi = false,
    this.ippatsu = false,
    this.lastTile = false,
    this.rinshan = false,
    this.dora = const [],
    this.uraDora = const [],
  });

  final int winTile;
  final bool tsumo;

  /// Winde als Steinnummer 27 bis 30.
  final int seatWind;
  final int roundWind;
  final bool riichi;
  final bool ippatsu;
  final bool lastTile;
  final bool rinshan;

  /// Dora-Steine selbst, nicht die Anzeiger.
  final List<int> dora;
  final List<int> uraDora;
}

class Yaku {
  const Yaku(this.name, this.han);
  final String name;

  /// 13 oder mehr steht für Yakuman.
  final int han;
}

class HandScore {
  HandScore(this.yaku, this.han, this.fu, this.yakuman);
  final List<Yaku> yaku;
  final int han;
  final int fu;
  final int yakuman;

  /// Han nur aus Yaku, ohne Dora.
  int get yakuHan => yaku.where((y) => !y.name.startsWith('Dora') && !y.name.startsWith('Ura')).fold(0, (s, y) => s + y.han);
  bool get valid => yakuman > 0 || yakuHan > 0;

  /// Grundpunkte vor dem Verteilen.
  int get basePoints {
    if (yakuman > 0) return 8000 * yakuman;
    if (han >= 13) return 8000;
    if (han >= 11) return 6000;
    if (han >= 8) return 4000;
    if (han >= 6) return 3000;
    final b = fu * pow(2, han + 2).toInt();
    if (han >= 5 || b >= 2000) return 2000;
    return b;
  }

  String get limitName {
    if (yakuman > 0) return yakuman > 1 ? '${yakuman}-faches Yakuman' : 'Yakuman';
    if (han >= 13) return 'Gezähltes Yakuman';
    if (han >= 11) return 'Sanbaiman';
    if (han >= 8) return 'Baiman';
    if (han >= 6) return 'Haneman';
    if (basePoints == 2000) return 'Mangan';
    return '';
  }
}

int roundUp100(num v) => ((v + 99) ~/ 100) * 100;

/// Bewertet eine fertige Hand. closed: 14 bzw. mit Kans entsprechend weniger geschlossene Steine inklusive Gewinnstein.
HandScore? scoreHand(List<int> closed, List<Meld> melds, WinContext ctx) {
  final counts = countsOf(closed);
  final openHand = melds.any((m) => m.open);
  final all = [...closed, for (final m in melds) ...m.tiles];
  final allCounts = countsOf(all);
  HandScore? best;
  void consider(HandScore s) {
    if (!s.valid) return;
    if (best == null ||
        s.yakuman > best!.yakuman ||
        (s.yakuman == best!.yakuman && _value(s) > _value(best!))) {
      best = s;
    }
  }

  int doraHan() {
    var n = 0;
    for (final t in all) {
      n += ctx.dora.where((d) => d == t).length;
    }
    return n;
  }

  int uraHan() {
    if (!ctx.riichi) return 0;
    var n = 0;
    for (final t in all) {
      n += ctx.uraDora.where((d) => d == t).length;
    }
    return n;
  }

  List<Yaku> extras(List<Yaku> y) {
    final d = doraHan();
    final u = uraHan();
    return [...y, if (d > 0) Yaku('Dora', d), if (u > 0) Yaku('Ura-Dora', u)];
  }

  // Yakuman unabhängig von der Zerlegung
  final yakumanBase = <Yaku>[];
  if (all.every((t) => isHonor(t))) yakumanBase.add(const Yaku('Nur Ehrensteine (Tsuuiisou)', 13));
  if (all.every((t) => isTerminal(t))) yakumanBase.add(const Yaku('Nur Endsteine (Chinroutou)', 13));
  const greens = {19, 20, 21, 23, 25, 32};
  if (all.every(greens.contains)) yakumanBase.add(const Yaku('Alles grün (Ryuuiisou)', 13));
  final dragonsTrip = [31, 32, 33].where((d) => allCounts[d] >= 3).length;
  if (dragonsTrip == 3) yakumanBase.add(const Yaku('Drei große Drachen (Daisangen)', 13));
  final windTrip = [27, 28, 29, 30].where((w) => allCounts[w] >= 3).length;
  final windPair = [27, 28, 29, 30].where((w) => allCounts[w] == 2).length;
  if (windTrip == 4) yakumanBase.add(const Yaku('Vier große Winde (Daisuushii)', 13));
  if (windTrip == 3 && windPair == 1) yakumanBase.add(const Yaku('Vier kleine Winde (Shousuushii)', 13));

  // Dreizehn Waisen
  if (!openHand && melds.isEmpty && shantenKokushi(counts) == -1) {
    consider(HandScore([const Yaku('Dreizehn Waisen (Kokushi musou)', 13), ...yakumanBase], 13, 0, 1 + yakumanBase.length));
  }

  // Sieben Paare
  if (melds.isEmpty && counts.where((n) => n == 2).length == 7) {
    final y = <Yaku>[const Yaku('Sieben Paare (Chiitoitsu)', 2)];
    _commonYaku(y, ctx, all, openHand: false);
    final suits = all.where((t) => !isHonor(t)).map(suitOf).toSet();
    if (suits.length == 1) {
      y.add(all.any(isHonor) ? const Yaku('Halbe Farbe (Honitsu)', 3) : const Yaku('Reine Farbe (Chinitsu)', 6));
    }
    if (all.every(isTerminalOrHonor)) y.add(const Yaku('Nur Ende und Ehre (Honroutou)', 2));
    if (yakumanBase.isNotEmpty) {
      consider(HandScore(yakumanBase, 13, 25, yakumanBase.length));
    } else {
      final ex = extras(y);
      consider(HandScore(ex, ex.fold(0, (s, e) => s + e.han), 25, 0));
    }
  }

  for (final (pair, groupsClosed) in decompositions(counts)) {
    if (groupsClosed.length + melds.length != 4) continue;
    final meldGroups = [
      for (final m in melds) Group(m.kind == MeldKind.chi, m.first, open: m.open, kan: m.kind == MeldKind.kan),
    ];
    // Der Gewinnstein kann in verschiedenen Gruppen stecken; das ändert Wartemuster und Fu
    final roles = <int>[];
    if (pair == ctx.winTile) roles.add(-1);
    for (var g = 0; g < groupsClosed.length; g++) {
      if (groupsClosed[g].contains(ctx.winTile)) roles.add(g);
    }
    for (final role in roles) {
      final groups = <Group>[];
      for (var g = 0; g < groupsClosed.length; g++) {
        final gr = groupsClosed[g];
        // Ein Drilling, der durch Ron fertig wird, gilt als offen
        groups.add(g == role && !ctx.tsumo && !gr.seq ? Group(false, gr.first, open: true) : gr);
      }
      groups.addAll(meldGroups);
      final s = _scoreDecomposition(pair, groups, role, groupsClosed, ctx, all, openHand, yakumanBase, counts);
      if (s.yakuman > 0) {
        consider(s);
      } else {
        final ex = extras(s.yaku);
        consider(HandScore(ex, ex.fold(0, (a, e) => a + e.han), s.fu, 0));
      }
    }
  }
  return best;
}

int _value(HandScore s) => s.basePoints * 100 + s.han;

void _commonYaku(List<Yaku> y, WinContext ctx, List<int> all, {required bool openHand}) {
  if (ctx.riichi) y.add(const Yaku('Riichi', 1));
  if (ctx.riichi && ctx.ippatsu) y.add(const Yaku('Ippatsu', 1));
  if (ctx.tsumo && !openHand) y.add(const Yaku('Selbst gezogen (Menzen Tsumo)', 1));
  if (all.every(isSimple)) y.add(const Yaku('Nur Mittelsteine (Tanyao)', 1));
  if (ctx.lastTile) y.add(ctx.tsumo ? const Yaku('Letzter Stein (Haitei)', 1) : const Yaku('Letzter Abwurf (Houtei)', 1));
  if (ctx.rinshan) y.add(const Yaku('Nach dem Kan (Rinshan)', 1));
}

HandScore _scoreDecomposition(
  int pair,
  List<Group> groups,
  int role,
  List<Group> closedGroups,
  WinContext ctx,
  List<int> all,
  bool openHand,
  List<Yaku> yakumanBase,
  List<int> closedCounts,
) {
  final yaku = <Yaku>[];
  final yakuman = [...yakumanBase];
  final seqs = groups.where((g) => g.seq).toList();
  final trips = groups.where((g) => !g.seq).toList();
  final closedTrips = trips.where((g) => !g.open).length;

  // Wartemuster
  var wait = 'tanki';
  if (role >= 0) {
    final g = closedGroups[role];
    if (!g.seq) {
      wait = 'shanpon';
    } else {
      final pos = ctx.winTile - g.first;
      final n = numberOf(g.first);
      if (pos == 1) {
        wait = 'kanchan';
      } else if ((pos == 2 && n == 1) || (pos == 0 && n == 7)) {
        wait = 'penchan';
      } else {
        wait = 'ryanmen';
      }
    }
  }

  // Yakuman aus der Zerlegung
  if (closedTrips == 4) {
    yakuman.add(const Yaku('Vier verdeckte Drillinge (Suuankou)', 13));
  }
  if (!openHand && all.every((t) => !isHonor(t)) && all.map(suitOf).toSet().length == 1) {
    final suit = suitOf(all.first) * 9;
    final need = [3, 1, 1, 1, 1, 1, 1, 1, 3];
    var ok = true;
    for (var k = 0; k < 9; k++) {
      if (closedCounts[suit + k] < need[k]) ok = false;
    }
    if (ok) yakuman.add(const Yaku('Neun Tore (Chuuren poutou)', 13));
  }
  if (yakuman.isNotEmpty) return HandScore(yakuman, 13, 0, yakuman.length);

  _commonYaku(yaku, ctx, all, openHand: openHand);
  final valueHonors = {31, 32, 33, ctx.seatWind, ctx.roundWind};
  final pinfu = !openHand &&
      trips.isEmpty &&
      wait == 'ryanmen' &&
      !valueHonors.contains(pair);
  if (pinfu) yaku.add(const Yaku('Nur Folgen (Pinfu)', 1));

  if (!openHand) {
    final seqStarts = [for (final g in seqs) g.first]..sort();
    var dupes = 0;
    final used = <int>{};
    for (var i = 0; i < seqStarts.length; i++) {
      if (used.contains(i)) continue;
      for (var j = i + 1; j < seqStarts.length; j++) {
        if (!used.contains(j) && seqStarts[i] == seqStarts[j]) {
          dupes++;
          used
            ..add(i)
            ..add(j);
          break;
        }
      }
    }
    if (dupes == 2) {
      yaku.add(const Yaku('Zwei doppelte Folgen (Ryanpeikou)', 3));
    } else if (dupes == 1) {
      yaku.add(const Yaku('Doppelte Folge (Iipeikou)', 1));
    }
  }

  for (final g in trips) {
    if (g.first >= 31) yaku.add(Yaku('Drache: ${tileName(g.first)}', 1));
    if (g.first == ctx.seatWind) yaku.add(const Yaku('Sitzwind', 1));
    if (g.first == ctx.roundWind) yaku.add(const Yaku('Rundenwind', 1));
  }

  // Drei gleiche Folgen in allen Farben
  for (var n = 0; n < 7; n++) {
    if (seqs.any((g) => g.first == n) && seqs.any((g) => g.first == n + 9) && seqs.any((g) => g.first == n + 18)) {
      yaku.add(Yaku('Drei Farben, gleiche Folge (Sanshoku)', openHand ? 1 : 2));
      break;
    }
  }
  // Durchgehende Straße 1 bis 9
  for (var s = 0; s < 3; s++) {
    final b = s * 9;
    if (seqs.any((g) => g.first == b) && seqs.any((g) => g.first == b + 3) && seqs.any((g) => g.first == b + 6)) {
      yaku.add(Yaku('Reine Straße (Ittsu)', openHand ? 1 : 2));
      break;
    }
  }
  bool groupHasEnd(Group g) => g.seq ? (numberOf(g.first) == 1 || numberOf(g.first) == 7) : isTerminalOrHonor(g.first);
  final allEnds = groups.every(groupHasEnd) && isTerminalOrHonor(pair);
  final anyHonor = all.any(isHonor);
  if (allEnds && seqs.isNotEmpty) {
    if (anyHonor) {
      yaku.add(Yaku('Enden überall (Chanta)', openHand ? 1 : 2));
    } else {
      yaku.add(Yaku('Reine Enden überall (Junchan)', openHand ? 2 : 3));
    }
  }
  if (trips.length == 4) yaku.add(const Yaku('Nur Drillinge (Toitoi)', 2));
  if (closedTrips == 3) yaku.add(const Yaku('Drei verdeckte Drillinge (Sanankou)', 2));
  for (var n = 0; n < 9; n++) {
    if (trips.any((g) => g.first == n) && trips.any((g) => g.first == n + 9) && trips.any((g) => g.first == n + 18)) {
      yaku.add(const Yaku('Drei Farben, gleicher Drilling (Sanshoku doukou)', 2));
    }
  }
  final dragonTrips = trips.where((g) => g.first >= 31).length;
  if (dragonTrips == 2 && pair >= 31) yaku.add(const Yaku('Drei kleine Drachen (Shousangen)', 2));
  if (all.every(isTerminalOrHonor)) yaku.add(const Yaku('Nur Ende und Ehre (Honroutou)', 2));
  final suits = all.where((t) => !isHonor(t)).map(suitOf).toSet();
  if (suits.length == 1) {
    if (anyHonor) {
      yaku.add(Yaku('Halbe Farbe (Honitsu)', openHand ? 2 : 3));
    } else {
      yaku.add(Yaku('Reine Farbe (Chinitsu)', openHand ? 5 : 6));
    }
  }

  // Fu
  int fu;
  if (pinfu) {
    fu = ctx.tsumo ? 20 : 30;
  } else {
    fu = 20;
    if (!openHand && !ctx.tsumo) fu += 10;
    if (ctx.tsumo) fu += 2;
    for (final g in trips) {
      var v = isTerminalOrHonor(g.first) ? 4 : 2;
      if (!g.open) v *= 2;
      if (g.kan) v *= 4;
      fu += v;
    }
    if (pair >= 31) fu += 2;
    if (pair == ctx.seatWind) fu += 2;
    if (pair == ctx.roundWind) fu += 2;
    if (wait == 'kanchan' || wait == 'penchan' || wait == 'tanki') fu += 2;
    if (fu == 20) fu = 30;
    fu = ((fu + 9) ~/ 10) * 10;
  }
  return HandScore(yaku, yaku.fold(0, (s, e) => s + e.han), fu, 0);
}

/// Dora zu einem Anzeiger: der nächste Stein derselben Sorte.
int doraFromIndicator(int t) {
  if (t < 27) return (t ~/ 9) * 9 + (t % 9 + 1) % 9;
  if (t < 31) return 27 + (t - 27 + 1) % 4;
  return 31 + (t - 31 + 1) % 3;
}
