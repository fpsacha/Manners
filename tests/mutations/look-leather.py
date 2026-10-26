# Mutations for the Leather look: tests/scenarios/look-leather.lua, with the
# ring's reach judged by hunt37-effects.lua and the switching checks by
# looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

LEATHER = "Looks/Leather.lua"
GENERATOR = "tools/make_leather_textures.py"
S = "runscenarios.py"

# The scenarios the mutations below are judged by, by name: a mutation is traced to the scenarios
# whose names it quotes, so each names the scenario that has to go red.
S_REG = 'look-leather: it is registered, listed and loaded after the other looks'
S_GONE = 'look-leather: the look it replaced is gone and a saved style of it falls back'
S_TRANS = 'look-leather: its name is translated into all eight languages'
S_ART = 'look-leather: it draws only art of its own, all of it ships and every file is drawn'
S_STATE = 'look-leather: every state paints without an error on '
S_LAYOUT = 'look-leather: nothing overlaps or leaves the prompt, at every size, '
S_KEY = 'look-leather: the bound key and the count sit left of the eyelet and the name keeps its room'
S_OPAQUE = "look-leather: the leather is opaque at rest, whatever the panel's opacity says"
S_REASON = 'look-leather: the reason is carried by the thread and the enamel, in both palettes'
S_OUTCOME = "look-leather: the outcome keeps the name and writes the verdict, in the verdict's colour"
S_TEXT = 'look-leather: the text reads on the leather'
S_FACE = "look-leather: the name's face on a "
S_LEAVEFACE = "look-leather: leaving the look leaves the name's face to the next look"
S_LIST = 'look-leather: the list hangs from the same ring, its names secure buttons on frames'
S_ICON = 'look-leather: the icon is set in square or round, and the sweep follows it'
S_ARRIVE = 'look-leather: a favour arriving swings the tag in once, for somebody owed'
S_SWING = 'look-leather: the swing sums to nothing and the eyelet is held still by the opposite movement'
S_LAND = 'look-leather: a landed buff lights the thread piece by piece and a refusal flashes it red and amber'
S_CALM = 'look-leather: Calm is fades only: nothing moves, nothing loops'
S_OWED = 'look-leather: owed glows three times and rests, and stops with the favour'
S_TIME = 'look-leather: the effects stay inside their time and their room under the text'
S_FIGHTQ = 'look-leather: in a fight no effect touches a protected frame, and none plays when quiet'
S_STOP = 'look-leather: every effect stops on a repaint and on a restyle, and parks what it lit'
S_FIGHT = 'look-leather: a fight greys the leather and keeps the reason'
S_LEAVE = 'look-leather: leaving it gives the lines, the icon and the sweep back'
S_CURSOR = 'look-leather: the cursor lights the brass, and unlocked it can still be dragged'
S_SHIP = 'look-leather: its art is 32-bit, a power of two, and every file is named and shipped'
S_GEN = 'look-leather: tools/make_leather_textures.py is deterministic and draws what ships'


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only look-leather finds them
    all, the ones that edit the toc, a locale and the shared files included."""
    kw.setdefault("script", S)
    mutate(file, old, new, "look-leather: " + label, **kw)


# --- registration, the toc, the translations, the look it replaced ---------

_m(LEATHER,
   "\torder = 6,\n",
   "\torder = 7,\n",
   "its place in the dropdown moved",
   expect=S_REG)

_m(LEATHER,
   "\tname = L[\"Leather -- a stitched leather tag with a brass ring\"],\n",
   "\tname = L[\"Leather\"],\n",
   "the dropdown's label is only the name",
   expect=S_REG)

_m("Manners.toc",
   "Looks\\Leather.lua\n",
   "",
   "the toc does not load the look",
   expect=S_REG)

_m("Locales/deDE.lua",
   "L[\"Leather\"] = \"Leder\"\n",
   "L[\"Leather\"] = \"Leather\"\n",
   "a title left in English in German",
   expect=S_TRANS)

_m("Locales/zhTW.lua",
   "L[\"a stitched leather tag with a brass ring\"] = \"附黃銅環的縫線皮革吊牌\"\n",
   "",
   "a card's line missing in Traditional Chinese",
   expect=S_TRANS)

_m("Looks/Looks.lua",
   "\tfor key in pairs(Looks.list) do out[key] = true end\n",
   "\tsetmetatable(out, { __index = function() return true end })\n",
   "any saved style allowed, a look that was removed included",
   expect=S_GONE)

# --- the art ---------------------------------------------------------------

_m(LEATHER,
   "self.iconRim:SetTexture(ART .. (round and \"IconRimRd\" or \"IconRim\"))",
   "self.iconRim:SetTexture(ART .. \"IconRim\")",
   "a round icon set in the square rim",
   expect=S_ICON)

_m(LEATHER,
   "\tself.sheen = tex(art, \"BACKGROUND\", -5, \"Sheen\")\n",
   "\tself.sheen = tex(art, \"BACKGROUND\", -5, \"Sheen\")\n"
   "\tself.sheen:SetTexture(\"Interface\\\\Buttons\\\\WHITE8X8\")\n",
   "a texture of the client's drawn",
   expect=S_ART)

_m(LEATHER,
   "\t\tlocal c = kit.ReasonColor(rows[i] and rows[i].reason)\n",
   "\t\tlocal c = nil\n",
   "the list painted with no colour for a row",
   expect=S_STATE)

# --- the layout ------------------------------------------------------------

_m(LEATHER,
   "\tBox(s[3], rel, x1 - capR, y0, x1, y1)\n",
   "\tBox(s[3], rel, x1 - capR, y0, x1 - 2, y1)\n",
   "the leather's right end short of the prompt's edge",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tlocal topY, bottomY = INSET * su, self.H - INSET * su\n",
   "\tlocal topY, bottomY = -INSET * su, self.H - INSET * su\n",
   "the thread's top line outside the prompt",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tlocal ringX = W - EYE_AT * H\n",
   "\tlocal ringX = W - 0.9 * H\n",
   "the eyelet out of the right end",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tself.ringInset = math.ceil(W - self.ringLeft + 3)\n",
   "\tself.ringInset = 6\n",
   "the lines run to the edge, over the eyelet",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tself.iconFrame:SetSize(math.max(1, S), math.max(1, S))\n",
   "\tself.iconFrame:SetSize(math.max(1, S + 4), math.max(1, S + 4))\n",
   "the icon's setting larger than the icon",
   expect=S_LAYOUT)

_m(LEATHER,
   "\t\ttextX = iconX + S + 6\n",
   "\t\ttextX = iconX + 4\n",
   "the name starts over the icon",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tlocal S = showIcon and Clamp(p.iconSize, 12, math.max(12, H - 2 * (edge + 2))) or 0\n",
   "\tlocal S = showIcon and Clamp(p.iconSize, 12, 200) or 0\n",
   "the icon taller than the leather inside the thread",
   expect=S_LAYOUT)

_m(LEATHER,
   "\tself.chipRight = math.ceil(self.ringInset)\n",
   "\tself.chipRight = 2\n",
   "the key's patch over the eyelet",
   expect=S_KEY)

_m(LEATHER,
   "\tif self.countMode == \"pair\" then inset = math.max(inset, self:PairRoom()) end\n",
   "",
   "the name runs under the count beside the key",
   expect=S_KEY)

_m(LEATHER,
   "\t\t\t\tkit.fit.chipRoom = room\n",
   "",
   "a three-digit count wider than the room the name left it",
   expect=S_KEY)

_m(LEATHER,
   "\t\tlocal h = self.chipH\n\t\tlocal w = math.floor(self.countW + 0.5)\n",
   "\t\tlocal h = self.chipH\n\t\tlocal w = self.chipW2\n",
   "the count's patch too narrow for its words",
   expect=S_KEY)

# --- opaque leather --------------------------------------------------------

_m(LEATHER,
   "\tcombatArtAlpha = 1,\n",
   "\tcombatArtAlpha = 0.55,\n",
   "the whole tag dimmed in a fight, leather and all",
   expect=S_FIGHT)

_m(LEATHER,
   "\t\tgrad(t, \"HORIZONTAL\", dye[1] * ka, dye[2] * ka, dye[3] * ka, 1, dye[1] * kb, dye[2] * kb, dye[3] * kb, 1)\n",
   "\t\tgrad(t, \"HORIZONTAL\", dye[1] * ka, dye[2] * ka, dye[3] * ka, 0.9, dye[1] * kb, dye[2] * kb, dye[3] * kb, 0.9)\n",
   "the leather a tenth see-through",
   expect=S_OPAQUE)

_m(LEATHER,
   "\t\ts[i] = keep(t)\n",
   "\t\tt:SetBlendMode(\"ADD\")\n\t\ts[i] = keep(t)\n",
   "the leather drawn additive",
   expect=S_OPAQUE)

_m(LEATHER,
   "\t\tself.dye = { 1, 1, 1 }\n\t\treturn\n",
   "\t\tself.dye = { 0.8, 0.9, 1 }\n\t\treturn\n",
   "the untouched leather tinted",
   expect=S_OPAQUE)

# --- the reason ------------------------------------------------------------

_m(LEATHER,
   "\tlocal rim = out or mode == \"icon\" or mode == \"both\"\n",
   "\tlocal rim = out or mode == \"both\"\n",
   "the icon's thread not dyed on the icon marker",
   expect=S_REASON)

_m(LEATHER,
   "\tlocal stripe = out or mode == \"stripe\" or mode == \"both\"\n",
   "\tlocal stripe = out\n",
   "the tag's thread not dyed on the stripe marker",
   expect=S_REASON)

_m(LEATHER,
   "\tlocal enamel = out or mode ~= \"off\"\n",
   "\tlocal enamel = true\n",
   "an enamel in the eyelet with the marker off",
   expect=S_REASON)

_m(LEATHER,
   "\tlocal tr, tg, tb = Bright(tint, a[1], a[2], a[3], 0.34)\n",
   "\tlocal tr, tg, tb = a[1], a[2], a[3]\n",
   "the thread left as dark as the reason's colour",
   expect=S_REASON)

_m(LEATHER,
   "\tlocal er, eg, eb = Bright(tint, a[1], a[2], a[3], 0.22)\n",
   "\tlocal er, eg, eb = a[1], a[2], a[3]\n",
   "the enamel left as dark as the reason's colour",
   expect=S_REASON)

_m(LEATHER,
   "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, mode ~= \"off\"\n",
   "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false, true\n",
   "the options page told the marker off carries something",
   expect=S_REASON)

_m(LEATHER,
   "\tself.accent = { o[1], o[2], o[3], mode = self.p.accentMode or \"icon\", outcome = true }\n",
   "\tself.accent = { o[1], o[2], o[3], mode = self.p.accentMode or \"icon\", outcome = false }\n",
   "the verdict's colour not on the thread",
   expect=S_OUTCOME)

_m(LEATHER,
   "\tinkOnDark = true,\n",
   "\tinkOnDark = false,\n",
   "the name's colour codes taken dark for a light panel",
   expect=S_TEXT)

_m("Prompt/Text.lua",
   "if not ink.light and look and (look.inkOnDark or (fs == R.subText and look.subOnDark)) then",
   "if not ink.light and look and (fs == R.subText and look.subOnDark) then",
   "the shared line setter ignores a look's own dark ground for the name",
   expect=S_TEXT)

_m(LEATHER,
   "\tif chosen and Luminance(p.fontColor[1] or 1, p.fontColor[2] or 1, p.fontColor[3] or 1) < 0.18 then\n\t\tchosen = false\n\tend\n",
   "",
   "a text colour too dark for brown taken as chosen",
   expect=S_TEXT)

_m(LEATHER,
   "local NAME_INK = { 1.00, 0.95, 0.84 }\n",
   "local NAME_INK = { 0.55, 0.40, 0.25 }\n",
   "the name inked in a tan too dark for the leather",
   expect=S_TEXT)

_m(LEATHER,
   "\tclassSoften = 0.70,\n",
   "\tclassSoften = 0.20,\n",
   "class colours left dark on brown",
   expect=S_TEXT)

# --- the fonts -------------------------------------------------------------

_m(LEATHER,
   "local NAME_FACE = \"Fonts\\\\MORPHEUS.TTF\"\n",
   "local NAME_FACE = \"Fonts\\\\SKURRI.TTF\"\n",
   "the name in another face",
   expect=S_FACE)

_m(LEATHER,
   "\tptBR = true }\n",
   "\tptBR = true, koKR = true }\n",
   "a Latin-only face named for a Korean client",
   expect=S_FACE)

_m(LEATHER,
   "\tif type(p.font) == \"string\" and p.font ~= d then return nil end\n",
   "",
   "the player's chosen font overruled",
   expect=S_FACE)

_m(LEATHER,
   "\t\tfit.paths[kit.name] = face\n",
   "",
   "a shrinking name leaves its face",
   expect=S_FACE)

_m("Prompt/Text.lua",
   "\tfit.path, fit.flags, fit.paths = fontPath, outline, {}\n",
   "\tfit.path, fit.flags = fontPath, outline\n",
   "the next look inherits the name's face",
   expect=S_FACE)

# --- the list --------------------------------------------------------------

_m(LEATHER,
   "\t\ttag.eyelet:SetPoint(\"CENTER\", art, \"TOPLEFT\", self.ringX, -(top + h / 2))\n",
   "\t\ttag.eyelet:SetPoint(\"CENTER\", art, \"TOPLEFT\", self.ringX - 6, -(top + h / 2))\n",
   "the list's eyelets off the main tag's column",
   expect=S_LIST)

_m(LEATHER,
   "\tlocal right = self.ringX + 0.38 * h\n",
   "\tlocal right = self.ringX + 0.38 * h + 60\n",
   "the list's tags wider than the prompt",
   expect=S_LIST)

_m(LEATHER,
   "\t\tlocal width = math.max(20, eyeLeft - 3 - x)\n",
   "\t\tlocal width = math.max(20, W - x)\n",
   "a row's text runs over its eyelet",
   expect=S_LIST)

_m(LEATHER,
   "\t\tself.tags[i].dot:SetVertexColor(r, g, b, 1)\n",
   "\t\tself.tags[i].dot:SetVertexColor(1, 1, 1, 1)\n",
   "a row's enamel not in its reason's colour",
   expect=S_LIST)

_m(LEATHER,
   "\t\tif not (list and i <= shown) then\n",
   "\t\tif false then\n",
   "the list's tags stay with the list off",
   expect=S_LIST)

# --- the icon --------------------------------------------------------------

_m(LEATHER,
   "\tlocal maskFile = ART .. (round and \"IconMaskRd\" or \"IconMask\")\n",
   "\tlocal maskFile = ART .. \"IconMask\"\n",
   "a round icon cut square",
   expect=S_ICON)

_m(LEATHER,
   "\t\t\tif cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end\n",
   "\t\t\tif cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end\n",
   "the sweep's edge square on a round icon",
   expect=S_ICON)

_m(LEATHER,
   "\t\tself.fx:Shape(round, ART .. \"FxRing\", ART .. \"FxRingSq\")\n",
   "\t\tself.fx:Shape(round, ART .. \"FxRingSq\", ART .. \"FxRing\")\n",
   "the rings in the wrong shape",
   expect=S_ICON)

# --- the motion ------------------------------------------------------------

_m(LEATHER,
   "\t\tif not self.outcomeOn then\n\t\t\tif full then\n",
   "\t\tif true then\n\t\t\tif full then\n",
   "an arrival played over an outcome",
   expect=S_ARRIVE)

_m(LEATHER,
   "\tif isNew then\n\t\tself.glowSpent = nil\n",
   "\tif true then\n\t\tself.glowSpent = nil\n",
   "the arrival played on every repaint",
   expect=S_ARRIVE)

_m(LEATHER,
   "\t{ 0, 4, 0.10, \"IN_OUT\" }, { 0, -1, 0.08, \"IN_OUT\" },\n",
   "\t{ 0, 4, 0.10, \"IN_OUT\" }, { 0, -3, 0.08, \"IN_OUT\" },\n",
   "a swing that ends displaced",
   expect=S_SWING)

_m(LEATHER,
   "\tfor _, f in ipairs({ self.ringFrame, self.ringGlowFrame, self.starFrame }) do into(Swing(f, SWING, -1)) end\n",
   "\tfor _, f in ipairs({ self.ringFrame, self.ringGlowFrame, self.starFrame }) do into(Swing(f, SWING, 1)) end\n",
   "the eyelet swings with the tag",
   expect=S_SWING)

_m(LEATHER,
   "\tself.swing = Swing(art, SWING, 1)\n",
   "\tself.swing = Swing(self.kit.button, SWING, 1)\n",
   "the swing on the secure button",
   expect=S_SWING)

_m(LEATHER,
   "\t\tAlpha(g, 0, 1, 0.05, 1, \"OUT\", (i - 1) * 0.022)\n",
   "\t\tAlpha(g, 0, 1, 0.05, 1, \"OUT\", 0)\n",
   "the thread lit all at once for a landing",
   expect=S_LAND)

_m(LEATHER,
   "\t\tAlpha(g, 0, 1, 0.05, 1, \"OUT\", (i - 1) * 0.022)\n",
   "\t\tAlpha(g, 0, 1, 0.05, 1, \"OUT\", (i - 1) * 0.08)\n",
   "a landing that takes over a second",
   expect=S_TIME)

_m(LEATHER,
   "\tself:LightThread(self.kit.Tint(o[1], o[2], o[3], 0.45))\n",
   "\tself:LightThread(1, 0.3, 0.3)\n",
   "the lit thread not green",
   expect=S_LAND)

_m(LEATHER,
   "\t\t\tlocal c = GHOSTS[(i % 2) + 1]\n",
   "\t\t\tlocal c = GHOSTS[1]\n",
   "a refusal that flashes red only",
   expect=S_LAND)

_m(LEATHER,
   "\t{ 1, -3, 0.04 }, { -2, 5, 0.04 }, { 2, -4, 0.04 }, { -1, 3, 0.04 }, { 1, -2, 0.04 }, { -1, 1, 0.04 },\n",
   "\t{ 1, -3, 0.04 }, { -2, 5, 0.04 }, { 2, -4, 0.04 }, { -1, 3, 0.04 }, { 1, -2, 0.04 }, { -1, 3, 0.04 },\n",
   "a jerk that ends displaced",
   expect=S_SWING)

_m(LEATHER,
   "\tif kind ~= \"cast\" then return end\n",
   "",
   "a cast nobody confirmed lit the thread as a landing",
   expect=S_LAND)

_m(LEATHER,
   "\t\t\tif full then\n\t\t\t\tPlayAll(self.arrive)\n\t\t\telse\n",
   "\t\t\tif true then\n\t\t\t\tPlayAll(self.arrive)\n\t\t\telse\n",
   "the tag swings in on Calm",
   expect=S_CALM)

_m(LEATHER,
   "\tAlpha(soft, 0, 0.8, 0.18, 1, \"OUT\")\n",
   "\tAlpha(soft, 0, 0.8, 0.18, 1, \"OUT\")\n\tSlide(soft, 3, 0, 0.18, 1)\n",
   "Calm's glow slides as well as fades",
   expect=S_CALM)

_m(LEATHER,
   "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n",
   "\t\tC_Timer.After(BREATHS * BREATH * 2000, function()\n",
   "the owed glow never rests",
   expect=S_OWED)

_m(LEATHER,
   "local BREATHS, BREATH = 3, 1.25\n",
   "local BREATHS, BREATH = 3, 2.5\n",
   "a glow five seconds round",
   expect=S_OWED)

_m(LEATHER,
   "\tself:HoldPulse()\n\tself.accent = { o[1]",
   "\tself.accent = { o[1]",
   "the owed glow goes on over an outcome",
   expect=S_OWED)

_m(LEATHER,
   "\tfor _, g in ipairs(self.pulse) do g:Stop() end\n\tself.glowFrame:SetAlpha(0)\n\tself.ringGlowFrame:SetAlpha(0)\n\tself.soft:Stop()\n",
   "\tself.glowFrame:SetAlpha(0)\n\tself.ringGlowFrame:SetAlpha(0)\n\tself.soft:Stop()\n",
   "the glow loops on with nobody owed",
   expect=S_OWED)

_m(LEATHER,
   "\tfor _, g in ipairs(self.landing) do g:Stop() end\n\tfor _, g in ipairs(self.refusal) do g:Stop() end\n",
   "\tfor _, g in ipairs(self.refusal) do g:Stop() end\n",
   "a landing's light left running by a repaint",
   expect=S_STOP)

_m(LEATHER,
   "\t\tf:SetFrameLevel(level + 2)\n\tend\n\tself.chipFrame:SetFrameLevel(level + 3)\n",
   "\t\tf:SetFrameLevel(level + 9)\n\tend\n\tself.chipFrame:SetFrameLevel(level + 3)\n",
   "the lights over the text",
   expect=S_TIME)

_m(LEATHER,
   "\tself.bandMove:SetOffset(math.max(8, W - capR - capL - bandW), 0)\n",
   "\tself.bandMove:SetOffset(W, 0)\n",
   "the band of light runs out over the right end",
   expect=S_TIME)

_m(LEATHER,
   "local FX_PEAK, FX_EDGE = 0.70, 0.88\n",
   "local FX_PEAK, FX_EDGE = 0.70, 0.99\n",
   "the ring held to more room than its art needs",
   expect="each ring's declared reach is the reach of its art",
   script="runscenarios.py")

# --- the fight -------------------------------------------------------------

_m(LEATHER,
   "\tGrey(self.body, on)\n",
   "\tGrey(self.body, false)\n",
   "the leather keeps its colour in a fight",
   expect=S_FIGHT)

_m(LEATHER,
   "local TEXT_COMBAT, LEATHER_COMBAT, ICON_COMBAT = 0.78, 0.62, 0.70\n",
   "local TEXT_COMBAT, LEATHER_COMBAT, ICON_COMBAT = 1, 0.62, 0.70\n",
   "the name not dimmed in a fight",
   expect=S_FIGHT)

_m(LEATHER,
   "local TEXT_COMBAT, LEATHER_COMBAT, ICON_COMBAT = 0.78, 0.62, 0.70\n",
   "local TEXT_COMBAT, LEATHER_COMBAT, ICON_COMBAT = 0.78, 1, 0.70\n",
   "the leather no darker in a fight",
   expect=S_FIGHT)

_m(LEATHER,
   "\tif self.combat == on then return end\n\tself.combat = on\n",
   "\tif self.combat == on then return end\n\tself.combat = on or self.combat\n",
   "the fight never lets go of the leather",
   expect=S_FIGHT)

_m(LEATHER,
   "\t\tself:StopAttention()\n\t\tself:StopFlourishes()\n\tend\n\tself:Tone()\n",
   "\tend\n\tself:Tone()\n",
   "the glow keeps going into a fight",
   expect=S_FIGHT)

# --- leaving the look, the cursor ------------------------------------------

_m(LEATHER,
   "\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n\tend\n",
   "",
   "the icon still cut by Leather's mask on the next look",
   expect=S_LEAVE)

_m(LEATHER,
   "\tkit.count:Show()\n\tkit.sub:SetShadowOffset(1, -1)\n",
   "\tkit.sub:SetShadowOffset(1, -1)\n",
   "the count left hidden for the next look",
   expect=S_LEAVE, script="runscenarios.py")

_m(LEATHER,
   "\tg.to = on and 0.5 or 0\n",
   "\tg.to = 0.5\n",
   "the brass stays lit when the cursor leaves",
   expect=S_CURSOR)

_m(LEATHER,
   "\tg.fade:SetDuration(on and 0.12 or 0.18)\n\tg:Play()\n",
   "\tg.fade:SetDuration(on and 0.12 or 0.18)\n",
   "the cursor lights nothing",
   expect=S_CURSOR)

# --- the art, its generator and the constants the two share ----------------

_m(LEATHER,
   "local PERIOD, INSET, STRIP = 16, 9, 16\n",
   "local PERIOD, INSET, STRIP = 16, 8, 16\n",
   "the Lua's inset not the art's",
   expect=S_SHIP)

_m(GENERATOR,
   "    rng = np.random.default_rng(seed)\n    g = rng.uniform",
   "    rng = np.random.default_rng()\n    g = rng.uniform",
   "the grain drawn from an unseeded generator",
   expect=S_GEN)

_m(GENERATOR,
   "INSET = 9               # the thread's distance from the edge",
   "INSET = 10              # the thread's distance from the edge",
   "the art drawn again and not shipped",
   expect=S_GEN)

_m(GENERATOR,
   "    make_fx_rings()\n    for name, w, h in written:",
   "    for name, w, h in written:",
   "a file the generator no longer writes",
   expect=S_GEN)
