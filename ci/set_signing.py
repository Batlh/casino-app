#!/usr/bin/env python3
"""Traegt den festen Signierschluessel in die von Flutter erzeugte Gradle-Datei ein."""
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
config = """    signingConfigs {
        create("fest") {
            storeFile = file("../../ci/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {"""
if 'create("fest")' not in text:
    assert "    buildTypes {" in text, "buildTypes nicht gefunden"
    assert 'signingConfigs.getByName("debug")' in text, "Signatur nicht gefunden"
    text = text.replace("    buildTypes {", config, 1)
    text = text.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("fest")')
    open(path, "w", encoding="utf-8").write(text)
