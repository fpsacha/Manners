# Mutations for Death Knight's painted frame (Looks/Ebon.lua's paintedHides,
# PaintedPlace, PaintedSocket, PaintedStyled, the key's room in its Chip and the
# Tone line in its Dress): the look wearing its painting and none of its own
# frame, Earlier art giving every part back, the icon in the socket, the words
# in the well and the key on the keycap, what it keeps telling the reason, the
# count and the list, a fight greying the painting.
# Each is caught by the scenario in tests/scenarios/painted-ebon.lua that names it.

S = "runscenarios.py"

mutate("Looks/Ebon.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"guard\", \"runes\", \"runeLit\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"guard\", \"runes\", \"runeLit\", \"keyChip\" },\n",
       "painted-ebon: the blade's steel drawn under the painting",
       expect="Death Knight's own frame is drawn under the painting", script=S)

mutate("Looks/Ebon.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"guard\", \"runes\", \"runeLit\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"body\", \"runes\", \"runeLit\", \"keyChip\" },\n",
       "painted-ebon: the guard drawn over the painted socket",
       expect="Death Knight's own frame is drawn under the painting", script=S)

mutate("Looks/Ebon.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"guard\", \"runes\", \"runeLit\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"body\", \"guard\", \"runes\", \"runeLit\" },\n",
       "painted-ebon: the look's key tag over the painted keycap",
       expect="the look's own key tag", script=S)

mutate("Looks/Ebon.lua",
       "\tself.textX = g.textX\n\tself:PlaceGuard(showIcon)\n",
       "\tself:PlaceGuard(showIcon)\n",
       "painted-ebon: the words where the guard had them",
       expect="the well's text at", script=S)

mutate("Looks/Ebon.lua",
       "\t\tself.vapourScroll[i]:Window((vx1 - vx0) / (VAPOUR.tile * VAPOUR.long), vh / VAPOUR.tile)\n\tend\n\tBox(self.vapourMask[1], art, vx0, yb - vh * 0.4, vx1, yb + vh * 0.6)\n",
       "\t\tself.vapourScroll[i]:Window((vx1 - vx0) / (VAPOUR.tile * VAPOUR.long), vh / VAPOUR.tile)\n\t\tdo break end\n\tend\n\tBox(self.vapourMask[1], art, vx0, yb - vh * 0.4, vx1, yb + vh * 0.6)\n",
       "painted-ebon: the vapour floats off the painted frame's edge",
       expect="the vapour floats off", script=S)

mutate("Looks/Ebon.lua",
       "\tself.chipInset = math.ceil(self.W - keyL) + 3\n",
       "",
       "painted-ebon: the words run over the keycap",
       expect="painted-ebon: the icon sits in the socket", script=S)

mutate("Looks/Ebon.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -self.chipInset, 0)\n",
       "painted-ebon: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Ebon.lua",
       "\tself.socket:SetTexture(ROUND_RING)\n",
       "",
       "painted-ebon: the socket's light keeps eight sides in the round socket",
       expect="keeps the guard's eight sides", script=S)

mutate("Looks/Ebon.lua",
       "\tself.mask:SetTexture(ROUND_MASK, \"CLAMPTOBLACKADDITIVE\", \"CLAMPTOBLACKADDITIVE\")\n",
       "",
       "painted-ebon: the icon cut to eight sides in the round socket",
       expect="the icon is cut to eight sides", script=S)

mutate("Looks/Ebon.lua",
       "\tself.socket:SetTexture(ART .. \"Socket\")\n",
       "",
       "painted-ebon: Earlier art keeps the painting's round ring",
       expect="keeps the painting's round ring", script=S)

mutate("Looks/Ebon.lua",
       "\tself.halo:SetTexture(ART .. \"Halo\")\n\tself.mask:SetTexture(ART .. \"Mask\", \"CLAMPTOBLACKADDITIVE\", \"CLAMPTOBLACKADDITIVE\")\n",
       "\tself.halo:SetTexture(ART .. \"Halo\")\n",
       "painted-ebon: Earlier art keeps the round mask",
       expect="keeps the painting's round mask", script=S)

mutate("Looks/Ebon.lua",
       "\tself.keyText:SetParent(kit.textLayer)\n",
       "",
       "painted-ebon: Earlier art leaves the letter off the words",
       expect="the key's letter is not with the words", script=S)

mutate("Looks/Ebon.lua",
       "\tself.flameFoot = cy - PAINT.crown * u\n",
       "",
       "painted-ebon: the soulfire over the skull's face",
       expect="the soulfire does not stand on the skull's crown", script=S)

mutate("Looks/Ebon.lua",
       "\t\tlocal x, size = g.keyX + PAINT.runes[i] * u, math.max(5, PAINT.rune * u)\n",
       "\t\tlocal x, size = self.runeX[i], math.max(5, PAINT.rune * u)\n",
       "painted-ebon: the runes' lights where the blade's runes were",
       expect="light is not past the keycap", script=S)

mutate("Looks/Ebon.lua",
       "\tself.listX0 = showIcon and (self.discRight - 1) or 2\n",
       "\tself.listX0 = 2\n",
       "painted-ebon: the list's marks on the socket's ring",
       expect="sits on the socket's ring", script=S)

mutate("Looks/Ebon.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * fr, pc[2] * fg, pc[3] * fb, fight or dead)\n",
       "",
       "painted-ebon: Death Knight's dressing leaves the painting alone",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Ebon.lua",
       "\tif fight then fr, fg, fb = PAINT_COMBAT, PAINT_COMBAT, PAINT_COMBAT end\n",
       "",
       "painted-ebon: a fight dims the painting as far as the blade",
       expect="in a fight the painting is not dimmed a little", script=S)
