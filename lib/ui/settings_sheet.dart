import 'package:flutter/material.dart';

import '../core/scope.dart';
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
