#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <ColorConstants.au3>
#include <MsgBoxConstants.au3>
#include <AutoItConstants.au3>
#include <Array.au3>
#include <ScreenCapture.au3>
#include <WinAPIFiles.au3>


Opt("SendKeyDownDelay", 150)
Opt("GUIOnEventMode", 1) ; Change to OnEvent mode

HotKeySet ("{INSERT}","TogglePause")
HotKeySet ("{END}","ends")
HotKeySet ("!b","storeBankerCoords")				; Alt + b
HotKeySet ("!c","storeCoalBagCoords")				; Alt + c
HotKeySet ("!o","storeLastOreCoords")				; Alt + o
HotKeySet ("{F2}","setAllCheckpoints")

; Loads Settings File
Global Const $SETTINGS_INI = "settings.ini";

; Alter Settings
Global Const $loadoutNumber = loadValue( "Settings", "loadoutNumber", "2" )
Global Const $superheat_key = loadValue( "Settings", "superheatKey", "x" )
Global Const $load_size = loadValue( "Settings", "loadSize", "11" )
Global $superheat_cooldown = loadValue( "Settings", "superheatCooldown", "800" )
Global $runtime = loadValue( "Settings", "runtime", "1000" )
Global $lag = loadValue( "Settings", "lag", "0" )

; Window Derived Identifiers
Global Const $windowName = loadValue( "Window", "windowName", "RuneScape" )
Global Const $rsWindowHandle = WinActive($windowName)

; Stored Settings
Global $Paused = False
Global $safeClick = False
Global $cycle_start_time = Null
Global $bars_to_produce = 9999

; Stored Pixel Settings
Global $BANK_OPEN[2] = [1261, 650]
loadCoord( "Coordinates", "bankOpen", $BANK_OPEN )
Global $BANK_OPEN_PIXEL = loadValue( "Pixels", "bankOpen", "724751" )
Global $BANK_CLOSED[2] = [1261, 650]
loadCoord( "Coordinates", "bankClosed", $BANK_CLOSED )
Global $BANK_CLOSED_PIXEL = loadValue( "Pixels", "bankClosed", "2568754" )
Global $INACTIVE_SUPERHEAT_SPELL[2] = [0,0]
loadCoord( "Coordinates", "superheat", $INACTIVE_SUPERHEAT_SPELL )
Global $INACTIVE_SUPERHEAT_SPELL_PIXEL = loadValue( "Pixels", "superheat", 0 )

; Coordinates
Global $banker_coord[2][3] = [[True,0,0],[False,0,0]]
loadSpecialCoord( "Coordinate Ranges", "banker", $banker_coord )
Global $coalBag_coord[2][3] = [[True,0,0],[False,0,0]]
loadSpecialCoord( "Coordinate Ranges", "coalBag", $coalBag_coord )
Global $lastOre_coord[2][3] = [[True,0,0],[False,0,0]]
loadSpecialCoord( "Coordinate Ranges", "lastOre", $lastOre_coord )


; Metrics
Global $trip_limit = $bars_to_produce / $load_size
Global $completed_trips = 0
Global $cycleTime = 0


; Sets Up GUI
Local $gui_width = 200
Local $gui_height = 275
Global $hMainGUI = GUICreate("Superheat v3.0", $gui_width, $gui_height)
WinSetOnTop ($hMainGUI, "", 1)

;; GUI Lables and Buttons ;;
; Coordinates
GUICtrlCreateLabel("Banker: ", 5, 10)
Local $id_bankerCoord = GUICtrlCreateLabel(stringifyCoord($banker_coord), 60, 10, $gui_width)
GUICtrlCreateLabel("CoalBag: ", 5, 25)
Local $id_coalBagCoord = GUICtrlCreateLabel(stringifyCoord($coalBag_coord), 60, 25, $gui_width)
GUICtrlCreateLabel("Last Ore: ", 5, 40)
Local $id_lastOreCoord = GUICtrlCreateLabel(stringifyCoord($lastOre_coord), 60, 40, $gui_width)
;GUICtrlCreateLabel("Anvil: ", 5, 55)
;Local $id_anvilCoord = GUICtrlCreateLabel(stringifyCoord($anvil_coord), 60, 55, $gui_width)

; Modifiable Delays
GUICtrlCreateLabel("Lag Time: ", 5, 75)
Local $label_lagTime = GUICtrlCreateLabel('', 70, 75, 50, Null)
Local $button_decLagTime = GUICtrlCreateButton("\/", 110, 73, 20, 15)
Local $button_incLagTime = GUICtrlCreateButton("/\", 130, 73, 20, 15)
GUICtrlSetData($label_lagTime, $lag)
GUICtrlCreateLabel("Cooldown: ", 5, 90)
Local $label_cooldownTime = GUICtrlCreateLabel('', 70, 90, 50, Null)
Local $button_decCooldownTime = GUICtrlCreateButton("\/", 110, 88, 20, 15)
Local $button_incCooldownTime = GUICtrlCreateButton("/\", 130, 88, 20, 15)
GUICtrlSetData($label_cooldownTime, $superheat_cooldown)

; Metrics
GUICtrlCreateLabel("Bars Done", 5, 130)
Local $label_barsDone = GUICtrlCreateLabel(Null, 70, 130, 30, 15)
GUICtrlCreateLabel("/", 100, 130, 10, 15)
Local $label_barsTotal = GUICtrlCreateLabel(Null, 110, 130, 40, 15)
Local $button_changeBarsTotal = GUICtrlCreateButton("+", 150, 130, 18, 15)
GUICtrlCreateLabel("Cycle Time", 5, 145, 65, 15)
Local $label_cycleTime = GUICtrlCreateLabel(1234, 70, 145)
;GUICtrlCreateLabel("Forge Time", 5, 160, 65, 15)
;Local $label_forgeTime = GUICtrlCreateLabel(1234, 70, 160)

; Button Settings
;Local $button_ignoreForge = GUICtrlCreateButton("Ignore Forges", 0, $gui_height-80, $gui_width/2, 25)
;GUICtrlSetBkColor($button_ignoreForge, $COLOR_RED)
;Local $button_setCheckpoints = GUICtrlCreateButton("Top Right", $gui_width/2, $gui_height-80, $gui_width/2, 25)
;GUICtrlSetBkColor($button_setCheckpoints, $COLOR_RED)
;Local $button_stopAfterForge = GUICtrlCreateButton("Stop After Forge", 0, $gui_height-55, $gui_width/2, 25)
;GUICtrlSetBkColor($button_stopAfterForge, $COLOR_RED)
Local $button_toggleSafeClick = GUICtrlCreateButton("Safe Click", $gui_width/2, $gui_height-55, $gui_width/2, 25)
GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_RED)
Local $button_togglePause = GUICtrlCreateButton("SCRIPT IN ACTION", 0, $gui_height-30, $gui_width, 30)
GUICtrlSetBkColor($button_togglePause, $COLOR_RED)

; GUI Listeners
GUICtrlSetOnEvent($button_toggleSafeClick, "gui_toggleSafeClick")
GUICtrlSetOnEvent($button_incCooldownTime, "gui_incCooldownTime")
GUICtrlSetOnEvent($button_decCooldownTime, "gui_decCooldownTime")
GUICtrlSetOnEvent($button_incLagTime, "gui_incLagTime")
GUICtrlSetOnEvent($button_decLagTime, "gui_decLagTime")
GUICtrlSetOnEvent($button_changeBarsTotal, "gui_changeBarsTotal")
GUISetOnEvent($GUI_EVENT_CLOSE, "ends")
; Shows GUI1
GUISetState(@SW_SHOW, $hMainGUI)


;; Ini Parsing ;;
Func loadCoord($section, $key, ByRef $default)
	Local Const $EXPECTED = UBound($default, $UBOUND_ROWS)
	Local $data = IniRead( $SETTINGS_INI, $section, $key, "ERROR" )
	Local $data_split = StringSplit($data, ",", $STR_NOCOUNT)
	If @error or $data=="ERROR" Then
		; No configuration found or could not split properly
		ConsoleWrite(@TAB& "["& $section &"] - ["& $key &"] : No initialization found."& @LF)
		return $default
	EndIf
	If ($EXPECTED <> UBound($data_split, $UBOUND_ROWS)) Then
		; Found configuration does not match given array size
		ConsoleWrite(@TAB& "["& $section &"] - ["& $key &"] : Bad initialization."& @LF)
		ConsoleWrite(@TAB& "Given array does not match size of configuration" & @LF)
		return $default
	EndIf

	For $d=0 To $EXPECTED-1
		$default[$d] = $data_split[$d]
	Next

	ConsoleWrite("["& $section &"] - ["& $key &"] : Successfully initialized!"& @LF)
	return $default
 EndFunc

Func saveCoord($section, $key, ByRef $toSave)
	Local $dimensions = UBound($toSave, $UBOUND_DIMENSIONS)
	If ($dimensions == 1) Then
	   ; Normal 2 value array
	   Local $value = $toSave[0] & ',' & $toSave[1]
	Else
	   Local $value = $toSave[0][1] & ',' & $toSave[0][2] & ',' & $toSave[1][1] & ',' & $toSave[1][2]
	EndIf
	Local $data = IniWrite( $SETTINGS_INI, $section, $key, $value )
	ConsoleWrite("["& $section &"] - ["& $key &"] : Successfully saved!"& @LF)
	return $data
EndFunc

Func saveValue($section, $key, $toSave)
	Local $data = IniWrite( $SETTINGS_INI, $section, $key, $toSave )
	ConsoleWrite("["& $section &"] - ["& $key &"] : Successfully saved!"& @LF)
	return $data
 EndFunc

Func loadSpecialCoord($section, $key, ByRef $default)
	Local Const $EXPECTED = 4
	Local $data = IniRead( $SETTINGS_INI, $section, $key, "ERROR" )
	Local $data_split = StringSplit($data, ",", $STR_NOCOUNT)
	If @error or $data=="ERROR" Then
		; Could not parse
		; No configuration found or could not split properly
		ConsoleWrite(@TAB& "["& $section &"] - ["& $key &"] : No initialization found." & @LF)
		return $default
	EndIf
	Local $found = UBound($data_split, $UBOUND_ROWS)
	If ($EXPECTED <> $found) Then
		; Found configuration does not match given array size
		ConsoleWrite(@TAB& "["& $section &"] - ["& $key &"] : Bad initialization."& @LF)
		ConsoleWrite(@TAB& "Found "& $found &" of "& $EXPECTED &" coordinates"& @LF)
		ConsoleWrite(@TAB& "Found initialization value of ["& $data &"]"& @LF)
		return $default
	EndIf

	$default[0][0] = True
	$default[0][1] = $data_split[0]
	$default[0][2] = $data_split[1]
	$default[1][0] = False
	$default[1][1] = $data_split[2]
	$default[1][2] = $data_split[3]

	ConsoleWrite("["& $section &"] - ["& $key &"] : Successfully initialized!"& @LF)
	return $default
 EndFunc


Func loadValue($section, $key, $default)
	Local $data = IniRead( $SETTINGS_INI, $section, $key, "ERROR" )
	If @error or $data=="ERROR" Then
		; No configuration found or could not split properly
		ConsoleWrite(@TAB& "["& $section &"] - ["& $key &"] : No initialization found." & @LF)
		return $default
	EndIf
	ConsoleWrite("["& $section &"] - ["& $key &"] : Succesfully initialized!"& @LF)
	return $data
EndFunc



;; Begins ;;
TogglePause()

;; Essential Global Functions ;;
Func TogglePause()
	$Paused = NOT $Paused
	If($Paused) Then
		GUICtrlSetBkColor($button_togglePause, $COLOR_RED)
	EndIf

	While $Paused
		Sleep(100)
	WEnd

	GUICtrlSetBkColor($button_togglePause, $COLOR_GREEN)
EndFunc

Func ends()
	Exit
 EndFunc


;; Helper Methods ;;
Func _coordFromRange($coordRangeObject)
	Local $chosenCoord[2]
	$chosenCoord[0] = Random(_ArrayMin($coordRangeObject, 1, 0, 1, 1), _ArrayMax($coordRangeObject, 1, 0, 1, 1), 1)
	$chosenCoord[1] = Random(_ArrayMin($coordRangeObject, 1, 0, 1, 2), _ArrayMax($coordRangeObject, 1, 0, 1, 2), 1)
	Return $chosenCoord
EndFunc

Func safeClick($button, $coord, $type = 'exact')
	Local $MOUSE_MOVE_SPEED = Random(2, 9, 1)
	If($button <> 'left' and $button <> 'right') Then
		ConsoleWrite("FUNC safeClick: Improper value for $button. ["&$button&"] given. Left or right expected." & @LF)
		ends()
	EndIf
	; Modifies Coordinates By Type
	If($type == 'exact') Then
		; Do nothing
	ElseIf($type == 'range') Then
		$coord = _coordFromRange($coord)
	Else
		$coord = _coord($coord, $type)
	EndIf
	; Ensures Window Is Active
	If($safeClick) Then
		While NOT WinActive($windowName)
			Sleep(300)
			GUICtrlSetColor($button_toggleSafeClick, $COLOR_WHITE)
			Sleep(300)
			GUICtrlSetColor($button_toggleSafeClick, $COLOR_BLACK)
		WEnd
	EndIf
	MouseClick($button, $coord[0], $coord[1], 1, $MOUSE_MOVE_SPEED)
	Local $temp = [$coord[0], $coord[1]]
	Return $temp
EndFunc

; Accessed using 1: firstOption, 2: secondOption...
Func _dropDownMenu($base, $drilldownSelection)
   Local $firstClick_coords[2]
   Local $secondClick_coords[2]
   Local $clickType

   ; Makes Initial Right Click
   $firstClick_coords = safeClick('right', $base, 'range')

   ; Delay Between Clicks
   Sleep(200 + $lag/2 + Random(0, 300+$lag/4, 1))

   $secondClick_coords[0] = $firstClick_coords[0] + Random(-40, 40, 1)
   $secondClick_coords[1] = $firstClick_coords[1] + 20 - 8 + ($drilldownSelection * 16) + Random(-1 * 4, 4, 1)

   ; Clicks Option
   safeClick('left', $secondClick_coords, 'exact')
EndFunc


 ;; Main GUI Functions ;;
Func gui_toggleSafeClick()
	$safeClick = NOT $safeClick
	If($safeClick) Then
		GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_GREEN)
	Else
		GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_RED)
	EndIf
	WinActivate($windowName)
EndFunc

Func gui_incCooldownTime()
   $superheat_cooldown = $superheat_cooldown + 25
   saveValue("Settings", "superheatCooldown", $superheat_cooldown)
   GUICtrlSetData($label_cooldownTime, $superheat_cooldown)
   WinActivate($windowName)
EndFunc

Func gui_decCooldownTime()
	If ($superheat_cooldown >= 25) Then
		$superheat_cooldown = $superheat_cooldown - 25
	EndIf
	saveValue("Settings", "superheatCooldown", $superheat_cooldown)
	GUICtrlSetData($label_cooldownTime, $superheat_cooldown)
	WinActivate($windowName)
EndFunc

Func gui_incLagTime()
   $lag = $lag + 100
   saveValue("Settings", "lag", $lag)
   GUICtrlSetData($label_lagTime, $lag)
   WinActivate($windowName)
EndFunc

Func gui_decLagTime()
	If($lag >= 100) Then
		$lag = $lag - 100
	EndIf
	saveValue("Settings", "lag", $lag)
	GUICtrlSetData($label_lagTime, $lag)
	WinActivate($windowName)
EndFunc

Func gui_changeBarsTotal()
	$inputData = InputBox("Bars", "How many bars are you making?", '', '', 200, 150)
	; Removes ALL Spaces - (3)for leading and trailing only
	If(Execute(StringStripWS($inputData, 8)) == "") Then
		Return
	EndIf
	$bars_to_produce = Execute($inputData)
	$trip_limit = $bars_to_produce / $load_size
	$completed_trips = 0
	GUICtrlSetData($label_barsDone, 0)
	GUICtrlSetData($label_barsTotal, $bars_to_produce)
	WinActivate($windowName)
EndFunc


;; Store Coordinates ;;
Func stringifyCoord($coords)
	Local $stringified = ""
	; Looks at First Coord
	If($coords[0][1] == '' Or $coords[0][2] == '') Then
		$stringified = $stringified & 'NONE'
	Else
		$stringified = $stringified & $coords[0][1] & "," & $coords[0][2]
	EndIf
	$stringified = $stringified & "   --   "
	; Looks at Second Coord
	If($coords[1][1] == '' Or $coords[1][2] == '') Then
		$stringified = $stringified & 'NONE'
	Else
		$stringified = $stringified & $coords[1][1] & "," & $coords[1][2]
	EndIf
	Return $stringified
EndFunc

Func storeBankerCoords()
   setCoord($banker_coord, MouseGetPos())
   saveCoord("Coordinate Ranges", "banker", $banker_coord)
   GUICtrlSetData($id_bankerCoord, stringifyCoord($banker_coord))
EndFunc

Func storeCoalBagCoords()
   setCoord($coalBag_coord, MouseGetPos())
   saveCoord("Coordinate Ranges", "coalBag", $coalBag_coord)
   GUICtrlSetData($id_coalBagCoord, stringifyCoord($coalBag_coord))
EndFunc

Func storeLastOreCoords()
	setCoord($lastOre_coord, MouseGetPos())
	saveCoord("Coordinate Ranges", "lastOre", $lastOre_coord)
	GUICtrlSetData($id_lastOreCoord, stringifyCoord($lastOre_coord))
EndFunc

Func setCoord(ByRef $coordName, $coord, $coordNumber=-1)
	; New Coordinate
	If($coordName[0][0]=='' or $coordName[1][0]=='') Then
		$coordName[0][0] = True
		$coordName[1][0] = False
	EndIf
	If($coordNumber == -1) Then												; Not set by calling function
		If($coordName[0][0] == True) Then										; First coord wants to be set next or never set
			$coordNumber = 0													; Set first coord
		Else
			$coordNumber = 1													; Set second coord
		EndIf
	EndIf
	$coordName[$coordNumber][1] = $coord[0]									; Sets coordinate
	$coordName[$coordNumber][2] = $coord[1]									; Sets coordinate
	$coordName[0][0] = NOT $coordName[0][0]
	$coordName[1][0] = NOT $coordName[1][0]
EndFunc

;; Sets Pixels ;;
Func setAllCheckpoints()
   HotKeySet ("{F3}", "setReadyToAssignCheckpoint")
   HotKeySet ("{F4}", "skipCheckpoint")
   Global $READY_TO_SET_CHECKPOINT = False
   Global $MOVE_ON = False

   ; Set Bank Closed ;
   setCheckpointTooltip("Bank Is Closed", "Ideally a pixel that changes from dark/light on bank open/close.")
   setWaitInfo("bankClosed", $BANK_CLOSED, "bankClosed", $BANK_CLOSED_PIXEL)

   ; Set Bank Open ;
   setCheckpointTooltip("Bank Is Open", "Ideally a pixel that changes from dark/light on bank open/close.")
   setWaitInfo("bankOpen", $BANK_OPEN, "bankOpen", $BANK_OPEN_PIXEL)

   ; Set Superheat Spell is Not Cast-able ;
   setCheckpointTooltip("Superheat Spell is Greyed Out", "A pixel inside the spell when it is not cast-able.")
   setWaitInfo("superheat", $INACTIVE_SUPERHEAT_SPELL, "superheat", $INACTIVE_SUPERHEAT_SPELL_PIXEL)

   ToolTip("Everything has been setup!")
   Sleep(1300)
   ToolTip("")
   Return
EndFunc

Func setCheckpointTooltip($name, $description = "")
	ToolTip("Press F3 to set: [" & $name & "]" & @LF & $description & @LF & "Press F4 to skip this checkpoint.", 0, 0, "Checkpoint Setup Wizard")
	; Waits Before Setting and Moving On ;
	While $MOVE_ON == False
		Sleep(100)
	WEnd
EndFunc

Func setReadyToAssignCheckpoint()
	$MOVE_ON = True
	$READY_TO_SET_CHECKPOINT = True
EndFunc
Func skipCheckpoint()
	$MOVE_ON = True
	$READY_TO_SET_CHECKPOINT = False
EndFunc

Func setWaitInfo($coordKey, ByRef $coordsToSet, $pixelKey, ByRef $pixelToSet)
	If($READY_TO_SET_CHECKPOINT == False) Then
		$MOVE_ON = False
		Return
	EndIf

	Local Const $CLEAR_PIXEL_DELAY = 300
	$coordsToSet = MouseGetPos()
	If($pixelToSet <> null) Then
		MouseMove(0, 0, 0)
		Sleep($CLEAR_PIXEL_DELAY + $lag/2)
		$pixelToSet = PixelGetColor($coordsToSet[0], $coordsToSet[1])
		saveCoord("Coordinates", $coordKey, $coordsToSet)
		saveValue("Pixels", $pixelKey, $pixelToSet)
		MouseMove($coordsToSet[0], $coordsToSet[1], 0)
	EndIf
	$READY_TO_SET_CHECKPOINT = False
	$MOVE_ON = False
EndFunc




;; Waiting Functions ;;
Func wait_bankClosed($_wait)
	$wait =  $_wait
	$after = Random(0, $lag/2, 1)
	$pixel = $BANK_CLOSED_PIXEL
	$coord = $BANK_CLOSED
	ConsoleWrite("Waiting for bank to close...")
	Return waitOrPixel($wait, $pixel, $coord, $after)
EndFunc

Func wait_bankOpen($_wait)
	$wait =  $_wait
	$after = Random(0, $lag/2, 1)
	$pixel = $BANK_OPEN_PIXEL
	$coord = $BANK_OPEN
	ConsoleWrite("Waiting for bank to open...")
	Return waitOrPixel($wait, $pixel, $coord)
EndFunc

Func waitOrPixel($wait, $pixel, $coord, $extraWait = 0)
	Local $timeSlept = 0
	While $timeSlept <= $wait
		Sleep(100)
		$timeSlept = $timeSlept + 100
		Local $found = PixelSearch($coord[0]-1, $coord[1]-1, $coord[0]+1, $coord[1]+1, $pixel, 2)
		If NOT @error Then
			; Found Coordinate
			ConsoleWrite("Success" & @LF)
			If($extraWait > 0) Then
				Sleep($extraWait)
			EndIf
			Return True
		EndIf
	WEnd
	ConsoleWrite("TIMEOUT" & @LF)
	Return False
EndFunc

Func canSuperheat()
	Local $pixel = $INACTIVE_SUPERHEAT_SPELL_PIXEL
	Local $coord = $INACTIVE_SUPERHEAT_SPELL
	Local $found = PixelSearch($coord[0]-1, $coord[1]-1, $coord[0]+1, $coord[1]+1, $pixel, 2)
	If NOT @error Then
		; Found Pixel
		Return False
	EndIf
	Return True
EndFunc

#CS
Func finishedSuperheating($_wait)
	$wait =  $_wait
	$after = Random(0, $lag/2, 1)
	Local $pixel = $INACTIVE_SUPERHEAT_SPELL_PIXEL
	Local $coord = $INACTIVE_SUPERHEAT_SPELL
	ConsoleWrite("Superheating a bar... ")
	Return tryUntilDone($wait, $pixel, $coord)
EndFunc

Func tryUntilDone($wait, $pixel, $coord, $extraWait = 0)
	Local $timeSlept = 0
	While $timeSlept <= $wait
		Sleep(100)
		$timeSlept = $timeSlept + 100
		Local $found = PixelSearch($coord[0]-1, $coord[1]-1, $coord[0]+1, $coord[1]+1, $pixel, 2)
		If NOT @error Then
			; Found Coordinate
			ConsoleWrite("DONE EARLY" & @LF)
			If($extraWait > 0) Then
				Sleep($extraWait)
			EndIf
			Return True
		EndIf
	WEnd
	ConsoleWrite("Continuing" & @LF)
	Return False
EndFunc

Func moreOreExist()
	ConsoleWrite("Checking for unheated ore... ")
	Local $coord = $INACTIVE_SUPERHEAT_SPELL
	Local $pixel = $INACTIVE_SUPERHEAT_SPELL_PIXEL
	Local $found = PixelSearch($coord[0]-1, $coord[1]-1, $coord[0]+1, $coord[1]+1, $pixel, 2)
	If NOT @error Then
		; Found Coordinate
		ConsoleWrite("All done" & @LF)
		Return False
	Else
		ConsoleWrite("Found some" & @LF)
		Return True
	EndIf
EndFunc
#CE

;; Step Functions ;;
Func doOpenBank()
	ConsoleWrite("Trying To: OPEN BANK" & @LF)
	Local $success = False
	Local $tries = 0
	Do
		$tries = $tries + 1
		; Click Banker
		safeClick('left', $banker_coord, 'range')

		; Run to Banker
		$success = wait_bankOpen($runtime + $lag)
	Until ($tries >= 3 or $success)
	If ($success) Then
		Return True
	Else
		ConsoleWrite("Error: could not open the bank" & @LF)
		_ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
		TogglePause()
		Return False
	EndIf
EndFunc

Func doWithdrawAndCloseBank()
	ConsoleWrite("Trying To: WITHDRAW AND CLOSE BANK" & @LF)
	Local $success = False
	Local $tries = 0
	Do
		$tries = $tries + 1
		; Fill Coal Bag
		_dropDownMenu($coalBag_coord, 2)

		; Wait for Bag To Fill
		Sleep(100 + $lag + Random(0, 200, 1))

		; Withdraw Ores @ Preset #1
		Send($loadoutNumber)

		; Withdrawal Delay ;
		$success = wait_bankClosed(2600 + $lag)
	Until ($tries >= 3 or $success)
	If ($success) Then
		Return True
	Else
		ConsoleWrite("Error: could not withdraw and close the bank" & @LF)
		_ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
		TogglePause()
		Return False
	EndIf
EndFunc

Func doSuperheating()
	Local $spells_cast = 0
	Local Const $tryAgainThreshold = 5

	Do
		; Activate Superheat HotKeySet
		Send($superheat_key)

		; Register Spell Selection
		Sleep(Random(75, 150, 1))

		; Cast on Last Ore
		safeClick('left', $lastOre_coord, 'range')

		; Wait out Spell Animation
		Sleep($superheat_cooldown + Random(0, 50, 1))

		; Count Spell
		$spells_cast = $spells_cast + 1
    Until $spells_cast >= $load_size or canSuperheat() == False
	;Until (finishedSuperheating($superheat_cooldown + Random(0, 50, 1)) and $spells_cast > $load_size) or ($spells_cast >= $load_size + $tryAgainThreshold)
EndFunc


While 1
	; Record Start Cycle Timer
	$cycle_start_time = _NowCalc()

	; Open Bank
	doOpenBank()

	; Withdraw and Close Bank
	doWithdrawAndCloseBank()

	; Wait for Smithing
	doSuperheating()

	; Increment Metrics
	$completed_trips = $completed_trips + 1
	$cycleTime = _DateDiff('s', $cycle_start_time, _NowCalc())

	; Update Metrics
	GUICtrlSetData($label_barsDone, $completed_trips*$load_size)
	GUICtrlSetData($label_cycleTime, $cycleTime)
	Opt("SendKeyDownDelay", Random(100, 200, 1))

	; Should It Pause?
	If($completed_trips >= $trip_limit) Then
		TogglePause()
	EndIf
	ConsoleWrite(@LF)
WEnd
