#!/bin/bash
# Prueft alle Skripte: Bash-Syntax (mit /bin/bash 3.2 auf macOS), AppleScript- und JavaScript-Uebersetzung
# und – wenn UTM installiert ist – den Bau der Start-App samt Symbol (wowmac.sh selftest).
set -eu
cd "$(dirname "$0")/.."
for f in install.sh installer/wowmac.sh installer/lib/*.sh installer/build-installer-app.sh \
         installer/guest/wow-start installer/guest/wow-launch installer/guest/wow-provision; do
  /bin/bash -n "$f" && echo "Syntax ok: $f"
done
T=$(mktemp -d)
cat installer/apps/installer.applescript installer/apps/progress.applescript.inc > "$T/i.applescript"
cat installer/apps/uninstaller.applescript installer/apps/progress.applescript.inc > "$T/u.applescript"
sed -e 's/__VMNAME__/WoW-Linux/g' -e 's/__APPNAME__/WoW Test/g' -e 's/__SCALE__/1/g' installer/apps/starter.applescript > "$T/s.applescript"
HAVE_UTM=0; open -Ra UTM 2>/dev/null && HAVE_UTM=1
for f in "$T"/*.applescript; do
  xattr -w com.apple.TextEncoding "utf-8;134217984" "$f" 2>/dev/null || true
  if [ "$(basename "$f")" = s.applescript ] && [ "$HAVE_UTM" = 0 ]; then echo "UTM fehlt – Starter wird nicht uebersetzt"; continue; fi
  osacompile -o "$T/$(basename "$f" .applescript).scpt" "$f" && echo "AppleScript ok: $(basename "$f")"
done
osadecompile "$T/i.scpt" | grep -q "Wähle deinen WoW" && echo "Umlaute ok"
osacompile -l JavaScript -o "$T/icon.scpt" installer/lib/make-icon.js && echo "JavaScript ok: make-icon.js"
if [ "$HAVE_UTM" = 1 ]; then
  # Start-App mit Symbol wirklich bauen (in einem Wegwerf-Benutzerordner)
  mkdir -p "$T/home"
  HOME="$T/home" bash installer/wowmac.sh selftest "$T/selftest"
  ls -la "$T/selftest"
  if [ -n "${CI_ARTIFACTS:-}" ]; then mkdir -p "$CI_ARTIFACTS" && cp "$T/selftest/leistung.png" "$CI_ARTIFACTS/"; fi
fi
rm -rf "$T"
