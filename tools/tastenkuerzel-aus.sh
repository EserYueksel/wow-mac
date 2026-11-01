#!/bin/bash
# tastenkuerzel-aus.sh – schaltet in der WoW-VM die Tastenkürzel der Oberfläche (Xfce) ab.
# Für Installationen vor 1.1.1, ohne „Reparieren“. Ändert nichts am Spiel; WoW darf dabei laufen.
# Grund: Nach dem Freigeben der Maus mit Ctrl + Option bleiben Ctrl und Alt für Linux „gedrückt“,
# dann wird D zu Ctrl+Alt+D („Desktop anzeigen“) und WoW verschwindet.
# Aufruf: curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/tools/tastenkuerzel-aus.sh | bash
STATE="$HOME/Library/Application Support/WoW-Mac/state.env"
VM=$( [ -f "$STATE" ] && grep '^VM_NAME=' "$STATE" | tail -1 | cut -d= -f2- )
VM="${1:-${VM:-WoW-Linux}}"
read -r -d '' G <<'GAST'
# läuft als root in der VM: Xfce-Tastenkürzel abschalten (wie wow-mac 1.1.1)
exec > /tmp/wow-tasten.txt 2>&1
U=eser; [ -f /etc/wow-mac.conf ] && . /etc/wow-mac.conf && U="${WOW_USER:-eser}"
id "$U" >/dev/null || { echo "FEHLER: Benutzer $U fehlt"; exit 1; }
H=$(getent passwd "$U" | cut -d: -f6); X="$H/.config/xfce4/xfconf/xfce-perchannel-xml"
BUS="/run/user/$(id -u "$U")/bus"
if pgrep -u "$U" -x xfconfd >/dev/null && [ -S "$BUS" ]; then
  xq() { sudo -u "$U" -H env DBUS_SESSION_BUS_ADDRESS="unix:path=$BUS" xfconf-query -c xfce4-keyboard-shortcuts "$@"; }
  echo "Kürzel vorher: $(xq -l | grep -c '/custom/<')"
  for p in xfwm4 commands; do
    xq -p "/$p/custom/override" -n -t bool -s true
    xq -l | grep "^/$p/custom/" | grep -v '/override$' | while IFS= read -r k; do xq -p "$k" -r; done
  done
  echo "Kürzel nachher: $(xq -l | grep -c '/custom/<')"
  echo "Ctrl+Alt+D: $(xq -p '/xfwm4/custom/<Primary><Alt>d' 2>&1)"
else
  mkdir -p "$X"
  cat > "$X/xfce4-keyboard-shortcuts.xml" <<'E'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
</channel>
E
  chown -R "$U:" "$H/.config"
  echo "Keine laufende Sitzung – Datei vorgegeben (gilt ab der nächsten Anmeldung)"
fi
echo FERTIG
GAST
r=$(osascript - "$VM" "$G" <<'OSA' 2>&1
on run argv
  tell application "UTM"
    set vm to virtual machine named (item 1 of argv)
    if status of vm is not started then return "VM_AUS"
    execute of vm at "/bin/bash" with arguments {"-c", item 2 of argv}
  end tell
  return "ok"
end run
OSA
)
case "$r" in
  VM_AUS) echo "Die VM „$VM“ läuft nicht. Bitte zuerst WoW über die Start-App öffnen (oder die VM in UTM starten) und dann erneut ausführen."; exit 1;;
  ok) ;;
  *) echo "UTM-Fehler: $r"; exit 1;;
esac
sleep 5
osascript - "$VM" <<'OSA'
on run argv
  tell application "UTM"
    set f to open file of virtual machine named (item 1 of argv) at "/tmp/wow-tasten.txt" for reading
    return read f
  end tell
end run
OSA
