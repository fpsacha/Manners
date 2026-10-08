# What the clients' bug hunt fixed (tests/scenarios/clients-fixes.lua): the
# combat log asking the group and the ignore list as the aura scan does,
# Mists' raid-buff kinds, the party auras no family holds, Earth Shield cast
# on somebody else, and the level cap per client. Each fault put back has to
# be caught by the check it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ the log's record
# The combat log's record left without inGroup: a party member's lapsing
# shout is a "buffed you" line at every pull on the clients with a log.
mutate("Favours.lua",
       "\t\t\tseen.inGroup = inGroup\n",
       "",
       "clients-fix: the log's record outside the group",
       expect="clients-fix: a party member's lapsing shout read off the combat log is announced once",
       script=S)

# The log no longer asking the ignore list: filed, announced and offered.
mutate("Favours.lua",
       "\t\tif ns.Ignored(full, sourceGUID) then return end\n",
       "",
       "clients-fix: the log filing somebody ignored",
       expect="clients-fix: a stranger on your ignore list read off the combat log is not filed",
       script=S)

# The tokenless owed fallback trusting that nobody ignored is owed anything.
mutate("Queue.lua",
       "\t\t\t\tand not (ignoring and ns.Ignored(full, entry.guid))\n",
       "",
       "clients-fix: an ignored debtor offered by name",
       expect="clients-fix: a debt to somebody you have since ignored is not offered by name",
       script=S)

# ------------------------------------------------ Mists' raid-buff kinds
# Kings matched by its own id alone: a paladin offers it over a druid's Mark.
mutate("Buffs.lua",
       "{ key = \"kings\", ranks = { 20217 }, alike = { 1126, 117666, 117667 } },",
       "{ key = \"kings\", ranks = { 20217 } },",
       "clients-fix: Kings over Mark of the Wild",
       expect="clients-fix: a Mists paladin is not offered a second +5% stats buff over a druid's Mark of the Wild",
       script=S)

# Mark of the Wild matched by its own id alone.
mutate("Buffs.lua",
       "{ key = \"motw\", ranks = { 1126 }, alike = { 20217, 117666, 117667 } },",
       "{ key = \"motw\", ranks = { 1126 } },",
       "clients-fix: Mark of the Wild over Kings",
       expect="clients-fix: a Mists druid is not offered a second +5% stats buff over a paladin's Blessing of Kings",
       script=S)

# Legacy of the Emperor matched by its own auras alone.
mutate("Buffs.lua",
       "\t\t\talike = { 20217, 1126 },\n",
       "",
       "clients-fix: Legacy over Mark of the Wild",
       expect="clients-fix: a Mists monk is not offered a second +5% stats buff over a druid's Mark of the Wild",
       script=S)

# The rest of the kinds, one each.
mutate("Buffs.lua",
       "{ key = \"fortitude\", ranks = { 21562 }, alike = { 109773, 469 } },",
       "{ key = \"fortitude\", ranks = { 21562 } },",
       "clients-fix: Fortitude over Dark Intent",
       expect="clients-fix: on Mists fortitude is covered by another class's of its kind",
       script=S)

mutate("Buffs.lua",
       "\t\t\talike = { 1459, 61316, 24932 },\n",
       "",
       "clients-fix: White Tiger over Arcane Brilliance",
       expect="clients-fix: on Mists whitetiger is covered by another class's of its kind",
       script=S)

mutate("Buffs.lua",
       "partyOnly = true, alike = { 57330, 19506 } },",
       "partyOnly = true },",
       "clients-fix: Battle Shout over Horn of Winter",
       expect="clients-fix: on Mists battleshout is covered by another class's of its kind",
       script=S)

mutate("Buffs.lua",
       "partyOnly = true, alike = { 6673, 19506 } },",
       "partyOnly = true },",
       "clients-fix: Horn of Winter over Battle Shout",
       expect="clients-fix: on Mists hornofwinter is covered by another class's of its kind",
       script=S)

# Another class's of the kind read as nobody's, so as the paladin's own when
# its caster has no token: Kings covered, and Might never reached.
mutate("Core.lua",
       "\t\t\t\tif buff.alikeIds and buff.alikeIds[id] then mine = false end\n",
       "",
       "clients-fix: another class's of the kind read as ours",
       expect="clients-fix: a Mists paladin is not offered a second +5% stats buff over Mark of the Wild from somebody unnamed",
       script=S)

# The kinds filed under the buffs that list them: a favour of Mark of the
# Wild thanked as Kings or Legacy.
mutate("Buffs.lua",
       "\t\t\t\t\tbuff.alikeIds[id] = true\n",
       "\t\t\t\t\tbuff.alikeIds[id] = true\n\t\t\t\t\tns.BUFF_BY_ID[id] = buff\n",
       "clients-fix: another class's of the kind filed as ours",
       expect="clients-fix: on Mists a buff's id is filed under its own buff",
       script=S)

# ------------------------------------------------ party auras
# The druid's forms in no table on vanilla content (Forever, Era).
mutate("Buffs.lua",
       "\tnotFavour = { [24932] = true, [24907] = true },\n",
       "",
       "clients-fix: Leader of the Pack a favour on vanilla",
       expect="clients-fix: a party aura no family holds is never a favour (vanilla)",
       script=S)

# Burning Crusade's own party auras forgotten: vanilla's list alone.
mutate("Buffs.lua",
       "\tnotFavour = { [24932] = true, [24907] = true, [34123] = true, [6562] = true, [28878] = true },\n",
       "",
       "clients-fix: Tree of Life a favour on Burning Crusade",
       expect="clients-fix: a party aura no family holds is never a favour (tbc)",
       script=S)

# Mists' passives in no list.
mutate("Buffs.lua",
       "\tnotFavour = {\n\t\t[19506] = true,",
       "\tnotFavourGone = {\n\t\t[19506] = true,",
       "clients-fix: Trueshot Aura a favour on Mists",
       expect="clients-fix: a party aura no family holds is never a favour (mists)",
       script=S)

# The combat log no longer asking the list.
mutate("Favours.lua",
       "\t\tif ns.IsOwnAura(spellId) or ns.NOT_FAVOUR_IDS[spellId] then return end\n",
       "\t\tif ns.IsOwnAura(spellId) then return end\n",
       "clients-fix: the log taking a party aura for a favour",
       expect="read off the combat log with heals counted was a favour",
       script=S)

# ------------------------------------------------ Earth Shield
# Every own spell nobody's favour again, Earth Shield included.
mutate("Buffs.lua",
       "\treturn spell ~= nil and not spell.castOnOthers\n",
       "\treturn spell ~= nil\n",
       "clients-fix: Earth Shield on you nobody's favour",
       expect="clients-fix: a shaman's Earth Shield on a warrior is a favour with heals counted",
       script=S)

mutate("Buffs.lua",
       "ranks = { 32594, 32593, 974 }, castOnOthers = true,\n",
       "ranks = { 32594, 32593, 974 },\n",
       "clients-fix: Burning Crusade's Earth Shield an aura",
       expect="clients-fix: a shaman's Earth Shield on a warrior is a favour with heals counted (tbc)",
       script=S)

mutate("Buffs.lua",
       "charges = 9,\n\t\t\t\t\tcastOnOthers = true },",
       "charges = 9 },",
       "clients-fix: Mists' Earth Shield an aura",
       expect="clients-fix: a shaman's Earth Shield on a warrior is a favour with heals counted (mists)",
       script=S)

# The log's own check back on the whole own table.
mutate("Favours.lua",
       "\t\tif ns.IsOwnAura(spellId) or ns.NOT_FAVOUR_IDS[spellId] then return end\n",
       "\t\tif ns.OWN_BY_ID[spellId] or ns.NOT_FAVOUR_IDS[spellId] then return end\n",
       "clients-fix: the log taking Earth Shield for an aura",
       expect="read off the combat log was nobody's favour",
       script=S)

# ------------------------------------------------ the level cap
# Vanilla's 60 in the repair: 85 on Mists cut back at every login.
mutate("Core.lua",
       "\t{ \"filters\", \"minLevel\", 1, ns.MaxPlayerLevel },\n",
       "\t{ \"filters\", \"minLevel\", 1, 60 },\n",
       "clients-fix: the repair capped at 60",
       expect="clients-fix: Skip players below level 85 holds on mists",
       script=S)

# ...and on the slider.
mutate("Options/Who.lua",
       "\t\t\t\tmax = ns.MaxPlayerLevel(),\n",
       "\t\t\t\tmax = 60,\n",
       "clients-fix: the slider stopping at 60",
       expect="clients-fix: Skip players below level 65 holds on tbc",
       script=S)

# The flavour's cap alone, whatever the client says.
mutate("Core.lua",
       "\tif type(level) == \"number\" and level > cap then cap = level end\n",
       "",
       "clients-fix: the client's own cap ignored",
       expect="clients-fix: Skip players below level 95 holds on mainline (the client says 100)",
       script=S)

# Burning Crusade read as vanilla: its cap of 70 lost.
mutate("Core.lua",
       "local cap = (flavour == \"tbc\" and 70) or",
       "local cap = (flavour == \"tbc\" and 60) or",
       "clients-fix: Burning Crusade capped at 60",
       expect="clients-fix: Skip players below level 65 holds on tbc",
       script=S)
