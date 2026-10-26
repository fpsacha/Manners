# Mutations for the Whisper look: tests/scenarios/look-whisper.lua, and the
# per-look loops of looks.lua and hunt37-effects.lua that name it.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make -- a reason line that lost the colour, a breath that
# loops on Calm, a line that grows from the wrong end, a shake left at five
# units, a dot with no round mask, type with no outline over snow, a list name
# anchored to a region -- and names the check that has to object.

WHISPER = "Looks/Whisper.lua"
S = "runscenarios.py"

# --- the reason ------------------------------------------------------------

mutate(WHISPER,
       "\t\tself.ring:SetVertexColor(r, g, b, 0.95)\n",
       "\t\tself.ring:SetVertexColor(0.5, 0.5, 0.5, 0.95)\n",
       "look-whisper: the dot's ring never takes the reason",
       expect="the dot's ring is not in", script=S)

mutate(WHISPER,
       "\tself.plain:SetVertexColor(r, g, b, 0.95)\n",
       "\tself.plain:SetVertexColor(1, 1, 1, 0.95)\n",
       "look-whisper: the plain dot is white",
       expect="the plain dot is not in", script=S)

mutate(WHISPER,
       "\tkit.sub:SetTextColor(sr, sg, sb, 1)\n",
       "\tkit.sub:SetTextColor(0.9, 0.9, 0.9, 1)\n",
       "look-whisper: the reason line is not in the reason's colour",
       expect="the reason line is not in", script=S)

mutate(WHISPER,
       "\tif mode == \"off\" then\n\t\tr, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]\n\tend\n",
       "",
       "look-whisper: the reason line keeps its colour with the marker off",
       expect="with the marker off the reason line is still a colour", script=S)

mutate(WHISPER,
       "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, mode ~= \"off\"\n",
       "\treturn true, true\n",
       "look-whisper: the options page is told the marker is always on",
       expect="AccentCarriers says", script=S)

mutate(WHISPER,
       "\tsr, sg, sb = OnBlack(sr, sg, sb, 7)\n",
       "",
       "look-whisper: the reason line is not held to its black edge",
       expect="the reason line for", script=S)

mutate(WHISPER,
       "local ROW_REASON = \"|cffbfc2d0\"\n",
       "local ROW_REASON = \"|cff505058\"\n",
       "look-whisper: the words after a list name are dim grey at the edge",
       expect="the words after a list row's name", script=S)

mutate(WHISPER,
       "\tclassSoften = 0.85,\n",
       "",
       "look-whisper: class-coloured names left as they are",
       expect="leaves class-coloured names", script=S)

mutate(WHISPER,
       "\tcombatArtAlpha = 1,\n",
       "\tcombatArtAlpha = 0.55,\n",
       "look-whisper: the fight dims the whole art",
       expect="lets the fight dim its art", script=S)

# --- legible by its own letters ---------------------------------------------

mutate(WHISPER,
       "\t\tSetFace(fs, path, size, \"OUTLINE\")\n",
       "\t\tSetFace(fs, path, size, \"\")\n",
       "look-whisper: the type has no outline, so snow takes it",
       expect="is not outlined", script=S)

mutate(WHISPER,
       "\t\tfs:SetShadowColor(0, 0, 0, 0.65)\n",
       "\t\tfs:SetShadowColor(0, 0, 0, 0)\n",
       "look-whisper: the type has no shadow",
       expect="no soft shadow", script=S)

mutate(WHISPER,
       "\tif (Luminance(r, g, b) + 0.05) / 0.05 < 7 then r, g, b = Mix(r, g, b, 0.9) end\n",
       "",
       "look-whisper: a dark font colour stays dark in a black outline",
       expect="the name with a dark font colour", script=S)

mutate(WHISPER,
       "\tink.light, ink.lo, ink.hi = true, 0.02, 0.02\n",
       "",
       "look-whisper: a light panel colour darkens the handle's words",
       expect="with a light panel colour the handle's words were taken dark", script=S)

mutate(WHISPER,
       "\tlocal path = fit.path\n",
       "\tlocal path = \"Interface\\\\AddOns\\\\Manners\\\\Fonts\\\\Own.TTF\"\n",
       "look-whisper: the look names a font file of its own",
       expect="names a font file of its own", script=S)

mutate(WHISPER,
       "\tif not fs:SetFont(path, size, flags) or not fs:GetFont() then\n\t\tfs:SetFont(STANDARD_TEXT_FONT, size, flags)\n\tend\n",
       "\tfs:SetFont(path, size, flags)\n",
       "look-whisper: a font the client refuses leaves a line with no font",
       expect="an unloadable font threw", script=S)

# --- the outcomes ----------------------------------------------------------

mutate(WHISPER,
       "\tfailed = { 1.00, 0.50, 0.30 },\n",
       "\tfailed = { 0.55, 0.55, 0.60 },\n",
       "look-whisper: a refusal is not red-amber",
       expect="a refusal's reason line is not red-amber", script=S)

mutate(WHISPER,
       "\tcast = { 0.52, 0.90, 0.52 },\n",
       "\tcast = { 0.90, 0.52, 0.52 },\n",
       "look-whisper: a landed buff is not green",
       expect="a landed buff's reason line is not green", script=S)

# --- the reason in letter-spaced capitals ---------------------------------

mutate(WHISPER,
       "\t\tif self.upper then value = self:Caps(fs, setText, value) end\n",
       "",
       "look-whisper: the reason is not set in capitals",
       expect="plain ASCII is not letter-spaced capitals", script=S)

mutate(WHISPER,
       "\tout = out:gsub(\"  \", \"   \")\n",
       "",
       "look-whisper: the words of a spaced line run together",
       expect="plain ASCII is not letter-spaced capitals", script=S)

mutate(WHISPER,
       "\t\tif width and width <= self.subRoom then out = spaced end\n",
       "\t\tout = spaced\n",
       "look-whisper: a line too long to space is spaced and cut",
       expect="a line too long to space is not plain capitals", script=S)

mutate(WHISPER,
       "\tif caps:find(\"[A-Z]\") and not caps:find(\"[\\128-\\255|]\") then\n",
       "\tif caps:find(\"[A-Z]\") then\n",
       "look-whisper: a capitalised line with an accent is spaced",
       expect="a capitalised line with an accent was changed", script=S)

mutate(WHISPER,
       "\tif text:find(\"[\\128-\\255]\") or text:find(\"|[TtHh]\") or not text:find(\"[a-z]\") then return text end\n",
       "\tif text:find(\"|[TtHh]\") or not text:find(\"[a-z]\") then return text end\n",
       "look-whisper: a line with an accent is capitalised byte by byte",
       expect="a line with an accent was changed", script=S)

mutate(WHISPER,
       "\tlocal out = text:upper():gsub(\"|C(%x%x%x%x%x%x%x%x)\", function(hex) return \"|c\" .. hex:lower() end)\n",
       "\tlocal out = text:upper()\n",
       "look-whisper: capitals break a colour code",
       expect="a coloured line is not plain capitals", script=S)

mutate(WHISPER,
       "\tif text == self.capsIn then return self.capsOut end\n",
       "",
       "look-whisper: every repaint sets and measures the reason again",
       expect="measured", script=S)

mutate(WHISPER,
       "\tself.upper = false\n",
       "",
       "look-whisper: the reason stays in capitals after the look is left",
       expect="on glass the reason is still in capitals", script=S)

# --- motion ----------------------------------------------------------------

mutate(WHISPER,
       "\t\t\tif not self.breaths[1]:IsPlaying() then PlayAll(self.breaths) end\n",
       "",
       "look-whisper: the owed breath never plays",
       expect="do not breathe", script=S)

mutate(WHISPER,
       "\t\tif full then\n\t\t\tif not self.breaths[1]:IsPlaying()",
       "\t\tif true then\n\t\t\tif not self.breaths[1]:IsPlaying()",
       "look-whisper: the breath loops on Calm",
       expect="animation(s) loop on Calm", script=S)

mutate(WHISPER,
       "function Whisper:StopAttention()\n\tStopAll(self.breaths)\n",
       "function Whisper:StopAttention()\n",
       "look-whisper: the breath never stops",
       expect="the breath still loops with nobody owed", script=S)

mutate(WHISPER,
       "local BREATH_SECONDS = 1.5\n",
       "local BREATH_SECONDS = 0.3\n",
       "look-whisper: the breath is a flutter",
       expect="faster than a slow one", script=S)

mutate(WHISPER,
       "local BREATH_LOW, BREATH_REST, BREATH_HIGH = 0.45, 0.90, 1.0\n",
       "local BREATH_LOW, BREATH_REST, BREATH_HIGH = 0.0, 0.90, 1.0\n",
       "look-whisper: the breath goes out and comes back",
       expect="the breath is not a gentle shift", script=S)

mutate(WHISPER,
       "\tif isNew and not self.combat then\n\t\tStopAll(self.warns)",
       "\tif not self.combat then\n\t\tStopAll(self.warns)",
       "look-whisper: the type comes up again on every repaint",
       expect="came up again", script=S)

mutate(WHISPER,
       "\tdrop:SetOffset(0, -5)\n",
       "\tdrop:SetOffset(0, -2)\n",
       "look-whisper: the name's rise does not end where it began",
       expect="does not end where it began", script=S)

mutate(WHISPER,
       "\t\tif full then self.nameArrival:Play() else self.nameArrivalCalm:Play() end\n",
       "\t\tself.nameArrival:Play()\n",
       "look-whisper: the name rises on Calm",
       expect="on Calm the name rose", script=S)

mutate(WHISPER,
       "grow:SetOrigin(\"LEFT\", 0, 0)",
       "grow:SetOrigin(\"CENTER\", 0, 0)",
       "look-whisper: the line grows from its middle",
       expect="does not grow from its left end", script=S)

mutate(WHISPER,
       "\tgrow:SetDuration(0.30)\n",
       "\tgrow:SetDuration(0.90)\n",
       "look-whisper: the line takes more than a landing's time",
       expect="a landing is under 0.7", script=S)

mutate(WHISPER,
       "\tif swell.SetScaleTo then swell:SetScaleTo(1.06, 1.06) end\n",
       "\tif swell.SetScaleTo then swell:SetScaleTo(1.60, 1.60) end\n",
       "look-whisper: the bloom swells past the letters",
       expect="the bloom is not a small swell", script=S)

mutate(WHISPER,
       "for i = 0, 7 do\n\tlocal a = i * math.pi / 4\n",
       "for i = 0, 1 do\n\tlocal a = i * math.pi / 4\n",
       "look-whisper: the bloom has too few copies to hug the letters",
       expect="too few copies of the letters", script=S)

mutate(WHISPER,
       "\t\techo:SetTextColor(r, g, b, 1)\n",
       "\t\techo:SetTextColor(1, 1, 1, 1)\n",
       "look-whisper: the bloom is not in the outcome's colour",
       expect="is not in the outcome's green", script=S)

mutate(WHISPER,
       "\t\tself.echoFrame:SetPoint(\"LEFT\", kit.textLayer, \"LEFT\", self.nameX, self.nameY)\n",
       "\t\tself.echoFrame:SetPoint(\"LEFT\", kit.textLayer, \"LEFT\", self.nameX, self.nameY + 9)\n",
       "look-whisper: the bloom lies off the name",
       expect="the bloom does not lie where the name stands", script=S)

mutate(WHISPER,
       "\tif full then self.drawAnim:Play() else self.calmAnim:Play() end\n",
       "\tself.drawAnim:Play()\n",
       "look-whisper: the line is drawn from its end on Calm",
       expect="on Calm the line was drawn", script=S)

mutate(WHISPER,
       "\tif full then self.bloomAnim:Play() else self.bloomCalm:Play() end\n",
       "\tself.bloomAnim:Play()\n",
       "look-whisper: the name blooms with a swell on Calm",
       expect="on Calm the line was drawn or the name bloomed", script=S)

mutate(WHISPER,
       "\t\tStopAll(self.arrivals)\n\t\tStopAll(self.warns)\n\t\tPlayAll(self.warns)\n",
       "\t\tStopAll(self.arrivals)\n\t\tStopAll(self.warns)\n\t\tPlayAll(self.warns)\n"
       "\t\tself:Draw(true, 1, 0.4, 0.3)\n",
       "look-whisper: a refusal draws the line",
       expect="a refusal drew the line", script=S)

mutate(WHISPER,
       "\t\tStopAll(self.arrivals)\n\t\tStopAll(self.warns)\n\t\tPlayAll(self.warns)\n",
       "\t\tStopAll(self.arrivals)\n\t\tStopAll(self.warns)\n",
       "look-whisper: a refusal does not dip the dot and the reason",
       expect="a refusal did not dip", script=S)

mutate(WHISPER,
       "local SHAKE_SCALE = 0.4\n",
       "local SHAKE_SCALE = 1\n",
       "look-whisper: the refusal's shake is left at five units",
       expect="Whisper's nudge is two", script=S)

mutate(WHISPER,
       "\tself:QuietShake(false)\n",
       "",
       "look-whisper: the shared shake is not given back",
       expect="the shared shake is still Whisper's two units", script=S)

mutate(WHISPER,
       "\t\t\tlocal was = self.shakeWas[step]\n",
       "\t\t\tlocal was = nil\n",
       "look-whisper: restyling takes the nudge down again each time",
       expect="restyling changed the nudge", script=S)

mutate(WHISPER,
       "\tanim:Stop()\n\tanim.to = (on and self.lineOn) and 1 or 0\n\tanim.fade:SetFromAlpha(from)\n\tanim.fade:SetToAlpha(anim.to)\n\tanim.fade:SetDuration(on and 0.12 or 0.18)\n\tanim:Play()\n",
       "\tanim:Stop()\n\tanim.to = (on and self.lineOn) and 1 or 0\n\tanim.fade:SetFromAlpha(from)\n\tanim.fade:SetToAlpha(anim.to)\n\tanim.fade:SetDuration(on and 0.12 or 0.18)\n",
       "look-whisper: the cursor does not light the line",
       expect="did not light the line", script=S)

# --- the fight --------------------------------------------------------------

mutate(WHISPER,
       "\t\tfor _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(1) end\n\telse\n",
       "\t\tfor _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(0.4) end\n\telse\n",
       "look-whisper: the dot and the reason are dimmed in a fight",
       expect="the dot or the reason is dimmed in a fight", script=S)

mutate(WHISPER,
       "local INK_COMBAT, TEXT_COMBAT = 0.62, 0.82\n",
       "local INK_COMBAT, TEXT_COMBAT = 1, 0.82\n",
       "look-whisper: the icon is not dimmed in a fight",
       expect="the icon is not dimmed in a fight", script=S)

# --- laying out ------------------------------------------------------------

mutate(WHISPER,
       "\t\tsubY = top - reasonH / 2\n",
       "\t\tsubY = -top + reasonH / 2\n",
       "look-whisper: the reason line sits under the name",
       expect="is not above the name", script=S)

mutate(WHISPER,
       "\tself.nameX = self.subX\n",
       "\tself.nameX = PAD\n",
       "look-whisper: the name does not begin where the reason does",
       expect="do not begin at one edge", script=S)

mutate(WHISPER,
       "\tlocal dotY = two and subY or nameY\n",
       "\tlocal dotY = 0\n",
       "look-whisper: the dot is not on the line it leads",
       expect="the dot is not on the line it leads", script=S)

mutate(WHISPER,
       "\t\tD = math.max(7, math.min(math.floor(p.iconSize * 0.4 + 0.5), cap, math.floor(room)))\n",
       "\t\tD = math.max(7, math.min(math.floor(p.iconSize * 0.4 + 0.5), cap))\n",
       "look-whisper: the dot's ring is not held inside the panel",
       expect="the dot's ring leaves the panel", script=S)

mutate(WHISPER,
       "\t\tself.ring:SetPoint(\"TOPLEFT\", icon, \"TOPLEFT\", -RING_PAD, RING_PAD)\n",
       "\t\tself.ring:SetPoint(\"TOPLEFT\", icon, \"TOPLEFT\", -RING_PAD, RING_PAD + 3)\n",
       "look-whisper: the ring is not round the icon",
       expect="the ring is not round the icon", script=S)

mutate(WHISPER,
       "\tself.mask:SetTexture(ART .. \"MaskRound\", \"CLAMPTOBLACKADDITIVE\", \"CLAMPTOBLACKADDITIVE\")\n",
       "\tself.mask:SetTexture(ART .. \"Bar\", \"CLAMPTOBLACKADDITIVE\", \"CLAMPTOBLACKADDITIVE\")\n",
       "look-whisper: the icon is cut by a square mask",
       expect="the icon's mask is not the round one", script=S)

mutate(WHISPER,
       "\t\ticon:AddMaskTexture(self.mask)\n\t\tself.masked = true\n",
       "\t\tself.masked = true\n",
       "look-whisper: the icon is not cut round at all",
       expect="the icon is not cut by the look's mask", script=S)

mutate(WHISPER,
       "\tlocal x = math.floor(self.nameX + width + 7 + 0.5)\n",
       "\tlocal x = math.floor(self.nameX + 7 + 0.5)\n",
       "look-whisper: the count lies on the name",
       expect="the count overlaps the name", script=S)

mutate(WHISPER,
       "\tface(kit.count, R)\n",
       "\tface(kit.count, N)\n",
       "look-whisper: the count is as large as the name",
       expect="the count is not smaller than the name", script=S)

mutate(WHISPER,
       "\tlocal countUp = on and self:NameFits((keyUp and self.keyRoom or 0) + self.countRoom) or false\n",
       "\tlocal countUp = on and true or false\n",
       "look-whisper: the count is up over a name it cuts",
       expect="the count or the key is up over the long name", script=S)

mutate(WHISPER,
       "\tlocal keyUp = key ~= nil and self:NameFits(self.keyRoom)\n",
       "\tlocal keyUp = key ~= nil\n",
       "look-whisper: the key is up over a name it cuts",
       expect="the count or the key is up over the long name", script=S)

mutate(WHISPER,
       "\t\t\tself.keyText:SetText(\"[\" .. key .. \"]\")\n",
       "\t\t\tself.keyText:SetText(key)\n",
       "look-whisper: the key is not in brackets",
       expect="the key is not up as [F]", script=S)

mutate(WHISPER,
       "\tkit.fit.room[name] = math.max(20, self.W - self.nameX - right)\n",
       "",
       "look-whisper: the name is fitted to a room that is not its own",
       expect="the key leaves the panel", script=S)

mutate(WHISPER,
       "\tlocal lineY = math.max(nameY - nameH / 2 - 2.0, -H / 2 + 2.5)\n",
       "\tlocal lineY = nameY\n",
       "look-whisper: the line under the name lies on the letters",
       expect="the line under the name covers the type", script=S)

mutate(WHISPER,
       "math.min(math.floor(fs * 1.2 + 0.5), p.height - 6)",
       "math.min(fs, p.height - 6)",
       "look-whisper: the name is no larger than the player's size",
       expect="is not clearly larger than the reason line", script=S)

mutate(WHISPER,
       "\tlocal rows = math.max(7, math.floor(fs * 0.80 + 0.5))\n",
       "\tlocal rows = math.max(7, math.floor(fs * 1.50 + 0.5))\n",
       "look-whisper: the list is set larger than the name",
       expect="smaller than the name", script=S)

mutate(WHISPER,
       "function Whisper.TwoLineHeight(fontSize)\n\treturn math.max(ns.TwoLineHeight(fontSize, \"glass\"), math.ceil(BlockHeight(fontSize) + 4))\n",
       "function Whisper.TwoLineHeight(fontSize)\n\treturn math.ceil(BlockHeight(fontSize) + 4)\n",
       "look-whisper: it asks for less height than glass does",
       expect="asks for less than glass", script=S)

mutate(WHISPER,
       "function Whisper.TwoLineHeight(fontSize)\n\treturn math.max(ns.TwoLineHeight(fontSize, \"glass\"), math.ceil(BlockHeight(fontSize) + 4))\n",
       "function Whisper.TwoLineHeight(fontSize)\n\treturn math.max(ns.TwoLineHeight(fontSize, \"glass\"), math.ceil(BlockHeight(fontSize) + 40))\n",
       "look-whisper: a profile with two lines on glass loses one",
       expect="where glass has two lines, Whisper has one", script=S)

# --- under the text, the list, leaving ------------------------------------

mutate(WHISPER,
       "\tself.lineFrame = frame(art, 0, base + 1)\n",
       "\tself.lineFrame = frame(art, 0, base + 40)\n",
       "look-whisper: a frame of its motion is over the text",
       expect="not under the text's", script=S)

mutate(WHISPER,
       "\tself.echoFrame = frame(textLayer, 0, text + 1)\n",
       "\tself.echoFrame = frame(textLayer, 0, text + 9)\n",
       "look-whisper: the bloom lies over the letters",
       expect="the bloom is not under the reason and the name", script=S)

mutate("tests/scenarios/hunt37-effects.lua",
       "local ALL = { \"glass\", \"framed\", \"minimal\", \"luxe\", \"toast\", \"arcane\", \"whisper\", \"heritage\" }",
       "local ALL = { \"glass\", \"framed\", \"minimal\", \"luxe\", \"toast\", \"arcane\", \"heritage\" }",
       "look-whisper: hunt37's per-look loops forget it",
       expect="per-look loops do not name Whisper", script=S)

mutate("tests/scenarios/looks.lua",
       "\t\t\tlocal read = said:lower():gsub(\"%s+\", \"\")\n",
       "\t\t\tlocal read = said\n",
       "look-whisper: the shared verdict check reads letter-spaced capitals as they are",
       expect="the lines do not say the verdict", script=S)

mutate(WHISPER,
       "\t\tfs:SetPoint(\"LEFT\", art, edge, self.subX, y)\n",
       "\t\tfs:SetPoint(\"LEFT\", self.lineFrame, edge, self.subX, y)\n",
       "look-whisper: a list name hangs from a frame that is not the panel's",
       expect="and cannot be clicked", script=S)

mutate(WHISPER,
       "\t\tfs:SetPoint(\"LEFT\", art, edge, self.subX, y)\n",
       "\t\tfs:SetPoint(\"LEFT\", art, edge, PAD, y)\n",
       "look-whisper: the list does not start in the reason's column",
       expect="does not start in the reason's column", script=S)

mutate(WHISPER,
       "\t\tdot:SetVertexColor(c[1], c[2], c[3], 0.95)\n",
       "\t\tdot:SetVertexColor(0.6, 0.6, 0.6, 0.95)\n",
       "look-whisper: a list dot is grey",
       expect="dot is grey", script=S)

mutate(WHISPER,
       "\tif shown == self.listShown and above == self.listAbove then return end\n",
       "",
       "look-whisper: every repaint lays the list out again",
       expect="re-anchored", script=S)

mutate(WHISPER,
       "\t\t\ty = 4 + (shown - i) * pitch + pitch / 2\n",
       "\t\t\ty = 4 + (i - 1) * pitch + pitch / 2\n",
       "look-whisper: a list above the panel reads upwards",
       expect="the list does not read from the top", script=S)

mutate(WHISPER,
       "\tself.rowReach = self.subX - self.dotX + 5\n",
       "\tself.rowReach = 0\n",
       "look-whisper: a name's click area leaves out its dot",
       expect="click area does not hold its dot", script=S)

mutate(WHISPER,
       "\t\tkit.name:SetParent(kit.textLayer)\n",
       "",
       "look-whisper: the name is left in its own frame when the look is left",
       expect="the lines are still in Whisper's frames", script=S)

mutate(WHISPER,
       "\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n",
       "\t\tself.masked = nil\n",
       "look-whisper: the icon keeps its mask when the look is left",
       expect="mask still shapes the icon", script=S)

mutate(WHISPER,
       "\tkit.count:SetJustifyH(\"CENTER\")\n",
       "",
       "look-whisper: the count keeps its alignment when the look is left",
       expect="the count kept Whisper's alignment", script=S)

mutate(WHISPER,
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tfor _, group in ipairs(self.breaths) do group:Stop() end\n",
       "\tfor _, group in ipairs(self.breaths) do group:Stop() end\n",
       "look-whisper: its regions are left showing when the look is left",
       expect="still shows under", script=S)

# --- the move handle -------------------------------------------------------

mutate(WHISPER,
       "\tself.marksFrame:SetShown(unlocked)\n",
       "\tself.marksFrame:SetShown(true)\n",
       "look-whisper: the move marks show on a locked prompt",
       expect="the move marks show on a locked prompt", script=S)

mutate(WHISPER,
       "\tlocal unlocked = p.locked == false\n",
       "\tlocal unlocked = false\n",
       "look-whisper: an unlocked prompt shows no move handle",
       expect="is hidden while unlocked", script=S)

mutate(WHISPER,
       "\t\t\tlight:SetVertexColor(MARK_GOLD[1], MARK_GOLD[2], MARK_GOLD[3], 0.95)\n",
       "\t\t\tlight:SetVertexColor(0.3, 0.3, 0.9, 0.95)\n",
       "look-whisper: the move marks are not the gold handle",
       expect="is not the gold handle's colour", script=S)

mutate(WHISPER,
       "\t\t\tdark:SetVertexColor(0, 0, 0, 0.55)\n",
       "\t\t\tdark:SetVertexColor(0, 0, 0, 0)\n",
       "look-whisper: the move marks have no dark stroke to read over snow",
       expect="has no dark stroke", script=S)

mutate(WHISPER,
       "\t\t\tlight:SetPoint(corner, art, corner, dx * 1, dy * 1)\n",
       "\t\t\tlight:SetPoint(corner, art, corner, dx * 40, dy * 1)\n",
       "look-whisper: the move marks are pulled in over the type",
       expect="lies on the type", script=S)

# --- no box, the toc, the art ----------------------------------------------

mutate(WHISPER,
       "\tself.ringFlare = frame(art, 1, base + 1)\n",
       "\tself.ringFlare = frame(art, 1, base + 1)\n"
       "\tself.veil = tex(self.ringFlare, \"BACKGROUND\", -6, \"Bar\")\n"
       "\tself.veil:SetAllPoints(art)\n",
       "look-whisper: a sheet is laid behind the type",
       expect="is the size of a panel", script=S)

mutate(WHISPER,
       "\tname = L[\"Whisper -- floating letters, the reason in small capitals\"],\n",
       "\tname = L[\"Whisper -- no box, one thin line in the reason colour\"],\n",
       "look-whisper: its name has no translation",
       expect="its name is translated", script=S)

mutate("Manners.toc",
       "Looks\\Whisper.lua\n",
       "",
       "look-whisper: its file is not in the toc",
       expect="no look registered as whisper", script=S)

mutate("tools/make_whisper_textures.py",
       "    save(\"Whisper_Line\", ramp * smooth(edge / 12.0))\n",
       "    save(\"Whisper_Line\", ramp * smooth(edge / 12.0) * (1 - 0.01 * np.random.rand(h, w)))\n",
       "look-whisper: the generator is not deterministic",
       expect="differs between two runs", script=S)

mutate("tools/make_whisper_textures.py",
       "RING_INNER = 0.86\n",
       "RING_INNER = 0.70\n",
       "look-whisper: the generator draws a different ring from the one that ships",
       expect="does not match the file that ships", script=S)

mutate("tools/make_whisper_textures.py",
       "    w, h = 128, 2\n",
       "    w, h = 120, 2\n",
       "look-whisper: a texture that is not a power of two",
       expect="not a power of two", script=S)
