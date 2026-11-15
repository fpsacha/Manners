# Mutations for Druid's painted frame (Looks/Wild.lua's paintedHides,
# PaintedPlace, PaintedStyled and the Tone line in its Dress): the painting
# worn and none of the bough, Earlier art giving it back, the icon in the
# socket, the words in the well, the key's tag on the keycap, the water, the
# count's tag and the list still telling, a fight greying the painting.
# Each is caught by the scenario in tests/scenarios/painted-wild.lua it names.

S = "runscenarios.py"

mutate("Looks/Wild.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"disc\",",
       "\tpaintedHides = { \"shadow\", \"disc\",",
       "painted-wild: the bough drawn under the painting",
       expect="Druid's own frame is drawn under the painting", script=S)

mutate("Looks/Wild.lua",
       "\"antlers\", \"moon\", \"sprigs\" },\n",
       "\"antlers\", \"sprigs\" },\n",
       "painted-wild: the moon drawn over the painted gem",
       expect="painted-wild: Druid wears its painting and none of its own frame", script=S)

mutate("Looks/Wild.lua",
       "\tfor i in ipairs(self.sprigs) do self.sprigOn[i] = false end\n\tself:PlaceMotion(showIcon, above)\n",
       "\tself:PlaceMotion(showIcon, above)\n",
       "painted-wild: the sprigs said to stand on the painting",
       expect="is said to stand on the painting", script=S)

mutate("Looks/Wild.lua",
       "\tself.textX = g.textX\n\tself:PlaceWreath(showIcon)\n",
       "\tself:PlaceWreath(showIcon)\n",
       "painted-wild: the words start where the bough's did",
       expect="Druid's well's text at", script=S)

mutate("Looks/Wild.lua",
       "\tlocal dy = self.H / 2 - g.textY\n",
       "\tlocal dy = 0\n",
       "painted-wild: the lines not centred on the well",
       expect="down, Druid's well at", script=S)

mutate("Looks/Wild.lua",
       "\tself.circle = g.iconSize * CIRCLE_SCALE / ICON_FRAME\n",
       "\tself.circle = g.socketR * 2 * CIRCLE_SCALE / ICON_FRAME\n",
       "painted-wild: the water past the socket",
       expect="past the socket's", script=S)

mutate("Looks/Wild.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX - 6, -g.keyY)\n",
       "painted-wild: the key's tag off the keycap",
       expect="the key's tag is at", script=S)

mutate("Looks/Wild.lua",
       "\tlocal most = math.max(6, math.floor(g.keyH * 0.62))\n",
       "\tlocal most = 99\n",
       "painted-wild: the key's letter larger than the keycap",
       expect="on Druid's keycap", script=S)

mutate("Looks/Wild.lua",
       "\t\tkeyUp = ns.Looks.Painted.On(self) or self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = self:NameFits(self.keyRoom) and not ns.Looks.Painted.On(self)\n",
       "painted-wild: no key's tag on the painted keycap",
       expect="the key's tag or its letter is not drawn", script=S)

mutate("Looks/Wild.lua",
       "\tself.listGap = math.max(0, g.unit * 0.08)\n",
       "\tself.listGap = 0\n",
       "painted-wild: the list's rows on the bar's bark",
       expect="on Druid's bark", script=S)

mutate("Looks/Wild.lua",
       "\t\t\ty = H + 3 + gap + (i - 1) * pitch + pitch / 2\n",
       "\t\t\ty = H + 3 + (i - 1) * pitch + pitch / 2\n",
       "painted-wild: the list's gap not given its rows",
       expect="on Druid's bark", script=S)

mutate("Looks/Wild.lua",
       "\tself.listGap = nil\n\tself.keyText:SetParent(kit.textLayer)\n",
       "\tself.keyText:SetParent(kit.textLayer)\n",
       "painted-wild: Earlier art keeps the painting's list gap",
       expect="the list keeps the painting's gap", script=S)

mutate("Looks/Wild.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * fr, pc[2] * fg, pc[3] * fb, fight or sere)\n",
       "",
       "painted-wild: a fight does not grey the painting",
       expect="in a fight Druid's painting is not greyed", script=S)

mutate("Looks/Wild.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * fr, pc[2] * fg, pc[3] * fb, fight or sere)\n",
       "\tns.Looks.Painted.Tone(self, pc[1] * fr, pc[2] * fg, pc[3] * fb, fight)\n",
       "painted-wild: a refusal does not wither the painting",
       expect="a refusal does not wither the painted bough", script=S)

mutate("Looks/Wild.lua",
       "\t\tlocal limitV = math.min(cy, H - cy) - kit.EDGE_MARGIN\n",
       "\t\tlocal limitV = H / 2 - kit.EDGE_MARGIN\n",
       "painted-wild: the rings fitted to a socket in the middle",
       expect="hunt37-effects: the rings, the echo and the halo stay in their room", script=S)
