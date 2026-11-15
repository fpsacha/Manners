# Mutations for Warchief's painted frame (Looks/Warchief.lua's paintedHides,
# PaintedPlace and the Tone line in Dull): it wears its painting and none of
# the frame the painting replaces, the banner's film stilled under the
# painted banner, the words start in the well, the brand round the icon in
# the socket, the key's letter on the keycap, the list from the socket to the
# keycap, a fight greying the painting. Each is caught by the scenario in
# tests/scenarios/painted-warchief.lua that names it.

S = "runscenarios.py"

mutate("Looks/Warchief.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"frame\",",
       "\tpaintedHides = { \"shadow\", \"frame\",",
       "painted-warchief: the iron drawn under the painting",
       expect="Warchief's own frame is drawn under the painting", script=S)

mutate("Looks/Warchief.lua",
       "\"frame\", \"tusks\", \"spikes\",",
       "\"frame\", \"spikes\",",
       "painted-warchief: the code-drawn tusks over the painted one",
       expect="Warchief's own frame is drawn under the painting", script=S)

mutate("Looks/Warchief.lua",
       "\tself.bannerOK = W - textX >= bannerW + 40 and not ns.Looks.Painted.On(self)\n",
       "\tself.bannerOK = W - textX >= bannerW + 40\n",
       "painted-warchief: the hidden banner's film left running",
       expect="the hidden banner's film still runs over the painting", script=S)

mutate("Looks/Warchief.lua",
       "\tself.iconSize, self.cx, self.bz, self.frameRight, self.textX = iconSize, cx, bz, frameRight, g.textX\n",
       "\tself.iconSize, self.cx, self.bz, self.frameRight, self.textX = iconSize, cx, bz, frameRight, g.textX + 6\n",
       "painted-warchief: the words start past the well's start",
       expect="painted-warchief: the icon sits in the socket, the words start in the well", script=S)

mutate("Looks/Warchief.lua",
       "\tAt(self.brand, art, cx, g.socketY, bz)\n",
       "\tAt(self.brand, art, cx + 6, g.socketY, bz)\n",
       "painted-warchief: the brand off the socket",
       expect="the brand is not round the icon in the socket", script=S)

mutate("Looks/Warchief.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX - 8, -g.keyY)\n",
       "painted-warchief: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Warchief.lua",
       "\tif self.listX0 then x0, x1 = self.listX0, self.listX1 end\n",
       "",
       "painted-warchief: the list runs under the painted banner",
       expect="the list runs past the keycap, under the banner", script=S)

mutate("Looks/Warchief.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * f, pc[2] * f, pc[3] * f, on)\n",
       "",
       "painted-warchief: a fight leaves the painting as it is",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Warchief.lua",
       "\tlocal dy = self.H / 2 - cy\n",
       "\tlocal dy = self.H / 2 - cy - 0.2 * unit\n",
       "painted-warchief: the lines off the well",
       expect="the lines run from", script=S)
