# Plan: mehrere Sprachen

Stand 14.11.2026, Wunsch des Nutzers: Die App soll in den meistgesprochenen Sprachen einstellbar sein.

## Sprachen

**Vom Nutzer genannt:**

| Sprache | Code |
|---|---|
| Deutsch (bisher) | de |
| Englisch | en |
| Französisch | fr |
| Spanisch | es |
| Portugiesisch | pt |
| Chinesisch (vereinfacht) | zh |
| Japanisch | ja |
| Koreanisch | ko |
| Thailändisch | th |
| Russisch | ru |

**Weitere häufig gesprochene Sprachen, mit dem Nutzer zu klären:**

| Sprache | Code | Anmerkung |
|---|---|---|
| Hindi | hi | |
| Indonesisch | id | |
| Türkisch | tr | |
| Italienisch | it | |
| Polnisch | pl | |
| Vietnamesisch | vi | |
| Arabisch | ar | wird von rechts nach links geschrieben, siehe unten |

## Umfang

- **Texte:** Alle Texte stehen bisher fest auf Deutsch im Code, grob 2 500 Textstellen in etwa 135 Dateien.
- **Betroffene Bereiche:** Menüs, Einstellungen, Spielregeln und Hilfe, Meldungen, Anzeigetexte der Flipper und
  Pachinko-Maschinen.
- **Spielnamen bleiben:** Skat, Mau Mau und Schwarze Dame behalten ihren Namen. Erklärt wird in der jeweiligen
  Sprache.

## Umsetzung

1. **Gerüst:** Flutter-Bordmittel (`flutter_localizations`, `gen_l10n`), dazu eine ARB-Datei je Sprache in
   `lib/l10n/`.
2. **Texte herauslösen:** Bereich für Bereich in `app_de.arb` überführen. Dazu gehören auch Zahlen und Münzbeträge
   im Format der jeweiligen Sprache.
3. **Einstellung:** „Sprache: wie System / Deutsch / English / …“. Die Auswahl wird gespeichert und gilt sofort.
4. **Übersetzungen:** zuerst Englisch, dann die übrigen Sprachen.
5. **Tests:**
   - In jeder Sprache fehlt kein Schlüssel.
   - Platzhalter stimmen überein.
   - Die Bildschirm-Bilder (Golden-Tests) in einer langen Sprache (Deutsch oder Russisch) und in einer
     Schriftzeichen-Sprache (Japanisch) laufen ohne Überlauf.

## Besonderheiten

- **Schriften:** Chinesisch, Japanisch, Koreanisch und Thailändisch brauchen passende Schriften.
  - Android bringt sie mit, Windows meist auch, Linux nicht immer.
  - Vollständige Schriften für Chinesisch, Japanisch und Koreanisch sind je 10–20 MB groß. Darum für Android und
    Windows die Systemschrift nutzen und nur bei Bedarf eine Teilmenge mitliefern, so wie heute schon bei Noto Serif
    JP.
- **Kartenbilder:** Deutsch zeigt B/D/K, die anderen Sprachen zeigen J/Q/K. Die Umschaltung in den Einstellungen
  bleibt. Französische Karten nutzen eigentlich V/D/R, als mögliche spätere Option.
- **Rechts nach links:** Bei Arabisch muss die ganze Oberfläche gespiegelt werden. Das kommt, wenn überhaupt, als
  letzte Sprache.
- **Übersetzungsqualität:** Die erste Fassung entsteht maschinell. Wo möglich, sollte jemand mit der Sprache als
  Muttersprache drüberschauen. Fehler können im Repository gemeldet werden.
- **Textlänge:** Russisch und Deutsch sind lang, Chinesisch und Japanisch kurz. Knöpfe und Kacheln müssen mitwachsen
  oder umbrechen.

## Reihenfolge

1. Das Gerüst und Englisch kommen zusammen. Erst dann lohnt sich alles Weitere.
2. Danach die genannten Sprachen.
3. Zum Schluss die weiteren Sprachen nach Rücksprache.

Die laufenden Grafikprojekte (Flipper, Spielkarten) gehen vor oder laufen parallel. Neue Texte in den Tischen
werden gleich in die ARB-Dateien geschrieben, sobald das Gerüst steht.
