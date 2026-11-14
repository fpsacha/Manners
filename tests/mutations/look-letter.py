# Mutations for the Letter look: tests/scenarios/look-letter.lua, with the seal's
# room judged by hunt37-effects.lua and the switching checks by looks.lua. The
# torn sheet, the writing, the flourish and the glint are at the end.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

LETTER = "Looks/Letter.lua"
GEN = "tools/make_letter_textures.py"


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only look-letter finds them
    all, the ones that edit the toc, a locale and Options included."""
    mutate(file, old, new, "look-letter: " + label, **kw)


S = "runscenarios.py"

# --- the reason ------------------------------------------------------------

_m(LETTER,
   "\tif mode ~= \"icon\" and mode ~= \"both\" then return WAX_NEUTRAL[1], WAX_NEUTRAL[2], WAX_NEUTRAL[3] end\n",
   "",
   "the marker switched off and the wax still carries the reason",
   expect="with the marker off the wax still carries the reason", script=S)

_m(LETTER,
   "\tif p.accentByReason == false then return r, g, b end\n",
   "",
   "the marker colour the player chose ignored by the wax",
   expect="the marker colour the player chose is not the wax", script=S)

_m(LETTER,
   "\t\towed = { 0.80, 0.10, 0.13 },\n\t\ttarget = { 0.12, 0.58, 0.58 },",
   "\t\towed = { 0.18, 0.30, 0.82 },\n\t\ttarget = { 0.12, 0.58, 0.58 },",
   "owed is not red wax in the standard set",
   expect="the default seal is not red wax", script=S)

_m(LETTER,
   "\t\tnearby = { 0.17, 0.17, 0.20 },\n",
   "\t\tnearby = { 0.12, 0.58, 0.60 },\n",
   "a stranger's wax nearly the colour of the target's",
   expect="wax are only", script=S)

_m(LETTER,
   "\t\towed = { 0.93, 0.43, 0.05 },\n",
   "\t\towed = { 0.50, 0.08, 0.22 },\n",
   "the colourblind set's owed and asked wax the same",
   expect="wax are only", script=S)

_m(LETTER,
   "\tColour(self.rim, w[1] * k, w[2] * k, w[3] * k)\n",
   "\tColour(self.rim, k, k, k)\n",
   "the seal's lip left uncoloured",
   expect="the lip is not", script=S)

_m(LETTER,
   "\tif ruleOn then\n\t\tlocal dr, dg, db = kit.Legible(rr, rg, rb, 3)",
   "\tif false then\n\t\tlocal dr, dg, db = kit.Legible(rr, rg, rb, 3)",
   "the stroke of ink never drawn",
   expect="on stripe only the stroke of ink is not drawn", script=S)

_m(LETTER,
   "\t\tlocal dr, dg, db = kit.Legible(rr, rg, rb, 3)\n",
   "\t\tlocal dr, dg, db = rr, rg, rb\n",
   "the stroke of ink in the palette's own colour, too light for the paper",
   expect="is under 3:1 on the paper", script=S)

_m(LETTER,
   "\treturn mode == \"icon\" or mode == \"both\", mode == \"stripe\" or mode == \"both\"\n",
   "\treturn mode == \"stripe\" or mode == \"both\", mode == \"icon\" or mode == \"both\"\n",
   "the marker's carriers the wrong way round",
   expect="AccentCarriers", script=S)

_m(LETTER,
   "\t\tlocal sr, sg, sb = kit.Legible(mr, mg, mb, 4.5)\n\t\tkit.sub:SetTextColor(sr, sg, sb, 1)\n\telse",
   "\t\tkit.sub:SetTextColor(mr, mg, mb, 1)\n\telse",
   "the reason line's ink leaning towards the reason, too light to read",
   expect="the reason line in", script=S)

# --- the ink and the paper ---------------------------------------------------

_m(LETTER,
   "\tclassContrast = 5,\n",
   "",
   "class colours left as the class paints them, on parchment",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m("Prompt/Paint.lua",
   "\tif contrast then\n\t\tlocal key = \"class\" .. c.colorStr",
   "\tif false then\n\t\tlocal key = \"class\" .. c.colorStr",
   "the shared class colour code ignoring a look's contrast",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m(LETTER,
   "\tcodeContrast = 5,\n",
   "",
   "colour codes held to 3:1 only, on parchment",
   expect="a colour code the player wrote", script=S)

_m("Prompt/Text.lua",
   "\tlocal least = S.activeLook and S.activeLook.codeContrast or CODE_CONTRAST\n",
   "\tlocal least = CODE_CONTRAST\n",
   "the shared colour code ignoring a look's contrast",
   expect="a colour code the player wrote", script=S)

_m(LETTER,
   "\tlocal r, gg, b = kit.Legible(INK[1], INK[2], INK[3], 4.5)\n",
   "\tlocal r, gg, b = 0.80, 0.80, 0.80\n",
   "the name written in a light ink on the paper",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m(LETTER,
   "\tink.light = false\n",
   "\tink.light = true\n",
   "the parchment called a dark ground, so the code takes colours towards white",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m(LETTER,
   "\t\ttr, tg, tb = Pale(tr, tg, tb, PAPER_FLOOR, PAPER_RGB)\n",
   "",
   "a dark panel colour making the parchment dark",
   expect="too dark for paper", script=S)

_m(LETTER,
   "\tif chosen then\n\t\tlocal m = math.max(",
   "\tif true then\n\t\tlocal m = math.max(",
   "the default panel colour tinting the parchment",
   expect="the default panel colour tints the parchment", script=S)

_m(LETTER,
   "local PAPER_LUM, PAPER_LUM_LOW = 0.756, 0.494\n",
   "local PAPER_LUM, PAPER_LUM_LOW = 0.756, 0.70\n",
   "the look's idea of its paper lighter than the file's",
   expect="the look's idea of its paper is the file's", script=S)

_m(LETTER,
   "\tself.paperLow = PAPER_LUM_LOW * dim / was\n",
   "\tself.paperLow = PAPER_LUM_LOW * now / was\n",
   "the ink chosen for the paper at rest, not for the paper in a fight",
   expect=", fight,", script=S)

_m(LETTER,
   "\t\tlocal sr, sg, sb = kit.Legible(o[1] * 0.75, o[2] * 0.75, o[3] * 0.75, 4.5)\n\t\tkit.sub:SetTextColor(sr, sg, sb, 1)\n",
   "\t\tkit.sub:SetTextColor(o[1], o[2], o[3], 1)\n",
   "an outcome's verdict in the outcome's own light colour",
   expect="the verdict of the", script=S)

_m(LETTER,
   "\tself:PaintPaper(on and DIM_PAPER or 1)\n",
   "\tself:PaintPaper(1)\n",
   "the paper not dimmed in a fight",
   expect="the paper is not dimmer in a fight", script=S)

_m(LETTER,
   "\t\tfor _, t in ipairs(self.paperL[c]) do Colour(t, r, g, b) end\n",
   "\t\tfor _, t in ipairs(self.paperL[c]) do Colour(t, r, g, b, 0.9) end\n",
   "the paper a little see-through",
   expect="see-through", script=S)

# --- the frame, the seal and the text ----------------------------------------

_m(LETTER,
   "\tg.rodW, g.rodL, g.rodR = rodW, SHAKE, W - SHAKE - rodW\n",
   "\tg.rodW, g.rodL, g.rodR = rodW, 0, W - rodW\n",
   "the rods against the prompt's edge, with no room for a shake",
   expect="a rod is nearer the edge than a shake's room", script=S)

_m(LETTER,
   "\tlocal textRight = g.x1 - 0.30 * g.paperH\n",
   "\tlocal textRight = g.x1 + 6\n",
   "the text running under the right rod",
   expect="runs over a rod", script=S)

_m(LETTER,
   "\tg.textX = math.ceil(g.sealRight + 4.5)\n",
   "\tg.textX = math.ceil(g.sealRight - 8)\n",
   "the text starting over the seal",
   expect="starts over the seal", script=S)

_m(LETTER,
   "\tlocal reach = H - 2.5\n",
   "\tlocal reach = H + 6\n",
   "the seal taller than the prompt",
   expect="outside the prompt", script=S)

_m(LETTER,
   "\tg.iconSize = math.max(8, math.floor(ICON_AT * g.sealD + 0.5))\n",
   "\tg.iconSize = math.max(8, math.floor(0.4 * g.sealD + 0.5))\n",
   "an icon smaller than the seal's recess",
   expect="the icon is", script=S)

_m(LETTER,
   "\tlocal need = nameSize + subSize + 3\n",
   "\tlocal need = nameSize + subSize + 30\n",
   "two lines needing more height than the default prompt has",
   expect="the default size shows no second line", script=S)

_m(LETTER,
   "\t\t\tself.paperL[c][r] = tex(art, \"BACKGROUND\", -6, \"Paper\")\n",
   "\t\t\tself.paperL[c][r] = tex(self.paperFrame, \"BACKGROUND\", -6, \"Paper\")\n",
   "the paper under the seal on a frame over the icon",
   expect="is not on art itself", script=S)

_m(LETTER,
   "\tlocal k = Clamp(math.floor(midH / tile + 0.5), 1, TILES)\n",
   "\tlocal k = 1\n",
   "a long paper stretched from one tile, leaving no room to meet",
   expect="is stretched", script=S)

# --- the slips and the lines -------------------------------------------------

_m(LETTER,
   "\t\tkeyUp = two or self:NameFits(base + self.keyW + 4)\n",
   "\t\tkeyUp = false\n",
   "a bound key with no slip",
   expect="a bound key shows no slip", script=S)

_m(LETTER,
   "\t\tif self.keyUp then subRoom = (self.keyW or 0) + 4 end\n",
   "",
   "the reason running under the key's slip",
   expect="the key's slip is over the reason", script=S)

_m(LETTER,
   "\t\tif self.countMode == \"chip\" then nameRoom = (self.countW or 0) + 4 end\n",
   "",
   "the name running under the count's slip",
   expect="the count's slip is over the name", script=S)

_m(LETTER,
   "\t\tif self.countMode == \"sub\" then subRoom = subRoom + (self.countW or 0) + 4 end\n",
   "",
   "the reason running under the count's slip",
   expect="the count's slip is over the reason", script=S)

# The name's room at the default size with a count and a key up: the count's
# slip is pinned on the seal, so it takes the room of neither line.
_m(LETTER,
   "\tself.sealOK = showIcon and g.sealD / 2 >= SEAL_BADGE_FROM and self.badgeH <= g.sealD / 2 * 0.75\n",
   "\tself.sealOK = false\n",
   "the count's slip back on the lines, taking their room",
   expect="is not cut at the default size", script=S)

_m(LETTER,
   "\t\tself.countBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.cx + dx, -(g.cy + dy))\n",
   "\t\tself.countBox:SetPoint(\"CENTER\", art, \"TOPLEFT\", g.cx + dx, -g.cy)\n",
   "the count's slip in the middle of the seal, off the wax's edge",
   expect="not on the wax's edge", script=S)

_m(LETTER,
   "\t\tself.countBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -edge, nameDy)\n",
   "\t\tself.countBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -edge, subDy)\n",
   "the count on the reason's line",
   expect="the count's slip is not on the name line", script=S)

# --- the list ----------------------------------------------------------------

_m(LETTER,
   "\tself:LayRods(y0 - g.pv + 1, y1 + g.pv - 1)\n",
   "",
   "a list that lengthens the paper but not the rods",
   expect="do not stand over the paper", script=S)

_m(LETTER,
   "\t\trow:SetParent(self.rowFrame)\n",
   "",
   "the rows left on art, under the paper",
   expect="is not on the rows' frame", script=S)

_m(LETTER,
   "\t\t{ self.rowFrame, 5 },\n",
   "\t\t{ self.rowFrame, 0 },\n",
   "the rows' frame under the paper's",
   expect="the rows' frame is not over the paper's", script=S)

_m(LETTER,
   "\t\t{ self.glowFrame, 5 },\n",
   "\t\t{ self.glowFrame, 7 },\n",
   "the candle's light over the text",
   expect="candle is not beneath the text", script=S)

_m(LETTER,
   "\tfor _, row in ipairs(kit.rows) do row:SetParent(kit.art) end\n",
   "",
   "the rows left on the letter's frame for the next look",
   expect="is still on the letter's frame on glass", script=S)

_m(LETTER,
   "\t\tself.drops[i]:SetPoint(\"CENTER\", art, \"TOPLEFT\", self.dropX, -y)\n",
   "\t\tself.drops[i]:SetPoint(\"CENTER\", art, \"TOPLEFT\", self.rowX, -y)\n",
   "a drop of wax not under the seal",
   expect="drop of wax is not under the seal", script=S)

_m(LETTER,
   "\tself.mark = tex(self.sealFrame, \"ARTWORK\", 0, \"Mark\")\n",
   "\tself.mark = tex(self.sealFrame, \"ARTWORK\", 0, \"Seal\")\n",
   "a file that ships and nothing draws",
   expect="Mark ships but the look never draws it", script=S)

# --- motion ------------------------------------------------------------------

_m(LETTER,
   "\tfor _, group in ipairs(self.unrollGroups) do group:Play() end\n",
   "\tself.unrollGroups[1]:Play()\n",
   "an unroll that moves the window and not the paper and the rod",
   expect="did not unroll the scroll", script=S)

_m(LETTER,
   "\tself.slideP:SetOffset(-back, 0)\n",
   "\tself.slideP:SetOffset(back, 0)\n",
   "the paper sliding with its window, so it does not hold still",
   expect="do not move together", script=S)

_m(LETTER,
   "\tself.paperSlide:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.splitX, -(self.paperTop or 0))\n",
   "\tself.paperSlide:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.splitX + 3, -(self.paperTop or 0))\n",
   "the window not put back where it belongs when the unroll ends",
   expect="not at rest", script=S)

_m(LETTER,
   "\tif self.paperSlide.SetClipsChildren then self.paperSlide:SetClipsChildren(true) end\n",
   "",
   "a window onto the paper that does not cut it",
   expect="does not cut what it holds", script=S)

_m(LETTER,
   "\tfor _, group in ipairs(self.unrollGroups) do group:Stop() end\n\tself.paperSlide:ClearAllPoints()\n"
   "\tself.paperSlide:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.splitX - back, -(self.paperTop or 0))\n"
   "\tself.paperSheet:ClearAllPoints()\n"
   "\tself.paperSheet:SetPoint(\"TOPLEFT\", self.paperSlide, \"TOPLEFT\", back, 0)\n"
   "\tself.rodRight:ClearAllPoints()\n"
   "\tself.rodRight:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.rodR - back, -(self.rodY0 or 1))\n"
   "\tfor _, group in ipairs(self.unrollGroups) do group:Play() end\n",
   "\tself.paperSlide:ClearAllPoints()\n"
   "\tself.paperSlide:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.splitX - back, -(self.paperTop or 0))\n"
   "\tself.paperSheet:ClearAllPoints()\n"
   "\tself.paperSheet:SetPoint(\"TOPLEFT\", self.paperSlide, \"TOPLEFT\", back, 0)\n"
   "\tself.rodRight:ClearAllPoints()\n"
   "\tself.rodRight:SetPoint(\"TOPLEFT\", self.kit.art, \"TOPLEFT\", self.g.rodR - back, -(self.rodY0 or 1))\n"
   "\tfor _, group in ipairs(self.unrollGroups) do group:Stop() group:Play() end\n",
   "an unroll stopped after its frames were moved, which puts them back at rest",
   expect="an unroll begun while one runs does not start from its start", script=S)

_m(LETTER,
   "\tself.shakes = {}\n\tself.shakeList = {",
   "\tself.shakes = {}\n\tself.shakeList = { self.paperFrame } or {",
   "a scroll shaking by its paper alone, the rods and the seal left behind",
   expect="does not shake with it", script=S)

_m(LETTER,
   "local SHAKE_STEPS = { -2, 3, -3, 2, -1, 1 }\n",
   "local SHAKE_STEPS = { -2, 3, -3, 2, -1, 4 }\n",
   "a shake that does not settle",
   expect="the scroll's shake does not settle", script=S)

_m(LETTER,
   "\tlocal full = self.kit.FullEffects()\n\tif flashStyle == \"off\" or self.combat then",
   "\tlocal full = true\n\tif flashStyle == \"off\" or self.combat then",
   "Calm unrolling the scroll and breathing",
   expect="look-letter: Calm is fades only", script=S)

_m(LETTER,
   "\tif grow.SetScaleFrom then grow:SetScaleFrom(0.55, 0.55) end\n",
   "\tif grow.SetScaleFrom then grow:SetScaleFrom(1.30, 1.30) end\n",
   "the seal pressing down from a size bigger than the prompt",
   expect="hunt37-effects: the rings, the echo and the halo stay in their room, in letter", script=S)

_m(LETTER,
   "local BREATHS, BREATH = 3, 1.3\n",
   "local BREATHS, BREATH = 30, 1.3\n",
   "a candle that breathes thirty times",
   expect="the owed breath still loops after its three breaths", script=S)

_m(LETTER,
   "\tAlpha(core, 0, CORE_PEAK, BREATH * 0.62, 1, nil, \"IN_OUT\")\n",
   "\tAlpha(core, 0, CORE_PEAK, BREATH, 1, nil, \"IN_OUT\")\n",
   "the candle's core breathing in step with its glow",
   expect="the core is not quicker than the glow", script=S)

_m(LETTER,
   "\t\tPlayAll(self.crackAnims)\n",
   "",
   "a refusal that does not crack the seal",
   expect="a refusal did not crack the seal", script=S)

_m(LETTER,
   "\tPlayAll(self.passAnims)\n",
   "",
   "a landing that passes no light over the paper",
   expect="did not pass a light over the paper", script=S)

_m(LETTER,
   "\tif kind ~= \"cast\" then return end\n",
   "",
   "a cast nobody confirmed claiming a landing",
   expect="a cast nobody confirmed got a flourish", script=S)

_m(LETTER,
   "function Letter:StopAttention()\n\tself.pulseGen = (self.pulseGen or 0) + 1\n\tfor _, g in ipairs(self.pulse) do g:Stop() end\n",
   "function Letter:StopAttention()\n\tself.pulseGen = (self.pulseGen or 0) + 1\n",
   "a breath that does not stop with the favour",
   expect="the glow stayed with nobody owed", script=S)

_m(LETTER,
   "\tif on then\n\t\tself:StopAttention()\n\t\tself:StopFlourishes()\n\tend\n",
   "\tif on then\n\t\tself:StopFlourishes()\n\tend\n",
   "the candle still breathing in a fight",
   expect="something loops in a fight", script=S)

_m(LETTER,
   "\tif held then self:Combat(true) end\n",
   "",
   "a fight's hold lost when the look is laid out again",
   expect="laying the look out again during the hold", script=S)

_m(LETTER,
   "\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n\tend\n\tself.mask:Hide()\n",
   "",
   "the seal's mask left on the icon for the next look",
   expect="the seal's mask still cuts the icon on glass", script=S)

_m(LETTER,
   "\ticon:SetAlpha(1)\n\ticon:SetVertexColor(1, 1, 1)\n",
   "\ticon:SetAlpha(1)\n",
   "the icon left dimmed for the next look",
   expect="left the icon dimmed on glass", script=S)

# --- the font ----------------------------------------------------------------

_m(LETTER,
   "\tif LATIN[locale] then return MORPHEUS end\n",
   "\tif LATIN[locale] then return nil end\n",
   "a Latin client without the letter's face",
   expect="the name is in", script=S)

_m(LETTER,
   "\tif d ~= nil and p.font ~= d then return nil end\n",
   "",
   "the player's chosen font overridden",
   expect="the font the player chose is not the name's", script=S)

_m(LETTER,
   "\tif locale == \"ruRU\" then return MORPHEUS_CYR end\n",
   "\tif locale == \"ruRU\" then return MORPHEUS end\n",
   "a Russian client in a face without Cyrillic",
   expect="the font on a ruRU client", script=S)

_m(LETTER,
   "\tif serif then return fs + 1, math.max(7, fs - 2) end\n",
   "\tif serif then return fs, math.max(7, fs - 3) end\n",
   "Morpheus at the size of a face with a bigger x-height",
   expect="pt, not", script=S)

# --- the art, the toc, the translations and the generator -------------------

_m(LETTER,
   "\tself.shadow = tex(self.shadowClip, \"ARTWORK\", 0, \"SealShadow\")\n",
   "\tself.shadow = tex(self.shadowClip, \"ARTWORK\", 0, \"SealShadow\")\n\tself.shadow:SetTexture(\"Interface\\\\Buttons\\\\WHITE8X8\")\n",
   "a texture of the client's in a look that draws its own",
   expect="which is not its own art", script=S)

_m("Manners.toc",
   "Looks\\Letter.lua\n",
   "",
   "the look left out of the toc",
   expect="no look is registered as letter", script=S)

_m("Locales/deDE.lua",
   "L[\"Letter -- parchment and a red wax seal\"] = \"Brief \u2013 Pergament und ein rotes Wachssiegel\"",
   "L[\"Letter -- parchment and a red wax seal\"] = \"Letter -- parchment and a red wax seal\"",
   "the look's name left in English in German",
   expect="deDE's translation of letter -- parchment and a red wax seal", script=S)

_m("Locales/koKR.lua",
   "L[\"parchment and a red wax seal\"] = \"\uc591\ud53c\uc9c0\uc640 \ubd89\uc740 \ubc00\ub78d \uc778\uc7a5\"",
   "L[\"parchment and a red wax seal\"] = \"parchment and a red wax seal\"",
   "the look's line left in English in Korean",
   expect="koKR's translation of parchment and a red wax seal", script=S)

_m(GEN,
   "    rng = np.random.default_rng(seed)\n    nx = int(",
   "    rng = np.random.default_rng()\n    nx = int(",
   "texture noise seeded from the clock",
   expect="differs between two runs", script=S)

_m(GEN,
   "SEAL_R = 0.90\n",
   "SEAL_R = 0.92\n",
   "the seal's radius in the generator not the look's",
   expect="the seal's radius, the icon's edge", script=S)

# --- the wax: the icon pressed into it, and the light on it never tinted -----

_m(LETTER,
   "local SEAL_R, ICON_AT, SEAL_EDGE = 0.90, 0.60, 0.96\n",
   "local SEAL_R, ICON_AT, SEAL_EDGE = 0.90, 0.72, 0.96\n",
   "the icon nearly three quarters of the wax, the seal a frame for it",
   expect="the icon is pressed into the wax at a little over half its diameter", script=S)

_m(LETTER,
   "\tg.iconSize = math.max(8, math.floor(ICON_AT * g.sealD + 0.5))\n",
   "\tg.iconSize = math.max(8, math.floor(0.70 * g.sealD + 0.5))\n",
   "the icon sized to a share of the wax the look does not declare",
   expect="of the wax's diameter", script=S)

_m(LETTER,
   "\tColour(self.gloss, 1, 1, 1, k >= 1 and 1 or 0.7)\n",
   "\tColour(self.gloss, w[1] * k, w[2] * k, w[3] * k, k >= 1 and 1 or 0.7)\n",
   "the light on the wax tinted with the wax",
   expect="the light on the seal is tinted", script=S)

_m(LETTER,
   "\tColour(self.gloss, 1, 1, 1, k >= 1 and 1 or 0.7)\n",
   "\tColour(self.gloss, 1, 1, 1)\n",
   "the light on the wax as bright in a fight as out of one",
   expect="the light on the wax is not fainter in a fight", script=S)

_m(LETTER,
   "\tfor _, t in ipairs(self.pins) do Colour(t, w[1] * k, w[2] * k, w[3] * k) end\n",
   "",
   "the drops that pin the slips left white, not the seal's wax",
   expect="is not the seal's wax", script=S)

_m(LETTER,
   "\tfor _, t in ipairs(self.dropLights) do Colour(t, 1, 1, 1) end\n",
   "\tfor _, t in ipairs(self.dropLights) do Colour(t, 0.9, 0.2, 0.2) end\n",
   "the light on the list's drops tinted",
   expect="a drop's light is tinted", script=S)

_m(LETTER,
   "\t\tself.dropLights[i]:Show()\n",
   "",
   "a drop of wax in the list with no light on it",
   expect="has no light on it", script=S)

_m(LETTER,
   "\t\tself.dropLights[i]:ClearAllPoints()\n\t\tself.dropLights[i]:SetAllPoints(self.drops[i])\n",
   "\t\tself.dropLights[i]:ClearAllPoints()\n\t\tself.dropLights[i]:SetAllPoints(self.drops[i])\n\t\tself.dropLights[i]:SetPoint(\"CENTER\", art, \"TOPLEFT\", self.rowX, -y)\n",
   "a drop's light drawn away from its drop",
   expect="light is not where the drop is", script=S)

_m(LETTER,
   "\t\tt:SetPoint(\"CENTER\", box, \"TOPLEFT\", d * 0.50, -d * 0.45)\n",
   "\t\tt:SetPoint(\"CENTER\", box, \"CENTER\", 0, 0)\n",
   "the pin in the middle of its slip, over the writing",
   expect="pin is not on its slip's upper left corner", script=S)

_m(LETTER,
   "\tself.pins = { self.countPin }\n",
   "\tself.pins = { self.countPin }\n\tself.keyPin = tex(self.chipFrame, \"ARTWORK\", 2, \"Dot\")\n",
   "a drop of wax on the key's slip, away from the seal",
   expect="the key's slip is pinned with a drop of wax", script=S)

_m(GEN,
   "SHADOW_ZOOM = 1.34\n",
   "SHADOW_ZOOM = 1.50\n",
   "the shadow's zoom in the generator not the look's",
   expect="the shadow's zoom", script=S)

_m(GEN,
   "TEXT_U = (0.30, 0.92)\n",
   "TEXT_U = (0.10, 0.99)\n",
   "the paper's measured stretch not the stretch the text lies on",
   expect="the generator measures", script=S)

_m("Options/Look.lua",
   "disabled = function() return not P().showIcon or ns.Looks.RoundAlways(P().style) end,",
   "disabled = function() return not P().showIcon end,",
   "the round icon toggle live on a seal that is always round",
   expect="the round icon toggle is live on a seal that is always round", script=S)

_m("Core.lua",
   "\toneOf(p, \"style\", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)\n",
   "\toneOf(p, \"style\", ns.Looks.Allowed(), \"letter\")\n",
   "an unknown saved style becoming the letter instead of the default",
   expect="an unknown saved style becomes the default", script=S)

# --- the torn sheet and its folds --------------------------------------------

_m(LETTER,
   "\tg.b = math.max(2.4, 0.098 * g.paperH)\n",
   "\tg.b = math.max(1, 0.03 * g.paperH)\n",
   "the lines laid as near the sheet's edge as if it were cut straight",
   expect="stands in the tear", script=S)

_m(LETTER,
   "\tself.lightClip:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", g.splitX, -(y0 + g.b))\n\tself.lightClip:SetSize(w, lightH)\n",
   "\tself.lightClip:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", g.splitX, -y0)\n\tself.lightClip:SetSize(w, h)\n",
   "the light that crosses cut at the file's edge, not the paper's",
   expect="the light falls beyond the torn edge", script=S)

_m(LETTER,
   "local FOLD_FROM = 150\n",
   "local FOLD_FROM = 0\n",
   "a sheet too short to have been folded, folded",
   expect="a short sheet is folded", script=S)

_m(LETTER,
   "\tself.folds[2]:SetTexCoord(1, 0, 0, 1)\n",
   "",
   "both folds going the same way",
   expect="the second fold is not the first mirrored", script=S)

_m(LETTER,
   "\t\tColour(self.folds[i], r, g, b)\n",
   "\t\tColour(self.folds[i], 1, 1, 1)\n",
   "the folds left the parchment's own colour on a tinted sheet",
   expect="is not the sheet's tint", script=S)

_m(GEN,
   "    return np.clip(e, 0.7, DECKLE_MAX - 0.9)\n",
   "    return np.clip(e, 0.0, 0.2)\n",
   "a sheet cut straight, drawn by the generator and not shipped",
   expect="does not match the file that ships", script=S)

_m(GEN,
   "    make_quill()\n    make_flourish()\n",
   "    make_flourish()\n",
   "a file the look draws that the generator no longer writes",
   expect="the generator wrote", script=S)

_m(GEN,
   "QUILL_NIB = (13, 11)\n",
   "QUILL_NIB = (40, 11)\n",
   "the quill's point in the generator not where the look holds it",
   expect="the quill's point", script=S)

_m(LETTER,
   "\t\tif h - 2 * pv - 2 * b - LIFT * ph >= need then return h end\n",
   "\t\tif h - 2 * pv >= need then return h end\n",
   "two lines said to fit where the torn edges leave them no room",
   expect="look-letter: the sheet is torn at its long edges and the lines stand clear of the tear", script=S)

# --- the writing ---------------------------------------------------------------

_m(LETTER,
   "\tfor _, hold in ipairs(self.holds) do\n\t\thold:Stop()\n\t\thold:Play()\n\tend\n",
   "",
   "the words standing in the air beyond the roll while the scroll unrolls",
   expect="the words are not held back while the scroll unrolls", script=S)

_m(LETTER,
   "\tfor i, f in ipairs({ kit.textLayer, self.chipFrame, self.rowFrame }) do\n",
   "\tfor i, f in ipairs({ self.chipFrame, self.rowFrame, self.rowFrame }) do\n",
   "the slips and the rows held back, and the words themselves not",
   expect="the words, the slips or the rows are not held back", script=S)

_m(LETTER,
   "\t\tAlpha(hold, 0, 0, UNROLL_SECONDS + 0.01, 1)\n",
   "\t\tAlpha(hold, 0, 0, UNROLL_SECONDS + 1.5, 1)\n",
   "the words held back long after the scroll is open",
   expect="a hold lasts", script=S)

_m(LETTER,
   "\tDelay(w.on, math.max(0, delay - 0.02))\n",
   "\tDelay(w.on, 0)\n",
   "the cover there while the scroll unrolls, paper where no paper is yet",
   expect="the cover is over the sheet before the paper is", script=S)

_m(LETTER,
   "\tw.back:SetOffset(-travel, 0)\n",
   "\tw.back:SetOffset(travel, 0)\n",
   "the cover's copy sliding with its window, so it does not hold still",
   expect="the cover's copy does not hold still", script=S)

_m(LETTER,
   "\t\t{ self.inkFrame, kit.TEXT_LEVEL + 1 }, { self.inkSlide, kit.TEXT_LEVEL + 1 }, { self.inkSheet, kit.TEXT_LEVEL + 1 },\n",
   "\t\t{ self.inkFrame, 3 }, { self.inkSlide, 3 }, { self.inkSheet, 3 },\n",
   "the cover under the text, where it covers nothing",
   expect="cover is not over the text", script=S)

_m(LETTER,
   "\tif self.inkSlide.SetClipsChildren then self.inkSlide:SetClipsChildren(true) end\n",
   "",
   "a cover whose window does not cut it, over the whole sheet for as long as the pen is down",
   expect="the cover's window does not cut what it holds", script=S)

_m(LETTER,
   "\tPark(slide, self.inkSlide, 0)\n",
   "\tPark(slide, self.inkSlide, 1)\n",
   "the cover left over the words when the pen has passed",
   expect="the cover is left over the words after the pen has passed", script=S)

_m(LETTER,
   "\tlocal over = Cut(right, g.rodR - 0.5, \"left\")\n",
   "\tlocal over = right\n",
   "the cover running on over the right rod",
   expect="the cover reaches over the right rod", script=S)

_m(LETTER,
   "\t\t\t\tBox(tc, self.inkSheet, cc[1] - ox, row[1] - oy, cc[2] - ox + 0.25, row[2] - oy + 0.25)\n",
   "\t\t\t\tBox(tc, self.inkSheet, cc[1] - ox + 3, row[1] - oy, cc[2] - ox + 3.25, row[2] - oy + 0.25)\n",
   "the cover laid three units off the paper it copies",
   expect="a piece of the cover", script=S)

_m(LETTER,
   "\t\tfor _, t in ipairs(self.paperC[c]) do Colour(t, r, g, b) end\n",
   "",
   "the cover left the parchment's own colour over a tinted sheet",
   expect="the cover is not the paper's colour", script=S)

_m(LETTER,
   "\tlocal from = g.textX - 2\n\tlocal room = g.rodR - 0.5 - from\n",
   "\tlocal from = g.textX + 30\n\tlocal room = g.rodR - 0.5 - from\n",
   "a pen that comes down in the middle of the name",
   expect="the pen does not start at the name", script=S)

_m(LETTER,
   "\t\tif wide > 0 then reach = Clamp(wide + 8, 24, room) end\n",
   "\t\tif wide > 0 then reach = Clamp(wide * 0.5, 24, room) end\n",
   "a pen lifted half way along the line, the rest of it uncovered at a stroke",
   expect="the longer line is", script=S)

_m(LETTER,
   "\tlocal function down()\n\t\tLetter.quill:SetAlpha(0)\n\t\tLetter.quill:Hide()\n\tend\n",
   "\tlocal function down()\n\tend\n",
   "the quill left on the sheet when it has written",
   expect="the quill is left on the sheet", script=S)

_m(LETTER,
   "local QUILL_STROKES = { -5, 10, -10, 10, -10, 5 }\n",
   "local QUILL_STROKES = { -5, 10, -10, 10, -10, 25 }\n",
   "the quill's turns leaving it askew",
   expect="the quill's turns do not sum to nothing", script=S)

_m(LETTER,
   "\tw.pen:SetOffset(travel, 0)\n",
   "\tw.pen:SetOffset(travel * 0.5, 0)\n",
   "the quill falling behind the pen it is",
   expect="the quill does not go with", script=S)

_m(LETTER,
   "\tself.quill:SetPoint(\"BOTTOMLEFT\", art, \"TOPLEFT\", from - QUILL_NIB[1] * q, -penY - QUILL_NIB[2] * q)\n",
   "\tself.quill:SetPoint(\"BOTTOMLEFT\", art, \"TOPLEFT\", from, -penY)\n",
   "the quill set down by its corner, its point off the pen",
   expect="the quill's point is not on the pen", script=S)

_m(LETTER,
   "\t\t\tfor _, g in ipairs(self.pressAnims) do\n\t\t\t\tg:Stop()\n\t\t\t\tg:Play()\n\t\t\tend\n",
   "",
   "a seal pressed with no light of the stamp on it",
   expect="the stamp's light did not follow", script=S)

_m(LETTER,
   "\t\t\tself:WriteLetter()\n",
   "",
   "a favour that arrives and is not written in",
   expect="did not put the cover over the sheet", script=S)

# --- the outcomes: the flourish, the glow, the crack ---------------------------

_m(LETTER,
   "\tPlayAll(self.haloAnims)\n\tself:Sign()\n",
   "\tPlayAll(self.haloAnims)\n",
   "a landing nobody signs",
   expect="a landed buff was not signed with a flourish", script=S)

_m(LETTER,
   "\tPlayAll(self.haloAnims)\n",
   "",
   "a landing with no glow round the seal",
   expect="a landed buff did not glow round the seal", script=S)

_m(LETTER,
   "\t\t\tColour(self.swash, sr, sg, sb, 0.92)\n",
   "\t\t\tColour(self.swash, 1, 1, 1, 0.92)\n",
   "the flourish left white on the parchment",
   expect="the flourish is not in the verdict's ink", script=S)

_m(LETTER,
   "\t\t\tsigned = self.textX + used + 6 <= self.swashX\n",
   "\t\t\tsigned = true\n",
   "the flourish written over a verdict that needs the room",
   expect="the flourish is written over the verdict's own words", script=S)

_m(LETTER,
   "\tw.still:SetOffset(-sw, 0)\n",
   "\tw.still:SetOffset(sw, 0)\n",
   "the flourish sliding in with its window, not written from its left",
   expect="the flourish's window and the stroke in it do not move together", script=S)

_m(LETTER,
   "\tself.swashSheet:SetPoint(\"TOPLEFT\", self.swashClip, \"TOPLEFT\", 0, 0)\nend\n",
   "\tself.swashSheet:SetPoint(\"TOPLEFT\", self.swashClip, \"TOPLEFT\", 4, 0)\nend\n",
   "the flourish not put back where it belongs when it is written",
   expect="after it is written the flourish is not at rest", script=S)

_m(LETTER,
   "\tif two and sw >= 28 then\n",
   "\tif sw >= 28 then\n",
   "a flourish with no second line to lie on",
   expect="a landing is signed with a flourish", script=S)

_m(LETTER,
   "\t\tself.crackAnims[1].to = CRACK_HELD\n",
   "",
   "a crack that closes again while the refusal is still on the panel",
   expect="the crack does not stay in the wax while the refusal stands", script=S)

# --- at rest: the glint ----------------------------------------------------------

_m(LETTER,
   "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
   "\tlocal on = (self.active and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
   "the glint going on in a fight",
   expect="the glint goes on in a fight", script=S)

_m(LETTER,
   "\tlocal on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false\n",
   "\tlocal on = (self.active and not self.combat and self.kit.button:IsShown()) and true or false\n",
   "the glint going on with Effects on Calm",
   expect="the glint goes on with Effects on Calm", script=S)

_m(LETTER,
   "\tself.idle = { anim(glint) }\n",
   "\tself.idle = {}\n\tanim(glint)\n",
   "a loop at rest the look does not name",
   expect="does not name its one loop at rest", script=S)

_m(LETTER,
   "\tAlpha(glint, 0, GLINT_PEAK, 0.14, 1, GLINT_EVERY, \"OUT\")\n",
   "\tAlpha(glint, 0, GLINT_PEAK, 0.14, 1, 0.4, \"OUT\")\n",
   "a glint that comes twice a second",
   expect="which is a blink, not a glint", script=S)

_m(LETTER,
   "\tself.glint:SetPoint(\"CENTER\", art, \"TOPLEFT\", cx - 0.64 * rw, -(cy - 0.37 * rw))\n",
   "\tself.glint:SetPoint(\"CENTER\", art, \"TOPLEFT\", cx + 2.5 * rw, -(cy - 0.37 * rw))\n",
   "the glint out on the paper, off the wax",
   expect="the glint is not on the wax", script=S)

# --- what a review of the pictures found -------------------------------------------

_m(LETTER,
   "\tself.glow = tex(self.glowFrame, \"ARTWORK\", 0, \"Candle\")\n",
   "\tself.glow = tex(self.glowFrame, \"ARTWORK\", 0, \"Candle\", \"ADD\")\n",
   "the candle's glow additive again, for the seconds it breathes",
   expect="the candle's glow rests on the seal and is drawn additive", script=S)

_m(LETTER,
   "\tself.hilite = tex(self.sealFrame, \"ARTWORK\", 2, \"Candle\")\n",
   "\tself.hilite = tex(self.sealFrame, \"ARTWORK\", 2, \"Mask\", \"ADD\")\n",
   "the cursor's light additive again, for as long as the cursor stays",
   expect="the cursor's light rests on the seal and is drawn additive", script=S)

_m(LETTER,
   "\tself.core:SetSize(half * 2 * CORE_SIZE, half * 2 * CORE_SIZE)\n",
   "\tself.core:SetSize(half * 1.2, half * 1.2)\n",
   "the candle's hot ring laid over the icon",
   expect="the hot light's ring does not lie on the lip of the recess", script=S)

_m(GEN,
   "    a = ring * side + 0.14 * np.exp(-(rho / 0.45) ** 2)\n",
   "    a = ring * side + 0.9 * np.exp(-(rho / 0.45) ** 2)\n",
   "the candle's light as strong over the icon as on the wax",
   expect="does not match the file that ships", script=S)

_m(LETTER,
   "\tAlpha(struck, 0, 0, POP_SECONDS * STRUCK_AT, 1)\n",
   "\tAlpha(struck, 1, 1, POP_SECONDS * STRUCK_AT, 1)\n",
   "the icon standing on the paper while the wax is poured under it",
   expect="the icon stands on the paper", script=S)

_m(LETTER,
   "\tself.stamp[#self.stamp + 1] = struck\n",
   "",
   "the icon's coming left out of the stamp",
   expect="the icon's coming is not part of the stamp", script=S)

_m(LETTER,
   "local STRUCK_AT = 0.7\n",
   "local STRUCK_AT = 0.2\n",
   "the icon struck into wax that is still a puddle",
   expect="the icon stands on the paper", script=S)

_m(LETTER,
   "\tself.sweepFrame:SetPoint(\"TOPLEFT\", self.lightClip, \"TOPLEFT\", 0, 0)\n",
   "\tself.sweepFrame:SetPoint(\"TOPLEFT\", self.lightClip, \"TOPLEFT\", -bw, 0)\n",
   "the landing's light slid in through its window's edge",
   expect="units outside its window", script=S)

_m(LETTER,
   "\tself.passAnims[1].move:SetOffset(w + 2, 0)\n",
   "\tself.passAnims[1].move:SetOffset(w * 0.5, 0)\n",
   "the landing's light stopping halfway along the paper",
   expect="the light does not cross the whole paper", script=S)

_m(GEN,
   "    a = a * sstep(0.0, 0.26, y / h) * sstep(1.0, 0.74, y / h)\n",
   "",
   "the landing's light at full strength where it is cut at the torn edges",
   expect="does not match the file that ships", script=S)

_m(LETTER,
   "\tg.sy = math.min(g.paperH / 64, SY_MAX, SY_NARROW * (g.x1 - g.x0))\n",
   "\tg.sy = g.paperH / 64\n",
   "a tall prompt's paper pulled out from one copy of the file",
   expect="a row of the paper's file is drawn", script=S)

_m(LETTER,
   "\tg.sy = math.min(g.paperH / 64, SY_MAX, SY_NARROW * (g.x1 - g.x0))\n",
   "\tg.sy = math.min(g.paperH / 64, SY_MAX)\n",
   "a short tall sheet's rows drawn three times its columns",
   expect="its grain runs in streaks", script=S)

_m(GEN,
   "MID_STRETCH = 1.8\n",
   "MID_STRETCH = 1.0\n",
   "the paper drawn evenly along a middle the look stretches",
   expect="does not match the file that ships", script=S)

_m(GEN,
   "    side = np.clip(0.5 + 0.5 * toward, 0, 1)\n",
   "    side = 0.5 + 0.5 * toward - 0.2\n",
   "the lip's shadow raised to a power where it is under nothing",
   expect="does not match the file that ships", script=S)

_m(LETTER,
   "\t\tlocal rowsTop = math.max(g.zone1 + 2, g.cy + g.sealW / 2 + 1 - slack)\n",
   "\t\tlocal rowsTop = g.zone1 + 2\n",
   "the list begun at the lines' edge, its first drop on the seal",
   expect="drop of wax lies", script=S)

_m(LETTER,
   "\t\tlocal rowsBottom = math.min(g.zone0 - 2, g.cy - g.sealW / 2 - 1 + slack)\n",
   "\t\tlocal rowsBottom = g.zone0 - 2\n",
   "a list above ending at the lines' edge, its last drop on the seal",
   expect="the list above: row 3's drop of wax lies on the seal", script=S)

_m(LETTER,
   "local GLINT_EVERY, GLINT_PEAK, GLINT_SIZE = 4.0, 1, 0.8\n",
   "local GLINT_EVERY, GLINT_PEAK, GLINT_SIZE = 4.0, 1, 0.5\n",
   "the glint a speck on the wax",
   expect="a speck", script=S)

_m(GEN,
   "    px = 6 + 114 * ts + 11.0 * np.sin(turn)\n",
   "    px = 6 + 114 * ts\n",
   "the flourish a plain wave, with no loop in it",
   expect="does not match the file that ships", script=S)
