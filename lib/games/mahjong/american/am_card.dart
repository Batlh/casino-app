import '../tiles.dart';

/// Eigene Karte für American Mahjong („Glückskarte“). Die Hände sind selbst ausgedacht,
/// im Stil der amerikanischen Jahreskarten, aber keine Kopie davon.
///
/// Steinsorten in dieser Variante: 0 bis 33 wie gewohnt, 34 steht für jede Blume, Joker extra.
const amFlower = 34;
const amKinds = 35;

/// Drache, der zu einer Farbe gehört: Zeichen rot, Kreise weiß, Bambus grün.
int dragonOfSuit(int suit) => const [33, 31, 32][suit];

/// Ein Baustein einer Kartenhand.
class AmSpec {
  const AmSpec(this.code, this.count, [this.suit = '']);

  /// '1' bis '9' feste Zahl, 'n', 'n+1' … Zahl mit Variable, 'F' Blume, 'D' Drache der Farbe,
  /// '0' Weißer Drache als Null, 'N' 'E' 'W' 'S' Winde, 'R' 'G' 'Wh' feste Drachen.
  final String code;
  final int count;

  /// Farbvariable A, B oder C (verschiedene Buchstaben, verschiedene Farben).
  final String suit;
}

class AmHand {
  const AmHand(this.category, this.value, this.specs, {this.concealed = false});
  final String category;
  final int value;
  final List<AmSpec> specs;

  /// Nur verdeckt (C), sonst darf man aufdecken (X).
  final bool concealed;

  String get label => specs.map((s) => _codeText(s)).join(' ');
}

String _codeText(AmSpec s) {
  final c = switch (s.code) {
    'Wh' => '0',
    'R' => 'D',
    'G' => 'D',
    _ => s.code,
  };
  if (c.startsWith('n')) return List.filled(s.count, c).join('·');
  return List.filled(s.count, c).join();
}

const amCard = <AmHand>[
  // Jahreszahl
  AmHand('2026', 25, [AmSpec('2', 3, 'A'), AmSpec('0', 4), AmSpec('2', 3, 'B'), AmSpec('6', 4, 'C')]),
  AmHand('2026', 30, [AmSpec('F', 2), AmSpec('2', 4, 'A'), AmSpec('0', 4), AmSpec('6', 4, 'A')]),
  AmHand('2026', 50, [AmSpec('F', 2), AmSpec('2', 2, 'A'), AmSpec('0', 2), AmSpec('2', 2, 'B'), AmSpec('6', 2, 'B'), AmSpec('2', 2, 'C'), AmSpec('6', 2, 'C')], concealed: true),
  // Gerade Zahlen
  AmHand('2468', 25, [AmSpec('2', 3, 'A'), AmSpec('4', 4, 'A'), AmSpec('6', 3, 'A'), AmSpec('8', 4, 'A')]),
  AmHand('2468', 25, [AmSpec('F', 2), AmSpec('2', 4, 'A'), AmSpec('4', 2, 'B'), AmSpec('6', 2, 'B'), AmSpec('8', 4, 'A')]),
  AmHand('2468', 30, [AmSpec('2', 3, 'A'), AmSpec('4', 3, 'A'), AmSpec('6', 3, 'B'), AmSpec('8', 3, 'B'), AmSpec('D', 2, 'C')]),
  // Gleiche Zahlen
  AmHand('Gleiche Zahlen', 25, [AmSpec('F', 4), AmSpec('n', 3, 'A'), AmSpec('n', 4, 'B'), AmSpec('n', 3, 'C')]),
  AmHand('Gleiche Zahlen', 30, [AmSpec('F', 2), AmSpec('n', 4, 'A'), AmSpec('D', 4, 'A'), AmSpec('n', 4, 'B')]),
  // Folgen
  AmHand('Folgen', 25, [AmSpec('n', 3, 'A'), AmSpec('n+1', 4, 'A'), AmSpec('n+2', 3, 'A'), AmSpec('n+3', 4, 'A')]),
  AmHand('Folgen', 25, [AmSpec('F', 2), AmSpec('n', 4, 'A'), AmSpec('n+1', 4, 'B'), AmSpec('n+2', 4, 'C')]),
  AmHand('Folgen', 30, [AmSpec('F', 2), AmSpec('n', 3, 'A'), AmSpec('n+1', 3, 'A'), AmSpec('n+2', 3, 'A'), AmSpec('D', 3, 'A')]),
  // Ungerade Zahlen
  AmHand('13579', 25, [AmSpec('1', 3, 'A'), AmSpec('3', 4, 'A'), AmSpec('5', 3, 'A'), AmSpec('7', 4, 'A')]),
  AmHand('13579', 30, [AmSpec('1', 2, 'A'), AmSpec('3', 3, 'A'), AmSpec('5', 4, 'A'), AmSpec('7', 3, 'A'), AmSpec('9', 2, 'A')]),
  AmHand('13579', 25, [AmSpec('F', 2), AmSpec('1', 4, 'A'), AmSpec('D', 4, 'A'), AmSpec('9', 4, 'A')]),
  // Rechnen
  AmHand('Rechnen 3 + 4 = 7', 30, [AmSpec('F', 2), AmSpec('3', 4, 'A'), AmSpec('4', 4, 'B'), AmSpec('7', 4, 'C')]),
  // Drei, sechs, neun
  AmHand('369', 25, [AmSpec('3', 3, 'A'), AmSpec('6', 4, 'A'), AmSpec('9', 3, 'A'), AmSpec('D', 4, 'B')]),
  AmHand('369', 30, [AmSpec('F', 2), AmSpec('3', 4, 'A'), AmSpec('6', 4, 'B'), AmSpec('9', 4, 'C')]),
  // Fünflinge (nur mit Jokern möglich)
  AmHand('Fünflinge', 40, [AmSpec('n', 5, 'A'), AmSpec('n+1', 4, 'A'), AmSpec('n+2', 5, 'A')]),
  AmHand('Fünflinge', 45, [AmSpec('F', 4), AmSpec('n', 5, 'A'), AmSpec('D', 5, 'A')]),
  // Winde und Drachen
  AmHand('Winde und Drachen', 25, [AmSpec('N', 4), AmSpec('E', 3), AmSpec('W', 3), AmSpec('S', 4)]),
  AmHand('Winde und Drachen', 30, [AmSpec('F', 2), AmSpec('N', 3), AmSpec('E', 4), AmSpec('W', 3), AmSpec('S', 2)]),
  AmHand('Winde und Drachen', 30, [AmSpec('N', 2), AmSpec('S', 2), AmSpec('R', 3), AmSpec('G', 4), AmSpec('Wh', 3)]),
  // Paare (nur verdeckt, keine Joker)
  AmHand('Paare', 50, [AmSpec('F', 2), AmSpec('n', 2, 'A'), AmSpec('n+1', 2, 'A'), AmSpec('n+2', 2, 'A'), AmSpec('n+3', 2, 'A'), AmSpec('n+4', 2, 'A'), AmSpec('n+5', 2, 'A')], concealed: true),
  AmHand('Paare', 50, [AmSpec('N', 2), AmSpec('E', 2), AmSpec('W', 2), AmSpec('S', 2), AmSpec('1', 2, 'A'), AmSpec('1', 2, 'B'), AmSpec('1', 2, 'C')], concealed: true),
];

/// Eine Kartenhand mit eingesetzten Farben und Zahlen.
class AmConcrete {
  AmConcrete(this.hand, this.index, this.groups);
  final AmHand hand;
  final int index;

  /// (Steinsorte, Anzahl) je Gruppe.
  final List<(int, int)> groups;
}

int? _kindOf(AmSpec s, Map<String, int> suits, int n) {
  final c = s.code;
  if (c == 'F') return amFlower;
  if (c == '0' || c == 'Wh') return 31;
  if (c == 'R') return 33;
  if (c == 'G') return 32;
  if (c == 'N') return 30;
  if (c == 'E') return 27;
  if (c == 'W') return 29;
  if (c == 'S') return 28;
  final suit = suits[s.suit]!;
  if (c == 'D') return dragonOfSuit(suit);
  int num;
  if (c.startsWith('n')) {
    num = n + (c.length > 1 ? int.parse(c.substring(2)) : 0);
  } else {
    num = int.parse(c);
  }
  if (num < 1 || num > 9) return null;
  return suit * 9 + num - 1;
}

const _perms = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

/// Alle Varianten aller Kartenhände (einmal berechnet).
final List<AmConcrete> amConcretes = () {
  final out = <AmConcrete>[];
  final seen = <String>{};
  for (var i = 0; i < amCard.length; i++) {
    final h = amCard[i];
    final usesN = h.specs.any((s) => s.code.startsWith('n'));
    for (final perm in _perms) {
      final suits = {'A': perm[0], 'B': perm[1], 'C': perm[2]};
      for (var n = 1; n <= (usesN ? 9 : 1); n++) {
        final groups = <(int, int)>[];
        var ok = true;
        for (final s in h.specs) {
          final k = _kindOf(s, suits, n);
          if (k == null) {
            ok = false;
            break;
          }
          groups.add((k, s.count));
        }
        if (!ok) continue;
        final key = '$i:${([...groups]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2)).join()}';
        if (seen.add(key)) out.add(AmConcrete(h, i, groups));
      }
    }
  }
  return out;
}();

/// Aufgedeckte Gruppe: Sorte, Anzahl, wie viele Joker darin.
class AmExposure {
  AmExposure(this.kind, this.count, this.jokers, {this.from = -1});
  final int kind;
  final int count;
  int jokers;
  final int from;
  List<int> get tiles => [
        for (var i = 0; i < count - jokers; i++) kind == amFlower ? firstFlower : kind,
        for (var i = 0; i < jokers; i++) jokerKind,
      ];
}

/// Steinsorte für die Karte: alle Blumen und Jahreszeiten sind gleich.
int amKind(int tile) => tile >= firstFlower && tile < firstAnimal ? amFlower : tile;

List<int> amCounts(Iterable<int> tiles) {
  final c = List.filled(amKinds, 0);
  for (final t in tiles) {
    if (t == jokerKind) continue;
    c[amKind(t)]++;
  }
  return c;
}

/// Wie viele Steine fehlen noch zu dieser Kartenhand? -1 heißt unmöglich (passt nicht zu den aufgedeckten Gruppen).
int amDistance(List<int> counts, int jokers, AmConcrete c, List<AmExposure> exposed) {
  if (c.hand.concealed && exposed.isNotEmpty) return -1;
  final groups = [...c.groups];
  for (final e in exposed) {
    final i = groups.indexWhere((g) => g.$1 == e.kind && g.$2 == e.count);
    if (i < 0) return -1;
    groups.removeAt(i);
  }
  final small = List.filled(amKinds, 0);
  final big = List.filled(amKinds, 0);
  for (final (k, n) in groups) {
    if (n >= 3) {
      // Joker nur in Gruppen ab drei Steinen
      big[k] += n;
    } else {
      small[k] += n;
    }
  }
  var missSmall = 0;
  var missBig = 0;
  for (var k = 0; k < amKinds; k++) {
    if (small[k] == 0 && big[k] == 0) continue;
    final r = counts[k];
    missSmall += (small[k] - r).clamp(0, 99);
    final left = (r - small[k]).clamp(0, 99);
    missBig += (big[k] - left).clamp(0, 99);
  }
  return missSmall + (missBig - jokers).clamp(0, 99);
}

/// Steine der Hand, die für diese Kartenhand nicht gebraucht werden (ohne Joker).
List<int> amUseless(List<int> hand, AmConcrete c, List<AmExposure> exposed) {
  final groups = [...c.groups];
  for (final e in exposed) {
    final i = groups.indexWhere((g) => g.$1 == e.kind && g.$2 == e.count);
    if (i >= 0) groups.removeAt(i);
  }
  final need = List.filled(amKinds, 0);
  for (final (k, n) in groups) {
    need[k] += n;
  }
  final out = <int>[];
  for (final t in hand) {
    if (t == jokerKind) continue;
    final k = amKind(t);
    if (need[k] > 0) {
      need[k]--;
    } else {
      out.add(t);
    }
  }
  return out;
}

/// Passende fertige Kartenhand für 14 Steine (Hand plus aufgedeckt), oder null.
AmConcrete? amWinning(List<int> hand, List<AmExposure> exposed) {
  final total = hand.length + exposed.fold(0, (a, e) => a + e.count);
  if (total != 14) return null;
  final counts = amCounts(hand);
  final j = hand.where((t) => t == jokerKind).length;
  AmConcrete? best;
  for (final c in amConcretes) {
    if (amDistance(counts, j, c, exposed) != 0) continue;
    // Paare-Hände ohne Joker
    if (j > 0 && c.groups.every((g) => g.$2 <= 2)) continue;
    if (best == null || c.hand.value > best.hand.value) best = c;
  }
  return best;
}

/// Die nächsten Kartenhände für eine Hand, sortiert nach fehlenden Steinen und Wert.
List<(AmConcrete, int)> amTargets(List<int> hand, List<AmExposure> exposed, {int limit = 5}) {
  final counts = amCounts(hand);
  final j = hand.where((t) => t == jokerKind).length;
  final out = <(AmConcrete, int)>[];
  for (final c in amConcretes) {
    var d = amDistance(counts, j, c, exposed);
    if (d < 0) continue;
    if (j > 0 && c.groups.every((g) => g.$2 <= 2)) d += j;
    out.add((c, d));
  }
  out.sort((a, b) => a.$2 != b.$2 ? a.$2 - b.$2 : b.$1.hand.value - a.$1.hand.value);
  return out.take(limit).toList();
}
