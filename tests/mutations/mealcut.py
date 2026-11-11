# Mutations for an interrupted meal (Core.lua, OwnVerdict, mealOn). Each is
# caught by the scenario in tests/scenarios/mealcut.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\t\t\tfor _, each in ipairs(family.spells) do ns.MarkAttempted(ctx.name, each.key, 0) end\n",
       "",
       "mealcut: the block is kept after a meal cut short",
       expect="mealcut: a meal cut short brings the reminder back at once", script=S)

mutate("Core.lua",
       "\t\t\t\tmealOn = true\n\t\t\t\treturn nil, up, left, \"tried\", spell\n",
       "\t\t\t\treturn nil, up, left, \"tried\", spell\n",
       "mealcut: a meal is never noticed",
       expect="mealcut: a meal cut short brings the reminder back at once", script=S)

mutate("Core.lua",
       "\t\t\tif mealOn then\n\t\t\t\tmealOn = false\n",
       "\t\t\tif true then\n\t\t\t\tmealOn = false\n",
       "mealcut: every press let go at once",
       expect="mealcut: a press with no meal after it still waits out the cooldown", script=S)
