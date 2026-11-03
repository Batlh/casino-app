import 'dart:math';

/// Europäisches Roulette mit einer Null.
const List<int> wheelOrder = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
];

const Set<int> redNumbers = {
  1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36,
};

bool isRed(int n) => redNumbers.contains(n);

enum BetType {
  straight,
  red,
  black,
  even,
  odd,
  low,
  high,
  dozen,
  column,
}

/// Eine Stelle auf dem Tisch. value: Zahl, Dutzend (0 bis 2) oder Kolonne (0 bis 2).
class BetSpot {
  const BetSpot(this.type, [this.value = 0]);

  final BetType type;
  final int value;

  /// Auszahlung zum Einsatz, ohne den Einsatz selbst.
  int get odds => switch (type) {
        BetType.straight => 35,
        BetType.dozen || BetType.column => 2,
        _ => 1,
      };

  bool wins(int n) {
    if (type == BetType.straight) return n == value;
    if (n == 0) return false;
    return switch (type) {
      BetType.red => isRed(n),
      BetType.black => !isRed(n),
      BetType.even => n.isEven,
      BetType.odd => n.isOdd,
      BetType.low => n <= 18,
      BetType.high => n >= 19,
      BetType.dozen => (n - 1) ~/ 12 == value,
      BetType.column => (n - 1) % 3 == value,
      BetType.straight => false,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BetSpot && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);
}

int spinWheel(Random rng) => wheelOrder[rng.nextInt(wheelOrder.length)];

/// Münzen, die nach dem Dreh zurückkommen. Einsatz plus Gewinn auf jeder
/// gewonnenen Stelle.
int resolveBets(Map<BetSpot, int> bets, int number) {
  var back = 0;
  bets.forEach((spot, stake) {
    if (spot.wins(number)) back += stake * (spot.odds + 1);
  });
  return back;
}
