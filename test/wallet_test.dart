import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/scope.dart';
import 'package:gluckspfennig/core/settings.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('Startguthaben und Speichern', () {
    final w = Wallet(prefs);
    expect(w.balance, Wallet.startBalance);
    expect(w.spend(1000), isTrue);
    expect(Wallet(prefs).balance, Wallet.startBalance - 1000);
  });

  test('Kein Einsatz über dem Guthaben', () {
    final w = Wallet(prefs);
    expect(w.spend(Wallet.startBalance + 1), isFalse);
    expect(w.balance, Wallet.startBalance);
  });

  test('Tagesbonus nur einmal pro Tag', () {
    var now = DateTime(2026, 11, 3, 23, 50);
    final w = Wallet(prefs, clock: () => now);
    expect(w.claimBonus(), Wallet.dailyBonus);
    expect(w.claimBonus(), 0);
    expect(w.bonusAvailable, isFalse);
    now = DateTime(2026, 11, 4, 0, 5);
    expect(w.bonusAvailable, isTrue);
  });

  test('Nachfüllen nur wenn kein Einsatz mehr möglich ist', () {
    final w = Wallet(prefs);
    w.spend(Wallet.startBalance - Wallet.minBet);
    expect(w.refillIfBroke(), isFalse);
    w.spend(5);
    expect(w.refillIfBroke(), isTrue);
    expect(w.balance, 5 + Wallet.refillAmount);
    expect(w.refills.value, 1);
  });

  test('Bildkarten: J und Q als Standard, B und D wählbar und gespeichert', () {
    const bube = PlayingCard(11, Suit.spades);
    const dame = PlayingCard(12, Suit.hearts);
    final s = Settings(prefs);
    expect(s.cardNames, CardNames.international);
    expect(bube.rankLabel(s.cardNames), 'J');
    expect(dame.rankLabel(s.cardNames), 'Q');
    s.cardNames = CardNames.deutsch;
    expect(bube.rankLabel(s.cardNames), 'B');
    expect(dame.rankLabel(s.cardNames), 'D');
    expect(Settings(prefs).cardNames, CardNames.deutsch);
  });

  test('Tausenderpunkte', () {
    expect(formatCoins(0), '0');
    expect(formatCoins(999), '999');
    expect(formatCoins(1000), '1.000');
    expect(formatCoins(1234567), '1.234.567');
    expect(formatCoins(-2500), '-2.500');
  });
}
