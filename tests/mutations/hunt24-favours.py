# Mutations for round 24's fix in Favours.lua: a zone change gives the settle
# scans back (settleTries = 0), but the timer parked for the old zone could not
# be called back, so settlePending stayed true until it fired, up to a second
# inside the slow stage, and the new zone's first settle scan came that late.
# The fix is an epoch: ResetAuraBaseline moves it on and clears settlePending,
# and a timer set under an older one does nothing. Each undoes a part of that
# and is caught by the scenario in tests/scenarios/hunt24-favours.lua it names.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# ------------------------------------------------------------ the old timer
# The stale timer no longer stands down: it scans, clears the flag the new
# chain owns and, with the baseline still unsettled, asks for the next reading
# itself. Two chains, each asking every fifth of a second.
mutate("Favours.lua",
       "\t\t\tif epoch ~= settleEpoch then return end\n\t\t\tsettlePending = false\n",
       "\t\t\tsettlePending = false\n",
       "hunt24-favours: a settle timer from the old zone still runs",
       expect="hunt24-favours: a zone change leaves one settle chain, not two", script=S)

# The check made after the flag is cleared: no scan, but the new chain's flag
# is gone, and the next event that wants a settle starts a second chain beside
# the one already parked.
mutate("Favours.lua",
       "\t\t\tif epoch ~= settleEpoch then return end\n\t\t\tsettlePending = false\n",
       "\t\t\tsettlePending = false\n\t\t\tif epoch ~= settleEpoch then return end\n",
       "hunt24-favours: a settle timer from the old zone clears the new chain's flag",
       expect="hunt24-favours: a zone change leaves one settle chain, not two", script=S)

# ------------------------------------------------------------ the zone change
# The epoch is never moved on: the flag is cleared and the new chain starts at
# once, but the old timer is still current and runs beside it.
mutate("Favours.lua",
       "\t\tsettleEpoch = settleEpoch + 1\n\t\tsettlePending = false\n",
       "\t\tsettlePending = false\n",
       "hunt24-favours: a zone change that leaves the old timer current",
       expect="hunt24-favours: a zone change leaves one settle chain, not two", script=S)

# The flag is not cleared: the old timer stands down, and with it the only
# thing that would have cleared the flag, so no chain ever starts again.
mutate("Favours.lua",
       "\t\tsettleEpoch = settleEpoch + 1\n\t\tsettlePending = false\n",
       "\t\tsettleEpoch = settleEpoch + 1\n",
       "hunt24-favours: a zone change that leaves settlePending set",
       expect="hunt24-favours: a zone change in the slow stage settles within a fifth of a second", script=S)

# The fix undone as 1.7.8 had it: the zone change gives back the tries and
# nothing else, and the new chain waits for the timer parked for the old zone.
mutate("Favours.lua",
       "\t\tsettleEpoch = settleEpoch + 1\n\t\tsettlePending = false\n",
       "",
       "hunt24-favours: a zone change that waits for the parked timer",
       expect="hunt24-favours: a zone change late in a slow wait settles within a fifth of a second", script=S)
