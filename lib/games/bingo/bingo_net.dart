import 'dart:async';
import 'dart:math';

import '../../core/net/lan.dart';
import 'bingo_engine.dart';

/// Was ein Spieler am Bingo-Tisch sieht. Für das Spiel allein, den Gastgeber und die Mitspieler gleich,
/// damit die Oberfläche nur eine Darstellung braucht.
class BingoView {
  BingoView({
    required this.variant,
    required this.pattern,
    required this.cardPrice,
    required this.pot,
    required this.called,
    required this.stage,
    required this.over,
    required this.myCards,
    required this.others,
    required this.log,
    required this.playerCount,
    required this.cardCount,
  });

  final BingoVariant variant;
  final BingoPattern pattern;
  final int cardPrice;
  final int pot;
  final List<int> called;
  final int stage;
  final bool over;
  final List<BingoCard> myCards;

  /// Andere Spieler mit der kleinsten Zahl fehlender Felder.
  final List<(String, int)> others;
  final List<String> log;
  final int playerCount;
  final int cardCount;

  Set<int> get drawn => called.toSet();
  int get stages => variant == BingoVariant.us75 ? 1 : 3;
  List<double> get shares => variant == BingoVariant.us75 ? const [1.0] : const [0.15, 0.25, 0.6];
  int prizeFor(int s) => (pot * shares[s.clamp(0, stages - 1)]).floor();
  String stageName(int s) =>
      variant == BingoVariant.us75 ? bingoPatternNames[pattern]! : const ['Eine Reihe', 'Zwei Reihen', 'Volle Karte'][s.clamp(0, 2)];

  /// Aus einem laufenden Spiel, gesehen von einem Spieler.
  static BingoView of(BingoGame g, BingoPlayer me, List<String> log) => BingoView(
        variant: g.variant,
        pattern: g.pattern,
        cardPrice: g.cardPrice,
        pot: g.pot,
        called: List.of(g.called),
        stage: g.stage,
        over: g.over,
        myCards: me.cards,
        others: [
          for (final p in g.players)
            if (p != me) (p.name, p.cards.map((c) => c.missing(g.variant, g.drawn, pattern: g.pattern, stage: min(g.stage, g.stages - 1))).reduce(min)),
        ],
        log: List.of(log),
        playerCount: g.players.length,
        cardCount: g.players.fold(0, (a, p) => a + p.cards.length),
      );

  LanMessage toJson() => {
        't': 'view',
        'variant': variant.name,
        'pattern': pattern.name,
        'price': cardPrice,
        'pot': pot,
        'called': called,
        'stage': stage,
        'over': over,
        'cards': [for (final c in myCards) c.rows],
        'others': [for (final (n, m) in others) [n, m]],
        'log': log,
        'players': playerCount,
        'cardCount': cardCount,
      };

  static BingoView fromJson(LanMessage m) => BingoView(
        variant: BingoVariant.values.byName(m['variant'] as String),
        pattern: BingoPattern.values.byName(m['pattern'] as String),
        cardPrice: (m['price'] as num).toInt(),
        pot: (m['pot'] as num).toInt(),
        called: [for (final n in m['called'] as List) (n as num).toInt()],
        stage: (m['stage'] as num).toInt(),
        over: m['over'] as bool,
        myCards: [
          for (final c in m['cards'] as List) BingoCard([for (final r in c as List) [for (final n in r as List) (n as num).toInt()]]),
        ],
        others: [for (final o in m['others'] as List) ('${(o as List)[0]}', (o[1] as num).toInt())],
        log: [for (final l in m['log'] as List) '$l'],
        playerCount: (m['players'] as num).toInt(),
        cardCount: (m['cardCount'] as num).toInt(),
      );
}

/// Ein Mitspieler im Netz, wie der Gastgeber ihn kennt.
class BingoSeat {
  BingoSeat(this.id, this.name, this.cards);
  final int id;
  String name;
  int cards;
  bool ready = true;
  BingoPlayer? player;
}

/// Gastgeber: führt das Spiel, verteilt Karten, zieht Kugeln, schickt jedem seine Sicht und seine Gewinne.
class BingoHost {
  BingoHost({required this.hostName, required this.variant, required this.pattern, required this.cardPrice, required this.bots, Random? rng})
      : rng = rng ?? Random.secure(),
        lan = LanHost(game: 'bingo', name: hostName);

  final String hostName;
  final BingoVariant variant;
  final BingoPattern pattern;
  final int cardPrice;
  final int bots;
  final Random rng;
  final LanHost lan;
  final Map<int, BingoSeat> seats = {};
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;
  final List<StreamSubscription<Object?>> _subs = [];

  String get info => '${variant == BingoVariant.us75 ? '75 Kugeln · ${bingoPatternNames[pattern]}' : '90 Kugeln'} · Karte $cardPrice';

  Future<void> open() async {
    lan.info = info;
    await lan.start();
    _subs.add(lan.messages.listen((e) {
      final (id, m) = e;
      switch (m['t']) {
        case 'join':
          final cards = ((m['cards'] as num?)?.toInt() ?? 1).clamp(1, 4);
          final seat = seats.putIfAbsent(id, () => BingoSeat(id, '${m['name']}', cards));
          seat
            ..name = '${m['name']}'.trim().isEmpty ? 'Gast $id' : '${m['name']}'.trim()
            ..cards = cards
            ..ready = true;
          _lobby();
        case 'leave':
          seats[id]?.ready = false;
          _lobby();
      }
    }));
    _subs.add(lan.leaves.listen((id) {
      seats.remove(id);
      _lobby();
    }));
  }

  void _lobby() {
    lan.info = '$info · ${seats.length + 1} Spieler';
    lan.broadcast({
      't': 'lobby',
      'host': hostName,
      'info': info,
      'players': [hostName, for (final s in seats.values) '${s.name}${s.ready ? '' : ' (wartet)'}'],
      'price': cardPrice,
    });
    _changed.add(null);
  }

  /// Startet eine Runde mit allen bereiten Mitspielern. Liefert das Spiel und den Platz des Gastgebers.
  (BingoGame, BingoPlayer) startRound(int hostCards, List<String> botNames) {
    final me = BingoPlayer(hostName, human: true)..cards.addAll(BingoGame.dealCards(variant, hostCards, rng));
    final players = [me];
    for (final s in seats.values) {
      s.player = null;
      if (!s.ready) continue;
      final p = BingoPlayer(s.name)..cards.addAll(BingoGame.dealCards(variant, s.cards, rng));
      s.player = p;
      players.add(p);
      s.ready = false;
    }
    for (var i = 0; i < bots; i++) {
      players.add(BingoPlayer(botNames[i % botNames.length])..cards.addAll(BingoGame.dealCards(variant, 1 + rng.nextInt(3), rng)));
    }
    final g = BingoGame(variant: variant, players: players, cardPrice: cardPrice, pattern: pattern, rng: rng);
    // Mitspieler bezahlen ihre Karten selbst, sobald die Runde beginnt
    for (final s in seats.values) {
      if (s.player != null) lan.send(s.id, {'t': 'start', 'cost': s.cards * cardPrice});
    }
    return (g, me);
  }

  /// Nach jeder Kugel: jedem seine Sicht, Gewinnern ihre Münzen.
  void publish(BingoGame g, List<BingoWin> wins, List<String> log) {
    for (final s in seats.values) {
      final p = s.player;
      if (p == null) continue;
      lan.send(s.id, BingoView.of(g, p, log).toJson());
      for (final w in wins.where((w) => w.player == p)) {
        lan.send(s.id, {'t': 'pay', 'amount': w.amount, 'text': g.stageName(w.stage)});
      }
    }
  }

  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await lan.close();
    await _changed.close();
  }
}

/// Mitspieler: tritt einem Tisch bei, zahlt seine Karten, bekommt Sicht und Gewinne vom Gastgeber.
class BingoGuest {
  BingoGuest(this.name, this.cards);
  final String name;
  int cards;
  final LanClient lan = LanClient();
  List<String> lobby = [];
  String info = '';
  int price = 0;
  BingoView? view;
  bool ready = false;
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;

  /// Wird gerufen, wenn eine Runde beginnt (Karten bezahlen) oder ein Gewinn kommt.
  bool Function(int cost)? onStart;
  void Function(int amount, String text)? onPay;

  Future<void> join(String address, int port) async {
    await lan.connect(address, port);
    lan.messages.listen((m) {
      switch (m['t']) {
        case 'lobby':
          lobby = [for (final p in m['players'] as List) '$p'];
          info = '${m['info']}';
          price = (m['price'] as num).toInt();
        case 'start':
          final ok = onStart?.call((m['cost'] as num).toInt()) ?? true;
          ready = false;
          if (!ok) lan.send({'t': 'leave'});
        case 'view':
          view = BingoView.fromJson(m);
        case 'pay':
          onPay?.call((m['amount'] as num).toInt(), '${m['text']}');
      }
      _changed.add(null);
    });
    unawaited(lan.done.then((_) {
      if (!_changed.isClosed) _changed.add(null);
    }));
    sendReady();
  }

  void sendReady() {
    ready = true;
    lan.send({'t': 'join', 'name': name, 'cards': cards});
  }

  Future<void> close() async {
    await lan.close();
    await _changed.close();
  }
}
