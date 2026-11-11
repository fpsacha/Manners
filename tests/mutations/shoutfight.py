# Mutations for a lone warrior's shout in a fight (Queue.lua, SelfEntry and
# FightShouts; GitHub issue 13). Each is caught by the scenario in
# tests/scenarios/shoutfight.lua that names it.

S = "runscenarios.py"

mutate("Queue.lua",
       "\tlocal fight = held == \"fight\" and not ownOnly and FightShouts(candidates)\n",
       "\tlocal fight = false\n",
       "shoutfight: nothing of yours in a fight, the shout included",
       expect="shoutfight: a lone warrior's shout stays on in a fight", script=S)

mutate("Queue.lua",
       "\tif fight then held, full = HeldBackExceptList(db, now, true) end\n",
       "",
       "shoutfight: the fight's hold still stands for the shout",
       expect="shoutfight: a lone warrior's shout stays on in a fight", script=S)

mutate("Queue.lua",
       "\tif fight then held, full = HeldBackExceptList(db, now, true) end\n",
       "\tif fight then held, full = nil, ns.UnitFullName(\"player\") end\n",
       "shoutfight: the other rules skipped in a fight",
       expect="shoutfight: the city rule holds in a fight too", script=S)

mutate("Queue.lua",
       "\tif not buff and fight then return nil end\n",
       "",
       "shoutfight: your other own buffs offered in a fight",
       expect="shoutfight: in a fight the shout alone, never your other own buffs", script=S)

mutate("Queue.lua",
       "\t\tif buff.selfCast then\n\t\t\tout = out or {}\n",
       "\t\tif true then\n\t\t\tout = out or {}\n",
       "shoutfight: every self buff let through a fight",
       expect="shoutfight: a mage's own Intellect is not offered in a fight", script=S)
