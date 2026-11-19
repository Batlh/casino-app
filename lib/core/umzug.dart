import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'debug_log.dart';

/// Umzug vom alten Paketnamen de.privat.gluckspfennig auf io.github.batlh.gluckspfennig.
///
/// Am PC hängt der Speicherort der Einstellungen am Namen (Windows: `%APPDATA%\Firma\Produkt`,
/// Linux: `~/.local/share/Kennung`). Beim ersten Start mit dem neuen Namen holt die App die alten Daten selbst.
/// Android und macOS trennen die Apps streng; dort bleibt nur die Sicherung (Einstellungen → Spielstand sichern).
const oldOrg = 'de.privat';
const newOrg = 'io.github.batlh';
const prefsFile = 'shared_preferences.json';

/// Läuft die App schon unter dem neuen Namen? Erst dann fragt die Lobby nach einer Sicherung aus der alten App.
const packageRenamed = false;

/// Beim Start nichts gespeichert gefunden (setzt main.dart).
bool freshInstall = false;

/// Alter Ordner zum neuen Speicherort, oder null, wenn der Pfad den neuen Namen nicht enthält.
String? oldSupportPath(String newPath) {
  final i = newPath.lastIndexOf(newOrg);
  if (i < 0) return null;
  return newPath.replaceRange(i, i + newOrg.length, oldOrg);
}

/// Kopiert die alten Einstellungen in den neuen Ordner, wenn dort noch keine liegen. Gibt den alten Pfad zurück.
Future<String?> moveDesktopData({Future<Directory> Function()? supportDir}) async {
  if (supportDir == null && !(Platform.isWindows || Platform.isLinux)) return null;
  try {
    final dir = await (supportDir ?? getApplicationSupportDirectory)();
    final target = File('${dir.path}${Platform.pathSeparator}$prefsFile');
    if (target.existsSync()) return null;
    final old = oldSupportPath(dir.path);
    if (old == null) return null;
    final source = File('$old${Platform.pathSeparator}$prefsFile');
    if (!source.existsSync()) return null;
    dir.createSync(recursive: true);
    source.copySync(target.path);
    return source.path;
  } catch (e) {
    debugLog.warn('umzug', 'Alte Daten nicht übernommen: $e');
    return null;
  }
}
