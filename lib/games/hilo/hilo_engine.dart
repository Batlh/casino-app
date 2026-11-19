import 'dart:math';

import '../cards/playing_card.dart';

/// Höher oder Tiefer: Eine Karte liegt offen, du rätst, ob die nächste höher oder tiefer ist. Jeder Treffer
/// multipliziert den Gewinn, du kannst jederzeit aussteigen. Gleich hoch zählt als verloren. Ass ist hoch.
///
/// Der Faktor jeder Stufe richtet sich nach der Wahrscheinlichkeit aus dem Restspiel (sechs Decks), mit 3 % Vorteil
/// für die Bank: Faktor = 0,97 / Trefferchance, abgerundet auf zwei Stellen.
const hiloReturn = 0.97;

/// Längste Leiter; danach wird automatisch ausgezahlt.
const hiloMaxSteps = 10;

/// Höchster Gewinn als Vielfaches des Einsatzes; erreicht, wird automatisch ausgezahlt.
const hiloMaxFactor = 1000;

enum HiloGuess { higher, lower }

enum HiloPhase { idle, running, lost, cashed }

class HiloGame {
  HiloGame({Random? rng}) : _rng = rng ?? Random.secure() {
    _shoe = shuffledDeck(_rng, decks: 6);
  }

  final Random _rng;
  late List<PlayingCard> _shoe;

  HiloPhase phase = HiloPhase.idle;
  int bet = 0;

  /// Aktueller Gewinn in Hundertsteln des Einsatzes (100 = Einsatz).
  int _factor100 = 100;
  int steps = 0;
  PlayingCard? card;
  final List<PlayingCard> history = [];

  int get win => bet * _factor100 ~/ 100;
  int get remaining => _shoe.length;

  PlayingCard _draw() {
    if (_shoe.length < 30) _shoe = shuffledDeck(_rng, decks: 6);
    return _shoe.removeLast();
  }

  /// Wie viele Karten im Schuh sind höher bzw. tiefer als [c]?
  (int higher, int lower, int total) _counts(PlayingCard c) {
    var h = 0, l = 0;
    for (final x in _shoe) {
      if (x.rank > c.rank) h++;
      if (x.rank < c.rank) l++;
    }
    return (h, l, _shoe.length);
  }

  /// Chance für [g] bei der aktuellen Karte (0..1).
  double chance(HiloGuess g) {
    final c = card;
    if (c == null) return 0;
    final (h, l, t) = _counts(c);
    return (g == HiloGuess.higher ? h : l) / t;
  }

  /// Faktor für einen Treffer mit [g] in Hundertsteln, oder 0, wenn unmöglich.
  int factor100(HiloGuess g) {
    final p = chance(g);
    if (p <= 0) return 0;
    return max(101, (hiloReturn / p * 100).floor());
  }

  void start(int stake) {
    bet = stake;
    _factor100 = 100;
    steps = 0;
    history.clear();
    card = _draw();
    phase = HiloPhase.running;
  }

  /// Raten. Gibt die neue Karte zurück.
  PlayingCard guess(HiloGuess g) {
    final c = card!;
    final f = factor100(g);
    final next = _draw();
    history.add(c);
    card = next;
    final hit = g == HiloGuess.higher ? next.rank > c.rank : next.rank < c.rank;
    if (!hit || f == 0) {
      phase = HiloPhase.lost;
      return next;
    }
    _factor100 = min(_factor100 * f ~/ 100, hiloMaxFactor * 100);
    steps++;
    if (steps >= hiloMaxSteps || _factor100 >= hiloMaxFactor * 100) phase = HiloPhase.cashed;
    return next;
  }

  /// Aussteigen nach mindestens einem Treffer: Der Gewinn wird ausgezahlt.
  bool get canCashOut => phase == HiloPhase.running && steps > 0;

  int cashOut() {
    if (!canCashOut && phase != HiloPhase.cashed) return 0;
    phase = HiloPhase.cashed;
    return win;
  }
}
