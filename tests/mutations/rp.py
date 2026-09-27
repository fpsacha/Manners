# Mutations for the "In character" phrase set (Phrases.lua and its hooks in
# Core.lua and Options.lua). Each is caught by the scenario in
# tests/scenarios/rp.lua that names it.

# The hook in ns.PickPhrase never taken: the set speaks its examples as lines.
mutate("Core.lua",
       "\t\tif inCharacter and inCharacter.Active(db.speech) then\n",
       "\t\tif false then\n",
       "in character never asked by PickPhrase",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A set that writes its own text, read as a list of lines it does not have.
mutate("Core.lua",
       "\tif set.text then return set.text() end\n",
       "",
       "a per-character set read as a list",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# An allied race left out of its people.
mutate("Phrases.lua",
       '\tDwarf = "dwarf", DarkIronDwarf = "dwarf", EarthenDwarf = "dwarf",\n',
       '\tDwarf = "dwarf", EarthenDwarf = "dwarf",\n',
       "dark iron dwarves not dwarves",
       expect="rp: every race speaks with its own people",
       script="runscenarios.py")

# A favour returned with an offer's words.
mutate("Phrases.lua",
       '\tlocal KIND = { owed = "thanks", asked = "asked", group = "group" }\n',
       '\tlocal KIND = { asked = "asked", group = "group" }\n',
       "thanks said as an offer",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# A group member hears none of their people's offers.
mutate("Phrases.lua",
       '\t\treturn tbl[kind] or (kind == "group" and tbl.offer) or nil\n',
       "\t\treturn tbl[kind]\n",
       "no race lines in a group",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# The friendlier group lines never said.
mutate("Phrases.lua",
       "\t\t\tadd(RP.GENERAL.group, weight.group)\n",
       "",
       "no group lines",
       expect="rp: reasons pick their own lines",
       script="runscenarios.py")

# The general lines gone outside a group, so a people repeats itself.
mutate("Phrases.lua",
       "\t\t\tadd(RP.GENERAL[kind], weight.general)\n",
       "",
       "no general lines",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A people's own lines weighed no more than anybody's.
mutate("Phrases.lua",
       "RP.WEIGHT = { race = 3, kin = 6, faction = 2, general = 1, group = 2 }\n",
       "RP.WEIGHT = { race = 1, kin = 6, faction = 2, general = 1, group = 2 }\n",
       "race lines not weighted highest",
       expect="rp: a dwarf of the Alliance thanks like one",
       script="runscenarios.py")

# A faction the client would not name taken as it came.
mutate("Phrases.lua",
       '\t\tif faction ~= "Alliance" and faction ~= "Horde" then faction = "Neutral" end\n',
       "",
       "no neutral fallback",
       expect="rp: a pandaren with no faction yet",
       script="runscenarios.py")

# Every line kept whatever the room, so a long name pushes the hand-back off.
mutate("Phrases.lua",
       '\t\t\t\t\tif said ~= "" and #line <= budget then\n',
       '\t\t\t\t\tif said ~= "" then\n',
       "in character lines not measured",
       expect="rp: every line fits the macro with a long name",
       script="runscenarios.py")

# A line built around the spell said with a hole where it would go.
mutate("Phrases.lua",
       '\t\t\t\t\tand (buff or not text:find("{buff}", 1, true))\n',
       "",
       "spell lines said without a spell",
       expect="rp: no hole where a spell name would go",
       script="runscenarios.py")

# Kin never greeted.
mutate("Phrases.lua",
       "\t\tif RP.IsKin(entry, family) then",
       "\t\tif false then",
       "kin never greeted",
       expect="rp: kin is greeted as kin",
       script="runscenarios.py")

# Kin read off a token that has moved on to somebody else.
mutate("Phrases.lua",
       "\t\tif not ok or name == nil or name ~= entry.name then return false end\n",
       "\t\tif not ok then return false end\n",
       "kin read off a recycled token",
       expect="rp: kin is greeted as kin",
       script="runscenarios.py")

# Only this character's examples count as untouched, so a shared profile's
# set reads as edited on every other character.
mutate("Phrases.lua",
       "\t\t\tfor family in pairs(RP.RACE) do\n"
       "\t\t\t\tif text == RP.Examples(family, faction) then answer = true end\n"
       "\t\t\tend\n",
       "\t\t\tif text == RP.Text() then answer = true end\n",
       "shared profile loses in character",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# The set never listed in the dropdown.
mutate("Phrases.lua",
       'table.insert(ns.PHRASE_SET_ORDER, 2, "incharacter")\n',
       "",
       "in character not listed",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# Every line rolled, the favours only or not.
mutate("Phrases.lua",
       "\t\tif speech and speech.onlyWhenReturning then rows = { ROLL[1], ROLL[1], ROLL[1] } end\n",
       "",
       "roll ignores only when returning",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")

# The box shows the examples the profile was saved with, not this character's.
mutate("Options.lua",
       "\t\t\t\t\t\t\tif ns.InCharacter and ns.InCharacter.Active(SP()) then\n"
       "\t\t\t\t\t\t\t\treturn ns.PhraseSetText(\"incharacter\")\n",
       "\t\t\t\t\t\t\tif false then\n"
       "\t\t\t\t\t\t\t\treturn ns.PhraseSetText(\"incharacter\")\n",
       "box shows another character's examples",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# The dropdown blank on a character sharing the profile.
mutate("Options.lua",
       "\t\t\t\t\t\t\tif ns.InCharacter and ns.InCharacter.Active(SP()) then return choice end\n",
       "",
       "dropdown blank on a shared profile",
       expect="rp: load the set, share it, edit it",
       script="runscenarios.py")

# Roll a few rolls the box's examples as though they were the lines.
mutate("Options.lua",
       "\t\t\t\t\t\t\t\tns.InCharacter.Roll(L[\"Somebody\"])\n"
       "\t\t\t\t\t\t\t\treturn\n",
       "",
       "roll a few ignores in character",
       expect="rp: roll a few rolls a line per reason",
       script="runscenarios.py")
