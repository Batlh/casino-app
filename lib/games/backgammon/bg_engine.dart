import 'dart:math';

/// Backgammon für zwei. Jeder Spieler zählt aus seiner Sicht: Punkt 23 ist am weitesten weg, 0 ist
/// der letzte Punkt im Heimfeld (0 bis 5). [bar] ist 24, abgetragen (vom Brett) ist -1.
/// Weiß (0) und Schwarz (1) sehen das Brett gespiegelt: relativer Punkt i ist absolut i bzw. 23 - i.
const bgBar = 24;
const bgOff = -1;

class BgStep {
  const BgStep(this.from, this.to, this.die, {this.hit = false});
  final int from;
  final int to;
  final int die;
  final bool hit;

  List<int> toJson() => [from, to, die, hit ? 1 : 0];
  static BgStep fromJson(List<dynamic> j) => BgStep(j[0] as int, j[1] as int, j[2] as int, hit: j[3] == 1);

  bool same(BgStep o) => from == o.from && to == o.to && die == o.die;

  @override
  String toString() => '${from == bgBar ? 'Bar' : from + 1}/${to == bgOff ? 'ab' : to + 1}${hit ? '*' : ''}';
}

class BgGame {
  BgGame({Random? rng}) : _rng = rng ?? Random() {
    for (final p in [0, 1]) {
      counts[p][23] = 2;
      counts[p][12] = 5;
      counts[p][7] = 3;
      counts[p][5] = 5;
    }
  }

  BgGame._(this._rng);

  final Random _rng;
  final List<List<int>> counts = [List.filled(24, 0), List.filled(24, 0)];
  final List<int> bar = [0, 0];
  final List<int> off = [0, 0];
  int current = 0;

  /// Würfel dieses Zugs (leer vor dem Würfeln) und die noch offenen Augen.
  List<int> dice = const [];
  List<int> remaining = [];
  int? winner;

  /// 1 einfach, 2 Gammon, 3 Backgammon.
  int winKind = 1;

  bool get over => winner != null;
  bool get rolled => dice.isNotEmpty;

  BgGame copy() {
    final g = BgGame._(_rng)
      ..current = current
      ..dice = List.of(dice)
      ..remaining = List.of(remaining)
      ..winner = winner
      ..winKind = winKind;
    for (final p in [0, 1]) {
      g.counts[p].setAll(0, counts[p]);
      g.bar[p] = bar[p];
      g.off[p] = off[p];
    }
    return g;
  }

  /// Gegnerische Steine auf dem relativen Punkt [i] von Spieler [p].
  int opp(int p, int i) => counts[1 - p][23 - i];

  bool allHome(int p) {
    if (bar[p] > 0) return false;
    for (var i = 6; i < 24; i++) {
      if (counts[p][i] > 0) return false;
    }
    return true;
  }

  int pips(int p) {
    var s = bar[p] * 25;
    for (var i = 0; i < 24; i++) {
      s += counts[p][i] * (i + 1);
    }
    return s;
  }

  /// Wer beginnt, wird ausgewürfelt; der Startwurf ist gleich der erste Zug.
  void start() {
    int a;
    int b;
    do {
      a = 1 + _rng.nextInt(6);
      b = 1 + _rng.nextInt(6);
    } while (a == b);
    current = a > b ? 0 : 1;
    _setDice(a, b);
  }

  void roll([int? a, int? b]) {
    if (rolled || over) throw StateError('schon gewürfelt');
    _setDice(a ?? 1 + _rng.nextInt(6), b ?? 1 + _rng.nextInt(6));
  }

  void _setDice(int a, int b) {
    dice = [a, b];
    remaining = a == b ? [a, a, a, a] : [a, b];
  }

  BgStep? stepFor(int from, int die) {
    final p = current;
    if (bar[p] > 0 && from != bgBar) return null;
    if (from == bgBar) {
      if (bar[p] == 0) return null;
    } else if (counts[p][from] == 0) {
      return null;
    }
    final start = from == bgBar ? 24 : from;
    final to = start - die;
    if (to < 0) {
      if (!allHome(p)) return null;
      if (to < -1) {
        // Mit höherem Wurf nur vom höchsten besetzten Punkt
        for (var i = from + 1; i < 6; i++) {
          if (counts[p][i] > 0) return null;
        }
      }
      return BgStep(from, bgOff, die);
    }
    final o = opp(p, to);
    if (o >= 2) return null;
    return BgStep(from, to, die, hit: o == 1);
  }

  void apply(BgStep s) {
    final p = current;
    if (s.from == bgBar) {
      bar[p]--;
    } else {
      counts[p][s.from]--;
    }
    if (s.to == bgOff) {
      off[p]++;
    } else {
      if (s.hit) {
        counts[1 - p][23 - s.to]--;
        bar[1 - p]++;
      }
      counts[p][s.to]++;
    }
    remaining.remove(s.die);
    if (off[p] == 15) {
      winner = p;
      final o = 1 - p;
      if (off[o] > 0) {
        winKind = 1;
      } else {
        // Backgammon: Gegner hat noch Steine auf der Bar oder in meinem Heimfeld
        var deep = bar[o] > 0;
        for (var i = 18; i < 24; i++) {
          if (counts[o][i] > 0) deep = true;
        }
        winKind = deep ? 3 : 2;
      }
    }
  }

  /// Alle erlaubten Zugfolgen mit den offenen Würfeln (so viele Augen wie möglich, sonst den höheren).
  List<List<BgStep>> sequences() {
    final out = <List<BgStep>>[];
    var best = 0;
    void dfs(BgGame g, List<BgStep> seq) {
      var any = false;
      if (!g.over) {
        final tried = <int>{};
        for (final d in g.remaining) {
          if (!tried.add(d)) continue;
          for (final from in [bgBar, for (var i = 23; i >= 0; i--) i]) {
            final s = g.stepFor(from, d);
            if (s == null) continue;
            any = true;
            final c = g.copy()..apply(s);
            dfs(c, [...seq, s]);
          }
        }
      }
      if (!any && seq.isNotEmpty) {
        if (seq.length > best) {
          best = seq.length;
          out.clear();
        }
        if (seq.length == best) out.add(seq);
      }
    }

    dfs(this, []);
    if (best == 1 && remaining.length == 2 && remaining[0] != remaining[1]) {
      final high = max(remaining[0], remaining[1]);
      final withHigh = out.where((s) => s.first.die == high).toList();
      if (withHigh.isNotEmpty) return withHigh;
    }
    return out;
  }

  /// Zug beenden: der Nächste würfelt.
  void endTurn() {
    current = 1 - current;
    dice = const [];
    remaining = [];
  }

  Map<String, Object?> toJson() => {
        'counts': counts,
        'bar': bar,
        'off': off,
        'current': current,
        'dice': dice,
        'remaining': remaining,
        'winner': winner,
        'kind': winKind,
      };

  static BgGame fromJson(Map<String, dynamic> j, {Random? rng}) {
    List<int> ints(Object? v) => [for (final x in v as List) x as int];
    final g = BgGame._(rng ?? Random())
      ..current = j['current'] as int
      ..dice = ints(j['dice'])
      ..remaining = ints(j['remaining'])
      ..winner = j['winner'] as int?
      ..winKind = j['kind'] as int;
    final c = j['counts'] as List;
    for (final p in [0, 1]) {
      g.counts[p].setAll(0, ints(c[p]));
      g.bar[p] = ints(j['bar'])[p];
      g.off[p] = ints(j['off'])[p];
    }
    return g;
  }
}

/// Bewertung aus Sicht von [p] (größer ist besser).
double bgEval(BgGame g, int p) {
  if (g.winner != null) return g.winner == p ? 10000.0 * g.winKind : -10000.0 * g.winKind;
  final o = 1 - p;
  var s = (g.pips(o) - g.pips(p)).toDouble();
  s += 6.0 * (g.off[p] - g.off[o]);
  s += 8.0 * g.bar[o] - 8.0 * g.bar[p];
  // Gegnerische Steine in meiner Zählung: Sein Punkt j ist mein 23 - j, seine Bar wirkt wie -1.
  // Er läuft in meiner Zählung aufwärts.
  final oppPos = <int>[
    for (var j = 0; j < 24; j++)
      if (g.counts[o][j] > 0) 23 - j,
    if (g.bar[o] > 0) -1,
  ];
  final contact = oppPos.isNotEmpty && oppPos.reduce(min) < _maxPoint(g, p);
  for (var i = 0; i < 24; i++) {
    final c = g.counts[p][i];
    if (c >= 2) {
      // Gebaute Punkte, im Heimfeld und davor besonders wertvoll
      s += i < 6 ? 5 : (i < 8 ? 4 : 2);
    } else if (c == 1 && contact) {
      // Ungeschützter Stein: wie viele gegnerische Steine stehen 1 bis 12 Punkte dahinter?
      var shots = 0;
      for (final q in oppPos) {
        final dist = i - q;
        if (dist > 0 && dist <= 12) shots += dist <= 6 ? 2 : 1;
      }
      s -= 2.5 * shots + (i < 12 ? 1 : 0);
    }
  }
  return s;
}

int _maxPoint(BgGame g, int p) {
  if (g.bar[p] > 0) return 24;
  for (var i = 23; i >= 0; i--) {
    if (g.counts[p][i] > 0) return i;
  }
  return -1;
}

/// Computerzug: die Folge mit der besten Bewertung; leicht würfelt etwas Zufall dazu.
List<BgStep> bgBotSequence(BgGame g, int level, Random rng) {
  final seqs = g.sequences();
  if (seqs.isEmpty) return const [];
  if (level == 0 && rng.nextDouble() < 0.35) return seqs[rng.nextInt(seqs.length)];
  final me = g.current;
  var best = seqs.first;
  var bestV = double.negativeInfinity;
  for (final s in seqs) {
    final c = g.copy();
    for (final st in s) {
      c.apply(st);
    }
    final v = bgEval(c, me) + (level == 0 ? rng.nextDouble() * 6 : 0);
    if (v > bestV) {
      bestV = v;
      best = s;
    }
  }
  return best;
}
