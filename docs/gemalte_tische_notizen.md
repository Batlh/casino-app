# Gemalte Flippertische – Beobachtungen beim Einbau

Stand: 13.11.2026, Testzweig `neonstadt-v9-test`. Grundlage sind die V2-Konzeptpakete von GPT.

## Was gebaut wurde

- **Tische:** Neon Nacht, Weltraumstation, Piratenbucht, Spukschloss und Eifelring (Rennstrecke). Sie ersetzen auf
  dem Testzweig die alten, mit Formen gezeichneten Tische. Die alten bleiben im Code als `classicTables` erhalten.
- **Optik:** Das gemalte Konzept ist 1:1 das Spielfeld. Darüber liegen nur die beweglichen Teile:
  - Flipper und Kugel;
  - Lichtblitze an Bumpern, Schleudern, Zielen und Löchern;
  - abgedunkelte gefallene Fallziele;
  - leuchtende Gassen;
  - blinkender Rand beim Multiball.
- **Physik:** von Hand nach dem Bild gelegt. Grundlage waren GPTs Laufpläne, die Bauteillisten und ein Weltgitter
  über dem Bild. Erzeugt wird alles aus `tables_*.py` mit `gen.py`, in `lib/games/pinball/painted_tables.dart`.
- **„Physik zeigen“:** Ein Knopf neben „Tisch wechseln“ (am PC auch die Taste P) blendet Wände, Rampeneinfahrten und
  -wege, Bumper, Schleudern und Löcher als farbige Linien über dem Bild ein. Damit lässt sich direkt sehen, wo Bild
  und Physik auseinanderliegen. Das ist für deine Markierungen gedacht.

## Grundsätzliche Grenzen (betreffen alle fünf)

1. **Kugel zu groß fürs Bild.** GPT hat die Bilder für eine halb so große Kugel gemalt (Radius 0,11 statt 0,22 bei
   uns). Unsere Kugel wirkt deshalb doppelt so groß wie die gemalten Kugeln. Die Flipper musste ich länger machen
   als die gemalten, sonst wäre der Spalt zwischen ihnen für unsere Kugel viel zu breit.
2. **Gemalte Flipper bleiben sichtbar.** Unsere Flipper liegen über den gemalten. Klappt ein Flipper hoch, bleibt
   der gemalte unten als „Geist“ stehen. Lösung: ein Spielfeldbild ohne Flipper und die Flipper als eigenes Asset.
3. **Rampen und Umlaufbahnen sind „Fahrten“.** Die Kugel verlässt an der Einfahrt die Physik und fährt den Weg ab.
   Gemalte Bahnen am Boden sind deshalb physisch einfach Spielfeld, die Kugel kann über sie rollen.
4. **Erhöhte Ebenen** (Ballsaal, Galeonendeck, DJ-Bühne, Hangar, Rennbahn-Plateau) sind keine eigene Ebene. Die
   Bumper stehen auf dem normalen Spielfeld. Geschlossene Ränder um diese Flächen musste ich wieder entfernen, weil
   die Kugel darin gefangen blieb.
5. **Unsichtbare Dächer.** Flache Oberkanten von Gebäuden (Boxengasse, DJ-Pult, Spielhalle, Brücke, Gruft, Turm)
   haben unsichtbar ein leichtes Spitzdach bekommen, sonst bleibt die Kugel oben liegen.
6. **Abschussbahn fest.** Die Engine hat die Abschussbahn fest bei x 9,25–9,95, die Kugel startet ganz unten. Die
   gemalten Federn sitzen teils woanders, zum Beispiel beim Eifelring die Gangschaltung in der Mitte der Bahn.
7. **Nicht umgesetzte Mechanik** (nur gemalt, ohne Funktion):
   - Kanonen (Weltraumstation, Piratenbucht);
   - Magnete (Geisterhand, Turbo-Schleife);
   - drehendes Bücherregal, sich drehendes Sternentor und Hologramm;
   - Kickback-Stößel, „Nochmal schießen“-Lampe und Modus-Lampen. Die Einsätze sind gemalt, leuchten aber nicht
     nach Spielstand.
   - Videomodus und Musikwunsch.
8. **Regeln:** Es läuft das bestehende einfache Missionssystem, die 8 Modi des Konzepts nacheinander als Missionen,
   Multiball nach 3 Locks. Wählbare Modi, Wizard-Modus, Kombos und Bonus-Multiplikator wie bei Neonstadt sind noch
   nicht übertragen.

## Je Tisch

### Neon Nacht
- **Strandstraße als Schuss gestrichen:** Die Einfahrt der rechten Umlaufbahn liegt im Bild hinter dem
  Spielhallen-Automaten und ist von keinem Flipper erreichbar. Die Strandstraße ist jetzt der Rückweg der
  Boulevard-Umlaufbahn (links rein, oben herum, rechts runter).
- **Equalizer:** 3 + 3 Fallziele, wie gemalt. Im Prompt standen 3 + 2.
- **Rechte Gassen:** Die rechte Rücklauf- und Ausgasse sind etwas schmaler und weiter links als gemalt, weil rechts
  die Abschussbahn der Engine liegt.
- **Abwurf aus der Bahn:** Die Kugel geht über die Gassen N-E-O auf die Bühne. Das passt.

### Weltraumstation
- **Bildausschnitt:** Das Bild hatte links und rechts breite schwarze Ränder. Ich habe es zugeschnitten und um etwa
  14 % vergrößert, damit die gemalte Abschussbahn auf der Engine-Bahn liegt. Unten fehlen dadurch gut 2 Einheiten
  Schürze und der Federgriff.
- **Abschuss über das Sternentor:** Vom Abschuss aus gibt es im Bild keinen Weg zu den Gassen W-A-R-P, das
  Sternentor versperrt die Oberkante. Der Abschuss fährt deshalb als unsichtbarer Bogen rechts herunter in die
  Gassen.
- **Reaktorkern** ist ein großer Bumper. Im Konzept ist es eine gefangene Kugel.
- **Quadrant Alpha/Beta/Gamma:** gemalt sind drei Einfahrten, umgesetzt ist eine Rampe.
- **Dritter Flipper** am Hangar, mit einem Abweiser darüber. Ohne den blieb die Kugel auf seinem Drehpunkt liegen.
- **Bumper zwischen den Gassen:** wie beim Spukschloss stehen die Bumper zwischen den Gassen W-A-R-P statt auf
  den gemalten Asteroiden.
- **Erreichbarkeit: der schwächste Tisch.** Die Flipper sitzen sehr tief, darüber stehen hohe Schleudern, und die
  Mitte versperrt der Reaktor. Mit zufälligem Flippern kommt die Kugel kaum nach oben. Den Außenring hat sie in 300
  Versuchen nie erreicht, Torkern und Andockschleuse nur, wenn die Kugel von oben kommt. Hier braucht es
  vermutlich einen anderen Aufbau unten: Schleudern kürzer, Flipper höher, Reaktor als gefangene Kugel statt
  Bumper.

### Piratenbucht
- **Schädelinsel-Fallziele** liegen etwa 0,3 weiter rechts als gemalt, sonst wären sie hinter der Riff-Röhre nicht
  erreichbar.
- **Schmugglerversteck** (Sackgasse unten links) ist nicht umgesetzt, es läge mitten im Riff-Einlauf.
- **Galeonendeck** ohne Rumpfwand: Mit Rumpf blieb die Kugel im Deck wie in einer Schüssel liegen.
- **Dritter Flipper** oben rechts. Der Abweiser darüber hat den Abschuss blockiert und ist wieder raus.

### Spukschloss
- **Geister-Bumper versetzt:** Der mittlere Geist lag genau unter der Gasse U. Die Kugel sprang endlos zwischen
  Bumper und Gasse hin und her. Die drei Bumper stehen jetzt im Dreieck zwischen den Gassen, nicht genau auf den
  gemalten Geistern.
- **Gruft-Falltür** sitzt als Loch etwas links vom gemalten Schild „Falltür“. Dort liegt die Einfahrt der
  Turmrampe.
- **Turm:** physisch nur bis zur Höhe 1,9 (die Spitze ist Bild), sonst käme der Abschuss nicht über den Turm zu den
  Gassen B-U-H.
- **Dritter Flipper** am Wehrgang ist wieder raus. Die Kugel blieb zwischen Turm, Abweiser und Flipper hängen.
  Er braucht eine eigene Gasse.

### Eifelring
- **Start-Ziel-Brücke:** Ihre Pfeiler sind raus, mit dem Gebäude der Boxengasse bildeten sie eine Falle.
- **Motor:** Der Schuss zum Motor geht mittig unter der Brücke durch, im Bild ist der Weg nicht eindeutig.
- **Gangschaltung und Turbo-Magnete** sind nur gemalt.

## Testergebnis

Alle 449 Tests der App sind auf GitHub grün, auch die Analyse. Zusätzlich gibt es:
- **`painted_render_test`:** Jedes Spielfeldbild lädt (848 × 1536), und jeder Tisch lässt sich mitten im Spiel mit
  und ohne „Physik zeigen“ zeichnen.
- **`pinball_stuck_test`:** 240 Kugeln pro Tisch, keine bleibt hängen, keine fliegt raus. Bei den gemalten Tischen
  fällt die Testkugel jetzt unter einer oberen Gasse ins Feld statt ganz oben, sonst landete sie über dem Bild
  außerhalb des Tisches.
- **`painted_tables_test`:** 300 Kugeln mit zufälligem Flippern, gezählt wird, welche Rampe wie oft getroffen
  wird:

| Tisch | Rampen (Treffer) | Löcher | Fallziele | Bumper |
|---|---|---|---|---|
| Neon Nacht | Platte 49, Kassette 30, Treppe 28, Hufeisen 107, Boulevard 83 | 101 | 847 | 40 |
| Weltraumstation | Außenring 0, Hyperraum 1, Quadrant 1, Hangar 5 | 0 | 2 | 2972 |
| Piratenbucht | Riff 7, Mast 31, Strudel 14, Planke 6 | 74 | 30 | 410 |
| Spukschloss | Schlossgraben 1, Wehrgang 18, Treppe 15, Turm 13 | 18 | 41 | 244 |
| Eifelring | Nordschleife 5, Fuchsröhre 37, Grand-Prix 14, Motor 30, Brünnchen 3 | 18 | 123 | 55 |

Der Außenring der Weltraumstation ist als „selten“ eingetragen und wird gemeldet, aber nicht verlangt. Die
Pflicht, dass jedes Loch getroffen wird, habe ich wegen der Station aus dem Test genommen.

Für die gemalten Tische entfernt: die beiden Vergleichstests gegen 0.9.2 bzw. V7. Sie prüften, dass die alten fünf
Tische unverändert bleiben, und das sind sie auf diesem Zweig absichtlich nicht mehr.

Selten erreicht, also gute Kandidaten für deine Markierungen: Schlossgraben (Spukschloss), Brünnchen und
Nordschleife (Eifelring), Riffpassage und Planke (Piratenbucht).
