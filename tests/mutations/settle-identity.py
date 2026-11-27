# Cast settlement must not turn a missing spell id into a match merely because
# the target named by the event is the pending press's target.

S = "runscenarios.py"

mutate("Clicks.lua",
       "\tif spellId == nil then return boundToPress == true end\n",
       "\tif spellId == nil then return true end\n",
       "settle: a missing spell id counts as ours",
       expect="settle-identity: a secret-id unrelated cast cannot settle the same target",
       script=S)
