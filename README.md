# Glückspfennig

Privates Offline-Casino für Android, Windows, Linux und macOS. Es gibt nur Spielmünzen ohne Geldwert, keinen Shop, keine Werbung. Ins Internet geht die App nur für die abschaltbare Update-Prüfung: eine Anfrage an GitHub, ob es eine neue Version gibt, ohne Daten von dir.

## Umstieg von Versionen vor 0.9.51

Mit Version 0.9.51 hat die App wegen Änderungen an der Architektur einen neuen internen Namen bekommen (`io.github.batlh.gluckspfennig`). Für das System ist sie damit eine neue App. Eine alte Version aktualisiert sich deshalb nicht von selbst auf die neue, man muss einmal umziehen:

1. Alte Version zuerst auf 0.9.50 bringen. Ältere Versionen aktualisieren nur bis dorthin.
2. In der alten App unter Einstellungen „Spielstand sichern“ wählen und die Datei speichern (`.json`).
3. Neue Version installieren. Am Handy erscheint sie als eigene App neben der alten.
4. Beim ersten Start fragt die neue App nach einer Sicherung: Datei laden. Danach die alte App löschen.

Unter Windows und Linux übernimmt die neue Version Münzen und Spielstände von selbst. Am Mac bitte ebenfalls sichern und laden. In der App erklärt die Hilfe den Umzug unter „Spielstände und Sicherung“.

## Bauen

Jeder Push auf `main` testet den Code und baut die APK. Sie liegt danach unter Releases bei „Aktueller Stand“. Die PC-Versionen entstehen über „Run workflow“ oder einen Tag wie `v0.1.0`.

Lokal: `bash ci/prepare.sh`, danach `flutter run`.

`ci/debug.keystore` signiert alle APKs gleich, damit Updates sich über die alte Version installieren lassen. `ci/set_signing.py` trägt den Schlüssel ein, der Build prüft die Signatur.

## Schriften

Shrikhand und Barlow Semi Condensed stehen unter der SIL Open Font License 1.1.
