# The self-test's fight group (Selftest.lua, tests/scenarios/selftest-fight.lua):
# each fault put back has to be caught by the scenario that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

PASSING = "selftest-fight: cure buttons and keys pass when made and bound"
NEVER = "selftest-fight: a cure switched on and never made warns"
APIS = "selftest-fight: the fight APIs are reported as data on every client"
STONE = "selftest-fight: a warlock's healthstone counts, nothing for others"
MUTE = "selftest-fight: the mute list's shape, counts only"
SHIFT = "selftest-fight: a Shift key taken by another Manners key warns"

# A cure never made passes.
mutate("Selftest.lua",
       "\t\t\tadd(WARN, name .. \": switched on, but the button was never made\")\n",
       "\t\t\tadd(PASS, name .. \": switched on, but the button was never made\")\n",
       "selftest-fight: a cure never made passes",
       expect=NEVER,
       script=S)

# A header that is not at peace passes.
mutate("Selftest.lua",
       "\t\tif state ~= \"peace\" then\n",
       "\t\tif false then\n",
       "selftest-fight: a header not at peace passes",
       expect=NEVER,
       script=S)

# The cure's key is not read.
mutate("Selftest.lua",
       "\treturn key and (\"key \" .. key) or \"no key: a click on it casts\"\n",
       "\treturn \"no key: a click on it casts\"\n",
       "selftest-fight: the cure's key is not read",
       expect=PASSING,
       script=S)

# The game's list of removable debuffs is always yes.
mutate("Selftest.lua",
       "(lists and \"yes\" or \"no\")",
       "\"yes\"",
       "selftest-fight: the list of debuffs is always yes",
       expect=APIS,
       script=S)

# The stones in the bags are not counted.
mutate("Selftest.lua",
       "\tfor _, item in ipairs(spell.items or {}) do stones = stones + (ns.ReagentCount and ns.ReagentCount(item) or 0) end\n",
       "",
       "selftest-fight: the stones are not counted",
       expect=STONE,
       script=S)

# Everybody is a warlock.
mutate("Selftest.lua",
       "\tif Class() ~= \"WARLOCK\" then\n\t\tadd(PASS, \"not a warlock\")\n",
       "\tif false then\n\t\tadd(PASS, \"not a warlock\")\n",
       "selftest-fight: a mage is a warlock",
       expect=STONE,
       script=S)

# A list of a shape Manners does not read passes.
mutate("Selftest.lua",
       "\tif db and db.filters and db.filters.skipMuted == true and type(m.names) ~= \"table\" then\n",
       "\tif false then\n",
       "selftest-fight: an unreadable mute list passes",
       expect=MUTE,
       script=S)

# The mute list's names are counted by their own words.
mutate("Selftest.lua",
       "\t\tif type(t) ~= \"table\" then return type(t) end\n\t\tlocal n = 0\n\t\tfor _ in pairs(t) do n = n + 1 end\n\t\treturn \"table (\" .. n .. \")\"\n",
       "\t\tif type(t) ~= \"table\" then return type(t) end\n\t\tlocal n = {}\n\t\tfor k in pairs(t) do n[#n + 1] = tostring(k) end\n\t\treturn \"table (\" .. table.concat(n, \",\") .. \")\"\n",
       "selftest-fight: the mute list's names are listed",
       expect=MUTE,
       script=S)

# A Shift key taken by another Manners key passes.
mutate("Selftest.lua",
       "\t\tif byKey[shifted] then\n",
       "\t\tif false then\n",
       "selftest-fight: a taken Shift key passes",
       expect=SHIFT,
       script=S)

# One key on two commands passes.
mutate("Selftest.lua",
       "\t\t\tif byKey[row.key] then\n",
       "\t\t\tif false then\n",
       "selftest-fight: one key on two commands passes",
       expect=SHIFT,
       script=S)

# A fight key with no prompt key passes.
mutate("Selftest.lua",
       "\tif ns.FightKey and ns.FightKey.Applies(db) and not KeyOf(ns.Setup.COMMAND) then\n",
       "\tif false then\n",
       "selftest-fight: a fight key with no prompt key passes",
       expect=SHIFT,
       script=S)
