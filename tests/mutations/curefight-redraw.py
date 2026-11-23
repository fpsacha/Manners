# Mutations for the game's aura display following a token that names somebody
# else now (Prompt/CureNeed.lua, Redraw; GitHub issue 43). Each is caught by the
# scenario in tests/scenarios/curefight-redraw.lua that names it.

S = "runscenarios.py"
CN = "Prompt/CureNeed.lua"
P = "curefight-redraw: "

mutate(CN,
       "\tif wrap then Redraw(wrap, WrapWanted(unit, watched)) end\n",
       "\tif wrap then wrap:SetShown(WrapWanted(unit, watched)) end\n",
       P + "a new target keeps the old one's display",
       expect=P + "forever: a new friend targeted in a fight is drawn, not the last one", script=S)

mutate(CN,
       "\t\tRedraw(need.wraps[unit], WrapWanted(unit, watched))\n",
       "\t\tneed.wraps[unit]:SetShown(WrapWanted(unit, watched))\n",
       P + "a reshuffled party keeps the old holders' display",
       expect=P + "forever: the party reordered in a fight is drawn for who each token names now", script=S)

mutate(CN,
       "\twrap:Hide()\n\twrap:SetShown(on)\n",
       "\twrap:SetShown(on)\n",
       P + "a wrap already up is never redrawn",
       expect=P + "forever: a new friend targeted in a fight is drawn, not the last one", script=S)
