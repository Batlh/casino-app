import 'dart:math';

import 'riichi_hand.dart';
import 'tiles.dart';

/// Riichi-Mahjong für vier Spieler, gespielt wird eine Ostrunde.
/// Spieler 0 sitzt unten, dann rechts (1), oben (2) und links (3). Gezogen wird in dieser Reihenfolge.

class RDiscard {
  RDiscard(this.tile, {this.riichi = false});
  final int tile;
  final bool riichi;

  /// Von jemandem für Pon, Chi oder Kan genommen.
  bool called = false;
}

class RPlayer {
  RPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<int> hand = [];
  List<Meld> melds = [];
  List<RDiscard> discards = [];
  int points = 25000;
  bool riichi = false;
  bool ippatsu = false;

  /// Hat eine Ron-Möglichkeit ausgelassen: bis zum nächsten eigenen Abwurf (in Riichi für immer) kein Ron.
  bool passedRon = false;

  bool get closed => melds.every((m) => !m.open);
  int get meldCount => melds.length;
}

enum RPhase { discard, claim, handOver, gameOver }

enum ClaimType { pass, ron, pon, kan, chi }

class ClaimOption {
  const ClaimOption(this.type, [this.tiles = const []]);
  final ClaimType type;

  /// Für Chi: die zwei eigenen Steine der Folge.
  final List<int> tiles;
}

class HandResult {
  HandResult({
    required this.text,
    required this.changes,
    this.winner,
    this.loser,
    this.score,
    this.winHand = const [],
    this.winMelds = const [],
    this.winTile,
    this.tenpai = const [],
  });

  final String text;
  final List<int> changes;
  final int? winner;
  final int? loser;
  final HandScore? score;
  final List<int> winHand;
  final List<Meld> winMelds;
  final int? winTile;
  final List<int> tenpai;
  bool get draw => winner == null;
}

class RiichiGame {
  RiichiGame({Random? rng, List<String> names = const ['Du', 'Helga', 'Otto', 'Bärbel']})
      : _rng = rng ?? Random.secure(),
        players = [for (var i = 0; i < 4; i++) RPlayer(names[i], human: i == 0)];

  final Random _rng;
  final List<RPlayer> players;
  List<int> wall = [];
  List<int> deadWall = [];
  int doraCount = 1;
  int rinshanUsed = 0;
  int dealer = 0;
  int startDealer = 0;

  /// Wie oft der Geber schon gewechselt hat; nach vier Wechseln ist die Ostrunde vorbei.
  int dealerMoves = 0;
  int honba = 0;
  int riichiSticks = 0;
  RPhase phase = RPhase.discard;
  int current = 0;
  int? drawn;
  bool afterKan = false;
  int? lastDiscard;
  int lastDiscarder = -1;
  Map<int, List<ClaimOption>> claims = {};
  HandResult? result;
  String lastEvent = '';
  int handsPlayed = 0;

  int roundWind = 27;
  int seatWind(int p) => 27 + (p - dealer + 4) % 4;
  int get handNumber => dealerMoves + 1;
  int get wallLeft => wall.length;
  List<int> get doraIndicators => [for (var i = 0; i < doraCount; i++) deadWall[4 + i]];
  List<int> get uraIndicators => [for (var i = 0; i < doraCount; i++) deadWall[9 + i]];
  List<int> get doraTiles => doraIndicators.map(doraFromIndicator).toList();

  void start() {
    startDealer = 0;
    dealer = 0;
    newHand();
  }

  void newHand() {
    final tiles = [for (var t = 0; t < tileKinds; t++) ...[t, t, t, t]]..shuffle(_rng);
    deadWall = tiles.sublist(tiles.length - 14);
    wall = tiles.sublist(0, tiles.length - 14);
    doraCount = 1;
    rinshanUsed = 0;
    for (final p in players) {
      p.hand = [];
      p.melds = [];
      p.discards = [];
      p.riichi = false;
      p.ippatsu = false;
      p.passedRon = false;
    }
    for (var k = 0; k < 13; k++) {
      for (var i = 0; i < 4; i++) {
        players[(dealer + i) % 4].hand.add(wall.removeAt(0));
      }
    }
    for (final p in players) {
      p.hand.sort();
    }
    result = null;
    claims = {};
    lastDiscard = null;
    lastDiscarder = -1;
    afterKan = false;
    current = dealer;
    phase = RPhase.discard;
    lastEvent = '';
    _draw(dealer);
  }

  void _draw(int p, {bool rinshan = false}) {
    int t;
    if (rinshan) {
      t = deadWall[rinshanUsed];
      rinshanUsed++;
      // Der tote Teil bleibt bei 14 Steinen
      if (wall.isNotEmpty) wall.removeLast();
    } else {
      if (wall.isEmpty) {
        _exhaustiveDraw();
        return;
      }
      t = wall.removeAt(0);
    }
    players[p].hand.add(t);
    drawn = t;
    current = p;
    afterKan = rinshan;
    phase = RPhase.discard;
  }

  // ---------- Auswertung ----------

  WinContext _ctx(int p, int tile, {required bool tsumo}) => WinContext(
        winTile: tile,
        tsumo: tsumo,
        seatWind: seatWind(p),
        roundWind: roundWind,
        riichi: players[p].riichi,
        ippatsu: players[p].ippatsu,
        lastTile: wall.isEmpty,
        rinshan: tsumo && afterKan,
        dora: doraTiles,
        uraDora: uraIndicators.map(doraFromIndicator).toList(),
      );

  HandScore? winScore(int p, int tile, {required bool tsumo}) {
    final pl = players[p];
    final closed = tsumo ? pl.hand : [...pl.hand, tile];
    if (shanten(countsOf(closed), pl.meldCount) != -1) return null;
    final s = scoreHand(closed, pl.melds, _ctx(p, tile, tsumo: tsumo));
    return s != null && s.valid ? s : null;
  }

  List<int> waits(int p) {
    final pl = players[p];
    return waitsOf(countsOf(pl.hand), pl.meldCount);
  }

  bool furiten(int p) {
    final pl = players[p];
    if (pl.passedRon) return true;
    final w = waits(p);
    return pl.discards.any((d) => w.contains(d.tile));
  }

  bool canTsumo(int p) => phase == RPhase.discard && current == p && drawn != null && winScore(p, drawn!, tsumo: true) != null;

  /// Steine, nach deren Abwurf die Hand Tenpai ist und Riichi erlaubt wäre.
  List<int> riichiDiscards(int p) {
    final pl = players[p];
    if (phase != RPhase.discard || current != p || pl.riichi || !pl.closed || pl.points < 1000 || wall.length < 4) {
      return [];
    }
    final out = <int>{};
    for (final t in pl.hand.toSet()) {
      final rest = [...pl.hand]..remove(t);
      if (shanten(countsOf(rest), pl.meldCount) == 0) out.add(t);
    }
    return out.toList()..sort();
  }

  /// Mögliche Kans am Zug: verdeckt (vier in der Hand) oder Pon erweitern.
  List<int> kanOptions(int p) {
    final pl = players[p];
    if (phase != RPhase.discard || current != p || pl.riichi || wall.isEmpty || rinshanUsed >= 4) return [];
    final c = countsOf(pl.hand);
    final out = <int>[];
    for (var t = 0; t < tileKinds; t++) {
      if (c[t] == 4) out.add(t);
      if (c[t] >= 1 && pl.melds.any((m) => m.kind == MeldKind.pon && m.first == t)) out.add(t);
    }
    return out;
  }

  /// Darf dieser Stein abgeworfen werden? In Riichi nur der gezogene.
  bool canDiscard(int p, int tile) {
    final pl = players[p];
    if (phase != RPhase.discard || current != p || !pl.hand.contains(tile)) return false;
    if (pl.riichi && drawn != null) return tile == drawn;
    return true;
  }

  // ---------- Aktionen am Zug ----------

  void tsumo(int p) {
    if (!canTsumo(p)) return;
    final s = winScore(p, drawn!, tsumo: true)!;
    _settleWin(p, null, s, drawn!);
  }

  void kan(int p, int t) {
    if (!kanOptions(p).contains(t)) return;
    final pl = players[p];
    final pon = pl.melds.where((m) => m.kind == MeldKind.pon && m.first == t);
    if (pon.isNotEmpty) {
      final m = pon.first;
      pl.melds[pl.melds.indexOf(m)] = Meld(MeldKind.kan, [t, t, t, t], open: true, from: m.from);
      pl.hand.remove(t);
    } else {
      for (var i = 0; i < 4; i++) {
        pl.hand.remove(t);
      }
      pl.melds.add(Meld(MeldKind.kan, [t, t, t, t], open: false));
    }
    _breakIppatsu();
    doraCount = min(5, doraCount + 1);
    lastEvent = '${_who(p)} ${p == 0 ? 'machst' : 'macht'} Kan';
    _draw(p, rinshan: true);
  }

  void discard(int p, int tile, {bool riichi = false}) {
    if (!canDiscard(p, tile)) return;
    final pl = players[p];
    if (riichi && !riichiDiscards(p).contains(tile)) riichi = false;
    pl.hand.remove(tile);
    pl.hand.sort();
    if (pl.riichi) pl.ippatsu = false;
    if (riichi) {
      pl.riichi = true;
      pl.ippatsu = true;
      pl.points -= 1000;
      riichiSticks++;
      lastEvent = '${_who(p)} ${p == 0 ? 'sagst' : 'sagt'} Riichi!';
    } else {
      lastEvent = '';
    }
    if (!pl.riichi) pl.passedRon = false;
    pl.discards.add(RDiscard(tile, riichi: riichi));
    drawn = null;
    afterKan = false;
    lastDiscard = tile;
    lastDiscarder = p;
    _openClaims();
  }

  String _who(int p) => p == 0 ? 'Du' : players[p].name;

  void _breakIppatsu() {
    for (final pl in players) {
      pl.ippatsu = false;
    }
  }

  // ---------- Ansagen auf einen Abwurf ----------

  void _openClaims() {
    claims = {};
    final t = lastDiscard!;
    final from = lastDiscarder;
    for (var k = 1; k <= 3; k++) {
      final q = (from + k) % 4;
      final pl = players[q];
      final opts = <ClaimOption>[];
      if (!furiten(q) && winScore(q, t, tsumo: false) != null) opts.add(const ClaimOption(ClaimType.ron));
      if (!pl.riichi && wall.isNotEmpty) {
        final c = pl.hand.where((x) => x == t).length;
        if (c >= 2) opts.add(ClaimOption(ClaimType.pon, [t, t]));
        if (c >= 3 && rinshanUsed < 4) opts.add(ClaimOption(ClaimType.kan, [t, t, t]));
        if (k == 1 && t < 27) {
          final n = t % 9;
          bool has(int x) => pl.hand.contains(x);
          if (n >= 2 && has(t - 2) && has(t - 1)) opts.add(ClaimOption(ClaimType.chi, [t - 2, t - 1]));
          if (n >= 1 && n <= 7 && has(t - 1) && has(t + 1)) opts.add(ClaimOption(ClaimType.chi, [t - 1, t + 1]));
          if (n <= 6 && has(t + 1) && has(t + 2)) opts.add(ClaimOption(ClaimType.chi, [t + 1, t + 2]));
        }
      }
      if (opts.isNotEmpty) claims[q] = opts;
    }
    if (claims.isEmpty) {
      _nextTurn();
    } else {
      phase = RPhase.claim;
    }
  }

  void _nextTurn() {
    claims = {};
    _draw((lastDiscarder + 1) % 4);
  }

  /// Wertet alle Antworten aus. Fehlende Spieler gelten als „passen“.
  void resolveClaims(Map<int, ClaimOption> choices) {
    if (phase != RPhase.claim) return;
    final t = lastDiscard!;
    final from = lastDiscarder;
    // Wer Ron hätte machen können und passt, ist bis zum nächsten Abwurf gesperrt
    for (final e in claims.entries) {
      final hadRon = e.value.any((o) => o.type == ClaimType.ron);
      if (hadRon && choices[e.key]?.type != ClaimType.ron) players[e.key].passedRon = true;
    }
    for (var k = 1; k <= 3; k++) {
      final q = (from + k) % 4;
      if (choices[q]?.type == ClaimType.ron) {
        final s = winScore(q, t, tsumo: false);
        if (s != null) {
          players[q].hand.add(t);
          players[from].discards.last.called = true;
          _settleWin(q, from, s, t);
          return;
        }
      }
    }
    for (var k = 1; k <= 3; k++) {
      final q = (from + k) % 4;
      final c = choices[q];
      if (c == null || (c.type != ClaimType.pon && c.type != ClaimType.kan)) continue;
      _takeMeld(q, from, t, c);
      return;
    }
    final next = (from + 1) % 4;
    final c = choices[next];
    if (c != null && c.type == ClaimType.chi) {
      _takeMeld(next, from, t, c);
      return;
    }
    _nextTurn();
  }

  void _takeMeld(int q, int from, int t, ClaimOption c) {
    final pl = players[q];
    for (final x in c.tiles) {
      pl.hand.remove(x);
    }
    players[from].discards.last.called = true;
    _breakIppatsu();
    claims = {};
    final kind = switch (c.type) {
      ClaimType.chi => MeldKind.chi,
      ClaimType.kan => MeldKind.kan,
      _ => MeldKind.pon,
    };
    pl.melds.add(Meld(kind, ([...c.tiles, t]..sort()), from: from));
    final name = switch (kind) {
      MeldKind.chi => 'Chi',
      MeldKind.pon => 'Pon',
      MeldKind.kan => 'Kan',
    };
    lastEvent = '${_who(q)} ${q == 0 ? 'rufst' : 'ruft'} $name';
    if (kind == MeldKind.kan) {
      doraCount = min(5, doraCount + 1);
      _draw(q, rinshan: true);
    } else {
      current = q;
      drawn = null;
      phase = RPhase.discard;
    }
  }

  // ---------- Abrechnung ----------

  void _settleWin(int winner, int? loser, HandScore s, int tile) {
    final changes = List.filled(4, 0);
    final base = s.basePoints;
    final dealerWins = winner == dealer;
    if (loser != null) {
      final pay = roundUp100(base * (dealerWins ? 6 : 4)) + honba * 300;
      changes[loser] -= pay;
      changes[winner] += pay;
    } else {
      for (var p = 0; p < 4; p++) {
        if (p == winner) continue;
        final pay = (dealerWins || p == dealer ? roundUp100(base * 2) : roundUp100(base)) + honba * 100;
        changes[p] -= pay;
        changes[winner] += pay;
      }
    }
    changes[winner] += riichiSticks * 1000;
    riichiSticks = 0;
    for (var p = 0; p < 4; p++) {
      players[p].points += changes[p];
    }
    final how = loser == null ? 'Tsumo' : 'Ron';
    final who = winner == 0 ? 'Du gewinnst' : '${players[winner].name} gewinnt';
    final from = loser == null ? '' : (loser == 0 ? ' mit deinem Abwurf' : ' mit dem Abwurf von ${players[loser].name}');
    result = HandResult(
      text: '$who mit $how$from',
      changes: changes,
      winner: winner,
      loser: loser,
      score: s,
      winHand: [...players[winner].hand]..sort(),
      winMelds: players[winner].melds,
      winTile: tile,
    );
    phase = RPhase.handOver;
    claims = {};
    handsPlayed++;
    _advanceDealer(dealerKeeps: dealerWins);
  }

  void _exhaustiveDraw() {
    final tenpai = [for (var p = 0; p < 4; p++) if (shanten(countsOf(players[p].hand), players[p].meldCount) == 0) p];
    final changes = List.filled(4, 0);
    if (tenpai.isNotEmpty && tenpai.length < 4) {
      final gain = 3000 ~/ tenpai.length;
      final loss = 3000 ~/ (4 - tenpai.length);
      for (var p = 0; p < 4; p++) {
        changes[p] = tenpai.contains(p) ? gain : -loss;
        players[p].points += changes[p];
      }
    }
    final names = [for (final p in tenpai) p == 0 ? 'du' : players[p].name];
    result = HandResult(
      text: tenpai.isEmpty
          ? 'Die Mauer ist leer. Niemand ist Tenpai'
          : 'Die Mauer ist leer. Tenpai: ${names.join(', ')}',
      changes: changes,
      tenpai: tenpai,
    );
    phase = RPhase.handOver;
    claims = {};
    drawn = null;
    handsPlayed++;
    honba++;
    _advanceDealer(dealerKeeps: tenpai.contains(dealer), countHonba: false);
  }

  bool _gameEnds = false;

  void _advanceDealer({required bool dealerKeeps, bool countHonba = true}) {
    if (dealerKeeps) {
      if (countHonba) honba++;
    } else {
      if (countHonba) honba = 0;
      dealerMoves++;
      dealer = (dealer + 1) % 4;
    }
    _gameEnds = dealerMoves >= 4 || players.any((p) => p.points < 0);
  }

  /// Nach der Abrechnung: nächste Hand oder Spielende.
  void nextHand() {
    if (phase != RPhase.handOver) return;
    if (_gameEnds) {
      // Übrige Riichi-Stöcke gehen an den Ersten
      final order = ranking();
      players[order.first].points += riichiSticks * 1000;
      riichiSticks = 0;
      phase = RPhase.gameOver;
      return;
    }
    newHand();
  }

  bool get gameWillEnd => _gameEnds;

  /// Spieler nach Punkten, bei Gleichstand nach Sitzreihenfolge ab dem ersten Geber.
  List<int> ranking() {
    final order = [0, 1, 2, 3];
    order.sort((a, b) {
      final d = players[b].points - players[a].points;
      if (d != 0) return d;
      return (a - startDealer + 4) % 4 - (b - startDealer + 4) % 4;
    });
    return order;
  }

  /// Alle sichtbaren Steine aus Sicht von Spieler p, für die Computer.
  List<int> visibleCounts(int p) {
    final c = List.filled(tileKinds, 0);
    for (final pl in players) {
      for (final d in pl.discards) {
        c[d.tile]++;
      }
      for (final m in pl.melds) {
        for (final t in m.tiles) {
          c[t]++;
        }
      }
    }
    for (final t in players[p].hand) {
      c[t]++;
    }
    for (final t in doraIndicators) {
      c[t]++;
    }
    return c;
  }
}
