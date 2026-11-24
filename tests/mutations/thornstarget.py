# Mutations for Thorns, also offered to my target (1.12.1): the switch
# buff.toTarget lets your target past Offer to (Core.lua Castable, Queue.lua
# BuildQueue), its place in Who to buff and the window, its repair and its
# export. Each is caught by the scenario in tests/scenarios/thornstarget.lua
# that names it.

S = "runscenarios.py"

ON = "thornstarget: Tanks only and the switch offer Thorns to a target who does not tank"
OFF = "thornstarget: switch off, Tanks only keeps Thorns off the target"
SWITCH = "thornstarget: the switch is in Who to buff, placed under Offer to, and sets only its own set"

mutate("Core.lua",
       "\t\tlocal freed = opts.toTarget and buff.tankChoice and opts.toTarget[buff.key]\n",
       "\t\tlocal freed = nil\n",
       "thornstarget: Castable never lets the target past Offer to",
       expect=ON, script=S)

mutate("Queue.lua",
       "\t\topts.toTarget = unit == \"target\" and opts.toTargetHeld or nil\n",
       "\t\topts.toTarget = nil\n",
       "thornstarget: the walk never hands the set on",
       expect=ON, script=S)

mutate("Queue.lua",
       "\t\topts.toTarget = unit == \"target\" and opts.toTargetHeld or nil\n",
       "\t\topts.toTarget = opts.toTargetHeld\n",
       "thornstarget: everybody let past Offer to, not only the target",
       expect=ON, script=S)

mutate("Queue.lua",
       "\tlocal toTargetHeld = db.buff.toTarget\n",
       "\tlocal toTargetHeld = db.buff.tanksOnly\n",
       "thornstarget: the target let past with the switch off",
       expect=OFF, script=S)

mutate("Options/Who.lua",
       "B().toTarget[buff.key] = value and true or nil",
       "B().toTarget[buff.key] = value and true or false",
       "thornstarget: off leaves false behind",
       expect=SWITCH, script=S)

mutate("Options/Window/Layout.lua",
       "\t\t\t\tif buff.tankChoice then items[#items + 1] = { \"who.toTarget_\" .. tostring(buff.key), indent = true } end\n",
       "",
       "thornstarget: the window never places the switch",
       expect=SWITCH, script=S)

mutate("Core.lua",
       "\tif type(profile.buff.toTarget) ~= \"table\" then profile.buff.toTarget = {} end\n",
       "",
       "thornstarget: a damaged set is not repaired",
       expect=SWITCH, script=S)
