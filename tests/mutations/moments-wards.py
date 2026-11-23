# Mutations for Fire Ward and Frost Ward for the moment:
# tests/scenarios/moments-wards.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\tif other ~= school and when > at and (not recent or now - when <= HIT_SECONDS) then\n',
       '\t\tif false then\n',
       "moments-wards: the later school rule is dropped",
       expect="moments-wards: the later school wins", script=S)

mutate(SENSE,
       '\tif not at then return "no", "nothing of that kind has hit you" end\n',
       '',
       "moments-wards: a ward lit with no hit",
       expect="moments-wards: no hit: dark, with the reason", script=S)

mutate(SENSE,
       'local HIT_SECONDS = 10\n',
       'local HIT_SECONDS = 60\n',
       "moments-wards: a hit counts for a minute",
       expect="moments-wards: eleven seconds is too long", script=S)

mutate(SENSE,
       '\tlocal mask = plain(rawMask)\n',
       '\tlocal mask = rawMask\n',
       "moments-wards: a hidden school mask is read",
       expect="moments-wards: a hidden school mask is ignored", script=S)

mutate(SENSE,
       '\tif plain(action) ~= "WOUND" then return end\n',
       '',
       "moments-wards: a heal counts as a hit",
       expect="moments-wards: only a wound counts", script=S)

mutate(M,
       '\tif slot.row.shares == other.row.key then other.readyAt = slot.readyAt end\n',
       '',
       "moments-wards: a cast of one ward does not start the other's clock",
       expect="moments-wards: a cast of either darkens both", script=S)

mutate(M,
       '\t\t\tif needs.schoolhit then Register("UNIT_COMBAT", "player") end\n',
       '',
       "moments-wards: the combat event is not registered at the pull",
       expect="moments-wards: the hits are heard only in a fight", script=S)

mutate(SENSE,
       '\tif guess then return "yes", nil, false end\n',
       '',
       "moments-wards: the target's cast does not light the ward",
       expect="moments-wards: your target casting lights the ward of the school that hit you", script=S)

mutate(M,
       '\t\tJudgeAll("schoolhit")\n\t\tJudgeAll("casting")\n\t\treturn Schedule()\n',
       '\t\tJudgeAll("casting")\n\t\treturn Schedule()\n',
       "moments-wards: a cast's start is not judged for the wards",
       expect="moments-wards: your target casting lights the ward of the school that hit you", script=S)
