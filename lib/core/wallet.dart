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

  int get balance => _balance;

  String get _today {
    final d = _clock();
    return '${d.year}-${d.month}-${d.day}';
  }

  bool get bonusAvailable => _lastBonus != _today;

  bool canAfford(int amount) => amount <= _balance;

  /// Zieht den Einsatz ab. Liefert false, wenn das Guthaben nicht reicht.
  bool spend(int amount) {
    if (amount <= 0 || amount > _balance) return false;
    _set(_balance - amount);
    return true;
  }

  void credit(int amount) {
    if (amount <= 0) return;
    _set(_balance + amount);
  }

  /// Schreibt den Tagesbonus gut. Liefert den Betrag, oder 0 wenn er schon abgeholt ist.
  int claimBonus() {
    if (!bonusAvailable) return 0;
    _lastBonus = _today;
    _prefs.setString(_bonusKey, _lastBonus!);
    _set(_balance + dailyBonus);
    return dailyBonus;
  }

  /// Am Ende einer Runde aufrufen. Wer nicht mehr setzen kann, bekommt neue Münzen.
  bool refillIfBroke() {
    if (_balance >= minBet) return false;
    _set(_balance + refillAmount);
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
