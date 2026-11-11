# Etappe 5 – Fehler, Einstellungen, neue Brettspiele, Grafik

Geplant am 10.11.2026 (nach Version 0.8.2). Umsetzung ab 11.11.2026, Reihenfolge wie unten.
Alle Antworten unten hat der Nutzer am 10.11.2026 gegeben.

## Stand 11.11.2026 (Version 0.8.3)

- Erledigt: Fehler aus 1 (Flipper-Klappe; Pachinko mit steilem Dach und breiten Lücken statt ohne Kollision, weil
  ohne Kollision die Auszahlung auf 148 % stieg; Tippen über `TapCatcher` in Solitär, Shisen-Sho und der Hand),
  Einstellungen aufgeteilt (2; Mau Mau und Eins im Spiel, Mensch ärgere dich nicht mit eigenem Regel-Panel),
  Debug-Log (8; Protokoll in den Einstellungen unter „Fehlersuche“, Kopieren in die Zwischenablage statt
  Datei-Export), Mitspieler-Auswahl für Brettspiele, neue Spiele Memory, Leiterspiel, Reversi,
  Mensch ärgere dich nicht, Mühle, Dame.
- Offen: Mahjong-Regeln (3), Backgammon, Halma, Go mit Tutorial, Kniffel (4), Weitergeben bei den Kartenspielen (5),
  Flipper ausbauen (6), Grafik (7).

## Stand 11.11.2026 abends

- Neu (noch nicht gebaut): Backgammon, Stern-Halma (2 bis 6), Go 9×9/13×13 mit Go-Schule (7 Aufgaben),
  Weitergeben des Geräts bei Mau Mau, Pik Dame und Arschloch (`HandCover` in `lib/games/board/seats.dart`).
- Backgammon und Halma haben die CI-Prüfung bestanden; Go und das Weitergeben sind noch ungeprüft, weil GitHub
  Actions keine Läufe mehr startet (vermutlich Kontingent des privaten Repos aufgebraucht).
- Offen: Weitergeben bei Eins (Glücksrad, Roulette und „am schnellsten“ brauchen eigene Lösungen),
  Mahjong-Regeln (3), Flipper ausbauen (6), Grafik (7).
- Hinweis: Die CI meldet `package:flutter/material.dart` als veraltet (neues Paket `material_ui`); nur Hinweise,
  Umstellung später.

## Stand 12.11.2026 nachts (Version 0.8.5)

- 0.8.4 ausgeliefert: Backgammon, Halma, Go mit Go-Schule, Weitergeben bei Mau Mau, Pik Dame und Arschloch,
  Spielstand als Datei, Mahjong-Steinkunde mit Hilfszahlen, Übungen für alle Mahjong-Varianten.
- Neu in 0.8.5: Weitergeben auch bei Eins! (beim Wettrennen hat jeder Mensch einen eigenen Knopf, Münzseite fragt
  jeden einzeln). Mahjong-Regeln (3) für MCR, Korea und Philippinen, Quellen siehe unten.
- Offen: Vietnam mit echten Jokerarten (siehe 3), Flipper ausbauen (6), Grafik (7).

## 1. Fehler zuerst

- **Flipper:** Der Ball rollt aus dem Spielfeld zurück in die Startrampe. Lösung: eine Klappe, die nur in eine
  Richtung durchlässt, am Ausgang der Startrampe.
- **Pachinko:** Der Block oben mit den Zahlen hat Kollision, deshalb bleiben Kugeln darauf liegen. Lösung: Der Block
  bekommt keine Kollision mehr oder ein schräges Dach. Dazu eine Sicherung: Eine Kugel, die sich ein paar Sekunden kaum
  bewegt, wird angestoßen oder entfernt.
- **Mahjong am Handy, Tippen geht manchmal nicht** (in Solitär, Shisen-Sho und Mahjong mit Hand):
  - Solitär: Getroffen wird nur die obere Fläche des Steins, die Kante nicht. Bewegt sich der Finger leicht, wird
    `onTapUp` verworfen. Geplant: auf das Aufsetzen des Fingers reagieren, mit etwas Spielraum, und die Kante zählt mit.
  - Shisen-Sho: Die Lücken zwischen den Steinen reagieren nicht. Geplant: `HitTestBehavior.opaque` und die Trefferfläche
    über die Lücken ziehen.
  - Hand (Sichuan, Riichi usw.): Der Abstand über dem Stein (Rand 10 px) gehört nicht zur Trefferfläche, und ein
    hochgerückter Stein wechselt beim Antippen seine Lage. Geplant: eine feste Trefferfläche über die ganze Höhe.
    Beim Abwerfen bleibt es bei zweimal tippen: einmal wählen, einmal werfen. So ist es gewollt, damit man sich nicht
    verklickt. Nur das erste Antippen muss sicher sitzen.
- Erledigt (kommt mit der nächsten Version): kürzere Hinweise bei Mahjong Solitär und Shisen-Sho, damit nichts
  abgeschnitten wird.

## 2. Einstellungen aufteilen

- **Global** (Zahnrad in der Lobby): Ton, Tempo der Computer, Bildkarten (J/Q oder B/D) und Kartengröße.
- **Pro Spiel** (Zahnrad im Spiel): alle Regeln, z. B. die Mau-Mau-Hausregeln, die Eins-Regeln und die Optionen von
  Pik Dame. Im Spiel zeigt das Zahnrad nur die Einstellungen dieses Spiels, dazu einen Link „Allgemeine Einstellungen“.
- Neue Spiele bringen ihre Einstellungen gleich auf diese Art mit.

## 3. Mahjong-Regeln ausarbeiten

Die vereinfachten Varianten auf die echten Regeln bringen. Vorher die Quellen recherchieren und hier eintragen.
- **MCR:** Knitted Straight einbauen, alle Ausschlussregeln nach dem offiziellen Regelwerk.
- **Korea:** die Punkte nach echter Quelle statt nur angelehnt.
- **Vietnam:** die Joker-Regeln vollständig.
- **Philippinen:** echte Werte statt Hausregel-Werten.
- Für jede Variante die Erklärung und das Tutorial anpassen.

Umgesetzt am 12.11.2026:
- **MCR:** Verbundene Straße (12) als eigene Hand mit einer Gruppe und einem Paar (die Gruppe darf aufgedeckt sein);
  Kleine Ehren mit kompletter Straße zählen beides. Ausschluss nach dem Nicht-Wiederholungs-Prinzip: Ein Muster, das
  selbst ausgeschlossen ist, schließt nichts aus. Ergänzte Ausschlüsse (Ganz verdeckt bei Sieben Paaren, Waisen und
  Verbundenen, Drei Kans, Vier verschobene Folgen, Drei große Winde, Nur Folgen schließt Ohne Ehren aus). Rand-, Mittel-
  und Einzelwartung zählen nur, wenn es die einzige Wartung war. Fehlt noch: „Letzter seiner Art“ (4).
- **Korea:** Handpunkte, Bonuspunkte, Grenze 40 und halbe Grenze 20, Minimum 3, Geber wechselt jede Hand, Bezahlung
  wie in der Quelle (Grenzhand bei Ron: beide zahlen, der Werfende doppelt). Quelle: englische Wikipedia
  „Three-player mahjong“, Abschnitt Korean. Weggelassen: 2 Bonuspunkte je Gegner, der nicht fertig ist, und das Ansagen.
- **Philippinen:** Winde und Drachen sind Blumen (nur Farben in der Hand), Werte in Vierteln einer Auszahlung,
  Sofortzahlungen für Kan, geheimen Kan, Sagasa, keine Blumen und 13 Blumen; Bunot alle doppelt, bei Ron der Werfende
  doppelt. Quellen: mahjongero.com „Mahjong, as we play it“ (2020) und filipinomj.com. Ohne den optionalen Joker.
- **Vietnam (noch offen):** Quelle riichi_advanced, documentation/vietnamese.md: 176 Steine mit 16 Blumen (auch Kaiser
  und Kaiserin), 12 grünen Jokern (Allgemein, Kreise, Bambus, Zeichen) und 12 roten (Blume, Wind, Drache, Farbe),
  je drei mit verschiedenem Rahmen. Joker können für Punkte beiseitegelegt werden. Wertung in Phán und Mủn (6 Phán =
  1 Mủn), keine Sieben Paare, Sonderhand „Keine Blumen, keine Blätter“. Braucht neue Steine, Joker mit Einschränkung
  in der Zerlegung und eine neue Wertung; kommt als eigener Schritt.

## 4. Neue Spiele

Alle neuen Brettspiele: gegen den Computer oder mehrere an einem Gerät, freie Plätze füllt der Computer.
Jedes Spiel mit Erklärung und Tutorial wie die anderen, mit eigenen Einstellungen (siehe 2) und mit Spielstand-Speichern.

- **Memory:** Motivsätze Mahjong-Steine, eigene Symbole (neu gezeichnet) und Katzen, wählbar.
- **Mühle**
- **Mensch ärgere dich nicht:** Jede Regel einzeln als Einstellung: drei Versuche ohne Figur draußen, nach einer 6
  nochmal würfeln, Rausmuss-Pflicht (bei einer 6 muss eine Figur raus, das Startfeld wird frei gemacht), Schlagzwang.
  Standard: alle an.
- **Leiterspiel:** klassisches Brett mit 100 Feldern und festen Leitern und Schlangen, oder jedes Mal zufällig verteilt.
  Beides zur Auswahl.
- **Dame:** deutsche Dame 8×8 und internationale Dame 10×10, beide zur Auswahl.
- **Reversi**
- **Backgammon** (mit Würfeln)
- **Halma / Stern-Halma** (bis zu 6 Spieler)
- **Go** auf 9×9 und 13×13, **mit Tutorial und Übungen zum Lernen** (Freiheiten, Schlagen, Ko, Leben und Tod, Zählen).
- **Kniffel**

## 5. Mehrspieler an einem Gerät

- Ablauf beim Start (bestätigt am 10.11.2026): Vor jedem Spiel kommt die Frage, wie viele Menschen an diesem Gerät
  mitspielen, mit Namen für jeden. Alle übrigen Plätze übernehmen Computer. Wer allein spielt, wählt „1 Spieler“ und
  spielt wie bisher gegen Computer. Die letzte Wahl wird pro Spiel gemerkt.
- Alle neuen Brettspiele (siehe 4).
- Kartenspiele, bei denen die Hand verdeckt ist: Mau Mau, Eins, Pik Dame, Arschloch. Das Gerät wird weitergegeben.
  Dazwischen kommt ein Bildschirm „Gib das Gerät an …“, und die Hand ist erst nach Antippen sichtbar.
- Nicht geplant: Mahjong mit Hand und die Casino-Spiele.

## 6. Flipper ausbauen (nach der Fehlerbehebung in 1)

- Mehr auf dem Tisch: Rampen, Zielscheiben, Missionen, Multiball.
- Mehrere Tische mit eigenem Thema.
- Schönere Grafik: Licht, Effekte, Animationen, Sound.

## 7. Grafik verbessern

Reihenfolge: Flipper und Pachinko, dann die Kartenspiele (Kartenbild, Tisch, Animationen beim Austeilen), dann die
Lobby (Startbildschirm, Kacheln der Spiele).

## 8. Debug-Log und Fehlerstapel (Wunsch vom 11.11.2026, für später)

Ziel: Wenn etwas hakt (Kugel bleibt hängen, Tippen geht nicht, Absturz), soll der Nutzer ein Log schicken können,
mit dem sich der Fehler nachstellen lässt.

- **Fehler abfangen:** `FlutterError.onError`, `PlatformDispatcher.instance.onError` und eine `runZonedGuarded`-Zone
  in `main`. Jeder Fehler landet mit vollständigem Stacktrace im Log. Die App stürzt dabei nicht ab, nur das Spiel
  zeigt einen Hinweis „Fehler aufgezeichnet“.
- **Log-Puffer:** Ringpuffer im Speicher (z. B. die letzten 2.000 Einträge), zusätzlich als Datei im App-Ordner
  (`logs/debug.log`). Die Datei wird ab ca. 1 MB rotiert, es bleiben höchstens zwei alte Dateien. Jeder Eintrag hat
  Zeit, Stufe (Info/Warnung/Fehler), Bereich (z. B. `pinball`, `mahjong.solitaire`, `saves`) und den Text.
- **Was protokolliert wird:**
  - App-Start mit Version, Build, Plattform und Bildschirmgröße
  - Spiel geöffnet oder geschlossen, Spielstand geladen oder gespeichert (bei Fehler mit Grund)
  - Die Spielaktionen, die es durch die Spielstände ohnehin gibt (Seed und Aktionsliste). Damit lässt sich eine
    Partie Zug für Zug nachspielen.
  - Tippen und Treffer in Mahjong Solitär, Shisen-Sho und in der Mahjong-Hand: Position, getroffener Stein oder
    „kein Treffer“ (für den Tipp-Fehler aus 1)
  - Flipper und Pachinko: Kugel steckt fest (Position, Dauer), Kugel verloren, Ball in der Startrampe
- **Ansicht in der App:** In den allgemeinen Einstellungen ein Bereich „Fehlersuche“, standardmäßig aus.
  Eingeschaltet zeigt er:
  - das Log, filterbar nach Stufe und Bereich
  - „Kopieren“ (Zwischenablage) und „Als Datei speichern/teilen“ (Android: Teilen-Menü, PC: Speichern-Dialog)
  - „Log leeren“
  - Schalter für Debug-Overlays: Kollisionsformen bei Flipper und Pachinko, Trefferflächen bei den Mahjong-Steinen,
    FPS-Anzeige
- **Datenschutz:** Das Log bleibt auf dem Gerät und verlässt es nur, wenn der Nutzer es selbst teilt. Es enthält
  keine Namen außer den selbst eingegebenen Spielernamen.
- **Aus im Release:** Ausführliche Einträge (Tippen, Physik) werden nur bei eingeschalteter Fehlersuche geschrieben.
  Fehler mit Stacktrace werden immer aufgezeichnet.
- **Test:** Unit-Test für Ringpuffer und Rotation. Ein Test, der einen Fehler wirft und prüft, dass er im Log landet.

## 9. Spielstand als Datei (Wunsch vom 11.11.2026)

- In den allgemeinen Einstellungen unter „Spielstand sichern“: „Als Datei sichern“ und „Aus Datei laden“
  (Paket `file_picker`: Android über das System-Dateifenster, PC über den Dateidialog), dazu als Ausweg
  „In Zwischenablage“ und „Aus Zwischenablage laden“.
- Die Datei (`gluckspfennig-spielstand-JJJJ-MM-TT.json`) enthält Münzen, Einstellungen und alle angefangenen Spiele,
  nicht das Fehlerprotokoll. Vor dem Laden zeigt die App Münzen und Zahl der Spiele und fragt nach; danach wird die
  App mit den geladenen Daten neu aufgebaut (`restartApp` in `lib/core/backup.dart`).

## Hinweis zum Kontingent

Das Wochen-Kontingent ist knapp. Deshalb mehrere Punkte zusammen bauen und nur selten einen vollen Build starten.
Für Zwischenstände reicht `check.yml` (Analyse und Tests). macOS bleibt aus.
