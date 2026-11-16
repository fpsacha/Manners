# Mutations for Hunter's painted frame (Looks/Leather.lua: paintedHides,
# PaintedPlace, PaintedBrand, Unpaint, the Tone line and what the painted
# frame changes in Chip, Accent, Idle and the swing): it wears its painting and
# none of its own frame, Earlier art gives every piece back, the icon in the
# porthole and the words in the well, what it keeps still telling, a fight
# greying the painting. Each is caught by the scenario in
# tests/scenarios/painted-leather.lua that names it.

S = "runscenarios.py"
LEATHER = "Looks/Leather.lua"

mutate(LEATHER,
       "\tpaintedHides = { \"shadow\", \"body\", \"sheen\",",
       "\tpaintedHides = { \"shadow\", \"sheen\",",
       "painted-leather: the leather drawn under the painting",
       expect="painted-leather: Hunter wears its painting and none of its own frame", script=S)

mutate(LEATHER,
       "\t\t\"studs\", \"buckle\", \"feathers\", \"brand\", \"keyChip\" },\n",
       "\t\t\"studs\", \"buckle\", \"brand\", \"keyChip\" },\n",
       "painted-leather: the code's feathers hung over the painted ones",
       expect="painted-leather: Hunter wears its painting and none of its own frame", script=S)

mutate(LEATHER,
       "\tif ns.Looks.Painted.On(self) then sway = false end\n",
       "",
       "painted-leather: hidden feathers left stirring",
       expect="painted-leather: Hunter wears its painting and none of its own frame", script=S)

mutate(LEATHER,
       "\tself.textX = g.textX\n\t-- They end where the well does",
       "\t-- They end where the well does",
       "painted-leather: the words start where the leather's did, not in the well",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tlocal wellRight = math.max(g.x2, g.right - PAINT.wellEnd * u)\n",
       "\tlocal wellRight = g.keyX - g.keyW / 2\n",
       "painted-leather: the words run over the paw print to the keycap",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tlocal nameC, subC = m + nameSize / 2, m + nameSize + gap + sub / 2\n",
       "\tlocal nameC, subC = m + nameSize / 2, m + nameSize / 2\n",
       "painted-leather: the reason written over the name in the well",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tself.iconFrame:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.socketX, -g.socketY)\n",
       "\tself.iconFrame:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.socketX + 6, -g.socketY)\n",
       "painted-leather: the thread round the icon off the porthole",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "",
       "painted-leather: the key's letter left off the keycap",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tself.keyText:SetShown(lane ~= nil or (capped and key ~= nil))\n",
       "\tself.keyText:SetShown(lane ~= nil)\n",
       "painted-leather: no letter on the keycap",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\t\tself.keyText:SetText(text)\n\tend\nend\n",
       "\tend\nend\n",
       "painted-leather: a controller's buttons drawn wider than the keycap",
       expect="painted-leather: the icon sits in the porthole, the words stay in the well", script=S)

mutate(LEATHER,
       "\tif ns.Looks.Painted.On(self) then rim = out or mode ~= \"off\" end\n",
       "",
       "painted-leather: on stripe the reason goes nowhere",
       expect="painted-leather: what it keeps still tells", script=S)

mutate(LEATHER,
       "\tif ns.Looks.Painted.On(self) then return self:PaintedBrand() end\n",
       "",
       "painted-leather: the embers on the old brand's place, not the paw print",
       expect="painted-leather: what it keeps still tells", script=S)

mutate(LEATHER,
       "\tself.listGap = above and math.max(0, -g.y0) or math.max(0, g.y1 - H)\n",
       "",
       "painted-leather: the list hung into the feathers",
       expect="painted-leather: what it keeps still tells", script=S)

mutate(LEATHER,
       "\tlocal inset = math.ceil(W - wellRight + 0.12 * u)\n",
       "\tlocal inset = math.ceil(W - g.keyX + 0.12 * u)\n",
       "painted-leather: the count's patch on the paw print",
       expect="painted-leather: what it keeps still tells", script=S)

mutate(LEATHER,
       "\tns.Looks.Painted.Tone(self, dye[1] * pk, dye[2] * pk, dye[3] * pk, on)\n",
       "",
       "painted-leather: a fight leaves the painting in colour",
       expect="painted-leather: a fight greys the painting", script=S)

mutate(LEATHER,
       "\t\tif not (skip and skip[g]) then g:Play() end\n",
       "\t\tg:Play()\n",
       "painted-leather: lights held still while the painted tag jerks",
       expect="painted-leather: a fight greys the painting", script=S)

mutate(LEATHER,
       "\tself.ember:SetTexture(ART .. \"Ember\")\n\tself.brandFlash:SetTexture(ART .. \"Ember\")\n",
       "",
       "painted-leather: Earlier art keeps the painted embers",
       expect="painted-leather: Earlier art brings its own frame back", script=S)

mutate(LEATHER,
       "\tself.keyText:SetParent(self.kit.textLayer)\n",
       "",
       "painted-leather: Earlier art leaves the key's letter on the keycap's frame",
       expect="painted-leather: Earlier art brings its own frame back", script=S)

mutate(LEATHER,
       "\t\t\tpiece.tex:SetTexture(ART .. \"StitchM\", \"REPEAT\", \"REPEAT\")\n",
       "",
       "painted-leather: Earlier art keeps the thread's light soft",
       expect="painted-leather: Earlier art brings its own frame back", script=S)
