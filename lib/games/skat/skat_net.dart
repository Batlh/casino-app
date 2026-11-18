import '../../core/saves.dart';
import 'skat_engine.dart';

/// Skat im lokalen Netz durch Nachspielen: Startwert und Namen zu Beginn der Liste, danach die Einträge des
/// Aktionsprotokolls der Engine. Jedes Gerät hat dieselbe Partie; Computer zieht nur der Gastgeber.

const skatNetGame = 'skat';

/// Darf der Mitspieler an Platz [seat] diese Aktion jetzt machen?
bool skatAllowed(SkatGame g, int seat, List<dynamic> a) {
  if (a.isEmpty) return false;
  bool inHand(Object? code) => code is String && g.players[seat].hand.contains(cardFromCode(code));
  switch (a[0]) {
    case 'y' || 'b':
      return a.length == 2 && a[1] == seat && g.phase == SkatPhase.bidding && g.bidTurn == seat;
    case 's' || 'h':
      return g.declarer == seat && g.phase == SkatPhase.skatChoice;
    case 'd':
      return g.declarer == seat && g.phase == SkatPhase.discard && a.length == 3 && inHand(a[1]) && inHand(a[2]) && a[1] != a[2];
    case 'a':
      return g.declarer == seat && g.phase == SkatPhase.declare && a.length == 4 && a[1] is int && (a[1] as int) < SkatType.values.length;
    case 'p':
      return a.length == 3 &&
          a[1] == seat &&
          g.phase == SkatPhase.playing &&
          g.current == seat &&
          inHand(a[2]) &&
          g.legalCards(seat).contains(cardFromCode(a[2] as String));
  }
  return false;
}
