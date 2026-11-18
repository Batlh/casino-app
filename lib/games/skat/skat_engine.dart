import '../../core/action_log.dart';
import '../../core/saves.dart';
import 'dart:math';

import '../cards/playing_card.dart';

/// Skat zu dritt nach den üblichen Regeln: Reizen, Skat aufnehmen oder Hand, Farbspiel, Grand oder Null.
/// Ouvert gibt es hier nicht. Gewertet wird einfach: gewonnen +Spielwert, verloren −2 × Spielwert.

enum SkatType { diamonds, hearts, spades, clubs, grand, nullGame }

const skatTypeNames = {
  SkatType.diamonds: 'Karo',
  SkatType.hearts: 'Herz',
  SkatType.spades: 'Pik',
  SkatType.clubs: 'Kreuz',
  SkatType.grand: 'Grand',
  SkatType.nullGame: 'Null',
};

const _baseValue = {
  SkatType.diamonds: 9,
  SkatType.hearts: 10,
  SkatType.spades: 11,
  SkatType.clubs: 12,
  SkatType.grand: 24,
};

Suit? trumpSuitOf(SkatType t) => switch (t) {
      SkatType.diamonds => Suit.diamonds,
      SkatType.hearts => Suit.hearts,
      SkatType.spades => Suit.spades,
      SkatType.clubs => Suit.clubs,
      _ => null,
    };

/// Rang der Buben: Kreuz, Pik, Herz, Karo.
int jackRank(Suit s) => const {Suit.clubs: 4, Suit.spades: 3, Suit.hearts: 2, Suit.diamonds: 1}[s]!;

int cardPoints(PlayingCard c) => switch (c.rank) { 14 => 11, 10 => 10, 13 => 4, 12 => 3, 11 => 2, _ => 0 };

bool isTrump(PlayingCard c, SkatType t) {
  if (t == SkatType.nullGame) return false;
  if (c.rank == 11) return true;
  return c.suit == trumpSuitOf(t);
}

/// Farbe für das Bedienen: Trumpf zählt als eigene Farbe (null).
Suit? followSuit(PlayingCard c, SkatType t) => isTrump(c, t) ? null : c.suit;

/// Stärke innerhalb der eigenen Farbe.
int power(PlayingCard c, SkatType t) {
  if (t == SkatType.nullGame) {
    return const {14: 8, 13: 7, 12: 6, 11: 5, 10: 4, 9: 3, 8: 2, 7: 1}[c.rank]!;
  }
  if (c.rank == 11) return 100 + jackRank(c.suit);
  return const {14: 7, 10: 6, 13: 5, 12: 4, 9: 3, 8: 2, 7: 1}[c.rank]!;
}

/// Gewinner eines Stichs (Index in der Stichliste).
int trickWinner(List<PlayingCard> trick, SkatType t) {
  var best = 0;
  for (var i = 1; i < trick.length; i++) {
    final a = trick[best];
    final b = trick[i];
    final ta = isTrump(a, t);
    final tb = isTrump(b, t);
    if (tb && !ta) {
      best = i;
    } else if (tb == ta && followSuit(a, t) == followSuit(b, t) && power(b, t) > power(a, t)) {
      best = i;
    }
  }
  return best;
}

/// Alle Reizwerte bis 264.
final List<int> bidValues = () {
  final s = <int>{23, 35, 46, 59};
  for (final b in _baseValue.values) {
    for (var m = 2; m <= 11; m++) {
      if (b * m <= 264) s.add(b * m);
    }
  }
  return (s.where((v) => v >= 18).toList()..sort());
}();

int nextBid(int v) => bidValues.firstWhere((x) => x > v, orElse: () => v);

/// Spitzen: „mit“ oder „ohne“ wie viele, aus allen zwölf Karten des Spielers.
int spitzen(List<PlayingCard> cards, SkatType t) {
  final order = <PlayingCard>[
    for (final s in const [Suit.clubs, Suit.spades, Suit.hearts, Suit.diamonds]) PlayingCard(11, s),
    if (trumpSuitOf(t) != null)
      for (final r in const [14, 10, 13, 12, 9, 8, 7]) PlayingCard(r, trumpSuitOf(t)!),
  ];
  final has = cards.contains(order.first);
  var n = 0;
  for (final c in order) {
    if (cards.contains(c) == has) {
      n++;
    } else {
      break;
    }
  }
  return n;
}

int nullValue({required bool hand}) => hand ? 35 : 23;

class SkatPlayer {
  SkatPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<PlayingCard> hand = [];
  List<PlayingCard> won = [];
  int score = 0;
  int tricks = 0;
}

enum SkatPhase { bidding, skatChoice, discard, declare, playing, dealOver, matchOver }

class SkatResult {
  SkatResult({
    required this.text,
    required this.declarer,
    required this.won,
    required this.value,
    required this.points,
    this.lines = const [],
  });
  final String text;
  final int declarer;
  final bool won;
  final int value;
  final int points;
  final List<String> lines;
}

class SkatGame with ActionLog {
  SkatGame({Random? rng, this.deals = 12, List<String> names = const ['Du', 'Horst', 'Inge']})
      : _rng = rng ?? Random.secure(),
        players = [for (var i = 0; i < 3; i++) SkatPlayer(names[i], human: i == 0)];

  final Random _rng;
  final List<SkatPlayer> players;
  final int deals;
  int dealsPlayed = 0;
  int dealer = 2;
  SkatPhase phase = SkatPhase.bidding;
  List<PlayingCard> skat = [];
  List<PlayingCard> originalSkat = [];

  // Reizen
  int bid = 0;
  int sayer = 0;
  int listener = 0;
  int _stage = 1;
  final Set<int> passed = {};
  int declarer = -1;

  // Spiel
  SkatType type = SkatType.grand;
  bool hand = false;
  bool schneiderAnnounced = false;
  bool schwarzAnnounced = false;
  int current = 0;
  List<PlayingCard> trick = [];
  int trickStarter = 0;
  List<PlayingCard> lastTrick = [];
  int lastTrickWinner = -1;
  SkatResult? result;
  String lastEvent = '';

  int get forehand => (dealer + 1) % 3;
  int get middlehand => (dealer + 2) % 3;
  int get rearhand => dealer;

  void start() => newDeal();

  void newDeal() {
    final deck = [
      for (final s in Suit.values)
        for (final r in const [7, 8, 9, 10, 11, 12, 13, 14]) PlayingCard(r, s),
    ]..shuffle(_rng);
    for (var i = 0; i < 3; i++) {
      players[i]
        ..hand = sortSkat(deck.sublist(i * 10, i * 10 + 10), null)
        ..won = []
        ..tricks = 0;
    }
    skat = deck.sublist(30);
    originalSkat = [...skat];
    bid = 0;
    passed.clear();
    declarer = -1;
    hand = false;
    schneiderAnnounced = false;
    schwarzAnnounced = false;
    trick = [];
    lastTrick = [];
    lastTrickWinner = -1;
    result = null;
    lastEvent = '';
    _stage = 1;
    sayer = middlehand;
    listener = forehand;
    phase = SkatPhase.bidding;
  }

  // ---------- Reizen ----------

  /// Wer muss gerade entscheiden?
  int get bidTurn => _waitingListener ? listener : sayer;
  bool _waitingListener = false;

  /// Wartet das Reizen auf ein Ja oder Passe des Hörers?
  bool get listening => _waitingListener;

  /// Der Reizwert, um den es gerade geht.
  int get askedValue => _waitingListener ? bid : nextBid(bid == 0 ? 17 : bid);

  /// Sagen (als Sager) oder halten (als Hörer).
  void bidYes(int p) => record(['y', p], () => _bidYesImpl(p));

  void _bidYesImpl(int p) {
    if (phase != SkatPhase.bidding || p != bidTurn) return;
    if (_waitingListener) {
      lastEvent = '${_who(p)}: Ja';
      _waitingListener = false;
    } else {
      bid = askedValue;
      lastEvent = '${_who(p)}: $bid';
      if (_stage == 3) {
        // Vorhand allein: 18 sagen heißt spielen
        _finishBidding(p);
        return;
      }
      _waitingListener = true;
    }
  }

  void bidPass(int p) => record(['b', p], () => _bidPassImpl(p));

  void _bidPassImpl(int p) {
    if (phase != SkatPhase.bidding || p != bidTurn) return;
    passed.add(p);
    lastEvent = '${_who(p)}: Passe';
    _waitingListener = false;
    if (_stage == 3) {
      _allPassed();
      return;
    }
    final winner = p == sayer ? listener : sayer;
    if (_stage == 1) {
      _stage = 2;
      sayer = rearhand;
      listener = winner;
      return;
    }
    if (bid == 0) {
      // Niemand hat gereizt: Vorhand darf noch 18 sagen
      _stage = 3;
      sayer = winner;
      return;
    }
    _finishBidding(winner);
  }

  void _allPassed() {
    result = SkatResult(text: 'Eingepasst: Niemand reizt, neu geben', declarer: -1, won: false, value: 0, points: 0);
    dealsPlayed++;
    phase = dealsPlayed >= deals ? SkatPhase.matchOver : SkatPhase.dealOver;
    dealer = (dealer + 1) % 3;
  }

  void _finishBidding(int p) {
    declarer = p;
    if (bid == 0) bid = 18;
    _declarerCards = [...players[p].hand, ...originalSkat];
    phase = SkatPhase.skatChoice;
    lastEvent = '${_who(p)} ${p == 0 ? 'spielst' : 'spielt'} für $bid';
  }

  // ---------- Skat, Drücken, Ansagen ----------

  void takeSkat() => record(['s'], () => _takeSkatImpl());

  void _takeSkatImpl() {
    if (phase != SkatPhase.skatChoice) return;
    players[declarer].hand = sortSkat([...players[declarer].hand, ...skat], null);
    skat = [];
    hand = false;
    phase = SkatPhase.discard;
  }

  void playHand() => record(['h'], () => _playHandImpl());

  void _playHandImpl() {
    if (phase != SkatPhase.skatChoice) return;
    hand = true;
    phase = SkatPhase.declare;
  }

  void discard(List<PlayingCard> two) => record(['d', for (final c in two) cardCode(c)], () => _discardImpl(two));

  void _discardImpl(List<PlayingCard> two) {
    if (phase != SkatPhase.discard || two.length != 2 || two[0] == two[1]) return;
    final h = players[declarer].hand;
    if (!two.every(h.contains)) return;
    for (final c in two) {
      h.remove(c);
    }
    skat = [...two];
    phase = SkatPhase.declare;
  }

  /// Ansagen nur bei Handspielen, Schwarz setzt Schneider voraus.
  void declare(SkatType t, {bool schneider = false, bool schwarz = false}) => record(['a', t.index, schneider, schwarz], () => _declareImpl(t, schneider: schneider, schwarz: schwarz));

  void _declareImpl(SkatType t, {bool schneider = false, bool schwarz = false}) {
    if (phase != SkatPhase.declare) return;
    type = t;
    schneiderAnnounced = hand && t != SkatType.nullGame && (schneider || schwarz);
    schwarzAnnounced = hand && t != SkatType.nullGame && schwarz;
    for (final p in players) {
      p.hand = sortSkat(p.hand, t);
    }
    phase = SkatPhase.playing;
    current = forehand;
    trickStarter = forehand;
    trick = [];
    final extras = [if (hand) 'Hand', if (schwarzAnnounced) 'Schwarz angesagt' else if (schneiderAnnounced) 'Schneider angesagt'];
    lastEvent = '${_who(declarer)} ${declarer == 0 ? 'spielst' : 'spielt'} ${skatTypeNames[t]}${extras.isEmpty ? '' : ' (${extras.join(', ')})'}';
  }

  /// Höchster Wert, den das Spiel ohne Schneider erreichen kann (für die Überreiz-Prüfung vor dem Spiel).
  int baseGameValue(SkatType t, List<PlayingCard> all, {bool hand = false}) {
    if (t == SkatType.nullGame) return nullValue(hand: hand);
    return _baseValue[t]! * (spitzen(all, t) + 1 + (hand ? 1 : 0));
  }

  // ---------- Stiche ----------

  List<PlayingCard> legalCards(int p) {
    final h = players[p].hand;
    if (trick.isEmpty) return [...h];
    final lead = trick.first;
    final leadTrump = isTrump(lead, type);
    final follow = h.where((c) => leadTrump ? isTrump(c, type) : (!isTrump(c, type) && c.suit == lead.suit)).toList();
    return follow.isEmpty ? [...h] : follow;
  }

  void play(int p, PlayingCard c) => record(['p', p, cardCode(c)], () => _playImpl(p, c));

  void _playImpl(int p, PlayingCard c) {
    if (phase != SkatPhase.playing || p != current || !legalCards(p).contains(c)) return;
    players[p].hand.remove(c);
    if (trick.isEmpty) trickStarter = p;
    trick.add(c);
    if (trick.length < 3) {
      current = (current + 1) % 3;
      return;
    }
    final w = (trickStarter + trickWinner(trick, type)) % 3;
    players[w].won.addAll(trick);
    players[w].tricks++;
    lastTrick = [...trick];
    lastTrickWinner = w;
    trick = [];
    current = w;
    // Null: Der Alleinspieler verliert mit dem ersten Stich
    if (type == SkatType.nullGame && w == declarer) {
      _settle();
      return;
    }
    if (players.every((pl) => pl.hand.isEmpty)) _settle();
  }

  /// Wer gehört zu wem: Gegenspieler gegen den Alleinspieler.
  bool sameTeam(int a, int b) => a == b || (a != declarer && b != declarer);

  int declarerPoints() => players[declarer].won.fold(0, (a, c) => a + cardPoints(c)) + skat.fold(0, (a, c) => a + cardPoints(c));

  void _settle() {
    final dp = declarerPoints();
    final lines = <String>[];
    bool won;
    int value;
    if (type == SkatType.nullGame) {
      won = players[declarer].tricks == 0;
      value = nullValue(hand: hand);
      lines.add('Null${hand ? ' Hand' : ''}: $value');
    } else {
      final sp = spitzen(_declarerCards, type);
      final opp = 120 - dp;
      final schneider = dp >= 90 || opp >= 90;
      final declarerTricks = players[declarer].tricks;
      final schwarz = declarerTricks == 10 || declarerTricks == 0;
      var mult = sp + 1;
      final mit = _declarerCards.contains(const PlayingCard(11, Suit.clubs));
      lines.add('${mit ? 'Mit' : 'Ohne'} $sp, Spiel 1');
      if (hand) {
        mult++;
        lines.add('Hand 1');
      }
      if (schneider) {
        mult++;
        lines.add('Schneider 1');
      }
      if (schneiderAnnounced) {
        mult++;
        lines.add('Schneider angesagt 1');
      }
      if (schwarz) {
        mult++;
        lines.add('Schwarz 1');
      }
      if (schwarzAnnounced) {
        mult++;
        lines.add('Schwarz angesagt 1');
      }
      value = _baseValue[type]! * mult;
      lines.add('${skatTypeNames[type]} ${_baseValue[type]} × $mult = $value');
      won = dp >= 61;
      if (schneiderAnnounced && dp < 90) won = false;
      if (schwarzAnnounced && declarerTricks < 10) won = false;
    }
    if (value < bid) {
      // Überreizt: verloren mit dem kleinsten Vielfachen über dem Reizwert
      won = false;
      if (type != SkatType.nullGame) {
        final b = _baseValue[type]!;
        value = ((bid + b - 1) ~/ b) * b;
      } else {
        value = bidValues.firstWhere((v) => v >= bid);
      }
      lines.add('Überreizt! Gereizt war $bid');
    }
    final change = won ? value : -2 * value;
    players[declarer].score += change;
    final who = _who(declarer);
    final text = type == SkatType.nullGame
        ? '$who ${won ? (declarer == 0 ? 'gewinnst' : 'gewinnt') : (declarer == 0 ? 'verlierst' : 'verliert')} den Null'
        : '$who ${won ? (declarer == 0 ? 'gewinnst' : 'gewinnt') : (declarer == 0 ? 'verlierst' : 'verliert')} mit $dp Augen';
    result = SkatResult(text: text, declarer: declarer, won: won, value: value, points: change, lines: lines);
    dealsPlayed++;
    dealer = (dealer + 1) % 3;
    phase = dealsPlayed >= deals ? SkatPhase.matchOver : SkatPhase.dealOver;
  }

  /// Die zwölf Karten des Alleinspielers am Anfang (Hand plus Skat).
  List<PlayingCard> _declarerCards = [];

  void nextDeal() => record(['n'], () => _nextDealImpl());

  void _nextDealImpl() {
    if (phase == SkatPhase.dealOver) newDeal();
  }

  /// Wer vor diesem Bildschirm sitzt (im Netz je Gerät verschieden); nur für die Texte.
  int me = 0;
  String _who(int p) => p == me ? 'Du' : players[p].name;

  List<int> ranking() => [0, 1, 2]..sort((a, b) => players[b].score - players[a].score);
}

/// Sortierung auf der Hand: Buben zuerst, dann Trumpffarbe, dann die übrigen Farben.
List<PlayingCard> sortSkat(List<PlayingCard> cards, SkatType? t) {
  final ts = t == null ? null : trumpSuitOf(t);
  int key(PlayingCard c) {
    if (t != SkatType.nullGame && c.rank == 11) return 1000 - jackRank(c.suit) * 10;
    final suitOrder = const {Suit.clubs: 0, Suit.spades: 1, Suit.hearts: 2, Suit.diamonds: 3}[c.suit]!;
    final s = c.suit == ts ? -1 : suitOrder;
    final p = t == SkatType.nullGame ? power(c, SkatType.nullGame) : power(c, SkatType.grand);
    return 2000 + s * 100 - p;
  }

  return [...cards]..sort((a, b) => key(a) - key(b));
}

/// Spielt einen gespeicherten Zug nach.
void skatApply(SkatGame g, List<dynamic> a) {
  switch (a[0] as String) {
    case 'y':
      g.bidYes(a[1] as int);
    case 'b':
      g.bidPass(a[1] as int);
    case 's':
      g.takeSkat();
    case 'h':
      g.playHand();
    case 'd':
      g.discard([for (final x in a.sublist(1)) cardFromCode(x as String)]);
    case 'a':
      g.declare(SkatType.values[a[1] as int], schneider: a[2] as bool, schwarz: a[3] as bool);
    case 'p':
      g.play(a[1] as int, cardFromCode(a[2] as String));
    case 'n':
      g.nextDeal();
  }
}
