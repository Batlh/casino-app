import 'dart:math';

/// Memory: Paare aufdecken. Wer ein Paar findet, behält es und ist nochmal dran.
class MemoryGame {
  MemoryGame(int pairs, this.players, {Random? rng})
      : _rng = rng ?? Random(),
        cards = [for (var i = 0; i < pairs; i++) ...[i, i]],
        scores = List.filled(players, 0),
        turns = List.filled(players, 0) {
    cards.shuffle(_rng);
    owner = List.filled(cards.length, -1);
  }

  MemoryGame._(this.players, this.cards, this.owner, this.scores, this.turns, this._rng);

  final int players;
  final Random _rng;
  final List<int> cards;
  late final List<int> owner;
  final List<int> scores;

  /// Züge (zwei Karten aufdecken) je Spieler.
  final List<int> turns;

  /// Offen liegende Karten im laufenden Zug.
  final List<int> open = [];

  /// Was die Computer gesehen haben: Karte → Motiv. Jeder Computer vergisst manches (siehe [botRemember]).
  final Map<int, Map<int, int>> botMemory = {};
  int current = 0;

  int get pairs => cards.length ~/ 2;
  bool get over => owner.every((o) => o >= 0);
  bool get waiting => open.length == 2;

  bool canFlip(int i) => i >= 0 && i < cards.length && owner[i] < 0 && !open.contains(i) && open.length < 2;

  /// Deckt eine Karte auf. [botRemember] ist die Chance, mit der sich die Computer die Karte merken.
  bool flip(int i, {double botRemember = 0.8, Iterable<int> bots = const []}) {
    if (!canFlip(i)) return false;
    open.add(i);
    for (final b in bots) {
      if (_rng.nextDouble() < botRemember) (botMemory[b] ??= {})[i] = cards[i];
    }
    return true;
  }

  /// Nach zwei offenen Karten: Paar wegnehmen (gleicher Spieler bleibt dran) oder umdrehen und weitergeben.
  bool resolve() {
    if (!waiting) return false;
    final a = open[0];
    final b = open[1];
    turns[current]++;
    open.clear();
    final match = cards[a] == cards[b];
    if (match) {
      owner[a] = current;
      owner[b] = current;
      scores[current]++;
      for (final m in botMemory.values) {
        m
          ..remove(a)
          ..remove(b);
      }
    } else {
      current = (current + 1) % players;
    }
    return match;
  }

  /// Nächste Karte für Computer [p].
  int botPick(int p) {
    final mem = {
      for (final e in (botMemory[p] ?? const <int, int>{}).entries)
        if (owner[e.key] < 0 && !open.contains(e.key)) e.key: e.value,
    };
    final hidden = [for (var i = 0; i < cards.length; i++) if (canFlip(i)) i];
    if (open.isEmpty) {
      // Bekanntes Paar zuerst
      final byValue = <int, List<int>>{};
      for (final e in mem.entries) {
        (byValue[e.value] ??= []).add(e.key);
      }
      for (final l in byValue.values) {
        if (l.length >= 2) return l.first;
      }
      final unknown = hidden.where((i) => !mem.containsKey(i)).toList();
      return (unknown.isNotEmpty ? unknown : hidden)[_rng.nextInt((unknown.isNotEmpty ? unknown : hidden).length)];
    }
    final want = cards[open.first];
    for (final e in mem.entries) {
      if (e.value == want && e.key != open.first) return e.key;
    }
    final unknown = hidden.where((i) => !mem.containsKey(i)).toList();
    final pool = unknown.isNotEmpty ? unknown : hidden;
    return pool[_rng.nextInt(pool.length)];
  }

  Map<String, Object?> toJson() => {
        'players': players,
        'cards': cards,
        'owner': owner,
        'scores': scores,
        'turns': turns,
        'current': current,
      };

  static MemoryGame fromJson(Map<String, dynamic> j, {Random? rng}) {
    List<int> ints(Object? v) => [for (final x in v as List) x as int];
    return MemoryGame._(j['players'] as int, ints(j['cards']), ints(j['owner']), ints(j['scores']), ints(j['turns']),
        rng ?? Random())
      ..current = j['current'] as int;
  }
}
