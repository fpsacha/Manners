# Mutations for the Heritage look: tests/scenarios/look-heritage.lua, with the
# ring's reach judged by hunt37-effects.lua and the switching checks by
# looks.lua.
#
# Run by tests/selftest.py with mutate() in scope. Each puts back a mistake the
# look could plausibly make and names the check that has to object.

HERITAGE = "Looks/Heritage.lua"


def _m(file, old, new, label, **kw):
    """Every label starts with the topic, so --only look-heritage finds them
    all, the ones that edit the toc, a locale and Options included."""
    mutate(file, old, new, "look-heritage: " + label, **kw)


# --- the reason ------------------------------------------------------------

_m(HERITAGE,
       "\tfor _, t in ipairs(self.tint) do t:SetVertexColor(r, g, b, 1) end\n",
       "\tfor _, t in ipairs(self.tint) do t:SetVertexColor(1, 1, 1, 1) end\n",
       "the slot's tint left uncoloured",
       expect="look-heritage: the reason is carried by the slot's tint",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif mode == \"off\" then\n\t\tself:Tint(NEUTRAL",
       "\tif false then\n\t\tself:Tint(NEUTRAL",
       "the marker switched off and the glow still carries the reason",
       expect="with the marker off the glow still carries the reason",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal bar = mode ~= \"off\" and (mode == \"stripe\" or mode == \"both\" or not icon)\n",
       "\tlocal bar = mode ~= \"off\" and (mode == \"stripe\" or mode == \"both\")\n",
       "nothing carries the reason with the icon off",
       expect="with the icon off nothing carries the reason",
       script="runscenarios.py")

# --- the slot and the icon -------------------------------------------------

_m(HERITAGE,
       "if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end",
       "if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end",
       "the sweep's edge round on a square slot",
       expect="the sweep's edge is round on a square slot",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal _, _, icon = SlotSize(p.height or 44, p.width)\n\treturn icon\n",
       "\tlocal _, _, icon = SlotSize(p.height or 44, p.width)\n\treturn icon + 3\n",
       "Options states an icon size the look does not draw",
       expect="and Options says",
       script="runscenarios.py")

_m(HERITAGE,
       "local function SlotGap(H) return math.max(1.5, H * 0.035) end",
       "local function SlotGap(H) return -3 end",
       "the slot over the frame's gold",
       expect="the slot is over the frame's gold",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal textX = showIcon and (sx + S + 7) or math.floor(e + 9 + 0.5)\n",
       "\tlocal textX = showIcon and (sx + S - 4) or math.floor(e + 9 + 0.5)\n",
       "the lines start over the slot",
       expect="the name starts over the slot",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.barX0, self.barX1 = textX, W - e - 6\n",
       "\tself.barX0, self.barX1 = textX, W + 6\n",
       "the bar runs out of the frame",
       expect="the bar leaves the frame",
       script="runscenarios.py")

_m(HERITAGE,
       "math.max(8, math.min(sub + 6, math.floor(bottom - top - 1)))",
       "sub + 6",
       "a chip taller than the room between the frame and the bar",
       expect="chip leaves the frame",
       script="runscenarios.py")

_m(HERITAGE,
       "\tclassSoften = 0.40,\n",
       "\tclassSoften = 0,\n",
       "class colours left as the class paints them, dark on the stone",
       expect="the text reads on the stone",
       script="runscenarios.py")

# --- the stone and the text ------------------------------------------------

_m(HERITAGE,
       "\tif ratio(0) >= minimum then return r, g, b end\n",
       "\tif true then return r, g, b end\n",
       "colours not lifted to read on the stone",
       expect="on the stone, under",
       script="runscenarios.py")

_m(HERITAGE,
       "local GROUND = 0.056\n",
       "local GROUND = 0.012\n",
       "colours lifted against a ground darker than the stone",
       expect="the look lifts its colours against a ground",
       script="runscenarios.py")

# --- the motion ------------------------------------------------------------

_m(HERITAGE,
       "\tif isNew then\n\t\tself.pulseSpent = nil\n",
       "\tif true then\n\t\tself.pulseSpent = nil\n",
       "the frame catches the light on every repaint",
       expect="the arrival played again on a repaint",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tif full then\n\t\t\tEach(self.flare, \"SetVertexColor\", WARM_GOLD[1]",
       "\t\tif true then\n\t\t\tEach(self.flare, \"SetVertexColor\", WARM_GOLD[1]",
       "the frame catches the light on Calm",
       expect="with Effects on Calm the",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif kind ~= \"cast\" then return end\n",
       "",
       "a cast nobody confirmed flashes as a landing",
       expect="a cast nobody confirmed got a flourish",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\t\tself.fx:Refuse(1.00, 0.36, 0.22, 0.85)\n",
       "\t\t\tself.fx:Land(1.00, 0.36, 0.22, 0.85)\n",
       "a refusal spreads rings as a landing does",
       expect="a refusal spread the landing's rings",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tself.flash:SetVertexColor(1, 0.92, 0.60, 1)\n\t\tPlayAll(self.flashAnims)\n",
       "\t\tself.flash:SetVertexColor(1, 0.92, 0.60, 1)\n",
       "a landed buff without the activation flash",
       expect="a landed buff did not flash the icon",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif self.refused then\n\t\tkit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)\n\telse\n\t\tkit.icon:SetVertexColor(v, v, v)\n\tend\n\tkit.icon:SetDesaturated(self.combat and true or false)\n\tif kit.sub:IsShown()",
       "\tkit.icon:SetVertexColor(v, v, v)\n\tkit.icon:SetDesaturated(self.combat and true or false)\n\tif kit.sub:IsShown()",
       "the refused icon not red",
       expect="the refused icon is not red",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tC_Timer.After(BREATHS * BREATH * 2, function()\n",
       "\t\tC_Timer.After(1e9, function()\n",
       "the owed breath never settles",
       expect="the owed breath still loops after its three breaths",
       script="runscenarios.py")

_m(HERITAGE,
       "local BREATH = 1.3\n",
       "local BREATH = 3\n",
       "a breath six seconds round",
       expect="the owed breath is",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.pulse = { anim(proc), anim(warm), anim(frame) }\n",
       "\tself.pulse = { anim(proc), anim(warm) }\n",
       "the frame's gold does not breathe with the glow",
       expect="look-heritage: owed breathes three times",
       script="runscenarios.py")

_m(HERITAGE,
       "\tkit.textLayer:SetFrameLevel(base + 4)\n\n\t-- The glint",
       "\tkit.textLayer:SetFrameLevel(base + 1)\n\n\t-- The glint",
       "the text under the frames of light",
       expect="is not beneath the text",
       script="runscenarios.py")

_m(HERITAGE,
       "kit.RingArt(ART .. \"Ring\", 0.74, 0.89)",
       "kit.RingArt(ART .. \"Ring\", 0.74, 0.60)",
       "the ring held to less room than its art takes",
       expect="Heritage_Ring is seen out to",
       script="runscenarios.py")

# --- the fight and leaving -------------------------------------------------

_m(HERITAGE,
       "\t\tt:SetDesaturated(on)\n",
       "\t\tt:SetDesaturated(false)\n",
       "the gold keeps its colour in a fight",
       expect="did not turn to iron",
       script="runscenarios.py")

_m(HERITAGE,
       "\ticon:SetAlpha(1)\n\ticon:SetVertexColor(1, 1, 1)\n\ticon:SetDesaturated(false)\n",
       "\ticon:SetAlpha(1)\n\ticon:SetDesaturated(false)\n",
       "the icon left dimmed for the next look",
       expect="left the icon dimmed on glass",
       script="runscenarios.py")

_m(HERITAGE,
       "\tkit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)\n\tkit.textLayer:SetAlpha(1)\n\tkit.sub:SetShadowOffset(0, 0)\n",
       "\tkit.sub:SetShadowOffset(0, 0)\n",
       "the text's level and alpha not put back",
       expect="the text's level was not put back",
       script="runscenarios.py")

# --- the list --------------------------------------------------------------

_m(HERITAGE,
       "\t\tself.drawer[i]:SetShown(not ((above and bottomRow) or (not above and topRow)))\n",
       "\t\tself.drawer[i]:SetShown(true)\n",
       "the drawer's row at the panel drawn twice",
       expect="the drawer shows",
       script="runscenarios.py")

# --- the art, the toc and the translations ---------------------------------

_m(HERITAGE,
       "\tself.gloss = tex(art, \"ARTWORK\", 3, \"Gloss\")\n",
       "\tself.gloss = tex(art, \"ARTWORK\", 3, \"Gloss\")\n\tself.gloss:SetTexture(\"Interface\\\\Buttons\\\\WHITE8X8\")\n",
       "a texture of the client's in a look that draws its own",
       expect="which is not its own art",
       script="runscenarios.py")

_m("Manners.toc",
       "Looks\\Heritage.lua\n",
       "",
       "the look left out of the toc",
       expect="no look is registered as heritage",
       script="runscenarios.py")

_m("Locales/deDE.lua",
       "L[\"Heritage -- stone and gold, like the first interface\"] = \"Erbe",
       "L[\"Heritage -- stone and gold, like the first interface\"] = \"Heritage",
       "the look's name left in English in German",
       expect="deDE's translation of the look's name",
       script="runscenarios.py")

_m("tools/make_heritage_textures.py",
       "    rng = np.random.default_rng(seed)\n",
       "    rng = np.random.default_rng()\n",
       "texture noise seeded from the clock",
       expect="differs between two runs",
       script="runscenarios.py")

_m("Options/Look.lua",
       "disabled = function() return not P().showIcon or P().style == \"heritage\" end,",
       "disabled = function() return not P().showIcon end,",
       "the round icon toggle live on a square slot",
       expect="the round icon toggle is live on a square slot",
       script="runscenarios.py")
