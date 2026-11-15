# Mutations for the fight's three weak points of the 2026-11-15 review
# (Prompt/Fight.lua, Prompt/Macro.lua, Prompt/Refresh.lua, Clicks.lua's bar
# macro, Queue.lua's remembered passers-by). Caught by
# tests/scenarios/par-core2.lua.

S = "runscenarios.py"
FIGHT = "Prompt/Fight.lua"
REFRESH = "Prompt/Refresh.lua"
GONE = "par-core2: a pull three seconds after a crowd walked off arms none of them"

# 1. What the pull arms: nobody offered from memory alone.
mutate(FIGHT,
       "\t\tif entry.remembered and entry.reason == \"nearby\" then\n",
       "\t\tif false then\n",
       "par-core2: the pull keeps passers-by remembered",
       expect=GONE, script=S)

mutate("Queue.lua",
       "\t\t\t\tremembered = true,\n",
       "",
       "par-core2: a remembered passer-by is not marked as one",
       expect=GONE, script=S)

mutate(REFRESH,
       "\tif ArmingForFight() then queue = ForFight(queue) end\n",
       "",
       "par-core2: the pull's repaint arms the queue as built",
       expect="par-core2: at a pull with one passer-by still beside you and two gone", script=S)

mutate(FIGHT,
       "\t\tif entry.remembered and entry.reason == \"nearby\" then\n",
       "\t\tif entry.unit == nil then\n",
       "par-core2: the pull leaves out everybody with no token",
       expect="par-core2: a favour owed with no token is still armed at the pull", script=S)

mutate(REFRESH,
       "\tif ArmingForFight() then queue = ForFight(queue) end\n",
       "\tqueue = ForFight(queue)\n",
       "par-core2: the memory is left out of every repaint",
       expect="par-core2: out of a fight a passer-by who walked off is still offered", script=S)

mutate(REFRESH,
       "\t\t\tif S.fightLine then\n",
       "\t\t\tif false then\n",
       "par-core2: the fuse after a fight keeps the fight's line",
       expect="par-core2: the fight over with nobody left, the second line no longer speaks of the fight", script=S)
