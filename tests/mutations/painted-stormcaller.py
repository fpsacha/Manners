# Mutations for the Stormcaller's painted frame (Looks/Stormcaller.lua's
# paintedHides, PaintedPlace, PaintedStyled, its Dress's Tone line, the shades
# over the painted sigils that sleep): each undoes one thing the look does over
# its painting and is caught by the scenario in
# tests/scenarios/painted-stormcaller.lua that names it.

S = "runscenarios.py"
LUA = "Looks/Stormcaller.lua"

# --- worn ---

mutate(LUA,
       "\tpaintedHides = { \"shadow\", \"body\", \"totem\",",
       "\tpaintedHides = { \"shadow\", \"totem\",",
       "painted-stormcaller: the slab drawn under the painting",
       expect="its own frame is drawn under the painting", script=S)

mutate(LUA,
       "\"stele\", \"sigils\", \"shims\", \"feathers\", \"keyChip\" },",
       "\"stele\", \"sigils\", \"shims\", \"keyChip\" },",
       "painted-stormcaller: the feathers hung on a painting with no wings",
       expect="its own frame is drawn under the painting", script=S)

mutate(LUA,
       "\tlocal drawn = not ns.Looks.Painted.On(self)\n",
       "\tlocal drawn = true\n",
       "painted-stormcaller: the hidden feathers still stirring",
       expect="stirs under the painting", script=S)

# --- placed ---

mutate(LUA,
       "\tself.cx, self.cy, self.iconSize, self.totemSize, self.textX = cx, g.socketY, g.iconSize, size, g.textX\n",
       "\tself.cx, self.cy, self.iconSize, self.totemSize, self.textX = cx, g.socketY, g.iconSize, size, self.textX\n",
       "painted-stormcaller: the words left where the carved totem had them",
       expect="the name starts at", script=S)

mutate(LUA,
       "\tself.nameY, self.subY = self.nameY + dy, self.subY + dy\n",
       "",
       "painted-stormcaller: the lines not moved onto the well",
       expect="the lines are centred at", script=S)

mutate(LUA,
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX - g.keyW, -g.keyY)\n",
       "painted-stormcaller: the key's letter beside the keycap",
       expect="the key's letter is at", script=S)

mutate(LUA,
       "\tself.keyText:SetParent(self.chipFrame)\n",
       "",
       "painted-stormcaller: the key's letter dimmed with the words",
       expect="the key's letter is dimmed with the words", script=S)

mutate(LUA,
       "\t\tkeyUp = ns.Looks.Painted.On(self) or self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = false\n",
       "painted-stormcaller: no letter on the keycap",
       expect="the key's letter is not drawn", script=S)

mutate(LUA,
       "\tself.top, self.bottom, self.ph = g.y0, g.y1, g.y1 - g.y0\n",
       "",
       "painted-stormcaller: the list hung inside what the painting hangs below",
       expect="inside what hangs below", script=S)

mutate(LUA,
       "\tlocal x0, x1 = g.textX - 2, keyL - 2\n\tlocal ch = math.max(2, PAINT.channel * u)\n"
       "\tlocal y0, y1 = g.wellBottom - ch * 0.35, g.wellBottom + ch * 0.65\n",
       "\tlocal x0, x1 = g.textX - 2, keyL - 2\n\tlocal ch = math.max(2, PAINT.channel * u)\n"
       "\tlocal y0, y1 = g.top + u * 0.9, g.top + u * 0.9 + ch\n",
       "painted-stormcaller: the channel off the well's rim",
       expect="the channel is not on the well's lower rim", script=S)

mutate(LUA,
       "\tAt(self.eyes, art, cx, g.top + PAINT.eyesY * u, PAINT.eyesW * u, PAINT.eyesH * u)\n",
       "",
       "painted-stormcaller: the eyes left where the carved totem had them",
       expect="the eyes are", script=S)

# --- the sigils ---

mutate(LUA,
       "\t\tself.sleep[i]:SetAlpha(on and 0 or PAINT.sleep)\n",
       "\t\tself.sleep[i]:SetAlpha(0)\n",
       "painted-stormcaller: no sigil shaded asleep",
       expect="clear though asleep", script=S)

mutate(LUA,
       "\t\tself.sleep[i]:SetAlpha(on and 0 or PAINT.sleep)\n",
       "\t\tself.sleep[i]:SetAlpha(PAINT.sleep)\n",
       "painted-stormcaller: the awake sigil shaded too",
       expect="shaded though awake", script=S)

mutate(LUA,
       "\t\tself.sleep[i]:Show()\n",
       "",
       "painted-stormcaller: the shades never shown",
       expect="clear though asleep", script=S)

mutate(LUA,
       "\tEach(self.sleep, \"Hide\")\n",
       "",
       "painted-stormcaller: the shades drawn over the earlier art",
       expect="the painted sigil", script=S)

mutate(LUA,
       "\t\tlocal sx, sy = g.right - s[1] * u, g.top + s[2] * u\n",
       "\t\tlocal sx, sy = g.right + s[1] * u, g.top + s[2] * u\n",
       "painted-stormcaller: the shades off the sigil stone",
       expect="shade is off the stone", script=S)

# --- a fight ---

mutate(LUA,
       "\tns.Looks.Painted.Tone(self, pc[1] * k, pc[2] * k, pc[3] * k, fight)\n",
       "",
       "painted-stormcaller: a fight leaves the painting in colour",
       expect="in a fight the painting is not greyed", script=S)
