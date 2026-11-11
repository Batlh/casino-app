import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'version.dart';

/// Lädt die App nach einem Import mit den neuen Daten neu (setzt main.dart).
void Function()? restartApp;

/// Kennung der Sicherungsdatei, damit keine fremden Dateien eingelesen werden.
const backupFormat = 'gluckspfennig-spielstand';

/// Wird beim Import nicht angefasst: das Fehlerprotokoll gehört zum Gerät.
bool _skip(String key) => key.startsWith('debug.');

/// Alle Spielstände, Münzen und Einstellungen als JSON-Text.
String exportBackup(SharedPreferences prefs, {DateTime? now}) {
  final values = <String, Object?>{};
  for (final k in prefs.getKeys().toList()..sort()) {
    if (_skip(k)) continue;
    final v = prefs.get(k);
    values[k] = switch (v) {
      bool b => {'t': 'b', 'v': b},
      int i => {'t': 'i', 'v': i},
      double d => {'t': 'd', 'v': d},
      String s => {'t': 's', 'v': s},
      List<String> l => {'t': 'l', 'v': l},
      _ => null,
    };
  }
  values.removeWhere((k, v) => v == null);
  return const JsonEncoder.withIndent(' ').convert({
    'format': backupFormat,
    'version': 1,
    'app': appVersion,
    'exported': (now ?? DateTime.now()).toIso8601String(),
    'values': values,
  });
}

/// Dateiname mit Datum, z. B. gluckspfennig-spielstand-2026-11-11.json.
String backupFileName([DateTime? now]) {
  final d = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '$backupFormat-${d.year}-${two(d.month)}-${two(d.day)}.json';
}

/// Prüft den Text und gibt Münzstand und Zahl der Spielstände zurück, ohne etwas zu ändern.
({int coins, int saves, String app}) inspectBackup(String text) {
  final m = _parse(text);
  final values = m['values'] as Map<String, dynamic>;
  final coins = (values['wallet.balance'] as Map?)?['v'];
  final saves = values.keys.where((k) => k.startsWith('save.') && !k.startsWith('save.seats.') && !k.startsWith('save.rules.')).length;
  return (coins: coins is int ? coins : 0, saves: saves, app: '${m['app'] ?? '?'}');
}

/// Ersetzt alle Spielstände, Münzen und Einstellungen durch die aus [text]. Gibt die Zahl der Einträge zurück.
Future<int> importBackup(SharedPreferences prefs, String text) async {
  final m = _parse(text);
  final values = m['values'] as Map<String, dynamic>;
  for (final k in prefs.getKeys().toList()) {
    if (!_skip(k)) await prefs.remove(k);
  }
  var n = 0;
  for (final e in values.entries) {
    if (_skip(e.key)) continue;
    final v = e.value as Map<String, dynamic>;
    final x = v['v'];
    switch (v['t']) {
      case 'b':
        await prefs.setBool(e.key, x as bool);
      case 'i':
        await prefs.setInt(e.key, x as int);
      case 'd':
        await prefs.setDouble(e.key, (x as num).toDouble());
      case 's':
        await prefs.setString(e.key, x as String);
      case 'l':
        await prefs.setStringList(e.key, [for (final s in x as List) s as String]);
      default:
        continue;
    }
    n++;
  }
  return n;
}

Map<String, dynamic> _parse(String text) {
  final Object? j;
  try {
    j = jsonDecode(text.trim());
  } on FormatException {
    throw const FormatException('Das ist keine Spielstand-Datei von Glückspfennig');
  }
  if (j is! Map<String, dynamic> || j['format'] != backupFormat || j['values'] is! Map<String, dynamic>) {
    throw const FormatException('Das ist keine Spielstand-Datei von Glückspfennig');
  }
  final values = j['values'] as Map<String, dynamic>;
  for (final v in values.values) {
    if (v is! Map<String, dynamic> || v['t'] is! String || !v.containsKey('v')) {
      throw const FormatException('Die Spielstand-Datei ist beschädigt');
    }
  }
  return j;
}
