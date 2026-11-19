#!/usr/bin/env bash
# Erzeugt die Plattform-Ordner, setzt den App-Namen und das Icon.
set -euo pipefail
NAME="Glückspfennig"
flutter create --project-name gluckspfennig --org io.github.batlh --platforms=android,windows,linux,macos .
flutter pub get
dart run flutter_launcher_icons || echo "Icons wurden nicht erzeugt, Build läuft weiter"
if [ -f android/app/src/main/AndroidManifest.xml ]; then
  sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$NAME\"/" android/app/src/main/AndroidManifest.xml
fi
# Update-Funktion: Internet, Installationserlaubnis, FileProvider, eigene MainActivity
if [ -f android/app/src/main/AndroidManifest.xml ]; then
  python3 ci/patch_android.py . || python ci/patch_android.py .
fi
# Feste Signatur, sonst bekommt jede APK einen neuen Schlüssel und Updates scheitern
GRADLE=android/app/build.gradle.kts
if [ -f "$GRADLE" ]; then
  python3 ci/set_signing.py "$GRADLE" || python ci/set_signing.py "$GRADLE"
fi
if [ -f windows/runner/main.cpp ]; then
  sed -i.bak "s/L\"gluckspfennig\"/L\"Glueckspfennig\"/" windows/runner/main.cpp
fi
if [ -f linux/runner/my_application.cc ]; then
  sed -i.bak "s/\"gluckspfennig\"/\"$NAME\"/g" linux/runner/my_application.cc
fi
if [ -d macos/Runner ]; then
  python3 ci/patch_macos.py . || python ci/patch_macos.py .
fi
if [ -f macos/Runner/Configs/AppInfo.xcconfig ]; then
  # Ohne Umlaut: Mit ü im Dateinamen schlägt die macOS-Signatur fehl
  sed -i.bak "s/^PRODUCT_NAME = .*/PRODUCT_NAME = Glueckspfennig/" macos/Runner/Configs/AppInfo.xcconfig
fi
find . -name '*.bak' -not -path './.dart_tool/*' -delete
# Lint der Plugins beim Release-Build abschalten: Die Lint-Prüfung stürzt bei
# url_launcher_android ab (Fehler in Lint selbst), der Build bricht sonst ab.
if [ -f android/build.gradle.kts ] && ! grep -q 'lintVital' android/build.gradle.kts; then
  cat >> android/build.gradle.kts <<'EOF'

subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
EOF
fi
