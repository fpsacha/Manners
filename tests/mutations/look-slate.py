# Mutations for the Slate look: tests/scenarios/look-slate.lua, and the
# per-look checks in hunt35-effects.lua and hunt37-effects.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

SLATE = "Looks/Slate.lua"
GEN = "tools/make_slate_textures.py"

# --- registration ------------------------------------------------------------

mutate(SLATE,
       "\torder = 6,\n",
       "",
       "the look has no place in the dropdown",
       expect="the look has no place in the dropdown",
       script="runscenarios.py")

mutate("Manners.toc",
       "Looks\\Slate.lua\n",
       "",
       "the look is not in the toc",
       expect="no look is registered under",
       script="runscenarios.py")

mutate("Locales/frFR.lua",
       'L["Slate -- modern card, soft shadow, thin progress line"] = "Ardoise -- carte moderne',
       'L["Slate -- modern card, soft shadow, thin progress line"] = "Slate -- carte moderne',
       "the look's name left in English in French",
       expect="left the look's name in English",
       script="runscenarios.py")

mutate(SLATE,
       "\treturn math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 12)\n",
       "\treturn math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 40)\n",
       "two lines asked to be taller than the default panel",
       expect="two lines at the default font need",
       script="runscenarios.py")

# --- painting ------------------------------------------------------------------

mutate(SLATE,
       "\tif icon then self.fx:Land(o[1], o[2], o[3], 0.70) end\n",
       "\tif icon then self.fx:Landed(o[1], o[2], o[3], 0.70) end\n",
       "a landed buff throws on the rings",
       expect="look-slate: every state paints",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal ringW = math.max(0.6, S * RING_FRACTION)\n",
       "\tlocal ringW = math.max(0.6, S * RING_FRACTION * 3)\n",
       "the ring three times too wide, out of the card",
       expect="outside the card",
       script="runscenarios.py")

# --- the layout ----------------------------------------------------------------

mutate(SLATE,
       "\tlocal textX = showIcon and (iconX + S + 10) or (barOn and 19 or 14)\n",
       "\tlocal textX = showIcon and (iconX + S - 4) or (barOn and 19 or 14)\n",
       "the name starts under the icon",
       expect="runs into the icon",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tf:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", x0, -(H - 4.6 - lineH / 2))\n",
       "\t\tf:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", x0, -(H / 2))\n",
       "the line along the bottom runs through the text",
       expect="the line runs through",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal x0 = showIcon and (textX - 4) or (c + 1)\n",
       "\tlocal x0 = c + 1\n",
       "the line along the bottom runs under the icon",
       expect="the line runs under the icon",
       script="runscenarios.py")

mutate(SLATE,
       "\t\ty0 = self.H + 3\n",
       "\t\ty0 = self.H - 3\n",
       "the tray hangs over the card",
       expect="the tray below touches the card",
       script="runscenarios.py")

mutate(SLATE,
       "\t\ty1 = -3\n",
       "\t\ty1 = 3\n",
       "the tray above sits on the card",
       expect="the tray above touches the card",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tfs:SetPoint(\"LEFT\", art, \"TOPLEFT\", self.rowX, -y)\n",
       "\t\tfs:SetPoint(\"LEFT\", self.dots[i], \"RIGHT\", 9, 0)\n",
       "a row hangs off a texture, which a secure button cannot anchor to",
       expect="names are buttons",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.rowReach = showIcon and (self.rowX - cx + 7) or 15\n",
       "\tself.rowReach = 0\n",
       "the click area misses the dot",
       expect="click area misses its dot",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tkeyUp = self:NameFits(self.keyRoom)\n",
       "\t\tkeyUp = true\n",
       "the key's chip never steps aside for a long name",
       expect="the key's chip stayed up",
       script="runscenarios.py")

mutate(SLATE,
       "\t\t\tif self:NameFits(self:PairRoom()) then mode = \"pair\" end\n",
       "\t\t\tmode = \"pair\"\n",
       "the count's chip never steps aside beside the key's",
       expect="both chips are up and cut the name",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tif type(text) == \"string\" and text:match(\"^%d+$\") then count:SetText(\"+\" .. text) end\n",
       "",
       "the count chip says a bare number",
       expect="the count chip does not say how many more",
       script="runscenarios.py")

mutate(SLATE,
       "\tif self.outcomeOn or type(GetBindingKey) ~= \"function\" then return nil end\n",
       "\tif type(GetBindingKey) ~= \"function\" then return nil end\n",
       "the key's chip shows over an outcome",
       expect="the key's chip is up over an outcome",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal room = self.lineRoom - lead\n",
       "\tlocal room = 9999\n",
       "the reason line is never fitted to its room",
       expect="was not fitted",
       script="runscenarios.py")

mutate(SLATE,
       "\tinset = math.min(inset, math.max(0, self.W - self.textX - 20))\n",
       "",
       "the name loses its 20 units at the right",
       expect="hunt34-layout: slate keeps the name 20 units",
       script="runscenarios.py")

mutate(SLATE,
       "\t\t\tself.listShown, self.listAt = nil, nil\n\t\t\tfor _, s in ipairs({ self.trayShadow, self.trayBody, self.trayRim }) do Each(s, \"Hide\") end\n",
       "\t\t\tself.listShown, self.listAt = nil, nil\n",
       "the tray stays when the list goes",
       expect="the tray stayed when the list went",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.dots[i]:SetVertexColor(c[1], c[2], c[3], 1)\n",
       "\tself.dots[i]:SetVertexColor(1, 1, 1, 1)\n",
       "the list's dots are all white",
       expect="dot is not in a reason's colour",
       script="runscenarios.py")

# --- the room the effects keep to ------------------------------------------------

mutate(SLATE,
       "\t\tlocal cap = kit.CapScale(math.min(limitH, limitV), S / 2, 1)\n",
       "\t\tlocal cap = 1e9\n",
       "the icon's bounce is not held to its room",
       expect="past the room's",
       script="runscenarios.py")

mutate(SLATE,
       "\tfor _, f in ipairs(self.fx.frames) do\n\t\tkeep(f)\n\t\tf:SetFrameLevel(base + 2)\n\tend\n",
       "\tfor _, f in ipairs(self.fx.frames) do\n\t\tkeep(f)\n\t\tf:SetFrameLevel(base + 9)\n\tend\n",
       "the rings are drawn over the text",
       expect="hunt37-effects: the light is drawn beneath the text, in slate",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.chipFrame = frame(3)\n",
       "\tself.chipFrame = frame(9)\n",
       "the chips are drawn over the text",
       expect="every frame of Slate's is under the text",
       script="runscenarios.py")

mutate(SLATE,
       "\tkit.RingArt(ART .. \"FxRing\", FX_PEAK, FX_EDGE)\n",
       "\tkit.RingArt(ART .. \"FxRing\", FX_PEAK, 0.5)\n",
       "the ring's reach is declared shorter than its art",
       expect="is seen out to",
       script="runscenarios.py")

# --- the cooldown line -------------------------------------------------------------

mutate(SLATE,
       "\tif self.coolBurn.SetScaleFrom then self.coolBurn:SetScaleFrom(frac, 1) end\n",
       "\tif self.coolBurn.SetScaleFrom then self.coolBurn:SetScaleFrom(1, 1) end\n",
       "the line always starts full",
       expect="the line starts at",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.coolBurn:SetDuration(left)\n",
       "\tself.coolBurn:SetDuration(duration)\n",
       "the line runs the whole cooldown from wherever it has got to",
       expect="look-slate: the cooldown line burns down",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.coolBurn = Grow(burn, 1, 1, 0.001, 1, 1, 1, nil, \"LEFT\")\n",
       "\tself.coolBurn = Grow(burn, 1, 1, 0.001, 1, 1, 1, nil, \"CENTER\")\n",
       "the line burns towards its middle",
       expect="does not burn towards its left edge",
       script="runscenarios.py")

mutate(SLATE,
       "\t\t\tcooldown:SetAlpha(0)\n",
       "\t\t\tcooldown:SetAlpha(1)\n",
       "the sweep is drawn as well as the line",
       expect="the sweep is drawn",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tif Slate.active then Slate:CoolStop() end\n",
       "",
       "a cleared cooldown leaves the line up",
       expect="a cleared cooldown left the line up",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tif Slate.active then Slate:Cool(start, duration) end\n",
       "\t\tSlate:Cool(start, duration)\n",
       "the line burns on another look",
       expect="Slate's line burned on another look",
       script="runscenarios.py")

mutate(SLATE,
       "\tif not self.p.showIcon then return end\n\tself.coolOn = true\n",
       "\tself.coolOn = true\n",
       "a cooldown line with no icon to cool",
       expect="a cooldown line with no icon",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.coolOn = true\n\tlocal frac",
       "\tself.coolOn = true\n\tself.coolBox:SetScript(\"OnUpdate\", function() end)\n\tlocal frac",
       "the line runs a frame script",
       expect="has an OnUpdate while the line runs",
       script="runscenarios.py")

mutate(SLATE,
       "\tif kit.cooldown then\n\t\tkit.cooldown:SetAlpha(1)\n",
       "\tif kit.cooldown then\n",
       "leaving Slate leaves the sweep at no strength",
       expect="the sweep was not given back its strength",
       script="runscenarios.py")

# --- the marker ------------------------------------------------------------------------

mutate(SLATE,
       "\tEach(self.bar, \"SetVertexColor\", r, g, b, 1)\n",
       "\tEach(self.bar, \"SetVertexColor\", 1, 1, 1, 1)\n",
       "the pill is white",
       expect="the pill is not in the reason's colour",
       script="runscenarios.py")

mutate(SLATE,
       "\tif ringOn or outcome then\n",
       "\tif true then\n",
       "the ring wears the reason's colour in every mode",
       expect="the ring wears the reason's colour though the mode says it does not",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.glow:SetVertexColor(r, g, b, 1)\n",
       "\tself.glow:SetVertexColor(1, 1, 1, 1)\n",
       "the owed light is white",
       expect="the owed light is not in the reason's colour",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.barFrame:SetShown(barOn)\n\tself.fx:SetShown(showIcon)\n",
       "\tself.barFrame:SetShown(true)\n\tself.fx:SetShown(showIcon)\n",
       "the pill is up in every mode",
       expect="the pill is up",
       script="runscenarios.py")

mutate(SLATE,
       "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false,\n\t\t(mode == \"stripe\" or mode == \"both\")\n",
       "\treturn (mode == \"stripe\" or mode == \"both\") and p.showIcon and true or false,\n\t\t(mode == \"icon\" or mode == \"both\")\n",
       "the carriers the wrong way round",
       expect="AccentCarriers says",
       script="runscenarios.py")

mutate(SLATE,
       "\tif mode == \"off\" then\n\t\tself:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], mode)\n",
       "\tif false then\n\t\tself:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], mode)\n",
       "the marker off and the card still coloured",
       expect="with the marker off the pill or the light",
       script="runscenarios.py")

# --- the outcomes -------------------------------------------------------------------------

mutate(SLATE,
       "\tself.glyphOn = kind ~= \"sent\"\n",
       "\tself.glyphOn = true\n",
       "a cast nobody confirmed gets a tick",
       expect="a cast nobody confirmed got a tick",
       script="runscenarios.py")

mutate(SLATE,
       "\tif kind ~= \"cast\" then return end\n\tlocal o = OUTCOME.cast\n",
       "\tlocal o = OUTCOME.cast\n",
       "a cast nobody confirmed gets the landing",
       expect="a cast nobody confirmed got a flourish",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.fillGrow = Grow(fill, 0.001, 1, 1, 1, 0.30, 1, \"OUT\", \"LEFT\")\n",
       "\tself.fillGrow = Grow(fill, 0.001, 1, 1, 1, 0.30, 1, \"OUT\", \"CENTER\")\n",
       "the fill grows from its middle",
       expect="the landing's fill does not slide",
       script="runscenarios.py")

mutate(SLATE,
       "\tEach(self.land, \"SetVertexColor\", OUTCOME.cast[1], OUTCOME.cast[2], OUTCOME.cast[3], 1)\n",
       "\tEach(self.land, \"SetVertexColor\", OUTCOME.failed[1], OUTCOME.failed[2], OUTCOME.failed[3], 1)\n",
       "the fill is red for a landed buff",
       expect="the fill is not green",
       script="runscenarios.py")

mutate(SLATE,
       "\tfor i, dx in ipairs({ -2, 3, -3, 2, -1, 1 }) do Slide(shake, dx, 0, 0.045, i) end\n",
       "\tfor i, dx in ipairs({ -2, 3, -3, 2, -1, 2 }) do Slide(shake, dx, 0, 0.045, i) end\n",
       "the pill's shake ends displaced",
       expect="does not end where it began",
       script="runscenarios.py")

mutate(SLATE,
       "\tfor i, dx in ipairs({ -2, 3, -3, 2, -1, 1 }) do Slide(shake, dx, 0, 0.045, i) end\n",
       "\tfor i, dx in ipairs({ -1, 1, -2, 2, -3, 3 }) do Slide(shake, dx, 0, 0.045, i) end\n",
       "the pill's shake grows instead of dying away",
       expect="the pill's shake does not die away",
       script="runscenarios.py")

mutate(SLATE,
       "\tSlide(slide, 6, 0, 0.20, 2, \"OUT\")\n",
       "\tSlide(slide, 7, 0, 0.20, 2, \"OUT\")\n",
       "the pill slides in to the wrong place",
       expect="slide-in does not end at the pill's place",
       script="runscenarios.py")

mutate(SLATE,
       "\tPlayAll(self.refusal)\n",
       "",
       "a refusal does not flash the line",
       expect="a refusal did not flash the line",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal o = OUTCOME[kind] or OUTCOME.cast\n\tlocal word\n",
       "\tlocal o = OUTCOME.sent\n\tlocal word\n",
       "every outcome in the sent colour",
       expect="did not turn the ring green",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tkit.SetLine(kit.name, who)\n",
       "\t\tkit.SetLine(kit.name, lead)\n",
       "the name is rewritten by the outcome",
       expect="a landed buff moved the name",
       script="runscenarios.py")

# --- arrival, the breath, Calm -------------------------------------------------------------

mutate(SLATE,
       "\t\tif full and not self.outcomeOn then\n",
       "\t\tif not self.outcomeOn then\n",
       "the arrival plays on Calm",
       expect="Calm played",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tif full and not self.outcomeOn then\n",
       "\t\tif full then\n",
       "the arrival plays over an outcome",
       expect="the arrival played over an outcome",
       script="runscenarios.py")

mutate(SLATE,
       "\tif not full or self.pulseSpent then\n",
       "\tif self.pulseSpent then\n",
       "Calm keeps the owed light breathing",
       expect="look-slate: Calm plays none",
       script="runscenarios.py")

mutate(SLATE,
       "\t\t\tif Slate.pulse[1]:IsPlaying() then Slate:HoldPulse() end\n",
       "",
       "the breath never stops",
       expect="still breathing after its breaths",
       script="runscenarios.py")

mutate(SLATE,
       "local BREATHS, BREATH = 3, 1.25\n",
       "local BREATHS, BREATH = 3, 2.0\n",
       "a breath four seconds round",
       expect="the breath is",
       script="runscenarios.py")

mutate(SLATE,
       "local WARM = { 1.00, 0.88, 0.66 }\n",
       "local WARM = { 0.66, 0.88, 1.00 }\n",
       "a cold second tone",
       expect="the second tone of the breath is not warm",
       script="runscenarios.py")

mutate(SLATE,
       "\t-- The owed breathing is about the favour, not the click: it stops.\n\t-- Attention starts it again for the next person owed.\n\tself:HoldPulse()\n",
       "",
       "the breath goes on over an outcome",
       expect="the breath went on over an outcome",
       script="runscenarios.py")

mutate(SLATE,
       "\tif flashStyle ~= \"pulse\" then\n\t\tself:StopAttention()\n\t\treturn\n\tend\n\tif not full",
       "\tif not full",
       "the breath plays with the flash on once",
       expect="the breath played with the flash set to",
       script="runscenarios.py")

# --- a fight -----------------------------------------------------------------------------------

mutate(SLATE,
       "\tkit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)\n",
       "\tkit.textLayer:SetAlpha(1)\n",
       "the text does not dim in a fight",
       expect="the text does not dim in a fight",
       script="runscenarios.py")

mutate(SLATE,
       "\tkit.icon:SetDesaturated(on or self.refused or false)\n\t-- Dimmed by its colour",
       "\tkit.icon:SetDesaturated(self.refused or false)\n\t-- Dimmed by its colour",
       "the icon keeps its colour in a fight",
       expect="the icon keeps its colour in a fight",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal v = on and ICON_COMBAT or 1\n",
       "\tlocal v = 1\n",
       "the icon is not dimmed in a fight",
       expect="the icon is not dimmed in a fight",
       script="runscenarios.py")

mutate(SLATE,
       "\tif on then\n\t\tself:StopAttention()\n\t\tfor _, g in ipairs(self.arrive) do g:Stop() end\n",
       "\tif on then\n\t\tfor _, g in ipairs(self.arrive) do g:Stop() end\n",
       "the owed light burns in a fight",
       expect="the owed light is lit in a fight",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.plateColor = { 0.025, 0.030, 0.042, 1 }\n",
       "\tself.plateColor = { 0.025, 0.030, 0.042, 0.4 }\n",
       "nothing opaque under the icon",
       expect="nothing opaque under the icon in a fight",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal held = self.combat\n",
       "\tlocal held = nil\n",
       "a restyle in a fight lets the dim go",
       expect="laying the card out again during the hold",
       script="runscenarios.py")

# --- leaving the look ------------------------------------------------------------------------------

mutate(SLATE,
       "\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n\tend\n\tself.mask:Hide()\n",
       "\tself.mask:Hide()\n",
       "Slate's mask is left on the icon",
       expect="Slate's mask still shapes the icon",
       script="runscenarios.py")

mutate(SLATE,
       "\ticon:SetVertexColor(1, 1, 1)\n\ticon:SetDesaturated(false)\n\tif kit.cooldown then\n",
       "\ticon:SetDesaturated(false)\n\tif kit.cooldown then\n",
       "leaving Slate in a fight leaves the icon dimmed",
       expect="left the icon dimmed on glass",
       script="runscenarios.py")

mutate(SLATE,
       "\tkit.textLayer:SetAlpha(1)\n\tself.combat, self.hovered, self.outcomeOn = nil, nil, nil\n",
       "\tself.combat, self.hovered, self.outcomeOn = nil, nil, nil\n",
       "leaving Slate in a fight leaves the text dimmed",
       expect="left the text dimmed on glass",
       script="runscenarios.py")

mutate(SLATE,
       "\tkit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil\n",
       "",
       "glass inherits the room Slate kept for the lines",
       expect="glass fits its lines to the room Slate kept",
       script="runscenarios.py")

mutate(SLATE,
       "\tfor _, g in ipairs(self.anims) do g:Stop() end\n\tself.fx:Stop()\n\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n",
       "the look's animations keep playing after it goes",
       expect="hunt35-effects: every effect stops cleanly on a repaint and a restyle, in slate",
       script="runscenarios.py")

mutate(SLATE,
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tself.pulseGen",
       "\tself.pulseGen",
       "Slate's pieces stay shown on another look",
       expect="a piece of Slate's is still shown on glass",
       script="runscenarios.py")

# --- the ground ----------------------------------------------------------------------------------------

mutate(SLATE,
       "\treturn math.min(Ratio(1, lo), Ratio(1, hi)) >= math.min(Ratio(0, lo), Ratio(0, hi))\n",
       "\treturn math.min(Ratio(1, lo), Ratio(1, hi)) < math.min(Ratio(0, lo), Ratio(0, hi))\n",
       "the card thinks a dark panel is light",
       expect="hairline",
       script="runscenarios.py")

mutate(SLATE,
       "local SLATE_TOP, SLATE_BOTTOM, SLATE_ALPHA = { 0.088, 0.098, 0.122 }, { 0.058, 0.066, 0.086 }, 0.93\n",
       "local SLATE_TOP, SLATE_BOTTOM, SLATE_ALPHA = { 0.55, 0.58, 0.62 }, { 0.50, 0.52, 0.56 }, 0.93\n",
       "a pale slate",
       expect="the card's slate is not dark",
       script="runscenarios.py")

mutate(SLATE,
       "\treturn kit.Legible(sr, sg, sb, 4.5)\nend\n",
       "\treturn sr * 0.45, sg * 0.45, sb * 0.45\nend\n",
       "the reason line is not held to its contrast",
       expect="the reason line is",
       script="runscenarios.py")

mutate(SLATE,
       "\tlocal shadowA = (ta < 0.2) and 0 or 0.62 * self.shadowK\n",
       "\tlocal shadowA = 0.62 * self.shadowK\n",
       "a nearly clear card keeps its shadow",
       expect="a nearly clear card keeps its shadow",
       script="runscenarios.py")

mutate(SLATE,
       "\tg.to = on and 1 or RIM_REST\n",
       "\tg.to = on and 1 or 1\n",
       "the highlight never settles back after the cursor",
       expect="the highlight did not settle back",
       script="runscenarios.py")

# --- the art -----------------------------------------------------------------------------------------------

mutate(SLATE,
       "local ART = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Slate\\\\Slate_\"\n",
       "local ART = \"Interface\\\\AddOns\\\\Manners\\\\Textures\\\\Slate\\\\Slat_\"\n",
       "the look draws files that do not exist",
       expect="a texture of Slate's is from",
       script="runscenarios.py")

mutate(SLATE,
       "\tself.glow:SetAlpha(0)\n\tself.flash:SetAlpha(0)\n\tself.plate = tex",
       "\tself.glow:SetAlpha(0)\n\tself.glow:SetBlendMode(\"ADD\")\n\tself.flash:SetAlpha(0)\n\tself.plate = tex",
       "the light behind the icon is additive",
       expect="a texture of Slate's is additive",
       script="runscenarios.py")

mutate(GEN,
       "ICON_RADIUS = 0.26\n",
       "ICON_RADIUS = 0.30\n",
       "the art redrawn without the generator",
       expect="does not match the file that ships",
       script="runscenarios.py")

mutate(GEN,
       "        return a * sstep(0.0, 8.0, edge)\n    make(\"Slate_Shadow\"",
       "        return a\n    make(\"Slate_Shadow\"",
       "the shadow cut off hard at the file's edge",
       expect="does not match the file that ships",
       script="runscenarios.py")

mutate(GEN,
       "    make(\"Slate_Dot\"",
       "    make(\"Slate_Dott\"",
       "a file the look draws is not drawn",
       expect="Slate_Dot is not drawn by the generator",
       script="runscenarios.py")

# --- the per-look loops in the shared checks ---------------------------------------------------------------

mutate(SLATE,
       "\tself.arrive = { anim(pop), anim(slide), anim(Flash(self.flash, 1, 0.09, 0.36)) }\n",
       "\tself.arrive = { anim(pop) }\n",
       "an arrival with one effect",
       expect="look-slate: the arrival plays once",
       script="runscenarios.py")

mutate(SLATE,
       "\t\tif icon or i ~= 2 then\n",
       "\t\tif i ~= 2 then\n",
       "a landed buff never bounces the icon",
       expect="did not fill the line, bounce the icon",
       script="runscenarios.py")
