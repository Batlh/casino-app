# Planung

Ideen und offene Vorhaben, Stand 19.11.2026. Reihenfolge ist noch offen. Erledigt: Glücksrad, Entchen angeln, Fruchtlawine, Mega-Slot (Pharaonengold), Flippertische Angelsee, Dschungeltempel, Zirkus.

## Ausbau (Zweig ausbau, Stand 19.11.2026)
Abarbeitung nach und nach, jeder Schritt mit Tests und eigenem Commit. Nach main nur mit OK.

1. Lobby: Favoriten (Stern auf jedem Automaten, eigener Bereich oben) und Suche
2. Statistik je Spiel (Runden, größter Gewinn, Einsatz/Auszahlung) als Grundlage für 3 und 4
3. Erfolge und Abzeichen
4. Tagesaufgaben mit Bonusmünzen
5. Höher oder Tiefer (Kartenleiter), auch als Risikoleiter für Slots nutzbar
6. Three Card Poker (gegen die Bank, später gemeinsamer Geber im Netz)
7. Roulette-Ausbau: französisch mit Kesselansagen (Nachbarn, Tiers, Orphelins), amerikanisch mit Doppelnull
8. Slot „Spielhalle“: Retro-Geldspielautomat mit Risikoleiter, Sonderspielen, Halten und Nachschieben
9. Slot mit Buch-Mechanik (sich ausdehnendes Sondersymbol in Freispielen), eigenes Thema
10. Slot mit Cluster-Gewinnen (7 × 7, ab 5 zusammenhängenden, Kaskaden)
11. Slot mit wandernden Jokern und Riesensymbolen
12. Slot mit endlosen Walzen
13. Pachislo (Walzen selbst stoppen, Geschick)
14. Münzschieber (Forge2D, Draufsicht mit Schräge, Sonderteile)
15. Greifautomat (Forge2D)
16. Pferderennen vom Jahrmarkt (Kugeln rollen, im Netz gemeinsam)
17. Turniere im Netz (feste Zeit oder feste Chips, Rangliste)
18. Schnellnachrichten am Netztisch (feste Knöpfe)
19. Hilfe: Liste aller Spiele mit Kurzbeschreibung, Bilder in den Kapiteln

Nur durch dich möglich: Test im echten WLAN mit mehreren Geräten.

## Neue Spiele

### Fruchtlawine (Slot)
- 3 × 3 Walzen, 27 Wege, Kaskaden: Gewinnfrüchte verschwinden, neue fallen nach.
- Probe-Simulation mit den Früchtekorb-Walzen: ~1,5 Gewinne pro Drehung, Ketten bis 13 Kaskaden,
  Quote 183 % (ohne Multiplikator) bzw. 379 % (×1, ×2, ×3, ×5). Darum:
  - 9 statt 6 Fruchtsorten, damit seltener wieder etwas passt
  - Beträge stark senken (etwa ein Viertel bis ein Achtel) und neu abstimmen
- Charakter: viele kleine Gewinne, ständig rattert es.

### Mega-Slot „mit allem“
- Alle Bausteine in einem Automaten: wechselnde Walzenhöhe (6 Walzen, 2–5 hoch), Kaskaden mit
  steigendem Multiplikator, Joker mit Multiplikator, liegenbleibende Joker in Freispielen,
  Glücksmünzen mit Hold & Spin und Jackpots, Bonus-Glücksrad (Freispiele, Hold & Spin, Münzen).
- Schwierig: Abstimmung. Jede Funktion bekommt einen festen Anteil an der Quote (z. B. Wege 55 %,
  Freispiele 20 %, Hold & Spin 15 %, Rad 5 %), Freispiele dürfen sich nicht endlos selbst auslösen.
- Name und Thema noch offen.

### Glücksrad (eigenes Casinospiel)
- Großes Geldrad wie im Casino („Big Six“): Felder mit 1, 2, 5, 10, 20 und zwei Sonderfelder (40).
- Man setzt auf eine oder mehrere Zahlen, das Rad dreht, Auszahlung nach dem Feld.
- Gut fürs Netzwerk: mehrere Spieler setzen am selben Rad.

### Entchen angeln (Jahrmarkt)
- Entchen schwimmen im Becken, man angelt eins; unter dem Entchen steht der Gewinn
  (Niete, klein, mittel, groß). Gewinn wird beim Angeln ausgewürfelt wie bei den Losen.
- Preis pro Angelversuch, eigene Gewinntabelle, kleine Angel-Animation.

### Drei neue Flippertische
Vorhanden: Neon Nacht, Weltraumstation, Piratenbucht, Spukschloss, Rennstrecke, Neonstadt. Jeder neue Tisch bekommt
ein Bauteil, das es noch nicht gibt, damit er sich anders spielt und nicht nur anders aussieht. Eigene Entwürfe, keine
Nachbauten echter Automaten (keine Namen, Figuren oder Spielelemente bekannter Geräte).

1. **Angelsee**
   - Neu: **Rückschuss links** („Rettungsring“): Die linke Auslaufbahn schießt die Kugel zurück ins Spiel,
     muss über die Ziele „R-I-N-G“ wieder scharf gemacht werden.
   - Drehspinner „Angelschnur“ zählt Meter; Missionen der Reihe nach: Barsch → Hecht → Zander → Wels.
   - Multiball „Schwarm“ über drei gefangene Kugeln im Bootssteg (Saucer), Jackpot auf der Stegrampe.
2. **Dschungeltempel**
   - Neu: **Tempeltor** (Weiche): Drei Fallziele räumen öffnet das Tor, dahinter liegt das Kugelschloss.
     Ohne offenes Tor prallt die Kugel ab.
   - Neu: **dritter Flipper** oben links, von dort ist die Lianenrampe gut zu treffen.
   - Missionen: Idol finden, Brücke überqueren, Schatzkammer.
3. **Zirkus**
   - Neu: **gefangene Kugel** („Kanone“): eine feste zweite Kugel hinter einer Gasse; trifft man sie, stößt sie
     gegen ein Ziel. Fünf Treffer = „Mensch aus der Kanone“ (Bonus).
   - Neu: **Glücksrad im Saucer**: Kugel im Loch dreht ein kleines Rad mit Zufallspreis (Punkte, Ballrettung,
     Extrakugel, Mission erhöhen).
   - Trapezrampe und Jongleur-Bumper, Missionen: Seiltanz, Raubtiernummer, Große Manege.

Reihenfolge: Bauteile zuerst in der Physik (pinball_table.dart) mit Tests, dann die Tische.

## Hilfeseite in der Lobby
Erste Fassung steht (lib/ui/help_screen.dart): Fragezeichen und Knopf „Hilfe“ in der Lobby, Eintrag in den Einstellungen,
Suche. Noch offen: Bilder in den Kapiteln, Liste aller Spiele mit Kurzbeschreibung.
- Eigener Eintrag „Hilfe“ in der Lobby (gut sichtbar, z. B. Fragezeichen oben und ein Kärtchen unter den Spielen).
- Kurze Kapitel mit Bildern oder Symbolen, durchsuchbar:
  - Erste Schritte: Münzen ohne Geldwert, Tagesbonus, Nachfüllen (wann und wie viel)
  - Im Netzwerk spielen: alle Geräte im selben WLAN, Tisch eröffnen oder beitreten, Name, Adresse von Hand eingeben,
    was bei Verbindungsabbruch passiert, welche Spiele es gibt und wie sie im Netz laufen (Plätze, Computer, gemeinsamer Tisch)
  - Einstellungen: Ton, Tempo, Kartennamen, Darstellung, Aktualisieren
  - Spielstände: was gespeichert wird, Weiterspielen nach dem Schließen
  - Spielregeln: Verweis auf das Fragezeichen in jedem Spiel, Liste aller Spiele mit Kurzbeschreibung
  - Probleme: Tisch wird nicht gefunden (Firewall, Gast-WLAN), Update installieren, Protokoll für Fehlerberichte
- Inhalte als Daten (eine Datei), damit neue Spiele und Funktionen leicht ergänzt werden.

## Paketname umstellen auf io.github.batlh.gluckspfennig
Ziel: Android-Apps heißen intern io.github.batlh.<Repo>. Die GitHub-Adresse gehört uns, das passt auch zur kommenden
Entwicklerprüfung von Google (Paketname wird mit dem Signierschlüssel registriert). Bindestriche sind im Paketnamen nicht
erlaubt: aus md-leser wird z. B. io.github.batlh.mdleser oder md_leser, für dieses Repo (casino-app) bleibt der App-Name
gluckspfennig.

Was sich ändert:
- ci/prepare.sh: --org de.privat → io.github.batlh; ci/update/MainActivity.kt: package-Zeile. Signierschlüssel bleibt gleich.
- Android sieht eine neue App: Die alte wird nicht ersetzt, das Update aus der App installiert die neue daneben.
  Daten kommen nur über die Sicherung mit (Einstellungen → Spielstand sichern → als Datei oder Zwischenablage, in der neuen App laden).
- Am PC und Mac hängt der Speicherort auch am Namen (Windows: Firmenname im AppData-Pfad, Linux: ~/.local/share/<id>,
  macOS: Bundle-ID). Entweder dort beim ersten Start die alten Daten selbst übernehmen (geht, weil derselbe Benutzerordner),
  oder den Namen nur unter Android ändern. Vorschlag: Android umstellen, am PC automatisch übernehmen.

Ablauf:
1. Letzte Version mit altem Namen: Hinweis im Update-Dialog und in den Release-Notes, vorher die Sicherung zu machen.
   Optional Knopf „Jetzt sichern“ direkt im Update-Dialog.
2. Version mit neuem Namen: Release-Notes erklären Sichern, Laden in der neuen App, alte App danach löschen.
   Die neue App zeigt beim ersten Start „Sicherung laden?“, wenn noch keine Daten da sind.
3. Updater: Erkennt die alte App, dass die neue einen anderen Paketnamen hat, sagt sie das vor dem Installieren.

## Mehrspieler im lokalen Netzwerk
- Im Netz spielbar sind alle Mehrspielerspiele: Bingo, Poker (Hold'em, Omaha, Five Card Draw), Mau-Mau, Eins, Skat,
  Schwarze Dame, Pik Dame, Arschloch, Kniffel, Mensch ärgere dich nicht, Leiterspiel, Halma, Backgammon, Viererkette, Memory,
  Reversi, Mühle, Dame, Schach, Go, Shogi, Mahjong (klassische Varianten, Riichi, American) und die gemeinsamen Tische
  Roulette, Glücksrad, Craps, Sic Bo, Keno, Baccarat, Black Jack und Caribbean Stud.
  Einstieg überall auch über die Einstellungen („Im Netzwerk spielen“). Einzelautomaten (Slots, Flipper, Pachinko, Lose,
  Entchen, Video-Poker, Solitär, Shisen-Sho) bleiben ohne Netz.
- Für neue Spiele: core/net/lan_table.dart (Tisch, Warteraum) und ui/net_panels.dart (Bildschirme).
- Vier Wege: Sicht schicken (Poker, Mau-Mau), Startwert plus Aktionen nachspielen (Eins; ActionLog-Spiele über ui/net_replay_mixin.dart),
  Züge austauschen (Brettspiele, core/net/net_duel.dart und ui/net_duel_mixin.dart),
  gemeinsamer Tisch (Ergebnis oder Startwert vom Gastgeber, jeder rechnet selbst ab: ui/net_shared_mixin.dart).
- Mahjong: Ansagen sammelt der Gastgeber („cl“ an ihn, nicht im Protokoll); erst wenn alle gewählt haben, entscheidet er.
- Offen: Test im echten WLAN mit mehreren Geräten.
- Pro Spiel: Züge als Nachrichten, jeder sieht nur seine eigenen Karten, Computer füllen freie Plätze.

## Sonstiges
- Spielkarten-Grafik: Korrektur von GPT abwarten (Zweig spielkarten-grafik), dann prüfen und einbauen.

### Zwischenstand Ausbau (19.11.2026, 23:30)
- Erledigt: 1–12 (Favoriten/Suche, Statistik, Erfolge, Tagesaufgaben, Höher oder Tiefer, Three Card Poker, Roulette-Ausbau,
  Goldene Sieben, Zauberbibliothek (Buch), Bonbonfabrik (Gruppen), Goldgräber (wandernde Joker, Riesensymbol),
  Runenpfad (endlose Walzen)).
- Als Nächstes 13 Pachislo. Entwurf in tool/entwurf/pachislo.py und gen.py: nur die Mittellinie zählt, Rutschen
  höchstens 4 Felder, interne Auslosung (Pflaume, Replay, Kirsche überall auf Walze 1, Glocke nur mit Zielen, BIG 7-7-7,
  REG 7-7-BAR; Bonus-Fahne bleibt bis zum Treffer, Glückslampe). Walzen mit 21 Feldern: Pflaume und Replay höchstens
  alle 5 Felder, Kirsche höchstens alle 7; Pflaume und Replay dürfen auf Walze 1 nicht nur neben Kirschen erreichbar sein.
  gen.py sucht passende Bänder (Prüfung pro Druckpunkt eingebaut, Lauf noch nicht fertig).
- Spielkarten: Runde 5 bis auf die Mittelnaht abgenommen; Runde 6 macht Stolen, Ärmel und Bandenden am Querband
  bündig (Versatz bis 15 px). Danach beim nächsten Merge auf main mitnehmen, als ein einzelner Commit ohne URL.
- Erledigt bis 20.11. früh zusätzlich: 13 Pachislo, 14 Münzschieber, 15 Greifautomat, 16 Pferderennen (Netz),
  17 Turniere im Netz (gleiche Startchips, 10/20/30 Runden, Rangliste), 18 Schnellnachrichten, 19 Hilfe mit
  Spieleliste und Bildern. Damit sind alle 19 Schritte umgesetzt; offen ist nur der Test im echten WLAN.
