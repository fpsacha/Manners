# Mutations for the framed look's painting (Prompt/Panel.lua, the dressing
# after ApplyLook, and the Ground call in ApplyStyle): the painting worn and
# the flat panel, rim and shadow gone; Earlier art taking the dressing off; a
# prompt too narrow keeping the earlier art; the icon in the socket, the words
# in the well and the key on the keycap; the reason's mark, the count chip and
# the list kept; the words held to the washed well; a fight greying the
# painting and letting it go; the wash on the well and given back after.
# Each is caught by the scenario that names it (tests/scenarios/painted-framed.lua,
# and the shared files where the framed look's light is held to its room).

S = "runscenarios.py"
P = "Prompt/Panel.lua"

# --- worn, and Earlier art ---

mutate(P,
       "\t\t\tR.panel:Hide()\n\t\t\tfor _, list in ipairs({ R.tooltipRim, R.shadows }) do\n",
       "\t\t\tfor _, list in ipairs({ R.tooltipRim, R.shadows }) do\n",
       "painted-framed: the flat panel drawn under the painting",
       expect="painted-framed: Framed wears its painting and none of its own frame", script=S)

mutate(P,
       "\tif dress and dress.Wanted and not dress:Wanted(p) then dress = nil end\n",
       "",
       "painted-framed: Earlier art keeps the painting's dressing on",
       expect="look-glass: Gryphons at the ends takes them away", script=S)

mutate(P,
       "\t\t\tif g and g.unit < p.height * SMALLEST then g = nil end\n",
       "",
       "painted-framed: a prompt too narrow has the painting drawn smaller, off the words",
       expect="painted-framed: the pieces follow the prompt's size and meet", script=S)

# --- the socket, the well and the keycap ---

mutate(P,
       "\t\t\treturn setmetatable({ width = wide, bgColor = self.ground }, { __index = p }), g.textX, room\n",
       "\t\t\treturn setmetatable({ width = wide, bgColor = self.ground }, { __index = p }), textX, room\n",
       "painted-framed: the words start where the earlier art had them, not in the well",
       expect="painted-framed: the icon sits in the socket, the words start in the well", script=S)

mutate(P,
       "\t\t\tR.icon:SetPoint(\"CENTER\", R.art, \"TOPLEFT\", g.socketX, -g.socketY)\n",
       "\t\t\tR.icon:SetPoint(\"CENTER\", R.art, \"TOPLEFT\", g.socketX + 4, -g.socketY)\n",
       "painted-framed: the icon off its socket",
       expect="painted-framed: the icon sits in the socket", script=S)

mutate(P,
       "\t\t\tlocal wide = keyUp and (keyL - 4 + EDGE_ROOM) or p.width\n",
       "\t\t\tlocal wide = p.width\n",
       "painted-framed: the words may run under the keycap",
       expect="past the keycap", script=S)

mutate(P,
       "\t\t\tself.keyText:SetShown(up)\n",
       "\t\t\tself.keyText:SetShown(false)\n",
       "painted-framed: no letter on the keycap",
       expect="painted-framed: the icon sits in the socket, the words start in the well and the key is on the keycap",
       script=S)

# --- what is kept ---

mutate(P,
       "\t\t\tif not mark then\n\t\t\t\tR.bezel:Hide()\n",
       "\t\t\tif false then\n\t\t\t\tR.bezel:Hide()\n",
       "painted-framed: the bezel covers the painted rim with the marker on the stripe",
       expect="painted-framed: the reason's mark, the count chip and the list", script=S)

mutate(P,
       "\t\t\tR.countChip:SetPoint(\"RIGHT\", R.art, \"TOPLEFT\", chipRight, -g.keyY)\n",
       "\t\t\tR.countChip:SetPoint(\"RIGHT\", R.art, \"TOPLEFT\", chipRight + 30, -g.keyY)\n",
       "painted-framed: the count chip off the keycap's place",
       expect="painted-framed: the reason's mark, the count chip and the list", script=S)

mutate(P,
       "\t\t\tR.queueBack:SetVertexColor(w[1], w[2], w[3], LIST_ALPHA)\n",
       "",
       "painted-framed: the list on the panel colour, not the well's",
       expect="painted-framed: the reason's mark, the count chip and the list", script=S)

mutate(P,
       "\t\t\tink.lo, ink.hi = d.ink.lo, hi\n",
       "\t\t\tink.lo, ink.hi = d.ink.lo, d.ink.hi\n",
       "painted-framed: the words held to the well unwashed",
       expect="darker than the washed well", script=S)

mutate(P,
       "\t\t\tR.ruleTop:SetPoint(\"TOPLEFT\", R.art, \"TOPLEFT\", ruleX, -RULE_INSET)\n"
       "\t\t\tR.ruleTop:SetPoint(\"TOPRIGHT\", R.art, \"TOPRIGHT\", -RULE_END, -RULE_INSET)\n",
       "\t\t\tR.ruleTop:SetPoint(\"TOPLEFT\", R.art, \"TOPLEFT\", ruleX, -(g.wellTop + RULE_INSET))\n"
       "\t\t\tR.ruleTop:SetPoint(\"TOPRIGHT\", R.art, \"TOPRIGHT\", -RULE_END, -(g.wellTop + RULE_INSET))\n",
       "painted-framed: the top rule across the name",
       expect="a rule of light runs across the words", script=S)

# --- a fight, an outcome, another look ---

mutate(P,
       "\t\t\tPainted.Tone(self, k, k, k, on and true or false)\n",
       "",
       "painted-framed: a fight leaves the painting in colour",
       expect="painted-framed: a fight greys the painting", script=S)

mutate(P,
       "\t\t\tif self.fight then self:Combat(false) end\n",
       "",
       "painted-framed: a look picked in a fight leaves the painting grey",
       expect="painted-framed: another look picked in a fight leaves the painting in colour", script=S)

mutate(P,
       "\t\t\tBox(R.resultFill, x0, g.wellTop, x1, g.wellBottom)\n",
       "",
       "painted-framed: the wash over the steel, not the well",
       expect="the outcome's wash is not on the well", script=S)

mutate(P,
       "\tR.resultFill:ClearAllPoints()\n\tR.resultFill:SetAllPoints(R.art)\n\tif dress and p.classicArt",
       "\tif dress and p.classicArt",
       "painted-framed: the wash left on the well for another look",
       expect="the wash is still laid on Framed's well", script=S)
