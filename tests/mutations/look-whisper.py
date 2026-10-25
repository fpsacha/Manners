# Mutations for the Whisper look: tests/scenarios/look-whisper.lua, and the
# per-look loops of looks.lua and hunt37-effects.lua that name it.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make -- a dash that lost the reason, a breath that loops
# on Calm, a line that grows from the wrong end, a shake left at five units, a
# frame of light over the text, a list name anchored to a region -- and names
# the check that has to object.

WHISPER = "Looks/Whisper.lua"
S = "runscenarios.py"

# --- the reason ------------------------------------------------------------

mutate(WHISPER,
       "\tself.dash:SetVertexColor(r, g, b, 1)\n",
       "\tself.dash:SetVertexColor(1, 1, 1, 1)\n",
       "look-whisper: the dash left uncoloured",
       expect="the dash is not in", script=S)

mutate(WHISPER,
       "\t\tself.ring:SetVertexColor(r, g, b, 0.9)\n",
       "\t\tself.ring:SetVertexColor(0.5, 0.5, 0.5, 0.9)\n",
       "look-whisper: the icon's frame never takes the reason",
       expect="the icon's frame is not in", script=S)

mutate(WHISPER,
       "\tself.dash:SetShown(self.ruleOn and mode ~= \"off\" and true or false)\n",
       "\tself.dash:SetShown(self.ruleOn and true or false)\n",
       "look-whisper: the dash stays with the marker off",
       expect="with the marker off the dash is still drawn", script=S)

mutate(WHISPER,
       "\t\tself.track:SetVertexColor(r, g, b, 0.30)\n",
       "\t\tself.track:SetVertexColor(1, 1, 1, 0.30)\n",
       "look-whisper: \"both\" does not light the hairline",
       expect="the hairline does not carry the reason", script=S)

mutate(WHISPER,
       "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, mode ~= \"off\"\n",
       "\treturn true, true\n",
       "look-whisper: the options page is told the marker is always on",
       expect="AccentCarriers says", script=S)

mutate(WHISPER,
       "\tif kit.ink.light then sr, sg, sb = self:OverSnow(sr, sg, sb) end\n",
       "",
       "look-whisper: the reason line is not held to the veil over snow",
       expect="the reason line for", script=S)

mutate(WHISPER,
       "kit.ink.rowReason = kit.ink.light and \"|cffc4c6d2\" or \"|cff585860\"",
       "kit.ink.rowReason = kit.ink.light and \"|cff707078\" or \"|cff585860\"",
       "look-whisper: the words after a list name are dim grey on the veil",
       expect="the words after a list row's name", script=S)

mutate(WHISPER,
       "local VEIL_K = 0.80\n",
       "local VEIL_K = 0.40\n",
       "look-whisper: the veil is too faint to read on",
       expect="the veil is only", script=S)

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

# --- the outcomes ----------------------------------------------------------

mutate(WHISPER,
       "\tfailed = { 1.00, 0.50, 0.30 },\n",
       "\tfailed = { 0.55, 0.55, 0.60 },\n",
       "look-whisper: a refusal is not red-amber",
       expect="a refusal's dash is not red-amber", script=S)

mutate(WHISPER,
       "\tcast = { 0.52, 0.90, 0.52 },\n",
       "\tcast = { 0.90, 0.52, 0.52 },\n",
       "look-whisper: a landed buff is not green",
       expect="a landed buff's dash is not green", script=S)

# --- motion ----------------------------------------------------------------

mutate(WHISPER,
       "\t\t\tif not self.breathAnim:IsPlaying() then self.breathAnim:Play() end\n",
       "",
       "look-whisper: the owed breath never plays",
       expect="the marks do not breathe", script=S)

mutate(WHISPER,
       "\t\tif full then\n\t\t\tif not self.breathAnim:IsPlaying()",
       "\t\tif true then\n\t\t\tif not self.breathAnim:IsPlaying()",
       "look-whisper: the breath loops on Calm",
       expect="animation(s) loop on Calm", script=S)

mutate(WHISPER,
       "function Whisper:StopAttention()\n\tself.breathAnim:Stop()\n",
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
       "\tif isNew and not self.combat then\n\t\tself.warnAnim:Stop()",
       "\tif not self.combat then\n\t\tself.warnAnim:Stop()",
       "look-whisper: the marks come up again on every repaint",
       expect="came up again", script=S)

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
       "\tif full then\n\t\tself.drawAnim:Play()\n",
       "\tif true then\n\t\tself.drawAnim:Play()\n",
       "look-whisper: the line is drawn from its end on Calm",
       expect="on Calm the line was drawn from its end", script=S)

mutate(WHISPER,
       "\t\tself.flareAnim:Stop()\n\t\tself.warnAnim:Stop()\n\t\tself.warnAnim:Play()\n",
       "\t\tself.flareAnim:Stop()\n\t\tself.warnAnim:Stop()\n\t\tself.warnAnim:Play()\n"
       "\t\tself:Draw(true, 1, 0.4, 0.3)\n",
       "look-whisper: a refusal draws the line",
       expect="a refusal drew the line", script=S)

mutate(WHISPER,
       "\t\tself.flareAnim:Stop()\n\t\tself.warnAnim:Stop()\n\t\tself.warnAnim:Play()\n",
       "\t\tself.flareAnim:Stop()\n\t\tself.warnAnim:Stop()\n",
       "look-whisper: a refusal does not dip the dash",
       expect="a refusal did not dip the dash", script=S)

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
       "\tlocal anim = self.hoverAnim\n\tlocal from = self.hoverFrame:GetAlpha()\n\tanim:Stop()\n\tanim.to = on and 1 or 0\n\tanim.fade:SetFromAlpha(from)\n\tanim.fade:SetToAlpha(anim.to)\n\tanim.fade:SetDuration(on and 0.12 or 0.18)\n\tanim:Play()\n",
       "\tlocal anim = self.hoverAnim\n\tlocal from = self.hoverFrame:GetAlpha()\n\tanim:Stop()\n\tanim.to = on and 1 or 0\n\tanim.fade:SetFromAlpha(from)\n\tanim.fade:SetToAlpha(anim.to)\n\tanim.fade:SetDuration(on and 0.12 or 0.18)\n",
       "look-whisper: the cursor does not light the hairline",
       expect="did not light the hairline", script=S)

# --- the fight --------------------------------------------------------------

mutate(WHISPER,
       "\t\tself.breathAnim:Stop()\n\t\tself.breathFrame:SetAlpha(1)\n\telse\n",
       "\t\tself.breathAnim:Stop()\n\t\tself.breathFrame:SetAlpha(0.4)\n\telse\n",
       "look-whisper: the dash is dimmed in a fight",
       expect="the dash is dimmed in a fight", script=S)

mutate(WHISPER,
       "local INK_COMBAT, TEXT_COMBAT = 0.62, 0.82\n",
       "local INK_COMBAT, TEXT_COMBAT = 1, 0.82\n",
       "look-whisper: the icon is not dimmed in a fight",
       expect="the icon is not dimmed in a fight", script=S)

# --- laying out ------------------------------------------------------------

mutate(WHISPER,
       "math.min(p.iconSize, math.floor((H - 2) / 1.2))",
       "math.min(p.iconSize, H - 10)",
       "look-whisper: the icon's frame is not held inside the panel",
       expect="the icon's frame leaves the panel", script=S)

mutate(WHISPER,
       "\t\truleY = H / 2 - (top + nameH + gap / 2)\n",
       "\t\truleY = nameY\n",
       "look-whisper: the hairline sits on the reason line",
       expect="is not between the lines", script=S)

mutate(WHISPER,
       "right = math.min(math.max(right, PAD), math.max(0, self.W - self.textX - 20))",
       "right = math.min(math.max(right, 0), math.max(0, self.W - self.textX - 20))\n\tright = 0",
       "look-whisper: the name runs under the count",
       expect="the count overlaps the name", script=S)

mutate(WHISPER,
       "\t\t\tif width * least / size > self.W - self.textX - fit.chipRoom - 0.5 then on = false end\n",
       "",
       "look-whisper: the count is up over a name it cuts",
       expect="the count is up over the long name", script=S)

mutate(WHISPER,
       "function Whisper.TwoLineHeight(fontSize)\n\treturn math.max(ns.TwoLineHeight(fontSize, \"glass\"), BlockHeight(fontSize, true))\n",
       "function Whisper.TwoLineHeight(fontSize)\n\treturn BlockHeight(fontSize)\n",
       "look-whisper: a profile with two lines on glass loses one",
       expect="where glass has two lines, Whisper has one", script=S)

# --- under the text, the list, leaving ------------------------------------

mutate(WHISPER,
       "\tself.breathFrame:SetFrameLevel(base + 2)\n",
       "\tself.breathFrame:SetFrameLevel(base + 20)\n",
       "look-whisper: a frame of its motion is over the text",
       expect="not under the text's", script=S)

mutate("tests/scenarios/hunt37-effects.lua",
       "local ALL = { \"glass\", \"framed\", \"minimal\", \"luxe\", \"toast\", \"arcane\", \"whisper\", \"heritage\" }",
       "local ALL = { \"glass\", \"framed\", \"minimal\", \"luxe\", \"toast\", \"arcane\", \"heritage\" }",
       "look-whisper: hunt37's per-look loops forget it",
       expect="per-look loops do not name Whisper", script=S)

mutate(WHISPER,
       "\t\tfs:SetPoint(\"LEFT\", art, edge, self.textX, y)\n",
       "\t\tfs:SetPoint(\"LEFT\", self.trayBox, edge, self.textX, y)\n",
       "look-whisper: a list name hangs from a frame that is not the panel's",
       expect="and cannot be clicked", script=S)

mutate(WHISPER,
       "\t\tdot:SetVertexColor(c[1], c[2], c[3], 0.95)\n",
       "\t\tdot:SetVertexColor(0.6, 0.6, 0.6, 0.95)\n",
       "look-whisper: a list dot is grey",
       expect="dot is grey", script=S)

mutate(WHISPER,
       "\tlocal placed = self.trayHeight == height and self.trayAt == above\n",
       "\tlocal placed = false\n",
       "look-whisper: every repaint lays the list out again",
       expect="re-anchored", script=S)

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
       "\tfor _, x in ipairs(self.own) do x:Hide() end\n\tfor _, anim in ipairs({ self.breathAnim,",
       "\tfor _, anim in ipairs({ self.breathAnim,",
       "look-whisper: its regions are left showing when the look is left",
       expect="still shows under", script=S)

# --- the name, the toc, the art -------------------------------------------

mutate(WHISPER,
       "\tname = L[\"Whisper -- no box, one hairline in the reason colour\"],\n",
       "\tname = L[\"Whisper -- no box, one thin line in the reason colour\"],\n",
       "look-whisper: its name has no translation",
       expect="its name is translated", script=S)

mutate("Manners.toc",
       "Looks\\Whisper.lua\n",
       "",
       "look-whisper: its file is not in the toc",
       expect="no look registered as whisper", script=S)

mutate("tools/make_whisper_textures.py",
       "    save(\"Whisper_Veil\", a * smooth(rim / 5.0))\n",
       "    save(\"Whisper_Veil\", a * smooth(rim / 5.0) * (1 - 0.01 * np.random.rand(n, n)))\n",
       "look-whisper: the generator is not deterministic",
       expect="differs between two runs", script=S)

mutate("tools/make_whisper_textures.py",
       "RING_GAP, RING_WIDTH, ICON_RADIUS = 2.0, 1.0, 0.20 * RING_ICON\n",
       "RING_GAP, RING_WIDTH, ICON_RADIUS = 2.0, 1.6, 0.20 * RING_ICON\n",
       "look-whisper: the generator draws a different frame from the one that ships",
       expect="does not match the file that ships", script=S)

mutate("tools/make_whisper_textures.py",
       "    w, h = 128, 2\n",
       "    w, h = 120, 2\n",
       "look-whisper: a texture that is not a power of two",
       expect="not a power of two", script=S)
