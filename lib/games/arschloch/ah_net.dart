import '../../core/saves.dart';
import 'ah_engine.dart';

const ahNetGame = 'arschloch';

/// Darf der Mitspieler an Platz [seat] diesen Zug machen? Platz 0 ist immer der Gastgeber.
bool ahAllowed(AhGame g, int seat, List<dynamic> a) {
  if (a.isEmpty || seat == 0) return false;
  final cards = [for (final x in a.skip(2)) if (x is String) cardFromCode(x)];
  switch (a[0]) {
    case 'p':
      return a.length >= 3 && a[1] == seat && g.phase == AhPhase.play && g.current == seat && cards.length == a.length - 2 && g.canPlay(seat, cards);
    case 'x':
      return a.length == 2 && a[1] == seat && g.phase == AhPhase.play && g.current == seat && !g.leading;
    case 'G':
      return a[1] == seat &&
          g.phase == AhPhase.exchange &&
          g.pendingGive.contains(seat) &&
          cards.length == a.length - 2 &&
          cards.length == g.gives(seat) &&
          cards.toSet().length == cards.length &&
          cards.every(g.players[seat].hand.contains);
  }
  return false;
}
