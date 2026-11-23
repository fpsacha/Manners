# Mutations for the rank a macro names for a low-level target, Fortitude's
# report (GitHub issue 42): only ranks you know (Core.lua LandingRank,
# ProbeBuff), the client's rank words asked for at the probe and again at the
# macro (Prompt/Macro.lua RankText), and a remembered passer-by's level
# (Queue.lua). Each is caught by the scenario in
# tests/scenarios/downrank-fortitude.lua that names it.

S = "runscenarios.py"

mutate("Core.lua",
       "\t\tlocal at = (not known or known[rank]) and ns.RankLevel(rank)\n",
       "\t\tlocal at = ns.RankLevel(rank)\n",
       "downrank-fort: a rank never learned is named",
       expect="downrank-fort: forever: a rank never learned is skipped", script=S)

mutate("Core.lua",
       "\t\t\t\t\tsafecall(C_Spell and C_Spell.RequestLoadSpellData, id)\n",
       "",
       "downrank-fort: the probe does not ask for the rank words",
       expect="downrank-fort: the rank's words are asked for at login", script=S)

mutate("Prompt/Macro.lua",
       "\t\t\tasked[id] = now\n\t\t\tload(id)\n",
       "\t\t\tasked[id] = now\n",
       "downrank-fort: the macro does not ask for words not loaded",
       expect="downrank-fort: words not loaded are asked for again by the macro", script=S)

mutate("Prompt/Macro.lua",
       "\t\tif not text then Unnamed(entry, name, \"text\") end\n",
       "",
       "downrank-fort: debug does not say the rank went unnamed",
       expect="downrank-fort: words not loaded are asked for again by the macro", script=S)

mutate("Queue.lua",
       "\t\t\tif memo.level then queue[#queue].level = memo.level end\n",
       "",
       "downrank-fort: a remembered passer-by has no level",
       expect="downrank-fort: a passer-by remembered keeps the rank for their level", script=S)
