# Mutations for the empowered-cast events: tests/scenarios/moments-empower.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"

mutate(M,
       'local CAST_START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_EMPOWER_START = true }\n',
       'local CAST_START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }\n',
       "moments-empower: an empowered start is not a cast start",
       expect="moments-empower: an empowered cast start lights Counterspell", script=S)

mutate(M,
       'local CAST_STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_EMPOWER_STOP = true,\n',
       'local CAST_STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true,\n',
       "moments-empower: an empowered stop is not a cast stop",
       expect="moments-empower: an empowered cast start lights Counterspell", script=S)

mutate(M,
       '\tif not Sense.accepted[name] or fightEvents[name] then return end\n',
       '\tif fightEvents[name] then return end\n',
       "moments-empower: an unprobed event name is registered directly",
       expect="moments-empower: without the events the pull still registers the rest", script=S)
