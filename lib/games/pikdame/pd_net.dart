import 'pd_engine.dart';

const pdNetGame = 'pikdame';

/// Darf der Mitspieler an Platz [seat] diesen Zug machen? Die Engine prüft die Spielregeln selbst und wirft sonst.
bool pdAllowed(PdGame g, int seat, List<dynamic> a) {
  if (a.isEmpty || g.current != seat) return false;
  if (g.phase != PdPhase.draw && g.phase != PdPhase.play) return false;
  switch (a[0]) {
    case 's' || 'o':
      return a.length == 2 && a[1] == seat && g.phase == PdPhase.draw;
    case 'p':
      return a.length == 3 && a[1] == seat && g.phase == PdPhase.draw && a[2] is List && g.canTakePile(seat, _cards(g, a[2] as List));
    case 'm':
      return a.length == 3 && a[1] == seat && g.phase == PdPhase.play && a[2] is List && g.canMeld(seat, _cards(g, a[2] as List));
    case 'e':
      return a.length == 4 && a[1] == seat && g.phase == PdPhase.play && g.canExtend(seat, a[2] as int, g.cardById(a[3] as int));
    case 'j':
      return a.length == 4 && a[1] == seat && g.phase == PdPhase.play && g.canSwapJoker(seat, a[2] as int, g.cardById(a[3] as int));
    case 'u':
      return a.length == 1 && g.phase == PdPhase.play && g.canUndoTurn;
    case 'd':
      return a.length == 3 && a[1] == seat && g.phase == PdPhase.play && g.discardBlocker(seat) == null;
  }
  return false;
}

List<PdCard> _cards(PdGame g, List<dynamic> ids) => [for (final id in ids) g.cardById(id as int)];
