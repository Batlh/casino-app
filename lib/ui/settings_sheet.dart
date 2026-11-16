import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/licenses.dart';
import '../core/scope.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/version.dart';
import '../games/cards/playing_card.dart';
import 'backup_section.dart';
import 'debug_screen.dart';

/// Einstellungen öffnen. Aus einem Spiel heraus zeigt [game] zuerst die Einstellungen dieses Spiels,
/// die allgemeinen Einstellungen stehen eingeklappt darunter. Aus der Lobby nur die allgemeinen.
void showSettingsSheet(BuildContext context, {GameSettings? game}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SettingsSheet(game: game),
  );
}

/// Einstellungen eines einzelnen Spiels.
class GameSettings {
  const GameSettings(this.title, this.builder);
  final String title;
  final WidgetBuilder builder;
}

const mauMauSettings = GameSettings('Mau Mau', _mauMau);
const einsSettings = GameSettings('Eins!', _eins);

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({this.game});
  final GameSettings? game;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Palette.of(context);
    final game = this.game;
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
                if (game == null) ...[
                  Text('Einstellungen', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  _general(context),
                ] else ...[
                  Text('${game.title}: Einstellungen', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  game.builder(context),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      iconColor: p.ink,
                      collapsedIconColor: p.ink,
                      title: Text(
                        'Allgemeine Einstellungen',
                        style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Ton, Tempo, Bildkarten, Kartenbild, Kartenrücken, Kartengröße, Mahjong-Hilfszahlen, Spielstand',
                        style: TextStyle(color: p.inkSoft, fontSize: 14),
                      ),
                      children: [_general(context)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gilt für alle Spiele.
Widget _general(BuildContext context) {
  final app = AppScope.of(context);
  final p = Palette.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
          Text('Kartenbild', style: TextStyle(color: p.ink, fontSize: 17)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Klassisch')),
                ButtonSegment(value: false, label: Text('Einfach')),
              ],
              selected: {app.settings.illustratedCards},
              onSelectionChanged: (s) => app.settings.illustratedCards = s.first,
            ),
          ),
          const SizedBox(height: 16),
          Text('Kartenrücken', style: TextStyle(color: p.ink, fontSize: 17)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('70er')),
                ButtonSegment(value: 1, label: Text('Klassisch')),
                ButtonSegment(value: 2, label: Text('Neon')),
              ],
              selected: {app.settings.cardBack},
              onSelectionChanged: (s) => app.settings.cardBack = s.first,
            ),
          ),
          const SizedBox(height: 16),
          Text('Tempo der Computergegner', style: TextStyle(color: p.ink, fontSize: 17)),
          Text(
            'Wie lange die Gegner überlegen, bevor sie ziehen. Gilt für alle Karten- und Brettspiele.',
            style: TextStyle(color: p.inkSoft, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<BotSpeed>(
              showSelectedIcon: false,
              segments: [
                for (final v in BotSpeed.values) ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {app.settings.botSpeed},
              onSelectionChanged: (s) => app.settings.botSpeed = s.first,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kartengröße ${(app.settings.cardScale * 100).round()} %',
            style: TextStyle(color: p.ink, fontSize: 17),
          ),
          Text(
            'Gilt für alle Kartenspiele. Passt eine Patience nicht mehr auf den Bildschirm, lässt sie sich seitlich schieben.',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Hilfszahlen auf Mahjong-Steinen', style: TextStyle(color: p.ink, fontSize: 17)),
            subtitle: Text(
              'Zeigt auf jedem Stein klein die Zahl, die Windrichtung (O, S, W, N) oder die Drachenfarbe.',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            value: app.settings.mahjongHints,
            onChanged: (v) => app.settings.mahjongHints = v,
          ),
          const SizedBox(height: 8),
      const SizedBox(height: 8),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: p.ink,
          collapsedIconColor: p.ink,
          title: Text('Spielstand sichern', style: TextStyle(color: p.ink, fontSize: 17)),
          subtitle: Text(
            'Als Datei speichern oder auf einem anderen Gerät laden',
            style: TextStyle(color: p.inkSoft, fontSize: 14),
          ),
          children: const [BackupSection()],
        ),
      ),
      const SizedBox(height: 8),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: p.ink,
          collapsedIconColor: p.ink,
          title: Text('Fehlersuche', style: TextStyle(color: p.ink, fontSize: 17)),
          subtitle: Text(
            'Protokoll ansehen und kopieren, wenn etwas hakt',
            style: TextStyle(color: p.inkSoft, fontSize: 14),
          ),
          children: const [DebugSection()],
        ),
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Lizenzen', style: TextStyle(color: p.ink, fontSize: 17)),
        subtitle: Text(
          'Verwendete Schriften und Pakete',
          style: TextStyle(color: p.inkSoft, fontSize: 14),
        ),
        trailing: Icon(Icons.chevron_right, color: p.ink),
        onTap: () => showLicensePage(
          context: context,
          applicationName: 'Glückspfennig',
          applicationVersion: appVersion,
          applicationLegalese: appLegalese,
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Neueste Version herunterladen', style: TextStyle(color: p.ink, fontSize: 17)),
        subtitle: Text(
          'Updates für Android und PC auf GitHub (installiert: $appVersion)',
          style: TextStyle(color: p.inkSoft, fontSize: 14),
        ),
        trailing: Icon(Icons.system_update_alt, color: p.ink),
        onTap: () => openLink(context, releasesUrl),
        onLongPress: () => _copyLink(context, releasesUrl),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Quellcode auf GitHub', style: TextStyle(color: p.ink, fontSize: 17)),
        subtitle: Text(
          repoUrl.replaceFirst('https://', ''),
          style: TextStyle(color: p.inkSoft, fontSize: 14),
        ),
        trailing: Icon(Icons.open_in_new, color: p.ink),
        onTap: () => openLink(context, repoUrl),
        onLongPress: () => _copyLink(context, repoUrl),
      ),
    ],
  );
}

/// Öffnet einen Link im Browser. Klappt das nicht, wird er kopiert.
Future<void> openLink(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) _copyLink(context, url);
}

void _copyLink(BuildContext context, String url) {
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text('Link kopiert: $url')),
  );
}

/// Regeln mit eigenem Schalter: Mau Mau.
Widget _mauMau(BuildContext context) {
  final app = AppScope.of(context);
  final p = Palette.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
          const SizedBox(height: 8),
    ],
  );
}

/// Regeln mit eigenem Schalter: Eins!
Widget _eins(BuildContext context) {
  final app = AppScope.of(context);
  final p = Palette.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Plus-Karten stapeln', style: TextStyle(color: p.ink, fontSize: 16)),
            subtitle: Text(
              'Gleicher oder höherer Wert. Bei Gnadenlos immer an',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            value: app.settings.einsStackDraws,
            onChanged: (v) => app.settings.einsStackDraws = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Eins! rufen ist Pflicht', style: TextStyle(color: p.ink, fontSize: 16)),
            subtitle: Text(
              'Wer bei der vorletzten Karte nicht ruft, zieht zwei',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            value: app.settings.einsCallRequired,
            onChanged: (v) => app.settings.einsCallRequired = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Anzweifeln', style: TextStyle(color: p.ink, fontSize: 16)),
            subtitle: Text(
              'Farbwahl +4, +2 und Ziehen bis zur Farbe nur ohne passende Farbe. Der Nächste darf anzweifeln',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            value: app.settings.einsChallenge,
            onChanged: (v) => app.settings.einsChallenge = v,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Gnadenlos mit Erweiterung', style: TextStyle(color: p.ink, fontSize: 16)),
            subtitle: Text(
              '24 Zusatzkarten und Münzen. Gilt ab der nächsten Runde',
              style: TextStyle(color: p.inkSoft, fontSize: 14),
            ),
            value: app.settings.einsExpansion,
            onChanged: (v) => app.settings.einsExpansion = v,
          ),
    ],
  );
}
