# Mutations for tests/scenarios/tracking.lua.

S = "runscenarios.py"

# Tracking read like an aura: the minimap's list ignored, so it never reads on.
mutate("Core.lua",
       "\t\tif family.tracking then\n\t\t\tlocal list = TrackingList()\n\t\t\tif not list then return nil end\n",
       "\t\tif false then\n\t\t\tlocal list = TrackingList()\n\t\t\tif not list then return nil end\n",
       "tracking: read as an aura",
       expect="tracking: Find Herbs off is offered, on is not",
       script=S)

# A tracking spell known whether or not the minimap lists it.
mutate("Core.lua",
       "\t\tif spell.family and spell.family.tracking then\n",
       "\t\tif false then\n",
       "tracking: known without the minimap list",
       expect="counts as known",
       script=S)
