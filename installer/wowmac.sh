#!/bin/bash
# wowmac.sh – World of Warcraft 3.3.5a auf einem Mac mit Apple-Chip:
#   UTM (QEMU) + Ubuntu-26.04-VM + Hangover (Wine 11 + FEX) + OpenGL über virgl.
#
#   wowmac.sh preflight                 Voraussetzungen prüfen (Ausgabe KEY=WERT, für die App)
#   wowmac.sh check-wow ORDNER          WoW-Ordner prüfen
#   wowmac.sh install [Optionen]        einrichten – wiederholbar, setzt nach Abbruch fort
#   wowmac.sh repair                    Einrichtung in der VM erneut ausführen
#   wowmac.sh uninstall [Optionen]      alles sauber entfernen (Spielordner bleibt unberührt)
#   wowmac.sh status                    Zustand anzeigen
#
# Optionen für install:
#   --wow-dir ORDNER     WoW-3.3.5a-Ordner (mit Wow.exe und Data/)
#   --move-to ORDNER     WoW-Ordner vorher dorthin verschieben
#   --app-name NAME      Name der Start-App (Standard: "WoW 3.3.5a")
#   --vm-name NAME       Name der VM in UTM (Standard: "WoW-Linux")
#   --disk-gb N          Größe der VM-Platte (Standard 64, waechst nur bei Bedarf)
#   --no-dock            Start-App nicht ins Dock legen
#   --update-utm         zu alte UTM-Version durch die getestete ersetzen
#   --fresh              eine unterbrochene, noch nicht eingerichtete VM verwerfen und neu anlegen
#   --gui                von der Installer-App gestartet (keine Dialoge, nur Statusdatei)
# Optionen für uninstall:
#   --remove-utm         UTM ebenfalls entfernen (nur wenn der Installer es installiert hat und keine
#                        anderen VMs mehr darin sind)
#   --restore-config     WTF/Config.wtf auf den Stand vor der Installation zurücksetzen
#   --gui
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
. "$HERE/lib/common.sh"

LOGFILE=/dev/null
CAFF_PID=""

# ======================================================================= Hilfen
find_utm() {
  local p
  p=$(state_get UTM_APP); [ -n "$p" ] && [ -d "$p" ] && { echo "$p"; return; }
  for p in /Applications/UTM.app "$APPS_DIR/UTM.app"; do [ -d "$p" ] && { echo "$p"; return; }; done
  mdfind "kMDItemCFBundleIdentifier == 'com.utmapp.UTM'" 2>/dev/null | grep -v '^/Volumes/' | head -1
}
utm_version() { defaults read "$1/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null; }
utm_running() { pgrep -x UTM >/dev/null 2>&1; }
utm_started_vms() {   # Anzahl laufender VMs (nur wenn UTM läuft, sonst 0)
  utm_running || { echo 0; return; }
  utm_osa 'set n to 0
repeat with v in virtual machines
  if status of v is not stopped then set n to n + 1
end repeat
return n' 2>/dev/null || echo 0
}
utm_ensure() {   # UTM starten (falls noetig) und nach dem Start kurz warten – direkt nach dem Start ist UTM empfindlich
  utm_running && return 0
  open -g -a "$(find_utm)" 2>/dev/null || open -g -b com.utmapp.UTM 2>/dev/null
  local i; for i in $(seq 1 40); do utm_running && break; sleep 1; done
  sleep 6
  utm_running
}
utm_quit() {
  utm_running || return 0
  osascript -e 'tell application id "com.utmapp.UTM" to quit' >/dev/null 2>&1
  local i; for i in $(seq 1 30); do utm_running || return 0; sleep 1; done
  return 1
}

wow_exe() { local n; for n in Wow.exe WoW.exe wow.exe; do [ -f "$1/$n" ] && { echo "$1/$n"; return 0; }; done; return 1; }

check_wow() {   # gibt bei Fehlern einen Text aus und liefert 1
  local d=$1
  [ -d "$d" ] || { echo "Der Ordner wurde nicht gefunden."; return 1; }
  wow_exe "$d" >/dev/null || { echo "Im Ordner fehlt Wow.exe. Bitte den Hauptordner von WoW 3.3.5a wählen."; return 1; }
  [ -d "$d/Data" ] || { echo "Im Ordner fehlt der Unterordner Data. Bitte den Hauptordner von WoW 3.3.5a wählen."; return 1; }
  if [ -n "$(find "$d" -maxdepth 3 -flags +dataless 2>/dev/null | head -1)" ]; then
    echo "Der Ordner liegt in iCloud und ist nicht vollständig auf diesem Mac geladen. Bitte im Finder 'Jetzt laden' wählen oder den Ordner außerhalb von iCloud ablegen."
    return 1
  fi
  return 0
}

fs_type() { mount | awk -v m="$(df "$1" | awk 'NR==2{print $NF}')" '$3==m {gsub(/[(),]/," "); print $4; exit}'; }

download_verified() {   # URL DATEI SHA256 BESCHRIFTUNG UNGEFAEHRE_MB
  local url=$1 f=$2 sha=$3 label=$4 mb=${5:-0} i pid sz
  if [ -f "$f" ] && [ "$(sha256_of "$f")" = "$sha" ]; then log "   $label: schon vorhanden und geprüft"; return 0; fi
  for i in 1 2 3; do
    curl -fL --retry 3 --retry-delay 5 -sS -C - -o "$f.part" "$url" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
      sz=$(( $(stat -f %z "$f.part" 2>/dev/null || echo 0) / 1048576 ))
      if [ "$mb" -gt 0 ]; then detail "$label wird geladen: $sz von ca. $mb MB" $(( sz * 100 / mb > 100 ? 100 : sz * 100 / mb )); else detail "$label wird geladen: $sz MB"; fi
      sleep 2
    done
    wait "$pid"
    if [ -f "$f.part" ] && [ "$(sha256_of "$f.part")" = "$sha" ]; then mv -f "$f.part" "$f"; log "   $label: geladen und Prüfsumme stimmt"; return 0; fi
    log "   $label: Versuch $i fehlgeschlagen (Download oder Prüfsumme)"
    [ -f "$f.part" ] && [ "$(stat -f %z "$f.part")" -ge $(( mb * 1048576 * 9 / 10 )) ] && rm -f "$f.part"
    sleep 5
  done
  return 1
}

# Tastatur, Sprache und Zeitzone des Macs für die VM übernehmen.
# kbd_map NAME -> setzt XKB_L/XKB_V/WINE_KBD; Rückgabe 0 = eindeutiges Länderlayout, 1 = nur Annahme
kbd_map() {
  case "$(printf '%s' "$1" | tr -d ' ')" in
    German|German-DIN-2137)          XKB_L="de"; XKB_V="mac";    WINE_KBD=00000407 ;;
    SwissGerman)                     XKB_L="ch"; XKB_V="de_mac"; WINE_KBD=00000807 ;;
    SwissFrench)                     XKB_L="ch"; XKB_V="fr_mac"; WINE_KBD=0000100c ;;
    Austrian)                        XKB_L="at"; XKB_V="mac";    WINE_KBD=00000c07 ;;
    British|British-PC)              XKB_L="gb"; XKB_V="mac";    WINE_KBD=00000809 ;;
    French|French-PC|French-numerical) XKB_L="fr"; XKB_V="mac";  WINE_KBD=0000040c ;;
    Spanish|Spanish-ISO)             XKB_L="es"; XKB_V="mac";    WINE_KBD=0000040a ;;
    Italian|Italian-Pro)             XKB_L="it"; XKB_V="mac";    WINE_KBD=00000410 ;;
    Dutch)                           XKB_L="nl"; XKB_V="mac";    WINE_KBD=00000413 ;;
    Swedish|Swedish-Pro)             XKB_L="se"; XKB_V="mac";    WINE_KBD=0000041d ;;
    Danish)                          XKB_L="dk"; XKB_V="mac";    WINE_KBD=00000406 ;;
    Norwegian)                       XKB_L="no"; XKB_V="mac";    WINE_KBD=00000414 ;;
    Finnish)                         XKB_L="fi"; XKB_V="mac";    WINE_KBD=0000040b ;;
    Portuguese)                      XKB_L="pt"; XKB_V="mac";    WINE_KBD=00000816 ;;
    Polish|PolishPro)                XKB_L="pl"; XKB_V="";       WINE_KBD=00000415 ;;
    Turkish|Turkish-QWERTY|Turkish-QWERTY-PC) XKB_L="tr"; XKB_V=""; WINE_KBD=0000041f ;;
    US|U.S.|USInternational-PC)      XKB_L="us"; XKB_V="mac";    WINE_KBD=00000409 ;;
    ABC-QWERTZ)                      XKB_L="de"; XKB_V="mac";    WINE_KBD=00000407 ;;   # QWERTZ-Tastatur ohne Länderlayout
    ABC-AZERTY)                      XKB_L="fr"; XKB_V="mac";    WINE_KBD=0000040c ;;
    *)                               XKB_L="us"; XKB_V="mac";    WINE_KBD=00000409; return 1 ;;
  esac
  return 0
}
detect_locale() {
  local names n first=""
  names=$( { defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>/dev/null | sed 's/.*\.//'
             for k in AppleSelectedInputSources AppleEnabledInputSources; do
               defaults read com.apple.HIToolbox "$k" 2>/dev/null | sed -n 's/.*"KeyboardLayout Name" = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p'
             done; } | awk 'NF && !seen[$0]++')
  KBD_NAME=""
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    [ -n "$first" ] || first=$n
    if kbd_map "$n"; then KBD_NAME=$n; break; fi
  done <<EOF2
$names
EOF2
  if [ -z "$KBD_NAME" ]; then KBD_NAME=${first:-unbekannt}; kbd_map "$KBD_NAME"; fi
  local lang
  lang=$(defaults read -g AppleLanguages 2>/dev/null | sed -n 's/^ *"\{0,1\}\([a-zA-Z]*\).*/\1/p' | grep -v '^$' | head -1)
  [ -n "$lang" ] || { lang=$(defaults read -g AppleLocale 2>/dev/null); lang=${lang%%_*}; }
  case "$lang" in
    de) LOCALE=de_DE.UTF-8 ;; fr) LOCALE=fr_FR.UTF-8 ;; es) LOCALE=es_ES.UTF-8 ;; it) LOCALE=it_IT.UTF-8 ;;
    nl) LOCALE=nl_NL.UTF-8 ;; pl) LOCALE=pl_PL.UTF-8 ;; pt) LOCALE=pt_PT.UTF-8 ;; sv) LOCALE=sv_SE.UTF-8 ;;
    da) LOCALE=da_DK.UTF-8 ;; fi) LOCALE=fi_FI.UTF-8 ;; tr) LOCALE=tr_TR.UTF-8 ;;
    *)  LOCALE=en_US.UTF-8; lang=en ;;
  esac
  LANGPACK=""; [ "$lang" != en ] && LANGPACK="  - language-pack-$lang"
  TZ_NAME=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
  [ -n "$TZ_NAME" ] || TZ_NAME=UTC
}

valid_name() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,40}$'; }
urlpath() { printf '%s' "$1" | sed 's/%/%25/g; s/ /%20/g'; }

dock_add() {   # APP-PFAD
  local u; u="file://$(urlpath "$1")/"
  defaults read com.apple.dock persistent-apps 2>/dev/null | grep -qF "$u" && return 0
  defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$u</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
  killall Dock 2>/dev/null; return 0
}
dock_remove() {   # APP-PFAD
  local u t i n changed=0 v; u="file://$(urlpath "$1")/"
  t=$(mktemp /tmp/wowmac-dock.XXXXXX) || return 0
  defaults export com.apple.dock "$t" 2>/dev/null || { rm -f "$t"; return 0; }
  i=0
  while v=$(/usr/libexec/PlistBuddy -c "Print :persistent-apps:$i:tile-data:file-data:_CFURLString" "$t" 2>/dev/null) || \
        /usr/libexec/PlistBuddy -c "Print :persistent-apps:$i" "$t" >/dev/null 2>&1; do
    if [ "$v" = "$u" ]; then /usr/libexec/PlistBuddy -c "Delete :persistent-apps:$i" "$t"; changed=1; else i=$((i+1)); fi
    v=""
  done
  [ "$changed" = 1 ] && defaults import com.apple.dock "$t" && killall Dock 2>/dev/null
  rm -f "$t"; return 0
}

to_trash() {   # PFAD – verschiebt in den Papierkorb (wiederherstellbar) statt zu löschen
  local p=$1 b; [ -e "$p" ] || return 0
  b=$(basename "$p"); [ -e "$HOME/.Trash/$b" ] && b="${b%.*} $(date +%H%M%S).${b##*.}"
  mv "$p" "$HOME/.Trash/$b"
}

make_icns() {   # PNG ICNS
  local src=$1 out=$2 set s
  set=$(mktemp -d /tmp/wowmac-icon.XXXXXX)/wow.iconset; mkdir -p "$set"
  for s in 16 32 128 256 512; do
    sips -s format png -z $s $s "$src" --out "$set/icon_${s}x${s}.png" >/dev/null 2>&1
    sips -s format png -z $((s*2)) $((s*2)) "$src" --out "$set/icon_${s}x${s}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$set" -o "$out" 2>/dev/null
}

sed_esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }   # Sonderzeichen für den sed-Ersatz schuetzen
build_applet() {   # VORLAGE ZIEL BUNDLE-ID ICNS(optional)
  local src=$1 app=$2 bid=$3 icns=${4:-} tmp
  tmp="$SUPPORT/build-$(basename "$app" .app).applescript"
  sed -e "s|__VMNAME__|$(sed_esc "$VM_NAME")|g" -e "s|__APPNAME__|$(sed_esc "$APP_NAME")|g" \
      -e "s|__ENGINE__|$(sed_esc "$SUPPORT/app/installer/wowmac.sh")|g" \
      -e "s|__UNINSTALLER__|$(sed_esc "$UNINSTALLER_NAME")|g" "$src" > "$tmp" || return 1
  case "$(basename "$src")" in starter.*) ;; *) cat "$(dirname "$src")/progress.applescript.inc" >> "$tmp";; esac
  xattr -w com.apple.TextEncoding "utf-8;134217984" "$tmp" 2>/dev/null
  rm -rf "$app"
  osacompile -o "$app" "$tmp" || return 1
  rm -f "$tmp"
  [ -n "$icns" ] && [ -f "$icns" ] && cp "$icns" "$app/Contents/Resources/applet.icns"
  local P="$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bid" "$P" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $bid" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $(basename "$app" .app)" "$P" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleName string $(basename "$app" .app)" "$P"
  /usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'Steuert UTM, um die WoW-VM zu starten und ins Vollbild zu schalten.'" "$P" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :WoWMacVersion string $WOWMAC_VERSION" "$P" 2>/dev/null
  codesign --force --deep --sign - "$app" >/dev/null 2>&1
  touch "$app"
}

is_our_app() { [ "$(defaults read "$1/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" = "$2" ]; }

start_logging() {   # NAME
  LOGFILE="$LOGDIR/$1-$(date +%Y%m%d-%H%M%S).log"
  if [ "$GUI" = 1 ]; then exec >>"$LOGFILE" 2>&1; else exec > >(tee -a "$LOGFILE") 2>&1; fi
  log "WoW-Mac $WOWMAC_VERSION – $1 – macOS $(sw_vers -productVersion) – $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
}
take_lock() {
  if ! mkdir "$SUPPORT/lock" 2>/dev/null; then
    local p; p=$(cat "$SUPPORT/lock/pid" 2>/dev/null)
    if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then die "Der Installer läuft bereits."; fi
    rm -rf "$SUPPORT/lock"; mkdir "$SUPPORT/lock" || die "Sperre nicht möglich"
  fi
  echo $$ > "$SUPPORT/lock/pid"
  trap 'rm -rf "$SUPPORT/lock"; [ -n "$CAFF_PID" ] && kill "$CAFF_PID" 2>/dev/null' EXIT
  trap 'log "Abgebrochen."; status FAIL 0 "Abgebrochen." ""; exit 143' TERM INT HUP
  caffeinate -dimsu -w $$ & CAFF_PID=$!
}

# Fortschritt grob nach Dauer gewichtet (Schritt 8 dauert am laengsten)
step_base() { case $1 in 1) echo 0;; 2) echo 2;; 3) echo 4;; 4) echo 12;; 5) echo 14;; 6) echo 24;; 7) echo 26;; 8) echo 30;; 9) echo 90;; *) echo 95;; esac; }
step_span() { case $1 in 3) echo 8;; 5) echo 10;; 8) echo 60;; *) echo 2;; esac; }
step() { CUR_STEP=$1; CUR_TEXT=$2; log "== Schritt $1/$TOTAL_STEPS: $2"; status RUN "$(step_base "$1")" "$2" ""; }
LAST_KEY=""
detail() {   # TEXT [PROZENT_DES_SCHRITTS] – ins Protokoll nur, wenn sich mehr als die Zahlen aendert
  local p=${2:-0} key; key=$(printf '%s' "$1" | tr -d '0-9')
  [ "$key" = "$LAST_KEY" ] || { log "   $1"; LAST_KEY=$key; }
  status RUN $(( $(step_base "$CUR_STEP") + $(step_span "$CUR_STEP") * p / 100 )) "$CUR_TEXT" "$1"
}

# ======================================================================= preflight
do_preflight() {
  local arm macos major ram cpus free utm ver net vm vmours
  arm=0; [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] && arm=1
  macos=$(sw_vers -productVersion); major=${macos%%.*}
  ram=$(( $(sysctl -n hw.memsize) / 1073741824 ))
  cpus=$(sysctl -n hw.ncpu)
  free=$(df -k "$HOME" | awk 'NR==2{print int($4/1048576)}')
  utm=$(find_utm); ver=""; [ -n "$utm" ] && ver=$(utm_version "$utm")
  net=0; curl -sSfI -m 10 https://github.com >/dev/null 2>&1 && net=1
  vm=$(state_get VM_NAME); vmours=0; [ -n "$vm" ] && vmours=1
  echo "ARM=$arm"; echo "MACOS=$macos"; echo "MACOS_MAJOR=$major"; echo "RAM_GB=$ram"; echo "CPUS=$cpus"
  echo "FREE_GB=$free"; echo "UTM_APP=$utm"; echo "UTM_VERSION=$ver"
  if [ -z "$utm" ]; then echo "UTM_STATE=missing"; elif ver_ge "$ver" "$UTM_MIN_VERSION"; then echo "UTM_STATE=ok"; else echo "UTM_STATE=old"; fi
  echo "UTM_RUNNING_VMS=$(utm_started_vms)"
  echo "NET=$net"; echo "INSTALLED=$(state_get INSTALL_DONE)"; echo "OUR_VM=$vm"; echo "WOW_DIR=$(state_get WOW_DIR)"
  local rp; rp=$(cat "$SUPPORT/lock/pid" 2>/dev/null); { [ -n "$rp" ] && kill -0 "$rp" 2>/dev/null; } || rp=""
  echo "RUNNING_PID=$rp"
  echo "PREFS_MANUAL=$(state_get UTM_PREFS_MANUAL)"
  echo "APP_NAME=$(state_get APP_NAME)"; echo "UTM_BY_US=$(state_get UTM_INSTALLED_BY_US)"; echo "VERSION=$WOWMAC_VERSION"
}

# ======================================================================= install
do_install() {
  local WOW="" MOVE_TO="" DOCK=1 UPDATE_UTM=0 DISK_GB=64 VM_SET=0 FRESH=0
  VM_NAME=$(state_get VM_NAME); APP_NAME=$(state_get APP_NAME)
  while [ $# -gt 0 ]; do
    case $1 in
      --wow-dir) WOW=$2; shift;; --move-to) MOVE_TO=$2; shift;; --app-name) APP_NAME=$2; shift;;
      --vm-name) VM_NAME=$2; VM_SET=1; shift;; --disk-gb) DISK_GB=$2; shift;; --no-dock) DOCK=0;;
      --update-utm) UPDATE_UTM=1;; --gui) GUI=1;; --fresh) FRESH=1;;
      *) echo "Unbekannte Option: $1"; exit 2;;
    esac; shift
  done
  local VM_EXPLICIT=$VM_SET
  [ -n "$(state_get VM_NAME)" ] && VM_EXPLICIT=1
  [ -n "$VM_NAME" ] || VM_NAME="WoW-Linux"
  [ -n "$APP_NAME" ] || APP_NAME="WoW 3.3.5a"
  [ -n "$WOW" ] || WOW=$(state_get WOW_DIR)
  start_logging install
  take_lock
  status RUN 0 "Start" ""

  # ---------------------------------------------------------------- 1
  step 1 "Voraussetzungen prüfen"
  [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || die "Dieser Mac hat keinen Apple-Chip (M1 oder neuer). Der Weg über Linux und FEX funktioniert nur dort."
  local major; major=$(sw_vers -productVersion | cut -d. -f1)
  [ "$major" -ge 13 ] || die "macOS $(sw_vers -productVersion) ist zu alt. Nötig ist macOS 13 oder neuer."
  valid_name "$VM_NAME" || die "Ungültiger VM-Name: $VM_NAME"
  valid_name "$APP_NAME" || die "Ungültiger App-Name: $APP_NAME (erlaubt: Buchstaben, Ziffern, Leerzeichen, . _ -)"
  local free; free=$(df -k "$HOME" | awk 'NR==2{print int($4/1048576)}')
  [ "$(state_get VM_ID)" ] || [ "$free" -ge 20 ] || die "Zu wenig freier Speicher: $free GB frei, nötig sind mindestens 20 GB."
  curl -sSfI -m 15 https://github.com >/dev/null 2>&1 || die "Keine Internetverbindung (github.com nicht erreichbar)."
  local ram_total cpus RAM_MB NCPU
  ram_total=$(( $(sysctl -n hw.memsize) / 1048576 )); cpus=$(sysctl -n hw.ncpu)
  RAM_MB=$(( ram_total / 2 )); [ $RAM_MB -gt 8192 ] && RAM_MB=8192; [ $RAM_MB -lt 4096 ] && RAM_MB=4096
  NCPU=$(( cpus - 2 )); [ $NCPU -gt 6 ] && NCPU=6; [ $NCPU -lt 2 ] && NCPU=2
  log "   RAM für die VM: $RAM_MB MB, Kerne: $NCPU, frei: $free GB"

  # ---------------------------------------------------------------- 2
  step 2 "WoW-Ordner prüfen"
  [ -n "$WOW" ] || die "Kein WoW-Ordner angegeben."
  WOW=$(cd "$WOW" 2>/dev/null && pwd -P) || die "WoW-Ordner nicht gefunden."
  local msg; msg=$(check_wow "$WOW") || die "$msg"
  if [ -n "$MOVE_TO" ]; then
    local dest; MOVE_TO=$(cd "$MOVE_TO" 2>/dev/null && pwd -P) || die "Zielordner nicht gefunden."
    dest="$MOVE_TO/$(basename "$WOW")"
    if [ "$dest" != "$WOW" ]; then
      [ -e "$dest" ] && die "Am Ziel gibt es schon einen Ordner $(basename "$WOW")."
      if [ "$(stat -f %d "$WOW")" = "$(stat -f %d "$MOVE_TO")" ]; then
        detail "Verschiebe den WoW-Ordner nach $MOVE_TO"
        mv "$WOW" "$dest" || die "Verschieben fehlgeschlagen."
      else
        local need have
        need=$(du -sk "$WOW" | awk '{print int($1/1048576)+1}'); have=$(df -k "$MOVE_TO" | awk 'NR==2{print int($4/1048576)}')
        [ "$have" -gt "$need" ] || die "Am Ziel ist zu wenig Platz ($have GB frei, nötig $need GB)."
        detail "Kopiere den WoW-Ordner auf das andere Laufwerk ($need GB) – das dauert"
        ditto "$WOW" "$dest" || die "Kopieren fehlgeschlagen."
        [ "$(find "$dest" -type f | wc -l)" -eq "$(find "$WOW" -type f | wc -l)" ] || die "Kopie unvollständig – der Originalordner bleibt unverändert."
        log "   Kopie vollständig. Der Originalordner bleibt liegen und kann von Hand gelöscht werden: $WOW"
        state_set OLD_WOW_DIR "$WOW"
      fi
      WOW=$dest
    fi
  fi
  case "$(fs_type "$WOW")" in apfs|hfs|"") ;; *) log "   WARNUNG: Dateisystem $(fs_type "$WOW") – empfohlen ist APFS." ;; esac
  if [ -f "$WOW/WTF/Config.wtf" ] && [ -z "$(state_get CONFIG_BACKUP)" ]; then
    cp -p "$WOW/WTF/Config.wtf" "$WOW/WTF/Config.wtf.vor-wowmac" && state_set CONFIG_BACKUP "$WOW/WTF/Config.wtf.vor-wowmac"
  fi
  state_set WOW_DIR "$WOW"; state_set APP_NAME "$APP_NAME"
  log "   WoW-Ordner: $WOW"

  # ---------------------------------------------------------------- 3
  step 3 "UTM prüfen bzw. installieren"
  local UTM_APP ver
  UTM_APP=$(find_utm); ver=""; [ -n "$UTM_APP" ] && ver=$(utm_version "$UTM_APP")
  if [ -n "$UTM_APP" ] && ver_ge "$ver" "$UTM_MIN_VERSION"; then
    log "   UTM $ver vorhanden: $UTM_APP"
  else
    if [ -n "$UTM_APP" ] && [ "$UPDATE_UTM" != 1 ]; then die "UTM $ver ist zu alt (nötig: $UTM_MIN_VERSION oder neuer). Bitte UTM aktualisieren und den Installer erneut starten."; fi
    [ "$(utm_started_vms)" = 0 ] || die "In UTM laufen noch VMs. Bitte diese beenden und den Installer erneut starten."
    utm_quit
    local D="$CACHE/UTM-$UTM_VERSION.dmg" MNT TARGET
    download_verified "$UTM_URL" "$D" "$UTM_SHA256" "UTM $UTM_VERSION" 300 || die "UTM konnte nicht geladen werden (github.com)."
    MNT=$(mktemp -d /tmp/wowmac-utm.XXXXXX)
    hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MNT" "$D" >/dev/null || die "UTM-Abbild lässt sich nicht öffnen."
    if ! codesign --verify --deep --strict "$MNT/UTM.app" 2>/dev/null || ! codesign -dv "$MNT/UTM.app" 2>&1 | grep -q "TeamIdentifier=$UTM_TEAM_ID"; then
      hdiutil detach "$MNT" -quiet; die "Die Signatur von UTM stimmt nicht – Abbruch."
    fi
    TARGET=/Applications; [ -w /Applications ] || TARGET="$APPS_DIR"; mkdir -p "$TARGET"
    [ -n "$UTM_APP" ] && to_trash "$UTM_APP"
    ditto "$MNT/UTM.app" "$TARGET/UTM.app" || { hdiutil detach "$MNT" -quiet; die "UTM konnte nicht nach $TARGET kopiert werden."; }
    hdiutil detach "$MNT" -quiet
    UTM_APP="$TARGET/UTM.app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$UTM_APP" 2>/dev/null
    [ -z "$(state_get UTM_INSTALLED_BY_US)" ] && state_set UTM_INSTALLED_BY_US 1
    log "   UTM $UTM_VERSION installiert: $UTM_APP"
  fi
  [ -z "$(state_get UTM_INSTALLED_BY_US)" ] && state_set UTM_INSTALLED_BY_US 0
  state_set UTM_APP "$UTM_APP"

  # ---------------------------------------------------------------- 4
  step 4 "UTM einstellen (Grafik: Apple Core OpenGL, Maus automatisch fangen)"
  if [ ! -d "$HOME/Library/Containers/com.utmapp.UTM" ]; then
    detail "UTM wird einmal gestartet (legt seine Einstellungen an)"
    open -g -a "$UTM_APP"; local i; for i in $(seq 1 30); do utm_running && break; sleep 1; done; sleep 4
  fi
  local kv k typ want cur needw=0 readable=1
  # Ist die Einstellungsdatei vorhanden, aber nicht lesbar, schuetzt macOS sie (Daten anderer Apps).
  if [ -e "$UTM_PREFS.plist" ] && ! cat "$UTM_PREFS.plist" >/dev/null 2>&1; then readable=0; fi
  for kv in QEMURendererBackend:int:3 FullScreenAutoCapture:bool:1 WindowFocusAutoCapture:bool:1; do
    k=${kv%%:*}; want=${kv##*:}
    if [ "$readable" = 1 ]; then cur=$(defaults read "$UTM_PREFS" "$k" 2>/dev/null) || cur="__unset__"; else cur="__unknown__"; fi
    [ -n "$(state_get "PREV_$k")" ] || state_set "PREV_$k" "$cur"
    [ "$cur" = "$want" ] || needw=1
  done
  if [ "$needw" = 1 ] && [ "$readable" = 0 ]; then
    for k in QEMURendererBackend FullScreenAutoCapture WindowFocusAutoCapture; do state_set "PREV_$k" "__unknown__"; done
    log "   UTM-Einstellungen nicht lesbar (macOS-Schutz für App-Daten) – Hinweis folgt am Ende"
    state_set UTM_PREFS_MANUAL 1
    needw=0
  fi
  if [ "$needw" = 1 ]; then
    if [ "$(utm_started_vms)" = 0 ]; then utm_quit; sleep 3; else log "   UTM läuft mit VMs – Einstellungen gelten für neu gestartete VMs"; fi
    local okw=1
    for kv in QEMURendererBackend:int:3 FullScreenAutoCapture:bool:1 WindowFocusAutoCapture:bool:1; do
      k=${kv%%:*}; typ=${kv#*:}; typ=${typ%%:*}; want=${kv##*:}
      if [ "$typ" = int ]; then defaults write "$UTM_PREFS" "$k" -int "$want" 2>/dev/null; else defaults write "$UTM_PREFS" "$k" -bool true 2>/dev/null; fi
      [ "$(defaults read "$UTM_PREFS" "$k" 2>/dev/null)" = "$want" ] || okw=0
    done
    if [ "$okw" = 1 ]; then state_set UTM_PREFS_MANUAL 0
    else
      for k in QEMURendererBackend FullScreenAutoCapture WindowFocusAutoCapture; do state_set "PREV_$k" "__unknown__"; done
      # macOS schuetzt die Daten anderer Apps; dann setzt die VM den Renderer selbst (-spice gl=core)
      # und der Nutzer schaltet das automatische Fangen der Maus einmal in UTM ein (Hinweis am Ende).
      log "   UTM-Einstellungen nicht direkt setzbar (macOS-Schutz für App-Daten) – Hinweis folgt am Ende"
      state_set UTM_PREFS_MANUAL 1
    fi
  fi
  log "   Renderer=$(defaults read "$UTM_PREFS" QEMURendererBackend 2>/dev/null) Vollbild-Fangen=$(defaults read "$UTM_PREFS" FullScreenAutoCapture 2>/dev/null) Fokus-Fangen=$(defaults read "$UTM_PREFS" WindowFocusAutoCapture 2>/dev/null)"

  utm_ensure || die "UTM lässt sich nicht starten."
  local VM_ID; VM_ID=$(state_get VM_ID)
  if [ -n "$VM_ID" ] && vm_exists "$VM_NAME" && [ "$(state_get PROVISION_DONE)" != 1 ] && \
     { [ "$FRESH" = 1 ] || [ ! -f "$(state_get SEED_ISO)" ]; }; then
    # Noch nicht fertig eingerichtete VM neu anlegen (auf Wunsch oder weil ihre Startdaten fehlen)
    log "   VM $VM_NAME ist unvollständig – wird neu angelegt"
    vm_poweroff "$VM_NAME"
    utm_osa 'delete virtual machine named (item 1 of argv)
return "ok"' "$VM_NAME" >/dev/null 2>&1 || die "Die unvollständige VM $VM_NAME ließ sich nicht entfernen."
    state_set VM_ID ""; VM_ID=""
  fi
  if [ -n "$VM_ID" ] && vm_exists "$VM_NAME"; then
    log "   VM $VM_NAME gibt es schon (aus einem früheren Lauf) – setze fort"
  else
    if vm_exists "$VM_NAME"; then
      [ "$VM_EXPLICIT" = 1 ] && die "In UTM gibt es schon eine VM namens \"$VM_NAME\", die nicht von diesem Installer stammt. Bitte einen anderen Namen wählen."
      local base=$VM_NAME n=2
      while vm_exists "$base-$n"; do n=$((n+1)); done
      VM_NAME="$base-$n"
      log "   Den Namen $base gibt es in UTM schon – die neue VM heißt $VM_NAME"
    fi
    VM_ID=""
    # ---------------------------------------------------------------- 5
    step 5 "Ubuntu-Abbild laden und prüfen"
    local IMG="$CACHE/$UBU_IMG"
    if ! download_verified "$UBU_REL/$UBU_IMG" "$IMG" "$UBU_SHA256" "Ubuntu 26.04" 900; then
      log "   feste Version nicht ladbar – versuche die aktuelle Version"
      local sums sha2
      sums=$(curl -fsSL --retry 3 "$UBU_FALLBACK/SHA256SUMS") || die "Ubuntu-Abbild nicht erreichbar (cloud-images.ubuntu.com)."
      sha2=$(printf '%s\n' "$sums" | awk -v f="$UBU_IMG" '$2==f || $2=="*"f {print $1; exit}')
      [ ${#sha2} -eq 64 ] || die "Prüfsumme für das Ubuntu-Abbild nicht gefunden."
      IMG="$CACHE/aktuell-$UBU_IMG"
      download_verified "$UBU_FALLBACK/$UBU_IMG" "$IMG" "$sha2" "Ubuntu 26.04 (aktuell)" 900 || die "Ubuntu-Abbild konnte nicht geladen werden."
    fi

    # ---------------------------------------------------------------- 6
    step 6 "VM-Platte und Startdaten vorbereiten"
    local B="$SUPPORT/build"
    rm -rf "$B"; mkdir -p "$B/seed"
    cp -c "$IMG" "$B/wow-linux.qcow2" 2>/dev/null || cp "$IMG" "$B/wow-linux.qcow2" || die "Kopieren des Abbilds fehlgeschlagen."
    bash "$HERE/lib/qcow2-grow.sh" "$B/wow-linux.qcow2" "$DISK_GB" || die "VM-Platte konnte nicht vergrößert werden."
    detect_locale
    log "   Tastatur: $KBD_NAME -> $XKB_L/$XKB_V (Wine $WINE_KBD), Sprache $LOCALE, Zeitzone $TZ_NAME"
    local G="$HERE/guest" b64p b64s b64l
    b64p=$(base64 < "$G/wow-provision" | tr -d '\n'); b64s=$(base64 < "$G/wow-start" | tr -d '\n'); b64l=$(base64 < "$G/wow-launch" | tr -d '\n')
    awk -v user=wow -v uid="$(id -u)" -v loc="$LOCALE" -v tz="$TZ_NAME" -v xl="$XKB_L" -v xv="$XKB_V" \
        -v lp="$LANGPACK" -v wk="$WINE_KBD" -v hv="$HANGOVER_VERSION" -v hs="$HANGOVER_SHA256" -v wv="$WOWMAC_VERSION" \
        -v bp="$b64p" -v bs="$b64s" -v bl="$b64l" '
      $0 == "__LANGPACK__" { if (lp != "") print lp; next }
      { gsub(/__USER__/, user); gsub(/__UID__/, uid); gsub(/__LOCALE__/, loc); gsub(/__TZ__/, tz)
        gsub(/__XKB_LAYOUT__/, xl); gsub(/__XKB_VARIANT__/, "\"" xv "\""); gsub(/__WINE_KBD__/, wk)
        gsub(/__HANGOVER_VERSION__/, hv); gsub(/__HANGOVER_SHA256__/, hs); gsub(/__WOWMAC_VERSION__/, wv)
        gsub(/__B64_PROVISION__/, bp); gsub(/__B64_START__/, bs); gsub(/__B64_LAUNCH__/, bl); print }' \
      "$G/user-data.tpl" > "$B/seed/user-data" || die "user-data"
    grep -q "__" "$B/seed/user-data" && grep -n "__[A-Z_]*__" "$B/seed/user-data" | head -3 && die "Platzhalter in user-data nicht ersetzt."
    printf 'instance-id: wowmac-%s\nlocal-hostname: wow-linux\n' "$(date +%Y%m%d%H%M%S)" > "$B/seed/meta-data"
    # UTM kopiert Wechsellaufwerke nicht in die VM, sondern verweist nur darauf -> dauerhaft ablegen
    local SEED="$SUPPORT/seed/$VM_NAME.iso"
    mkdir -p "$SUPPORT/seed"; rm -f "$SEED"
    hdiutil makehybrid -o "$SEED" "$B/seed" -iso -joliet -default-volume-name cidata >/dev/null || die "Startdaten (seed.iso) konnten nicht erstellt werden."
    state_set SEED_ISO "$SEED"

    # ---------------------------------------------------------------- 7
    step 7 "VM in UTM anlegen und starten"
    VM_ID=$(create_vm "$VM_NAME" "$B/wow-linux.qcow2" "$SEED" "$WOW" "$RAM_MB" "$NCPU" 2>&1) \
      || die "Die VM konnte in UTM nicht angelegt werden: $VM_ID"
    case "$VM_ID" in *-*-*-*-*) ;; *) die "Unerwartete Antwort von UTM: $VM_ID";; esac
    state_set VM_NAME "$VM_NAME"; state_set VM_ID "$VM_ID"; state_set PROVISION_DONE ""
    log "   VM angelegt: $VM_NAME ($VM_ID)"
    rm -rf "$B"
  fi

  if [ "$(state_get PROVISION_DONE)" != 1 ]; then
    [ "$(vm_status "$VM_NAME")" = stopped ] && { vm_share "$VM_NAME" "$WOW" || log "   WARNUNG: Freigabe des Spielordners ließ sich nicht erneuern"; }
    vm_start "$VM_NAME" || exit 1
    # ---------------------------------------------------------------- 8
    step 8 "Linux, Wine und FEX einrichten (dauert 15–30 Minuten)"
    local before=""
    if [ -n "$(state_get PROV_FAIL_STARTS)" ]; then
      detail "Letzter Versuch brach in der VM ab – Einrichtung wird wiederholt"
      local i; for i in $(seq 1 120); do vm_agent_ok "$VM_NAME" && break; sleep 2; done
      before=$(guest_read "$VM_NAME" /var/lib/wow-mac/status | grep -c '^START|')
      guest_exec "$VM_NAME" /usr/local/sbin/wow-provision || die "Einrichtung konnte nicht neu gestartet werden (Gastagent)."
    fi
    sleep 20; check_renderer
    wait_provision "$before" || exit 1
    state_set PROV_FAIL_STARTS ""
    state_set PROVISION_DONE 1
    # ---------------------------------------------------------------- 9
    step 9 "VM abschließen"
    guest_fetch "$VM_NAME" /var/lib/wow-mac/wow-icon.png "$SUPPORT/wow-icon.png" && log "   Programmsymbol aus Wow.exe übernommen"
    vm_poweroff "$VM_NAME"
    utm_osa 'create snapshot virtual machine named (item 1 of argv) named "Frisch installiert"
return "ok"' "$VM_NAME" >/dev/null 2>&1 && log "   UTM-Snapshot \"Frisch installiert\" angelegt" || log "   (kein Snapshot – UTM-Version unterstützt das per Skript nicht)"
  fi

  # ---------------------------------------------------------------- 10
  step 10 "Start-App und Deinstallation anlegen"
  install_apps "$DOCK" || die "Die Apps konnten nicht angelegt werden."
  state_set INSTALL_DONE 1
  log "== FERTIG. Start: $APPS_DIR/$APP_NAME.app"
  status DONE 100 "Fertig" "$APPS_DIR/$APP_NAME.app"
}

# Engine dauerhaft ablegen, Start-App und Deinstallations-App bauen
install_apps() {
  local dock=$1 icns="" app="$APPS_DIR/$APP_NAME.app" un="$APPS_DIR/$UNINSTALLER_NAME.app" f
  mkdir -p "$APPS_DIR" "$SUPPORT/app"
  if [ "$HERE" != "$SUPPORT/app/installer" ]; then
    rm -rf "$SUPPORT/app.neu"; mkdir -p "$SUPPORT/app.neu"
    cp -R "$HERE" "$SUPPORT/app.neu/installer" && rm -rf "$SUPPORT/app" && mv "$SUPPORT/app.neu" "$SUPPORT/app" || return 1
  fi
  local WOW; WOW=$(state_get WOW_DIR)
  for f in "$WOW/World of Warcraft.app/Contents/Resources/"*.icns; do [ -f "$f" ] && { icns=$f; break; }; done
  if [ -z "$icns" ] && [ -s "$SUPPORT/wow-icon.png" ]; then make_icns "$SUPPORT/wow-icon.png" "$SUPPORT/wow.icns" && icns="$SUPPORT/wow.icns"; fi
  if [ -e "$app" ] && ! is_our_app "$app" "$STARTER_ID"; then
    log "   Es gibt schon eine fremde App \"$APP_NAME\" – sie wird in den Papierkorb gelegt"; to_trash "$app"
  fi
  build_applet "$SUPPORT/app/installer/apps/starter.applescript" "$app" "$STARTER_ID" "$icns" || return 1
  build_applet "$SUPPORT/app/installer/apps/uninstaller.applescript" "$un" "$UNINSTALLER_ID" "" || return 1
  state_set STARTER_APP "$app"; state_set UNINSTALLER_APP "$un"
  if [ "$dock" = 1 ]; then dock_add "$app"; state_set DOCK_ADDED 1; fi
  log "   Start-App: $app"; log "   Deinstallation: $un"
}

create_vm() {   # NAME PLATTE SEED WOW-ORDNER RAM KERNE -> gibt die VM-ID aus
  osascript - "$@" <<'OSA'
on run argv
  set vmName to item 1 of argv
  set diskF to POSIX file (item 2 of argv)
  set seedF to POSIX file (item 3 of argv)
  set wowF to POSIX file (item 4 of argv)
  set ramMB to (item 5 of argv) as integer
  set nCpu to (item 6 of argv) as integer
  tell application id "com.utmapp.UTM"
    set vm to make new virtual machine with properties {backend:qemu, configuration:{name:vmName, architecture:"aarch64", memory:ramMB, cpu cores:nCpu, hypervisor:true, uefi:true, directory share mode:VirtFS, drives:{{interface:VirtIO, source:diskF}, {removable:true, source:seedF}}, displays:{{hardware:"virtio-gpu-gl-pci", dynamic resolution:true}}, qemu additional arguments:{{argument string:"-audiodev coreaudio,id=wowsnd"}, {argument string:"-device intel-hda"}, {argument string:"-device hda-output,audiodev=wowsnd"}, {argument string:"-spice gl=core"}}}}
    update registry of vm with {wowF}
    return id of vm
  end tell
end run
OSA
}

# Prüft am laufenden QEMU-Prozess, ob UTM wirklich Apple Core OpenGL nutzt (gl=core statt gl=es)
check_renderer() {
  local gl; gl=$(ps -axww -o args= 2>/dev/null | grep -i 'spice' | grep -v grep | grep -o 'gl=[a-z]*' | sort -u | tr '\n' ' ')
  log "   QEMU-Grafik: ${gl:-unbekannt}"
  case "$gl" in *gl=es*) log "   WARNUNG: UTM nutzt nicht Apple Core OpenGL – die Einstellung greift erst nach einem Neustart von UTM";; esac
}

vm_share() {   # Spielordner (neu) als VirtFS-Freigabe eintragen – UTM merkt sich die Freigabe als Lesezeichen
  local vm=$1 dir=$2
  osascript - "$vm" "$dir" <<'OSA' >/dev/null 2>&1
on run argv
  set wowF to POSIX file (item 2 of argv)
  tell application id "com.utmapp.UTM"
    update registry of virtual machine named (item 1 of argv) with {wowF}
  end tell
end run
OSA
}

vm_start() {   # startet die VM; ein zweiter Versuch, falls UTM dabei abstuerzt (Fehler -609)
  local vm=$1 err try
  for try in 1 2; do
    utm_ensure || die "UTM lässt sich nicht starten."
    case "$(vm_status "$vm")" in started|starting) return 0;; esac
    err=$(utm_osa 'start virtual machine named (item 1 of argv)' "$vm" 2>&1 >/dev/null) && return 0
    log "   Start-Versuch $try: $err"
    case "$err" in *-609*|*"Connection is invalid"*|*-1708*|*-1712*) sleep 5; continue;; esac
    break
  done
  die "Die VM startet nicht: $(printf '%s' "$err" | sed 's/.*QEMU error: //' | cut -c1-300)"
}

vm_poweroff() {
  local vm=$1 i
  [ "$(vm_status "$vm")" = stopped ] && return 0
  guest_exec "$vm" /usr/bin/systemctl poweroff || utm_osa 'stop virtual machine named (item 1 of argv) by request' "$vm" >/dev/null 2>&1
  for i in $(seq 1 90); do [ "$(vm_status "$vm")" = stopped ] && return 0; sleep 2; done
  utm_osa 'stop virtual machine named (item 1 of argv) by force' "$vm" >/dev/null 2>&1
  for i in $(seq 1 15); do [ "$(vm_status "$vm")" = stopped ] && return 0; sleep 2; done
  return 1
}

# Wartet auf die Einrichtung im Gast. $1 = Anzahl START-Zeilen, die schon vorher in der Statusdatei standen.
wait_provision() {
  local before=${1:-} t0 el s last n tot txt L done_n tot_p frac starts
  t0=$(date +%s)
  while :; do
    el=$(( $(date +%s) - t0 ))
    [ $el -gt 5400 ] && die "Die Einrichtung in der VM dauert ungewöhnlich lange (über 90 Minuten). Bitte Internetverbindung prüfen und den Installer erneut starten – er setzt fort."
    case "$(vm_status "$VM_NAME")" in stopped) die "Die VM wurde während der Einrichtung beendet. Bitte den Installer erneut starten – er setzt fort.";; esac
    if vm_agent_ok "$VM_NAME"; then
      s=$(guest_read "$VM_NAME" /var/lib/wow-mac/status)
      starts=$(printf '%s\n' "$s" | grep -c '^START|')
      if [ -n "$s" ] && { [ -z "$before" ] || [ "$starts" -gt "$before" ]; }; then
        last=$(printf '%s\n' "$s" | grep -v '^WARNUNG|' | tail -1)
        case "$last" in
          FERTIG*) detail "Einrichtung in der VM abgeschlossen" 100; return 0;;
          FEHLER*) state_set PROV_FAIL_STARTS "$starts"; die "In der VM: ${last#FEHLER|} (Installer erneut starten – er wiederholt die Einrichtung)";;
          SCHRITT*) n=$(echo "$last" | cut -d'|' -f2); tot=$(echo "$last" | cut -d'|' -f3); txt=$(echo "$last" | cut -d'|' -f4)
                    detail "WoW-Einrichtung $n/$tot: $txt" $(( 60 + 40 * (n - 1) / tot ));;
          *) detail "WoW-Einrichtung startet";;
        esac
      else
        L=$(guest_read "$VM_NAME" /var/log/cloud-init-output.log)
        tot_p=$(printf '%s\n' "$L" | sed -n 's/^\([0-9]*\) upgraded, \([0-9]*\) newly installed.*/\1 \2/p' | awk '{s+=$1+$2} END {print s+0}')
        done_n=$(printf '%s\n' "$L" | grep -c -E '^Setting up |wird eingerichtet')
        if [ "$tot_p" -gt 0 ]; then
          frac=$(( done_n * 100 / tot_p )); [ $frac -gt 100 ] && frac=100
          detail "Ubuntu-Pakete werden installiert: $done_n von $tot_p ($(( el / 60 )) Min.)" $(( 60 * frac / 100 ))
        else
          detail "Ubuntu wird vorbereitet ($(( el / 60 )) Min.)" 2
        fi
      fi
    else
      detail "Ubuntu startet zum ersten Mal ($(( el / 60 )) Min.)" 1
    fi
    sleep 5
  done
}

# ======================================================================= repair
do_repair() {
  while [ $# -gt 0 ]; do case $1 in --gui) GUI=1;; esac; shift; done
  start_logging repair; take_lock
  VM_NAME=$(state_get VM_NAME); APP_NAME=$(state_get APP_NAME)
  utm_ensure
  [ -n "$VM_NAME" ] && vm_exists "$VM_NAME" || die "Die VM dieser Installation fehlt in UTM. Bitte zuerst „WoW-Mac deinstallieren“ öffnen und danach neu installieren."
  CUR_STEP=8; CUR_TEXT="Einrichtung in der VM wiederholen"; status RUN 30 "$CUR_TEXT" ""
  [ "$(vm_status "$VM_NAME")" = stopped ] && vm_share "$VM_NAME" "$(state_get WOW_DIR)"
  vm_start "$VM_NAME"
  local i; for i in $(seq 1 120); do vm_agent_ok "$VM_NAME" && break; sleep 2; done
  local before; before=$(guest_read "$VM_NAME" /var/lib/wow-mac/status | grep -c '^START|')
  guest_exec "$VM_NAME" /usr/local/sbin/wow-provision || die "Einrichtung konnte nicht gestartet werden (Gastagent)."
  wait_provision "$before" || exit 1
  state_set PROVISION_DONE 1
  status DONE 100 "Reparatur abgeschlossen" ""
  log "== Reparatur fertig"
}

# ======================================================================= uninstall
do_uninstall() {
  local RM_UTM=0 RESTORE=0
  while [ $# -gt 0 ]; do
    case $1 in --remove-utm) RM_UTM=1;; --restore-config) RESTORE=1;; --gui) GUI=1;; *) echo "Unbekannte Option: $1"; exit 2;; esac; shift
  done
  start_logging uninstall; take_lock
  TOTAL_STEPS=5
  VM_NAME=$(state_get VM_NAME); APP_NAME=$(state_get APP_NAME)
  local VM_ID UTM_APP; VM_ID=$(state_get VM_ID); UTM_APP=$(find_utm)

  CUR_STEP=1; status RUN 5 "VM beenden und löschen" ""; log "== VM"
  [ -n "$VM_NAME" ] && [ -n "$UTM_APP" ] && utm_ensure
  if [ -n "$VM_NAME" ] && [ -n "$UTM_APP" ] && vm_exists "$VM_NAME"; then
    local id; id=$(utm_osa 'return id of virtual machine named (item 1 of argv)' "$VM_NAME" 2>/dev/null)
    if [ -n "$VM_ID" ] && [ "$id" = "$VM_ID" ]; then
      vm_poweroff "$VM_NAME" || log "   VM ließ sich nicht sauber beenden – wird hart gestoppt"
      utm_osa 'delete virtual machine named (item 1 of argv)
return "ok"' "$VM_NAME" >/dev/null 2>&1 && log "   VM $VM_NAME gelöscht" || die "Die VM konnte nicht gelöscht werden."
    else
      log "   VM \"$VM_NAME\" gehört nicht zu dieser Installation – bleibt unangetastet"
    fi
  else
    log "   keine VM zu löschen"
  fi

  status RUN 30 "Apps und Dock-Eintrag entfernen" ""; log "== Apps"
  local app un; app=$(state_get STARTER_APP); un=$(state_get UNINSTALLER_APP)
  if [ -n "$app" ] && [ -e "$app" ] && is_our_app "$app" "$STARTER_ID"; then dock_remove "$app"; to_trash "$app"; log "   $app -> Papierkorb"; fi
  tccutil reset All "$STARTER_ID" >/dev/null 2>&1; tccutil reset All "$UNINSTALLER_ID" >/dev/null 2>&1

  status RUN 50 "UTM-Einstellungen zurücksetzen" ""; log "== UTM-Einstellungen"
  local k prev
  for k in QEMURendererBackend FullScreenAutoCapture WindowFocusAutoCapture; do
    prev=$(state_get "PREV_$k")
    case "$prev" in
      ""|__unknown__) ;;
      __unset__) defaults delete "$UTM_PREFS" "$k" 2>/dev/null; log "   $k entfernt";;
      *) if [ "$k" = QEMURendererBackend ]; then defaults write "$UTM_PREFS" "$k" -int "$prev"; else defaults write "$UTM_PREFS" "$k" -bool "$([ "$prev" = 1 ] && echo true || echo false)"; fi
         log "   $k wieder $prev";;
    esac
  done

  if [ "$RM_UTM" = 1 ]; then
    status RUN 65 "UTM entfernen" ""; log "== UTM"
    if [ -z "$UTM_APP" ]; then log "   UTM nicht gefunden"
    elif [ "$(state_get UTM_INSTALLED_BY_US)" != 1 ]; then log "   UTM war schon vor der Installation da – bleibt"
    else
      local cnt; cnt=$(utm_osa 'return count of virtual machines' 2>/dev/null || echo 1)
      if [ "$cnt" != 0 ]; then log "   In UTM sind noch $cnt andere VMs – UTM bleibt"
      else utm_quit; to_trash "$UTM_APP" && log "   UTM -> Papierkorb"; fi
    fi
  fi

  if [ "$RESTORE" = 1 ]; then
    status RUN 80 "WoW-Einstellungen zurücksetzen" ""; log "== Config.wtf"
    local bk WOW; bk=$(state_get CONFIG_BACKUP); WOW=$(state_get WOW_DIR)
    if [ -n "$bk" ] && [ -f "$bk" ] && [ -f "$WOW/WTF/Config.wtf" ]; then
      cp -p "$WOW/WTF/Config.wtf" "$WOW/WTF/Config.wtf.vor-deinstallation" && cp -p "$bk" "$WOW/WTF/Config.wtf" && log "   Config.wtf zurückgesetzt (aktuelle Fassung: Config.wtf.vor-deinstallation)"
    else log "   keine Sicherung gefunden"; fi
  fi

  status RUN 90 "Hilfsdateien entfernen" ""; log "== Hilfsdateien"
  rm -rf "$CACHE"
  [ -n "$un" ] && [ -e "$un" ] && is_our_app "$un" "$UNINSTALLER_ID" && to_trash "$un"
  local ia="$APPS_DIR/WoW-Mac Installer.app"
  [ -e "$ia" ] && is_our_app "$ia" "io.github.wowmac.installer" && to_trash "$ia" && log "   Installer-App -> Papierkorb"
  local keep="$LOGDIR"
  rm -rf "$SUPPORT/app" "$SUPPORT/build" "$SUPPORT/seed" "$SUPPORT/wow-icon.png" "$SUPPORT/wow.icns" "$STATE"
  log "== FERTIG. Der Spielordner wurde nicht verändert. Protokolle bleiben in $keep"
  status DONE 100 "Deinstallation abgeschlossen" "Der Spielordner wurde nicht verändert."
}

# ======================================================================= status
do_status() {
  echo "WoW-Mac $WOWMAC_VERSION"
  [ -f "$STATE" ] && sed 's/^/  /' "$STATE" || echo "  (nicht installiert)"
  local vm; vm=$(state_get VM_NAME)
  [ -n "$vm" ] && [ -n "$(find_utm)" ] && echo "  VM-Status: $(vm_status "$vm")"
  [ -f "$STATUS" ] && echo "  Letzter Fortschritt: $(tr '\t' ' ' < "$STATUS")"
}

cmd=${1:-help}; [ $# -gt 0 ] && shift
case "$cmd" in
  preflight) do_preflight ;;
  check-wow) check_wow "${1:-}" && echo OK ;;
  install)   do_install "$@" ;;
  repair)    do_repair "$@" ;;
  uninstall) do_uninstall "$@" ;;
  status)    do_status ;;
  stop)      p=$(cat "$SUPPORT/lock/pid" 2>/dev/null)
             if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then pkill -P "$p" 2>/dev/null; kill "$p" 2>/dev/null; sleep 2; kill -0 "$p" 2>/dev/null && kill -9 "$p"; echo "gestoppt"; else echo "läuft nicht"; fi
             rm -rf "$SUPPORT/lock" ;;
  detect)    detect_locale; echo "Tastatur=$KBD_NAME XKB=$XKB_L/$XKB_V Wine=$WINE_KBD Sprache=$LOCALE Paket=${LANGPACK:-keins} Zeitzone=$TZ_NAME" ;;
  *) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
