# Mutations for the cure button where only the game knows who needs a cure
# (Prompt/CureNeed.lua, Prompt/CureFight.lua; GitHub issue 43). Each is caught
# by the scenario in tests/scenarios/curefight-container.lua that names it.

S = "runscenarios.py"
CN = "Prompt/CureNeed.lua"
CF = "Prompt/CureFight.lua"
P = "curefight-container: "

mutate(CN,
       "\t\tRedraw(need.wraps[unit], WrapWanted(unit, watched))\n",
       "\t\tRedraw(need.wraps[unit], false)\n",
       P + "the game's display shows nobody in a fight",
       expect=P + "forever: the game shows the debuff on the cure button in a fight", script=S)

mutate(CN,
       "\tneed.holder:Hide()\n\tif need.mark then need.mark:Hide() end\n",
       "\tif need.mark then need.mark:Hide() end\n",
       P + "the game's display stays up after the fight",
       expect=P + "forever: the game shows the debuff on the cure button in a fight", script=S)

mutate(CN,
       "\t\t\tneed.boxes[unit]:SetAuraSlotCandidateFilters(SLOT, { includeDispelTypes = set })\n",
       "",
       P + "a button's display shows every kind",
       expect=P + "forever: each button's display shows only its own kinds", script=S)

mutate(CN,
       "\tif unit == \"target\" or unit == \"focus\" then return plain(UnitCanAssist(\"player\", unit)) == true end\n",
       "",
       P + "an enemy's debuffs are shown",
       expect=P + "forever: an enemy targeted is never shown", script=S)

mutate(CF,
       "\t\t\tif slots[index].gameOn then CureNeed.Retarget(index, \"target\", watched) end\n",
       "",
       P + "a target taken in the fight is never shown",
       expect=P + "forever: an enemy targeted is never shown", script=S)

mutate(CF,
       "\tif not (slot.gameOn and not slot.visible) then return false end\n",
       "\tif true then return false end\n",
       P + "the cover never opens where only the game knows",
       expect=P + "forever: one click casts nothing, the second of two casts", script=S)

mutate(CF,
       "local OPEN_GAP = 0.3\n",
       "local OPEN_GAP = 0\n",
       P + "a double click casts",
       expect=P + "forever: one click casts nothing, the second of two casts", script=S)

mutate(CF,
       "\t\t\tif slot.openUntil == opened then ns.Guard(\"cure in a fight\", Close, slot) end\n",
       "",
       P + "the first of two never closes",
       expect=P + "forever: the first of two closes by itself", script=S)

mutate(CF,
       "\t\tClose(slot)\n\tend\n\tlocal pending = ns.pendingClick\n",
       "\tend\n\tlocal pending = ns.pendingClick\n",
       P + "the cover stays down after the second click",
       expect=P + "forever: one click casts nothing, the second of two casts", script=S)

mutate(CF,
       "\t\tslot.gameOn = slot.button ~= nil and slot.list ~= nil and CureNeed ~= nil and CureNeed.Begin(index, watched)\n",
       "\t\tslot.gameOn = true\n",
       P + "the two clicks open with no display under the button",
       expect=P + "a click on the dark button never casts without the game's display", script=S)

mutate(CN,
       "\tif probed == true then return \"from the game's aura display\" end\n",
       "",
       P + "the debug line never says the game's display",
       expect=P + "the debug line and the self-test say where the need comes from", script=S)

mutate("Selftest.lua",
       "\tadd(PASS, \"cure need: \" .. (ns.CureNeed and ns.CureNeed.Words() or \"from the auras\"))\n",
       "",
       P + "the self-test never says where the need comes from",
       expect=P + "the debug line and the self-test say where the need comes from", script=S)

mutate(CN,
       "\tif caps.secretRestrictions ~= true then\n\t\tprobed = false\n",
       "\tif false then\n\t\tprobed = false\n",
       P + "the display is made where the auras are read",
       expect=P + "the debug line and the self-test say where the need comes from", script=S)
