# Mutations for every class's enabled own buff at the combat snapshot.

S = "runscenarios.py"

mutate("Queue.lua",
       "\tlocal prompt = ns.Prompt\n"
       "\tlocal fight = held == \"fight\" and not ownOnly and prompt ~= nil\n"
       "\t\tand prompt.armedForFight == true and not InCombatLockdown()\n",
       "\tlocal fight = false\n",
       "shoutfight: all own buffs held in a fight",
       expect="shoutfight: a lone warrior's shout stays in the pull snapshot", script=S)

mutate("Queue.lua",
       "\tif fight then held, full = HeldBackExceptList(db, now, true) end\n",
       "",
       "shoutfight: the fight's hold still stands",
       expect="shoutfight: a lone warrior's shout stays in the pull snapshot", script=S)

mutate("Queue.lua",
       "\tif fight then held, full = HeldBackExceptList(db, now, true) end\n",
       "\tif fight then held, full = nil, ns.UnitFullName(\"player\") end\n",
       "shoutfight: the other own-buff rules skipped in a fight",
       expect="shoutfight: the city rule holds in a fight too", script=S)

mutate("Queue.lua",
       "\t\tif fight and buff and ns.ItemFamily(buff.family) then buff = nil end\n",
       "",
       "shoutfight: bagged items join the combat snapshot",
       expect="shoutfight: in a fight the shout alone, never your other own buffs", script=S)

mutate("Queue.lua",
       "\t\tand prompt.armedForFight == true and not InCombatLockdown()\n",
       "\t\tand prompt.armedForFight == true and not InCombatLockdown() and ns.caps.class == \"WARRIOR\"\n",
       "shoutfight: only warriors may snapshot their own buff",
       expect="shoutfight: a mage's own Intellect is offered from the pre-fight snapshot", script=S)

SELF = "shoutfight: your own shout with both shout switches on is held, without an error"
mutate("Queue.lua",
       "\t\tif db.buff.shoutCombatInstances == true and ns.ShoutCombatAllowed() ~= true then return nil end\n\tend",
       "\t\tif db.buff.shoutCombatInstances == true then opts.shoutCombatAllowed = ns.ShoutCombatAllowed() end\n\tend",
       "shoutfight: your own shout writes to a table that is not there (#74)",
       expect=SELF, script=S)
mutate("Queue.lua",
       "\t\tif db.buff.shoutCombatInstances == true and ns.ShoutCombatAllowed() ~= true then return nil end\n\tend",
       "\tend",
       "shoutfight: your own shout ignores the dungeon-fight timing",
       expect=SELF, script=S)
