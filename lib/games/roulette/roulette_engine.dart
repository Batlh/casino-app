import 'dart:math';

/// Europäisches Roulette mit einer Null.
const List<int> wheelOrder = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26,
];

/// Amerikanischer Kessel mit Null und Doppelnull (37 steht für „00“).
const int doubleZero = 37;
const List<int> wheelOrderAmerican = [
  0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1, doubleZero,
  27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2,
];

/// Europäisch (eine Null), französisch (eine Null, bei Null gibt es auf einfachen Chancen die Hälfte zurück),
/// amerikanisch (Null und Doppelnull).
enum RouletteVariant { european, french, american }

const rouletteVariantNames = {
  RouletteVariant.european: 'Europäisch',
  RouletteVariant.french: 'Französisch',
  RouletteVariant.american: 'Amerikanisch',
};

List<int> wheelFor(RouletteVariant v) => v == RouletteVariant.american ? wheelOrderAmerican : wheelOrder;

bool isZero(int n) => n == 0 || n == doubleZero;
String pocketLabel(int n) => n == doubleZero ? '00' : '$n';

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

  /// Mehrere Zahlen zusammen (Cheval, Transversale, Carré …), Zahlen in [BetSpot.numbers].
  group,
}

/// Eine Stelle auf dem Tisch. value: Zahl, Dutzend (0 bis 2) oder Kolonne (0 bis 2).
class BetSpot {
  const BetSpot(this.type, [this.value = 0]) : numbers = const [];

  /// Mehrere Zahlen: 2 (Cheval 17:1), 3 (Transversale 11:1), 4 (Carré 8:1), 6 (Sixain 5:1).
  BetSpot.group(List<int> numbers)
      : type = BetType.group,
        value = 0,
        numbers = List.unmodifiable([...numbers]..sort());

  final BetType type;
  final int value;
  final List<int> numbers;

  /// Auszahlung zum Einsatz, ohne den Einsatz selbst.
  int get odds => switch (type) {
        BetType.straight => 35,
        BetType.dozen || BetType.column => 2,
        BetType.group => 36 ~/ numbers.length - 1,
        _ => 1,
      };

  /// Einfache Chance (Rot/Schwarz, Gerade/Ungerade, 1–18/19–36).
  bool get evenMoney => const {BetType.red, BetType.black, BetType.even, BetType.odd, BetType.low, BetType.high}.contains(type);

  bool wins(int n) {
    if (type == BetType.straight) return n == value;
    if (type == BetType.group) return numbers.contains(n);
    if (isZero(n)) return false;
    return switch (type) {
      BetType.red => isRed(n),
      BetType.black => !isRed(n),
      BetType.even => n.isEven,
      BetType.odd => n.isOdd,
      BetType.low => n <= 18,
      BetType.high => n >= 19,
      BetType.dozen => (n - 1) ~/ 12 == value,
      BetType.column => (n - 1) % 3 == value,
      BetType.straight || BetType.group => false,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BetSpot && other.type == type && other.value == value && other.numbers.join(',') == numbers.join(',');

  @override
  int get hashCode => Object.hash(type, value, numbers.join(','));
}

int spinWheel(Random rng, [RouletteVariant v = RouletteVariant.european]) {
  final order = wheelFor(v);
  return order[rng.nextInt(order.length)];
}

/// Münzen, die nach dem Dreh zurückkommen. Einsatz plus Gewinn auf jeder gewonnenen Stelle.
/// Französisch ([partage]): Fällt die Null, kommt auf einfachen Chancen die Hälfte des Einsatzes zurück.
int resolveBets(Map<BetSpot, int> bets, int number, {bool partage = false}) {
  var back = 0;
  bets.forEach((spot, stake) {
    if (spot.wins(number)) {
      back += stake * (spot.odds + 1);
    } else if (partage && number == 0 && spot.evenMoney) {
      back += stake ~/ 2;
    }
  });
  return back;
}

// ------------------------------------------------------------------ Kesselansagen (nur Kessel mit einer Null)

/// Eine Ansage: Stellen mit der Zahl der Stücke je Stelle.
class CallBet {
  const CallBet(this.name, this.text, this.parts);
  final String name;
  final String text;
  final List<(List<int>, int)> parts;

  int get pieces => parts.fold(0, (a, p) => a + p.$2);

  /// Einsätze für [chip] je Stück.
  Map<BetSpot, int> spots(int chip) => {
        for (final (nums, n) in parts) (nums.length == 1 ? BetSpot(BetType.straight, nums.first) : BetSpot.group(nums)): n * chip,
      };
}

const callBets = [
  CallBet('Voisins du Zéro', 'Die 17 Zahlen rund um die Null, 9 Stücke', [
    ([0, 2, 3], 2), ([4, 7], 1), ([12, 15], 1), ([18, 21], 1), ([19, 22], 1), ([25, 26, 28, 29], 2), ([32, 35], 1),
  ]),
  CallBet('Tiers du Cylindre', 'Das Drittel gegenüber der Null, 6 Stücke', [
    ([5, 8], 1), ([10, 11], 1), ([13, 16], 1), ([23, 24], 1), ([27, 30], 1), ([33, 36], 1),
  ]),
  CallBet('Orphelins', 'Die übrigen 8 Zahlen, 5 Stücke', [
    ([1], 1), ([6, 9], 1), ([14, 17], 1), ([17, 20], 1), ([31, 34], 1),
  ]),
  CallBet('Jeu Zéro', 'Die 7 Zahlen direkt bei der Null, 4 Stücke', [
    ([0, 3], 1), ([12, 15], 1), ([26], 1), ([32, 35], 1),
  ]),
];

/// Nachbarn: die Zahl und je [count] Nachbarn links und rechts auf dem Kessel, je ein Stück.
CallBet neighbours(int n, {int count = 2}) {
  final i = wheelOrder.indexOf(n);
  final nums = [for (var k = -count; k <= count; k++) wheelOrder[(i + k) % wheelOrder.length]];
  return CallBet('$n und Nachbarn', nums.join(' · '), [for (final x in nums) ([x], 1)]);
}
