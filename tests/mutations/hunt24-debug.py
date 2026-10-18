# Mutations for tests/scenarios/hunt24-debug.lua: each puts back the fault it
# fixes (/manners debug and the Diagnostics tab reading "none up -- X is the
# one to cast" while your own name is on the never-offer list), or breaks what
# the fix has to keep.

S = "runscenarios.py"
WHAT = "your own name on the never-offer list is what /manners debug says"

# The family lines go on after the line about the list, each naming a spell the
# prompt will never put up for you.
mutate("Commands.lua",
       "\t\tif held == \"listed\" then return out end\n",
       "",
       "hunt24-debug: the family lines go on naming a spell while you are listed",
       expect=WHAT,
       script=S)

# MyselfHeldBack says you are held back, and /manners debug has no line for it.
mutate("Commands.lua",
       "\t\tlisted = L[\"your own buffs: held back -- you are on your never-offer list.\"],\n",
       "",
       "hunt24-debug: no line says you are on the never-offer list",
       expect=WHAT,
       script=S)

# Anybody on the list, not you, holds your own buffs back.
mutate("Queue.lua",
       "\tif ns.IsNeverOffered(full) then return \"listed\" end\n",
       "\tif NeverSet() and next(NeverSet()) ~= nil then return \"listed\" end\n",
       "hunt24-debug: somebody else on the list holds your own buffs back",
       expect=WHAT,
       script=S)
