# Mutations for Arcane's painted frame (Looks/Arcane.lua's paintedHides,
# PaintedPlace, PaintedKey and its fight's Tone line): Arcane wearing its
# painting and none of its own glass, the words starting in the well, the
# reason's rim, the clock, the lines and the list laid on the painting, the
# keycap stepping aside for an outcome and a fight greying the painting.
# Each is caught by the scenario in tests/scenarios/painted-arcane.lua that
# names it.

S = "runscenarios.py"
A = "Looks/Arcane.lua"

mutate(A,
       "\tpaintedHides = { \"shadow\", \"glass\", \"smoke\", \"glint\", \"well\", \"keycap\" },\n",
       "\tpaintedHides = { \"shadow\", \"smoke\", \"glint\", \"well\", \"keycap\" },\n",
       "painted-arcane: Arcane's glass drawn under the painting",
       expect="painted-arcane: Arcane wears its painting and none of its own glass", script=S)

mutate(A,
       "\tself.cx, self.M, self.iconSize, self.textX = cx, M, iconSize, g.textX\n",
       "\tself.cx, self.M, self.iconSize = cx, M, iconSize\n",
       "painted-arcane: Arcane's words where its lens had them",
       expect="the name starts at", script=S)

mutate(A,
       "\tns.Looks.Painted.Tone(self, on and PAINT_COMBAT or 1, on and PAINT_COMBAT or 1, on and PAINT_COMBAT or 1, on)\n",
       "",
       "painted-arcane: a fight leaves Arcane's painting alone",
       expect="in a fight the painting is not greyed", script=S)

mutate(A,
       "\t\tSliceOn(s, art, W, H, rx0, ry0, rx1, ry1)\n",
       "",
       "painted-arcane: the reason's rim round the card, not the painted well",
       expect="the reason's rim starts at", script=S)

mutate(A,
       "\t\tt:SetPoint(\"LEFT\", art, \"TOPLEFT\", drainX, -drainY)\n",
       "\t\tt:SetPoint(\"LEFT\", art, \"BOTTOMLEFT\", drainX, 3.4)\n",
       "painted-arcane: the clock on the card's foot, under the painted well",
       expect="the clock runs", script=S)

mutate(A,
       "\tself.minRight = self.edge + 2\n",
       "",
       "painted-arcane: with no keycap the lines run past the well's rim",
       expect="with no keycap, the name may run to", script=S)

mutate(A,
       "\tself.trayL, self.trayR = math.floor(bx0 + 1), math.floor(W - bx1 + 1)\n",
       "",
       "painted-arcane: the list's sheet runs under the crystal",
       expect="the list's sheet runs to", script=S)

mutate(A,
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", kit.textLayer, \"RIGHT\", -8, 0)\n",
       "painted-arcane: the key's letter off the painted keycap",
       expect="the key's letter is at", script=S)

mutate(A,
       "\tself.outcomeOn = true\n\tself:PaintedKey()\n",
       "",
       "painted-arcane: the painted keycap over an outcome",
       expect="the painted keycap stayed up over an outcome", script=S)

mutate(A,
       "\tself.outcomeOn = nil\n\tself:PaintedKey()\n",
       "\tself.outcomeOn = nil\n",
       "painted-arcane: the painted keycap back only at the next repaint",
       expect="after the outcome the painted keycap is not back", script=S)

mutate(A,
       "\tlocal M = 2 * g.socketR\n",
       "\tlocal M = 3 * g.socketR\n",
       "painted-arcane: the runes over the socket's frame",
       expect="the runes are not in the socket round the icon", script=S)

mutate(A,
       "\tself.pg, self.edge, self.minRight, self.lineDY = nil, nil, nil, nil\n\tself.trayL, self.trayR, self.outcomeOn = nil, nil, nil\n\n",
       "\n",
       "painted-arcane: Earlier art keeps the painting's places",
       expect="with Earlier art on, the painting's places are kept", script=S)
