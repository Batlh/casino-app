import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backup.dart';
import '../core/debug_log.dart';
import '../core/scope.dart';
import '../core/theme.dart';

/// „Spielstand sichern“ in den allgemeinen Einstellungen: alles als Datei speichern oder laden.
class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sichert Münzen, Einstellungen und alle angefangenen Spiele in einer Datei. Auf einem anderen Gerät '
          'oder nach einer Neuinstallation lädst du sie wieder und spielst weiter.',
          style: TextStyle(color: p.inkSoft, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.save_alt),
              label: const Text('Als Datei sichern'),
              onPressed: () => backupExport(context),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Aus Datei laden'),
              onPressed: () => backupImportFile(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: () => backupCopy(context), child: const Text('In Zwischenablage')),
            TextButton(onPressed: () => backupPaste(context), child: const Text('Aus Zwischenablage laden')),
          ],
        ),
      ],
    );
  }
}

void _say(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

/// Alles als Datei sichern.
Future<void> backupExport(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final text = exportBackup(prefs);
  final bytes = Uint8List.fromList(utf8.encode(text));
  try {
    // Der Dialog schreibt die Datei auf allen Plattformen selbst
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Spielstand sichern',
      fileName: backupFileName(),
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (uri == null) return;
    debugLog.info('spielstand', 'Gesichert: $uri');
    if (context.mounted) _say(context, 'Spielstand gesichert');
  } catch (e, st) {
    debugLog.error('spielstand.export', e, st);
    if (context.mounted) {
      _say(context, 'Speichern als Datei ging nicht. Nimm „In Zwischenablage“ und speichere den Text selbst.');
    }
  }
}

/// Sicherung aus einer Datei laden (fragt vorher nach).
Future<void> backupImportFile(BuildContext context) async {
  String text;
  try {
    final f = await FilePicker.pickFile(dialogTitle: 'Spielstand laden');
    if (f == null) return;
    text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
  } catch (e, st) {
    debugLog.error('spielstand.import', e, st);
    if (context.mounted) _say(context, 'Die Datei ließ sich nicht öffnen');
    return;
  }
  if (context.mounted) await _apply(context, text);
}

/// Sicherung als Text in die Zwischenablage.
Future<void> backupCopy(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await Clipboard.setData(ClipboardData(text: exportBackup(prefs)));
  if (context.mounted) _say(context, 'Spielstand als Text kopiert');
}

/// Sicherung aus der Zwischenablage laden (fragt vorher nach).
Future<void> backupPaste(BuildContext context) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  if (!context.mounted) return;
  if (text.trim().isEmpty) {
    _say(context, 'Die Zwischenablage ist leer');
    return;
  }
  await _apply(context, text);
}

/// Zeigt, was in der Sicherung steckt, fragt nach und ersetzt dann alles.
Future<void> _apply(BuildContext context, String text) async {
  final ({int coins, int saves, String app}) info;
  try {
    info = inspectBackup(text);
  } on FormatException catch (e) {
    _say(context, e.message);
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Spielstand laden?'),
      content: Text(
        'Die Sicherung (Version ${info.app}) enthält ${formatCoins(info.coins)} Münzen und '
        '${info.saves} angefangene${info.saves == 1 ? 's Spiel' : ' Spiele'}.\n\n'
        'Alles, was gerade auf diesem Gerät gespeichert ist, wird dabei ersetzt.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Laden und ersetzen')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final n = await importBackup(prefs, text);
    debugLog.info('spielstand', 'Geladen: $n Einträge aus Version ${info.app}');
  } catch (e, st) {
    debugLog.error('spielstand.import', e, st);
    if (context.mounted) _say(context, 'Laden fehlgeschlagen: $e');
    return;
  }
  // Alles neu aufbauen, damit Münzen und Spiele aus der Datei gelten
  restartApp?.call();
}
