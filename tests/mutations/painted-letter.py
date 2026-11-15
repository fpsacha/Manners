# Mutations for the Letter's painted frame (Looks/Letter.lua's paintedHides,
# PaintedPlace, PaintedLay, PaintedList, the Tone in PaintPaper): the painting
# worn over none of the letter's own sheet, the words in the well, the key on
# the keycap, the cover short of it, the list on the painting's parchment, a
# fight greying the painting, a refusal leaving it still, another look taking
# the letter's key back. Each is caught by tests/scenarios/painted-letter.lua.

S = "runscenarios.py"
F = "Looks/Letter.lua"

mutate(F,
       'paintedHides = { "sheetL", "sheetR", ',
       'paintedHides = { "sheetL", ',
       "painted-letter: the letter's own sheet drawn under the painting",
       expect="the Letter's own frame is drawn under the painting", script=S)

mutate(F,
       "\tself.textX = g.textX\n\tself.nameY = self.nameY + dy\n",
       "\tself.nameY = self.nameY + dy\n",
       "painted-letter: the words start where the letter's own seal ends, not in the painted well",
       expect="painted-letter: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\tns.Looks.Painted.Tone(self, r, g, b, k < 1)\n",
       "",
       "painted-letter: a fight leaves the painting in colour",
       expect="in a fight the painting is not greyed", script=S)

mutate(F,
       "\tif keyUp and pg then\n",
       "\tif keyUp and pg and false then\n",
       "painted-letter: the key's letter where the letter's own slip stood",
       expect="the key's letter is at", script=S)

mutate(F,
       "\tlocal stop = lg.rodR\n",
       "\tlocal stop = math.huge\n",
       "painted-letter: the writing's cover runs over the keycap",
       expect="over the keycap at", script=S)

mutate(F,
       "\tif self.pg then return self:PaintedList(shown, above) end\n",
       "",
       "painted-letter: the list laid on the letter's own sheet under a painting",
       expect="painted-letter: what it keeps still tells", script=S)

mutate(F,
       "\t\tif not self.pg then PlayAll(self.shakes) end\n",
       "\t\tPlayAll(self.shakes)\n",
       "painted-letter: a refusal shakes the letter's layers off the still painting",
       expect="a refusal shakes the letter's layers", script=S)

mutate(F,
       "\tself.pg = nil\n\tfor _, t in ipairs(self.coverArt or {}) do t:Hide() end\n\tfor _, t in ipairs(self.listArt or {}) do t:Hide() end\n\tself.keyText:SetParent(kit.textLayer)\nend\n",
       "\tself.pg = nil\n\tfor _, t in ipairs(self.coverArt or {}) do t:Hide() end\n\tfor _, t in ipairs(self.listArt or {}) do t:Hide() end\nend\n",
       "painted-letter: the key's letter left on the slips' frame for the next look",
       expect="key letter is left on its slips' frame", script=S)

mutate(F,
       "\tself.rim:SetSize(lip, lip)\n",
       "\tself.rim:SetSize(lip, lip)\n\tself.rim:Hide()\n",
       "painted-letter: the reason's wax gone from the painted seal",
       expect="the lip of the reason's wax round the icon is gone", script=S)
