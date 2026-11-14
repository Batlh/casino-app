# Flipper: Aufbau der Tische

Stand 14.11.2026, mit dem Nutzer abgestimmt.

Aufgebaut wie bei den Williams-Automaten: Alle Geräte nutzen dieselbe Technik (bei Williams das WPC-System), jeder
Tisch hat sein eigenes Spielprogramm und sein eigenes Spielfeld.

## Gemeinsam (eine Engine für alle Tische)

- **Physik:** Kugel, Flipper, Bumper, Schleudern, Wände, Rampenfahrten.
- **Ablauf:** Tilt, Ball-Save, Eingabe, Punktezählung, Speichern.
- **Prüftests:** Kugel bleibt hängen, Erreichbarkeit, Zeichnen.

Ein Fehler in der Physik wird nur einmal behoben, und alle Tische fühlen sich gleich an.

## Eigen pro Tisch

1. **Tischdaten** (`TableSpec`):
   - Wände, Rampen, Löcher, Ziele, Gassen;
   - Flipperlänge und -kraft. Bei Tischen nach unterschiedlichen Herstellern unterscheidet sich hier nur der Wert.
2. **Regeln als eigene Datei:**
   - Modi, Wizard-Modus, Kombos, Jackpots, Bonus.
   - Sie bauen auf einem gemeinsamen Regel-Grundgerüst auf. Das Gerüst entsteht aus dem Regelteil von Neonstadt
     (`neonstadt_rules.dart`).
3. **Grafik:**
   - gemaltes Spielfeld mit passgenauen Ebenen oder ein eigener Zeichner;
   - dazu Anzeige-Animationen (DMD) und Sounds.

## Maße

- **Maßstab ist die Kugel:** Durchmesser 0,44 Einheiten, fest in der Engine. Alle Größen werden in Kugelbreiten
  angegeben, im Verhältnis eines echten Automaten. Ein Beispiel: Gassen etwa 1,4 Kugelbreiten.
- **Tischformat:** 9,95 × 18 Einheiten für alle Tische.
- **Neonstadt:**
  - Flipper in echtem Williams-Maß, etwa 2,8 Kugeldurchmesser (≈ 1,25 Einheiten);
  - Drehpunkte etwa bei 2,95 und 6,30, damit der Spalt zwischen den Spitzen etwa 1,0 bleibt.
- **Die anderen fünf Tische:** Die Flipperlänge ist noch offen. Sie richten sich teils nach anderen Herstellern.

## Reihenfolge

1. Neonstadt V10 und die fünf V3-Laufpläne (GPT) abwarten.
2. Danach das Regel-Grundgerüst aus Neonstadt herauslösen. Jeder gemalte Tisch bekommt seine eigene Regeldatei
   statt des einfachen Missionssystems.
