#!/usr/bin/env bash
# install.sh – World of Warcraft 3.3.5a auf Linux Mint / Ubuntu (x86-64): Wine (32-Bit-Prefix) + DXVK 2.7.1
# Teil von github.com/EserYueksel/wow-mac (Ordner linux/). Anleitung: linux/README.md
#
# Aufruf:  bash install.sh [/pfad/zum/WoW-Ordner]
#          ohne Pfad wird der Ordner mit Wow.exe im Persönlichen Ordner gesucht.
#
# Was es tut:
#  - installiert Wine, winetricks, Vulkan-Bibliotheken und icoutils aus den Paketquellen der Distribution (sudo)
#  - legt ~/.wine-wow an (32 Bit, Windows 7, Tastatur wie im System)
#  - setzt DXVK 2.7.1 ein (offizielles Release github.com/doitsujin/dxvk, Prüfsumme fest)
#  - stellt in WTF/Config.wtf nur Grafik-Schlüssel ein (vorher Sicherung des WTF-Ordners)
#  - legt Starter (~/bin/wow-starten.sh), Menüeintrag und Desktop-Verknüpfung mit WoW-Symbol an
# Was es NICHT tut: nichts an Wow.exe, Data/, Interface/ oder WTF/Account ändern; nichts löschen.
set -u

PREFIX="$HOME/.wine-wow"
LOG="$HOME/wow-setup.log"
DXVK_V="2.7.1"
DXVK_SHA256="d85ce7c79f57ecd765aaa1b9e7007cb875e6fde9f6d331df799bce73d513ce87"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_V}/dxvk-${DXVK_V}.tar.gz"
exec > >(tee -a "$LOG") 2>&1
WOWLINUX_VERSION="1.0.0"
echo "=== WoW-Linux $WOWLINUX_VERSION – $(date) ==="
[ "$(id -u)" = 0 ] && { echo "FEHLER: Bitte NICHT mit sudo starten – das Skript fragt selbst nach dem Passwort."; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo "FEHLER: Nur für x86-64-Rechner (Intel/AMD). Für Macs mit Apple-Chip siehe README im Hauptordner."; exit 1; }
command -v apt-get >/dev/null || { echo "FEHLER: apt fehlt – gedacht für Linux Mint, Ubuntu und Debian-Abkömmlinge."; exit 1; }

say()  { printf '\n== %s ==\n' "$*"; }
warn() { printf 'HINWEIS: %s\n' "$*"; WARN=1; }
die()  { printf '\nFEHLER: %s\n(Protokoll: %s)\n' "$*" "$LOG"; exit 1; }
WARN=0

# ---------------------------------------------------------------- 1
say "1. Prüfen"
GAME_DIR="${1:-}"
if [ -z "$GAME_DIR" ]; then
  GAME_DIR="$(find "$HOME" -maxdepth 5 -type f -iname 'Wow.exe' -not -path '*/.wine*' -not -path '*/.local/share/Trash/*' 2>/dev/null | head -1)"
  GAME_DIR="${GAME_DIR%/*}"
fi
[ -n "$GAME_DIR" ] && [ -f "$GAME_DIR/Wow.exe" ] || die "Wow.exe nicht gefunden. Bitte den WoW-Ordner angeben: bash $0 /pfad/zum/WoW-Ordner"
[ -d "$GAME_DIR/Data" ] || die "Ordner Data fehlt in: $GAME_DIR"
echo "WoW-Ordner: $GAME_DIR"
[ -w "$GAME_DIR" ] || die "Keine Schreibrechte im WoW-Ordner (Einstellungen könnten nicht gespeichert werden)."
echo "Wow.exe md5: $(md5sum "$GAME_DIR/Wow.exe" | cut -d' ' -f1)"
. /etc/os-release; echo "System: $PRETTY_NAME, Kernel $(uname -r)"
echo "Sitzung: ${XDG_SESSION_TYPE:-?}"
[ "${XDG_SESSION_TYPE:-}" = "x11" ] || warn "Keine X11-Sitzung. Bei springender Kamera bitte beim Anmelden X11 wählen."
pgrep -xi 'wow.exe' >/dev/null 2>&1 && die "WoW läuft noch. Bitte zuerst beenden."
# Unvollständig kopierter Spielordner (häufig: abgebrochenes Kopieren, danach Duplikate „… (2).mpq“)
DUP="$(ls "$GAME_DIR/Data" 2>/dev/null | grep -E ' \([0-9]+\)\.[Mm][Pp][Qq]$')"
[ -n "$DUP" ] && warn "Im Ordner Data liegen doppelte Dateien mit „(2)“ im Namen – das deutet auf einen abgebrochenen Kopiervorgang hin. Siehe README, Abschnitt „Failed to open archive common.MPQ“:
$DUP"
for m in common.MPQ:2884765590 common-2.MPQ:1814307386 expansion.MPQ:1923425368 lichking.MPQ:2581185567; do
  f="${m%%:*}"; want="${m##*:}"
  p="$(find "$GAME_DIR/Data" -maxdepth 1 -iname "$f" | head -1)"
  if [ -z "$p" ]; then warn "Data/$f fehlt."
  else have="$(stat -c%s "$p")"; [ "$have" -ge "$want" ] || warn "Data/$f ist mit $have Bytes kleiner als üblich ($want) – vermutlich unvollständig kopiert."; fi
done
FREE_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9); echo "Frei: ${FREE_GB} GB"
[ "${FREE_GB:-0}" -ge 3 ] || die "Zu wenig Platz (mindestens 3 GB frei nötig)."

command -v lspci >/dev/null || sudo apt-get install -y pciutils >/dev/null
GPU_INFO="$(lspci | grep -Ei 'vga|3d|display')"; echo "$GPU_INFO"
HAS_NVIDIA=0; echo "$GPU_INFO" | grep -qi nvidia && HAS_NVIDIA=1
HAS_OTHER=0;  echo "$GPU_INFO" | grep -Eqi 'intel|amd|ati' && HAS_OTHER=1
OPTIMUS=0; [ "$HAS_NVIDIA" = 1 ] && [ "$HAS_OTHER" = 1 ] && OPTIMUS=1
echo "NVIDIA: $HAS_NVIDIA, zweite Grafik: $HAS_OTHER, Optimus: $OPTIMUS"

# ---------------------------------------------------------------- 2
say "2. NVIDIA-Treiber"
NV_VER=""
if [ "$HAS_NVIDIA" = 1 ]; then
  if nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    NV_VER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1 | cut -d. -f1)"
    command -v prime-select >/dev/null && echo "Prime: $(prime-select query 2>&1)"
    [ "$(prime-select query 2>/dev/null)" = "intel" ] && die "Prime steht auf intel. In den NVIDIA-Einstellungen (Systemleiste) On-Demand wählen, neu starten, Skript erneut starten."
  else
    if ! dpkg -l 2>/dev/null | grep -qE '^ii +nvidia-driver-[0-9]'; then
      die "Kein NVIDIA-Treiber installiert. Bitte in der Treiberverwaltung den empfohlenen NVIDIA-Treiber wählen, neu starten und das Skript erneut starten (README, Schritt 1)."
    fi
    if mokutil --sb-state 2>/dev/null | grep -qi enabled && [ -f /var/lib/shim-signed/mok/MOK.der ] \
       && mokutil --test-key /var/lib/shim-signed/mok/MOK.der 2>/dev/null | grep -qi 'not enrolled'; then
      die "Der NVIDIA-Treiber ist installiert, darf aber nicht laden: Secure Boot ist an und der Schlüssel des Treibers wurde nie bestätigt.
So geht es (Secure Boot bleibt an):
  1. sudo mokutil --import /var/lib/shim-signed/mok/MOK.der   (danach ein Einmal-Passwort ausdenken, nur Kleinbuchstaben ohne y/z und Ziffern)
  2. Neu starten -> blauer Bildschirm \"Perform MOK management\": sofort eine Taste drücken
  3. Enroll MOK -> Continue -> Yes -> Einmal-Passwort -> Reboot
  4. Prüfen: nvidia-smi   – dann dieses Skript erneut starten (README, Schritt 1)"
    fi
    die "Der NVIDIA-Treiber ist installiert, aber nicht geladen (nvidia-smi geht nicht). Bitte neu starten; hilft das nicht, siehe README, Schritt 1."
  fi
fi

# ---------------------------------------------------------------- 3
say "3. Pakete (sudo-Passwort wird abgefragt)"
echo "Installiert aus den Mint/Ubuntu-Quellen: wine (32 + 64 Bit), winetricks, Vulkan-Bibliotheken, icoutils."
sudo dpkg --add-architecture i386 || die "i386-Architektur ließ sich nicht einschalten"
sudo apt-get update || warn "apt update meldete Fehler (siehe oben) – es geht trotzdem weiter"
sudo apt-get install -y wine wine32 wine64 libwine libwine:i386 winetricks cabextract \
     libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 vulkan-tools \
     icoutils pciutils x11-xserver-utils x11-xkb-utils curl \
  || die "apt-Installation fehlgeschlagen (Meldung oben lesen)"
if [ -n "$NV_VER" ]; then
  if dpkg -s "libnvidia-gl-$NV_VER:i386" >/dev/null 2>&1; then
    echo "32-Bit-NVIDIA-Teil vorhanden: libnvidia-gl-$NV_VER:i386"
  else
    sudo apt-get install -y "libnvidia-gl-$NV_VER:i386" || die "libnvidia-gl-$NV_VER:i386 nicht installierbar – muss zur Treiberversion passen."
  fi
fi
echo "Wine: $(wine --version 2>&1)"

# ---------------------------------------------------------------- 4
say "4. Vulkan-Test"
NVENV=""
[ "$OPTIMUS" = 1 ] && NVENV="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only"
VK="$(env $NVENV vulkaninfo --summary 2>&1)"
echo "$VK" | grep -E 'deviceName|driverName|apiVersion' | head -8
if [ "$HAS_NVIDIA" = 1 ]; then
  echo "$VK" | grep -q 'deviceName.*NVIDIA' || warn "Vulkan sieht die NVIDIA-Karte nicht. WoW würde langsam über die Intel-Grafik laufen."
fi

# ---------------------------------------------------------------- 5
say "5. Wine-Umgebung (32 Bit) in $PREFIX"
export WINEPREFIX="$PREFIX" WINEARCH=win32 WINEDEBUG=-all
if [ ! -f "$PREFIX/system.reg" ]; then
  wineboot -u || die "Wine-Umgebung konnte nicht angelegt werden"
  wineserver -w
fi
grep -q '#arch=win32' "$PREFIX/system.reg" || die "$PREFIX ist kein 32-Bit-Prefix. Bitte umbenennen (z. B. ~/.wine-wow-alt) und erneut starten."
wine reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win7 /f >/dev/null || warn "Windows-7-Modus nicht gesetzt"
# Tastatur wie im System (sonst kommen ä ö ü im WoW-Chat nicht an)
XKB="$(setxkbmap -query 2>/dev/null | awk '/^layout/{print $2}' | cut -d, -f1)"
case "$XKB" in
  de) KBD=00000407;; us) KBD=00000409;; gb) KBD=00000809;; tr) KBD=0000041f;;
  fr) KBD=0000040c;; gr) KBD=00000408;; ch) KBD=00000807;; at) KBD=00000c07;;
  *)  KBD=00000407;;
esac
echo "Tastatur: ${XKB:-?} -> $KBD"
wine reg add 'HKCU\Keyboard Layout\Preload' /v 1 /t REG_SZ /d "$KBD" /f >/dev/null || warn "Tastatur-Layout nicht gesetzt"
for d in d3d9 d3d10core d3d11 d3d8 dxgi; do
  wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /t REG_SZ /d native /f >/dev/null
done
for d in mscoree mshtml; do
  wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$d" /t REG_SZ /d "" /f >/dev/null
done
wineserver -w

# ---------------------------------------------------------------- 6
say "6. DXVK $DXVK_V"
SYS32="$PREFIX/drive_c/windows/system32"
TMP="$(mktemp -d)"
curl -fL --retry 3 -sS -o "$TMP/dxvk.tar.gz" "$DXVK_URL" || die "Download fehlgeschlagen: $DXVK_URL"
echo "$DXVK_SHA256  $TMP/dxvk.tar.gz" | sha256sum -c --status || die "Prüfsumme von DXVK stimmt nicht – abgebrochen."
tar -xzf "$TMP/dxvk.tar.gz" -C "$TMP" || die "Entpacken fehlgeschlagen"
BAK="$PREFIX/dxvk-backup-$(date +%F-%H%M%S)"; mkdir -p "$BAK"
for f in "$TMP/dxvk-$DXVK_V/x32"/*.dll; do
  n="$(basename "$f")"
  [ -f "$SYS32/$n" ] && cp -a "$SYS32/$n" "$BAK/$n"
  cp -f "$f" "$SYS32/$n" && echo "eingesetzt: $n"
done
rm -rf "$TMP"
SZ="$(stat -c%s "$SYS32/d3d9.dll")"; echo "d3d9.dll: $SZ Bytes"
[ "$SZ" -gt 1000000 ] || die "d3d9.dll ist zu klein – DXVK nicht aktiv."

# ---------------------------------------------------------------- 7
say "7. Grafik-Einstellungen (WTF/Config.wtf)"
BK="$GAME_DIR/WTF_Backup_Linux_$(date +%F-%H%M%S)"
if [ -d "$GAME_DIR/WTF" ]; then cp -a "$GAME_DIR/WTF" "$BK" && echo "WTF gesichert: $BK"; fi
mkdir -p "$GAME_DIR/WTF"
CFG="$GAME_DIR/WTF/Config.wtf"; [ -f "$CFG" ] || : > "$CFG"
set_cfg() { if grep -q "^SET $1 " "$CFG"; then sed -i "s|^SET $1 .*|SET $1 \"$2\"|" "$CFG"; else printf 'SET %s "%s"\n' "$1" "$2" >> "$CFG"; fi; }
LINE="$(xrandr --current 2>/dev/null | awk '/ connected/ {c=$1} /^ +[0-9]+x[0-9]+/ && c { for(i=2;i<=NF;i++) if ($i ~ /\*/) {print $1, $i; exit} }')"
RES="$(echo "$LINE" | awk '{print $1}')"
REF="$(echo "$LINE" | awk '{print $2}' | sed 's/[^0-9.].*//' | cut -d. -f1)"
echo "Bildschirm: ${RES:-?} @ ${REF:-?} Hz"
set_cfg gxApi d3d9
[ -n "$RES" ] && set_cfg gxResolution "$RES"
[ -n "$REF" ] && [ "$REF" -ge 30 ] 2>/dev/null && set_cfg gxRefresh "$REF"
set_cfg gxVSync 0
set_cfg maxFPS 120
set_cfg maxFPSBk 15
set_cfg EnableVoiceChat 0
set_cfg EnableMicrophone 0
grep -E '^SET (gxApi|gxResolution|gxRefresh|gxWindow|gxMaximize|gxVSync|maxFPS|maxFPSBk) ' "$CFG"

# ---------------------------------------------------------------- 8
say "8. Starter, Symbol und Menüeintrag"
mkdir -p "$HOME/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons"
[ -f "$HOME/bin/wow-starten.sh" ] && cp -a "$HOME/bin/wow-starten.sh" "$HOME/bin/wow-starten.sh.alt-$(date +%F-%H%M%S)"
{
  echo '#!/usr/bin/env bash'
  echo '# Startet WoW 3.3.5a über Wine + DXVK (erzeugt von WoW-Linux, github.com/EserYueksel/wow-mac)'
  printf 'GAME_DIR=%q\n' "$GAME_DIR"
  printf 'PREFIX=%q\n' "$PREFIX"
  echo 'export WINEPREFIX="$PREFIX" WINEARCH=win32 WINEDEBUG=-all DXVK_LOG_LEVEL=none'
  if [ "$OPTIMUS" = 1 ]; then
    echo '# Optimus: WoW auf der NVIDIA-Karte rechnen lassen (Desktop bleibt auf der Intel-Grafik)'
    echo 'export __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only DXVK_FILTER_DEVICE_NAME=NVIDIA'
    echo 'export __GL_SHADER_DISK_CACHE=1 __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1'
  fi
  echo 'if pgrep -xi wow.exe >/dev/null; then echo "WoW läuft bereits."; exit 0; fi'
  echo 'cd "$GAME_DIR" || exit 1'
  echo 'echo "=== Start $(date) ===" >> "$HOME/wow-wine.log"'
  echo 'exec wine Wow.exe "$@" >> "$HOME/wow-wine.log" 2>&1'
} > "$HOME/bin/wow-starten.sh"
chmod +x "$HOME/bin/wow-starten.sh"

ICON="$HOME/.local/share/icons/wow-335a.png"
T="$(mktemp -d)"
wrestool -x -t 14 -o "$T" "$GAME_DIR/Wow.exe" 2>/dev/null
I="$(ls "$T"/*.ico 2>/dev/null | head -1)"
if [ -n "$I" ]; then
  icotool -x -o "$T" "$I" 2>/dev/null
  B="$(ls "$T"/*.png 2>/dev/null | awk -F_ '{split($NF,a,"x"); print a[1]" "$0}' | sort -n | tail -1 | cut -d' ' -f2-)"
  [ -n "$B" ] && cp "$B" "$ICON"
fi
rm -rf "$T"
ICON_LINE=""; [ -s "$ICON" ] && ICON_LINE="Icon=$ICON" || warn "Kein Symbol gefunden – der Menüeintrag hat ein Standardsymbol."
DESK="$HOME/.local/share/applications/wow-335a.desktop"
cat > "$DESK" <<EOF
[Desktop Entry]
Type=Application
Name=World of Warcraft 3.3.5a
Comment=World of Warcraft 3.3.5a
Exec=$HOME/bin/wow-starten.sh
Path=$GAME_DIR
Terminal=false
Categories=Game;
StartupWMClass=wow.exe
$ICON_LINE
EOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
DDIR="$(xdg-user-dir DESKTOP 2>/dev/null)"; [ -n "$DDIR" ] && [ "$DDIR" != "$HOME" ] || DDIR="$HOME/Desktop"
if [ -d "$DDIR" ] && [ "${WOW_DESKTOP:-1}" = 1 ]; then
  cp -f "$DESK" "$DDIR/" && chmod +x "$DDIR/wow-335a.desktop"
  gio set "$DDIR/wow-335a.desktop" metadata::trusted true 2>/dev/null || true
  echo "Desktop-Verknüpfung: $DDIR/wow-335a.desktop"
fi
echo "Menüeintrag: $DESK"

# ---------------------------------------------------------------- fertig
say "Fertig"
[ "$WARN" = 1 ] && echo "Es gab Hinweise (oben mit HINWEIS markiert)."
echo "Start: Doppelklick auf dem Desktop oder Menü -> Spiele -> World of Warcraft 3.3.5a (oder ~/bin/wow-starten.sh)"
echo "Protokolle: $LOG (Einrichtung), ~/wow-wine.log (Wine), $GAME_DIR/Errors/ (Spiel)"
echo "FPS im Spiel: /run print(GetFramerate()) in den Chat eintippen."
echo "Hängt das Beenden: WINEPREFIX=$PREFIX wineserver -k"
