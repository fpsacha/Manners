# Mutations for pass 2, the verdicts lens: tests/scenarios/pass2-verdicts.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back one of the
# faults the pass found and names the scenario that objects.

S = "runscenarios.py"
P = "pass2-verdicts: "

mutate("Core.lua",
       "for _, each in ipairs(family.spells) do ns.ReleaseRetry(ctx.name, each.key) end",
       "for _, each in ipairs(family.spells) do ns.MarkAttempted(ctx.name, each.key, 0) end",
       "pass2-verdicts: a plain meal lets go a food's long skip",
       expect=P + "a meal of plain bread keeps a skipped food skipped", script=S)

mutate("Queue.lua",
       "f.quietShortInTowns == true and Resting() == true then",
       "f.quietShortInTowns == true and f.quietInTowns ~= true and Resting() == true then",
       "pass2-verdicts: Never in cities and inns lifts the short hold for yourself",
       expect=P + "Never in cities and inns does not let your own short buffs through", script=S)
