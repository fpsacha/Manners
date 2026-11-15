# Mutations for Luxe's painted frame (Looks/Luxe.lua: paintedHides,
# PaintedPlace, PaintedInsets, KeyLabel and the Tone line in SetInk). Each is
# caught by the scenario in tests/scenarios/painted-luxe.lua that names it.

S = "runscenarios.py"

mutate("Looks/Luxe.lua",
       "\tpaintedHides = { \"shadow\", \"card\", \"bevel\", \"rim\" },\n",
       "\tpaintedHides = { \"shadow\", \"bevel\", \"rim\" },\n",
       "painted-luxe: the card drawn under the painting",
       expect="painted-luxe: Luxe wears its painting and none of its own card", script=S)

mutate("Looks/Luxe.lua",
       "\tpaintedIconFill = 0.80,\n",
       "\tpaintedIconFill = 0.98,\n",
       "painted-luxe: the icon over the socket's gold frame",
       expect="not inside its gold frame", script=S)

mutate("Looks/Luxe.lua",
       "\tself.textX = g.textX\n\tself.nameY, self.pillTop",
       "\tself.textX = self.textX\n\tself.nameY, self.pillTop",
       "painted-luxe: the words start where the card had them",
       expect="painted-luxe: the icon sits in the socket, the words start in the well", script=S)

mutate("Looks/Luxe.lua",
       "\tself.pillFrame:SetPoint(\"TOPLEFT\", kit.textLayer, \"TOPLEFT\", g.textX, -self.pillTop)\n",
       "",
       "painted-luxe: the tag left where the card had it",
       expect="the tag", script=S)

mutate("Looks/Luxe.lua",
       "\tself.spine:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", sx0, -sy0)\n",
       "\tself.spine:SetPoint(\"LEFT\", SPINE_X, 0)\n",
       "painted-luxe: the spine off the painted one",
       expect="off the painted one", script=S)

mutate("Looks/Luxe.lua",
       "\tif ns.Looks.Painted then ns.Looks.Painted.Tone(self, tone, tone, tone, ground < 1) end\n",
       "",
       "painted-luxe: a fight does not grey the painting",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Luxe.lua",
       "\tif not (Painted and Painted.KeyShown(self)) then return nil end\n",
       "\tif not Painted then return nil end\n",
       "painted-luxe: the key's letter under the earlier art",
       expect="Luxe draws a key it never had", script=S)

mutate("Looks/Luxe.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.textX, -g.keyY)\n",
       "painted-luxe: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Luxe.lua",
       "\t\tlineRight = g.keyX - g.keyW / 2 - 4\n",
       "\t\tlineRight = g.right - (PAINT_CARD[3] + 0.10) * g.unit - 4\n",
       "painted-luxe: the chip runs onto the keycap",
       expect="onto the keycap", script=S)

mutate("Looks/Luxe.lua",
       "\tself.trayGap = 3 + math.max(0, above and -g.y0 or (g.y1 - H))\n",
       "\tself.trayGap = -6\n",
       "painted-luxe: the list under the bar's edge",
       expect="inside the bar that ends", script=S)

mutate("Looks/Luxe.lua",
       "\tself.dotX = (sx0 + sx1) / 2\n",
       "",
       "painted-luxe: the list's marks not under the spine",
       expect="the list's mark is not under the spine", script=S)
