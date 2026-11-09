# Etappe 4 – Kartenspiele und Casino

Stand 9.11.2026 (Version 0.8.0): eingebaut sind Pik Dame, Arschloch, Skat, Omaha, Caribbean Stud,
Baccarat, Sic Bo, Keno und Craps. Dazu alle Mahjong-Varianten (siehe unten).

Arschloch, Skat, weitere Pokervarianten, übrige Casinospiele – und:

## Pik Dame (Rommé-Ableger)

Quelle: https://www.gutefrage.net/frage/pik-dame---spielanleitung (Antworten von Devizz und HaWiNet)

Festgelegt mit dem Nutzer (8.11.2026):
- Blatt: 2×52 Karten + 6 Joker (110 Karten, zwei Pik Damen)
- Kartenwerte als Schalter, beide Varianten:
  - A: 2–9 = 5, 10–König = 10, Ass = 15, Joker = 20, Pik Dame = 100
  - B: wie A, aber Ass = 20, Joker = 15
- Erstes Auslegen mindestens 50 Punkte: Schalter, standardmäßig an

Regeln laut Quelle:
- Jeder bekommt 15 Karten, eine Karte offen neben den Stapel.
- Wer abhebt, darf eine aufgedeckte Pik Dame oder einen Joker behalten.
- Der erste Spieler darf die offene Karte ohne Auslegen nehmen, sonst vom Stapel ziehen; danach eine Karte abwerfen.
- Später gilt: Vom Ablagestapel nur nehmen, wenn man mit der obersten Karte sofort auslegt – und dann den ganzen Ablagestapel auf die Hand.
- Auslegen: Sätze (gleicher Rang) und Folgen ab 3 Karten. Eigene Auslagen dürfen ergänzt werden, ein ausgelegter Joker darf durch die passende Karte ersetzt und auf die Hand genommen werden.
- Ausmachen braucht eine Restkarte, die verdeckt abgelegt wird.
- Rundenende: Ausgelegtes zählt plus, Karten auf der Hand minus.
- „Hand“ (alles auf einmal ohne vorherige Auslage): eigene Punkte doppelt, Handkarten der anderen doppelt minus, deren Auslagen einfach plus.
- Ziel: als Erster 1.000 Punkte.
- Eingebaut mit den Standardantworten auf die offenen Fragen: Folgen nur in einer Farbe, Anlegen nur an eigene Auslagen,
  höchstens ein Joker je Auslage, Sätze nur aus verschiedenen Farben.
- Selbst entschieden: Ist der Stapel leer, endet die Runde und jeder rechnet ab (kein Neumischen, sonst kann eine Runde
  endlos laufen). Wenn die Familienregel anders ist, umstellen.

## Flipper / Pinball (Wunsch vom 8.11.2026)

- Mindestens ein Flipper-Tisch mit Physik (forge2d wie Pachinko).
- PC: Tastatur (linker/rechter Flipper, Abschuss mit Leertaste oder Pfeil runter).
- Handy: Tasten auf dem Bildschirm links/rechts und Abschuss.
- Spielmünzen für Punkte, kein Echtgeld; Erklärungsseite wie bei den anderen Spielen.

## Mahjong-Varianten (9.11.2026)

- Sichuan Blutkampf und Blutfluss (NTE „Mahjong Inferno“ = Blutfluss), Hongkong, Taiwan 16, MCR (vereinfachte
  Ausschlussregeln, ohne Knitted Straight), Singapur mit Tieren, Korea zu dritt (Punkte angelehnt), Zung Jung,
  westlich klassisch (ohne Abrechnung unter Verlierern), Philippinen (Hausregel-Werte), Vietnam (Joker vereinfacht).
- American Mahjong mit eigener „Glückskarte“ (24 Hände), weil die echte NMJL-Karte geschützt ist.
- Shisen-Sho (Lösbarkeit per Löser geprüft), Solitär-Formen Pyramide, Festung, Drache, Kreuz.
