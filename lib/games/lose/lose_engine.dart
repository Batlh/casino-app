import 'dart:math';

/// Rubbellose und Pull-Tabs. Jedes Los wird erst beim Kauf ausgewürfelt: Zuerst der Gewinn nach der
/// Gewinntabelle der Sorte, dann wird das Los passend dazu „bedruckt“. Es gibt keinen begrenzten Stapel.

/// Ein Eintrag der Gewinntabelle: Gewinn (Münzen) und Chance „1 zu oneIn“.
class LosPrize {
  const LosPrize(this.amount, this.oneIn);
  final int amount;
  final int oneIn;
  double get chance => 1 / oneIn;
}

/// Würfelt einen Gewinn aus der Tabelle, 0 für eine Niete.
int drawPrize(List<LosPrize> table, Random rng) {
  var x = rng.nextDouble();
  for (final p in table) {
    x -= p.chance;
    if (x < 0) return p.amount;
  }
  return 0;
}

/// Erwartete Auszahlung je Los (Münzen).
double expectedPayout(List<LosPrize> table) => table.fold(0.0, (a, p) => a + p.amount * p.chance);

/// Gewinnchance insgesamt.
double winChance(List<LosPrize> table) => table.fold(0.0, (a, p) => a + p.chance);

// ---------------------------------------------------------------- Rubbellose

enum RubbelKind { dreiGleiche, gewinnzahlen, symbolSuche }

class RubbelSorte {
  const RubbelSorte({
    required this.id,
    required this.name,
    required this.price,
    required this.kind,
    required this.table,
    required this.rule,
    required this.colors,
  });
  final String id;
  final String name;
  final int price;
  final RubbelKind kind;
  final List<LosPrize> table;

  /// Spielregel in einem Satz, steht auf dem Los.
  final String rule;

  /// Hintergrundfarben des Loses.
  final List<int> colors;

  int get topPrize => table.map((p) => p.amount).reduce(max);
}

/// Ein Feld auf dem Rubbellos: Zahl oder Symbol, dazu ein Betrag.
class RubbelFeld {
  const RubbelFeld({this.number = 0, this.symbol = '', this.amount = 0, this.winning = false});
  final int number;
  final String symbol;
  final int amount;
  final bool winning;
}

class RubbelLos {
  const RubbelLos({required this.sorte, required this.prize, required this.fields, this.winningNumbers = const []});
  final RubbelSorte sorte;
  final int prize;
  final List<RubbelFeld> fields;

  /// Nur bei Gewinnzahlen: die oben stehenden Gewinnzahlen.
  final List<int> winningNumbers;
}

const rubbelSorten = [
  RubbelSorte(
    id: 'klee',
    name: 'Glücksklee',
    price: 50,
    kind: RubbelKind.dreiGleiche,
    rule: '3 gleiche Beträge gewinnen diesen Betrag.',
    colors: [0xFF2E7D32, 0xFF81C784],
    table: [
      LosPrize(50, 5),
      LosPrize(100, 12),
      LosPrize(250, 40),
      LosPrize(500, 100),
      LosPrize(1000, 400),
      LosPrize(2500, 1000),
      LosPrize(25000, 25000),
    ],
  ),
  RubbelSorte(
    id: 'gold',
    name: 'Goldrausch',
    price: 200,
    kind: RubbelKind.gewinnzahlen,
    rule: 'Stimmt eine deiner Zahlen mit einer Gewinnzahl überein, gewinnst du den Betrag darunter.',
    colors: [0xFF8D6E00, 0xFFFFD54F],
    table: [
      LosPrize(200, 6),
      LosPrize(400, 10),
      LosPrize(1000, 30),
      LosPrize(2000, 100),
      LosPrize(5000, 600),
      LosPrize(10000, 2000),
      LosPrize(200000, 250000),
    ],
  ),
  RubbelSorte(
    id: 'diamant',
    name: 'Diamantfieber',
    price: 500,
    kind: RubbelKind.symbolSuche,
    rule: 'Findest du einen Diamanten, gewinnst du den Betrag in diesem Feld.',
    colors: [0xFF1A237E, 0xFF4FC3F7],
    table: [
      LosPrize(500, 5),
      LosPrize(1000, 10),
      LosPrize(2500, 30),
      LosPrize(5000, 120),
      LosPrize(25000, 1500),
      LosPrize(100000, 20000),
      LosPrize(1000000, 1000000),
    ],
  ),
];

/// Symbole der Symbolsuche außer dem Diamanten.
const rubbelNieten = ['Kohle', 'Stein', 'Spitzhacke', 'Laterne', 'Hufeisen'];

RubbelLos makeRubbelLos(RubbelSorte s, Random rng) {
  final prize = drawPrize(s.table, rng);
  final amounts = s.table.map((p) => p.amount).toList();
  int otherAmount(Set<int> avoid) {
    final pool = amounts.where((a) => !avoid.contains(a)).toList();
    // Kleine Beträge öfter als große, damit das Los glaubwürdig aussieht
    final weights = [for (var i = 0; i < pool.length; i++) pool.length - i];
    var x = rng.nextInt(weights.fold(0, (a, b) => a + b));
    for (var i = 0; i < pool.length; i++) {
      x -= weights[i];
      if (x < 0) return pool[i];
    }
    return pool.first;
  }

  switch (s.kind) {
    case RubbelKind.dreiGleiche:
      // 6 Felder; bei Gewinn genau 3 × Gewinnbetrag, sonst höchstens 2 gleiche
      final values = <int>[];
      if (prize > 0) values.addAll([prize, prize, prize]);
      final counts = <int, int>{for (final v in values) v: values.where((x) => x == v).length};
      while (values.length < 6) {
        final full = {for (final e in counts.entries) if (e.value >= 2) e.key, if (prize > 0) prize};
        final v = otherAmount(full);
        values.add(v);
        counts[v] = (counts[v] ?? 0) + 1;
      }
      values.shuffle(rng);
      return RubbelLos(sorte: s, prize: prize, fields: [for (final v in values) RubbelFeld(amount: v, winning: prize > 0 && v == prize)]);
    case RubbelKind.gewinnzahlen:
      // 2 Gewinnzahlen und 8 eigene Zahlen von 1 bis 30, jede mit Betrag darunter
      final all = [for (var i = 1; i <= 30; i++) i]..shuffle(rng);
      final win = all.take(2).toList();
      final rest = all.skip(2).toList();
      final own = <RubbelFeld>[];
      final hit = prize > 0 ? rng.nextInt(8) : -1;
      var k = 0;
      for (var i = 0; i < 8; i++) {
        if (i == hit) {
          own.add(RubbelFeld(number: win[rng.nextInt(2)], amount: prize, winning: true));
        } else {
          own.add(RubbelFeld(number: rest[k++], amount: otherAmount({if (prize > 0) prize})));
        }
      }
      return RubbelLos(sorte: s, prize: prize, fields: own, winningNumbers: win);
    case RubbelKind.symbolSuche:
      // 9 Felder; bei Gewinn genau ein Diamant mit dem Gewinnbetrag
      final hit = prize > 0 ? rng.nextInt(9) : -1;
      return RubbelLos(
        sorte: s,
        prize: prize,
        fields: [
          for (var i = 0; i < 9; i++)
            i == hit
                ? RubbelFeld(symbol: 'Diamant', amount: prize, winning: true)
                : RubbelFeld(symbol: rubbelNieten[rng.nextInt(rubbelNieten.length)], amount: otherAmount({})),
        ],
      );
  }
}

// ---------------------------------------------------------------- Pull-Tabs

/// Symbole der Pull-Tabs, von klein nach groß.
const pullSymbole = ['Kirsche', 'Zitrone', 'Glocke', 'Hufeisen', 'Sieben', 'Krone', 'Diamant', 'Goldbarren'];

class PullSorte {
  const PullSorte({required this.id, required this.name, required this.price, required this.pays, required this.colors});
  final String id;
  final String name;
  final int price;

  /// Symbol (Index in pullSymbole) → Vielfaches des Preises und Chance.
  final Map<int, LosPrize> pays;
  final List<int> colors;

  List<LosPrize> get table => [for (final p in pays.values) LosPrize(p.amount * price, p.oneIn)];
}

const pullSorten = [
  PullSorte(
    id: 'kirsch',
    name: 'Kirsch-Tabs',
    price: 25,
    colors: [0xFFC62828, 0xFFFF8A80],
    pays: {0: LosPrize(1, 4), 1: LosPrize(2, 10), 2: LosPrize(5, 30), 3: LosPrize(20, 250), 4: LosPrize(100, 2500), 5: LosPrize(500, 25000)},
  ),
  PullSorte(
    id: 'glocke',
    name: 'Glocken-Tabs',
    price: 50,
    colors: [0xFF6A1B9A, 0xFFCE93D8],
    pays: {
      0: LosPrize(1, 5),
      1: LosPrize(2, 14),
      2: LosPrize(5, 40),
      3: LosPrize(20, 200),
      4: LosPrize(100, 1500),
      5: LosPrize(500, 10000),
      6: LosPrize(2000, 200000),
    },
  ),
  PullSorte(
    id: 'gold',
    name: 'Goldbarren-Tabs',
    price: 100,
    colors: [0xFF4E342E, 0xFFFFCA28],
    pays: {0: LosPrize(1, 6), 2: LosPrize(5, 30), 3: LosPrize(20, 150), 4: LosPrize(100, 1000), 5: LosPrize(500, 7500), 7: LosPrize(5000, 250000)},
  ),
];

class PullTab {
  const PullTab({required this.sorte, required this.prize, required this.rows, required this.winRow});
  final PullSorte sorte;
  final int prize;

  /// 5 Fenster mit je 3 Symbolen (Index in pullSymbole).
  final List<List<int>> rows;

  /// Fenster mit dem Gewinn, -1 bei einer Niete.
  final int winRow;
}

PullTab makePullTab(PullSorte s, Random rng) {
  // Gewinn auswürfeln, dazu das Symbol
  var x = rng.nextDouble();
  var sym = -1;
  for (final e in s.pays.entries) {
    x -= e.value.chance;
    if (x < 0) {
      sym = e.key;
      break;
    }
  }
  final symbols = s.pays.keys.toList();
  List<int> loseRow() {
    // Nie drei gleiche; manchmal zwei gleiche, das sieht nach „knapp daneben“ aus
    while (true) {
      final r = [for (var i = 0; i < 3; i++) symbols[rng.nextInt(symbols.length)]];
      if (!(r[0] == r[1] && r[1] == r[2])) return r;
    }
  }

  final winRow = sym >= 0 ? rng.nextInt(5) : -1;
  final rows = [for (var i = 0; i < 5; i++) i == winRow ? [sym, sym, sym] : loseRow()];
  return PullTab(sorte: s, prize: sym >= 0 ? s.pays[sym]!.amount * s.price : 0, rows: rows, winRow: winRow);
}
