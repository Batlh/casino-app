import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'debug_log.dart';
import 'scope.dart';
import 'theme.dart';
import 'version.dart';

/// Sucht auf GitHub nach einer neuen Version und installiert sie auf Wunsch.
///
/// Übertragen wird nichts außer der üblichen Anfrage an die öffentliche GitHub-Schnittstelle:
/// keine Kennung, kein Spielstand, keine Nutzungsdaten.
const _releasesApi = 'https://api.github.com/repos/Batlh/casino-app/releases/latest';
const _channel = MethodChannel('gluckspfennig/update');

/// Eine veröffentlichte Version.
class Release {
  const Release({required this.version, required this.notes, required this.page, this.apk, this.windowsZip});
  final String version;
  final String notes;
  final String page;
  final String? apk;
  final String? windowsZip;
}

/// „0.9.39+34“ oder „v0.9.39“ → [0, 9, 39]
List<int> parseVersion(String v) =>
    v.replaceFirst(RegExp('^v'), '').split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();

/// true, wenn a neuer ist als b.
bool isNewer(String a, String b) {
  final x = parseVersion(a);
  final y = parseVersion(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d > 0;
  }
  return false;
}

/// Liest die Antwort der GitHub-Schnittstelle.
Release? parseRelease(Map<String, Object?> json) {
  final tag = json['tag_name'];
  if (tag is! String || !tag.startsWith('v')) return null;
  String? asset(bool Function(String) want) {
    for (final a in (json['assets'] as List?) ?? const []) {
      if (a is Map && a['name'] is String && want(a['name'] as String)) return a['browser_download_url'] as String?;
    }
    return null;
  }

  return Release(
    version: tag.substring(1),
    notes: (json['body'] as String?) ?? '',
    page: (json['html_url'] as String?) ?? 'https://github.com/Batlh/casino-app/releases',
    apk: asset((n) => n.endsWith('.apk')),
    windowsZip: asset((n) => n.endsWith('-windows.zip')),
  );
}

bool get _updatesPossible =>
    !kIsWeb && (Platform.isAndroid || Platform.isWindows || Platform.isLinux) && !Platform.environment.containsKey('FLUTTER_TEST');

Future<Release?> fetchLatestRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(Uri.parse(_releasesApi));
    req.headers.set(HttpHeaders.userAgentHeader, 'Glueckspfennig/$appVersion');
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      debugLog.warn('update', 'GitHub antwortet mit ${res.statusCode}');
      return null;
    }
    final body = await res.transform(utf8.decoder).join();
    return parseRelease(jsonDecode(body) as Map<String, Object?>);
  } finally {
    client.close();
  }
}

/// Prüft beim Start, höchstens alle sechs Stunden, und nur wenn die Einstellung an ist.
Future<void> autoCheckForUpdate(BuildContext context) async {
  final settings = AppScope.of(context).settings;
  if (!_updatesPossible || !settings.autoUpdate) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - settings.lastUpdateCheck < const Duration(hours: 6).inMilliseconds) return;
  settings.lastUpdateCheck = now;
  try {
    final r = await fetchLatestRelease();
    if (r == null || !isNewer(r.version, appVersion) || !context.mounted) return;
    debugLog.info('update', 'Neue Version ${r.version} gefunden');
    await offerUpdate(context, r);
  } catch (e) {
    // Kein Netz oder GitHub nicht erreichbar: still weitermachen
    debugLog.warn('update', 'Prüfung fehlgeschlagen: $e');
  }
}

/// Von Hand aus den Einstellungen: meldet auch, wenn alles aktuell ist.
Future<void> manualCheckForUpdate(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!_updatesPossible) {
    messenger?.showSnackBar(const SnackBar(content: Text('Auf diesem Gerät gibt es keine automatische Aktualisierung.')));
    return;
  }
  final settings = AppScope.of(context).settings;
  try {
    final r = await fetchLatestRelease();
    settings.lastUpdateCheck = DateTime.now().millisecondsSinceEpoch;
    if (!context.mounted) return;
    if (r == null || !isNewer(r.version, appVersion)) {
      messenger?.showSnackBar(SnackBar(content: Text('Du hast die neueste Version (${appVersion.split('+').first}).')));
      return;
    }
    await offerUpdate(context, r);
  } catch (e) {
    debugLog.warn('update', 'Prüfung fehlgeschlagen: $e');
    messenger?.showSnackBar(const SnackBar(content: Text('GitHub ist gerade nicht erreichbar. Besteht eine Internetverbindung?')));
  }
}

/// Fragt nach und aktualisiert. Android lädt die APK und startet die Installation, am PC öffnet sich die Download-Seite.
Future<void> offerUpdate(BuildContext context, Release r) async {
  final p = Palette.of(context);
  final notes = r.notes
      .split('\n')
      .where((l) => l.trim().startsWith('- '))
      .take(8)
      .join('\n');
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Version ${r.version} ist da'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Du hast ${appVersion.split('+').first}. Jetzt aktualisieren?', style: TextStyle(color: p.ink)),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Neu:', style: TextStyle(color: p.ink, fontWeight: FontWeight.w700)),
              Text(notes, style: TextStyle(color: p.inkSoft, fontSize: 14)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Später')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Aktualisieren')),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;
  if (Platform.isAndroid && r.apk != null) {
    await _installAndroid(context, r);
  } else {
    // Am PC: Download-Seite im Browser, dort liegt die ZIP
    await launchUrl(Uri.parse(r.windowsZip != null && Platform.isWindows ? r.windowsZip! : r.page), mode: LaunchMode.externalApplication);
  }
}

Future<void> _installAndroid(BuildContext context, Release r) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Einmalig muss erlaubt werden, dass die App andere Apps (sich selbst) installieren darf
  if (await _channel.invokeMethod<bool>('canInstall') != true) {
    if (!context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erlaubnis nötig'),
        content: const Text(
          'Android fragt einmalig, ob Glückspfennig Updates installieren darf. Schalte im nächsten Fenster '
          '„Aus dieser Quelle zulassen“ ein, komm zurück und tippe noch einmal auf „Aktualisieren“.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Zu den Einstellungen')),
        ],
      ),
    );
    if (go == true) await _channel.invokeMethod<void>('allowInstall');
    return;
  }
  if (!context.mounted) return;
  final progress = ValueNotifier<double?>(null);
  var cancelled = false;
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Lade ${r.version} …'),
      content: ValueListenableBuilder<double?>(
        valueListenable: progress,
        builder: (context, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: v),
            const SizedBox(height: 8),
            Text(v == null ? '' : '${(v * 100).round()} %'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            Navigator.of(context).pop();
          },
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
  var open = true;
  unawaited(dialog.then((_) => open = false));
  try {
    final dir = await _channel.invokeMethod<String>('cacheDir');
    final file = File('$dir/gluckspfennig-${r.version}.apk');
    final client = HttpClient();
    try {
      final res = await (await client.getUrl(Uri.parse(r.apk!))).close();
      if (res.statusCode != 200) throw HttpException('Download ${res.statusCode}');
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        if (cancelled) break;
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress.value = got / total;
      }
      await sink.close();
    } finally {
      client.close();
    }
    if (cancelled) return;
    if (open && context.mounted) Navigator.of(context).pop();
    debugLog.info('update', 'APK ${r.version} geladen, starte Installation');
    await _channel.invokeMethod<void>('install', {'path': file.path});
  } catch (e, st) {
    debugLog.error('update', e, st);
    if (open && context.mounted) Navigator.of(context).pop();
    messenger?.showSnackBar(const SnackBar(content: Text('Das Update konnte nicht geladen werden.')));
  }
}
