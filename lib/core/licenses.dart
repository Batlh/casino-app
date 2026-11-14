import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lizenztexte der mitgelieferten Schriften (SIL Open Font License 1.1) für die
/// Lizenzseite. Die Lizenzen der Pakete sammelt Flutter selbst.
const fontLicenses = {
  'Barlow (Schrift)': 'assets/fonts/Barlow-OFL.txt',
  'Shrikhand (Schrift)': 'assets/fonts/Shrikhand-OFL.txt',
  'Noto Serif JP (Schrift)': 'assets/fonts/NotoSerifJP-OFL.txt',
};

/// Quellcode der App.
const repoUrl = 'https://github.com/Batlh/casino-app';

/// Neueste Version mit APK und Windows-Datei.
const releasesUrl = '$repoUrl/releases/latest';

/// Zeile unter dem App-Namen auf der Lizenzseite.
const appLegalese = '© 2026 Batlh · MIT-Lizenz\nNur Spielmünzen, kein Echtgeld.\n$repoUrl';

var _registered = false;

/// Trägt die Schriftlizenzen einmalig ins LicenseRegistry ein.
void registerFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final e in fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks([e.key], await rootBundle.loadString(e.value));
    }
  });
}
