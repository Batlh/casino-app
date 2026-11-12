import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_engine.dart';
import 'mj_hand.dart';
import 'mj_scoring.dart' show vietBonusPhan;

sealed class MjBotTurn {}

class MjBotWin extends MjBotTurn {}

class MjBotKan extends MjBotTurn {
  MjBotKan(this.tile);
  final int tile;
}

class MjBotJoker extends MjBotTurn {
  MjBotJoker(this.tile);
  final int tile;
}

class MjBotDiscard extends MjBotTurn {
  MjBotDiscard(this.tile);
  final int tile;
}

int _shanten(MjGame g, List<int> hand, int melds) => shantenN(
      countsPlain(hand),
      melds,
      g.rules.sets,
      jokers: jokersIn(hand),
      sevenPairs: g.rules.sevenPairs,
      orphans: g.rules.orphans,
    );

/// Welche Farbe ein Computer sammelt, wenn die Regel Wert verlangt. -1 heißt keine.
int planSuit(MjGame g, int p) {
  final pl = g.players[p];
  if (g.rules.minScore == 0 && !g.rules.voidSuit) return -1;
  final all = [...pl.hand, for (final m in pl.melds) ...m.tiles];
  final per = [for (var s = 0; s < 3; s++) all.where((t) => t < 27 && suitOf(t) == s).length];
  final honors = all.where(isHonor).length;
  var best = 0;
  for (var s = 1; s < 3; s++) {
    if (per[s] > per[best]) best = s;
  }
  // Mischfarben in den Figuren machen den Plan unmöglich
  final meldSuits = {for (final m in pl.melds) for (final t in m.tiles) if (t < 27) suitOf(t)};
  if (meldSuits.length > 1) return -1;
  if (meldSuits.isNotEmpty && meldSuits.first != best) return -1;
  final need = g.rules.minScore >= 8 ? 0.55 : 0.65;
  return per[best] + honors >= (all.length * need).ceil() ? best : -1;
}

MjBotTurn mjBotTurn(MjGame g, int p, Random rng) {
  final pl = g.players[p];
  if (g.canTsumo(p)) return MjBotWin();
  if (pl.locked && g.drawn != null) return MjBotDiscard(g.drawn!);
  // Vietnam: Joker mit Sitzbonus ablegen, solange die Hand noch weit weg ist
  for (final t in g.declarableJokers(p)) {
    if (vietBonusPhan(t, g.seatOf(p)) >= 2 && _bestAfterDiscard(g, pl.hand, pl.meldCount) >= 3) return MjBotJoker(t);
  }
  for (final t in g.kanOptions(p)) {
    final c = countsPlain(pl.hand);
    final before = _bestAfterDiscard(g, pl.hand, pl.meldCount);
    final rest = [...pl.hand]..removeWhere((x) => x == t);
    final after = c[t] == 4 ? _shanten(g, rest, pl.meldCount + 1) : _bestAfterDiscard(g, rest, pl.meldCount);
    if (after <= before) return MjBotKan(t);
  }
  return MjBotDiscard(mjBestDiscard(g, p, rng));
}

int _bestAfterDiscard(MjGame g, List<int> hand, int melds) {
  var best = 99;
  for (final t in hand.toSet()) {
    final rest = [...hand]..remove(t);
    best = min(best, _shanten(g, rest, melds));
  }
  return best;
}

int mjBestDiscard(MjGame g, int p, Random rng) {
  final pl = g.players[p];
  final visible = g.visibleCounts(p);
  final plan = planSuit(g, p);
  int? best;
  var bestScore = -1e9;
  for (final t in pl.hand.toSet()) {
    if (!g.canDiscard(p, t)) continue;
    final rest = [...pl.hand]..remove(t);
    final s = _shanten(g, rest, pl.meldCount);
    var ukeire = 0;
    final c = countsPlain(rest);
    final j = jokersIn(rest);
    for (final k in g.rules.kinds) {
      final left = 4 - visible[k];
      if (left <= 0) continue;
      c[k]++;
      if (shantenN(c, pl.meldCount, g.rules.sets, jokers: j, sevenPairs: g.rules.sevenPairs) < s) ukeire += left;
      c[k]--;
    }
    var score = -s * 1000.0 + ukeire * 8;
    if (isJokerTile(t)) score -= 5000;
    if (isHonor(t)) {
      final pairs = pl.hand.where((x) => x == t).length;
      final valuable = t >= 31 || t == g.seatWind(p) || t == g.roundWind;
      score += pairs >= 2 ? (valuable ? -60 : -20) : (valuable ? 2 : 8);
    }
    if (isTerminal(t)) score += 3;
    if (plan >= 0) {
      if (t < 27 && suitOf(t) != plan) score += 120;
      if (t < 27 && suitOf(t) == plan) score -= 60;
    }
    score += rng.nextDouble();
    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return best ?? pl.hand.firstWhere((t) => g.canDiscard(p, t), orElse: () => pl.hand.last);
}

MjOption mjBotClaim(MjGame g, int q, List<MjOption> options) {
  final win = options.where((o) => o.type == MjClaimType.win);
  if (win.isNotEmpty) return win.first;
  final pl = g.players[q];
  final t = g.lastDiscard!;
  final before = _shanten(g, pl.hand, pl.meldCount);
  final plan = planSuit(g, q);
  final fits = plan < 0 ? g.rules.minScore <= 1 : (t >= 27 || suitOf(t) == plan);
  final valueTile = t >= 31 || t == g.seatWind(q) || t == g.roundWind;
  for (final o in options) {
    final after = [...pl.hand];
    for (final x in o.tiles) {
      after.remove(x);
    }
    if (o.type == MjClaimType.kan) {
      final s = _shanten(g, after, pl.meldCount + 1);
      if (s <= before && (fits || g.rules.voidSuit)) return o;
    }
    if (o.type == MjClaimType.pon) {
      final s = _bestAfterDiscard(g, after, pl.meldCount + 1);
      if ((valueTile && s <= before) || (s < before && (fits || g.rules.voidSuit))) return o;
    }
    if (o.type == MjClaimType.chi) {
      final s = _bestAfterDiscard(g, after, pl.meldCount + 1);
      if (s < before && fits && before <= 3) return o;
    }
  }
  return const MjOption(MjClaimType.pass);
}

/// Für die Anzeige der eigenen Hand: wie weit bis fertig.
int mjShanten(MjGame g, int p) => _shanten(g, g.players[p].hand, g.players[p].meldCount);

bool isMeldOpen(Meld m) => m.open;
