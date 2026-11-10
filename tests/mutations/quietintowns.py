# Mutations for never offering in cities and inns (Queue.lua inTown, Core.lua's
# default, Options/Who.lua, the layout slot and the page's reset). Each is caught by
# the scenario in tests/scenarios/quietintowns.lua (or model-window.lua) that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\tlocal inTown = f.quietInTowns == true and Resting() == true\n",
       "\tlocal inTown = false\n",
       "quietintowns: the setting is never read",
       expect="quietintowns: on, nobody is offered in a city, not even a favour or the group", script=S)

mutate("Queue.lua",
       "\tlocal inTown = f.quietInTowns == true and Resting() == true\n",
       "\tlocal inTown = f.quietInTowns == true\n",
       "quietintowns: held back wherever you are",
       expect="quietintowns: on, out in the world everybody is offered as ever", script=S)

mutate("Queue.lua",
       "\tlocal inTown = f.quietInTowns == true and Resting() == true\n",
       "\tlocal inTown = Resting() ~= false\n",
       "quietintowns: held back whenever resting cannot be told, or off",
       expect="quietintowns: when resting cannot be told, nothing is held back", script=S)

mutate("Queue.lua",
       "\t\tif inTown and (not pointed or f.quietTargets == true) then\n",
       "\t\tif inTown then\n",
       "quietintowns: a target is held back too",
       expect="quietintowns: on, a target or focus is still offered in a city", script=S)

mutate("Queue.lua",
       "\t\t\tif inTown then break end\n",
       "",
       "quietintowns: a favour owed with no token is still offered",
       expect="quietintowns: on, a favour owed to somebody out of sight waits for a city to end", script=S)

mutate("Core.lua",
       "\t\t\tquietInTowns = false,\n",
       "\t\t\tquietInTowns = true,\n",
       "quietintowns: on by default",
       expect="quietintowns: off by default, and then a city changes nothing", script=S)

mutate("Options/Who.lua",
       "\t\t\t\torder = 13.35,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = fGet,\n\t\t\t\tset = fSet,\n",
       "\t\t\t\torder = 13.35,\n\t\t\t\twidth = \"full\",\n\t\t\t\tget = fGet,\n\t\t\t\tset = function() end,\n",
       "quietintowns: the switch writes nothing",
       expect="quietintowns: Who to buff has the switch, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\t\"who.quietInTowns\",\n",
       "",
       "quietintowns: the switch is not placed on the page",
       expect="quietInTowns", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"filters.quietInTowns\", \"filters.quietInInstances\", \"filters.quietTargets\",\n",
       "\t\t\"filters.quietInInstances\", \"filters.quietTargets\",\n",
       "quietintowns: the page's reset leaves the switch",
       expect="model: the reset puts when back", script=S)
