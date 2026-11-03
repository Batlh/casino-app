import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/slots/slot_data.dart';
import 'package:gluckspfennig/games/slots/slot_engine.dart';

void main() {
  test('Walzen enthalten nur gültige Symbole', () {
    expect(kosmosStrips.length, reelCount);
    for (final strip in kosmosStrips) {
      expect(strip.every((s) => s >= 0 && s <= symLoch), isTrue);
    }
  });

  test('Linienwertung', () {
    expect(evaluateLine([symRakete, symRakete, symRakete, symMond, symMond])?.multiplier, 20);
    expect(evaluateLine([symSonne, symRakete, symRakete, symRakete, symRakete])?.multiplier, 500);
    expect(evaluateLine([symMond, symMond, symStern, symMond, symMond]), isNull);
    expect(evaluateLine([symLoch, symRakete, symRakete, symRakete, symRakete]), isNull);
    // Drei Sonnen zahlen mehr als drei Monde mit Joker
    final wild = evaluateLine([symSonne, symSonne, symSonne, symMond, symStern]);
    expect(wild?.symbol, symSonne);
    expect(wild?.multiplier, 50);
    expect(evaluateLine(List.filled(5, symSonne))?.multiplier, 1000);
  });

  test('Scatter zählt überall und startet Freispiele', () {
    final grid = [
      [symLoch, symMond, symStern],
      [symStern, symLoch, symMond],
      [symMond, symStern, symKomet],
      [symKomet, symLoch, symUfo],
      [symUfo, symKomet, symPlanet],
    ];
    final r = SlotEngine.evaluateGrid(grid, 50);
    expect(r.scatterCount, 3);
    expect(r.scatterWin, 100);
    expect(r.freeSpinsWon, freeSpinsAward);
  });

  test('Auszahlungsquote liegt nahe der abgestimmten 96 Prozent', () {
    final engine = SlotEngine(rng: Random(4));
    const stake = 100;
    const spins = 400000;
    var paid = 0;
    var free = 0;
    for (var i = 0; i < spins; i++) {
      var r = engine.spin(stake);
      paid += r.total;
      free += r.freeSpinsWon;
      while (free > 0) {
        free--;
        r = engine.spin(stake, multiplier: freeSpinMultiplier);
        paid += r.total;
        free += r.freeSpinsWon;
      }
    }
    final rtp = paid / (spins * stake);
    expect(rtp, inInclusiveRange(0.92, 1.0), reason: 'RTP war $rtp');
  });
}
