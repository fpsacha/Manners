# Mutations for the Letter look: tests/scenarios/look-letter.lua, with the seal's
# room judged by hunt37-effects.lua and the switching checks by looks.lua.
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
   "\tself.rim:SetVertexColor(w[1] * k, w[2] * k, w[3] * k, 1)\n",
   "\tself.rim:SetVertexColor(k, k, k, 1)\n",
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
   "\tclassContrast = 4.5,\n",
   "",
   "class colours left as the class paints them, on parchment",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m("Prompt/Paint.lua",
   "\tif contrast then\n\t\tlocal key = \"class\" .. c.colorStr",
   "\tif false then\n\t\tlocal key = \"class\" .. c.colorStr",
   "the shared class colour code ignoring a look's contrast",
   expect="the ink reads on the paper at 4.5:1", script=S)

_m(LETTER,
   "\tcodeContrast = 4.5,\n",
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
   "local PAPER_LUM, PAPER_LUM_LOW = 0.707, 0.496\n",
   "local PAPER_LUM, PAPER_LUM_LOW = 0.707, 0.70\n",
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
   "\t\tEach(self.paperL[c], \"SetVertexColor\", r, g, b, 1)\n",
   "\t\tEach(self.paperL[c], \"SetVertexColor\", r, g, b, 0.9)\n",
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
   "\t\tif self.countMode then nameRoom = (self.countW or 0) + 4 end\n",
   "",
   "the name running under the count's slip",
   expect="the count's slip is over the name", script=S)

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
   "\t\tself.drops[i] = tex(self.chipFrame, \"ARTWORK\", 0, \"Dot\")\n",
   "\t\tself.drops[i] = tex(self.chipFrame, \"ARTWORK\", 0, \"Seal\")\n",
   "a file that ships and nothing draws",
   expect="Dot ships but the look never draws it", script=S)

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
   "\tif grow.SetScaleFrom then grow:SetScaleFrom(0.80, 0.80) end\n",
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
   "SEAL_R = 0.88\n",
   "SEAL_R = 0.90\n",
   "the seal's radius in the generator not the look's",
   expect="the seal's radius, the icon's edge", script=S)

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
   "disabled = function() return not P().showIcon or P().style == \"letter\" end,",
   "disabled = function() return not P().showIcon end,",
   "the round icon toggle live on a seal that is always round",
   expect="the round icon toggle is live on a seal that is always round", script=S)

_m("Core.lua",
   "\toneOf(p, \"style\", ns.Looks.Allowed(), ns.defaults.profile.prompt.style)\n",
   "\toneOf(p, \"style\", ns.Looks.Allowed(), \"letter\")\n",
   "an unknown saved style becoming the letter instead of the default",
   expect="an unknown saved style becomes the default", script=S)
