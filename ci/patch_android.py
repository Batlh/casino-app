"""Ergänzt die von flutter create erzeugten Android-Dateien um die Update-Funktion.

- Berechtigungen INTERNET (Update-Prüfung) und REQUEST_INSTALL_PACKAGES (Update installieren)
- FileProvider für die geladene APK
- eigene MainActivity mit dem Kanal gluckspfennig/update
- androidx.core für FileProvider
"""
import pathlib
import shutil
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
app = root / "android" / "app"
manifest = app / "src" / "main" / "AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")
perms = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>',
]
for p in perms:
    if p not in m:
        m = m.replace("<application", p + "\n    <application", 1)
provider = """
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.updates"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/update_paths" />
        </provider>
    </application>"""
if "androidx.core.content.FileProvider" not in m:
    m = m.replace("</application>", provider.lstrip("\n"), 1)
manifest.write_text(m, encoding="utf-8")

xml = app / "src" / "main" / "res" / "xml"
xml.mkdir(parents=True, exist_ok=True)
shutil.copy(root / "ci" / "android" / "update_paths.xml", xml / "update_paths.xml")

activities = list((app / "src" / "main").rglob("MainActivity.kt")) + list((app / "src" / "main").rglob("MainActivity.java"))
for a in activities:
    a.unlink()
target = app / "src" / "main" / "kotlin" / "de" / "privat" / "gluckspfennig" / "MainActivity.kt"
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copy(root / "ci" / "android" / "MainActivity.kt", target)

gradle = app / "build.gradle.kts"
g = gradle.read_text(encoding="utf-8")
if "androidx.core:core" not in g:
    g += '\n\ndependencies {\n    implementation("androidx.core:core:1.13.1")\n}\n'
gradle.write_text(g, encoding="utf-8")
print("Android: Update-Funktion eingetragen")
