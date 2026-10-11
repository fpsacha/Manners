# What the performance pass changed without changing a decision
# (tests/scenarios/perf-fixes.lua): the aura reads taken together under one
# protected call, for another unit's buff (Core.lua, PrefetchAuras) and for the
# walk of your own forty slots (Favours.lua, PrefetchSlots), and the combat
# log's two cheapest questions asked ahead of the guard. Each fault put back
# has to be caught by the scenario it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------ another unit's aura ids
# The reads not taken together: every id asked under a protected call of its
# own, as it was -- the answers are the same, the count is not.
mutate("Core.lua",
       "\tlocal threw = not pcall(PrefetchAuras, unit, buff.auraIds, info.secrecy)\n",
       "\tlocal threw = false\n",
       "perf-fix: the ids not read together",
       expect="perf-fix: a unit's aura ids are read under one protected call",
       script=S)

# The reads going on past the first aura worn: ids the loop never asks.
mutate("Core.lua",
       "\t\t\tif not (issecretvalue and issecretvalue(aura)) and type(aura) == \"table\" then return end\n",
       "",
       "perf-fix: the ids read past the first aura worn",
       expect="perf-fix: a unit's aura reads stop at the first aura worn",
       script=S)

# The loop trusting what was taken for every position, a position the read
# threw at included: the ids after a throw are never asked.
mutate("Core.lua",
       "\t\t\tif index > auraTaken then\n",
       "\t\t\tif false then\n",
       "perf-fix: the ids after a throw not asked",
       expect="perf-fix: an aura id whose read throws costs only itself",
       script=S)

# The id the read threw at asked again on the spot, where it throws again:
# two failures for one, a buff of one id (most buffs on Mists and retail)
# paying twice what it paid before.
mutate("Core.lua",
       "\t\t\t\tif threw then\n",
       "\t\t\t\tif false then\n",
       "perf-fix: the id that threw asked again",
       expect="perf-fix: an aura id whose read threw is not asked a second time",
       script=S)

# The throw remembered past the id it belongs to: every id after it read as a
# refusal without being asked.
mutate("Core.lua",
       "\t\t\t\t\tthrew, ok, aura = false, false, nil\n",
       "\t\t\t\t\tok, aura = false, nil\n",
       "perf-fix: every id after a throw refused",
       expect="perf-fix: an aura id whose read throws costs only itself",
       script=S)

# An answer filed under the count of reads made instead of the position of the
# id it was asked of: an id the client keeps secret before it shifts every
# answer after it onto the wrong id.
mutate("Core.lua",
       "\t\t\tauraReads[index] = aura\n",
       "\t\t\tauraReads[auraTaken + 1] = aura\n",
       "perf-fix: the answers filed by count",
       expect="perf-fix: an answer is the answer of the id it was asked of",
       script=S)

# And taken from the wrong end: the loop reading the next position's answer.
mutate("Core.lua",
       "\t\t\tlocal ok, aura = true, auraReads[index]\n",
       "\t\t\tlocal ok, aura = true, auraReads[index + 1]\n",
       "perf-fix: the answer of the next id taken",
       expect="perf-fix: an answer is the answer of the id it was asked of",
       script=S)

# The position that threw counted as taken: its answer is whatever the last
# reading left there, and the refusal is lost.
mutate("Core.lua",
       "\t\t\tlocal aura = read(unit, id)\n"
       "\t\t\tauraReads[index] = aura\n"
       "\t\t\tauraTaken = index\n",
       "\t\t\tauraTaken = index\n"
       "\t\t\tlocal aura = read(unit, id)\n"
       "\t\t\tauraReads[index] = aura\n",
       "perf-fix: the position that threw taken",
       expect="perf-fix: an aura id whose read throws costs only itself",
       script=S)

# What was taken for the last unit still standing when this unit's first read
# throws.
mutate("Core.lua",
       "\tauraTaken = 0\n\tlocal read = C_UnitAuras.GetUnitAuraBySpellID\n",
       "\tlocal read = C_UnitAuras.GetUnitAuraBySpellID\n",
       "perf-fix: the last unit's answers kept",
       expect="perf-fix: a read that threw is not answered from the last unit's",
       script=S)

# An id the client keeps secret asked after all.
mutate("Core.lua",
       "\t\tif secrecy[id] ~= true then\n\t\t\tlocal aura = read(unit, id)\n",
       "\t\tif true then\n\t\t\tlocal aura = read(unit, id)\n",
       "perf-fix: a secret id asked",
       expect="perf-fix: an aura id the client keeps secret is not asked",
       script=S)

# ------------------------------------------------ your own forty slots
# The slots not read together: a protected call for each, as it was.
mutate("Favours.lua",
       "\t\tTakeSlots()\n",
       "",
       "perf-fix: the slots not read together",
       expect="perf-fix: the walk of your own auras is one protected call",
       script=S)

# The slot the read threw at asked again on the spot, where it throws again.
mutate("Favours.lua",
       "\t\tslotsTaken = slotsTaken + 1\n"
       "\t\tslotReads[slotsTaken] = false\n",
       "",
       "perf-fix: the slot that threw asked again",
       expect="perf-fix: a slot whose read threw is not asked a second time",
       script=S)

# The slot that threw filed as an empty one: no refusal, and a hole in the list.
mutate("Favours.lua",
       "\t\tslotReads[slotsTaken] = false\n",
       "\t\tslotReads[slotsTaken] = nil\n",
       "perf-fix: the slot that threw read as empty",
       expect="perf-fix: a slot whose read throws is a refusal and the rest are read",
       script=S)

# The slots after a throw trusted from the last walk.
mutate("Favours.lua",
       "\t\tif index > slotsTaken then ok, value = pcall(",
       "\t\tif false then ok, value = pcall(",
       "perf-fix: the slots after a throw not asked",
       expect="perf-fix: a slot whose read throws is a refusal and the rest are read",
       script=S)

# The slot that threw counted as taken.
mutate("Favours.lua",
       "\t\t\tslotReads[index] = read(\"player\", index, \"HELPFUL\")\n"
       "\t\t\tslotsTaken = index\n",
       "\t\t\tslotsTaken = index\n"
       "\t\t\tslotReads[index] = read(\"player\", index, \"HELPFUL\")\n",
       "perf-fix: the slot that threw taken",
       expect="perf-fix: a slot whose read throws is a refusal and the rest are read",
       script=S)

# The last walk's count still standing when the first slot throws.
mutate("Favours.lua",
       "\t\tslotsTaken = 0\n\t\tlocal read = C_UnitAuras.GetAuraDataByIndex\n",
       "\t\tlocal read = C_UnitAuras.GetAuraDataByIndex\n",
       "perf-fix: the last walk's slots kept",
       expect="perf-fix: a first slot that throws is not answered from the last walk",
       script=S)

# ------------------------------------------------ the combat log
# The two cheap questions not asked ahead of the guard: every swing, tick and
# proc of a fight pays for a protected call again (and is turned away, or not,
# by what comes after).
mutate("Favours.lua",
       "\t\tif plain(subevent) ~= \"SPELL_AURA_APPLIED\" then return end\n"
       "\t\tif plain(auraType) ~= \"BUFF\" then return end\n"
       "\t\t-- Guarded: an unguarded handler that throws simply stops being a source.\n",
       "\t\t-- Guarded: an unguarded handler that throws simply stops being a source.\n",
       "perf-fix: every combat log line guarded",
       expect="perf-fix: a combat log line that is nobody's business costs no protected call",
       script=S)

# The line of the kind it reads read without the guard: a fault in reading it
# escapes to the client's error handler on every line that is one.
mutate("Favours.lua",
       "\t\tns.Guard(\"combat log\", ReadCombatLogFavour, sourceGUID, destGUID, spellId)\n",
       "\t\tReadCombatLogFavour(sourceGUID, destGUID, spellId)\n",
       "perf-fix: a buff landing read unguarded",
       expect="perf-fix: a combat log line of a buff landing on you is still guarded",
       script=S)

# The line read from the client a second time by the part that follows the
# two questions, as it was first made: a second call of twenty values for every
# aura landing in a raid fight, those on other people included.
mutate("Favours.lua",
       "\tlocal function ReadCombatLogFavour(sourceGUID, destGUID, spellId)\n",
       "\tlocal function ReadCombatLogFavour(sourceGUID, destGUID, spellId)\n"
       "\t\tCombatLogEvent()\n",
       "perf-fix: the log line read twice",
       expect="perf-fix: a combat log line asks the client for its reading once",
       script=S)
