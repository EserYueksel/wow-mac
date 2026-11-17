# WoW 3.3.5a auf Linux Mint – Installationsanleitung

Diese Anleitung macht **World of Warcraft 3.3.5a** (Wrath of the Lich King) auf einem Linux-Rechner mit Intel- oder AMD-Prozessor spielbar: mit Wine und DXVK, ohne Lutris, ohne PlayOnLinux, mit Menüeintrag und Desktop-Verknüpfung.

Auf Linux geht das ohne Umweg: Der Prozessor ist x86 wie bei Windows, Wine führt `Wow.exe` direkt aus. Den Absturz #132 nach dem Login, den es auf Macs mit Apple-Chip gibt, gibt es hier nicht. (Für Macs: siehe [README im Hauptordner](../README.md).)

**Getestet** mit Linux Mint 22.3 (Cinnamon, X11) auf
- Lenovo IdeaPad mit Intel Iris Xe + NVIDIA GeForce MX450 (Optimus, Treiber 595, Secure Boot an) – läuft
- Razer Blade 15 mit Intel UHD + NVIDIA RTX 3070 Laptop (Optimus) – offene Welt ca. 98 FPS, Dalaran 84–110 FPS bei 2560×1440

Mit AMD- oder reiner Intel-Grafik sollte es ebenso gehen (Mesa-Treiber), das ist aber noch nicht auf echter Hardware getestet.

---

## Voraussetzungen

| | |
|---|---|
| System | Linux Mint 22.x oder Ubuntu 24.04 (64 Bit). Andere Debian-Abkömmlinge vermutlich auch. |
| Prozessor | Intel oder AMD (x86-64) |
| Grafik | NVIDIA (mit Treiber aus der Treiberverwaltung), AMD oder Intel |
| Sitzung | X11 (bei Linux Mint Cinnamon Standard) |
| Speicher | ca. 20 GB für den Spielordner + 1 GB für Wine |
| Spiel | ein eigener, vollständiger WoW-3.3.5a-Ordner (mit `Wow.exe` und `Data/`). Es werden keine Spieldateien mitgeliefert. |

Alle Befehle unten gibst du im **Terminal** ein (Menü → Terminal, oder Strg+Alt+T). Zum Einfügen im Terminal: **Strg+Umschalt+V**.

---

## Schritt 1 – Grafiktreiber prüfen (nur bei NVIDIA)

Hast du AMD- oder Intel-Grafik, überspringe diesen Schritt.

Prüfe, ob der NVIDIA-Treiber läuft:

```bash
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
```

**Kommt der Name deiner Karte heraus** (z. B. `NVIDIA GeForce MX450, 595.99.02`) → weiter mit Schritt 2.

**Kommt „command not found“** → es ist kein Treiber installiert: Menü → **Treiberverwaltung** → den empfohlenen NVIDIA-Treiber wählen → **Änderungen anwenden** → neu starten → erneut prüfen.

**Kommt „NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver“** → der Treiber ist installiert, darf aber nicht laden. Fast immer liegt das an **Secure Boot**: Der Schlüssel des Treibers wurde bei der Installation nie bestätigt. Prüfen:

```bash
mokutil --sb-state; mokutil --test-key /var/lib/shim-signed/mok/MOK.der
```

Steht dort `SecureBoot enabled` und `… is not enrolled`, bestätige den Schlüssel so (Secure Boot bleibt an):

1. Schlüssel vormerken:
   ```bash
   sudo mokutil --import /var/lib/shim-signed/mok/MOK.der
   ```
   Zuerst fragt `sudo` nach deinem normalen Passwort. Dann fragt `mokutil` zweimal nach einem **neuen Einmal-Passwort**, das du dir ausdenkst.
   **Wichtig:** Auf dem blauen Bildschirm gleich gilt die **US-Tastatur**. Nimm nur Kleinbuchstaben **ohne y und z** und Ziffern, z. B. `wow2026`.
2. **Neu starten.** Vor Linux erscheint ein blauer Bildschirm „Perform MOK management“. Er wartet nur ca. 10 Sekunden – **sofort eine Taste drücken**.
3. **Enroll MOK** → **Continue** → **Yes** → Einmal-Passwort eingeben → **Reboot**.
4. Nach dem Neustart erneut `nvidia-smi --query-gpu=name,driver_version --format=csv,noheader` – jetzt sollte die Karte erscheinen.

Verpasst? Einfach Punkt 1 wiederholen und neu starten.

---

## Schritt 2 – WoW-Ordner auf den Rechner kopieren und prüfen

Kopiere deinen WoW-Ordner in deinen Persönlichen Ordner, am besten nach **Dokumente** (`~/Documents`). Ob von USB-Stick, externer Festplatte oder Netzwerk ist egal.

**Danach prüfen, ob die Kopie vollständig ist** – ein abgebrochener Kopiervorgang ist der häufigste Fehler (Meldung im Spiel: „Failed to open archive common.MPQ“):

```bash
ls -la ~/Documents/*/Data/*.[Mm][Pp][Qq]
```

So sollte es bei 3.3.5a aussehen (Größen in Bytes):

| Datei | Größe |
|---|---|
| `common.MPQ` | 2 884 765 590 |
| `common-2.MPQ` | 1 814 307 386 |
| `expansion.MPQ` | 1 923 425 368 |
| `lichking.MPQ` | 2 581 185 567 |
| `patch.MPQ`, `patch-2.MPQ`, `patch-3.MPQ` … | je nach Server unterschiedlich |

Ist eine dieser Dateien kleiner, oder liegen Dateien mit **„(2)“** im Namen daneben (z. B. `common (2).mpq`), ist beim Kopieren etwas schiefgegangen → siehe [Häufige Probleme](#failed-to-open-archive-commonmpq).

---

## Schritt 3 – Installer ausführen

Eine Zeile – den Pfad am Ende an deinen Ordner anpassen:

```bash
curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/linux/install.sh | bash -s -- ~/Documents/WoW_3.3.5a
```

Lässt du den Pfad weg, sucht der Installer den Ordner mit `Wow.exe` selbst.

Alternativ erst herunterladen und dann starten:

```bash
curl -fsSL -o ~/Downloads/wow-install.sh https://raw.githubusercontent.com/EserYueksel/wow-mac/main/linux/install.sh
bash ~/Downloads/wow-install.sh ~/Documents/WoW_3.3.5a
```

- **Nicht** mit `sudo` starten – der Installer fragt selbst einmal nach deinem Passwort (beim Tippen siehst du keine Zeichen, das ist normal).
- Dauer: ca. 3–10 Minuten, je nach Internet.
- Am Ende steht `== Fertig ==`. Zeilen mit `HINWEIS:` bitte lesen – sie sagen, was nicht ganz gepasst hat.
- Protokoll: `~/wow-setup.log`

### Was der Installer macht

1. **Prüfen:** WoW-Ordner, Schreibrechte, freier Platz, unvollständige Kopie, Grafikkarte, NVIDIA-Treiber (bei Secure-Boot-Problem zeigt er die Schritte aus Schritt 1).
2. **Pakete** aus den Paketquellen deiner Distribution: `wine` (32 + 64 Bit), `winetricks`, Vulkan-Bibliotheken (auch 32 Bit), `icoutils`; bei NVIDIA den passenden 32-Bit-Teil `libnvidia-gl-<Version>:i386`.
3. **Vulkan-Test:** zeigt, ob die richtige Grafikkarte gefunden wird.
4. **Wine-Umgebung** `~/.wine-wow`: 32 Bit, Windows 7, Tastatur wie im System (sonst kommen ä ö ü im Chat nicht an).
5. **DXVK 2.7.1** (Direct3D 9 über Vulkan) vom offiziellen Release, mit Prüfsumme. Bewusst nicht die neueste 3.x – die läuft mit dem Wine 9 aus Ubuntu 24.04 nicht („No adapters found“).
6. **Einstellungen:** sichert zuerst den Ordner `WTF` (als `WTF_Backup_Linux_<Datum>`), stellt dann in `WTF/Config.wtf` nur Grafik ein: Direct3D 9, Auflösung des Bildschirms, VSync aus, FPS-Grenze 120 (15 im Hintergrund), Sprachchat aus.
7. **Starter** `~/bin/wow-starten.sh`, **Menüeintrag** (Spiele → World of Warcraft 3.3.5a) und **Desktop-Verknüpfung**, jeweils mit dem Symbol aus `Wow.exe`. Bei Laptops mit zwei Grafikkarten (Optimus) startet der Starter WoW auf der NVIDIA-Karte; der Desktop bleibt auf der sparsamen Intel-Grafik.

An `Wow.exe`, `Data/`, `Interface/` (AddOns) und `WTF/Account` ändert der Installer nichts. Gelöscht wird nichts.

Ohne Desktop-Verknüpfung: `WOW_DESKTOP=0` vor `bash` setzen.

---

## Schritt 4 – Spielen

- **Doppelklick** auf „World of Warcraft 3.3.5a“ auf dem Desktop, oder Menü → **Spiele** → **World of Warcraft 3.3.5a**.
  Fragt Mint beim ersten Mal, ob es der Verknüpfung vertrauen soll: **Vertrauen und starten**.
- Der erste Start dauert etwas länger (DXVK bereitet die Grafik vor), danach geht es schneller.
- **FPS anzeigen:** im Chat `/run print(GetFramerate())` eintippen.
- **Fenster/Vollbild:** wie unter Windows im Grafikmenü des Spiels. Das Fenster lässt sich frei ziehen.
- **Beenden:** im Spiel Esc → Spiel beenden.

---

## Häufige Probleme

### „Failed to open archive common.MPQ“
Die Datei `Data/common.MPQ` ist unvollständig oder fehlt – fast immer ein abgebrochener Kopiervorgang. Prüfe die Größen wie in [Schritt 2](#schritt-2--wow-ordner-auf-den-rechner-kopieren-und-prüfen).
- Liegt daneben eine vollständige Fassung mit „(2)“ im Namen (z. B. `common (2).mpq` in der richtigen Größe), hat der Dateimanager beim zweiten Kopieren „beide behalten“ gewählt. Die zu kleine Datei beiseitelegen und die vollständige umbenennen:
  ```bash
  cd ~/Documents/WoW_3.3.5a/Data && mkdir -p ~/WoW_Reste && mv common.MPQ ~/WoW_Reste/ && mv "common (2).mpq" common.MPQ
  ```
  (Für andere Dateien entsprechend. `~/WoW_Reste` kannst du löschen, wenn das Spiel läuft.)
- Sonst die betroffene Datei noch einmal vom Original kopieren.

### WoW läuft langsam / nutzt die falsche Grafikkarte
Bei Laptops mit Intel + NVIDIA: Schritt 1 prüfen (`nvidia-smi` muss die Karte zeigen) und in den NVIDIA-Einstellungen (Systemleiste) **On-Demand** oder **NVIDIA (Performance)** wählen, nicht „Intel (Power Saving)“. Den Installer danach noch einmal laufen lassen.

### Umlaute (ä ö ü ß) gehen im Chat nicht
Der Installer übernimmt das Tastaturlayout des Systems. Wurde es danach geändert, den Installer erneut laufen lassen – oder für Deutsch:
```bash
WINEPREFIX=~/.wine-wow wine reg add 'HKCU\Keyboard Layout\Preload' /v 1 /t REG_SZ /d 00000407 /f
```

### Spiel hängt beim Beenden
```bash
WINEPREFIX=~/.wine-wow wineserver -k
```

### Kamera springt / Maus dreht durch
Bei der Anmeldung (Zahnrad am Anmeldebildschirm) eine **X11**-Sitzung wählen, nicht Wayland.

### Es geht trotzdem nicht
Installer einfach noch einmal laufen lassen – er ist dafür gemacht und überschreibt nur seine eigenen Teile. Hilft das nicht: `~/wow-setup.log`, `tail -50 ~/wow-wine.log` und die neueste Datei in `Errors/` im WoW-Ordner ansehen bzw. in einem Issue anhängen (vorher Kontonamen entfernen).

---

## Aktualisieren

Installer erneut ausführen (Schritt 3). Einstellungen werden vorher wieder gesichert.

## Deinstallation

```bash
curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/linux/uninstall.sh | bash
```

Entfernt Starter, Menüeintrag, Desktop-Verknüpfung und Symbol und fragt, ob die Wine-Umgebung `~/.wine-wow` (ca. 600 MB, keine Spieldaten) gelöscht werden soll. **Der WoW-Ordner bleibt unverändert.** Die Pakete (Wine usw.) bleiben installiert; die Zeile zum Entfernen zeigt das Skript am Ende an.

---

## Fair Play

Der Installer verändert das Spiel nicht: keine Patches an `Wow.exe`, keine Cheats, keine Bots, keine Eingriffe in den Speicher. Wine und DXVK sind dieselben Werkzeuge, die z. B. auch Steam (Proton) verwendet. Ob ein Server Linux-Spieler erlaubt, regelt der jeweilige Server.

## Technik (für Neugierige)

| Problem | Lösung |
|---|---|
| DXVK 3.x: `dxvk::DxvkError`, „No adapters found“ mit Wine 9.0 | DXVK 2.7.1 (x32-DLLs nach `system32`, Overrides `native`) |
| NVIDIA-Treiber lädt nicht, `nvidia-smi` ohne Verbindung | Secure Boot: DKMS-Schlüssel per `mokutil --import` bestätigen |
| WoW läuft auf der Intel-Grafik | `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only DXVK_FILTER_DEVICE_NAME=NVIDIA` |
| 32-Bit-Spiel findet die NVIDIA-Grafik nicht | `libnvidia-gl-<Treiberversion>:i386` (muss genau zur Treiberversion passen) |
| Umlaute fehlen im Chat | Prefix-Tastatur auf das System-Layout (`HKCU\Keyboard Layout\Preload`) |
| `gamemoderun` erzeugt Fehlermeldungen | weggelassen (32-Bit-Bibliothek fehlt) |
