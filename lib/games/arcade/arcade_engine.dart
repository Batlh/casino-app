import 'dart:math';

/// „Goldene Sieben“: Geldspielautomat wie in der Spielhalle der Achtziger.
///
/// Drei Walzen, eine Gewinnlinie in der Mitte. Nach Drehungen ohne Gewinn bietet der Automat manchmal
/// „Halten“ (Walzen für die nächste Drehung festhalten) oder „Nachschieben“ (eine Walze um ein Feld rücken) an.
/// Drei Sterne bringen Sonderspiele mit doppeltem Gewinn. Jeder Gewinn kann auf der Risikoleiter verdoppelt
/// werden (50 : 50) oder sofort angenommen werden.
///
/// Abgestimmt mit tool/tune_spielhalle.py (gleiche Walzen und Werte): etwa 96 % bei Spiel nach der Hilfe.
const arcadeSymbols = ['Kirsche', 'Zitrone', 'Orange', 'Pflaume', 'Melone', 'Glocke', 'Stern', 'Sieben'];
const arcadeStar = 6;
const arcadeSeven = 7;

const arcadeStrips = [
  [0, 1, 2, 0, 3, 1, 4, 0, 2, 5, 1, 3, 0, 6, 2, 1, 4, 0, 3, 7, 1, 2],
  [1, 0, 3, 2, 1, 4, 2, 0, 5, 1, 3, 2, 6, 1, 0, 4, 2, 3, 7, 1, 2, 3],
  [2, 1, 3, 0, 4, 2, 1, 5, 3, 2, 1, 6, 4, 2, 3, 1, 7, 2, 4, 1, 3, 2],
];

/// Drei Gleiche auf der Linie, × Einsatz.
const arcadeThree = {7: 100, 5: 40, 4: 20, 3: 12, 2: 10, 1: 6, 0: 5};
const arcadeTwoCherries = 3;
const arcadeOneCherry = 1;
const arcadeFreeSpins = 10;
const arcadeFreeMult = 2;
const arcadeHoldChance = 0.22;
const arcadeNudgeChance = 0.15;

/// Risikoleiter: höchstens so oft verdoppeln.
const arcadeLadderSteps = 6;

int arcadeLinePay(List<int> line) {
  final [a, b, c] = line;
  if (a == b && b == c) return a == arcadeStar ? 0 : arcadeThree[a]!;
  if (a == 0 && b == 0) return arcadeTwoCherries;
  if (a == 0) return arcadeOneCherry;
  return 0;
}

bool arcadeStars(List<int> line) => line.every((s) => s == arcadeStar);

enum ArcadeOffer { none, hold, nudge }

class ArcadeMachine {
  ArcadeMachine({Random? rng}) : _rng = rng ?? Random.secure();
  final Random _rng;

  /// Stopp je Walze (Index in der Walze); die Linie liegt auf diesem Feld.
  List<int> pos = [0, 7, 3];
  int bet = 10;
  int freeSpins = 0;

  /// Angebot nach der letzten Drehung.
  ArcadeOffer offer = ArcadeOffer.none;

  /// Walzen, die bei der nächsten Drehung stehen bleiben.
  final Set<int> held = {};

  /// Gewinn der letzten Drehung (vor der Risikoleiter).
  int lastWin = 0;
  bool lastFree = false;

  int symbolAt(int reel, int offset) {
    final s = arcadeStrips[reel];
    return s[(pos[reel] + offset) % s.length];
  }

  List<int> get line => [for (var r = 0; r < 3; r++) symbolAt(r, 0)];

  /// Drehen. Gibt den Gewinn zurück (Sonderspiele zahlen doppelt). Kosten trägt der Aufrufer, außer in Sonderspielen.
  int spin() {
    lastFree = freeSpins > 0;
    if (lastFree) freeSpins--;
    for (var r = 0; r < 3; r++) {
      if (!held.contains(r)) pos[r] = _rng.nextInt(arcadeStrips[r].length);
    }
    held.clear();
    return _settle(allowOffer: true);
  }

  int _settle({required bool allowOffer}) {
    final l = line;
    var win = arcadeLinePay(l) * bet * (lastFree ? arcadeFreeMult : 1);
    if (arcadeStars(l)) freeSpins += arcadeFreeSpins;
    offer = ArcadeOffer.none;
    if (allowOffer && win == 0 && !arcadeStars(l) && !lastFree) {
      if (_rng.nextDouble() < arcadeNudgeChance) {
        offer = ArcadeOffer.nudge;
      } else if (_rng.nextDouble() < arcadeHoldChance) {
        offer = ArcadeOffer.hold;
      }
    }
    lastWin = win;
    return win;
  }

  /// Nachschieben: Walze [reel] um [dir] (−1 hoch, +1 runter) rücken. Nur einmal je Angebot.
  int nudge(int reel, int dir) {
    if (offer != ArcadeOffer.nudge) return 0;
    final n = arcadeStrips[reel].length;
    pos[reel] = (pos[reel] + dir + n) % n;
    return _settle(allowOffer: false);
  }

  /// Bester Schub laut Hilfe, oder null, wenn keiner etwas bringt.
  (int reel, int dir)? suggestNudge() {
    (int, int)? best;
    var bestPay = 0;
    for (var r = 0; r < 3; r++) {
      for (final d in const [-1, 1]) {
        final p = [...pos];
        final n = arcadeStrips[r].length;
        p[r] = (p[r] + d + n) % n;
        final l = [for (var i = 0; i < 3; i++) arcadeStrips[i][p[i]]];
        final pay = arcadeLinePay(l) + (arcadeStars(l) ? 1000 : 0);
        if (pay > bestPay) {
          bestPay = pay;
          best = (r, d);
        }
      }
    }
    return best;
  }

  /// Halten laut Hilfe: Paare (bestes Symbol), sonst Kirsche auf Walze 1, sonst zwei Sterne vorn.
  Set<int> suggestHold() {
    final l = line;
    (int, int)? best;
    for (final (i, j) in const [(0, 1), (0, 2), (1, 2)]) {
      if (l[i] == l[j] && l[i] != arcadeStar && (best == null || arcadeThree[l[i]]! > arcadeThree[l[best.$1]]!)) best = (i, j);
    }
    if (best != null) return {best.$1, best.$2};
    if (l[0] == 0) return {0};
    if (l[0] == arcadeStar && l[1] == arcadeStar) return {0, 1};
    return {};
  }

  void toggleHold(int reel) {
    if (offer != ArcadeOffer.hold) return;
    if (!held.remove(reel)) held.add(reel);
  }
}
