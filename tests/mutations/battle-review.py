# Mutations for the review of battlegrounds and arenas (Battle.lua and its
# hooks in Queue.lua, Commands.lua, Options/When.lua and Options/Who.lua): the
# team out of a single cast's reach kept for a group cast's fold with Only in
# range off, a settings string from before the section carried when pasted,
# and Hold back my target and focus too said to reach a battleground. Each is
# caught by the scenario in tests/scenarios/battle-review.lua that names it.

S = "runscenarios.py"
B = "Battle.lua"

# ------------------------------------------------- the fold, Only in range off
# Only that switch keeps somebody for the fold, as before: in a battleground
# with it off, Battle.Reach drops them ahead of the group cast.
mutate("Queue.lua",
       "\t\tif (f.requireInRange or opts.reachOnly) and ranged == false and inGroup and not owner and checked and ns.GROUP_IS_RAID\n",
       "\t\tif f.requireInRange and ranged == false and inGroup and not owner and checked and ns.GROUP_IS_RAID\n",
       "battle-review: a battleground keeps nobody for the fold with Only in range off",
       expect="it should be the one Arcane Brilliance it is with that switch on", script=S)

# The walk is never told it is in a battleground.
mutate("Queue.lua",
       "\topts.reachOnly = battle and true or nil\n",
       "\topts.reachOnly = nil\n",
       "battle-review: the walk is not told of the battleground",
       expect="still counted by a group cast (prep)", script=S)

# ------------------------------------------------------- a string pasted
# The paste is not carried: the team's switch goes back to its default.
mutate("Commands.lua",
       "\t\tif not own then ns.Battle.CarryPasted(profile, parsed.values) end\n",
       "",
       "battle-review: a pasted string from before the section is not carried",
       expect="Buff my team there is on after the paste", script=S)

# Every string with the instance switch on is carried, one that names the
# team's switch too.
mutate(B,
       "\tif values[\"filters.quietInInstances\"] ~= true or values[\"battle.team\"] ~= nil then return end\n",
       "\tif values[\"filters.quietInInstances\"] ~= true then return end\n",
       "battle-review: a string that names the team's switch is carried over it",
       expect="came back with Buff my team there off", script=S)

# Every string is carried, the instance switch on or not.
mutate(B,
       "\tif values[\"filters.quietInInstances\"] ~= true or values[\"battle.team\"] ~= nil then return end\n",
       "\tif values[\"battle.team\"] ~= nil then return end\n",
       "battle-review: every old string unticks the team's switch",
       expect="an old string without the instance switch unticked Buff my team there", script=S)

# The export leaves the team's switch out beside the instance switch, as any
# default: the player's own string reads as one from before the section.
mutate("Commands.lua",
       "\t\t\tif not text and field.name == \"battle.team\" and ns.Battle.Shared(profile) then text = \"1\" end\n",
       "",
       "battle-review: the export does not name the team's switch beside the instance switch",
       expect="came back with Buff my team there off", script=S)

# ------------------------------------------- the target, held back there too
# /manners debug says the target is offered whatever that switch holds.
mutate(B,
       "\tif not Battle.On(\"team\") and type(db.filters) == \"table\" and db.filters.quietTargets == true then\n",
       "\tif false then\n",
       "battle-review: /manners debug promises a target that is held back",
       expect="your target is held back in a battleground and /manners debug says", script=S)

# The team's switch does not say what holds the target back there.
mutate("Options/When.lua",
       "\t\t\t\t\t\t.. \" \" .. L[\"In a battleground or an arena with %s off, %s holds back somebody you target or focus too.\"]\n"
       "\t\t\t\t\t\t\t:format(\"|cffffd100\" .. L[\"Buff my team there\"] .. \"|r\",\n"
       "\t\t\t\t\t\t\t\t\"|cffffd100\" .. L[\"Hold back my target and focus too\"] .. \"|r\")\n",
       "",
       "battle-review: Buff my team there does not say the target can be held back",
       expect="battleTeam's text does not say", script=S)

# Nor does the switch that holds it back say it reaches a battleground.
mutate("Options/Who.lua",
       "\t\t\t\t\t\t.. \" \" .. L[\"In a battleground or an arena with %s off, %s holds back somebody you target or focus too.\"]\n"
       "\t\t\t\t\t\t\t:format(\"|cffffd100\" .. L[\"Buff my team there\"] .. \"|r\",\n"
       "\t\t\t\t\t\t\t\t\"|cffffd100\" .. L[\"Hold back my target and focus too\"] .. \"|r\")\n",
       "",
       "battle-review: Hold back my target and focus too does not say it reaches a battleground",
       expect="quietTargets's text does not say", script=S)
