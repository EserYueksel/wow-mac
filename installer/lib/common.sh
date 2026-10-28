#!/bin/bash
# common.sh – gemeinsame Werte und Hilfsfunktionen des WoW-Mac-Installers (macOS, /bin/bash 3.2).

WOWMAC_VERSION="1.0.0"

# ---- feste, getestete Versionen (Prüfsummen von den offiziellen Release-Seiten) ----
UTM_MIN_VERSION="5.0.0"
UTM_VERSION="5.0.8"
UTM_URL="https://github.com/utmapp/UTM/releases/download/v${UTM_VERSION}/UTM.dmg"
UTM_SHA256="7b2d7b2e2a02b3de1757ef19a8f36573e6d9cceae8c8cca0abcbcaa4a852019a"
UTM_TEAM_ID="WDNLXAD4W8"                      # Entwicklerkennung von UTM (Turing Software, LLC)

UBU_IMG="ubuntu-26.04-server-cloudimg-arm64.img"
UBU_REL="https://cloud-images.ubuntu.com/releases/resolute/release-20261016"
UBU_SHA256="8eb876c2ccc4b6ff89e4a65d511815923b285e04503ba465809bf587f763da24"
UBU_FALLBACK="https://cloud-images.ubuntu.com/releases/resolute/release"   # nur falls die feste Version fehlt

HANGOVER_VERSION="11.16"
HANGOVER_SHA256="bdf7d91d67367a3dc6e856be3c6ab16e8d3b9049e7cd197844df20a7e4b45c52"

# ---- Orte ----
SUPPORT="$HOME/Library/Application Support/WoW-Mac"
CACHE="$HOME/Library/Caches/WoW-Mac"
LOGDIR="$HOME/Library/Logs/WoW-Mac"
STATE="$SUPPORT/state.env"
STATUS="$SUPPORT/status.txt"
APPS_DIR="$HOME/Applications"
# UTM ist eine Sandbox-App: ihre Einstellungen liegen im Container (defaults com.utmapp.UTM erreicht sie nicht)
UTM_PREFS="$HOME/Library/Containers/com.utmapp.UTM/Data/Library/Preferences/com.utmapp.UTM"
STARTER_ID="io.github.wowmac.starter"
UNINSTALLER_ID="io.github.wowmac.uninstaller"
UNINSTALLER_NAME="WoW-Mac deinstallieren"

GUI=0
TOTAL_STEPS=10

mkdir -p "$SUPPORT" "$CACHE" "$LOGDIR"

ts()  { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*"; }

# Fortschritt für die Installer-App: PHASE<TAB>PROZENT<TAB>TEXT<TAB>DETAIL
status() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}" > "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"; }
CUR_STEP=0; CUR_TEXT=""
die() {
  log "FEHLER: $*"
  status FAIL 0 "$*" "Protokoll: $LOGFILE"
  [ "$GUI" = 1 ] || osa_alert "WoW-Mac: Fehler" "$*" || true
  exit 1
}

# ---- Zustand: Zeilen KEY=wert (Wert bis Zeilenende, beliebige Zeichen ausser Zeilenumbruch).
#      Die Datei wird nie per "source" eingelesen.
state_get() { [ -f "$STATE" ] && grep "^$1=" "$STATE" | tail -1 | cut -d= -f2-; }
state_set() {
  local k=$1 v tmp="$STATE.tmp"
  v=$(printf '%s' "$2" | tr '\n' ' ')
  { [ -f "$STATE" ] && grep -v "^$k=" "$STATE"; printf '%s=%s\n' "$k" "$v"; } > "$tmp" && mv "$tmp" "$STATE"
}

# ---- Prüfsummen ohne Zusatzprogramme ----
sha256_of() {
  local h
  h=$(openssl dgst -sha256 -r "$1" 2>/dev/null | cut -d' ' -f1)
  [ ${#h} -eq 64 ] || h=$(shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1)
  echo "$h"
}

# ---- Versionsvergleich: ver_ge 5.0.8 5.0.0 ----
ver_ge() {
  local a b i x y
  IFS=. read -r -a a <<< "$1"; IFS=. read -r -a b <<< "$2"
  for i in 0 1 2; do
    x=${a[$i]:-0}; y=${b[$i]:-0}; x=${x%%[!0-9]*}; y=${y%%[!0-9]*}
    [ "${x:-0}" -gt "${y:-0}" ] && return 0
    [ "${x:-0}" -lt "${y:-0}" ] && return 1
  done
  return 0
}

# ---- Dialoge (nur im Terminal-Modus; die App fragt selbst) ----
osa_alert() { osascript - "$1" "$2" <<'OSA' >/dev/null 2>&1
on run argv
  display alert (item 1 of argv) message (item 2 of argv) as critical buttons {"OK"} default button 1
end run
OSA
}

# ---- UTM per AppleScript; Argumente immer über argv (keine Probleme mit Leer- oder Sonderzeichen) ----
# utm_osa SKRIPT [ARG...]  – SKRIPT ist der Rumpf von "on run argv"
utm_osa() {
  local body=$1; shift
  osascript - "$@" <<OSA
on run argv
  tell application id "com.utmapp.UTM"
$body
  end tell
end run
OSA
}
vm_exists() { [ "$(utm_osa 'if exists virtual machine named (item 1 of argv) then return "ja"
return "nein"' "$1" 2>/dev/null)" = "ja" ]; }
vm_status() { utm_osa 'return (status of virtual machine named (item 1 of argv)) as text' "$1" 2>/dev/null; }
vm_agent_ok() { utm_osa 'with timeout of 15 seconds
  query ip of virtual machine named (item 1 of argv)
end timeout
return "ok"' "$1" >/dev/null 2>&1; }
# guest_read VM PFAD – Inhalt einer Gastdatei (leer, wenn es sie nicht gibt)
guest_read() { utm_osa 'with timeout of 30 seconds
  set f to open file of virtual machine named (item 1 of argv) at (item 2 of argv) for reading
  return read f
end timeout' "$1" "$2" 2>/dev/null; }
# guest_fetch VM GASTPFAD MACPFAD – kopiert eine (kleine) Gastdatei auf den Mac (Base64, ohne Sandbox-Freigaben)
guest_fetch() {
  local b
  b=$(utm_osa 'set f to open file of virtual machine named (item 1 of argv) at (item 2 of argv) for reading
return read f base64 encoding true' "$1" "$2" 2>/dev/null) || return 1
  [ -n "$b" ] && printf '%s' "$b" | base64 --decode > "$3" 2>/dev/null && [ -s "$3" ]
}
# guest_exec VM PROGRAMM [ARG...]  – startet ein Programm im Gast (als root), wartet nicht
guest_exec() {
  local vm=$1 prog=$2; shift 2
  utm_osa 'set args to {}
repeat with i from 3 to count of argv
  set end of args to item i of argv
end repeat
execute of virtual machine named (item 1 of argv) at (item 2 of argv) with arguments args
return "ok"' "$vm" "$prog" "$@" >/dev/null 2>&1
}
