import 'dart:math';

import '../cards/playing_card.dart';

enum HeartsPhase { passing, playing, handOver, gameOver }

class HeartsSeat {
  HeartsSeat(this.name, {this.human = false});
  final String name;
  final bool human;
  List<PlayingCard> hand = [];
  List<PlayingCard> taken = [];
  int score = 0;
  int handPoints = 0;
}

class TrickCard {
  const TrickCard(this.seat, this.card);
  final int seat;
  final PlayingCard card;
}

bool isQueenOfSpades(PlayingCard c) => c.suit == Suit.spades && c.rank == 12;

int cardPoints(PlayingCard c) =>
    c.suit == Suit.hearts ? 1 : (isQueenOfSpades(c) ? 13 : 0);

int pointsOf(Iterable<PlayingCard> cards) =>
    cards.fold<int>(0, (s, c) => s + cardPoints(c));

/// Schwarze Dame für vier Spieler. Gespielt wird im Uhrzeigersinn:
/// 0 unten, 1 links, 2 oben, 3 rechts. Ende ab 100 Punkten.
class HeartsEngine {
  HeartsEngine({required this.seats, Random? rng, this.target = 100})
      : _rng = rng ?? Random.secure();

  final List<HeartsSeat> seats;
  final int target;
  final Random _rng;

  HeartsPhase phase = HeartsPhase.handOver;
  int handNumber = 0;
  int current = 0;
  int tricksPlayed = 0;
  bool heartsBroken = false;
  List<TrickCard> trick = [];
  List<TrickCard> lastTrick = [];
  int? lastTrickWinner;
  int? moonShooter;
  final Set<PlayingCard> played = {};
  final Map<int, List<PlayingCard>> _passes = {};
  List<PlayingCard> received = [];

  /// Weitergabe: 1 nach links, 3 nach rechts, 2 gegenüber, 0 keine.
  int get passOffset => const [1, 3, 2, 0][handNumber % 4];

  String get passLabel => switch (passOffset) {
        1 => 'nach links',
        3 => 'nach rechts',
        2 => 'nach gegenüber',
        _ => '',
      };

  bool get queenPlayed => played.any(isQueenOfSpades);

  void startHand({List<PlayingCard>? deck}) {
    final cards = deck?.toList() ?? shuffledDeck(_rng);
    for (final s in seats) {
      s.hand = [];
      s.taken = [];
      s.handPoints = 0;
    }
    for (var i = 0; i < 52; i++) {
      seats[i % 4].hand.add(cards[i]);
    }
    trick = [];
    lastTrick = [];
    lastTrickWinner = null;
    moonShooter = null;
    tricksPlayed = 0;
    heartsBroken = false;
    played.clear();
    _passes.clear();
    received = [];
    if (passOffset == 0) {
      _beginPlay();
    } else {
      phase = HeartsPhase.passing;
    }
  }

  void newGame() {
    for (final s in seats) {
      s.score = 0;
    }
    handNumber = 0;
    startHand();
  }

  bool hasPassed(int seat) => _passes.containsKey(seat);

  void choosePass(int seat, List<PlayingCard> cards) {
    if (phase != HeartsPhase.passing || cards.length != 3) {
      throw StateError('Weitergabe nicht möglich');
    }
    if (!cards.every(seats[seat].hand.contains)) {
      throw StateError('Karte nicht auf der Hand');
    }
    _passes[seat] = cards.toList();
    if (_passes.length == 4) _applyPasses();
  }

  void _applyPasses() {
    for (final e in _passes.entries) {
      for (final c in e.value) {
        seats[e.key].hand.remove(c);
      }
    }
    for (final e in _passes.entries) {
      final to = (e.key + passOffset) % 4;
      seats[to].hand.addAll(e.value);
      if (seats[to].human) received = e.value.toList();
    }
    _passes.clear();
    _beginPlay();
  }

  void _beginPlay() {
    phase = HeartsPhase.playing;
    current = seats.indexWhere(
      (s) => s.hand.any((c) => c.suit == Suit.clubs && c.rank == 2),
    );
  }

  List<PlayingCard> legalCards(int seat) {
    final hand = seats[seat].hand;
    if (phase != HeartsPhase.playing || seat != current) return [];
    if (trick.isEmpty) {
      if (tricksPlayed == 0) {
        return hand.where((c) => c.suit == Suit.clubs && c.rank == 2).toList();
      }
      if (!heartsBroken) {
        final other = hand.where((c) => c.suit != Suit.hearts).toList();
        if (other.isNotEmpty) return other;
      }
      return hand.toList();
    }
    final lead = trick.first.card.suit;
    final follow = hand.where((c) => c.suit == lead).toList();
    if (follow.isNotEmpty) return follow;
    if (tricksPlayed == 0) {
      final clean = hand.where((c) => cardPoints(c) == 0).toList();
      if (clean.isNotEmpty) return clean;
    }
    return hand.toList();
  }

  /// Spielt eine Karte. Liefert true, wenn damit ein Stich fertig ist.
  bool play(PlayingCard c) {
    final s = current;
    if (!legalCards(s).contains(c)) throw StateError('Karte nicht erlaubt');
    seats[s].hand.remove(c);
    trick.add(TrickCard(s, c));
    played.add(c);
    if (c.suit == Suit.hearts) heartsBroken = true;
    if (trick.length < 4) {
      current = (s + 1) % 4;
      return false;
    }
    final lead = trick.first.card.suit;
    var win = trick.first;
    for (final t in trick) {
      if (t.card.suit == lead && t.card.rank > win.card.rank) win = t;
    }
    seats[win.seat].taken.addAll(trick.map((t) => t.card));
    lastTrick = trick;
    lastTrickWinner = win.seat;
    trick = [];
    tricksPlayed++;
    current = win.seat;
    if (tricksPlayed == 13) _endHand();
    return true;
  }

  void _endHand() {
    final pts = [for (final s in seats) pointsOf(s.taken)];
    final shooter = pts.indexWhere((p) => p == 26);
    if (shooter >= 0) {
      moonShooter = shooter;
      for (var i = 0; i < 4; i++) {
        pts[i] = i == shooter ? 0 : 26;
      }
    }
    for (var i = 0; i < 4; i++) {
      seats[i].handPoints = pts[i];
      seats[i].score += pts[i];
    }
    handNumber++;
    phase = seats.any((s) => s.score >= target)
        ? HeartsPhase.gameOver
        : HeartsPhase.handOver;
  }

  /// Spieler mit dem niedrigsten Stand.
  List<int> get leaders {
    final low = seats.map((s) => s.score).reduce(min);
    return [for (var i = 0; i < 4; i++) if (seats[i].score == low) i];
  }
}

/// Weitergabe eines Computer-Gegners: gefährliche Karten zuerst.
List<PlayingCard> heartsBotPass(List<PlayingCard> hand) {
  final spades = hand.where((c) => c.suit == Suit.spades).length;
  double danger(PlayingCard c) {
    if (isQueenOfSpades(c)) return 100;
    if (c.suit == Suit.spades && c.rank > 12) {
      return spades >= 5 ? 1 : 90 + c.rank.toDouble();
    }
    if (c.suit == Suit.hearts) return 20 + c.rank.toDouble();
    return c.rank.toDouble();
  }

  final sorted = hand.toList()..sort((a, b) => danger(b).compareTo(danger(a)));
  return sorted.take(3).toList();
}

/// Zug eines Computer-Gegners: Stiche mit Punkten meiden, gefährliche Karten abwerfen.
PlayingCard heartsBotPlay(HeartsEngine e) {
  final legal = e.legalCards(e.current);
  if (legal.length == 1) return legal.first;
  PlayingCard lowest(Iterable<PlayingCard> cs) =>
      cs.reduce((a, b) => b.rank < a.rank ? b : a);
  PlayingCard highest(Iterable<PlayingCard> cs) =>
      cs.reduce((a, b) => b.rank > a.rank ? b : a);
  List<PlayingCard> withoutQueen(List<PlayingCard> cs) {
    final rest = cs.where((c) => !isQueenOfSpades(c)).toList();
    return rest.isEmpty ? cs : rest;
  }

  if (e.trick.isEmpty) {
    double key(PlayingCard c) {
      var k = c.rank.toDouble();
      if (c.suit == Suit.hearts) k += 10;
      if (c.suit == Suit.spades && c.rank >= 12 && !e.queenPlayed) k += 30;
      return k;
    }

    return legal.reduce((a, b) => key(b) < key(a) ? b : a);
  }

  final lead = e.trick.first.card.suit;
  final following = legal.first.suit == lead;
  if (following) {
    final winning = e.trick
        .where((t) => t.card.suit == lead)
        .map((t) => t.card.rank)
        .reduce(max);
    final below = legal.where((c) => c.rank < winning).toList();
    if (below.isNotEmpty) return highest(below);
    final safe = withoutQueen(legal);
    return e.trick.length == 3 ? highest(safe) : lowest(safe);
  }
  final queen = legal.where(isQueenOfSpades);
  if (queen.isNotEmpty) return queen.first;
  if (!e.queenPlayed) {
    final bigSpades = legal.where((c) => c.suit == Suit.spades && c.rank > 12);
    if (bigSpades.isNotEmpty) return highest(bigSpades);
  }
  final hearts = legal.where((c) => c.suit == Suit.hearts);
  if (hearts.isNotEmpty) return highest(hearts);
  return highest(legal);
}
