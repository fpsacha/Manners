# Mutations for a shaman's weapon imbues (Buffs.lua shamanimbue, Core.lua
# ReadImbue, Options/Who.lua, the layout and the length tables). Each is caught
# by the scenario in tests/scenarios/shamanimbue.lua (or the one named) that
# names it.

S = "runscenarios.py"

# up is an imbue of the main hand: without the flag the family is read as auras.
mutate("Buffs.lua",
       "\t\t\timbue = true,\n\t\t\tenchantKind = \"imbue\",\n\t\t\tspells = {\n\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362,",
       "\t\t\tenchantKind = \"imbue\",\n\t\t\tspells = {\n\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362,",
       "shamanimbue: read as an aura, not an imbue of the hand",
       expect="shamanimbue: an imbue on the main hand is not offered another", script=S)

# only an enchant of the Imbue kind counts: a stone is not one.
mutate("Buffs.lua",
       "\t\t\timbue = true,\n\t\t\tenchantKind = \"imbue\",\n\t\t\tspells = {\n\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362,",
       "\t\t\timbue = true,\n\t\t\tspells = {\n\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362,",
       "shamanimbue: any enchant on the hand counts",
       expect="shamanimbue: a stone or an oil on the hand is not an imbue", script=S)

# Windfury ahead of the rest for Automatic.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362, 10486, 8235, 8232 } },\n"
       "\t\t\t\t{ key = \"flametongueweapon\", ranks = { 16342, 16341, 16339, 8030, 8027, 8024 } },\n",
       "\t\t\t\t{ key = \"flametongueweapon\", ranks = { 16342, 16341, 16339, 8030, 8027, 8024 } },\n"
       "\t\t\t\t{ key = \"windfuryweapon\", ranks = { 16362, 10486, 8235, 8232 } },\n",
       "shamanimbue: Automatic does not take Windfury first",
       expect="shamanimbue: Automatic takes the first you know", script=S)

# the page's description is a scroll's.
mutate("Options/Who.lua",
       "\t\t\t\t\tif family.imbue and not family.spells[1].item then\n",
       "\t\t\t\t\tif false then\n",
       "shamanimbue: the page describes scrolls",
       expect="shamanimbue: the page says what an imbue reminder is", script=S)

# the control placed on the page.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_shamanimbue\", indent = true },\n",
       "",
       "shamanimbue: the control not placed on the page",
       expect="own_shamanimbue", script=S)

# every id the set holds has a length (Forever's: an hour).
mutate("Buffs.lua",
       "\t\t{ 3600, 16362, 10486, 8235, 8232 }, -- Windfury Weapon\n",
       "",
       "shamanimbue: Forever's Windfury has no length",
       expect="SHAMAN.windfuryweapon", script=S)
