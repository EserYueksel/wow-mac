#!/usr/bin/env python3
# Ausführliche Anleitung "WoW 3.3.5a auf Linux Mint" als PDF (reportlab, DejaVu für Umlaute und Pfeile)
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                KeepTogether, PageBreak)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping

F = "/usr/share/fonts/truetype/dejavu/"
pdfmetrics.registerFont(TTFont("DV", F + "DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("DVB", F + "DejaVuSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("DVI", F + "DejaVuSans-Oblique.ttf"))
pdfmetrics.registerFont(TTFont("DVM", F + "DejaVuSansMono.ttf"))
addMapping("DV", 0, 0, "DV"); addMapping("DV", 1, 0, "DVB"); addMapping("DV", 0, 1, "DVI"); addMapping("DV", 1, 1, "DVB")

INK = colors.HexColor("#1d2330"); MUTED = colors.HexColor("#5b6475")
ACC = colors.HexColor("#2f7a4f"); LINE = colors.HexColor("#d9dee7"); SOFT = colors.HexColor("#f2f5f9")
WARN = colors.HexColor("#fff6e0"); OK = colors.HexColor("#eaf6ee"); CODEBG = colors.HexColor("#1f2430")

st = {
 "title": ParagraphStyle("title", fontName="DVB", fontSize=22, leading=27, textColor=INK, spaceAfter=4),
 "sub": ParagraphStyle("sub", fontName="DV", fontSize=10, leading=14, textColor=MUTED, spaceAfter=12),
 "h1": ParagraphStyle("h1", fontName="DVB", fontSize=15, leading=19, textColor=ACC, spaceBefore=10, spaceAfter=5, keepWithNext=1),
 "h2": ParagraphStyle("h2", fontName="DVB", fontSize=11.5, leading=15, textColor=INK, spaceBefore=7, spaceAfter=3, keepWithNext=1),
 "p": ParagraphStyle("p", fontName="DV", fontSize=9.6, leading=13.4, textColor=INK, spaceAfter=4),
 "li": ParagraphStyle("li", fontName="DV", fontSize=9.6, leading=13.4, textColor=INK, leftIndent=14, bulletIndent=3, spaceAfter=2),
 "cell": ParagraphStyle("cell", fontName="DV", fontSize=8.8, leading=11.6, textColor=INK),
 "cellb": ParagraphStyle("cellb", fontName="DVB", fontSize=8.8, leading=11.6, textColor=INK),
 "code": ParagraphStyle("code", fontName="DVM", fontSize=8.4, leading=11.2, textColor=colors.white),
 "out": ParagraphStyle("out", fontName="DVM", fontSize=8.2, leading=10.8, textColor=INK),
 "foot": ParagraphStyle("foot", fontName="DV", fontSize=7.5, leading=10, textColor=MUTED),
}
W = 170 * mm

def P(t, s="p"): return Paragraph(t, st[s])
def bullets(items): return [Paragraph(i, st["li"], bulletText="•") for i in items]
def steps(items, start=1): return [Paragraph(i, st["li"], bulletText=f"{n}.") for n, i in enumerate(items, start)]
def esc(t): return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def box(flow, bg, border=LINE, pad=7):
    t = Table([[flow]], colWidths=[W], hAlign="LEFT")
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), bg), ("BOX", (0, 0), (-1, -1), 0.5, border),
                           ("LEFTPADDING", (0, 0), (-1, -1), pad), ("RIGHTPADDING", (0, 0), (-1, -1), pad),
                           ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
    return t

def code(text):
    """Befehl zum Abtippen/Einfügen: dunkler Kasten. Der Absatz davor bleibt mit dem Kasten auf einer Seite."""
    lines = "<br/>".join(esc(l).replace(" ", "&nbsp;") if l.startswith(" ") else esc(l) for l in text.strip("\n").split("\n"))
    k = box(Paragraph(lines, st["code"]), CODEBG, CODEBG)
    if s and isinstance(s[-1], Paragraph):
        grp = [s.pop()]
        if s and isinstance(s[-1], Paragraph) and s[-1].style.name in ("h1", "h2"):
            grp.insert(0, s.pop())          # Überschrift nicht allein am Seitenende stehen lassen
        return [KeepTogether(grp + [Spacer(1, 2), k]), Spacer(1, 5)]
    return [Spacer(1, 2), k, Spacer(1, 5)]

def out(text):
    """So sieht die Ausgabe aus: heller Kasten."""
    lines = "<br/>".join(esc(l) for l in text.strip("\n").split("\n"))
    return [box(Paragraph(lines, st["out"]), SOFT), Spacer(1, 5)]

def note(text, bg=WARN): return [box(Paragraph(text, st["cell"]), bg), Spacer(1, 6)]

def table(rows, widths, head=True):
    data = [[Paragraph(c, st["cellb" if (head and r == 0) else "cell"]) for c in row] for r, row in enumerate(rows)]
    t = Table(data, colWidths=widths, hAlign="LEFT", repeatRows=1 if head else 0)
    style = [("GRID", (0, 0), (-1, -1), 0.4, LINE), ("VALIGN", (0, 0), (-1, -1), "TOP"),
             ("LEFTPADDING", (0, 0), (-1, -1), 5), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
             ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3)]
    if head: style.append(("BACKGROUND", (0, 0), (-1, 0), SOFT))
    t.setStyle(TableStyle(style)); return [t, Spacer(1, 6)]

REPO = "https://raw.githubusercontent.com/EserYueksel/wow-mac/main/linux"
s = []

# ---------------------------------------------------------------- Titel
s.append(P("World of Warcraft 3.3.5a auf Linux Mint", "title"))
s.append(P("Ausführliche Schritt-für-Schritt-Anleitung · für Einsteiger · Linux Mint 22 / Ubuntu 24.04 · Installer-Version 1.0.0 · Stand November 2026", "sub"))
s.append(P("Diese Anleitung führt dich vom fertigen Linux-Rechner bis ins Spiel. Du musst nichts über Linux wissen: Jeder Befehl steht "
           "vollständig da, du kopierst ihn nur ins Terminal. Zu jedem Schritt steht, was du sehen solltest und was zu tun ist, wenn nicht."))
s.append(P("Das Ergebnis", "h2"))
s += bullets([
 "WoW 3.3.5a startet per <b>Doppelklick auf dem Desktop</b> oder über das Startmenü (Spiele → World of Warcraft 3.3.5a).",
 "Es läuft über <b>Wine</b> (führt Windows-Programme unter Linux aus) und <b>DXVK</b> (übersetzt die Windows-Grafik in Vulkan). "
 "Beides ist kostenlos, quelloffen und wird auch von Steam (Proton) verwendet.",
 "Umlaute im Chat, Ton, AddOns und deine Einstellungen funktionieren wie unter Windows.",
 "Am Spiel selbst wird nichts verändert: keine Patches, keine Cheats, kein Eingriff in <font name='DVM'>Wow.exe</font>.",
])
s.append(P("Gemessen", "h2"))
s += table([
 ["Rechner", "Grafik", "Auflösung", "Dalaran", "Offene Welt"],
 ["Lenovo IdeaPad (Linux Mint 22.3)", "NVIDIA GeForce MX450 + Intel Iris Xe", "1920×1080", "93–124 FPS", "–"],
 ["Razer Blade 15 (Linux Mint 22.3)", "NVIDIA RTX 3070 Laptop + Intel UHD", "2560×1440", "84–110 FPS", "ca. 98 FPS"],
], [52 * mm, 50 * mm, 22 * mm, 22 * mm, 24 * mm])

s.append(P("Was du brauchst", "h1"))
s += table([
 ["Rechner", "Laptop oder PC mit Intel- oder AMD-Prozessor (64 Bit)", "Macs mit Apple-Chip: eigener Installer, siehe README im Hauptordner"],
 ["System", "Linux Mint 22.x (Cinnamon, Xfce oder MATE) oder Ubuntu 24.04", "andere Distributionen mit apt vermutlich auch, nicht getestet"],
 ["Grafik", "NVIDIA, AMD oder Intel", "getestet sind NVIDIA-Laptops; AMD/Intel sollten gehen"],
 ["Speicherplatz", "ca. 20 GB für den Spielordner, ca. 1 GB für Wine", ""],
 ["Internet", "für den Download von Wine und DXVK (ca. 300–500 MB)", ""],
 ["Spiel", "dein eigener, <b>vollständiger</b> WoW-3.3.5a-Ordner mit <font name='DVM'>Wow.exe</font> und dem Ordner <font name='DVM'>Data</font>",
  "Spieldateien werden nicht mitgeliefert"],
 ["Passwort", "dein Linux-Anmeldepasswort", "für die Installation von Wine"],
], [28 * mm, 82 * mm, 60 * mm], head=False)

s.append(P("Ablauf auf einen Blick", "h2"))
s += table([
 ["Schritt", "Was passiert", "Dauer"],
 ["0", "Terminal kennenlernen: Befehle einfügen und Ausgaben lesen", "2 Min."],
 ["1", "Grafikkarte prüfen, bei NVIDIA den Treiber startklar machen (evtl. Secure Boot)", "5–15 Min."],
 ["2", "WoW-Ordner nach „Dokumente“ kopieren und auf Vollständigkeit prüfen", "10–30 Min."],
 ["3", "Installer ausführen (eine Zeile)", "3–10 Min."],
 ["4", "Spielen", "–"],
], [18 * mm, 128 * mm, 24 * mm])

# ---------------------------------------------------------------- Schritt 0
s.append(P("Schritt 0 – Das Terminal", "h1"))
s.append(P("Das Terminal ist ein Fenster, in das man Befehle als Text eingibt. Für diese Anleitung brauchst du nur drei Dinge:"))
s += steps([
 "<b>Öffnen:</b> Tastenkombination <b>Strg + Alt + T</b>, oder Startmenü → „Terminal“ eintippen → Enter.",
 "<b>Befehl einfügen:</b> Befehl aus dieser Anleitung markieren und kopieren (Strg + C), im Terminal mit "
 "<b>Strg + Umschalt + V</b> einfügen (nicht Strg + V!) oder Rechtsklick → Einfügen. Dann <b>Enter</b> drücken.",
 "<b>Warten, bis der Befehl fertig ist:</b> Das erkennst du daran, dass wieder die Eingabezeile mit <font name='DVM'>$</font> am Ende erscheint, z. B. "
 "<font name='DVM'>max@laptop:~$</font>.",
])
s.append(P("Gut zu wissen", "h2"))
s += bullets([
 "Fragt das Terminal nach einem <b>Passwort</b>, ist dein Linux-Anmeldepasswort gemeint. Beim Tippen erscheinen <b>keine Zeichen und keine Sternchen</b> – "
 "das ist normal. Einfach blind tippen und Enter drücken.",
 "<font name='DVM'>~</font> steht für deinen Persönlichen Ordner (z. B. <font name='DVM'>/home/max</font>). "
 "<font name='DVM'>~/Documents</font> ist also der Ordner „Dokumente“ bzw. „Documents“ darin.",
 "Einen <b>Ordnerpfad</b> musst du nicht abtippen: Zieh den Ordner aus dem Dateimanager mit der Maus ins Terminal-Fenster – der Pfad wird eingesetzt.",
 "Mit der <b>Pfeiltaste nach oben</b> holst du den letzten Befehl zurück.",
 "Läuft etwas schief, schicke den Text aus dem Terminal an jemanden, der helfen kann. Zum Kopieren aus dem Terminal: markieren, dann <b>Strg + Umschalt + C</b>.",
])

# ---------------------------------------------------------------- Schritt 1
s.append(P("Schritt 1 – Grafikkarte prüfen", "h1"))
s.append(P("Welche Grafik steckt in deinem Rechner? Füge diesen Befehl ein:"))
s += code("lspci | grep -Ei 'vga|3d|display'")
s.append(P("Beispiel einer Ausgabe (Laptop mit zwei Grafikchips):"))
s += out("00:02.0 VGA compatible controller: Intel Corporation TigerLake-LP GT2 [Iris Xe Graphics]\n"
         "01:00.0 3D controller: NVIDIA Corporation TU117M [GeForce MX450]")
s += table([
 ["Steht dort …", "dann …"],
 ["kein <b>NVIDIA</b> (nur Intel oder AMD)", "bist du mit diesem Schritt fertig → weiter mit <b>Schritt 2</b>. Die Treiber sind bei Mint schon dabei."],
 ["<b>NVIDIA</b>", "lies weiter: Der NVIDIA-Treiber muss installiert und geladen sein."],
], [55 * mm, 115 * mm])

s.append(P("1a – Läuft der NVIDIA-Treiber?", "h2"))
s += code("nvidia-smi --query-gpu=name,driver_version --format=csv,noheader")
s += table([
 ["Ausgabe", "Bedeutung und nächster Schritt"],
 ["<font name='DVM'>NVIDIA GeForce MX450, 595.99.02</font><br/>(Name deiner Karte und eine Versionsnummer)", "<b>Alles gut.</b> Weiter mit <b>Schritt 2</b>."],
 ["<font name='DVM'>nvidia-smi: command not found</font><br/>oder „Befehl nicht gefunden“", "Es ist <b>kein NVIDIA-Treiber installiert</b> → <b>1b</b>."],
 ["<font name='DVM'>NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver</font>",
  "Der Treiber ist installiert, <b>darf aber nicht laden</b> – fast immer wegen Secure Boot → <b>1c</b>."],
], [80 * mm, 90 * mm])

s.append(P("1b – NVIDIA-Treiber installieren", "h2"))
s += steps([
 "Startmenü → <b>Treiberverwaltung</b> öffnen (fragt nach deinem Passwort).",
 "Den Eintrag mit <b>„empfohlen“</b> bzw. „recommended“ wählen (z. B. „nvidia-driver-595-open“).",
 "<b>Änderungen anwenden</b> und warten, bis es fertig ist.",
 "Fragt Mint während der Installation nach einem Passwort für <b>Secure Boot</b>: eins ausdenken und merken – es wird nach dem Neustart gebraucht (wie in 1c, Punkt 3).",
 "<b>Neu starten</b>, dann den Befehl aus 1a wiederholen.",
])

s.append(P("1c – Secure Boot: den Treiber freigeben", "h2"))
s.append(P("<b>Was ist los?</b> Secure Boot ist eine Schutzfunktion des Rechners: Er lädt nur Treiber mit einer bekannten Unterschrift. "
           "Mint unterschreibt den NVIDIA-Treiber mit einem eigenen Schlüssel – diesen Schlüssel musst du <b>einmal</b> beim Start bestätigen. "
           "Wurde das bei der Treiber-Installation übersprungen, lädt der Treiber nie. Secure Boot bleibt dabei an; wir schalten nichts ab."))
s.append(P("<b>Prüfen</b>, ob es daran liegt:"))
s += code("mokutil --sb-state; mokutil --test-key /var/lib/shim-signed/mok/MOK.der")
s += out("SecureBoot enabled\nFailed to accesss kernel trusted keyring: Required key not available\n/var/lib/shim-signed/mok/MOK.der is not enrolled")
s.append(P("Steht dort <b>SecureBoot enabled</b> und <b>is not enrolled</b>, liegt es daran (die Zeile „Failed to access …“ ist harmlos). Dann:"))
s += steps([
 "<b>Schlüssel vormerken:</b>",
])
s += code("sudo mokutil --import /var/lib/shim-signed/mok/MOK.der")
s += bullets([
 "Zuerst fragt <font name='DVM'>[sudo] password</font> nach deinem <b>Linux-Passwort</b>.",
 "Dann fragt <font name='DVM'>input password</font> und <font name='DVM'>input password again</font> nach einem <b>neuen Einmal-Passwort</b>, das du dir jetzt ausdenkst. "
 "Du brauchst es nur einmal, gleich nach dem Neustart.",
])
s += note("<b>Wichtig beim Einmal-Passwort:</b> Auf dem blauen Bildschirm nach dem Neustart gilt die <b>amerikanische Tastatur</b>. "
          "Auf einer deutschen Tastatur sind dort <b>y und z vertauscht</b>, Sonderzeichen und Umlaute liegen woanders. "
          "Nimm deshalb nur <b>Kleinbuchstaben ohne y und z</b> und <b>Ziffern</b>, zum Beispiel <font name='DVM'>wow2026</font>.")
s += steps(start=2, items=[
 "<b>Neu starten.</b> Noch bevor Linux startet, erscheint ein <b>blauer Bildschirm</b> mit „Perform MOK management“. "
 "Er wartet nur etwa <b>10 Sekunden</b> – <b>sofort eine Taste drücken</b> (z. B. Pfeil nach unten).",
 "Mit den Pfeiltasten und Enter wählen: <b>Enroll MOK</b> → <b>Continue</b> → <b>Yes</b>.",
 "Das <b>Einmal-Passwort</b> eingeben (auch hier sind keine Zeichen zu sehen) und Enter.",
 "<b>Reboot</b> wählen. Linux startet jetzt normal.",
 "Im Terminal den Befehl aus <b>1a</b> wiederholen. Jetzt sollte deine Karte erscheinen.",
])
s.append(P("Verpasst? Der Rechner ist einfach normal gestartet und der Treiber lädt weiter nicht. Kein Problem: Punkt 1 (Schlüssel vormerken) wiederholen und neu starten."))

s.append(P("1d – Beide Grafikchips (Laptops): Modus prüfen", "h2"))
s.append(P("Viele Laptops haben eine sparsame Intel-Grafik und eine starke NVIDIA-Karte. Der Installer sorgt dafür, dass WoW auf der NVIDIA-Karte läuft. "
           "Dafür muss der Modus <b>On-Demand</b> (oder „NVIDIA – Performance“) eingestellt sein, nicht „Intel – Power Saving“:"))
s += code("prime-select query")
s.append(P("Steht dort <font name='DVM'>on-demand</font> oder <font name='DVM'>nvidia</font>, passt es. Steht dort <font name='DVM'>intel</font>: "
           "auf das NVIDIA-Symbol in der Systemleiste unten rechts klicken → <b>On-Demand</b> wählen → neu anmelden bzw. neu starten."))

# ---------------------------------------------------------------- Schritt 2
s.append(P("Schritt 2 – WoW-Ordner kopieren und prüfen", "h1"))
s.append(P("<b>2a – Kopieren.</b> Kopiere deinen kompletten WoW-Ordner in den Ordner <b>Dokumente</b> (bzw. „Documents“) in deinem Persönlichen Ordner – "
           "von USB-Stick, externer Festplatte oder aus dem Netzwerk. Warte, bis der Dateimanager <b>vollständig</b> fertig ist (ca. 19 GB). "
           "Den Rechner währenddessen nicht in den Ruhezustand schicken und das Laufwerk nicht abziehen."))
s += note("<b>Häufigster Fehler:</b> Der Kopiervorgang bricht ab (Stick abgezogen, Ruhezustand, voll). Kopiert man danach noch einmal und der Dateimanager fragt "
          "„Ersetzen oder beide behalten?“, entsteht mit „beide behalten“ ein Durcheinander: die abgebrochene Datei unter dem richtigen Namen, die vollständige daneben "
          "als <font name='DVM'>common (2).mpq</font>. Das Spiel meldet dann <b>„Failed to open archive common.MPQ“</b>. "
          "Bei der Frage deshalb immer <b>„Ersetzen“</b> wählen – oder vorher den halb kopierten Ordner löschen.")
s.append(P("<b>2b – Wo liegt der Ordner?</b> Dieser Befehl sucht <font name='DVM'>Wow.exe</font> in deinem Persönlichen Ordner und zeigt den Pfad:"))
s += code("find ~ -maxdepth 5 -iname 'Wow.exe' -not -path '*/.wine*'")
s += out("/home/max/Documents/WoW_3.3.5a/Wow.exe")
s.append(P("Der Ordner davor (hier <font name='DVM'>/home/max/Documents/WoW_3.3.5a</font>) ist dein <b>WoW-Ordner</b>. Merke ihn dir für Schritt 3."))
s.append(P("<b>2c – Ist die Kopie vollständig?</b> Zeige die Größen der großen Spieldateien an (Ordnername anpassen):"))
s += code("ls -l ~/Documents/WoW_3.3.5a/Data/*.[Mm][Pp][Qq]")
s.append(P("Die Zahl vor dem Datum ist die Größe in Bytes. Bei 3.3.5a müssen diese vier Dateien <b>genau</b> so groß sein:"))
s += table([
 ["Datei", "Größe in Bytes", "ca."],
 ["common.MPQ", "2 884 765 590", "2,9 GB"],
 ["common-2.MPQ", "1 814 307 386", "1,8 GB"],
 ["expansion.MPQ", "1 923 425 368", "1,9 GB"],
 ["lichking.MPQ", "2 581 185 567", "2,6 GB"],
 ["patch.MPQ, patch-2.MPQ, patch-3.MPQ …", "je nach Server verschieden", ""],
], [70 * mm, 60 * mm, 40 * mm])
s.append(P("Passt alles und es gibt keine Dateien mit „(2)“ im Namen → weiter mit <b>Schritt 3</b>. "
           "Sonst: siehe <b>Probleme → „Failed to open archive common.MPQ“</b> am Ende dieser Anleitung. "
           "Der Installer prüft das übrigens auch selbst und warnt mit einem <b>HINWEIS</b>."))

# ---------------------------------------------------------------- Schritt 3
s.append(P("Schritt 3 – Installer ausführen", "h1"))
s.append(P("Füge diese <b>eine Zeile</b> ein. Den Pfad am Ende ersetzt du durch deinen WoW-Ordner aus Schritt 2b:"))
s += code(f"curl -fsSL {REPO}/install.sh \\\n  | bash -s -- ~/Documents/WoW_3.3.5a")
s += bullets([
 "<b>Nicht</b> <font name='DVM'>sudo</font> davor schreiben. Der Installer fragt selbst einmal nach deinem Passwort (unsichtbar tippen, Enter).",
 "Lässt du den Pfad weg (also nur <font name='DVM'>… | bash</font>), sucht der Installer den Ordner selbst.",
 "Es dauert 3–10 Minuten. Es läuft viel Text durch – das ist normal. Einfach warten, bis die Eingabezeile wieder erscheint.",
])
s.append(P("<b>Variante ohne Einzeiler</b> (erst herunterladen, dann starten – gleiche Wirkung):"))
s += code(f"curl -fsSL -o ~/Downloads/wow-install.sh \\\n  {REPO}/install.sh\nbash ~/Downloads/wow-install.sh ~/Documents/WoW_3.3.5a")

s.append(P("Was du sehen solltest", "h2"))
s.append(P("Der Installer arbeitet in acht Abschnitten (<font name='DVM'>== 1. Prüfen ==</font> bis <font name='DVM'>== 8. Starter … ==</font>) und endet so:"))
s += out("== 6. DXVK 2.7.1 ==\neingesetzt: d3d9.dll\n…\n== 8. Starter, Symbol und Menüeintrag ==\n"
         "Desktop-Verknüpfung: /home/max/Desktop/wow-335a.desktop\n\n== Fertig ==\n"
         "Start: Doppelklick auf dem Desktop oder Menü -> Spiele -> World of Warcraft 3.3.5a")
s += table([
 ["Du siehst …", "Bedeutung"],
 ["<font name='DVM'>== Fertig ==</font>", "Alles eingerichtet. Weiter mit Schritt 4."],
 ["Zeilen mit <font name='DVM'>HINWEIS:</font>", "Etwas passt nicht ganz, der Installer ist aber durchgelaufen. Hinweis lesen – er sagt, was zu tun ist "
  "(z. B. unvollständige Spieldateien, keine X11-Sitzung, kein Symbol gefunden)."],
 ["<font name='DVM'>FEHLER:</font> und Abbruch", "Der Installer hat aufgehört, bevor er etwas Falsches tut. Die Zeile sagt, warum "
  "(z. B. NVIDIA-Treiber nicht geladen → Schritt 1). Nach dem Beheben den Installer einfach erneut starten."],
], [55 * mm, 115 * mm])
s.append(P("Der ganze Text steht auch in der Datei <font name='DVM'>~/wow-setup.log</font>."))

s.append(P("Was der Installer genau macht", "h2"))
s += table([
 ["Abschnitt", "Was passiert"],
 ["1. Prüfen", "WoW-Ordner, Schreibrechte, freier Platz, unvollständige Kopie, Grafikchips"],
 ["2. NVIDIA-Treiber", "nur bei NVIDIA: läuft der Treiber? Bei Secure-Boot-Problem zeigt er die Schritte aus 1c"],
 ["3. Pakete", "installiert aus den offiziellen Paketquellen von Mint/Ubuntu: Wine (32 + 64 Bit), winetricks, Vulkan-Bibliotheken, icoutils; "
  "bei NVIDIA den passenden 32-Bit-Teil des Treibers"],
 ["4. Vulkan-Test", "zeigt, welche Grafikkarte das Spiel benutzen wird"],
 ["5. Wine-Umgebung", "legt den Ordner <font name='DVM'>~/.wine-wow</font> an (eine kleine „Windows-7-Umgebung“ nur für WoW) "
  "und übernimmt deine Tastatur, damit ä ö ü ß im Chat ankommen"],
 ["6. DXVK 2.7.1", "lädt DXVK vom offiziellen Projekt (github.com/doitsujin/dxvk), prüft die Prüfsumme und setzt es ein. "
  "Bewusst nicht die neueste 3.x – die läuft mit dem Wine aus Ubuntu 24.04 nicht"],
 ["7. Einstellungen", "sichert zuerst deinen Ordner <font name='DVM'>WTF</font> (als <font name='DVM'>WTF_Backup_Linux_Datum</font>) und stellt dann nur "
  "Grafik ein: Direct3D 9, Auflösung deines Bildschirms, VSync aus, höchstens 120 FPS (15 im Hintergrund), Sprachchat aus"],
 ["8. Starter", "Startskript <font name='DVM'>~/bin/wow-starten.sh</font>, Eintrag im Startmenü und Verknüpfung auf dem Desktop – "
  "mit dem WoW-Symbol aus <font name='DVM'>Wow.exe</font>"],
], [33 * mm, 137 * mm])
s += note("<b>Was der Installer nicht anfasst:</b> <font name='DVM'>Wow.exe</font>, den Ordner <font name='DVM'>Data</font> (Spieldateien), "
          "<font name='DVM'>Interface</font> (AddOns) und <font name='DVM'>WTF/Account</font> (Kontoeinstellungen, Makros). Er löscht nichts.", OK)

# ---------------------------------------------------------------- Schritt 4
s.append(P("Schritt 4 – Spielen", "h1"))
s += steps([
 "<b>Doppelklick</b> auf „World of Warcraft 3.3.5a“ auf dem Desktop – oder Startmenü → <b>Spiele</b> → <b>World of Warcraft 3.3.5a</b> "
 "(oder im Startmenü „WoW“ eintippen).",
 "Fragt Mint beim ersten Mal, ob es der Verknüpfung vertrauen soll: <b>„Vertrauen und starten“</b>.",
 "Der <b>erste Start dauert länger</b> und das erste Laden ins Spiel kann kurz ruckeln: DXVK bereitet die Grafik einmalig vor. Danach geht es schnell.",
 "Einloggen und spielen wie unter Windows.",
])
s += table([
 ["Was", "Wie"],
 ["FPS anzeigen", "im Chat eintippen: <font name='DVM'>/run print(GetFramerate())</font>"],
 ["Fenster oder Vollbild", "im Spiel unter Grafik, wie unter Windows. Das Fenster lässt sich frei ziehen."],
 ["Zum Desktop wechseln", "Alt + Tab"],
 ["Beenden", "im Spiel <b>Esc → Spiel beenden</b>"],
 ["Einstellungen, AddOns", "liegen wie gewohnt im WoW-Ordner (<font name='DVM'>WTF</font>, <font name='DVM'>Interface/AddOns</font>)"],
], [40 * mm, 130 * mm])

# ---------------------------------------------------------------- Probleme
s.append(P("Probleme und Lösungen", "h1"))

s.append(P("„Failed to open archive common.MPQ“ (oder eine andere .MPQ-Datei)", "h2"))
s.append(P("Die genannte Datei im Ordner <font name='DVM'>Data</font> ist unvollständig oder fehlt – fast immer ein abgebrochener Kopiervorgang (siehe Schritt 2). "
           "Prüfe die Größen wie in Schritt 2c."))
s += bullets([
 "<b>Liegt daneben eine vollständige Fassung mit „(2)“ im Namen</b> (z. B. <font name='DVM'>common (2).mpq</font> mit 2 884 765 590 Bytes): "
 "die zu kleine Datei beiseitelegen und die vollständige umbenennen. Beispiel für common.MPQ (Ordnername anpassen):",
])
s += code("cd ~/Documents/WoW_3.3.5a/Data\nmkdir -p ~/WoW_Reste\nmv common.MPQ ~/WoW_Reste/\nmv \"common (2).mpq\" common.MPQ")
s += bullets([
 "Für andere Dateien entsprechend (z. B. <font name='DVM'>expansion.MPQ</font> und <font name='DVM'>\"expansion (2).mpq\"</font>). "
 "Ist das Original schon richtig groß, kann die „(2)“-Kopie einfach nach <font name='DVM'>~/WoW_Reste</font>.",
 "Den Ordner <font name='DVM'>~/WoW_Reste</font> löschst du, wenn das Spiel wieder läuft.",
 "<b>Gibt es keine vollständige Fassung:</b> die betroffene Datei noch einmal vom Original kopieren (bei der Rückfrage „Ersetzen“ wählen).",
])

s.append(P("WoW ist langsam / läuft auf der falschen Grafikkarte", "h2"))
s += bullets([
 "Schritt 1a prüfen: <font name='DVM'>nvidia-smi</font> muss die Karte zeigen.",
 "Schritt 1d prüfen: Modus <b>On-Demand</b> oder <b>NVIDIA</b>, nicht „intel“.",
 "Danach den Installer erneut ausführen (Schritt 3). Im Abschnitt „4. Vulkan-Test“ muss bei <font name='DVM'>deviceName</font> die NVIDIA-Karte stehen.",
 "Laptop am Netzteil betreiben – im Akkubetrieb drosseln viele Laptops die Grafik.",
])

s.append(P("Umlaute (ä ö ü ß) gehen im Chat nicht", "h2"))
s.append(P("Der Installer übernimmt das Tastaturlayout, das beim Installieren eingestellt war. Hast du es danach geändert, den Installer erneut ausführen – "
           "oder für Deutsch direkt:"))
s += code("WINEPREFIX=~/.wine-wow wine reg add \\\n  'HKCU\\Keyboard Layout\\Preload' /v 1 /t REG_SZ /d 00000407 /f")

s.append(P("Spiel hängt beim Beenden / lässt sich nicht mehr starten", "h2"))
s += code("WINEPREFIX=~/.wine-wow wineserver -k")
s.append(P("Das beendet alle Reste von Wine. Danach WoW normal neu starten."))

s.append(P("Kamera springt, Maus dreht durch", "h2"))
s.append(P("Abmelden, am Anmeldebildschirm über das Symbol neben dem Benutzernamen eine <b>X11</b>-Sitzung wählen (nicht „Wayland“), wieder anmelden. "
           "Bei Linux Mint Cinnamon ist X11 der Standard."))

s.append(P("Doppelklick auf die Verknüpfung tut nichts / zeigt nur Text", "h2"))
s.append(P("Rechtsklick auf die Verknüpfung → <b>„Ausführen erlauben“</b> bzw. „Vertrauen und starten“. Oder über das Startmenü starten."))

s.append(P("Es geht trotzdem nicht", "h2"))
s += steps([
 "Den Installer noch einmal ausführen – er ist dafür gemacht und überschreibt nur seine eigenen Teile.",
 "Diese drei Dinge ansehen bzw. weitergeben, wenn du Hilfe suchst (vorher Kontonamen und Passwörter entfernen):",
])
s += code("tail -40 ~/wow-setup.log\ntail -40 ~/wow-wine.log\nls -t ~/Documents/WoW_3.3.5a/Errors | head -3")
s.append(P("Fehlerberichte und Fragen: Issues auf github.com/EserYueksel/wow-mac."))

# ---------------------------------------------------------------- Aktualisieren / Deinstallieren
s.append(P("Aktualisieren", "h1"))
s.append(P("Einfach die Zeile aus Schritt 3 erneut ausführen. Deine Einstellungen werden vorher wieder gesichert."))

s.append(P("Deinstallieren", "h1"))
s += code(f"curl -fsSL {REPO}/uninstall.sh \\\n  | bash")
s += bullets([
 "Entfernt Startskript, Startmenü-Eintrag, Desktop-Verknüpfung und Symbol.",
 "Fragt, ob die Wine-Umgebung <font name='DVM'>~/.wine-wow</font> (ca. 600 MB, keine Spieldaten) gelöscht werden soll. Mit <b>j</b> löschen, mit Enter behalten.",
 "<b>Dein WoW-Ordner bleibt unverändert.</b> Die Sicherungen deiner Einstellungen liegen dort als <font name='DVM'>WTF_Backup_Linux_Datum</font>.",
 "Wine und die anderen Pakete bleiben installiert, weil andere Programme sie nutzen könnten. Die Zeile zum Entfernen zeigt das Skript am Ende an.",
])

# ---------------------------------------------------------------- Hintergrund
s.append(P("Hintergrund und Fair Play", "h1"))
s.append(P("WoW 3.3.5a ist ein Windows-Programm. <b>Wine</b> stellt ihm unter Linux eine Windows-Umgebung bereit, ohne Windows zu emulieren – "
           "das Spiel läuft direkt auf dem Prozessor. <b>DXVK</b> übersetzt die Grafikbefehle (Direct3D 9) in Vulkan, das die Grafiktreiber unter Linux "
           "schnell beherrschen. Weil Rechner mit Intel- oder AMD-Prozessor denselben Befehlssatz wie Windows-PCs haben, läuft auch das Anti-Cheat-Modul "
           "vieler Server (Warden) normal durch."))
s.append(P("Der Installer verändert das Spiel nicht: keine Patches an <font name='DVM'>Wow.exe</font>, keine Cheats, keine Bots, keine Eingriffe in den Speicher. "
           "Ob ein Server Linux-Spieler erlaubt, regelt der jeweilige Server."))
s.append(Spacer(1, 6))
s.append(P("Quellen der installierten Software: Paketquellen von Linux Mint / Ubuntu (Wine, Vulkan, icoutils) und das offizielle DXVK-Release "
           "github.com/doitsujin/dxvk (Version 2.7.1, SHA-256 d85ce7c7…d513ce87). Installer und Anleitung: github.com/EserYueksel/wow-mac (Ordner linux), MIT-Lizenz. "
           "World of Warcraft ist eine Marke von Blizzard Entertainment; dieses Projekt steht in keiner Verbindung zu Blizzard.", "foot"))

def deco(c, d):
    c.saveState(); c.setFont("DV", 7.5); c.setFillColor(MUTED)
    c.drawString(20 * mm, 10 * mm, "WoW 3.3.5a auf Linux Mint – Anleitung · github.com/EserYueksel/wow-mac")
    c.drawRightString(190 * mm, 10 * mm, f"Seite {d.page}")
    c.restoreState()

out_path = sys.argv[1]
doc = SimpleDocTemplate(out_path, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=17 * mm, bottomMargin=17 * mm,
                        title="WoW 3.3.5a auf Linux Mint – Anleitung", author="WoW-Mac (github.com/EserYueksel/wow-mac)",
                        subject="Schritt-für-Schritt-Anleitung für Wine + DXVK unter Linux Mint")
doc.build(s, onFirstPage=deco, onLaterPages=deco)
print("ok", out_path)
