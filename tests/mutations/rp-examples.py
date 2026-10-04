# Mutations for the "In character" phrase box's examples (Phrases.lua's
# RP.Examples, RP.Active and RP.Repair). Each is caught by the scenario in
# tests/scenarios/rp-examples.lua that names it.

S = "runscenarios.py"

# The box back to eight lines, one of each of a few pools, which the owner
# read as everything the set would say.
mutate("Phrases.lua",
       "\t\t\tfor i = 1, older and (before or 0) or now do\n",
       "\t\t\tfor i = 1, before or 0 do\n",
       "rp examples back to eight lines",
       expect="the box shows only", script=S)

# Every character shown a mage's lines.
mutate("Phrases.lua",
       '\t\tput(PoolFor(pools.CLASS[class], "offer"), 2, 1)\n',
       '\t\tput(PoolFor(pools.CLASS.MAGE, "offer"), 2, 1)\n',
       "rp examples show another class's lines",
       expect="the box shows a line that is not the character's own", script=S)

# Anybody's kin line where the people has its own.
mutate("Phrases.lua",
       "put(general.group, 0, 1) put(race.kin or pools.KIN, 1)\n",
       "put(general.group, 0, 1) put(pools.KIN, 1)\n",
       "rp examples show everybody's kin line",
       expect="the box shows a line that is not the character's own", script=S)

# The general group line kept from the older box, which is nobody's own.
mutate("Phrases.lua",
       "put(general.group, 0, 1) put(race.kin or pools.KIN, 1)\n",
       "put(general.group, 1, 1) put(race.kin or pools.KIN, 1)\n",
       "rp examples show the general group line",
       expect="the box shows a line that is not the character's own", script=S)

# No line of the people's own hours.
mutate("Phrases.lua",
       "\t\tif race then put(race.night, 1) put(race.morning, 1) end\n",
       "",
       "rp examples show no hour of the people's",
       expect="the box shows no race.night line", script=S)

# The box 1.5.0 saved read as the player's own lines.
mutate("Phrases.lua",
       "\tlocal SAVED = { TODAY, { false, RP.BEFORE }, { true, RP.BEFORE } }\n",
       "\tlocal SAVED = { TODAY, { false, RP.BEFORE } }\n",
       "rp examples 1.5.0 box lost",
       expect="a Forsaken mage's 1.5.0 box counts as edited", script=S)

# ...and taken for today's by the load repair, so it stays eight lines.
mutate("Phrases.lua",
       "\t\tlocal forms = older and SAVED or { TODAY }\n",
       "\t\tlocal forms = SAVED\n",
       "rp examples 1.5.0 box never repaired",
       expect="a Forsaken mage's 1.5.0 box was not turned into today's", script=S)

# The box 1.6.4 saved, before the trolls' examples were reworded, read as
# the player's own lines.
mutate("Phrases.lua",
       "\tlocal SAVED = { TODAY, { false, RP.BEFORE }, { true, RP.BEFORE } }\n",
       "\tlocal SAVED = { TODAY, { true, RP.BEFORE } }\n",
       "rp examples 1.6.4 box lost",
       expect="a troll mage's 1.6.4 box counts as edited", script=S)

# The pools of saved boxes made of today's lines: a reworded example forgotten.
mutate("Phrases.lua",
       "\t\tRP.BEFORE[name] = Before(RP[name])\n",
       "\t\tRP.BEFORE[name] = RP[name]\n",
       "rp examples reworded lines forgotten",
       expect="a troll mage's 1.5.0 box counts as edited", script=S)

# The old lines left whole on another language's client, where the box
# they filled had a line without a translation left out.
mutate("Phrases.lua",
       "\t\tRP.BEFORE = Keep(RP.BEFORE)\n",
       "",
       "rp examples old lines not thinned abroad",
       expect="a troll mage's German 1.6.4 box, a line left out, counts as edited", script=S)

# beta.9's five lines read as the player's own.
mutate("Phrases.lua",
       "\t\t\t\tif older and text == Frozen(family, faction, english) then return true end\n",
       "",
       "rp examples beta.9 box lost",
       expect="a Forsaken's beta.9 box counts as edited", script=S)

# An edited box taken for the set because it begins like the examples.
mutate("Phrases.lua",
       "\t\t\t\t\t\t\tif text == Examples(family, faction, class or nil, english, form[1], form[2]) then\n",
       "\t\t\t\t\t\t\tif true then\n",
       "rp examples an edited box read as the set",
       expect="today's box and a line of the player's counts as In character", script=S)

# English examples built from the translations: a box saved in English
# before the lines were translated reads as edited.
mutate("Phrases.lua",
       "\t\treturn english and ENGLISH[text] or text\n",
       "\t\treturn text\n",
       "rp examples english box lost abroad",
       expect="1.5.0's box in English counts as edited on deDE", script=S)

# The box on another language's client shown in English.
mutate("Phrases.lua",
       "\t\treturn english and ENGLISH[text] or text\n",
       "\t\treturn ENGLISH[text] or text\n",
       "rp examples show english abroad",
       expect="the box shows an untranslated line on deDE", script=S)

# Two lines translated alike both shown.
mutate("Phrases.lua",
       "\t\t\t\tif older or not seen[text] then\n",
       "\t\t\t\tif true then\n",
       "rp examples show a line twice",
       expect="the box shows a line twice on deDE", script=S)

# ...and 1.5.0's box rebuilt checked for them, which it never was.
mutate("Phrases.lua",
       "\t\t\t\tif older or not seen[text] then\n",
       "\t\t\t\tif not seen[text] then\n",
       "rp examples rebuild 1.5.0's box without its twin",
       expect="1.5.0's German box with two lines alike counts as edited", script=S)
