# Reopening settings must not leave the key-binding field holding focus.

mutate("Options/Window/Window.lua",
       """local function ReleaseKeyboard()
	local W = ns.WindowWidgets
	if W and W.StopCapture then W.StopCapture() end
	local focus = type(GetCurrentKeyBoardFocus) == "function" and GetCurrentKeyBoardFocus() or nil
	if InWindow(focus) and type(focus.ClearFocus) == "function" then focus:ClearFocus() end
end
""",
       "local function ReleaseKeyboard() end\n",
       "issue60-options-input: the options window keeps its keyboard focus",
       expect="window: closing options releases the player's keyboard focus",
       script="runscenarios.py")
