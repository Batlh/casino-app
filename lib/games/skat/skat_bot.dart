import 'dart:math';

import '../cards/playing_card.dart';
import 'skat_engine.dart';

const _suitGames = [SkatType.diamonds, SkatType.hearts, SkatType.spades, SkatType.clubs];

/// Stärke einer Hand für ein Spiel; über etwa 8,5 lohnt es sich.
double skatStrength(List<PlayingCard> hand, SkatType t) {
  if (t == SkatType.nullGame) return _nullStrength(hand);
  var s = 0.0;
  final jacks = hand.where((c) => c.rank == 11).toList();
  for (final j in jacks) {
    s += const {Suit.clubs: 3.0, Suit.spades: 2.5, Suit.hearts: 2.0, Suit.diamonds: 1.6}[j.suit]!;
  }
  final ts = trumpSuitOf(t);
  final trumps = hand.where((c) => isTrump(c, t)).length;
  if (ts != null) {
    for (final c in hand.where((c) => c.suit == ts && c.rank != 11)) {
      s += switch (c.rank) { 14 => 1.6, 10 => 1.3, 13 => 0.9, _ => 0.6 };
    }
  }
  for (final suit in Suit.values) {
    if (suit == ts) continue;
    final cards = hand.where((c) => c.suit == suit && c.rank != 11).map((c) => c.rank).toSet();
    if (cards.contains(14)) s += 1.4;
    if (cards.contains(10)) s += cards.contains(14) ? 1.0 : 0.3;
    if (cards.isEmpty && (ts == null ? jacks.length >= 2 : trumps >= 5)) s += 0.6;
  }
  if (t == SkatType.grand) {
    // Grand braucht Buben und Asse
    if (jacks.length < 2) return 0;
    return s + (jacks.length >= 3 ? 1.5 : 0);
  }
  if (trumps < 5) return s * 0.6;
  return s + (trumps - 5) * 0.9;
}

double _nullStrength(List<PlayingCard> hand) {
  // Jede Farbe braucht kleine Karten unter den großen
  var s = 10.0;
  for (final suit in Suit.values) {
    final ranks = hand.where((c) => c.suit == suit).map((c) => power(c, SkatType.nullGame)).toList()..sort();
    for (var i = 0; i < ranks.length; i++) {
      // Die i-te kleinste Karte sollte höchstens Stärke 2*i+2 haben
      if (ranks[i] > 2 * i + 2) s -= ranks[i] - (2 * i + 2);
    }
  }
  return s;
}

const skatPlayable = 8.5;

/// Höchster Reizwert, den der Computer mitgeht, 0 heißt passen.
int skatMaxBid(List<PlayingCard> hand) {
  var best = 0;
  for (final t in [..._suitGames, SkatType.grand]) {
    if (skatStrength(hand, t) < skatPlayable + (t == SkatType.grand ? 1 : 0)) continue;
    final base = const {SkatType.diamonds: 9, SkatType.hearts: 10, SkatType.spades: 11, SkatType.clubs: 12, SkatType.grand: 24}[t]!;
    // Bei „ohne“ vorsichtig: höchstens ohne 2 zählen
    final sp = spitzen(hand, t);
    final mit = hand.contains(const PlayingCard(11, Suit.clubs));
    final m = (mit ? sp : min(sp, 2)) + 1;
    best = max(best, base * m);
  }
  if (_nullStrength(hand) >= 9.5) best = max(best, 23);
  return best;
}

/// Bestes Spiel für zwölf Karten (nach dem Skat), möglichst mit genug Wert für den Reizwert.
SkatType skatChooseGame(SkatGame g, List<PlayingCard> cards) {
  SkatType? best;
  var bestScore = -1e9;
  for (final t in [..._suitGames, SkatType.grand, SkatType.nullGame]) {
    final s = skatStrength(cards, t);
    final value = g.baseGameValue(t, cards, hand: g.hand);
    final enough = value >= g.bid;
    final score = s + (enough ? 5 : -20) + (t == SkatType.grand ? 0.5 : 0);
    if (score > bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return best!;
}

/// Zwei Karten in den Skat: volle Karten aus kurzen Farben ohne Ass, sonst Fehlfarben blank machen.
List<PlayingCard> skatDiscard(List<PlayingCard> cards, SkatType t) {
  final cand = cards.where((c) => !isTrump(c, t)).toList();
  if (t == SkatType.nullGame) {
    cand.sort((a, b) => power(b, t) - power(a, t));
    return cand.take(2).toList();
  }
  int len(Suit s) => cand.where((c) => c.suit == s).length;
  bool hasAce(Suit s) => cand.any((c) => c.suit == s && c.rank == 14);
  double value(PlayingCard c) {
    var v = cardPoints(c).toDouble();
    if (c.rank == 14) v -= 20;
    if (c.rank == 10 && hasAce(c.suit)) v -= 8;
    v += (4 - len(c.suit)) * 2;
    return v;
  }

  if (cand.length < 2) {
    final all = [...cards]..sort((a, b) => power(a, t) - power(b, t));
    return all.take(2).toList();
  }
  cand.sort((a, b) => value(b).compareTo(value(a)));
  return cand.take(2).toList();
}

/// Kartenwahl im Spiel.
PlayingCard skatBotCard(SkatGame g, int p, Random rng) {
  final legal = g.legalCards(p);
  if (legal.length == 1) return legal.first;
  final t = g.type;
  final seen = <PlayingCard>{
    for (final pl in g.players) ...pl.won,
    ...g.trick,
    ...g.players[p].hand,
    if (p == g.declarer) ...g.skat,
  };
  final unseen = [
    for (final s in Suit.values)
      for (final r in const [7, 8, 9, 10, 11, 12, 13, 14])
        if (!seen.contains(PlayingCard(r, s))) PlayingCard(r, s),
  ];
  final declarer = p == g.declarer;

  if (t == SkatType.nullGame) return _nullCard(g, p, legal, declarer);

  PlayingCard lowest(List<PlayingCard> cs) => (cs..sort((a, b) {
        final d = cardPoints(a) - cardPoints(b);
        if (d != 0) return d;
        final ta = isTrump(a, t) ? 1 : 0, tb = isTrump(b, t) ? 1 : 0;
        if (ta != tb) return ta - tb;
        return power(a, t) - power(b, t);
      }))
          .first;

  if (g.trick.isEmpty) {
    final trumps = legal.where((c) => isTrump(c, t)).toList()..sort((a, b) => power(b, t) - power(a, t));
    final enemyTrumps = unseen.where((c) => isTrump(c, t)).toList();
    if (declarer) {
      if (trumps.isNotEmpty && enemyTrumps.isNotEmpty) {
        final topEnemy = enemyTrumps.map((c) => power(c, t)).reduce(max);
        return power(trumps.first, t) > topEnemy ? trumps.first : trumps.last;
      }
      final aces = legal.where((c) => !isTrump(c, t) && c.rank == 14).toList();
      if (aces.isNotEmpty) return aces.first;
      return lowest(legal.where((c) => !isTrump(c, t)).toList().isEmpty ? legal : legal.where((c) => !isTrump(c, t)).toList());
    }
    // Gegenspieler: Asse ziehen, sonst kurze Farbe anspielen
    final aces = legal.where((c) => !isTrump(c, t) && c.rank == 14).toList();
    if (aces.isNotEmpty) return aces.first;
    final side = legal.where((c) => !isTrump(c, t)).toList();
    if (side.isNotEmpty) {
      int len(Suit s) => side.where((c) => c.suit == s).length;
      side.sort((a, b) => len(a.suit) != len(b.suit) ? len(a.suit) - len(b.suit) : cardPoints(a) - cardPoints(b));
      return side.first;
    }
    return lowest(legal);
  }

  // Folgen
  final winIdx = trickWinner(g.trick, t);
  final winner = (g.trickStarter + winIdx) % 3;
  final last = g.trick.length == 2;
  final friendWins = g.sameTeam(winner, p) && winner != p;
  final pts = g.trick.fold(0, (a, c) => a + cardPoints(c));
  if (friendWins && (last || p != g.declarer)) {
    // Schmieren: volle Karte zum Partner, wenn er sicher hat
    final safe = last || !_beatable(g.trick, unseen, t);
    if (safe) {
      final rich = [...legal]..sort((a, b) => cardPoints(b) - cardPoints(a));
      final candidate = rich.firstWhere((c) => !(isTrump(c, t) && c.rank == 11), orElse: () => rich.first);
      return candidate;
    }
    return lowest(legal);
  }
  final beaters = legal.where((c) => trickWinner([...g.trick, c], t) == g.trick.length).toList()
    ..sort((a, b) => power(a, t) - power(b, t) + (isTrump(a, t) ? 50 : 0) - (isTrump(b, t) ? 50 : 0));
  if (beaters.isNotEmpty && (pts >= 3 || last || declarer)) {
    // Mit der kleinsten Karte stechen, die sicher bleibt
    for (final b in beaters) {
      if (last || !_beatable([...g.trick, b], unseen, t)) return b;
    }
    return beaters.first;
  }
  return lowest(legal);
}

/// Kann noch eine unbekannte Karte diesen Stich übernehmen?
bool _beatable(List<PlayingCard> trick, List<PlayingCard> unseen, SkatType t) {
  for (final u in unseen) {
    if (trickWinner([...trick, u], t) == trick.length) return true;
  }
  return false;
}

PlayingCard _nullCard(SkatGame g, int p, List<PlayingCard> legal, bool declarer) {
  const t = SkatType.nullGame;
  final sorted = [...legal]..sort((a, b) => power(a, t) - power(b, t));
  if (declarer) {
    if (g.trick.isEmpty) return sorted.first;
    // Höchste Karte, die noch unter dem Stich bleibt
    final under = sorted.where((c) => trickWinner([...g.trick, c], t) != g.trick.length).toList();
    if (under.isNotEmpty) return under.last;
    return sorted.first;
  }
  // Gegenspieler wollen den Alleinspieler zum Stechen zwingen
  if (g.trick.isEmpty) return sorted.first;
  final winner = (g.trickStarter + trickWinner(g.trick, t)) % 3;
  if (winner == g.declarer) return sorted.last;
  return sorted.first;
}
