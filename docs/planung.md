# Planung

Ideen und offene Vorhaben, Stand 18.11.2026. Reihenfolge ist noch offen. Erledigt: Glücksrad, Entchen angeln, Fruchtlawine, Mega-Slot (Pharaonengold), Flippertische Angelsee, Dschungeltempel, Zirkus.

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

## Mehrspieler im lokalen Netzwerk
- Grundgerüst steht (core/net/lan.dart), Bingo, Poker (Hold'em, Omaha, Five Card Draw), Mau-Mau, Eins, Skat, Schwarze Dame, Pik Dame,
  Arschloch und die Brettspiele Reversi, Mühle, Dame, Schach, Go, Shogi laufen schon.
  Für neue Spiele: core/net/lan_table.dart (Tisch, Warteraum) und ui/net_panels.dart (Bildschirme).
- Drei Wege: Sicht schicken (Poker, Mau-Mau), Startwert plus Aktionen nachspielen (Eins; ActionLog-Spiele über ui/net_replay_mixin.dart),
  Züge austauschen (Brettspiele, core/net/net_duel.dart und ui/net_duel_mixin.dart).
- Nächste Kandidaten: Viererkette (Zufallssteine), Halma (bis 6),
  Würfelspiele (Backgammon, Mensch ärgere dich nicht, Kniffel), Mahjong, Casino-Tische.
- Pro Spiel: Züge als Nachrichten, jeder sieht nur seine eigenen Karten, Computer füllen freie Plätze.

## Sonstiges
- Spielkarten-Grafik: Korrektur von GPT abwarten (Zweig spielkarten-grafik), dann prüfen und einbauen.
