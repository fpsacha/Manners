# Retail Midnight made ready (tests/scenarios/mainline.lua). Each fault put
# back has to be caught by the scenario it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the set retail is handed
# Forever's set on retail: vanilla ranks nobody there has, the mage's scrolls.
mutate("Buffs.lua",
       "\tmainline = MAINLINE_SET,\n",
       "\tmainline = CAMELOT_SET,\n",
       "mainline: retail handed Forever's set",
       expect="mainline: retail is read as Midnight and given the mainline set",
       script=S)

# The interface band missing retail: read by the project id alone, as a guess.
mutate("Flavour.lua",
       "\t{ flavour = \"mainline\", family = \"modern\", min = 100000, max = 999999 },\n",
       "\t{ flavour = \"mainline\", family = \"modern\", min = 1000000, max = 9999999 },\n",
       "mainline: retail's interface number in no band",
       expect="mainline: retail is read as Midnight and given the mainline set",
       script=S)

# The combat log probed on a client known to have none: a registration that
# can raise ADDON_ACTION_FORBIDDEN with Manners' name on it.
mutate("Core.lua",
       "\t\tif caps.recognised and caps.family == \"modern\" then\n\t\t\tcaps.combatLogProbe = nil\n",
       "\t\tif false then\n\t\t\tcaps.combatLogProbe = nil\n",
       "mainline: the combat log probed on retail",
       expect="mainline: retail is read as Midnight and given the mainline set",
       script=S)

# The interface number and the project id taken to disagree: the self-test's
# client line goes to WARN on every retail session.
mutate("Flavour.lua",
       "\t\t\tout.agrees = (project.family == band.family)\n",
       "\t\t\tout.agrees = false and (project.family == band.family)\n",
       "mainline: the project id read as disagreeing",
       expect="mainline: a mage's session runs clean",
       script=S)

# ------------------------------------------------ the data
# A Skyfury id one off: unknown on retail, so no shaman ever offers it.
mutate("Buffs.lua",
       "\t\t{ key = \"skyfury\", ranks = { 462854 } },\n",
       "\t\t{ key = \"skyfury\", ranks = { 462853 } },\n",
       "mainline: Skyfury's id wrong",
       expect="mainline: every buff is retail's own id with retail's flags",
       script=S)

# One of the thirteen class auras of the Blessing dropped: a warrior wearing
# it reads as missing it, and is blessed again and again.
mutate("Buffs.lua",
       "\t\t\t\t381752, 381753, 381754, 381756, 381757, 381758,\n",
       "\t\t\t\t381752, 381753, 381754, 381756, 381757,\n",
       "mainline: the warrior's Blessing of the Bronze aura dropped",
       expect="mainline: an evoker's bronze worn as 381758 reads as buffed",
       script=S)

# Arcane Intellect for everybody again: a warrior passing by is offered it.
mutate("Buffs.lua",
       "\t\t\t-- default) promises.\n\t\t\tmanaOnly = true,\n",
       "\t\t\t-- default) promises.\n",
       "mainline: Arcane Intellect offered to players without mana",
       expect="mainline: a warrior passing by is not offered Arcane Intellect",
       script=S)

# Source of Magic on Automatic's walk: moved from one passer-by to the next.
mutate("Buffs.lua",
       "\t\t\t-- pinned, and to whoever asks for it by name (ns.AskOnlyBuffs).\n\t\t\tneverAuto = true,\n",
       "\t\t\t-- pinned, and to whoever asks for it by name (ns.AskOnlyBuffs).\n",
       "mainline: Source of Magic walked by Automatic",
       expect="mainline: Automatic never moves Source of Magic from one passer-by to the next",
       script=S)

# The favour-only spells gone: a Soulstone from your party is nobody's favour.
mutate("Buffs.lua",
       "\tfavourOnly = { 20707, 546, 5697 },\n",
       "",
       "mainline: no favour-only spells on retail",
       expect="mainline: a Soulstone from a party member is a favour (20707)",
       script=S)

# Retail's paladin auras gone from the set: with heals counted, every walk
# back into a party paladin's range is a favour, a debt and a /thank.
mutate("Buffs.lua",
       "\tnotFavour = { [465] = true, [317920] = true, [32223] = true, [183435] = true },\n",
       "",
       "mainline: a party paladin's aura a favour",
       expect="mainline: a party paladin's aura is never a favour, with heals counted",
       script=S)

# The aura scan no longer asking: the same, by the code.
mutate("Favours.lua",
       "\t\t\t\t\t\t\tand not ns.NOT_FAVOUR_IDS[spellId]\n",
       "",
       "mainline: party auras not filtered from favours",
       expect="mainline: a party paladin's aura is never a favour, with heals counted",
       script=S)

# The vanilla trainers' levels on retail: Arcane Intellect at 1, and a mage
# of 5 who cannot cast it is passed over with "Skip my own class" on.
mutate("Buffs.lua",
       "\tif chosen.rankLevel then ns.RANK_LEVEL = chosen.rankLevel end\n",
       "",
       "mainline: vanilla's learning levels on retail",
       expect="mainline: Skip my own class reads retail's levels (Arcane Intellect at 8)",
       script=S)

# Unending Breath's gift lines out of reach: on retail no buff holds 5697.
mutate("Phrases.lua",
       "\t\t[5697] = \"breath\",\n",
       "",
       "mainline: Unending Breath favour without gift lines",
       expect="mainline: a favour of Unending Breath has its gift lines",
       script=S)

# ------------------------------------------------ asked for by name
# Source of Magic, never Automatic's, no longer reached by a request naming it.
mutate("Requests.lua",
       "\t\t\t\tif askOnly and request.keys ~= ASK.ANY then\n",
       "\t\t\t\tif false then\n",
       "mainline: Source of Magic asked for and not offered",
       expect="mainline: an evoker offers Source of Magic to whoever asks for it by name",
       script=S)

# ...and the asker let go the moment their nameplate does.
mutate("Queue.lua",
       "\tif askOnly and memo.reason == \"asked\" then\n",
       "\tif false then\n",
       "mainline: an asker for Source of Magic not remembered",
       expect="mainline: an evoker offers Source of Magic to whoever asks for it by name",
       script=S)

# The per-spell switch ignored: Source of Magic switched off on the options
# page, and offered to whoever asks all the same.
mutate("Core.lua",
       "\t\tif buff.neverAuto and ns.IsBuffKnown(buff) and not (skip and skip[buff.key]) then\n",
       "\t\tif buff.neverAuto and ns.IsBuffKnown(buff) then\n",
       "mainline: a switched-off Source of Magic offered when asked",
       expect="mainline: an evoker offers Source of Magic to whoever asks for it by name",
       script=S)

# Battle Shout held to one raid subgroup, as vanilla's is.
mutate("Buffs.lua",
       "\tname = \"mainline\",\n\tbuffs = MAINLINE,\n",
       "\tname = \"mainline\",\n\tbuffs = MAINLINE,\n\tpartyIsSubgroup = true,\n",
       "mainline: retail's shout held to one subgroup",
       expect="mainline: Battle Shout in a raid reaches every subgroup, and nobody outside it",
       script=S)

# ------------------------------------------------ mana, by class
# A retail hunter taken for a mana user where his power is withheld.
mutate("Core.lua",
       "if (ns.Flavour and ns.Flavour.flavour) == \"mainline\" then MANA_CLASSES.HUNTER = nil end\n",
       "",
       "mainline: a retail hunter read as having mana",
       expect="mainline: a hunter is not taken for a mana user",
       script=S)

# ------------------------------------------------ names
# A realm joined as a surname off Camelot: "Petra Ravencrest", which no
# /target finds.
mutate("Core.lua",
       "\treturn (ns.Flavour and ns.Flavour.flavour) == \"camelot\"\n",
       "\treturn (ns.Flavour and ns.Flavour.flavour) ~= \"vanilla\"\n",
       "mainline: a realm taken for a surname on retail",
       expect="mainline: a stranger from another realm is filed with the realm and targeted without it",
       script=S)

# ------------------------------------------------ knowing your spells
# The deprecated IsSpellKnown and IsPlayerSpell only: with
# Blizzard_DeprecatedSpellBook not loaded, every class knows nothing.
mutate("Core.lua",
       "\t\tlocal book = C_SpellBook\n\t\tif type(book) == \"table\" then\n",
       "\t\tlocal book = C_SpellBook\n\t\tif false then\n",
       "mainline: spells known through the deprecated globals only",
       expect="mainline: an evoker's buffs are found (C_SpellBook)",
       script=S)

# ------------------------------------------------ secret values
# A refused aura read taken as "not wearing it".
mutate("Core.lua",
       "\tif not has and refused then has = nil end\n",
       "",
       "mainline: a withheld aura read as missing",
       expect="mainline: an aura the client withholds is not read as missing (withheld as a secret)",
       script=S)
