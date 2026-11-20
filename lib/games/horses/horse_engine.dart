import 'dart:math';

/// Pferderennen: sechs Pferde, Wetten auf Sieg oder Platz (unter den ersten zwei).
///
/// Vor jedem Rennen bekommt jedes Pferd eine Stärke. Die Einlaufreihenfolge wird danach ausgelost: Erst wird der
/// Sieger nach Stärke gezogen, dann aus den übrigen der Zweite und so weiter. Daraus ergeben sich die Gewinnchancen
/// genau, und die Quoten sind so gesetzt, dass auf lange Sicht [horseReturn] der Einsätze zurückfließen.
const horseReturn = 0.95;

const horseNames = ['Blitz', 'Sturmwind', 'Abendrot', 'Hafersack', 'Silberpfeil', 'Mondschein'];

enum BetKind { win, place }

class HorseBet {
  const HorseBet(this.horse, this.kind, this.amount);
  final int horse;
  final BetKind kind;
  final int amount;
}

/// Rennkarte: Stärken und Quoten eines Rennens.
class RaceCard {
  RaceCard(this.weights) : assert(weights.length == horseNames.length);

  /// Karte aus einem Startwert (gleich bei allen am Netztisch).
  factory RaceCard.fromSeed(int seed) {
    final rng = Random(seed);
    return RaceCard([for (var i = 0; i < horseNames.length; i++) 0.6 + rng.nextDouble() * 2.4]);
  }

  final List<double> weights;
  double get _sum => weights.reduce((a, b) => a + b);

  double winChance(int i) => weights[i] / _sum;

  /// Chance, unter den ersten zwei zu sein.
  double placeChance(int i) {
    final s = _sum;
    var p = weights[i] / s;
    for (var j = 0; j < weights.length; j++) {
      if (j == i) continue;
      p += weights[j] / s * weights[i] / (s - weights[j]);
    }
    return p;
  }

  /// Auszahlung je eingesetzter Münze in Zehnteln (z. B. 35 = 3,5-fach, Einsatz inklusive), abgerundet.
  int odds10(int horse, BetKind kind) {
    final p = kind == BetKind.win ? winChance(horse) : placeChance(horse);
    return max(11, (horseReturn / p * 10).floor());
  }

  /// Einlaufreihenfolge aus einem Startwert.
  List<int> race(int seed) {
    final rng = Random(seed);
    final left = [for (var i = 0; i < weights.length; i++) i];
    final order = <int>[];
    while (left.isNotEmpty) {
      final s = left.fold(0.0, (a, i) => a + weights[i]);
      var v = rng.nextDouble() * s;
      var pick = left.last;
      for (final i in left) {
        v -= weights[i];
        if (v <= 0) {
          pick = i;
          break;
        }
      }
      order.add(pick);
      left.remove(pick);
    }
    return order;
  }

  /// Auszahlung einer Wette (0 bei Verlust).
  int payout(HorseBet b, List<int> order) {
    final won = b.kind == BetKind.win ? order.first == b.horse : order.take(2).contains(b.horse);
    return won ? b.amount * odds10(b.horse, b.kind) ~/ 10 : 0;
  }
}

/// Fortschritt (0 … 1) eines Pferdes zur Zeit [t] (0 … 1) des Rennens, passend zur Einlaufreihenfolge.
/// Alle laufen mit kleinen Schwankungen; wer früher ankommt, ist im Mittel schneller.
double horseProgress(List<int> order, int horse, double t, int seed) {
  final rank = order.indexOf(horse);
  final finish = 0.82 + rank * 0.035; // Zieleinlauf in Rennzeit
  final base = (t / finish).clamp(0.0, 1.0);
  final wobble = sin(t * 9 + horse * 1.7 + seed % 7) * 0.025 + sin(t * 23 + horse * 0.9) * 0.012;
  return (base + wobble * base * (1 - base) * 4).clamp(0.0, 1.0);
}
