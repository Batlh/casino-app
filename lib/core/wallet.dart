import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Münzkonto. Münzen haben keinen Geldwert und lassen sich weder kaufen
/// noch auszahlen.
class Wallet extends ChangeNotifier {
  Wallet(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _balance = _prefs.getInt(_balanceKey) ?? startBalance;
    _lastBonus = _prefs.getString(_bonusKey);
  }

  static const startBalance = 5000;
  static const dailyBonus = 1000;
  static const refillAmount = 2000;

  /// Kleinster Einsatz in allen Spielen. Darunter wird nachgefüllt.
  static const minBet = 10;

  static const _balanceKey = 'wallet.balance';
  static const _bonusKey = 'wallet.lastBonus';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  late int _balance;
  String? _lastBonus;

  /// Zählt hoch, sobald nachgefüllt wurde. Die Oberfläche zeigt dann einen Hinweis.
  final ValueNotifier<int> refills = ValueNotifier<int>(0);

  /// Wie viel zuletzt nachgefüllt wurde.
  int lastRefill = refillAmount;

  int get balance => _balance;

  String get _today {
    final d = _clock();
    return '${d.year}-${d.month}-${d.day}';
  }

  bool get bonusAvailable => _lastBonus != _today;

  bool canAfford(int amount) => amount <= _balance;

  /// Zieht den Einsatz ab. Liefert false, wenn das Guthaben nicht reicht.
  /// Beobachter für Statistik und Erfolge (setzt Progress).
  void Function(int amount)? onSpend;
  void Function(int amount)? onCredit;
  void Function()? onBonus;

  bool spend(int amount) {
    if (amount <= 0 || amount > _balance) return false;
    _set(_balance - amount);
    onSpend?.call(amount);
    return true;
  }

  void credit(int amount) {
    if (amount <= 0) return;
    _set(_balance + amount);
    onCredit?.call(amount);
  }

  /// Belohnung (Tagesaufgabe, Erfolg): Münzen dazu, zählt aber nicht als Gewinn eines Spiels.
  void addReward(int amount) {
    if (amount <= 0) return;
    _set(_balance + amount);
  }

  /// Schreibt den Tagesbonus gut. Liefert den Betrag, oder 0 wenn er schon abgeholt ist.
  int claimBonus() {
    if (!bonusAvailable) return 0;
    _lastBonus = _today;
    _prefs.setString(_bonusKey, _lastBonus!);
    _set(_balance + dailyBonus);
    onBonus?.call();
    return dailyBonus;
  }

  /// Am Ende einer Runde und beim Öffnen eines Spiels aufrufen. Wer den kleinsten Einsatz des Spiels ([min])
  /// nicht mehr bezahlen kann, bekommt neue Münzen, mindestens so viele, dass es wieder reicht.
  bool refillIfBroke({int min = minBet}) {
    final need = math.max(min, minBet);
    if (_balance >= need) return false;
    lastRefill = math.max(refillAmount, need - _balance);
    _set(_balance + lastRefill);
    refills.value++;
    return true;
  }

  void _set(int value) {
    _balance = value;
    _prefs.setInt(_balanceKey, value);
    notifyListeners();
  }

  @override
  void dispose() {
    refills.dispose();
    super.dispose();
  }
}
