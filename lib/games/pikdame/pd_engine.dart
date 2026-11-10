import '../../core/action_log.dart';
import 'dart:math';

import '../cards/playing_card.dart';

/// Pik Dame: Rommé mit 2×52 Karten und 6 Jokern. Die Pik Dame zählt 100.
/// Sätze (gleicher Rang, verschiedene Farben) und Folgen (gleiche Farbe) ab drei Karten, höchstens ein Joker je Auslage.

class PdCard {
  const PdCard(this.rank, this.suit, this.id);
  const PdCard.joker(this.id)
      : rank = 0,
        suit = null;

  /// 2 bis 14 (Ass), 0 beim Joker.
  final int rank;
  final Suit? suit;

  /// Eindeutig, weil es jede Karte doppelt gibt.
  final int id;

  bool get joker => suit == null;
  bool get pikDame => rank == 12 && suit == Suit.spades;
  PlayingCard get card => PlayingCard(rank, suit!);

  String get name => joker ? 'Joker' : card.spokenName;

  @override
  bool operator ==(Object other) => other is PdCard && other.id == id;

  @override
  int get hashCode => id;
}

class PdOptions {
  const PdOptions({this.jokerValue = 25, this.maxJokers = 1, this.firstMeld50 = true, this.target = 1000, this.players = 3});

  /// Wert des Jokers: 25 (Standard), 20 oder 15.
  final int jokerValue;

  /// Joker je Auslage: üblich einer, wenn nötig auch zwei.
  final int maxJokers;
  final bool firstMeld50;
  final int target;
  final int players;
}

int pdValue(PdCard c, PdOptions o) {
  if (c.joker) return o.jokerValue;
  if (c.pikDame) return 100;
  if (c.rank == 14) return 25;
  if (c.rank >= 10) return 10;
  return 5;
}

/// Eine Auslage. Jede Position kennt die Karte und den Rang, den sie darstellt.
class PdMeld {
  PdMeld(this.run, this.cards, this.ranks, this.suit, this.owner);
  final bool run;
  final List<PdCard> cards;

  /// Dargestellter Rang je Karte (bei Folgen 1 für das tiefe Ass).
  final List<int> ranks;

  /// Farbe der Folge, bei Sätzen null.
  final Suit? suit;
  final int owner;

  int get jokerCount => cards.where((c) => c.joker).length;
  int points(PdOptions o) => cards.fold(0, (a, c) => a + pdValue(c, o));
}

/// Prüft eine Kartenmenge und baut daraus eine Auslage, oder null.
/// Sätze: gleicher Wert, Farben dürfen doppelt sein. Folgen: eine Farbe, Ass tief oder hoch.
PdMeld? pdBuildMeld(List<PdCard> cards, int owner, {int maxJokers = 1}) {
  if (cards.length < 3) return null;
  final jokers = cards.where((c) => c.joker).toList();
  if (jokers.length > maxJokers) return null;
  final real = cards.where((c) => !c.joker).toList();
  if (real.length < 2) return null;
  // Satz
  if (real.every((c) => c.rank == real.first.rank)) {
    return PdMeld(false, [...real, ...jokers], [for (final _ in cards) real.first.rank], null, owner);
  }
  // Folge
  final suit = real.first.suit;
  if (real.any((c) => c.suit != suit)) return null;
  for (final aceLow in [false, true]) {
    final rs = [for (final c in real) c.rank == 14 && aceLow ? 1 : c.rank]..sort();
    if (rs.toSet().length != rs.length) continue;
    final span = rs.last - rs.first + 1;
    final gaps = span - rs.length;
    if (gaps > jokers.length) continue;
    // Joker füllen Lücken, übrige hängen oben an, sonst unten
    var lo = rs.first;
    var hi = rs.last;
    for (var k = 0; k < jokers.length - gaps; k++) {
      if (hi < 14) {
        hi++;
      } else {
        lo--;
      }
    }
    if (lo < 1 || hi > 14 || (lo == 1 && hi == 14)) continue;
    final ordered = <PdCard>[];
    final ranks = <int>[];
    var ji = 0;
    for (var r = lo; r <= hi; r++) {
      final i = rs.indexOf(r);
      if (i >= 0) {
        ordered.add(real.firstWhere((c) => (c.rank == 14 && aceLow ? 1 : c.rank) == r));
      } else {
        ordered.add(jokers[ji++]);
      }
      ranks.add(r);
    }
    if (ordered.length != cards.length) continue;
    return PdMeld(true, ordered, ranks, suit, owner);
  }
  return null;
}

/// Lässt sich die Karte an die Auslage legen? Gibt die neue Auslage zurück.
PdMeld? pdExtend(PdMeld m, PdCard c, {int maxJokers = 1}) => pdBuildMeld([...m.cards, c], m.owner, maxJokers: maxJokers);

/// Welcher Joker der Auslage lässt sich durch die echte Karte ersetzen? -1 heißt keiner.
int pdSwapIndex(PdMeld m, PdCard c) {
  if (c.joker) return -1;
  for (var i = 0; i < m.cards.length; i++) {
    if (!m.cards[i].joker) continue;
    if (m.run) {
      if (c.suit == m.suit && (c.rank == m.ranks[i] || (c.rank == 14 && m.ranks[i] == 1))) return i;
    } else if (c.rank == m.ranks[0]) {
      return i;
    }
  }
  return -1;
}

bool pdCanSwapJoker(PdMeld m, PdCard c) => pdSwapIndex(m, c) >= 0;

class PdPlayer {
  PdPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<PdCard> hand = [];
  int score = 0;
  int roundScore = 0;

  /// Hat in dieser Runde schon ausgelegt (vor dem aktuellen Zug).
  bool hasMelded = false;
}

enum PdPhase { draw, play, roundOver, gameOver }

class PdRoundResult {
  PdRoundResult(this.winner, this.hand, this.changes, this.text);
  final int winner;

  /// Alles auf einmal ausgelegt („Hand“).
  final bool hand;
  final List<int> changes;
  final String text;
}

class PdGame with ActionLog {
  PdGame(this.options, {Random? rng, List<String> names = const ['Du', 'Oma Erna', 'Opa Karl', 'Tante Gisela']})
      : _rng = rng ?? Random.secure(),
        players = [for (var i = 0; i < options.players; i++) PdPlayer(names[i], human: i == 0)];

  final PdOptions options;
  final Random _rng;
  final List<PdPlayer> players;
  List<PdCard> stack = [];
  List<PdCard> pile = [];
  List<PdMeld> melds = [];
  int dealer = 0;
  int current = 0;
  PdPhase phase = PdPhase.draw;
  int round = 0;

  /// Wie oft in dieser Runde die Ablage neu gemischt wurde.
  int reshuffles = 0;

  /// Beim Abheben aufgedeckte Pik Dame oder Joker: wer sie bekommen hat.
  PdCard? cutCard;
  int cutter = -1;

  /// Erster Zug der Runde: die offene Karte darf ohne Auslegen genommen werden.
  bool firstTurn = true;

  /// Vom Ablagestapel genommen: diese Karte muss in diesem Zug ausgelegt werden.
  PdCard? mustUse;

  /// Auslagen dieses Zuges (für die 50er-Regel und zum Zurücknehmen).
  final List<PdMeld> _turnMelds = [];
  _Snapshot? _snap;
  PdRoundResult? result;
  String lastEvent = '';

  int get n => players.length;
  PdPlayer get me => players[0];

  void start() {
    dealer = _rng.nextInt(n);
    newRound();
  }

  void newRound() {
    var id = 0;
    final deck = <PdCard>[
      for (var d = 0; d < 2; d++)
        for (final s in Suit.values)
          for (var r = 2; r <= 14; r++) PdCard(r, s, id++),
      for (var j = 0; j < 6; j++) PdCard.joker(id++),
    ]..shuffle(_rng);
    // Abheben: Ist die aufgedeckte Karte eine Pik Dame oder ein Joker, darf der Abhebende sie zusätzlich behalten
    cutter = (dealer + n - 1) % n;
    final cutAt = 10 + _rng.nextInt(deck.length - 20);
    final shown = deck[cutAt];
    cutCard = shown.joker || shown.pikDame ? deck.removeAt(cutAt) : null;
    stack = deck;
    pile = [];
    melds = [];
    reshuffles = 0;
    for (final p in players) {
      p
        ..hand = []
        ..hasMelded = false
        ..roundScore = 0;
    }
    for (var k = 0; k < 15; k++) {
      for (var i = 1; i <= n; i++) {
        players[(dealer + i) % n].hand.add(stack.removeLast());
      }
    }
    if (cutCard != null) players[cutter].hand.add(cutCard!);
    pile.add(stack.removeLast());
    current = (dealer + 1) % n;
    firstTurn = true;
    phase = PdPhase.draw;
    mustUse = null;
    _turnMelds.clear();
    result = null;
    round++;
    lastEvent = cutCard == null ? '' : '${who(cutter)} ${cutter == 0 ? 'hebst' : 'hebt'} ${cutCard!.name} ab und ${cutter == 0 ? 'behältst' : 'behält'} sie';
  }

  int value(PdCard c) => pdValue(c, options);

  /// Karte über ihre Nummer finden (für gespeicherte Spielstände).
  PdCard cardById(int id) {
    for (final pl in players) {
      for (final c in pl.hand) {
        if (c.id == id) return c;
      }
    }
    for (final c in [...pile, ...stack, for (final m in melds) ...m.cards]) {
      if (c.id == id) return c;
    }
    throw StateError('Karte $id fehlt');
  }
  int handPoints(int p) => players[p].hand.fold(0, (a, c) => a + value(c));
  int meldPoints(int p) => melds.where((m) => m.owner == p).fold(0, (a, m) => a + m.points(options));
  List<PdMeld> meldsOf(int p) => melds.where((m) => m.owner == p).toList();

  String who(int p) => p == 0 ? 'Du' : players[p].name;

  // ---------- Ziehen ----------

  void drawStack(int p) => record(['s', p], () => _drawStackImpl(p));

  void _drawStackImpl(int p) {
    if (phase != PdPhase.draw || current != p) return;
    // Ist der Stapel leer, wird die Ablage ohne die oberste Karte gemischt und neuer Stapel.
    // Nach dem dritten Mal endet die Runde, damit sie nicht ewig dauert.
    if (stack.isEmpty) {
      if (pile.length <= 1 || reshuffles >= 3) {
        _endRound(null);
        return;
      }
      final top = pile.removeLast();
      stack = [...pile]..shuffle(_rng);
      pile = [top];
      reshuffles++;
      lastEvent = 'Die Ablage wird gemischt und neuer Stapel';
    }
    players[p].hand.add(stack.removeLast());
    firstTurn = false;
    _beginPlay(p);
  }

  /// Erster Zug: die offene Karte ohne Bedingung nehmen.
  bool canTakeOpen(int p) => phase == PdPhase.draw && current == p && firstTurn && pile.length == 1;

  void takeOpen(int p) => record(['o', p], () => _takeOpenImpl(p));

  void _takeOpenImpl(int p) {
    if (!canTakeOpen(p)) return;
    players[p].hand.add(pile.removeLast());
    firstTurn = false;
    _beginPlay(p);
  }

  /// Ablagestapel nehmen: Die oberste Karte muss mit [with_] sofort eine Auslage bilden.
  bool canTakePile(int p, List<PdCard> with_) {
    if (phase != PdPhase.draw || current != p || pile.isEmpty) return false;
    if (!with_.every(players[p].hand.contains)) return false;
    return pdBuildMeld([...with_, pile.last], p, maxJokers: options.maxJokers) != null;
  }

  void takePile(int p, List<PdCard> with_) => record(['p', p, [for (final c in with_) c.id]], () => _takePileImpl(p, with_));

  void _takePileImpl(int p, List<PdCard> with_) {
    if (!canTakePile(p, with_)) return;
    _snap = _Snapshot.of(this);
    _turnMelds.clear();
    final top = pile.last;
    players[p].hand.addAll(pile);
    pile = [];
    firstTurn = false;
    phase = PdPhase.play;
    mustUse = top;
    lastEvent = '${who(p)} ${p == 0 ? 'nimmst' : 'nimmt'} den Ablagestapel';
    meld(p, [...with_, top]);
  }

  void _beginPlay(int p) {
    phase = PdPhase.play;
    mustUse = null;
    _turnMelds.clear();
    _snap = _Snapshot.of(this);
  }

  // ---------- Auslegen ----------

  /// Bleibt nach dem Auslegen noch eine Karte zum Abwerfen?
  bool _leavesCard(int p, int count) => players[p].hand.length - count >= 1;

  bool canMeld(int p, List<PdCard> cards) =>
      phase == PdPhase.play && current == p && cards.every(players[p].hand.contains) && _leavesCard(p, cards.length) && pdBuildMeld(cards, p, maxJokers: options.maxJokers) != null;

  void meld(int p, List<PdCard> cards) => record(['m', p, [for (final c in cards) c.id]], () => _meldImpl(p, cards));

  void _meldImpl(int p, List<PdCard> cards) {
    if (!canMeld(p, cards)) return;
    final m = pdBuildMeld(cards, p, maxJokers: options.maxJokers)!;
    for (final c in cards) {
      players[p].hand.remove(c);
    }
    melds.add(m);
    _turnMelds.add(m);
    if (mustUse != null && cards.contains(mustUse)) mustUse = null;
  }

  /// An eine eigene Auslage anlegen.
  bool canExtend(int p, int meldIndex, PdCard c) {
    if (phase != PdPhase.play || current != p || !players[p].hand.contains(c) || !_leavesCard(p, 1)) return false;
    final m = melds[meldIndex];
    if (m.owner != p) return false;
    // Erst anlegen, wenn die erste Auslage steht (50er-Regel)
    if (!players[p].hasMelded && !_turnMelds.contains(m)) return false;
    return pdExtend(m, c, maxJokers: options.maxJokers) != null;
  }

  void extend(int p, int meldIndex, PdCard c) => record(['e', p, meldIndex, c.id], () => _extendImpl(p, meldIndex, c));

  void _extendImpl(int p, int meldIndex, PdCard c) {
    if (!canExtend(p, meldIndex, c)) return;
    final old = melds[meldIndex];
    final m = pdExtend(old, c, maxJokers: options.maxJokers)!;
    melds[meldIndex] = m;
    final ti = _turnMelds.indexOf(old);
    if (ti >= 0) _turnMelds[ti] = m;
    players[p].hand.remove(c);
    if (mustUse == c) mustUse = null;
  }

  bool canSwapJoker(int p, int meldIndex, PdCard c) =>
      phase == PdPhase.play &&
      current == p &&
      players[p].hand.contains(c) &&
      melds[meldIndex].owner == p &&
      (players[p].hasMelded || _turnMelds.contains(melds[meldIndex])) &&
      pdCanSwapJoker(melds[meldIndex], c);

  void swapJoker(int p, int meldIndex, PdCard c) => record(['j', p, meldIndex, c.id], () => _swapJokerImpl(p, meldIndex, c));

  void _swapJokerImpl(int p, int meldIndex, PdCard c) {
    if (!canSwapJoker(p, meldIndex, c)) return;
    final m = melds[meldIndex];
    final i = pdSwapIndex(m, c);
    final joker = m.cards[i];
    final cards = [...m.cards]..[i] = c;
    final nm = PdMeld(m.run, cards, m.ranks, m.suit, p);
    melds[meldIndex] = nm;
    final ti = _turnMelds.indexOf(m);
    if (ti >= 0) _turnMelds[ti] = nm;
    players[p].hand
      ..remove(c)
      ..add(joker);
  }

  /// Punkte der in diesem Zug neu ausgelegten Karten.
  int get turnMeldPoints => _turnMelds.fold(0, (a, m) => a + m.points(options));

  /// Warum der Zug noch nicht beendet werden darf, oder null.
  String? discardBlocker(int p) {
    if (mustUse != null) return 'Die Karte vom Ablagestapel muss erst ausgelegt werden';
    if (options.firstMeld50 && !players[p].hasMelded && _turnMelds.isNotEmpty && turnMeldPoints < 50) {
      return 'Die erste Auslage braucht mindestens 50 Punkte (jetzt $turnMeldPoints)';
    }
    return null;
  }

  bool get canUndoTurn => _snap != null && (phase == PdPhase.play) && (_turnMelds.isNotEmpty || mustUse != null || _snap!.fromPile);

  /// Nimmt alle Auslagen dieses Zuges zurück. Nach dem Ablagestapel liegt er wieder da.
  void undoTurn() => record(['u'], () => _undoTurnImpl());

  void _undoTurnImpl() {
    if (!canUndoTurn) return;
    _snap!.restore(this);
    _turnMelds.clear();
    mustUse = null;
    phase = _snap!.fromPile ? PdPhase.draw : PdPhase.play;
    if (!_snap!.fromPile) _snap = _Snapshot.of(this);
  }

  void discard(int p, PdCard c) => record(['d', p, c.id], () => _discardImpl(p, c));

  void _discardImpl(int p, PdCard c) {
    if (phase != PdPhase.play || current != p || !players[p].hand.contains(c) || discardBlocker(p) != null) return;
    final pl = players[p];
    pl.hand.remove(c);
    final handWin = !pl.hasMelded && _turnMelds.isNotEmpty;
    if (_turnMelds.isNotEmpty) pl.hasMelded = true;
    if (pl.hand.isEmpty) {
      // Die letzte Karte wird verdeckt abgelegt
      _endRound(p, hand: handWin);
      return;
    }
    pile.add(c);
    lastEvent = '${who(p)} ${p == 0 ? 'wirfst' : 'wirft'} ${c.name} ab';
    _turnMelds.clear();
    _snap = null;
    current = (current + 1) % n;
    phase = PdPhase.draw;
  }

  // ---------- Abrechnung ----------

  void _endRound(int? winner, {bool hand = false}) {
    final changes = List.filled(n, 0);
    for (var p = 0; p < n; p++) {
      final plus = meldPoints(p);
      final minus = handPoints(p);
      if (winner != null && hand) {
        changes[p] = p == winner ? 2 * plus : plus - 2 * minus;
      } else {
        changes[p] = plus - minus;
      }
      players[p]
        ..score += changes[p]
        ..roundScore = changes[p];
    }
    final text = winner == null
        ? 'Der Stapel ist leer, die Runde endet'
        : '${who(winner)} ${winner == 0 ? 'machst' : 'macht'} aus${hand ? ' – mit Hand!' : ''}';
    result = PdRoundResult(winner ?? -1, hand, changes, text);
    phase = players.any((pl) => pl.score >= options.target) ? PdPhase.gameOver : PdPhase.roundOver;
  }

  void nextRound() => record(['n'], () => _nextRoundImpl());

  void _nextRoundImpl() {
    if (phase != PdPhase.roundOver) return;
    dealer = (dealer + 1) % n;
    newRound();
  }

  List<int> ranking() {
    final order = [for (var i = 0; i < n; i++) i];
    order.sort((a, b) => players[b].score - players[a].score);
    return order;
  }
}

class _Snapshot {
  _Snapshot(this.hand, this.melds, this.pile, this.fromPile, this.player);
  factory _Snapshot.of(PdGame g) =>
      _Snapshot([...g.players[g.current].hand], [...g.melds], [...g.pile], g.phase == PdPhase.draw, g.current);
  final List<PdCard> hand;
  final List<PdMeld> melds;
  final List<PdCard> pile;
  final bool fromPile;
  final int player;

  void restore(PdGame g) {
    g.players[player].hand = [...hand];
    g.melds = [...melds];
    g.pile = [...pile];
  }
}

// ---------- Computer ----------

/// Alle möglichen Auslagen aus einer Hand (Sätze und Folgen, je höchstens ein Joker).
List<List<PdCard>> pdCandidateMelds(List<PdCard> hand) {
  final out = <List<PdCard>>[];
  final jokers = hand.where((c) => c.joker).toList();
  final real = hand.where((c) => !c.joker).toList();
  // Sätze
  final byRank = <int, List<PdCard>>{};
  for (final c in real) {
    byRank.putIfAbsent(c.rank, () => []).add(c);
  }
  for (final cards in byRank.values) {
    if (cards.length >= 3) {
      out.add([...cards]);
      if (cards.length > 3) out.add(cards.take(3).toList());
    }
    if (cards.length >= 2 && jokers.isNotEmpty) out.add([...cards.take(3), jokers.first]);
  }
  // Folgen
  for (final s in Suit.values) {
    final bySuitRank = <int, PdCard>{};
    for (final c in real.where((c) => c.suit == s)) {
      bySuitRank.putIfAbsent(c.rank, () => c);
      if (c.rank == 14) bySuitRank.putIfAbsent(1, () => c);
    }
    for (var start = 1; start <= 12; start++) {
      final run = <PdCard>[];
      var usedJoker = false;
      for (var r = start; r <= 14; r++) {
        final c = bySuitRank[r];
        if (c != null && !run.contains(c)) {
          run.add(c);
        } else if (!usedJoker && jokers.isNotEmpty && run.isNotEmpty) {
          run.add(jokers.first);
          usedJoker = true;
        } else {
          break;
        }
        if (run.length >= 3 && pdBuildMeld(run, 0) != null) out.add([...run]);
      }
    }
  }
  return out;
}

/// Beste Auswahl sich nicht überschneidender Auslagen (nach Punkten), höchstens [keep] Karten bleiben übrig.
List<List<PdCard>> pdBestMelds(List<PdCard> hand, PdOptions o) {
  final cands = pdCandidateMelds(hand)..sort((a, b) => b.length - a.length);
  var best = <List<PdCard>>[];
  var bestPts = 0;
  var nodes = 0;
  void search(int i, List<List<PdCard>> chosen, Set<int> used, int pts) {
    if (++nodes > 20000) return;
    if (pts > bestPts && hand.length - used.length >= 1) {
      bestPts = pts;
      best = [...chosen];
    }
    if (i >= cands.length || chosen.length >= 6) return;
    for (var k = i; k < cands.length; k++) {
      final m = cands[k];
      if (m.any((c) => used.contains(c.id))) continue;
      if (hand.length - used.length - m.length < 1) continue;
      chosen.add(m);
      search(k + 1, chosen, {...used, ...m.map((c) => c.id)}, pts + m.fold(0, (a, c) => a + pdValue(c, o)));
      chosen.removeLast();
    }
  }

  search(0, [], {}, 0);
  return best;
}

/// Wie nützlich eine Karte für spätere Auslagen ist.
int _usefulness(PdCard c, List<PdCard> hand) {
  if (c.joker) return 100;
  var u = 0;
  for (final o in hand) {
    if (o == c || o.joker) continue;
    if (o.rank == c.rank && o.suit != c.suit) u += 3;
    if (o.suit == c.suit && (o.rank - c.rank).abs() == 1) u += 3;
    if (o.suit == c.suit && (o.rank - c.rank).abs() == 2) u += 1;
  }
  return u;
}

/// Ein ganzer Computerzug.
void pdBotTurn(PdGame g, int p, Random rng) {
  final pl = g.players[p];
  final o = g.options;
  // Ablage nehmen, wenn die oberste Karte gut passt
  if (g.pile.isNotEmpty && !g.firstTurn) {
    final top = g.pile.last;
    final cands = pdCandidateMelds([...pl.hand, top]).where((m) => m.contains(top)).toList();
    if (cands.isNotEmpty) {
      cands.sort((a, b) => b.length - a.length);
      final use = cands.first.where((c) => c != top).toList();
      final after = [...pl.hand, ...g.pile];
      final total = pdBestMelds(after, o).fold(0, (a, m) => a + m.fold(0, (x, c) => x + pdValue(c, o)));
      final okFirst = pl.hasMelded || !o.firstMeld50 || total >= 50;
      if (okFirst && (g.pile.length <= 10 || pl.hasMelded)) {
        g.takePile(p, use);
      }
    }
  }
  if (g.phase == PdPhase.draw) {
    if (g.canTakeOpen(p) && _usefulness(g.pile.last, pl.hand) >= 3) {
      g.takeOpen(p);
    } else {
      g.drawStack(p);
    }
  }
  if (g.phase != PdPhase.play) return;
  // Auslegen
  final best = pdBestMelds(pl.hand, o);
  final pts = best.fold(0, (a, m) => a + m.fold(0, (x, c) => x + pdValue(c, o)));
  final firstOk = pl.hasMelded || !o.firstMeld50 || pts + g.turnMeldPoints >= 50;
  if (firstOk) {
    for (final m in best) {
      g.meld(p, m);
    }
  }
  // Anlegen und Joker holen
  if (pl.hasMelded || g.turnMeldPoints >= (o.firstMeld50 ? 50 : 0)) {
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < g.melds.length && !changed; i++) {
        if (g.melds[i].owner != p) continue;
        for (final c in [...pl.hand]) {
          if (g.canSwapJoker(p, i, c)) {
            g.swapJoker(p, i, c);
            changed = true;
            break;
          }
          if (!c.joker && g.canExtend(p, i, c)) {
            g.extend(p, i, c);
            changed = true;
            break;
          }
        }
      }
    }
  }
  if (g.discardBlocker(p) != null) g.undoTurn();
  if (g.phase == PdPhase.draw) {
    // Rücknahme nach Ablagestapel: dann eben vom Stapel ziehen
    g.drawStack(p);
    if (g.phase != PdPhase.play) return;
  }
  // Abwerfen: unnützeste Karte, bei Gleichstand die teuerste
  final hand = pl.hand;
  hand.sort((a, b) {
    final u = _usefulness(a, hand) - _usefulness(b, hand);
    if (u != 0) return u;
    return pdValue(b, o) - pdValue(a, o);
  });
  final pick = hand.firstWhere((c) => !c.joker, orElse: () => hand.first);
  g.discard(p, pick);
}

/// Spielt einen gespeicherten Zug nach.
void pdApply(PdGame g, List<dynamic> a) {
  int i(int k) => a[k] as int;
  PdCard c(int k) => g.cardById(i(k));
  List<PdCard> cs(int k) => [for (final id in a[k] as List) g.cardById(id as int)];
  switch (a[0] as String) {
    case 's':
      g.drawStack(i(1));
    case 'o':
      g.takeOpen(i(1));
    case 'p':
      g.takePile(i(1), cs(2));
    case 'm':
      g.meld(i(1), cs(2));
    case 'e':
      g.extend(i(1), i(2), c(3));
    case 'j':
      g.swapJoker(i(1), i(2), c(3));
    case 'u':
      g.undoTurn();
    case 'd':
      g.discard(i(1), c(2));
    case 'n':
      g.nextRound();
  }
}
