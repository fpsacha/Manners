# Mutations for a warlock's Firestone or Spellstone on WoW Forever (Buffs.lua's
# warlockstone kind and rows, Core.lua's dungeon hold, the layout slot). Each is
# caught by the scenario in tests/scenarios/warlockstones.lua that names it.

S = "runscenarios.py"

# The rows gone: no family at all.
mutate("Buffs.lua",
       "\t\twarlockstone = {\n\t\t\t{ 13701, 0, 1825, 17949, MELEE }, -- Major Firestone\n",
       "\t\twarlockstoneX = {\n\t\t\t{ 13701, 0, 1825, 17949, MELEE }, -- Major Firestone\n",
       "warlockstones: no rows for Forever",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# Every class given the warlock's stones.
mutate("Buffs.lua",
       "label = L[\"Firestone or Spellstone\"], only = \"WARLOCK\", mainHand = true },",
       "label = L[\"Firestone or Spellstone\"], mainHand = true },",
       "warlockstones: offered to every class",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# A family for the off hand too.
mutate("Buffs.lua",
       "label = L[\"Firestone or Spellstone\"], only = \"WARLOCK\", mainHand = true },",
       "label = L[\"Firestone or Spellstone\"], only = \"WARLOCK\" },",
       "warlockstones: a family for the off hand",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# A spellstone's enchant misread.
mutate("Buffs.lua",
       "\t\t\t{ 13603, 0, 8061, 1237159, MELEE }, -- Major Spellstone\n",
       "\t\t\t{ 13603, 0, 8060, 1237159, MELEE }, -- Major Spellstone\n",
       "warlockstones: the Major Spellstone's enchant wrong",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# The Lesser Firestone ahead of the Major one.
mutate("Buffs.lua",
       "\t\t\t{ 13701, 0, 1825, 17949, MELEE }, -- Major Firestone\n",
       "\t\t\t{ 1254, 0, 1803, 758, MELEE }, -- Lesser Firestone\n\t\t\t{ 13701, 0, 1825, 17949, MELEE }, -- Major Firestone\n",
       "warlockstones: not best first",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# Their length missing from Forever's table.
mutate("Buffs.lua",
       "\t\t{ 7200, 17949, 1237159, 17947, 1237156, 17945, 1237152, 758 }, -- firestones and spellstones (2 h, build 1.60.1.70790)\n",
       "",
       "warlockstones: no length",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# Listed as a temporary enchant, as an oil is. Core.lua learns the kind from the
# stone's own enchant once it is on (learnedKind), so the press scenarios recover;
# the data scenario holds the family to the Imbue kind.
mutate("Buffs.lua",
       "\tCAMELOT_KINDS.warlockstone = IMBUE\n",
       "\tCAMELOT_KINDS.warlockstone = TEMPORARY\n",
       "warlockstones: listed as a temporary enchant",
       expect="warlockstones: one family on Forever, a warlock's alone, for the main hand, best first", script=S)

# Held to dungeons and raids like an oil.
mutate("Core.lua",
       "\t\tif family.kind == \"warlockstone\" then return false end\n",
       "",
       "warlockstones: held to dungeons",
       expect="warlockstones: a switch under Myself, and not held to dungeons", script=S)

# The switch not placed on Who to buff's page.
mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t{ \"who.own_warlockstone\", indent = true },\n",
       "",
       "warlockstones: the switch is not placed on the page",
       expect="every control has one place in the options window", script=S)
