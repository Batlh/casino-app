import 'dart:math';

import '../cards/hand_eval.dart';
import '../cards/playing_card.dart';

enum HoldemStreet { preflop, flop, turn, river, finished }

enum HoldemActionKind { fold, check, call, raise }

class HoldemAction {
  const HoldemAction(this.kind, [this.raiseTo = 0]);
  final HoldemActionKind kind;

  /// Gesamteinsatz dieser Setzrunde nach der Erhöhung.
  final int raiseTo;

  static const fold = HoldemAction(HoldemActionKind.fold);
  static const check = HoldemAction(HoldemActionKind.check);
  static const call = HoldemAction(HoldemActionKind.call);
}

class HoldemPlayer {
  HoldemPlayer(this.name, this.stack, {this.style, this.isHuman = false});

  String name;
  int stack;
  final bool isHuman;

  /// Spielstil der Computer-Gegner.
  BotStyle? style;

  List<PlayingCard> hole = [];
  int streetBet = 0;
  int totalBet = 0;
  bool folded = false;
  bool allIn = false;
  bool inHand = false;
  String lastAction = '';
  HandValue? shownValue;

  bool get live => inHand && !folded;
  bool get canAct => live && !allIn;
}

class PotResult {
  const PotResult(this.amount, this.winners, this.value);
  final int amount;
  final List<HoldemPlayer> winners;

  /// null, wenn alle anderen ausgestiegen sind.
  final HandValue? value;
}

/// No-Limit Texas Hold'em. Die Klasse kennt nur die Regeln.
class HoldemEngine {
  HoldemEngine({
    required this.players,
    required this.smallBlind,
    required this.bigBlind,
    Random? rng,
    this.stackedDeck,
  }) : _rng = rng ?? Random.secure();

  final List<HoldemPlayer> players;
  final int smallBlind;
  final int bigBlind;
  final Random _rng;

  /// Nur für Tests. Karten werden von hinten gezogen.
  final List<PlayingCard>? stackedDeck;

  List<PlayingCard> _deck = [];
  List<PlayingCard> board = [];
  HoldemStreet street = HoldemStreet.finished;
  int dealer = -1;
  int toAct = -1;
  int currentBet = 0;
  int minRaise = 0;
  Set<int> _pending = {};
  List<PotResult> results = [];

  bool get handOver => street == HoldemStreet.finished;
  HoldemPlayer get actor => players[toAct];
  int get pot => players.fold(0, (s, p) => s + p.totalBet);
  int get toCall => max(0, currentBet - actor.streetBet);

  int _next(int from, bool Function(HoldemPlayer) test) {
    for (var i = 1; i <= players.length; i++) {
      final j = (from + i) % players.length;
      if (test(players[j])) return j;
    }
    return -1;
  }

  PlayingCard _draw() => _deck.removeLast();

  void _putIn(HoldemPlayer p, int amount) {
    final a = min(amount, p.stack);
    p.stack -= a;
    p.streetBet += a;
    p.totalBet += a;
    if (p.stack == 0) p.allIn = true;
  }

  /// Startet eine neue Hand. Es müssen mindestens zwei Spieler Chips haben.
  void startHand() {
    final seated = players.where((p) => p.stack > 0).length;
    if (seated < 2) throw StateError('Zu wenige Spieler');
    _deck = stackedDeck?.toList() ?? shuffledDeck(_rng);
    board = [];
    results = [];
    for (final p in players) {
      p.hole = [];
      p.streetBet = 0;
      p.totalBet = 0;
      p.folded = false;
      p.allIn = false;
      p.inHand = p.stack > 0;
      p.lastAction = '';
      p.shownValue = null;
    }
    dealer = _next(dealer < 0 ? players.length - 1 : dealer, (p) => p.inHand);
    final first = _next(dealer, (p) => p.inHand);
    for (var round = 0; round < 2; round++) {
      var i = first;
      for (var n = 0; n < seated; n++) {
        players[i].hole.add(_draw());
        i = _next(i, (p) => p.inHand);
      }
    }
    final sb = seated == 2 ? dealer : first;
    final bb = _next(sb, (p) => p.inHand);
    _putIn(players[sb], smallBlind);
    _putIn(players[bb], bigBlind);
    currentBet = bigBlind;
    minRaise = bigBlind;
    street = HoldemStreet.preflop;
    _pending = {
      for (var i = 0; i < players.length; i++)
        if (players[i].canAct) i,
    };
    toAct = bb;
    _moveOn();
  }

  int get minRaiseTo => min(
        currentBet + minRaise,
        actor.streetBet + actor.stack,
      );
  int get maxRaiseTo => actor.streetBet + actor.stack;
  bool get canRaise => actor.stack > toCall;

  void apply(HoldemAction action) {
    final p = actor;
    switch (action.kind) {
      case HoldemActionKind.fold:
        p.folded = true;
        p.lastAction = 'Passt';
      case HoldemActionKind.check:
        if (toCall > 0) throw StateError('Schieben geht nicht');
        p.lastAction = 'Schiebt';
      case HoldemActionKind.call:
        final amount = toCall;
        _putIn(p, amount);
        p.lastAction = p.allIn ? 'All-in' : 'Geht mit';
      case HoldemActionKind.raise:
        final to = action.raiseTo.clamp(minRaiseTo, maxRaiseTo);
        final increase = to - currentBet;
        _putIn(p, to - p.streetBet);
        if (increase >= minRaise) minRaise = increase;
        if (increase > 0) {
          currentBet = to;
          _pending = {
            for (var i = 0; i < players.length; i++)
              if (i != toAct && players[i].canAct) i,
          };
        }
        p.lastAction = p.allIn ? 'All-in' : 'Erhöht auf $to';
    }
    _pending.remove(toAct);
    _moveOn();
  }

  void _moveOn() {
    final live = players.where((p) => p.live).toList();
    if (live.length == 1) {
      _finish();
      return;
    }
    _pending.removeWhere((i) => !players[i].canAct);
    if (_pending.isEmpty) {
      _endStreet();
      return;
    }
    toAct = _next(toAct, (p) => _pending.contains(players.indexOf(p)));
  }

  void _endStreet() {
    for (final p in players) {
      p.streetBet = 0;
    }
    currentBet = 0;
    minRaise = bigBlind;
    final able = players.where((p) => p.canAct).length;
    if (street == HoldemStreet.river) {
      _finish();
      return;
    }
    if (able <= 1) {
      while (board.length < 5) {
        board.add(_draw());
      }
      _finish();
      return;
    }
    if (street == HoldemStreet.preflop) {
      board.addAll([_draw(), _draw(), _draw()]);
      street = HoldemStreet.flop;
    } else {
      board.add(_draw());
      street = street == HoldemStreet.flop
          ? HoldemStreet.turn
          : HoldemStreet.river;
    }
    for (final p in players) {
      p.lastAction = p.folded || p.allIn ? p.lastAction : '';
    }
    _pending = {
      for (var i = 0; i < players.length; i++)
        if (players[i].canAct) i,
    };
    toAct = dealer;
    toAct = _next(toAct, (p) => _pending.contains(players.indexOf(p)));
  }

  void _finish() {
    street = HoldemStreet.finished;
    final live = players.where((p) => p.live).toList();
    final showdown = live.length > 1;
    if (showdown) {
      for (final p in live) {
        p.shownValue = bestHand([...p.hole, ...board]);
      }
    }
    final levels = players.map((p) => p.totalBet).where((b) => b > 0).toSet().toList()
      ..sort();
    var previous = 0;
    var carry = 0;
    final out = <PotResult>[];
    for (final level in levels) {
      var amount = carry;
      for (final p in players) {
        amount += min(p.totalBet, level) - min(p.totalBet, previous);
      }
      previous = level;
      final eligible = live.where((p) => p.totalBet >= level).toList();
      if (eligible.isEmpty) {
        carry = amount;
        continue;
      }
      carry = 0;
      var winners = eligible;
      HandValue? best;
      if (showdown) {
        best = eligible.map((p) => p.shownValue!).reduce(
              (a, b) => a.compareTo(b) >= 0 ? a : b,
            );
        winners = eligible
            .where((p) => p.shownValue!.compareTo(best!) == 0)
            .toList();
      }
      _pay(amount, winners);
      if (out.isNotEmpty &&
          out.last.winners.length == winners.length &&
          out.last.winners.every(winners.contains)) {
        out[out.length - 1] =
            PotResult(out.last.amount + amount, winners, best);
      } else {
        out.add(PotResult(amount, winners, best));
      }
    }
    if (carry > 0 && out.isNotEmpty) {
      _pay(carry, out.last.winners);
    }
    results = out;
  }

  void _pay(int amount, List<HoldemPlayer> winners) {
    final share = amount ~/ winners.length;
    var rest = amount - share * winners.length;
    // Der ungerade Rest geht an den ersten Gewinner links vom Dealer
    for (var i = 1; i <= players.length; i++) {
      final p = players[(dealer + i) % players.length];
      if (!winners.contains(p)) continue;
      p.stack += share;
      if (rest > 0) {
        p.stack += 1;
        rest--;
      }
    }
  }

  /// Einsätze, die niemand mitgegangen ist, zählen beim Gewinner mit.
  HoldemPlayer? get human {
    for (final p in players) {
      if (p.isHuman) return p;
    }
    return null;
  }
}

String handName(HandValue v) => switch (v.category) {
      HandCategory.royalFlush => 'Royal Flush',
      HandCategory.straightFlush => 'Straight Flush',
      HandCategory.quads => 'Vierling',
      HandCategory.fullHouse => 'Full House',
      HandCategory.flush => 'Flush',
      HandCategory.straight => 'Straße',
      HandCategory.trips => 'Drilling',
      HandCategory.twoPair => 'Zwei Paare',
      HandCategory.pair => 'Ein Paar',
      HandCategory.highCard => 'Höchste Karte',
    };

/// Spielstil eines Computer-Gegners.
class BotStyle {
  const BotStyle(this.label, this.margin, this.aggression, this.bluff);

  final String label;

  /// Zusätzliche Gewinnchance, die zum Mitgehen nötig ist.
  final double margin;

  /// Wahrscheinlichkeit, mit einer starken Hand zu erhöhen statt mitzugehen.
  final double aggression;

  /// Wahrscheinlichkeit für einen Bluff.
  final double bluff;

  static const fels = BotStyle('Vorsichtig', 0.10, 0.45, 0.02);
  static const hai = BotStyle('Abgebrüht', 0.03, 0.70, 0.08);
  static const zocker = BotStyle('Riskant', -0.03, 0.85, 0.16);
  static const dauergast = BotStyle('Geht oft mit', -0.08, 0.20, 0.03);

  static const all = [fels, hai, zocker, dauergast];
}

/// Schätzt die Gewinnchance per Zufallssimulation.
double estimateEquity(
  List<PlayingCard> hole,
  List<PlayingCard> board,
  int opponents,
  Random rng, {
  int iterations = 120,
}) {
  final known = {...hole, ...board};
  final rest = freshDeck().where((c) => !known.contains(c)).toList();
  final needBoard = 5 - board.length;
  final need = needBoard + opponents * 2;
  var score = 0.0;
  for (var it = 0; it < iterations; it++) {
    for (var i = 0; i < need; i++) {
      final j = i + rng.nextInt(rest.length - i);
      final t = rest[i];
      rest[i] = rest[j];
      rest[j] = t;
    }
    final full = [...board, ...rest.sublist(0, needBoard)];
    final mine = bestHand([...hole, ...full]);
    var best = true;
    var ties = 0;
    for (var o = 0; o < opponents; o++) {
      final a = needBoard + o * 2;
      final theirs = bestHand([rest[a], rest[a + 1], ...full]);
      final c = mine.compareTo(theirs);
      if (c < 0) {
        best = false;
        break;
      }
      if (c == 0) ties++;
    }
    if (best) score += 1 / (ties + 1);
  }
  return score / iterations;
}

/// Entscheidung eines Computer-Gegners für den Spieler, der am Zug ist.
HoldemAction botDecide(HoldemEngine e, Random rng) {
  final p = e.actor;
  final style = p.style ?? BotStyle.hai;
  final opponents = max(1, e.players.where((x) => x.live).length - 1);
  final equity = estimateEquity(p.hole, e.board, min(opponents, 4), rng) +
      (rng.nextDouble() - 0.5) * 0.08;
  final toCall = e.toCall;
  final pot = e.pot;
  final odds = toCall == 0 ? 0.0 : toCall / (pot + toCall);
  // Gegen mehrere Gegner reicht schon ein kleiner Vorteil
  final fair = 1 / (opponents + 1);

  int sizing(double fraction) {
    final target = e.currentBet + (pot * fraction).round();
    final rounded = (target / e.smallBlind).round() * e.smallBlind;
    return rounded.clamp(e.minRaiseTo, e.maxRaiseTo);
  }

  final strong = equity > fair + 0.28;
  final good = equity > fair + 0.12;

  if (e.canRaise && strong && rng.nextDouble() < style.aggression) {
    return HoldemAction(
      HoldemActionKind.raise,
      sizing(0.5 + rng.nextDouble() * 0.5),
    );
  }
  if (toCall == 0) {
    if (e.canRaise && good && rng.nextDouble() < style.aggression * 0.6) {
      return HoldemAction(HoldemActionKind.raise, sizing(0.5));
    }
    if (e.canRaise && rng.nextDouble() < style.bluff) {
      return HoldemAction(HoldemActionKind.raise, sizing(0.6));
    }
    return HoldemAction.check;
  }
  if (equity >= odds + style.margin) return HoldemAction.call;
  if (e.canRaise && rng.nextDouble() < style.bluff * 0.5) {
    return HoldemAction(HoldemActionKind.raise, sizing(0.7));
  }
  return HoldemAction.fold;
}
