import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
              onPressed: () => _export(context),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Aus Datei laden'),
              onPressed: () => _import(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton(onPressed: () => _copy(context), child: const Text('In Zwischenablage')),
            TextButton(onPressed: () => _paste(context), child: const Text('Aus Zwischenablage laden')),
          ],
        ),
      ],
    );
  }

  static void _say(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final text = exportBackup(prefs);
    final bytes = Uint8List.fromList(utf8.encode(text));
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Spielstand sichern',
        fileName: backupFileName(),
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (path == null) return;
      // Am PC schreibt der Dialog die Datei nicht immer selbst
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      debugLog.info('spielstand', 'Gesichert: $path');
      if (context.mounted) _say(context, 'Spielstand gesichert');
    } catch (e, st) {
      debugLog.error('spielstand.export', e, st);
      if (context.mounted) {
        _say(context, 'Speichern als Datei ging nicht. Nimm „In Zwischenablage“ und speichere den Text selbst.');
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    String text;
    try {
      final r = await FilePicker.platform.pickFiles(dialogTitle: 'Spielstand laden', withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;
      final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
      if (bytes == null) throw const FormatException('Datei nicht lesbar');
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (e, st) {
      debugLog.error('spielstand.import', e, st);
      if (context.mounted) _say(context, 'Die Datei ließ sich nicht öffnen');
      return;
    }
    if (context.mounted) await _apply(context, text);
  }

  Future<void> _copy(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await Clipboard.setData(ClipboardData(text: exportBackup(prefs)));
    if (context.mounted) _say(context, 'Spielstand als Text kopiert');
  }

  Future<void> _paste(BuildContext context) async {
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
}
