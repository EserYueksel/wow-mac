-- WoW-Mac Installer – richtet World of Warcraft 3.3.5a auf einem Mac mit Apple-Chip ein
-- (UTM + Ubuntu-VM + Hangover/FEX). Die eigentliche Arbeit macht wowmac.sh.

on run
	set eng to my enginePath()
	set q to quoted form of eng
	set pf to do shell script "/bin/bash " & q & " preflight 2>/dev/null; true"
	set ver to my val(pf, "VERSION")

	-- läuft der Installer schon im Hintergrund (z. B. nachdem das Fenster geschlossen wurde)?
	set rp to my val(pf, "RUNNING_PID")
	if rp is not "" then
		set b to button returned of (display dialog "Der Installer arbeitet gerade im Hintergrund." & return & return & "„Fortschritt anzeigen“ zeigt, wie weit er ist. „Stoppen“ hält ihn an – später kannst du fortsetzen oder neu beginnen." buttons {"Stoppen", "Fortschritt anzeigen"} default button 2 with title "WoW-Mac " & ver)
		if b is "Fortschritt anzeigen" then
			my finish(my watchProgress(rp, "WoW-Mac wird eingerichtet"), true)
			return
		end if
		do shell script "/bin/bash " & q & " stop"
		set pf to do shell script "/bin/bash " & q & " preflight 2>/dev/null; true"
	end if

	-- schon eingerichtet?
	if my val(pf, "INSTALLED") is "1" then
		set b to button returned of (display dialog "WoW-Mac ist auf diesem Mac schon eingerichtet." & return & return & "„Reparieren“ wiederholt die Einrichtung in der Linux-VM (z. B. nach Problemen). Spielstand und Einstellungen bleiben erhalten." buttons {"Abbrechen", "Deinstallieren …", "Reparieren"} cancel button "Abbrechen" default button 3 with title "WoW-Mac " & ver)
		if b is "Reparieren" then
			my finish(my runWithProgress(eng, "repair --gui", "WoW-Mac wird repariert"), false)
		else if b starts with "Deinstallieren" then
			try
				do shell script "open \"$HOME/Applications/WoW-Mac deinstallieren.app\""
			on error
				display alert "Deinstallations-App nicht gefunden" message "Im Terminal geht es so:" & return & "bash " & q & " uninstall"
			end try
		end if
		return
	end if

	-- unterbrochene Installation?
	if my val(pf, "OUR_VM") is not "" then
		set b to button returned of (display dialog "Eine unterbrochene Installation wurde gefunden." & return & "WoW-Ordner: " & my val(pf, "WOW_DIR") & return & return & "„Fortsetzen“ macht dort weiter. „Neu beginnen“ legt die noch unfertige Linux-VM neu an (bereits geladene Dateien werden weiterverwendet)." buttons {"Abbrechen", "Neu beginnen", "Fortsetzen"} cancel button "Abbrechen" default button 3 with title "WoW-Mac " & ver)
		if b is "Fortsetzen" then
			my finish(my runWithProgress(eng, "install --gui", "WoW-Mac wird eingerichtet"), true)
		else if b is "Neu beginnen" then
			my finish(my runWithProgress(eng, "install --gui --fresh", "WoW-Mac wird eingerichtet"), true)
		end if
		return
	end if

	display dialog "Dieser Installer richtet World of Warcraft 3.3.5a auf deinem Mac ein:" & return & return & ¬
		"• UTM (kostenlose Virtualisierung) – falls noch nicht vorhanden" & return & ¬
		"• eine kleine Linux-VM mit Wine und FEX, in der WoW läuft" & return & ¬
		"• eine Start-App im Dock" & return & return & ¬
		"Du brauchst: deinen WoW-3.3.5a-Ordner (er wird nicht mitgeliefert), Internet (ca. 1,5 GB Download), ca. 20 GB freien Speicher und 20–40 Minuten Zeit. Passwörter werden nicht abgefragt." buttons {"Abbrechen", "Weiter"} cancel button "Abbrechen" default button 2 with title "WoW-Mac " & ver

	-- Voraussetzungen
	if my val(pf, "ARM") is not "1" then
		display alert "Kein Apple-Chip" message "WoW-Mac funktioniert nur auf Macs mit Apple-Chip (M1 oder neuer)." as critical
		return
	end if
	if ((my val(pf, "MACOS_MAJOR")) as integer) < 13 then
		display alert "macOS zu alt" message "Nötig ist macOS 13 oder neuer (installiert: " & my val(pf, "MACOS") & ")." as critical
		return
	end if
	if ((my val(pf, "FREE_GB")) as integer) < 20 then
		display alert "Zu wenig Speicher" message "Frei: " & my val(pf, "FREE_GB") & " GB. Nötig sind mindestens 20 GB." as critical
		return
	end if
	if my val(pf, "NET") is not "1" then
		display alert "Keine Internetverbindung" message "github.com ist nicht erreichbar. Bitte Internet prüfen und erneut starten." as critical
		return
	end if
	if ((my val(pf, "RAM_GB")) as integer) < 16 then
		display dialog "Dein Mac hat " & my val(pf, "RAM_GB") & " GB Arbeitsspeicher. Es geht, aber neben WoW sollten dann kaum andere Programme laufen." buttons {"Abbrechen", "Trotzdem weiter"} cancel button "Abbrechen" default button 2 with icon caution
	end if
	set extra to ""
	if my val(pf, "UTM_STATE") is "old" then
		display dialog "UTM " & my val(pf, "UTM_VERSION") & " ist zu alt. Soll es durch die getestete Version ersetzt werden? (Deine anderen VMs bleiben erhalten.)" buttons {"Abbrechen", "UTM aktualisieren"} cancel button "Abbrechen" default button 2 with icon caution
		set extra to " --update-utm"
	end if
	if ((my val(pf, "UTM_RUNNING_VMS")) as integer) > 0 then
		display alert "In UTM laufen noch VMs" message "Bitte beende sie zuerst und starte den Installer dann erneut." as warning
		return
	end if

	-- WoW-Ordner wählen
	repeat
		set f to choose folder with prompt "Wähle deinen WoW-3.3.5a-Ordner (darin liegen Wow.exe und der Ordner Data):"
		set p to POSIX path of f
		if p ends with "/" and (length of p) > 1 then set p to text 1 thru -2 of p
		set r to do shell script "/bin/bash " & q & " check-wow " & quoted form of p & " 2>&1; true"
		if r ends with "OK" then exit repeat
		display alert "Das passt noch nicht" message r as warning
	end repeat

	-- Speicherort
	set moveArg to ""
	set b to button returned of (display dialog "Wo soll der WoW-Ordner liegen?" & return & return & p buttons {"Woanders hin verschieben …", "Hier lassen"} default button 2 with title "WoW-Ordner")
	if b starts with "Woanders" then
		set d to POSIX path of (choose folder with prompt "Wohin soll der WoW-Ordner verschoben werden?")
		set moveArg to " --move-to " & quoted form of d
	end if

	-- Name der Start-App
	set appName to "WoW 3.3.5a"
	repeat
		set appName to text returned of (display dialog "Name der Start-App (erscheint im Dock):" default answer appName with title "Start-App")
		if (do shell script "printf '%s' " & quoted form of appName & " | grep -Eq '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,40}$' && echo ok || echo nein") is "ok" then exit repeat
		display alert "Bitte nur Buchstaben (ohne Umlaute), Ziffern, Leerzeichen, Punkt, Unterstrich oder Bindestrich verwenden." as warning
	end repeat
	set dockArg to ""
	set b to button returned of (display dialog "Start-App ins Dock legen?" buttons {"Nein", "Ja"} default button 2 with title "Start-App")
	if b is "Nein" then set dockArg to " --no-dock"

	display dialog "Alles bereit." & return & return & ¬
		"Gleich fragt macOS, ob der Installer UTM steuern darf – bitte „Erlauben“ wählen." & return & return & ¬
		"Die Einrichtung dauert 20–40 Minuten. Der Mac bleibt dabei wach; bitte den Deckel offen lassen. Du kannst nebenbei weiterarbeiten." buttons {"Abbrechen", "Installieren"} cancel button "Abbrechen" default button 2 with title "WoW-Mac " & ver

	set args to "install --gui --wow-dir " & quoted form of p & moveArg & " --app-name " & quoted form of appName & dockArg & extra
	my finish(my runWithProgress(eng, args, "WoW-Mac wird eingerichtet"), true)
end run

on finish(res, isInstall)
	if item 1 of res then
		if isInstall then
			set pf to do shell script "/bin/bash " & quoted form of (my supportDir() & "/app/installer/wowmac.sh") & " preflight 2>/dev/null; true"
			set appName to my val(pf, "APP_NAME")
			if my val(pf, "PREFS_MANUAL") is "1" then
				set b to button returned of (display dialog "Noch ein Handgriff in UTM (einmalig) – macOS lässt den Installer diese Einstellungen nicht selbst setzen:" & return & return & ¬
					"1. UTM öffnen → Menü UTM → Einstellungen (Settings) → Eingabe (Input): „Capture input automatically when entering full screen“ und „Capture input automatically when window is focused“ einschalten. Sonst dreht sich die Kamera im Spiel beim Klicken wild im Kreis." & return & return & ¬
					"2. Empfohlen bei sehr großen Monitoren: Einstellungen → Display → Renderer Backend: „Apple Core OpenGL“ (spürbar mehr FPS)." buttons {"Später", "UTM öffnen"} default button 2 with icon caution with title "WoW-Mac")
				if b is "UTM öffnen" then do shell script "open -b com.utmapp.UTM"
			end if
			set b to button returned of (display dialog "Fertig!" & return & return & ¬
				"Starte WoW über „" & appName & "“ im Dock (oder in deinem Benutzerordner unter Programme)." & return & return & ¬
				"Beim ersten Start fragt macOS, ob die App UTM und System Events steuern darf – bitte erlauben. Für das automatische Vollbild zusätzlich unter Bedienungshilfen einschalten." & return & return & ¬
				"Maus: Klick ins Spiel fängt die Maus, Ctrl+Option gibt sie frei." & return & ¬
				"Beenden: im Spiel Esc → Spiel beenden (nicht das UTM-Fenster schließen)." buttons {"Fertig", "Jetzt starten"} default button 2 with title "WoW-Mac")
			if b is "Jetzt starten" then do shell script "open \"$HOME/Applications/" & appName & ".app\""
		else
			display dialog (item 2 of res) buttons {"OK"} default button 1 with title "WoW-Mac"
		end if
	else
		set b to button returned of (display dialog "Das hat nicht geklappt:" & return & return & (item 2 of res) & return & return & "Starte den Installer einfach erneut – er setzt dort fort, wo es aufgehört hat." buttons {"Protokoll anzeigen", "OK"} default button 2 with icon caution with title "WoW-Mac")
		if b is "Protokoll anzeigen" then my showLog()
	end if
end finish
