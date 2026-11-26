# The Combat module's Plain, Shift and Ctrl cure choices.

S = "runscenarios.py"
N = "curefight-mods: "

mutate("Modules/Combat/CureFight.lua",
       "\tif ctrlSpell then parts[#parts + 1] = Clause(ctrlSpell.name, \"ctrl\") end\n",
       "",
       "curefight-mods: Ctrl is left out of a cure macro",
       expect=N + "a druid's three cures go plain, Shift and Ctrl", script=S)
