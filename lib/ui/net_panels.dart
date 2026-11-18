import 'package:flutter/material.dart';

import '../core/net/lan.dart';
import '../core/net/lan_table.dart';
import '../core/theme.dart';
import 'widgets.dart';

/// Gemeinsame Bildschirme für Spiele im lokalen Netz: Start, Warteraum des Gastgebers, Tischsuche, Warten als Gast.

Widget _panel(List<Widget> children) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );

TextStyle _style(BuildContext context) => TextStyle(color: Palette.of(context).onFelt, fontSize: 16);

Widget _title(BuildContext context, String t) =>
    Text(t, textAlign: TextAlign.center, style: _style(context).copyWith(fontSize: 20, fontWeight: FontWeight.w800));

Widget _note(BuildContext context, String t) =>
    t.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, textAlign: TextAlign.center, style: _style(context)));

/// Erste Seite: Name eingeben, Tisch eröffnen oder beitreten.
class NetStartPanel extends StatelessWidget {
  const NetStartPanel({
    super.key,
    required this.name,
    required this.onName,
    required this.onHost,
    required this.onBrowse,
    required this.onBack,
    this.message = '',
    this.hint = 'Alle Geräte im selben WLAN. Freie Plätze füllen Computer.',
  });

  final String name;
  final ValueChanged<String> onName;
  final VoidCallback onHost;
  final VoidCallback onBrowse;
  final VoidCallback onBack;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) => _panel([
        _title(context, 'Im lokalen Netzwerk'),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: name,
          maxLength: 16,
          decoration: const InputDecoration(labelText: 'Dein Name am Tisch', counterText: ''),
          onChanged: onName,
        ),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          ActionButton(primary: true, label: 'Tisch eröffnen', onPressed: onHost),
          ActionButton(label: 'Tisch beitreten', onPressed: onBrowse),
          ActionButton(label: 'Zurück', onPressed: onBack),
        ]),
        _note(context, message),
        const SizedBox(height: 8),
        Text(hint, textAlign: TextAlign.center, style: _style(context).copyWith(fontSize: 14)),
      ]);
}

/// Warteraum des Gastgebers.
class NetHostLobby extends StatelessWidget {
  const NetHostLobby({
    super.key,
    required this.host,
    required this.addresses,
    required this.bots,
    required this.maxBots,
    required this.onBots,
    required this.onStart,
    required this.onClose,
    this.startLabel = 'Spiel starten',
    this.minPlayers = 2,
  });

  final NetTableHost host;
  final List<String> addresses;
  final int bots;
  final int maxBots;
  final ValueChanged<int> onBots;
  final VoidCallback onStart;
  final VoidCallback onClose;
  final String startLabel;
  final int minPlayers;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    final guests = host.seats.length;
    final b = bots.clamp(0, maxBots);
    return _panel([
      _title(context, 'Dein Tisch ist offen'),
      const SizedBox(height: 4),
      Text(host.info, textAlign: TextAlign.center, style: style),
      Text('Von Hand beitreten: ${addresses.isEmpty ? '–' : addresses.map((a) => '$a:${host.lan.port}').join(' oder ')}',
          textAlign: TextAlign.center, style: style.copyWith(fontSize: 14)),
      const SizedBox(height: 12),
      Text('Am Tisch', style: style.copyWith(fontWeight: FontWeight.w700)),
      Text('• ${host.hostName} (du)', style: style),
      for (final s in host.seats.values) Text('• ${s.name}', style: style),
      const SizedBox(height: 12),
      Text('Computer-Gegner dazu', style: style.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        for (var n = 0; n <= maxBots; n++) ChoiceChip(label: Text('$n'), selected: b == n, onSelected: (_) => onBots(n)),
      ]),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        ActionButton(primary: true, label: startLabel, onPressed: 1 + guests + b >= minPlayers ? onStart : null),
        ActionButton(label: 'Tisch schließen', onPressed: onClose),
      ]),
    ]);
  }
}

/// Tischsuche für Mitspieler.
class NetBrowsePanel extends StatelessWidget {
  const NetBrowsePanel({
    super.key,
    required this.tables,
    required this.manual,
    required this.onJoin,
    required this.onBack,
    this.message = '',
  });

  final List<LanTable> tables;
  final TextEditingController manual;
  final void Function(String address, int port) onJoin;
  final VoidCallback onBack;
  final String message;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    return _panel([
      _title(context, 'Offene Tische'),
      const SizedBox(height: 6),
      if (tables.isEmpty)
        Text('Suche im WLAN …', textAlign: TextAlign.center, style: style)
      else
        for (final t in tables)
          Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text('${t.info}\n${t.address}'),
              isThreeLine: true,
              trailing: const Icon(Icons.login),
              onTap: () => onJoin(t.address, t.port),
            ),
          ),
      const SizedBox(height: 12),
      TextField(
        controller: manual,
        decoration: const InputDecoration(labelText: 'Von Hand: Adresse:Port, z. B. 192.168.1.20:41234'),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
        ActionButton(
          label: 'Verbinden',
          onPressed: () {
            final parts = manual.text.trim().split(':');
            final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
            if (port != null) onJoin(parts[0], port);
          },
        ),
        ActionButton(label: 'Zurück', onPressed: onBack),
      ]),
      _note(context, message),
    ]);
  }
}

/// Als Gast verbunden, aber noch keine Runde (oder Verbindung beendet).
class NetGuestWaiting extends StatelessWidget {
  const NetGuestWaiting({super.key, required this.guest, required this.onLeave, this.message = ''});
  final NetTableGuest guest;
  final VoidCallback onLeave;
  final String message;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    if (!guest.lan.connected) {
      return _panel([
        Text(message.isEmpty ? 'Verbindung beendet' : message, textAlign: TextAlign.center, style: style.copyWith(fontSize: 18)),
        const SizedBox(height: 12),
        Center(child: ActionButton(primary: true, label: 'Zurück', onPressed: onLeave)),
      ]);
    }
    return _panel([
      _title(context, guest.info.isEmpty ? 'Verbunden' : guest.info),
      const SizedBox(height: 12),
      Text('Am Tisch', style: style.copyWith(fontWeight: FontWeight.w700)),
      for (final p in guest.lobby) Text('• $p', style: style),
      const SizedBox(height: 12),
      Text('Warte, bis der Gastgeber startet …', textAlign: TextAlign.center, style: style),
      _note(context, message),
      const SizedBox(height: 12),
      Center(child: ActionButton(label: 'Tisch verlassen', onPressed: onLeave)),
    ]);
  }
}
