# Mutations for With Shift and With Ctrl set to Nothing (Prompt/CureFight.lua,
# ChoseNothing and Build; GitHub issue 43). Each is caught by the scenario in
# tests/scenarios/curefight-nothing.lua that names it.

S = "runscenarios.py"
CF = "Prompt/CureFight.lua"
P = "curefight-nothing: "

mutate(CF,
       "\tif not ctrlSpell and none.ctrl and (shiftSpell or plainSpell) then parts[#parts + 1] = \"[mod:ctrl] \" end\n",
       "",
       P + "Ctrl on Nothing casts the plain cure",
       expect=P + "Ctrl set to Nothing casts nothing", script=S)

mutate(CF,
       "\tif not shiftSpell and none.shift and plainSpell then parts[#parts + 1] = \"[mod:shift] \" end\n",
       "",
       P + "Shift on Nothing casts the plain cure",
       expect=P + "Shift set to Nothing casts nothing", script=S)

mutate(CF,
       "\tnone.ctrl = none.ctrl and not slots[1].ctrlKey\n",
       "",
       P + "a Ctrl key with Ctrl on Nothing casts nothing",
       expect=P + "a key bound with Ctrl keeps casting with Ctrl on Nothing", script=S)
