# Mutations for the controller button in the options window's key boxes
# (Options/Window/WidgetsChoice.lua). Caught by tests/scenarios/gamepad-key.lua.

S = "runscenarios.py"
F = "Options/Window/WidgetsChoice.lua"

mutate(F,
       "\tif row.button.EnableGamePadButton then row.button:EnableGamePadButton(true) end\n",
       "",
       "gamepad-key: a waiting box never takes the controller",
       expect="gamepad-key: a controller button pressed in The prompt's key binds the prompt to it", script=S)

mutate(F,
       "\tif row.button.EnableGamePadButton then row.button:EnableGamePadButton(false) end\n",
       "",
       "gamepad-key: a finished capture leaves the box holding the controller",
       expect="gamepad-key: the box takes no controller button unless it is waiting for one", script=S)

mutate(F,
       "\tif type(GetCVar) ~= \"function\" then return false end\n",
       "\tif true then return false end\n",
       "gamepad-key: a trigger that acts as Shift is taken as the key",
       expect="gamepad-key: a trigger set to act as Shift starts a chord, and the button after it binds SHIFT-", script=S)

mutate(F,
       "\t\tif b.EnableGamePadButton then\n\t\t\tb:SetScript(\"OnGamePadButtonDown\", function(self, key) ns.Guard(\"options key\", PadPressed, self, key) end)\n\t\tend\n",
       "",
       "gamepad-key: the box has no controller script",
       expect="gamepad-key: a controller button pressed in The prompt's key binds the prompt to it", script=S)

mutate(F,
       "\tif PadModifier(key) then return end\n\tTake(row, key)\n",
       "\tif PadModifier(key) then return end\n\tTake(row, \"PAD1\")\n",
       "gamepad-key: every controller button binds as PAD1",
       expect="gamepad-key: a trigger set to act as Shift starts a chord, and the button after it binds SHIFT-", script=S)
