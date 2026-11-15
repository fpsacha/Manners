# Mutations for Ribbon's painted frame (Looks/Ribbon.lua: paintedHides,
# PaintedPlace, PaintedStyled, its Chip, Idle, PaintReason and Cloth under a
# painting). Each is caught by the scenario in tests/scenarios/painted-ribbon.lua
# that names it.

S = "runscenarios.py"
F = "Looks/Ribbon.lua"

mutate(F,
       '\tpaintedHides = { "drop", "shade", "cloth", "trim",',
       '\tpaintedHides = { "drop", "shade", "trim",',
       "painted-ribbon: the code-drawn cloth left under the painting",
       expect="painted-ribbon: Ribbon wears its painting", script=S)

mutate(F,
       "\tif ns.Looks.Painted.On(self) then\n\t\tself.flow:StopAll()\n\telse",
       "\tif false then\n\t\tself.flow:StopAll()\n\telse",
       "painted-ribbon: the old fork's flutter running over the painted fork",
       expect="painted-ribbon: Ribbon wears its painting", script=S)

mutate(F,
       "\tself.textX = g.textX\n\tlocal dy = H / 2 - g.textY\n",
       "\tlocal dy = H / 2 - g.textY\n",
       "painted-ribbon: the words starting where the old ribbon had them, not in the well",
       expect="painted-ribbon: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\tDisc(self.enamel, art, cx, cy, enamel)\n",
       "",
       "painted-ribbon: the enamel left where the old medallion was",
       expect="painted-ribbon: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\t\t\tlocal x = boxW > g.keyW and math.min(g.keyX, self.W - boxW / 2) or g.keyX\n",
       "\t\t\tlocal x = g.keyX - g.keyW\n",
       "painted-ribbon: the key's letter off the painted keycap",
       expect="painted-ribbon: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\tif painted then\n\t\tself.keyText:SetShown(self.keyUp)\n",
       "\tif painted then\n\t\tself.keyText:SetShown(false)\n",
       "painted-ribbon: no letter on the painted keycap",
       expect="painted-ribbon: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\tlocal c = Lum(ink[1], ink[2], ink[3]) > 0.4 and GOLD_INK or ink\n\tself.paintedKeyInk = c\n",
       "\tlocal c = TAG_INK\n",
       "painted-ribbon: the old tag's dark letter on the dark keycap",
       expect="painted-ribbon: the icon sits in the socket, the words start in the well", script=S)

mutate(F,
       "\tif clothOn and ns.Looks.Painted.On(self) then ringOn = true end\n",
       "",
       "painted-ribbon: the stripe's reason shown nowhere on the painting",
       expect="painted-ribbon: what stays live still tells something", script=S)

mutate(F,
       "\tself.listTop, self.listBottom = coreTop - 2, coreBottom + 2\n",
       "\tself.listTop, self.listBottom = coreTop + 4, coreBottom - 4\n",
       "painted-ribbon: the list's ribbons over the painted cord",
       expect="painted-ribbon: what stays live still tells something", script=S)

mutate(F,
       "\tself.rim = { cx = cx, cy = cy, R = R }\n",
       "",
       "painted-ribbon: the count's badge on the old medallion's rim",
       expect="painted-ribbon: what stays live still tells something", script=S)

mutate(F,
       "\t\tns.Looks.Painted.Tone(self, PAINT_COMBAT[1], PAINT_COMBAT[2], PAINT_COMBAT[3], false)\n",
       "\t\tns.Looks.Painted.Tone(self, 1, 1, 1, false)\n",
       "painted-ribbon: a fight leaving the painting at its full light",
       expect="painted-ribbon: a fight dims the painting", script=S)
