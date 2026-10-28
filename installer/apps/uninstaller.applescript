-- WoW-Mac deinstallieren – entfernt alles, was der WoW-Mac-Installer angelegt hat.
-- Der WoW-Ordner selbst bleibt unverändert.

on run
	set eng to my enginePath()
	set q to quoted form of eng
	set pf to do shell script "/bin/bash " & q & " preflight 2>/dev/null; true"
	set vmName to my val(pf, "OUR_VM")
	set appName to my val(pf, "APP_NAME")
	if vmName is "" and appName is "" then
		display alert "Nichts zu entfernen" message "Es wurde keine WoW-Mac-Installation gefunden."
		return
	end if
	display dialog "Folgendes wird entfernt:" & return & return & ¬
		"• die Linux-VM „" & vmName & "“ in UTM (mit allem darin)" & return & ¬
		"• die Start-App „" & appName & "“ und ihr Dock-Eintrag (in den Papierkorb)" & return & ¬
		"• die Einstellungen, die der Installer in UTM geändert hat" & return & ¬
		"• Zwischenspeicher und Hilfsdateien" & return & return & ¬
		"Dein WoW-Ordner bleibt unverändert." buttons {"Abbrechen", "Weiter"} cancel button "Abbrechen" default button 2 with icon caution with title "WoW-Mac deinstallieren"
	set extra to ""
	if my val(pf, "UTM_BY_US") is "1" then
		set b to button returned of (display dialog "UTM wurde vom Installer eingerichtet. Soll UTM ebenfalls entfernt werden?" & return & "(Nur wenn darin keine anderen VMs mehr sind.)" buttons {"UTM behalten", "UTM entfernen"} default button 1 with title "WoW-Mac deinstallieren")
		if b is "UTM entfernen" then set extra to extra & " --remove-utm"
	end if
	set b to button returned of (display dialog "Sollen die WoW-Einstellungen (WTF/Config.wtf) auf den Stand vor der Installation zurückgesetzt werden?" & return & "Sinnvoll, wenn du WoW danach wieder unter Windows nutzt. Die heutige Fassung wird vorher gesichert." buttons {"Nein", "Ja, zurücksetzen"} default button 1 with title "WoW-Mac deinstallieren")
	if b starts with "Ja" then set extra to extra & " --restore-config"
	set b to button returned of (display dialog "Jetzt endgültig deinstallieren?" buttons {"Abbrechen", "Deinstallieren"} cancel button "Abbrechen" default button 1 with icon caution with title "WoW-Mac deinstallieren")
	set res to my runWithProgress(eng, "uninstall --gui" & extra, "WoW-Mac wird entfernt")
	if item 1 of res then
		display dialog "WoW-Mac wurde entfernt. Dein WoW-Ordner ist unverändert." & return & return & "Die entfernten Apps liegen im Papierkorb." buttons {"OK"} default button 1 with title "WoW-Mac"
	else
		set b to button returned of (display dialog "Das hat nicht geklappt:" & return & return & (item 2 of res) buttons {"Protokoll anzeigen", "OK"} default button 2 with icon caution with title "WoW-Mac")
		if b is "Protokoll anzeigen" then my showLog()
	end if
end run
