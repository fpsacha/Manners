# Classic Era made to run (tests/scenarios/era.lua), and the staged
# Manners_Vanilla.toc kept from shipping (tests/validate.py). Each fault put
# back has to be caught by the check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
V = "validate.py"

# ------------------------------------------------ the combat log's reading
# The old global only: gone with loadDeprecationFallbacks off on every client
# that has a log, and the log then read nothing.
mutate("Favours.lua",
       "\t\tlocal log = _G.C_CombatLog\n",
       "\t\tlocal log = nil\n",
       "era: the combat log read through the deprecated global only",
       expect="era: a buff from a stranger is read off the combat log (deprecation fallbacks off)",
       script=S)

# ------------------------------------------------ knowing your spells
# The deprecated IsSpellKnown and IsPlayerSpell only: with
# Blizzard_DeprecatedSpellBook not loaded, every class knows nothing.
mutate("Core.lua",
       "\t\tlocal book = C_SpellBook\n\t\tif type(book) == \"table\" then\n",
       "\t\tlocal book = C_SpellBook\n\t\tif false then\n",
       "era: spells known through the deprecated globals only",
       expect="era: a priest's buffs are found (C_SpellBook)",
       script=S)

# ------------------------------------------------ the set Era is handed
# Forever's set on Era: the mage's scrolls, no Sanctuary, no Omen.
mutate("Buffs.lua",
       "\tvanilla = VANILLA_SET,\n",
       "\tvanilla = CAMELOT_SET,\n",
       "era: Classic Era handed Forever's set",
       expect="era: Classic Era is read as vanilla and given the vanilla set without Forever's scrolls",
       script=S)

# A druid's Omen of Clarity gone from the vanilla lists, as Forever has it.
mutate("Buffs.lua",
       "\t\t{ key = \"omen\", spells = { { key = \"omen\", ranks = { 16864 }, talent = true } } },\n",
       "",
       "era: Omen of Clarity gone from Classic Era",
       expect="era: a druid without Omen of Clarity up is offered it",
       script=S)

# Era's group spells taken to reach the whole raid, as Forever's do.
mutate("Buffs.lua",
       "\tpartyIsSubgroup = true,\n",
       "\tpartyIsSubgroup = true,\n\tgroupIsRaid = true,\n",
       "era: a group spell on Era taken to reach the raid",
       expect="era: a group cast is aimed at one raid group and counts that group alone",
       script=S)

# ------------------------------------------------ names
# A realm joined as a surname, off Camelot too.
mutate("Core.lua",
       "\treturn (ns.Flavour and ns.Flavour.flavour) == \"camelot\"\n",
       "\treturn (ns.Flavour and ns.Flavour.flavour) ~= \"mainline\"\n",
       "era: a realm taken for a surname on Era",
       expect="era: a stranger from another realm is filed with the realm and targeted without it",
       script=S)

# ------------------------------------------------ the options window
# A dropdown with no client menu to open does nothing at all.
mutate("Options/Window/WidgetsChoice.lua",
       "\t\tCycle(row, values)\n\t\treturn\n",
       "\t\treturn\n",
       "era: a dropdown without MenuUtil does nothing",
       expect="era: the options window builds without MenuUtil",
       script=S)

# ------------------------------------------------ the staged toc
# tools/ no longer ignored: tools/tocs/Manners_Vanilla.toc would go out in the
# zip for any Era client to load.
mutate(".pkgmeta",
       "  - tools\n",
       "",
       "era: the staged toc's folder no longer ignored",
       expect=".pkgmeta does not ignore tools/",
       script=V)

# (A mutation moving STAGED_DIR went with 1.6.7: Era ships, nothing is staged,
# and validate's staged-toc check has nothing to hold until something is.)

# ------------------------------------------------ the Notes
# The tested-and-unverified line back on the English Notes, and on a
# translation's.
mutate("Manners.toc",
       "## Notes: One click to buff back whoever just buffed you, and nearby players missing yours.\n",
       "## Notes: One click to buff back whoever just buffed you, and nearby players missing yours."
       "|n|cffffd100Mage is tested in game; other classes are implemented but unverified.|r\n",
       "era: the English Notes say what is unverified",
       expect="Manners.toc: ## Notes: One click",
       script=V)

mutate("Manners.toc",
       "denen Euer Stärkungszauber fehlt.\n",
       "denen Euer Stärkungszauber fehlt.|n|cffffd100Der Magier ist im Spiel getestet; "
       "die anderen Klassen sind umgesetzt, aber ungeprüft.|r\n",
       "era: the German Notes say what is unverified",
       expect="Manners.toc: ## Notes-deDE:",
       script=V)
