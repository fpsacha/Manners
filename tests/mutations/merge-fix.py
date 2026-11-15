# Mutations for the fixes after the painted looks were merged
# (tests/scenarios/merge-fix.lua): the middle reaching under each end, the
# keycap stepping aside on a narrow prompt (the engine's, the framed
# painting's, the glass's lines), the framed painting's outline frame put away
# with it, the rows past the list's own left where the earlier art lays them,
# and the wash given back the whole panel for Minimal as for Framed.

S = "runscenarios.py"
P = "Prompt/Panel.lua"
E = "Looks/Painted.lua"

mutate(E,
       "local SEAM = 1\n",
       "local SEAM = 0\n",
       "merge-fix: the pieces butted edge to edge again",
       expect="merge-fix: every painting's middle reaches a unit under each end", script=S)

mutate(E,
       "\treturn art ~= nil and art.on == true and art.keyFits ~= false and Looks.KeyWanted(look)\n",
       "\treturn art ~= nil and art.on == true and Looks.KeyWanted(look)\n",
       "merge-fix: the keycap stands on a prompt too narrow for the words",
       expect="the keycap stands with", script=S)

mutate(E,
       "\tif not up and art.on and look.keyText then look.keyText:Hide() end\n",
       "",
       "merge-fix: the key's letter left written with the keycap gone",
       expect="the key's letter is written with the keycap gone", script=S)

mutate(E,
       "\treturn g.keyX - g.keyW / 2 - textX >= KEY_ROOM_EMS * (fontSize or 0)\n",
       "\treturn g.keyX - g.keyW / 2 - textX >= 3 * KEY_ROOM_EMS * (fontSize or 0)\n",
       "merge-fix: the keycap dropped at the prompt's own size",
       expect="at 320x58 the keycap is not drawn", script=S)

mutate(P,
       "\t\t\tself.keyText:Hide()\n\t\t\tself.keyLabel = nil\n\t\t\tself.outline:Hide()\n",
       "\t\t\tself.keyText:Hide()\n\t\t\tself.keyLabel = nil\n",
       "merge-fix: the framed painting's outline left switched on under another look",
       expect="a frame is switched on that was not before", script=S)

mutate(P,
       "\t\tlocal x = i <= rowCount and rowX or panelX\n",
       "\t\tlocal x = rowX\n",
       "merge-fix: the rows past the list's own left where the framed painting moved them",
       expect="selftest-launch: nothing is left changed (the prompt in", script=S)

mutate(P,
       "\tR.resultFill:ClearAllPoints()\n\tR.resultFill:SetAllPoints(R.art)\n\tif dress and p.classicArt",
       "\tif dress and p.classicArt",
       "merge-fix: the wash left on Minimal's pane for another look",
       expect="the wash is still laid on Minimal's pane", script=S)
