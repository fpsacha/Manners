# Mutations for Cold Snap for the moment: tests/scenarios/moments-coldsnap.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\tif cooling == false then return "no", "the spell it brings back is ready" end\n',
       '\tif cooling == false then return "yes" end\n',
       "moments-coldsnap: lit with Ice Block ready",
       expect="moments-coldsnap: dark with Ice Block ready", script=S)

mutate(SENSE,
       '\tif partner.readyAt and now < partner.readyAt then return "yes" end\n',
       '',
       "moments-coldsnap: the partner's own clock is not consulted",
       expect="moments-coldsnap: your Cold Snap clears Ice Block's own clock", script=S)

mutate(SENSE,
       '\tif not partner then return "no", "the spell it brings back is not known" end\n',
       '',
       "moments-coldsnap: a spell not known is not refused",
       expect="moments-coldsnap: dark with Ice Block not known", script=S)

mutate(M,
       '\t\tif other.row.key == key then other.readyAt = nil end\n',
       '\t\tif other.row.key == key then other.readyAt = other.readyAt end\n',
       "moments-coldsnap: resets are not applied",
       expect="moments-coldsnap: your Cold Snap clears Ice Block's own clock", script=S)

mutate(M,
       '\t\tholder.onGCD = flag\n',
       '',
       "moments-coldsnap: the kept clock's flag is not read in the cooldown event",
       expect="moments-coldsnap: the flag read in the cooldown event", script=S)

mutate(M,
       '\t\t\tif not holder and entry and entry.id then\n',
       '\t\t\tif false then\n',
       "moments-coldsnap: no clock is kept with Ice Block's own switch off",
       expect="moments-coldsnap: it works with Ice Block's own switch off", script=S)
