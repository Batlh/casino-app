/// Münzen in den Kartenspielen. Gespielt wird ohne Einsatz: Münzen gibt es für
/// den Sieg, als Trostpreis für jeden Gegner, der hinter dir landet, und für
/// gute Züge mitten im Spiel.
library;

/// Trostpreis je Gegner, der am Ende hinter dir liegt.
const placeRewardPerBeaten = 25;

/// Gute Züge mitten im Spiel.
const callReward = 5;
const challengeReward = 15;
const actionTileReward = 5;
const blockReward = 10;
const cleanTrickReward = 5;

/// Wie viele Mitspieler hinter Spieler [me] liegen. Kleinere Werte sind besser.
int beatenCount(List<num> scores, int me) {
  var n = 0;
  for (var i = 0; i < scores.length; i++) {
    if (i != me && scores[i] > scores[me]) n++;
  }
  return n;
}

/// Trostpreis für eine Platzierung hinter dem Sieger.
int placeReward(int beaten, {double factor = 1}) => (beaten * placeRewardPerBeaten * factor).round();
