-- __APPNAME__ – Starter (WoW-Mac)
-- Startet die Linux-VM "__VMNAME__" in UTM, schaltet ihr Fenster ins Vollbild
-- und startet darin World of Warcraft 3.3.5a (Hangover-Wine + FEX).
property vmName : "__VMNAME__"
property launchScale : "__SCALE__" -- "1" = normal, "0.5" = Leistungsmodus (halbe Auflösung, hochskaliert)

on run
	try
		tell application id "com.utmapp.UTM" to launch
	on error
		display alert "UTM fehlt" message "UTM wurde nicht gefunden. Bitte den WoW-Mac-Installer erneut ausführen." as critical
		return
	end try
	try
		tell application id "com.utmapp.UTM"
			set vm to virtual machine named vmName
			set vmState to status of vm
			if vmState is stopped or vmState is paused then start vm
			activate
		end tell
	on error errMsg number errNum
		if errNum is -1743 then
			my noAutomation()
		else
			display alert "WoW konnte nicht gestartet werden" message "Die VM „" & vmName & "“ fehlt in UTM oder startet nicht:" & return & errMsg as critical
		end if
		return
	end try

	-- Vollbild möglichst früh: dann startet die Linux-Oberfläche gleich in der richtigen Auflösung
	my enterFullScreen()

	-- warten, bis die VM gebootet ist und ihr Gastagent antwortet (max. 3 Minuten)
	set ready to false
	repeat 180 times
		try
			with timeout of 10 seconds
				tell application id "com.utmapp.UTM" to set ips to query ip of virtual machine named vmName
			end timeout
			set ready to true
			exit repeat
		end try
		delay 1
	end repeat
	if not ready then
		display alert "Die VM antwortet nicht" message "Bitte in UTM nachsehen. Hilft das nicht: VM in UTM ausschalten und die App erneut starten." as warning
		return
	end if

	my enterFullScreen()
	tell application id "com.utmapp.UTM"
		try
			execute of virtual machine named vmName at "/usr/local/bin/wow-launch" with arguments {"3", launchScale}
		on error errMsg
			display alert "WoW konnte in der VM nicht gestartet werden" message errMsg as warning
		end try
	end tell
end run

-- Vollbild über die Bedienungshilfen (einmalige Freigabe nötig). Ohne Freigabe bleibt es ein Fenster.
on enterFullScreen()
	set hintFile to POSIX path of (path to home folder) & "Library/Application Support/WoW-Mac/kein-vollbild-hinweis"
	repeat 20 times
		try
			tell application "System Events"
				tell process "UTM"
					set frontmost to true
					repeat with w in windows
						if name of w is vmName then
							if value of attribute "AXFullScreen" of w is false then set value of attribute "AXFullScreen" of w to true
							return
						end if
					end repeat
				end tell
			end tell
		on error errMsg number errNum
			if errNum is -1719 or errNum is -25211 or errNum is -1743 then
				try
					do shell script "test -f " & quoted form of hintFile
				on error
					set b to button returned of (display dialog "Für das automatische Vollbild braucht „__APPNAME__“ einmalig die Freigabe unter „Bedienungshilfen“ (und „Automation“ für System Events)." & return & return & "Ohne Freigabe läuft WoW im Fenster – das geht auch." buttons {"Nicht mehr fragen", "Einstellungen öffnen"} default button 2 with icon note)
					if b is "Einstellungen öffnen" then
						do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
					else
						do shell script "mkdir -p \"$(dirname " & quoted form of hintFile & ")\" && touch " & quoted form of hintFile
					end if
				end try
				return
			end if
		end try
		delay 1
	end repeat
end enterFullScreen

on noAutomation()
	set b to button returned of (display dialog "„__APPNAME__“ darf UTM noch nicht steuern." & return & return & "Bitte unter Systemeinstellungen → Datenschutz & Sicherheit → Automation bei „__APPNAME__“ den Schalter für UTM einschalten und die App erneut starten." buttons {"OK", "Einstellungen öffnen"} default button 2 with icon caution)
	if b is "Einstellungen öffnen" then do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Automation'"
end noAutomation
