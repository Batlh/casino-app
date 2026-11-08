import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../games/cards/playing_card.dart';

void showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListenableBuilder(
          listenable: Listenable.merge([app.settings, app.sfx]),
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Einstellungen',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ton', style: TextStyle(color: p.ink, fontSize: 17)),
                  value: app.sfx.enabled,
                  onChanged: (_) => app.sfx.toggle(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bildkarten',
                  style: TextStyle(color: p.ink, fontSize: 17),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<CardNames>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: CardNames.international,
                        label: Text('J, Q, K, A'),
                      ),
                      ButtonSegment(
                        value: CardNames.deutsch,
                        label: Text('B, D, K, A'),
                      ),
                    ],
                    selected: {app.settings.cardNames},
                    onSelectionChanged: (s) => app.settings.cardNames = s.first,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kartengröße ${(app.settings.cardScale * 100).round()} %',
                  style: TextStyle(color: p.ink, fontSize: 17),
                ),
                Text(
                  'Gilt für Solitaire, Spider, Mau Mau und Schwarze Dame. Passt Spider nicht mehr auf den Bildschirm, lässt es sich seitlich schieben.',
                  style: TextStyle(color: p.inkSoft, fontSize: 14),
                ),
                Slider(
                  value: app.settings.cardScale,
                  min: Settings.minCardScale,
                  max: Settings.maxCardScale,
                  divisions: 8,
                  activeColor: p.accent,
                  label: '${(app.settings.cardScale * 100).round()} %',
                  onChanged: (v) => app.settings.cardScale = v,
                ),
                const SizedBox(height: 8),
                Text('Mau Mau', style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Nach Strafkarten ist der Zug vorbei',
                    style: TextStyle(color: p.ink, fontSize: 16),
                  ),
                  subtitle: Text(
                    app.settings.penaltyEndsTurn
                        ? 'Wer für eine Sieben zieht, darf nicht mehr legen'
                        : 'Wer für eine Sieben zieht, darf danach normal weiterspielen',
                    style: TextStyle(color: p.inkSoft, fontSize: 14),
                  ),
                  value: app.settings.penaltyEndsTurn,
                  onChanged: (v) => app.settings.penaltyEndsTurn = v,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Bube auf Bube erlaubt',
                    style: TextStyle(color: p.ink, fontSize: 16),
                  ),
                  value: app.settings.jackOnJack,
                  onChanged: (v) => app.settings.jackOnJack = v,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
