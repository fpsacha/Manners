# Mutations for whispering the spoken line. Each is caught by the scenario in
# tests/scenarios/whisper.lua that names it.

# No whisper channel at all: the setting falls back to Say.
mutate("Speech.lua",
       "\tWHISPER = \"w\",\n",
       "",
       "no whisper channel",
       expect="whisper: a cross-realm name is whispered with its realm",
       script="runscenarios.py")

# The whisper without its name: "/w Thanks, Brom." whispers somebody called
# Thanks.
mutate("Speech.lua",
       "\t\t\tcommand = command .. \" \" .. whisperTo\n",
       "",
       "whisper leaves out the name",
       expect="whisper: a cross-realm name is whispered with its realm",
       script="runscenarios.py")

# Whispered by the /target spelling, which off Camelot has the realm taken off.
mutate("Speech.lua",
       "\t\tlocal name = ns.plain(entry.name)\n",
       "\t\tlocal name = ns.plain(entry.targetName or entry.name)\n",
       "whisper drops the realm",
       expect="whisper: a cross-realm name is whispered with its realm",
       script="runscenarios.py")

# A name that could break the macro let through.
mutate("Speech.lua",
       "\t\tif not (ns.SafeForMacro and ns.SafeForMacro(name)) then return nil end\n",
       "\t\tif type(name) ~= \"string\" then return nil end\n",
       "whisper name not checked for the macro",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# Control characters let through.
mutate("Speech.lua",
       "\t\tif name:find(\"%c\") then return nil end\n",
       "",
       "whisper name keeps control characters",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# A secret realm not noticed: the whisper goes to the bare name, on your realm.
mutate("Speech.lua",
       "\t\t\t\tif not ok or secret(first) or secret(second) then return nil end\n",
       "\t\t\t\tif not ok or secret(first) then return nil end\n",
       "secret realm whispered bare",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# The same with no unit: a bare name off the tokenless fallback whispered
# without asking the GUID whether a realm was withheld.
mutate("Speech.lua",
       "\t\telseif entry.targetName ~= nil and not name:find(\"[%s%-]\") then\n",
       "\t\telseif false then\n",
       "tokenless bare name never asked of its GUID",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# The GUID asked but its realm not read: a secret realm passes.
mutate("Speech.lua",
       "\t\t\tif not (ok and ns.plain(who) == name and ns.plain(realm) == \"\") then return nil end\n",
       "\t\t\tif not (ok and ns.plain(who) == name) then return nil end\n",
       "tokenless realm not read from the GUID",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# The GUID's name not compared: whoever it names now is taken for them.
mutate("Speech.lua",
       "\t\t\tif not (ok and ns.plain(who) == name and ns.plain(realm) == \"\") then return nil end\n",
       "\t\t\tif not (ok and ns.plain(realm) == \"\") then return nil end\n",
       "tokenless name not read from the GUID",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# Nothing accepted at all: the own-realm control gets no line either.
mutate("Speech.lua",
       "\t\t\tif not (ok and ns.plain(who) == name and ns.plain(realm) == \"\") then return nil end\n",
       "\t\t\treturn nil\n",
       "tokenless bare name never whispered",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# The stand-in exemption gone here too: Roll a few's one-word "Somebody" has no
# debt to ask, so Camelot's preview shows no whisper.
mutate("Speech.lua",
       "\t\telseif entry.targetName ~= nil and not name:find(\"[%s%-]\") then\n",
       "\t\telseif not name:find(\"[%s%-]\") then\n",
       "tokenless GUID check asked of stand-ins",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# A realm counted as missing whatever the name holds: every tokenless
# cross-realm name must now be vouched for by a GUID, and the control has none.
mutate("Speech.lua",
       "\t\telseif entry.targetName ~= nil and not name:find(\"[%s%-]\") then\n",
       "\t\telseif entry.targetName ~= nil then\n",
       "tokenless GUID check asked of a name with its realm",
       expect="whisper: a secret or unsafe name says nothing",
       script="runscenarios.py")

# The chat box's reading of the line never asked.
mutate("Speech.lua",
       "\t\tif line and whisperTo and entry.targetName ~= nil\n",
       "\t\tif false\n",
       "whisper parse not checked",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# The stand-in exemption turned inside out: real people skip the parse.
mutate("Speech.lua",
       "\t\tif line and whisperTo and entry.targetName ~= nil\n",
       "\t\tif line and whisperTo and entry.targetName == nil\n",
       "whisper parse asked of stand-ins only",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# The stand-in exemption gone: Roll a few shows nothing on Camelot.
mutate("Speech.lua",
       "\t\tif line and whisperTo and entry.targetName ~= nil\n",
       "\t\tif line and whisperTo\n",
       "whisper parse asked of stand-ins",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# Regional names walked as if they were realm names: "Munin Hugins" reads as
# Munin.
mutate("Speech.lua",
       "\t\tlocal more = regional and \"[%s-](%w+)%s\" or \"%s\"\n",
       "\t\tlocal more = \"%s\"\n",
       "whisper parse ignores regional names",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# The walk takes one word off and stops.
mutate("Speech.lua",
       "\t\twhile target and target:find(more) do\n",
       "\t\tif target and target:find(more) then\n",
       "whisper parse walks once",
       expect="whisper: Camelot whispers name and surname, and nothing it would misread",
       script="runscenarios.py")

# The client's own answer about regional names never asked.
mutate("Speech.lua",
       "\t\tlocal on = ns.safecall(_G.RegionalUniqueNamesEnabled)\n",
       "\t\tlocal on = nil\n",
       "regional names judged by flavour only",
       expect="whisper: the client's regional-names answer decides the parse",
       script="runscenarios.py")

# The budget measured without the name, so a long name and realm overrun it.
mutate("Speech.lua",
       "\t\tlocal line = Roll(db, entry, command, budget)\n",
       "\t\tlocal line = Roll(db, entry, command, budget + (whisperTo and #whisperTo + 1 or 0))\n",
       "whisper budget forgets the name",
       expect="whisper: the budget counts a long name and realm",
       script="runscenarios.py")

# The tooltip quoting the whisper's name as though it were said.
mutate("Speech.lua",
       "\t\t\tif target then rest = rest:sub(#target + 2) end\n",
       "",
       "tooltip quotes the whisper's name",
       expect="whisper: a cross-realm name is whispered with its realm",
       script="runscenarios.py")

mutate("Prompt.lua",
       "\t\tout[#out + 1] = L[\"Says: |cffffffff%s|r\"]:format(ns.SpokenText(phraseText))\n",
       "\t\tout[#out + 1] = L[\"Says: |cffffffff%s|r\"]:format((phraseText:gsub(\"^/%S+%s*\", \"\")))\n",
       "tooltip strips only the command",
       expect="whisper: a cross-realm name is whispered with its realm",
       script="runscenarios.py")

# The dropdown without the choice, or without saying who hears it.
mutate("Options.lua",
       "\t\t\t\t\t\t\tWHISPER = L[\"Whisper them\"] },\n",
       "\t\t\t\t\t\t\t},\n",
       "no Whisper them in the dropdown",
       expect="whisper: other channels unchanged",
       script="runscenarios.py")

mutate("Options.lua",
       "\t\t\t\t\t\tdesc = L[\"Who hears the line: Say and Emote reach players near you, Yell a wider area, Party and Raid your group. Whisper them sends it to the person you buff and nobody else.\"],\n",
       "",
       "Channel dropdown does not say who hears it",
       expect="whisper: other channels unchanged",
       script="runscenarios.py")
