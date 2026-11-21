# Mutations for pass 2, the fight lens: tests/scenarios/pass2-fight.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back one of the
# faults the pass found and names the scenario that objects.

S = "runscenarios.py"
P = "pass2-fight: "
HOLD = 'button:SetAttribute("pressAndHoldAction", true)'

# --- a key press is a down click ---------------------------------------------

mutate("Prompt/FightKey.lua", HOLD, "-- " + HOLD,
       "pass2-fight: the fight key without pressAndHoldAction",
       expect=P + "the fight key casts on its key with ActionButtonUseKeyDown off", script=S)

mutate("Prompt/CureFight.lua", HOLD, "-- " + HOLD,
       "pass2-fight: the cure button without pressAndHoldAction",
       expect=P + "the cure button casts on its key with ActionButtonUseKeyDown off", script=S)

mutate("Prompt/BreakFree.lua", HOLD, "-- " + HOLD,
       "pass2-fight: the break-free button without pressAndHoldAction",
       expect=P + "the break-free button casts on its key with ActionButtonUseKeyDown off", script=S)

mutate("Prompt/MendPet.lua", HOLD, "-- " + HOLD,
       "pass2-fight: the mend-pet button without pressAndHoldAction",
       expect=P + "the mend-pet button casts on its key with ActionButtonUseKeyDown off", script=S)

# --- the cure button takes no click out of sight ------------------------------

mutate("Prompt/CureFight.lua", "button:EnableMouse(keyLabel == nil)",
       "button:EnableMouse(true)",
       "pass2-fight: the cure button takes clicks with its key bound",
       expect=P + "out of sight with its key bound the cure button takes no click", script=S)

# --- a secret is never compared ------------------------------------------------

mutate("Prompt/BreakFree.lua", 'elseif type(raw) ~= "nil" then',
       "elseif raw ~= nil then",
       "pass2-fight: ReadLoss compares a possibly secret record",
       expect=P + "ReadLoss never compares a possibly secret record", script=S)
