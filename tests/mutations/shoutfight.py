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
       "\tlocal out = {}\n\tfor _, b in ipairs(list) do\n\t\tlocal held = b.recipientMelee",
       "\tlocal out = opts.out\n\tfor _, b in ipairs(list) do\n\t\tlocal held = b.recipientMelee",
       "shoutfight: your own shout reads a table that is not there (#74)",
       expect=SELF, script=S)
mutate("Queue.lua",
       "\t\t\tor (fight and ns.ShoutCombatAllowed() ~= true))",
       "\t\t\tor false)",
       "shoutfight: your own shout ignores the dungeon-fight timing",
       expect=SELF, script=S)
mutate("Queue.lua",
       "\tlocal mine = ShoutHeld(db, ns.SelfBuffs(Affordable(ns.CastableBuffs(), UNPAID)))",
       "\tlocal mine = ns.SelfBuffs(Affordable(ns.CastableBuffs(), UNPAID))",
       "shoutfight: /manners debug names a held shout",
       expect=SELF, script=S)
