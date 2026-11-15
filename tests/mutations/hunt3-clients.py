# Mutations for the third hunt's faults that differ by client. Each is caught
# by the scenario in tests/scenarios/hunt3-clients.lua that names it.

S = "runscenarios.py"

# "Nobody Left Out": the names a cast with no group version reached.
RAID = "hunt3-clients: one cast that lands on the whole raid has left nobody out"
mutate("Milestones.lua",
       "{ pending.wideMembers or false, pending.selfCast",
       "{ false, pending.selfCast",
       "hunt3-clients: a cast that lands on the whole raid counts one name",
       expect=RAID, script=S)
mutate("Milestones.lua",
       "pending.selfCast and pending.shoutMembers or false })",
       "false })",
       "hunt3-clients: a shout's hearers count for nothing",
       expect=RAID, script=S)
mutate("Milestones.lua",
       "\t\t\t\t\tif not w.grouped then Sat(st, w.key or e.gave, w.names, w.size, w.clock) end\n",
       "\t\t\t\t\tif not w.grouped then Sat(st, w.key or e.gave, { e.name }, w.size, w.clock) end\n",
       "hunt3-clients: a favour returned by a raid-wide cast counts one name",
       expect=RAID, script=S)

# A season's rune is the class's whether learned or not; and the other way,
# nobody has a resurrection until it is learned.
DRUID = "hunt3-clients: a druid on Classic Era has a resurrection only once the rune is learned"
PRIEST = "hunt3-clients: a priest who has not trained his resurrection is still shown the milestone"
mutate("Resurrect.lua",
       "\treturn mine.rune ~= true or Info() ~= nil\n",
       "\treturn true\n",
       "hunt3-clients: a rune nobody on the realm can learn counts as a resurrection",
       expect=DRUID, script=S)
mutate("Resurrect.lua",
       "\treturn mine.rune ~= true or Info() ~= nil\n",
       "\treturn Info() ~= nil\n",
       "hunt3-clients: no class has a resurrection until it is trained",
       expect=PRIEST, script=S)

# A class with nothing for anybody.
ROGUE = "hunt3-clients: a class with no buff for others is promised no milestone it cannot earn"
KEEP = "hunt3-clients: the milestones read from the ledger stay for a class with a buff to give"
mutate("Milestones.lua",
       "\tif not def.feature and NothingToGive() then return false end\n",
       "",
       "hunt3-clients: a rogue is shown ten milestones it cannot earn",
       expect=ROGUE, script=S)
mutate("Milestones.lua",
       "\treturn class ~= nil and type(without) == \"table\" and without[class] == true\n",
       "\treturn class ~= nil\n",
       "hunt3-clients: no class keeps the ledger's milestones",
       expect=KEEP, script=S)
mutate("Hall.lua",
       "\treturn of > 0\nend\n",
       "\treturn true\nend\n",
       "hunt3-clients: the hall of fame shown with nothing to earn",
       expect=ROGUE, script=S)
mutate("Milestones.lua",
       "\tlocal on = On() and select(2, M.Tally()) > 0\n",
       "\tlocal on = On()\n",
       "hunt3-clients: an empty Milestones tab",
       expect=ROGUE, script=S)

# Mists: the level a refreshment asks.
LEVEL = "hunt3-clients: mists: nobody is handed a refreshment above their level"
mutate("Courtesy.lua",
       "\t\tif needs and (needs[item] or 0) > level then count = 0 end\n",
       "",
       "hunt3-clients: mists: a refreshment traded to somebody too low for it",
       expect=LEVEL, script=S)
mutate("Courtesy.lua",
       "\t\t\t\t\tif (needs[item] or 0) > level then return nil, \"level\" end\n",
       "",
       "hunt3-clients: mists: a conjure for somebody too low for what it makes",
       expect=LEVEL, script=S)

# A courtesy's own cooldown.
COOL = "hunt3-clients: mists: a summon or a Soulwell still cooling down is not offered"
CONJURE = "hunt3-clients: a conjure still cooling down is not offered"
mutate("Courtesy.lua",
       "\t\tif Cooling(kind.spell) then return nil, \"cooldown\" end\n",
       "",
       "hunt3-clients: a summon offered while the ritual cools down",
       expect=COOL, script=S)
mutate("Courtesy.lua",
       "\t\tif Cooling(spell) then return nil, \"cooldown\" end\n",
       "",
       "hunt3-clients: a Soulwell or a portal offered while it cools down",
       expect=COOL, script=S)
mutate("Courtesy.lua",
       "\tif Cooling(conjure.spell) then return nil, \"cooldown\" end\n",
       "",
       "hunt3-clients: a conjure offered while it cools down",
       expect=CONJURE, script=S)
mutate("Courtesy.lua",
       "and duration > 3\n\t\tand start + duration > GetTime()\n",
       "and duration > 0\n\t\tand start + duration > GetTime()\n",
       "hunt3-clients: the global cooldown takes a courtesy off the prompt",
       expect=COOL, script=S)
