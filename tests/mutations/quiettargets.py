# Mutations for holding the target and focus back too (Queue.lua BuildQueue,
# Core.lua's default, Options/Who.lua). Each is caught by the scenario in
# tests/scenarios/quiettargets.lua that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\t\tif inTown and (not pointed or f.quietTargets == true) then\n",
       "\t\tif inTown and not pointed then\n",
       "quiettargets: the switch is never read",
       expect="quiettargets: on, the target is held back inside an instance", script=S)

mutate("Queue.lua",
       "\t\tif inTown and (not pointed or f.quietTargets == true) then\n",
       "\t\tif f.quietTargets == true or (inTown and not pointed) then\n",
       "quiettargets: held back wherever you are",
       expect="quiettargets: on, out in the world the target is offered as ever", script=S)

mutate("Queue.lua",
       "\t\tif inTown and (not pointed or f.quietTargets == true) then\n",
       "\t\tif inTown then\n",
       "quiettargets: the target is held back with the switch off",
       expect="quiettargets: off by default, the target is still offered inside", script=S)

mutate("Core.lua",
       "\t\t\tquietTargets = false,\n",
       "\t\t\tquietTargets = true,\n",
       "quiettargets: on by default",
       expect="quiettargets: off by default, the target is still offered inside", script=S)

mutate("Options/Who.lua",
       "\t\t\tquietTargets = {\n\t\t\t\ttype = \"toggle\",",
       "\t\t\tquietTarget = {\n\t\t\t\ttype = \"toggle\",",
       "quiettargets: the switch has no place in Who to buff",
       expect="quiettargets: Who to buff has the switch, and it is kept", script=S)
