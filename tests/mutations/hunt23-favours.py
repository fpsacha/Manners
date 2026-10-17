# Mutations for round 23's fix in Favours.lua: the aura baseline's settle scans
# had a budget of twenty fifths of a second, spent by every scan the client
# refused too, so a loading screen, fight or match that kept the list refused
# for longer left the baseline waiting for the next UNIT_AURA, which is the
# favour itself, filed as already carried. A second, slower stage follows the
# first, and the combat log's claim window (NOTE_MEMORY) is as long as both.
# Each undoes a part of that and is caught by the scenario in
# tests/scenarios/hunt23-favours.lua it names. (The chain that never ends is
# tests/selftest.py's "a settling chain with no end to it", judged by
# scenarios.lua.)
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ the slow stage
# The fix undone: the budget is the fast stage alone again, and a refusal of
# more than four seconds leaves nothing to ask for the second reading.
mutate("Favours.lua",
       "\tif settlePending or settleTries >= SETTLE_TRIES + SETTLE_SLOW_TRIES then return end\n",
       "\tif settlePending or settleTries >= SETTLE_TRIES then return end\n",
       "hunt23-favours: no slow settle stage",
       expect="hunt23-favours: settle-budget-spent-by-refused-scans-never-refilled", script=S)

# A slow stage that gives out after five seconds: it passes six seconds of
# refusals and fails a loading screen's twenty.
mutate("Favours.lua",
       "\tlocal SETTLE_SLOW_TRIES = 30\n",
       "\tlocal SETTLE_SLOW_TRIES = 5\n",
       "hunt23-favours: a slow stage that stops after five seconds",
       expect="hunt23-favours: a baseline waits out twenty seconds of refusals", script=S)

# A slow stage that asks as often as the fast one: the same walk every fifth
# of a second, which is the cost the stage exists to avoid.
mutate("Favours.lua",
       "\t\tlocal interval = settleTries < SETTLE_TRIES and SETTLE_INTERVAL or SETTLE_SLOW_INTERVAL\n",
       "\t\tlocal interval = settleTries < SETTLE_TRIES and SETTLE_INTERVAL or SETTLE_INTERVAL\n",
       "hunt23-favours: a slow stage as fast as the first",
       expect="hunt23-favours: a refused baseline is asked less often as it waits, and then not at all", script=S)

# A zone change that does not give the tries back: once a refusal has spent
# them, the next loading screen is left waiting for an event.
mutate("Favours.lua",
       "\t\tauraScanPrimed = false\n\t\tsettleTries = 0\n",
       "\t\tauraScanPrimed = false\n",
       "hunt23-favours: a zone change that keeps the spent tries",
       expect="hunt23-favours: a refused baseline is asked less often as it waits, and then not at all", script=S)

# ------------------------------------------------------------ the log's claim
# The claim window left at the fast stage's length: a landing the aura scan
# reads twenty seconds behind the log's is announced twice.
mutate("Favours.lua",
       "\tlocal NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES)\n"
       "\t\t+ (SETTLE_SLOW_INTERVAL * SETTLE_SLOW_TRIES) + 1\n",
       "\tlocal NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES) + 1\n",
       "hunt23-favours: a claim window of the fast stage alone",
       expect="hunt23-favours: the log's claim lasts twenty seconds behind", script=S)

# ...and one far longer than the stages together: the mark nobody consumes
# swallows a real recast for an hour.
mutate("Favours.lua",
       "\tlocal NOTE_MEMORY = (SETTLE_INTERVAL * SETTLE_TRIES)\n"
       "\t\t+ (SETTLE_SLOW_INTERVAL * SETTLE_SLOW_TRIES) + 1\n",
       "\tlocal NOTE_MEMORY = 3600\n",
       "hunt23-favours: a claim window of an hour",
       expect="hunt23-favours: the log's claim ends within a minute", script=S)
