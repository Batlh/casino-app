import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/wallet.dart';
import '../core/scope.dart';

/// Ein Kapitel der Hilfe: Überschrift, kurze Zusammenfassung und Abschnitte.
class HelpTopic {
  const HelpTopic(this.icon, this.title, this.summary, this.sections);
  final IconData icon;
  final String title;
  final String summary;
  final List<(String, String)> sections;

  /// Passt das Kapitel zu allen Suchwörtern?
  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return true;
    final text = [title, summary, for (final (h, t) in sections) '$h $t'].join(' ').toLowerCase();
    return words.every(text.contains);
  }
}

/// Inhalt der Hilfe. Neue Spiele und Funktionen hier ergänzen.
final List<HelpTopic> helpTopics = [
  HelpTopic(Icons.waving_hand, 'Erste Schritte', 'Münzen, Tagesbonus und wie du Spiele findest', [
    (
      'Münzen ohne Geldwert',
      'Glückspfennig ist ein Spielcasino nur zum Zeitvertreib. Du startest mit ${formatCoins(Wallet.startBalance)} Münzen. '
          'Münzen lassen sich weder kaufen noch auszahlen und haben keinen Geldwert.',
    ),
    (
      'Tagesbonus',
      'Einmal am Tag kannst du in der Lobby ${formatCoins(Wallet.dailyBonus)} Münzen abholen. Der Knopf steht unter der Leuchtschrift.',
    ),
    (
      'Nachfüllen',
      'Reicht dein Guthaben nicht mehr für den kleinsten Einsatz eines Spiels, bekommst du ${formatCoins(Wallet.refillAmount)} '
          'neue Münzen, sobald du das Spiel öffnest oder eine Runde beendest. Solange du noch setzen kannst, wird nicht nachgefüllt.',
    ),
    (
      'Spiele finden',
      'Die Lobby ist in Casino, Kartenspiele, Brettspiele und Mahjong geteilt. Die Knöpfe oben springen direkt zum Bereich. '
          'Was du zuletzt gespielt hast, steht ganz oben unter „Zuletzt gespielt“. Mit dem Stern auf einem Automaten '
          'kommt ein Spiel zu den Favoriten ganz oben, das Suchfeld findet Spiele nach Namen oder Beschreibung. Alle Spiele '
          'mit Bild und kurzer Beschreibung stehen in der Hilfe unter „Alle Spiele“.',
    ),
    (
      'Erfolge und Tagesaufgaben',
      'Der Pokal oben in der Lobby öffnet drei Seiten: „Heute“ mit drei neuen Aufgaben pro Tag, die Münzen bringen (alle drei '
          'zusammen noch ein Extra), „Erfolge“ zum Freischalten und „Statistik“ mit Einsätzen, Bilanz und größtem Gewinn je Spiel. '
          'Ein roter Punkt am Pokal zeigt, dass eine Aufgabe zum Abholen bereit ist.',
    ),
  ]),
  const HelpTopic(Icons.wifi, 'Im Netzwerk spielen', 'Mit Freunden an mehreren Geräten im selben WLAN', [
    (
      'Was du brauchst',
      'Alle Geräte müssen im selben WLAN sein und am besten dieselbe Version von Glückspfennig haben. '
          'Ein Internetzugang ist nicht nötig, gespielt wird direkt zwischen den Geräten.',
    ),
    (
      'So startest du',
      'Öffne das Spiel und tippe oben auf das Zahnrad, dann auf „Im Netzwerk spielen“. Auf breiten Bildschirmen gibt es dafür '
          'auch das WLAN-Symbol oben rechts. Gib deinen Namen ein. Einer tippt auf „Tisch eröffnen“ und ist damit der Gastgeber, '
          'die anderen tippen auf „Tisch beitreten“ und wählen den Tisch aus der Liste.',
    ),
    (
      'Der Gastgeber',
      'Der Gastgeber sieht, wer schon am Tisch sitzt, und startet das Spiel. Bei vielen Spielen kann er freie Plätze mit '
          'Computergegnern auffüllen. Er startet auch neue Runden und neue Spiele.',
    ),
    (
      'Karten- und Brettspiele',
      'Jeder spielt an seinem Gerät seinen eigenen Platz und sieht nur seine eigenen Karten oder Steine. Die Züge der anderen '
          'erscheinen sofort. Im Netz: Mau-Mau, Eins, Skat, Schwarze Dame, Pik Dame, Arschloch, Poker (Hold\'em, Omaha, '
          'Five Card Draw), Bingo, Kniffel, Mensch ärgere dich nicht, Leiterspiel, Halma, Backgammon, Viererkette, Memory, '
          'Reversi, Mühle, Dame, Schach, Go, Shogi und Mahjong (Riichi, American und alle Varianten).',
    ),
    (
      'Gemeinsame Casinotische',
      'Bei Roulette, Glücksrad, Craps, Sic Bo, Keno, Baccarat, Black Jack und Caribbean Stud setzt jeder mit seinen eigenen '
          'Münzen. Der Gastgeber dreht, würfelt oder teilt aus, alle sehen dasselbe Ergebnis. Bei Black Jack und Caribbean Stud '
          'hat die Bank für alle dieselben Karten, aber jeder spielt seine eigene Hand. Genauso bei Three Card Poker und beim '
          'Pferderennen: alle sehen dasselbe Rennen mit denselben Quoten. Unter dem Ergebnis steht, wer wie viel gesetzt hat.',
    ),
    (
      'Schnellnachrichten',
      'Am Netztisch erscheint oben eine Sprechblase. Darüber schickst du allen am Tisch einen festen Satz, etwa „Viel Glück!“ '
          'oder „Noch eine Runde?“. Die Nachricht steht kurz unten auf allen Geräten. Freie Texte gibt es bewusst nicht.',
    ),
    (
      'Münzen im Netz',
      'Münzen wandern nie zwischen den Geräten. Jeder gewinnt und verliert nur auf seinem eigenen Konto.',
    ),
    (
      'Verlassen und Abbrüche',
      'Mit „Tisch verlassen“ gehst du jederzeit. Geht ein Mitspieler, übernimmt bei den meisten Spielen ein Computer seinen Platz. '
          'Schließt der Gastgeber den Tisch, endet das Spiel für alle. Netzspiele werden nicht gespeichert.',
    ),
  ]),
  const HelpTopic(Icons.help_outline, 'Regeln und Hilfen im Spiel', 'Erklärungen, Tutorials und Einstellungen je Spiel', [
    (
      'Spielregeln',
      'In jedem Spiel steht oben ein Fragezeichen. Dahinter findest du die Regeln, die Auszahlungen und Tipps.',
    ),
    (
      'Geführte Tutorials',
      'Für Schach, Shogi, Riichi Mahjong und Mahjong Solitär gibt es in der Erklärung ein geführtes Tutorial zum Ausprobieren.',
    ),
    (
      'Einstellungen im Spiel',
      'Das Zahnrad im Spiel zeigt die allgemeinen Einstellungen und, wo es welche gibt, die Regeln dieses Spiels, '
          'zum Beispiel Plus-Karten stapeln bei Eins.',
    ),
    (
      'Mahjong-Steine',
      'Bei Mahjong erklärt der Knopf oben die Steine. In den Einstellungen kannst du kleine Hilfszahlen auf den Steinen einschalten.',
    ),
  ]),
  const HelpTopic(Icons.settings, 'Einstellungen', 'Ton, Tempo, Karten und Updates', [
    (
      'Wo',
      'Das Zahnrad oben links in der Lobby oder oben in jedem Spiel.',
    ),
    (
      'Was du einstellen kannst',
      'Ton, Bildschirm anlassen, automatische Suche nach Updates, Bildkarten als J, Q, K, A oder B, D, K, A, Kartenrücken '
          '(70er, Klassisch, Neon), Tempo der Computergegner sowie Anzeige und Automatik bei den Slots.',
    ),
  ]),
  const HelpTopic(Icons.save, 'Spielstände und Sicherung', 'Weiterspielen und Münzen auf ein neues Gerät mitnehmen', [
    (
      'Automatisch gespeichert',
      'Viele Spiele merken sich die laufende Partie, etwa Schach, Mahjong, Skat, Kniffel, Memory, Solitär und die Flipper. '
          'Öffnest du das Spiel wieder, geht es dort weiter.',
    ),
    (
      'Sichern und laden',
      'Unter Einstellungen, „Spielstand sichern“, kannst du Münzen und Spielstände als Datei oder in die Zwischenablage sichern '
          'und wieder laden. So nimmst du alles auf ein neues Gerät mit. Laden ersetzt den bisherigen Stand.',
    ),
    (
      'Umzug auf die neue App (ab 0.9.51)',
      'Seit Version 0.9.51 hat Glückspfennig einen neuen internen Namen. Am Handy ist es deshalb eine neue App neben der alten. '
          'So kommen Münzen und Spielstände mit: In der alten App unter Einstellungen „Spielstand sichern“ wählen, in der neuen '
          'App laden, danach die alte App löschen. Unter Windows und Linux übernimmt die neue Version alles von selbst, am Mac geht es wie am Handy über die Sicherung.',
    ),
  ]),
  const HelpTopic(Icons.system_update, 'Updates', 'Neue Versionen finden und installieren', [
    (
      'Automatisch',
      'Die App sucht beim Start nach einer neuen Version und zeigt, was neu ist. Am Handy lädt sie die neue Version und startet '
          'die Installation, am PC öffnet sich die Download-Seite.',
    ),
    (
      'Von Hand',
      'In den Einstellungen gibt es „Jetzt nach Updates suchen“ und „Neueste Version herunterladen“.',
    ),
  ]),
  const HelpTopic(Icons.build, 'Probleme lösen', 'Wenn ein Tisch nicht auftaucht oder etwas hakt', [
    (
      'Tisch wird nicht gefunden',
      'Prüfe, ob alle Geräte im selben WLAN sind. Gäste-WLANs und manche Hotspots verbieten, dass sich Geräte gegenseitig sehen. '
          'Am PC muss die Firewall Glückspfennig im privaten Netzwerk erlauben (Windows fragt beim ersten Mal).',
    ),
    (
      'Von Hand verbinden',
      'Beim Gastgeber steht unter „Von Hand beitreten“ eine Adresse wie 192.168.1.20:41234. Gib sie beim Beitreten in das Feld '
          '„Von Hand“ ein und tippe auf „Verbinden“.',
    ),
    (
      'Fehler melden',
      'Unter Einstellungen, „Fehlersuche“, steht das Protokoll der App. Einträge zum Netzwerk sind mit „netz“ markiert. '
          'Das Protokoll hilft beim Finden von Fehlern.',
    ),
  ]),
];

/// Ein Spiel für die Liste „Alle Spiele“ (kommt aus der Lobby).
class HelpGame {
  const HelpGame(this.area, this.name, this.blurb, this.color, this.art, [this.open]);
  final String area;
  final String name;
  final String blurb;
  final Color color;
  final CustomPainter Function() art;
  final VoidCallback? open;

  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final text = '$area $name $blurb'.toLowerCase();
    return words.every(text.contains);
  }
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, this.games = const []});

  /// Alle Spiele mit Bild; leer, wenn die Hilfe nicht aus der Lobby kommt.
  final List<HelpGame> games;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final topics = helpTopics.where((t) => t.matches(_query)).toList();
    final games = widget.games.where((g) => g.matches(_query)).toList();
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: p.bg, foregroundColor: p.ink, title: const Text('Hilfe')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                TextField(
                  controller: _search,
                  style: TextStyle(color: p.ink),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: p.inkSoft),
                    hintText: 'Suchen, z. B. Netzwerk, Münzen, Update',
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Suche löschen',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 12),
                if (games.isNotEmpty) _GamesCard(games: games, open: _query.isNotEmpty, key: ValueKey('spiele|${_query.isNotEmpty}')),
                if (topics.isEmpty && games.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Dazu gibt es keinen Eintrag.', textAlign: TextAlign.center, style: TextStyle(color: p.inkSoft)),
                  ),
                for (final t in topics) _TopicCard(topic: t, open: _query.isNotEmpty, key: ValueKey('${t.title}|${_query.isNotEmpty}')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kapitel „Alle Spiele“: nach Bereichen, jedes Spiel mit seinem Lobbybild. Antippen öffnet das Spiel.
class _GamesCard extends StatelessWidget {
  const _GamesCard({super.key, required this.games, required this.open});
  final List<HelpGame> games;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final areas = {for (final g in games) g.area};
    return Card(
      color: p.panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.panelEdge, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: open,
        iconColor: p.ink,
        collapsedIconColor: p.ink,
        leading: Icon(Icons.casino, color: p.accent, size: 28),
        title: Text('Alle Spiele', style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 18)),
        subtitle: Text('${games.length} Spiele mit Bild und kurzer Beschreibung', style: TextStyle(color: p.inkSoft)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in areas) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(a, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            for (final g in games.where((g) => g.area == a))
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: g.open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 72,
                      height: 54,
                      decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(8)),
                      clipBehavior: Clip.antiAlias,
                      child: CustomPaint(painter: g.art()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(g.name, style: TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(g.blurb, style: TextStyle(color: p.inkSoft, fontSize: 14)),
                      ]),
                    ),
                    if (g.open != null) Icon(Icons.chevron_right, color: p.inkSoft),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({super.key, required this.topic, required this.open});
  final HelpTopic topic;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Card(
      color: p.panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.panelEdge, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: open,
        iconColor: p.ink,
        collapsedIconColor: p.ink,
        leading: Icon(topic.icon, color: p.accent, size: 28),
        title: Text(topic.title, style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 18)),
        subtitle: Text(topic.summary, style: TextStyle(color: p.inkSoft)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (heading, text) in topic.sections) ...[
            const SizedBox(height: 8),
            Text(heading, style: TextStyle(color: p.ink, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: p.ink, fontSize: 15, height: 1.35)),
          ],
        ],
      ),
    );
  }
}
