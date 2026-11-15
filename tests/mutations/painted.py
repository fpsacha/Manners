# Mutations for the painted looks (Looks/Painted.lua, Looks/Frost.lua's
# PaintedPlace, Core.lua's default, the Look page's switch): Frost wearing its
# painting and none of its own frame, Earlier art giving its own frame back,
# the pieces meeting and following the prompt's size with only the middle
# stretched, the icon in the socket, the words in the well and the key on the
# keycap, a fight greying the painting, another look leaving nothing of it.
# Each is caught by the scenario in tests/scenarios/painted.lua that names it.

S = "runscenarios.py"

# --- worn, and the switch ---

mutate("Looks/Painted.lua",
       "\tif look and not look.native and not look.fallback and type(look.Apply) == \"function\" then\n",
       "\tif false and look and not look.native and not look.fallback and type(look.Apply) == \"function\" then\n",
       "painted: no look is wrapped",
       expect="painted: Frost wears its painting and none of its own frame", script=S)

mutate("Looks/Painted.lua",
       "\tt:Hide()\n\tt.Show = Noop\n",
       "\tt:Hide()\n",
       "painted: Frost's own frame shown under the painting",
       expect="Frost's own frame is drawn under the painting", script=S)

mutate("Core.lua",
       "\t\t\tclassicArt = false,\n",
       "\t\t\tclassicArt = true,\n",
       "painted: Earlier art on by default",
       expect="painted: Frost wears its painting", script=S)

mutate("Looks/Painted.lua",
       "\treturn not (p and p.classicArt)\n",
       "\treturn true\n",
       "painted: Earlier art reads nothing",
       expect="with Earlier art on, piece", script=S)

mutate("Looks/Painted.lua",
       "\tt.Show = saved[1] or nil\n",
       "",
       "painted: the frame's own Show not given back",
       expect="Frost's own frame is not drawn", script=S)

mutate("Options/Look.lua",
       "\t\t\tclassicArt = {\n\t\t\t\ttype = \"toggle\",\n",
       "\t\t\tclassicArtGone = {\n\t\t\t\ttype = \"toggle\",\n",
       "painted: no switch for Earlier art",
       expect="no switch on the Look page sets prompt.classicArt", script=S)

# --- the pieces ---

mutate("Looks/Painted.lua",
       "\tBox(s[3], rel, g.x2, g.y0, g.right, g.y1)\n",
       "\tBox(s[3], rel, g.x2 + 3, g.y0, g.right, g.y1)\n",
       "painted: the middle and the right end overlap",
       expect="the pieces do not meet", script=S)

mutate("Looks/Painted.lua",
       "\tlocal unit = math.max(1, H)\n",
       "\tlocal unit = math.max(1, 44)\n",
       "painted: the painting a fixed height",
       expect="painted: the pieces follow the prompt's width and height", script=S)

mutate("Looks/Painted.lua",
       "\t\tlw, over = L - cut, over - cut\n",
       "\t\tover = over - cut\n",
       "painted: the left end squeezed rather than cut back",
       expect="painted: an end cut back keeps the painting's proportion", script=S)

mutate("Looks/Painted.lua",
       "\ts[1]:SetTexCoord(0, g.leftR, 0, d.left.b)\n",
       "\ts[1]:SetTexCoord(0, d.left.r, 0, d.left.b)\n",
       "painted: the left end's file not cut where the end is",
       expect="the left end cut back is drawn", script=S)

mutate("Looks/Painted.lua",
       "\t\t\tunit = W / (lw + rw - hlu - hru)\n",
       "",
       "painted: a painting too long for the prompt runs past it",
       expect="painted: the pieces follow the prompt's width and height", script=S)

# --- the socket, the well, the keycap ---

mutate("Looks/Painted.lua",
       "\ticon:SetPoint(\"CENTER\", kit.art, \"TOPLEFT\", g.socketX, -g.socketY)\n",
       "\ticon:SetPoint(\"CENTER\", kit.art, \"TOPLEFT\", g.socketX + 6, -g.socketY)\n",
       "painted: the icon beside the socket",
       expect="the icon's middle is", script=S)

mutate("Looks/Frost.lua",
       "\tself.textX = g.textX\n\tself:PlaceCrystal(showIcon)\n",
       "\tself:PlaceCrystal(showIcon)\n",
       "painted: Frost's words where its own frame had them",
       expect="the well's text at", script=S)

mutate("Looks/Frost.lua",
       "\tself.chipInset = math.ceil(self.W - keyL) + 3\n",
       "",
       "painted: the words run over the keycap",
       expect="past the keycap", script=S)

mutate("Looks/Frost.lua",
       "\tself.keyBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.keyX, -g.keyY)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -self.chipInset, 0)\n",
       "painted: the key's letter off the keycap",
       expect="the key's letter is at", script=S)

mutate("Looks/Frost.lua",
       "\tpaintedHides = { \"shadow\", \"body\", \"hoar\", \"disc\", \"lip\", \"rune\", \"runeGlow\", \"icicles\", \"rimes\", \"keyChip\" },\n",
       "\tpaintedHides = { \"shadow\", \"body\", \"hoar\", \"disc\", \"lip\", \"rune\", \"runeGlow\", \"icicles\", \"rimes\" },\n",
       "painted: Frost's key tag over the painted keycap",
       expect="Frost's own key tag", script=S)

# --- a fight, and another look ---

mutate("Looks/Painted.lua",
       "\t\tt:SetDesaturated(grey and true or false)\n",
       "\t\tt:SetDesaturated(false)\n",
       "painted: a fight leaves the painting in colour",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Frost.lua",
       "\tns.Looks.Painted.Tone(self, pc[1] * fr, pc[2] * fg, pc[3] * fb, fight or dead)\n",
       "",
       "painted: Frost's dressing leaves the painting alone",
       expect="in a fight the painting is not greyed", script=S)

mutate("Looks/Painted.lua",
       "\t\thide(self)\n\t\tRelease(self)\n",
       "\t\thide(self)\n",
       "painted: another look leaves the painting up",
       expect="under Glass", script=S)

mutate("Looks/Painted.lua",
       "for key, d in pairs(ns.PaintedData or {}) do\n",
       "for key, d in pairs({ wild = ns.PaintedData.frost, frost = ns.PaintedData.frost }) do\n",
       "painted: a look painted with another's painting",
       expect="has a painted frame it has no painting for", script=S)

# --- the words' room ---

mutate("Looks/Painted.lua",
       "\tif short > 0 then\n",
       "\tif false then\n",
       "painted: the ends never hang past a prompt too short for the words",
       expect="the well leaves", script=S)

# --- the keycap and Show my key on the prompt ---

mutate("Looks/Looks.lua",
       "\tif choice == \"hide\" then return false end\n",
       "",
       "painted: Never shows the key",
       expect="Never: the keycap", script=S)

mutate("Looks/Looks.lua",
       "\tif art and art.on then return art.data.keycap.shown ~= false end\n",
       "",
       "painted: a look's own keycap default ignored",
       expect="on a look whose keycap is hidden, the key is drawn", script=S)

mutate("Looks/Painted.lua",
       "\treturn art ~= nil and art.on == true and Looks.KeyWanted(look) and Looks.BoundKey() ~= nil\n",
       "\treturn art ~= nil and art.on == true and Looks.KeyWanted(look)\n",
       "painted: a blank keycap with no key bound",
       expect="with no key bound", script=S)

mutate("Looks/Frost.lua",
       "\tif not ns.Looks.KeyWanted(self) then return nil end\n",
       "",
       "painted: Frost's own tag deaf to Show my key",
       expect="Earlier art, Never", script=S)

mutate("Looks/Painted.lua",
       "\tart.keycap:Hide()\n",
       "",
       "painted: the keycap left up when the painting goes",
       expect="under Glass, Frost's keycap is drawn", script=S)

mutate("Looks/Painted.lua",
       "\tlocal kx, ky = g.keyX + c.dx * g.unit, g.keyY + c.dy * g.unit\n",
       "\tlocal kx, ky = g.keyX + 4, g.keyY + c.dy * g.unit\n",
       "painted: the keycap piece beside the keycap",
       expect="the keycap piece is at", script=S)

mutate("Core.lua",
       "\toneOf(p, \"keycap\", { look = true, show = true, hide = true }, \"look\")\n",
       "",
       "painted: Show my key not repaired",
       expect="a damaged Show my key is kept", script=S)

mutate("Options/Look.lua",
       "\t\t\tkeycap = {\n\t\t\t\ttype = \"select\",\n",
       "\t\t\tkeycapGone = {\n\t\t\t\ttype = \"select\",\n",
       "painted: no control for Show my key",
       expect="no control on the Look page sets prompt.keycap", script=S)
