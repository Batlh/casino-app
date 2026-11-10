# Etappe 5 – Fehler, Einstellungen, neue Brettspiele, Grafik

Geplant am 10.11.2026 (nach Version 0.8.2). Umsetzung ab 11.11.2026, Reihenfolge wie unten.
Alle Antworten unten hat der Nutzer am 10.11.2026 gegeben.

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

## Hinweis zum Kontingent

Das Wochen-Kontingent ist knapp. Deshalb mehrere Punkte zusammen bauen und nur selten einen vollen Build starten.
Für Zwischenstände reicht `check.yml` (Analyse und Tests). macOS bleibt aus.
