# Neonstadt V5 – gezielter Flipper-Patch

## Übernahme

Dieses Paket enthält ausschließlich `lib/games/pinball/`, `assets/pinball/neonstadt/` und Flipper-Tests unter `test/`. Keine Dateien aus `lib/ui/` oder `lib/core/` und keine vollständige alte pubspec.yaml übernehmen. Die vorhandene Asset-Ordnerzeile in pubspec.yaml bleibt gültig.

**Den bisherigen Ordner `assets/pinball/neonstadt/` durch den neuen ersetzen, nicht zusammenführen.** Sonst würden die nicht mehr verwendeten großen PNGs weiterhin mitverpackt. Der neue Bildsatz besteht aus zwölf WebP-Dateien und dem Manifest.

## Aufbau

Der neue Tisch hat seine eigene Spielfeldhöhe von 14,04 statt 18 Einheiten; Breite 9,95, Hauptfeld bis x=9,25. Das Kopfteil von 1,85 Einheiten wird außerhalb der Physik proportional darüber gezeichnet. Alle anderen Tische behalten Höhe 18, ihre bisherigen Flippermaße, Abschussbahn und Tischdefinitionen. Der Untergrund ist das bisherige Neonstadt-Motiv, proportional eingepasst und als WebP komprimiert.

Neu aufgebaut: goldene Bumper, kurze obere Rampenbögen an den Außenseiten, getrennte kastenförmige Zielbänke, großer runder Projektor mit Porträt-Hologramm, mittiges Pfeilfeld, breite rote Schleudern, elfenbeinfarbene Flipper, echte Inlanes und Outlanes, Schürze mit mittlerem Abfluss, obere Gehäuseblende mit zwei Stadtbildschirmen und Punktanzeige, beleuchtete Abschussbahn mit langem Federweg. Die untere Geometrie ist ausdrücklich nicht mehr von den anderen Tischen übernommen.

## Prüfung

25 synchrone Physiktests bestehen im separaten Dart-/Forge2D-VM-Adapter: 1.440 Zufallsversuche über sechs Tische ohne Festhänger oder Austritt; 162 Rücklaufvarianten und 54 vollständige Rampenfahrten; Fronttreffer der Zielkästen, Rollovers, Einlass und Multiball; Outlane-Verlust und Ballrettung auf beiden Seiten; vier echte Flipperschüsse für alle Flipper-/Rampenkombinationen; gezielte Prüfung hinter den Zielgehäusen; Abschuss über die neue Federbahn.

Die Zufallssteuerung verwendet die tatsächliche Flipperhöhe des jeweiligen Tisches. Der Grenzwert der anderen Tische bleibt dadurch gleich. Die gezielten Schussprüfungen starten an der Schlagfläche mit stillstehender oder abwärts laufender Kugel; ein tatsächlicher Kontakt mit dem betätigten Flipper muss vor der ersten Rampeneinfahrt erkannt werden. Die Kugel wird nicht im Rampenmund platziert oder nach oben beschleunigt.

Diese Tests ersetzen keinen Flutter-Build. Flutter-Analyse, Android-/Windows-Build sowie Touch-, Bildraten- und GPU-Prüfung müssen im aktuellen Gesamtprojekt erfolgen. Die frühere SDK-Ausführung war durch die automatische Freigabeprüfung wegen eines Metadatenzugriffs blockiert worden und wurde nicht erneut versucht. Die Modellvorschau stammt aus einem separaten Renderer mit denselben Texturen und Rampendaten, nicht aus einem Gerätemitschnitt.

Die Physik bleibt Forge2D direkt mit CustomPainter. Rampen sind geführte 2,5D-Fahrten; seitliches Herausfallen und Kugel-Kugel-Kollisionen auf Rampen sind nicht simuliert.

Reguläre Prüfung im vollständigen aktuellen Projekt:

```sh
flutter analyze
flutter test test/pinball_test.dart test/pinball_stuck_test.dart test/neonstadt_ramps_test.dart test/neonstadt_routes_test.dart
```

Die neuen Bilddateien wurden mit dem integrierten Bildgenerator erstellt und anschließend nur beschnitten, proportional verkleinert und nach WebP komprimiert. Motive: goldene transparente Bumperkappe; horizontaler elfenbeinfarbener Flipper mit dunklem Rand; breite rote dreieckige Schleuder; runder goldbeleuchteter Projektor mit Cyan-Stadt und Porträt; Neonstadt-Kopfteil; zwei separate Dreifach-Zielkästen, rot und Cyan.
