#!/bin/bash
# WoW-Mac – Einstieg. Im Terminal einfuegen:
#   curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/install.sh | bash
# Laedt den Installer von GitHub nach ~/Library/Application Support/WoW-Mac, baut daraus die
# Installer-App (lokal gebaut, daher ohne Gatekeeper-Rueckfrage) und oeffnet sie.
# Aus einem geklonten Repo:  bash install.sh --local
set -euo pipefail
REPO="${WOWMAC_REPO:-EserYueksel/wow-mac}"
REF="${WOWMAC_REF:-main}"
SUP="$HOME/Library/Application Support/WoW-Mac"

say()  { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31mFehler: %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "Das ist kein Mac."
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = 1 ] || fail "Dieser Mac hat keinen Apple-Chip (M1 oder neuer)."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail "macOS $(sw_vers -productVersion) ist zu alt (noetig: 13 oder neuer)."

mkdir -p "$SUP"
if [ "${1:-}" = "--local" ]; then
  SRC=$(cd "$(dirname "$0")" && pwd -P)
  [ -f "$SRC/installer/wowmac.sh" ] || fail "installer/wowmac.sh nicht gefunden – bitte im Repo-Ordner ausfuehren."
  say "WoW-Mac: verwende die lokalen Dateien aus $SRC"
else
  say "WoW-Mac: lade den Installer von github.com/$REPO ($REF) …"
  T=$(mktemp -d /tmp/wowmac.XXXXXX)
  curl -fsSL --retry 3 "https://codeload.github.com/$REPO/tar.gz/$REF" -o "$T/src.tgz" || fail "Download von GitHub fehlgeschlagen."
  tar -xzf "$T/src.tgz" -C "$T" || fail "Archiv beschaedigt."
  SRC=$(find "$T" -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -f "$SRC/installer/wowmac.sh" ] || fail "Unerwarteter Inhalt im Archiv."
fi
rm -rf "$SUP/app.neu"; mkdir -p "$SUP/app.neu"
cp -R "$SRC/installer" "$SUP/app.neu/installer"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$SUP/app.neu/"
rm -rf "$SUP/app"; mv "$SUP/app.neu" "$SUP/app"
chmod +x "$SUP/app/installer/"*.sh "$SUP/app/installer/lib/"*.sh
APP=$(bash "$SUP/app/installer/build-installer-app.sh" "$HOME/Applications" | tail -1)
say "Installer-App bereit: $APP"
open "$APP"
say "Die Installer-App ist geoeffnet – dort geht es weiter."
