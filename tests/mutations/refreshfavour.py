# Mutations for a buff topped up on you while it still ran (Favours.lua, IsNew,
# RECAST_GAIN). Each is caught by the scenario in
# tests/scenarios/refreshfavour.lua that names it. The test's other faults
# (any later end, the same end, no end) are in tests/mutations/ownbuffs.py.

S = "runscenarios.py"

mutate("Favours.lua",
       "\t\tif before and expires and before > 0 and expires >= before + RECAST_GAIN\n"
       "\t\t\tand lastPresent[instanceId] == key then\n",
       "\t\tif before and expires and before > 0 and expires >= before + RECAST_GAIN\n"
       "\t\t\tand lastPresent[instanceId] == key and before <= GetTime() then\n",
       "refreshfavour: only a buff that ran out counts, a top-up let go",
       expect="refreshfavour: a buff put back on you while it still ran is a favour", script=S)

mutate("Favours.lua",
       "\tlocal RECAST_GAIN = 3\n",
       "\tlocal RECAST_GAIN = 3000\n",
       "refreshfavour: no top-up ever moves the end far enough",
       expect="refreshfavour: a buff put back on you while it still ran is a favour", script=S)
