# Mutations for Warrior's painted frame (Looks/Forge.lua's paintedHides,
# PaintedPlace, PaintedStyled and its one Painted.Tone line): Forge wearing its
# painting and none of its own frame, Earlier art giving every piece back, the
# words in the well, the key on the keycap, the slot's heat on the painted seam,
# the list clear of the painting, a fight greying it. Each is caught by the
# scenario in tests/scenarios/painted-forge.lua that names it.

S = "runscenarios.py"
F = "Looks/Forge.lua"

mutate(F,
       "\tpaintedHides = { \"shadow\", \"plate\", \"strapTop\",",
       "\tpaintedHides = { \"shadow\", \"strapTop\",",
       "painted-forge: the plate drawn under the painting",
       expect="Forge's own frame is drawn under the painting", script=S)

mutate(F,
       "\tself.iconSize, self.textX, self.bezelRight = iconSize, g.textX, g.socketX + frame\n",
       "\tself.iconSize, self.bezelRight = iconSize, g.socketX + frame\n",
       "painted-forge: the words start where the plate had them",
       expect="the name starts at", script=S)

mutate(F,
       "\tlocal dy = H / 2 - g.textY\n",
       "\tlocal dy = 0\n",
       "painted-forge: the lines left at the plate's middle, off the well",
       expect="the lines centre at", script=S)

mutate(F,
       "\tns.Looks.Painted.Tone(self, pc[1] * f, pc[2] * f, pc[3] * f, on)\n",
       "",
       "painted-forge: a fight leaves the painting as it was",
       expect="in a fight the painting is not greyed", script=S)

mutate(F,
       "\tns.Looks.Painted.Tone(self, pc[1] * f, pc[2] * f, pc[3] * f, on)\n",
       "\tns.Looks.Painted.Tone(self, pc[1], pc[2], pc[3], on)\n",
       "painted-forge: a fight greys the painting without dimming it",
       expect="in a fight the painting is not dimmed a little", script=S)

mutate(F,
       "\t\tself.keyBox:SetPoint(\"CENTER\", self.kit.art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\t\tself.keyBox:SetPoint(\"CENTER\", self.kit.art, \"TOPLEFT\", g.keyX - g.keyW, -g.keyY)\n",
       "painted-forge: the key's letter beside the keycap",
       expect="the key's letter is at", script=S)

mutate(F,
       "\tself.keyText:SetParent(self.chipFrame)\n",
       "",
       "painted-forge: the key's letter dims with the words in a fight",
       expect="the key's letter dims with the words", script=S)

mutate(F,
       "\tself.keyText:SetTextColor(ink[1], ink[2], ink[3], 1)\n",
       "",
       "painted-forge: the key's letter in the tag's cream, not the keycap's ink",
       expect="the key's letter is not in the keycap's ink", script=S)

mutate(F,
       "\tband(self.slot, SEAM_LINE / 2, SEAM_LINE / 2)\n",
       "",
       "painted-forge: the slot left beside the icon, off the painted seam",
       expect="the slot lies at", script=S)

mutate(F,
       "\tband(self.core, SEAM_CORE / 2, SEAM_CORE / 2)\n",
       "",
       "painted-forge: the owed breath left beside the icon",
       expect="the breath is not on the seam", script=S)

mutate(F,
       "\tself.listGap = math.max(0, above and -g.y0 or (g.y1 - H)) + 1\n",
       "\tself.listGap = 0\n",
       "painted-forge: the list's plate hung over the painting's foot",
       expect="over the painting's foot", script=S)

mutate(F,
       "\tself.chipInset = math.ceil(W - keyL) + 3\n",
       "\tself.chipInset = 8\n",
       "painted-forge: the lines and the count's tag run onto the keycap",
       expect="past the keycap at", script=S)

mutate(F,
       "\tself.slot:SetTexture(ART .. \"Slot\")\n",
       "",
       "painted-forge: Earlier art keeps the seam's texture on the slot",
       expect="with Earlier art on, the slot draws", script=S)

mutate(F,
       "\tself.keyText:SetParent(kit.textLayer)\n",
       "",
       "painted-forge: Earlier art leaves the key's letter on the painted layer",
       expect="with Earlier art on, the key's letter is not on the words' layer", script=S)

mutate(F,
       "\tlocal tag = keyUp and (self.keyWide or not ns.Looks.Painted.On(self))\n",
       "\tlocal tag = keyUp and not ns.Looks.Painted.On(self)\n",
       "painted-forge: a long key's label left bare over the keycap",
       expect="has no tag under it", script=S)

mutate(F,
       "\t\tself.keyW = math.max(g.keyW, textW + 10)\n",
       "\t\tself.keyW = g.keyW\n",
       "painted-forge: a long key squeezed onto the keycap",
       expect="the tag is", script=S)
