import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lizenzen der Schriften sind eingetragen und lesbar', () async {
    registerFontLicenses();
    registerFontLicenses(); // zweimal aufrufen trägt nichts doppelt ein
    final entries = await LicenseRegistry.licenses.toList();
    for (final name in fontLicenses.keys) {
      final found = entries.where((e) => e.packages.contains(name)).toList();
      expect(found, hasLength(1), reason: name);
      final text = found.first.paragraphs.map((p) => p.text).join(' ');
      expect(text, contains('SIL OPEN FONT LICENSE'), reason: name);
    }
  });
}
