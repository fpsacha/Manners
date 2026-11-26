# The Combat module's client-owned aura display on secret-aura clients.

S = "runscenarios.py"
N = "curefight-container: "

mutate("Modules/Combat/CureFight.lua",
       "\t\t\tif slot.button and CureNeed and CureNeed.Attach(index, slot.button) then CureNeed.SetKinds(index, kinds) end\n",
       "",
       "curefight-container: Forever never gets the game's aura display",
       expect=N + "forever: the game shows the debuff", script=S)
