import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/games/baccarat/baccarat_engine.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/keno/keno_screen.dart';
import 'package:gluckspfennig/games/sicbo/sicbo_screen.dart';

PlayingCard c(int r) => PlayingCard(r, Suit.hearts);

void main() {
  group('Baccarat', () {
    test('Werte und Summen', () {
      expect(bacTotal([c(7), c(8)]), 5);
      expect(bacTotal([c(13), c(14)]), 1);
      expect(bacTotal([c(10), c(9)]), 9);
    });
    test('Ziehregeln der Bank', () {
      expect(bankerDraws(5, null), isTrue);
      expect(bankerDraws(6, null), isFalse);
      expect(bankerDraws(3, 8), isFalse);
      expect(bankerDraws(3, 9), isTrue);
      expect(bankerDraws(4, 1), isFalse);
      expect(bankerDraws(6, 7), isTrue);
      expect(bankerDraws(7, 6), isFalse);
    });
    test('Auszahlung', () {
      final tie = BacRound([c(10), c(7)], [c(13), c(7)]);
      expect(tie.winner, BacWinner.tie);
      expect(tie.payout(BacBet.player, 100), 100);
      expect(tie.payout(BacBet.tie, 100), 900);
      final bank = BacRound([c(10), c(2)], [c(13), c(8)]);
      expect(bank.payout(BacBet.banker, 100), 190);
      expect(bank.payout(BacBet.player, 100), 0);
    });
    test('Schuh spielt viele Runden', () {
      final s = BaccaratShoe(rng: Random(1));
      for (var i = 0; i < 500; i++) {
        final r = s.play();
        expect(r.player.length, inInclusiveRange(2, 3));
        expect(r.banker.length, inInclusiveRange(2, 3));
      }
    });
  });

  group('Sic Bo', () {
    test('Klein verliert beim Drilling', () {
      expect(const SicSmall().payout([2, 2, 2], 10), 0);
      expect(const SicSmall().payout([1, 2, 3], 10), 20);
      expect(const SicSingle(5).payout([5, 5, 1], 10), 30);
      expect(const SicTriple(4).payout([4, 4, 4], 10), 1510);
      expect(const SicTotal(4).payout([1, 1, 2], 10), 510);
    });
  });

  group('Keno', () {
    test('Tabelle', () {
      expect(kenoPayout(1, 1, 10), 30);
      expect(kenoPayout(10, 0, 10), 20);
      expect(kenoPayout(5, 2, 10), 0);
    });
  });
}
