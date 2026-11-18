import 'dart:math';

import '../../core/net/lan.dart';
import 'eins_card.dart';
import 'eins_engine.dart';

/// Eins im lokalen Netz durch Nachspielen.
///
/// Der Gastgeber schickt zu Rundenbeginn die Einstellungen und einen Startwert. Jedes Gerät baut daraus dieselbe
/// Engine (gleich gemischt) und wendet danach dieselben Aktionen in derselben Reihenfolge an. Zufall gibt es nur in
/// der Engine selbst, darum bleiben alle Geräte gleich. Computer spielen nur beim Gastgeber; Mitspieler schicken
/// ihre Aktionen an den Gastgeber, der sie prüft und an alle verteilt.

const einsNetGame = 'eins';

/// Einstellungen einer Runde.
class EinsRound {
  const EinsRound({
    required this.seed,
    required this.round,
    required this.mode,
    required this.names,
    required this.humans,
    required this.startPlayer,
    required this.stackDraws,
    required this.callRequired,
    required this.challengeRule,
    required this.expansion,
  });

  final int seed;
  final int round;
  final EinsMode mode;
  final List<String> names;

  /// Plätze, an denen Menschen sitzen (Gastgeber und Mitspieler), der Rest sind Computer.
  final Set<int> humans;
  final int startPlayer;
  final bool stackDraws;
  final bool callRequired;
  final bool challengeRule;
  final bool expansion;

  int get bots => names.length - humans.length;

  LanMessage toJson() => {
        'seed': seed,
        'round': round,
        'mode': mode.name,
        'names': names,
        'humans': humans.toList(),
        'start': startPlayer,
        'stack': stackDraws,
        'call': callRequired,
        'challenge': challengeRule,
        'expansion': expansion,
      };

  static EinsRound fromJson(LanMessage m) => EinsRound(
        seed: (m['seed'] as num).toInt(),
        round: (m['round'] as num).toInt(),
        mode: EinsMode.values.byName('${m['mode']}'),
        names: [for (final n in m['names'] as List) '$n'],
        humans: {for (final h in m['humans'] as List) (h as num).toInt()},
        startPlayer: (m['start'] as num).toInt(),
        stackDraws: m['stack'] as bool,
        callRequired: m['call'] as bool,
        challengeRule: m['challenge'] as bool,
        expansion: m['expansion'] as bool,
      );

  /// Engine für ein Gerät: [me] ist dort der Mensch vor dem Bildschirm.
  EinsEngine engine(int me) => EinsEngine(
        players: [for (final (i, n) in names.indexed) EinsPlayer(n, human: i == me)],
        mode: mode,
        rng: Random(seed),
        stackDraws: stackDraws,
        callRequired: callRequired,
        challengeRule: challengeRule,
        expansion: expansion,
      )..start(startPlayer: startPlayer);
}

// ---------------------------------------------------------------- Aktionen

LanMessage einsPlayAction(EinsCard c,
        {EinsColor? chosen, int? target, bool flex = false, EinsColor? discardColor, bool coin = false, bool called = true}) =>
    {
      'a': 'play',
      'card': c.id,
      'chosen': chosen?.index,
      'target': target,
      'flex': flex,
      'discardColor': discardColor?.index,
      'coin': coin,
      'called': called,
    };

const LanMessage einsDrawAction = {'a': 'draw'};
const LanMessage einsPassAction = {'a': 'pass'};
const LanMessage einsEndAction = {'a': 'end'};
const LanMessage einsChallengeAction = {'a': 'challenge'};
const LanMessage einsMercyAction = {'a': 'mercy'};

/// Rad drehen: zieht das Feld aus dem Zufall der Engine (alle Geräte gleich).
const LanMessage einsRollAction = {'a': 'roll'};

LanMessage einsRouletteAction(EinsColor c) => {'a': 'roulette', 'color': c.index};

LanMessage einsSpinAction(SpinSpace space, SpinChoice choice) => {
      'a': 'spin',
      'space': space.name,
      'keep': choice.keep?.toList(),
      'number': choice.number,
      'color': choice.color?.index,
      'top': choice.topId,
      'target': choice.target,
    };

LanMessage einsRaceAction(int winner, int? discardId) => {'a': 'race', 'winner': winner, 'discard': discardId};

LanMessage einsCoinAction(int player, EinsCoin coin) => {'a': 'coin', 'player': player, 'coin': coin.name};

EinsColor? _color(Object? v) => v == null ? null : EinsColor.values[(v as num).toInt()];
int? _int(Object? v) => v == null ? null : (v as num).toInt();

/// Aktionen, die nur der Spieler selbst schicken darf, der gerade dran ist.
bool einsTurnAction(LanMessage a) => const {'play', 'draw', 'pass', 'end', 'challenge', 'mercy', 'roll', 'roulette', 'spin'}.contains(a['a']);

/// Wendet eine Aktion an. Liefert beim Drehen das Feld. Wirft bei ungültigen Aktionen.
SpinSpace? einsApply(EinsEngine e, LanMessage a) {
  switch (a['a']) {
    case 'play':
      final id = (a['card'] as num).toInt();
      final c = e.actor.hand.firstWhere((x) => x.id == id);
      e.play(
        c,
        chosen: _color(a['chosen']),
        target: _int(a['target']),
        flex: a['flex'] == true,
        discardColor: _color(a['discardColor']),
        coin: a['coin'] == true,
        called: a['called'] != false,
      );
    case 'draw':
      e.draw();
    case 'pass':
      e.pass();
    case 'end':
      e.endTurn();
    case 'challenge':
      if (!e.canChallenge) throw StateError('Anzweifeln geht nicht');
      e.challenge();
    case 'mercy':
      e.useMercyCoin();
    case 'roll':
      if (!e.mustSpin) throw StateError('Jetzt wird nicht gedreht');
      return e.randomSpace();
    case 'roulette':
      e.resolveRoulette(_color(a['color'])!);
    case 'spin':
      final keep = a['keep'] as List?;
      e.spin(
        forced: SpinSpace.values.byName('${a['space']}'),
        choice: SpinChoice(
          keep: keep == null ? null : {for (final k in keep) (k as num).toInt()},
          number: _int(a['number']),
          color: _color(a['color']),
          topId: _int(a['top']),
          target: _int(a['target']),
        ),
      );
    case 'race':
      e.resolveRace((a['winner'] as num).toInt(), discardId: _int(a['discard']));
    case 'coin':
      e.coins[(a['player'] as num).toInt()] = EinsCoin.values.byName('${a['coin']}');
    default:
      throw StateError('Unbekannte Aktion ${a['a']}');
  }
  return null;
}
