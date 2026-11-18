import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/net/lan.dart';
import 'package:gluckspfennig/games/eins/eins_engine.dart';
import 'package:gluckspfennig/games/eins/eins_net.dart';

/// Nächste Aktion wie im Bildschirm (Computer für alle Plätze).
List<LanMessage> _turn(EinsEngine e, Random rng) {
  if (e.raceOpen) {
    final active = [for (var i = 0; i < e.count; i++) if (!e.out[i]) i];
    return [einsRaceAction(active[rng.nextInt(active.length)], null)];
  }
  if (e.mustSpin) return [einsRollAction];
  if (einsBotMercy(e)) return [einsMercyAction];
  if (einsBotChallenges(e, rng)) return [einsChallengeAction];
  if (e.mustChooseRoulette) return [einsRouletteAction(favoriteColor(e, e.actor.hand))];
  final c = einsBotChoice(e, rng);
  if (c.card != null) {
    return [einsPlayAction(c.card!, chosen: c.color, target: c.target, flex: c.flex, discardColor: c.discardColor, coin: c.coin)];
  }
  if (e.extraPlay) return [einsEndAction];
  return [einsDrawAction];
}

String _state(EinsEngine e) => [
      e.current,
      e.direction,
      e.top.id,
      e.drawPile.length,
      e.darkSide,
      for (final p in e.players) p.hand.map((c) => c.id).join(','),
      e.out.join(','),
      e.winner?.name ?? '-',
    ].join('|');

void main() {
  for (final mode in EinsMode.values) {
    for (final expansion in mode == EinsMode.noMercy ? [false, true] : [false]) {
      test('Eins ${mode.name}${expansion ? ' mit Erweiterung' : ''}: Gastgeber und Mitspieler bleiben beim Nachspielen gleich', () {
        for (var game = 0; game < 6; game++) {
          final r = EinsRound(
            seed: 1000 + game,
            round: game,
            mode: mode,
            names: const ['Gastgeber', 'Anna', 'Otto', 'Helga'],
            humans: const {0, 1},
            startPlayer: game % 4,
            stackDraws: true,
            callRequired: true,
            challengeRule: true,
            expansion: expansion,
          );
          final host = r.engine(0);
          final guest = r.engine(1);
          final rng = Random(game);
          var steps = 0;
          final log = <LanMessage>[];
          while (!host.finished && host.out.where((o) => !o).length > 1 && steps < 3000) {
            for (final a in _turn(host, rng)) {
              final s1 = einsApply(host, a);
              final s2 = einsApply(guest, a);
              expect(s2, s1, reason: 'Rad zeigt dasselbe Feld');
              log.add(a);
              if (s1 != null) {
                final spin = einsSpinAction(s1, const SpinChoice());
                einsApply(host, spin);
                einsApply(guest, spin);
                log.add(spin);
              }
              // Nach dem Ziehen: passende Karte legen oder behalten
              if (a['a'] == 'draw' && host.drewThisTurn && !host.finished) {
                final again = einsBotChoice(host, rng);
                final next = again.card != null
                    ? einsPlayAction(again.card!, chosen: again.color, target: again.target, flex: again.flex, discardColor: again.discardColor, coin: again.coin)
                    : (host.extraPlay ? einsEndAction : einsPassAction);
                einsApply(host, next);
                einsApply(guest, next);
                log.add(next);
              }
            }
            expect(_state(guest), _state(host), reason: 'Schritt $steps');
            steps++;
          }
          // Ein später Beitritt spielt das ganze Protokoll nach und landet beim selben Stand
          final late = r.engine(1);
          for (final a in log) {
            einsApply(late, a);
          }
          expect(_state(late), _state(host));
        }
      });
    }
  }
}
