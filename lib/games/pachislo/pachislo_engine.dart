import 'dart:math';

/// Pachislo: drei Walzen mit Stopptasten, gewertet wird nur die Mittellinie.
///
/// Wie im Original entscheidet vor jedem Spiel eine interne Auslosung, welche Rolle (Gewinn) erlaubt ist.
/// Die Walzen rutschen nach dem Tastendruck höchstens [psSlip] Felder weiter: Sie richten eine ausgeloste Rolle aus,
/// wenn sie im Rutschbereich liegt, und verhindern jede nicht ausgeloste. Pflaume, Replay und Kirsche liegen so dicht,
/// dass sie immer klappen. Auch die Kirsche zählt nur in der Mitte von Walze 1. Glocke und die Sieben für den Bonus muss man treffen (zielen). Ein ausgeloster Bonus bleibt
/// erhalten, bis er ausgerichtet ist; dann leuchtet die Glückslampe.

const psSeven = 0, psBar = 1, psBell = 2, psCherry = 3, psReplay = 4, psPlum = 5;

const psSymbolNames = ['Sieben', 'Balken', 'Glocke', 'Kirsche', 'Replay', 'Pflaume'];

/// Felder je Walze.
const psLength = 21;

/// Höchstens so viele Felder rutscht eine Walze nach dem Drücken weiter.
const psSlip = 4;

/// Walzenbänder. Sichtbar sind die Felder s, s + 1, s + 2; s + 1 ist die Mittellinie.
/// Entworfen mit tool/entwurf/build.py: Pflaume und Replay (und auf Walze 1 die Kirsche) höchstens alle 5 Felder,
/// darum klappen sie immer. Sieben und Glocke muss man treffen.
const psStrips = <List<int>>[
  [psBell, psPlum, psReplay, psCherry, psSeven, psPlum, psReplay, psCherry, psBar, psPlum, psReplay, psCherry, psBar, psBell, psPlum, psReplay, psCherry, psSeven, psPlum, psReplay, psCherry],
  [psSeven, psPlum, psBar, psReplay, psBell, psBar, psPlum, psReplay, psReplay, psPlum, psPlum, psBell, psReplay, psPlum, psPlum, psSeven, psReplay, psBell, psPlum, psReplay, psReplay],
  [psPlum, psPlum, psSeven, psReplay, psBell, psPlum, psBar, psReplay, psBell, psPlum, psBar, psReplay, psReplay, psPlum, psPlum, psBell, psReplay, psSeven, psPlum, psReplay, psReplay],
];

/// Was die Auslosung erlaubt.
enum PsFlag { none, replay, plum, cherry, bell, big, reg }

/// Auslosung je Spiel in 65.536stel.
const psOdds = {
  PsFlag.big: 234, // etwa 1 : 280
  PsFlag.reg: 164, // etwa 1 : 400
  PsFlag.bell: 655, // etwa 1 : 100
  PsFlag.cherry: 1820, // etwa 1 : 36
  PsFlag.replay: 8978, // etwa 1 : 7,3
  PsFlag.plum: 10600, // etwa 1 : 6,2
};

/// Auszahlung in Münzen je Rolle bei Einsatz [psBet].
const psPays = {PsFlag.plum: 7, PsFlag.cherry: 2, PsFlag.bell: 14};

/// Einsatz je Spiel in Münzen.
const psBet = 3;

/// Bonus: Spiele und Auszahlung je Bonus-Pflaume.
const psBigGames = 24, psRegGames = 8, psBonusPay = 15;

/// Symbolfolgen auf der Mittellinie.
const _need = {
  PsFlag.plum: [psPlum, psPlum, psPlum],
  PsFlag.replay: [psReplay, psReplay, psReplay],
  PsFlag.bell: [psBell, psBell, psBell],
  PsFlag.big: [psSeven, psSeven, psSeven],
  PsFlag.reg: [psSeven, psSeven, psBar],
};

List<int> psWindow(int reel, int stop) => [for (var i = 0; i < 3; i++) psStrips[reel][(stop + i) % psLength]];

/// Rollen, die mit den gestoppten Walzen fertig sind. mid[r] ist null für laufende Walzen.
Set<PsFlag> psRoles(List<int?> mid, List<int>? left) {
  final out = <PsFlag>{};
  if (left != null && left[1] == psCherry) out.add(PsFlag.cherry);
  if (!mid.contains(null)) {
    for (final e in _need.entries) {
      if (mid[0] == e.value[0] && mid[1] == e.value[1] && mid[2] == e.value[2]) out.add(e.key);
    }
  }
  return out;
}

/// Ergebnis eines Spiels.
class PsResult {
  const PsResult({required this.flag, required this.role, required this.paid, this.replay = false, this.bonusStarted, this.missed = false});

  /// Was ausgelost war.
  final PsFlag flag;

  /// Was ausgerichtet wurde (none ohne Gewinn).
  final PsFlag role;

  /// Ausgezahlte Münzen (ohne Münzwert).
  final int paid;

  /// Nächstes Spiel ist gratis.
  final bool replay;

  /// BIG oder REG hat begonnen.
  final PsFlag? bonusStarted;

  /// Ausgeloste Rolle verpasst (Glocke oder Bonus nicht getroffen).
  final bool missed;
}

class PachisloMachine {
  PachisloMachine({Random? rng, this.held}) : _rng = rng ?? Random.secure();
  final Random _rng;

  /// Ausgeloster, noch nicht ausgerichteter Bonus (Glückslampe an).
  PsFlag? held;

  /// Laufender Bonus und verbleibende Bonusspiele.
  PsFlag? bonus;
  int bonusLeft = 0;

  /// Das aktuelle Spiel ist ein Replay (kostet nichts).
  bool freeGame = false;

  /// Auslosung des laufenden Spiels.
  PsFlag flag = PsFlag.none;

  final List<int?> stops = [null, null, null];
  bool running = false;

  bool get lamp => held != null;
  bool get allStopped => !stops.contains(null);

  /// Startet ein Spiel und lost aus. Der Einsatz wird außerhalb abgebucht (außer bei [freeGame]).
  PsFlag start() {
    for (var i = 0; i < 3; i++) {
      stops[i] = null;
    }
    running = true;
    if (bonus != null) {
      flag = PsFlag.plum;
    } else if (held != null) {
      flag = held!;
    } else {
      flag = draw(_rng.nextInt(65536));
      if (flag == PsFlag.big || flag == PsFlag.reg) held = flag;
    }
    return flag;
  }

  /// Auslosung aus einer Zahl 0 … 65535.
  static PsFlag draw(int v) {
    for (final e in psOdds.entries) {
      if (v < e.value) return e.key;
      v -= e.value;
    }
    return PsFlag.none;
  }

  /// Stoppt eine Walze, die beim Drücken das Feld [press] oben zeigte. Liefert das Haltefeld.
  int stop(int reel, int press) {
    final s = controlStop(reel, press);
    stops[reel] = s;
    return s;
  }

  /// Walzensteuerung: innerhalb des Rutschbereichs die ausgeloste Rolle ausrichten, keine andere zulassen.
  int controlStop(int reel, int press) {
    int? any;
    int? good;
    final need = _need[flag];
    for (var d = 0; d <= psSlip; d++) {
      final s = (press + d) % psLength;
      final w = psWindow(reel, s);
      final mid = [for (var r = 0; r < 3; r++) r == reel ? w[1] : (stops[r] == null ? null : psStrips[r][(stops[r]! + 1) % psLength])];
      final left = reel == 0 ? w : (stops[0] == null ? null : psWindow(0, stops[0]!));
      if (psRoles(mid, left).difference({flag}).isNotEmpty) continue;
      any ??= s;
      if (flag == PsFlag.cherry) {
        if (reel == 0 && w[1] == psCherry) return s;
      } else if (need != null && w[1] == need[reel]) {
        good ??= s;
      }
    }
    return good ?? any ?? press % psLength;
  }

  /// Wertet das Spiel aus, wenn alle Walzen stehen.
  PsResult finish() {
    running = false;
    final mid = [for (var r = 0; r < 3; r++) psStrips[r][(stops[r]! + 1) % psLength]];
    final roles = psRoles(mid, psWindow(0, stops[0]!));
    final role = roles.isEmpty ? PsFlag.none : roles.first;
    freeGame = false;
    if (bonus != null) {
      bonusLeft--;
      final paid = role == PsFlag.plum ? psBonusPay : 0;
      if (bonusLeft <= 0) bonus = null;
      return PsResult(flag: flag, role: role, paid: paid, missed: role != PsFlag.plum);
    }
    switch (role) {
      case PsFlag.big:
      case PsFlag.reg:
        held = null;
        bonus = role;
        bonusLeft = role == PsFlag.big ? psBigGames : psRegGames;
        return PsResult(flag: flag, role: role, paid: 0, bonusStarted: role);
      case PsFlag.replay:
        freeGame = true;
        return PsResult(flag: flag, role: role, paid: 0, replay: true);
      case PsFlag.none:
        return PsResult(flag: flag, role: role, paid: 0, missed: flag != PsFlag.none);
      default:
        return PsResult(flag: flag, role: role, paid: psPays[role] ?? 0);
    }
  }
}
