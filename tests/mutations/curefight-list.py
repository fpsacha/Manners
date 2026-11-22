# Mutations for what the cure line says about the game's list of debuffs you can
# remove (Prompt/CureFight.lua, Selftest.lua). Each is caught by the scenario in
# tests/scenarios/curefight-list.lua that names it.

S = "runscenarios.py"
CF = "Prompt/CureFight.lua"

mutate(CF,
       "last.listWithheld = last.listWithheld + 1",
       "last.listWithheld = last.listWithheld + 0",
       "curefight-list: a withheld list is never counted",
       expect="curefight-list: a withheld list is counted on the cure line", script=S)

mutate(CF,
       "elseif listed == 0 then",
       "elseif false then",
       "curefight-list: an empty list is never counted",
       expect="curefight-list: an empty list is counted on the cure line", script=S)

mutate(CF,
       "CanList() and (caps.secretRestrictions == true and \"yes\" or \"yes, not needed here\") or \"no\",",
       "\"yes\",",
       "curefight-list: the cure line always says the list is there",
       expect="curefight-list: the cure line says whether the game has the list", script=S)

mutate("Selftest.lua",
       " .. (lists and \"yes\" or \"no\") .. suffix)",
       " .. (lists and \"yes\" or \"no\"))",
       "curefight-list: the self-test never asks the list",
       expect="curefight-list: the self-test says what the game's list answers now", script=S)
