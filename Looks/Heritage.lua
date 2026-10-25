-- Manners -- the Heritage look: the prompt as a unit frame of the game's first
-- interface.
--
-- Not a rectangle. A round portrait, the spell's icon, sits in a thick gold ring
-- that is taller than everything beside it, with a gold wing of blades fanning
-- out of the ring's upper left and a curl below it. Beside it, tucked under the
-- ring, a gold-bordered body holds a name banner (the name, centred, on a ground
-- tinted in the reason's colour, as the game tints a name by whom it is) and a
-- status bar under it (the reason, small and white with a shadow, on the bar).
-- A level badge sits on the ring's lower right and carries the count (+2); the
-- bound key has a small tab at the banner's end.
--
-- The bar is the favour's time: full and green while there is plenty, yellow and
-- then red as it runs out, drained from the right as a health bar is; with no
-- clock to show (a passer-by, your group, your own buff) it stands full in the
-- blue of a mana bar. While the global cooldown runs, a blue bar drains across it
-- the same way, and the sweep runs round the portrait.
--
-- It is still at rest, and moves in the idiom of the unit frame:
--   * owed: the ring, and the gold of the body's border, catch a slow glow, as the
--     frame glows while resting: three breaths and still;
--   * arriving: the panel fades in (Prompt's entrance), the portrait flashes and a
--     glint runs along the banner;
--   * landed: a gold flash in the portrait, a ring of light from it, the border
--     brightening, a glint along the bar, the bar's green flashing;
--   * refused: the portrait turns the red of an out-of-range icon, the banner
--     flashes red and shakes a little, a ring snaps in, and the text shakes
--     (Prompt's);
--   * in a fight: the red glow the frame wears in combat, round the ring and the
--     border, still.
-- "Calm" is fades only: the entrance, and nothing loops or moves.
--
-- Where the reason lives:
--   * the banner, whatever the marker's mode but "off" (then it is a neutral
--     gold-brown);
--   * a soft ring just inside the portrait's edge in the reason's colour, with the
--     icon on and the mode "icon" or "both" (the "ring");
--   * the pip of each row of the list.
--
-- Every region is a texture from Textures/Heritage (tools/make_heritage_textures.py),
-- none of the client's: a game texture cannot be drawn by the preview, and the
-- clients do not keep the same ones. The gold is baked, because it is
-- decoration; what means something -- the banner, the rim, the pips, the lights --
-- is white or grey art coloured by SetVertexColor, so one file serves all six
-- reasons, both palettes, a custom marker colour and the outcomes. The interface
-- this file implements is described at the top of Looks/Looks.lua.
--
-- Rules it keeps:
--   * the whole frame is fitted into the prompt's width and height: the portrait
--     is as tall as the frame, the frame is no taller than the prompt and no
--     taller than 38% of its width, and the wing, the ring, the badge and the lights
--     stay inside (the secure button covers the prompt, so the whole look takes
--     clicks and the drag);
--   * no additive light at rest: the lights are ADD, parked at nothing, and none
--     stays lit for long (the breath is three breaths and a rest, a flourish is
--     gone within 0.6 s). A fight's red glow is the one steady light, dim;
--   * the text stands on the banner and the bar, which are deep enough for it
--     (the banner is held to a luminance, the bar's colours are chosen), and it
--     never reaches the ring, the wing or the border; the lights are under it;
--   * the icon is always round, whatever "Round the icon off" says, and the
--     portrait sizes it from the frame's height (Options says so);
--   * a class-coloured name is taken three-fifths of the way to white, so the
--     darker classes read on the banner.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Heritage\\Heritage_"

local Heritage = ns.Looks.Register("heritage", {
	name = L["Heritage -- stone and gold, like the first interface"],
	title = L["Heritage"],
	description = L["stone and gold, like the first interface"],
	order = 5,
	-- The frame holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	-- The banner is a deep colour and a class's own is dark on it: a name is
	-- taken most of the way to white, so a death knight's red and a warlock's
	-- purple still read.
	classSoften = 0.60,
})

-- The portrait's file (CELL_ASPECT, RING_CX, RING_IN and RING_OUT in
-- tools/make_heritage_textures.py, which must agree): the cell is
-- CELL times as wide as the frame is high, the ring's middle is RING_CX of the
-- height from the left, and its edge and outer edge are RING_IN and RING_OUT of
-- it. The icon runs ICON_OVER under the ring's inner edge.
local CELL, RING_CX = 1.6, 1.0
local RING_IN, RING_OUT, ICON_OVER = 0.31, 0.43, 0.012
-- The aura's file has the ring's outer edge at this fraction of its half-width.
local AURA_AT = RING_OUT / 0.5
-- The body's border, in texels of its 128 file (quarter 32): the gold's width and
-- where the border ends (ROD and INSET_TEXELS in the generator), and how far the
-- glow reaches outside it.
local ROD_TEXELS, INSET_TEXELS, GLOW_OUT = 3.2, 4.7, 6
-- The ring of light's file: its line is at 0.74 of the half-width, and nothing is
-- seen beyond 0.89 of it.
local RING_PEAK, RING_EDGE = 0.74, 0.89

-- The banner's brightest end is held to this luminance on a dark panel, so white
-- text reads on it at 4.5:1 or more and a softened class colour at 3:1 or more;
-- on a light panel it is held to at least PALE, so dark text does.
local BANNER_LUM, PALE_LUM = 0.10, 0.55
-- The bar's colours, deep enough for white text: a favour with plenty of time,
-- little, and nearly none; a bar with no clock to show.
local HEALTH = { 0.09, 0.42, 0.11 }
local WARN = { 0.44, 0.34, 0.05 }
local LOW = { 0.58, 0.12, 0.09 }
local MANA = { 0.10, 0.18, 0.55 }
local TRACK = { 0.03, 0.03, 0.04 }
-- What a reason's absence is painted in: a neutral gold-brown.
local NEUTRAL = { 0.66, 0.58, 0.36 }
local WARM_GOLD = { 1.00, 0.84, 0.50 }
local PALE_GOLD = { 1.00, 0.86, 0.52 }
local FIGHT_RED = { 1.00, 0.20, 0.14 }
local WHITE_TEXT = { 0.97, 0.96, 0.92 }
-- The outcomes' own colours.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- The icon of an out-of-range button, and what a fight does to the text and icon.
local OUT_OF_RANGE = { 1.00, 0.36, 0.32 }
local TEXT_COMBAT, ICON_COMBAT = 0.88, 0.78
-- The owed breath: the glow lit to these and back, this many breaths of
-- 2.6 s, then it settles.
local AURA_PEAK, RIM_PEAK = 0.62, 0.30
local BREATHS = 3
local BREATH = 1.3
-- The fight's glow, and the longest an additive flourish may stay lit.
local FIGHT_AURA, FIGHT_BORDER = 0.50, 0.55
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end

local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Lum(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

-- A colour scaled towards black until its luminance is at most `limit`, keeping
-- its hue.
local function Deepen(r, g, b, limit)
	if Lum(r, g, b) <= limit then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 14 do
		local k = (lo + hi) / 2
		if Lum(r * k, g * k, b * k) <= limit then lo = k else hi = k end
	end
	return r * lo, g * lo, b * lo
end

-- A colour taken towards white until its luminance is at least `limit`.
local function Pale(r, g, b, limit)
	if Lum(r, g, b) >= limit then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 14 do
		local t = (lo + hi) / 2
		if Lum(r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t) >= limit then hi = t else lo = t end
	end
	return r + (1 - r) * hi, g + (1 - g) * hi, b + (1 - b) * hi
end

-- Whether this client reads an English string in its own language; the
-- verdict words are new, and a German player is better served by the lines
-- that are translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

---------------------------------------------------------------------------
-- geometry: the frame, worked out once a layout, never per paint
---------------------------------------------------------------------------

-- Everything is measured from the prompt's own top left, y running down. The
-- frame is as tall as the prompt, but no taller than 38% of its width; narrower
-- than that and it is centred in the height. `two`: whether the second line is
-- up; `icon`: whether the portrait is.
local function Geometry(W, H, fs, two, icon)
	local g = {}
	local u = math.min(H, 0.38 * W)
	g.u, g.fy = u, (H - u) / 2
	local sub = SubSize(fs)
	-- The margin between the body and the frame's top and bottom: the portrait
	-- stands this much taller than the body.
	local m = Clamp(0.09 * u, 2.4, 8)
	-- The border's gold, its corner piece, and where the border ends.
	local b = Clamp(0.04 * u, 1.2, 2.4)
	local c = b * 32 / ROD_TEXELS
	local ib = INSET_TEXELS / 32 * c
	local avail = math.max(8, u - 2 * m - 2 * ib - 1)
	local bh, rh
	if two then
		local wantB, wantR = fs + 3, sub + 3
		local total = wantB + wantR
		if avail >= total then
			local extra = avail - total
			bh = math.min(wantB + extra * wantB / total, fs + 9)
			rh = math.min(wantR + extra * wantR / total, sub + 8)
		else
			bh = avail * wantB / total
			rh = avail - bh
		end
	else
		rh = math.min(Clamp(0.2 * u, 3.5, 8), avail * 0.4)
		bh = math.min(fs + 9, avail - rh)
	end
	bh, rh = math.max(4, bh), math.max(2, rh)
	local bodyH = 2 * ib + bh + 1 + rh
	local top = g.fy + (u - bodyH) / 2
	g.m, g.b, g.ib, g.c = m, b, ib, math.min(c, bodyH / 2)
	g.bodyTop, g.bodyBottom, g.bodyH = top, top + bodyH, bodyH
	g.bannerTop, g.bannerH = top + ib, bh
	g.barTop, g.barH = top + ib + bh + 1, rh
	g.bannerMid = g.bannerTop + bh / 2
	g.barMid = g.barTop + rh / 2
	-- Sideways: the body ends a little inside the prompt, which is also the room
	-- a refusal's shake has.
	local inset = math.max(3, 0.09 * u)
	g.bx1 = W - inset
	g.bannerX1 = g.bx1 - ib
	if icon then
		g.cx, g.cy = RING_CX * u, H / 2
		g.ri, g.ro = RING_IN * u, RING_OUT * u
		g.iconSize = math.floor(2 * (g.ri + ICON_OVER * u) + 0.5)
		g.bx0 = g.cx
		g.vis0 = g.cx + g.ri + 0.5
		g.textX = math.ceil(g.cx + g.ro + 4)
	else
		g.bx0 = math.max(3, 0.09 * u)
		g.vis0 = g.bx0 + ib
		g.textX = math.ceil(g.bx0 + ib + 6)
	end
	g.barLen = math.max(8, g.bannerX1 - g.vis0)
	return g
end

-- The height two lines need on this look: the room between the body's margins
-- must hold the banner and the bar.
function Heritage.TwoLineHeight(fontSize)
	local sub = SubSize(fontSize)
	local need = fontSize + 3 + sub + 3
	for h = 28, 200 do
		local u = h
		local m = Clamp(0.09 * u, 2.4, 8)
		local b = Clamp(0.04 * u, 1.2, 2.4)
		local ib = INSET_TEXELS / 32 * (b * 32 / ROD_TEXELS)
		if u - 2 * m - 2 * ib - 1 >= need then return h end
	end
	return 200
end

-- The marker's carriers: the ring, and the banner (the reason's colour on the
-- banner, which the marker "off" turns neutral).
local function Carriers(p)
	local mode = p.accentMode or "icon"
	local icon = p.showIcon and true or false
	local ring = icon and (mode == "icon" or mode == "both")
	local banner = mode ~= "off"
	return ring, banner
end

function Heritage.AccentCarriers(p)
	return Carriers(p)
end

-- The portrait sizes the icon from the prompt's height, so Options says so.
function Heritage.IconSize(p)
	return Geometry(p.width or 220, p.height or 44, p.fontSize or 13, false, true).iconSize
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A frame cut from one file: corners from the outer quarters, edges from a
-- thin middle strip, so they stretch without warping. TL T TR L R BL B BR, and
-- for a ground that fills the box, the middle.
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.46, 0.54, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.46, 0.54 }, { 0.75, 1, 0.46, 0.54 },
	{ 0, 0.25, 0.75, 1 }, { 0.46, 0.54, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.46, 0.54, 0.46, 0.54 },
}

local function Pieces(parent, layer, sublevel, file, blend, keep, fills)
	local s = {}
	for i = 1, fills and 9 or 8 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(CUT[i][1], CUT[i][2], CUT[i][3], CUT[i][4])
		if blend then t:SetBlendMode(blend) end
		s[i] = keep(t)
	end
	return s
end

-- A texture over a box given from `rel`'s top left, y running down.
local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

-- The pieces round a box, corners `c` square.
local function PlacePieces(s, rel, x0, y0, x1, y1, c)
	Box(s[1], rel, x0, y0, x0 + c, y0 + c)
	Box(s[2], rel, x0 + c, y0, x1 - c, y0 + c)
	Box(s[3], rel, x1 - c, y0, x1, y0 + c)
	Box(s[4], rel, x0, y0 + c, x0 + c, y1 - c)
	Box(s[5], rel, x1 - c, y0 + c, x1, y1 - c)
	Box(s[6], rel, x0, y1 - c, x0 + c, y1)
	Box(s[7], rel, x0 + c, y1 - c, x1 - c, y1)
	Box(s[8], rel, x1 - c, y1 - c, x1, y1)
	-- The middle runs a quarter-unit under the edges, so no seam shows between.
	if s[9] then Box(s[9], rel, x0 + c - 0.25, y0 + c - 0.25, x1 - c + 0.25, y1 - c + 0.25) end
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- A horizontal three-slice: caps half the height wide from the file's outer
-- quarters, the middle stretched.
local function ThreeSlice(parent, layer, sublevel, file, keep)
	local s = {}
	for i, cut in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(cut[1], cut[2], 0, 1)
		s[i] = keep(t)
	end
	return s
end

local function PlaceThree(s, box, height)
	local cap = height / 2
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[1]:SetWidth(cap)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[3]:SetWidth(cap)
	s[2]:SetPoint("TOPLEFT", s[1], "TOPRIGHT", 0, 0)
	s[2]:SetPoint("BOTTOMRIGHT", s[3], "BOTTOMLEFT", 0, 0)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights, parked at alpha 0
-- between plays, so nothing is left lit when it stops
---------------------------------------------------------------------------

local function Park(group, region, to)
	local function park() region:SetAlpha(group.to or to or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, delay, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down, delay, smoothing)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, 0, peak, up, 1, delay, "OUT")
	g.down = Alpha(g, peak, 0, down, 2, nil, smoothing or "OUT")
	Park(g, region, 0)
	return g
end

-- A glint along a run: in, along, out, all within FLOURISH of its start. The
-- offset is set for each layout.
local function Travel(region, delay)
	local g = region:CreateAnimationGroup()
	local move = g:CreateAnimation("Translation")
	move:SetDuration(FLOURISH - 0.1 - delay)
	if move.SetStartDelay then move:SetStartDelay(delay) end
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	Alpha(g, 0, 1, 0.1, 1, delay)
	Alpha(g, 1, 0, 0.2, 1, FLOURISH - 0.3)
	g.move = move
	Park(g, region, 0)
	return g
end

-- A refusal's shake: steps that sum to nothing and die away, so that the region
-- never strays more than two units.
local SHAKE_STEPS = { -2, 3, -3, 2, -1, 1 }

local function Shake(region)
	local g = region:CreateAnimationGroup()
	for i, dx in ipairs(SHAKE_STEPS) do Slide(g, dx, 0, 0.045, i) end
	return g
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Heritage:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file, blend)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	local function anim(g) anims[#anims + 1] = g return g end
	local function frame(level, parent)
		local f = keep(CreateFrame("Frame", nil, parent or art))
		f:SetFrameLevel(art:GetFrameLevel() + level)
		return f
	end

	-- The ground, on art itself, below the icon and the list's rows (which are
	-- art's too): the portrait's socket, the body's plate, its banner and bar,
	-- and the border over their edges. The icon (ARTWORK 0) is over all of them,
	-- and the ring's frame over that.
	self.socket = tex(art, "BACKGROUND", -8, "Mask")
	self.plate = Pieces(art, "BACKGROUND", -6, ART .. "Plate", nil, keep, true)
	self.banner = tex(art, "BORDER", 0, "White")
	self.bannerShine = tex(art, "BORDER", 1, "White")
	self.bannerFlash = tex(art, "BORDER", 2, "White")
	self.bannerGlint = tex(art, "BORDER", 3, "Glint", "ADD")
	self.track = tex(art, "BORDER", 1, "White")
	self.fill = tex(art, "BORDER", 2, "White")
	self.fillShine = tex(art, "BORDER", 3, "White")
	self.body = Pieces(art, "BORDER", 5, ART .. "Body", nil, keep)
	self.bannerFlash:SetAlpha(0)
	self.bannerGlint:SetAlpha(0)
	-- The reason's rim just inside the portrait's edge, on the icon.
	self.rim = tex(art, "ARTWORK", 1, "Rim")

	-- The list: a tray the body's own pieces make, and a pip for each row.
	self.tray = Pieces(art, "BACKGROUND", -7, ART .. "Plate", nil, keep, true)
	self.trayBody = Pieces(art, "BORDER", 5, ART .. "Body", nil, keep)
	self.pips, self.pipRings = {}, {}
	for i = 1, #kit.rows do
		self.pips[i] = tex(art, "ARTWORK", 0, "Mask")
		self.pipRings[i] = tex(art, "ARTWORK", 1, "Pip")
	end

	-- Over the bar and under the ring: the global cooldown's blue bar draining,
	-- the glint along the bar for a landing and its green flash, in a frame that
	-- cuts what it holds at the bar's edges.
	self.barBox = frame(1)
	if self.barBox.SetClipsChildren then self.barBox:SetClipsChildren(true) end
	self.coolTex = tex(self.barBox, "ARTWORK", 0, "White")
	self.landTex = tex(self.barBox, "ARTWORK", 1, "White")
	self.barGlint = tex(self.barBox, "ARTWORK", 2, "Glint", "ADD")
	self.coolTex:SetAlpha(0)
	self.landTex:SetAlpha(0)
	self.barGlint:SetAlpha(0)

	-- The ring and its wing, over the icon and the bar's ends.
	self.ornFrame = frame(2)
	self.orn = tex(self.ornFrame, "ARTWORK", 0, "Portrait")

	-- The lights, over the gold and under everything else: the breath, the
	-- flash on the portrait and the cursor's light, the border's light for a
	-- flourish and for the breath, and the fight's red.
	self.lightFrame = frame(3)
	self.aura = tex(self.lightFrame, "ARTWORK", 0, "Aura", "ADD")
	self.flash = tex(self.lightFrame, "ARTWORK", 1, "Mask", "ADD")
	self.hilite = tex(self.lightFrame, "ARTWORK", 1, "Mask", "ADD")
	self.aura:SetAlpha(0)
	self.flash:SetAlpha(0)
	self.hilite:SetAlpha(0)
	self.flareFrame = frame(3)
	self.flareFrame:SetAlpha(0)
	self.flare = Pieces(self.flareFrame, "ARTWORK", 0, ART .. "Glow", "ADD", keep)
	self.breathFrame = frame(3)
	self.breathFrame:SetAlpha(0)
	self.breath = Pieces(self.breathFrame, "ARTWORK", 0, ART .. "Glow", "ADD", keep)
	self.fightFrame = frame(3)
	self.fightFrame:SetAlpha(0)
	self.fightAura = tex(self.fightFrame, "ARTWORK", 0, "Aura", "ADD")
	self.fightGlow = Pieces(self.fightFrame, "ARTWORK", 0, ART .. "Glow", "ADD", keep)

	-- The rings that spread from the portrait when a buff lands and the one that
	-- snaps in when one is refused, in frames over the art and under the text.
	-- No echo: the icon stays clean.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		keep(f)
		f:SetFrameLevel(art:GetFrameLevel() + 4)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)

	-- The badge on the ring that carries the count, and the tabs at the banner's
	-- end that carry the bound key (and the count with the portrait off). Their
	-- text is on textLayer, over them.
	self.chipFrame = frame(5)
	self.badgeBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.badge = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Badge", keep)
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Badge", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Badge", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	self:BuildAnimations(anim)
	self:WrapCooldown()
end

function Heritage:BuildAnimations(anim)
	-- The owed breath: the ring's aura and the border's light on one breath
	-- (2.6 s round); see Attention for how many.
	local aura = self.aura:CreateAnimationGroup()
	aura:SetLooping("BOUNCE")
	Alpha(aura, 0, AURA_PEAK, BREATH, 1, nil, "IN_OUT")
	local border = self.breathFrame:CreateAnimationGroup()
	border:SetLooping("BOUNCE")
	Alpha(border, 0, RIM_PEAK, BREATH, 1, nil, "IN_OUT")
	self.pulse = { anim(aura), anim(border) }

	-- A favour arrives: the portrait flashes and a glint runs along the banner.
	self.arrive = { anim(Flash(self.flash, 0.55, 0.10, 0.42)) }
	self.sweep = { anim(Travel(self.bannerGlint, 0.04)) }
	-- A landing or a refusal: the border catches the light, the portrait flashes,
	-- and the bar's glint and green. The first ring is the one the scenarios watch.
	self.flareAnims = { anim(Flash(self.flareFrame, 0.55, 0.10, 0.42)) }
	self.flashAnims = { anim(Flash(self.flash, 0.60, 0.07, 0.30)) }
	self.landAnims = { anim(Travel(self.barGlint, 0)), anim(Flash(self.landTex, 0.70, 0.08, 0.40)) }
	self.burstAnim = self.fx.rings[1].land
	-- A refusal: the banner flashes red and shakes, every part of it.
	self.refuseAnims = { anim(Flash(self.bannerFlash, 0.70, 0.05, 0.28)) }
	self.shakes = { anim(Shake(self.banner)), anim(Shake(self.bannerShine)), anim(Shake(self.bannerFlash)) }

	-- The cursor's light on the portrait, both ways; from and to are set for each
	-- play.
	local hover = self.hilite:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hilite, 0)
	self.hoverAnims = { anim(hover) }

	-- The global cooldown: a blue bar over the favour's, drained from the right by
	-- sliding it out of the box that cuts it. Its length and start are set for
	-- each cooldown (Cool).
	local run = self.coolTex:CreateAnimationGroup()
	self.coolSlide = Slide(run, -10, 0, 1, 1)
	run:SetScript("OnFinished", function() self.coolTex:SetAlpha(0) end)
	run:SetScript("OnStop", function() self.coolTex:SetAlpha(0) end)
	self.coolRun = anim(run)
end

-- Prompt starts and clears the cooldown on the shared frame; the bar follows it
-- by wrapping the two calls, once, and answering only while this look is up.
function Heritage:WrapCooldown()
	local cd = self.kit.cooldown
	if not cd or cd.mannersHeritage then return end
	local set, clear = cd.SetCooldown, cd.Clear
	if type(set) ~= "function" or type(clear) ~= "function" then return end
	cd.mannersHeritage = true
	cd.SetCooldown = function(frame, start, duration, ...)
		local out = set(frame, start, duration, ...)
		if Heritage.active then Heritage:Cool(start, duration) end
		return out
	end
	cd.Clear = function(frame, ...)
		local out = clear(frame, ...)
		if Heritage.active then Heritage:CoolStop() end
		return out
	end
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Heritage:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	local two = p.showSub and H >= Heritage.TwoLineHeight(fs)
	local ringOn, bannerOn = Carriers(p)
	local g = Geometry(W, H, fs, two, showIcon)
	self.active = true
	self.p, self.W, self.H, self.sub, self.above, self.g, self.two = p, W, H, sub, above, g, two
	self.ringOn, self.bannerOn = ringOn, bannerOn
	self.showIcon = showIcon
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = sub + 6

	local base = art:GetFrameLevel()
	local bgc = type(p.bgColor) == "table" and p.bgColor or {}
	local br, bg, bb, ba = bgc[1] or 0.04, bgc[2] or 0.04, bgc[3] or 0.06, bgc[4] == nil and 0.88 or bgc[4]
	self.plateColor = { br, bg, bb, math.max(0.82, ba) }
	-- Whether the panel's colour wants light text: the banner follows it.
	self.dark = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5

	-- The body: plate, border, and the light that lies on the border.
	local c = g.c
	local gx = math.max(0.5, math.min(GLOW_OUT * c / 32, g.bodyTop - 0.4, g.m + (H - g.u) / 2 - 0.4, W - g.bx1 - 0.4))
	local cg = 32 * gx / GLOW_OUT
	PlacePieces(self.plate, art, g.bx0, g.bodyTop, g.bx1, g.bodyBottom, c)
	PlacePieces(self.body, art, g.bx0, g.bodyTop, g.bx1, g.bodyBottom, c)
	for _, set in ipairs({ self.flare, self.breath, self.fightGlow }) do
		PlacePieces(set, art, g.bx0 - gx, g.bodyTop - gx, g.bx1 + gx, g.bodyBottom + gx, cg)
	end
	Each(self.plate, "SetVertexColor", self.plateColor[1], self.plateColor[2], self.plateColor[3], self.plateColor[4])
	Each(self.flare, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	Each(self.breath, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	Each(self.fightGlow, "SetVertexColor", FIGHT_RED[1], FIGHT_RED[2], FIGHT_RED[3], 1)
	self.drawnList = nil

	-- The banner over the top row of the body, the bar over the bottom one.
	local x0, x1 = g.vis0, g.bannerX1
	Box(self.banner, art, x0, g.bannerTop, x1, g.bannerTop + g.bannerH)
	Box(self.bannerFlash, art, x0, g.bannerTop, x1, g.bannerTop + g.bannerH)
	Box(self.bannerShine, art, x0, g.bannerTop, x1, g.bannerTop + g.bannerH * 0.5)
	kit.Gradient(self.bannerShine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)
	self.bannerFlash:SetVertexColor(1, 0.22, 0.18, 1)
	Box(self.track, art, x0 - 0.7, g.barTop - 0.7, x1 + 0.7, g.barTop + g.barH + 0.7)
	self.track:SetVertexColor(TRACK[1], TRACK[2], TRACK[3], 0.95)
	self.barLen = g.barLen
	self.fill:ClearAllPoints()
	self.fill:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -g.barTop)
	self.fill:SetSize(g.barLen, g.barH)
	self.fillShine:ClearAllPoints()
	self.fillShine:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -g.barTop)
	self.fillShine:SetSize(g.barLen, math.max(1, g.barH * 0.5))
	kit.Gradient(self.fillShine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.10)
	self.barW, self.barBucket, self.barLive = nil, nil, nil

	-- The bar's overlays, in a box that is the bar.
	self.barBox:ClearAllPoints()
	self.barBox:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -g.barTop)
	self.barBox:SetSize(g.barLen, g.barH)
	self.coolTex:ClearAllPoints()
	self.coolTex:SetPoint("TOPLEFT", self.barBox, "TOPLEFT", 0, 0)
	self.coolTex:SetSize(g.barLen, g.barH)
	kit.Gradient(self.coolTex, "VERTICAL", MANA[1] * 0.72, MANA[2] * 0.72, MANA[3] * 0.72, 1, MANA[1], MANA[2], MANA[3], 1)
	self.landTex:ClearAllPoints()
	self.landTex:SetAllPoints(self.barBox)
	self.landTex:SetVertexColor(0.30, 0.95, 0.35, 1)
	local gw = math.max(14, g.barLen * 0.18)
	self.barGlint:ClearAllPoints()
	self.barGlint:SetPoint("LEFT", self.barBox, "LEFT", 0, 0)
	self.barGlint:SetSize(gw, g.barH * 1.6)
	self.barGlint:SetVertexColor(1, 0.95, 0.75, 0.9)
	self.landAnims[1].move:SetOffset(math.max(6, g.barLen - gw), 0)
	local bgw = math.max(18, g.bannerH * 2.2)
	self.bannerGlint:ClearAllPoints()
	self.bannerGlint:SetPoint("LEFT", art, "TOPLEFT", x0, -g.bannerMid)
	self.bannerGlint:SetSize(bgw, g.bannerH * 1.5)
	self.bannerGlint:SetVertexColor(1, 0.95, 0.75, 0.9)
	self.sweep[1].move:SetOffset(math.max(8, x1 - x0 - bgw), 0)
	self.coolOn = nil

	-- The portrait: its socket, the icon cut round, its rim, the ring and the wing
	-- over them, and the lights.
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.mask:SetShown(showIcon)
	self.cx, self.cy = g.cx, g.cy
	local cooldown = kit.cooldown
	if showIcon then
		local S = g.iconSize
		icon:SetSize(S, S)
		icon:SetPoint("CENTER", art, "TOPLEFT", g.cx, -g.cy)
		self.socket:ClearAllPoints()
		self.socket:SetPoint("CENTER", art, "TOPLEFT", g.cx, -g.cy)
		self.socket:SetSize(2 * g.ri + 2, 2 * g.ri + 2)
		self.socket:SetVertexColor(0.03, 0.03, 0.04, 1)
		self.rim:ClearAllPoints()
		self.rim:SetAllPoints(icon)
		self.ornFrame:ClearAllPoints()
		self.ornFrame:SetAllPoints(art)
		self.orn:ClearAllPoints()
		self.orn:SetPoint("TOPLEFT", self.ornFrame, "TOPLEFT", 0, -g.fy)
		self.orn:SetSize(CELL * g.u, g.u)
		for _, t in ipairs({ self.flash, self.hilite }) do
			t:ClearAllPoints()
			t:SetAllPoints(icon)
		end
		self.flash:SetVertexColor(1, 0.92, 0.60, 1)
		self.hilite:SetVertexColor(1, 0.88, 0.50, 0.22)
		-- The aura is the ring's light: its file puts the ring's outer edge at
		-- AURA_AT of its half-width, so it is as wide as the frame is high.
		for _, t in ipairs({ self.aura, self.fightAura }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", art, "TOPLEFT", g.cx, -g.cy)
			t:SetSize(g.ro / AURA_AT * 2, g.ro / AURA_AT * 2)
		end
		self.aura:SetVertexColor(WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
		self.fightAura:SetVertexColor(FIGHT_RED[1], FIGHT_RED[2], FIGHT_RED[3], 1)
		-- The rings spread from the ring's outer edge, round.
		local half = g.ro / RING_PEAK
		self.fx:Place(icon, half - S / 2, S)
		self.fx:Shape(false, ART .. "Ring", ART .. "Ring")
		local limitH = math.min(g.textX - g.cx - kit.TEXT_MARGIN, g.cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep is round, and its edge.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(ART .. "Mask") end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end
	self.textX = g.textX

	-- The lines: the name centred on the banner, the reason centred on the bar.
	local shift = H / 2
	self.nameY = shift - g.bannerMid + 0.5
	self.subY = shift - g.barMid + 0.5

	-- The tabs at the banner's end and the badge on the ring: as tall as the
	-- banner less its air, never taller than a third of the frame for the badge.
	local chipH = math.max(8, math.min(g.bannerH - 3, math.floor(g.bannerH)))
	self.chipH = chipH
	local badgeH = Clamp(sub + 5, 11, math.max(11, 0.4 * g.u))
	self.badgeH = badgeH
	PlaceThree(self.badge, self.badgeBox, badgeH)
	self.badgeBox:ClearAllPoints()
	if showIcon then
		-- On the ring's band, down and to the right of the portrait's middle.
		local k = (g.ri + g.ro) / 2
		self.badgeBox:SetPoint("CENTER", art, "TOPLEFT", g.cx + k * 0.64, -(g.cy + k * 0.77))
	end
	self.badgeBox:SetSize(badgeH, badgeH)
	local right = W - g.bannerX1 + 3
	PlaceThree(self.chip, self.chipBox, chipH)
	self.chipBox:ClearAllPoints()
	self.chipBox:SetPoint("RIGHT", art, "RIGHT", -right, shift - g.bannerMid)
	self.chipBox:SetSize(chipH * 1.75, chipH)
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -right, shift - g.bannerMid)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.countText, self.keyLabel = nil, nil

	self.chipFrame:SetFrameLevel(base + 5)
	self.barBox:SetFrameLevel(base + 1)
	self.ornFrame:SetFrameLevel(base + 2)
	for _, f in ipairs({ self.lightFrame, self.flareFrame, self.breathFrame, self.fightFrame }) do
		f:SetFrameLevel(base + 3)
	end
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 4) end
	kit.textLayer:SetFrameLevel(base + kit.TEXT_LEVEL)

	-- The list's tray runs from the ring's left edge (the body's, with no portrait)
	-- to the body's end, a gold pip in each row; the rows start after the pip and
	-- stop inside the tray, and each name's click area starts at the tray's edge.
	local trayX0 = showIcon and (g.cx - g.ro) or g.bx0
	self.trayX0 = trayX0
	self.pip = sub + 2
	self.pipX = trayX0 + g.ib + 4 + self.pip / 2
	self.rowX = self.pipX + self.pip / 2 + 4
	self.rowReach = self.rowX - (trayX0 + g.ib) + 1
	local rowWidth = math.max(20, g.bx1 - g.ib - self.rowX - 4)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the list
	-- for PaintQueue, the chip for Chip, the bar for PaintReason.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.socket, self.rim, self.aura, self.fightAura, self.flash, self.hilite }) do
		t:SetShown(showIcon)
	end
	self.orn:SetShown(showIcon)
	self.ornFrame:SetShown(showIcon)
	self.fx:SetShown(showIcon)
	self.rim:SetShown(showIcon and ringOn)
	self.bannerFlash:SetAlpha(0)
	self.bannerGlint:SetAlpha(0)
	self.coolTex:SetAlpha(0)
	self.landTex:SetAlpha(0)
	self.barGlint:SetAlpha(0)
	self.flash:SetAlpha(0)
	self.hilite:SetAlpha(0)
	self.aura:SetAlpha(0)
	Each(self.tray, "Hide")
	Each(self.trayBody, "Hide")
	for i = 1, #self.pips do
		self.pips[i]:Hide()
		self.pipRings[i]:Hide()
	end
	Each(self.badge, "Hide")
	Each(self.chip, "Hide")
	Each(self.keyChip, "Hide")
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self.fightFrame:SetAlpha(0)
	self.flareFrame:SetAlpha(0)
	self.breathFrame:SetAlpha(0)
	if held then self:Combat(true) end

	-- The room the count keeps at the right is none: the badge is on the ring, and
	-- the tabs make their own room (PlaceLines).
	return g.textX, 0
end

function Heritage:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- Centred, on the banner and on the bar, as a unit frame centres them.
	kit.name:SetJustifyH("CENTER")
	kit.sub:SetJustifyH("CENTER")
	-- The reason is the unit frame's small white text with a shadow, on the bar.
	kit.sub:SetTextColor(WHITE_TEXT[1], WHITE_TEXT[2], WHITE_TEXT[3], 1)
	kit.sub:SetShadowColor(0, 0, 0, 1)
	kit.sub:SetShadowOffset(1, -1)
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 1)
		kit.name:SetShadowOffset(1, -1)
	end
	-- The badge and the tabs are dark whatever the panel, so their text is pale
	-- gold as it is.
	kit.count:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	-- On the badge the count is held to what the badge's height holds: it is
	-- never taller than the ring's band is wide.
	if self.showIcon then
		local small = math.min(size, math.max(7, math.floor(self.badgeH * 0.72)))
		if small < size then kit.count:SetFont(path, small, "") end
	end
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	self.keyText:SetShadowOffset(0, 0)
end

function Heritage:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	for _, t in ipairs({ self.aura, self.flash, self.hilite, self.bannerFlash, self.bannerGlint, self.coolTex,
		self.landTex, self.barGlint }) do
		t:SetAlpha(0)
	end
	for _, f in ipairs({ self.flareFrame, self.breathFrame, self.fightFrame }) do f:SetAlpha(0) end
	for _, x in ipairs(self.own) do x:Hide() end
	self.pulseGen = (self.pulseGen or 0) + 1
	-- The shared regions, as the other looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetVertexColor(1, 1, 1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.name:SetJustifyH("LEFT")
	kit.sub:SetJustifyH("LEFT")
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	kit.sub:SetShadowOffset(0, 0)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Heritage:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit, g = kit.name, kit.sub, kit.fit, self.g
	-- The banner's end and a little air; the tabs add their room.
	local inset = (self.W - g.bannerX1) + 5
	if self.keyUp then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	if self.countMode == "chip" then inset = math.max(inset, self.chipRoom or 0) end
	-- The two points never cross: the name keeps 20 units, the room at the
	-- right gives way.
	inset = math.min(inset, math.max(0, self.W - self.textX - 20))
	self.inset = inset
	self.lineRoom = math.max(20, self.W - self.textX - inset)
	fit.room[name] = self.lineRoom
	name:SetPoint("LEFT", self.textX, self.nameY)
	name:SetPoint("RIGHT", -inset, self.nameY)
	-- The bar's own text has no tab beside it: the whole bar's room, less the air.
	local subInset = (self.W - g.bannerX1) + 5
	subInset = math.min(subInset, math.max(0, self.W - self.textX - 20))
	fit.room[sub] = math.max(20, self.W - self.textX - subInset)
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -subInset, self.subY)
end

function Heritage:Fitted() end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Heritage:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	local own = (self.W - self.g.bannerX1) + 5
	return width * least / size <= self.W - self.textX - math.max(room, own) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only
-- where a press casts something: the button armed (a fight's frozen macro
-- too, unlocked or not), never over a held panel with nothing armed, nor over
-- an outcome.
function Heritage:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
	local key = GetBindingKey(COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = GetBindingText(key, true)
		if type(text) == "string" and text ~= "" then key = text end
	end
	return key
end

-- The room the lines leave at the right for the key's tab with the count's
-- beside it: the key's room, a two-digit tab and the gap between them.
function Heritage:PairRoom()
	return (self.keyRoom or 0) + (self.chipW or 0) + 4
end

-- Run on every repaint, which is also the bar's tick. The count on the badge
-- (with the portrait up), or in a tab at the banner's end (with it off), beside
-- the key's tab; the key's tab when a key is bound. A tab steps aside for a paint
-- in which the name would otherwise be cut.
function Heritage:Chip(on)
	local kit = self.kit
	self:Clock()
	-- The width FitLine took of the name just now (every paint sets it before
	-- the chip), measured here only where it could not. Measured outright, it
	-- was a pcall on every repaint (Looks.lua: none on a per-scan path).
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW = w
			self.keyRoom = math.ceil(w) + (self.W - self.g.bannerX1) + 8
			-- A key bound anew is a tab of a new width: Prompt places the lines
			-- again, beside it.
			kit.fit.right = nil
		end
		keyUp = self:NameFits(self.keyRoom)
	end
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		-- Prompt places the lines again, and PlaceLines keeps the key's room.
		kit.fit.right = nil
	end
	if keyUp then self.keyBox:SetWidth(math.floor(self.keyW + 0.5)) end
	for _, t in ipairs(self.keyChip) do t:SetShown(keyUp) end
	self.keyText:SetShown(keyUp)

	local mode
	if on then
		if self.showIcon then
			mode = "badge"
		elseif keyUp then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(self.chipW or self.chipH * 1.75 + 10) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		text = count:GetText()
		local h = mode == "badge" and self.badgeH or self.chipH
		if text ~= self.countText or mode ~= self.countMode then
			self.countText = text
			self.countW = math.max(h * (mode == "badge" and 1 or 1.75), (kit.TextWidth(count) or self.sub) + (mode == "badge" and 5 or 8))
			if mode ~= "badge" then
				self.chipW = math.ceil(self.countW)
				self.chipRoom = self.chipW + (self.W - self.g.bannerX1) + 8
			end
		end
		if mode ~= self.countMode then
			local box = mode == "badge" and self.badgeBox or self.chipBox
			if mode == "pair" then
				self.chipBox:ClearAllPoints()
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			elseif mode == "chip" then
				self.chipBox:ClearAllPoints()
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -((self.W - self.g.bannerX1) + 3), self.H / 2 - self.g.bannerMid)
			end
			kit.count:ClearAllPoints()
			kit.count:SetPoint("CENTER", box, "CENTER", 0, 0)
		end
		if mode == "badge" then
			self.badgeBox:SetSize(math.floor(self.countW + 0.5), h)
		else
			self.chipBox:SetSize(math.floor(self.countW + 0.5), h)
		end
	end
	self.countMode = mode
	for _, t in ipairs(self.badge) do t:SetShown(mode == "badge") end
	for _, t in ipairs(self.chip) do t:SetShown(mode == "chip" or mode == "pair") end
	kit.count:SetShown(mode ~= nil)
	-- Only a tab at the banner's end takes room from the lines; PlaceLines gives
	-- a pair the room of both.
	return mode == "chip" or mode == "pair"
end

-- The bar's fill: how much of the time to return the favour is left, drained from
-- the right; full, in the blue of a mana bar, where there is no clock to show. A
-- preview shows it part-spent, so it can be seen while styling.
function Heritage:Clock()
	local frac
	local P = ns.Prompt
	if P and P.InTest and P:InTest() then
		frac = 0.62
	else
		local name = P and P.PanelName and P:PanelName()
		local debt = name and ns.owed and ns.owed[name]
		if type(debt) == "table" and type(debt.at) == "number" and ns.DebtExpiry then
			local ends, now = ns.DebtExpiry(debt), GetTime()
			if type(ends) == "number" and ends > now and ends > debt.at then
				frac = math.min(1, (ends - now) / (ends - debt.at))
			end
		end
	end
	local live = frac ~= nil
	local width = math.max(1.2, (frac or 1) * self.barLen)
	local bucket = live and math.floor(frac * 16 + 0.5) or -1
	if self.barLive == live and self.barBucket == bucket and self.barW and math.abs(width - self.barW) < 0.25 then
		return
	end
	if self.barLive ~= live or self.barBucket ~= bucket then
		self.barLive, self.barBucket = live, bucket
		self:PaintFill(live and bucket / 16 or nil)
	end
	self.barW = width
	self.fill:SetWidth(width)
	self.fillShine:SetWidth(width)
end

-- The fill's colour: green while there is time, through yellow to red as it runs
-- out; the blue of a mana bar for a bar with no clock. Lit from above.
function Heritage:PaintFill(frac)
	local r, g, b
	if frac == nil then
		r, g, b = MANA[1], MANA[2], MANA[3]
	elseif frac >= 0.5 then
		r, g, b = HEALTH[1], HEALTH[2], HEALTH[3]
	elseif frac >= 0.25 then
		local t = (0.5 - frac) / 0.25
		r, g, b = HEALTH[1] + (WARN[1] - HEALTH[1]) * t, HEALTH[2] + (WARN[2] - HEALTH[2]) * t,
			HEALTH[3] + (WARN[3] - HEALTH[3]) * t
	else
		local t = math.min(1, (0.25 - frac) / 0.20)
		r, g, b = WARN[1] + (LOW[1] - WARN[1]) * t, WARN[2] + (LOW[2] - WARN[2]) * t, WARN[3] + (LOW[3] - WARN[3]) * t
	end
	self.fillColor = { r, g, b }
	self.kit.Gradient(self.fill, "VERTICAL", r * 0.72, g * 0.72, b * 0.72, 1, r, g, b, 1)
	self:BarAlpha()
end

-- The fill's strength: lit for a favour with a clock, quieter for the rest.
function Heritage:BarAlpha()
	self.fill:SetAlpha(self.barLive and 1 or 0.85)
	self.fillShine:SetAlpha(1)
end

---------------------------------------------------------------------------
-- the global cooldown
---------------------------------------------------------------------------

-- The cooldown began at `start` and lasts `duration`: the blue bar covers the bar
-- from the left, and slides out to the left over what is left of it, so its right
-- end drains as a bar does. A translation inside a box that cuts it, so it
-- follows the real clock without a frame script, and begun again by every new
-- cooldown (a cast during the global cooldown moves the end).
function Heritage:Cool(start, duration)
	if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then return self:CoolStop() end
	local left = start + duration - GetTime()
	if left <= 0.02 then return self:CoolStop() end
	if not self.showIcon then return end
	self.coolOn = true
	local done = Clamp(1 - left / duration, 0, 0.98)
	self.coolRun:Stop()
	self.coolTex:ClearAllPoints()
	self.coolTex:SetPoint("TOPLEFT", self.barBox, "TOPLEFT", -done * self.barLen, 0)
	self.coolSlide:SetOffset(-(1 - done) * self.barLen, 0)
	self.coolSlide:SetDuration(left)
	self.coolTex:SetAlpha(0.92)
	self.coolRun:Play()
end

function Heritage:CoolStop()
	if not self.coolOn and not self.coolRun:IsPlaying() then return end
	self.coolOn = nil
	self.coolRun:Stop()
	self.coolTex:ClearAllPoints()
	self.coolTex:SetPoint("TOPLEFT", self.barBox, "TOPLEFT", 0, 0)
	self.coolTex:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The banner in the reason's colour, deepened to a luminance the name reads on
-- (or lightened on a light panel); the rim in the colour itself. An outcome calls
-- it with its own colour.
function Heritage:Tint(r, g, b, outcome)
	local kit = self.kit
	local tr, tg, tb
	if self.dark then
		tr, tg, tb = Deepen(r, g, b, BANNER_LUM)
		kit.Gradient(self.banner, "VERTICAL", tr * 0.70, tg * 0.70, tb * 0.70, 1, tr, tg, tb, 1)
	else
		tr, tg, tb = Pale(r, g, b, PALE_LUM)
		kit.Gradient(self.banner, "VERTICAL", tr * 0.86, tg * 0.86, tb * 0.86, 1, tr, tg, tb, 1)
	end
	self.rim:SetVertexColor(r, g, b, 1)
	self.bannerColour = { tr, tg, tb }
	self.tinted = { r, g, b }
end

function Heritage:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
	else
		self:Tint(r, g, b)
	end
	-- A refusal reddened the icon; a fight keeps it dim.
	self.refused = nil
	local k = self.combat and ICON_COMBAT or 1
	self.kit.icon:SetVertexColor(k, k, k)
	self.kit.icon:SetDesaturated(false)
end

-- The fight: the red glow round the ring and the border, still, the icon and the
-- text dimmed a little and the lights that loop put out. The reason stays.
function Heritage:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	local v = on and ICON_COMBAT or 1
	if self.refused then
		kit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)
	else
		kit.icon:SetVertexColor(v, v, v)
	end
	kit.icon:SetDesaturated(false)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	self.fightFrame:SetAlpha(on and 1 or 0)
	self.fightAura:SetAlpha(on and FIGHT_AURA or 0)
	for _, t in ipairs(self.fightGlow) do t:SetAlpha(on and FIGHT_BORDER or 0) end
	if on then
		self:StopAttention()
		for _, g in ipairs(self.arrive) do g:Stop() end
		self:StopFlourishes()
	end
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

-- The breathing, let go: after its breaths, and on Calm. The glow settles.
function Heritage:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.aura:SetAlpha(0)
	self.breathFrame:SetAlpha(0)
end

function Heritage:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- The portrait flashes for a new favour, never for a new face; and a
		-- glint runs along the banner.
		if full then
			PlayAll(self.sweep)
			if self.showIcon then PlayAll(self.arrive) end
		end
	end
	if flashStyle ~= "pulse" then
		self:StopAttention()
		return
	end
	if not full or self.pulseSpent or not self.showIcon then
		-- Calm, or breathed its fill, or nothing to glow: nothing loops.
		self:HoldPulse()
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps the
	-- breathing going but takes its own three breaths, not what is left of the
	-- last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self.aura:SetAlpha(0)
		self.breathFrame:SetAlpha(0)
		self.pulse[1]:Play()
		self.pulse[2]:Play()
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Heritage.pulseGen or not Heritage.active then return end
			Heritage.pulseSpent = true
			if Heritage.pulse[1]:IsPlaying() then Heritage:HoldPulse() end
		end)
	end
end

function Heritage:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.aura:SetAlpha(0)
	self.breathFrame:SetAlpha(0)
end

-- The lights are ADD at the peaks set here: the amplitudes ride on the vertex
-- alphas, the animation on the texture's own alpha.
function Heritage:Flourish(kind)
	-- A refusal: the border flares red and amber, the portrait flashes red, a ring
	-- snaps in, and the banner flashes red and shakes. The text's shake is
	-- Prompt's.
	if kind == "failed" then
		Each(self.flare, "SetVertexColor", 1, 0.34, 0.20, 1)
		PlayAll(self.flareAnims)
		PlayAll(self.refuseAnims)
		PlayAll(self.shakes)
		if self.kit.icon:IsShown() then
			self.flash:SetVertexColor(1, 0.26, 0.20, 1)
			PlayAll(self.flashAnims)
			self.fx:Refuse(1.00, 0.36, 0.22, 0.85)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	Each(self.flare, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	PlayAll(self.flareAnims)
	PlayAll(self.landAnims)
	if self.kit.icon:IsShown() then
		-- The gold flash on the portrait, and the light that goes out from it.
		self.flash:SetVertexColor(1, 0.92, 0.60, 1)
		PlayAll(self.flashAnims)
		self.fx:Land(1.0, 0.88, 0.50, 0.75)
	end
end

function Heritage:StopFlourishes()
	for _, list in ipairs({ self.arrive, self.flareAnims, self.flashAnims, self.landAnims, self.refuseAnims, self.shakes,
		self.sweep }) do
		for _, g in ipairs(list) do g:Stop() end
	end
	self.fx:Stop()
end

function Heritage:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hilite
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 1 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so the
-- eye never has to find the person again. The banner takes the outcome's colour;
-- a refusal reddens the icon, as an out-of-range button is.
function Heritage:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or (Known("could not buff") and L["could not buff"])
	elseif kind == "sent" then
		word = Known("sent, unconfirmed") and L["sent, unconfirmed"]
	else
		word = Known("buffed") and L["buffed"]
	end
	if who and kit.sub:IsShown() then
		kit.SetLine(kit.name, who)
		-- Not in this client's language yet: the built-in looks' second line,
		-- which is, as the verdict. The name stays put in every language.
		if not word then word = sub or "" end
	else
		-- Nobody to name, or no second line to hold the verdict: the built-in
		-- looks' headline, which says both what happened and to whom.
		kit.SetLine(kit.name, lead)
		word = sub or ""
	end
	self.outcomeOn = true
	-- The owed breathing is about the favour, not the click: it stops. Attention
	-- starts it again for the next person owed.
	self:HoldPulse()
	self:Tint(o[1], o[2], o[3], true)
	self.refused = kind == "failed"
	local v = self.combat and ICON_COMBAT or 1
	if self.refused then
		kit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)
	else
		kit.icon:SetVertexColor(v, v, v)
	end
	kit.icon:SetDesaturated(false)
	if kit.sub:IsShown() then kit.SetLine(kit.sub, word) end
end

function Heritage:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list hangs as a tray of party frames under the frame (or over it): the
-- body's own border round a dark plate, a gold pip in each row in its reason's
-- colour.
function Heritage:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.pips do
		if not (list and i <= shown) then
			self.pips[i]:Hide()
			self.pipRings[i]:Hide()
		end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.tray, "Hide")
			Each(self.trayBody, "Hide")
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.pips[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.pips[i]:Show()
		self.pipRings[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local g, pitch = self.g, self.pitch
	local depth = shown * pitch + 2 * g.ib + 3
	local c = math.min(g.c, depth / 2)
	local x0, x1 = self.trayX0, g.bx1
	local y0, y1
	if above then
		y0, y1 = -1 - depth, -1
	else
		y0, y1 = self.H + 1, self.H + 1 + depth
	end
	PlacePieces(self.tray, art, x0, y0, x1, y1, c)
	PlacePieces(self.trayBody, art, x0, y0, x1, y1, c)
	Each(self.tray, "SetVertexColor", self.plateColor[1], self.plateColor[2], self.plateColor[3], self.plateColor[4])
	Each(self.tray, "Show")
	Each(self.trayBody, "Show")

	local pip = self.pip
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y = y0 + g.ib + 1.5 + (i - 0.5) * pitch
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		self.pipRings[i]:ClearAllPoints()
		self.pipRings[i]:SetPoint("CENTER", art, "TOPLEFT", self.pipX, -y)
		self.pipRings[i]:SetSize(pip, pip)
		self.pips[i]:ClearAllPoints()
		self.pips[i]:SetPoint("CENTER", art, "TOPLEFT", self.pipX, -y)
		self.pips[i]:SetSize(pip * 0.56, pip * 0.56)
	end
end
