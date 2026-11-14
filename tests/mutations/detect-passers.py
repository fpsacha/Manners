# Mutations for Detect Invisibility to passers-by too (Core.lua's
# buff.detectPassers, ns.PassersToo and Castable; Options/Who.lua's
# passers_<key> switch and the buff's label; Options/Window/Layout.lua's place
# for it; Options/Advanced.lua's reset). Each is caught by the scenario in
# tests/scenarios/detect-passers.lua that names it.
#
# Run by selftest.py with mutate() in scope.

S = "runscenarios.py"
P = "detect-passers: "

mutate("Core.lua",
       "\t\t\tdetectPassers = false,\n",
       "\t\t\tdetectPassers = true,\n",
       "detect-passers: on by default",
       expect=P + "off on a new profile, and off it changes nothing", script=S)

mutate("Core.lua",
       "\treturn type(b) == \"table\" and b.detectPassers == true\n",
       "\treturn false\n",
       "detect-passers: the switch does nothing",
       expect=P + "ticked, a passer-by is offered it, and so is one who asks", script=S)

mutate("Core.lua",
       "\treturn type(b) == \"table\" and b.detectPassers == true\n",
       "\treturn true\n",
       "detect-passers: passers-by offered it with the switch off",
       expect=P + "off on a new profile, and off it changes nothing", script=S)

mutate("Core.lua",
       " and not ns.PassersToo(buff) then return false end\n",
       " then return false end\n",
       "detect-passers: Castable never asks the switch",
       expect=P + "ticked, a passer-by is offered it, and so is one who asks", script=S)

mutate("Core.lua",
       "\t\tif ns.PassersToo(buff) then return false end\n",
       "",
       "detect-passers: still said to reach only the group",
       expect=P + "ticked, a passer-by is offered it, and so is one who asks", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.detectPassers\",\n",
       "",
       "detect-passers: the page's reset leaves it on",
       expect=P + "the switch travels with a profile, is repaired", script=S)

mutate("Options/Who.lua",
       "\t\tif not ns.PassersToo(buff) then label = L[\"%s |cff808080(your group only)|r\"]:format(label) end\n",
       "\t\tlabel = L[\"%s |cff808080(your group only)|r\"]:format(label)\n",
       "detect-passers: the buff still labelled your group only",
       expect=P + "ticked, a passer-by is offered it, and so is one who asks", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\treturn ns.BuffOff(buff, B())\n",
       "\t\t\t\t\treturn false\n",
       "detect-passers: the switch shows with the buff unticked",
       expect=P + "the switch shows only once the buff is ticked", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().detectPassers = value and true or false\n",
       "\t\t\t\t\tB().detectPassers = false\n",
       "detect-passers: the switch saves nothing",
       expect=P + "ticked, a passer-by is offered it, and so is one who asks", script=S)

mutate("Options/Who.lua",
       "\t\tif buff.membersOnly and not (buff.partyOnly or buff.groupOnly or buff.oneTarget) then\n\t\t\targs[\"passers_\"",
       "\t\tif true then\n\t\t\targs[\"passers_\"",
       "detect-passers: every buff gets the switch",
       expect=P + "only where the class and the client have the buff", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\t\titems[#items + 1] = { \"who.passers_\" .. tostring(buff.key), indent = true }\n",
       "\t\t\t\t\titems[#items + 1] = \"who.passers_\" .. tostring(buff.key)\n",
       "detect-passers: the switch level with its buff",
       expect=P + "the switch shows only once the buff is ticked", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t[\"who.passers_detectgroup\"] = \"who.offer_detectgroup\",\n",
       "",
       "detect-passers: search is not told the switch's parent",
       expect=P + "the switch shows only once the buff is ticked", script=S)
