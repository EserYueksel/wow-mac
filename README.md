# WoW-Mac – World of Warcraft 3.3.5a auf dem Mac mit Apple-Chip

Ein Installer, der **World of Warcraft 3.3.5a** (WotLK, Client 12340, getestet auf einem 3.3.5a-Server mit Warden) auf Macs mit Apple-Chip spielbar macht – **ohne CrossOver, ohne Streaming, kostenlos**. Er richtet alles automatisch ein und lässt sich genauso sauber wieder entfernen.

> **Wichtig:** Die Spieldateien sind **nicht** enthalten. Du brauchst deinen eigenen WoW-3.3.5a-Ordner (mit `Wow.exe` und `Data/`).

---

## Warum eine Linux-VM?

Unter macOS laufen Windows-Spiele über Wine und **Rosetta 2**. Rosetta kann aber einen alten x86-Befehl (`ARPL`) nicht ausführen, den das Anti-Cheat-Modul (Warden) vieler 3.3.5a-Server beim Einloggen benutzt. Die Folge: Absturz mit Fehler **#132** direkt nach dem Login – egal ob CrossOver, Whisky oder Wine.

Der x86-Übersetzer **FEX** führt `ARPL` korrekt aus, läuft aber nur unter Linux. WoW-Mac baut deshalb diese Kette auf:

```
Mac  ──►  UTM (QEMU, Hypervisor)  ──►  Ubuntu 26.04 (arm64)  ──►  Hangover: Wine 11 + FEX  ──►  Wow.exe
                     │                                                         │
                     └── 3D über virgl → Apple Core OpenGL                     └── Spielordner vom Mac (VirtFS)
```

---

## Voraussetzungen

| | |
|---|---|
| Mac | Apple-Chip (M1 oder neuer) |
| macOS | 13 oder neuer (getestet: macOS 27 auf MacBook Air M4) |
| Arbeitsspeicher | 16 GB empfohlen, 8 GB geht |
| Speicher | ca. 20 GB frei |
| Internet | ca. 1,5 GB Download während der Einrichtung |
| Spiel | eigener WoW-3.3.5a-Ordner (Client 12340) |

Passwörter werden nicht abgefragt, Homebrew wird nicht gebraucht.

---

## Installation

### Variante A – eine Zeile im Terminal (empfohlen)

Terminal öffnen (Programme → Dienstprogramme → Terminal), diese Zeile einfügen und Enter drücken:

```bash
curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/install.sh | bash
```

Die Zeile lädt den Installer, baut daraus die App **„WoW-Mac Installer“** und öffnet sie. Weil die App auf deinem Mac gebaut wird, gibt es keine Gatekeeper-Rückfrage.

### Variante B – App herunterladen

Unter **Releases** die Datei `WoW-Mac-Installer.zip` laden, entpacken und öffnen. Da die App nicht mit einer kostenpflichtigen Apple-Entwickler-ID beglaubigt ist, blockiert macOS sie beim ersten Mal: dann **Systemeinstellungen → Datenschutz & Sicherheit → „Dennoch öffnen“** klicken. (Gatekeeper bleibt dabei für alles andere an.)

### Was der Installer fragt

1. deinen **WoW-Ordner** (wird geprüft: `Wow.exe`, `Data/`, nicht nur halb aus iCloud geladen)
2. ob der Ordner **bleiben oder verschoben** werden soll
3. den **Namen der Start-App** (Standard: „WoW 3.3.5a“) und ob sie ins Dock soll

Danach läuft alles allein (20–40 Minuten), mit Fortschrittsanzeige. Der Mac bleibt dabei wach. Bricht etwas ab, einfach den Installer erneut starten – **er setzt dort fort**.

### Was installiert wird

| Teil | Version | Quelle | Prüfung |
|---|---|---|---|
| UTM (nur falls nicht vorhanden) | 5.0.8 | github.com/utmapp/UTM | SHA-256 + Apple-Signatur (Team WDNLXAD4W8) |
| Ubuntu Cloud-Image arm64 | 26.04 (release-20261016) | cloud-images.ubuntu.com | SHA-256 |
| Hangover (Wine 11 + FEX) | 11.16 | github.com/AndreRH/hangover | SHA-256 |
| Ubuntu-Pakete (Xfce, Mesa, PipeWire …) | aktuell | Ubuntu-Archiv | apt-Signaturen |
| Start-App, Deinstallations-App | – | lokal gebaut | – |

Die Linux-VM liegt in UTM (`WoW-Linux`), die Platte wächst nur bei Bedarf (typisch 10–12 GB). Nach der Einrichtung legt der Installer in UTM den Schnappschuss **„Frisch installiert“** an, falls deine UTM-Version das per Skript erlaubt.

---

### Einmalig in UTM einschalten

macOS schützt die Einstellungen anderer Apps, deshalb kann der Installer diese zwei Dinge nicht selbst setzen (er zeigt am Ende einen Hinweis):

1. **UTM → Einstellungen → Eingabe (Input):** „Capture input automatically when entering full screen“ und „Capture input automatically when window is focused“ einschalten. Ohne das dreht sich die Kamera im Spiel beim Klicken wild im Kreis.
2. **Empfohlen bei sehr großen Monitoren:** UTM → Einstellungen → Display → *Renderer Backend*: „Apple Core OpenGL“ – bei 5120×1440 etwa 50 % mehr FPS als die Standardeinstellung.

## Erster Start

Starte WoW über die App im Dock. Beim ersten Mal fragt macOS:

- ob die App **UTM** und **System Events** steuern darf → **Erlauben**
- für das automatische Vollbild: **Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen** → die Start-App einschalten (ohne Freigabe läuft WoW im Fenster – das geht auch)

Dann bootet die VM (ca. 30 Sekunden), schaltet ins Vollbild und WoW startet. Einmal ins Spiel klicken, damit die Maus „gefangen“ wird – dann Login und Spielen wie gewohnt.

## Bedienung

| | |
|---|---|
| Starten | Start-App im Dock |
| Maus fangen / freigeben | ins Spiel klicken / **Ctrl + Option** |
| Beenden | im Spiel **Esc → Spiel beenden** (nicht das UTM-Fenster schließen) |
| Monitor oder Laptop | die Auflösung passt sich beim Start automatisch an |
| Tastatur | wird vom Mac übernommen (z. B. deutsche Mac-Tastatur: ä ö ü ß @ € [ ] mit Wahltaste) |
| AddOns | wie immer in `Interface/AddOns` im WoW-Ordner |

## Leistung (gemessen, MacBook Air M4)

| Auflösung | Ort | FPS |
|---|---|---|
| 1280×800 | Dalaran | ca. 69 |
| 5120×1440 (Ultrawide) | Dalaran | ca. 36 |
| 5120×1440 (Ultrawide) | offene Welt | ca. 24–32 |

Sehr hohe Auflösungen kosten viel, weil jedes Bild durch die VM muss. Spürbar hilft: **Sichtweite**, **Bodenbewuchs** und **Umgebungsdetails** im Grafikmenü etwas herunterzunehmen.

---

## Häufige Probleme

1. **Standbild direkt nach dem Start** – passiert, wenn während des Starts zwischen Fenster und Vollbild gewechselt wurde. Start-App erneut öffnen; hilft das nicht: in UTM die VM stoppen und die App erneut starten.
2. **WoW schließt sich, wenn im Grafikmenü „Fenstermodus“ oder „Maximiert“ umgeschaltet wird** – diese beiden Einstellungen nicht anfassen; die Start-App setzt sie bei jedem Start richtig.
3. **Kein Ton** – Mac-Lautstärke prüfen; die VM gibt den Ton direkt über CoreAudio aus. Sonst VM neu starten.
4. **Maus gefangen** – **Ctrl + Option** drückt sie frei.
5. **Gelegentliche Abstürze** – in der VM in `~/.config/wow-mac.conf` die Zeile `FEX_TSOENABLED=1` eintragen (stabiler, aber deutlich langsamer).
6. **Irgendetwas ist kaputt** – Installer erneut öffnen → **„Reparieren“**. Das wiederholt die Einrichtung in der VM; Spielstand und Einstellungen bleiben.

Protokolle liegen in `~/Library/Logs/WoW-Mac/`.

## Deinstallation

App **„WoW-Mac deinstallieren“** öffnen (in deinem Benutzerordner unter *Programme*). Sie entfernt die VM, die Start-App samt Dock-Eintrag, die geänderten UTM-Einstellungen und alle Hilfsdateien. UTM selbst wird nur auf Wunsch entfernt – und nur, wenn der Installer es eingerichtet hat und keine anderen VMs mehr darin sind. **Der WoW-Ordner bleibt unverändert**; auf Wunsch wird `WTF/Config.wtf` auf den Stand vor der Installation zurückgesetzt.

Im Terminal geht es auch:

```bash
bash ~/Library/Application\ Support/WoW-Mac/app/installer/wowmac.sh uninstall
```

---

## Fair Play

WoW-Mac verändert **keine** Spieldateien und keine `Wow.exe`, injiziert nichts und automatisiert nichts. Geändert werden nur Grafikwerte in `WTF/Config.wtf` (`gxApi`, `gxResolution`, `gxWindow`, `gxMaximize`, `gxVSync`); vorher wird `WTF/Config.wtf.vor-wowmac` gesichert. Halte dich an die Regeln deines Servers.

## Technik (für Neugierige)

Diese Stolpersteine löst der Installer automatisch:

| Problem | Lösung |
|---|---|
| Rosetta 2 kann `ARPL` nicht (#132 beim Login) | FEX in Linux statt Rosetta in macOS |
| Wine 11 füllt bei OpenGL < 3.0 die Erweiterungstabelle falsch → Standbild in der Welt | `MESA_GL_VERSION_OVERRIDE=3.0COMPAT` |
| 3 FPS | `FEX_X87REDUCEDPRECISION=1`, `FEX_TSOENABLED=0`, `FEX_MULTIBLOCK=1` |
| Bildrate rastet bei 30/40/60 ein | `vblank_mode=0`, `gxVSync 0` |
| DXVK/Vulkan stürzt in der VM ab | WoW im OpenGL-Modus über virgl, Renderer „Apple Core OpenGL“ |
| Ton bricht weg (SPICE) | Ton direkt über CoreAudio (`-audiodev coreaudio`) |
| Maus dreht durch (Tablet-Modus) | UTM fängt die Maus automatisch (relativ) |
| virtio-gpu verpasst beim Vollbild-Wechsel einen vblank | Start-Skript erkennt das und startet die Oberfläche neu |
| Sperrbildschirm in der VM | entfernt (der VM-Benutzer hat kein Passwort) |

Aufbau des Repos:

```
install.sh                    Einstieg per Terminal-Zeile
installer/wowmac.sh           eigentlicher Installer (install, repair, uninstall, status)
installer/lib/                gemeinsame Funktionen, qcow2-Vergrößerung ohne qemu-img
installer/guest/              läuft in der VM: cloud-init-Vorlage, Einrichtung, Start-Skripte
installer/apps/               AppleScript-Vorlagen für Installer, Start-App, Deinstallation
```

## Lizenz und Hinweise

Der Code in diesem Repository steht unter der MIT-Lizenz (siehe `LICENSE`). Während der Installation werden fremde Programme von ihren offiziellen Quellen geladen; es gelten deren Lizenzen: UTM (Apache-2.0), QEMU (GPL-2.0), Ubuntu, Wine (LGPL-2.1), FEX (MIT), Hangover.

*World of Warcraft* ist eine Marke von Blizzard Entertainment. Dieses Projekt steht in keiner Verbindung zu Blizzard Entertainment oder zu einem Server.

---

## English summary

WoW-Mac makes **World of Warcraft 3.3.5a** playable on Apple Silicon Macs without CrossOver or streaming. Rosetta 2 cannot execute the `ARPL` instruction used by the Warden anti-cheat of many 3.3.5a servers (crash #132 at login), so the installer sets up a small Ubuntu VM in UTM and runs the game with Hangover (Wine 11 + FEX), which handles `ARPL` correctly. Install with:

```bash
curl -fsSL https://raw.githubusercontent.com/EserYueksel/wow-mac/main/install.sh | bash
```

You need your own WoW 3.3.5a folder; no game files are included. Uninstall with the bundled “WoW-Mac deinstallieren” app – your game folder is never modified (apart from graphics keys in `WTF/Config.wtf`, which are backed up first).
