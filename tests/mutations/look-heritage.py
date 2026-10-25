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
       "\tself.rim:SetVertexColor(r, g, b, 1)\n",
       "\tself.rim:SetVertexColor(1, 1, 1, 1)\n",
       "the portrait's ring left uncoloured",
       expect="look-heritage: the reason is carried by the banner",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif mode == \"off\" then\n\t\tself:Tint(NEUTRAL",
       "\tif false then\n\t\tself:Tint(NEUTRAL",
       "the marker switched off and the banner still carries the reason",
       expect="with the marker off the banner",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal banner = mode ~= \"off\"\n",
       "\tlocal banner = mode ~= \"off\" and icon\n",
       "nothing carries the reason with the icon off",
       expect="with the icon off the banner should carry the reason alone",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif Lum(r, g, b) <= limit then return r, g, b end\n\tlocal lo, hi = 0, 1\n\tfor _ = 1, 14 do\n\t\tlocal k = (lo + hi) / 2",
       "\tif true then return r, g, b end\n\tlocal lo, hi = 0, 1\n\tfor _ = 1, 14 do\n\t\tlocal k = (lo + hi) / 2",
       "the banner not deepened for the name to read on",
       expect="the name on the banner for",
       script="runscenarios.py")

_m(HERITAGE,
       "local BANNER_LUM, PALE_LUM = 0.10, 0.55\n",
       "local BANNER_LUM, PALE_LUM = 0.30, 0.55\n",
       "the banner held to a luminance the name does not read on",
       expect="the name on the banner for",
       script="runscenarios.py")

_m(HERITAGE,
       "local BANNER_LUM, PALE_LUM = 0.10, 0.55\n",
       "local BANNER_LUM, PALE_LUM = 0.10, 0.10\n",
       "a light panel's banner left too dark for dark text",
       expect="on the pale banner",
       script="runscenarios.py")

_m(HERITAGE,
       "\tclassSoften = 0.60,\n",
       "\tclassSoften = 0,\n",
       "class colours left as the class paints them, dark on the banner",
       expect="on the banner",
       script="runscenarios.py")

_m(HERITAGE,
       "local HEALTH = { 0.09, 0.42, 0.11 }\n",
       "local HEALTH = { 0.20, 0.80, 0.25 }\n",
       "the bar's green too bright for the reason's white text",
       expect="the reason line on the bar",
       script="runscenarios.py")

# --- the frame, the portrait and the body ----------------------------------

_m(HERITAGE,
       "\tlocal u = math.min(H, 0.38 * W)\n",
       "\tlocal u = H * 1.15\n",
       "the frame taller than the prompt",
       expect="is outside the prompt",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal u = math.min(H, 0.38 * W)\n",
       "\tlocal u = math.min(H, 0.9 * W)\n",
       "the frame as tall as the prompt's height in a narrow prompt",
       expect="its share of the width",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal m = Clamp(0.09 * u, 2.4, 8)\n\t-- The border's gold",
       "\tlocal m = 0\n\t-- The border's gold",
       "the body as tall as the frame: the portrait no taller than it",
       expect="is not taller than the body",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tg.textX = math.ceil(g.cx + g.ro + 4)\n",
       "\t\tg.textX = math.ceil(g.cx + g.ro - 6)\n",
       "the lines start over the ring",
       expect="starts over the ring",
       script="runscenarios.py")

_m(HERITAGE,
       "\tg.bannerX1 = g.bx1 - ib\n",
       "\tg.bannerX1 = g.bx1 + 6\n",
       "the banner and the bar run out of the body",
       expect="the banner is not inside the body's border",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.subY = shift - g.barMid + 0.5\n",
       "\tself.subY = shift - g.barMid + 7\n",
       "the reason line off the bar",
       expect="the reason is not on the bar",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif s[9] then Box(s[9], rel, x0 + c - 0.25, y0 + c - 0.25, x1 - c + 0.25, y1 - c + 0.25) end\n",
       "\tif s[9] then Box(s[9], rel, x0 + c + 6, y0 + c - 0.25, x1 - c + 0.25, y1 - c + 0.25) end\n",
       "the plate's middle not meeting its corners",
       expect="the plate's middle does not meet its corners",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tif u - 2 * m - 2 * ib - 1 >= need then return h end\n",
       "\t\tif u - 2 * m - 2 * ib - 1 >= need - 12 then return h end\n",
       "two lines asked for in a prompt too short to hold them",
       expect="look-heritage: nothing overlaps or leaves the prompt",
       script="runscenarios.py")

_m(HERITAGE,
       "\treturn Geometry(p.width or 220, p.height or 44, p.fontSize or 13, false, true).iconSize\n",
       "\treturn Geometry(p.width or 220, p.height or 44, p.fontSize or 13, false, true).iconSize + 3\n",
       "Options states an icon size the look does not draw",
       expect="and Options says",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\ticon:AddMaskTexture(self.mask)\n\t\tself.masked = true\n",
       "\t\tself.masked = true\n",
       "the portrait not cut round",
       expect="the icon is not cut round by the mask",
       script="runscenarios.py")

_m(HERITAGE,
       "if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end",
       "if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end",
       "the sweep's edge square on a round portrait",
       expect="the sweep's edge is not round",
       script="runscenarios.py")

_m(HERITAGE,
       "\tlocal chipH = math.max(8, math.min(g.bannerH - 3, math.floor(g.bannerH)))\n",
       "\tlocal chipH = g.bannerH + 6\n",
       "a tab taller than the banner",
       expect="tab leaves the banner",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -right, shift - g.bannerMid)\n",
       "\tself.keyBox:SetPoint(\"RIGHT\", art, \"RIGHT\", -right, shift - g.barMid)\n",
       "the key's tab on the bar",
       expect="the key's tab leaves the banner",
       script="runscenarios.py")

_m(HERITAGE,
       "g.cx + k * 0.64, -(g.cy + k * 0.77))",
       "g.cx + k * 2.2, -(g.cy + k * 0.77))",
       "the badge off the ring",
       expect="the badge is not on the ring's band",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tlocal small = math.min(size, math.max(7, math.floor(self.badgeH * 0.72)))\n",
       "\t\tlocal small = size\n",
       "the count on the badge as big as the lines' font",
       expect="the count is taller than the badge",
       script="runscenarios.py")

# --- the bar ---------------------------------------------------------------

_m(HERITAGE,
       "\tlocal width = math.max(1.2, (frac or 1) * self.barLen)\n",
       "\tlocal width = math.max(1.2, 1 * self.barLen)\n",
       "the bar the same length whatever time is left",
       expect="look-heritage: the bar tracks the favour's time",
       script="runscenarios.py")

_m(HERITAGE,
       "\telseif frac >= 0.5 then\n\t\tr, g, b = HEALTH[1], HEALTH[2], HEALTH[3]\n",
       "\telseif frac >= 0.5 then\n\t\tr, g, b = LOW[1], LOW[2], LOW[3]\n",
       "the bar not green with plenty of time",
       expect="is not green",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tr, g, b = MANA[1], MANA[2], MANA[3]\n",
       "\t\tr, g, b = HEALTH[1], HEALTH[2], HEALTH[3]\n",
       "a bar with no clock green, as a favour's",
       expect="not the blue of a mana bar",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.fill:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", x0, -g.barTop)\n",
       "\tself.fill:SetPoint(\"TOPLEFT\", art, \"TOPLEFT\", x0 + 10, -g.barTop)\n",
       "the fill not starting at the bar's left",
       expect="the fill is not drained from the right",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.coolRun:Play()\n",
       "",
       "the global cooldown not draining the bar",
       expect="does not drain a bar across the favour's",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.coolSlide:SetDuration(left)\n",
       "\tself.coolSlide:SetDuration(1)\n",
       "the cooldown's bar draining over another time than the cooldown has left",
       expect="the bar drains over",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif self.barBox.SetClipsChildren then self.barBox:SetClipsChildren(true) end\n",
       "\tif self.barBox.SetClipsChildren then self.barBox:SetClipsChildren(false) end\n",
       "the draining bar not cut at the bar's edges",
       expect="not cut at the bar's edges",
       script="runscenarios.py")

# --- the motion ------------------------------------------------------------

_m(HERITAGE,
       "\tif isNew then\n\t\tself.pulseSpent = nil\n",
       "\tif true then\n\t\tself.pulseSpent = nil\n",
       "the portrait flashes on every repaint",
       expect="the arrival played again on a repaint",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tif full then\n\t\t\tPlayAll(self.sweep)\n",
       "\t\tif true then\n\t\t\tPlayAll(self.sweep)\n",
       "the glint runs along the banner on Calm",
       expect="with Effects on Calm the",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\t\tif self.showIcon then PlayAll(self.arrive) end\n",
       "",
       "an arrival without the flash on the portrait",
       expect="the glint or the portrait's flash did not play",
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
       "a landed buff without the flash on the portrait",
       expect="a landed buff did not flash the portrait",
       script="runscenarios.py")

_m(HERITAGE,
       "\tPlayAll(self.landAnims)\n",
       "",
       "a landed buff without the glint and the green along the bar",
       expect="did not run the glint and the green along the bar",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tPlayAll(self.shakes)\n",
       "",
       "a refusal that does not shake the banner",
       expect="a refusal did not flash the banner red and shake it",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.bannerFlash:SetVertexColor(1, 0.22, 0.18, 1)\n",
       "\tself.bannerFlash:SetVertexColor(0.2, 1, 0.3, 1)\n",
       "a refusal that flashes the banner green",
       expect="the banner does not flash red",
       script="runscenarios.py")

_m(HERITAGE,
       "\tfor i, dx in ipairs(SHAKE_STEPS) do Slide(g, dx, 0, 0.045, i) end\n",
       "\tfor i, dx in ipairs(SHAKE_STEPS) do Slide(g, dx * 3, 0, 0.045, i) end\n",
       "the banner's shake wide",
       expect="the banner's shake does not settle",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif self.refused then\n\t\tkit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)\n\telse\n\t\tkit.icon:SetVertexColor(v, v, v)\n\tend\n\tkit.icon:SetDesaturated(false)\n\tif kit.sub:IsShown()",
       "\tkit.icon:SetVertexColor(v, v, v)\n\tkit.icon:SetDesaturated(false)\n\tif kit.sub:IsShown()",
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
       "\tself.pulse = { anim(aura), anim(border) }\n",
       "\tself.pulse = { anim(aura) }\n",
       "the border's gold does not breathe with the ring",
       expect="the border does not breathe with the ring",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif not full or self.pulseSpent or not self.showIcon then\n",
       "\tif not full or self.pulseSpent then\n",
       "a ring that breathes with the icon off",
       expect="with the icon off something breathes",
       script="runscenarios.py")

_m(HERITAGE,
       "\tkit.textLayer:SetFrameLevel(base + kit.TEXT_LEVEL)\n",
       "\tkit.textLayer:SetFrameLevel(base + 1)\n",
       "the text under the frames of light",
       expect="is not beneath the text",
       script="runscenarios.py")

_m(HERITAGE,
       "\tself.ornFrame:SetFrameLevel(base + 2)\n",
       "\tself.ornFrame:SetFrameLevel(base + 1)\n",
       "the ring under the bar's overlays",
       expect="the bar's overlays are not under the ring",
       script="runscenarios.py")

_m(HERITAGE,
       "local RING_PEAK, RING_EDGE = 0.74, 0.89\n",
       "local RING_PEAK, RING_EDGE = 0.74, 0.60\n",
       "the ring held to less room than its art takes",
       expect="Heritage_Ring is seen out to",
       script="runscenarios.py")

# --- the fight and leaving -------------------------------------------------

_m(HERITAGE,
       "\tself.fightFrame:SetAlpha(on and 1 or 0)\n",
       "\tself.fightFrame:SetAlpha(0)\n",
       "no red glow in a fight",
       expect="a fight does not light the red glow",
       script="runscenarios.py")

_m(HERITAGE,
       "local FIGHT_RED = { 1.00, 0.20, 0.14 }\n",
       "local FIGHT_RED = { 0.20, 0.30, 1.00 }\n",
       "a fight's glow that is not red",
       expect="is not red",
       script="runscenarios.py")

_m(HERITAGE,
       "\ticon:SetAlpha(1)\n\ticon:SetVertexColor(1, 1, 1)\n\ticon:SetDesaturated(false)\n",
       "\ticon:SetAlpha(1)\n\ticon:SetDesaturated(false)\n",
       "the icon left dimmed for the next look",
       expect="left the icon dimmed on glass",
       script="runscenarios.py")

_m(HERITAGE,
       "\tkit.textLayer:SetAlpha(1)\n\tkit.sub:SetShadowOffset(0, 0)\n",
       "\tkit.sub:SetShadowOffset(0, 0)\n",
       "the text's alpha not put back",
       expect="left the text dimmed",
       script="runscenarios.py")

_m(HERITAGE,
       "\tif self.masked then\n\t\ticon:RemoveMaskTexture(self.mask)\n\t\tself.masked = nil\n\tend\n\tself.mask:Hide()\n",
       "",
       "the portrait's mask left on the icon for the next look",
       expect="the portrait's mask still cuts the icon on glass",
       script="runscenarios.py")

# --- the list --------------------------------------------------------------

_m(HERITAGE,
       "\tEach(self.trayBody, \"Show\")\n\n\tlocal pip",
       "\n\tlocal pip",
       "the tray's border left hidden",
       expect="the tray shows",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tself.pips[i]:SetVertexColor(c[1], c[2], c[3], 1)\n",
       "\t\tself.pips[i]:SetVertexColor(1, 1, 1, 1)\n",
       "a pip not in its reason's colour",
       expect="is not in a colour of the",
       script="runscenarios.py")

_m(HERITAGE,
       "\t\tfs:SetPoint(\"LEFT\", art, \"TOPLEFT\", self.rowX, -y)\n",
       "\t\tfs:SetPoint(\"LEFT\", self.pips[i], \"RIGHT\", 6, 0)\n",
       "a row's text anchored to a region, so no name is a button",
       expect="no name is a button",
       script="runscenarios.py")

# --- the art, the toc and the translations ---------------------------------

_m(HERITAGE,
       "\tself.socket = tex(art, \"BACKGROUND\", -8, \"Mask\")\n",
       "\tself.socket = tex(art, \"BACKGROUND\", -8, \"Mask\")\n\tself.socket:SetTexture(\"Interface\\\\Buttons\\\\WHITE8X8\")\n",
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
       "the round icon toggle live on a portrait that is always round",
       expect="the round icon toggle is live on a portrait that is always round",
       script="runscenarios.py")
