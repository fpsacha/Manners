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

# --- see-through panes and words on nothing ---

mutate("Looks/PaintedData.lua",
       "\t\tpane = 0.8,\n",
       "\t\tpane = 1,\n",
       "painted: a see-through pane said to be solid",
       expect="pane opacity is", script=S)

mutate("Looks/Plain.lua",
       "\tfor _, t in ipairs(self.backing) do t:SetShown(bare ~= nil) end\n",
       "\tfor _, t in ipairs(self.backing) do t:SetShown(false) end\n",
       "painted: words on nothing with nothing under them",
       expect="the backing under Hairline's words is not drawn", script=S)

mutate("Looks/Plain.lua",
       "\t\tkit.name:SetShadowOffset(1, -1)\n",
       "\t\tkit.name:SetShadowOffset(0, 0)\n",
       "painted: a plain look's name with no shadow",
       expect="Hairline's name has no shadow", script=S)

# --- dark ink ---

mutate("Looks/Painted.lua",
       "\t\tif d.ink.name then DarkInk(self.kit, d.ink, p) end\n",
       "",
       "painted: a painting's own ink ignored",
       expect="under 4.5:1 on the light ground", script=S)

mutate("Looks/Painted.lua",
       "\t\tlook.classContrast, look.codeContrast = DARK_CONTRAST, DARK_CONTRAST\n",
       "",
       "painted: class colours not held to a dark-ink ground",
       expect="not given the class colours' contrast", script=S)

# --- the plain looks ---

mutate("Looks/Painted.lua",
       "\t\tif not (art and (Wanted() or self.paintedOnly)) then\n",
       "\t\tif not (art and Wanted()) then\n",
       "painted: Earlier art strips a plain look bare",
       expect="Earlier art takes its painting away", script=S)

mutate("Looks/Plain.lua",
       "\tLooks.Painted.Tone(self, paint, paint, paint, on)\n",
       "",
       "painted: a plain look's fight leaves its painting alone",
       expect="a fight does not grey the painting", script=S)

mutate("Looks/Plain.lua",
       "\tif d.socket.shape == \"round\" then Looks.roundAlways[row.key] = true end\n",
       "",
       "painted: a round socket follows the round switch",
       expect="its round rule is not its socket's", script=S)

mutate("Looks/Plain.lua",
       "\tlocal textX = self.textX or 0\n",
       "\tlocal textX = 0\n",
       "painted: a plain look's words over its socket",
       expect="the name does not start in the well", script=S)

mutate("Looks/Plain.lua",
       "\tif flashStyle == \"off\" or self.combat or not full then\n",
       "\tif flashStyle == \"off\" or self.combat then\n",
       "painted: a plain look breathes on Calm",
       expect="on Calm the socket's light still moves", script=S)

mutate("Looks/Plain.lua",
       "\t\ty0 = self.H + gap\n",
       "\t\ty0 = gap\n",
       "painted: a plain look's list over its bar",
       expect="the sheet is not under the bar", script=S)

# --- categories and names ---

mutate("Looks/Looks.lua",
       "\t\tif ca ~= cb then return ca < cb end\n",
       "",
       "painted: the dropdown not sorted by category",
       expect="comes after a look of a later category", script=S)

mutate("Looks/Looks.lua",
       "\tminimal = { \"minimal\", \"ghost\", \"hairline\", \"pill\", \"slate\", \"luxe\" },\n",
       "\tminimal = { \"minimal\", \"ghost\", \"hairline\", \"pill\", \"slate\" },\n",
       "painted: Luxe on no shelf",
       expect="luxe is in themed, not minimal", script=S)

mutate("Looks/Fel.lua",
       "\ttitle = L[\"Warlock\"],\n",
       "\ttitle = L[\"Fel\"],\n",
       "painted: Fel keeps its old name",
       expect="fel's card says", script=S)

mutate("Looks/Fel.lua",
       "\tname = L[\"Warlock -- black felsteel and fel fire, a summoning circle\"],\n",
       "\tname = L[\"Fel -- black felsteel and fel fire, a summoning circle\"],\n",
       "painted: the dropdown's label not the card's name",
       expect="dropdown label is", script=S)

mutate("Options/Window/WidgetsTheme.lua",
       "\t\t\tif heads and (i == 1 or list[i - 1].category ~= cat) then y = PlaceHead(row, cat, y, width) end\n",
       "",
       "painted: the gallery's categories with no heading",
       expect="no heading for", script=S)

# Was "the chosen look's shelf shut", while the shelves folded: the picker
# opens on For my class since it has tabs (tests/scenarios/lookpage.lua).
mutate("Options/Window/WidgetsTheme.lua",
       "\t\t\trow.tab = row.counts.mine > 0 and \"mine\" or \"all\"\n",
       "\t\t\trow.tab = \"all\"\n",
       "painted: the picker opens a mage on All, not on the mage looks",
       expect="not For my class", script=S)

# Was "a shelf's heading opens nothing": a tab's click opens a shelf now.
mutate("Options/Window/WidgetsTheme.lua",
       "\trow.tab = b.tab\n\trow:Refresh()\n",
       "\trow:Refresh()\n",
       "painted: a tab's click opens nothing",
       expect="lookpage: a mage's tabs", script=S)
