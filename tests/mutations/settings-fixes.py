# Round 30, the settings (Commands.lua, Options/Start.lua, Buffs.lua,
# Core.lua): the raid groups in a settings string, an own profile only
# visited, a string from another game client, and NaN in a bounded number.
# Each fault is caught by the scenario in tests/scenarios/settings-fixes.lua
# that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ raid groups

# Not a set of its own: the walk goes into the empty default and finds nothing,
# so the groups never travel and an import never puts them back.
mutate("Commands.lua",
       "\t\t\t\t\t\telseif name == \"filters.skipRaidGroups\" then\n",
       "\t\t\t\t\t\telseif false then\n",
       "settings-fix: raid groups not shared",
       expect="settings-fix: an export carries the raid groups switched off", script=S)

# Read back as the text "2" rather than group 2, which the repair then drops.
mutate("Commands.lua",
       "\t\t\t\tout[tonumber(part)] = true\n",
       "\t\t\t\tout[part] = true\n",
       "settings-fix: raid groups read as text",
       expect="settings-fix: a string's raid groups are read as group numbers", script=S)

# Any digit taken for a raid group, a ninth among them.
mutate("Commands.lua",
       "\t\t\t\tif not part:match(\"^[1-8]$\") then return nil end\n",
       "\t\t\t\tif not part:match(\"^%d$\") then return nil end\n",
       "settings-fix: raid group 9 read",
       expect="settings-fix: a string's raid groups are read as group numbers", script=S)

# ------------------------------------------------ own profile

# Back on the old rule: anything in it, the repair's stamps included, counts.
mutate("Options/Start.lua",
       "\treturn type(own) == \"table\" and not OnlyVisited(own)\n",
       "\treturn type(own) == \"table\" and next(own) ~= nil\n",
       "settings-fix: an own profile only visited counts",
       expect="settings-fix: an own profile only visited is filled from the shared one", script=S)

# Every phrase box taken for the one the repair fills, the player's own too.
mutate("Options/Start.lua",
       "\t\t\t\tif k ~= \"phrases\" or not (v == ns.PhraseSetText(\"roleplay\")\n"
       "\t\t\t\t\tor ns.EnglishPhraseSet(v) == \"roleplay\") then\n",
       "\t\t\t\tif k ~= \"phrases\" then\n",
       "settings-fix: typed lines taken for the repair's",
       expect="settings-fix: an own profile with lines typed on it is gone back to", script=S)

# ------------------------------------------------ other clients

# Another client's own buff counted as a later version's setting.
mutate("Commands.lua",
       "\t\t\t\telseif (ns.OWN_FAMILY_ANY_CLIENT or {})[name:match(\"^ownBuffs%.pick%.([%w_]+)$\") or \"\"] then\n",
       "\t\t\t\telseif false then\n",
       "settings-fix: another client's family called newer",
       expect="settings-fix: a camelot string read on tbc is not called newer", script=S)

# ...or every own buff skipped without a word, a later version's included.
mutate("Commands.lua",
       "\t\t\t\telseif (ns.OWN_FAMILY_ANY_CLIENT or {})[name:match(\"^ownBuffs%.pick%.([%w_]+)$\") or \"\"] then\n",
       "\t\t\t\telseif name:match(\"^ownBuffs%.pick%.([%w_]+)$\") then\n",
       "settings-fix: every own buff skipped silently",
       expect="settings-fix: an own buff no client has is still called newer", script=S)

# The families of this client only, which are fields already.
mutate("Buffs.lua",
       "for _, set in pairs(SETS) do\n\tfor _, families in pairs(set.own or {}) do\n",
       "for _, set in pairs({ chosen }) do\n\tfor _, families in pairs(set.own or {}) do\n",
       "settings-fix: other clients' families unknown",
       expect="settings-fix: a tbc string read on camelot is not called newer", script=S)

# ------------------------------------------------ NaN

# NaN taken for a number, which no bound then catches.
mutate("Core.lua",
       "\t\tlocal number = type(value) == \"number\" and value == value\n",
       "\t\tlocal number = type(value) == \"number\"\n",
       "settings-fix: NaN kept in a bounded number",
       expect="settings-fix: a NaN in a saved number is put back to its default", script=S)
