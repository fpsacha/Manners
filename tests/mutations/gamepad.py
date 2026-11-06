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
       "or ns.GamepadActive() then\n\t\tCycle(row, values)",
       "then\n\t\tCycle(row, values)",
       "gamepad: a drop-down opens the menu with a gamepad on",
       expect="gamepad: an options drop-down goes to the next choice with a gamepad on", script=S)

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
