import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/umzug.dart';
import 'package:gluckspfennig/core/updater.dart';

void main() {
  test('Alter Speicherort aus dem neuen', () {
    expect(oldSupportPath(r'C:\Users\a\AppData\Roaming\io.github.batlh\gluckspfennig'), r'C:\Users\a\AppData\Roaming\de.privat\gluckspfennig');
    expect(oldSupportPath('/home/a/.local/share/io.github.batlh.gluckspfennig'), '/home/a/.local/share/de.privat.gluckspfennig');
    expect(oldSupportPath('/home/a/.local/share/de.privat.gluckspfennig'), isNull);
  });

  test('Am PC werden die alten Daten einmal übernommen', () async {
    final root = Directory.systemTemp.createTempSync('umzug');
    addTearDown(() => root.deleteSync(recursive: true));
    final old = Directory('${root.path}/de.privat.gluckspfennig')..createSync();
    File('${old.path}/$prefsFile').writeAsStringSync('{"flutter.wallet.balance":1234}');
    final fresh = Directory('${root.path}/io.github.batlh.gluckspfennig');
    final moved = await moveDesktopData(supportDir: () async => fresh);
    expect(moved, isNotNull);
    expect(File('${fresh.path}/$prefsFile').readAsStringSync(), contains('1234'));
    // Beim nächsten Start liegt schon etwas da: nichts überschreiben
    File('${old.path}/$prefsFile').writeAsStringSync('{"flutter.wallet.balance":1}');
    expect(await moveDesktopData(supportDir: () async => fresh), isNull);
    expect(File('${fresh.path}/$prefsFile').readAsStringSync(), contains('1234'));
  });

  test('Hinweise im Release-Text', () {
    const notes = 'Stand vom …\n\n! Vor dem Update sichern\n- Neu: etwas\n  ! Zweiter Hinweis\n';
    expect(updateNotices(notes), ['Vor dem Update sichern', 'Zweiter Hinweis']);
    expect(updateNotices('- nur Neues'), isEmpty);
  });
}
