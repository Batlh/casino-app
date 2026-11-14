#!/usr/bin/env python3
"""Traegt den festen Signierschluessel in die von Flutter erzeugte Gradle-Datei ein.

Der echte Schluessel liegt verschluesselt in ci/release.keystore.enc und wird nur im
Build auf main mit dem Secret ANDROID_KEY_PASSWORD entschluesselt (GP_KEYSTORE,
GP_KEYSTORE_PW, GP_KEY_ALIAS). Ohne diese Variablen, etwa bei einem lokalen Build,
wird der oeffentliche Debug-Schluessel genommen. Solche APKs lassen sich nicht ueber
die echte App installieren.
"""
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
config = """    signingConfigs {
        create("fest") {
            storeFile = file(System.getenv("GP_KEYSTORE") ?: "../../ci/debug.keystore")
            storePassword = System.getenv("GP_KEYSTORE_PW") ?: "android"
            keyAlias = System.getenv("GP_KEY_ALIAS") ?: "androiddebugkey"
            keyPassword = System.getenv("GP_KEYSTORE_PW") ?: "android"
        }
    }

    buildTypes {"""
if 'create("fest")' not in text:
    assert "    buildTypes {" in text, "buildTypes nicht gefunden"
    assert 'signingConfigs.getByName("debug")' in text, "Signatur nicht gefunden"
    text = text.replace("    buildTypes {", config, 1)
    text = text.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("fest")')
    open(path, "w", encoding="utf-8").write(text)
