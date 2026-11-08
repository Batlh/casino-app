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

/// Spielweisen nach den bekannten Kartenspiel-Varianten.
enum EinsMode { classic, flip, noMercy, extreme, spin, spinNew, flex }

String modeName(EinsMode m) => switch (m) {
      EinsMode.classic => 'Klassisch',
      EinsMode.flip => 'Kehrseite',
      EinsMode.noMercy => 'Gnadenlos',
      EinsMode.extreme => 'Kartenwerfer',
      EinsMode.spin => 'Glücksrad',
      EinsMode.spinNew => 'Glücksrad neu',
      EinsMode.flex => 'Kraftkarten',
    };

String modeBlurb(EinsMode m) => switch (m) {
      EinsMode.classic => 'Die bekannten Regeln',
      EinsMode.flip => 'Wie Flip: Wendekarten drehen alles auf die dunkle Seite',
      EinsMode.noMercy => 'Wie No Mercy: bis +10, Farbroulette, ab 25 Karten raus',
      EinsMode.extreme => 'Wie Extreme: Der Werfer spuckt zufällig Karten aus',
      EinsMode.spin => 'Wie Spin (2005): Der Nächste dreht, Duell und Wettrennen',
      EinsMode.spinNew => 'Wie Spin (2025): Du drehst selbst, Farbe ziehen und 2×',
      EinsMode.flex => 'Wie Flex: zweite Farben und Kraftseiten',
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
  // Gnadenlos-Erweiterung
  wildDiscardAll,
  wildReverseDrawEight,
  wildFinalAttack,
  wildSuddenDeath,
  // Kartenwerfer
  hitTwo,
  extremeHit,
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
    this.flexColor,
  });

  final EinsKind kind;

  /// null bei Farbwahl-Karten.
  final EinsColor? color;
  final int number;

  /// Glücksrad: Karte mit Wirbel.
  final bool spin;

  /// Kraftkarten: Zahl mit Kraftwechsel-Zeichen.
  final bool flipMark;

  /// Kraftkarten: zweite Farbe einer Zahlenkarte.
  final EinsColor? flexColor;

  bool get isWild => color == null;
  bool get isNumber => kind == EinsKind.number;

  /// Hat eine Kraftseite.
  bool get hasFlex =>
      flexColor != null ||
      const {
        EinsKind.flexSkip,
        EinsKind.flexReverse,
        EinsKind.flexDrawTwo,
        EinsKind.flexWildAllDraw,
        EinsKind.flexWildTargetDraw,
        EinsKind.flexWildDrawFour,
      }.contains(kind);

  /// Strafwert für das Stapeln. Nur echte Plus-Karten.
  int get drawValue => switch (kind) {
        EinsKind.drawOne => 1,
        EinsKind.drawTwo || EinsKind.wildDrawTwo || EinsKind.flexDrawTwo => 2,
        EinsKind.drawFour ||
        EinsKind.wildDrawFour ||
        EinsKind.wildReverseDrawFour ||
        EinsKind.flexWildDrawFour =>
          4,
        EinsKind.drawFive => 5,
        EinsKind.wildDrawSix => 6,
        EinsKind.wildReverseDrawEight => 8,
        EinsKind.wildDrawTen => 10,
        _ => 0,
      };

  /// Darf nur ohne passende Farbe gelegt werden und kann angezweifelt werden.
  bool get challengeable =>
      kind == EinsKind.wildDrawFour ||
      kind == EinsKind.flexWildDrawFour ||
      kind == EinsKind.wildDrawTwo ||
      kind == EinsKind.wildDrawColor;

  /// Gleiches Symbol zählt als passend, Kraftkarten wie ihr normales Gegenstück.
  EinsKind get symbol => switch (kind) {
        EinsKind.flexSkip => EinsKind.skip,
        EinsKind.flexReverse => EinsKind.reverse,
        EinsKind.flexDrawTwo => EinsKind.drawTwo,
        _ => kind,
      };

  /// Punkte für die Wertung und die Wahl der wertvollsten Karte.
  int get points => isNumber ? number : (isWild ? 50 : 20);

  String get label => switch (kind) {
        EinsKind.number => spin ? '$number mit Glücksrad' : '$number',
        EinsKind.skip || EinsKind.flexSkip => 'Aussetzen',
        EinsKind.reverse || EinsKind.flexReverse => 'Richtungswechsel',
        EinsKind.drawTwo || EinsKind.flexDrawTwo => 'Plus zwei',
        EinsKind.wild || EinsKind.flexWildAllDraw || EinsKind.flexWildTargetDraw =>
          spin ? 'Farbwahl mit Glücksrad' : 'Farbwahl',
        EinsKind.wildDrawFour || EinsKind.flexWildDrawFour => 'Farbwahl plus vier',
        EinsKind.drawOne => 'Plus eins',
        EinsKind.flip => 'Wenden',
        EinsKind.wildDrawTwo => 'Farbwahl plus zwei',
        EinsKind.drawFive => 'Plus fünf',
        EinsKind.skipEveryone => 'Alle setzen aus',
        EinsKind.wildDrawColor => 'Farbwahl, ziehen bis zur Farbe',
        EinsKind.drawFour => 'Plus vier',
        EinsKind.discardAll => 'Alle abwerfen',
        EinsKind.wildReverseDrawFour => 'Richtungswechsel plus vier',
        EinsKind.wildDrawSix => 'Farbwahl plus sechs',
        EinsKind.wildDrawTen => 'Farbwahl plus zehn',
        EinsKind.wildColorRoulette => 'Farbroulette',
        EinsKind.wildDiscardAll => 'Farbwahl, alle abwerfen',
        EinsKind.wildReverseDrawEight => 'Richtungswechsel plus acht',
        EinsKind.wildFinalAttack => 'Finaler Angriff',
        EinsKind.wildSuddenDeath => 'Plötzlicher Tod',
        EinsKind.hitTwo => 'Zweimal drücken',
        EinsKind.extremeHit => 'Extrem-Treffer',
        EinsKind.wildAllFlip => 'Kraftwechsel für alle',
      };

  /// Wirkung der Kraftseite.
  String? get flexEffect {
    if (flexColor != null) return 'als ${colorName(flexColor!)} legen';
    return switch (kind) {
      EinsKind.flexSkip => 'alle setzen aus',
      EinsKind.flexReverse => 'Richtungswechsel und aussetzen',
      EinsKind.flexDrawTwo => 'alle anderen ziehen eine',
      EinsKind.flexWildAllDraw => 'alle anderen ziehen zwei',
      EinsKind.flexWildTargetDraw => 'ein Gegner deiner Wahl zieht zwei',
      EinsKind.flexWildDrawFour => 'ein Gegner deiner Wahl zieht vier',
      _ => null,
    };
  }

  String get spokenName {
    final base = color == null ? label : '${colorName(color!)} $label';
    if (flipMark) return '$base mit Kraftwechsel';
    final fx = flexEffect;
    return fx == null ? base : '$base, Kraft: $fx';
  }
}

class EinsCard {
  EinsCard(this.id, this.light, [this.dark]);

  EinsCard.simple(int id, EinsKind kind, {EinsColor? color, int number = -1})
      : this(id, EinsFace(kind, color: color, number: number));

  final int id;
  final EinsFace light;

  /// Dunkle Seite, nur in der Kehrseite.
  final EinsFace? dark;

  @override
  bool operator ==(Object other) => other is EinsCard && other.id == id;

  @override
  int get hashCode => id;
}

/// Kraftkarten: zweite Farbe je Grundfarbe und Zahl, wie im Original.
EinsColor flexColorFor(EinsColor c, int n) {
  const table = {
    EinsColor.yellow: [EinsColor.green, EinsColor.blue, EinsColor.red],
    EinsColor.green: [EinsColor.yellow, EinsColor.red, EinsColor.blue],
    EinsColor.blue: [EinsColor.red, EinsColor.yellow, EinsColor.green],
    EinsColor.red: [EinsColor.blue, EinsColor.green, EinsColor.yellow],
  };
  return table[c]![n <= 3 ? 0 : (n <= 6 ? 1 : 2)];
}

/// Kraftkarten: Gelb und Blau ungerade, Rot und Grün gerade tragen den Kraftwechsel.
bool flexFlipMark(EinsColor c, int n) =>
    (c == EinsColor.yellow || c == EinsColor.blue) ? n.isOdd : n.isEven;

/// Kartensatz je Spielweise, Verteilung wie in den Originalanleitungen.
List<EinsCard> deckFor(EinsMode mode, Random rng, {bool expansion = false}) {
  var id = 0;
  final out = <EinsCard>[];
  void add(int n, EinsFace f) {
    for (var k = 0; k < n; k++) {
      out.add(EinsCard(id++, f));
    }
  }

  void classicActions(EinsColor c) {
    for (final k in [EinsKind.skip, EinsKind.reverse, EinsKind.drawTwo]) {
      add(2, EinsFace(k, color: c));
    }
  }

  switch (mode) {
    case EinsMode.classic:
      for (final c in lightColors) {
        add(1, EinsFace(EinsKind.number, color: c, number: 0));
        for (var n = 1; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        classicActions(c);
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
        for (var n = 0; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        add(3, EinsFace(EinsKind.drawTwo, color: c));
        add(2, EinsFace(EinsKind.drawFour, color: c));
        add(3, EinsFace(EinsKind.skip, color: c));
        add(2, EinsFace(EinsKind.skipEveryone, color: c));
        add(3, EinsFace(EinsKind.reverse, color: c));
        add(3, EinsFace(EinsKind.discardAll, color: c));
        if (expansion) add(2, EinsFace(EinsKind.number, color: c, number: 10));
      }
      add(8, const EinsFace(EinsKind.wildReverseDrawFour));
      add(4, const EinsFace(EinsKind.wildDrawSix));
      add(4, const EinsFace(EinsKind.wildDrawTen));
      add(8, const EinsFace(EinsKind.wildColorRoulette));
      if (expansion) {
        add(8, const EinsFace(EinsKind.wildDiscardAll));
        add(4, const EinsFace(EinsKind.wildReverseDrawEight));
        add(2, const EinsFace(EinsKind.wildFinalAttack));
        add(2, const EinsFace(EinsKind.wildSuddenDeath));
      }
    case EinsMode.extreme:
      for (final c in lightColors) {
        for (var n = 1; n <= 9; n++) {
          add(2, EinsFace(EinsKind.number, color: c, number: n));
        }
        for (final k in [EinsKind.hitTwo, EinsKind.reverse, EinsKind.skip, EinsKind.discardAll]) {
          add(2, EinsFace(k, color: c));
        }
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.extremeHit));
    case EinsMode.spin:
      // Je Farbe 0 einmal, 1 bis 9 doppelt, von 1 bis 5 ist je eine Karte eine Glücksradkarte
      for (final c in lightColors) {
        add(1, EinsFace(EinsKind.number, color: c, number: 0));
        for (var n = 1; n <= 9; n++) {
          add(1, EinsFace(EinsKind.number, color: c, number: n));
          add(1, EinsFace(EinsKind.number, color: c, number: n, spin: n <= 5));
        }
        classicActions(c);
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.wildDrawFour));
    case EinsMode.spinNew:
      for (final c in lightColors) {
        for (var n = 0; n <= 9; n++) {
          add(n <= 5 ? 1 : 2, EinsFace(EinsKind.number, color: c, number: n));
        }
        for (var n = 1; n <= 5; n++) {
          add(1, EinsFace(EinsKind.number, color: c, number: n, spin: true));
        }
        classicActions(c);
      }
      add(4, const EinsFace(EinsKind.wild));
      add(4, const EinsFace(EinsKind.wild, spin: true));
      add(4, const EinsFace(EinsKind.wildDrawFour));
    case EinsMode.flex:
      for (final c in lightColors) {
        for (var n = 1; n <= 8; n++) {
          add(1, EinsFace(EinsKind.number, color: c, number: n, flipMark: flexFlipMark(c, n)));
          add(1, EinsFace(EinsKind.number, color: c, number: n, flexColor: flexColorFor(c, n)));
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
      add(4, const EinsFace(EinsKind.flexWildTargetDraw));
      add(4, const EinsFace(EinsKind.flexWildAllDraw));
      add(2, const EinsFace(EinsKind.flexWildDrawFour));
      add(6, const EinsFace(EinsKind.wildAllFlip));
  }
  return out;
}

List<EinsCard> einsDeck() => deckFor(EinsMode.classic, Random(0));

/// Felder der Glücksräder. Die ersten neun gehören zum Rad von 2005, der Rest zum Rad von 2025.
enum SpinSpace {
  almostDone,
  discardNumber,
  discardColor,
  drawRed,
  drawBlue,
  tradeHands,
  showHand,
  war,
  race,
  colorDrawRed,
  colorDrawYellow,
  colorDrawGreen,
  colorDrawBlue,
  wildColorDraw,
  colorDiscard,
  swapHands,
  twice,
}

const wheel2005 = [
  SpinSpace.almostDone,
  SpinSpace.discardNumber,
  SpinSpace.discardColor,
  SpinSpace.drawRed,
  SpinSpace.drawBlue,
  SpinSpace.tradeHands,
  SpinSpace.showHand,
  SpinSpace.war,
  SpinSpace.race,
];

const wheel2025 = [
  SpinSpace.colorDrawRed,
  SpinSpace.colorDrawYellow,
  SpinSpace.colorDrawGreen,
  SpinSpace.colorDrawBlue,
  SpinSpace.wildColorDraw,
  SpinSpace.colorDiscard,
  SpinSpace.swapHands,
  SpinSpace.twice,
];

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
      SpinSpace.colorDrawRed => 'Zieh Rot',
      SpinSpace.colorDrawYellow => 'Zieh Gelb',
      SpinSpace.colorDrawGreen => 'Zieh Grün',
      SpinSpace.colorDrawBlue => 'Zieh Blau',
      SpinSpace.wildColorDraw => 'Wunschfarbe ziehen',
      SpinSpace.colorDiscard => 'Farbe abwerfen',
      SpinSpace.swapHands => 'Hände tauschen',
      SpinSpace.twice => 'Zwei Karten',
    };

/// Entscheidungen beim Glücksrad. Fehlende Angaben wählt die Spiellogik selbst.
class SpinChoice {
  const SpinChoice({this.keep, this.number, this.color, this.topId, this.target});

  /// Fast fertig: diese zwei Karten behalten.
  final Set<int>? keep;

  /// Zahl abwerfen: diese Zahl.
  final int? number;

  /// Farbe abwerfen, Wunschfarbe ziehen, Farbe abwerfen (2025).
  final EinsColor? color;

  /// Welche abgeworfene Karte oben liegt.
  final int? topId;

  /// Hände tauschen (2025): mit wem.
  final int? target;
}

/// Münzen der Gnadenlos-Erweiterung.
enum EinsCoin { mercy, noMercy }

class EinsPlayer {
  EinsPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<EinsCard> hand = [];
}

class _Challenge {
  _Challenge(this.offender, this.victim, this.guilty, this.value, this.color);
  final int offender;
  final int victim;
  final bool guilty;

  /// Strafkarten dieser Karte, 0 bei Ziehen bis zur Farbe.
  final int value;

  /// Ziehen bis zur Farbe: diese Farbe.
  final EinsColor? color;
}

class EinsEngine {
  EinsEngine({
    required this.players,
    this.mode = EinsMode.classic,
    Random? rng,
    this.handSize = 7,
    bool stackDraws = true,
    this.callRequired = true,
    this.challengeRule = true,
    this.expansion = false,
  })  : _rng = rng ?? Random.secure(),
        _stackSetting = stackDraws;

  final List<EinsPlayer> players;
  final EinsMode mode;
  final int handSize;
  final Random _rng;
  bool _stackSetting;

  /// Plus-Karten stapeln. Bei Gnadenlos immer an.
  bool get stackDraws => mode == EinsMode.noMercy || _stackSetting;
  set stackDraws(bool v) => _stackSetting = v;

  bool callRequired;

  /// Farbwahl-Strafkarten nur ohne passende Farbe, der Nächste darf anzweifeln.
  bool challengeRule;

  /// Gnadenlos mit Erweiterung: neue Karten und Münzen.
  final bool expansion;

  List<EinsCard> drawPile = [];
  List<EinsCard> discard = [];

  /// Gnadenlos: Karten ausgeschiedener Spieler, kommen beim Mischen zurück.
  List<EinsCard> setAside = [];
  int current = 0;
  int direction = 1;
  late EinsColor color;
  int pendingDraw = 0;
  int pendingValue = 0;
  bool drewThisTurn = false;
  EinsCard? drawnCard;
  EinsPlayer? winner;
  String lastEvent = '';

  bool darkSide = false;
  late List<bool> power;
  late List<bool> out;

  /// Münze je Spieler, null wenn keine oder schon benutzt.
  late List<EinsCoin?> coins;

  /// Der Spieler am Zug muss bis zu dieser Farbe ziehen.
  EinsColor? forcedColorDraw;
  int _forcedExtra = 0;

  bool rouletteVictim = false;

  /// Der Spieler am Zug muss am Glücksrad drehen.
  bool spinPending = false;
  bool raceOpen = false;
  SpinSpace? lastSpin;
  int? revealed;

  /// Glücksrad neu: Alle dürfen zwei Karten pro Zug legen.
  bool doublePlay = false;

  /// Glücksrad neu: Der Spieler am Zug darf noch eine zweite Karte legen.
  bool extraPlay = false;

  int? lastLaunch;
  _Challenge? _challenge;

  int get count => players.length;
  EinsCard get top => discard.last;
  EinsFace get topFace => face(top);
  EinsPlayer get actor => players[current];
  bool get finished => winner != null;
  List<EinsColor> get sideColors => darkSide ? darkColors : lightColors;
  int get activeCount => out.where((o) => !o).length;

  bool get mustSpin => spinPending && !finished;
  bool get mustChooseRoulette => rouletteVictim && !finished;

  /// Der Spieler am Zug darf die zuletzt gelegte Karte anzweifeln.
  bool get canChallenge => !finished && _challenge != null && _challenge!.victim == current;
  int? get challengeOffender => _challenge?.offender;

  List<SpinSpace> get wheel => mode == EinsMode.spinNew ? wheel2025 : wheel2005;

  EinsFace face(EinsCard c) => darkSide && c.dark != null ? c.dark! : c.light;
  EinsFace? otherFace(EinsCard c) => c.dark == null ? null : (darkSide ? c.light : c.dark);

  /// Kehrseite: die Seite, die nach dem Wenden oben liegt.
  EinsFace? get flipNewTop => discard.isEmpty ? null : otherFace(discard.first);

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

  void start({int startPlayer = 0, List<EinsCard>? stacked, List<EinsCoin>? coinChoice}) {
    drawPile = stacked?.toList() ?? (deckFor(mode, _rng, expansion: expansion)..shuffle(_rng));
    discard = [];
    setAside = [];
    darkSide = false;
    power = List.filled(count, true);
    out = List.filled(count, false);
    coins = List.generate(
      count,
      (i) => mode == EinsMode.noMercy && expansion
          ? (coinChoice != null && i < coinChoice.length
              ? coinChoice[i]
              : EinsCoin.values[_rng.nextInt(2)])
          : null,
    );
    for (final p in players) {
      p.hand = [];
    }
    for (var i = 0; i < handSize; i++) {
      for (final p in players) {
        p.hand.add(drawPile.removeLast());
      }
    }
    var i = drawPile.length - 1;
    bool plain(EinsFace f) => f.isNumber && !f.spin && !f.flipMark && f.flexColor == null && f.number < 10;
    while (i > 0 && !plain(drawPile[i].light)) {
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
    _forcedExtra = 0;
    rouletteVictim = false;
    spinPending = false;
    raceOpen = false;
    lastSpin = null;
    revealed = null;
    doublePlay = false;
    extraPlay = false;
    lastLaunch = null;
    _challenge = null;
  }

  bool get _busy =>
      finished || spinPending || rouletteVictim || raceOpen || forcedColorDraw != null;

  /// Passt die Karte ohne Kraftseite?
  bool canPlayNormal(EinsCard c) {
    if (_busy) return false;
    if (drewThisTurn && c != drawnCard) return false;
    final f = face(c);
    if (pendingDraw > 0) {
      if (!stackDraws || extraPlay) return false;
      final v = f.drawValue;
      if (v == 0) return false;
      return v >= pendingValue || (coins[current] == EinsCoin.noMercy && v * 2 >= pendingValue);
    }
    if (f.isWild) return true;
    if (f.color == color) return true;
    final t = topFace;
    if (f.isNumber) return t.isNumber && t.number == f.number;
    return f.symbol == t.symbol;
  }

  /// Kraftkarten: Passt die Zahlenkarte über ihre zweite Farbe?
  bool canPlayFlex(EinsCard c) {
    if (_busy || pendingDraw > 0) return false;
    if (drewThisTurn && c != drawnCard) return false;
    final f = face(c);
    return mode == EinsMode.flex && power[current] && f.flexColor != null && f.flexColor == color;
  }

  bool canPlay(EinsCard c) => canPlayNormal(c) || canPlayFlex(c);

  List<EinsCard> playableCards() => actor.hand.where(canPlay).toList();

  String _who(EinsPlayer p, String du, String er) => p.human ? 'Du $du' : '${p.name} $er';
  String _name(EinsPlayer p) => p.human ? 'Du' : p.name;
  String _dat(EinsPlayer p) => p.human ? 'dir' : p.name;
  static String _cards(int n) => n == 1 ? 'eine Karte' : '$n Karten';

  /// Darf die Kraftseite dieser Aktions- oder Farbwahlkarte genutzt werden?
  bool canUseFlex(int player, EinsCard c) {
    final f = face(c);
    return mode == EinsMode.flex && pendingDraw == 0 && power[player] && f.hasFlex && f.flexColor == null;
  }

  /// Braucht die Karte einen Zielspieler?
  bool needsTarget(EinsCard c, {bool flex = false}) {
    final f = face(c);
    if (f.kind == EinsKind.extremeHit) return true;
    if (mode == EinsMode.noMercy && f.isNumber && f.number == 7) return true;
    if (flex && (f.kind == EinsKind.flexWildTargetDraw || f.kind == EinsKind.flexWildDrawFour)) return true;
    return false;
  }

  /// Muss beim Legen dieser Plus-Karte die Keine-Gnade-Münze genutzt werden?
  bool coinNeeded(EinsCard c) => pendingDraw > 0 && face(c).drawValue < pendingValue;

  /// Darf die Keine-Gnade-Münze für diese Karte genutzt werden?
  bool coinPossible(EinsCard c) => coins[current] == EinsCoin.noMercy && face(c).drawValue > 0;

  List<int> get opponentsOfActor => [
        for (var i = 0; i < count; i++)
          if (i != current && !out[i]) i,
      ];

  bool _hasColor(List<EinsCard> hand, EinsColor col) =>
      hand.any((x) => face(x).color == col);

  /// Spielt eine Karte.
  /// chosen: Farbe für Farbwahl. target: Zielspieler. flex: Kraftseite nutzen.
  /// discardColor: Farbe für Farbwahl-alle-abwerfen. coin: Keine-Gnade-Münze. called: Eins! gerufen.
  void play(
    EinsCard c, {
    EinsColor? chosen,
    int? target,
    bool flex = false,
    EinsColor? discardColor,
    bool coin = false,
    bool called = true,
  }) {
    if (!actor.hand.contains(c) || !canPlay(c)) {
      throw StateError('Karte nicht spielbar');
    }
    if (revealed == current) revealed = null;
    lastLaunch = null;
    _challenge = null;
    final me = current;
    final p = actor;
    final f = face(c);
    final normal = canPlayNormal(c);
    final useFlex = !normal || (flex && (canUseFlex(me, c) || canPlayFlex(c)));
    final hadColor = _hasColor(p.hand.where((x) => x != c).toList(), color);
    final wasExtra = extraPlay;
    extraPlay = false;
    p.hand.remove(c);
    discard.add(c);
    final emptied = p.hand.isEmpty;
    color = f.color ?? (chosen != null && sideColors.contains(chosen) ? chosen : favoriteColor(this, p.hand));
    var steps = 1;
    final targetIndex = target != null && target != me && !out[target] ? target : _defaultTarget();
    final useCoin = f.drawValue > 0 && coins[me] == EinsCoin.noMercy && (coin || coinNeeded(c));
    final value = f.drawValue * (useCoin ? 2 : 1);
    if (useCoin) coins[me] = null;
    void addPenalty() {
      pendingDraw += value;
      pendingValue = value;
      lastEvent = '${useCoin ? 'Keine Gnade! ' : ''}Der Nächste zieht $pendingDraw';
    }

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
        } else if (f.number == 10) {
          steps = 0;
          lastEvent = '${_who(p, 'bist', 'ist')} nochmal dran';
        }
        if (mode == EinsMode.flex && f.flipMark) {
          power[me] = !power[me];
          _checkAllOff();
        }
        if (useFlex) {
          lastEvent = '${_who(p, 'legst', 'legt')} über die Kraftseite auf ${colorName(f.flexColor!)}, '
              'weiter mit ${colorName(f.color!)}';
        }
        if (f.spin && (mode == EinsMode.spin || mode == EinsMode.spinNew)) spinPending = true;
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
      case EinsKind.wildDrawSix:
      case EinsKind.wildDrawTen:
        addPenalty();
      case EinsKind.wildDrawTwo:
      case EinsKind.wildDrawFour:
        addPenalty();
        if (challengeRule && pendingDraw == value) {
          _challenge = _Challenge(me, indexAfter(1), hadColor, value, null);
        }
      case EinsKind.wildReverseDrawFour:
      case EinsKind.wildReverseDrawEight:
        direction = -direction;
        addPenalty();
        // Zu zweit trifft es den Spieler selbst, er darf zurückstapeln
        if (activeCount == 2) steps = 0;
        lastEvent = 'Richtungswechsel. ${steps == 0 ? '${_who(p, 'musst', 'muss')} $pendingDraw ziehen oder stapeln' : lastEvent}';
      case EinsKind.wildDrawColor:
        forcedColorDraw = color;
        _forcedExtra = 0;
        lastEvent = '${_who(nextPlayer, 'ziehst', 'zieht')} bis ${colorName(color)}';
        if (challengeRule) _challenge = _Challenge(me, indexAfter(1), hadColor, 0, color);
      case EinsKind.wildColorRoulette:
        rouletteVictim = true;
        lastEvent = 'Farbroulette für ${_name(nextPlayer)}';
      case EinsKind.discardAll:
      case EinsKind.wildDiscardAll:
        final col = f.kind == EinsKind.discardAll ? f.color! : (discardColor ?? _mostColor(p.hand) ?? color);
        final same = p.hand.where((x) => face(x).color == col).toList();
        for (final x in same) {
          p.hand.remove(x);
          discard.insert(discard.length - 1, x);
        }
        lastEvent = '${_who(p, 'wirfst', 'wirft')} ${same.length} weitere ab';
      case EinsKind.flip:
        darkSide = !darkSide;
        discard = discard.reversed.toList();
        drawPile = drawPile.reversed.toList();
        final nf = topFace;
        color = nf.color ?? (chosen != null && sideColors.contains(chosen) ? chosen : favoriteColor(this, p.hand));
        lastEvent = darkSide ? 'Alles gewendet: dunkle Seite' : 'Alles gewendet: helle Seite';
      case EinsKind.hitTwo:
        final victim = nextPlayer;
        final got = press(victim) + press(victim);
        steps = 2;
        lastEvent = '${_name(victim)} ${victim.human ? 'drückst' : 'drückt'} zweimal: ${_cards(got)}';
      case EinsKind.extremeHit:
        final t = players[targetIndex];
        final got = press(t) + press(t);
        lastEvent = 'Extrem-Treffer: ${_who(t, 'bekommst', 'bekommt')} ${_cards(got)}';
      case EinsKind.wildFinalAttack:
        final victim = nextPlayer;
        final n = p.hand.where((x) => !face(x).isNumber).length;
        if (n >= 7) {
          _give(victim, 25);
          for (final i in opponentsOfActor) {
            if (players[i] != victim) _give(players[i], 5);
          }
          lastEvent = 'Finaler Angriff mit $n Sonderkarten: ${_name(victim)} zieht 25, alle anderen 5';
        } else {
          _give(victim, n);
          lastEvent = 'Finaler Angriff: ${_who(victim, 'ziehst', 'zieht')} ${_cards(n)}';
        }
        steps = 2;
      case EinsKind.wildSuddenDeath:
        var i = me;
        for (var k = 0; k < count; k++) {
          if (!out[i]) {
            while (players[i].hand.length < 24 && _give(players[i], 1) == 1) {}
          }
          i = (i + direction) % count;
        }
        lastEvent = 'Plötzlicher Tod: alle haben jetzt 24 Karten';
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
          addPenalty();
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
        if (useFlex) {
          _give(players[targetIndex], 2);
          lastEvent = 'Kraft: ${_who(players[targetIndex], 'ziehst', 'zieht')} zwei';
        } else {
          lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}';
        }
      case EinsKind.flexWildDrawFour:
        if (useFlex) {
          _give(players[targetIndex], 4);
          lastEvent = 'Kraft: ${_who(players[targetIndex], 'ziehst', 'zieht')} vier';
        } else {
          addPenalty();
          if (challengeRule && pendingDraw == value) {
            _challenge = _Challenge(me, indexAfter(1), hadColor, value, null);
          }
        }
      case EinsKind.wildAllFlip:
        for (var i = 0; i < count; i++) {
          power[i] = !power[i];
        }
        _checkAllOff();
        lastEvent = 'Alle Kraftkarten gewendet';
      case EinsKind.wild:
        lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}';
        if (f.spin && mode == EinsMode.spinNew) spinPending = true;
    }
    if (useFlex && mode == EinsMode.flex) {
      power[me] = false;
      _checkAllOff();
    }
    if (p.hand.isEmpty) {
      spinPending = false;
      winner = p;
      lastEvent = _who(p, 'hast keine Karten mehr', 'hat keine Karten mehr');
      return;
    }
    if (p.hand.length == 1) {
      if (callRequired && !called) {
        final got = mode == EinsMode.extreme ? press(p) + press(p) : _give(p, 2);
        lastEvent = _who(p, 'hast vergessen, Eins! zu rufen: ${_cards(got)}',
            'hat vergessen, Eins! zu rufen: ${_cards(got)}');
      } else {
        lastEvent = lastEvent.isEmpty ? '${_name(p)}: Eins!' : '$lastEvent. ${_name(p)}: Eins!';
      }
    }
    _mercy();
    if (finished) return;
    if (steps == 0 && out[current]) steps = 1;
    if (spinPending) {
      if (mode == EinsMode.spinNew) {
        // Wer die Karte legt, dreht selbst
        lastEvent = '${lastEvent.isEmpty ? '' : '$lastEvent. '}${_who(p, 'drehst', 'dreht')} am Glücksrad';
        drewThisTurn = false;
        drawnCard = null;
        return;
      }
      final spinner = nextPlayer.human ? 'Du drehst' : '${nextPlayer.name} dreht';
      lastEvent = '${lastEvent.isEmpty ? '' : '$lastEvent. '}$spinner am Glücksrad';
    }
    // Glücksrad neu, Feld 2×: nach einer Zahlenkarte darf eine zweite folgen
    if (doublePlay && !wasExtra && f.isNumber && steps == 1 && !spinPending) {
      drewThisTurn = false;
      drawnCard = null;
      if (actor.hand.any(canPlayNormal)) {
        extraPlay = true;
        return;
      }
    }
    _advance(steps);
  }

  /// Glücksrad neu: Nach der ersten Karte auf die zweite verzichten.
  void endTurn() {
    if (!extraPlay) return;
    extraPlay = false;
    _advance(1);
  }

  EinsColor? _mostColor(List<EinsCard> hand) {
    final counts = <EinsColor, int>{};
    for (final x in hand) {
      final col = face(x).color;
      if (col != null) counts[col] = (counts[col] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  int _defaultTarget() {
    final others = opponentsOfActor;
    if (others.isEmpty) return current;
    others.sort((a, b) => players[a].hand.length.compareTo(players[b].hand.length));
    return others.first;
  }

  void _passHands(int dir) {
    final active = [
      for (var i = 0; i < count; i++)
        if (!out[i]) i,
    ];
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

  /// Ziehen, Strafe annehmen oder den Werfer drücken.
  void draw() {
    if (finished || spinPending || rouletteVictim || raceOpen || extraPlay) return;
    if (revealed == current) revealed = null;
    lastLaunch = null;
    _challenge = null;
    final p = actor;
    if (forcedColorDraw != null) {
      final target = forcedColorDraw!;
      forcedColorDraw = null;
      final got = _drawUntil(p, target, wildCounts: false) + _give(p, _forcedExtra);
      _forcedExtra = 0;
      lastEvent = _who(p, 'ziehst ${_cards(got)} bis ${colorName(target)}',
          'zieht ${_cards(got)} bis ${colorName(target)}');
      _mercy();
      if (!finished) _advance(1);
      return;
    }
    if (pendingDraw > 0) {
      final n = pendingDraw;
      pendingDraw = 0;
      pendingValue = 0;
      final got = _give(p, n);
      lastEvent = _who(p, 'ziehst ${_cards(got)}', 'zieht ${_cards(got)}');
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
      var got = 0;
      EinsCard? last;
      while (got < 300) {
        final c = _take();
        if (c == null) break;
        p.hand.add(c);
        got++;
        last = c;
        drewThisTurn = true;
        drawnCard = c;
        if (canPlay(c)) break;
      }
      lastEvent = _who(p, 'ziehst ${_cards(got)}', 'zieht ${_cards(got)}');
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

  /// Anzweifeln: War die Strafkarte erlaubt?
  /// Ob das letzte Anzweifeln berechtigt war.
  bool lastChallengeWon = false;

  void challenge() {
    final ch = _challenge;
    if (!canChallenge || ch == null) return;
    _challenge = null;
    lastChallengeWon = ch.guilty;
    final victim = actor;
    final offender = players[ch.offender];
    if (ch.guilty) {
      int got;
      if (ch.color != null) {
        forcedColorDraw = null;
        got = _drawUntil(offender, ch.color!, wildCounts: false);
      } else {
        pendingDraw -= ch.value;
        if (pendingDraw <= 0) {
          pendingDraw = 0;
          pendingValue = 0;
        }
        got = _give(offender, ch.value);
      }
      lastEvent = 'Zu Recht angezweifelt: ${_who(offender, 'ziehst', 'zieht')} ${_cards(got)}. '
          '${_who(victim, 'bist', 'ist')} dran';
      _mercy();
      return;
    }
    if (ch.color != null) {
      _forcedExtra = 2;
      draw();
      lastEvent = 'Zu Unrecht angezweifelt. $lastEvent';
      return;
    }
    pendingDraw += 2;
    final n = pendingDraw;
    pendingDraw = 0;
    pendingValue = 0;
    final got = _give(victim, n);
    lastEvent = 'Zu Unrecht angezweifelt: ${_who(victim, 'ziehst', 'zieht')} ${_cards(got)}';
    _mercy();
    if (!finished) _advance(1);
  }

  /// Farbroulette: Farbe ansagen und ziehen, bis sie kommt. Die Farbe gilt danach.
  void resolveRoulette(EinsColor chosen) {
    if (!rouletteVictim) return;
    rouletteVictim = false;
    final p = actor;
    final got = _drawUntil(p, chosen, wildCounts: false);
    color = chosen;
    lastEvent = _who(p, 'ziehst ${_cards(got)} bis ${colorName(chosen)}',
        'zieht ${_cards(got)} bis ${colorName(chosen)}');
    _mercy();
    if (!finished) _advance(1);
  }

  /// Gnadenlos-Erweiterung: Gnade-Münze. Ganze Hand weg, sieben neue, Strafe verfällt.
  bool useMercyCoin() {
    if (coins[current] != EinsCoin.mercy || finished || spinPending || raceOpen) return false;
    _mercyCoin(current);
    pendingDraw = 0;
    pendingValue = 0;
    rouletteVictim = false;
    forcedColorDraw = null;
    _challenge = null;
    lastEvent = '${_who(actor, 'nutzt', 'nutzt')} die Gnade-Münze: sieben neue Karten';
    return true;
  }

  void _mercyCoin(int i) {
    coins[i] = null;
    final p = players[i];
    discard.insertAll(0, p.hand);
    p.hand = [];
    _give(p, 7);
  }

  SpinSpace randomSpace() => wheel[_rng.nextInt(wheel.length)];

  /// Glücksrad drehen. Liefert das Feld. Beim Wettrennen folgt [resolveRace].
  SpinSpace spin({SpinSpace? forced, SpinChoice choice = const SpinChoice()}) {
    if (!spinPending) throw StateError('Kein Glücksrad');
    spinPending = false;
    if (revealed == current) revealed = null;
    final space = forced ?? randomSpace();
    lastSpin = space;
    final p = actor;

    // Abgeworfene Karten kommen oben auf die Ablage, eine gewählte Karte liegt ganz oben
    void toTop(List<EinsCard> cards) {
      if (cards.isEmpty) return;
      for (final x in cards) {
        p.hand.remove(x);
      }
      final topCard = cards.firstWhere((x) => x.id == choice.topId, orElse: () => _bestTop(cards, p.hand));
      for (final x in cards) {
        if (x != topCard) discard.add(x);
      }
      discard.add(topCard);
      color = face(topCard).color ?? choice.color ?? favoriteColor(this, p.hand);
    }

    switch (space) {
      case SpinSpace.almostDone:
        if (p.hand.length > 2) {
          var keep = p.hand.where((x) => choice.keep?.contains(x.id) ?? false).toList();
          if (keep.length != 2) {
            keep = (p.hand.toList()..sort((a, b) => _keepScore(b).compareTo(_keepScore(a)))).take(2).toList();
          }
          toTop(p.hand.where((x) => !keep.contains(x)).toList());
        }
        lastEvent = '${_who(p, 'behältst', 'behält')} nur zwei Karten';
      case SpinSpace.discardNumber:
        final numbers = {for (final x in p.hand) if (face(x).isNumber) face(x).number};
        if (numbers.isEmpty) {
          lastEvent = '${_who(p, 'hast', 'hat')} keine Zahl zum Abwerfen';
        } else {
          final n = numbers.contains(choice.number) ? choice.number! : _bestNumber(p.hand);
          final cards = p.hand.where((x) => face(x).isNumber && face(x).number == n).toList();
          toTop(cards);
          lastEvent = '${_who(p, 'wirfst', 'wirft')} ${cards.length} mal die $n ab';
        }
      case SpinSpace.discardColor:
        final colors = {for (final x in p.hand) if (face(x).color != null) face(x).color!};
        if (colors.isEmpty) {
          lastEvent = '${_who(p, 'hast', 'hat')} keine Farbe zum Abwerfen';
        } else {
          final col = colors.contains(choice.color) ? choice.color! : _mostColor(p.hand)!;
          final cards = p.hand.where((x) => face(x).color == col).toList();
          toTop(cards);
          lastEvent = '${_who(p, 'wirfst', 'wirft')} alle ${colorName(col)} ab: ${_cards(cards.length)}';
        }
      case SpinSpace.drawRed:
      case SpinSpace.drawBlue:
        final target = space == SpinSpace.drawRed ? EinsColor.red : EinsColor.blue;
        final got = _drawUntil(p, target, wildCounts: true);
        lastEvent = _who(p, 'ziehst ${_cards(got)} bis ${colorName(target)}',
            'zieht ${_cards(got)} bis ${colorName(target)}');
      case SpinSpace.tradeHands:
        _passHands(1);
        lastEvent = 'Alle geben ihre Hand nach links weiter';
      case SpinSpace.showHand:
        revealed = current;
        lastEvent = '${_who(p, 'zeigst', 'zeigt')} die Hand';
      case SpinSpace.war:
        final w = _war();
        if (w == null) {
          lastEvent = 'Duell fällt aus, niemand hat Zahlen';
        } else {
          lastEvent = '${_name(players[w])} ${players[w].human ? 'gewinnst' : 'gewinnt'} das Duell';
          if (players[w].hand.isEmpty) {
            winner = players[w];
            return space;
          }
          current = w;
          _advance(1);
          return space;
        }
      case SpinSpace.race:
        raceOpen = true;
        lastEvent = 'Wettrennen: Wer zuerst drückt, wirft eine Karte ab';
        return space;
      case SpinSpace.colorDrawRed:
      case SpinSpace.colorDrawYellow:
      case SpinSpace.colorDrawGreen:
      case SpinSpace.colorDrawBlue:
      case SpinSpace.wildColorDraw:
        final target = switch (space) {
          SpinSpace.colorDrawRed => EinsColor.red,
          SpinSpace.colorDrawYellow => EinsColor.yellow,
          SpinSpace.colorDrawGreen => EinsColor.green,
          SpinSpace.colorDrawBlue => EinsColor.blue,
          _ => choice.color != null && lightColors.contains(choice.color) ? choice.color! : _leastColor(p.hand),
        };
        final got = _drawUntil(p, target, wildCounts: false);
        lastEvent = _who(p, 'ziehst ${_cards(got)} bis ${colorName(target)}',
            'zieht ${_cards(got)} bis ${colorName(target)}');
      case SpinSpace.colorDiscard:
        final colors = {for (final x in p.hand) if (face(x).color != null) face(x).color!};
        if (colors.isEmpty) {
          lastEvent = '${_who(p, 'hast', 'hat')} keine Farbe zum Abwerfen';
        } else {
          final col = colors.contains(choice.color) ? choice.color! : _mostColor(p.hand)!;
          final cards = p.hand.where((x) => face(x).color == col).toList();
          for (final x in cards) {
            p.hand.remove(x);
          }
          // Unter die Ablage
          discard.insertAll(0, cards);
          lastEvent = '${_who(p, 'wirfst', 'wirft')} alle ${colorName(col)} ab: ${_cards(cards.length)}';
        }
      case SpinSpace.swapHands:
        final others = opponentsOfActor;
        final t = others.contains(choice.target)
            ? choice.target!
            : (others..sort((a, b) => players[a].hand.length.compareTo(players[b].hand.length))).first;
        final tmp = p.hand;
        p.hand = players[t].hand;
        players[t].hand = tmp;
        lastEvent = '${_who(p, 'tauschst', 'tauscht')} die Hand mit ${_dat(players[t])}';
      case SpinSpace.twice:
        doublePlay = true;
        lastEvent = 'Ab jetzt dürfen alle zwei Karten legen';
    }
    if (mode == EinsMode.spinNew && space != SpinSpace.twice) doublePlay = false;
    if (p.hand.isEmpty) {
      winner = p;
      return space;
    }
    _advance(1);
    return space;
  }

  /// Wettrennen: Der Gewinner wirft eine Karte seiner Wahl ab, sie liegt oben.
  void resolveRace(int winnerIndex, {int? discardId}) {
    if (!raceOpen) return;
    raceOpen = false;
    final w = players[winnerIndex];
    if (w.hand.isNotEmpty) {
      final pick = w.hand.firstWhere(
        (x) => x.id == discardId,
        orElse: () => w.hand.reduce((a, b) => face(b).points > face(a).points ? b : a),
      );
      w.hand.remove(pick);
      discard.add(pick);
      color = face(pick).color ?? favoriteColor(this, w.hand);
    }
    lastEvent = '${_name(w)} ${w.human ? 'warst' : 'war'} am schnellsten';
    if (w.hand.isEmpty) {
      winner = w;
      return;
    }
    current = winnerIndex;
    _advance(1);
  }

  EinsCard _bestTop(List<EinsCard> cards, List<EinsCard> rest) {
    final fav = rest.isEmpty ? null : favoriteColor(this, rest);
    return cards.firstWhere((x) => face(x).color == fav, orElse: () => cards.last);
  }

  int _bestNumber(List<EinsCard> hand) {
    final counts = <int, int>{};
    for (final x in hand) {
      final f = face(x);
      if (f.isNumber) counts[f.number] = (counts[f.number] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  EinsColor _leastColor(List<EinsCard> hand) {
    final counts = {for (final c in lightColors) c: 0};
    for (final x in hand) {
      final col = face(x).color;
      if (col != null && counts.containsKey(col)) counts[col] = counts[col]! + 1;
    }
    // Eine Farbe, die man noch nicht hat, ist im Stapel am häufigsten
    return counts.entries.reduce((a, b) => b.value < a.value ? b : a).key;
  }

  int _keepScore(EinsCard c) {
    final f = face(c);
    if (f.isWild) return 100;
    if (f.color == color) return 50;
    return f.isNumber ? 10 - f.number : 30;
  }

  /// Duell: höchste Zahl, bei Gleichstand die nächsthöhere. Der Gewinner wirft seine Duellkarten ab.
  int? _war() {
    final nums = <int, List<EinsCard>>{};
    for (var i = 0; i < count; i++) {
      if (out[i]) continue;
      final list = players[i].hand.where((x) => face(x).isNumber).toList()
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
    for (final x in played.reversed) {
      players[w].hand.remove(x);
      discard.add(x);
    }
    color = face(discard.last).color ?? color;
    return w;
  }

  /// Kartenwerfer: Oft kommt nichts, manchmal ein ganzer Schwall.
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

  int _drawUntil(EinsPlayer p, EinsColor target, {required bool wildCounts}) {
    var got = 0;
    while (got < 300) {
      final c = _take();
      if (c == null) break;
      p.hand.add(c);
      got++;
      final f = face(c);
      if (f.color == target || (wildCounts && f.isWild)) break;
    }
    return got;
  }

  /// Gnadenlos: Wer 25 oder mehr Karten hat, scheidet aus, außer die Gnade-Münze rettet ihn.
  void _mercy() {
    if (mode != EinsMode.noMercy) return;
    for (var i = 0; i < count; i++) {
      if (out[i] || players[i].hand.length < 25) continue;
      if (coins[i] == EinsCoin.mercy) {
        _mercyCoin(i);
        lastEvent = '$lastEvent. Die Gnade-Münze rettet ${players[i].human ? 'dich' : players[i].name}';
        continue;
      }
      out[i] = true;
      setAside.addAll(players[i].hand);
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
    extraPlay = false;
  }

  EinsCard? _take() {
    if (drawPile.isEmpty && (discard.length > 1 || setAside.isNotEmpty)) {
      final keep = discard.removeLast();
      drawPile = [...discard, ...setAside]..shuffle(_rng);
      discard = [keep];
      setAside = [];
    }
    return drawPile.isEmpty ? null : drawPile.removeLast();
  }

  int get cardCount =>
      drawPile.length +
      discard.length +
      setAside.length +
      players.fold<int>(0, (s, p) => s + p.hand.length);
}

EinsColor favoriteColor(EinsEngine e, List<EinsCard> hand) {
  final counts = <EinsColor, int>{};
  for (final c in hand) {
    final col = e.face(c).color;
    if (col != null && e.sideColors.contains(col)) counts[col] = (counts[col] ?? 0) + 1;
  }
  if (counts.isEmpty) return e.sideColors.first;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

typedef EinsChoice = ({
  EinsCard? card,
  EinsColor? color,
  int? target,
  bool flex,
  EinsColor? discardColor,
  bool coin,
});

const EinsChoice _noChoice = (card: null, color: null, target: null, flex: false, discardColor: null, coin: false);

EinsChoice einsBotChoice(EinsEngine e, Random rng) {
  final hand = e.actor.hand;
  var options = e.playableCards();
  // Mit Anzweifel-Regel legen Computer Strafkarten meist nur erlaubt
  if (e.challengeRule) {
    final hasColor = hand.any((x) => e.face(x).color == e.color);
    if (hasColor && rng.nextDouble() > 0.12) {
      final legal = options.where((x) => !e.face(x).challengeable || e.pendingDraw > 0).toList();
      if (legal.isNotEmpty) options = legal;
    }
  }
  if (options.isEmpty) return _noChoice;
  final danger = e.nextPlayer.hand.length <= 2;
  final fewest = e.opponentsOfActor.map((i) => e.players[i].hand.length).fold<int>(999, min);
  double score(EinsCard c) {
    final f = e.face(c);
    var s = 0.0;
    if (f.drawValue > 0) s += danger ? 25 : (f.isWild ? -20 : 4);
    switch (f.kind) {
      case EinsKind.wild:
      case EinsKind.wildAllFlip:
      case EinsKind.flexWildAllDraw:
      case EinsKind.flexWildTargetDraw:
        s -= 25;
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
      case EinsKind.wildDiscardAll:
        s += 10;
      case EinsKind.extremeHit:
      case EinsKind.wildFinalAttack:
        s += danger ? 20 : -5;
      case EinsKind.wildSuddenDeath:
        s += hand.length <= 6 ? 15 : -40;
      case EinsKind.number:
        s += f.number * 0.3;
        if (f.number == 10) s += 8;
        if (e.mode == EinsMode.noMercy && f.number == 7) s += fewest < hand.length - 2 ? 20 : -10;
        if (f.spin) s += 6;
        if (e.mode == EinsMode.flex && !e.canPlayNormal(c)) s -= 6;
      default:
        break;
    }
    if (f.color != null) s += hand.where((h) => e.face(h).color == f.color && h != c).length * 2;
    return s + rng.nextDouble();
  }

  final scored = {for (final c in options) c: score(c)};
  options.sort((a, b) => scored[b]!.compareTo(scored[a]!));
  final card = options.first;
  final f = e.face(card);
  final flex = !e.canPlayNormal(card) ||
      (e.canUseFlex(e.current, card) && (f.kind != EinsKind.flexDrawTwo || e.activeCount > 2));
  final rest = hand.where((h) => h != card).toList();
  final color = f.isWild || f.kind == EinsKind.flip ? favoriteColor(e, rest) : null;
  int? target;
  if (e.needsTarget(card, flex: flex)) {
    final others = e.opponentsOfActor
      ..sort((a, b) => e.players[a].hand.length.compareTo(e.players[b].hand.length));
    target = others.first;
  }
  EinsColor? discardColor;
  if (f.kind == EinsKind.wildDiscardAll) {
    final counts = <EinsColor, int>{};
    for (final h in rest) {
      final col = e.face(h).color;
      if (col != null) counts[col] = (counts[col] ?? 0) + 1;
    }
    if (counts.isNotEmpty) discardColor = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
  final coin = e.coinPossible(card) && (e.coinNeeded(card) || danger);
  return (card: card, color: color, target: target, flex: flex, discardColor: discardColor, coin: coin);
}

/// Soll der Computer anzweifeln? Er weiß nichts über die Hand, also Bauchgefühl.
bool einsBotChallenges(EinsEngine e, Random rng) => e.canChallenge && rng.nextDouble() < 0.3;

/// Soll der Computer seine Gnade-Münze nutzen?
bool einsBotMercy(EinsEngine e) =>
    e.coins[e.current] == EinsCoin.mercy && (e.actor.hand.length >= 18 || e.actor.hand.length + e.pendingDraw >= 22);

void _botPlay(EinsEngine e, EinsChoice c) => e.play(
      c.card!,
      chosen: c.color,
      target: c.target,
      flex: c.flex,
      discardColor: c.discardColor,
      coin: c.coin,
    );

/// Ein ganzer Zug eines Computer-Gegners, ohne Pausen. Für Tests.
void einsBotTurn(EinsEngine e, Random rng) {
  if (e.finished) return;
  if (e.raceOpen) {
    final active = [
      for (var i = 0; i < e.count; i++)
        if (!e.out[i]) i,
    ];
    e.resolveRace(active[rng.nextInt(active.length)]);
    return;
  }
  if (e.mustSpin) {
    e.spin();
    return;
  }
  if (einsBotMercy(e)) e.useMercyCoin();
  if (e.mustChooseRoulette) {
    e.resolveRoulette(favoriteColor(e, e.actor.hand));
    return;
  }
  if (einsBotChallenges(e, rng)) {
    final me = e.current;
    e.challenge();
    // Zu Unrecht angezweifelt: Der Zug ist vorbei
    if (e.finished || e.current != me) return;
  }
  final choice = einsBotChoice(e, rng);
  if (choice.card != null) {
    _botPlay(e, choice);
    if (e.extraPlay && !e.finished) {
      final second = einsBotChoice(e, rng);
      if (second.card != null) {
        _botPlay(e, second);
      } else {
        e.endTurn();
      }
    }
    return;
  }
  e.draw();
  if (e.drewThisTurn && !e.finished) {
    final again = einsBotChoice(e, rng);
    if (again.card != null) {
      _botPlay(e, again);
      if (e.extraPlay && !e.finished) e.endTurn();
    } else {
      e.pass();
    }
  }
}
