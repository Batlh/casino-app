import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/cards/playing_card.dart';

/// Dauerhaft gespeicherte Einstellungen der App.
class Settings extends ChangeNotifier {
  Settings(this._prefs)
      : _cardNames = CardNames.values.firstWhere(
          (v) => v.name == _prefs.getString(_cardNamesKey),
          orElse: () => CardNames.international,
        );

  static const _cardNamesKey = 'settings.cardNames';
  final SharedPreferences _prefs;
  CardNames _cardNames;

  CardNames get cardNames => _cardNames;

  set cardNames(CardNames value) {
    if (value == _cardNames) return;
    _cardNames = value;
    _prefs.setString(_cardNamesKey, value.name);
    notifyListeners();
  }
}
