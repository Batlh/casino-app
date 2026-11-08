import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/cards/playing_card.dart';

/// Dauerhaft gespeicherte Einstellungen der App.
class Settings extends ChangeNotifier {
  Settings(this._prefs)
      : _cardNames = CardNames.values.firstWhere(
          (v) => v.name == _prefs.getString(_cardNamesKey),
          orElse: () => CardNames.international,
        ),
        _penaltyEndsTurn = _prefs.getBool(_penaltyKey) ?? true,
        _jackOnJack = _prefs.getBool(_jackKey) ?? true,
        _cardScale = (_prefs.getDouble(_scaleKey) ?? 1.0).clamp(minCardScale, maxCardScale),
        _einsStackDraws = _prefs.getBool(_einsStackKey) ?? true,
        _einsCallRequired = _prefs.getBool(_einsCallKey) ?? true;

  static const _cardNamesKey = 'settings.cardNames';
  static const _penaltyKey = 'settings.mauPenaltyEndsTurn';
  static const _jackKey = 'settings.mauJackOnJack';
  static const _scaleKey = 'settings.cardScale';
  static const _einsStackKey = 'settings.einsStackDraws';
  static const _einsCallKey = 'settings.einsCallRequired';
  static const minCardScale = 0.8;
  static const maxCardScale = 1.6;

  final SharedPreferences _prefs;
  CardNames _cardNames;
  bool _penaltyEndsTurn;
  bool _jackOnJack;
  double _cardScale;
  bool _einsStackDraws;
  bool _einsCallRequired;

  /// Eins!: Plus-Karten dürfen gestapelt werden.
  bool get einsStackDraws => _einsStackDraws;

  set einsStackDraws(bool value) {
    if (value == _einsStackDraws) return;
    _einsStackDraws = value;
    _prefs.setBool(_einsStackKey, value);
    notifyListeners();
  }

  /// Eins!: Wer auf eine Karte kommt, muss rufen.
  bool get einsCallRequired => _einsCallRequired;

  set einsCallRequired(bool value) {
    if (value == _einsCallRequired) return;
    _einsCallRequired = value;
    _prefs.setBool(_einsCallKey, value);
    notifyListeners();
  }

  CardNames get cardNames => _cardNames;

  set cardNames(CardNames value) {
    if (value == _cardNames) return;
    _cardNames = value;
    _prefs.setString(_cardNamesKey, value.name);
    notifyListeners();
  }

  /// Mau Mau: Wer Strafkarten zieht, ist danach fertig.
  bool get penaltyEndsTurn => _penaltyEndsTurn;

  set penaltyEndsTurn(bool value) {
    if (value == _penaltyEndsTurn) return;
    _penaltyEndsTurn = value;
    _prefs.setBool(_penaltyKey, value);
    notifyListeners();
  }

  /// Mau Mau: Ein Bube darf auf einen Buben.
  bool get jackOnJack => _jackOnJack;

  set jackOnJack(bool value) {
    if (value == _jackOnJack) return;
    _jackOnJack = value;
    _prefs.setBool(_jackKey, value);
    notifyListeners();
  }

  /// Kartengröße in den Kartenspielen, 1 ist die automatische Größe.
  double get cardScale => _cardScale;

  set cardScale(double value) {
    final v = value.clamp(minCardScale, maxCardScale);
    if (v == _cardScale) return;
    _cardScale = v;
    _prefs.setDouble(_scaleKey, v);
    notifyListeners();
  }
}
