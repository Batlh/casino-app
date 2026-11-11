import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Sichern und Laden ersetzt alles außer dem Protokoll', () async {
    SharedPreferences.setMockInitialValues({
      'wallet.balance': 12345,
      'settings.cardScale': 1.2,
      'sfx.enabled': false,
      'save.memory': '{"a":1}',
      'save.seats.memory': '{"seats":[]}',
      'list': <String>['x', 'y'],
      'debug.log': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    final text = exportBackup(prefs, now: DateTime(2026, 11, 11));
    expect(text, isNot(contains('debug.log')));
    final info = inspectBackup(text);
    expect(info.coins, 12345);
    expect(info.saves, 1);
    expect(backupFileName(DateTime(2026, 11, 1)), 'gluckspfennig-spielstand-2026-11-01.json');

    // Anderes Gerät: anderer Stand
    await prefs.clear();
    await prefs.setInt('wallet.balance', 1);
    await prefs.setString('save.old', 'weg');
    await prefs.setString('debug.log', 'bleibt');
    final n = await importBackup(prefs, text);
    expect(n, 6);
    expect(prefs.getInt('wallet.balance'), 12345);
    expect(prefs.getDouble('settings.cardScale'), 1.2);
    expect(prefs.getBool('sfx.enabled'), false);
    expect(prefs.getStringList('list'), ['x', 'y']);
    expect(prefs.getString('save.old'), isNull);
    expect(prefs.getString('debug.log'), 'bleibt');
  });

  test('Fremde Dateien werden abgelehnt, ohne etwas zu ändern', () async {
    SharedPreferences.setMockInitialValues({'wallet.balance': 7});
    final prefs = await SharedPreferences.getInstance();
    expect(() => inspectBackup('hallo'), throwsFormatException);
    expect(() => inspectBackup('{"format":"anders","values":{}}'), throwsFormatException);
    await expectLater(importBackup(prefs, '{"x":1}'), throwsFormatException);
    expect(prefs.getInt('wallet.balance'), 7);
  });
}
