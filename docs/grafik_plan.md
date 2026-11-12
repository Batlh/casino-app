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

## Ablauf pro Tisch bzw. Maschine (Lehre aus Neonstadt V4–V7)

1. GPT erstellt **nur die Konzeptgrafik** im Neonstadt-Stil: gemaltes Spielfeld, Bauteile aus Acryl und Chrom,
   Licht als eigene Ebene.
2. Claude analysiert sie gründlich:
   - Bauteile zählen und nummerieren;
   - Lagen in Prozent festhalten;
   - Abgleich mit dem Vorbild (Flipper: Williams-Automaten der 90er; Pachinko: echte Automaten);
   - verdeckte Bereiche nach Bauweise des Vorbilds ergänzen.
3. Claude schreibt eine **Bauliste** mit Positionen, Schüssen und Regeln und baut danach Geometrie und Regeln im
   Code.
4. GPT liefert die **Grafiken Teil für Teil** nach der Liste, und Claude prüft jedes Teil einzeln:
   - Überlagerung Konzept/Modell mit 50 % Deckkraft;
   - Tabelle mit den Stufen gleich / abweichend / fehlt / ergänzt;
   - Ausschnitt-Paare Konzept neben Modell.
5. Die Tests laufen über GitHub. Erst danach wird übernommen.

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
