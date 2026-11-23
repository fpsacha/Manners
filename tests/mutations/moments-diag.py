# Mutations for what the buttons for the moment say of themselves:
# tests/scenarios/moments-diag.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one guard back to
# its absence and names the scenario that objects.

S = "runscenarios.py"
M = "Prompt/Moments.lua"

mutate(M,
       '\t\tif slot.trailAt and now - slot.trailAt < TRAIL_GAP then return end\n',
       '',
       "moments-diag: the trail's two-second gap is removed",
       expect="moments-diag: one trail line per lighting", script=S)

mutate(M,
       '\t\tif (slot.trailCount or 0) >= TRAIL_MAX then return end\n',
       '',
       "moments-diag: the trail's twelve a fight is removed",
       expect="moments-diag: one trail line per lighting", script=S)

mutate("Core.lua",
       '\tif words then ns.Trail("fight", "fight summary, buttons for the moment: " .. words) end\n',
       '\tif false then ns.Trail("fight", "fight summary, buttons for the moment: " .. words) end\n',
       "moments-diag: the second summary line is not written",
       expect="moments-diag: the second fight-summary line says what each button saw", script=S)

mutate("Options/BugReport.lua",
       '\t\tfor _, line in ipairs(ns.Moments.MarkWords()) do ns.Trail("MARK", line) end\n',
       '',
       "moments-diag: Mark this moment leaves the buttons out",
       expect="moments-diag: Mark this moment adds", script=S)

mutate("Commands.lua",
       '\t\tfor _, line in ipairs(ns.MomentLines and ns.MomentLines() or {}) do self:Print("  " .. line) end\n',
       '',
       "moments-diag: /manners debug leaves the buttons out",
       expect="moments-diag: /manners debug has a line per row", script=S)

mutate(M,
       '\t\t\tif state ~= "peace" and not (state == "fight" and Sense.fighting) then\n',
       '\t\t\tif false then\n',
       "moments-diag: the self-test does not warn of a header out of peace",
       expect="moments-diag: the self-test's rows", script=S)

mutate(M,
       '\t\telseif not (slot and slot.button) then\n',
       '\t\telseif false then\n',
       "moments-diag: the self-test does not warn of a button never made",
       expect="moments-diag: the self-test's rows", script=S)

mutate(M,
       '\t\t\tif leaks > 0 then\n\t\t\t\ttext = text ..',
       '\t\t\tif false then\n\t\t\t\ttext = text ..',
       "moments-diag: the self-test does not warn of a leaked click",
       expect="moments-diag: the self-test's rows", script=S)

mutate(M,
       '\t\tTrail(slot, "left to the game (" ..',
       '\t\tTrail(slot, "lit (" ..',
       "moments-diag: a hidden value is called lit on the trail",
       expect="moments-diag: a hidden value is said to be left to the game", script=S)

mutate("Selftest.lua",
       '\t\t\tif row.armed and row.command then Row(row.key, row.command) end\n',
       '',
       "moments-diag: the keys group leaves the buttons out",
       expect="moments-diag: the self-test's rows", script=S)
