# Mutations for Slow Fall for the moment: tests/scenarios/moments-slowfall.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"
SENSE = "Prompt/MomentsSense.lua"

mutate(SENSE,
       'local FALL_SECONDS = 1.0\n',
       'local FALL_SECONDS = 0.5\n',
       "moments-slowfall: the fall threshold is halved",
       expect="moments-slowfall: a jump shorter than a second never lights it", script=S)

mutate(M,
       '\t\t\t\tif slot.armed and slot.button:IsShown() then slot.button:Hide() end\n',
       '',
       "moments-slowfall: a keep button is not taken down after a fight",
       expect="moments-slowfall: after a fight with no fall the button is not shown", script=S)

mutate("Prompt/MomentsData.lua",
       '\t\t\tneeds = { "falling", "usable" } },\n',
       '\t\t\tneeds = { "falling" } },\n',
       "moments-slowfall: the usable test is dropped from Slow Fall",
       expect="moments-slowfall: no feather", script=S)

mutate(M,
       '\t\tif state ~= was and slot.row.peace == true and not InCombatLockdown() then PeaceShow(slot, state) end\n',
       '\t\tif state ~= was and slot.row.peace == true then PeaceShow(slot, state) end\n',
       "moments-slowfall: Show is not guarded by the lockdown",
       expect="moments-slowfall: in a fight a second lights it with nothing protected called", script=S)

mutate(M,
       '\tif not (falling or moving or Sense.fighting or now < watchHold) then watch:Hide() end\n',
       '',
       "moments-slowfall: the watch never goes quiet",
       expect="moments-slowfall: the watch is hidden standing still", script=S)

mutate(SENSE,
       '\tif slot.castAt and now - slot.castAt < (slot.row.seconds or 0) then return "no", "it is on you" end\n',
       '',
       "moments-slowfall: your own cast does not keep it dark",
       expect="moments-slowfall: your own cast keeps it dark for its length", script=S)

mutate(SENSE,
       '\tif issecretvalue(rawFall) then\n\t\tSense.fallSince, Sense.fallSecret = nil, true\n\t\treturn false\n\tend\n',
       '',
       "moments-slowfall: a hidden IsFalling is not told from not falling",
       expect="moments-slowfall: a hidden IsFalling stays dark", script=S)

mutate(M,
       '\t\tif caps.conditionalTargeting then\n\t\t\tslot.shape = "[@player]"\n',
       '\t\tif true then\n\t\t\tslot.shape = "[@player]"\n',
       "moments-slowfall: Forever gets [@player]",
       expect="moments-slowfall: Forever's macro targets you by name", script=S)

mutate(M,
       '\t\t\tif slot.needs.falling then wantMove = true end\n',
       '',
       "moments-slowfall: the movement events are not registered",
       expect="moments-slowfall: the watch is hidden standing still", script=S)

mutate(M,
       '\t\t\tif slot.armed and slot.row.peace == true and slot.state == "lit" then\n',
       '\t\t\tif false then\n',
       "moments-slowfall: a fight ending mid-fall takes the button down",
       expect="moments-slowfall: a fight ending mid-fall leaves it up", script=S)

mutate(M,
       '\t\t\telseif not (on and self:GetAttribute("manners-keep-" .. i)) then\n',
       '\t\t\telseif true then\n',
       "moments-slowfall: the driver hides a keep button at the release",
       expect="moments-slowfall: a fight ending mid-fall leaves it up", script=S)

mutate(SENSE,
       '\tSense.fallSince = nil\n\treturn false\nend\n',
       '\treturn false\nend\n',
       "moments-slowfall: landing does not end the fall",
       expect="moments-slowfall: half a second is no fall", script=S)
