#!/bin/bash
# tasten-fix.sh – richtet in der WoW-VM den Tastenwächter ein und schaltet die Xfce-Tastenkürzel ab.
# Für Installationen vor 1.1.1, ohne „Reparieren“. Ändert nichts am Spiel; WoW darf dabei laufen.
# Grund: Nach dem Freigeben der Maus mit Ctrl + Option bleiben Ctrl/Alt für Linux „gedrückt“,
# dann wird M zu Ctrl+M (Musik aus), S zu Ctrl+S (Ton aus), D zu Ctrl+Alt+D (WoW verschwindet).
# Aufruf: curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/tools/tasten-fix.sh | bash
STATE="$HOME/Library/Application Support/WoW-Mac/state.env"
VM=$( [ -f "$STATE" ] && grep '^VM_NAME=' "$STATE" | tail -1 | cut -d= -f2- )
VM="${1:-${VM:-WoW-Linux}}"
read -r -d '' G <<'GAST'
# läuft als root in der VM: Tastenkürzel aus + Tastenwächter (wow-mac 1.1.1)
exec > /tmp/wow-tasten.txt 2>&1
U=eser; [ -f /etc/wow-mac.conf ] && . /etc/wow-mac.conf && U="${WOW_USER:-eser}"
id "$U" >/dev/null || { echo "FEHLER: Benutzer $U fehlt"; exit 1; }
H=$(getent passwd "$U" | cut -d: -f6); X="$H/.config/xfce4/xfconf/xfce-perchannel-xml"
BUS=""
for pid in $(pgrep -u "$U" -x xfconfd) $(pgrep -u "$U" -x xfwm4); do      # Bus der laufenden Sitzung
  BUS=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -1)
  [ -n "$BUS" ] && break
done
if [ -n "$BUS" ] && pgrep -u "$U" -x xfconfd >/dev/null; then
  xq() { sudo -u "$U" -H env DBUS_SESSION_BUS_ADDRESS="$BUS" xfconf-query -c xfce4-keyboard-shortcuts "$@"; }
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
# Tastenwächter: löst hängende Ctrl/Alt/Cmd nach dem Verlassen der VM
cat > /usr/local/sbin/wow-tastenwaechter.neu <<'PY'
#!/usr/bin/python3
# wow-tastenwaechter – löst in der VM hängengebliebene Ctrl/Alt/Shift/Cmd-Tasten (läuft als root, systemd).
#
# Problem: Gibt man in UTM die Maus mit Ctrl + Option frei (oder verlässt die VM mit Cmd + Tab), bekommt die
# VM nur das Drücken der Tasten mit, das Loslassen landet schon beim Mac. Für Linux und WoW bleiben die
# Tasten gedrückt: D wird zu Ctrl+Alt+D, M zu Ctrl+M (Musik aus), S zu Ctrl+S (Ton aus) usw.
# Lösung: Der Wächter schickt ein „Loslassen“ direkt an die virtuelle Tastatur,
#  1. sobald Ctrl und Alt zusammen oder Cmd gedrückt werden (= UTM-Freigabe bzw. Verlassen der VM) und
#  2. wenn Ctrl, Alt oder Cmd länger als STALE Sekunden gedrückt sind, ohne dass eine andere Taste kommt
#     (falls UTM nur einen Teil der Kombination an die VM weitergibt).
# WoW nutzt weder Ctrl+Alt noch Cmd; Shift bleibt bei Regel 2 außen vor (wird im Spiel länger gehalten).
import os, struct, select, time, sys

EV_SYN, EV_KEY, SYN_REPORT = 0, 1, 0
CTRL, ALT, SHIFT, META = {29, 97}, {56, 100}, {42, 54}, {125, 126}
MODS = CTRL | ALT | SHIFT | META
STALE = 3.0                                    # Sekunden ohne andere Taste -> Ctrl/Alt/Cmd gilt als hängend
FMT = "llHHi"                                  # struct input_event (64 Bit)
SIZE = struct.calcsize(FMT)


def log(msg):
    print(msg, flush=True)


def keyboards():
    """Ereignisgeräte mit Tastatur-Handler (kbd) aus /proc/bus/input/devices."""
    found, name = [], ""
    try:
        text = open("/proc/bus/input/devices").read()
    except OSError:
        return found
    for line in text.splitlines():
        if line.startswith("N: Name="):
            name = line.split("=", 1)[1].strip('"')
        elif line.startswith("H: Handlers=") and " kbd" in " " + line:
            for h in line.split("=", 1)[1].split():
                if h.startswith("event"):
                    found.append(("/dev/input/" + h, name))
    return found


def release(fd, keys):
    t = time.time()
    sec, usec = int(t), int((t % 1) * 1e6)
    for k in sorted(keys):
        os.write(fd, struct.pack(FMT, sec, usec, EV_KEY, k, 0))
    os.write(fd, struct.pack(FMT, sec, usec, EV_SYN, SYN_REPORT, 0))


def main():
    devs = {}       # fd -> {"path", "name", "down": {taste: zeit}, "act": zeit der letzten anderen Taste}
    last_scan = 0
    while True:
        now = time.time()
        if now - last_scan > 10:                # neue Tastaturen (z. B. nach UTM-Neustart) aufnehmen
            last_scan = now
            known = {d["path"] for d in devs.values()}
            for path, name in keyboards():
                if path in known:
                    continue
                try:
                    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
                except OSError as e:
                    log(f"{path} ({name}) nicht nutzbar: {e}")
                    continue
                devs[fd] = {"path": path, "name": name, "down": {}, "act": now}
                log(f"überwache {path} ({name})")
        if not devs:
            time.sleep(2)
            continue
        ready, _, _ = select.select(list(devs), [], [], 0.5)
        for fd in ready:
            d = devs[fd]
            try:
                data = os.read(fd, SIZE * 64)
            except BlockingIOError:
                continue
            except OSError:                     # Gerät verschwunden
                os.close(fd)
                del devs[fd]
                continue
            now = time.time()
            for i in range(0, len(data) - SIZE + 1, SIZE):
                _, _, typ, code, val = struct.unpack(FMT, data[i:i + SIZE])
                if typ != EV_KEY or val == 2:   # Wiederholungen zählen nicht als Aktivität
                    continue
                down = d["down"]
                if code not in MODS:
                    d["act"] = now
                    continue
                if val == 1:
                    down[code] = now
                else:
                    down.pop(code, None)
                keys = set(down)
                if val == 1 and ((keys & CTRL and keys & ALT) or keys & META):
                    free(fd, d, keys, "Freigabe-Kombination")
        now = time.time()
        for fd, d in list(devs.items()):        # Regel 2: hängende Ctrl/Alt/Cmd
            stale = {k for k, t in d["down"].items()
                     if k not in SHIFT and now - max(t, d["act"]) > STALE}
            if stale:
                free(fd, d, stale, f"länger als {STALE:g} s ohne andere Taste")


def free(fd, d, keys, why):
    try:
        release(fd, keys)
        log(f"losgelassen ({why}): {sorted(keys)} auf {d['path']}")
    except OSError as e:
        log(f"Loslassen fehlgeschlagen auf {d['path']}: {e}")
    for k in keys:
        d["down"].pop(k, None)


if __name__ == "__main__":
    if os.geteuid() != 0:
        sys.exit("wow-tastenwaechter muss als root laufen")
    main()
PY
chmod 755 /usr/local/sbin/wow-tastenwaechter.neu && mv -f /usr/local/sbin/wow-tastenwaechter.neu /usr/local/sbin/wow-tastenwaechter
cat > /etc/systemd/system/wow-tastenwaechter.service <<'U'
[Unit]
Description=WoW-Mac: haengende Sondertasten nach dem Verlassen der VM loesen
After=systemd-udev-settle.service

[Service]
ExecStart=/usr/local/sbin/wow-tastenwaechter
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable wow-tastenwaechter >/dev/null 2>&1
systemctl restart wow-tastenwaechter
sleep 2
echo "Tastenwächter: $(systemctl is-active wow-tastenwaechter)"
journalctl -u wow-tastenwaechter -n 5 --no-pager -o cat
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
sleep 8
osascript - "$VM" <<'OSA'
on run argv
  tell application "UTM"
    set f to open file of virtual machine named (item 1 of argv) at "/tmp/wow-tasten.txt" for reading
    return read f
  end tell
end run
OSA
