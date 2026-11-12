import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'version.dart';

enum LogLevel { info, warn, error }

class LogEntry {
  LogEntry(this.time, this.level, this.area, this.text);

  final DateTime time;
  final LogLevel level;
  final String area;
  final String text;

  String get line {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${time.millisecond.toString().padLeft(3, '0')}';
    final l = switch (level) { LogLevel.info => 'I', LogLevel.warn => 'W', LogLevel.error => 'E' };
    return '${time.year}-${two(time.month)}-${two(time.day)} $t $l [$area] $text';
  }

  List<Object> toJson() => [time.millisecondsSinceEpoch, level.index, area, text];

  static LogEntry? fromJson(Object? j) {
    if (j is! List || j.length != 4) return null;
    final ms = j[0];
    final lv = j[1];
    if (ms is! int || lv is! int || lv < 0 || lv >= LogLevel.values.length) return null;
    return LogEntry(DateTime.fromMillisecondsSinceEpoch(ms), LogLevel.values[lv], '${j[2]}', '${j[3]}');
  }
}

/// Fehler- und Ablaufprotokoll der App. Bleibt auf dem Gerät; der Nutzer kann es in den
/// Einstellungen unter „Fehlersuche“ ansehen und kopieren.
class DebugLog extends ChangeNotifier {
  DebugLog._();

  static final DebugLog instance = DebugLog._();

  /// Einträge im Speicher.
  static const maxEntries = 2000;

  /// Einträge, die einen Neustart überleben.
  static const keptEntries = 500;

  /// Länge eines einzelnen Eintrags; Stacktraces werden darauf gekürzt.
  static const maxText = 4000;

  static const _key = 'debug.log';
  static const _verboseKey = 'debug.verbose';

  final ListQueue<LogEntry> _entries = ListQueue();
  SharedPreferences? _prefs;
  Timer? _saveTimer;
  bool _notifyQueued = false;
  bool _verbose = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Ausführliche Einträge (Tippen, Physik). Fehler werden immer aufgezeichnet.
  bool get verbose => _verbose;
  set verbose(bool v) {
    if (v == _verbose) return;
    _verbose = v;
    _prefs?.setBool(_verboseKey, v);
    info('debug', v ? 'Fehlersuche eingeschaltet' : 'Fehlersuche ausgeschaltet');
  }

  /// Lädt die gespeicherten Einträge der letzten Sitzungen.
  void attach(SharedPreferences prefs) {
    _prefs = prefs;
    _verbose = prefs.getBool(_verboseKey) ?? false;
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final old = [for (final j in list) LogEntry.fromJson(j)].whereType<LogEntry>();
        final now = _entries.toList();
        _entries
          ..clear()
          ..addAll(old)
          ..addAll(now);
        _trim();
      } catch (_) {
        // Kaputtes Protokoll: verwerfen
      }
    }
  }

  void info(String area, String text) => _add(LogLevel.info, area, text);
  void warn(String area, String text) => _add(LogLevel.warn, area, text);

  /// Nur bei eingeschalteter Fehlersuche.
  void detail(String area, String text) {
    if (_verbose) _add(LogLevel.info, area, text);
  }

  void error(String area, Object error, [StackTrace? stack]) {
    final s = StringBuffer('$error');
    if (stack != null) s.write('\n$stack');
    _add(LogLevel.error, area, s.toString());
  }

  void _add(LogLevel level, String area, String text) {
    final t = text.length > maxText ? '${text.substring(0, maxText)} …' : text;
    _entries.add(LogEntry(DateTime.now(), level, area, t));
    _trim();
    if (kDebugMode && level != LogLevel.info) debugPrint('[$area] $t');
    // Fehler sofort sichern, sonst gesammelt
    if (level == LogLevel.error) {
      _save();
    } else {
      _saveTimer ??= Timer(const Duration(seconds: 3), _save);
    }
    if (!_notifyQueued) {
      _notifyQueued = true;
      // Nicht mitten im Aufbau eines Bildes benachrichtigen
      scheduleMicrotask(() {
        _notifyQueued = false;
        notifyListeners();
      });
    }
  }

  void _trim() {
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final prefs = _prefs;
    if (prefs == null) return;
    final keep = _entries.length > keptEntries ? _entries.skip(_entries.length - keptEntries) : _entries;
    prefs.setString(_key, jsonEncode([for (final e in keep) e.toJson()]));
  }

  void clear() {
    _entries.clear();
    _save();
    notifyListeners();
  }

  /// Text zum Kopieren und Weiterschicken.
  String export({LogLevel minLevel = LogLevel.info, String? area}) {
    final out = StringBuffer()
      ..writeln('Glückspfennig $appVersion · ${defaultTargetPlatform.name}')
      ..writeln('Exportiert ${DateTime.now().toIso8601String()}')
      ..writeln();
    for (final e in _entries) {
      if (e.level.index < minLevel.index) continue;
      if (area != null && e.area != area && !e.area.startsWith('$area.')) continue;
      out.writeln(e.line);
    }
    return out.toString();
  }
}

/// Kurzform für die Spiele.
DebugLog get debugLog => DebugLog.instance;
