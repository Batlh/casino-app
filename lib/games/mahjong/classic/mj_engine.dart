import '../../../core/action_log.dart';
import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_hand.dart';
import 'mj_rules.dart';
import 'mj_shape.dart';

/// Mahjong für die chinesischen und asiatischen Regeln. Spieler 0 sitzt unten, gezogen wird reihum.

class MjDiscard {
  MjDiscard(this.tile);
  final int tile;
  bool called = false;
}

class MjPlayer {
  MjPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<int> hand = [];
  List<Meld> melds = [];
  List<MjDiscard> discards = [];
  List<int> bonus = [];
  int points = 0;

  /// Sichuan: die gestrichene Farbe 0 bis 2.
  int? voidSuit;

  /// Blutkampf: hat gewonnen und spielt nicht mehr mit.
  bool out = false;

  /// Blutfluss: hat gewonnen, die Hand bleibt fest und wartet weiter.
  bool locked = false;

  /// Gewinnsteine dieser Hand (Blutfluss kann mehrmals gewinnen).
  List<int> wonTiles = [];

  /// Wie viele davon nur geteilt waren: mehrere gewinnen auf denselben Abwurf.
  int sharedWins = 0;

  /// Gewählte Steine zum Tauschen.
  List<int> exchange = [];

  int get meldCount => melds.length;
  bool get concealed => melds.every((m) => !m.open);
  bool hasVoid() => voidSuit != null && hand.any((t) => t < 27 && suitOf(t) == voidSuit);
}

enum MjPhase { exchange, voidChoice, discard, claim, handOver, gameOver }

enum MjClaimType { pass, win, pon, kan, chi }

class MjOption {
  const MjOption(this.type, [this.tiles = const []]);
  final MjClaimType type;

  /// Für Chi: die zwei eigenen Steine der Folge.
  final List<int> tiles;
}

class MjWin {
  MjWin({
    required this.winner,
    required this.loser,
    required this.score,
    required this.tile,
    required this.hand,
    required this.melds,
    required this.changes,
  });
  final int winner;
  final int? loser;
  final MjScore score;
  final int tile;
  final List<int> hand;
  final List<Meld> melds;
  final List<int> changes;
}

class MjHandResult {
  MjHandResult({required this.text, required this.changes, required this.wins, this.notes = const []});
  final String text;
  final List<int> changes;
  final List<MjWin> wins;

  /// Weitere Abrechnungen am Ende (Blumenschwein, nicht fertig, Kans).
  final List<String> notes;
  bool get draw => wins.isEmpty;
}

class MjGame with ActionLog {
  /// [humans]: Plätze, an denen Menschen sitzen (allein nur 0). [me]: dein Platz, für die Texte („Du“).
  MjGame(this.rules, {Random? rng, List<String>? names, Set<int> humans = const {0}, this.me = 0})
      : _rng = rng ?? Random.secure(),
        players = [
          for (var i = 0; i < rules.players; i++)
            MjPlayer((names ?? const ['Du', 'Mei', 'Jun', 'Lan'])[i], human: humans.contains(i)),
        ];

  /// Dein Platz (im Netz je Gerät verschieden).
  final int me;

  final MjRules rules;
  final Random _rng;
  final List<MjPlayer> players;
  int get n => players.length;

  List<int> wall = [];
  int dealer = 0;
  int dealerMoves = 0;
  int handsPlayed = 0;
  MjPhase phase = MjPhase.discard;
  int current = 0;
  int? drawn;
  bool afterKan = false;
  bool _discardAfterKan = false;
  int? lastDiscard;
  int lastDiscarder = -1;
  Map<int, List<MjOption>> claims = {};

  /// Läuft gerade eine Kan-Erweiterung, die geraubt werden kann?
  int? robbingTile;
  int _robbingPlayer = -1;
  int callsMade = 0;
  int discardsMade = 0;

  /// Sichuan: Richtung beim Tauschen (1 nach rechts, -1 nach links, 2 gegenüber).
  int exchangeDir = 1;
  List<int> handChanges = [];
  final List<MjWin> handWins = [];
  final List<String> handNotes = [];
  MjHandResult? result;
  String lastEvent = '';

  int seatOf(int p) => (p - dealer + n) % n;
  int seatWind(int p) => 27 + seatOf(p);
  int get roundWind => 27;
  int get wallLeft => wall.length;
  bool get _sichuan => rules.voidSuit;

  String who(int p) => p == me ? 'Du' : players[p].name;
  String _verb(int p, String du, String er) => p == me ? du : er;

  void start() {
    for (final p in players) {
      p.points = rules.startPoints;
    }
    dealer = 0;
    newHand();
  }

  void newHand() {
    wall = rules.buildWall()..shuffle(_rng);
    for (final p in players) {
      p
        ..hand = []
        ..melds = []
        ..discards = []
        ..bonus = []
        ..voidSuit = null
        ..out = false
        ..locked = false
        ..wonTiles = []
        ..sharedWins = 0
        ..exchange = [];
    }
    for (var k = 0; k < rules.handSize; k++) {
      for (var i = 0; i < n; i++) {
        players[(dealer + i) % n].hand.add(wall.removeAt(0));
      }
    }
    for (var i = 0; i < n; i++) {
      _replaceBonus((dealer + i) % n);
    }
    for (final p in players) {
      p.hand.sort();
    }
    result = null;
    claims = {};
    lastDiscard = null;
    lastDiscarder = -1;
    afterKan = false;
    _discardAfterKan = false;
    robbingTile = null;
    callsMade = 0;
    discardsMade = 0;
    handChanges = List.filled(n, 0);
    handWins.clear();
    handNotes.clear();
    for (var p = 0; p < n; p++) {
      if (players[p].bonus.isEmpty) _instant(p, 'noFlowers', 'keine Blumen');
      if (players[p].bonus.length >= 13) _instant(p, 'flowers13', '13 Blumen');
    }
    lastEvent = '';
    current = dealer;
    drawn = null;
    if (rules.exchange) {
      phase = MjPhase.exchange;
      exchangeDir = const [1, -1, 2][_rng.nextInt(n == 4 ? 3 : 2)];
      for (var p = 0; p < n; p++) {
        if (!players[p].human) players[p].exchange = botExchange(p);
      }
    } else if (rules.voidSuit) {
      _startVoid();
    } else {
      _draw(dealer);
    }
  }

  void _replaceBonus(int p) {
    final pl = players[p];
    while (pl.hand.any(_isBonus) && wall.isNotEmpty) {
      final b = pl.hand.firstWhere(_isBonus);
      pl.hand.remove(b);
      pl.bonus.add(b);
      pl.hand.add(wall.removeLast());
    }
  }

  // ---------- Sichuan: Tauschen und leere Farbe ----------

  /// Vorschlag: drei Steine der schwächsten Farbe mit mindestens drei Steinen.
  List<int> botExchange(int p) {
    final h = players[p].hand;
    int? best;
    var bestN = 99;
    for (var s = 0; s < 3; s++) {
      final c = h.where((t) => t < 27 && suitOf(t) == s).length;
      if (c >= 3 && c < bestN) {
        bestN = c;
        best = s;
      }
    }
    final tiles = h.where((t) => t < 27 && suitOf(t) == best).toList();
    // Einzelne Steine zuerst abgeben
    final c = countsPlain(h);
    tiles.sort((a, b) => _keepValue(c, a).compareTo(_keepValue(c, b)));
    return tiles.take(3).toList();
  }

  int _keepValue(List<int> c, int t) {
    var v = c[t] * 4;
    if (t < 27) {
      final k = t % 9;
      if (k > 0 && c[t - 1] > 0) v += 2;
      if (k < 8 && c[t + 1] > 0) v += 2;
      if (k > 1 && c[t - 2] > 0) v += 1;
      if (k < 7 && c[t + 2] > 0) v += 1;
    }
    return v;
  }

  bool validExchange(List<int> tiles) =>
      tiles.length == 3 && tiles.every((t) => t < 27) && tiles.map(suitOf).toSet().length == 1;

  void submitExchange(int p, List<int> tiles) => record(['x', p, [...tiles]], () => _submitExchangeImpl(p, tiles));

  void _submitExchangeImpl(int p, List<int> tiles) {
    if (phase != MjPhase.exchange || !validExchange(tiles)) return;
    final pl = players[p];
    final h = [...pl.hand];
    for (final t in tiles) {
      if (!h.remove(t)) return;
    }
    pl.exchange = [...tiles];
    if (players.any((q) => q.exchange.length != 3)) return;
    for (final q in players) {
      for (final t in q.exchange) {
        q.hand.remove(t);
      }
    }
    for (var i = 0; i < n; i++) {
      final to = (i + exchangeDir + n) % n;
      players[to].hand.addAll(players[i].exchange);
    }
    for (final q in players) {
      q.hand.sort();
    }
    lastEvent = switch (exchangeDir) {
      1 => 'Getauscht nach rechts',
      -1 => 'Getauscht nach links',
      _ => 'Getauscht über den Tisch',
    };
    _startVoid();
  }

  /// Die Farbe mit den wenigsten Steinen.
  int botVoid(int p) {
    final h = players[p].hand;
    var best = 0;
    var bestN = 99;
    for (var s = 0; s < 3; s++) {
      final c = h.where((t) => t < 27 && suitOf(t) == s).length;
      if (c < bestN) {
        bestN = c;
        best = s;
      }
    }
    return best;
  }

  void _startVoid() {
    phase = MjPhase.voidChoice;
    for (var p = 0; p < n; p++) {
      if (!players[p].human) players[p].voidSuit = botVoid(p);
    }
  }

  void chooseVoid(int p, int suit) => record(['v', p, suit], () => _chooseVoidImpl(p, suit));

  void _chooseVoidImpl(int p, int suit) {
    if (phase != MjPhase.voidChoice) return;
    players[p].voidSuit = suit;
    if (players.any((q) => q.voidSuit == null)) return;
    _draw(dealer);
  }

  // ---------- Ziehen ----------

  void _draw(int p, {bool replacement = false}) {
    final pl = players[p];
    afterKan = replacement;
    while (true) {
      if (wall.isEmpty) {
        _wallEnd();
        return;
      }
      final t = replacement ? wall.removeLast() : wall.removeAt(0);
      if (_isBonus(t)) {
        pl.bonus.add(t);
        if (pl.bonus.length == 13) _instant(p, 'flowers13', '13 Blumen');
        lastEvent = '${who(p)} ${_verb(p, 'ziehst', 'zieht')} ${tileName(t)} und ${_verb(p, 'nimmst', 'nimmt')} Ersatz';
        replacement = true;
        continue;
      }
      pl.hand.add(t);
      drawn = t;
      break;
    }
    current = p;
    phase = MjPhase.discard;
  }

  // ---------- Auswertung ----------

  WinInfo _info(int p, int tile, {required bool tsumo, bool robKong = false}) {
    final pl = players[p];
    final first = callsMade == 0 && pl.discards.isEmpty && pl.wonTiles.isEmpty;
    return WinInfo(
      winTile: tile,
      tsumo: tsumo,
      seatWind: seatWind(p),
      roundWind: roundWind,
      seat: seatOf(p),
      dealer: p == dealer,
      lastTile: wall.isEmpty,
      rinshan: tsumo && afterKan,
      robKong: robKong,
      afterKongDiscard: !tsumo && _discardAfterKan,
      heaven: tsumo && first && p == dealer && discardsMade == 0,
      earth: first && p != dealer && (tsumo || discardsMade == 1),
      bonus: pl.bonus,
      early: discardsMade < 5,
    );
  }

  MjScore? winScore(int p, int tile, {required bool tsumo, bool robKong = false}) {
    final pl = players[p];
    if (pl.out) return null;
    final closed = tsumo ? pl.hand : [...pl.hand, tile];
    if (pl.voidSuit != null) {
      final bad = [...closed, for (final m in pl.melds) ...m.tiles].any((t) => t < 27 && suitOf(t) == pl.voidSuit);
      if (bad) return null;
    }
    final c = countsPlain(closed);
    final j = jokersIn(closed);
    if (shantenN(c, pl.meldCount, rules.sets, jokers: j, sevenPairs: rules.sevenPairs, orphans: rules.orphans) != -1 &&
        !(rules.knitted && (knittedHonors(c) >= 5 || isKnittedStraightHand(c, pl.meldCount))) &&
        !(rules.pairsPung && isPairsPlusPung(c))) {
      return null;
    }
    final s = rules.evaluate(closed, pl.melds, _info(p, tile, tsumo: tsumo, robKong: robKong));
    if (s == null || s.core < rules.minScore) return null;
    return s;
  }

  bool canTsumo(int p) =>
      phase == MjPhase.discard && current == p && drawn != null && winScore(p, drawn!, tsumo: true) != null;

  /// Wartesteine mit der dazugehörigen Wertung (nur für Anzeige und Computer).
  List<int> waits(int p) {
    final pl = players[p];
    final out = <int>[];
    for (final t in rules.kinds) {
      if (winScore(p, t, tsumo: false) != null) out.add(t);
    }
    if (pl.out) return [];
    return out;
  }

  /// Ist die Hand bereit, egal ob der Wert reicht (für Sichuan „nicht fertig“).
  bool ready(int p) {
    final pl = players[p];
    if (pl.hasVoid()) return false;
    final c = countsPlain(pl.hand);
    return shantenN(c, pl.meldCount, rules.sets, jokers: jokersIn(pl.hand), sevenPairs: rules.sevenPairs) == 0;
  }

  List<int> kanOptions(int p) {
    final pl = players[p];
    if (phase != MjPhase.discard || current != p || pl.locked || wall.isEmpty) return [];
    final c = countsPlain(pl.hand);
    final out = <int>[];
    for (var t = 0; t < tileKinds; t++) {
      if (pl.voidSuit != null && t < 27 && suitOf(t) == pl.voidSuit) continue;
      if (c[t] == 4) out.add(t);
      if (c[t] >= 1 && pl.melds.any((m) => m.kind == MeldKind.pon && m.first == t)) out.add(t);
    }
    return out;
  }

  bool canDiscard(int p, int tile) {
    final pl = players[p];
    if (phase != MjPhase.discard || current != p || !pl.hand.contains(tile)) return false;
    if (pl.locked && drawn != null) return tile == drawn;
    // Sichuan: Steine der leeren Farbe müssen zuerst weg
    if (pl.hasVoid() && !(tile < 27 && suitOf(tile) == pl.voidSuit)) return false;
    return true;
  }

  // ---------- Aktionen am Zug ----------

  void tsumo(int p) => record(['t', p], () => _tsumoImpl(p));

  void _tsumoImpl(int p) {
    if (!canTsumo(p)) return;
    final s = winScore(p, drawn!, tsumo: true)!;
    final t = drawn!;
    players[p].hand.remove(t);
    _win(p, null, s, t);
    _afterWins([p], p);
  }

  /// Vietnam: Joker, die man jetzt für Punkte beiseitelegen darf (danach gibt es einen Ersatzstein).
  List<int> declarableJokers(int p) {
    final pl = players[p];
    if (!rules.vietnamSet || phase != MjPhase.discard || current != p || pl.locked || wall.isEmpty) return const [];
    return {for (final t in pl.hand) if (isJokerTile(t)) t}.toList()..sort();
  }

  void declareJoker(int p, int t) => record(['j', p, t], () => _declareJokerImpl(p, t));

  void _declareJokerImpl(int p, int t) {
    if (!declarableJokers(p).contains(t)) return;
    final pl = players[p];
    pl.hand.remove(t);
    pl.bonus.add(t);
    final note = '${who(p)} ${_verb(p, 'legst', 'legt')} ${tileName(t)} für Punkte beiseite';
    _draw(p, replacement: true);
    lastEvent = note;
  }

  void kan(int p, int t) => record(['k', p, t], () => _kanImpl(p, t));

  void _kanImpl(int p, int t) {
    if (!kanOptions(p).contains(t)) return;
    final pl = players[p];
    final pon = pl.melds.where((m) => m.kind == MeldKind.pon && m.first == t);
    if (pon.isNotEmpty) {
      // Erweiterter Kan: andere dürfen den Stein rauben
      pl.hand.remove(t);
      drawn = null;
      robbingTile = t;
      _robbingPlayer = p;
      claims = {};
      for (var q = 0; q < n; q++) {
        if (q == p || players[q].out) continue;
        if (winScore(q, t, tsumo: false, robKong: true) != null) claims[q] = const [MjOption(MjClaimType.win)];
      }
      if (claims.isEmpty) {
        _finishAddedKan();
      } else {
        lastDiscard = t;
        lastDiscarder = p;
        phase = MjPhase.claim;
        lastEvent = '${who(p)} ${_verb(p, 'willst', 'will')} Kan auf ${tileName(t)} erweitern';
      }
      return;
    }
    for (var i = 0; i < 4; i++) {
      pl.hand.remove(t);
    }
    pl.melds.add(Meld(MeldKind.kan, [t, t, t, t], open: false));
    lastEvent = '${who(p)} ${_verb(p, 'machst', 'macht')} einen verdeckten Kan';
    _kanPay(p, null, 2);
    _instant(p, 'kanClosed', 'den geheimen Kan');
    _draw(p, replacement: true);
  }

  void _finishAddedKan() {
    final p = _robbingPlayer;
    final t = robbingTile!;
    final pl = players[p];
    final m = pl.melds.firstWhere((m) => m.kind == MeldKind.pon && m.first == t);
    pl.melds[pl.melds.indexOf(m)] = Meld(MeldKind.kan, [t, t, t, t], open: true, from: m.from);
    robbingTile = null;
    claims = {};
    lastEvent = '${who(p)} ${_verb(p, 'erweiterst', 'erweitert')} zum Kan';
    _kanPay(p, null, 1);
    _instant(p, 'kanAdded', 'Sagasa (Pung zum Kan erweitert)');
    _draw(p, replacement: true);
  }

  /// Bonussteine; auf den Philippinen zählen auch Winde und Drachen dazu.
  bool _isBonus(int t) => isBonusTile(t) || (rules.honorsAreFlowers && t >= 27 && t < 34);

  /// Sofortzahlung von allen anderen (Philippinen: Kan, Sagasa, keine Blumen, 13 Blumen).
  void _instant(int p, String key, String label) {
    final units = rules.instant[key] ?? 0;
    if (units == 0) return;
    final v = units * rules.instantUnit;
    for (var q = 0; q < n; q++) {
      if (q == p || players[q].out) continue;
      players[q].points -= v;
      players[p].points += v;
      handChanges[q] -= v;
      handChanges[p] += v;
    }
    handNotes.add('${who(p)} ${_verb(p, 'bekommst', 'bekommt')} für $label sofort $v von jedem');
  }

  /// Sichuan: Kans bringen sofort Punkte. from: wer zahlt (null = alle anderen).
  void _kanPay(int p, int? from, int units) {
    if (!_sichuan) return;
    const unit = 100;
    for (var q = 0; q < n; q++) {
      if (q == p || players[q].out) continue;
      if (from != null && q != from) continue;
      final v = units * unit;
      players[q].points -= v;
      players[p].points += v;
      handChanges[q] -= v;
      handChanges[p] += v;
    }
  }

  void discard(int p, int tile) => record(['d', p, tile], () => _discardImpl(p, tile));

  void _discardImpl(int p, int tile) {
    if (!canDiscard(p, tile)) return;
    final pl = players[p];
    pl.hand.remove(tile);
    pl.hand.sort();
    pl.discards.add(MjDiscard(tile));
    discardsMade++;
    drawn = null;
    _discardAfterKan = afterKan;
    afterKan = false;
    lastDiscard = tile;
    lastDiscarder = p;
    if (!lastEvent.contains('Kan') && !lastEvent.contains('Ersatz')) lastEvent = '';
    _openClaims();
  }

  int nextActive(int p) {
    for (var k = 1; k <= n; k++) {
      final q = (p + k) % n;
      if (!players[q].out) return q;
    }
    return p;
  }

  int get activeCount => players.where((p) => !p.out).length;

  // ---------- Ansagen ----------

  void _openClaims() {
    claims = {};
    final t = lastDiscard!;
    final from = lastDiscarder;
    final next = nextActive(from);
    for (var k = 1; k < n; k++) {
      final q = (from + k) % n;
      final pl = players[q];
      if (pl.out) continue;
      final opts = <MjOption>[];
      if (winScore(q, t, tsumo: false) != null) opts.add(const MjOption(MjClaimType.win));
      final voidTile = pl.voidSuit != null && t < 27 && suitOf(t) == pl.voidSuit;
      if (!pl.locked && wall.isNotEmpty && !isJokerTile(t) && !voidTile) {
        final c = pl.hand.where((x) => x == t).length;
        if (c >= 2) opts.add(MjOption(MjClaimType.pon, [t, t]));
        if (c >= 3) opts.add(MjOption(MjClaimType.kan, [t, t, t]));
        if (rules.chi && q == next && t < 27) {
          final m = t % 9;
          bool has(int x) => pl.hand.contains(x);
          if (m >= 2 && has(t - 2) && has(t - 1)) opts.add(MjOption(MjClaimType.chi, [t - 2, t - 1]));
          if (m >= 1 && m <= 7 && has(t - 1) && has(t + 1)) opts.add(MjOption(MjClaimType.chi, [t - 1, t + 1]));
          if (m <= 6 && has(t + 1) && has(t + 2)) opts.add(MjOption(MjClaimType.chi, [t + 1, t + 2]));
        }
      }
      if (opts.isNotEmpty) claims[q] = opts;
    }
    if (claims.isEmpty) {
      _nextTurn();
    } else {
      phase = MjPhase.claim;
    }
  }

  void _nextTurn() {
    claims = {};
    _draw(nextActive(lastDiscarder));
  }

  void resolveClaims(Map<int, MjOption> choices) => record(['c', [for (final e in choices.entries) [e.key, e.value.type.index, ...e.value.tiles]]], () => _resolveClaimsImpl(choices));

  void _resolveClaimsImpl(Map<int, MjOption> choices) {
    if (phase != MjPhase.claim) return;
    final t = lastDiscard!;
    final from = lastDiscarder;
    final robbing = robbingTile != null;
    final winners = <int>[];
    for (var k = 1; k < n; k++) {
      final q = (from + k) % n;
      if (choices[q]?.type != MjClaimType.win || !(claims[q]?.any((o) => o.type == MjClaimType.win) ?? false)) continue;
      final s = winScore(q, t, tsumo: false, robKong: robbing);
      if (s == null) continue;
      if (winners.isNotEmpty) players[q].sharedWins++;
      winners.add(q);
      _win(q, from, s, t);
      if (!rules.multiRon) break;
    }
    if (winners.isNotEmpty) {
      if (robbing) {
        // Der Pung bleibt ohne den geraubten Stein
        robbingTile = null;
      } else {
        players[from].discards.last.called = true;
      }
      claims = {};
      _afterWins(winners, winners.last);
      return;
    }
    if (robbing) {
      _finishAddedKan();
      return;
    }
    for (var k = 1; k < n; k++) {
      final q = (from + k) % n;
      final c = choices[q];
      if (c == null || (c.type != MjClaimType.pon && c.type != MjClaimType.kan)) continue;
      if (!(claims[q]?.any((o) => o.type == c.type) ?? false)) continue;
      _takeMeld(q, from, t, c);
      return;
    }
    final next = nextActive(from);
    final c = choices[next];
    if (c != null && c.type == MjClaimType.chi && (claims[next]?.any((o) => o.type == MjClaimType.chi) ?? false)) {
      _takeMeld(next, from, t, c);
      return;
    }
    _nextTurn();
  }

  void _takeMeld(int q, int from, int t, MjOption c) {
    final pl = players[q];
    for (final x in c.tiles) {
      pl.hand.remove(x);
    }
    players[from].discards.last.called = true;
    callsMade++;
    claims = {};
    final kind = switch (c.type) {
      MjClaimType.chi => MeldKind.chi,
      MjClaimType.kan => MeldKind.kan,
      _ => MeldKind.pon,
    };
    pl.melds.add(Meld(kind, ([...c.tiles, t]..sort()), from: from));
    final name = switch (kind) {
      MeldKind.chi => 'Chi',
      MeldKind.pon => 'Pung',
      MeldKind.kan => 'Kan',
    };
    lastEvent = '${who(q)} ${_verb(q, 'rufst', 'ruft')} $name';
    if (kind == MeldKind.kan) {
      _kanPay(q, from, 2);
      _instant(q, 'kanOpen', 'den Kan');
      _draw(q, replacement: true);
    } else {
      current = q;
      drawn = null;
      phase = MjPhase.discard;
    }
  }

  // ---------- Gewinnen und Abrechnung ----------

  void _win(int winner, int? loser, MjScore s, int tile) {
    final pl = players[winner];
    final active = [for (var p = 0; p < n; p++) !players[p].out && p != winner];
    final ch = rules.pay(s, PayContext(players: n, winner: winner, loser: loser, dealer: dealer, active: active));
    for (var p = 0; p < n; p++) {
      players[p].points += ch[p];
      handChanges[p] += ch[p];
    }
    handWins.add(MjWin(
      winner: winner,
      loser: loser,
      score: s,
      tile: tile,
      hand: [...pl.hand, tile]..sort(),
      melds: [...pl.melds],
      changes: ch,
    ));
    pl.wonTiles.add(tile);
    final how = loser == null ? 'selbst gezogen' : (loser == 0 ? 'mit deinem Abwurf' : 'mit dem Abwurf von ${players[loser].name}');
    lastEvent = '${winner == 0 ? 'Du gewinnst' : '${pl.name} gewinnt'} $how';
  }

  void _afterWins(List<int> winners, int last) {
    claims = {};
    drawn = null;
    if (rules.blood == BloodMode.none) {
      _endHand();
      return;
    }
    for (final w in winners) {
      if (rules.blood == BloodMode.battle) {
        players[w].out = true;
      } else {
        players[w].locked = true;
      }
    }
    if (activeCount <= 1 || wall.isEmpty) {
      _wallEnd(early: activeCount <= 1);
      return;
    }
    lastDiscarder = last;
    _draw(nextActive(last));
  }

  void _wallEnd({bool early = false}) {
    if (_sichuan) _sichuanSettle(early: early);
    _endHand();
  }

  /// Sichuan am Ende: Blumenschwein zahlt allen das Höchste, wer nicht fertig ist, zahlt den Fertigen.
  void _sichuanSettle({required bool early}) {
    if (early) return;
    final cap = sichuanUnit(MjScore(const [], 6), 6);
    final open = [for (var p = 0; p < n; p++) if (players[p].wonTiles.isEmpty && !players[p].out) p];
    final pigs = open.where((p) => players[p].hasVoid()).toList();
    final ready = <int, int>{};
    for (final p in open) {
      if (pigs.contains(p) || !this.ready(p)) continue;
      var best = 0;
      for (final t in rules.kinds) {
        final s = rules.evaluate([...players[p].hand, t], players[p].melds, _info(p, t, tsumo: false));
        if (s != null) best = max(best, sichuanUnit(s, 6));
      }
      ready[p] = best;
    }
    void move(int from, int to, int v) {
      players[from].points -= v;
      players[to].points += v;
      handChanges[from] -= v;
      handChanges[to] += v;
    }

    for (final pig in pigs) {
      for (var q = 0; q < n; q++) {
        if (q == pig || pigs.contains(q)) continue;
        move(pig, q, cap);
      }
      handNotes.add('${who(pig)} ${_verb(pig, 'bist', 'ist')} Blumenschwein und ${_verb(pig, 'zahlst', 'zahlt')} allen $cap');
    }
    for (final p in open) {
      if (pigs.contains(p) || ready.containsKey(p)) continue;
      for (final e in ready.entries) {
        move(p, e.key, e.value);
      }
      if (ready.isNotEmpty) handNotes.add('${who(p)} ${_verb(p, 'bist', 'ist')} nicht fertig und ${_verb(p, 'zahlst', 'zahlt')} den Fertigen');
    }
  }

  bool _gameEnds = false;
  bool get gameWillEnd => _gameEnds;

  void _endHand() {
    phase = MjPhase.handOver;
    claims = {};
    drawn = null;
    handsPlayed++;
    final dealerWon = handWins.any((w) => w.winner == dealer);
    String text;
    if (handWins.isEmpty) {
      text = 'Die Mauer ist leer. Niemand hat gewonnen';
    } else if (handWins.length == 1) {
      text = lastEvent;
    } else {
      final names = [for (final w in handWins) w.winner == 0 ? 'du' : players[w.winner].name];
      text = '${handWins.length} Siege: ${names.join(', ')}';
    }
    result = MjHandResult(text: text, changes: [...handChanges], wins: [...handWins], notes: [...handNotes]);
    final keep = rules.dealerStays && !_sichuan && (dealerWon || handWins.isEmpty);
    if (!keep) {
      dealerMoves++;
      dealer = (dealer + 1) % n;
    }
    _gameEnds = dealerMoves >= rules.hands ||
        handsPlayed >= rules.hands * 3 ||
        (rules.startPoints > 0 && players.any((p) => p.points < 0));
  }

  void nextHand() => record(['n'], () => _nextHandImpl());

  void _nextHandImpl() {
    if (phase != MjPhase.handOver) return;
    if (_gameEnds) {
      phase = MjPhase.gameOver;
      return;
    }
    newHand();
  }

  List<int> ranking() {
    final order = [for (var i = 0; i < n; i++) i];
    order.sort((a, b) {
      final d = players[b].points - players[a].points;
      return d != 0 ? d : a - b;
    });
    return order;
  }

  /// Sichtbare Steine für die Computer.
  List<int> visibleCounts(int p) {
    final c = List.filled(tileKinds, 0);
    for (final pl in players) {
      for (final d in pl.discards) {
        if (d.tile < tileKinds) c[d.tile]++;
      }
      for (final m in pl.melds) {
        for (final t in m.tiles) {
          if (t < tileKinds) c[t]++;
        }
      }
    }
    for (final t in players[p].hand) {
      if (t < tileKinds) c[t]++;
    }
    return c;
  }
}

/// Spielt einen gespeicherten Zug nach.
void mjApply(MjGame g, List<dynamic> a) {
  int i(int k) => a[k] as int;
  switch (a[0] as String) {
    case 'x':
      g.submitExchange(i(1), [for (final t in a[2] as List) t as int]);
    case 'v':
      g.chooseVoid(i(1), i(2));
    case 't':
      g.tsumo(i(1));
    case 'k':
      g.kan(i(1), i(2));
    case 'j':
      g.declareJoker(i(1), i(2));
    case 'd':
      g.discard(i(1), i(2));
    case 'c':
      g.resolveClaims({
        for (final e in a[1] as List)
          (e as List)[0] as int: MjOption(MjClaimType.values[e[1] as int], [for (final t in e.sublist(2)) t as int]),
      });
    case 'n':
      g.nextHand();
  }
}
