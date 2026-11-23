# Mutations for the urgent buttons for the moment lighting at once, under the
# global cooldown: tests/scenarios/moments-fast.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       '\t\tif slot.row.fast and OnlyGcd(slot, now) then return "yes" end\n',
       '',
       "moments-fast: a cooldown that is only the global one holds the urgent button dark",
       expect="moments-fast: the owner's trail", script=S)

mutate(SENSE,
       '\tif cooling == true and OnlyGcd(partner, now) then return "no", "the spell it brings back is ready" end\n',
       '',
       "moments-fast: Cold Snap lights for the global cooldown",
       expect="moments-fast: the global cooldown is no reason for Cold Snap", script=S)

mutate(SENSE,
       '\tif slot.readyAt and now < slot.readyAt then return false end\n\tlocal running, gcdEnd = GcdRunning(now)\n',
       '\tlocal running, gcdEnd = GcdRunning(now)\n',
       "moments-fast: Manners' own clock is not asked before the global cooldown is blamed",
       expect="moments-fast: a real cooldown still holds Blink dark under the global cooldown", script=S)

mutate(SENSE,
       '\t\tif gcdEnd then return start + duration <= gcdEnd + 0.05 end\n',
       '\t\tif gcdEnd then return true end\n',
       "moments-fast: a plain cooldown of fifteen seconds is taken for the global one",
       expect="moments-fast: a plain cooldown of fifteen seconds under the global cooldown keeps Blink dark", script=S)

mutate(M,
       '\t\tif event == "LOSS_OF_CONTROL_ADDED" then Sense.locAt = GetTime() end\n',
       '',
       "moments-fast: a loss of control the game would not name starts no guess",
       expect="moments-fast: a hidden loss-of-control count lights Blink at the event itself", script=S)

mutate(M,
       '\t\tif event == "LOSS_OF_CONTROL_ADDED" then Sense.locAt = GetTime() end\n\t\tJudgeAll("stuck")\n\t\treturn Schedule()\n',
       '\t\tif event == "LOSS_OF_CONTROL_ADDED" then Sense.locAt = GetTime() end\n\t\treturn JudgeAll("stuck")\n',
       "moments-fast: a loss of control schedules no second look",
       expect="moments-fast: a dark verdict that clears on its own is read again within a quarter second", script=S)

mutate(SENSE,
       '\t\t\tSense.lostAt, Sense.locAt = nil, nil\n\t\t\treturn "no", "you have control"',
       '\t\t\tSense.lostAt = nil\n\t\t\treturn "no", "you have control"',
       "moments-fast: the guess from a loss of control outlives its ten seconds",
       expect="moments-fast: the hidden guess ends after ten seconds", script=S)

mutate(M,
       '\tif slot.row.fast then\n\t\tslot.face:SetAlpha(1)\n\t\tslot.fading, slot.fadeTo = false, 1\n\telse\n\t\tFadeTo(slot, 1)\n\tend\n',
       '\tFadeTo(slot, 1)\n',
       "moments-fast: the urgent buttons fade in",
       expect="moments-fast: Counterspell and Ice Block painted by the game appear at once", script=S)

mutate(M,
       '\tif slot.row.fast then\n\t\tslot.face:SetAlpha(1)\n\t\tslot.fading, slot.fadeTo = false, 1\n\telse\n\t\tFadeTo(slot, 1)\n\tend\n',
       '\tslot.face:SetAlpha(1)\n\tslot.fading, slot.fadeTo = false, 1\n',
       "moments-fast: every button appears with no fade",
       expect="moments-fast: Evocation still fades in", script=S)

mutate(M,
       '\t\tif slot.heldWhy ~= why then\n',
       '\t\tif false then\n',
       "moments-fast: a button held dark says nothing on the trail",
       expect="moments-fast: a held dark Blink says why on the trail", script=S)

mutate(M,
       '\t["the game says it cannot be cast now"] = true }\n',
       '\t}\n',
       "moments-fast: a spell the game will call castable soon is not looked at again",
       expect="moments-fast: a dark verdict that clears on its own is read again within a quarter second", script=S)

mutate("Prompt/MomentsData.lua",
       'Row { key = "blink", slot = 3, fast = true, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,\n\t\t\tbreaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },\n\t\t\tneeds = { "fight", "stuck", "ready", "usable" } },\n\t\tRow { key = "evocation"',
       'Row { key = "blink", slot = 3, ranks = { 1953 }, stop = true, blind = "weak", cooldown = 15,\n\t\t\tbreaks = { STUN = true, STUN_MECHANIC = true, ROOT = true },\n\t\t\tneeds = { "fight", "stuck", "ready", "usable" } },\n\t\tRow { key = "evocation"',
       "moments-fast: Blink is not marked urgent",
       expect="moments-fast: the owner's trail", script=S)
