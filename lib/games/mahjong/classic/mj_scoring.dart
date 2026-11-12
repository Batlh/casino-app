import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_hand.dart';
import 'mj_shape.dart';

/// Wertet eine Zerlegung aus. Der beste Wert über alle Zerlegungen gewinnt.
typedef ShapeScorer = MjScore Function(Shape s, WinInfo w);

MjScore? bestScore(List<Shape> shapes, WinInfo w, ShapeScorer f) {
  MjScore? best;
  for (final s in shapes) {
    final r = f(s, w);
    if (best == null || r.points > best.points) best = r;
  }
  return best;
}

MjScore _sum(List<Fan> fans, {int cap = 1 << 30, int extra = 0, bool limit = false}) {
  final total = fans.fold(0, (a, f) => a + f.value);
  return MjScore(fans, min(cap, total), limit: limit || total >= cap, extra: extra);
}

bool _isGreen(int t) => const {19, 20, 21, 23, 25, 32}.contains(t);

bool _nineGates(Shape s) {
  if (!s.fullFlush || !s.concealed || s.kans.isNotEmpty) return false;
  final b = suitOf(s.all.first) * 9;
  const need = [3, 1, 1, 1, 1, 1, 1, 1, 3];
  for (var k = 0; k < 9; k++) {
    if (s.counts[b + k] < need[k]) return false;
  }
  return true;
}

// ---------------------------------------------------------------- Sichuan

/// Sichuan (Blutkampf und Blutfluss). Grundwert 1, jedes Fan verdoppelt.
MjScore scoreSichuan(Shape s, WinInfo w, {int cap = 6}) {
  final f = <Fan>[];
  if (w.heaven) return MjScore([const Fan('Himmlischer Sieg', 6)], cap, limit: true);
  if (w.earth) return MjScore([const Fan('Irdischer Sieg', 6)], cap, limit: true);
  var roots = s.fours;
  if (s.special == 'sevenPairs') {
    if (roots > 0) {
      f.add(const Fan('Drachen-Sieben-Paare', 3));
      roots--;
    } else {
      f.add(const Fan('Sieben Paare', 2));
    }
  } else {
    final generals = s.allTrip &&
        [s.pair, for (final g in s.trips) g.first].every((t) => const {1, 4, 7}.contains(t % 9));
    if (generals) {
      f.add(const Fan('Generalspaare (nur 2, 5, 8)', 3));
    } else if (s.allTrip) {
      f.add(const Fan('Nur Pungs', 1));
    }
    if (s.groups.where((g) => g.open || g.kan).length == 4 && s.wait == 'tanki') {
      f.add(const Fan('Goldener Haken (nur noch ein Stein)', 1));
    }
    if (s.outside) f.add(const Fan('Überall Eins oder Neun', 2));
  }
  if (s.fullFlush) f.add(const Fan('Reine Farbe', 2));
  for (var k = 0; k < roots; k++) {
    f.add(const Fan('Wurzel (vier Gleiche)', 1));
  }
  if (w.tsumo) f.add(const Fan('Selbst gezogen', 1));
  if (w.rinshan) f.add(const Fan('Blüte auf dem Kan', 1));
  if (w.afterKongDiscard) f.add(const Fan('Schuss nach dem Kan', 1));
  if (w.robKong) f.add(const Fan('Kan geraubt', 1));
  if (w.lastTile) f.add(Fan(w.tsumo ? 'Mond aus dem Meer' : 'Letzter Abwurf', 1));
  if (f.isEmpty) f.add(const Fan('Einfacher Sieg', 0));
  return _sum(f, cap: cap);
}

// ---------------------------------------------------------------- Hongkong

const hkLimit = 13;

MjScore scoreHongKong(Shape s, WinInfo w) {
  final f = <Fan>[];
  MjScore lim(String n) => MjScore([Fan(n, hkLimit)], hkLimit, limit: true);
  if (w.heaven) return lim('Himmlischer Sieg');
  if (w.earth) return lim('Irdischer Sieg');
  if (s.special == 'orphans') return lim('Dreizehn Waisen');
  if (_nineGates(s)) return lim('Neun Tore');
  if (s.kans.length == 4) return lim('Vier Kans (18 Gelehrte)');
  if (s.allTrip && s.concealedTrips == 4) return lim('Vier verdeckte Pungs');
  if (s.windTrips.length == 4) return lim('Vier große Winde');
  if (s.allHonors) return lim('Nur Ehrensteine');
  if (s.allTerminals) return lim('Nur Endsteine');
  if (s.dragonTrips.length == 3) f.add(const Fan('Drei große Drachen', 8));
  if (s.dragonTrips.length == 2 && s.dragonPair) f.add(const Fan('Drei kleine Drachen', 5));
  if (s.windTrips.length == 3 && s.windPair) f.add(const Fan('Vier kleine Winde', 10));
  if (s.special == 'sevenPairs') f.add(const Fan('Sieben Paare', 4));
  if (s.allTrip) f.add(const Fan('Nur Pungs', 3));
  if (s.allSeq && !s.dragonPair && s.pair != w.seatWind && s.pair != w.roundWind && w.bonus.isEmpty) {
    f.add(const Fan('Nur Folgen', 1));
  }
  if (s.fullFlush) f.add(const Fan('Reine Farbe', 7));
  if (s.halfFlush) f.add(const Fan('Halbe Farbe', 3));
  if (s.allTermHonor && !s.allHonors && !s.allTerminals) f.add(const Fan('Nur Ende und Ehre', 1));
  if (s.dragonTrips.length < 3) {
    for (final g in s.dragonTrips) {
      f.add(Fan('Drache: ${tileName(g.first)}', 1));
    }
  }
  if (s.hasTrip(w.seatWind)) f.add(const Fan('Sitzwind', 1));
  if (s.hasTrip(w.roundWind)) f.add(const Fan('Rundenwind', 1));
  if (s.concealed && !w.tsumo) f.add(const Fan('Verdeckte Hand', 1));
  if (w.tsumo) f.add(const Fan('Selbst gezogen', 1));
  if (w.lastTile) f.add(const Fan('Letzter Stein', 1));
  if (w.rinshan) f.add(const Fan('Blüte auf dem Kan', 1));
  if (w.robKong) f.add(const Fan('Kan geraubt', 1));
  final own = ownBonus(w.bonus, w.seat);
  if (own > 0) f.add(Fan('Eigene Blume oder Jahreszeit', own));
  if (fullFlowers(w.bonus)) f.add(const Fan('Alle vier Blumen', 2));
  if (fullSeasons(w.bonus)) f.add(const Fan('Alle vier Jahreszeiten', 2));
  if (w.bonus.isEmpty) f.add(const Fan('Ohne Blumen', 1));
  if (f.isEmpty) f.add(const Fan('Hühnerhand', 0));
  return _sum(f, cap: hkLimit);
}

// ---------------------------------------------------------------- Taiwan

MjScore scoreTaiwan(Shape s, WinInfo w) {
  final f = <Fan>[];
  if (w.heaven) return MjScore([const Fan('Himmlischer Sieg', 16)], 16, limit: true);
  if (w.earth) return MjScore([const Fan('Irdischer Sieg', 16)], 16, limit: true);
  if (w.dealer) f.add(const Fan('Geber', 1));
  if (s.concealed && w.tsumo) {
    f.add(const Fan('Verdeckt und selbst gezogen', 3));
  } else {
    if (s.concealed) f.add(const Fan('Verdeckte Hand', 1));
    if (w.tsumo) f.add(const Fan('Selbst gezogen', 1));
  }
  if (s.special == 'pairsPung') {
    f.add(const Fan('Sieben Paare und ein Pung', 8));
  }
  for (final g in s.dragonTrips) {
    f.add(Fan('Drache: ${tileName(g.first)}', 1));
  }
  if (s.hasTrip(w.seatWind)) f.add(const Fan('Sitzwind', 1));
  if (s.hasTrip(w.roundWind)) f.add(const Fan('Rundenwind', 1));
  final own = ownBonus(w.bonus, w.seat);
  if (own > 0) f.add(Fan('Eigene Blume oder Jahreszeit', own));
  if (fullFlowers(w.bonus)) f.add(const Fan('Alle vier Blumen', 2));
  if (fullSeasons(w.bonus)) f.add(const Fan('Alle vier Jahreszeiten', 2));
  if (s.allSeq && !s.hasHonor && w.bonus.isEmpty && !w.tsumo && s.wait == 'ryanmen') f.add(const Fan('Ping Hu (nur Folgen)', 2));
  if (s.groups.where((g) => g.open).length == 5 && !w.tsumo && s.wait == 'tanki') f.add(const Fan('Alles gerufen', 2));
  if (s.allTrip) f.add(const Fan('Nur Pungs', 4));
  final ct = s.concealedTrips;
  if (ct >= 5) {
    f.add(const Fan('Fünf verdeckte Pungs', 8));
  } else if (ct == 4) {
    f.add(const Fan('Vier verdeckte Pungs', 5));
  } else if (ct == 3) {
    f.add(const Fan('Drei verdeckte Pungs', 2));
  }
  if (s.allHonors) {
    f.add(const Fan('Nur Ehrensteine', 16));
  } else if (s.fullFlush) {
    f.add(const Fan('Reine Farbe', 8));
  } else if (s.halfFlush) {
    f.add(const Fan('Halbe Farbe', 4));
  }
  if (s.dragonTrips.length == 3) {
    f.add(const Fan('Drei große Drachen', 8));
  } else if (s.dragonTrips.length == 2 && s.dragonPair) {
    f.add(const Fan('Drei kleine Drachen', 4));
  }
  if (s.windTrips.length == 4) {
    f.add(const Fan('Vier große Winde', 16));
  } else if (s.windTrips.length == 3 && s.windPair) {
    f.add(const Fan('Vier kleine Winde', 8));
  }
  if (const {'kanchan', 'penchan', 'tanki'}.contains(s.wait)) f.add(const Fan('Warten auf einen Stein', 1));
  if (w.lastTile) f.add(Fan(w.tsumo ? 'Mond aus dem Meer' : 'Fisch aus dem Fluss', 1));
  if (w.rinshan) f.add(const Fan('Blüte auf dem Kan', 1));
  if (w.robKong) f.add(const Fan('Kan geraubt', 1));
  if (f.isEmpty) f.add(const Fan('Einfacher Sieg', 0));
  return _sum(f);
}

// ---------------------------------------------------------------- MCR (Chinesisch offiziell)

class _Mcr {
  final fans = <Fan>[];
  final _excl = <List<String>>[];
  void add(String n, int v, [List<String> excl = const []]) {
    fans.add(Fan(n, v));
    _excl.add(excl);
  }

  /// Höhere Muster schließen niedrigere aus. Ein selbst ausgeschlossenes Muster schließt nichts aus
  /// (offizielle Regel: „Nicht-Wiederholungs-Prinzip“).
  MjScore finish(int flowers) {
    final order = [for (var i = 0; i < fans.length; i++) i]
      ..sort((a, b) => fans[b].value != fans[a].value ? fans[b].value - fans[a].value : a - b);
    final blocked = <String>{};
    final keptIdx = <int>[];
    for (final i in order) {
      if (blocked.contains(fans[i].name)) continue;
      keptIdx.add(i);
      blocked.addAll(_excl[i]);
    }
    keptIdx.sort();
    final kept = [for (final i in keptIdx) fans[i]];
    if (kept.isEmpty) kept.add(const Fan('Hühnerhand', 8));
    if (flowers > 0) kept.add(Fan('Blumen', flowers));
    final total = kept.fold(0, (a, f) => a + f.value);
    return MjScore(kept, total, extra: flowers);
  }
}

const _allPungs = 'Nur Pungs';
const _outside = 'Außenhand';
const _ptoh = 'Pung aus End- oder Ehrensteinen';
const _noHonors = 'Ohne Ehrensteine';
const _concealed = 'Verdeckte Hand';
const _single = 'Einzelwartung';
const _selfDrawn = 'Selbst gezogen';
const _fullFlush = 'Reine Farbe';
const _pureDouble = 'Reine Doppelfolge';
const _mixedDouble = 'Gemischte Doppelfolge';
const _shortStraight = 'Kurze Straße';
const _twoTermChows = 'Zwei Endfolgen';
const _allChows = 'Nur Folgen';
const _allSimples = 'Nur Mittelsteine';
const _oneVoid = 'Eine Farbe fehlt';
const _dragonPung = 'Drachen-Pung';
const _fullyConcealed = 'Ganz verdeckt';
const _knittedStraight = 'Verbundene Straße';

MjScore scoreMcr(Shape s, WinInfo w) {
  final m = _Mcr();
  final flowers = w.bonus.length;
  final sp = s.special;

  // Sonderhände
  if (sp == 'orphans') {
    m.add('Dreizehn Waisen', 88, ['Alle Sorten', _concealed, _fullyConcealed, _single]);
  } else if (sp == 'knittedGreater') {
    m.add('Große Ehren und Verbundene', 24, ['Alle Sorten', _concealed, _fullyConcealed, _single, 'Kleine Ehren und Verbundene']);
  } else if (sp == 'knitted') {
    m.add('Kleine Ehren und Verbundene', 12, ['Alle Sorten', _concealed, _fullyConcealed, _single]);
    // Mit nur fünf Ehrensteinen ist die verbundene Straße komplett und zählt mit
    if (knittedStraights(s.counts).isNotEmpty) m.add(_knittedStraight, 12);
  } else if (sp == 'knittedStraight') {
    m.add(_knittedStraight, 12);
  } else if (sp == 'sevenPairs') {
    final firstPair = s.counts.indexWhere((n) => n >= 2);
    var shifted = s.fullFlush && firstPair >= 0;
    if (shifted) {
      final b = firstPair;
      for (var k = 0; k < 7; k++) {
        if (b + k >= 27 || suitOf(b + k) != suitOf(b) || s.counts[b + k] != 2) shifted = false;
      }
    }
    if (shifted) {
      m.add('Sieben verschobene Paare', 88, [_fullFlush, 'Sieben Paare', _concealed, _fullyConcealed, _single]);
    } else {
      m.add('Sieben Paare', 24, [_concealed, _fullyConcealed, _single]);
    }
  }

  // Ehrensteine
  final winds = s.windTrips.length;
  final dragons = s.dragonTrips.length;
  if (winds == 4) m.add('Vier große Winde', 88, ['Drei große Winde', _allPungs, 'Sitzwind', 'Rundenwind', _ptoh]);
  if (dragons == 3) m.add('Drei große Drachen', 88, [_dragonPung, 'Zwei Drachen-Pungs']);
  if (s.all.every(_isGreen)) m.add('Alles grün', 88, ['Halbe Farbe', _fullFlush]);
  if (_nineGates(s)) m.add('Neun Tore', 88, [_fullFlush, _ptoh, _noHonors, _concealed]);
  if (s.kans.length == 4) m.add('Vier Kans', 88, ['Drei Kans', _single, 'Zwei offene Kans', 'Zwei verdeckte Kans', 'Offener Kan']);
  if (s.allTerminals) m.add('Nur Endsteine', 64, [_allPungs, _outside, _ptoh, _noHonors, 'Nur End- und Ehrensteine']);
  if (winds == 3 && s.windPair) m.add('Vier kleine Winde', 64, ['Drei große Winde', _ptoh]);
  if (dragons == 2 && s.dragonPair) m.add('Drei kleine Drachen', 64, [_dragonPung, 'Zwei Drachen-Pungs']);
  if (s.allHonors) m.add('Nur Ehrensteine', 64, [_allPungs, _outside, _ptoh, 'Nur End- und Ehrensteine']);
  if (sp.isEmpty && s.concealedTrips == 4) m.add('Vier verdeckte Pungs', 64, [_allPungs, 'Drei verdeckte Pungs', 'Zwei verdeckte Pungs', _concealed, _fullyConcealed]);

  // Folgen in einer Farbe
  for (var suit = 0; suit < 3; suit++) {
    final b = suit * 9;
    if (s.seqCount(b) == 2 && s.seqCount(b + 6) == 2 && s.pair == b + 4) {
      m.add('Reine Endfolgen', 64, [_fullFlush, _allChows, _pureDouble, _twoTermChows]);
    }
  }
  for (final g in s.seqs.map((g) => g.first).toSet()) {
    final n = s.seqCount(g);
    if (n == 4) m.add('Vierfache Folge', 48, ['Dreifache Folge', _pureDouble, 'Vierer ohne Kan']);
    if (n == 3) m.add('Dreifache Folge', 24, [_pureDouble]);
  }
  // Verschobene Pungs in einer Farbe
  for (var t = 0; t < 27; t++) {
    if (t % 9 > 6) continue;
    if (s.hasTrip(t) && s.hasTrip(t + 1) && s.hasTrip(t + 2)) {
      if (t % 9 <= 5 && s.hasTrip(t + 3)) {
        m.add('Vier verschobene Pungs', 48, ['Drei verschobene Pungs', _allPungs]);
      } else {
        m.add('Drei verschobene Pungs', 24);
      }
      break;
    }
  }
  // Verschobene Folgen in einer Farbe
  var shiftedChows = false;
  for (var t = 0; t < 27 && !shiftedChows; t++) {
    for (final step in [1, 2]) {
      if (t % 9 + 2 * step > 6) continue;
      if (s.hasSeq(t) && s.hasSeq(t + step) && s.hasSeq(t + 2 * step)) {
        if (t % 9 + 3 * step <= 6 && s.hasSeq(t + 3 * step)) {
          m.add('Vier verschobene Folgen', 32, ['Drei verschobene Folgen', _shortStraight, _twoTermChows]);
        } else {
          m.add('Drei verschobene Folgen', 16);
        }
        shiftedChows = true;
        break;
      }
    }
  }
  if (s.kans.length == 3) m.add('Drei Kans', 32, ['Zwei offene Kans', 'Zwei verdeckte Kans', 'Offener Kan', 'Verdeckter Kan']);
  if (s.allTermHonor && !s.allTerminals && !s.allHonors) m.add('Nur End- und Ehrensteine', 32, [_allPungs, _outside, _ptoh]);

  if (sp.isEmpty && s.allTrip && s.all.every((t) => t < 27 && numberOf(t).isEven)) {
    m.add('Nur gerade Pungs', 24, [_allPungs, _allSimples]);
  }
  if (s.fullFlush) m.add(_fullFlush, 24, [_noHonors]);
  if (s.all.every((t) => t < 27 && numberOf(t) >= 7)) m.add('Obere Steine', 24, [_noHonors]);
  if (s.all.every((t) => t < 27 && numberOf(t) >= 4 && numberOf(t) <= 6)) m.add('Mittlere Steine', 24, [_noHonors, _allSimples]);
  if (s.all.every((t) => t < 27 && numberOf(t) <= 3)) m.add('Untere Steine', 24, [_noHonors]);

  if (s.pureStraight) m.add('Reine Straße', 16);
  for (var a = 0; a < 3; a++) {
    for (var b = 0; b < 3; b++) {
      if (a == b) continue;
      final c = 3 - a - b;
      if (s.hasSeq(a * 9) && s.hasSeq(a * 9 + 6) && s.hasSeq(b * 9) && s.hasSeq(b * 9 + 6) && s.pair == c * 9 + 4) {
        m.add('Endfolgen in drei Farben', 16, [_allChows, _twoTermChows, _noHonors, _mixedDouble]);
      }
    }
  }
  if (sp.isEmpty && s.groups.every((g) => g.seq ? g.first % 9 <= 4 && g.first % 9 >= 2 : g.first < 27 && g.first % 9 == 4) && s.pair < 27 && s.pair % 9 == 4) {
    m.add('Alles mit Fünf', 16, [_allSimples]);
  }
  if (s.tripleTrip) m.add('Dreifacher Pung', 16);
  if (s.concealedTrips == 3) m.add('Drei verdeckte Pungs', 16);

  if (s.all.every((t) => t < 27 && numberOf(t) >= 6)) m.add('Obere Vier', 12, [_noHonors]);
  if (s.all.every((t) => t < 27 && numberOf(t) <= 4)) m.add('Untere Vier', 12, [_noHonors]);
  if (winds == 3) m.add('Drei große Winde', 12, [_ptoh]);

  // Gemischte Muster über drei Farben
  for (final p in const [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]) {
    if (s.hasSeq(p[0] * 9) && s.hasSeq(p[1] * 9 + 3) && s.hasSeq(p[2] * 9 + 6)) {
      m.add('Gemischte Straße', 8);
      break;
    }
  }
  const reversible = {9, 10, 11, 12, 13, 16, 17, 19, 21, 22, 23, 25, 26, 31};
  if (s.all.every(reversible.contains)) m.add('Umkehrbare Steine', 8, [_oneVoid]);
  if (s.mixedTripleChow) m.add('Gleiche Folge in drei Farben', 8);
  for (final p in const [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]) {
    var hit = false;
    for (var n = 0; n < 7 && !hit; n++) {
      if (s.hasTrip(p[0] * 9 + n) && s.hasTrip(p[1] * 9 + n + 1) && s.hasTrip(p[2] * 9 + n + 2)) hit = true;
    }
    if (hit) {
      m.add('Verschobene Pungs in drei Farben', 8);
      break;
    }
  }
  var mixedShifted = false;
  for (final p in const [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]) {
    for (var n = 0; n < 5 && !mixedShifted; n++) {
      if (s.hasSeq(p[0] * 9 + n) && s.hasSeq(p[1] * 9 + n + 1) && s.hasSeq(p[2] * 9 + n + 2)) mixedShifted = true;
    }
  }
  if (mixedShifted) m.add('Verschobene Folgen in drei Farben', 6);
  if (w.lastTile) m.add(w.tsumo ? 'Letzter Stein gezogen' : 'Letzter Abwurf', 8, [_selfDrawn]);
  if (w.rinshan) m.add('Ersatzstein nach Kan', 8, [_selfDrawn]);
  if (w.robKong) m.add('Kan geraubt', 8);
  final closedKans = s.kans.where((g) => !g.open).length;
  final openKans = s.kans.length - closedKans;
  if (closedKans == 2) m.add('Zwei verdeckte Kans', 8, ['Verdeckter Kan']);

  if (sp.isEmpty && s.allTrip) m.add(_allPungs, 6);
  if (s.halfFlush) m.add('Halbe Farbe', 6);
  if (s.suits.length == 3 && (s.windTrips.isNotEmpty || s.windPair) && (s.dragonTrips.isNotEmpty || s.dragonPair)) {
    m.add('Alle Sorten', 6);
  }
  if (sp.isEmpty && s.groups.where((g) => g.open).length == 4 && !w.tsumo && s.wait == 'tanki') {
    m.add('Alles gerufen', 6, [_single]);
  }
  if (dragons == 2) m.add('Zwei Drachen-Pungs', 6, [_dragonPung]);

  if (s.outside) m.add(_outside, 4);
  if (s.concealed && w.tsumo) m.add(_fullyConcealed, 4, [_selfDrawn, _concealed]);
  if (openKans == 2) m.add('Zwei offene Kans', 4, ['Offener Kan']);

  for (var k = 0; k < dragons; k++) {
    m.add(_dragonPung, 2);
  }
  if (s.hasTrip(w.roundWind)) m.add('Rundenwind', 2);
  if (s.hasTrip(w.seatWind)) m.add('Sitzwind', 2);
  if (s.concealed && !w.tsumo) m.add(_concealed, 2);
  if (s.allSeq && !s.hasHonor) m.add(_allChows, 2, [_noHonors]);
  final kanTiles = {for (final g in s.kans) g.first};
  for (var t = 0; t < tileKinds; t++) {
    if (s.counts[t] == 4 && !kanTiles.contains(t)) m.add('Vierer ohne Kan', 2);
  }
  for (var n = 0; n < 9; n++) {
    final hits = [0, 1, 2].where((suit) => s.hasTrip(suit * 9 + n)).length;
    if (hits == 2) m.add('Doppelter Pung', 2);
  }
  if (s.concealedTrips == 2) m.add('Zwei verdeckte Pungs', 2);
  if (closedKans == 1) m.add('Verdeckter Kan', 2);
  if (s.allSimple) m.add(_allSimples, 2, [_noHonors]);

  // Kleine Folgenmuster nur einmal je Art
  final starts = [for (final g in s.seqs) g.first];
  if (starts.toSet().any((x) => starts.where((y) => y == x).length == 2)) m.add(_pureDouble, 1);
  if (starts.any((x) => starts.any((y) => y != x && y % 9 == x % 9 && suitOf(y) != suitOf(x)))) m.add(_mixedDouble, 1);
  if (starts.any((x) => starts.contains(x + 3) && x % 9 <= 3)) m.add(_shortStraight, 1);
  if ([0, 1, 2].any((suit) => starts.contains(suit * 9) && starts.contains(suit * 9 + 6))) m.add(_twoTermChows, 1);
  for (final g in s.trips) {
    if (isTerminal(g.first) || (g.first >= 27 && g.first < 31 && g.first != w.seatWind && g.first != w.roundWind)) {
      m.add(_ptoh, 1);
    }
  }
  if (openKans == 1) m.add('Offener Kan', 1);
  if (s.suits.length == 2) m.add(_oneVoid, 1);
  if (!s.hasHonor) m.add(_noHonors, 1);
  // Wartungen zählen nur, wenn genau dieser eine Stein die Hand fertig machen konnte
  if (const {'penchan', 'kanchan', 'tanki'}.contains(s.wait) && _onlyWait(s, w.winTile)) {
    if (s.wait == 'penchan') m.add('Randwartung', 1);
    if (s.wait == 'kanchan') m.add('Mittelwartung', 1);
    if (s.wait == 'tanki') m.add(_single, 1);
  }
  if (w.tsumo) m.add(_selfDrawn, 1);
  return m.finish(flowers);
}

// ---------------------------------------------------------------- Singapur

MjScore scoreSingapore(Shape s, WinInfo w) {
  final f = <Fan>[];
  if (s.special == 'orphans') return MjScore([const Fan('Dreizehn Waisen', 5)], 5, limit: true);
  if (s.dragonTrips.length == 3) return MjScore([const Fan('Drei große Drachen', 5)], 5, limit: true);
  if (s.windTrips.length == 4) return MjScore([const Fan('Vier große Winde', 5)], 5, limit: true);
  if (s.allHonors) return MjScore([const Fan('Nur Ehrensteine', 5)], 5, limit: true);
  final animals = animalCount(w.bonus);
  if (animals > 0) f.add(Fan('Tiere', animals));
  final own = ownBonus(w.bonus, w.seat);
  if (own > 0) f.add(Fan('Eigene Blume oder Jahreszeit', own));
  if (fullFlowers(w.bonus)) f.add(const Fan('Alle vier Blumen', 1));
  if (fullSeasons(w.bonus)) f.add(const Fan('Alle vier Jahreszeiten', 1));
  for (final g in s.dragonTrips) {
    f.add(Fan('Drache: ${tileName(g.first)}', 1));
  }
  if (s.hasTrip(w.seatWind)) f.add(const Fan('Sitzwind', 1));
  if (s.hasTrip(w.roundWind)) f.add(const Fan('Rundenwind', 1));
  if (s.allSeq && !s.dragonPair && s.pair != w.seatWind && s.pair != w.roundWind && s.wait == 'ryanmen') {
    f.add(Fan('Ping Hu (nur Folgen)', w.bonus.isEmpty ? 4 : 1));
  }
  if (s.special == 'sevenPairs') f.add(const Fan('Sieben Paare', 3));
  if (s.allTrip) f.add(const Fan('Nur Pungs', 2));
  if (s.fullFlush) {
    f.add(const Fan('Reine Farbe', 4));
  } else if (s.halfFlush) {
    f.add(const Fan('Halbe Farbe', 2));
  }
  if (s.dragonTrips.length == 2 && s.dragonPair) f.add(const Fan('Drei kleine Drachen', 2));
  if (s.windTrips.length == 3 && s.windPair) f.add(const Fan('Vier kleine Winde', 2));
  if (w.rinshan) f.add(const Fan('Blüte auf dem Kan', 1));
  if (w.lastTile) f.add(const Fan('Letzter Stein', 1));
  if (w.robKong) f.add(const Fan('Kan geraubt', 1));
  return _sum(f, cap: 5);
}

// ---------------------------------------------------------------- Korea (drei Spieler)

/// Korea zu dritt (Quelle: englische Wikipedia „Three-player mahjong“, Abschnitt Korean).
/// Handpunkte zählen fürs Minimum von 3, Bonuspunkte nicht. Grenze 40, kleine Drachen und kleine Winde 20.
MjScore scoreKorean(Shape s, WinInfo w) {
  int bonusPoints(List<Fan> into) {
    var b = 0;
    void add(String n, int v) {
      into.add(Fan(n, v));
      b += v;
    }

    if (w.tsumo) add('Aus der Mauer gewonnen', 1);
    if (w.lastTile) add('Letzter Stein der Mauer', 1);
    if (w.rinshan) add('Ersatzstein nach Blume oder Kan', 1);
    if (w.robKong) add('Kan geraubt', 1);
    final fl = w.bonus.length;
    if (fl > 0) add(fl == 4 ? 'Alle vier Blumen' : 'Blumen', fl + (fl == 4 ? 4 : 0));
    return b;
  }

  MjScore limit(String name, int value) {
    final f = [Fan(name, value)];
    final b = bonusPoints(f);
    return MjScore(f, value + b, extra: b, limit: true);
  }

  final windTrips = s.windTrips.length;
  if (s.special == 'orphans') return limit('Dreizehn Waisen', 40);
  if (s.dragonTrips.length == 3) return limit('Große Drachen', 40);
  if (windTrips == 3) return limit('Große Winde', 40);
  if (s.allHonors) return limit('Nur Ehrensteine', 40);
  if (s.special.isEmpty && s.concealedTrips == 4) return limit('Vier verdeckte Pungs', 40);
  if (s.kans.length == 4) return limit('Vier Kans', 40);
  if (_nineGates(s)) return limit('Neun Tore', 40);
  if (s.all.every((t) => t >= 18)) return limit('Nur Bambus und Ehren', 40);
  if (s.dragonTrips.length == 2 && s.dragonPair) return limit('Kleine Drachen', 20);
  if (windTrips == 2 && s.windPair) return limit('Kleine Winde', 20);

  final f = <Fan>[];
  final dragons = s.dragonTrips.length;
  for (final g in s.dragonTrips) {
    f.add(Fan('Drachen-Pung: ${tileName(g.first)}', 1));
  }
  if (dragons == 2) f.add(const Fan('Zwei Drachen-Pungs', 1));
  for (final g in s.windTrips) {
    f.add(Fan('Wind-Pung: ${tileName(g.first)}', 1));
  }
  if (s.hasTrip(w.seatWind)) f.add(const Fan('Eigener Wind', 1));
  if (s.hasTrip(w.roundWind)) f.add(const Fan('Rundenwind', 1));
  for (var k = 0; k < s.kans.length; k++) {
    f.add(const Fan('Kan', 1));
  }
  if (s.kans.length == 3) f.add(const Fan('Drei Kans', 3));
  final bam = [18, 26].where(s.hasTrip).length;
  for (var k = 0; k < bam; k++) {
    f.add(const Fan('Pung Bambus 1 oder 9', 1));
  }
  if (bam == 2) f.add(const Fan('Bambus 1 und 9', 4));
  final starts = [for (final g in s.seqs) g.first];
  if (starts.toSet().any((x) => starts.where((y) => y == x).length >= 2)) f.add(const Fan('Zwei gleiche Folgen', 2));
  if (s.concealedTrips >= 3) f.add(const Fan('Drei verdeckte Pungs', 3));
  if (s.allTrip) {
    f.add(const Fan('Nur Pungs', 3));
    if (s.allTermHonor) f.add(const Fan('Nur End- und Ehrensteine', 6));
  }
  if (s.halfFlush) f.add(const Fan('Halbe Farbe', 3));
  if (s.fullFlush) f.add(const Fan('Reine Farbe', 6));
  if (s.special == 'sevenPairs') f.add(const Fan('Sieben Paare', 3));
  if (s.pureStraight) f.add(const Fan('Straße 1 bis 9', 3));
  if (!s.hasHonor) {
    f.add(const Fan('Ohne Ehrensteine', 1));
    if (s.allSeq) f.add(const Fan('Nur Folgen mit einfachem Paar', 2));
  }
  if (s.concealed) {
    f.add(const Fan('Verdeckte Hand', 2));
    if (w.tsumo) f.add(const Fan('Verdeckt und aus der Mauer', 2));
  }
  final hand = min(40, f.fold(0, (a, x) => a + x.value));
  final b = bonusPoints(f);
  return MjScore(f, hand + b, extra: b, limit: hand >= 40);
}

// ---------------------------------------------------------------- Zung Jung

MjScore scoreZungJung(Shape s, WinInfo w) {
  final f = <Fan>[];
  if (w.heaven) f.add(const Fan('Segen des Himmels', 155));
  if (w.earth) f.add(const Fan('Segen der Erde', 155));
  if (s.special == 'orphans') {
    f.add(const Fan('Dreizehn Waisen', 160));
  } else if (s.special == 'sevenPairs') {
    f.add(const Fan('Sieben Paare', 30));
  }
  if (s.allSeq) f.add(const Fan('Nur Folgen', 5));
  if (s.concealed) f.add(const Fan('Verdeckte Hand', 5));
  if (s.allSimple) f.add(const Fan('Ohne Endsteine', 5));
  if (_nineGates(s)) {
    f.add(const Fan('Neun Tore', 480));
  } else if (s.fullFlush) {
    f.add(const Fan('Reine Farbe', 80));
  } else if (s.halfFlush) {
    f.add(const Fan('Halbe Farbe', 40));
  }
  final d = s.dragonTrips.length;
  if (d == 3) {
    f.add(const Fan('Drei große Drachen', 130));
  } else if (d == 2 && s.dragonPair) {
    f.add(const Fan('Drei kleine Drachen', 40));
  } else {
    for (var k = 0; k < d; k++) {
      f.add(const Fan('Drachen-Pung', 10));
    }
  }
  final wi = s.windTrips.length;
  if (wi == 4) {
    f.add(const Fan('Vier große Winde', 400));
  } else if (wi == 3 && s.windPair) {
    f.add(const Fan('Vier kleine Winde', 320));
  } else if (wi == 3) {
    f.add(const Fan('Drei große Winde', 120));
  } else if (wi == 2 && s.windPair) {
    f.add(const Fan('Drei kleine Winde', 30));
  }
  if (wi < 3) {
    if (s.hasTrip(w.seatWind)) f.add(const Fan('Sitzwind', 10));
    if (s.hasTrip(w.roundWind)) f.add(const Fan('Rundenwind', 10));
  }
  if (s.allHonors) f.add(const Fan('Nur Ehrensteine', 320));
  if (s.allTrip) f.add(const Fan('Nur Pungs', 30));
  final ct = s.concealedTrips;
  if (ct == 4) {
    f.add(const Fan('Vier verdeckte Pungs', 125));
  } else if (ct == 3) {
    f.add(const Fan('Drei verdeckte Pungs', 30));
  } else if (ct == 2) {
    f.add(const Fan('Zwei verdeckte Pungs', 5));
  }
  const kanVals = [0, 5, 20, 120, 480];
  if (s.kans.isNotEmpty) f.add(Fan('${s.kans.length} Kan', kanVals[s.kans.length]));
  final starts = [for (final g in s.seqs) g.first];
  final dupCounts = {for (final x in starts) x: starts.where((y) => y == x).length};
  final maxDup = dupCounts.values.fold(0, max);
  final pairsOfDup = dupCounts.values.where((n) => n == 2).length;
  if (maxDup == 4) {
    f.add(const Fan('Vier gleiche Folgen', 480));
  } else if (maxDup == 3) {
    f.add(const Fan('Drei gleiche Folgen', 120));
  } else if (pairsOfDup == 2) {
    f.add(const Fan('Zweimal zwei gleiche Folgen', 60));
  } else if (pairsOfDup == 1) {
    f.add(const Fan('Zwei gleiche Folgen', 10));
  }
  if (s.mixedTripleChow) f.add(const Fan('Ähnliche Folgen in drei Farben', 35));
  if (s.tripleTrip) {
    f.add(const Fan('Ähnliche Pungs in drei Farben', 120));
  } else {
    for (var n = 0; n < 9; n++) {
      final withTrip = [0, 1, 2].where((suit) => s.hasTrip(suit * 9 + n)).toList();
      if (withTrip.length == 2 && s.pair < 27 && s.pair % 9 == n && !withTrip.contains(suitOf(s.pair))) {
        f.add(const Fan('Kleine ähnliche Pungs', 30));
      }
    }
  }
  if (s.pureStraight) f.add(const Fan('Neun-Stein-Straße', 40));
  var consec = 0;
  for (var t = 0; t < 27; t++) {
    var k = 0;
    while (t + k < 27 && suitOf(t + k) == suitOf(t) && s.hasTrip(t + k)) {
      k++;
    }
    consec = max(consec, k);
  }
  if (consec >= 4) {
    f.add(const Fan('Vier aufeinanderfolgende Pungs', 200));
  } else if (consec == 3) {
    f.add(const Fan('Drei aufeinanderfolgende Pungs', 100));
  }
  if (s.special.isEmpty) {
    if (s.allTerminals) {
      f.add(const Fan('Reine große Enden', 400));
    } else if (s.allTermHonor) {
      f.add(const Fan('Gemischte große Enden', 100));
    } else if (s.outside && !s.hasHonor) {
      f.add(const Fan('Reine kleine Enden', 50));
    } else if (s.outside) {
      f.add(const Fan('Gemischte kleine Enden', 40));
    }
  }
  if (w.lastTile) f.add(Fan(w.tsumo ? 'Letzter Stein' : 'Letzter Abwurf', 10));
  if (w.rinshan) f.add(const Fan('Sieg auf dem Kan', 10));
  if (w.robKong) f.add(const Fan('Kan geraubt', 10));
  if (f.isEmpty) f.add(const Fan('Hühnerhand', 1));
  return _sum(f, cap: 320);
}

// ---------------------------------------------------------------- Westlich klassisch

/// Alte westliche Regel: Grundpunkte für Gruppen, danach Verdopplungen; Grenze 1000.
MjScore scoreWestern(Shape s, WinInfo w) {
  final f = <Fan>[const Fan('Mahjong', 20)];
  var base = 20;
  if (s.special == 'orphans') return MjScore([const Fan('Dreizehn Waisen (Grenzhand)', 1000)], 1000, limit: true);
  for (final g in s.trips) {
    var v = isTerminalOrHonor(g.first) ? 4 : 2;
    if (!g.open) v *= 2;
    if (g.kan) v *= 4;
    base += v;
  }
  if (s.trips.isNotEmpty) f.add(Fan('Pungs und Kans', base - 20));
  var pairPts = 0;
  if (s.pair >= 31 || s.pair == w.seatWind || s.pair == w.roundWind) pairPts = 2;
  if (pairPts > 0) f.add(Fan('Wertvolles Paar', pairPts));
  base += pairPts;
  if (w.tsumo) {
    f.add(const Fan('Selbst gezogen', 2));
    base += 2;
  }
  if (const {'kanchan', 'penchan', 'tanki'}.contains(s.wait)) {
    f.add(const Fan('Einzige Wartung', 2));
    base += 2;
  }
  if (w.bonus.isNotEmpty) {
    f.add(Fan('Blumen', 4 * w.bonus.length));
    base += 4 * w.bonus.length;
  }
  var doubles = 0;
  final dn = <String>[];
  void dbl(String n, [int k = 1]) {
    doubles += k;
    dn.add(n);
  }

  for (final g in s.dragonTrips) {
    dbl('Drachen-Pung ${tileName(g.first)}');
  }
  if (s.hasTrip(w.seatWind)) dbl('Sitzwind-Pung');
  if (s.hasTrip(w.roundWind)) dbl('Rundenwind-Pung');
  if (s.allTrip) dbl('Keine Folgen');
  if (s.concealed) dbl('Verdeckte Hand');
  if (s.allHonors) {
    dbl('Nur Ehrensteine', 3);
  } else if (s.fullFlush) {
    dbl('Reine Farbe', 3);
  } else if (s.halfFlush) {
    dbl('Halbe Farbe');
  }
  if (s.special == 'sevenPairs') dbl('Sieben Paare', 2);
  if (s.dragonTrips.length == 2 && s.dragonPair) dbl('Drei kleine Drachen');
  if (ownBonus(w.bonus, w.seat) == 2) dbl('Eigene Blume und Jahreszeit');
  if (fullFlowers(w.bonus) || fullSeasons(w.bonus)) dbl('Alle vier Blumen einer Art');
  if (w.lastTile) dbl('Letzter Stein');
  if (w.rinshan) dbl('Sieg auf dem Kan');
  if (w.robKong) dbl('Kan geraubt');
  for (final n in dn) {
    f.add(Fan('$n (verdoppelt)', 0));
  }
  final total = min(1000, base * (1 << min(doubles, 10)));
  return MjScore([...f, if (doubles > 0) Fan('$doubles× verdoppelt', 0)], total, limit: total >= 1000);
}

// ---------------------------------------------------------------- Philippinen

/// Philippinen (Quelle: mahjongero.com „Mahjong, as we play it“, filipinomj.com).
/// Eine volle Auszahlung sind vier Viertel. Kans, Sagasa, keine Blumen und 13 Blumen zahlt der Tisch sofort.
MjScore scoreFilipino(Shape s, WinInfo w) {
  final f = <Fan>[const Fan('Todas (Sieg)', 4)];
  if (w.heaven) f.add(const Fan('Bisaklat (Geber fertig ausgeteilt)', 4));
  if (w.early && !w.heaven) f.add(const Fan('Vor dem fünften Abwurf', 4));
  if (s.special == 'pairsPung') f.add(const Fan('Siete Pares', 2));
  if (s.pureStraight) f.add(const Fan('Escalera (1 bis 9)', 2));
  if (s.fullFlush) f.add(const Fan('Alles eine Farbe', 2));
  if (s.allSeq) f.add(const Fan('Nur Folgen', 1));
  if (s.allTrip) f.add(const Fan('Nur Pungs', 1));
  final openMelds = s.groups.where((g) => g.open).length;
  if (s.concealed) f.add(const Fan('All up (nichts aufgedeckt)', 1));
  if (s.special.isEmpty && openMelds == 5 && s.wait == 'tanki') f.add(const Fan('All down (alles aufgedeckt)', 1));
  if (s.special.isEmpty && s.wait == 'tanki') f.add(const Fan('Single (Warten aufs Paar)', 1));
  if (s.special.isEmpty && s.wait == 'shanpon') f.add(const Fan('Back to back (zwei Paare)', 1));
  if (s.special.isEmpty && s.wait == 'kanchan') f.add(const Fan('Paningit (Lücke in der Folge)', 1));
  if (w.tsumo) f.add(const Fan('Bunot (selbst gezogen): alle zahlen doppelt', 0));
  return MjScore(f, f.fold(0, (a, x) => a + x.value));
}

// ---------------------------------------------------------------- Vietnam

/// Phán für einen beiseitegelegten Stein (Blume, Joker). Kaiser und Kaiserin zählen nichts.
int vietBonusPhan(int t, int seat) {
  if (t >= firstFlower && t < firstAnimal) return (t - firstFlower) % 4 == seat ? 1 : 0;
  return switch (t) {
    47 => 2 + (seat == 0 ? 1 : 0),
    48 => 1 + (seat == 1 ? 1 : 0),
    49 => 1 + (seat == 2 ? 1 : 0),
    50 => 1 + (seat == 3 ? 1 : 0),
    51 => 2,
    52 => 1 + (seat == 1 ? 1 : 0),
    53 => 1 + (seat == 2 ? 1 : 0),
    54 => 2 + (seat == 3 ? 1 : 0),
    _ => 0,
  };
}

/// Auszahlung zu Phán: 0 und 1 zahlen 1, dann verdoppelt sich jeder Phán.
const _vietPhanPay = [1, 1, 2, 4, 8, 16];

/// Vietnam (Quelle: riichi_advanced, documentation/vietnamese.md). Phán sind die Grundeinheit, 6 Phán sind 1 Mủn;
/// ab 1 Mủn zählen übrige Phán nicht mehr. points ist die Auszahlung (1 Mủn = 32).
MjScore scoreVietnam(Shape s, WinInfo w) {
  final f = <Fan>[];
  var phan = 0;
  var mun = 0;
  void p(String n, int v) {
    if (v == 0) return;
    f.add(Fan(n, v, unit: 'Phán'));
    phan += v;
  }

  void m(String n, int v) {
    f.add(Fan(n, v, unit: 'Mủn'));
    mun += v;
  }

  for (final t in w.bonus) {
    p(tileName(t), vietBonusPhan(t, w.seat));
  }
  final noJokers = s.jokers == 0;
  final noFlowers = w.bonus.isEmpty;
  int plus(int base) => base + (noJokers ? 1 : 0) + (noFlowers ? 1 : 0);

  if (s.special == 'orphans') {
    m('Dreizehn Waisen', 2);
  } else {
    // Keine Blumen, keine Blätter: nur echte Farbsteine, nichts beiseitegelegt, Sieg auf einen Farbstein
    final nfnl = noFlowers && noJokers && !s.hasHonor && w.winTile < 27;
    if (nfnl) {
      final opts = <(String, int)>[('Keine Blumen, keine Blätter', 3)];
      if (s.allTrip) opts.add(('Keine Blumen, keine Blätter, nur Pungs', 4));
      if (s.fullFlush) opts.add(('Keine Blumen, keine Blätter, eine Farbe', 5));
      if (s.fullFlush && s.allTrip) opts.add(('Keine Blumen, keine Blätter, eine Farbe, nur Pungs', 6));
      if (s.concealed && s.allSeq && s.wait == 'tanki') opts.add(('Keine Blumen, keine Blätter, verdeckt, nur Folgen, Einzelwartung', 4));
      if (s.concealed && s.allTrip) opts.add(('Keine Blumen, keine Blätter, verdeckt, nur Pungs', 6));
      if (s.concealed && s.fullFlush && s.allTrip) opts.add(('Keine Blumen, keine Blätter, verdeckt, eine Farbe, nur Pungs', 8));
      opts.sort((a, b) => b.$2 - a.$2);
      m(opts.first.$1, opts.first.$2);
    } else if (noFlowers && !s.hasHonor) {
      if (s.allSeq) {
        m('Ohne Blumen, Ehren und Pungs', 2);
      } else {
        m('Ohne Blumen und Ehren', 1);
      }
    }
    // Pung-Hände: die höchste zählt
    if (s.allTrip) {
      final called = s.trips.every((g) => g.open);
      if (called && s.hasHonor) {
        m('Nur gerufene Pungs mit Ehren', 2);
      } else if (called) {
        m('Nur gerufene Pungs', 1);
      } else if (s.hasHonor) {
        m('Nur Pungs mit Ehren', 1);
      } else if (s.allTermHonor) {
        m('Nur Pungs aus Endsteinen', 1);
      } else {
        p('Nur Pungs', 3);
      }
    }
    if (s.allSeq) {
      if (isHonor(s.pair)) {
        p('Nur Folgen mit Ehren-Paar', 3);
      } else if (!(noFlowers && !s.hasHonor)) {
        p('Nur Folgen', 1);
      }
    }
    if (s.fullFlush) m('Eine Farbe', 2);
    if (s.pureStraight) m('Straße 1 bis 9', 3);
    if (s.allHonors) m('Nur Ehrensteine', 4);
    if (s.dragonTrips.length == 3) {
      m('Große drei Drachen', 2);
    } else if (s.dragonTrips.length == 2 && s.dragonPair) {
      m('Kleine drei Drachen', 1);
    }
    if (s.windTrips.length == 4) {
      m('Große vier Winde', plus(8));
    } else if (s.windTrips.length == 3 && s.windPair) {
      m('Kleine vier Winde', plus(5));
    }
    if (s.kans.length == 4) {
      m('Vier Kans', plus(4));
    } else if (s.special.isEmpty && s.concealedTrips == 4) {
      m('Vier verdeckte Pungs', plus(3));
    }
  }
  if (w.heaven) m('Segen des Himmels', 2);
  if (w.earth && !w.tsumo) m('Segen der Erde', 2);
  if (w.earth && w.tsumo) m('Segen des Menschen', 2);
  if (!w.tsumo && isJokerTile(w.winTile)) m('Gewonnen auf einen Joker', 1);

  mun += phan ~/ 6;
  final pay = mun > 0 ? 32 * mun : _vietPhanPay[phan];
  if (f.isEmpty) f.add(const Fan('Hühnerhand (0 Phán)', 0));
  return MjScore(f, pay, limit: mun > 0);
}

/// Nur zur Anzeige: wie viele Gruppen ein Meld hat.
int meldTileCount(Meld m) => m.tiles.length;

/// War [win] der einzige Stein, auf den die Hand gewartet hat? Kans zählen wie Pungs.
bool _onlyWait(Shape s, int win) {
  final c = countsPlain(s.all);
  for (final g in s.kans) {
    c[g.first]--;
  }
  if (c[win] == 0) return true;
  c[win]--;
  for (var t = 0; t < tileKinds; t++) {
    if (t == win || c[t] >= 4) continue;
    c[t]++;
    final done = decompositionsJ(c, 0, limit: 1).isNotEmpty || isSevenPairs(c, 0) || isThirteenOrphans(c) || knittedHonors(c) >= 5 || isKnittedStraightHand(c, 0);
    c[t]--;
    if (done) return false;
  }
  return true;
}
