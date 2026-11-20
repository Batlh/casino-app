import 'package:flutter/material.dart';

/// Schnellnachrichten am Netztisch: feste Sätze, verschickt wird nur die Nummer.
const quickMessages = [
  'Hallo!',
  'Viel Glück!',
  'Gut gespielt!',
  'Glückwunsch!',
  'Oh nein!',
  'Knapp!',
  'Moment bitte',
  'Noch eine Runde?',
  'Danke!',
  'Tschüss!',
];

/// Text zur Nummer, oder null bei Unsinn aus dem Netz.
String? quickMessageText(Object? index) {
  final i = index is num ? index.toInt() : null;
  return i != null && i >= 0 && i < quickMessages.length ? quickMessages[i] : null;
}

/// Knopf für die Titelleiste: öffnet die Liste der Sätze.
Widget quickChatButton(ValueChanged<int> onSend) => PopupMenuButton<int>(
      tooltip: 'Schnellnachricht',
      icon: const Icon(Icons.chat_bubble_outline),
      onSelected: onSend,
      itemBuilder: (context) => [
        for (var i = 0; i < quickMessages.length; i++) PopupMenuItem(value: i, child: Text(quickMessages[i])),
      ],
    );

/// Zeigt eine angekommene Nachricht kurz unten an.
void showQuickMessage(BuildContext context, String from, Object? index) {
  final text = quickMessageText(index);
  if (text == null || !context.mounted) return;
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text('$from: $text'),
    duration: const Duration(seconds: 3),
    behavior: SnackBarBehavior.floating,
  ));
}
