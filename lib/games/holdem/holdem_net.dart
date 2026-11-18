import 'dart:async';

import '../../core/net/lan.dart';
import '../cards/hand_eval.dart';
import '../cards/playing_card.dart';
import 'holdem_engine.dart';

/// Poker im lokalen Netz (Texas Hold'em, Omaha, Five Card Draw).
///
/// Der Gastgeber führt die echte HoldemEngine. Jeder Mitspieler bekommt nach jedem Zug seine Sicht:
/// alles Öffentliche, die eigenen Karten offen, fremde Karten erst beim Aufdecken. Beim Mitspieler wird
/// daraus eine gespiegelte Engine gebaut, damit die Oberfläche dieselbe bleibt. Züge gehen als Nachricht
/// an den Gastgeber, der sie prüft.

String holdemNetGame({required bool omaha, required bool draw}) => draw ? 'draw' : (omaha ? 'omaha' : 'holdem');

List<int> _card(PlayingCard c) => [c.rank, c.suit.index];
PlayingCard _cardOf(Object? l) => PlayingCard(((l as List)[0] as num).toInt(), Suit.values[(l[1] as num).toInt()]);
Object? _value(HandValue? v) => v == null ? null : [v.category.index, ...v.ranks];
HandValue? _valueOf(Object? l) {
  if (l == null) return null;
  final list = [for (final x in l as List) (x as num).toInt()];
  return HandValue(HandCategory.values[list.first], list.sublist(1));
}

/// Verdeckte Karte: Für fremde Hände kennt der Mitspieler nur die Anzahl.
const _hidden = PlayingCard(2, Suit.spades);

/// Sicht von Platz [seat] auf die Hand.
LanMessage holdemView(HoldemEngine e, int seat, int hand) => {
      't': 'view',
      'hand': hand,
      'me': seat,
      'omaha': e.omaha,
      'draw': e.draw,
      'sb': e.smallBlind,
      'bb': e.bigBlind,
      'street': e.street.name,
      'dealer': e.dealer,
      'toAct': e.toAct,
      'bet': e.currentBet,
      'minRaise': e.minRaise,
      'board': [for (final c in e.board) _card(c)],
      'players': [
        for (final (i, p) in e.players.indexed)
          {
            'name': p.name,
            'stack': p.stack,
            'street': p.streetBet,
            'total': p.totalBet,
            'folded': p.folded,
            'allIn': p.allIn,
            'inHand': p.inHand,
            'last': p.lastAction,
            'drew': p.drew,
            'style': p.remote ? '' : (p.style?.label ?? ''),
            'n': p.hole.length,
            if (i == seat || (p.shownValue != null && !p.folded)) 'hole': [for (final c in p.hole) _card(c)],
            'shown': _value(p.shownValue),
          },
      ],
      'results': [
        for (final r in e.results)
          {
            'amount': r.amount,
            'winners': [for (final w in r.winners) e.players.indexOf(w)],
            'value': _value(r.value),
          },
      ],
    };

/// Baut aus einer Sicht eine Engine, die nur zum Anzeigen dient. Der eigene Platz steht vorn (unten am Tisch).
HoldemEngine holdemMirror(LanMessage m) {
  final me = (m['me'] as num).toInt();
  final raw = m['players'] as List;
  final n = raw.length;
  int rot(int i) => i < 0 ? i : (i - me + n) % n;
  final players = List<HoldemPlayer?>.filled(n, null);
  for (var i = 0; i < n; i++) {
    final p = raw[i] as Map;
    final label = '${p['style'] ?? ''}';
    final style = BotStyle.all.where((s) => s.label == label).firstOrNull;
    final hp = HoldemPlayer('${p['name']}', (p['stack'] as num).toInt(), style: style, isHuman: i == me)
      ..streetBet = (p['street'] as num).toInt()
      ..totalBet = (p['total'] as num).toInt()
      ..folded = p['folded'] as bool
      ..allIn = p['allIn'] as bool
      ..inHand = p['inHand'] as bool
      ..lastAction = '${p['last']}'
      ..drew = (p['drew'] as num?)?.toInt()
      ..shownValue = _valueOf(p['shown']);
    final hole = p['hole'] as List?;
    hp.hole = hole == null ? List.filled((p['n'] as num).toInt(), _hidden) : [for (final c in hole) _cardOf(c)];
    players[rot(i)] = hp;
  }
  final list = players.cast<HoldemPlayer>();
  final e = HoldemEngine(
    players: list,
    smallBlind: (m['sb'] as num).toInt(),
    bigBlind: (m['bb'] as num).toInt(),
    omaha: m['omaha'] as bool,
    draw: m['draw'] as bool,
  )
    ..street = HoldemStreet.values.byName('${m['street']}')
    ..dealer = rot((m['dealer'] as num).toInt())
    ..toAct = rot((m['toAct'] as num).toInt())
    ..currentBet = (m['bet'] as num).toInt()
    ..minRaise = (m['minRaise'] as num).toInt()
    ..board = [for (final c in m['board'] as List) _cardOf(c)];
  e.results = [
    for (final r in m['results'] as List)
      PotResult(
        ((r as Map)['amount'] as num).toInt(),
        [for (final w in r['winners'] as List) list[rot((w as num).toInt())]],
        _valueOf(r['value']),
      ),
  ];
  return e;
}

/// Ein Mitspieler im Netz, wie der Gastgeber ihn kennt.
class HoldemSeat {
  HoldemSeat(this.id, this.name);
  final int id;
  String name;

  /// Hat den Einstieg bezahlt und sitzt am Tisch.
  HoldemPlayer? player;

  /// Will nachkaufen (hat schon bezahlt).
  bool rebuy = false;
}

/// Gastgeber: Warteraum, Plätze, Züge der Mitspieler, Sicht für jeden.
class HoldemHost {
  HoldemHost({required this.hostName, required this.omaha, required this.draw, required this.buyIn, required this.info})
      : lan = LanHost(game: holdemNetGame(omaha: omaha, draw: draw), name: hostName);

  final String hostName;
  final bool omaha;
  final bool draw;
  final int buyIn;
  final String info;
  final LanHost lan;
  final Map<int, HoldemSeat> seats = {};
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;
  final List<StreamSubscription<Object?>> _subs = [];

  /// Zug eines Mitspielers (Platz-ID, Nachricht); der Bildschirm prüft und führt ihn aus.
  void Function(HoldemSeat seat, LanMessage m)? onMove;

  /// Ein Mitspieler hat den Tisch verlassen.
  void Function(HoldemSeat seat)? onLeave;

  Future<void> open() async {
    lan.info = info;
    await lan.start();
    _subs.add(lan.messages.listen((e) {
      final (id, m) = e;
      switch (m['t']) {
        case 'join':
          final name = '${m['name']}'.trim();
          seats.putIfAbsent(id, () => HoldemSeat(id, name)).name = name.isEmpty ? 'Gast $id' : name;
          lobby();
        case 'act' || 'discard':
          final s = seats[id];
          if (s != null) onMove?.call(s, m);
        case 'rebuy':
          seats[id]?.rebuy = true;
          _changed.add(null);
        case 'leave':
          _drop(id);
      }
    }));
    _subs.add(lan.leaves.listen(_drop));
  }

  void _drop(int id) {
    final s = seats.remove(id);
    if (s != null) onLeave?.call(s);
    lobby();
  }

  void lobby() {
    lan.info = '$info · ${seats.length + 1} Spieler';
    lan.broadcast({
      't': 'lobby',
      'info': info,
      'buyIn': buyIn,
      'players': [hostName, for (final s in seats.values) s.name],
    });
    _changed.add(null);
  }

  /// Fordert den Einstieg an; der Mitspieler bezahlt und ist ab der nächsten Hand dabei.
  void seat(HoldemSeat s, HoldemPlayer p) {
    s.player = p;
    lan.send(s.id, {'t': 'seat', 'cost': buyIn});
  }

  /// Jedem Mitspieler seine Sicht.
  void publish(HoldemEngine e, int hand) {
    for (final s in seats.values) {
      final p = s.player;
      if (p == null) continue;
      final i = e.players.indexOf(p);
      if (i >= 0) lan.send(s.id, holdemView(e, i, hand));
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

/// Mitspieler: tritt einem Tisch bei, bezahlt den Einstieg, bekommt Sicht und schickt Züge.
class HoldemGuest {
  HoldemGuest(this.name);
  final String name;
  final LanClient lan = LanClient();
  List<String> lobby = [];
  String info = '';
  int buyIn = 0;
  LanMessage? view;
  HoldemEngine? engine;
  int hand = 0;

  /// Sitzt am Tisch (Einstieg bezahlt).
  bool seated = false;
  final _changed = StreamController<void>.broadcast();
  Stream<void> get changed => _changed.stream;

  /// Einstieg bezahlen; false, wenn die Münzen nicht reichen.
  bool Function(int cost)? onSeat;

  Future<void> join(String address, int port) async {
    await lan.connect(address, port);
    lan.messages.listen((m) {
      switch (m['t']) {
        case 'lobby':
          lobby = [for (final p in m['players'] as List) '$p'];
          info = '${m['info']}';
          buyIn = (m['buyIn'] as num).toInt();
        case 'seat':
          seated = onSeat?.call((m['cost'] as num).toInt()) ?? true;
          if (!seated) lan.send({'t': 'leave'});
        case 'view':
          view = m;
          hand = (m['hand'] as num).toInt();
          engine = holdemMirror(m);
      }
      if (!_changed.isClosed) _changed.add(null);
    });
    unawaited(lan.done.then((_) {
      if (!_changed.isClosed) _changed.add(null);
    }));
    lan.send({'t': 'join', 'name': name});
  }

  void act(HoldemAction a) => lan.send({'t': 'act', 'kind': a.kind.name, 'to': a.raiseTo, 'hand': hand});
  void discard(Iterable<int> cards) => lan.send({'t': 'discard', 'cards': cards.toList(), 'hand': hand});
  void rebuy() => lan.send({'t': 'rebuy'});

  Future<void> close() async {
    lan.send({'t': 'leave'});
    await lan.close();
    await _changed.close();
  }
}

/// Zug aus einer Nachricht; null, wenn sie keinen gültigen Zug enthält.
HoldemAction? holdemActionOf(LanMessage m) {
  final kind = HoldemActionKind.values.where((k) => k.name == m['kind']).firstOrNull;
  if (kind == null) return null;
  return HoldemAction(kind, (m['to'] as num?)?.toInt() ?? 0);
}
