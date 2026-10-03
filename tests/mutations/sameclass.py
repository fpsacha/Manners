# Mutations for tests/scenarios/sameclass.lua.

S = "runscenarios.py"

# The option never applied.
mutate("Queue.lua",
       "\t\topts.skip = SelfServed\n",
       "",
       "sameclass: never skipped",
       expect="who can cast your rank 2 Intellect, is still offered",
       script=S)

# A blessing he could give himself picked for him all the same.
mutate("Core.lua",
       "\t\t\t\t\telseif not skipped then\n",
       "\t\t\t\t\telse\n",
       "sameclass: a paladin offered what he gives himself",
       expect="sameclass: a paladin who can give himself the rest is offered Kings",
       script=S)

# Skipped blessings dropped before the aura read: your Wisdom on him no
# longer covers him, and Kings would replace it.
mutate("Core.lua",
       "\t\t\t\tif Castable(opts, buff) then\n\t\t\t\t\t-- One they could give themselves is still read",
       "\t\t\t\tif Castable(opts, buff) and not Skipped(opts, buff) then\n\t\t\t\t\t-- One they could give themselves is still read",
       "sameclass: your blessing on him not read",
       expect="sameclass: a paladin wearing your Wisdom is not walked onto Kings",
       script=S)

# The rank ignored: every mage skipped, lowbies included.
mutate("Queue.lua",
       "\tlocal need = ns.RankLevel(info and info.topRank) or 1\n",
       "\tlocal need = 1\n",
       "sameclass: the rank ignored",
       expect="too low for your rank 2 Intellect, was skipped",
       script=S)

# A favour owed skipped too.
mutate("Queue.lua",
       "\t\tlocal same = f.skipSameClass == true and not pointed and (reason == \"group\" or reason == \"nearby\")\n",
       "\t\tlocal same = f.skipSameClass == true and not pointed\n",
       "sameclass: a favour owed skipped",
       expect="a mage who buffed you was skipped",
       script=S)
