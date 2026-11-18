import '../../core/saves.dart';
import 'hearts_engine.dart';

const heartsNetGame = 'hearts';

/// Darf der Mitspieler an Platz [seat] diesen Zug machen? Neue Runde und neues Spiel startet nur der Gastgeber.
bool heartsAllowed(HeartsEngine e, int seat, List<dynamic> a) {
  if (a.isEmpty) return false;
  switch (a[0]) {
    case 'p':
      if (a.length != 5 || a[1] != seat || e.phase != HeartsPhase.passing || e.hasPassed(seat)) return false;
      final codes = a.sublist(2);
      if (codes.toSet().length != 3) return false;
      return codes.every((c) => c is String && e.seats[seat].hand.contains(cardFromCode(c)));
    case 'c':
      return a.length == 2 &&
          a[1] is String &&
          e.phase == HeartsPhase.playing &&
          e.current == seat &&
          e.legalCards(seat).contains(cardFromCode(a[1] as String));
  }
  return false;
}
