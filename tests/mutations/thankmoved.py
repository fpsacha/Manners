# Mutations for the thank that waits (thankDelay) finding the giver again on
# another token (Favours.lua Holding). Each is caught by the scenario in
# tests/scenarios/thankmoved.lua that names it.

S = "runscenarios.py"
N = "thankmoved: "

mutate("Favours.lua",
       "\t\tlocal unit = ns.UnitFor(seen.name, seen.unit)\n",
       "\t\tlocal unit = nil\n",
       "thankmoved: a giver whose token moved is never looked for again",
       expect=N + "the giver on another token by the end of the pause is thanked there", script=S)

mutate("Favours.lua",
       "\t\tif Holds(seen, unit) then return unit end\n\t\treturn nil\n",
       "\t\tif unit then return unit end\n\t\treturn nil\n",
       "thankmoved: the token found by name is thanked without being checked",
       expect=N + "a namesake with another GUID is never thanked", script=S)

mutate("Favours.lua",
       "\t\tif Holds(seen, seen.unit) then return seen.unit end\n",
       "\t\tif type(seen.unit) == \"string\" then return seen.unit end\n",
       "thankmoved: the first token is thanked whoever holds it now",
       expect=N + "a token naming somebody else is never thanked", script=S)
