import 'dart:math';

import 'riichi_engine.dart';
import 'riichi_hand.dart';
import 'tiles.dart';

/// Wie viele Steine die Hand verbessern würden (Ukeire), gemessen an den noch unsichtbaren Steinen.
int ukeire(List<int> counts, int melds, List<int> visible) {
  final base = shanten(counts, melds);
  var n = 0;
  for (var t = 0; t < tileKinds; t++) {
    final left = 4 - visible[t];
    if (left <= 0) continue;
    counts[t]++;
    if (shanten(counts, melds) < base) n += left;
    counts[t]--;
  }
  return n;
}

/// Wie gefährlich ein Abwurf gegen einen Spieler in Riichi ist, kleiner ist sicherer.
int danger(RiichiGame g, int me, int t) {
  var worst = 0;
  for (var p = 0; p < 4; p++) {
    if (p == me || !g.players[p].riichi) continue;
    final discards = g.players[p].discards.map((d) => d.tile).toSet();
    int d;
    if (discards.contains(t)) {
      d = 0;
    } else if (isHonor(t)) {
      final seen = g.visibleCounts(me)[t];
      d = seen >= 3 ? 1 : (seen == 2 ? 3 : 6);
    } else {
      final n = numberOf(t);
      // Suji: Ist die 4 abgeworfen, sind 1 und 7 sicherer
      final suji = (n > 3 && discards.contains(t - 3)) || (n < 7 && discards.contains(t + 3));
      d = suji ? 4 : (isTerminal(t) ? 5 : 8);
    }
    worst = max(worst, d);
  }
  return worst;
}

/// Entscheidung am eigenen Zug.
sealed class BotTurn {}

class BotTsumo extends BotTurn {}

class BotKan extends BotTurn {
  BotKan(this.tile);
  final int tile;
}

class BotDiscard extends BotTurn {
  BotDiscard(this.tile, {this.riichi = false});
  final int tile;
  final bool riichi;
}

BotTurn botTurn(RiichiGame g, int p, Random rng) {
  final pl = g.players[p];
  if (g.canTsumo(p)) return BotTsumo();
  if (pl.riichi && g.drawn != null) return BotDiscard(g.drawn!);
  // Verdeckter Kan nur, wenn er die Hand nicht verschlechtert
  for (final t in g.kanOptions(p)) {
    final c = countsOf(pl.hand);
    if (c[t] == 4) {
      final rest = [...pl.hand]..removeWhere((x) => x == t);
      if (shanten(countsOf(rest), pl.meldCount + 1) <= shanten(countsOf([...pl.hand]..remove(t)), pl.meldCount)) {
        return BotKan(t);
      }
    }
  }
  final visible = g.visibleCounts(p);
  final threat = g.players.any((o) => o != pl && o.riichi);
  final counts = countsOf(pl.hand);
  final current = shanten(counts, pl.meldCount);
  final doras = g.doraTiles;
  int? best;
  var bestScore = -1e9;
  for (final t in pl.hand.toSet()) {
    counts[t]--;
    final s = shanten(counts, pl.meldCount);
    final u = ukeire(counts, pl.meldCount, visible);
    counts[t]++;
    var score = -s * 1000.0 + u * 10;
    if (doras.contains(t)) score -= 40;
    if (isHonor(t)) score += 6;
    if (isTerminal(t)) score += 3;
    // Gegen Riichi lieber sicher abwerfen, wenn die eigene Hand weit weg ist
    if (threat && current >= 1) score -= danger(g, p, t) * (current >= 2 ? 400 : 120);
    score += rng.nextDouble();
    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  final riichiOk = g.riichiDiscards(p);
  if (riichiOk.contains(best) && !threat) return BotDiscard(best!, riichi: true);
  if (riichiOk.isNotEmpty && !riichiOk.contains(best)) {
    // Gibt es einen Riichi-Abwurf, der kaum schlechter ist, nimm ihn
    return BotDiscard(riichiOk.first, riichi: !threat || danger(g, p, riichiOk.first) <= 1);
  }
  return BotDiscard(best!);
}

/// Antwort auf einen fremden Abwurf.
ClaimOption botClaim(RiichiGame g, int q, List<ClaimOption> options) {
  final ron = options.where((o) => o.type == ClaimType.ron);
  if (ron.isNotEmpty) return ron.first;
  final pl = g.players[q];
  final t = g.lastDiscard!;
  final counts = countsOf(pl.hand);
  final before = shanten(counts, pl.meldCount);
  final valueTile = t >= 31 || t == g.seatWind(q) || t == g.roundWind;
  final hasYakuhai = pl.melds.any((m) => m.isTriplet && (m.first >= 31 || m.first == g.seatWind(q) || m.first == g.roundWind));
  final allSimple = pl.hand.every(isSimple) && pl.melds.every((m) => m.tiles.every(isSimple));
  for (final o in options) {
    if (o.type == ClaimType.pon) {
      final after = [...pl.hand]
        ..remove(t)
        ..remove(t);
      // Danach muss noch ein Stein weg; geschätzt am besten Abwurf
      final s = _bestShantenAfterDiscard(after, pl.meldCount + 1);
      if (valueTile && s <= before) return o;
      if ((hasYakuhai || (allSimple && isSimple(t))) && s < before) return o;
    }
    if (o.type == ClaimType.chi && (hasYakuhai || (allSimple && isSimple(t)))) {
      final after = [...pl.hand];
      for (final x in o.tiles) {
        after.remove(x);
      }
      if (_bestShantenAfterDiscard(after, pl.meldCount + 1) < before) return o;
    }
  }
  return const ClaimOption(ClaimType.pass);
}

int _bestShantenAfterDiscard(List<int> hand, int melds) {
  final c = countsOf(hand);
  var best = 99;
  for (final t in hand.toSet()) {
    c[t]--;
    best = min(best, shanten(c, melds));
    c[t]++;
  }
  return best;
}
