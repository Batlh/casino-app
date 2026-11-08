import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../ui/widgets.dart';
import '../cards/card_widgets.dart';
import 'eins_card.dart';
import 'eins_engine.dart';

const _names = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst'];
const einsRewardPerOpponent = 50;

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
    'Wer nicht legen kann, zieht eine Karte. Passt sie, darfst du sie sofort legen.',
    'Bei der vorletzten Karte musst du Eins! rufen, sonst gibt es Strafkarten (in den Einstellungen abschaltbar).',
    'Wer zuerst keine Karten mehr hat, gewinnt 50 Münzen pro Gegner.',
  ];
  return switch (m) {
    EinsMode.classic => [
        ...base,
        'Aussetzen, Richtungswechsel, Plus zwei, Farbwahl und Farbwahl plus vier.',
        'Plus-Karten dürfen gestapelt werden, wenn das in den Einstellungen an ist.',
      ],
    EinsMode.flip => [
        ...base,
        'Jede Karte hat eine helle und eine dunkle Seite. Bei den Gegnern und auf dem Stapel siehst du die jeweils andere Seite.',
        'Die Wendekarte dreht alle Karten um: Hand, Ablage und Stapel. Danach gelten die Farben und Karten der anderen Seite.',
        'Hell: Plus eins, Aussetzen, Richtungswechsel, Farbwahl plus zwei.',
        'Dunkel: Plus fünf, Alle setzen aus (du bist gleich nochmal dran), Farbwahl bis zur Farbe: Der Nächste zieht, bis die gewählte Farbe kommt.',
      ],
    EinsMode.noMercy => [
        ...base,
        'Plus-Karten bis plus zehn. Gestapelt wird immer, mit gleichem oder höherem Wert.',
        'Kannst du nicht legen, ziehst du, bis eine Karte passt, und musst sie legen.',
        'Sieben: Tausche die Hand mit einem Gegner. Null: Alle geben ihre Hand in Spielrichtung weiter.',
        'Alle abwerfen: Wirf zusätzlich alle Karten dieser Farbe ab.',
        'Farbroulette: Der Nächste sagt eine Farbe an und zieht, bis sie kommt.',
        'Wer 25 Karten oder mehr hat, scheidet aus. Wer als Letzter übrig ist, gewinnt auch.',
      ],
    EinsMode.extreme => [
        ...base.take(1),
        'Statt zu ziehen drückst du den Kartenwerfer. Er spuckt keine, ein paar oder viele Karten aus. Danach ist dein Zug vorbei.',
        'Zweimal werfen: Der Nächste drückt zweimal und setzt aus.',
        'Feuer: Der Nächste drückt, bis Karten kommen, und setzt aus. Alle werfen: Alle anderen drücken einmal.',
        'Hände tauschen: Tausche die Hand mit einem Gegner. Alle abwerfen: Wirf alle Karten dieser Farbe ab.',
        'Vergessenes Eins! kostet zweimal drücken.',
        base.last,
      ],
    EinsMode.spin => [
        ...base,
        'Karten mit Glücksrad lassen den nächsten Spieler drehen statt zu spielen.',
        'Felder: Fast fertig (nur zwei Karten behalten), Zahl abwerfen, Farbe abwerfen, Zieh bis Rot, Zieh bis Blau, Hände weitergeben, Hand zeigen, Duell (höchste Zahl gewinnt und wirft ab) und Wettrennen (wer zuerst drückt, wirft seine wertvollste Karte ab).',
      ],
    EinsMode.flex => [
        ...base,
        'Jeder hat eine Kraftkarte, die an oder aus ist. Karten mit goldenem Blitz haben eine Kraftseite.',
        'Ist deine Kraft an, darfst du die Kraftseite nutzen. Danach ist deine Kraft aus.',
        'Kraft: Aussetzen lässt alle aussetzen, Richtungswechsel lässt zusätzlich aussetzen, Plus zwei lässt alle anderen eine ziehen, Farbwahl-Karten lassen alle oder einen Gegner deiner Wahl ziehen.',
        'Zahlen mit weißem Blitz schalten deine eigene Kraft um. Kraftwechsel für alle schaltet alle um. Sind alle aus, gehen alle wieder an.',
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
  int _opponents = 2;
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

  /// Wettrennen: wartet auf den ersten Ruf.
  Completer<int>? _race;

  AppScope get _app => AppScope.of(context);
  bool get _humanOut => _e.out[0];
  bool get _over => _e.finished || _humanOut;
  bool get _myTurn => !_over && _e.actor.human && !_running && !_spinning;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _mode = widget.mode ?? _app.settings.einsMode;
    _setup();
  }

  void _setup() {
    final offset = _rng.nextInt(_names.length);
    final settings = _app.settings;
    _e = EinsEngine(
      players: [
        EinsPlayer('Du', human: true),
        for (var i = 0; i < _opponents; i++) EinsPlayer(_names[(offset + i) % _names.length]),
      ],
      mode: _mode,
      rng: _rng,
      stackDraws: settings.einsStackDraws,
      callRequired: settings.einsCallRequired,
    )..start(startPlayer: _round % (_opponents + 1));
    _rewarded = false;
    _called = false;
    _wheelVisible = false;
    _spinning = false;
    _race = null;
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
    final i = await showChoiceSheet(
      context,
      title: 'Wie viele Gegner?',
      options: const ['Ein Gegner', 'Zwei Gegner', 'Drei Gegner'],
    );
    if (i == null || !mounted) return;
    _opponents = i + 1;
    _newRound();
  }

  Future<void> _askMode() async {
    final m = await showModalBottomSheet<EinsMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
    if (_e.canUseFlex(0, c)) {
      final pick = await showChoiceSheet(
        context,
        title: 'Kraft nutzen?',
        options: ['Kraft: ${f.flexEffect}', 'Normal: ${f.label}'],
      );
      if (pick == null || !mounted || !_myTurn) return;
      flex = pick == 0;
    }
    int? target;
    if (_e.needsTarget(c, flex: flex)) {
      target = await _askTarget(
        f.kind == EinsKind.number || f.kind == EinsKind.tradeHands ? 'Mit wem tauschen?' : 'Wer soll ziehen?',
      );
      if (target == null || !mounted || !_myTurn) return;
    }
    EinsColor? chosen;
    if (f.isWild && _e.actor.hand.length > 1) {
      chosen = await showColorPicker(
        context,
        colors: _e.sideColors,
        title: f.kind == EinsKind.wildDrawColor ? 'Bis zu welcher Farbe ziehen?' : 'Farbe wählen',
      );
      if (chosen == null || !mounted || !_myTurn) return;
    }
    _e.play(c, chosen: chosen, target: target, flex: flex, called: _called);
    _called = false;
    _app.sfx.play(Sound.card);
    setState(() {});
    _after();
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
    await _animateSpin();
    if (!mounted) return;
    _after();
  }

  /// Dreht das Rad sichtbar und wendet dann das Feld an.
  Future<void> _animateSpin() async {
    final space = SpinSpace.values[_rng.nextInt(SpinSpace.values.length)];
    setState(() {
      _spinning = true;
      _wheelVisible = true;
      _wheelTurns = _wheelTurns.floorToDouble() + 3 + spinTurnsFor(space);
    });
    _app.sfx.play(Sound.tick);
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    _e.spin(forced: space);
    _app.sfx.play(Sound.coin);
    setState(() => _spinning = false);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _wheelVisible = _e.raceOpen);
  }

  /// Wettrennen: Computer reagieren nach zufälliger Zeit.
  Future<void> _runRace() async {
    final race = Completer<int>();
    setState(() => _race = race);
    final bots = [
      for (var i = 1; i < _e.count; i++)
        if (!_e.out[i]) i,
    ];
    var fastest = bots.isEmpty ? 0 : bots.first;
    var best = 99999;
    for (final b in bots) {
      final t = 450 + _rng.nextInt(900);
      if (t < best) {
        best = t;
        fastest = b;
      }
    }
    Future<void>.delayed(Duration(milliseconds: best), () {
      if (!race.isCompleted) race.complete(fastest);
    });
    final w = await race.future;
    if (!mounted) return;
    _e.resolveRace(w);
    _app.sfx.play(w == 0 ? Sound.win : Sound.card);
    setState(() {
      _race = null;
      _wheelVisible = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  void _raceTap() {
    final r = _race;
    if (r != null && !r.isCompleted) r.complete(0);
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
    if (_over) {
      _finish();
    } else {
      _pump();
    }
  }

  Future<void> _botPlay(EinsChoice choice) async {
    _e.play(choice.card!, chosen: choice.color, target: choice.target, flex: choice.flex);
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
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      if (_e.mustSpin) {
        await _animateSpin();
        continue;
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
        continue;
      }
      _e.draw();
      _app.sfx.play(Sound.card);
      setState(() {});
      if (_e.drewThisTurn && !_over) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        final again = einsBotChoice(_e, _rng);
        if (again.card != null) {
          await _botPlay(again);
        } else {
          _e.pass();
          setState(() {});
        }
      }
    }
    _running = false;
    if (!mounted) return;
    setState(() => _called = false);
    if (_over) _finish();
  }

  void _finish() {
    if (_rewarded) return;
    _rewarded = true;
    if (_e.finished && _e.winner!.human) {
      _app.wallet.credit(einsRewardPerOpponent * _opponents);
      _app.sfx.play(Sound.win);
    } else {
      _app.sfx.play(Sound.lose);
    }
    setState(() {});
  }

  String get _status {
    if (_humanOut) return 'Du hast 25 Karten und bist raus';
    if (_e.finished) {
      return _e.winner!.human
          ? 'Gewonnen! +${formatCoins(einsRewardPerOpponent * _opponents)} Münzen'
          : '${_e.winner!.name} gewinnt die Runde';
    }
    if (_race != null) return 'Wettrennen! Schnell drücken';
    if (_spinning) return '${_e.actor.human ? 'Du drehst' : '${_e.actor.name} dreht'} am Glücksrad';
    if (_e.actor.human) {
      final prefix = _e.lastEvent.isNotEmpty ? '${_e.lastEvent}. ' : '';
      if (_e.mustSpin) return '${prefix}Dreh am Glücksrad';
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
    return _e.lastEvent.isNotEmpty ? _e.lastEvent : '${_e.actor.name} ist dran';
  }

  String get _drawLabel {
    if (_e.mustSpin) return 'Glücksrad drehen';
    if (_e.mustChooseRoulette) return 'Farbe ansagen';
    if (_e.forcedColorDraw != null && _e.actor.human) return 'Bis ${colorName(_e.forcedColorDraw!)} ziehen';
    if (_e.pendingDraw > 0 && _e.actor.human) return '${_e.pendingDraw} Karten ziehen';
    return _mode == EinsMode.extreme ? 'Drücken' : 'Ziehen';
  }

  @override
  Widget build(BuildContext context) {
    final settings = _app.settings;
    return GameFrame(
      title: _mode == EinsMode.classic ? 'Eins!' : 'Eins! ${modeName(_mode)}',
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          _e.stackDraws = settings.einsStackDraws;
          _e.callRequired = settings.einsCallRequired;
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
    final parts = <String>[
      if (p.hand.length == 1) 'Eins!' else '${p.hand.length} Karten',
      if (_mode == EinsMode.flex) _e.power[i] ? 'Kraft an' : 'Kraft aus',
    ];
    return parts.join(' · ');
  }

  Widget _layout(BoxConstraints box, double scale) {
    final me = _e.players.first;
    final w = box.maxWidth;
    final h = box.maxHeight;
    final landscape = w > h * 1.3;
    final badge = math.min(118.0, (w - 24) / _opponents - 8);
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
        for (var i = 1; i < _e.players.length; i++)
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
    final status = ResultBanner(text: _status, highlight: _e.finished && _e.winner!.human);
    final special = _e.mustSpin || _e.mustChooseRoulette;
    final mustDraw = _e.pendingDraw > 0 || _e.forcedColorDraw != null;
    final canDraw = _myTurn && (special || mustDraw || !_e.drewThisTurn);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _over
          ? [
              ActionButton(primary: true, label: 'Neue Runde', onPressed: _newRound),
              ActionButton(label: 'Spielweise', onPressed: _askMode),
              ActionButton(label: 'Gegner wählen', onPressed: _askOpponents),
            ]
          : [
              if (_race != null)
                ActionButton(primary: true, label: 'Erster!', onPressed: _raceTap)
              else
                ActionButton(
                  primary: _myTurn && (special || _e.playableCards().isEmpty),
                  label: _drawLabel,
                  onPressed: canDraw ? _draw : null,
                ),
              if (_myTurn && _e.drewThisTurn && _mode != EinsMode.noMercy && !special)
                ActionButton(label: 'Behalten', onPressed: _keep),
              if (canCall)
                ActionButton(
                  primary: !_called,
                  label: _called ? 'Gerufen' : 'Eins! rufen',
                  onPressed: _called ? null : _call,
                ),
              if (_mode == EinsMode.flex) _powerChip(),
            ],
    );
    final hand = CardFan<EinsCard>(
      items: sortedEins(_e, me.hand),
      maxCardWidth: handW,
      cardBuilder: (c, width, raised) => _cardView(c, width, highlighted: raised),
      isEnabled: (c) => !_myTurn || _e.canPlay(c),
      isRaised: (c) => _myTurn && _e.canPlay(c),
      onTap: _play,
    );
    final centerContent = _wheelVisible
        ? TweenAnimationBuilder<double>(
            tween: Tween(end: _wheelTurns),
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SpinWheel(size: pileW * 2.6, turns: t),
          )
        : _center(pileW);
    final center = FittedBox(fit: BoxFit.scaleDown, child: centerContent);

    if (landscape) {
      return Column(
        children: [
          const SizedBox(height: 6),
          opponents,
          Expanded(
            child: Row(
              children: [
                Expanded(child: Center(child: center)),
                SizedBox(
                  width: math.min(320, w * 0.38),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: math.min(320, w * 0.38),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [status, buttons],
                      ),
                    ),
                  ),
                ),
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
    final on = _e.power[0];
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
