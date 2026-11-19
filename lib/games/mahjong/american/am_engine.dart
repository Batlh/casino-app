import '../../../core/action_log.dart';
import 'dart:math';

import '../tiles.dart';
import 'am_card.dart';

/// American Mahjong mit eigener Karte: 152 Steine mit acht Jokern, Charleston, nur Aufdecken für die Karte.

class AmPlayer {
  AmPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<int> hand = [];
  List<AmExposure> exposed = [];
  List<int> discards = [];
  List<int> pass = [];
  int points = 0;
}

enum AmPhase { charleston, discard, claim, handOver, gameOver }

/// Antwort auf einen Abwurf: Mahjong oder aufdecken mit [count] Steinen.
class AmClaim {
  const AmClaim.pass()
      : mahjong = false,
        count = 0;
  const AmClaim.mahjong()
      : mahjong = true,
        count = 0;
  const AmClaim.expose(this.count) : mahjong = false;
  final bool mahjong;
  final int count;
  bool get isPass => !mahjong && count == 0;
}

class AmResult {
  AmResult({required this.text, required this.changes, this.winner, this.loser, this.hand, this.tiles = const [], this.jokerless = false});
  final String text;
  final List<int> changes;
  final int? winner;
  final int? loser;
  final AmConcrete? hand;
  final List<int> tiles;
  final bool jokerless;
}

const charlestonNames = ['nach rechts', 'über den Tisch', 'nach links'];
const _charlestonDirs = [1, 2, 3];

class AmGame with ActionLog {
  /// [humans]: Plätze mit Menschen (allein nur 0). [me]: dein Platz, für die Texte („Du“).
  AmGame({Random? rng, List<String> names = const ['Du', 'Betty', 'Ruth', 'Sylvia'], Set<int> humans = const {0}, this.me = 0})
      : _rng = rng ?? Random.secure(),
        players = [for (var i = 0; i < 4; i++) AmPlayer(names[i], human: humans.contains(i))];

  /// Dein Platz (im Netz je Gerät verschieden).
  final int me;

  final Random _rng;
  final List<AmPlayer> players;
  List<int> wall = [];
  int dealer = 0;
  int handsPlayed = 0;
  AmPhase phase = AmPhase.charleston;
  int charlestonStep = 0;
  int current = 0;
  int? drawn;
  int? lastDiscard;
  int lastDiscarder = -1;
  Map<int, List<AmClaim>> claims = {};
  AmResult? result;
  String lastEvent = '';

  /// Gespielt wird, bis jeder einmal Geber war.
  static const hands = 4;
  static const startPoints = 1000;

  void start() {
    for (final p in players) {
      p.points = startPoints;
    }
    newHand();
  }

  void newHand() {
    wall = [
      for (var t = 0; t < tileKinds; t++) ...[t, t, t, t],
      for (var t = firstFlower; t < firstAnimal; t++) t,
      for (var i = 0; i < 8; i++) jokerKind,
    ]..shuffle(_rng);
    for (final p in players) {
      p
        ..hand = []
        ..exposed = []
        ..discards = []
        ..pass = [];
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
    drawn = null;
    lastEvent = '';
    charlestonStep = 0;
    phase = AmPhase.charleston;
    for (var p = 0; p < 4; p++) {
      if (!players[p].human) players[p].pass = botPass(p);
    }
  }

  // ---------- Charleston ----------

  /// Drei Steine, die der Computer am wenigsten braucht. Joker gibt niemand weg.
  /// [rng] nur für Vorschläge an den Menschen, damit das Spiel selbst gleich bleibt.
  List<int> botPass(int p, [Random? rng]) {
    final pl = players[p];
    final target = amTargets(pl.hand, pl.exposed, limit: 1);
    final useless = target.isEmpty ? <int>[] : amUseless(pl.hand, target.first.$1, pl.exposed);
    final out = <int>[...useless.take(3)];
    final rest = [...pl.hand];
    for (final t in out) {
      rest.remove(t);
    }
    rest.removeWhere((t) => t == jokerKind);
    rest.shuffle(rng ?? _rng);
    while (out.length < 3 && rest.isNotEmpty) {
      out.add(rest.removeLast());
    }
    return out;
  }

  bool validPass(int p, List<int> tiles) {
    if (tiles.length != 3 || tiles.contains(jokerKind)) return false;
    final h = [...players[p].hand];
    return tiles.every(h.remove);
  }

  void submitPass(int p, List<int> tiles) => record(['x', p, [...tiles]], () => _submitPassImpl(p, tiles));

  void _submitPassImpl(int p, List<int> tiles) {
    if (phase != AmPhase.charleston || !validPass(p, tiles)) return;
    players[p].pass = [...tiles];
    if (players.any((q) => q.pass.length != 3)) return;
    for (final q in players) {
      for (final t in q.pass) {
        q.hand.remove(t);
      }
    }
    final dir = _charlestonDirs[charlestonStep];
    for (var i = 0; i < 4; i++) {
      players[(i + dir) % 4].hand.addAll(players[i].pass);
    }
    for (final q in players) {
      q
        ..pass = []
        ..hand.sort();
    }
    lastEvent = 'Getauscht ${charlestonNames[charlestonStep]}';
    charlestonStep++;
    if (charlestonStep >= 3) {
      _draw(dealer);
    } else {
      for (var q = 0; q < 4; q++) {
        if (!players[q].human) players[q].pass = botPass(q);
      }
    }
  }

  // ---------- Spielzug ----------

  void _draw(int p) {
    if (wall.isEmpty) {
      _wallGame();
      return;
    }
    final t = wall.removeAt(0);
    players[p].hand.add(t);
    drawn = t;
    current = p;
    phase = AmPhase.discard;
  }

  AmConcrete? winningHand(int p, [int? extra]) {
    final pl = players[p];
    return amWinning(extra == null ? pl.hand : [...pl.hand, extra], pl.exposed);
  }

  bool canMahjong(int p) => phase == AmPhase.discard && current == p && winningHand(p) != null;

  bool canDiscard(int p, int t) => phase == AmPhase.discard && current == p && players[p].hand.contains(t);

  /// Joker, die man gegen einen echten Stein aus aufgedeckten Gruppen tauschen kann: (Besitzer, Gruppe).
  List<(int, int)> jokerSwaps(int p) {
    if (phase != AmPhase.discard || current != p) return [];
    final out = <(int, int)>[];
    final have = amCounts(players[p].hand);
    for (var o = 0; o < 4; o++) {
      final ex = players[o].exposed;
      for (var i = 0; i < ex.length; i++) {
        if (ex[i].jokers > 0 && have[ex[i].kind] > 0) out.add((o, i));
      }
    }
    return out;
  }

  void swapJoker(int p, int owner, int index) => record(['j', p, owner, index], () => _swapJokerImpl(p, owner, index));

  void _swapJokerImpl(int p, int owner, int index) {
    if (!jokerSwaps(p).contains((owner, index))) return;
    final e = players[owner].exposed[index];
    final pl = players[p];
    final real = pl.hand.firstWhere((t) => amKind(t) == e.kind);
    pl.hand.remove(real);
    pl.hand.add(jokerKind);
    pl.hand.sort();
    e.jokers--;
    lastEvent = '${_who(p)} ${p == me ? 'holst' : 'holt'} einen Joker';
  }

  void mahjong(int p) => record(['m', p], () => _mahjongImpl(p));

  void _mahjongImpl(int p) {
    final c = winningHand(p);
    if (!canMahjong(p) || c == null) return;
    _settle(p, null, c);
  }

  void discard(int p, int t) => record(['d', p, t], () => _discardImpl(p, t));

  void _discardImpl(int p, int t) {
    if (!canDiscard(p, t)) return;
    final pl = players[p];
    pl.hand.remove(t);
    pl.hand.sort();
    pl.discards.add(t);
    drawn = null;
    lastDiscard = t;
    lastDiscarder = p;
    lastEvent = '';
    _openClaims();
  }

  String _who(int p) => p == me ? 'Du' : players[p].name;

  /// Kann Spieler q mit dem Abwurf t eine Gruppe aus [count] Steinen aufdecken, die zu einer Kartenhand passt?
  bool _canExpose(int q, int t, int count) {
    final pl = players[q];
    final k = amKind(t);
    final real = amCounts(pl.hand)[k];
    final jokers = pl.hand.where((x) => x == jokerKind).length;
    if (real + jokers < count - 1) return false;
    final after = [...pl.exposed, AmExposure(k, count, 0)];
    for (final c in amConcretes) {
      if (c.hand.concealed) continue;
      if (amDistance(List.filled(amKinds, 0), 99, c, after) >= 0) return true;
    }
    return false;
  }

  void _openClaims() {
    claims = {};
    final t = lastDiscard!;
    for (var k = 1; k <= 3; k++) {
      final q = (lastDiscarder + k) % 4;
      final opts = <AmClaim>[];
      if (winningHand(q, t) != null) opts.add(const AmClaim.mahjong());
      if (t != jokerKind && wall.isNotEmpty) {
        for (final n in [3, 4, 5]) {
          if (_canExpose(q, t, n)) opts.add(AmClaim.expose(n));
        }
      }
      if (opts.isNotEmpty) claims[q] = opts;
    }
    if (claims.isEmpty) {
      _draw((lastDiscarder + 1) % 4);
    } else {
      phase = AmPhase.claim;
    }
  }

  void resolveClaims(Map<int, AmClaim> choices) => record(['c', [for (final e in choices.entries) [e.key, e.value.mahjong ? 1 : 0, e.value.count]]], () => _resolveClaimsImpl(choices));

  void _resolveClaimsImpl(Map<int, AmClaim> choices) {
    if (phase != AmPhase.claim) return;
    final t = lastDiscard!;
    for (var k = 1; k <= 3; k++) {
      final q = (lastDiscarder + k) % 4;
      final ch = choices[q];
      if (ch != null && ch.mahjong) {
        final c = winningHand(q, t);
        if (c != null) {
          players[q].hand.add(t);
          players[lastDiscarder].discards.removeLast();
          _settle(q, lastDiscarder, c);
          return;
        }
      }
    }
    for (var k = 1; k <= 3; k++) {
      final q = (lastDiscarder + k) % 4;
      final ch = choices[q];
      if (ch == null || ch.count == 0 || !_canExpose(q, t, ch.count)) continue;
      _expose(q, t, ch.count);
      return;
    }
    claims = {};
    _draw((lastDiscarder + 1) % 4);
  }

  void _expose(int q, int t, int count) {
    final pl = players[q];
    final k = amKind(t);
    players[lastDiscarder].discards.removeLast();
    var need = count - 1;
    var jokers = 0;
    while (need > 0) {
      final i = pl.hand.indexWhere((x) => x != jokerKind && amKind(x) == k);
      if (i >= 0) {
        pl.hand.removeAt(i);
      } else {
        pl.hand.remove(jokerKind);
        jokers++;
      }
      need--;
    }
    pl.exposed.add(AmExposure(k, count, jokers, from: lastDiscarder));
    claims = {};
    const names = {3: 'Pung', 4: 'Kong', 5: 'Fünfling'};
    lastEvent = '${_who(q)} ${q == me ? 'deckst' : 'deckt'} einen ${names[count]} auf';
    current = q;
    drawn = null;
    phase = AmPhase.discard;
  }

  // ---------- Abrechnung ----------

  void _settle(int winner, int? loser, AmConcrete c) {
    final pl = players[winner];
    final all = [...pl.hand, for (final e in pl.exposed) ...e.tiles];
    final jokerless = !all.contains(jokerKind) && c.groups.any((g) => g.$2 >= 3);
    final v = c.hand.value * (jokerless ? 2 : 1);
    final changes = List.filled(4, 0);
    for (var p = 0; p < 4; p++) {
      if (p == winner) continue;
      final pay = loser == null ? 2 * v : (p == loser ? 2 * v : v);
      changes[p] -= pay;
      changes[winner] += pay;
    }
    for (var p = 0; p < 4; p++) {
      players[p].points += changes[p];
    }
    final how = loser == null ? 'selbst gezogen' : (loser == me ? 'mit deinem Abwurf' : 'mit dem Abwurf von ${players[loser].name}');
    result = AmResult(
      text: '${winner == me ? 'Du hast' : '${pl.name} hat'} Mahjong, $how',
      changes: changes,
      winner: winner,
      loser: loser,
      hand: c,
      tiles: all..sort(),
      jokerless: jokerless,
    );
    _endHand();
  }

  void _wallGame() {
    result = AmResult(text: 'Die Mauer ist leer. Niemand hat Mahjong', changes: List.filled(4, 0));
    _endHand();
  }

  void _endHand() {
    phase = AmPhase.handOver;
    claims = {};
    drawn = null;
    handsPlayed++;
    dealer = (dealer + 1) % 4;
  }

  bool get gameWillEnd => handsPlayed >= hands;

  void nextHand() => record(['n'], () => _nextHandImpl());

  void _nextHandImpl() {
    if (phase != AmPhase.handOver) return;
    if (gameWillEnd) {
      phase = AmPhase.gameOver;
      return;
    }
    newHand();
  }

  List<int> ranking() {
    final order = [0, 1, 2, 3];
    order.sort((a, b) {
      final d = players[b].points - players[a].points;
      return d != 0 ? d : a - b;
    });
    return order;
  }
}

// ---------- Computer ----------

sealed class AmBotTurn {}

class AmBotMahjong extends AmBotTurn {}

class AmBotSwap extends AmBotTurn {
  AmBotSwap(this.owner, this.index);
  final int owner;
  final int index;
}

class AmBotDiscard extends AmBotTurn {
  AmBotDiscard(this.tile);
  final int tile;
}

AmBotTurn amBotTurn(AmGame g, int p, Random rng) {
  if (g.canMahjong(p)) return AmBotMahjong();
  final swaps = g.jokerSwaps(p);
  if (swaps.isNotEmpty) {
    // Nur tauschen, wenn der echte Stein nicht gebraucht wird
    final pl = g.players[p];
    final target = amTargets(pl.hand, pl.exposed, limit: 1);
    if (target.isNotEmpty) {
      final useless = amUseless(pl.hand, target.first.$1, pl.exposed).map(amKind).toSet();
      for (final s in swaps) {
        if (useless.contains(g.players[s.$1].exposed[s.$2].kind)) return AmBotSwap(s.$1, s.$2);
      }
    }
  }
  return AmBotDiscard(amBestDiscard(g, p, rng));
}

int amBestDiscard(AmGame g, int p, Random rng) {
  final pl = g.players[p];
  int? best;
  var bestScore = 1 << 30;
  for (final t in pl.hand.toSet()) {
    if (t == jokerKind) continue;
    final rest = [...pl.hand]..remove(t);
    final targets = amTargets(rest, pl.exposed, limit: 3);
    // Weniger fehlende Steine und mehrere gute Ziele sind besser
    var score = targets.isEmpty ? 99 : targets.first.$2 * 10;
    if (targets.length > 1) score += targets[1].$2;
    score = score * 10 + rng.nextInt(5);
    if (score < bestScore) {
      bestScore = score;
      best = t;
    }
  }
  return best ?? pl.hand.first;
}

AmClaim amBotClaim(AmGame g, int q, List<AmClaim> options) {
  if (options.any((o) => o.mahjong)) return const AmClaim.mahjong();
  final pl = g.players[q];
  final before = amTargets(pl.hand, pl.exposed, limit: 1);
  if (before.isEmpty) return const AmClaim.pass();
  final t = g.lastDiscard!;
  final k = amKind(t);
  for (final o in options) {
    if (o.count == 0) continue;
    // Nur aufdecken, wenn die beste Kartenhand genau diese Gruppe hat
    final c = before.first.$1;
    if (!c.hand.concealed && c.groups.any((gr) => gr.$1 == k && gr.$2 == o.count) && before.first.$2 <= 6) return o;
  }
  return const AmClaim.pass();
}

/// Spielt einen gespeicherten Zug nach.
void amApply(AmGame g, List<dynamic> a) {
  int i(int k) => a[k] as int;
  switch (a[0] as String) {
    case 'x':
      g.submitPass(i(1), [for (final t in a[2] as List) t as int]);
    case 'j':
      g.swapJoker(i(1), i(2), i(3));
    case 'm':
      g.mahjong(i(1));
    case 'd':
      g.discard(i(1), i(2));
    case 'c':
      g.resolveClaims({
        for (final e in a[1] as List)
          (e as List)[0] as int: e[1] == 1
              ? const AmClaim.mahjong()
              : (e[2] as int) > 0
                  ? AmClaim.expose(e[2] as int)
                  : const AmClaim.pass(),
      });
    case 'n':
      g.nextHand();
  }
}
