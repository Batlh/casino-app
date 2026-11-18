import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/baccarat/baccarat_engine.dart';

void main() {
  test('Baccarat-Runde übersteht den Weg durchs Netz', () {
    final shoe = BaccaratShoe(rng: Random(7));
    for (var i = 0; i < 50; i++) {
      final r = shoe.play();
      final back = bacRoundFromJson(jsonDecode(jsonEncode(bacRoundToJson(r))));
      expect(back, isNotNull);
      expect(back!.winner, r.winner);
      expect(back.playerTotal, r.playerTotal);
      expect(back.bankerTotal, r.bankerTotal);
      for (final b in BacBet.values) {
        expect(back.payout(b, 100), r.payout(b, 100));
      }
    }
  });

  test('Kaputte Daten werden abgelehnt', () {
    expect(bacRoundFromJson(null), isNull);
    expect(bacRoundFromJson([[]]), isNull);
    expect(bacRoundFromJson([[[1, 0], [5, 1]], [[9, 0], [3, 2]]]), isNull);
    expect(bacRoundFromJson([[[4, 9], [5, 1]], [[9, 0], [3, 2]]]), isNull);
  });
}
