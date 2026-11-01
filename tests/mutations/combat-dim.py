# The prompt's dim in a fight (Prompt/Effects.lua, CombatRestAlpha), which is
# off by default and turned on by "Dim the prompt in combat". Each fault put
# back has to be caught by the scenario in tests/scenarios/look.lua that names
# it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"

# The dim on for everybody again, the default that made a low Opacity vanish.
mutate("Core.lua",
       "\t\t\tdimInCombat = false,\n",
       "\t\t\tdimInCombat = true,\n",
       "combat-dim: the dim on by default",
       expect="the built-in prompt is not dimmed in a fight unless asked for", script=S)

# Reset this page on Look leaves the dim as it was.
mutate("Options/Advanced.lua",
       "\"prompt.hideInCombat\", \"prompt.dimInCombat\",",
       "\"prompt.hideInCombat\",",
       "combat-dim: Look's reset leaves the dim",
       expect="appearance reset: the list leaves out prompt.dimInCombat", script=S)

# A switch on a look it cannot reach, open as if it did something.
mutate("Options/Look.lua",
       "\t\t\t\tdisabled = function() return ns.Looks.Get(P().style) ~= nil end,\n",
       "",
       "combat-dim: the switch open on a look with its own fight",
       expect="look: Dim the prompt in combat is greyed out on a look with its own fight", script=S)

# A change in a fight left for the next fight.
mutate("Prompt/Panel.lua",
       "\tself:ReapplyCombatDim()\n",
       "",
       "combat-dim: the dim changed in a fight waits for the next",
       expect="the dim changed in a fight shows at once", script=S)

# The setting ignored: the built-in looks dim whether it is on or off.
mutate("Prompt/Effects.lua",
       "\treturn p and p.dimInCombat and 0.55 or 1\n",
       "\treturn 0.55\n",
       "combat-dim: the setting ignored in a fight",
       expect="the built-in prompt is not dimmed in a fight unless asked for", script=S)
