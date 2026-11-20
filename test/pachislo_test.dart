import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/pachislo/pachislo_engine.dart';

/// Spielt ein Spiel mit gegebener Drückstrategie. Liefert Auszahlung, Einsatz.
(int, int, PsResult) play(PachisloMachine m, Random rng, {bool aim = false}) {
  final bet = m.freeGame ? 0 : psBet;
  m.start();
  final order = rng.nextInt(4) == 0 ? ([0, 1, 2]..shuffle(rng)) : [0, 1, 2];
  for (final r in order) {
    var press = rng.nextInt(psLength);
    if (aim) {
      // Gezielt: das erste Drückfeld wählen, bei dem die Steuerung das Zielsymbol in die Mitte bringt
      for (var p = 0; p < psLength; p++) {
        final s = m.controlStop(r, p);
        final need = switch (m.flag) {
          PsFlag.big => psSeven,
          PsFlag.reg => r == 2 ? psBar : psSeven,
          PsFlag.bell => psBell,
          _ => -1,
        };
        if (need >= 0 && psStrips[r][(s + 1) % psLength] == need) {
          press = p;
          break;
        }
      }
    }
    m.stop(r, press);
  }
  final res = m.finish();
  return (res.paid, bet, res);
}

void main() {
  test('Bänder: 21 Felder, Pflaume und Replay höchstens alle 5, Kirsche auf Walze 1 ebenso', () {
    for (var r = 0; r < 3; r++) {
      final st = psStrips[r];
      expect(st.length, psLength);
      for (final sym in [psPlum, psReplay, if (r == 0) psCherry]) {
        final idx = [for (var i = 0; i < psLength; i++) if (st[i] == sym) i];
        for (var k = 0; k < idx.length; k++) {
          final gap = (idx[(k + 1) % idx.length] - idx[k] + psLength) % psLength;
          expect(gap == 0 ? psLength : gap, lessThanOrEqualTo(5), reason: 'Walze $r, ${psSymbolNames[sym]}');
        }
      }
    }
  });

  test('Steuerung: nie eine nicht ausgeloste Rolle, Pflaume, Replay und Kirsche immer', () {
    final rng = Random(3);
    for (final flag in PsFlag.values) {
      var hit = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        final m = PachisloMachine(rng: rng)..flag = flag;
        m.running = true;
        final order = [0, 1, 2]..shuffle(rng);
        for (final r in order) {
          m.stop(r, rng.nextInt(psLength));
        }
        final mid = [for (var r = 0; r < 3; r++) psStrips[r][(m.stops[r]! + 1) % psLength]];
        final roles = psRoles(mid, psWindow(0, m.stops[0]!));
        expect(roles.difference({flag}), isEmpty, reason: '$flag ergab $roles');
        if (roles.contains(flag)) hit++;
      }
      if ([PsFlag.plum, PsFlag.replay, PsFlag.cherry].contains(flag)) {
        expect(hit, n, reason: '$flag muss immer klappen');
      }
      if ([PsFlag.big, PsFlag.reg, PsFlag.bell].contains(flag)) {
        expect(hit / n, inInclusiveRange(0.03, 0.5), reason: '$flag muss man treffen');
      }
    }
  });

  test('Bonus bleibt erhalten, bis er ausgerichtet ist; BIG hat 24 Spiele', () {
    final m = PachisloMachine(rng: Random(1))..held = PsFlag.big;
    expect(m.start(), PsFlag.big);
    for (var r = 0; r < 3; r++) {
      // Sieben gezielt in die Mitte
      final p = List.generate(psLength, (i) => i).firstWhere((p) => psStrips[r][(m.controlStop(r, p) + 1) % psLength] == psSeven);
      m.stop(r, p);
    }
    final res = m.finish();
    expect(res.bonusStarted, PsFlag.big);
    expect(m.held, isNull);
    expect(m.bonusLeft, psBigGames);
    var paid = 0;
    final rng = Random(2);
    while (m.bonus != null) {
      final (p, _, _) = play(m, rng);
      paid += p;
    }
    expect(paid, psBigGames * psBonusPay, reason: 'im Bonus klappt jede Pflaume');
  });

  test('Auslosung summiert sich zu den Quoten', () {
    final count = <PsFlag, int>{};
    for (var v = 0; v < 65536; v++) {
      final f = PachisloMachine.draw(v);
      count[f] = (count[f] ?? 0) + 1;
    }
    for (final e in psOdds.entries) {
      expect(count[e.key], e.value);
    }
  });

  for (final aim in [false, true]) {
    test('Auszahlungsquote ${aim ? 'gezielt' : 'blind'}', () {
      final m = PachisloMachine(rng: Random(aim ? 7 : 8));
      final rng = Random(aim ? 9 : 10);
      var paid = 0, bet = 0;
      for (var i = 0; i < 400000; i++) {
        final (p, b, _) = play(m, rng, aim: aim);
        paid += p;
        bet += b;
      }
      final rtp = paid / bet;
      // ignore: avoid_print
      print('Pachislo ${aim ? 'gezielt' : 'blind'}: ${(rtp * 100).toStringAsFixed(1)} %');
      if (aim) {
        expect(rtp, inInclusiveRange(0.95, 1.0));
      } else {
        expect(rtp, inInclusiveRange(0.88, 0.96));
      }
    });
  }
}
