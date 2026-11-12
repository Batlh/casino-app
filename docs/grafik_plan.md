# Plan: Flipper und Pachinko im neuen Grafikstil

Stand: 12.11.2026. Notiz für später, noch nicht begonnen.

## Reihenfolge

1. **Neonstadt fertigstellen.** Das ist der Mustertisch. GPT baut ihn, Claude prüft gegen die Konzeptgrafik. Ins
   Repository kommt er erst, wenn alles passt.
2. **Die übrigen fünf Flippertische** auf den Stand von Neonstadt bringen: Neon Nacht, Weltraumstation,
   Piratenbucht, Spukschloss und Rennstrecke.
3. **Die fünf Pachinko-Maschinen** auf denselben Grafikstand bringen.

## Aufgabenteilung

- **GPT macht die Grafik:** Konzeptgrafik, Spielfeldbilder, Bauteile, Lichtebenen und Animations-Bildfolgen, alles
  als WebP mit Angaben zu Lage und Ankerpunkt.
- **Claude schreibt den Code:** Tischdaten, Physik, Regeln, Modi, Anzeige, Einbau der Grafiken und Tests. Claude
  prüft außerdem die Grafiken gegen das Konzept.

## Ablauf pro Tisch bzw. Maschine (Lehre aus Neonstadt V4–V9)

1. **GPT erstellt die Konzeptgrafik und gleichzeitig alle Assets** des Tisches im selben Durchgang, damit Stil,
   Licht und Maße zusammenpassen. Was dazugehört, steht unter „Asset-Paket“ unten.
2. **Der Nutzer markiert** die Konzeptgrafik: rote Kreise an Bahnen, Ebenen und Funktionen. Er kennt die
   Williams-Automaten aus eigener Spielpraxis und sieht übereinanderliegende Rampen, Umlaufbahnen und erhöhte
   Ebenen, die auf einem gemalten Bild leicht zu einer verschwimmen.
3. Claude analysiert Konzept, Markierungen und Assets gründlich:
   - Bauteile zählen und nummerieren;
   - **jeden Kugelweg von Anfang bis Ende verfolgen** (pro Seite oft vier bis fünf: Umlaufbahn, mehrere Rampen,
     Draht, Innenrampe);
   - Ebenen erkennen (Boden, Plateaus, Rampen, Draht);
   - Lagen in Pixeln bzw. Prozent festhalten;
   - Abgleich mit Williams der 90er;
   - verdeckte Bereiche nach Williams-Bauweise ergänzen;
   - prüfen, ob für jedes Bauteil ein Asset da ist und zum Konzept passt.
4. Fehlt etwas oder passt ein Asset nicht, liefert GPT **nur die betroffenen Assets** nach. Kein kompletter
   Neudurchlauf.
5. Claude schreibt den Code (Geometrie, Ebenen, Regeln, Einbau der Assets) und prüft das Ergebnis gegen das
   Konzept:
   - Überlagerung mit 50 % Deckkraft;
   - Tabelle mit gleich / abweichend / fehlt / ergänzt;
   - Ausschnitt-Paare, auch für jeden roten Kreis des Nutzers.
6. Die Tests laufen über GitHub. Erst danach wird übernommen.

## Asset-Paket (GPT liefert es zusammen mit der Konzeptgrafik)

Alles als WebP mit transparentem Hintergrund, wo nötig. Gemeinsam für alle Teile gelten:
- dieselbe Schrägsicht und dieselbe Lichtrichtung wie im Konzept;
- keine Marken- oder Herstellernamen.

Zu jedem Teil gehört in `manifest.json`:
- Name und Ebene (Boden, Plateau, Rampe unten, Rampe oben, Draht, Licht);
- Ankerpunkt;
- Lage im Konzept in Pixeln;
- Größe in Welteinheiten (Tisch 9,95 × 18).

- **Spielfeld:** Grundbild ohne Aufbauten, dazu **Lichtebene** und **Schattenebene** einzeln.
- **Kopfteil.**
- **Rampen:** jede Acrylrampe als eigene Teile:
  - Fahrbahn;
  - Seitenwände;
  - Einfahrtszunge.
  - Bei Kreuzungen getrennt in den Teil unter und den Teil über der Kreuzung.
- **Drahtbündel** mit Klammern, Umlaufbahnen und Eckrampen, Abschussbahn mit Gehäuse und Bogen.
- **Erhöhte Ebenen** (zum Beispiel Bumper-Plateau) mit Kante und Abfahrten.
- **Bauteile mit Zuständen:**
  - Bumper ruhig / getroffen;
  - Schleudern ruhig / ausgeschlagen;
  - Flipper unten / oben;
  - Zielbänke mit Einzelzielen an / aus;
  - Kern bzw. Loch, Kickback-Stößel, Feder.
- **Pfosten und Halter:** mit leuchtender Hülse, in zwei bis drei Höhen.
- **Leuchteinsätze:** jeder Pfeil, jede Gassen-, Modus-, Lock-, Spezial- und Rückstoß-Lampe sowie „Nochmal
  schießen“, jeweils **an** und **aus**.
- **Unten:** Rücklauf- und Ausgassen mit Rahmen, Flipper-Mulden, Schürze mit Abfluss, Seitenwand-Lichtleisten.
- **Blickfang:** als Bildfolge, zum Beispiel ein Hologramm, das sich dreht.
- **Anzeige:** Bildfolgen pro Modus für die Punktmatrix-Anzeige.

Umfang: etwa 1–1,5 MB pro Tisch.

## Flipper: Mindestumfang wie 90er-Williams

Die Engine-Teile, die mit Neonstadt entstehen, werden für alle Tische wiederverwendet: Hintergrundbild,
Lichtebene, Rampen aus mehreren Ebenen, Modi, Kickback und Ballsicherung.

Jeder Tisch braucht:
- 6–8 Hauptschüsse;
- 8 Modi und einen Wizard-Modus;
- 2 Multiball-Arten mit Jackpot und Super-Jackpot;
- Kombos, eine erspielbare Extra-Kugel und einen Skill-Shot;
- einen bewegten Blickfang;
- Tischmaß 9,95 × 18.

## Pachinko: Ideen für die Überarbeitung

- **Anzeigefeld:** Bleibt ein fester Block mit Kollision, wie bei echten Automaten.
  - Ein Durchfliegen wurde schon versucht und zurückgenommen: Es sieht falsch aus, und die Starttasche würde zu
    oft getroffen, was die Quoten verschiebt.
  - Stattdessen einen **Einlauf oben im Rahmen und eine Bühne vor dem Display** einbauen. Kugeln rollen über die
    Bühne und fallen manchmal in die Starttasche. Das ersetzt das Spitzdach als Schutz gegen liegende Kugeln.
- Die Erstattung nach 20 s bleibt, weil Kugeln um die Windmühle kreisen können.
- Nach jeder Änderung muss der Auszahlungstest wieder grün sein (60–120 % je Maschine).
- Grafik und Teile als WebP, insgesamt etwa 1 MB pro Maschine. Das gilt auch pro Flippertisch.
