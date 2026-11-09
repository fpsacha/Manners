# Mutations for the client's own menus with a gamepad on (Core.lua
# GamepadActive, Options/Launcher.lua, Options/Window/WidgetsChoice.lua and
# WindowChrome.lua). Each is caught by the scenario in tests/scenarios/gamepad.lua
# that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\treturn ns.safecall(enabled) == true\n",
       "\treturn false\n",
       "gamepad: never read as on",
       expect="gamepad: ns.GamepadActive follows the client, and no API is no gamepad", script=S)

mutate("Options/Launcher.lua",
       "\t\tand not ns.GamepadActive()\nend",
       "\nend",
       "gamepad: the launcher's menu opens with a gamepad on",
       expect="gamepad: the launcher's right click opens the menu, and not with a gamepad on", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "or ns.GamepadActive() then\n\t\tOpenList(field, row, values)",
       "then\n\t\tOpenList(field, row, values)",
       "gamepad: a drop-down opens the menu with a gamepad on",
       expect="gamepad: an options drop-down opens Manners' own list with a gamepad on", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "\tPaintList()\n\tlist.screen:Show()\n",
       "\tPaintList()\n",
       "gamepad: the list never shows",
       expect="gamepad: an options drop-down opens Manners' own list with a gamepad on", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "\tif key ~= nil then Pick(row, key) end\n",
       "",
       "gamepad: picking from the list does nothing",
       expect="gamepad: an options drop-down opens Manners' own list with a gamepad on", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "\tscreen:SetFrameStrata(\"FULLSCREEN_DIALOG\")\n",
       "",
       "gamepad: the list draws under the window",
       expect="gamepad: an options drop-down opens Manners' own list with a gamepad on", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "\tscreen:SetScript(\"OnClick\", function() ns.Guard(\"options list\", CloseList) end)\n",
       "",
       "gamepad: a click away leaves the list open",
       expect="gamepad: a click away from the list closes it and changes nothing", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "if not (list.field and list.field:IsVisible()) then",
       "if false then",
       "gamepad: the list outlives the window",
       expect="gamepad: the list shuts with the window", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "\t\tif IsChosen(row, v[1]) and i > LIST_ROWS then list.offset = i - 1 end\n",
       "",
       "gamepad: a long list opens at its top",
       expect="gamepad: a long list opens at the choice and scrolls", script=S)

mutate("Options/Window/WidgetsChoice.lua",
       "ScrollList, direction * (LIST_ROWS - 1))",
       "ScrollList, 0)",
       "gamepad: the list's arrows do nothing",
       expect="gamepad: a long list opens at the choice and scrolls", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tif ns.GamepadActive() then\n\t\tlocal B, start = ns.WindowBind, nil\n",
       "\tif false then\n\t\tlocal B, start = ns.WindowBind, nil\n",
       "gamepad: Snooze opens the menu with a gamepad on",
       expect="gamepad: the options window's Snooze button needs no menu with a gamepad on", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\t\t\tif item.key == \"snoozeStop\" then\n\t\t\t\t\tns.Guard(\"options snooze\", B.Run, item)\n",
       "\t\t\t\tif false then\n\t\t\t\t\tns.Guard(\"options snooze\", B.Run, item)\n",
       "gamepad: Snooze never stops a snooze",
       expect="gamepad: the options window's Snooze button needs no menu with a gamepad on", script=S)
