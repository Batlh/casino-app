import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/debug_log.dart';
import '../core/theme.dart';
import '../core/version.dart';

/// Abschnitt „Fehlersuche“ in den allgemeinen Einstellungen.
class DebugSection extends StatelessWidget {
  const DebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final log = DebugLog.instance;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final errors = log.entries.where((e) => e.level == LogLevel.error).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ausführlich aufzeichnen', style: TextStyle(color: p.ink, fontSize: 16)),
              subtitle: Text(
                'Auch Tippen und Kugeln. Fehler werden immer aufgezeichnet.',
                style: TextStyle(color: p.inkSoft, fontSize: 14),
              ),
              value: log.verbose,
              onChanged: (v) => log.verbose = v,
            ),
            Text(
              '${log.entries.length} ${log.entries.length == 1 ? 'Eintrag' : 'Einträge'}, davon $errors Fehler · Version $appVersion',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DebugLogScreen())),
                  child: const Text('Protokoll ansehen'),
                ),
                FilledButton.tonal(
                  onPressed: () => copyLog(context),
                  child: const Text('Kopieren'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

Future<void> copyLog(BuildContext context, {LogLevel minLevel = LogLevel.info}) async {
  await Clipboard.setData(ClipboardData(text: DebugLog.instance.export(minLevel: minLevel)));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('Protokoll kopiert. Du kannst es jetzt in eine Nachricht einfügen.')),
  );
}

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  LogLevel _min = LogLevel.info;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final log = DebugLog.instance;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text('Protokoll'),
        actions: [
          IconButton(tooltip: 'Kopieren', icon: const Icon(Icons.copy), onPressed: () => copyLog(context, minLevel: _min)),
          IconButton(
            tooltip: 'Leeren',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Protokoll leeren?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leeren')),
                  ],
                ),
              );
              if (ok == true) log.clear();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SegmentedButton<LogLevel>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: LogLevel.info, label: Text('Alles')),
                  ButtonSegment(value: LogLevel.warn, label: Text('Warnungen')),
                  ButtonSegment(value: LogLevel.error, label: Text('Fehler')),
                ],
                selected: {_min},
                onSelectionChanged: (s) => setState(() => _min = s.first),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: log,
                builder: (context, _) {
                  final items = log.entries.where((e) => e.level.index >= _min.index).toList().reversed.toList();
                  if (items.isEmpty) {
                    return Center(child: Text('Keine Einträge', style: TextStyle(color: p.inkSoft)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: items.length,
                    separatorBuilder: (context, i) => Divider(height: 1, color: p.panelEdge),
                    itemBuilder: (context, i) {
                      final e = items[i];
                      final color = switch (e.level) {
                        LogLevel.info => p.ink,
                        LogLevel.warn => const Color(0xFFE0A030),
                        LogLevel.error => const Color(0xFFE05A4A),
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: SelectableText(
                          e.line,
                          style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
