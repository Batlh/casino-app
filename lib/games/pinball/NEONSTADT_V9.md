# Neonstadt V9

Tischmaß 9,95 × 18. Originalhintergrund, freigegebener Streifen, Logo, Projektor/Hologramm, Bumperlagen und Flipperform bleiben erhalten. Linke Seite vier Wege, rechte Seite fünf; keine zusätzliche linke Bahn.

| Weg | Baugruppen / Funktion |
|---|---|
| L1 | umlauf_links: Bodengasse und kurze Eckrampe als ein Weg, zu den oberen Gassen |
| L2 | links: große klare Acrylrampe A, anschließend Draht C |
| L3 | links_innen: pinke Acrylbahn B über der roten Bank auf das Plateau |
| L4 | linker geklammerter Draht C über A zurück in die Inlane |
| R1 | sichtbare klare Abschusshaube und großer Bogen; drei Skill-Ausläufe derselben Bahn |
| R2 | umlauf_rechts: Bodengasse, oben Übergabe an R1 |
| R3 | rechts: innere Acrylrampe A, anschließend Draht C |
| R4 | rechts_innen: cyanfarbene B-Bahn über der Totenkopf-Bank aufs Plateau |
| R5 | rechter Draht C über A in die rechte Inlane |

C ist die Rückführung von A und kein zusätzlicher gewerteter Hauptschuss. Die zwei kurzen Plateau-Abfahrten sind die ausdrücklich verlangten Rückwege von der erhöhten Ebene. Die Bumper stehen in einer eigenen Forge2D-Welt; B und obere Gassen geben hinauf ab, nur zwei seitliche Öffnungen geben hinunter ab. Koordinaten dieser Ebene sind bereits auf die Schrägsicht projiziert; der Höhenversatz wird an Übergaben einmal angewendet.

Sieben Hauptschüsse in Reihenfolge: umlauf_links, links, links_innen, kern, rechts_innen, rechts, umlauf_rechts. Acht Modi und beide Multiballs bleiben als Grundgerüst erhalten. Netzrundlauf benötigt alle sieben; Verfolgung und Stromausfall wandern alle vier Sekunden darüber. Überlastung: Bumper +1, B +5, Umlauf +3. Datenraub bleibt auf A. Wizard: sieben Hauptschüsse und beide Zielbänke Jackpot. Rampen-Kombos wie V8, Umlauf-Kombos in beiden Richtungen innerhalb von drei Sekunden. Neonrennen zählt A/B mit steigenden Rampenpunkten.

Untere vier Gassen erhöhen den Bonusfaktor bis fünf; die oberen drei erhöhen die Bumper-Stufe bis fünf. Beide Gruppen wechseln mit den Flippertasten. Kugelbonus entspricht exakt Trefferzahl × Multiplikator, ohne zusätzlichen Punktefaktor. Spezial leuchtet nach dem vierten abgeschlossenen Modus für 20 Sekunden und gibt rechts einmal 50 000 Punkte. Der linke Kickback lädt über beide Inlanes. Die einmalige Ballsicherung gilt sechs Sekunden, fördert verzögert und schießt automatisch erneut ab. Die Federbewegung bleibt sichtbar. Der blaue C-Schalter zählt A genau einmal vor dem Auslauf.

Einzelziele bleiben an; eine vollständige Bank blinkt kurz vor der Rückstellung. Pfeile erhalten ihre Zustände ausschließlich aus litShots/shotState; Multiball-Jackpots und offene Kombos bleiben gemeinsam mit Moduszielen sichtbar. Modusstart, Multiball, Jackpot und Wizard bewegen und beleuchten das Hologramm. Ereignisblitze sitzen in der getrennten Wandlichtebene. Der optionale Magnet ist nicht eingebaut.

Einbindung: lib/, assets/ und test/ aus dem Patch in das bestehende App-Projekt übernehmen. forge2d 0.14.2+1 war die Prüfversion. Die Asset-Registrierung assets/pinball/neonstadt/ muss in pubspec.yaml bestehen. Ersatzschnittstellen und das Prüfprojekt aus den Nachweisen gehören nicht in die Produkt-App. Die vollständige App wurde nicht mitgeliefert; getestet wurde das enthaltene Flipperpaket und sein echter Bildschirm in der dokumentierten isolierten Umgebung.

Die anderen fünf Tischdefinitionen und ursprünglichen Grundtests sind bytegleich. Neue Datenfelder behalten ihre alten Standardwerte; die fünf anderen Tische wurden zusätzlich je 12 000 Schritte auf identisches Verhalten geprüft.

Die Zeichnung bleibt ein nativer Flutter-Renderer mit transparenten Acrylflächen, Metallkanten und Höhenprofilen. Sie ist nicht fotorealistisch deckungsgleich zur Konzeptgrafik. Bauteiltabelle und Bildpaare in den Nachweisen bewerten Material, Tiefe, Kontur und Lage ausdrücklich; vorhandene Bauteile werden nicht allein deshalb als gleich eingestuft.
