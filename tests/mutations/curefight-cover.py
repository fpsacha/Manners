# The Combat module's cover and first/second-click rule.

S = "runscenarios.py"
N = "curefight-cover: "

mutate("Modules/Combat/CureFight.lua",
       "\t\tif FirstOfTwo(slot, mouse) then return end\n",
       "\t\tif false then return end\n",
       "curefight-cover: the dark cure cover casts on its first click",
       expect="curefight-container: forever: one click casts nothing, the second of two casts", script=S)
