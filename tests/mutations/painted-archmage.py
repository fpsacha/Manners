# Mutations for Archmage (Arcane Mage) in its painted frame (Looks/Archmage.lua's
# paintedHides, PaintedPlace, PaintedStyled and its Tone line): the crystal
# shown under the painting, the words started off the well, the charges left
# unturned, the key's letter left off the keycap, the count's tag over the
# keycap, the list under what the socket hangs, a fight leaving the painting
# bright. Each is caught by the scenario in tests/scenarios/painted-archmage.lua
# that names it.

S = "runscenarios.py"

mutate("Looks/Archmage.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"bezel\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"bezel\", \"keyChip\" },\n",
       "painted-archmage: the crystal drawn under the painting",
       expect="painted-archmage: Archmage wears its painting and none of its own frame", script=S)

mutate("Looks/Archmage.lua",
       "\tself.textX = g.textX\n",
       "",
       "painted-archmage: the words start where the crystal had them",
       expect="painted-archmage: the icon and the charges sit in the socket", script=S)

mutate("Looks/Archmage.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * pf, pc[2] * pf, pc[3] * pf, on)\n",
       "",
       "painted-archmage: a fight leaves the painting bright",
       expect="painted-archmage: a fight greys the painting", script=S)

mutate("Looks/Archmage.lua",
       "\tTurnSetting(self, true)\n",
       "",
       "painted-archmage: the charges left lying flat in the standing hexagon",
       expect="painted-archmage: Archmage wears its painting and none of its own frame", script=S)

mutate("Looks/Archmage.lua",
       "\tTurnSetting(self, false)\n",
       "",
       "painted-archmage: Earlier art keeps the charges turned",
       expect="painted-archmage: Earlier art brings Archmage's own frame back", script=S)

mutate("Looks/Archmage.lua",
       "\tlocal bz = g.socketR * PAINT_BZ\n",
       "\tlocal bz = g.socketR * PAINT_BZ * 1.3\n",
       "painted-archmage: the charges laid over the painted gold",
       expect="painted-archmage: the icon and the charges sit in the socket", script=S)

mutate("Looks/Archmage.lua",
       "\tself.mask:SetTexture(ROUND_MASK, \"CLAMPTOBLACKADDITIVE\", \"CLAMPTOBLACKADDITIVE\")\n",
       "",
       "painted-archmage: a flat hexagon icon in the standing socket",
       expect="painted-archmage: Archmage wears its painting and none of its own frame", script=S)

mutate("Looks/Archmage.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -8, 0)\n",
       "painted-archmage: the key's letter off the painted keycap",
       expect="painted-archmage: the icon and the charges sit in the socket", script=S)

mutate("Looks/Archmage.lua",
       "\tself.chipRight = math.ceil(W - keyR)\n",
       "\tself.chipRight = 8\n",
       "painted-archmage: the count's tag over the keycap",
       expect="painted-archmage: the charges, the count's tag and the list", script=S)

mutate("Looks/Archmage.lua",
       "\tself.listGap = math.max(0, (above and -g.y0 or (g.y1 - self.H)) * 0.85)\n",
       "",
       "painted-archmage: the list under what the socket hangs",
       expect="painted-archmage: the charges, the count's tag and the list", script=S)

mutate("Looks/Archmage.lua",
       "\tself.keyText:SetParent(kit.textLayer)\n",
       "",
       "painted-archmage: Earlier art leaves the key's letter on the keycap's frame",
       expect="painted-archmage: Earlier art brings Archmage's own frame back", script=S)
