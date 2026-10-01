# Mutations for tests/scenarios/sameclass.lua.

S = "runscenarios.py"

# The option never applied.
mutate("Queue.lua",
       "\tif SelfServed(candidate, opts) then return true end\n",
       "",
       "sameclass: never skipped",
       expect="who can cast your rank 2 Intellect, is still offered",
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
