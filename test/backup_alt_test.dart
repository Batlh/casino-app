import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/backup.dart';
import 'package:gluckspfennig/core/wallet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Echte Sicherung aus Version 0.8.5 (Windows, vor dem Umzug auf den neuen Paketnamen).
void main() {
  test('Sicherung aus 0.8.5 lässt sich in die aktuelle Version laden', () async {
    final text = File('test/fixtures/spielstand-0.8.5.json').readAsStringSync();
    expect(inspectBackup(text).coins, 10930);
    SharedPreferences.setMockInitialValues({'wallet.balance': 5000, 'debug.log': '[]'});
    final prefs = await SharedPreferences.getInstance();
    final n = await importBackup(prefs, text);
    expect(n, 4);
    expect(Wallet(prefs).balance, 10930);
    expect(prefs.getBool('sfx.enabled'), isFalse);
    expect(prefs.getString('settings.cardNames'), 'deutsch');
    expect(prefs.getString('debug.log'), '[]');
    // Und wieder sichern: gleiches Format, gleicher Stand
    final again = exportBackup(prefs);
    expect(inspectBackup(again).coins, 10930);
  });
}
