# Mutations for hunt 36: a scroll that puts the same stat on somebody as your
# buff (Buffs.lua: `blockers`, `statValue`, readIds; Core.lua: UnitHasBuff,
# LandingRank). A Rank 1 Arcane Intellect cannot be cast over a Scroll of
# Intellect, and Manners kept offering it. Each undoes one behaviour and is
# caught by the scenario in tests/scenarios/hunt36-scrolls.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ the rule
# The blockers never weighed: a Rank 1 mage is offered Arcane Intellect over a
# scroll the game refuses it over.
mutate("Core.lua",
       "\tif blockerIds and not has and not refused then\n",
       "\tif false and blockerIds and not has and not refused then\n",
       "hunt36-scrolls: the blockers never weighed",
       expect="hunt36-scrolls: vanilla: a Rank 1 mage is held off by a Scroll of Intellect (+4 over +2)",
       script=S)

# The blockers left out of the one batched read: nothing is ever found.
mutate("Core.lua",
       "pcall(PrefetchAuras, unit, buff.readIds or buff.auraIds, info.secrecy)",
       "pcall(PrefetchAuras, unit, buff.auraIds, info.secrecy)",
       "hunt36-scrolls: the blockers left out of the batched read",
       expect="hunt36-scrolls: vanilla: a Rank 1 mage is held off by a Scroll of Intellect (+4 over +2)",
       script=S)

# An equal worth let through: the game holds a cast off a scroll worth the
# same, and Forever's Fortitude rank 1 (+4) meets a Scroll of Stamina (+4).
mutate("Core.lua",
       "\t\t\t\tif not (landing and value and value >= landing) then break end\n",
       "\t\t\t\tif not (landing and value and value > landing) then break end\n",
       "hunt36-scrolls: a scroll worth the same let through",
       expect="hunt36-scrolls: camelot: a Rank 1 priest is held off by a Scroll of Stamina (+4 over +4)",
       script=S)

# A scroll worth less read as covering, too. A Rank 3 mage (+15) is held off
# by a Scroll of Intellect (+4).
mutate("Core.lua",
       "\t\t\t\tif not (landing and value and value >= landing) then break end\n",
       "\t\t\t\tif not (landing and value) then break end\n",
       "hunt36-scrolls: a scroll worth less read as covering",
       expect="hunt36-scrolls: vanilla: a Rank 3 mage still offers over the same scroll (+15 over +4)",
       script=S)

# Weighed against the best rank you know rather than the one that lands on
# them: a level-12 target, who gets rank 2, is offered over a scroll worth more.
mutate("Core.lua",
       "\t\t\t\t\tlanding = landed and ns.STAT_VALUE[landed] or nil\n",
       "\t\t\t\t\tlanding = landed and ns.STAT_VALUE[info.topRank] or nil\n",
       "hunt36-scrolls: weighed against the top rank, not the one that lands",
       expect="hunt36-scrolls: vanilla: the rank that lands counts: a level-12 target wearing a Scroll of Intellect III is covered",
       script=S)

# The weakest first: the first scroll found is a weak one, and the strong one
# beside it never counts.
mutate("Buffs.lua",
       "\t\t\t\t\tif va ~= vb then return va > vb end\n",
       "\t\t\t\t\tif va ~= vb then return va < vb end\n",
       "hunt36-scrolls: the blockers sorted weakest first",
       expect="hunt36-scrolls: vanilla: the strongest scroll worn is the one that counts",
       script=S)

# The read going on past the buff it found: somebody wearing the top rank costs
# the scrolls' reads too, every scan. (The scroll is still never weighed over a
# buff that is worn: `not has` stands behind it.)
mutate("Core.lua",
       "\t\t\tif not (issecretvalue and issecretvalue(aura)) and type(aura) == \"table\" then return end\n",
       "",
       "hunt36-scrolls: the batched read going on past the buff found",
       expect="hunt36-scrolls: vanilla: a worn buff never reads its blockers",
       script=S)

# Covered, but not "over": the buff reads as worn and a favour is repaid with
# the cast the game refuses.
mutate("Core.lua",
       "\t\t\t\t\thas, over, mine = true, true, false\n",
       "\t\t\t\t\thas, over, mine = true, false, false\n",
       "hunt36-scrolls: covered by a scroll but not over it",
       expect="hunt36-scrolls: vanilla: a favour is not repaid with a cast a scroll holds off",
       script=S)

# ------------------------------------------------------------ what the client withholds
# A blocker declared secret read as nothing: "missing", where it is cannot-tell.
mutate("Core.lua",
       "\t\t\tif info.secrecy[id] == true then\n\t\t\t\tseen = true\n",
       "\t\t\tif info.secrecy[id] == true then\n\t\t\t\tseen = false\n",
       "hunt36-scrolls: a declared-secret blocker read as missing",
       expect="hunt36-scrolls: vanilla: a blocker declared secret is cannot-tell",
       script=S)

# The probe never recording the blockers' secrecy, so none is ever declared.
mutate("Core.lua",
       "\t\t\tinfo.secrecy[id] = AuraSecrecy(id)\n",
       "\t\t\tlocal _ = AuraSecrecy(id)\n",
       "hunt36-scrolls: the blockers' secrecy not recorded",
       expect="hunt36-scrolls: vanilla: a blocker declared secret is cannot-tell",
       script=S)

# A blocker read that comes back secret taken for an empty one.
mutate("Core.lua",
       "\t\t\t\tseen = (issecretvalue and issecretvalue(aura)) or (type(aura) == \"table\")\n",
       "\t\t\t\tseen = (type(aura) == \"table\") and not (issecretvalue and issecretvalue(aura))\n",
       "hunt36-scrolls: a secret blocker read as missing",
       expect="hunt36-scrolls: vanilla: a blocker read that comes back secret is cannot-tell",
       script=S)

# A blocker read that throws taken for an empty one.
mutate("Core.lua",
       "\t\t\t\tif threw then seen, threw = true, false end\n",
       "\t\t\t\tif threw then threw = false end\n",
       "hunt36-scrolls: a blocker read that throws read as missing",
       expect="hunt36-scrolls: vanilla: a blocker read that throws is cannot-tell",
       script=S)

# A level nobody can read taken for 60: it tests a scroll it cannot weigh.
mutate("Core.lua",
       "\t\t\t\t\tlocal landed = type(level) == \"number\" and level > 0 and LandingRank(buff, info, level)\n",
       "\t\t\t\t\tlocal landed = LandingRank(buff, info, type(level) == \"number\" and level or 60)\n",
       "hunt36-scrolls: an unreadable level taken for 60",
       expect="hunt36-scrolls: vanilla: a level the client withholds tests no scroll",
       script=S)

# ------------------------------------------------------------ the data
# A scroll worth the wrong amount: Scroll of Intellect I at +1 holds nothing
# off a Rank 1 mage (+2).
mutate("Buffs.lua",
       "\t[8096] = 4, [8097] = 8, [8098] = 12, [12176] = 16,\n",
       "\t[8096] = 1, [8097] = 8, [8098] = 12, [12176] = 16,\n",
       "hunt36-scrolls: a Scroll of Intellect worth +1",
       expect="hunt36-scrolls: vanilla: the table holds what the client's data gives",
       script=S)

# Forever's Fortitude rank 1 given Classic Era's worth (+3): the tie with a
# Scroll of Stamina (+4) is lost, and so is the number.
mutate("Buffs.lua",
       "[1243] = 4, [1244] = 10, [1245] = 26,",
       "[1243] = 3, [1244] = 10, [1245] = 26,",
       "hunt36-scrolls: Forever's Fortitude with Classic Era's first rank",
       expect="hunt36-scrolls: camelot: the table holds what the client's data gives",
       script=S)

# Burning Crusade's fifth Scroll of Spirit left off the list.
mutate("Buffs.lua",
       "\t\t\tblockers = { 8112, 8113, 8114, 12177, 33080 },\n",
       "\t\t\tblockers = { 8112, 8113, 8114, 12177 },\n",
       "hunt36-scrolls: Burning Crusade's fifth Scroll of Spirit not listed",
       expect="hunt36-scrolls: tbc: a Rank 1 priest is held off by a Scroll of Spirit V (+30 over +17)",
       script=S)

# Classic Era's Scrolls of Stamina no blocker of Fortitude.
mutate("Buffs.lua",
       "\t\t\tblockers = { 8099, 8100, 8101, 12178 },\n",
       "",
       "hunt36-scrolls: Fortitude with no blockers",
       expect="hunt36-scrolls: vanilla: a Rank 1 priest is held off by a Scroll of Stamina (+4 over +3)",
       script=S)

# Mists, whose stat buffs are percentages, given a scroll to compare with.
mutate("Buffs.lua",
       "{ key = \"fortitude\", ranks = { 21562 }, alike = { 109773, 469 } },",
       "{ key = \"fortitude\", ranks = { 21562 }, alike = { 109773, 469 }, blockers = { 8099 } },",
       "hunt36-scrolls: Mists given a scroll as a blocker",
       expect="hunt36-scrolls: mists: no blockers where the buffs are percentages",
       script=S)

# The blockers' ids left out of what the client is asked to name: a wrong id
# goes unreported.
mutate("Core.lua",
       "\t\tfor _, id in ipairs(buff.blockerIds or {}) do\n\t\t\tif not SpellNameFor(id) then\n",
       "\t\tfor _, id in ipairs({}) do\n\t\t\tif not SpellNameFor(id) then\n",
       "hunt36-scrolls: a wrong blocker id not reported",
       expect="hunt36-scrolls: vanilla: a blocker id the client does not know is reported",
       script=S)
