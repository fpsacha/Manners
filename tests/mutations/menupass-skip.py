# Mutations for the right-click lengths on Who to skip:
# tests/scenarios/menupass-skip.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts one rule back and
# names the scenario that objects.

S = "runscenarios.py"

mutate("Options/Window/WidgetsEntry.lua",
       "\t\tif v < 60 then return (ns.L[\"%s s\"]):format(Plain(v, step)) end\n\t\tif not isWhole",
       "\t\tif true then return (\"%d\"):format(v) end\n\t\tif not isWhole",
       "menupass-skip: the seconds branch prints a bare number",
       expect="menupass-skip: the box reads", script=S)

mutate("Options/Window/WidgetsEntry.lua",
       "\t\tlocal factor = LETTERS[letters]\n",
       "\t\tlocal factor = nil\n",
       "menupass-skip: RangeParse ignores the unit letters",
       expect="menupass-skip: a length typed", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"timing.skipSeconds\", \"timing.ownSkipMinutes\", \"timing.ownSkipChoices\",\n\t\tafter = function() rescan() end,",
       "\t\t\"timing.ownSkipMinutes\", \"timing.ownSkipChoices\",\n\t\tafter = function() rescan() end,",
       "menupass-skip: RESET.skip loses timing.skipSeconds",
       expect="menupass-skip: Who to skip's reset", script=S)
