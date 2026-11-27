# Mutations for the Ribbon look: tests/scenarios/look-ribbon.lua, with the
# ring's reach judged by hunt37-effects.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

RIBBON = "Looks/Ribbon.lua"
GEN = "tools/make_ribbon_textures.py"


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only look-ribbon finds them
    all, the ones that edit a locale or the generator included."""
    kw.setdefault("script", "runscenarios.py")
    mutate(file, old, new, "look-ribbon: " + label, **kw)


# --- registered, named, translated ------------------------------------------

_m(RIBBON,
   "\torder = 4,\n",
   "\torder = 40,\n",
   "the look no longer fourth in the dropdown",
   expect="look-ribbon: Ribbon is registered")

_m("Locales/deDE.lua",
   'L["Ribbon"] = "Band"\n',
   'L["Ribbon"] = "Ribbon"\n',
   "the card's title left in English in German",
   expect="look-ribbon: Ribbon is registered")

# --- the layout -------------------------------------------------------------

_m(RIBBON,
   "\tself.rightBase = math.ceil(g.notch + 8)\n",
   "\tself.rightBase = 4\n",
   "the lines run on into the fork's notch",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "\tself.textX = math.floor(cx + g.R + 5 + 0.5)\n",
   "\tself.textX = math.floor(cx + 0.5)\n",
   "the lines start over the medallion",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "local M = icon and math.min(H - 3, math.max(24, math.floor(W * 0.5))) or 0",
   "local M = icon and math.min(H + 8, math.max(24, math.floor(W * 0.5))) or 0",
   "a medallion taller than the prompt",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "g.inner = g.rh * (1 - 2 * 5.8 / RIBBON_PX)",
   "g.inner = g.rh * (1 - 2 * 0.5 / RIBBON_PX)",
   "the room between the rails over-counted: two lines drawn over the gold",
   expect="look-ribbon: the default size holds two lines")

_m(RIBBON,
   "local ov = Clamp(math.floor(H * 0.115 + 0.5), 1, 14)",
   "local ov = Clamp(math.floor(H * 0.02 + 0.5), 1, 14)",
   "a ribbon as tall as the medallion",
   expect="look-ribbon: the default size holds two lines")

_m(RIBBON,
   "\t\t\tself.keyBox:SetPoint(\"RIGHT\", kit.art, \"RIGHT\", -(self.g.notch + 5),\n",
   "\t\t\tself.keyBox:SetPoint(\"RIGHT\", kit.art, \"RIGHT\", -2,\n",
   "the key's tag cut by the fork",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "g.iconSize = math.floor(2 * M_BEZEL * g.half / MASK_FILL + 0.5)",
   "g.iconSize = math.floor(2.6 * M_BEZEL * g.half / MASK_FILL + 0.5)",
   "an icon wider than the bezel it sits in",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "\tself.shade:SetSize(1.88 * g.R / SHADE_FILL, 1.88 * g.R / SHADE_FILL)\n",
   "\tself.shade:SetSize(3.4 * g.R / SHADE_FILL, 3.4 * g.R / SHADE_FILL)\n",
   "the medallion's shade falling far outside the box",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "local SHADOW_ROOM = 0\n",
   "local SHADOW_ROOM = 6\n",
   "the ribbon's shadow drawn out past the right edge",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "\t\tlocal H = 24\n\t\twhile not (holds(H) and holds(H + 1) and holds(H + 2)) do H = H + 1 end\n",
   "\t\tlocal H = 24\n\t\twhile false do H = H + 1 end\n",
   "two lines asked for at any height",
   expect="look-ribbon: the options page can state")

# --- the reason line at every size ------------------------------------------

_m(RIBBON,
   "\t\tlocal function holds(H) return Geometry(200, H, true, fontSize, full).nameSz ~= nil end\n",
   "\t\tlocal function holds(H) return Geometry(200, H, true).inner >= NameSize(fontSize) + Gap(fontSize)"
   " + SubSize(fontSize) + 2 end\n",
   "two lines only where the cloth holds the display face unwidened: the reason dropped at large sizes",
   expect="look-ribbon: the reason line stays wherever")

_m(RIBBON,
   "\t\twhile ov > least and not Lines(two, ",
   "\t\twhile false and ov > least and not Lines(two, ",
   "the cloth never widens for two lines: the face shrinks first",
   expect="look-ribbon: the reason line stays wherever")

_m(RIBBON,
   "\tif full then return nil end\n",
   "\tdo return nil end\n",
   "the display face never gives way: the reason dropped where it does not fit",
   expect="look-ribbon: the reason line stays wherever")

_m(RIBBON,
   "math.max(from(false), ns.TwoLineHeight(fontSize, \"glass\"))",
   "from(false)",
   "two lines squeezed in below the height the built-in look keeps them at",
   expect="look-ribbon: the reason line stays wherever")

_m(RIBBON,
   "(H - (icon and M or H - 3) / TALLER) / 2 - 1e-6)",
   "(H - (icon and M or H - 3) / 0.95) / 2 - 1e-6)",
   "the cloth widened past the medallion for two lines",
   expect="look-ribbon: the reason line stays wherever")

_m(RIBBON,
   "\tlocal half = math.min(RIBBON_PX * s / 2, self.H - mid)\n",
   "\tlocal half = RIBBON_PX * s / 2\n",
   "the shadow of a widened cloth drawn out of the prompt",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "\treturn Geometry(p.width or 220, p.height or 44, true).iconSize\n",
   "\treturn 30\n",
   "the options page told the icon is 30 whatever the height",
   expect="look-ribbon: the options page can state")

_m(RIBBON,
   "\treturn (mode == \"icon\" or mode == \"both\") and p.showIcon and true or false,\n",
   "\treturn (mode == \"icon\" or mode == \"both\") and true or false,\n",
   "the ring claimed with the icon off",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\tBox(d[2], art, x1 - tip, y0, x1 + room, y1)\n",
   "\tBox(d[2], art, x1 - tip, y0, x1 + room - 4, y1)\n",
   "the shadow's forked end short of the edge",
   expect="look-ribbon: the layout holds")

# --- solid, not a veil ------------------------------------------------------

_m(RIBBON,
   "\tfor _, t in ipairs(self.cloth) do Colour(t, dye[1] * k, dye[2] * k, dye[3] * k) end\n",
   "\tfor _, t in ipairs(self.cloth) do Colour(t, dye[1] * k, dye[2] * k, dye[3] * k, 0.8) end\n",
   "the cloth drawn as a veil",
   expect="look-ribbon: the ribbon is a solid object")

_m(RIBBON,
   "\tself.cloth = Cloth(art, \"BORDER\", 0, \"Cloth_Mid\", \"Cloth_End\", nil, keep, true)\n",
   "\tself.cloth = Cloth(art, \"BORDER\", 0, \"Cloth_Mid\", \"Cloth_End\", \"ADD\", keep, true)\n",
   "the cloth drawn as light",
   expect="look-ribbon: the ribbon is a solid object")

_m(RIBBON,
   "\tEach(self.dark, \"SetAlpha\", 0)\n\tEach(self.hot, \"SetAlpha\", 0)\n\t-- The shine",
   "\tEach(self.dark, \"SetAlpha\", 0.6)\n\tEach(self.hot, \"SetAlpha\", 0)\n\t-- The shine",
   "the refusal's darkening left laid over the cloth",
   expect="look-ribbon: the ribbon is a solid object")

_m(RIBBON,
   "\tfor _, g in ipairs(self.pulse) do g:Stop() end\n\tself.lit:SetAlpha(0)\n\tself.enamelLit:SetAlpha(0)\nend\n\n-- A new favour",
   "\tfor _, g in ipairs(self.pulse) do g:Stop() end\n\tself.lit:SetAlpha(0.4)\n\tself.enamelLit:SetAlpha(0)\nend\n\n-- A new favour",
   "light left on the medallion at rest",
   expect="look-ribbon: the ribbon is a solid object")

_m(GEN,
   "        return np.clip(s, 0, 1), np.ones_like(s)\n    make(\"Ribbon_Cloth_Mid\"",
   "        return np.clip(s, 0, 1), np.ones_like(s) * 0.9\n    make(\"Ribbon_Cloth_Mid\"",
   "the cloth drawn at nine tenths: a veil in the art",
   expect="look-ribbon: the generator draws the same bytes")

_m(GEN,
   "NOTCH_PX = 19.0\n",
   "NOTCH_PX = 25.0\n",
   "the fork cut deeper in the art than the code lays it out for",
   expect="look-ribbon: the code and the generator agree")

# --- the reason -------------------------------------------------------------

_m(RIBBON,
   "\t\tself.ringNow = { Fired(r, g, b) }\n",
   "\t\tself.ringNow = NEUTRAL\n",
   "the enamel never carries the reason",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\tlocal clothOn = mode == \"stripe\" or mode == \"both\"\n\tif clothOn then\n\t\tlocal dr",
   "\tlocal clothOn = mode ~= \"off\"\n\tif clothOn then\n\t\tlocal dr",
   "the cloth dyed in the ring's mode too",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\tlocal ringOn = mode == \"icon\" or mode == \"both\"\n\tlocal clothOn = mode == \"stripe\" or mode == \"both\"\n\tif clothOn then",
   "\tlocal ringOn = mode ~= \"off\"\n\tlocal clothOn = mode == \"stripe\" or mode == \"both\"\n\tif clothOn then",
   "the enamel carrying the reason in the stripe's mode too",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "local CRIMSON = { 0.78, 0.14, 0.14 }",
   "local CRIMSON = { 0.45, 0.45, 0.50 }",
   "the default owed ribbon not crimson",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\towed = CRIMSON,\n",
   "\towed = { 0.20, 0.40, 0.80 },\n",
   "somebody owed dyed blue in the stripe",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\tif byReason ~= false and palette ~= \"colourblind\" and DYES[reason] then",
   "\tif byReason ~= false and DYES[reason] then",
   "the colour-blind palette dyed from the standard table",
   expect="look-ribbon: the reason is the enamel ring")

_m(RIBBON,
   "\tsr, sg, sb = Raise(sr, sg, sb, Lum(dye[1] * LIT_GREY, dye[2] * LIT_GREY, dye[3] * LIT_GREY), READ)\n",
   "\tsr, sg, sb = sr, sg, sb\n",
   "the reason line not lifted to read on a dye",
   expect="look-ribbon: the lettering holds its contrast")

_m(RIBBON,
   "local READ = 4.6\n",
   "local READ = 1.5\n",
   "the reason line held to a contrast nobody reads at",
   expect="look-ribbon: the lettering holds its contrast")

_m(RIBBON,
   "local DYE_LUMA, DYE_LUMA_LOW, DYE_LUMA_HIGH = 0.105, 0.016, 0.125",
   "local DYE_LUMA, DYE_LUMA_LOW, DYE_LUMA_HIGH = 0.105, 0.016, 0.45",
   "a colour-blind dye bright enough to lose the name",
   expect="look-ribbon: the lettering holds its contrast")

_m(RIBBON,
   "local LIT_GREY = 0.935\n",
   "local LIT_GREY = 0.700\n",
   "dyes worked out for a darker cloth than the art draws",
   expect="look-ribbon: the lettering holds its contrast")

_m(RIBBON,
   "\tkit.name:SetTextColor(GOLD_INK[1], GOLD_INK[2], GOLD_INK[3], Clamp(alpha, 0, 1))\n\t\tself.nameInk = GOLD_INK",
   "\tkit.name:SetTextColor(1, 1, 1, 1)\n\t\tself.nameInk = GOLD_INK",
   "the name white, not warm gold",
   expect="look-ribbon: a class colour stays Blizzard's colour, and the chosen font colour wins")

_m(RIBBON,
   "local PEACH = { 1.00, 0.88, 0.80 }",
   "local PEACH = { 0.60, 0.60, 0.60 }",
   "the reason in grey, not pale peach",
   expect="look-ribbon: a class colour stays Blizzard's colour, and the chosen font colour wins")

_m(RIBBON,
   "function Ribbon:Fitted() end\n",
   "function Ribbon:Fitted(fs) fs:SetText(\"|cffffd100Anna|r\") end\n",
   "a class colour changed by refitting",
   expect="look-ribbon: a class colour stays Blizzard's colour, and the chosen font colour wins")

mutate("Prompt/Paint.lua",
       "\treturn string.format(\"|c%s%s|r\", c.colorStr, text)\n",
       "\treturn \"|cffffd100\" .. text .. \"|r\"\n",
       "the class colour changed to gold before Ribbon draws it",
       expect="look-ribbon: a class colour stays Blizzard's colour, and the chosen font colour wins",
       script="runscenarios.py")

_m(RIBBON,
   "local TAG_INK = { 0.27, 0.05, 0.04 }",
   "local TAG_INK = { 0.95, 0.90, 0.80 }",
   "the tags' ink pale on gold",
   expect="look-ribbon: the lines keep clear of the tags")

_m(RIBBON,
   "local BADGE_INK = { 1.00, 0.90, 0.62 }",
   "local BADGE_INK = { 0.27, 0.05, 0.04 }",
   "the count's ink dark on its enamel",
   expect="look-ribbon: the lines keep clear of the tags")

_m(RIBBON,
   "\tself.chip = ThreeSlice(self.chipFrame, \"ARTWORK\", 1, ART .. \"Badge\", keep)\n",
   "\tself.chip = ThreeSlice(self.chipFrame, \"ARTWORK\", 1, ART .. \"Tag\", keep)\n",
   "the count on a plain gold tag, the badge shipped and never drawn",
   expect="look-ribbon: the lines keep clear of the tags")

# --- the art is modelled -----------------------------------------------------
# Each of these also leaves the shipped bytes behind the generator; the rule
# each breaks is the one the modelling scenario reads off the fresh files.

_m(GEN,
   "    s = 0.31 + 0.38 * diff + 0.36 * sheen\n",
   "    s = 0.70 + 0.0 * diff + 0.0 * sheen\n",
   "the cloth painted flat: no sheen, no hem",
   expect="look-ribbon: the art is modelled")

# The folds are the wave's since the cloth moves: ironed out there.
_m(GEN,
   "WAVE_DEPTH, WAVE_LEAN = 0.40, 0.30\n",
   "WAVE_DEPTH, WAVE_LEAN = 0.0, 0.30\n",
   "the cloth's folds ironed out",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "    s = s * (1 - 0.17 * fig * field) * (1 + 0.10 * rim * field)\n",
   "    s = s * 1.0\n",
   "the cloth plain: no figure woven into it",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "FLUTTER_PX, FLUTTER_DEPTH, SWING_PX = 46.0, 5.6, 7.0\n",
   "FLUTTER_PX, FLUTTER_DEPTH, SWING_PX = 46.0, 5.6, 0.0\n",
   "the fork's tails never swing: thirty-two frames of one picture",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "        return np.zeros(a.shape), a\n    make(\"Ribbon_Wave\", 128, RIBBON_PX, paint)\n",
   "        return np.ones(a.shape), a\n    make(\"Ribbon_Wave\", 128, RIBBON_PX, paint)\n",
   "the folds drawn white: light on the cloth under the words",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "FRAMES, COLS, SHEET_ROWS = 32, 8, 4\n",
   "FRAMES, COLS, SHEET_ROWS = 16, 8, 2\n",
   "the fork's sheet drawn in half the frames the code plays",
   expect="look-ribbon: the code and the generator agree")

_m(GEN,
   "    t = 0.12 + 0.42 * env + 0.30 * diff + 0.90 * spec - 0.10 * np.clip(tilt - 0.85, 0, 1) / 0.15\n",
   "    t = 0.55 + 0.0 * env + 0.0 * diff + 0.0 * spec - 0.0 * np.clip(tilt - 0.85, 0, 1) / 0.15\n",
   "the gold unlit: one flat yellow",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "        col = col * (1 - 0.75 * outline[..., None])\n",
   "        col = col * (1 - 0.0 * outline[..., None])\n",
   "the medallion with no dark outline",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "    outline = sstep(-0.5, 0.5, d) * (1 - sstep(c0 - 0.3, c0 + 0.3, d))\n",
   "    outline = sstep(-0.5, 0.5, d) * 0.0\n",
   "the cord with no outline against the world",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "        return np.zeros(a.shape), a * 0.72\n",
   "        return np.zeros(a.shape), a * 0.20\n",
   "the ribbon's shadow faint",
   expect="look-ribbon: the art is modelled")

_m(GEN,
   "ENAMEL_RGB = np.array([0.50, 0.07, 0.09], np.float32)\n",
   "ENAMEL_RGB = np.array([0.90, 0.65, 0.20], np.float32)\n",
   "the badge's field gold, not enamel",
   expect="look-ribbon: the art is modelled")

# --- the face ---------------------------------------------------------------

_m(RIBBON,
   "\tif not ROMAN[ns.LOCALE or \"enUS\"] then return nil end\n",
   "\tif false then return nil end\n",
   "Morpheus forced on a client that writes in another script",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "\tif type(p.font) == \"string\" and p.font ~= d then return nil end\n",
   "\tif false then return nil end\n",
   "the player's font overridden",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "\t\tif tried then nameFace = face else kit.name:SetFont(path, nameSz, fit.flags) end\n",
   "\t\tnameFace = face\n",
   "a refused face left as the line's font",
   expect="look-ribbon: a face the client refuses")

_m(RIBBON,
   "\tfit.paths[kit.name] = nameFace\n",
   "\tfit.paths[kit.name] = nameFace\n\tif nameFace then path = nameFace end\n",
   "the reason line back in the display serif's hair-thin capitals",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "\tfit.paths[kit.name] = nameFace\n",
   "\tfit.paths[kit.name] = nil\n",
   "a refitted name leaves its face",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "local function NameSize(fontSize, serif) return math.floor(fontSize * (serif and 1.2 or 1.1) + 0.5) end",
   "local function NameSize(fontSize, serif) return fontSize end",
   "the name not drawn at the size the layout counts on",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "local function NameSize(fontSize, serif) return math.floor(fontSize * (serif and 1.2 or 1.1) + 0.5) end",
   "local function NameSize(fontSize, serif) return math.floor(fontSize * 1.1 + 0.5) end",
   "the name in the serif back at the size of any other face, which did not read in the game",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "local function NameSize(fontSize, serif) return math.floor(fontSize * (serif and 1.2 or 1.1) + 0.5) end",
   "local function NameSize(fontSize, serif) return math.floor(fontSize * 1.2 + 0.5) end",
   "a font the player chose drawn at the serif's larger size",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "\tlocal g = Geometry(W, H, showIcon, two, nil, serif)\n",
   "\tlocal g = Geometry(W, H, showIcon, two)\n",
   "the cloth and the lines laid for a smaller name than the serif is drawn at",
   expect="look-ribbon: the face on")

_m(RIBBON,
   "\tlocal least = math.max(sub + 1, 7, math.floor(NameSize(fontSize) * 0.8 + 0.5))\n",
   "\tlocal least = math.max(sub + 1, 7, math.floor(name * 0.8 + 0.5))\n",
   "the serif's larger name gives way less than any other face's: the reason dropped on a narrow cloth",
   expect="look-ribbon: the reason line stays wherever")

# --- the tags ---------------------------------------------------------------

_m(RIBBON,
   "\treturn width * least / size <= self.W - self.textX - math.max(room, self.rightBase) + 0.5\n",
   "\treturn true\n",
   "a tag up over a name that cannot shrink",
   expect="look-ribbon: the lines keep clear of the tags")

_m(RIBBON,
   "\tif self.outcomeOn or type(GetBindingKey) ~= \"function\" then return nil end\n",
   "\tif type(GetBindingKey) ~= \"function\" then return nil end\n",
   "the key's tag over an outcome",
   expect="look-ribbon: the lines keep clear of the tags")

# The name's room at the default size with a count and a key up: the count is
# a badge on the medallion's rim and the key's tag stands on the reason line.
_m(RIBBON,
   "\tself.medalOK = showIcon and g.R >= MEDAL_BADGE_FROM and self.smallH <= g.R * 0.75\n",
   "\tself.medalOK = false\n",
   "the count back at the name line's end, taking the name's room",
   expect="is not cut at the default size")

_m(RIBBON,
   "\t\t\tif self:SubFits(self.keyRoom) then lane = \"sub\" end\n",
   "",
   "the key's tag back at the name line's end, taking the name's room",
   expect="is not cut at the default size")

_m(RIBBON,
   "\tif self.keyLane == \"sub\" then subInset = math.min(math.max(inset, self.keyRoom or 0), least) end\n",
   "",
   "the reason running under the key's tag",
   expect="look-ribbon: the lines keep clear of the tags")

_m(RIBBON,
   "\t\t\t\tself.chipBox:SetPoint(\"CENTER\", kit.art, \"TOPLEFT\", g.cx + dx, -(g.cy + dy))\n",
   "\t\t\t\tself.chipBox:SetPoint(\"CENTER\", kit.art, \"TOPLEFT\", g.cx + dx, -g.cy)\n",
   "the count's badge in the middle of the medallion, off its rim",
   expect="look-ribbon: the layout holds")

# --- the outcomes -----------------------------------------------------------

_m(RIBBON,
   "\tself.ringNow = { o[1], o[2], o[3] }\n",
   "\tself.ringNow = self.ringNow\n",
   "the enamel keeping the reason's colour over an outcome",
   expect="look-ribbon: the outcomes write a verdict")

_m(RIBBON,
   "\tself.refused = kind == \"failed\"\n\tkit.icon:SetDesaturated(self.refused or self.combat or false)\n",
   "\tself.refused = kind == \"failed\"\n\tkit.icon:SetDesaturated(self.combat or false)\n",
   "the icon not greyed by a refusal",
   expect="look-ribbon: the outcomes write a verdict")

# --- motion -----------------------------------------------------------------

_m(RIBBON,
   "\tif full and self.slideBy > 0 then\n\t\t-- Stopped first",
   "\tif self.slideBy > 0 then\n\t\t-- Stopped first",
   "Calm sliding the cloth",
   expect="look-ribbon: Calm plays only fades")

_m(RIBBON,
   "\tlocal slide = showIcon and Clamp(g.R * 0.55, 6, 24) or 0\n",
   "\tlocal slide = 0\n",
   "no slide from behind the medallion",
   expect="look-ribbon: the cloth slides out")

_m(RIBBON,
   "\t\tif Ribbon.active and Ribbon.W then Ribbon:PlaceRibbon(0) end\n",
   "\t\tif false then Ribbon:PlaceRibbon(0) end\n",
   "the cloth left where the slide began",
   expect="look-ribbon: the cloth slides out")

_m(RIBBON,
   "\t\tfor _, g in ipairs(self.slide) do g:Stop() end\n\t\tself:PlaceRibbon(-self.slideBy)\n",
   "\t\tself:PlaceRibbon(-self.slideBy)\n\t\tfor _, g in ipairs(self.slide) do g:Stop() end\n",
   "a second arrival put home by the stop that starts it",
   expect="look-ribbon: the cloth slides out")

_m(RIBBON,
   "\tif self.combat then return end\n\t-- A refusal",
   "\t-- A refusal",
   "a flourish played in a fight",
   expect="look-ribbon: a fight dims the ribbon")

_m(RIBBON,
   "\tif not full or self.pulseSpent then\n",
   "\tif self.pulseSpent then\n",
   "the breath looping on Calm",
   expect="look-ribbon: Calm plays only fades")

_m(RIBBON,
   "local BREATHS, BREATH = 3, 1.3\n",
   "local BREATHS, BREATH = 30, 1.3\n",
   "a breath that never stops",
   expect="look-ribbon: the medallion's gold breathes")

_m(RIBBON,
   "\tif on then\n\t\tself:StopAttention()\n\t\tself:StopFlourishes()\n\tend\n",
   "\tif on then\n\t\tself:StopFlourishes()\n\tend\n",
   "the breath going on in a fight",
   expect="look-ribbon: a fight dims the ribbon")

_m(RIBBON,
   "\tlocal k = self.combat and CLOTH_COMBAT or 1\n",
   "\tlocal k = 1\n",
   "the cloth not darkened in a fight",
   expect="look-ribbon: a fight dims the ribbon")

_m(RIBBON,
   "\tlocal gold = self.combat and GOLD_COMBAT or { 1, 1, 1 }\n",
   "\tlocal gold = { 1, 1, 1 }\n",
   "the gold not dimmed in a fight",
   expect="look-ribbon: a fight dims the ribbon")

_m(RIBBON,
   "\tself.travelMove:SetOffset(math.max(10, W - g.notch - 4 - sweepW - from + sweepW * 0.5), 0)\n",
   "\tself.travelMove:SetOffset(W, 0)\n",
   "the shine running on into the notch",
   expect="look-ribbon: a landing shines")

_m(RIBBON,
   "\tfor _, t in ipairs(self.hot) do Colour(t, 1, 0.40, 0.10) end\n",
   "\tfor _, t in ipairs(self.hot) do Colour(t, 0.2, 0.4, 1) end\n",
   "the refusal's flash not amber",
   expect="look-ribbon: a refusal darkens")

_m(RIBBON,
   "\tg.to = on and 0.55 or 0\n",
   "\tg.to = on and 1 or 0\n",
   "the cursor's light at full strength",
   expect="look-ribbon: the cursor lights")

_m(RIBBON,
   "\tlocal travel = self.sweep:CreateAnimationGroup()\n",
   "\tlocal travel = self.sweep:CreateAnimationGroup()\n\ttravel:CreateAnimation(\"Scale\")\n",
   "a scale among the look's own animations",
   expect="look-ribbon: every frame of Ribbon's is under the text")

_m(RIBBON,
   "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end\n",
   "\tfor _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 9) end\n",
   "the rings drawn over the text",
   expect="look-ribbon: every frame of Ribbon's is under the text")

_m(RIBBON,
   "\tkit.RingArt(ART .. \"Ring\", RING_PEAK, RING_EDGE)\n",
   "\tkit.RingArt(ART .. \"Ring\", RING_PEAK, 0.5)\n",
   "the ring held to less room than its art takes",
   expect="hunt37-effects: each ring's declared reach")

# --- the cooldown, the cursor, leaving ---------------------------------------

_m(RIBBON,
   "\t\t\tif cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end\n",
   "",
   "the sweep not in the icon's round shape",
   expect="look-ribbon: the cooldown sweeps the medallion")

_m(RIBBON,
   "\t\t\tif cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end\n",
   "",
   "the sweep's edge not round",
   expect="look-ribbon: the cooldown sweeps the medallion")

_m(RIBBON,
   "\t\ticon:RemoveMaskTexture(self.mask)\n",
   "",
   "the icon left round on another look",
   expect="look-ribbon: leaving the look")

_m(RIBBON,
   "\tkit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)\n\tkit.textLayer:SetAlpha(1)\n",
   "\tkit.textLayer:SetAlpha(1)\n",
   "the text's frame level not given back",
   expect="look-ribbon: leaving the look")

_m(RIBBON,
   "\tfor _, g in ipairs(self.anims) do g:Stop() end\n\tself.fx:Stop()\n\t-- A glow",
   "\tself.fx:Stop()\n\t-- A glow",
   "an animation left playing on another look",
   expect="look-ribbon: leaving the look")

# --- the list ----------------------------------------------------------------

_m(RIBBON,
   "\t\t\ty = g.top + 2 - (shown - i) * pitch - rh / 2 - 1\n",
   "\t\t\ty = g.top - 14 - (shown - i) * pitch - rh / 2 - 1\n",
   "the rows hanging clear of the main ribbon",
   expect="look-ribbon: the list is a small ribbon per name")

_m(RIBBON,
   "\tlocal rowWidth = math.max(20, W - 5 - self.rowNotch - 4 - self.rowX)\n",
   "\tlocal rowWidth = math.max(20, W - self.rowX)\n",
   "a row's name running into its fork",
   expect="look-ribbon: the list is a small ribbon per name")

_m(RIBBON,
   "\t\tif mode == \"off\" then\n\t\t\tColour(self.gems[i], NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])\n",
   "\t\tif false then\n\t\t\tColour(self.gems[i], NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])\n",
   "the rows' gems carrying a reason with the marker off",
   expect="look-ribbon: the rows' gems carry the reason")

_m(RIBBON,
   "\t\tif clothOn then\n\t\t\tdye = { Ribbon.Dye(c[1], c[2], c[3], reason, p.reasonPalette, p.accentByReason) }\n",
   "\t\tif false then\n\t\t\tdye = { Ribbon.Dye(c[1], c[2], c[3], reason, p.reasonPalette, p.accentByReason) }\n",
   "the rows' cloth never dyed",
   expect="look-ribbon: the rows' gems carry the reason")

# --- it moves: the wave, the flutter, the weave ------------------------------

_m(RIBBON,
   "\tself.waveFlow = flow:Scroll(self.wave, -SHEET.fps / SHEET.frames, 0, 1, 1)\n",
   "\tself.waveFlow = flow:Scroll(self.wave, SHEET.fps / SHEET.frames, 0, 1, 1)\n",
   "the folds running back up the cloth, away from the fork",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\t\tself.flutter[i] = flow:Sheet(t, SHEET.cols, SHEET.rows, SHEET.frames, SHEET.fps, true)\n",
   "\t\tself.flutter[i] = flow:Sheet(t, SHEET.cols, SHEET.rows, SHEET.frames, SHEET.fps * 0.75, true)\n",
   "the fork fluttering out of step with the folds",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\t\treturn write(handle, t0 + math.floor((now - t0) * SHEET.fps) / SHEET.fps)\n",
   "\t\treturn write(handle, now)\n",
   "the folds running on between two frames of the fork: a seam that comes and goes",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\t\tself.wavePhase = -span - lapLeft * per\n",
   "\t\tself.wavePhase = 0\n",
   "the folds not taken up by the fork's frame at the seam",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\tself.wave:SetTexture(ART .. \"Wave\", \"REPEAT\", \"CLAMP\")\n",
   "\tself.wave:SetTexture(ART .. \"Wave\")\n",
   "the wave not tiled along the ribbon",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "not self.refused and kit.FullEffects() and kit.button:IsShown()",
   "not self.refused and kit.button:IsShown()",
   "the cloth moving on Calm",
   expect="look-ribbon: Calm keeps the cloth still")

_m(RIBBON,
   "(self.active and not self.combat and not self.refused and kit.FullEffects()",
   "(self.active and not self.refused and kit.FullEffects()",
   "the cloth moving in a fight",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "not self.combat and not self.refused and kit.FullEffects()",
   "not self.combat and kit.FullEffects()",
   "the pennant flying over a refusal",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "kit.FullEffects() and kit.button:IsShown()) and true or false",
   "kit.FullEffects()) and true or false",
   "the cloth moving with the prompt down",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\t\tself:MatchFrames()\n\t\tPlayAll(self.refuse)\n",
   "\t\tPlayAll(self.refuse)\n",
   "the refusal darkening the fork's first frame, not the one drawn",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\tfor _, t in ipairs(self.lights) do t:SetAlpha(0) end\n\tself.flow:StopAll()\n",
   "\tfor _, t in ipairs(self.lights) do t:SetAlpha(0) end\n",
   "the cloth still flowing on another look",
   expect="look-ribbon: the cloth moves at rest")

_m(RIBBON,
   "\tif not self.showIcon then span = math.max(1, math.floor(span + 0.5)) end\n",
   "",
   "the folds meeting the left fork out of step",
   expect="look-ribbon: with no medallion both forks flutter")

_m(RIBBON,
   "\t\tif i <= 2 or not self.showIcon then h:Play() else h:Stop() end\n",
   "\t\tif i <= 2 then h:Play() else h:Stop() end\n",
   "the left fork still with no medallion over it",
   expect="look-ribbon: with no medallion both forks flutter")

_m(RIBBON,
   "\tlocal n = math.max(1, math.floor(width / (weave[2] / weave[1] * k) + 0.5))\n",
   "\tlocal n = weave[1]\n",
   "the weave stretched to the prompt's width: one file whatever the length",
   expect="look-ribbon: the middles are tiled")

_m(RIBBON,
   "\tset[1]:SetDrawLayer(layer, level + 1)\n",
   "\tset[1]:SetDrawLayer(layer, level)\n",
   "a middle on its fork's own level, the seam left to the order they were made in",
   expect="look-ribbon: the middles are tiled")

_m(RIBBON,
   "\t\tlapRight = set.flash and k or Lap(k)\n",
   "\t\tlapRight = 0\n",
   "the middle stopping at its fork's seam, the fork's empty column uncovered",
   expect="look-ribbon: the layout holds")

_m(RIBBON,
   "\treturn math.max(LAP, LAP_TEXELS * k)\n",
   "\treturn LAP\n",
   "a big ribbon's middle short of covering its fork's empty column",
   expect="look-ribbon: the layout holds")

_m(GEN,
   "        cell[:, 0, 3] = 0\n        cell[:, END_PX - 1, 3] = 0\n",
   "",
   "the fork's frames drawn to their edges, each filtered with its neighbour's cloth",
   expect="look-ribbon: the art is modelled")

# --- the prize pinned on, and the gleam at rest ------------------------------

_m(RIBBON,
   "\t\tPlayAll(self.prize)\n\t\tself.railAnim:Stop()\n",
   "\t\tself.railAnim:Stop()\n",
   "a landing that pins nothing on",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "\tself.burst = tex(art, \"BACKGROUND\", -6, \"Burst\", \"ADD\")\n",
   "\tself.burst = tex(art, \"BORDER\", 7, \"Burst\", \"ADD\")\n",
   "the rays drawn over the cloth, under the words",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "\tself.skyward = { self.medal, self.enamel, self.gloss, self.shade, self.burst, self.hover }\n",
   "\tself.skyward = { self.burst }\n",
   "the medallion leaving the panel as it comes down, and not named",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "local PIN_FROM, PIN_SHADE, PIN_SECONDS, BURST_REACH = 1.24, 1.42, 0.14, 1.95\n",
   "local PIN_FROM, PIN_SHADE, PIN_SECONDS, BURST_REACH = 1.24, 1.42, 0.45, 1.95\n",
   "the medallion hanging over its size for half a second",
   expect="look-ribbon: every frame of Ribbon's is under the text")

_m(RIBBON,
   "\tfor _, g in ipairs(self.prize) do g:Stop() end\n\tfor _, g in ipairs(self.tipAnims) do g:Stop() end\n",
   "\tfor _, g in ipairs(self.tipAnims) do g:Stop() end\n",
   "the prize playing on after a repaint about somebody else",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "\tlocal railBy = math.max(0, W - g.endW - g.rh * 0.3 - railFrom)\n",
   "\tlocal railBy = math.max(0, W - railFrom)\n",
   "the cords' gleam running straight on across the fork",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "\t\t-- And a gleam goes round its laurel and down the cords.\n\t\tif self.showIcon then PlayAll(self.gleam) end\n",
   "",
   "no gleam on the gold as a favour arrives",
   expect="look-ribbon: a landing pins the prize on")

_m(RIBBON,
   "\tself.idleArc = tex(art, \"ARTWORK\", -1, \"Arc\")\n",
   "\tself.idleArc = tex(art, \"ARTWORK\", -1, \"Arc\", \"ADD\")\n",
   "the laurel's gleam at rest drawn additive",
   expect="look-ribbon: a gleam travels the gold")

_m(RIBBON,
   "local GLEAM_EVERY, GLEAM_PEAK = 7, 1\n",
   "local GLEAM_EVERY, GLEAM_PEAK = 3, 1\n",
   "the gleam coming round every three seconds",
   expect="look-ribbon: a gleam travels the gold")

_m(RIBBON,
   "\tself.idle = { anim(round), anim(along) }\n",
   "\tself.idle = { anim(round) }\n\tanim(along)\n",
   "a loop at rest the look does not name",
   expect="look-ribbon: a gleam travels the gold")

_m(RIBBON,
   "\t\tself.flow:StopAll()\n\t\tfor _, g in ipairs(self.idle) do g:Stop() end\n\t\treturn\n",
   "\t\tself.flow:StopAll()\n\t\treturn\n",
   "the gleam going on in a fight",
   expect="look-ribbon: a gleam travels the gold")

# --- the review: the seam, the list's forks, the cursor's light ---------------

_m(RIBBON,
   "\t\tif i == 1 and tiled then t:SetTexture(ART .. file, \"REPEAT\", \"CLAMP\") else t:SetTexture(ART .. file) end\n",
   "\t\tt:SetTexture(ART .. file)\n",
   "the middles made with no wrap mode: the last column smeared along the ribbon",
   expect="look-ribbon: the middles are tiled")

_m(RIBBON,
   "\tset.weave, set.flash = TILE[kind], flash\n",
   "\tset.weave, set.flash = TILE[kind], flash\n\tset[1]:SetTexture(set[1]:GetTexture(), \"REPEAT\", \"CLAMP\")\n",
   "a middle's file set a second time to make it tile",
   expect="look-ribbon: the code and the generator agree")

_m(RIBBON,
   "SHEET.row = 7\n",
   "SHEET.row = 0\n",
   "the list's forks resting on the frame the wave shades, with no wave on the row",
   expect="look-ribbon: the middles are tiled")

_m(RIBBON,
   "local LAP, LAP_TEXELS = 1, 3\n",
   "local LAP, LAP_TEXELS = 1, 1.6\n",
   "the middle ending where its fork becomes whole: the seam a hairline",
   expect="look-ribbon: the code and the generator agree")

_m(RIBBON,
   "\tfor i, t in ipairs({ self.medal, self.enamel, self.gloss, self.shade, self.hover }) do\n",
   "\tfor i, t in ipairs({ self.medal, self.enamel, self.gloss, self.shade }) do\n",
   "the cursor's light left at its size as the medallion comes down: a second rim",
   expect="look-ribbon: a landing pins the prize on")

_m(GEN,
   "STILL_PX = 3.0\n",
   "STILL_PX = 0.0\n",
   "the fork's tails swinging from the seam itself, under the middle's lap",
   expect="look-ribbon: the code and the generator agree")

_m(GEN,
   "    q = np.clip((xe - STILL_PX) / (END_PX - STILL_PX), 0, 1)\n",
   "    q = np.clip(xe / END_PX, 0, 1)\n",
   "the fork's flutter drawn from the seam whatever the generator says it holds still",
   expect="look-ribbon: the art is modelled")

# --- the cloth is never absent on a prompt that is up -------------------------
WHOLE = "look-ribbon: the cloth stands whole at the first instant of a "

_m(RIBBON,
   "\tfor _, g in ipairs(self.fade) do g:Stop() end\n\t-- The flash shared the pulse's light: a breath in progress goes on.\n",
   "\t-- The flash shared the pulse's light: a breath in progress goes on.\n",
   "an arrival's fade runs on under a landing: the medallion and the words with no cloth",
   expect=WHOLE)

_m(RIBBON,
   "\t\tif not self.outcomeOn then self:Unfurl(full) end\n",
   "\t\tself:Unfurl(full)\n",
   "the next person owed plays the cloth's arrival over the verdict",
   expect=WHOLE)

_m(RIBBON,
   "\tif rising then PlayAll(self.fade) end\n",
   "\tPlayAll(self.fade)\n",
   "a favour on a prompt already up fades the cloth in from nothing",
   expect=WHOLE)

_m(RIBBON,
   "\tif rising then PlayAll(self.fade) end\n",
   "",
   "the cloth no longer fades in as the prompt comes up",
   expect="look-ribbon: the cloth slides out from behind the medallion and the medallion glints")
