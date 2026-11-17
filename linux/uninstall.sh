#!/usr/bin/env bash
# uninstall.sh – entfernt, was linux/install.sh angelegt hat. Der WoW-Ordner bleibt unverändert.
# Aufruf: bash uninstall.sh
set -u
[ "$(id -u)" = 0 ] && { echo "Bitte NICHT mit sudo starten."; exit 1; }
pgrep -xi 'wow.exe' >/dev/null 2>&1 && { echo "WoW läuft noch. Bitte zuerst beenden."; exit 1; }
ask() { local a; printf '%s [j/N] ' "$1"; read -r a </dev/tty || a=""; case "$a" in j|J|ja|Ja|y|Y) return 0;; esac; return 1; }
DDIR="$(xdg-user-dir DESKTOP 2>/dev/null)"; [ -n "$DDIR" ] || DDIR="$HOME/Desktop"
for f in "$HOME/.local/share/applications/wow-335a.desktop" "$DDIR/wow-335a.desktop" \
         "$HOME/.local/share/icons/wow-335a.png" "$HOME/bin/wow-starten.sh"; do
  [ -e "$f" ] && rm -f "$f" && echo "entfernt: $f"
done
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
if [ -d "$HOME/.wine-wow" ]; then
  echo "Die Wine-Umgebung ~/.wine-wow ($(du -sh "$HOME/.wine-wow" 2>/dev/null | cut -f1)) enthält nur Wine und DXVK, keine Spieldaten."
  if ask "~/.wine-wow löschen?"; then rm -rf "$HOME/.wine-wow" && echo "entfernt: ~/.wine-wow"; else echo "~/.wine-wow bleibt."; fi
fi
echo
echo "Fertig. Der WoW-Ordner wurde nicht angefasst. Sicherungen der Einstellungen liegen dort als WTF_Backup_Linux_<Datum>."
echo "Die installierten Pakete (wine, winetricks, Vulkan, icoutils) bleiben, weil andere Programme sie nutzen könnten."
echo "Wer sie auch entfernen will:  sudo apt remove wine wine32 wine64 winetricks && sudo apt autoremove"
