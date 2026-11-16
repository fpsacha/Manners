# Mutations for Gearworks' painted frame (Looks/Gearworks.lua's paintedHides,
# PaintedPlace, PaintedStyled and its dressing's Tone line, over
# Looks/Painted.lua). Each is caught by the scenario in
# tests/scenarios/painted-gearworks.lua that names it.

S = "runscenarios.py"

mutate("Looks/Gearworks.lua",
       "\tpaintedHides = { \"shadow\", \"shade\", \"body\", \"bezel\",",
       "\tpaintedHides = { \"shadow\", \"shade\", \"bezel\",",
       "painted-gearworks: the old housing drawn under the painting",
       expect="Gearworks' own frame is drawn under the painting", script=S)

mutate("Looks/Gearworks.lua",
       "\t\t\"gearbox\", \"cogs\", \"cogLights\", \"keyChip\" },\n",
       "\t\t\"gearbox\", \"cogLights\", \"keyChip\" },\n",
       "painted-gearworks: the old cogs over the painted gearbox",
       expect="Gearworks' own frame is drawn under the painting", script=S)

mutate("Looks/Gearworks.lua",
       "\t\t\"gearbox\", \"cogs\", \"cogLights\", \"keyChip\" },\n",
       "\t\t\"gearbox\", \"cogs\", \"cogLights\" },\n",
       "painted-gearworks: the old key tag over the painted keycap",
       expect="own key tag", script=S)

mutate("Looks/Gearworks.lua",
       "\tself.cx, self.gz, self.iconSize, self.textX = cx, gz, iconSize, g.textX\n",
       "\tself.cx, self.gz, self.iconSize = cx, gz, iconSize\n",
       "painted-gearworks: the words where the old frame had them",
       expect="the well's text at", script=S)

mutate("Looks/Gearworks.lua",
       "\tfor _, t in ipairs({ self.dial, self.dialWarm, self.dialHot, self.needle }) do At(t, art, cx, cy, gz) end\n\tlocal brass",
       "\tlocal brass",
       "painted-gearworks: the dial and needle left where the old gauge was",
       expect="painted-gearworks: the icon sits in the socket", script=S)

mutate("Looks/Gearworks.lua",
       "\tpaintedIconFill = 0.68,\n",
       "",
       "painted-gearworks: the icon fills the glass, no band for the dial",
       expect="leaving no band for the dial", script=S)

mutate("Looks/Gearworks.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -self.chipInset, 0)\n",
       "painted-gearworks: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Gearworks.lua",
       "\tself.chipInset = math.ceil(self.W - keyL) + 3\n",
       "",
       "painted-gearworks: the words run over the keycap",
       expect="past the keycap", script=S)

mutate("Looks/Gearworks.lua",
       "\tif mode == \"stripe\" and ns.Looks.Painted.On(self) then ring = true end\n",
       "",
       "painted-gearworks: the stripe's colour on a tube that is not drawn",
       expect="with the marker on the stripe", script=S)

mutate("Looks/Gearworks.lua",
       "\tself.listGap = math.max(0, (above and -g.y0 or (g.y1 - H)) * 0.85)\n",
       "\tself.listGap = 0\n",
       "painted-gearworks: the list's rows under what the painting hangs",
       expect="inside what the painting hangs", script=S)

mutate("Looks/Gearworks.lua",
       "\tlocal sx, mouth = g.right - PAINT.valveX * u, g.top + PAINT.valveY * u\n",
       "\tlocal sx, mouth = g.right - 0.1 * u, g.top + PAINT.valveY * u\n",
       "painted-gearworks: the steam off the painted valve",
       expect="the steam rises at", script=S)

mutate("Looks/Gearworks.lua",
       "\tself.boxed, self.tubeOK = false, false\n",
       "\tself.tubeOK = false\n",
       "painted-gearworks: the old cogs turn under the painted gearbox",
       expect="turns under the painted gearbox", script=S)

mutate("Looks/Gearworks.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * pf, pc[2] * pf, pc[3] * pf, on)\n",
       "",
       "painted-gearworks: a fight leaves the painting alone",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Gearworks.lua",
       "\t\tself.fx:Fit(limitH, math.min(cy, H - cy) - kit.EDGE_MARGIN, kit.SHAKE_LEFT)\n",
       "\t\tself.fx:Fit(limitH, H / 2 - kit.EDGE_MARGIN, kit.SHAKE_LEFT)\n",
       "painted-gearworks: the rings held to the button's middle, not the socket's",
       expect="the rings, the echo and the halo stay in their room", script=S)

# The whistle's sheet ending with its light is look-gearworks.py's now
# ("look-gearworks: the whistle's sheet runs on after its light").
