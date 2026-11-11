import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/debug_log.dart';
import 'package:gluckspfennig/core/version.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Versionsnummer passt zur pubspec', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.substring(8).trim(), appVersion);
  });

  test('Protokoll: Puffer, Speichern, Export', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = DebugLog.instance..attach(prefs);
    log.clear();
    for (var i = 0; i < DebugLog.maxEntries + 50; i++) {
      log.info('test', 'Eintrag $i');
    }
    expect(log.entries.length, DebugLog.maxEntries);
    expect(log.entries.first.text, 'Eintrag 50');
    log.detail('test', 'nur ausführlich');
    expect(log.entries.last.text, isNot('nur ausführlich'));
    try {
      throw StateError('kaputt');
    } catch (e, st) {
      log.error('test', e, st);
    }
    expect(log.entries.last.level, LogLevel.error);
    expect(log.entries.last.text, contains('kaputt'));
    expect(log.entries.last.text, contains('debug_log_test.dart'), reason: 'Stacktrace dabei');
    final saved = prefs.getString('debug.log')!;
    expect(saved, contains('kaputt'));
    expect(log.export(minLevel: LogLevel.error).split('\n').where((l) => l.contains('[test]')).length, 1);
    // Neustart: gespeicherte Einträge kommen zurück
    log.attach(prefs);
    expect(log.entries.any((e) => e.text.contains('kaputt')), isTrue);
  });
}
