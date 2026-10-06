# Burning Crusade Classic Anniversary made to run (tests/scenarios/tbc.lua):
# its own set in Buffs.lua, every rank and group version the 2.5.6 client has,
# the levels they are learned at, the class's own families with their new
# members, and the mock standing in for the client. Each fault put back has
# to be caught by the check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the set the client is handed
mutate("Buffs.lua",
       "\tname = \"tbc\",\n",
       "\tname = \"vanilla\",\n",
       "tbc: the set named vanilla",
       expect="tbc: Burning Crusade is read as tbc and given its own set",
       script=S)

# Forever's reach on this client: a group spell taken to cover the whole raid.
mutate("Buffs.lua",
       "\tname = \"tbc\",\n",
       "\tname = \"tbc\",\n\tgroupIsRaid = true,\n",
       "tbc: a group spell taken to reach the raid",
       expect="tbc: a group cast is aimed at one raid group and counts that group alone",
       script=S)

# The mock claiming secret restrictions the branch does not have.
mutate("tests/mockapi.lua",
       "\t\tproject = WOW_PROJECT_BURNING_CRUSADE_CLASSIC,\n"
       "\t\tcombatLog = true, surnames = false, unitBuff = true,\n"
       "\t\tconditionalTargeting = true,\n"
       "\t\tsecretRestrictions = false,",
       "\t\tproject = WOW_PROJECT_BURNING_CRUSADE_CLASSIC,\n"
       "\t\tcombatLog = true, surnames = false, unitBuff = true,\n"
       "\t\tconditionalTargeting = true,\n"
       "\t\tsecretRestrictions = true,",
       "tbc: the mock with secret restrictions",
       expect="tbc: Burning Crusade is read as tbc and given its own set",
       script=S)

# ------------------------------------------------ ranks and group versions
mutate("Buffs.lua",
       "\t\t\tranks = { 27126, 10157, 10156, 1461, 1460, 1459 },\n",
       "\t\t\tranks = { 10157, 10156, 1461, 1460, 1459 },\n",
       "tbc: Arcane Intellect's sixth rank gone",
       expect="tbc: a mage's buffs are found (IsSpellKnown)",
       script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 27127, 23028 },\n",
       "\t\t\tgroup = { 23028 },\n",
       "tbc: Arcane Brilliance's second rank not a group version",
       expect="tbc: a mage reads every rank and group version of its buffs as worn",
       script=S)

mutate("Buffs.lua",
       "\t\t\tgroupCast = { Rank(27127, ARCANE_POWDER), Rank(23028, ARCANE_POWDER) },\n",
       "\t\t\tgroupCast = { Rank(23028, ARCANE_POWDER) },\n",
       "tbc: Arcane Brilliance's second rank never cast",
       expect="tbc: a mage's buffs are found (C_SpellBook)",
       script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 25389, 10938, 10937, 2791, 1245, 1244, 1243 },\n",
       "\t\t\tranks = { 10938, 10937, 2791, 1245, 1244, 1243 },\n",
       "tbc: Fortitude's seventh rank gone",
       expect="tbc: a priest's buffs are found (IsSpellKnown)",
       script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 32999, 27681 },\n",
       "\t\t\tgroup = { 27681 },\n",
       "tbc: Prayer of Spirit's second rank not a group version",
       expect="tbc: a priest reads every rank and group version of its buffs as worn",
       script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 25433, 10958, 10957, 976 },\n",
       "\t\t\tranks = { 10958, 10957, 976 },\n",
       "tbc: Shadow Protection's fourth rank gone",
       expect="tbc: a priest reads every rank and group version of its buffs as worn",
       script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 26990, 9885, 9884, 8907, 5234, 6756, 5232, 1126 },\n",
       "\t\t\tranks = { 9885, 9884, 8907, 5234, 6756, 5232, 1126 },\n",
       "tbc: Mark of the Wild's eighth rank gone",
       expect="tbc: a druid's buffs are found (IsSpellKnown)",
       script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 26992, 9910, 9756, 8914, 1075, 782, 467 },\n",
       "\t\t\tranks = { 9910, 9756, 8914, 1075, 782, 467 },\n",
       "tbc: Thorns' seventh rank gone",
       expect="tbc: a druid reads every rank and group version of its buffs as worn",
       script=S)

mutate("Buffs.lua",
       "\t\t\tranks = { 27142, 25290, 19854, 19853, 19852, 19850, 19742 },\n",
       "\t\t\tranks = { 25290, 19854, 19853, 19852, 19850, 19742 },\n",
       "tbc: Blessing of Wisdom's seventh rank gone",
       expect="tbc: a paladin's buffs are found (IsSpellKnown)",
       script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 27141, 25916, 25782 },\n",
       "\t\t\tgroup = { 25916, 25782 },\n",
       "tbc: Greater Might's third rank not a group version",
       expect="tbc: a paladin reads every rank and group version of its buffs as worn",
       script=S)

mutate("Buffs.lua",
       "\t\t\tgroup = { 27169, 25899 },\n",
       "\t\t\tgroup = { 25899 },\n",
       "tbc: Greater Sanctuary's second rank not a group version",
       expect="tbc: a paladin reads every rank and group version of its buffs as worn",
       script=S)

# ------------------------------------------------ reagents
mutate("Buffs.lua",
       "Rank(25392, SACRED_CANDLE)",
       "Rank(25392, HOLY_CANDLE)",
       "tbc: Prayer of Fortitude's third rank on a Holy Candle",
       expect="tbc: a group spell's best rank eats its own reagent (Prayer of Fortitude, holy candles only)",
       script=S)

mutate("Buffs.lua",
       "Rank(26991, WILD_QUILLVINE)",
       "Rank(26991, WILD_THORNROOT)",
       "tbc: Gift of the Wild's third rank on Wild Thornroot",
       expect="tbc: a group spell's best rank eats its own reagent (Gift of the Wild, thornroot only)",
       script=S)

# ------------------------------------------------ shouts
mutate("Buffs.lua",
       "\t\t\tranks = { 2048, 25289, 11551, 11550, 11549, 6192, 5242, 6673 },\n",
       "\t\t\tranks = { 25289, 11551, 11550, 11549, 6192, 5242, 6673 },\n",
       "tbc: Battle Shout's eighth rank gone",
       expect="tbc: a party wearing Battle Shout is offered Commanding Shout",
       script=S)

mutate("Buffs.lua",
       "\t\t\tkey = \"commandingshout\",\n\t\t\tranks = { 469 },\n\t\t\tselfCast = true,\n",
       "\t\t\tkey = \"commandingshout\",\n\t\t\tranks = { 469 },\n",
       "tbc: Commanding Shout aimed at a target",
       expect="tbc: a party wearing Battle Shout is offered Commanding Shout",
       script=S)

mutate("Buffs.lua",
       "\t\t{\n\t\t\tkey = \"commandingshout\",\n\t\t\tranks = { 469 },\n\t\t\tselfCast = true,\n"
       "\t\t\tpartyOnly = true,\n\t\t},\n",
       "",
       "tbc: no Commanding Shout",
       expect="tbc: a warrior's buffs are found (IsSpellKnown)",
       script=S)

# ------------------------------------------------ the levels the new ranks land at
mutate("Buffs.lua",
       "\t[27126] = 70, [25389] = 70, [25433] = 68, [26990] = 70, [26992] = 64,\n",
       "\t[25389] = 70, [25433] = 68, [26990] = 70, [26992] = 64,\n",
       "tbc: Arcane Intellect's sixth rank with no level",
       expect="tbc: a level-70 wearing the rank below is offered the new one (mage)",
       script=S)

mutate("Buffs.lua",
       "[25433] = 68, [26990] = 70, [26992] = 64,\n",
       "[25433] = 68, [26990] = 70, [26992] = 54,\n",
       "tbc: Thorns' seventh rank learned at 54",
       expect="tbc: a level-70 wearing the rank below is offered the new one (druid)",
       script=S)

mutate("Buffs.lua",
       "\t[27142] = 65, [27140] = 70, [27144] = 69, [25312] = 70,\n",
       "\t[27140] = 70, [27144] = 69, [25312] = 70,\n",
       "tbc: Blessing of Wisdom's seventh rank with no level",
       expect="tbc: a level-70 wearing the rank below is offered the new one (paladin)",
       script=S)

mutate("Buffs.lua",
       "[26990] = 70, [26992] = 64,\n\t[27142] = 65, [27140] = 70, [27144] = 69, [25312] = 70,\n",
       "[26990] = 70, [26992] = 64,\n\t[27142] = 65, [27140] = 70, [27144] = 69,\n",
       "tbc: Divine Spirit's fifth rank with no level",
       expect="tbc: a level-70 wearing the rank below is offered the new one (priest)",
       script=S)

# ------------------------------------------------ your own
mutate("Buffs.lua",
       "\t\t\t\t{ key = \"moltenarmor\", ranks = { 30482 } },\n",
       "",
       "tbc: no Molten Armor",
       expect="tbc: a mage wearing Molten Armor is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"frostarmor\", ranks = { 27124, 10220,",
       "\t\t\t\t{ key = \"frostarmor\", ranks = { 10220,",
       "tbc: Ice Armor's fifth rank gone",
       expect="tbc: a mage wearing Molten Armor is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"felarmor\", ranks = { 28189, 28176 } },\n",
       "",
       "tbc: no Fel Armor",
       expect="tbc: a warlock wearing Fel Armor is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\t\t\tdungeon = \"felarmor\",\n",
       "",
       "tbc: no dungeon pick for a warlock",
       expect="tbc: a warlock is offered Fel Armor in a dungeon and Demon Armor outside one",
       script=S)

mutate("Buffs.lua",
       "{ key = \"crusaderaura\", ranks = { 32223 }, neverAuto = true },",
       "{ key = \"crusaderaura\", ranks = { 32223 } },",
       "tbc: Automatic picks Crusader Aura",
       expect="tbc: Automatic never picks crusaderaura",
       script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"crusaderaura\", ranks = { 32223 }, neverAuto = true },\n",
       "",
       "tbc: no Crusader Aura",
       expect="tbc: a paladin wearing Crusader Aura is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"aspectviper\", ranks = { 34074 } },\n",
       "",
       "tbc: no Aspect of the Viper",
       expect="tbc: a hunter wearing Aspect of the Viper is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\t\t\t\t{ key = \"watershield\", ranks = { 33736, 24398 }, charges = 3 },\n",
       "\t\t\t\t{ key = \"watershield\", ranks = { 408510 }, talent = true },\n",
       "tbc: Forever's Water Shield",
       expect="tbc: a shaman wearing Water Shield is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "talent = true, neverAuto = true, charges = 6 },",
       "talent = true, charges = 6 },",
       "tbc: Automatic picks Earth Shield",
       expect="tbc: Automatic never picks earthshield",
       script=S)

mutate("Buffs.lua",
       "\t\t\tspells = { { key = \"innerfire\", ranks = { 25431, 10952,",
       "\t\t\tspells = { { key = \"innerfire\", ranks = { 10952,",
       "tbc: Inner Fire's seventh rank gone",
       expect="tbc: a priest wearing Inner Fire is not reminded of the rest of the family",
       script=S)

mutate("Buffs.lua",
       "\tspells[#spells + 1] = { key = \"findfish\", ranks = { 43308 } }\n",
       "",
       "tbc: Find Fish not tracking",
       expect="tbc: Find Fish on counts as tracking up",
       script=S)

# ------------------------------------------------ favours
mutate("Buffs.lua",
       "\tfavourOnly = { 6346, 546, 132, 27239, 20765,",
       "\tfavourOnly = { 6346, 546, 132, 20765,",
       "tbc: the sixth Soulstone no favour",
       expect="tbc: a buff from a stranger is read off the combat log (the sixth Soulstone)",
       script=S)

mutate("Phrases.lua",
       "[20765] = \"soulstone\", [27239] = \"soulstone\",",
       "[20765] = \"soulstone\",",
       "tbc: the sixth Soulstone thanked as nothing",
       expect="tbc: a gift at a Burning Crusade rank is thanked as what it is",
       script=S)
