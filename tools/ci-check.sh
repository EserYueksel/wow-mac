#!/bin/bash
# Prueft alle Skripte: Bash-Syntax (mit /bin/bash 3.2 auf macOS) und AppleScript-Uebersetzung.
set -eu
cd "$(dirname "$0")/.."
for f in install.sh installer/wowmac.sh installer/lib/*.sh installer/build-installer-app.sh \
         installer/guest/wow-start installer/guest/wow-launch installer/guest/wow-provision; do
  /bin/bash -n "$f" && echo "Syntax ok: $f"
done
T=$(mktemp -d)
cat installer/apps/installer.applescript installer/apps/progress.applescript.inc > "$T/i.applescript"
cat installer/apps/uninstaller.applescript installer/apps/progress.applescript.inc > "$T/u.applescript"
sed -e 's/__VMNAME__/WoW-Linux/g' -e 's/__APPNAME__/WoW Test/g' installer/apps/starter.applescript > "$T/s.applescript"
for f in "$T"/*.applescript; do
  xattr -w com.apple.TextEncoding "utf-8;134217984" "$f" 2>/dev/null || true
  if [ "$(basename "$f")" = s.applescript ] && ! open -Ra UTM 2>/dev/null; then echo "UTM fehlt – Starter wird nicht uebersetzt"; continue; fi
  osacompile -o "$T/$(basename "$f" .applescript).scpt" "$f" && echo "AppleScript ok: $(basename "$f")"
done
osadecompile "$T/i.scpt" | grep -q "Wähle deinen WoW" && echo "Umlaute ok"
rm -rf "$T"
