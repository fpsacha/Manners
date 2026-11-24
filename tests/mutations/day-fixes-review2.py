# Mutations for the second review of the day's fixes (Hints.lua, the line said
# once at an inn; Core.lua, tracking in a battleground). Each undoes one fix
# and is caught by the scenario in tests/scenarios/day-fixes-review2.lua that
# names it.

S = "runscenarios.py"

# Switched off, snoozed.
mutate("Hints.lua",
       "\tif not db.profile.enabled or ns.SnoozeLeft(now) then return false end\n",
       "\tif ns.SnoozeLeft(now) then return false end\n",
       "day-fixes-review2: the resting line is said with Manners switched off",
       expect="said with Manners switched off", script=S)
mutate("Hints.lua",
       "\tif not db.profile.enabled or ns.SnoozeLeft(now) then return false end\n",
       "\tif not db.profile.enabled then return false end\n",
       "day-fixes-review2: the resting line is said while snoozed",
       expect="said while snoozed", script=S)

# The buff you give everybody, missing on yourself.
mutate("Hints.lua",
       "\treturn ns.SelfBuffFirst(profile, now, true) ~= nil\n",
       "\treturn false\n",
       "day-fixes-review2: only a family of your own counts as yours",
       expect="resting with your own Intellect missing, the line was not said", script=S)
mutate("Queue.lua",
       "\tif held == \"resting\" and pastResting then\n",
       "\tif false then\n",
       "day-fixes-review2: nothing looks past resting for your own buff",
       expect="resting with your own Intellect missing, the line was not said", script=S)
mutate("Queue.lua",
       "\tif held == \"resting\" and pastResting then\n",
       "\tif held == \"resting\" then\n",
       "day-fixes-review2: resting never holds your own buff off the debug page",
       expect="resting, the prompt is said to be on your own buff", script=S)
mutate("Queue.lua",
       "\t\tif not full or ns.IsBlocked(full, nil, now or GetTime()) or ns.IsNeverOffered(full) then return nil end\n",
       "\t\tif not full or ns.IsBlocked(full, nil, now or GetTime()) then return nil end\n",
       "day-fixes-review2: past resting, the never-offer list is not asked",
       expect="said with your own name on the never-offer list", script=S)

# A tracking to fight with.
mutate("Core.lua",
       "\t\t\tif not wanted or ns.GATHERING[wanted.key] then return nil, nil, nil, \"battle\" end\n",
       "\t\t\tif true then return nil, nil, nil, \"battle\" end\n",
       "day-fixes-review2: every tracking is held back in a battleground",
       expect="the Track Humanoids you picked is held back", script=S)
mutate("Core.lua",
       "\t\t\tlocal wanted = spell or ns.OwnAutoPick(family)\n",
       "\t\t\tlocal wanted = spell\n",
       "day-fixes-review2: Automatic's tracking is always held back in a battleground",
       expect="the Track Humanoids you had on last is held back", script=S)
mutate("Core.lua",
       "\tns.GATHERING = { findherbs = true, findminerals = true, findtreasure = true, findfish = true }\n",
       "\tns.GATHERING = { findherbs = true, findtreasure = true, findfish = true }\n",
       "day-fixes-review2: Find Minerals is a tracking to fight with",
       expect="Find Minerals picked is still offered", script=S)
