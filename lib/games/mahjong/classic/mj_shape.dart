import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_hand.dart';

/// Lage am Tisch beim Gewinnen.
class WinInfo {
  const WinInfo({
    required this.winTile,
    required this.tsumo,
    required this.seatWind,
    required this.roundWind,
    required this.seat,
    this.dealer = false,
    this.lastTile = false,
    this.rinshan = false,
    this.robKong = false,
    this.afterKongDiscard = false,
    this.heaven = false,
    this.earth = false,
    this.bonus = const [],
    this.early = false,
  });

  final int winTile;
  final bool tsumo;

  /// Winde als Steinnummer 27 bis 30.
  final int seatWind;
  final int roundWind;

  /// Sitz ab dem Geber, 0 bis 3; bestimmt die eigene Blume und Jahreszeit.
  final int seat;
  final bool dealer;
  final bool lastTile;
  final bool rinshan;
  final bool robKong;
  final bool afterKongDiscard;

  /// Geber gewinnt mit den ersten 14 Steinen.
  final bool heaven;

  /// Mitspieler gewinnt mit dem ersten eigenen Zug oder ersten Abwurf.
  final bool earth;
  final List<int> bonus;

  /// Sieg vor dem fünften Abwurf (philippinische Regel).
  final bool early;
}

/// Ein Muster in der Wertung.
class Fan {
  const Fan(this.name, this.value, {this.unit});
  final String name;
  final int value;

  /// Eigene Einheit, wenn sie von der Variante abweicht (Vietnam: Phán oder Mủn).
  final String? unit;
}

class MjScore {
  MjScore(this.fans, this.points, {this.limit = false, this.extra = 0});
  final List<Fan> fans;

  /// Fan, Tai oder Punkte je nach Variante.
  final int points;
  final bool limit;

  /// Punkte, die nicht für das Minimum zählen (zum Beispiel Blumen im MCR).
  final int extra;
  int get core => points - extra;
}

/// Eine zerlegte Hand mit allem, was die Wertungen brauchen.
class Shape {
  Shape({
    required this.pair,
    required this.groups,
    required this.all,
    required this.concealed,
    required this.wait,
    this.special = '',
    this.jokers = 0,
  });

  /// Paarstein, -1 bei Sonderhänden.
  final int pair;

  /// Alle Gruppen samt Figuren; offen heißt aufgedeckt (oder durch Ron fertig).
  final List<Group> groups;

  /// Alle Steine der Hand (Joker als der Stein, den sie darstellen).
  final List<int> all;

  /// Keine aufgedeckten Figuren (verdeckte Kans zählen als verdeckt).
  final bool concealed;

  /// tanki, kanchan, penchan, ryanmen, shanpon oder special.
  final String wait;

  /// sevenPairs, orphans, knitted, knittedGreater, knittedStraight, pairsPung oder leer.
  final String special;
  final int jokers;

  late final List<Group> seqs = groups.where((g) => g.seq).toList();
  late final List<Group> trips = groups.where((g) => !g.seq).toList();
  late final List<Group> kans = groups.where((g) => g.kan).toList();
  late final List<int> counts = countsPlain(all);
  late final Set<int> suits = {for (final t in all) if (t < 27) suitOf(t)};
  late final bool hasHonor = all.any(isHonor);
  late final bool fullFlush = suits.length == 1 && !hasHonor;
  late final bool halfFlush = suits.length == 1 && hasHonor;
  late final bool allHonors = all.every(isHonor);
  late final bool allTerminals = all.every(isTerminal);
  late final bool allTermHonor = all.every(isTerminalOrHonor);
  late final bool allSimple = all.every(isSimple);
  late final bool allSeq = special.isEmpty && trips.isEmpty;
  late final bool allTrip = special.isEmpty && seqs.isEmpty;
  late final int concealedTrips = trips.where((g) => !g.open).length;
  late final List<Group> dragonTrips = trips.where((g) => g.first >= 31).toList();
  late final List<Group> windTrips = trips.where((g) => g.first >= 27 && g.first < 31).toList();
  late final bool dragonPair = pair >= 31;
  late final bool windPair = pair >= 27 && pair < 31;

  /// Jede Gruppe und das Paar enthalten einen End- oder Ehrenstein.
  late final bool outside = special.isEmpty &&
      isTerminalOrHonor(pair) &&
      groups.every((g) => g.seq ? (numberOf(g.first) == 1 || numberOf(g.first) == 7) : isTerminalOrHonor(g.first));

  /// Wie viele Steinsorten viermal vorkommen (Sichuan „Gen“, Tile Hog).
  late final int fours = counts.where((n) => n == 4).length;

  bool hasSeq(int first) => seqs.any((g) => g.first == first);
  bool hasTrip(int t) => trips.any((g) => g.first == t);
  int seqCount(int first) => seqs.where((g) => g.first == first).length;

  /// Reine Straße 1 bis 9 in einer Farbe.
  bool get pureStraight => [0, 1, 2].any((s) => hasSeq(s * 9) && hasSeq(s * 9 + 3) && hasSeq(s * 9 + 6));

  /// Gleiche Folge in allen drei Farben.
  bool get mixedTripleChow => [for (var n = 0; n < 7; n++) n].any((n) => hasSeq(n) && hasSeq(n + 9) && hasSeq(n + 18));

  /// Gleicher Drilling in allen drei Farben.
  bool get tripleTrip => [for (var n = 0; n < 9; n++) n].any((n) => hasTrip(n) && hasTrip(n + 9) && hasTrip(n + 18));
}

/// Alle Zerlegungen einer fertigen Hand. closed enthält den Gewinnstein.
List<Shape> shapesOf(List<int> closed, List<Meld> melds, WinInfo w, {required int sets, bool sevenPairs = true, bool orphans = true, bool knitted = false, bool pairsPung = false}) {
  final out = <Shape>[];
  final c = countsPlain(closed);
  final j = jokersIn(closed);
  final open = melds.any((m) => m.open);
  final meldGroups = [
    for (final m in melds) Group(m.kind == MeldKind.chi, m.first, open: m.open, kan: m.kind == MeldKind.kan),
  ];
  final meldTiles = [for (final m in melds) ...m.tiles];

  if (melds.isEmpty && sets == 4) {
    if (orphans && j == 0 && isThirteenOrphans(c)) {
      out.add(Shape(pair: -1, groups: const [], all: closed, concealed: true, wait: 'special', special: 'orphans'));
    }
    if (sevenPairs && isSevenPairs(c, j)) {
      final all = [...closed.where((t) => !isJokerTile(t))];
      // Joker füllen die einzelnen Steine auf
      var left = j;
      for (var t = 0; t < tileKinds; t++) {
        if (c[t].isOdd && left > 0) {
          all.add(t);
          left--;
        }
      }
      while (left >= 2) {
        all
          ..add(33)
          ..add(33);
        left -= 2;
      }
      out.add(Shape(pair: -1, groups: const [], all: all, concealed: true, wait: 'tanki', special: 'sevenPairs', jokers: j));
    }
    if (knitted && j == 0) {
      final h = knittedHonors(c);
      if (h == 7) out.add(Shape(pair: -1, groups: const [], all: closed, concealed: true, wait: 'special', special: 'knittedGreater'));
      if (h >= 5 && h < 7) out.add(Shape(pair: -1, groups: const [], all: closed, concealed: true, wait: 'special', special: 'knitted'));
    }
  }
  // Verbundene Straße: neun verschiedene Steine plus eine Figur und ein Paar
  if (knitted && j == 0 && melds.length <= 1 && sets == 4) {
    for (final ks in knittedStraights(c)) {
      final rest = [...c];
      for (final t in ks) {
        rest[t]--;
      }
      for (final (pair, groupsClosed, _) in decompositionsJ(rest, 0, limit: 20)) {
        if (groupsClosed.length + melds.length != 1) continue;
        final groups = <Group>[];
        var wait = 'special';
        for (final g in groupsClosed) {
          // Bei Ron ist ein mit dem Gewinnstein fertiger Pung offen
          final byRon = !w.tsumo && !g.seq && g.first == w.winTile && !ks.contains(w.winTile) && pair != w.winTile;
          groups.add(byRon ? Group(false, g.first, open: true) : g);
        }
        groups.addAll(meldGroups);
        if (!ks.contains(w.winTile)) {
          if (pair == w.winTile) {
            wait = 'tanki';
          } else {
            final g = groupsClosed.isEmpty ? null : groupsClosed.first;
            if (g != null && g.seq) {
              final pos = w.winTile - g.first;
              final n = numberOf(g.first);
              wait = pos == 1
                  ? 'kanchan'
                  : (pos == 2 && n == 1) || (pos == 0 && n == 7)
                      ? 'penchan'
                      : 'ryanmen';
            } else if (g != null) {
              wait = 'shanpon';
            }
          }
        }
        out.add(Shape(
          pair: pair,
          groups: groups,
          all: [...closed, ...meldTiles],
          concealed: !open,
          wait: wait,
          special: 'knittedStraight',
        ));
      }
    }
  }
  if (pairsPung && melds.isEmpty && sets == 5 && j == 0 && isPairsPlusPung(c)) {
    out.add(Shape(pair: -1, groups: const [], all: closed, concealed: true, wait: 'special', special: 'pairsPung'));
  }

  for (final (pair, groupsClosed, subs) in decompositionsT(c, closed.where(isJokerTile).toList())) {
    if (groupsClosed.length + melds.length != sets) continue;
    final allTiles = [...closed.where((t) => !isJokerTile(t)), ...subs, ...meldTiles];
    final roles = <int>[];
    if (pair == w.winTile) roles.add(-1);
    for (var g = 0; g < groupsClosed.length; g++) {
      if (groupsClosed[g].contains(w.winTile)) roles.add(g);
    }
    if (roles.isEmpty) roles.add(-1);
    for (final role in roles) {
      final groups = <Group>[];
      for (var g = 0; g < groupsClosed.length; g++) {
        final gr = groupsClosed[g];
        groups.add(g == role && !w.tsumo && !gr.seq ? Group(false, gr.first, open: true) : gr);
      }
      groups.addAll(meldGroups);
      var wait = 'tanki';
      if (role >= 0) {
        final g = groupsClosed[role];
        if (!g.seq) {
          wait = 'shanpon';
        } else {
          final pos = w.winTile - g.first;
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
      out.add(Shape(pair: pair, groups: groups, all: allTiles, concealed: !open, wait: wait, jokers: j));
    }
  }
  return out;
}

/// Hilfen für Blumen: eigene Blume und Jahreszeit passen zum Sitz.
int ownBonus(List<int> bonus, int seat) =>
    bonus.where((b) => b == firstFlower + seat || b == firstSeason + seat).length;

bool fullFlowers(List<int> bonus) => [for (var k = 0; k < 4; k++) firstFlower + k].every(bonus.contains);
bool fullSeasons(List<int> bonus) => [for (var k = 0; k < 4; k++) firstSeason + k].every(bonus.contains);
int animalCount(List<int> bonus) => bonus.where((b) => b >= firstAnimal && b < firstAnimal + 4).length;
