import 'dart:math';

/// Hausregeln, jede einzeln schaltbar (Standard: alle an).
class MadnRules {
  const MadnRules({
    this.threeTries = true,
    this.sixAgain = true,
    this.mustLeaveStart = true,
    this.captureForced = true,
  });

  /// Ohne Figur auf der Laufbahn darf man dreimal würfeln, um eine 6 zu bekommen.
  final bool threeTries;

  /// Nach einer 6 nochmal würfeln.
  final bool sixAgain;

  /// Bei einer 6 muss eine Figur heraus, das eigene Startfeld muss frei gemacht werden.
  final bool mustLeaveStart;

  /// Wer schlagen kann, muss schlagen.
  final bool captureForced;

  MadnRules copyWith({bool? threeTries, bool? sixAgain, bool? mustLeaveStart, bool? captureForced}) => MadnRules(
        threeTries: threeTries ?? this.threeTries,
        sixAgain: sixAgain ?? this.sixAgain,
        mustLeaveStart: mustLeaveStart ?? this.mustLeaveStart,
        captureForced: captureForced ?? this.captureForced,
      );

  Map<String, bool> toJson() => {'t': threeTries, 's': sixAgain, 'l': mustLeaveStart, 'c': captureForced};

  static MadnRules fromJson(Map<String, dynamic>? j) => j == null
      ? const MadnRules()
      : MadnRules(
          threeTries: j['t'] as bool? ?? true,
          sixAgain: j['s'] as bool? ?? true,
          mustLeaveStart: j['l'] as bool? ?? true,
          captureForced: j['c'] as bool? ?? true,
        );
}

enum MadnPhase { roll, move, over }

class MadnMove {
  const MadnMove(this.piece, this.from, this.to, {this.captured});
  final int piece;
  final int from;
  final int to;

  /// Geschlagene Figur (Platz, Figur).
  final (int, int)? captured;
}

/// Mensch ärgere dich nicht. Jede Figur hat einen Fortschritt: -1 im Haus, 0 bis 39 auf der Laufbahn
/// (0 ist das eigene Startfeld), 40 bis 43 im Ziel. Platz i spielt Farbe i und startet auf Feld 10·i.
class MadnGame {
  MadnGame(this.players, {this.rules = const MadnRules(), Random? rng})
      : _rng = rng ?? Random(),
        pieces = List.generate(players, (_) => List.filled(4, -1));

  MadnGame._(this.players, this.pieces, this.rules, this._rng);

  static const track = 40;
  static const goalStart = 40;

  final int players;
  final List<List<int>> pieces;
  MadnRules rules;
  final Random _rng;

  int current = 0;
  int? dice;
  int tries = 0;
  MadnPhase phase = MadnPhase.roll;
  int? winner;
  List<int> movable = const [];

  int absolute(int seat, int progress) => (seat * 10 + progress) % track;

  /// Wer steht auf dem Laufbahnfeld [abs]?
  (int, int)? occupant(int abs) {
    for (var s = 0; s < players; s++) {
      for (var k = 0; k < 4; k++) {
        final p = pieces[s][k];
        if (p >= 0 && p < track && absolute(s, p) == abs) return (s, k);
      }
    }
    return null;
  }

  bool get _onTrack => pieces[current].any((p) => p >= 0 && p < track);

  /// Ziel des Zugs von Figur [k] mit [d] Augen, null wenn nicht möglich.
  int? target(int k, int d) {
    final mine = pieces[current];
    final p = mine[k];
    if (p < 0) {
      if (d != 6) return null;
      final occ = occupant(absolute(current, 0));
      if (occ != null && occ.$1 == current) return null;
      return 0;
    }
    final t = p + d;
    if (t > goalStart + 3) return null;
    if (t >= goalStart) {
      // Im Ziel nicht über eigene Figuren springen
      for (var g = max(p + 1, goalStart); g <= t; g++) {
        if (mine.contains(g)) return null;
      }
      return t;
    }
    final occ = occupant(absolute(current, t));
    if (occ != null && occ.$1 == current) return null;
    return t;
  }

  bool _captures(int k, int t) {
    if (t >= track) return false;
    final occ = occupant(absolute(current, t));
    return occ != null && occ.$1 != current;
  }

  List<int> legalMoves() {
    final d = dice;
    if (d == null) return const [];
    var ms = [for (var k = 0; k < 4; k++) if (target(k, d) != null) k];
    if (ms.isEmpty) return ms;
    final mine = pieces[current];
    final home = mine.any((p) => p < 0);
    if (rules.mustLeaveStart && home) {
      // Eigenes Startfeld zuerst räumen
      final onStart = [for (var k = 0; k < 4; k++) if (mine[k] == 0) k];
      final clear = ms.where(onStart.contains).toList();
      if (onStart.isNotEmpty && clear.isNotEmpty) {
        ms = clear;
      } else if (d == 6) {
        final enter = ms.where((k) => mine[k] < 0).toList();
        if (enter.isNotEmpty) ms = enter;
      }
    }
    if (rules.captureForced) {
      final cap = ms.where((k) => _captures(k, target(k, d)!)).toList();
      if (cap.isNotEmpty) ms = cap;
    }
    return ms;
  }

  /// Würfeln. Ohne möglichen Zug geht es je nach Regel nochmal oder zum Nächsten.
  int roll([int? fixed]) {
    if (phase != MadnPhase.roll) throw StateError('Jetzt wird nicht gewürfelt');
    final d = fixed ?? 1 + _rng.nextInt(6);
    dice = d;
    movable = legalMoves();
    if (movable.isNotEmpty) {
      phase = MadnPhase.move;
      return d;
    }
    if (rules.threeTries && !_onTrack && d != 6) {
      tries++;
      if (tries < 3) return d;
    }
    if (d == 6 && rules.sixAgain) {
      tries = 0;
      return d;
    }
    _next();
    return d;
  }

  /// Wie viele Würfe bleiben noch (drei Versuche)?
  int get triesLeft => rules.threeTries && !_onTrack ? 3 - tries : 1;

  MadnMove move(int k) {
    if (phase != MadnPhase.move || !movable.contains(k)) throw StateError('Zug nicht erlaubt');
    final d = dice!;
    final from = pieces[current][k];
    final to = target(k, d)!;
    (int, int)? captured;
    if (to < track) {
      final occ = occupant(absolute(current, to));
      if (occ != null && occ.$1 != current) {
        pieces[occ.$1][occ.$2] = -1;
        captured = occ;
      }
    }
    pieces[current][k] = to;
    final m = MadnMove(k, from, to, captured: captured);
    movable = const [];
    if (pieces[current].every((p) => p >= goalStart)) {
      winner = current;
      phase = MadnPhase.over;
      return m;
    }
    if (d == 6 && rules.sixAgain) {
      phase = MadnPhase.roll;
      tries = 0;
    } else {
      _next();
    }
    return m;
  }

  void _next() {
    current = (current + 1) % players;
    tries = 0;
    phase = MadnPhase.roll;
  }

  /// Einfache Computerwahl: schlagen, herauskommen, ins Ziel, Gefahr meiden, sonst die vorderste Figur.
  int botChoice() {
    final d = dice!;
    var best = movable.first;
    var bestScore = -1 << 30;
    for (final k in movable) {
      final from = pieces[current][k];
      final to = target(k, d)!;
      var s = 0;
      if (_captures(k, to)) s += 100;
      if (from < 0) s += 60;
      if (to >= goalStart && from < goalStart) s += 50;
      if (from >= 0 && from < track && _threat(from)) s += 30;
      if (to < track && _threat(to)) s -= 40;
      if (from == 0) s += 20;
      s += to;
      if (s > bestScore) {
        bestScore = s;
        best = k;
      }
    }
    return best;
  }

  /// Steht ein Gegner bis zu sechs Felder hinter Fortschritt [p]?
  bool _threat(int p) {
    final abs = absolute(current, p);
    for (var back = 1; back <= 6; back++) {
      final occ = occupant((abs - back + track) % track);
      if (occ != null && occ.$1 != current) return true;
    }
    return false;
  }

  Map<String, Object?> toJson() => {
        'players': players,
        'pieces': pieces,
        'rules': rules.toJson(),
        'current': current,
        'dice': dice,
        'tries': tries,
        'phase': phase.index,
        'winner': winner,
      };

  static MadnGame fromJson(Map<String, dynamic> j, {Random? rng}) {
    final g = MadnGame._(
      j['players'] as int,
      [for (final l in j['pieces'] as List) [for (final v in l as List) v as int]],
      MadnRules.fromJson(j['rules'] as Map<String, dynamic>?),
      rng ?? Random(),
    )
      ..current = j['current'] as int
      ..dice = j['dice'] as int?
      ..tries = j['tries'] as int
      ..phase = MadnPhase.values[j['phase'] as int]
      ..winner = j['winner'] as int?;
    if (g.phase == MadnPhase.move) g.movable = g.legalMoves();
    return g;
  }
}

/// Brett 11×11: Laufbahn ab dem Startfeld von Rot (links), Häuser in den Ecken, Ziele zur Mitte.
const madnTrack = <(int, int)>[
  (0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (4, 3), (4, 2), (4, 1), (4, 0), (5, 0), //
  (6, 0), (6, 1), (6, 2), (6, 3), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (10, 5),
  (10, 6), (9, 6), (8, 6), (7, 6), (6, 6), (6, 7), (6, 8), (6, 9), (6, 10), (5, 10),
  (4, 10), (4, 9), (4, 8), (4, 7), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6), (0, 5),
];

const madnHomes = <List<(int, int)>>[
  [(0, 0), (1, 0), (0, 1), (1, 1)],
  [(9, 0), (10, 0), (9, 1), (10, 1)],
  [(9, 9), (10, 9), (9, 10), (10, 10)],
  [(0, 9), (1, 9), (0, 10), (1, 10)],
];

const madnGoals = <List<(int, int)>>[
  [(1, 5), (2, 5), (3, 5), (4, 5)],
  [(5, 1), (5, 2), (5, 3), (5, 4)],
  [(9, 5), (8, 5), (7, 5), (6, 5)],
  [(5, 9), (5, 8), (5, 7), (5, 6)],
];

/// Feld einer Figur auf dem 11×11-Brett.
(int, int) madnCell(MadnGame g, int seat, int piece) {
  final p = g.pieces[seat][piece];
  if (p < 0) return madnHomes[seat][piece];
  if (p >= MadnGame.goalStart) return madnGoals[seat][p - MadnGame.goalStart];
  return madnTrack[g.absolute(seat, p)];
}
