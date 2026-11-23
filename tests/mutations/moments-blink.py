# Mutations for Blink for the moment: tests/scenarios/moments-blink.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\tslot.lockFlag = LockFlag(slot)\n\t\treturn "no", "not a stun or a root"\n',
       '\t\tslot.lockFlag = LockFlag(slot)\n\t\treturn "yes"\n',
       "moments-blink: a plain fear lights it",
       expect="moments-blink: dark for a plain", script=S)

mutate(SENSE,
       '\t\tif flag == true and Sense.lockProven then\n',
       '\t\tif flag == true then\n',
       "moments-blink: the lock flag vetoes before it is proven",
       expect="moments-blink: the lock flag reading true on the first loss of control", script=S)

mutate(SENSE,
       '\tif flag == false then Sense.lockProven = true end\n',
       '',
       "moments-blink: the lock flag is never proven",
       expect="moments-blink: the lock flag seen false once, then true", script=S)

mutate(M,
       '\t\tif type(who) == "string" and who ~= "player" then return end\n',
       '',
       "moments-blink: another unit's loss of control is not dropped",
       expect="moments-blink: another unit's loss of control does nothing", script=S)

mutate(M,
       '\t\t\tif slot.needs.stuck then wantControl = true end\n',
       '',
       "moments-blink: the control events are not kept while Blink is armed",
       expect="moments-blink:", script=S)

mutate(SENSE,
       '\t\tif full == true or now - lostAt > UNSURE_SECONDS then\n',
       '\t\tif full == true then\n',
       "moments-blink: the guess outlives its ten seconds",
       expect="moments-blink: the guess ends after ten seconds unreadable", script=S)

mutate(M,
       '\t\t\tif needs.stuck and type(_G.C_LossOfControl) == "table" then\n',
       '\t\t\tif false then\n',
       "moments-blink: the loss-of-control events are not registered at the pull",
       expect="moments-blink: a loss of control announced only by the loss-of-control event", script=S)

mutate("Prompt/MomentsData.lua",
       'needs = { "fight", "stuck", "ready", "usable" } },',
       'needs = { "fight", "stuck", "usable" } },',
       "moments-blink: Blink does not wait for its cooldown",
       expect="moments-blink: dark on cooldown", script=S)

mutate(M,
       '\t\tSense.lostAt = nil\n\t\treturn JudgeAll("stuck")\n',
       '\t\treturn JudgeAll("stuck")\n',
       "moments-blink: control gained does not end the guess",
       expect="moments-blink: no loss-of-control API: control lost before the pull lights it, control gained ends it", script=S)
