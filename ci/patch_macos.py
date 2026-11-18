"""macOS: Netzwerk im Sandbox-Modus erlauben (Mehrspieler im WLAN und Update-Prüfung)."""
import pathlib
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
for name in ["DebugProfile.entitlements", "Release.entitlements"]:
    p = root / "macos" / "Runner" / name
    if not p.exists():
        continue
    t = p.read_text(encoding="utf-8")
    for key in ["com.apple.security.network.server", "com.apple.security.network.client"]:
        if key not in t:
            t = t.replace("</dict>", f"\t<key>{key}</key>\n\t<true/>\n</dict>", 1)
    p.write_text(t, encoding="utf-8")
print("macOS: Netzwerk-Berechtigungen eingetragen")
