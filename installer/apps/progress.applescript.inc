-- ===== gemeinsamer Teil (wird beim Bauen angehängt) =====
on supportDir()
	return POSIX path of (path to home folder) & "Library/Application Support/WoW-Mac"
end supportDir

-- Installer-Dateien: in der Release-App liegen sie im Bundle und werden nach Application Support kopiert
on enginePath()
	set sup to my supportDir() & "/app"
	set bundled to POSIX path of (path to me) & "Contents/Resources/installer"
	try
		do shell script "test -f " & quoted form of (bundled & "/wowmac.sh")
		do shell script "mkdir -p " & quoted form of sup & " && rm -rf " & quoted form of (sup & "/installer.neu") & " && ditto " & quoted form of bundled & " " & quoted form of (sup & "/installer.neu") & " && rm -rf " & quoted form of (sup & "/installer") & " && mv " & quoted form of (sup & "/installer.neu") & " " & quoted form of (sup & "/installer")
	end try
	set eng to sup & "/installer/wowmac.sh"
	try
		do shell script "test -f " & quoted form of eng
	on error
		display alert "Installer-Dateien fehlen" message "Bitte den Installer erneut herunterladen." as critical
		error number -128
	end try
	return eng
end enginePath

on val(pf, k)
	repeat with l in paragraphs of pf
		set l to l as text
		if l starts with (k & "=") then
			if (length of l) > ((length of k) + 1) then return text ((length of k) + 2) thru -1 of l
			return ""
		end if
	end repeat
	return ""
end val

on showLog()
	try
		do shell script "f=$(ls -t \"$HOME/Library/Logs/WoW-Mac/\"*.log 2>/dev/null | head -1); [ -n \"$f\" ] && open -e \"$f\""
	end try
end showLog

-- startet wowmac.sh im Hintergrund und zeigt den Fortschritt an; Ergebnis: {ok, text}
on runWithProgress(eng, cmdArgs, title)
	set statusFile to my supportDir() & "/status.txt"
	set pid to do shell script "rm -f " & quoted form of statusFile & "; /bin/bash " & quoted form of eng & " " & cmdArgs & " >/dev/null 2>&1 & echo $!"
	return my watchProgress(pid, title)
end runWithProgress

-- zeigt den Fortschritt eines laufenden wowmac.sh (auch eines, das schon vorher gestartet wurde)
on watchProgress(pid, title)
	set statusFile to my supportDir() & "/status.txt"
	set progress total steps to 100
	set progress completed steps to 0
	set progress description to title
	set progress additional description to "Startet …"
	set gone to 0
	repeat
		try
			delay 2
			set stTxt to do shell script "cat " & quoted form of statusFile & " 2>/dev/null || true"
			if stTxt is not "" then
				set AppleScript's text item delimiters to tab
				set parts to text items of stTxt
				set AppleScript's text item delimiters to ""
				if (count of parts) >= 3 then
					set ph to item 1 of parts
					try
						set progress completed steps to (item 2 of parts) as integer
					end try
					set progress description to item 3 of parts
					if (count of parts) >= 4 then set progress additional description to item 4 of parts
					if ph is "DONE" then return {true, item 3 of parts}
					if ph is "FAIL" then return {false, item 3 of parts}
				end if
			end if
			if (do shell script "kill -0 " & pid & " 2>/dev/null && echo 1 || echo 0") is "0" then
				set gone to gone + 1
				if gone > 2 then return {false, "Der Installer wurde unerwartet beendet."}
			end if
		on error errMsg number errNum
			if errNum is -128 then
				set b to button returned of (display dialog "Wirklich abbrechen?" & return & "Du kannst später neu starten – es geht dort weiter, wo es aufgehört hat." buttons {"Weitermachen", "Abbrechen"} default button 1 with icon caution)
				if b is "Abbrechen" then
					do shell script "pkill -P " & pid & " 2>/dev/null; kill " & pid & " 2>/dev/null; true"
					return {false, "Abgebrochen."}
				end if
			else
				return {false, errMsg}
			end if
		end try
	end repeat
end watchProgress
