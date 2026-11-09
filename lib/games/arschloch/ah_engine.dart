import 'dart:math';

import '../cards/playing_card.dart';

/// Arschloch mit 32 Karten (7 bis Ass) für vier Spieler.
/// Wer zuerst keine Karten mehr hat, wird König, dann Vize-König, Vize-Arschloch und Arschloch.

const ahTitles = ['König', 'Vize-König', 'Vize-Arschloch', 'Arschloch'];
const ahPoints = [3, 2, 1, 0];

class AhPlayer {
  AhPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<PlayingCard> hand = [];

  /// Platz aus der letzten Runde (0 König bis 3 Arschloch), null in der ersten Runde.
  int? title;
  int points = 0;
}

enum AhPhase { exchange, play, roundOver, gameOver }

class AhGame {
  AhGame({Random? rng, this.rounds = 6, List<String> names = const ['Du', 'Kalle', 'Uschi', 'Bernd']})
      : _rng = rng ?? Random.secure(),
        players = [for (var i = 0; i < 4; i++) AhPlayer(names[i], human: i == 0)];

  final Random _rng;
  final List<AhPlayer> players;
  final int rounds;
  int round = 0;
  AhPhase phase = AhPhase.play;
  int current = 0;

  /// Oben liegende Karten des laufenden Stichs.
  List<PlayingCard> top = [];
  int topPlayer = -1;
  int _passes = 0;

  /// Reihenfolge, in der die Spieler fertig wurden.
  final List<int> finished = [];
  String lastEvent = '';

  /// Tausch: wer wem wie viele Karten gibt. (Geber, Empfänger, Anzahl, beste Karten?)
  List<(int, int, int, bool)> exchanges = [];

  /// Karten, die Spieler 0 beim Tausch bekommen hat.
  List<PlayingCard> received = [];

  int get activeCount => 4 - finished.length;
  bool active(int p) => !finished.contains(p);

  void start() => newRound();

  void newRound() {
    round++;
    final deck = [
      for (final s in Suit.values)
        for (var r = 7; r <= 14; r++) PlayingCard(r, s),
    ]..shuffle(_rng);
    for (var i = 0; i < 4; i++) {
      players[i].hand = sortAh(deck.sublist(i * 8, i * 8 + 8));
    }
    finished.clear();
    top = [];
    topPlayer = -1;
    _passes = 0;
    received = [];
    lastEvent = '';
    if (players.every((p) => p.title != null)) {
      final byTitle = [for (var t = 0; t < 4; t++) players.indexWhere((p) => p.title == t)];
      // Arschloch gibt dem König seine zwei besten, Vize-Arschloch dem Vize-König seine beste
      exchanges = [(byTitle[3], byTitle[0], 2, true), (byTitle[2], byTitle[1], 1, true)];
      for (final e in exchanges) {
        final give = sortAh(players[e.$1].hand).reversed.take(e.$3).toList();
        _move(e.$1, e.$2, give);
      }
      // Bots geben die schlechtesten zurück, der Mensch wählt selbst
      phase = AhPhase.exchange;
      for (final e in exchanges) {
        if (e.$2 != 0) _move(e.$2, e.$1, sortAh(players[e.$2].hand).take(e.$3).toList());
      }
      if (!exchanges.any((e) => e.$2 == 0)) _startPlay(byTitle[3]);
    } else {
      exchanges = [];
      // Erste Runde: Kreuz 7 fängt an
      _startPlay(players.indexWhere((p) => p.hand.contains(const PlayingCard(7, Suit.clubs))));
    }
  }

  void _move(int from, int to, List<PlayingCard> cards) {
    for (final c in cards) {
      players[from].hand.remove(c);
      players[to].hand.add(c);
    }
    players[from].hand = sortAh(players[from].hand);
    players[to].hand = sortAh(players[to].hand);
    if (to == 0) received = [...received, ...cards];
  }

  /// Wie viele Karten Spieler 0 zurückgeben muss.
  int get humanGives => exchanges.where((e) => e.$2 == 0).fold(0, (a, e) => a + e.$3);

  void humanGiveBack(List<PlayingCard> cards) {
    if (phase != AhPhase.exchange || cards.length != humanGives || !cards.every(players[0].hand.contains)) return;
    final e = exchanges.firstWhere((e) => e.$2 == 0);
    _move(0, e.$1, cards);
    _startPlay(players.indexWhere((p) => p.title == 3));
  }

  void _startPlay(int first) {
    phase = AhPhase.play;
    current = first;
  }

  // ---------- Spielen ----------

  bool canPlay(int p, List<PlayingCard> cards) {
    if (phase != AhPhase.play || current != p || cards.isEmpty || cards.length > 4) return false;
    if (!cards.every(players[p].hand.contains)) return false;
    final r = cards.first.rank;
    if (cards.any((c) => c.rank != r)) return false;
    if (top.isEmpty) return true;
    return cards.length == top.length && r > top.first.rank;
  }

  bool get leading => top.isEmpty;

  void play(int p, List<PlayingCard> cards) {
    if (!canPlay(p, cards)) return;
    for (final c in cards) {
      players[p].hand.remove(c);
    }
    top = [...cards];
    topPlayer = p;
    _passes = 0;
    final name = p == 0 ? 'Du spielst' : '${players[p].name} spielt';
    lastEvent = '$name ${_describe(cards)}';
    if (players[p].hand.isEmpty) {
      finished.add(p);
      lastEvent += ' und ${p == 0 ? 'bist' : 'ist'} fertig';
      if (activeCount == 1) {
        finished.add([0, 1, 2, 3].firstWhere(active));
        _endRound();
        return;
      }
    }
    _advance();
  }

  void pass(int p) {
    if (phase != AhPhase.play || current != p || top.isEmpty) return;
    _passes++;
    lastEvent = p == 0 ? 'Du passt' : '${players[p].name} passt';
    _advance();
  }

  void _advance() {
    // Haben alle anderen aktiven Spieler gepasst, ist der Stich zu Ende
    final others = active(topPlayer) ? activeCount - 1 : activeCount;
    if (_passes >= others) {
      top = [];
      _passes = 0;
      current = active(topPlayer) ? topPlayer : _next(topPlayer);
      return;
    }
    current = _next(current);
  }

  int _next(int p) {
    for (var k = 1; k <= 4; k++) {
      final q = (p + k) % 4;
      if (active(q)) return q;
    }
    return p;
  }

  void _endRound() {
    for (var i = 0; i < 4; i++) {
      final p = finished[i];
      players[p]
        ..title = i
        ..points += ahPoints[i];
    }
    top = [];
    phase = round >= rounds ? AhPhase.gameOver : AhPhase.roundOver;
  }

  void nextRound() {
    if (phase == AhPhase.roundOver) newRound();
  }

  List<int> ranking() => [0, 1, 2, 3]..sort((a, b) => players[b].points - players[a].points);
}

List<PlayingCard> sortAh(Iterable<PlayingCard> cards) =>
    cards.toList()..sort((a, b) => a.rank != b.rank ? a.rank - b.rank : a.suit.index - b.suit.index);

String rankName(int r) => switch (r) { 14 => 'Ass', 13 => 'König', 12 => 'Dame', 11 => 'Bube', _ => '$r' };

String _describe(List<PlayingCard> cards) {
  final r = cards.first.rank;
  if (cards.length == 1) {
    return const {11: 'einen Buben', 12: 'eine Dame', 13: 'einen König', 14: 'ein Ass'}[r] ?? 'eine $r';
  }
  const plural = {7: 'Siebenen', 8: 'Achten', 9: 'Neunen', 10: 'Zehnen', 11: 'Buben', 12: 'Damen', 13: 'Könige', 14: 'Asse'};
  return '${const ['', '', 'zwei', 'drei', 'vier'][cards.length]} ${plural[r]}';
}

/// Computerzug: kleinste passende Gruppe, Asse und große Sätze möglichst aufheben.
List<PlayingCard>? ahBotMove(AhGame g, int p) {
  final hand = g.players[p].hand;
  final byRank = <int, List<PlayingCard>>{};
  for (final c in hand) {
    byRank.putIfAbsent(c.rank, () => []).add(c);
  }
  final ranks = byRank.keys.toList()..sort();
  if (g.leading) {
    // Mit wenigen Karten: die größte Gruppe zuerst, sonst die niedrigste
    final r = hand.length <= 4 && ranks.length <= 2 ? ranks.last : ranks.first;
    return byRank[r];
  }
  final need = g.top.length;
  final over = g.top.first.rank;
  for (final r in ranks) {
    if (r <= over) continue;
    final group = byRank[r]!;
    if (group.length < need) continue;
    // Gruppen nicht aufbrechen, außer es geht nicht anders oder es sind fast keine Karten mehr da
    if (group.length > need && hand.length > 5 && ranks.any((x) => x > over && byRank[x]!.length == need)) continue;
    // Asse nur gegen hohe Karten oder kurz vor Schluss
    if (r == 14 && over < 12 && hand.length > 4) return null;
    return group.take(need).toList();
  }
  return null;
}
