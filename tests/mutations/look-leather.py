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
S_NOROOM = "look-leather: where the reason has no room the patches stand at the name line's end or aside"
S_WHOLE = 'is not cut at the default size'
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
S_SHADOW = 'look-leather: the tag throws a soft shadow under it, within half its height, under the leather'


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
   "\ttitle = L[\"Hunter\"],\n",
   "\ttitle = L[\"Leather\"],\n",
   "the dropdown's label is only the name",
   expect=S_REG)

_m("Manners.toc",
   "Looks\\Leather.lua\n",
   "",
   "the toc does not load the look",
   expect=S_REG)

_m("Locales/deDE.lua",
   "L[\"Hunter\"] = \"Jäger\"\n",
   "L[\"Hunter\"] = \"Hunter\"\n",
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
   expect=S_NOROOM)

_m(LEATHER,
   "\treturn math.ceil(self.chipRight + (self.countW or self.chipW2) + 4)\n",
   "\treturn math.ceil(self.chipRight + self.chipW2 + 4)\n",
   "a three-digit count wider than the room the line left it",
   expect=S_KEY)

_m(LEATHER,
   "\t\tlocal h = mode == \"sub\" and self.subChipH or self.chipH\n\t\tlocal w = math.floor(self.countW + 0.5)\n",
   "\t\tlocal h = mode == \"sub\" and self.subChipH or self.chipH\n\t\tlocal w = self.chipW2\n",
   "the count's patch too narrow for its words",
   expect=S_KEY)

# The name's room at the default size with a count and a key up: both patches
# stand on the reason's line, so they take the room of the name's line.
_m(LEATHER,
   "\t\t\tif self:SubFits(self.keyRoom) then lane = \"sub\" end\n",
   "",
   "the key's patch back at the name line's end, taking the name's room",
   expect=S_WHOLE)

_m(LEATHER,
   "\t\t\tif self:SubFits(lane == \"sub\" and self:PairRoom() or self:CountRoom()) then\n",
   "\t\t\tif false then\n",
   "the count's patch back at the name line's end, taking the name's room",
   expect=S_WHOLE)

_m(LEATHER,
   "\tif self.keyLane == \"sub\" then subInset = math.max(subInset, self.keyRoom or 0) end\n",
   "",
   "the reason running under the key's patch",
   expect=S_KEY)

_m(LEATHER,
   "\t\tsubInset = math.max(subInset, self.keyLane == \"sub\" and self:PairRoom() or self:CountRoom())\n",
   "",
   "the reason running under the count's patch",
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

mutate("Prompt/Paint.lua",
       "\treturn string.format(\"|c%s%s|r\", c.colorStr, text)\n",
       "\treturn \"|cffffffff\" .. text .. \"|r\"\n",
       "class colours replaced on brown",
       expect="tint: dark looks keep Blizzard class colours", script=S)

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
   "\t\tColour(self.tags[i].dot, r, g, b)\n",
   "\t\tColour(self.tags[i].dot, 1, 1, 1)\n",
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
   "\t\t\tif full then\n\t\t\t\tPlayAll(self.arrive, self:Held())\n\t\t\telse\n",
   "\t\t\tif true then\n\t\t\t\tPlayAll(self.arrive, self:Held())\n\t\t\telse\n",
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
   "\t\tf:SetFrameLevel(level + LEVEL.light)\n\tend\n",
   "\t\tf:SetFrameLevel(level + 9)\n\tend\n",
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

# --- the shadow the tag throws -----------------------------------------------

_m(LEATHER,
   "local SHADOW_SIDE, SHADOW_BEFORE, SHADOW_UP = 16, 48, 64\n",
   "local SHADOW_SIDE, SHADOW_BEFORE, SHADOW_UP = 16, 48, 128\n",
   "the shadow reaching past half the tag's height",
   expect=S_SHADOW)

_m(LEATHER,
   '\tself.shadow = Slices(art, "BACKGROUND", -7, keep, SHADOW_FILES)\n',
   '\tself.shadow = Slices(art, "BACKGROUND", -5, keep, SHADOW_FILES)\n',
   "the shadow drawn over the leather",
   expect=S_SHADOW)

_m(LEATHER,
   '\tfor _, t in ipairs(self.shadow) do Colour(t, 0, 0, 0, SHADOW_ALPHA) end\n',
   '\tfor _, t in ipairs(self.shadow) do Colour(t, 1, 1, 1, SHADOW_ALPHA) end\n',
   "the shadow drawn white",
   expect=S_SHADOW)

_m(LEATHER,
   "\tBox(s[1], rel, x0 - SHADOW_SIDE * su, top, lEnd, bottom)\n",
   "\tBox(s[1], rel, x0, top, lEnd, bottom)\n",
   "the shadow stopping at the tag's left edge",
   expect=S_SHADOW)

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

# --- the trim: studs, the buckle, the feathers -------------------------------

S_TRIM = 'look-leather: the studs, the buckle and the feathers stand where the art says, each within its reach'
S_BRAND = 'look-leather: the brand stands left of the eyelet and of the patches, and gives way to the words'
S_EMBER = 'look-leather: the brand smoulders while somebody is owed, and goes out with the favour and in a fight'
S_REST = ('look-leather: at rest the feathers stir and the thread catches the light, and it stops on Calm, in a fight '
          'and with the look')
S_STRIKE = ('look-leather: a landing strikes the brand and raises smoke, a refusal flashes it red, and the feathers '
            'are flung and settle')

_m(LEATHER,
   "\t\tcentre(t, stud, stud, at[i], (i % 2 == 1) and inset or H - inset)\n",
   "\t\tcentre(t, stud, stud, at[i], H / 2)\n",
   "the studs in the middle of the field, off the stitch",
   expect=S_TRIM)

_m(LEATHER,
   "\tlocal at = { capL, capL, W - capR, W - capR }\n",
   "\tlocal at = { capL, capL, W - capR / 2, W - capR / 2 }\n",
   "the right studs out on the half circle, not where it meets the straight",
   expect=S_TRIM)

_m(LEATHER,
   "\tlocal inset = math.max(INSET * su, stud / 2)\n",
   "\tlocal inset = 0\n",
   "the studs half off the leather's edge",
   expect=S_TRIM)

_m(LEATHER,
   "\tlocal left = W - BUCKLE_TIP * box\n",
   "\tlocal left = W\n",
   "the buckle hanging in the air past the tip",
   expect=S_TRIM)

_m(LEATHER,
   "local BUCKLE, BUCKLE_TIP, BUCKLE_HANG = 0.66, 19 / 64, { 55 / 64, 46 / 64 }\n",
   "local BUCKLE, BUCKLE_TIP, BUCKLE_HANG = 0.66, 30 / 64, { 55 / 64, 46 / 64 }\n",
   "the Lua's column for the tip not the buckle's art's",
   expect=S_TRIM)

_m(LEATHER,
   "\t\tt:SetPoint(\"TOP\", art, \"TOPLEFT\", hangX, -hangY)\n",
   "\t\tt:SetPoint(\"CENTER\", art, \"TOPLEFT\", hangX, -hangY)\n",
   "the feathers pinned by their middle, not hung by their top",
   expect=S_TRIM)

_m(LEATHER,
   "local FEATHER = { 0.62, 1.24 }\n",
   "local FEATHER = { 0.62, 2.40 }\n",
   "feathers twice as long as the tag is tall",
   expect=S_TRIM)

_m(LEATHER,
   "\tlocal eagle = tex(art, \"BACKGROUND\", -8, \"FeatherB\")\n",
   "\tlocal eagle = tex(art, \"BACKGROUND\", -5, \"FeatherB\")\n",
   "a feather drawn over the leather",
   expect=S_TRIM)

_m(LEATHER,
   "\tself.buckle:SetDesaturated(on)\n",
   "\tself.buckle:SetDesaturated(false)\n",
   "the buckle keeps its colour in a fight",
   expect=S_EMBER)

# --- the brand ---------------------------------------------------------------

_m(LEATHER,
   "\tlocal right = self.W - room - self.brandGap\n",
   "\tlocal right = self.W - self.brandGap\n",
   "the brand under the eyelet",
   expect=S_BRAND)

_m(LEATHER,
   "\tif self.keyLane then room = math.max(room, self.keyRoom or 0) end\n",
   "",
   "the brand under the key's patch",
   expect=S_BRAND)

_m(LEATHER,
   "\t-- The brand stands left of whatever is up, and gives way to the words.\n\tself:PlaceBrand()\n",
   "",
   "the brand left where it stood when a patch comes up",
   expect=S_BRAND)

_m(LEATHER,
   "\tself.ember:SetShown(up)\n",
   "\tself.ember:SetShown(true)\n",
   "the embers lit under the words",
   expect=S_BRAND)

_m(LEATHER,
   "\tBox(self.ember, art, left, top, right, top + size)\n",
   "\tBox(self.ember, art, left + size / 3, top, right, top + size)\n",
   "the embers squeezed into two thirds of the mark",
   expect=S_BRAND)

_m(LEATHER,
   "\tself.brandFlash:SetShown(up)\n",
   "\tself.brandFlash:SetShown(true)\n",
   "the strike's flash over the words",
   expect=S_BRAND)

_m(LEATHER,
   "\tBox(self.brandFlash, art, left, top, right, top + size)\n",
   "\tBox(self.brandFlash, art, left - size / 3, top, right, top + size)\n",
   "the strike's flash wider than the mark it lights",
   expect=S_BRAND)

_m(LEATHER,
   "\tlocal up = left >= self.textX + BRAND_CLEAR * size and clear >= BRAND_WORDS * size\n",
   "\tlocal up = left >= self.textX + BRAND_CLEAR * size and clear >= -2 * size\n",
   "the brand drawn under words that cover it",
   expect=S_BRAND)

_m(LEATHER,
   "\tlocal up = left >= self.textX + BRAND_CLEAR * size and clear >= BRAND_WORDS * size\n",
   "\tlocal up = left >= self.textX + BRAND_CLEAR * size and clear >= 0\n",
   "the brand's rim hard against the last letter",
   expect=S_BRAND)

_m(LEATHER,
   "\t\tif sub > words then words = sub end\n",
   "",
   "the brand drawn under a long reason line",
   expect=S_BRAND)

_m(LEATHER,
   "\tself.ember = tex(self.emberFrame, \"ARTWORK\", 1, \"Ember\")\n",
   "\tself.ember = tex(self.emberFrame, \"ARTWORK\", 1, \"Ember\", \"ADD\")\n",
   "the embers, which rest lit, drawn additive",
   expect=S_BRAND)

_m(LEATHER,
   "\tself.brandFlash:SetDesaturated(true)\n",
   "",
   "the strike's flash in the embers' orange whatever the outcome",
   expect=S_BRAND)

# --- the stack: what overlaps has a level of its own ---------------------------

_m(LEATHER,
   "local LEVEL = { thread = 1, trim = 2, ember = 3, light = 4, chip = 5 }\n",
   "local LEVEL = { thread = 1, trim = 1, ember = 3, light = 4, chip = 5 }\n",
   "the studs and the buckle on the thread's own level",
   expect=S_REST)

_m(LEATHER,
   "local LEVEL = { thread = 1, trim = 2, ember = 3, light = 4, chip = 5 }\n",
   "local LEVEL = { thread = 1, trim = 2, ember = 2, light = 4, chip = 5 }\n",
   "the embers on the burnt mark's own level",
   expect=S_REST)

_m(LEATHER,
   "local LEVEL = { thread = 1, trim = 2, ember = 3, light = 4, chip = 5 }\n",
   "local LEVEL = { thread = 1, trim = 2, ember = 3, light = 3, chip = 5 }\n",
   "the lights on the embers' own level",
   expect=S_REST)

_m(LEATHER,
   "\tself.smokeFrame:SetFrameLevel(level + LEVEL.chip)\n",
   "\tself.smokeFrame:SetFrameLevel(level + LEVEL.light)\n",
   "the smoke on the lights' own level",
   expect=S_REST)

_m(LEATHER,
   "\tlocal on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false\n\tlocal lit",
   "\tlocal on = (self.active and not self.combat and kit.FullEffects()) and true or false\n\tlocal lit",
   "the feathers stirring under a prompt that is down",
   expect=S_REST)

# --- the embers --------------------------------------------------------------

_m(LEATHER,
   "\tself.emberFrame:SetAlpha((self.owed and not self.combat) and EMBER_REST or 0)\n",
   "\tself.emberFrame:SetAlpha(EMBER_REST)\n",
   "the brand glowing with nobody owed",
   expect=S_EMBER)

_m(LEATHER,
   "\tself.emberFrame:SetAlpha((self.owed and not self.combat) and EMBER_REST or 0)\n",
   "\tself.emberFrame:SetAlpha(0)\n",
   "the brand dark once it has breathed, with somebody still owed",
   expect=S_EMBER)

_m(LEATHER,
   "\tself.owed = true\n\tif isNew then\n",
   "\tif isNew then\n",
   "somebody owed never told to the brand",
   expect=S_EMBER)

_m(LEATHER,
   "\t-- Nobody owed: the embers go out.\n\tself.owed = nil\n",
   "\t-- Nobody owed: the embers go out.\n",
   "the embers left lit when the favour is gone",
   expect=S_EMBER)

_m(LEATHER,
   "\tAlpha(ember, EMBER_LOW, 1, BREATH, 1, \"IN_OUT\")\n",
   "\tAlpha(ember, 0, 1, BREATH, 1, \"IN_OUT\")\n",
   "the embers going out between breaths",
   expect=S_EMBER)

# --- at rest -----------------------------------------------------------------

_m(LEATHER,
   "\tlocal on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false\n\tlocal lit",
   "\tlocal on = (self.active and not self.combat and kit.button:IsShown()) and true or false\n\tlocal lit",
   "the feathers stirring on Calm",
   expect=S_REST)

_m(LEATHER,
   "\tlocal on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false\n\tlocal lit",
   "\tlocal on = (self.active and kit.FullEffects() and kit.button:IsShown()) and true or false\n\tlocal lit",
   "the feathers stirring in a fight",
   expect=S_REST)

_m(LEATHER,
   "\t\tself.shimmer[i] = anim(Glint(piece.tex, 0.5 + (i - 1) * GLINT_STEP, GLINT_PEAK, 0.08, 0.30, GLINT_EVERY))\n",
   "\t\tself.shimmer[i] = anim(Glint(piece.tex, 0.5, GLINT_PEAK, 0.08, 0.30, GLINT_EVERY))\n",
   "the whole thread glinting at once",
   expect=S_REST)

_m(LEATHER,
   "\t\tself.shimmer[i] = anim(Glint(piece.tex, 0.5 + (i - 1) * GLINT_STEP, GLINT_PEAK, 0.08, 0.30, GLINT_EVERY))\n",
   "\t\tself.shimmer[i] = anim(Glint(piece.tex, 0.5 + (i - 1) * GLINT_STEP, GLINT_PEAK, 0.08, 1.30, GLINT_EVERY))\n",
   "an additive glint that stays for over a second",
   expect=S_REST)

_m(LEATHER,
   "\t\tself.idle[#self.idle + 1] = self.sways[i]\n",
   "",
   "the feathers' sway not named among the look's loops at rest",
   expect=S_REST)

_m(LEATHER,
   "\t\tif a.SetOrigin then a:SetOrigin(\"TOP\", 0, 0) end\n",
   "\t\tif a.SetOrigin then a:SetOrigin(\"CENTER\", 0, 0) end\n",
   "a feather turning about its middle like a propeller",
   expect=S_REST)

_m(LEATHER,
   "local SWAY = { { 8, 1.9 }, { -6.5, 2.4 } }\n",
   "local SWAY = { { 8, 1.9 }, { 8, 1.9 } }\n",
   "the two feathers swaying as one",
   expect=S_REST)

_m(LEATHER,
   "\t-- Flow's handles are not animation groups: stopped by hand.\n\tself.flow:StopAll()\n",
   "",
   "the smoke's clock left running under another look",
   expect=S_REST)

_m(LEATHER,
   "\t\t\tif full then self:Stir(\"arrive\") end\n",
   "\t\t\tself:Stir(\"arrive\")\n",
   "the feathers flung on Calm",
   expect=S_REST)

# --- a strike ----------------------------------------------------------------

_m(LEATHER,
   "\t\tself.cool:Stop()\n\t\tself.cool:Play()\n",
   "",
   "a landing leaves the brand cold",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tself.coolTo:SetToAlpha(self.owed and EMBER_REST or 0)\n",
   "\t\tself.coolTo:SetToAlpha(0)\n",
   "a brand struck while somebody is owed cools to nothing and jumps back alight",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tself.coolTo:SetToAlpha(self.owed and EMBER_REST or 0)\n",
   "\t\tself.coolTo:SetToAlpha(EMBER_REST)\n",
   "a brand struck with nobody owed cools to a smoulder and jumps dark",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tif self.cool:IsPlaying() then self.cool:Stop() end\n",
   "",
   "the cooling and a new favour's breath both on the embers",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tself.smokeSheet:Stop()\n\t\tself.smokeSheet:Play()\n",
   "",
   "a landing raises no smoke",
   expect=S_STRIKE)

_m(LEATHER,
   "\tif kind == \"cast\" and self.brandLit and not self.combat then\n",
   "\tif self.brandLit and not self.combat then\n",
   "a refusal strikes the brand hot and raises smoke",
   expect=S_STRIKE)

_m(LEATHER,
   "\tif kind == \"cast\" and self.brandLit and not self.combat then\n",
   "\tif kind == \"cast\" and self.brandLit then\n",
   "a landing in a fight lights the brand and raises smoke",
   expect=S_STRIKE)

_m(LEATHER,
   "\tcast = { { -9, 0.10 }, { 14, 0.16 }, { -7, 0.20 }, { 2, 0.24 } },\n",
   "\tcast = { { -9, 0.10 }, { 14, 0.16 }, { -7, 0.20 }, { 5, 0.24 } },\n",
   "a kick that leaves the feathers turned",
   expect=S_STRIKE)

_m(LEATHER,
   "\tif not set or self.combat then return end\n",
   "\tif not set then return end\n",
   "the feathers flung in a fight",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tfor _, piece in ipairs(self.pieces) do Colour(piece.tex, GLINT[1], GLINT[2], GLINT[3]) end\n",
   "",
   "the thread glinting in the last outcome's colour",
   expect=S_STRIKE)

_m(LEATHER,
   "\tself.struck = true\n",
   "",
   "the thread's own warm white painted over a landing's green",
   expect=S_LAND)

_m(LEATHER,
   "\tfor _, g in ipairs(self.aftermath) do g:Stop() end\n\tself.smokeSheet:Stop()\n",
   "\tself.smokeSheet:Stop()\n",
   "the feathers' fling and the cooling left running by a repaint",
   expect=S_STRIKE)

_m(LEATHER,
   "\tfor _, g in ipairs(self.aftermath) do g:Stop() end\n\tself.smokeSheet:Stop()\n",
   "\tfor _, g in ipairs(self.aftermath) do g:Stop() end\n",
   "the smoke left rising by a repaint",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tif Leather.active then Leather:Idle() end\n\tend\n\tself.stirs, self.aftermath = {}, {}\n",
   "\tend\n\tself.stirs, self.aftermath = {}, {}\n",
   "the feathers hanging dead after a fling",
   expect=S_STRIKE)

_m(LEATHER,
   "\tself:Strike(kind, self.kit.Tint(o[1], o[2], o[3], 0.30))\n",
   "\tself:Strike(kind, 1, 0.3, 0.3)\n",
   "a landing's flash on the brand not green",
   expect=S_STRIKE)

_m(LEATHER,
   "\t\tself:Strike(kind, 1.00, 0.30, 0.16)\n",
   "\t\tself:Strike(\"cast\", 1.00, 0.30, 0.16)\n",
   "a refusal told to the brand as a landing",
   expect=S_STRIKE)

# --- the trim's art ------------------------------------------------------------

_m(GENERATOR,
   "    make_smoke()\n    make_sheen()\n",
   "    make_sheen()\n",
   "the smoke's sheet no longer drawn",
   expect=S_GEN)

_m(GENERATOR,
   "RECESS = (17.0, 3.6, 3.3)\n",
   "RECESS = (17.0, 3.6, 1.0)\n",
   "the field pressed a third as deep as the hide that ships",
   expect=S_GEN)

# --- the serif's size ---------------------------------------------------------
S_SERIF = "look-leather: the serif's name is as large as the tag holds and costs no reason line"

mutate(LEATHER,
       "local SERIF = 1.2\nfunction Leather.NameSize(fontSize, serif, height, sub)\n",
       "local SERIF = 1.08\nfunction Leather.NameSize(fontSize, serif, height, sub)\n",
       "look-leather: the serif's name back at a point over the player's size, which did not read in the game",
       expect=S_FACE, script=S)

mutate(LEATHER,
       "\tif not serif then return fontSize, GAP end\n",
       "",
       "look-leather: a font the player chose drawn at the serif's larger size",
       expect=S_FACE, script=S)

mutate(LEATHER,
       "\treturn Clamp(math.floor(room), math.min(full, fontSize + 1), full), GAP\n",
       "\treturn full, GAP\n",
       "look-leather: the serif's larger name never gives way on a short tag: the lines leave their margin",
       expect=S_SERIF, script=S)

mutate(LEATHER,
       "\treturn Clamp(math.floor(room), math.min(full, fontSize + 1), full), GAP\n",
       "\treturn math.min(full, fontSize + 1), GAP\n",
       "look-leather: the serif's name left a point over the player's size on every tag",
       expect=S_SERIF, script=S)

mutate(LEATHER,
       "\treturn math.ceil((fontSize + 1) + GAP + SubSize(fontSize) + MARGIN)\n",
       "\treturn math.ceil(math.floor(fontSize * 1.2 + 0.5) + GAP + SubSize(fontSize) + MARGIN)\n",
       "look-leather: two lines counted with the serif's larger name: the reason line dropped at heights that had it",
       expect=S_SERIF, script=S)
