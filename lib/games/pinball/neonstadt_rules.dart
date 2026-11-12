enum NeonstadtLamp { aus, an, blinkend }

/// Neonstadt-Regeln, unabhängig von der Physik der anderen fünf Tische.
class NeonstadtRules {
  static const shots = [
    'umlauf_links',
    'links',
    'links_innen',
    'kern',
    'rechts_innen',
    'rechts',
    'umlauf_rechts',
  ];
  static const rampShots = {'links', 'rechts', 'links_innen', 'rechts_innen'};
  static const titles = [
    'Datenraub',
    'Überlastung',
    'Firewall knacken',
    'Verfolgungsjagd',
    'Netzrundlauf',
    'Stromausfall',
    'Implantat',
    'Neonrennen',
  ];
  static const instructions = [
    'A links/rechts abwechselnd · 4 Treffer',
    '25 Treffer · B +5 · Umlauf +3',
    'Beide Zielbänke vollständig abräumen',
    'Wandernden Schuss treffen · 3 Treffer',
    'Alle 7 Hauptschüsse einmal',
    'Nur Pfeile · 3 beleuchtete Schüsse',
    '3 Rampen-/Umlauf-Kombos · 3 Sekunden',
    '30 Sekunden · steigende Rampenpunkte',
  ];
  final completed = <int>{};
  final _banks = <String>{};
  final _seen = <String>{};
  int nextMode = 0;
  int? active;
  int progress = 0;
  double remaining = 0;
  double clock = 0;
  double started = 0;
  double hologramUntil = 0;
  double sideWallUntil = 0;
  double specialUntil = 0;
  bool get specialLit => clock < specialUntil;
  int locks = 0;
  bool kickbackLit = true;
  final _inlanes = <String>{};
  int innerHits = 0;
  int comboCount = 0;
  int comboChain = 0;
  String? _comboShot;
  double _comboAt = -10;
  String? _lastData;
  String multiball = '';
  int jackpots = 0;
  bool superLit = false;
  bool extraLit = false;
  bool _extraAwarded = false;
  bool wizardPlayed = false;
  bool wizard = false;
  int points = 0;
  final awards = <({int points, String kind, String text})>[];
  void _award(int value, String kind, String text) {
    points += value;
    if (kind == 'jackpot') {
      hologramUntil = clock + 1.2;
      sideWallUntil = clock + .8;
    }
    awards.add((points: value, kind: kind, text: text));
  }

  int serve = 0;
  int extras = 0;
  String message = '';
  String get title => wizard
      ? 'Systemabsturz'
      : active == null
      ? 'Kern startet ${titles[nextMode]}'
      : titles[active!];
  String get subtitle => wizard
      ? '4 Kugeln · alle Schüsse Jackpot'
      : active == null
      ? (extraLit ? 'Extra-Kugel am Kern bereit' : instructions[nextMode])
      : '${remaining.ceil()} s · $progress · ${instructions[active!]}';
  bool get blackout => active == 5;
  String get movingShot =>
      shots[((clock - started) / 4).floor() % shots.length];
  Set<String> get comboShots {
    if (clock - _comboAt > 3) return {};
    return switch (_comboShot) {
      'links' => {'rechts'},
      'links_innen' => {'rechts_innen'},
      'umlauf_links' => {'umlauf_rechts'},
      'umlauf_rechts' => {'umlauf_links'},
      _ => {},
    };
  }

  Set<String> get _modeShots {
    if (active == 3 || active == 5) return {movingShot};
    if (active == 0)
      return _lastData == null
          ? {'links', 'rechts'}
          : {_lastData == 'links' ? 'rechts' : 'links'};
    if (active == 4) return shots.where((s) => !_seen.contains(s)).toSet();
    if (active == 1)
      return {'links_innen', 'rechts_innen', 'umlauf_links', 'umlauf_rechts'};
    if (active == 2) return {'bank_links', 'bank_rechts'};
    if (active == 6) return {...rampShots, 'umlauf_links', 'umlauf_rechts'};
    if (active == 7) return rampShots;
    return {'kern'};
  }

  Set<String> get litShots {
    if (wizard) return {...shots, 'bank_links', 'bank_rechts'};
    return {
      ..._modeShots,
      ...comboShots,
      if (multiball == 'Datenupload') ...{
        'links',
        'rechts',
        if (superLit) 'kern',
      },
      if (multiball == 'Zielbank-Alarm') ...{'links_innen', 'rechts_innen'},
      if (extraLit) 'kern',
    };
  }

  NeonstadtLamp shotState(String id) {
    if (!litShots.contains(id)) return NeonstadtLamp.aus;
    if (comboShots.contains(id) ||
        ((active == 3 || active == 5) && id == movingShot))
      return NeonstadtLamp.blinkend;
    return NeonstadtLamp.an;
  }

  void tick(double dt) {
    clock += dt;
    if (active == null) return;
    remaining = (remaining - dt).clamp(0, 45);
    if (remaining < 0.000001) {
      if (active == 7)
        _complete();
      else {
        message = '${titles[active!]} · Zeit abgelaufen';
        nextMode = active!;
        active = null;
      }
    }
  }

  void _start() {
    if (completed.length == 8 && !wizardPlayed) {
      wizard = true;
      wizardPlayed = true;
      multiball = 'Systemabsturz';
      serve = 3;
      hologramUntil = clock + 2;
      sideWallUntil = clock + 1;
      message = 'Systemabsturz · 4-Kugel-Multiball';
      return;
    }
    if (completed.length == 8) return;
    while (completed.contains(nextMode)) nextMode = (nextMode + 1) % 8;
    active = nextMode;
    remaining = active == 7 ? 30 : 45;
    progress = 0;
    started = clock;
    _lastData = null;
    _seen.clear();
    hologramUntil = clock + 2;
    sideWallUntil = clock + 1;
    message = titles[active!];
  }

  void _complete() {
    final mode = active!;
    completed.add(mode);
    _award(10000, 'mission', '${titles[mode]} abgeschlossen');
    message = '${titles[mode]} abgeschlossen';
    active = null;
    nextMode = (mode + 1) % 8;
    _lightExtra();
    if (completed.length == 4) specialUntil = clock + 20;
  }

  void _lightExtra() {
    if (!_extraAwarded && (completed.length >= 3 || innerHits >= 10))
      extraLit = true;
  }

  void endMultiball() {
    multiball = '';
    wizard = false;
    superLit = false;
    jackpots = 0;
  }

  void drain() {
    active = null;
    _comboShot = null;
    comboChain = 0;
    endMultiball();
  }

  void hit(String kind, [String id = '']) {
    final modeBefore = active;
    if (kind == 'lane' && id.startsWith('inlane_')) {
      _inlanes.add(id);
      if (_inlanes.length == 2) {
        kickbackLit = true;
        _inlanes.clear();
        message = 'Kickback bereit';
      }
    }
    if (kind == 'lane' && id == 'outlane_rechts' && specialLit) {
      specialUntil = 0;
      _award(50000, 'jackpot', 'Spezial');
      message = 'Spezial · 50 000';
    }
    if (kind == 'target' && wizard) {
      _award(25000, 'jackpot', 'Jackpot');
      jackpots++;
    }
    if (kind == 'bank') {
      _banks.add(id);
      if (active == 2) {
        _seen.add(id);
        progress = _seen.length;
        if (progress == 2) _complete();
      }
      if (_banks.length == 2 && multiball.isEmpty) {
        _banks.clear();
        multiball = 'Zielbank-Alarm';
        serve = 1;
        message = 'Zielbank-Alarm · 2-Kugel-Multiball';
        hologramUntil = clock + 2;
        sideWallUntil = clock + 1;
      }
    }
    if (kind == 'bumper' && active == 1) {
      progress++;
      if (progress >= 25) _complete();
    }
    if (kind != 'shot') return;
    if (id.endsWith('_innen')) {
      innerHits++;
      _lightExtra();
    }
    final combo =
        clock - _comboAt <= 3 &&
        ((_comboShot == 'links' && id == 'rechts') ||
            (_comboShot == 'links_innen' && id == 'rechts_innen') ||
            (_comboShot == 'umlauf_links' && id == 'umlauf_rechts') ||
            (_comboShot == 'umlauf_rechts' && id == 'umlauf_links'));
    if (combo) {
      comboCount++;
      comboChain++;
      _award(2000 * comboChain, 'combo', 'Kombo $comboChain');
      message = 'Kombo $comboChain';
      if (active == 6) {
        progress++;
        if (progress >= 3) _complete();
      }
    } else if (clock - _comboAt > 3) {
      comboChain = 0;
    }
    _comboShot = id;
    _comboAt = clock;
    if (wizard ||
        (multiball == 'Datenupload' && (id == 'links' || id == 'rechts')) ||
        (multiball == 'Zielbank-Alarm' && id.endsWith('_innen'))) {
      _award(25000, 'jackpot', 'Jackpot');
      jackpots++;
      message = 'Jackpot';
      if (multiball == 'Datenupload' && jackpots >= 3) superLit = true;
    }
    if (id == 'kern') {
      if (extraLit) {
        extraLit = false;
        _extraAwarded = true;
        extras++;
        message = 'Extra-Kugel';
      }
      if (superLit) {
        _award(100000, 'jackpot', 'Super-Jackpot');
        superLit = false;
        jackpots = 0;
        message = 'Super-Jackpot';
      }
      if (multiball.isEmpty) {
        locks++;
        if (locks == 3) {
          locks = 0;
          multiball = 'Datenupload';
          serve = 2;
          message = 'Datenupload · 3-Kugel-Multiball';
          hologramUntil = clock + 2;
          sideWallUntil = clock + 1;
        }
      }
      if (active == null && !wizard && modeBefore == null) _start();
    }
    // Der startende Kernschuss zählt nicht bereits zur neuen Aufgabe.
    if (modeBefore == null || active != modeBefore) return;
    switch (active) {
      case 0:
        if ((id == 'links' || id == 'rechts') &&
            (_lastData == null || id != _lastData)) {
          _lastData = id;
          progress++;
          if (progress == 4) _complete();
        }
        break;
      case 1:
        if (id.endsWith('_innen') || id.startsWith('umlauf_')) {
          progress += id.endsWith('_innen') ? 5 : 3;
          if (progress >= 25) _complete();
        }
        break;
      case 5:
        if (id == movingShot) {
          progress++;
          if (progress == 3) _complete();
        }
        break;
      case 3:
        if (id == movingShot) {
          progress++;
          if (progress == 3) _complete();
        }
        break;
      case 4:
        if (shots.contains(id)) {
          _seen.add(id);
          progress = _seen.length;
          if (progress == shots.length) _complete();
        }
        break;
      case 7:
        if (rampShots.contains(id)) {
          progress++;
          _award(1000 * progress, 'ramp', 'Neonrennen · Rampe $progress');
        }
        break;
    }
  }
}
