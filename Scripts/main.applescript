use scripting additions
use framework "Foundation"
use framework "AppKit"

property myApp : a reference to current application
property plistURL : missing value
property plistDict : missing value
property helperDir : missing value
property statusBar : missing value
property statusItem : missing value
property preSelected : {}
property lastLidState : true
property monitorKeys : {"Spotify", "Apple Music", "Now Playing (Beta)"}
property resourcesDir : missing value
property propertiesPath : missing value
property lastMusicState : false
property lastLowPowerState : false
property toMonitorDict : missing value

property statusItemTitle : missing value
property setSleepTimerItem : missing value
property pidFilePath : "/tmp/lidmusic.pid"

on run
	try
		set myPath to POSIX path of (path to me)
		set resourcesDir to myPath & "Contents/Resources/"
		set helperDir to resourcesDir & "Helpers/"
		set propertiesPath to resourcesDir & "properties.plist"

		set plistURL to current application's |NSURL|'s fileURLWithPath:propertiesPath
		set plistDict to current application's NSDictionary's dictionaryWithContentsOfURL:plistURL

		if plistDict is missing value then
			display alert "Failed to read plist file."
			return
		end if

		if (plistDict's objectForKey:"helperDir") as text is not equal to helperDir or (plistDict's objectForKey:"isHelperInstalled") as boolean is false then
			set scriptList to paragraphs of (do shell script "find " & quoted form of helperDir & " -maxdepth 1 -type f -name '*.sh'")

			if scriptList is {} then
				display dialog "⚠️ No .sh files found in helper directory!"
				return
			end if

			set currentUser to do shell script "whoami"
			set sudoersContent to ""
			repeat with scriptPath in scriptList
				set sudoersContent to sudoersContent & currentUser & " ALL=(ALL) NOPASSWD: " & scriptPath & linefeed
			end repeat

			display alert "Configuring helper tools (you’ll be asked for your password)..."
			set sudoersFile to "/etc/sudoers.d/LidMusicHelper"
			do shell script "echo " & quoted form of sudoersContent & " | sudo tee " & quoted form of sudoersFile & " > /dev/null; sudo chown root:wheel " & quoted form of sudoersFile & "; sudo chmod 440 " & quoted form of sudoersFile with administrator privileges

			plistDict's setObject:(helperDir as text) forKey:"helperDir"
			plistDict's setObject:true forKey:"isHelperInstalled"
			plistDict's setObject:(do shell script "date -u '+%Y-%m-%dT%H:%M:%SZ'") forKey:"installedAt"
			plistDict's writeToURL:plistURL atomically:true

			if button returned of (display alert "✅ LidMusic helpers installed successfully!" buttons {"Skip", "Add to login items"}) is "Add to login items" then
				tell application "System Settings"
					activate
					reveal pane id "com.apple.LoginItems-Settings.extension"
				end tell
			end if
		end if

		-- Get the 'toMonitor' dictionary
		set toMonitorDict to plistDict's objectForKey:"toMonitor"
		repeat with k in monitorKeys
			if (toMonitorDict's objectForKey:k) as boolean then set preSelected's end to k
		end repeat

		-- Check if all are false
		if (count of preSelected) is 0 then Recalibrate()

	on error errMsg number errNum
		display dialog "❌ Setup failed (" & errNum & "): " & errMsg buttons {"OK"} default button "OK"
	end try

	set statusItemTitle to plistDict's objectForKey:"icon"
	my createStatusItem:statusItemTitle

	if (do shell script "system_profiler SPHardwareDataType | awk -F': ' '/Model Name/ {print $2}'") does not contain "MacBook" then
		display alert "LidMusic only works on MacBooks :("
		quit {}
	end if

end run

----- endless loop -----
on idle
	----- Music Sleep/Wake Logic ---
	set currentMusicState to isMusicPlaying()
	if currentMusicState is not lastMusicState then
		set lastMusicState to currentMusicState
		if currentMusicState is true then
			do shell script "sudo " & quoted form of (helperDir & "nosleep.sh")
		else
			do shell script "sudo " & quoted form of (helperDir & "sleep.sh")
		end if
	end if

	--low power mode logic--
	set currentLidState to isLidOpen()
	if currentLidState is not lastLidState then

		if currentLidState is false then
			do shell script "pmset displaysleepnow"
			lowPowerModeOn()
		else
			if lastLowPowerState is true then
				lowPowerModeOn()
			else
				do shell script "sudo " & quoted form of (helperDir & "lowPowerOff.sh")
			end if
		end if
		set lastLidState to currentLidState
	else
		if currentLidState is true then
			set lastLowPowerState to isLowPowerMode()
		end if
	end if
	return 2
end idle

on createStatusItem:title
	-- Get the system Status Bar object
	set statusBar to myApp's NSStatusBar's systemStatusBar()
	-- Create the Status Item with variable length
	set statusItem to statusBar's statusItemWithLength:(myApp's NSVariableStatusItemLength)
	-- Set the title only (no image)
	statusItem's button's setTitle:title
	my createMenuItems()
end createStatusItem:

on createMenuItems()
	set statusItemMenu to myApp's NSMenu's alloc()'s initWithTitle:(statusItemTitle as text)

	set RecalibrateMenuItem to myApp's NSMenuItem's alloc()'s initWithTitle:"🔧 Choose apps to monitor" action:"Recalibrate" keyEquivalent:"r"
	RecalibrateMenuItem's setTarget:me
	statusItemMenu's addItem:RecalibrateMenuItem

	set changeIcon to myApp's NSMenuItem's alloc()'s initWithTitle:"🌀 Change icon" action:"changeMenuIcon" keyEquivalent:"i"
	changeIcon's setTarget:me
	statusItemMenu's addItem:changeIcon

	set checkUpdate to myApp's NSMenuItem's alloc()'s initWithTitle:"🔄 Check for update" action:"checkForUpdate" keyEquivalent:"u"
	checkUpdate's setTarget:me
	statusItemMenu's addItem:checkUpdate

	set quitMenuItem to myApp's NSMenuItem's alloc()'s initWithTitle:"❌ Quit" action:"quitStatusItem" keyEquivalent:"q"
	quitMenuItem's setTarget:me
	statusItemMenu's addItem:quitMenuItem
	statusItem's setMenu:statusItemMenu

	set sepMenuItem to myApp's NSMenuItem's separatorItem()
	statusItemMenu's addItem:sepMenuItem

	set starOnGit to myApp's NSMenuItem's alloc()'s initWithTitle:"⭐️ Star on GitHub" action:"starOnGitHub" keyEquivalent:"g"
	starOnGit's setTarget:me
	statusItemMenu's addItem:starOnGit

	set sepMenuItem2 to myApp's NSMenuItem's separatorItem()
	statusItemMenu's addItem:sepMenuItem2

	set setSleepTimerItem to myApp's NSMenuItem's alloc()'s initWithTitle:"Set Sleep Timer" action:"setSleepTimer" keyEquivalent:"t"
	setSleepTimerItem's setTarget:me
	statusItemMenu's addItem:setSleepTimerItem

	set cancelSleepTimerItem to myApp's NSMenuItem's alloc()'s initWithTitle:"Cancel Sleep Timer" action:"cancelSleepTimer" keyEquivalent:""
	cancelSleepTimerItem's setTarget:me
	statusItemMenu's addItem:cancelSleepTimerItem

end createMenuItems

on setSleepTimer()
	set timerValue to text returned of (display dialog "Enter sleep timer in minutes:" default answer "0")
	try
		set timerValue to timerValue as integer
		if timerValue < 0 then error
	on error
		display dialog "Invalid input. Please enter a positive number."
		return
	end try
	plistDict's setObject:timerValue forKey:"sleepTimer"
	plistDict's writeToURL:plistURL atomically:true
	set pid to do shell script "sh " & quoted form of (helperDir & "sleep_timer.sh") & " " & quoted form of propertiesPath & " > /dev/null 2>&1 & echo $!"
	do shell script "echo " & pid & " > " & pidFilePath
	setSleepTimerItem's setTitle:"Timer is active (" & timerValue & " mins)"
end setSleepTimer

on cancelSleepTimer()
	do shell script "sh " & quoted form of (helperDir & "cancel_timer.sh")
	setSleepTimerItem's setTitle:"Set Sleep Timer"
end cancelSleepTimer

on changeMenuIcon()
	set statusItemTitle to text returned of (display dialog "Type emoji or text (or leave empty)" default answer statusItemTitle as text with icon note buttons {"Set new icon"} default button 1)

	statusItem's button's setTitle:statusItemTitle
	plistDict's setObject:(statusItemTitle as text) forKey:"icon"
	plistDict's writeToURL:plistURL atomically:true

end changeMenuIcon


on Recalibrate()
	set chosenApps to choose from list monitorKeys with title "Select services to Monitor" with prompt "Choose one or more:" default items preSelected with multiple selections allowed

	if chosenApps is false then
		if preSelected is {} then
			display alert "You can't leave it empty" buttons {"↪️ Choose again..."} as critical
			Recalibrate()
			return
		end if
	end if
	set preSelected to chosenApps

	-- Update dictionary: set true for chosen, false for unchosen
	repeat with anApp in monitorKeys
		if chosenApps contains anApp then
			(toMonitorDict's setObject:(true) forKey:(contents of anApp))
		else
			(toMonitorDict's setObject:(false) forKey:(contents of anApp))
		end if
	end repeat

	plistDict's writeToURL:plistURL atomically:true
end Recalibrate

on quitStatusItem()
	if my NSThread's isMainThread() as boolean then
		my removeStatusItem()
	else
		my performSelectorOnMainThread:"removeStatusItem" withObject:(missing value) waitUntilDone:true
	end if
	if name of myApp does not start with "Script" then
		tell me to quit
	end if
end quitStatusItem

on checkForUpdate()
	set installedAt to do shell script "plutil -extract installedAt raw -o - " & quoted form of propertiesPath
	set updateScript to quoted form of (POSIX path of (resourcesDir & "update.py"))
	set cmd to "printf %s " & quoted form of installedAt & " | python3 " & updateScript
	set out to do shell script cmd
	if out is not "" then
		set userInput to display dialog out & " is available! and will be automatically installed to your Applications folder." buttons {"Just install", "View on GitHub"} default button 2 with icon note with title "	✅ Update Found!"
		if button returned of userInput is "View on GitHub" then
			open location "https://github.com/Swapnil-Pradhan/LidMusic/releases/tag/LidMusic"
		end if

		if resourcesDir is not "/Applications/LidMusic.app/Contents/Resources/" then
			do shell script "rm -rf " & resourcesDir & "../.."
		end if

		display alert out & " installed in Applications folder. Reopening..."
		do shell script "nohup bash " & resourcesDir & "relaunch.sh"
		quit {}
	else
		display alert "LidMusic is up to date."
	end if
end checkForUpdate

on isMusicPlaying()
	set anyPlaying to false
	repeat with i in preSelected
		set j to i as text
		if j is "Now Playing (Beta)" then
			set anyPlaying to (do shell script "osascript " & resourcesDir & "nowPlaying.scpt") is "1"
		end if


		if j = "Apple Music" and application "Music" is running then
			tell application "Music"
				try
					if player state is playing then set anyPlaying to true
				end try
			end tell
		end if

		if j = "Spotify" and application "Spotify" is running then
			tell application "Spotify"
				try
					if player state is playing then set anyPlaying to true
				end try
			end tell
		end if

		if anyPlaying is true then return true
	end repeat

	return false
end isMusicPlaying

on starOnGitHub()
	open location "https://github.com/Swapnil-Pradhan/LidMusic"
end starOnGitHub

on removeStatusItem()
	statusBar's removeStatusItem:statusItem
end removeStatusItem

on quit
	do shell script "sh " & quoted form of (helperDir & "cancel_timer.sh")
	do shell script "sudo " & quoted form of (helperDir & "sleep.sh")
	continue quit
end quit

on isLidOpen()
	try
		do shell script "system_profiler SPDisplaysDataType | grep 'Resolution:'"
		return true
	on error
		return false
	end try
end isLidOpen

on isLowPowerMode()
	return (do shell script "pmset -g | grep -q 'lowpowermode 1'; echo $?") is "0"
end isLowPowerMode

on lowPowerModeOn()
	if isOnAC() is false then do shell script "sudo " & quoted form of (helperDir & "lowPowerOn.sh")
end lowPowerModeOn

on isOnAC()
	return (do shell script "pmset -g batt | grep -q 'AC Power'; echo $?") is "0"
end isOnAC