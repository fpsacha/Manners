# Mutations for "Below it, still offer" (filters.manaFloorKeeps: Queue.lua
# ns.ManaFloorKeeps, ns.ManaFloorKept, BuildQueue's manaHoldsAsked and
# SelfEntry; Core.lua's default and repair; Options/When.lua; the layout; the
# page's reset; every line that says what the floor keeps). Each is caught by
# the scenario in tests/scenarios/manakeeps.lua (or model-window.lua) that
# names it.

S = "runscenarios.py"

# ------------------------------------------------ what is held back
mutate("Queue.lua",
       "\tlocal manaHoldsAsked = savingMana and ns.ManaFloorKeeps(db) ~= \"asked\"\n",
       "\tlocal manaHoldsAsked = false\n",
       "manakeeps: favours and requests never held back",
       expect="manakeeps: only my own buff holds favours and requests back", script=S)

mutate("Queue.lua",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\" or manaHoldsAsked) then\n",
       "\t\tif savingMana and (reason == \"group\" or reason == \"nearby\") then\n",
       "manakeeps: the walk offers favours and requests below the floor",
       expect="somebody in the party was offered below the floor", script=S)

mutate("Queue.lua",
       "\t\t\tif manaHoldsAsked then break end\n",
       "",
       "manakeeps: the tokenless favour offered below the floor",
       expect="a favour nobody can see was offered below the floor", script=S)

mutate("Queue.lua",
       "\t\t\tor (not nearby and dropAsked)\n",
       "",
       "manakeeps: a remembered asker offered below the floor",
       expect="somebody who asked was offered from memory below the floor", script=S)

mutate("Queue.lua",
       "\tif sweep.saving and ns.ManaFloorKeeps(db) == \"none\" then return nil end\n",
       "",
       "manakeeps: Nothing keeps your own buff",
       expect="offered below the floor with Nothing", script=S)

mutate("Queue.lua",
       "\tif sweep.saving and ns.ManaFloorKeeps(db) == \"none\" then return nil end\n",
       "\tif ns.ManaFloorKeeps(db) == \"none\" then return nil end\n",
       "manakeeps: Nothing holds your own buff above the floor",
       expect="your own buff and the favour did not come back with the mana", script=S)

mutate("Queue.lua",
       "\t\treturn KEEPS[keeps] and keeps or \"asked\"\n",
       "\t\treturn \"asked\"\n",
       "manakeeps: the choice is never read",
       expect="manakeeps: only my own buff holds favours and requests back", script=S)

# ------------------------------------------------ the setting
mutate("Core.lua",
       "\t\t\tmanaFloorKeeps = \"asked\",\n",
       "\t\t\tmanaFloorKeeps = \"self\",\n",
       "manakeeps: the default moved",
       expect="the default is", script=S)

mutate("Core.lua",
       "\toneOf(profile.filters, \"manaFloorKeeps\", { asked = true, self = true, none = true }, \"asked\")\n",
       "",
       "manakeeps: a damaged value kept",
       expect="a damaged value was kept", script=S)

mutate("Core.lua",
       "\toneOf(profile.filters, \"manaFloorKeeps\", { asked = true, self = true, none = true }, \"asked\")\n",
       "\toneOf(profile.filters, \"manaFloorKeeps\", { asked = true, none = true }, \"asked\")\n",
       "manakeeps: the repair undoes Only my own buff",
       expect="the repair undid Only my own buff", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"when.manaFloorKeeps\", indent = true },\n",
       "",
       "manakeeps: the choice not placed under the slider",
       expect="the choice is not indented right under the slider", script=S)

mutate("Options/Advanced.lua",
       "\"filters.manaFloor\", \"filters.manaFloorKeeps\",\n",
       "\"filters.manaFloor\",\n",
       "manakeeps: When to offer's reset leaves the choice",
       expect="model: the reset puts when back", script=S)

mutate("Options/When.lua",
       "\t\t\t\tdisabled = function() return not ((tonumber(F().manaFloor) or 0) > 0) end,\n",
       "\t\t\t\tdisabled = function() return false end,\n",
       "manakeeps: the choice live with the floor off",
       expect="the choice is live with the floor at 0", script=S)

mutate("Options/When.lua",
       "\t\t\t\tsorting = { \"asked\", \"self\", \"none\" },\n\t\t\t\thidden = noManaBar,\n",
       "\t\t\t\tsorting = { \"asked\", \"self\", \"none\" },\n",
       "manakeeps: the choice on a warrior's page",
       expect="the choice is on a warrior's page", script=S)

# ------------------------------------------------ the lines
mutate("Queue.lua",
       "\tif keeps == \"self\" and own then return \"self\" end\n",
       "",
       "manakeeps: the lines call your own buff nothing",
       expect="manakeeps: the lines say what is kept (self)", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\telseif kept == \"self\" then\n\t\t\t\t\t\treturn L[",
       "\t\t\t\t\telseif false then\n\t\t\t\t\t\treturn L[",
       "manakeeps: the slider's description leaves the choice out",
       expect="the slider's description says", script=S)

mutate("Options/When.lua",
       "\t\t\t\t\telseif kept == \"self\" then\n\t\t\t\t\t\ttext = L[",
       "\t\t\t\t\telseif false then\n\t\t\t\t\t\ttext = L[",
       "manakeeps: the note leaves the choice out",
       expect="the note under the slider says", script=S)

mutate("Commands.lua",
       "\t\t\t\tor kept == \"self\"\n\t\t\t\tand L[\"|cffffd100saving mana|r",
       "\t\t\t\tor false\n\t\t\t\tand L[\"|cffffd100saving mana|r",
       "manakeeps: /manners debug leaves the choice out",
       expect="/manners debug says", script=S)

mutate("Prompt/Button.lua",
       "\t\t\tor keptNow == \"self\"\n",
       "\t\t\tor false\n",
       "manakeeps: the tooltip leaves the choice out",
       expect="the tooltip says", script=S)

mutate("Prompt/Press.lua",
       "\t\t\tlocal line = kept == \"askedself\"\n",
       "\t\t\tlocal line = kept ~= \"self\"\n",
       "manakeeps: an empty press leaves the choice out",
       expect="an empty press says", script=S)
