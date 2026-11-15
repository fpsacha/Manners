# The game's friendly nameplates off, said where every player looks: the
# greeting, Start here while Quick setup asks, the launcher and the options
# window's strip, and a line when a stranger's buff lands with nobody to name
# (tests/scenarios/par.lua). Each fault is caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------------ greeting

mutate("Commands.lua",
       "\t\tif ns.FriendlyPlatesOff() then\n"
       "\t\t\taddon:Print(L[\"|cffff8080Friendly nameplates are off|r",
       "\t\tif false then\n"
       "\t\t\taddon:Print(L[\"|cffff8080Friendly nameplates are off|r",
       "par: the greeting silent on the nameplates",
       expect="the greeting promises strangers and says nothing of the nameplates", script=S)

mutate("Commands.lua",
       "\t\tif ns.FriendlyPlatesOff() then\n"
       "\t\t\taddon:Print(L[\"|cffff8080Friendly nameplates are off|r",
       "\t\tif true then\n"
       "\t\t\taddon:Print(L[\"|cffff8080Friendly nameplates are off|r",
       "par: the greeting blames nameplates that are on",
       expect="the nameplates are on and the greeting says off", script=S)

# ------------------------------------------------------ Start here, Quick setup

mutate("Options/Start.lua",
       "\t\tif entry.key == picked then return entry.set[\"sources.strangers\"] == true end\n",
       "\t\tif entry.key == picked then return false end\n",
       "par: no Quick setup pick wants passers-by",
       expect="Everyone near me picked", script=S)

mutate("Options/Start.lua",
       "\t\tif entry.key == picked then return entry.set[\"sources.strangers\"] == true end\n",
       "\t\tif entry.key == picked then return true end\n",
       "par: every Quick setup pick wants passers-by",
       expect="My group picked, and Start here still asks", script=S)

mutate("Options/Start.lua",
       "\t\t\t\tname = function() return Quick.Asking() and L[\"Seeing passers-by\"] or L[\"1. Who to buff\"] end,\n",
       "\t\t\t\tname = L[\"1. Who to buff\"],\n",
       "par: a second step 1 over the call during Quick setup",
       expect="the call is titled 1. Who to buff", script=S)

# -------------------------------------------------------------- launcher

mutate("Options/Launcher.lua",
       "\telseif Page.PlatesWanted and Page.PlatesWanted() then\n",
       "\telseif false then\n",
       "par: the launcher watches in green with the nameplates off",
       expect="nameplates off reads as", script=S)

mutate("Options/Launcher.lua",
       "L[\"Start here\"]), 1, 0.82, 0, true, nil, \"plates\"\n",
       "L[\"Start here\"]), 0.4, 0.9, 0.4, true, nil, \"plates\"\n",
       "par: the launcher's nameplates line green",
       expect="the line is not amber", script=S)

mutate("Options/Launcher.lua",
       "\t\treturn true, L[\"Watching your group -- friendly nameplates are off",
       "\t\treturn false, L[\"Watching your group -- friendly nameplates are off",
       "par: the launcher stops watching the group",
       expect="the group is still watched", script=S)

# ----------------------------------------------------------------- strip

mutate("Options/Window/WindowChrome.lua",
       "\tplates = true, placeheld = true, mana = true }\n",
       "\tplates = false, placeheld = true, mana = true }\n",
       "par: the strip says nothing of the nameplates",
       expect="When to offer's strip says", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tif kind == \"plates\" and PLATES_SAID_ON[UI.page] then return nil end\n",
       "",
       "par: the strip repeats Start here's note",
       expect="Start here says it twice", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\tlocal platesShown = not lockShown and strip.kind == \"plates\"",
       "\tlocal platesShown = false and strip.kind == \"plates\"",
       "par: no button on the strip",
       expect="no Show friendly nameplates button on the strip", script=S)

mutate("Options/Window/WindowChrome.lua",
       "\t\tif strip.platesItem and not UI.Disabled(strip.platesItem) then ns.WindowBind.Run(strip.platesItem) end\n",
       "",
       "par: the strip's button does nothing",
       expect="the strip's button made 0 changes", script=S)

# ------------------------------------------------- a buff with nobody to name

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] then Unnamed(key) end\n",
       "",
       "par: a buff with nobody to name goes unsaid",
       expect="a Fortitude from nobody the game would name", script=S)

mutate("Favours.lua",
       "\t\tif not source and ns.ALL_BUFF_IDS[key] then Unnamed(key) end\n",
       "\t\tif ns.ALL_BUFF_IDS[key] then Unnamed(key) end\n",
       "par: a named buff called unnamed",
       expect="a buff from somebody named, and the line says nobody", script=S)

mutate("Hints.lua",
       "\tif unnamedSaid then return false end\n",
       "",
       "par: the unnamed line at every buff",
       expect="said twice in a session", script=S)

mutate("Hints.lua",
       "\tif not ns.FriendlyPlatesOff() then return false end\n"
       "\tlocal hints = db.char.hints\n"
       "\tlocal told",
       "\tlocal hints = db.char.hints\n"
       "\tlocal told",
       "par: the unnamed line with the nameplates on",
       expect="the nameplates are on, and the line blames them", script=S)

mutate("Hints.lua",
       "\tif InCombatLockdown() or db.profile.silentChat == true then return false end\n"
       "\tif not ns.FriendlyPlatesOff()",
       "\tif db.profile.silentChat == true then return false end\n"
       "\tif not ns.FriendlyPlatesOff()",
       "par: the unnamed line in a fight",
       expect="said in a fight", script=S)

mutate("Hints.lua",
       "\tif told >= UNNAMED_SESSIONS then return false end\n",
       "",
       "par: the unnamed line every session for ever",
       expect="said on a fourth session", script=S)

mutate("Hints.lua",
       "\thints.unnamed = told + 1\n",
       "",
       "par: the unnamed line's sessions not counted",
       expect="the session is not counted", script=S)
