# Mutations for Thorns held to the tanks of a group (Core.lua Castable and
# IsTankUnit, Queue.lua's per-person fields, Options/Who.lua, the layout slot,
# ClampSettings and the share list). Each is caught by the scenario in
# tests/scenarios/tankonly.lua that names it.

S = "runscenarios.py"

GATE = "\t\tif opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and opts.inGroup\n"

mutate("Core.lua", GATE,
       "\t\tif false and opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key] and opts.inGroup\n",
       "tankonly: the choice never holds a buff back",
       expect="tankonly: held to tanks, only the tank of the party is offered Thorns", script=S)

mutate("Core.lua", GATE,
       "\t\tif opts.tanksOnly and buff.tankChoice and opts.tanksOnly[buff.key]\n",
       "tankonly: held for passers-by too",
       expect="tankonly: held to tanks, a passer-by outside the group is offered Thorns as ever", script=S)

mutate("Core.lua", GATE,
       "\t\tif opts.tanksOnly and opts.tanksOnly[buff.key] and opts.inGroup\n",
       "tankonly: every buff held",
       expect="tankonly: a buff without the choice is never held, whatever the set says", script=S)

mutate("Queue.lua",
       "\t\tlocal tanksOnly = not asked and tanksHeld or nil\n",
       "\t\tlocal tanksOnly = tanksHeld\n",
       "tankonly: a request is held to the tanks",
       expect="tankonly: held to tanks, somebody who asks for Thorns is offered it", script=S)

mutate("Queue.lua",
       "\t\topts.isTank = tanksOnly and inGroup and ns.IsTankUnit(unit) or nil\n",
       "\t\topts.isTank = tanksOnly and inGroup and true or nil\n",
       "tankonly: everybody is a tank",
       expect="tankonly: held to tanks, somebody with no role is not a tank", script=S)

mutate("Core.lua",
       "\t\tif type(roles) == \"function\" and plain(roles(unit)) == \"TANK\" then return true end\n",
       "",
       "tankonly: the assigned role is not read",
       expect="tankonly: held to tanks, only the tank of the party is offered Thorns", script=S)

mutate("Core.lua",
       "\t\t\treturn plain(role) == \"MAINTANK\" or plain(combatRole) == \"TANK\"\n",
       "\t\t\treturn false\n",
       "tankonly: the main tank mark is not read",
       expect="tankonly: held to tanks, the main tank of a raid is offered Thorns", script=S)

mutate("Options/Who.lua",
       "\t\t\t\t\tB().tanksOnly[buff.key] = (value == \"tanks\") or nil\n",
       "\t\t\t\t\tB().tanksOnly[buff.key] = nil\n",
       "tankonly: the choice is never kept",
       expect="tankonly: Who to buff offers the choice for Thorns, and it is kept", script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.tankChoice then items[#items + 1] = { \"who.tank_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "tankonly: the choice is not placed on the page",
       expect="tank_thorns", script=S)

mutate("Core.lua",
       "\tif type(profile.buff.tanksOnly) ~= \"table\" then profile.buff.tanksOnly = {} end\n",
       "",
       "tankonly: a damaged set is never repaired",
       expect="tankonly: the set is repaired and travels with a profile", script=S)

mutate("Commands.lua",
       "elseif name == \"buff.skip\" or name == \"buff.tanksOnly\" then",
       "elseif name == \"buff.skip\" then",
       "tankonly: the choice does not travel with a profile",
       expect="tankonly: the set is repaired and travels with a profile", script=S)

mutate("Options/Advanced.lua",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.tanksOnly\", \"buff.kingsFirst\", \"buff.order\", \"filters.relevantOnly\",\n",
       "\t\t\"buff.choice\", \"buff.skip\", \"buff.kingsFirst\", \"buff.order\", \"filters.relevantOnly\",\n",
       "tankonly: the page's reset leaves the choice",
       expect="model: the reset puts who back", script=S)
