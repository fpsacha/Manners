# Mutations for the glass in its painting (Looks/Glass.lua's paintedHides,
# PaintedPlace, PaintedStyled, Chip and Gilt; Prompt/Panel.lua's wrap of the
# dressing and DressPainted; Prompt/Text.lua's edge room and line insets; the
# list's gap in Prompt/List.lua). Each is caught by the scenario in
# tests/scenarios/painted-glass.lua that names it.

S = "runscenarios.py"
GLASS = "Looks/Glass.lua"
PANEL = "Prompt/Panel.lua"

# --- worn, and Earlier art ---

mutate(PANEL,
       "\tif data and dress and ns.Looks.Painted and ns.Looks.Painted.Wrap then ns.Looks.Painted.Wrap(dress, data) end\n",
       "",
       "painted-glass: the glass's dressing never wrapped",
       expect="painted-glass: the glass wears its painting and none of what it replaces", script=S)

mutate(GLASS,
       "Glass.paintedHides = { \"pane\", ",
       "Glass.paintedHides = { ",
       "painted-glass: the pane drawn under the painting",
       expect="drawn under the painting: pane", script=S)

mutate(GLASS,
       "\"railTop\", \"railBottom\", \"gryphon\", \"lit\", \"eye\" }",
       "\"railTop\", \"railBottom\", \"lit\", \"eye\" }",
       "painted-glass: the code's gryphons stand over the painted heads",
       expect="drawn under the painting: gryphon", script=S)

mutate(GLASS,
       "\t\tself.pane, self.glassLight, self.shadows = regions.pane, regions.glassLight, regions.shadows\n",
       "",
       "painted-glass: the panel's pane, light and shadow never handed to the painting",
       expect="drawn under the painting", script=S)

mutate(PANEL,
       "\tif dress and p.classicArt and ns.Looks.Painted.On(dress) then dress:Hide() end\n",
       "",
       "painted-glass: Earlier art leaves the pane hidden for a restyle",
       expect="with Earlier art on, not drawn", script=S)

mutate(PANEL,
       "\tR.resultFill:ClearAllPoints()\n\tR.resultFill:SetAllPoints(R.art)\n",
       "",
       "painted-glass: Earlier art keeps the wash on the painted well",
       expect="Earlier art: the outcome's wash is not over the whole panel", script=S)

# --- where things go ---

mutate(GLASS,
       "\treturn g.textX\nend\n",
       "\treturn g.socketX\nend\n",
       "painted-glass: the words start over the socket",
       expect="the name starts at", script=S)

mutate("Looks/Painted.lua",
       "\tBox(s[2], rel, g.x1 - SEAM, g.y0, g.x2 + SEAM, g.y1)\n",
       "\tBox(s[2], rel, g.x1 + SEAM, g.y0, g.x2 + SEAM, g.y1)\n",
       "painted-glass: a gap between the left end and the middle",
       expect="the middle meets the ends at", script=S)

mutate(PANEL,
       "\t\tR.bezel:SetSize(socket, socket)\n",
       "",
       "painted-glass: the bezel left at the earlier art's size",
       expect="the bezel is not the socket's size round the icon", script=S)

mutate(PANEL,
       "\tlocal chipRight = keyUp and (keyL - 3) or keyR\n",
       "\tlocal chipRight = keyR\n",
       "painted-glass: the count chip over the keycap",
       expect="the count chip stands over the keycap", script=S)

mutate(PANEL,
       "\tlocal edge = math.max(EDGE_ROOM, math.ceil(W - (keyUp and keyL or wellEnd)) + 4)\n",
       "\tlocal edge = EDGE_ROOM\n",
       "painted-glass: the lines run onto the right end",
       expect="past the well's end", script=S)

mutate(PANEL,
       "\tlocal gap = S.queueAbove and S.queueGap or math.ceil(below)\n",
       "\tlocal gap = 0\n",
       "painted-glass: the list in the bar's lower rim",
       expect="in the bar's lower rim", script=S)

mutate(PANEL,
       "\tR.resultFill:SetPoint(\"TOPLEFT\", R.art, \"TOPLEFT\", g.left + (dress.PAINT_WELL_IN or 0) * u, -g.wellTop)\n",
       "\tR.resultFill:SetPoint(\"TOPLEFT\", R.art, \"TOPLEFT\", g.left, -g.wellTop)\n",
       "painted-glass: the outcome's wash over the socket",
       expect="the outcome's wash runs over the socket", script=S)

mutate("Prompt/Text.lua",
       "\t\tR.nameText:SetPoint(\"TOPLEFT\", left, -8 - (fit.lineTop or 0))\n",
       "\t\tR.nameText:SetPoint(\"TOPLEFT\", left, -8)\n",
       "painted-glass: the name off a bar drawn smaller than the prompt",
       expect="the name line", script=S)

# --- what stays live ---

mutate(GLASS,
       "\tlocal key = Looks.Painted.KeyShown(self) and Looks.BoundKey()\n",
       "\tlocal key = Looks.BoundKey()\n",
       "painted-glass: the key's letter drawn with the keycap hidden",
       expect="as the look has it, the glass shows its key", script=S)

mutate(GLASS,
       "\tself.keyText:SetTextColor(ink[1], ink[2], ink[3], 1)\n",
       "",
       "painted-glass: the key's letter not in the keycap's ink",
       expect="the key's letter is not in the keycap's ink", script=S)

mutate(GLASS,
       "\tlocal eyes = not Looks.Painted.On(self)\n",
       "\tlocal eyes = true\n",
       "painted-glass: the hidden eyes glint under the painting",
       expect="at rest", script=S)

# --- a fight ---

mutate(GLASS,
       "\tLooks.Painted.Tone(self, t, t, t, self.combat)\n",
       "",
       "painted-glass: a fight leaves the painting as it was",
       expect="in a fight the painting is not greyed", script=S)
