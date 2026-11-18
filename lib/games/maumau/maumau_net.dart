import '../../core/net/lan.dart';
import '../cards/playing_card.dart';
import 'maumau_engine.dart';

/// Mau Mau im lokalen Netz: Sicht eines Platzes und gespiegelte Engine beim Mitspieler.

const mauNetGame = 'maumau';

List<int> _card(PlayingCard c) => [c.rank, c.suit.index];
PlayingCard _cardOf(Object? l) => PlayingCard(((l as List)[0] as num).toInt(), Suit.values[(l[1] as num).toInt()]);

/// Platzhalter für Karten, die der Mitspieler nicht sehen darf.
const _hidden = PlayingCard(7, Suit.spades);

LanMessage mauView(MauMauEngine e, int seat, {required int round, required int bots}) => {
      't': 'view',
      'round': round,
      'me': seat,
      'bots': bots,
      'players': [
        for (final (i, p) in e.players.indexed)
          {
            'name': p.name,
            'n': p.hand.length,
            if (i == seat) 'hand': [for (final c in p.hand) _card(c)],
          },
      ],
      'pile': e.drawPile.length,
      'discard': e.discard.length,
      'top': _card(e.top),
      'current': e.current,
      'pending': e.pendingDraw,
      'wish': e.wish?.index,
      'drew': e.drewThisTurn,
      if (e.current == seat && e.drawnCard != null) 'drawn': _card(e.drawnCard!),
      'winner': e.winner == null ? -1 : e.players.indexOf(e.winner!),
      'event': e.lastEvent,
      'jackOnJack': e.jackOnJack,
      'penaltyEnds': e.penaltyEndsTurn,
    };

/// Engine nur zum Anzeigen; der eigene Platz ist der einzige Mensch darin.
MauMauEngine mauMirror(LanMessage m) {
  final me = (m['me'] as num).toInt();
  final players = <MauPlayer>[];
  for (final (i, raw) in (m['players'] as List).indexed) {
    final p = raw as Map;
    final hand = p['hand'] as List?;
    players.add(MauPlayer('${p['name']}', human: i == me)
      ..hand = hand == null ? List.filled((p['n'] as num).toInt(), _hidden) : [for (final c in hand) _cardOf(c)]);
  }
  final e = MauMauEngine(
    players: players,
    jackOnJack: m['jackOnJack'] as bool,
    penaltyEndsTurn: m['penaltyEnds'] as bool,
  )
    ..drawPile = List.filled((m['pile'] as num).toInt(), _hidden)
    ..discard = [...List.filled((m['discard'] as num).toInt() - 1, _hidden), _cardOf(m['top'])]
    ..current = (m['current'] as num).toInt()
    ..pendingDraw = (m['pending'] as num).toInt()
    ..wish = m['wish'] == null ? null : Suit.values[(m['wish'] as num).toInt()]
    ..drewThisTurn = m['drew'] as bool
    ..drawnCard = m['drawn'] == null ? null : _cardOf(m['drawn'])
    ..lastEvent = '${m['event']}'
    ..neutralText = true;
  final w = (m['winner'] as num).toInt();
  e.winner = w < 0 ? null : players[w];
  return e;
}

/// Züge eines Mitspielers.
LanMessage mauPlayMsg(PlayingCard c, Suit? wish, int round) => {'t': 'play', 'card': _card(c), 'wish': wish?.index, 'round': round};
LanMessage mauDrawMsg(int round) => {'t': 'draw', 'round': round};
LanMessage mauKeepMsg(int round) => {'t': 'keep', 'round': round};

/// Führt den Zug eines Mitspielers aus, wenn er gültig ist. Liefert true bei Erfolg.
bool mauApplyRemote(MauMauEngine e, int seat, LanMessage m) {
  if (e.finished || e.current != seat) return false;
  switch (m['t']) {
    case 'play':
      final c = _cardOf(m['card']);
      final card = e.actor.hand.where((h) => h.rank == c.rank && h.suit == c.suit).firstOrNull;
      if (card == null || !e.canPlay(card)) return false;
      final w = m['wish'];
      e.play(card, wishSuit: w == null ? null : Suit.values[(w as num).toInt()]);
      return true;
    case 'draw':
      if (e.drewThisTurn) return false;
      e.draw();
      return true;
    case 'keep':
      if (!e.drewThisTurn) return false;
      e.pass();
      return true;
  }
  return false;
}
