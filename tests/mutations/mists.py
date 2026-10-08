# Mists of Pandaria Classic made to run (tests/scenarios/mists.lua): its own
# set as the Mists client's data has it (Buffs.lua, MISTS_SET), and the mock
# held to the classic branch. Each fault put back has to be caught by the
# check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the set Mists is handed
# The Mists client in the mock restricting secrets again, which the classic
# branch's API documentation says it never does.
mutate("tests/mockapi.lua",
       "\t\tsecretRestrictions = false, weaponEnchantList = false, paperDoll = false,\n\t},\n\t-- Burning Crusade Classic Anniversary",
       "\t\tsecretRestrictions = true, weaponEnchantList = false, paperDoll = false,\n\t},\n\t-- Burning Crusade Classic Anniversary",
       "mists: the mock restricting secrets on Mists",
       expect="mists: Mists is read as mists and given the mists set",
       script=S)

# A Horn of Winter id the Mists client does not have: a death knight who has
# learned Horn of Winter is never found to know it, so it is never offered.
mutate("Buffs.lua",
       "{ key = \"hornofwinter\", ranks = { 57330 }, selfCast = true, partyOnly = true,",
       "{ key = \"hornofwinter\", ranks = { 57331 }, selfCast = true, partyOnly = true,",
       "mists: a death knight's shout under an id Mists lacks",
       expect="mists: a deathknight's buffs are found (IsSpellKnown)",
       script=S)

# ------------------------------------------------ already buffed
# Legacy of the Emperor matched by its cast's id alone: it lands as 117666 or
# 117667, so everybody wearing it reads as missing it.
mutate("Buffs.lua",
       "\t\t\tgroup = { 117666, 117667 },\n",
       "",
       "mists: Legacy of the Emperor's auras unmatched",
       expect="mists: a passer-by wearing a monk's Legacy is not offered it",
       script=S)

# Only the group aura: the one it lands as on a stranger is nobody's favour.
mutate("Buffs.lua",
       "\t\t\tgroup = { 117666, 117667 },\n",
       "\t\t\tgroup = { 117666 },\n",
       "mists: the Legacy a stranger gets you unmatched",
       expect="mists: Legacy of the Emperor from a stranger is read off the combat log (117667, deprecation fallbacks on)",
       script=S)

# Dalaran Brilliance no longer counted as Arcane Brilliance.
mutate("Buffs.lua",
       "\t\t\tgroup = { 61316 },\n",
       "",
       "mists: Dalaran Brilliance read as missing Brilliance",
       expect="mists: somebody wearing Dalaran Brilliance (61316) is read as having it",
       script=S)

# Arcane Brilliance held back from anybody without mana again: a warrior or a
# hunter (Focus on Mists) never offered the 5% critical strike it carries.
mutate("Buffs.lua",
       "\t\t\t-- mana bar either) as to a caster.\n\t\t},\n",
       "\t\t\t-- mana bar either) as to a caster.\n\t\t\tmanaOnly = true,\n\t\t},\n",
       "mists: Arcane Brilliance for mana users only",
       expect="mists: Arcane Brilliance is offered to a warrior and a hunter, who have no mana",
       script=S)

# A paladin's blessings taken to stack on Mists: the walk replaces the Kings
# you gave with your Might.
mutate("Buffs.lua",
       "\t-- the last click gave.\n\texclusive = { PALADIN = true },\n",
       "\t-- the last click gave.\n\texclusive = {},\n",
       "mists: blessings taken to stack",
       expect="mists: a paladin's blessings replace one another",
       script=S)

# ------------------------------------------------ favours
# Fear Ward, Water Walking and Soulstone no longer favours on Mists.
mutate("Buffs.lua",
       "\tfavourOnly = { 6346, 546, 20707 },\n",
       "",
       "mists: no favour-only buffs on Mists",
       expect="mists: a Fear Ward from somebody is a favour",
       script=S)

# ------------------------------------------------ reach
# A Legacy taken to reach your own party only, so a stranger is never offered
# one.
mutate("Buffs.lua",
       "ranks = { 115921 }, -- Legacy of the Emperor",
       "ranks = { 115921 }, partyOnly = true, -- Legacy of the Emperor",
       "mists: a monk's Legacy kept to the party",
       expect="mists: a stranger is targeted by their own name (monk)",
       script=S)

# The vanilla subgroup rule on Mists, whose shouts reach the whole raid.
mutate("Buffs.lua",
       "\trankLevel = MISTS_RANK_LEVEL,\n",
       "\trankLevel = MISTS_RANK_LEVEL,\n\tpartyIsSubgroup = true,\n",
       "mists: a shout kept to its raid group",
       expect="mists: Battle Shout reaches a raider in another raid group",
       script=S)

# ------------------------------------------------ the levels
# Vanilla's rank levels read on Mists: a level-40 mage taken for one who casts
# Arcane Brilliance (58) and skipped.
mutate("Buffs.lua",
       "\trankLevel = MISTS_RANK_LEVEL,\n",
       "",
       "mists: Mists' levels left out of its set",
       expect="mists: a mage below Arcane Brilliance's level is not skipped as one who has it",
       script=S)

mutate("Buffs.lua",
       "\tif chosen.rankLevel then ns.RANK_LEVEL = chosen.rankLevel end\n",
       "",
       "mists: a set's own levels never read",
       expect="mists: Mists is read as mists and given the mists set",
       script=S)

# White Tiger taken for something every monk has, and skipped for one who has
# only the Emperor.
mutate("Buffs.lua",
       "\t\t\t-- monk knows it.\n\t\t\ttalent = true,\n",
       "\t\t\t-- monk knows it.\n",
       "mists: White Tiger not a talent",
       expect="mists: a monk is still offered White Tiger, which Windwalkers alone have",
       script=S)

# ------------------------------------------------ your own buffs
# Nothing of their own for any class on Mists, as before: a mage with
# nothing up is never reminded of her armor.
mutate("Buffs.lua",
       "\town = MISTS_OWN,\n",
       "\town = {},\n",
       "mists: no own buffs on Mists",
       expect="mists: a mage's own buff is offered when none of its family is up",
       script=S)

# Inner Will out of the priest's family: a priest in Inner Will is told to
# put Inner Fire over it.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"innerwill\", ranks = { 73413 } },\n",
       "",
       "mists: Inner Will not of Inner Fire's family",
       expect="mists: a priest's own buff is offered when none of its family is up",
       script=S)

# Water Shield out of the shaman's family.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"watershield\", ranks = { 52127 } },\n",
       "",
       "mists: Water Shield not of the shield family",
       expect="mists: a shaman's own buff is offered when none of its family is up",
       script=S)

# Earth Shield out of the shaman's family: a Restoration shaman wearing her
# own is told to put Lightning Shield over it, which replaces it.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"earthshield\", ranks = { 974 }, neverAuto = true, talent = true, charges = 9,\n"
       "\t\t\t\t\tcastOnOthers = true },\n",
       "",
       "mists: Earth Shield not of the shield family",
       expect="mists: a shaman's own buff is offered when none of its family is up (with Earth Shield)",
       script=S)

# Earth Shield remembered like the others: once it has been up on her, it is
# what she is reminded of, in a group too, where it belongs on the tank.
mutate("Buffs.lua",
       "{ key = \"earthshield\", ranks = { 974 }, neverAuto = true, talent = true, charges = 9,",
       "{ key = \"earthshield\", ranks = { 974 }, talent = true, charges = 9,",
       "mists: Earth Shield picked by Automatic",
       expect="mists: a shaman's own Earth Shield is her shield, and never what Automatic reminds her of",
       script=S)

# Earth Shield's charges forgotten: down to its last one or two it is left to
# run out.
mutate("Buffs.lua",
       "{ key = \"earthshield\", ranks = { 974 }, neverAuto = true, talent = true, charges = 9,",
       "{ key = \"earthshield\", ranks = { 974 }, neverAuto = true, talent = true,",
       "mists: Earth Shield's charges forgotten",
       expect="mists: a shaman's own Earth Shield down to its last charges is topped up",
       script=S)

# Aspect of the Hawk ahead of the talent that replaces it.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"aspectironhawk\", ranks = { 109260 }, talent = true },\n"
       "\t\t\t\t{ key = \"aspecthawk\", ranks = { 13165 } },\n",
       "\t\t\t\t{ key = \"aspecthawk\", ranks = { 13165 } },\n"
       "\t\t\t\t{ key = \"aspectironhawk\", ranks = { 109260 }, talent = true },\n",
       "mists: the Hawk offered over the Iron Hawk",
       expect="mists: a hunter's own buff is offered when none of its family is up (with Aspect of the Iron Hawk)",
       script=S)

# Mage Armor first: a mage who knows all three armors (80 and up), with none
# up and none remembered, is offered Mage Armor rather than Molten. (Below 80
# the order cannot matter: FirstKnown passes over an armor she has not
# learned.)
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"moltenarmor\", ranks = { 30482 } },\n"
       "\t\t\t\t{ key = \"frostarmor\", ranks = { 7302 } },\n"
       "\t\t\t\t{ key = \"magearmor\", ranks = { 6117 } },\n",
       "\t\t\t\t{ key = \"magearmor\", ranks = { 6117 } },\n"
       "\t\t\t\t{ key = \"moltenarmor\", ranks = { 30482 } },\n"
       "\t\t\t\t{ key = \"frostarmor\", ranks = { 7302 } },\n",
       "mists: Mage Armor ahead of Molten",
       expect="mists: a mage's own buff is offered when none of its family is up",
       script=S)

# An armor timed like vanilla's: offered as a top-up while it is up.
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"magearmor\", ranks = { 6117 } },\n\t\t\t},\n\t\t\ttoggle = true,\n",
       "\t\t\t\t{ key = \"magearmor\", ranks = { 6117 } },\n\t\t\t},\n",
       "mists: an armor topped up",
       expect="mists: an armor is never a top-up",
       script=S)

# The priest's family under a key the options window does not place: the
# control is in the model and nowhere on Who to buff.
mutate("Buffs.lua",
       "\t\t\tkey = \"innerfire\",\n\t\t\tspells = {\n",
       "\t\t\tkey = \"inner\",\n\t\t\tspells = {\n",
       "mists: Inner Fire's family off the options window",
       expect="mists: the options window builds with MenuUtil",
       script=S)
