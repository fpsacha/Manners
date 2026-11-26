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

mutate("Core.lua",
       "\tForgetAllWorn(plain(UnitGUID(\"player\")))\n\tns.ForgetTrackingList()\n",
       "\tForgetAllWorn(plain(UnitGUID(\"player\")))\n",
       "tracking: death keeps the old minimap reading",
       expect="tracking: dying and reviving reread Find Minerals immediately",
       script=S)

mutate("Core.lua",
       "function addon:PLAYER_ALIVE()\n\tns.ForgetTrackingList()\n\tif ns.Prompt then ns.Prompt:Refresh() end\nend\n",
       "function addon:PLAYER_ALIVE()\n\tif ns.Prompt then ns.Prompt:Refresh() end\nend\n",
       "tracking: reviving keeps the old minimap reading",
       expect="tracking: dying and reviving reread Find Minerals immediately",
       script=S)

mutate("Core.lua",
       "function addon:PLAYER_UNGHOST()\n\tns.ForgetTrackingList()\n\tif ns.Prompt then ns.Prompt:Refresh() end\nend\n",
       "function addon:PLAYER_UNGHOST()\n\tif ns.Prompt then ns.Prompt:Refresh() end\nend\n",
       "tracking: unghosting keeps the old minimap reading",
       expect="tracking: dying and reviving reread Find Minerals immediately",
       script=S)
