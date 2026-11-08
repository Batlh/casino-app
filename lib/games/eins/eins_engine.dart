import 'dart:math';

enum EinsColor { red, yellow, green, blue }

enum EinsKind { number, skip, reverse, drawTwo, wild, wildDrawFour }

String colorName(EinsColor c) => switch (c) {
      EinsColor.red => 'Rot',
      EinsColor.yellow => 'Gelb',
      EinsColor.green => 'Grün',
      EinsColor.blue => 'Blau',
    };

class EinsCard {
  const EinsCard(this.id, this.kind, {this.color, this.number = -1});

  /// Jede der 108 Karten hat eine eigene Nummer, doppelte Karten bleiben unterscheidbar.
  final int id;
  final EinsKind kind;

  /// null bei Farbwahl und Plus-Vier.
  final EinsColor? color;
  final int number;

  bool get isWild => color == null;

  String get label => switch (kind) {
        EinsKind.number => '$number',
        EinsKind.drawTwo => '+2',
        EinsKind.wildDrawFour => '+4',
        EinsKind.skip => 'Aussetzen',
        EinsKind.reverse => 'Richtungswechsel',
        EinsKind.wild => 'Farbwahl',
      };

  String get spokenName =>
      color == null ? label : '${colorName(color!)} $label';

  @override
  bool operator ==(Object other) => other is EinsCard && other.id == id;

  @override
  int get hashCode => id;
}

/// 108 Karten: je Farbe eine Null, zweimal 1 bis 9, je zweimal Aussetzen,
/// Richtungswechsel und Plus-Zwei, dazu je vier Farbwahl und Plus-Vier.
List<EinsCard> einsDeck() {
  var id = 0;
  final out = <EinsCard>[];
  for (final c in EinsColor.values) {
    out.add(EinsCard(id++, EinsKind.number, color: c, number: 0));
    for (var n = 1; n <= 9; n++) {
      for (var k = 0; k < 2; k++) {
        out.add(EinsCard(id++, EinsKind.number, color: c, number: n));
      }
    }
    for (final kind in [EinsKind.skip, EinsKind.reverse, EinsKind.drawTwo]) {
      for (var k = 0; k < 2; k++) {
        out.add(EinsCard(id++, kind, color: c));
      }
    }
  }
  for (var k = 0; k < 4; k++) {
    out.add(EinsCard(id++, EinsKind.wild));
    out.add(EinsCard(id++, EinsKind.wildDrawFour));
  }
  return out;
}

class EinsPlayer {
  EinsPlayer(this.name, {this.human = false});
  final String name;
  final bool human;
  List<EinsCard> hand = [];
}

class EinsEngine {
  EinsEngine({
    required this.players,
    Random? rng,
    this.handSize = 7,
    this.stackDraws = true,
    this.callRequired = true,
  }) : _rng = rng ?? Random.secure();

  final List<EinsPlayer> players;
  final int handSize;
  final Random _rng;

  /// Plus-Karten dürfen gestapelt werden: auf +2 eine +2 oder +4, auf +4 nur +4.
  bool stackDraws;

  /// Wer auf eine Karte kommt, muss „Eins!“ rufen, sonst zieht er zwei.
  bool callRequired;

  List<EinsCard> drawPile = [];
  List<EinsCard> discard = [];
  int current = 0;
  int direction = 1;
  late EinsColor color;
  int pendingDraw = 0;
  bool pendingFour = false;
  bool drewThisTurn = false;
  EinsCard? drawnCard;
  EinsPlayer? winner;
  String lastEvent = '';

  EinsCard get top => discard.last;
  EinsPlayer get actor => players[current];
  bool get finished => winner != null;
  int get count => players.length;

  int indexAfter(int steps) => (current + direction * steps) % count;
  EinsPlayer get nextPlayer => players[indexAfter(1)];

  void start({int startPlayer = 0, List<EinsCard>? stacked}) {
    drawPile = stacked?.toList() ?? (einsDeck()..shuffle(_rng));
    discard = [];
    for (final p in players) {
      p.hand = [];
    }
    for (var i = 0; i < handSize; i++) {
      for (final p in players) {
        p.hand.add(drawPile.removeLast());
      }
    }
    // Erste offene Karte: eine Zahlenkarte
    var i = drawPile.length - 1;
    while (i > 0 && drawPile[i].kind != EinsKind.number) {
      i--;
    }
    discard.add(drawPile.removeAt(i));
    color = top.color!;
    current = startPlayer;
    direction = 1;
    pendingDraw = 0;
    pendingFour = false;
    drewThisTurn = false;
    drawnCard = null;
    winner = null;
    lastEvent = '';
  }

  bool canPlay(EinsCard c) {
    if (finished) return false;
    if (drewThisTurn && c != drawnCard) return false;
    if (pendingDraw > 0) {
      if (!stackDraws) return false;
      if (pendingFour) return c.kind == EinsKind.wildDrawFour;
      return c.kind == EinsKind.drawTwo || c.kind == EinsKind.wildDrawFour;
    }
    if (c.isWild) return true;
    if (c.color == color) return true;
    if (c.kind == EinsKind.number) {
      return top.kind == EinsKind.number && top.number == c.number;
    }
    return c.kind == top.kind;
  }

  List<EinsCard> playableCards() => actor.hand.where(canPlay).toList();

  String _who(EinsPlayer p, String du, String er) =>
      p.human ? 'Du $du' : '${p.name} $er';

  /// called: ob „Eins!“ gerufen wurde. Computer-Gegner rufen immer.
  void play(EinsCard c, {EinsColor? chosen, bool called = true}) {
    if (!canPlay(c) || !actor.hand.contains(c)) {
      throw StateError('Karte nicht spielbar');
    }
    final p = actor;
    p.hand.remove(c);
    discard.add(c);
    color = c.color ?? chosen ?? EinsColor.values[_rng.nextInt(4)];
    var steps = 1;
    switch (c.kind) {
      case EinsKind.skip:
        steps = 2;
        lastEvent = nextPlayer.human ? 'Du setzt aus' : '${nextPlayer.name} setzt aus';
      case EinsKind.reverse:
        direction = -direction;
        if (count == 2) steps = 2;
        lastEvent = 'Richtungswechsel';
      case EinsKind.drawTwo:
        pendingDraw += 2;
        pendingFour = false;
        lastEvent = 'Plus zwei, der Nächste zieht $pendingDraw';
      case EinsKind.wildDrawFour:
        pendingDraw += 4;
        pendingFour = true;
        lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}, der Nächste zieht $pendingDraw';
      case EinsKind.wild:
        lastEvent = '${_who(p, 'wählst', 'wählt')} ${colorName(color)}';
      case EinsKind.number:
        lastEvent = '';
    }
    if (p.hand.isEmpty) {
      winner = p;
      lastEvent = _who(p, 'hast keine Karten mehr', 'hat keine Karten mehr');
      return;
    }
    if (p.hand.length == 1) {
      if (callRequired && !called) {
        for (var i = 0; i < 2; i++) {
          final x = _take();
          if (x != null) p.hand.add(x);
        }
        lastEvent = _who(p, 'hast vergessen, Eins! zu rufen, und ziehst 2', 'hat vergessen, Eins! zu rufen, und zieht 2');
      } else {
        lastEvent = lastEvent.isEmpty ? '${p.human ? 'Du' : p.name}: Eins!' : '$lastEvent. ${p.human ? 'Du' : p.name}: Eins!';
      }
    }
    _advance(steps);
  }

  void draw() {
    if (finished) return;
    final p = actor;
    if (pendingDraw > 0) {
      final n = pendingDraw;
      pendingDraw = 0;
      pendingFour = false;
      var got = 0;
      for (var i = 0; i < n; i++) {
        final c = _take();
        if (c == null) break;
        p.hand.add(c);
        got++;
      }
      lastEvent = _who(p, 'ziehst $got', 'zieht $got');
      _advance(1);
      return;
    }
    if (drewThisTurn) return;
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

  void pass() {
    if (drewThisTurn) {
      lastEvent = _who(actor, 'ziehst', 'zieht');
      _advance(1);
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

EinsColor favoriteColor(List<EinsCard> hand, Random rng) {
  final counts = <EinsColor, int>{};
  for (final c in hand) {
    if (c.color != null) counts[c.color!] = (counts[c.color!] ?? 0) + 1;
  }
  if (counts.isEmpty) return EinsColor.values[rng.nextInt(4)];
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

({EinsCard? card, EinsColor? color}) einsBotChoice(EinsEngine e, Random rng) {
  final hand = e.actor.hand;
  final options = e.playableCards();
  if (options.isEmpty) return (card: null, color: null);
  final danger = e.nextPlayer.hand.length <= 2;
  double score(EinsCard c) {
    var s = 0.0;
    switch (c.kind) {
      case EinsKind.wildDrawFour:
        s += danger ? 20 : -40;
      case EinsKind.wild:
        s -= 30;
      case EinsKind.drawTwo:
      case EinsKind.skip:
      case EinsKind.reverse:
        s += danger ? 25 : 2;
      case EinsKind.number:
        s += c.number * 0.3;
    }
    if (c.color != null) {
      s += hand.where((h) => h.color == c.color && h != c).length * 2;
    }
    return s + rng.nextDouble();
  }

  options.sort((a, b) => score(b).compareTo(score(a)));
  final card = options.first;
  final color = card.isWild
      ? favoriteColor(hand.where((h) => h != card).toList(), rng)
      : null;
  return (card: card, color: color);
}

void einsBotTurn(EinsEngine e, Random rng) {
  final choice = einsBotChoice(e, rng);
  if (choice.card != null) {
    e.play(choice.card!, chosen: choice.color);
    return;
  }
  e.draw();
  if (e.drewThisTurn) {
    final again = einsBotChoice(e, rng);
    if (again.card != null) {
      e.play(again.card!, chosen: again.color);
    } else {
      e.pass();
    }
  }
}
