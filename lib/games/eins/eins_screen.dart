import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/guides.dart';
import '../../ui/settings_sheet.dart';
import '../../ui/widgets.dart';
import '../board/seats.dart';
import '../cards/card_widgets.dart';
import '../cards/rewards.dart';
import 'eins_card.dart';
import 'eins_engine.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const einsRewardPerOpponent = 50;

/// Schwere Spielweisen zahlen mehr.
double einsModeFactor(EinsMode mode, {bool expansion = false}) => switch (mode) {
      EinsMode.classic => 1.0,
      EinsMode.flip || EinsMode.spin || EinsMode.spinNew || EinsMode.flex => 1.25,
      EinsMode.extreme => 1.5,
      EinsMode.noMercy => expansion ? 2.0 : 1.5,
    };

/// Reihenfolge auf der Hand: nach Farbe, dann Zahl, Sonderkarten am Ende.
List<EinsCard> sortedEins(EinsEngine e, List<EinsCard> cards) {
  int key(EinsCard c) {
    final f = e.face(c);
    return (f.color?.index ?? 9) * 100 + (f.kind == EinsKind.number ? f.number : 20 + f.kind.index);
  }

  return cards.toList()..sort((a, b) => key(a).compareTo(key(b)));
}

/// Kurze Regeln je Spielweise für das Regelblatt.
List<String> modeRules(EinsMode m) {
  const base = [
    'Lege eine Karte gleicher Farbe, Zahl oder gleichen Symbols. Farbwahl-Karten passen immer.',
    'Wer nicht legen kann oder will, zieht eine Karte. Passt sie, darfst du sie sofort legen.',
    'Bei der vorletzten Karte musst du Eins! rufen, sonst gibt es Strafkarten (in den Einstellungen abschaltbar).',
    'Wer zuerst keine Karten mehr hat, gewinnt 50 Münzen pro Gegner.',
  ];
  const challenge =
      'Anzweifeln (in den Einstellungen abschaltbar): Farbwahl plus vier darf man nur legen, wenn man die liegende Farbe nicht hat. '
      'Der Nächste darf anzweifeln. Zu Recht: Der Leger zieht selbst. Zu Unrecht: Der Zweifler zieht zwei mehr.';
  return switch (m) {
    EinsMode.classic => [
        ...base,
        'Aussetzen, Richtungswechsel, Plus zwei, Farbwahl und Farbwahl plus vier.',
        'Plus-Karten dürfen gestapelt werden, wenn das in den Einstellungen an ist.',
        challenge,
      ],
    EinsMode.flip => [
        ...base,
        'Jede Karte hat eine helle und eine dunkle Seite. Bei den Gegnern und auf dem Stapel siehst du die jeweils andere Seite.',
        'Die Wendekarte dreht alles um: Hand, Stapel und Ablage. Die Ablage wird als Ganzes umgedreht, oben liegt danach die bisher unterste Karte mit ihrer anderen Seite. Ist sie eine Aktionskarte, passiert nichts. Ist sie eine Farbwahl, bestimmt der Wender die Farbe.',
        'Hell: Plus eins, Aussetzen, Richtungswechsel, Farbwahl plus zwei.',
        'Dunkel: Plus fünf, Alle setzen aus (du bist gleich nochmal dran), Farbwahl bis zur Farbe: Der Nächste zieht, bis die gewählte Farbe kommt. Farbwahl-Karten zählen dabei nicht.',
        'Anzweifeln gilt hier für Farbwahl plus zwei und Farbwahl bis zur Farbe.',
      ],
    EinsMode.noMercy => [
        ...base,
        'Plus-Karten bis plus zehn. Gestapelt wird immer, mit gleichem oder höherem Wert, Farbe egal.',
        'Kannst du nicht legen, ziehst du, bis eine Karte passt, und musst sie legen.',
        'Sieben: Tausche die Hand mit einem Gegner deiner Wahl. Null: Alle geben ihre Hand in Spielrichtung weiter.',
        'Alle abwerfen: Wirf zusätzlich alle Karten dieser Farbe ab. Alle setzen aus: Du bist gleich nochmal dran.',
        'Richtungswechsel plus vier: Erst die Richtung drehen, dann zieht der Nächste. Zu zweit trifft es dich selbst, du darfst aber zurückstapeln.',
        'Farbroulette: Der Nächste sagt eine Farbe an und zieht, bis sie kommt. Farbwahl-Karten zählen nicht. Die angesagte Farbe gilt danach.',
        'Wer 25 Karten oder mehr hat, scheidet aus. Seine Karten kommen erst beim nächsten Mischen zurück. Wer als Letzter übrig ist, gewinnt auch.',
        'Erweiterung (Einstellungen): 10er (nochmal dran), Farbwahl alle abwerfen (eine Farbe deiner Wahl), Richtungswechsel plus acht, Finaler Angriff (der Nächste zieht eine Karte pro Sonderkarte in deiner Hand, ab sieben 25 und alle anderen 5), Plötzlicher Tod (alle füllen auf 24 Karten auf).',
        'Münzen der Erweiterung, einmal pro Runde: Gnade wirft deine ganze Hand ab, du ziehst sieben neue und eine Strafe verfällt. Sie rettet dich auch automatisch vor dem Ausscheiden. Keine Gnade verdoppelt den Wert einer Plus-Karte, auch beim Stapeln.',
      ],
    EinsMode.extreme => [
        ...base.take(1),
        'Statt zu ziehen drückst du den Kartenwerfer. Er spuckt keine, ein paar oder viele Karten aus. Danach ist dein Zug vorbei. Drücken darfst du auch, wenn du legen könntest.',
        'Zweimal drücken: Der Nächste drückt zweimal und setzt aus.',
        'Extrem-Treffer: Farbwahl. Du wählst einen beliebigen Gegner, für den zweimal gedrückt wird. Danach geht es normal weiter.',
        'Alle abwerfen: Wirf alle Karten dieser Farbe ab.',
        'Zu zweit: Richtungswechsel und Aussetzen lassen dich gleich nochmal legen.',
        'Vergessenes Eins! kostet zweimal drücken.',
        base.last,
      ],
    EinsMode.spin => [
        ...base,
        'Wie Spin von 2005. Je Farbe sind die Karten 1 bis 5 einmal mit Wirbel. Wer eine davon legt, lässt den Nächsten am Glücksrad drehen, das ist dessen Zug.',
        'Fast fertig: Behalte nur zwei Karten deiner Wahl. Zahl abwerfen und Farbe abwerfen: Wirf alle Karten einer Zahl oder Farbe ab. Du wählst, welche abgeworfene Karte oben liegt, sie bestimmt das weitere Spiel.',
        'Zieh bis Rot und Zieh bis Blau: Ziehen, bis die Farbe oder eine Farbwahl kommt.',
        'Hände weitergeben: Alle geben ihre Hand nach links. Hand zeigen: Deine Karten liegen offen, bis du wieder dran bist.',
        'Duell: Alle zeigen ihre höchste Zahl, bei Gleichstand die nächste. Der Gewinner wirft seine Duellkarten ab, danach ist der Spieler nach ihm dran.',
        'Wettrennen: Wer zuerst drückt, wirft eine Karte seiner Wahl ab.',
        challenge,
      ],
    EinsMode.spinNew => [
        ...base,
        'Wie Spin von 2025. Glücksradkarten: je Farbe die 1 bis 5 einmal und vier Farbwahl-Karten. Wer eine legt, dreht selbst.',
        'Zieh Rot, Gelb, Grün, Blau: Ziehen, bis diese Farbe kommt. Wunschfarbe ziehen: Du wählst die Farbe und ziehst bis zu ihr.',
        'Farbe abwerfen: Wirf alle Karten einer Farbe deiner Wahl unter die Ablage. Hände tauschen: mit einem Gegner deiner Wahl.',
        'Zwei Karten: Ab dem Nächsten darf jeder nach einer Zahlenkarte noch eine zweite Karte legen, bis wieder gedreht wird.',
        challenge,
      ],
    EinsMode.flex => [
        ...base,
        'Jeder hat eine Kraftkarte, die an oder aus ist. Ist sie an, darfst du die Kraftseite einer Karte nutzen. Danach ist sie aus. Sind alle aus, gehen alle wieder an.',
        'Zahlen mit farbiger Ecke haben eine zweite Farbe. Mit Kraft darfst du sie in dieser Farbe legen, weiter geht es aber mit der Grundfarbe.',
        'Karten mit goldenem Blitz: Aussetzen lässt alle aussetzen, Richtungswechsel lässt zusätzlich aussetzen, Plus zwei lässt alle anderen eine ziehen. Farbwahl-Karten lassen alle anderen zwei ziehen oder einen Gegner deiner Wahl zwei oder vier.',
        'Zahlen mit weißem Kreispfeil schalten deine eigene Kraft um. Kraftwechsel für alle schaltet alle um.',
        challenge,
      ],
  };
}

class EinsScreen extends StatefulWidget {
  const EinsScreen({super.key, this.mode});

  /// Feste Spielweise, sonst die zuletzt gewählte.
  final EinsMode? mode;

  @override
  State<EinsScreen> createState() => _EinsScreenState();
}

class _EinsScreenState extends State<EinsScreen> {
  final _rng = math.Random.secure();
  /// Plätze am Tisch; mehrere Menschen geben das Gerät weiter.
  List<Seat> _seats = const [Seat('Du', human: true), Seat('Helga'), Seat('Otto')];
  int get _opponents => _seats.length - 1;
  int get _humans => _seats.where((s) => s.human).length;
  int get _bots => _seats.length - _humans;

  /// Wessen Hand gezeigt wird, und ob sie gerade verdeckt ist (Gerät wird weitergegeben).
  int _viewer = 0;
  bool _covered = false;
  int _round = 0;
  late EinsMode _mode;
  late EinsEngine _e;
  bool _running = false;
  bool _rewarded = false;
  bool _called = false;
  bool _started = false;

  /// Glücksrad gerade sichtbar und in Bewegung.
  bool _spinning = false;
  bool _wheelVisible = false;
  double _wheelTurns = 0;
  double _wheelFrom = 0;

  /// Wettrennen: wartet auf den ersten Ruf.
  Completer<int>? _race;

  AppScope get _app => AppScope.of(context);
  /// Alle Menschen sind mit 25 Karten raus.
  bool get _humanOut => [
        for (var i = 0; i < _e.count; i++)
          if (_e.players[i].human) _e.out[i],
      ].every((x) => x);
  bool get _over => _e.finished || _humanOut;

  double get _factor => einsModeFactor(_mode, expansion: _e.expansion);
  int get _winReward => (einsRewardPerOpponent * _bots * _factor).round();

  /// Trostpreis: je Gegner mit mehr Karten oder schon ausgeschieden.
  int get _placeReward {
    if (_humanOut || _humans != 1) return 0;
    final me = _seats.indexWhere((x) => x.human);
    final mine = _e.players[me].hand.length;
    var beaten = 0;
    for (var i = 0; i < _e.players.length; i++) {
      if (i != me && (_e.out[i] || _e.players[i].hand.length > mine)) beaten++;
    }
    return placeReward(beaten, factor: _factor);
  }
  bool get _myTurn =>
      !_over && _e.actor.human && !_running && !_spinning && !_covered && _e.current == _viewer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _mode = widget.mode ?? _app.settings.einsMode;
    final saved = _app.settings.loadGame('seats.eins');
    if (saved != null) {
      try {
        final list = [for (final j in saved['seats'] as List) Seat.fromJson(j as Map<String, dynamic>)];
        if (list.length >= 2 && list.any((x) => x.human)) _seats = list;
      } catch (_) {
        // Standard behalten
      }
    }
    _setup();
  }

  void _setup() {
    final offset = _rng.nextInt(_names.length);
    final settings = _app.settings;
    var bot = 0;
    final expansion = _mode == EinsMode.noMercy && settings.einsExpansion;
    _e = EinsEngine(
      players: [
        for (final seat in _seats)
          seat.human ? EinsPlayer(seat.name, human: true) : EinsPlayer(_names[(offset + bot++) % _names.length]),
      ],
      mode: _mode,
      rng: _rng,
      stackDraws: settings.einsStackDraws,
      callRequired: settings.einsCallRequired,
      challengeRule: settings.einsChallenge,
      expansion: expansion,
    )..start(startPlayer: _round % _seats.length);
    if (expansion) WidgetsBinding.instance.addPostFrameCallback((_) => _askCoin());
    _rewarded = false;
    _called = false;
    _wheelVisible = false;
    _spinning = false;
    _race = null;
    _viewer = _seats.indexWhere((x) => x.human);
    _covered = false;
    _syncViewer();
  }

  /// Ist ein anderer Mensch dran, wird die Hand verdeckt, bis er das Gerät hat.
  void _syncViewer() {
    if (_over || !_e.actor.human || _e.current == _viewer) return;
    _viewer = _e.current;
    _covered = _humans > 1;
  }

  /// Gnadenlos-Erweiterung: Seite der eigenen Münze zu Rundenbeginn festlegen.
  Future<void> _askCoin() async {
    for (var i = 0; i < _e.count; i++) {
      if (!mounted) return;
      if (!_e.players[i].human) continue;
      final pick = await showChoiceSheet(
        context,
        title: _humans > 1 ? '${_e.players[i].name}: Welche Seite deiner Münze?' : 'Welche Seite deiner Münze?',
        options: const [
          'Gnade: einmal die ganze Hand gegen sieben neue tauschen',
          'Keine Gnade: einmal eine Plus-Karte verdoppeln',
        ],
      );
      if (!mounted || pick == null) continue;
      setState(() => _e.coins[i] = pick == 0 ? EinsCoin.mercy : EinsCoin.noMercy);
    }
  }

  void _newRound() {
    setState(() {
      _round++;
      _setup();
    });
    _app.sfx.play(Sound.card);
    _pump();
  }

  Future<void> _askOpponents() async {
    final seats = await showSeatSetup(context, gameId: 'eins', title: 'Eins!', minSeats: 2, maxSeats: 4);
    if (seats == null || !mounted) return;
    _seats = seats;
    _newRound();
  }

  Future<void> _askMode() async {
    final m = await showModalBottomSheet<EinsMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final p = Palette.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Spielweise', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final m in EinsMode.values)
                    Card(
                      color: m == _mode ? p.accent.withValues(alpha: 0.25) : p.panel,
                      child: ListTile(
                        title: Text(
                          modeName(m),
                          style: TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 17),
                        ),
                        subtitle: Text(modeBlurb(m), style: TextStyle(color: p.inkSoft, fontSize: 14)),
                        onTap: () => Navigator.of(context).pop(m),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (m == null || !mounted) return;
    _mode = m;
    _app.settings.einsMode = m;
    _newRound();
  }

  Future<int?> _askTarget(String title) {
    final ids = _e.opponentsOfActor;
    return showChoiceSheet(
      context,
      title: title,
      options: [for (final i in ids) '${_e.players[i].name} (${_e.players[i].hand.length} Karten)'],
    ).then((pick) => pick == null ? null : ids[pick]);
  }

  Future<void> _play(EinsCard c) async {
    if (!_myTurn || !_e.canPlay(c)) return;
    final f = _e.face(c);
    var flex = false;
    if (_e.canUseFlex(_e.current, c)) {
      final pick = await showChoiceSheet(
        context,
        title: 'Kraft nutzen?',
        options: ['Kraft: ${f.flexEffect}', 'Normal: ${f.label}'],
      );
      if (pick == null || !mounted || !_myTurn) return;
      flex = pick == 0;
    }
    var coin = false;
    if (_e.coinPossible(c)) {
      if (_e.coinNeeded(c)) {
        coin = true;
      } else {
        final pick = await showChoiceSheet(
          context,
          title: 'Keine-Gnade-Münze einsetzen?',
          options: ['Ja, +${f.drawValue * 2} statt +${f.drawValue}', 'Nein, normal legen'],
        );
        if (pick == null || !mounted || !_myTurn) return;
        coin = pick == 0;
      }
    }
    int? target;
    if (_e.needsTarget(c, flex: flex)) {
      target = await _askTarget(switch (f.kind) {
        EinsKind.number => 'Mit wem tauschen?',
        EinsKind.extremeHit => 'Wen triffst du?',
        _ => 'Wer soll ziehen?',
      });
      if (target == null || !mounted || !_myTurn) return;
    }
    EinsColor? discardColor;
    if (f.kind == EinsKind.wildDiscardAll) {
      final present = [
        for (final col in _e.sideColors)
          if (_e.actor.hand.any((x) => x != c && _e.face(x).color == col)) col,
      ];
      if (present.isNotEmpty) {
        discardColor = await showColorPicker(context, colors: present, title: 'Welche Farbe abwerfen?');
        if (discardColor == null || !mounted || !_myTurn) return;
      }
    }
    EinsColor? chosen;
    final restAfter = _e.actor.hand.length - 1;
    if (f.isWild && restAfter > 0) {
      chosen = await showColorPicker(
        context,
        colors: _e.sideColors,
        title: f.kind == EinsKind.wildDrawColor ? 'Bis zu welcher Farbe ziehen?' : 'Farbe wählen',
      );
      if (chosen == null || !mounted || !_myTurn) return;
    } else if (f.kind == EinsKind.flip && (_e.flipNewTop?.isWild ?? false) && restAfter > 0) {
      chosen = await showColorPicker(
        context,
        colors: _e.darkSide ? lightColors : darkColors,
        title: 'Nach dem Wenden liegt eine Farbwahl oben',
      );
      if (chosen == null || !mounted || !_myTurn) return;
    }
    final callBonus = _called && _e.actor.hand.length == 2;
    _e.play(
      c,
      chosen: chosen,
      target: target,
      flex: flex,
      discardColor: discardColor,
      coin: coin,
      called: _called,
    );
    _called = false;
    if (callBonus && !_e.finished && _bots > 0) _app.wallet.credit(callReward);
    _app.sfx.play(Sound.card);
    setState(() {});
    _after();
  }

  void _challengeTap() {
    if (!_myTurn || !_e.canChallenge) return;
    _e.challenge();
    _app.sfx.play(Sound.chip);
    if (_e.lastChallengeWon && _bots > 0) _app.wallet.credit(challengeReward);
    setState(() {});
    _after();
  }

  void _mercyTap() {
    if (!_myTurn) return;
    if (_e.useMercyCoin()) {
      _app.sfx.play(Sound.coin);
      setState(() {});
    }
  }

  void _draw() {
    if (!_myTurn) return;
    if (_e.mustSpin) {
      _humanSpin();
      return;
    }
    if (_e.mustChooseRoulette) {
      _humanRoulette();
      return;
    }
    if (_e.extraPlay) {
      _e.endTurn();
      setState(() {});
      _after();
      return;
    }
    if (_e.drewThisTurn && _e.pendingDraw == 0 && _e.forcedColorDraw == null) return;
    _e.draw();
    _app.sfx.play(Sound.card);
    setState(() {});
    _after();
  }

  Future<void> _humanRoulette() async {
    final c = await showColorPicker(context, colors: _e.sideColors, title: 'Farbe ansagen');
    if (c == null || !mounted || !_myTurn) return;
    _e.resolveRoulette(c);
    _app.sfx.play(Sound.card);
    setState(() {});
    _after();
  }

  Future<void> _humanSpin() async {
    final space = await _animateSpin();
    if (!mounted || space == null) return;
    final choice = await _humanSpinChoice(space);
    if (!mounted) return;
    _e.spin(forced: space, choice: choice);
    _afterSpin();
    _after();
  }

  /// Dreht das Rad sichtbar. Liefert das Feld, angewendet wird es danach.
  Future<SpinSpace?> _animateSpin() async {
    final space = _e.randomSpace();
    setState(() {
      _spinning = true;
      _wheelVisible = true;
      _wheelFrom = _wheelTurns;
      _wheelTurns = _wheelTurns.floorToDouble() + 3 + spinTurnsFor(space, _e.wheel);
    });
    _app.sfx.play(Sound.tick);
    await Future<void>.delayed(_app.settings.botDelay(1900));
    if (!mounted) return null;
    _app.sfx.play(Sound.coin);
    return space;
  }

  void _afterSpin() {
    setState(() => _spinning = false);
    Future<void>.delayed(_app.settings.botDelay(900), () {
      if (mounted) setState(() => _wheelVisible = _e.raceOpen);
    });
  }

  /// Entscheidungen am Glücksrad für dich.
  Future<SpinChoice> _humanSpinChoice(SpinSpace space) async {
    final hand = _e.actor.hand;
    Future<int?> pickTop(List<EinsCard> cards) async {
      final distinct = {for (final x in cards) _e.face(x).spokenName};
      if (cards.length < 2 || distinct.length < 2) return null;
      final i = await showChoiceSheet(
        context,
        title: 'Welche Karte soll oben liegen?',
        options: [for (final x in cards) _e.face(x).spokenName],
      );
      return i == null ? null : cards[i].id;
    }

    switch (space) {
      case SpinSpace.almostDone:
        if (hand.length <= 2) return const SpinChoice();
        final keep = await _pickCards('Welche zwei Karten behältst du?', hand, 2);
        if (keep == null || !mounted) return const SpinChoice();
        final gone = hand.where((x) => !keep.contains(x.id)).toList();
        return SpinChoice(keep: keep, topId: await pickTop(gone));
      case SpinSpace.discardNumber:
        final counts = <int, int>{};
        for (final x in hand) {
          final f = _e.face(x);
          if (f.isNumber) counts[f.number] = (counts[f.number] ?? 0) + 1;
        }
        if (counts.isEmpty) return const SpinChoice();
        final numbers = counts.keys.toList()..sort();
        final i = await showChoiceSheet(
          context,
          title: 'Welche Zahl abwerfen?',
          options: [for (final n in numbers) '$n (${counts[n]}×)'],
        );
        if (i == null || !mounted) return const SpinChoice();
        final n = numbers[i];
        return SpinChoice(
          number: n,
          topId: await pickTop(hand.where((x) => _e.face(x).isNumber && _e.face(x).number == n).toList()),
        );
      case SpinSpace.discardColor:
      case SpinSpace.colorDiscard:
        final present = [
          for (final col in lightColors)
            if (hand.any((x) => _e.face(x).color == col)) col,
        ];
        if (present.isEmpty) return const SpinChoice();
        final col = await showColorPicker(context, colors: present, title: 'Welche Farbe abwerfen?');
        if (col == null || !mounted) return const SpinChoice();
        if (space == SpinSpace.colorDiscard) return SpinChoice(color: col);
        return SpinChoice(color: col, topId: await pickTop(hand.where((x) => _e.face(x).color == col).toList()));
      case SpinSpace.wildColorDraw:
        final col = await showColorPicker(context, title: 'Bis zu welcher Farbe ziehen?');
        return SpinChoice(color: col);
      case SpinSpace.swapHands:
        return SpinChoice(target: await _askTarget('Mit wem tauschen?'));
      default:
        return const SpinChoice();
    }
  }

  /// Wählt genau [count] Karten aus der Hand.
  Future<Set<int>?> _pickCards(String title, List<EinsCard> cards, int count) {
    final picked = <int>{};
    return showModalBottomSheet<Set<int>>(
      context: context,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in sortedEins(_e, cards))
                      GestureDetector(
                        onTap: () => setSheet(() {
                          if (!picked.remove(c.id) && picked.length < count) picked.add(c.id);
                        }),
                        child: Opacity(
                          opacity: picked.isEmpty || picked.contains(c.id) ? 1 : 0.55,
                          child: _cardView(c, 64, highlighted: picked.contains(c.id)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ActionButton(
                  primary: true,
                  label: 'Behalten (${picked.length}/$count)',
                  onPressed: picked.length == count ? () => Navigator.of(context).pop(picked) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Wettrennen: Computer reagieren nach zufälliger Zeit.
  Future<void> _runRace() async {
    final race = Completer<int>();
    setState(() => _race = race);
    final bots = [
      for (var i = 0; i < _e.count; i++)
        if (!_e.out[i] && !_e.players[i].human) i,
    ];
    var fastest = bots.isEmpty ? -1 : bots.first;
    var best = 99999;
    for (final b in bots) {
      final t = 450 + _rng.nextInt(900);
      if (t < best) {
        best = t;
        fastest = b;
      }
    }
    if (fastest >= 0) {
      Future<void>.delayed(_app.settings.botDelay(best), () {
        if (!race.isCompleted) race.complete(fastest);
      });
    }
    final w = await race.future;
    if (!mounted) return;
    int? discardId;
    final winner = _e.players[w];
    if (winner.human && winner.hand.length > 1) {
      final hand = sortedEins(_e, winner.hand);
      final i = await showChoiceSheet(
        context,
        title: _humans > 1 ? '${winner.name} war am schnellsten! Welche Karte abwerfen?' : 'Gewonnen! Welche Karte abwerfen?',
        options: [for (final x in hand) _e.face(x).spokenName],
      );
      if (!mounted) return;
      if (i != null) discardId = hand[i].id;
    }
    _e.resolveRace(w, discardId: discardId);
    _app.sfx.play(winner.human ? Sound.win : Sound.card);
    setState(() {
      _race = null;
      _wheelVisible = false;
    });
    await Future<void>.delayed(_app.settings.botDelay(700));
  }

  void _raceTap(int player) {
    final r = _race;
    if (r != null && !r.isCompleted) r.complete(player);
  }

  void _keep() {
    if (!_myTurn) return;
    _e.pass();
    setState(() {});
    _after();
  }

  void _call() {
    if (!_myTurn) return;
    _app.sfx.play(Sound.tick);
    setState(() => _called = true);
  }

  void _after() {
    if (mounted) setState(_syncViewer);
    if (_over) {
      _finish();
    } else {
      _pump();
    }
  }

  Future<void> _botPlay(EinsChoice choice) async {
    _e.play(
      choice.card!,
      chosen: choice.color,
      target: choice.target,
      flex: choice.flex,
      discardColor: choice.discardColor,
      coin: choice.coin,
    );
    _app.sfx.play(Sound.card);
    setState(() {});
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    while (mounted && !_over) {
      if (_e.raceOpen) {
        await _runRace();
        continue;
      }
      if (_e.actor.human) break;
      await Future<void>.delayed(_app.settings.botDelay(750));
      if (!mounted) return;
      if (_e.mustSpin) {
        final space = await _animateSpin();
        if (!mounted) return;
        if (space != null) _e.spin(forced: space);
        _afterSpin();
        continue;
      }
      if (einsBotMercy(_e) && _e.useMercyCoin()) {
        _app.sfx.play(Sound.coin);
        setState(() {});
        await Future<void>.delayed(_app.settings.botDelay(600));
        if (!mounted) return;
      }
      if (einsBotChallenges(_e, _rng)) {
        final me = _e.current;
        _e.challenge();
        _app.sfx.play(Sound.chip);
        setState(() {});
        if (_e.current != me || _over) continue;
        await Future<void>.delayed(_app.settings.botDelay(600));
        if (!mounted) return;
      }
      if (_e.mustChooseRoulette) {
        _e.resolveRoulette(favoriteColor(_e, _e.actor.hand));
        _app.sfx.play(Sound.card);
        setState(() {});
        continue;
      }
      final choice = einsBotChoice(_e, _rng);
      if (choice.card != null) {
        await _botPlay(choice);
        if (_e.extraPlay && !_over) {
          await Future<void>.delayed(_app.settings.botDelay(500));
          if (!mounted) return;
          final second = einsBotChoice(_e, _rng);
          if (second.card != null) {
            await _botPlay(second);
          } else {
            _e.endTurn();
            setState(() {});
          }
        }
        continue;
      }
      _e.draw();
      _app.sfx.play(Sound.card);
      setState(() {});
      if (_e.drewThisTurn && !_over) {
        await Future<void>.delayed(_app.settings.botDelay(500));
        if (!mounted) return;
        final again = einsBotChoice(_e, _rng);
        if (again.card != null) {
          await _botPlay(again);
          if (_e.extraPlay) {
            _e.endTurn();
            setState(() {});
          }
        } else {
          _e.pass();
          setState(() {});
        }
      }
    }
    _running = false;
    if (!mounted) return;
    setState(() {
      _called = false;
      _syncViewer();
    });
    if (_over) _finish();
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.finished && _e.winner!.human) {
      if (_winReward > 0) _app.wallet.credit(_winReward);
      _app.sfx.play(Sound.win);
    } else {
      if (_placeReward > 0) _app.wallet.credit(_placeReward);
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    final multi = _humans > 1;
    if (_humanOut) return multi ? 'Alle Spieler haben 25 Karten und sind raus' : 'Du hast 25 Karten und bist raus';
    if (_e.finished) {
      return _e.winner!.human
          ? (multi
              ? '${_e.winner!.name} gewinnt!${_winReward > 0 ? ' +${formatCoins(_winReward)} Münzen' : ''}'
              : 'Gewonnen! +${formatCoins(_winReward)} Münzen')
          : '${_e.winner!.name} gewinnt die Runde'
              '${_placeReward > 0 ? '. Trostpreis +${formatCoins(_placeReward)} Münzen' : ''}';
    }
    if (_race != null) return 'Wettrennen! Schnell drücken';
    if (_spinning) return '${_e.actor.human && !multi ? 'Du drehst' : '${_e.actor.name} dreht'} am Glücksrad';
    if (_e.actor.human && _covered) return 'Gib das Gerät an ${_e.actor.name}';
    if (_e.actor.human && multi) {
      final text = _humanStatus;
      // „… Du bist dran“ wird zu „… Ben ist dran“, sonst spricht die Meldung die Person mit Namen an
      if (text.endsWith('Du bist dran')) return '${text.substring(0, text.length - 12)}${_e.actor.name} ist dran';
      return '${_e.actor.name}: $text';
    }
    if (_e.actor.human) return _humanStatus;
    return _e.lastEvent.isNotEmpty ? _e.lastEvent : '${_e.actor.name} ist dran';
  }

  /// Meldung für den Menschen am Zug.
  String get _humanStatus {
    final prefix = _e.lastEvent.isNotEmpty ? '${_e.lastEvent}. ' : '';
    if (_e.mustSpin) return 'Dreh am Glücksrad!';
    if (_e.canChallenge) {
      final who = _e.players[_e.challengeOffender!].name;
      final what = _e.forcedColorDraw != null ? 'Ziehen bis zur Farbe' : '+${_e.pendingDraw}';
      return '$who legt $what. Annehmen oder anzweifeln?';
    }
    if (_e.extraPlay) return 'Du darfst noch eine Karte legen oder bist fertig';
    if (_e.mustChooseRoulette) return '${prefix}Sag eine Farbe an, du ziehst bis sie kommt';
    if (_e.forcedColorDraw != null) return 'Du musst ziehen, bis ${colorName(_e.forcedColorDraw!)} kommt';
    if (_e.pendingDraw > 0) {
      return _e.stackDraws
          ? 'Lege eine Plus-Karte mit mindestens +${_e.pendingValue} oder zieh ${_e.pendingDraw}'
          : 'Du musst ${_e.pendingDraw} ziehen';
    }
    if (_e.drewThisTurn) {
      return _mode == EinsMode.noMercy
          ? 'Du musst die gezogene Karte legen'
          : 'Gezogene Karte legen oder behalten';
    }
    return '${prefix}Du bist dran';
  }

  String get _drawLabel {
    if (_e.mustSpin) return 'Glücksrad drehen';
    if (_e.extraPlay && _e.actor.human) return 'Fertig';
    if (_e.mustChooseRoulette) return 'Farbe ansagen';
    if (_e.forcedColorDraw != null && _e.actor.human) return 'Bis ${colorName(_e.forcedColorDraw!)} ziehen';
    if (_e.pendingDraw > 0 && _e.actor.human) return '${_e.pendingDraw} Karten ziehen';
    return _mode == EinsMode.extreme ? 'Drücken' : 'Ziehen';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _app.settings;
    return GameFrame(
      settings: einsSettings,
      guide: einsGuide,
      title: _mode == EinsMode.classic ? 'Eins!' : 'Eins! ${modeName(_mode)}',
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          _e.stackDraws = settings.einsStackDraws;
          _e.callRequired = settings.einsCallRequired;
          _e.challengeRule = settings.einsChallenge;
          return LayoutBuilder(
            builder: (context, box) => _layout(box, settings.cardScale),
          );
        },
      ),
    );
  }

  Widget _cardView(EinsCard c, double width, {bool highlighted = false}) => EinsCardView(
        width: width,
        face: _e.face(c),
        dark: _e.darkSide && c.dark != null,
        highlighted: highlighted,
      );

  /// Was die anderen von einer Karte sehen: die Rückseite, bei der Kehrseite die andere Seite.
  Widget _backView(EinsCard? c, double width) {
    if (c != null && c.dark != null) {
      return EinsCardView(width: width, face: _e.otherFace(c), dark: !_e.darkSide);
    }
    return EinsCardView(width: width);
  }

  String _detail(int i) {
    if (_e.out[i]) return 'Raus';
    final p = _e.players[i];
    final count = p.hand.length == 1 ? 'Eins!' : '${p.hand.length} Karten';
    if (_e.expansion) {
      final coin = _e.coins[i];
      if (coin == null) return count;
      return '${p.hand.length == 1 ? 'Eins!' : p.hand.length} · ${coin == EinsCoin.mercy ? 'Gnade' : 'Keine Gnade'}';
    }
    if (_mode != EinsMode.flex) return count;
    return '${p.hand.length == 1 ? 'Eins!' : p.hand.length} · ${_e.power[i] ? 'Kraft an' : 'aus'}';
  }

  Widget _layout(BoxConstraints box, double scale) {
    final me = _e.players[_viewer];
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.3;
    final badge = math.min(130.0, (w - 24) / _opponents - 8);
    final handBase = landscape
        ? math.min(h * 0.3 * cardAspect, 110.0)
        : math.min(math.min(w / 5.2, h * 0.17 * cardAspect), 100.0);
    final handMax = h * (landscape ? 0.36 : 0.3) * cardAspect / 1.2;
    final handW = math.min((handBase * scale).clamp(30.0, 170.0), handMax);
    final pileBase = landscape
        ? math.min(h * 0.26 * cardAspect, 100.0)
        : math.min(math.min(w * 0.2, h * 0.2 * cardAspect), 100.0);
    final pileW = (pileBase * scale).clamp(30.0, 170.0);

    final opponents = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var k = 1; k < _e.players.length; k++)
          for (final i in [(_viewer + k) % _e.players.length])
          Opacity(
            opacity: _e.out[i] ? 0.45 : 1,
            child: OpponentBadge(
              name: _e.players[i].name,
              cardCount: _e.players[i].hand.length,
              active: !_over && _e.current == i,
              width: badge,
              cardBuilder: (cw, k) {
                final hand = _e.players[i].hand;
                final c = k < hand.length ? hand[k] : null;
                if (_e.revealed == i && c != null) return _cardView(c, cw);
                return _backView(c, cw);
              },
              detail: _detail(i),
            ),
          ),
      ],
    );
    final canCall = _myTurn && me.hand.length == 2 && _e.callRequired && _e.playableCards().isNotEmpty;
    final status = ResultBanner(text: _status, highlight: _e.finished && _e.winner!.human, maxLines: 2);
    final special = _e.mustSpin || _e.mustChooseRoulette;
    final mustDraw = _e.pendingDraw > 0 || _e.forcedColorDraw != null;
    final canDraw = _myTurn && (special || mustDraw || _e.extraPlay || !_e.drewThisTurn);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _over
          ? [
              ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
              ActionButton(label: 'Spielweise', onPressed: _askMode),
              ActionButton(label: 'Mitspieler wählen', onPressed: _askOpponents),
            ]
          : [
              if (_race != null)
                for (var i = 0; i < _e.count; i++)
                  if (_e.players[i].human && !_e.out[i])
                    ActionButton(
                      primary: true,
                      label: _humans > 1 ? '${_e.players[i].name}!' : 'Erster!',
                      onPressed: () => _raceTap(i),
                    ),
              if (_race == null)
                ActionButton(
                  primary: _myTurn && (special || _e.playableCards().isEmpty),
                  label: _drawLabel,
                  onPressed: canDraw ? _draw : null,
                ),
              if (_myTurn && _e.canChallenge) ActionButton(label: 'Anzweifeln', onPressed: _challengeTap),
              if (_myTurn && _e.drewThisTurn && _mode != EinsMode.noMercy && !special && !_e.extraPlay)
                ActionButton(label: 'Behalten', onPressed: _keep),
              if (_myTurn && _e.expansion && _e.coins[_e.current] == EinsCoin.mercy && !_e.mustSpin)
                ActionButton(label: 'Gnade-Münze', onPressed: _mercyTap),
              if (canCall)
                ActionButton(
                  primary: !_called,
                  label: _called ? 'Gerufen' : 'Eins! rufen',
                  onPressed: _called ? null : _call,
                ),
              if (_mode == EinsMode.flex) _powerChip(),
            ],
    );
    final Widget hand = _covered
        ? HandCover(name: _e.actor.name, onReveal: () => setState(() => _covered = false))
        : CardFan<EinsCard>(
      items: sortedEins(_e, me.hand),
      maxCardWidth: handW,
      cardBuilder: (c, width, raised) => _cardView(c, width, highlighted: raised),
      isEnabled: (c) => !_myTurn || _e.canPlay(c),
      isRaised: (c) => _myTurn && _e.canPlay(c),
      onTap: _play,
    );
    final centerContent = _wheelVisible
        ? TweenAnimationBuilder<double>(
            key: ValueKey(_wheelTurns),
            tween: Tween(begin: _wheelFrom, end: _wheelTurns),
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SpinWheel(size: pileW * 2.6, turns: t, spaces: _e.wheel),
          )
        : _center(pileW);
    final center = FittedBox(fit: BoxFit.scaleDown, child: centerContent);

    if (landscape) {
      // Meldung und Knöpfe sitzen direkt über der Hand und wandern mit ihr
      return Column(
        children: [
          const SizedBox(height: 6),
          opponents,
          Expanded(child: Center(child: center)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                SizedBox(width: math.min(440, w * 0.42), child: status),
                buttons,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 6), child: hand),
        ],
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        opponents,
        Expanded(child: Center(child: center)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: status),
        Padding(padding: const EdgeInsets.fromLTRB(10, 2, 10, 6), child: buttons),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: hand),
      ],
    );
  }

  Widget _powerChip() {
    final on = _e.power[_viewer];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE62A160E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? const Color(0xFFFFC95C) : const Color(0xFF6B3E1E), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 18, color: on ? const Color(0xFFFFC95C) : const Color(0xFF8C6A5E)),
          const SizedBox(width: 4),
          Text(
            on ? 'Kraft an' : 'Kraft aus',
            style: TextStyle(
              color: on ? const Color(0xFFFFC95C) : const Color(0xFFBFA58C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _center(double pileW) {
    final onFelt = Palette.of(context).onFelt;
    final label = TextStyle(color: onFelt, fontWeight: FontWeight.w700, fontSize: 15);
    final topCard = _e.drawPile.isEmpty ? null : _e.drawPile.last;
    final Widget pile;
    if (_mode == EinsMode.extreme) {
      pile = LauncherView(width: pileW, lastLaunch: _e.lastLaunch, enabled: _myTurn);
    } else if (topCard == null) {
      pile = CardSlot(width: pileW);
    } else {
      pile = _backView(topCard, pileW);
    }
    final infoColor = _e.forcedColorDraw ?? _e.color;
    String info;
    if (_e.pendingDraw > 0) {
      info = '+${_e.pendingDraw} ziehen';
    } else if (_e.forcedColorDraw != null) {
      info = 'Bis ${colorName(_e.forcedColorDraw!)}';
    } else {
      info = colorName(_e.color);
    }
    final alert = _e.pendingDraw > 0 || _e.forcedColorDraw != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(onTap: _draw, child: pile),
                const SizedBox(height: 4),
                Text(
                  _mode == EinsMode.extreme ? 'Werfer' : '${_e.drawPile.length} im Stapel',
                  style: label,
                ),
              ],
            ),
            SizedBox(width: pileW * 0.35),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey('${_e.discard.length}-${_e.darkSide}-${_e.top.id}'),
                    child: _cardView(_e.top, pileW),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: einsColors[infoColor],
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFF8E7), width: 2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      info,
                      style: alert ? label.copyWith(color: const Color(0xFFFFC95C)) : label,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _e.direction == 1 ? Icons.rotate_right : Icons.rotate_left,
              color: onFelt.withValues(alpha: 0.7),
              semanticLabel: _e.direction == 1 ? 'Im Uhrzeigersinn' : 'Gegen den Uhrzeigersinn',
            ),
            if (_mode == EinsMode.flip) ...[
              const SizedBox(width: 8),
              Text(_e.darkSide ? 'Dunkle Seite' : 'Helle Seite', style: label),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(Icons.tune, modeName(_mode), _askMode),
            const SizedBox(width: 8),
            _chip(Icons.help_outline, 'Regeln', _showRules),
          ],
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String text, VoidCallback onTap) => Material(
        color: const Color(0xE62A160E),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8A5A2B), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: const Color(0xFFFFC95C)),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(color: Color(0xFFF6E7C8), fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );

  void _showRules() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final p = Palette.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85, maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Eins! ${modeName(_mode)}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final line in modeRules(_mode))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: TextStyle(color: p.accent, fontSize: 16, fontWeight: FontWeight.w700)),
                          Expanded(child: Text(line, style: TextStyle(color: p.ink, fontSize: 16, height: 1.3))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
