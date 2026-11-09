import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/cards/playing_card.dart';
import '../games/eins/eins_engine.dart';

/// Tempo der Computergegner.
enum BotSpeed {
  slow('Gemütlich', 2.4),
  normal('Normal', 1.6),
  fast('Schnell', 1.0);

  const BotSpeed(this.label, this.factor);
  final String label;
  final double factor;
}

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
        _einsCallRequired = _prefs.getBool(_einsCallKey) ?? true,
        _einsChallenge = _prefs.getBool(_einsChallengeKey) ?? true,
        _einsExpansion = _prefs.getBool(_einsExpansionKey) ?? false,
        _pinballHigh = _prefs.getInt(_pinballHighKey) ?? 0,
        _botSpeed = BotSpeed.values.firstWhere(
          (v) => v.name == _prefs.getString(_botSpeedKey),
          orElse: () => BotSpeed.normal,
        ),
        _einsMode = EinsMode.values.firstWhere(
          (v) => v.name == _prefs.getString(_einsModeKey),
          orElse: () => EinsMode.classic,
        );

  static const _cardNamesKey = 'settings.cardNames';
  static const _penaltyKey = 'settings.mauPenaltyEndsTurn';
  static const _jackKey = 'settings.mauJackOnJack';
  static const _scaleKey = 'settings.cardScale';
  static const _einsStackKey = 'settings.einsStackDraws';
  static const _einsCallKey = 'settings.einsCallRequired';
  static const _einsModeKey = 'settings.einsMode';
  static const _einsChallengeKey = 'settings.einsChallenge';
  static const _einsExpansionKey = 'settings.einsNoMercyExpansion';
  static const _botSpeedKey = 'settings.botSpeed';
  static const _pinballHighKey = 'pinball.highscore';
  static const minCardScale = 0.8;
  static const maxCardScale = 1.6;

  final SharedPreferences _prefs;

  // ---------- Spielstände ----------

  /// Gespeicherter Spielstand eines Spiels, oder null.
  Map<String, dynamic>? loadGame(String id) {
    final raw = _prefs.getString('save.$id');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  final Map<String, String> _lastSaved = {};

  /// Speichert den Spielstand, wenn er sich geändert hat.
  void saveGame(String id, Map<String, dynamic> data) {
    final raw = jsonEncode(data);
    if (_lastSaved[id] == raw) return;
    _lastSaved[id] = raw;
    _prefs.setString('save.$id', raw);
  }

  void clearGame(String id) {
    _lastSaved.remove(id);
    _prefs.remove('save.$id');
  }
  CardNames _cardNames;
  bool _penaltyEndsTurn;
  bool _jackOnJack;
  double _cardScale;
  bool _einsStackDraws;
  bool _einsCallRequired;
  EinsMode _einsMode;
  bool _einsChallenge;
  bool _einsExpansion;
  BotSpeed _botSpeed;
  int _pinballHigh;

  /// Höchste Punktzahl am Flipper.
  int get pinballHigh => _pinballHigh;

  set pinballHigh(int value) {
    _pinballHigh = value;
    _prefs.setInt(_pinballHighKey, value);
    notifyListeners();
  }

  /// Wie schnell die Computergegner ziehen.
  BotSpeed get botSpeed => _botSpeed;

  set botSpeed(BotSpeed value) {
    if (value == _botSpeed) return;
    _botSpeed = value;
    _prefs.setString(_botSpeedKey, value.name);
    notifyListeners();
  }

  /// Wartezeit vor einem Computerzug, gestreckt nach dem gewählten Tempo.
  Duration botDelay(int ms) => Duration(milliseconds: (ms * _botSpeed.factor).round());

  /// Eins!: Farbwahl-Strafkarten nur ohne passende Farbe, der Nächste darf anzweifeln.
  bool get einsChallenge => _einsChallenge;

  set einsChallenge(bool value) {
    if (value == _einsChallenge) return;
    _einsChallenge = value;
    _prefs.setBool(_einsChallengeKey, value);
    notifyListeners();
  }

  /// Eins! Gnadenlos: mit den Karten und Münzen der Erweiterung.
  bool get einsExpansion => _einsExpansion;

  set einsExpansion(bool value) {
    if (value == _einsExpansion) return;
    _einsExpansion = value;
    _prefs.setBool(_einsExpansionKey, value);
    notifyListeners();
  }

  /// Eins!: zuletzt gewählte Spielweise.
  EinsMode get einsMode => _einsMode;

  set einsMode(EinsMode value) {
    if (value == _einsMode) return;
    _einsMode = value;
    _prefs.setString(_einsModeKey, value.name);
    notifyListeners();
  }

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
