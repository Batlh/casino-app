# Glückspfennig

Privates Offline-Casino für Android, Windows, Linux und macOS. Es gibt nur Spielmünzen ohne Geldwert, keinen Shop, keine Werbung und keine Internet-Berechtigung.

## Bauen

Jeder Push auf `main` testet den Code und baut die APK. Sie liegt danach unter Releases bei „Aktueller Stand“. Die PC-Versionen entstehen über „Run workflow“ oder einen Tag wie `v0.1.0`.

Lokal: `bash ci/prepare.sh`, danach `flutter run`.

`ci/debug.keystore` signiert alle APKs gleich, damit Updates sich über die alte Version installieren lassen.

## Schriften

Shrikhand und Barlow Semi Condensed stehen unter der SIL Open Font License 1.1.
