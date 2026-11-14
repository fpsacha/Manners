# Mutations for the review of resurrection (Resurrect.lua and its hooks): the
# rules that hold every other unasked offer back hold a resurrection too, a
# resurrection switched off is nothing to cast, and the tooltip of the cast
# for the whole group is its own. Each is caught by the scenario in
# tests/scenarios/res-review.lua that names it.

S = "runscenarios.py"

QUIET = "res-review: Offer nothing in dungeons holds a resurrection back, but for your target"
PVP = "res-review: no cast for the whole group while a dead member is flagged for PvP"
MANA = "res-review: the mana floor holds a resurrection back"
OFF = "res-review: switched off, a resurrection learned is nothing to cast"
TIP = "res-review: the tooltip of the group's resurrection is not a shout's"

# The quiet rule is never told to Resurrect.lua: the dead are offered inside.
mutate("Queue.lua",
       "\tif ns.deadSeen then ns.deadSeen.quiet = inTown or nil end\n",
       "",
       "res-review: the dead offered where nothing is offered",
       expect=QUIET, script=S)

# Your dead target held back with everybody else.
mutate("Resurrect.lua",
       "\t\tor not (plain(UnitIsUnit(unit, \"target\")) or plain(UnitIsUnit(unit, \"focus\")))) then\n",
       "\t\tor true) then\n",
       "res-review: a dead target held back inside",
       expect=QUIET, script=S)

# The cast for the whole group formed where nothing is offered.
mutate("Resurrect.lua",
       "\tif massReady and not flaggedDead and not scan.quiet then\n",
       "\tif massReady and not flaggedDead then\n",
       "res-review: the group's cast where nothing is offered",
       expect=QUIET, script=S)

# A flagged dead member is left out of the count, and not out of the cast.
mutate("Resurrect.lua",
       "\tif flagged and inGroup then flaggedDead = true end\n",
       "",
       "res-review: the group's cast reaches a flagged member",
       expect=PVP, script=S)

# Only the game's own "not enough mana" holds a resurrection back.
mutate("Resurrect.lua",
       "\tif ns.SavingMana() ~= nil then return nil, nil end\n",
       "",
       "res-review: a resurrection offered under the mana floor",
       expect=MANA, script=S)

# A resurrection learned counts with its switch off.
mutate("Core.lua",
       "\tif caps.res and ns.Resurrect and ns.Resurrect.Wanted() then return true end\n",
       "\tif caps.res then return true end\n",
       "res-review: a resurrection switched off is something to cast",
       expect=OFF, script=S)

# The shout's sentence for the group's resurrection.
mutate("Prompt/Macro.lua",
       "\telseif entry.resNames then\n",
       "\telseif false then\n",
       "res-review: the group's resurrection is cast on you",
       expect=TIP, script=S)

# "In your group." under the cast for everybody.
mutate("Prompt/Button.lua",
       "\tif entry.resNames then why = ns.Resurrect.Reason(entry) end\n",
       "",
       "res-review: the tooltip speaks of one member",
       expect=TIP, script=S)
