# Mutations for the review of sharing the group with other Manners users
# (Share.lua and its hooks in Queue.lua and GroupBuffs.lua): the channel of a
# group the game formed, the 45 seconds paused over a fight, a group cast left
# to another user, a party-wide buff on yourself, the verdict on somebody a
# group cast is aimed at, and the roster left alone with sharing off. Each is
# caught by the scenario in tests/scenarios/raidsplit-review.lua that names it.

S = "runscenarios.py"

# ------------------------------------------------------------ the channel
# A dungeon queue's party is said hello to on PARTY, which is not that group.
mutate("Share.lua",
       "\tif instance ~= nil and type(inGroup) == \"function\" and plain(inGroup(instance)) == true then\n"
       "\t\treturn \"INSTANCE_CHAT\"\n\tend\n",
       "",
       "raidsplit-review: a formed group's hello goes to PARTY",
       expect="in a group the game formed the hello went to", script=S)

# And a hello heard on the instance's channel is refused.
mutate("Share.lua",
       " and channel ~= \"INSTANCE_CHAT\" then\n",
       " then\n",
       "raidsplit-review: a hello on INSTANCE_CHAT is refused",
       expect="a hello heard on INSTANCE_CHAT was refused", script=S)

# ------------------------------------------------------------ the 45 seconds
# A stretch with no scan in it starts the count again, as every fight did.
mutate("Share.lua",
       "\tif InCombatLockdown() or now - last > LAPSE then return since + (now - last) end\n",
       "\tif now - last > LAPSE then return now end\n"
       "\tif InCombatLockdown() then return since + (now - last) end\n",
       "raidsplit-review: the 45 seconds start again after a fight",
       expect="20 seconds before a fight and 26 after it, and Dain is still not offered", script=S)

# Somebody the walk has nothing for is never told to Share: buffed and bare
# again, the old count goes on.
mutate("Queue.lua",
       "\t\t\tns.ShareSaw(opts, queue)\n",
       "",
       "raidsplit-review: a count goes on after they were buffed",
       expect="missing it again after being buffed, Dain is offered with no grace given to Bert", script=S)

# ------------------------------------------------------------ the group cast
# `+` for a group version learned, the reagent or no.
mutate("Share.lua",
       "\t\tlocal ready = ns.GroupStocked and ns.GroupStocked(db, castable)\n",
       "\t\tlocal ready = ns.GroupReady and ns.GroupReady(db, castable)\n",
       "raidsplit-review: a hello says + with no reagent",
       expect="with no Arcane Powder in the bags the hello reads", script=S)

# Left to the other user for good.
mutate("Share.lua",
       "\tif over[bucket.buff.key] == now or now - cast.since >= GRACE then return false end\n",
       "",
       "raidsplit-review: a group cast left to another user never comes back",
       expect="left to Anna for 46 seconds and never cast, the group cast is still not offered to Bert", script=S)

# ------------------------------------------------------------ yourself
# Your own entry never asks whose the party-wide buff is.
mutate("Queue.lua",
       "\tif ns.WIDE_CASTS == true and ns.ShareHoldsSelf and ns.ShareHoldsSelf(mine, queue, now) then\n",
       "\tif false then\n",
       "raidsplit-review: a party-wide buff of another user's is offered on yourself",
       expect="Anna casts the party's Fortitude, and Bert is offered it on", script=S)

# ------------------------------------------------------------ the verdict
# Kept for the fold, they are turned down there and then.
mutate("Queue.lua",
       "\t\t\t\trejected[full] = \"fold\"\n",
       "\t\t\t\trejected[full] = true\n",
       "raidsplit-review: who a group cast is aimed at reads as turned down",
       expect="whom the same scan calls turned down", script=S)

# And nobody says so when nothing came of the fold.
mutate("Queue.lua",
       "\t\t\tif entry.foldOnly and rejected[entry.name] == \"fold\" then rejected[entry.name] = true end\n",
       "",
       "raidsplit-review: kept for a fold that made nothing, and never turned down",
       expect="kept for a fold that made no group cast, is not turned down", script=S)

# ------------------------------------------------------------ switched off
# The roster read at every change, for a hello that will never be said.
mutate("Share.lua",
       "(me.on == false and self.said == self.sig)) and not Sharing() then\n",
       "(me.on == false and self.said == self.sig)) and false then\n",
       "raidsplit-review: the roster is read with sharing off",
       expect="with sharing off, a roster change asked after", script=S)

# Switched off after a hello, and nobody is told.
mutate("Share.lua",
       "\tif next(users) == nil and (self.said == nil or (me.on == false and self.said == self.sig)) and not",
       "\tif next(users) == nil and not",
       "raidsplit-review: switched off after a hello, it is never said",
       expect="switched off after a hello, 0 hellos said so", script=S)
