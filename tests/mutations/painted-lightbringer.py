# Mutations for Lightbringer's painted frame (Looks/Lightbringer.lua's
# paintedHides, PaintedPlace, PaintedStyled, Chip and Dull under a painting):
# its own frame hidden under the painting, the words in the well, the key on
# the keycap, the nimbus in the socket, the count's tag and the list clear of
# the painting, a fight greying it. Each is caught by the scenario in
# tests/scenarios/painted-lightbringer.lua that names it.

S = "runscenarios.py"

mutate("Looks/Lightbringer.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"sun\", \"rays\", \"raysWarm\", \"gem\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"sun\", \"rays\", \"raysWarm\", \"gem\", \"keyChip\" },\n",
       "painted-lightbringer: its plate drawn under the painting",
       expect="Lightbringer's own frame is drawn under the painting", script=S)

mutate("Looks/Lightbringer.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"sun\", \"rays\", \"raysWarm\", \"gem\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"body\", \"sun\", \"rays\", \"raysWarm\", \"gem\" },\n",
       "painted-lightbringer: its key tag over the painted keycap",
       expect="its own key tag", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.textX = g.textX\n\tAt(self.nimbus, art, sx, sy, bz)\n",
       "\tAt(self.nimbus, art, sx, sy, bz)\n",
       "painted-lightbringer: the words where its own frame had them",
       expect="the well's text at", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.textX = g.textX\n\tAt(self.nimbus, art, sx, sy, bz)\n",
       "\tself.textX = g.textX\n",
       "painted-lightbringer: the nimbus off the socket",
       expect="the nimbus is not round the icon in the socket", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal dy = H / 2 - g.textY\n",
       "\tlocal dy = H / 2 - g.textY + 0.6 * g.unit\n",
       "painted-lightbringer: the lines off the well",
       expect="off the well", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -self.chipInset, 0)\n",
       "painted-lightbringer: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.chipInset = math.ceil(self.W - keyL) + 3\n\tself.keyBox:ClearAllPoints()\n",
       "\tself.keyBox:ClearAllPoints()\n",
       "painted-lightbringer: the words and the count's tag over the keycap",
       expect="past the keycap at", script=S)

mutate("Looks/Lightbringer.lua",
       "\t\tkeyUp = ns.Looks.Painted.On(self) or self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = self:NameFits(self.keyRoom) and not ns.Looks.Painted.On(self)\n",
       "painted-lightbringer: no letter on the painted keycap",
       expect="the key's letter is not drawn", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.keyText:SetParent(self.chipFrame)\n",
       "",
       "painted-lightbringer: the key's letter dims with the words",
       expect="dims with the words in a fight", script=S)

mutate("Looks/Lightbringer.lua",
       "\tself.listGap = math.max(0, (above and -g.y0 or (g.y1 - H)) * 0.85)\n",
       "\tself.listGap = 0\n",
       "painted-lightbringer: the list under the painting's rays",
       expect="into what the painting hangs below the bar", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal gap = self.listGap or 0\n",
       "\tlocal gap = 0\n",
       "painted-lightbringer: the list's rows not moved by the gap",
       expect="into what the painting hangs below the bar", script=S)

mutate("Looks/Lightbringer.lua",
       "\tlocal x0, x1 = self.listX0 or self.plateX, self.listX1 or self.W\n",
       "\tlocal x0, x1 = self.plateX, self.W\n",
       "painted-lightbringer: the list's plate under the libram",
       expect="the list's plate runs past the keycap's far side", script=S)

mutate("Looks/Lightbringer.lua",
       "\tif ns.Looks.Painted and ns.Looks.Painted.On(self) then sun = false end\n",
       "",
       "painted-lightbringer: the hidden rays turn under the painting",
       expect="the hidden rays turn under the painting", script=S)

mutate("Looks/Lightbringer.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * f, pc[2] * f, pc[3] * f, on)\n",
       "",
       "painted-lightbringer: a fight leaves the painting in colour",
       expect="in a fight the painting is not greyed", script=S)
