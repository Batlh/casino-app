import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/progress.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late Wallet wallet;
  late Progress pr;
  var now = DateTime(2026, 11, 20, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 20, 10);
    wallet = Wallet(prefs, clock: () => now);
    pr = Progress(clock: () => now)..attach(prefs, wallet);
  });

  test('Einsätze und Gewinne zählen für das offene Spiel, Lobby und Boni nicht', () {
    wallet.spend(100); // Lobby: zählt nicht
    pr.current = 'Roulette';
    wallet.spend(50);
    wallet.spend(50);
    wallet.credit(1750);
    pr.current = null;
    wallet.claimBonus();
    wallet.refillIfBroke();
    final s = pr.stats['Roulette']!;
    expect(s.rounds, 2);
    expect(s.staked, 100);
    expect(s.paid, 1750);
    expect(s.best, 1750);
    expect(pr.stats.length, 1);
    expect(pr.counters['bonus'], 1);
    expect(pr.unlocked.keys, containsAll(['erste_runde', 'gewinn_1000']));
    expect(pr.unlocked.containsKey('gewinn_10000'), isFalse);
  });

  test('Erfolg wird gemeldet und bleibt nach Neustart erhalten', () {
    Achievement? got;
    pr.justUnlocked.addListener(() => got = pr.justUnlocked.value);
    pr.event('royal_flush');
    expect(got?.id, 'royal_flush');
    final again = Progress(clock: () => now)..attach(prefs, wallet);
    expect(again.unlocked.containsKey('royal_flush'), isTrue);
    expect(again.counters['e.royal_flush'], 1);
  });

  test('Tagesaufgaben: gleich für denselben Tag, neu am nächsten, Abholen mit Extra', () {
    final a = dailyTasksFor('2026-11-20');
    expect([for (final t in a) t.key], [for (final t in dailyTasksFor('2026-11-20')) t.key]);
    expect(a.length, 3);
    expect(a.map((t) => t.key).toSet().length, 3);
    // Alle drei erfüllen
    pr.current = 'Black Jack';
    for (final t in pr.daily.tasks) {
      switch (t.key) {
        case 'runden':
          for (var i = 0; i < 25; i++) {
            wallet.spend(10);
          }
        case 'verschieden':
          for (final g in ['A', 'B', 'C']) {
            pr.current = g;
            wallet.spend(10);
          }
        case 'gewinn':
          wallet.credit(600);
        case 'einsatz':
          wallet.spend(3000);
        default:
          if (t.key.startsWith('spiel:')) {
            pr.current = t.key.substring(6);
            wallet.spend(10);
          } else {
            pr.event(t.key.substring(2));
          }
      }
    }
    final before = wallet.balance;
    var total = 0;
    for (final t in pr.daily.tasks) {
      expect(pr.dailyDone(t), isTrue, reason: t.key);
      total += pr.claimDaily(t);
    }
    final rewards = pr.daily.tasks.fold(0, (s, t) => s + t.reward);
    expect(total, rewards + dailyAllBonus);
    expect(wallet.balance, before + total);
    // Doppelt abholen geht nicht, und Belohnungen zählen nicht als Spielgewinn
    expect(pr.claimDaily(pr.daily.tasks.first), 0);
    expect(pr.counters['aufgaben'], 3);
    // Nächster Tag: neue Aufgaben, nichts erledigt
    now = now.add(const Duration(days: 1));
    expect(pr.daily.date, '2026-11-21');
    expect(pr.dailyReady, 0);
  });
}
