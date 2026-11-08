import 'dart:math';

/// Helle Seite: Rot, Gelb, Grün, Blau. Dunkle Seite der Kehrseite: Türkis, Orange, Pink, Lila.
enum EinsColor { red, yellow, green, blue, teal, orange, pink, purple }

const lightColors = [EinsColor.red, EinsColor.yellow, EinsColor.green, EinsColor.blue];
const darkColors = [EinsColor.teal, EinsColor.orange, EinsColor.pink, EinsColor.purple];

String colorName(EinsColor c) => switch (c) {
      EinsColor.red => 'Rot',
      EinsColor.yellow => 'Gelb',
      EinsColor.green => 'Grün',
      EinsColor.blue => 'Blau',
      EinsColor.teal => 'Türkis',
      EinsColor.orange => 'Orange',
      EinsColor.pink => 'Pink',
      EinsColor.purple => 'Lila',
    };

/// Spielweisen. Die Regeln folgen den bekannten Kartenspiel-Varianten.
enum EinsMode { classic, flip, noMercy, extreme, spin, flex }

String modeName(EinsMode m) => switch (m) {
      EinsMode.classic => 'Klassisch',
      EinsMode.flip => 'Kehrseite',
      EinsMode.noMercy => 'Gnadenlos',
      EinsMode.extreme => 'Kartenwerfer',
      EinsMode.spin => 'Glücksrad',
      EinsMode.flex => 'Kraftkarten',
    };

String modeBlurb(EinsMode m) => switch (m) {
      EinsMode.classic => 'Die bekannten Regeln',
      EinsMode.flip => 'Wie Flip: Wendekarten drehen alles auf die dunkle Seite',
      EinsMode.noMercy => 'Wie No Mercy: +10, Farbroulette, ab 25 Karten raus',
      EinsMode.extreme => 'Wie Extreme: Der Werfer spuckt zufällig Karten aus',
      EinsMode.spin => 'Wie Spin: Drehkarten lassen das Glücksrad entscheiden',
      EinsMode.flex => 'Wie Flex: Kraftkarten schalten Sonderwirkungen frei',
    };

enum EinsKind {
  number,
  skip,
  reverse,
  drawTwo,
  wild,
  wildDrawFour,
  // Kehrseite
  drawOne,
  flip,
  wildDrawTwo,
  drawFive,
  skipEveryone,
  wildDrawColor,
  // Gnadenlos
  drawFour,
  discardAll,
  wildReverseDrawFour,
  wildDrawSix,
  wildDrawTen,
  wildColorRoulette,
  // Kartenwerfer
  hitTwo,
  tradeHands,
  wildHitFire,
  wildAllHit,
  // Kraftkarten
  flexSkip,
  flexReverse,
  flexDrawTwo,
  flexWildAllDraw,
  flexWildTargetDraw,
  flexWildDrawFour,
  wildAllFlip,
}

/// Eine Seite einer Karte.
class EinsFace {
  const EinsFace(
    this.kind, {
    this.color,
    this.number = -1,
    this.spin = false,
    this.flipMark = false,
  });

  final EinsKind kind;

  /// null bei Farbwahl-Karten.
  final EinsColor? color;
  final int number;

  /// Glücksrad: Diese Karte lässt den Nächsten drehen.
  final bool spin;

  /// Kraftkarten: Diese Zahl schaltet die eigene Kraft um.
  final bool flipMark;

  bool get isWild => color == null;

  bool get isFlex => const {
        EinsKind.flexSkip,
        EinsKind.flexReverse,
        EinsKind.flexDrawTwo,
        EinsKind.flexWildAllDraw,
        EinsKind.flexWildTargetDraw,
        EinsKind.flexWildDrawFour,
      }.contains(kind);

  /// Strafkarten, die auf den Nächsten wirken und gestapelt werden dürfen.
  int get drawValue => switch (kind) {
        EinsKind.drawOne => 1,
        EinsKind.drawTwo || EinsKind.wildDrawTwo || EinsKind.flexDrawTwo || EinsKind.flexWildTargetDraw => 2,
        EinsKind.drawFour || EinsKind.wildDrawFour || EinsKind.wildReverseDrawFour || EinsKind.flexWildDrawFour => 4,
        EinsKind.drawFive => 5,
        EinsKind.wildDrawSix => 6,
        EinsKind.wildDrawTen => 10,
        _ => 0,
      };

  /// Gleiches Symbol zählt als passend, Kraftkarten wie ihr normales Gegenstück.
  EinsKind get symbol => switch (kind) {
        EinsKind.flexSkip => EinsKind.skip,
        EinsKind.flexReverse => EinsKind.reverse,
        EinsKind.flexDrawTwo => EinsKind.drawTwo,
        _ => kind,
      };

  /// Punkte für die Wertung: Zahl, 20 für Aktionen, 50 für Farbwahl.
  int get points => kind == EinsKind.number ? number : (isWild ? 50 : 20);

  String get label => switch (kind) {
        EinsKind.number => spin ? '$number mit Glücksrad' : '$number',
        EinsKind.skip || EinsKind.flexSkip => 'Aussetzen',
        EinsKind.reverse || EinsKind.flexReverse => 'Richtungswechsel',
        EinsKind.drawTwo || EinsKind.flexDrawTwo => 'Plus zwei',
        EinsKind.wild => spin ? 'Farbwahl mit Glücksrad' : 'Farbwahl',
        EinsKind.wildDrawFour || EinsKind.flexWildDrawFour => 'Farbwahl plus vier',
        EinsKind.drawOne => 'Plus eins',
        EinsKind.flip => 'Wenden',
        EinsKind.wildDrawTwo || EinsKind.flexWildTargetDraw => 'Farbwahl plus zwei',
        EinsKind.drawFive => 'Plus fünf',
        EinsKind.skipEveryone => 'Alle setzen aus',
        EinsKind.wildDrawColor => 'Farbwahl, ziehen bis zur Farbe',
        EinsKind.drawFour => 'Plus vier',
        EinsKind.discardAll => 'Alle abwerfen',
        EinsKind.wildReverseDrawFour => 'Richtungswechsel plus vier',
        EinsKind.wildDrawSix => 'Farbwahl plus sechs',
        EinsKind.wildDrawTen => 'Farbwahl plus zehn',
        EinsKind.wildColorRoulette => 'Farbroulette',
        EinsKind.hitTwo => 'Zweimal werfen',
        EinsKind.tradeHands => 'Hände tauschen',
        EinsKind.wildHitFire => 'Feuer',
        EinsKind.wildAllHit => 'Alle werfen',
        EinsKind.flexWildAllDraw => 'Farbwahl, alle ziehen',
        EinsKind.wildAllFlip => 'Kraftwechsel für alle',
      };

  /// Wirkung der Kraftseite.
  String? get flexEffect => switch (kind) {
        EinsKind.flexSkip => 'alle setzen aus',
        EinsKind.flexReverse => 'Richtungswechsel und aussetzen',
        EinsKind.flexDrawTwo => 'alle anderen ziehen eine',
        EinsKind.flexWildAllDraw => 'alle anderen ziehen zwei',
        EinsKind.flexWildTargetDraw => 'ein Gegner deiner Wahl zieht zwei',
        EinsKind.flexWildDrawFour => 'ein Gegner deiner Wahl zieht vier',
        _ => null,
      };

  String get spokenName {
    final base = color == null ? label : '${colorName(color!)} $label';
    if (flipMark) return '$base mit Kraftwechsel';
    final fx = flexEffect;
    return fx == null ? base : '$base, Kraft: $fx';
  }
}

class EinsCard {
  EinsCard(this.id, this.light, [this.dark]);

  /// Für Karten mit nur einer Seite.
  EinsCard.simple(int id, EinsKind kind, {EinsColor? color, int number = -1})
      : this(id, EinsFace(kind, color: color, number: number));

  /// Eindeutige Nummer, doppelte Karten bleiben unterscheidbar.
  final int id;
  final EinsFace light;

  /// Dunkle Seite, nur in der Kehrseite.
  final EinsFace? dark;

  @override
  bool operator ==(Object other) => other is EinsCard && other.id == id;

  @override
  int get hashCode => id;
}

/// Kartensatz je Spielweise. Wo die Verteilung nicht veröffentlicht ist,
/// ist sie sinnvoll ergänzt (Gnadenlos, Kraftkarten).
List<EinsCard> deckFor(EinsMode mode, Random rng) {
  var id = 0;
  final out = <EinsCard>[];
  void add(int n, EinsFace f) {
    for (var k = 0; k < n; k++) {
      out.add(EinsCard(id++, f));
    }
  }

  switch (mode) {
    case EinsMode.classic:
      for (final c in lightColors) {
        add(1, EinsFace(EinsKind.number, color: c, number: 0));
        for (var n = 1; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        for (final k in [EinsKind.skip, EinsKind.reverse, EinsKind.drawTwo]) {
          add(2, EinsFace(k, color: c));
        }
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.wildDrawFour));
    case EinsMode.flip:
      final lightFaces = <EinsFace>[];
      final darkFaces = <EinsFace>[];
      for (var i = 0; i < 4; i++) {
        for (var n = 1; n <= 9; n++) {
          for (var k = 0; k < 2; k++) {
            lightFaces.add(EinsFace(EinsKind.number, color: lightColors[i], number: n));
            darkFaces.add(EinsFace(EinsKind.number, color: darkColors[i], number: n));
          }
        }
        for (var k = 0; k < 2; k++) {
          for (final kind in [EinsKind.drawOne, EinsKind.reverse, EinsKind.skip, EinsKind.flip]) {
            lightFaces.add(EinsFace(kind, color: lightColors[i]));
          }
          for (final kind in [EinsKind.drawFive, EinsKind.reverse, EinsKind.skipEveryone, EinsKind.flip]) {
            darkFaces.add(EinsFace(kind, color: darkColors[i]));
          }
        }
      }
      for (var k = 0; k < 4; k++) {
        lightFaces
          ..add(const EinsFace(EinsKind.wild))
          ..add(const EinsFace(EinsKind.wildDrawTwo));
        darkFaces
          ..add(const EinsFace(EinsKind.wild))
          ..add(const EinsFace(EinsKind.wildDrawColor));
      }
      darkFaces.shuffle(rng);
      for (var i = 0; i < lightFaces.length; i++) {
        out.add(EinsCard(id++, lightFaces[i], darkFaces[i]));
      }
    case EinsMode.noMercy:
      for (final c in lightColors) {
        add(1, EinsFace(EinsKind.number, color: c, number: 0));
        for (var n = 1; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        add(3, EinsFace(EinsKind.skip, color: c));
        add(2, EinsFace(EinsKind.skipEveryone, color: c));
        add(4, EinsFace(EinsKind.reverse, color: c));
        add(3, EinsFace(EinsKind.drawTwo, color: c));
        add(2, EinsFace(EinsKind.drawFour, color: c));
        add(4, EinsFace(EinsKind.discardAll, color: c));
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.wildReverseDrawFour));
      add(4, const EinsFace(EinsKind.wildDrawSix));
      add(4, const EinsFace(EinsKind.wildDrawTen));
      add(4, const EinsFace(EinsKind.wildColorRoulette));
    case EinsMode.extreme:
      for (final c in lightColors) {
        for (var n = 1; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        add(2, EinsFace(EinsKind.reverse, color: c));
        add(2, EinsFace(EinsKind.skip, color: c));
        add(2, EinsFace(EinsKind.hitTwo, color: c));
        add(1, EinsFace(EinsKind.discardAll, color: c));
        add(1, EinsFace(EinsKind.tradeHands, color: c));
      }
      add(4, const EinsFace(EinsKind.wild));
      add(2, const EinsFace(EinsKind.wildHitFire));
      add(2, const EinsFace(EinsKind.wildAllHit));
    case EinsMode.spin:
      for (final c in lightColors) {
        for (var n = 0; n <= 9; n++) {
          add(n <= 5 ? 1 : 2, EinsFace(EinsKind.number, color: c, number: n));
        }
        for (var n = 1; n <= 5; n++) {
          add(1, EinsFace(EinsKind.number, color: c, number: n, spin: true));
        }
        for (final k in [EinsKind.drawTwo, EinsKind.reverse, EinsKind.skip]) {
          add(2, EinsFace(k, color: c));
        }
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.wild, spin: true));
      add(4, const EinsFace(EinsKind.wildDrawFour));
    case EinsMode.flex:
      for (final c in lightColors) {
        for (var n = 1; n <= 8; n++) {
          add(1, EinsFace(EinsKind.number, color: c, number: n));
          add(1, EinsFace(EinsKind.number, color: c, number: n, flipMark: true));
        }
        for (final k in [
          EinsKind.skip,
          EinsKind.reverse,
          EinsKind.drawTwo,
          EinsKind.flexSkip,
          EinsKind.flexReverse,
          EinsKind.flexDrawTwo,
        ]) {
          add(1, EinsFace(k, color: c));
        }
      }
      add(4, const EinsFace(EinsKind.wildAllFlip));
      add(4, const EinsFace(EinsKind.flexWildAllDraw));
      add(4, const EinsFace(EinsKind.flexWildTargetDraw));
      add(4, const EinsFace(EinsKind.flexWildDrawFour));
  }
  return out;
}

/// Klassischer Satz, für ältere Aufrufe.
List<EinsCard> einsDeck() => deckFor(EinsMode.classic, Random(0));

enum SpinSpace { almostDone, discardNumber, discardColor, drawRed, drawBlue, tradeHands, showHand, war, race }

String spinName(SpinSpace s) => switch (s) {
      SpinSpace.almostDone => 'Fast fertig',
      SpinSpace.discardNumber => 'Zahl abwerfen',
      SpinSpace.discardColor => 'Farbe abwerfen',
      SpinSpace.drawRed => 'Zieh bis Rot',
      SpinSpace.drawBlue => 'Zieh bis Blau',
      SpinSpace.tradeHands => 'Hände weitergeben',
      SpinSpace.showHand => 'Hand zeigen',
      SpinSpace.war => 'Duell',
      SpinSpace.race => 'Wettrennen',
    };

class EinsPlayer {
  EinsPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<EinsCard> hand = [];
}

class EinsEngine {
  EinsEngine({
    required this.players,
    this.mode = EinsMode.classic,
    Random? rng,
    this.handSize = 7,
    bool stackDraws = true,
    this.callRequired = true,
  })  : _rng = rng ?? Random.secure(),
        _stackSetting = stackDraws;

  final List<EinsPlayer> players;
  final EinsMode mode;
  final int handSize;
  final Random _rng;
  bool _stackSetting;

  /// Plus-Karten stapeln: gleicher oder höherer Wert. Bei Gnadenlos immer an,
  /// beim Kartenwerfer gibt es keine Plus-Karten.
  bool get stackDraws => mode == EinsMode.noMercy || _stackSetting;
  set stackDraws(bool v) => _stackSetting = v;

  bool callRequired;

  List<EinsCard> drawPile = [];
  List<EinsCard> discard = [];
  int current = 0;
  int direction = 1;
  late EinsColor color;
  int pendingDraw = 0;
  int pendingValue = 0;
  bool drewThisTurn = false;
  EinsCard? drawnCard;
  EinsPlayer? winner;
  String lastEvent = '';

  /// Kehrseite: Die dunkle Seite liegt oben.
  bool darkSide = false;

  /// Kraftkarten: Kraft je Spieler an oder aus.
  late List<bool> power;

  /// Gnadenlos: ausgeschiedene Spieler.
  late List<bool> out;

  /// Der Spieler am Zug muss bis zu dieser Farbe ziehen.
  EinsColor? forcedColorDraw;

  /// Farbroulette: Der Spieler am Zug sagt eine Farbe an und zieht bis zu ihr.
  bool rouletteVictim = false;

  /// Glücksrad: Der Spieler am Zug dreht statt zu spielen.
  bool spinPending = false;

  /// Glücksrad: Wettrennen läuft, wer zuerst ruft, wirft eine Karte ab.
  bool raceOpen = false;
  SpinSpace? lastSpin;

  /// Glücksrad: Diese Hand liegt offen.
  int? revealed;

  /// Kartenwerfer: Ergebnis des letzten Drückens.
  int? lastLaunch;

  int get count => players.length;
  EinsCard get top => discard.last;
  EinsFace get topFace => face(top);
  EinsPlayer get actor => players[current];
  bool get finished => winner != null;
  List<EinsColor> get sideColors => darkSide ? darkColors : lightColors;
  int get activeCount => out.where((o) => !o).length;

  /// Muss der Spieler am Zug etwas anderes tun als legen oder ziehen?
  bool get mustSpin => spinPending && !finished;
  bool get mustChooseRoulette => rouletteVictim && !finished;

  EinsFace face(EinsCard c) => darkSide && c.dark != null ? c.dark! : c.light;
  EinsFace? otherFace(EinsCard c) => c.dark == null ? null : (darkSide ? c.light : c.dark);

  int _step(int from, int dir) {
    var i = from;
    for (var guard = 0; guard < count; guard++) {
      i = (i + dir) % count;
      if (!out[i]) return i;
    }
    return from;
  }

  int indexAfter(int steps, {int? from}) {
    var i = from ?? current;
    for (var s = 0; s < steps; s++) {
      i = _step(i, direction);
    }
    return i;
  }

  EinsPlayer get nextPlayer => players[indexAfter(1)];

  void start({int startPlayer = 0, List<EinsCard>? stacked}) {
    drawPile = stacked?.toList() ?? (deckFor(mode, _rng)..shuffle(_rng));
    discard = [];
    darkSide = false;
    power = List.filled(count, true);
    out = List.filled(count, false);
    for (final p in players) {
      p.hand = [];
    }
    for (var i = 0; i < handSize; i++) {
      for (final p in players) {
        p.hand.add(drawPile.removeLast());
      }
    }
    var i = drawPile.length - 1;
    while (i > 0 &&
        (drawPile[i].light.kind != EinsKind.number || drawPile[i].light.spin || drawPile[i].light.flipMark)) {
      i--;
    }
    discard.add(drawPile.removeAt(i));
    color = topFace.color!;
    current = startPlayer;
    direction = 1;
    pendingDraw = 0;
    pendingValue = 0;
    drewThisTurn = false;
    drawnCard = null;
    winner = null;
    lastEvent = '';
    forcedColorDraw = null;
    rouletteVictim = false;
    spinPending = false;
    raceOpen = false;
    lastSpin = null;
    revealed = null;
    lastLaunch = null;
  }

  bool canPlay(EinsCard c) {
    if (finished || spinPending || rouletteVictim || raceOpen || forcedColorDraw != null) {
      return false;
    }
    if (drewThisTurn && c != drawnCard) return false;
    final f = face(c);
    if (pendingDraw > 0) {
      if (!stackDraws) return false;
      return f.drawValue > 0 && f.drawValue >= pendingValue;
    }
    if (f.isWild) return true;
    if (f.color == color) return true;
    final t = topFace;
    if (f.kind == EinsKind.number) {
      return t.kind == EinsKind.number && t.number == f.number;
    }
    return f.symbol == t.symbol;
  }

  List<EinsCard> playableCards() => actor.hand.where(canPlay).toList();

  String _who(EinsPlayer p, String du, String er) => p.human ? 'Du $du' : '${p.name} $er';
  String _name(EinsPlayer p) => p.human ? 'Du' : p.name;
  String _dat(EinsPlayer p) => p.human ? 'dir' : p.name;
  static String _cards(int n) => n == 1 ? 'eine Karte' : '$n Karten';

  /// Braucht diese Karte einen Zielspieler?
  bool needsTarget(EinsCard c, {bool flex = false}) {
    final f = face(c);
    if (f.kind == EinsKind.tradeHands) return true;
    if (mode == EinsMode.noMercy && f.kind == EinsKind.number && f.number == 7) return true;
    if (flex && (f.kind == EinsKind.flexWildTargetDraw || f.kind == EinsKind.flexWildDrawFour)) return true;
    return false;
  }

  bool canUseFlex(int player, EinsCard c) =>
      mode == EinsMode.flex && pendingDraw == 0 && power[player] && face(c).isFlex;

  List<int> get opponentsOfActor => [
        for (var i = 0; i < count; i++)
          if (i != current && !out[i]) i,
      ];

  /// Spielt eine Karte. chosen: Farbe für Farbwahl. target: Zielspieler.
  /// flex: Kraftseite nutzen. called: Eins! gerufen (Computer rufen immer).
  void play(
    EinsCard c, {
    EinsColor? chosen,
    int? target,
    bool flex = false,
    bool called = true,
  }) {
    if (!canPlay(c) || !actor.hand.contains(c)) {
      throw StateError('Karte nicht spielbar');
    }
    if (revealed == current) revealed = null;
    lastLaunch = null;
    final me = current;
    final p = actor;
    final f = face(c);
    final useFlex = flex && canUseFlex(me, c);
    p.hand.remove(c);
    discard.add(c);
    final emptied = p.hand.isEmpty;
    color = f.color ?? (chosen != null && sideColors.contains(chosen) ? chosen : favoriteColor(this, p.hand));
    var steps = 1;
    final targetIndex = target ?? _defaultTarget();
    switch (f.kind) {
      case EinsKind.number:
        lastEvent = '';
        if (mode == EinsMode.noMercy && f.number == 7 && !emptied) {
          final t = players[targetIndex];
          final tmp = p.hand;
          p.hand = t.hand;
          t.hand = tmp;
          lastEvent = '${_who(p, 'tauschst', 'tauscht')} die Hand mit ${_dat(t)}';
        } else if (mode == EinsMode.noMercy && f.number == 0 && !emptied) {
          _passHands(direction);
          lastEvent = 'Alle geben ihre Hand weiter';
        }
        if (mode == EinsMode.flex && f.flipMark) {
          power[me] = !power[me];
          _checkAllOff();
        }
        if (mode == EinsMode.spin && f.spin) spinPending = true;
      case EinsKind.skip:
        steps = 2;
        lastEvent = '${_name(nextPlayer)} setzt aus';
      case EinsKind.skipEveryone:
        steps = 0;
        lastEvent = 'Alle setzen aus, ${_who(p, 'bist', 'ist')} nochmal dran';
      case EinsKind.reverse:
        direction = -direction;
        if (activeCount == 2) steps = 2;
        lastEvent = 'Richtungswechsel';
      case EinsKind.drawOne:
      case EinsKind.drawTwo:
      case EinsKind.drawFour:
      case EinsKind.drawFive:
      case EinsKind.wildDrawTwo:
      case EinsKind.wildDrawFour:
      case EinsKind.wildDrawSix:
      case EinsKind.wildDrawTen:
        pendingDraw += f.drawValue;
        pendingValue = f.drawValue;
        lastEvent = 'Der Nächste zieht $pendingDraw';
      case EinsKind.wildReverseDrawFour:
        direction = -direction;
        pendingDraw += 4;
        pendingValue = 4;
        lastEvent = 'Richtungswechsel, der Nächste zieht $pendingDraw';
      case EinsKind.wildDrawColor:
        forcedColorDraw = color;
        lastEvent = '${_who(nextPlayer, 'ziehst', 'zieht')} bis ${colorName(color)}';
      case EinsKind.wildColorRoulette:
        rouletteVictim = true;
        lastEvent = 'Farbroulette für ${_name(nextPlayer)}';
      case EinsKind.discardAll:
        final same = p.hand.where((x) => face(x).color == f.color).toList();
        for (final x in same) {
          p.hand.remove(x);
          discard.insert(discard.length - 1, x);
        }
        lastEvent = '${_who(p, 'wirfst', 'wirft')} ${same.length} weitere ab';
      case EinsKind.flip:
        darkSide = !darkSide;
        final nf = face(c);
        color = nf.color ?? favoriteColor(this, p.hand);
        lastEvent = darkSide ? 'Alles gewendet: dunkle Seite' : 'Alles gewendet: helle Seite';
      case EinsKind.hitTwo:
        final victim = nextPlayer;
        final got = press(victim) + press(victim);
        steps = 2;
        lastEvent = '${_name(victim)} ${victim.human ? 'drückst' : 'drückt'} zweimal: ${_cards(got)}';
      case EinsKind.tradeHands:
        if (emptied) break;
        final t = players[targetIndex];
        final tmp = p.hand;
        p.hand = t.hand;
        t.hand = tmp;
        lastEvent = '${_who(p, 'tauschst', 'tauscht')} die Hand mit ${_dat(t)}';
      case EinsKind.wildHitFire:
        final victim = nextPlayer;
        var got = 0;
        for (var tries = 0; tries < 30 && got == 0; tries++) {
          got = press(victim);
        }
        steps = 2;
        lastEvent = 'Feuer: ${_name(victim)} ${victim.human ? 'bekommst' : 'bekommt'} ${_cards(got)}';
      case EinsKind.wildAllHit:
        var total = 0;
        for (final i in opponentsOfActor) {
          total += press(players[i]);
        }
        lastEvent = 'Alle anderen drücken: ${_cards(total)}';
      case EinsKind.flexSkip:
        steps = useFlex ? 0 : 2;
        lastEvent = useFlex ? 'Kraft: Alle setzen aus' : '${_name(nextPlayer)} setzt aus';
      case EinsKind.flexReverse:
        direction = -direction;
        steps = useFlex || activeCount == 2 ? 2 : 1;
        lastEvent = useFlex ? 'Kraft: Richtungswechsel und aussetzen' : 'Richtungswechsel';
      case EinsKind.flexDrawTwo:
        if (useFlex) {
          for (final i in opponentsOfActor) {
            _give(players[i], 1);
          }
          lastEvent = 'Kraft: Alle anderen ziehen eine';
        } else {
          pendingDraw += 2;
          pendingValue = 2;
          lastEvent = 'Der Nächste zieht $pendingDraw';
        }
      case EinsKind.flexWildAllDraw:
        if (useFlex) {
          for (final i in opponentsOfActor) {
            _give(players[i], 2);
          }
          lastEvent = 'Kraft: Alle anderen ziehen zwei';
        } else {
          lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}';
        }
      case EinsKind.flexWildTargetDraw:
      case EinsKind.flexWildDrawFour:
        final n = f.drawValue;
        if (useFlex) {
          _give(players[targetIndex], n);
          lastEvent = 'Kraft: ${_who(players[targetIndex], 'ziehst', 'zieht')} $n';
        } else {
          pendingDraw += n;
          pendingValue = n;
          lastEvent = 'Der Nächste zieht $pendingDraw';
        }
      case EinsKind.wildAllFlip:
        for (var i = 0; i < count; i++) {
          power[i] = !power[i];
        }
        _checkAllOff();
        lastEvent = 'Alle Kraftkarten gewendet';
      case EinsKind.wild:
        lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}';
        if (f.spin) spinPending = true;
    }
    if (useFlex) {
      power[me] = false;
      _checkAllOff();
    }
    if (p.hand.isEmpty) {
      winner = p;
      lastEvent = _who(p, 'hast keine Karten mehr', 'hat keine Karten mehr');
      return;
    }
    if (p.hand.length == 1) {
      if (callRequired && !called) {
        final got = mode == EinsMode.extreme ? press(p) + press(p) : _give(p, 2);
        lastEvent = _who(p, 'hast vergessen, Eins! zu rufen: ${_cards(got)}', 'hat vergessen, Eins! zu rufen: ${_cards(got)}');
      } else {
        lastEvent = lastEvent.isEmpty ? '${_name(p)}: Eins!' : '$lastEvent. ${_name(p)}: Eins!';
      }
    }
    _mercy();
    if (finished) return;
    if (steps == 0 && out[current]) steps = 1;
    if (spinPending) {
      final spinner = nextPlayer.human ? 'Du drehst' : '${nextPlayer.name} dreht';
      lastEvent = '${lastEvent.isEmpty ? '' : '$lastEvent. '}$spinner am Glücksrad';
    }
    _advance(steps);
  }

  int _defaultTarget() {
    final others = opponentsOfActor;
    if (others.isEmpty) return current;
    others.sort((a, b) => players[a].hand.length.compareTo(players[b].hand.length));
    return others.first;
  }

  void _passHands(int dir) {
    final active = [for (var i = 0; i < count; i++) if (!out[i]) i];
    final old = {for (final i in active) i: players[i].hand};
    for (final i in active) {
      players[_step(i, dir)].hand = old[i]!;
    }
  }

  void _checkAllOff() {
    if (mode != EinsMode.flex) return;
    var anyOn = false;
    for (var i = 0; i < count; i++) {
      if (!out[i] && power[i]) anyOn = true;
    }
    if (!anyOn) {
      for (var i = 0; i < count; i++) {
        power[i] = true;
      }
    }
  }

  /// Ziehen oder Drücken, je nach Lage.
  void draw() {
    if (finished || spinPending || rouletteVictim || raceOpen) return;
    if (revealed == current) revealed = null;
    lastLaunch = null;
    final p = actor;
    if (forcedColorDraw != null) {
      final target = forcedColorDraw!;
      forcedColorDraw = null;
      final got = _drawUntil(p, target);
      lastEvent = _who(p, 'ziehst $got bis ${colorName(target)}', 'zieht $got bis ${colorName(target)}');
      _mercy();
      if (!finished) _advance(1);
      return;
    }
    if (pendingDraw > 0) {
      final n = pendingDraw;
      pendingDraw = 0;
      pendingValue = 0;
      final got = _give(p, n);
      lastEvent = _who(p, 'ziehst $got', 'zieht $got');
      _mercy();
      if (!finished) _advance(1);
      return;
    }
    if (drewThisTurn) return;
    if (mode == EinsMode.extreme) {
      final got = press(p);
      lastLaunch = got;
      lastEvent = got == 0
          ? _who(p, 'drückst: nichts', 'drückt: nichts')
          : _who(p, 'drückst: ${_cards(got)}', 'drückt: ${_cards(got)}');
      _advance(1);
      return;
    }
    if (mode == EinsMode.noMercy) {
      // Ziehen, bis etwas passt, und das dann spielen
      var got = 0;
      EinsCard? last;
      while (got < 200) {
        final c = _take();
        if (c == null) break;
        p.hand.add(c);
        got++;
        last = c;
        drewThisTurn = true;
        drawnCard = c;
        if (canPlay(c)) break;
      }
      lastEvent = _who(p, 'ziehst $got', 'zieht $got');
      _mercy();
      if (finished) return;
      if (out[current] || last == null || !canPlay(last)) _advance(1);
      return;
    }
    final c = _take();
    if (c == null) {
      lastEvent = _who(p, 'kannst nicht ziehen', 'kann nicht ziehen');
      _advance(1);
      return;
    }
    p.hand.add(c);
    drewThisTurn = true;
    drawnCard = c;
    if (!canPlay(c)) {
      lastEvent = _who(p, 'ziehst', 'zieht');
      _advance(1);
    }
  }

  /// Gezogene Karte behalten. Bei Gnadenlos muss sie gespielt werden.
  void pass() {
    if (drewThisTurn && mode != EinsMode.noMercy) {
      lastEvent = _who(actor, 'ziehst', 'zieht');
      _advance(1);
    }
  }

  /// Farbroulette: Farbe ansagen und ziehen, bis sie kommt.
  void resolveRoulette(EinsColor chosen) {
    if (!rouletteVictim) return;
    rouletteVictim = false;
    final p = actor;
    final got = _drawUntil(p, chosen);
    lastEvent = _who(p, 'ziehst $got bis ${colorName(chosen)}', 'zieht $got bis ${colorName(chosen)}');
    _mercy();
    if (!finished) _advance(1);
  }

  /// Glücksrad drehen. Liefert das Feld. Beim Wettrennen folgt [resolveRace].
  SpinSpace spin({SpinSpace? forced}) {
    if (!spinPending) throw StateError('Kein Glücksrad');
    spinPending = false;
    if (revealed == current) revealed = null;
    final space = forced ?? SpinSpace.values[_rng.nextInt(SpinSpace.values.length)];
    lastSpin = space;
    final p = actor;
    void toDiscard(Iterable<EinsCard> cards) {
      for (final x in cards.toList()) {
        p.hand.remove(x);
        discard.insert(discard.length - 1, x);
      }
    }

    switch (space) {
      case SpinSpace.almostDone:
        if (p.hand.length > 2) {
          final keep = p.hand.toList()
            ..sort((a, b) => _keepScore(b).compareTo(_keepScore(a)));
          toDiscard(keep.sublist(2));
        }
        lastEvent = '${_who(p, 'behältst', 'behält')} nur zwei Karten';
      case SpinSpace.discardNumber:
        final counts = <int, int>{};
        for (final x in p.hand) {
          final f = face(x);
          if (f.kind == EinsKind.number) counts[f.number] = (counts[f.number] ?? 0) + 1;
        }
        if (counts.isEmpty) {
          lastEvent = '${_who(p, 'hast', 'hat')} keine Zahl zum Abwerfen';
        } else {
          final n = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
          final cards = p.hand.where((x) => face(x).kind == EinsKind.number && face(x).number == n);
          final k = cards.length;
          toDiscard(cards);
          lastEvent = '${_who(p, 'wirfst', 'wirft')} $k mal die $n ab';
        }
      case SpinSpace.discardColor:
        final colored = p.hand.where((x) => face(x).color != null).toList();
        if (colored.isEmpty) {
          lastEvent = '${_who(p, 'hast', 'hat')} keine Farbe zum Abwerfen';
        } else {
          final col = favoriteColor(this, p.hand);
          final cards = p.hand.where((x) => face(x).color == col);
          final k = cards.length;
          toDiscard(cards);
          lastEvent = '${_who(p, 'wirfst', 'wirft')} $k ${colorName(col)}e ab';
        }
      case SpinSpace.drawRed:
      case SpinSpace.drawBlue:
        final target = space == SpinSpace.drawRed ? EinsColor.red : EinsColor.blue;
        final got = _drawUntil(p, target);
        lastEvent = _who(p, 'ziehst $got bis ${colorName(target)}', 'zieht $got bis ${colorName(target)}');
      case SpinSpace.tradeHands:
        _passHands(1);
        lastEvent = 'Alle geben ihre Hand nach links weiter';
      case SpinSpace.showHand:
        revealed = current;
        lastEvent = '${_who(p, 'zeigst', 'zeigt')} die Hand';
      case SpinSpace.war:
        final winnerIndex = _war();
        if (winnerIndex == null) {
          lastEvent = 'Duell fällt aus, niemand hat Zahlen';
        } else {
          lastEvent = '${_name(players[winnerIndex])} ${players[winnerIndex].human ? 'gewinnst' : 'gewinnt'} das Duell';
          if (players[winnerIndex].hand.isEmpty) {
            winner = players[winnerIndex];
            return space;
          }
          current = winnerIndex;
          _advance(1);
          return space;
        }
      case SpinSpace.race:
        raceOpen = true;
        lastEvent = 'Wettrennen: Wer zuerst ruft, wirft eine Karte ab';
        return space;
    }
    if (p.hand.isEmpty) {
      winner = p;
      return space;
    }
    _advance(1);
    return space;
  }

  /// Wettrennen auflösen: Der Gewinner wirft seine wertvollste Karte ab.
  void resolveRace(int winnerIndex) {
    if (!raceOpen) return;
    raceOpen = false;
    final w = players[winnerIndex];
    if (w.hand.isNotEmpty) {
      final worst = w.hand.reduce((a, b) => face(b).points > face(a).points ? b : a);
      w.hand.remove(worst);
      discard.insert(discard.length - 1, worst);
    }
    lastEvent = '${_name(w)} ${w.human ? 'warst' : 'war'} am schnellsten';
    if (w.hand.isEmpty) {
      winner = w;
      return;
    }
    current = winnerIndex;
    _advance(1);
  }

  int _keepScore(EinsCard c) {
    final f = face(c);
    if (f.isWild) return 100;
    if (f.color == color) return 50;
    return f.kind == EinsKind.number ? 10 - f.number : 30;
  }

  int? _war() {
    final nums = <int, List<EinsCard>>{};
    for (var i = 0; i < count; i++) {
      if (out[i]) continue;
      final list = players[i].hand.where((x) => face(x).kind == EinsKind.number).toList()
        ..sort((a, b) => face(b).number.compareTo(face(a).number));
      if (list.isNotEmpty) nums[i] = list;
    }
    if (nums.isEmpty) return null;
    var contenders = nums.keys.toList();
    var k = 0;
    while (true) {
      int value(int i) => k < nums[i]!.length ? face(nums[i]![k]).number : -1;
      final best = contenders.map(value).reduce(max);
      contenders = contenders.where((i) => value(i) == best).toList();
      if (contenders.length == 1 || best < 0) break;
      k++;
    }
    final w = contenders.first;
    final played = nums[w]!.take(k + 1).toList();
    for (final x in played) {
      players[w].hand.remove(x);
      discard.insert(discard.length - 1, x);
    }
    return w;
  }

  /// Kartenwerfer: zufällig keine bis viele Karten.
  int launchCount() {
    final r = _rng.nextDouble();
    if (r < 0.42) return 0;
    if (r < 0.60) return 1;
    if (r < 0.74) return 2;
    if (r < 0.84) return 3;
    if (r < 0.91) return 4;
    if (r < 0.96) return 5;
    return 6 + _rng.nextInt(4);
  }

  int press(EinsPlayer p) => _give(p, launchCount());

  int _give(EinsPlayer p, int n) {
    var got = 0;
    for (var i = 0; i < n; i++) {
      final c = _take();
      if (c == null) break;
      p.hand.add(c);
      got++;
    }
    return got;
  }

  int _drawUntil(EinsPlayer p, EinsColor target) {
    var got = 0;
    while (got < 200) {
      final c = _take();
      if (c == null) break;
      p.hand.add(c);
      got++;
      if (face(c).color == target) break;
    }
    return got;
  }

  /// Gnadenlos: Wer 25 oder mehr Karten hat, scheidet aus.
  void _mercy() {
    if (mode != EinsMode.noMercy) return;
    for (var i = 0; i < count; i++) {
      if (out[i] || players[i].hand.length < 25) continue;
      out[i] = true;
      drawPile.addAll(players[i].hand);
      drawPile.shuffle(_rng);
      players[i].hand = [];
      lastEvent = '${_name(players[i])} ${players[i].human ? 'bist' : 'ist'} mit 25 Karten raus';
    }
    if (activeCount == 1) {
      winner = players[out.indexOf(false)];
    }
  }

  void _advance(int steps) {
    current = indexAfter(steps);
    drewThisTurn = false;
    drawnCard = null;
  }

  EinsCard? _take() {
    if (drawPile.isEmpty && discard.length > 1) {
      final keep = discard.removeLast();
      drawPile = discard..shuffle(_rng);
      discard = [keep];
    }
    return drawPile.isEmpty ? null : drawPile.removeLast();
  }

  int get cardCount =>
      drawPile.length + discard.length + players.fold<int>(0, (s, p) => s + p.hand.length);
}

EinsColor favoriteColor(EinsEngine e, List<EinsCard> hand) {
  final counts = <EinsColor, int>{};
  for (final c in hand) {
    final col = e.face(c).color;
    if (col != null) counts[col] = (counts[col] ?? 0) + 1;
  }
  if (counts.isEmpty) return e.sideColors.first;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

typedef EinsChoice = ({EinsCard? card, EinsColor? color, int? target, bool flex});

EinsChoice einsBotChoice(EinsEngine e, Random rng) {
  final hand = e.actor.hand;
  final options = e.playableCards();
  if (options.isEmpty) return (card: null, color: null, target: null, flex: false);
  final danger = e.nextPlayer.hand.length <= 2;
  double score(EinsCard c) {
    final f = e.face(c);
    var s = 0.0;
    if (f.drawValue > 0) s += danger ? 25 : (f.isWild ? -25 : 4);
    switch (f.kind) {
      case EinsKind.wild:
      case EinsKind.wildAllFlip:
        s -= 30;
      case EinsKind.skip:
      case EinsKind.reverse:
      case EinsKind.flexSkip:
      case EinsKind.flexReverse:
      case EinsKind.hitTwo:
        s += danger ? 25 : 3;
      case EinsKind.skipEveryone:
        s += 12;
      case EinsKind.discardAll:
        s += hand.where((h) => e.face(h).color == f.color).length * 5;
      case EinsKind.tradeHands:
        final fewest = e.opponentsOfActor.map((i) => e.players[i].hand.length).fold<int>(999, min);
        s += fewest < hand.length - 2 ? 30 : -40;
      case EinsKind.number:
        s += f.number * 0.3;
        if (e.mode == EinsMode.noMercy && f.number == 7) {
          final fewest = e.opponentsOfActor.map((i) => e.players[i].hand.length).fold<int>(999, min);
          s += fewest < hand.length - 2 ? 20 : -10;
        }
      default:
        break;
    }
    if (f.color != null) s += hand.where((h) => e.face(h).color == f.color && h != c).length * 2;
    return s + rng.nextDouble();
  }

  options.sort((a, b) => score(b).compareTo(score(a)));
  final card = options.first;
  final f = e.face(card);
  final flex = e.canUseFlex(e.current, card) && (f.kind != EinsKind.flexDrawTwo || e.activeCount > 2);
  final color = f.isWild ? favoriteColor(e, hand.where((h) => h != card).toList()) : null;
  int? target;
  if (e.needsTarget(card, flex: flex)) {
    final others = e.opponentsOfActor
      ..sort((a, b) => e.players[a].hand.length.compareTo(e.players[b].hand.length));
    target = others.first;
  }
  return (card: card, color: color, target: target, flex: flex);
}

/// Ein ganzer Zug eines Computer-Gegners, ohne Pausen. Für Tests.
void einsBotTurn(EinsEngine e, Random rng) {
  if (e.finished) return;
  if (e.raceOpen) {
    final active = [for (var i = 0; i < e.count; i++) if (!e.out[i]) i];
    e.resolveRace(active[rng.nextInt(active.length)]);
    return;
  }
  if (e.mustSpin) {
    e.spin();
    return;
  }
  if (e.mustChooseRoulette) {
    e.resolveRoulette(favoriteColor(e, e.actor.hand));
    return;
  }
  final choice = einsBotChoice(e, rng);
  if (choice.card != null) {
    e.play(choice.card!, chosen: choice.color, target: choice.target, flex: choice.flex);
    return;
  }
  e.draw();
  if (e.drewThisTurn && !e.finished) {
    final again = einsBotChoice(e, rng);
    if (again.card != null) {
      e.play(again.card!, chosen: again.color, target: again.target, flex: again.flex);
    } else {
      e.pass();
    }
  }
}
