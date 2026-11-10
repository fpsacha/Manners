# Mutations for never offering inside an instance (Queue.lua Inside and the
# line that joins it to the cities rule, Core.lua's default, Options/Who.lua, the
# layout slot and the page's reset). Each is caught by the scenario in
# tests/scenarios/quietinstances.lua (or model-window.lua) that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\tif f.quietInInstances == true and Inside() then inTown = true end\n",
       "",
       "quietinstances: the setting is never read",
       expect="quietinstances: on, nobody but the target is offered inside (party)", script=S)

mutate("Queue.lua",
       "\tif f.quietInInstances == true and Inside() then inTown = true end\n",
       "\tif f.quietInInstances == true then inTown = true end\n",
       "quietinstances: held back wherever you are",
       expect="quietinstances: on, out in the world everybody is offered as ever", script=S)

mutate("Queue.lua",
       "\tif f.quietInInstances == true and Inside() then inTown = true end\n",
       "\tif Inside() then inTown = true end\n",
       "quietinstances: held back inside with the switch off",
       expect="quietinstances: off by default, and then a dungeon changes nothing", script=S)

mutate("Queue.lua",
       "\treturn (inside == true or inside == 1) and type(kind) == \"string\" and kind ~= \"none\"\n",
       "\treturn inside ~= false\n",
       "quietinstances: held back when the game will not say",
       expect="quietinstances: when the game will not say where you are, nothing is held back", script=S)

mutate("Queue.lua",
       "\treturn (inside == true or inside == 1) and type(kind) == \"string\" and kind ~= \"none\"\n",
       "\treturn (inside == true or inside == 1) and (kind == \"party\" or kind == \"raid\")\n",
       "quietinstances: battlegrounds left out",
       expect="quietinstances: on, nobody but the target is offered inside (pvp)", script=S)

mutate("Core.lua",
       "\t\t\tquietInInstances = false,\n",
       "\t\t\tquietInInstances = true,\n",
       "quietinstances: on by default",
       expect="quietinstances: off by default, and then a dungeon changes nothing", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 13.36,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = fGet,\n\t\t\t\tset = fSet,\n",
       "\t\t\t\torder = 13.36,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = fGet,\n\t\t\t\tset = function() end,\n",
       "quietinstances: the switch writes nothing",
       expect="quietinstances: Who to buff has the switch, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.quietInInstances\",\n",
       "",
       "quietinstances: the switch is not placed on the page",
       expect="every control has one place in the options window", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"filters.quietInTowns\", \"filters.quietInInstances\", \"filters.quietTargets\",\n",
       "\t\t\"filters.quietInTowns\", \"filters.quietTargets\",\n",
       "quietinstances: the page's reset leaves the switch",
       expect="model: the reset puts when back", script=S)
