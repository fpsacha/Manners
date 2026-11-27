-- Manners -- the Gearworks look: an engineer's, Gnomeregan's brass and
-- Kezan's copper, the spell under the glass of a pressure gauge.
--
-- A riveted brass instrument housing with a plate of dark enamel let into it,
-- which the words stand on. At its left the spell icon, round, under the
-- glass of a PRESSURE GAUGE taller than the housing: the DIAL round the icon
-- takes the reason's colour and the NEEDLE stands at the reason's mark, six
-- marks from a passer-by at nothing to a favour owed at full pressure. At
-- its right an open GEARBOX, taller than the housing too: three cogs (twelve
-- teeth of brass, eight of copper, eight of steel) that mesh and turn, each
-- at the speed its teeth give it, on a back of hammered iron. Along the
-- lower rim a SIGHT TUBE of liquid in the reason's colour;
-- on top a copper VENT and two brass TERMINALS. The list is a sheet of dark
-- iron in a brass strip under (or over) the housing.
--
-- Every region is a texture from Textures/Gearworks
-- (tools/make_gearworks_textures.py). The brass, the copper, the steel and
-- the enamel are baked, because they are decoration; everything that means
-- something -- the dial, the tube, the beads, the glyphs, the lights -- is
-- white or grey art coloured through Looks.Colour, so one file serves all six
-- reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-gearworks.lua):
--   * the needle SWINGS to each new reason's mark, past it and back, and to
--     nothing when a buff lands or is refused. Where it stands is a frame of
--     its sheet; the swing is a turn of the frame it stood in, and the frame
--     is changed for the new mark's as the turn ends;
--   * a favour arriving WHISTLES: a short puff from the vent and the dial
--     flashes as the needle climbs;
--   * owed, the pressure is up: the dial breathes, a warm gaslight with it,
--     the needle trembles at its mark and bubbles run through the tube
--     (Looks/Flow.lua; at rest they drift), three breaths, and then it
--     holds lit;
--   * a landing LETS THE STEAM OFF: a cloud from the vent, drawn frame by
--     frame, the cogs spin six teeth on and slow, the dial flashes, one ring
--     pulses on the glass and a second crosses the dial and leaves the brass
--     (`skyward`: the gauge stands proud of the room the rings are held to);
--   * a refusal SHORTS it: a spark jumps the terminals, frame by frame, the
--     dial blinks red and goes grey, the cogs kick back half a tooth and jam
--     until the next person, one ring snaps in; a cast nobody confirmed does
--     nothing;
--   * at rest, on Full effects, the cogs TURN, two teeth at a time (which
--     every cog ends as it began) and a glint crosses the upper rim now and
--     then; somebody new on the panel is greeted with the glint.
--     hunt35-effects lets the groups of `idle` loop with nobody owed, by
--     name; the author asked for a look that is alive at rest;
--   * no additive light at rest: the dial's flash and the spark are the only
--     ADD regions, each lit under 0.6 s and parked at nothing; the breath,
--     the gaslight, the steam, the glint and the hover are BLEND;
--   * the vent, the terminals, the steam and the spark stand over the
--     housing's top. With the list hung over the panel none of them is drawn;
--   * Calm keeps to fades: no turning, no swing, no steam, no spark, no
--     bubbles running;
--   * a fight dulls the brass and stops the cogs, dims the words and greys
--     the icon; the dial and the tube keep their colour;
--   * the icon is always round ("Round the icon off" reads nothing here) and
--     held inside the glass; on a prompt too short for the gearbox the
--     housing ends plain and the cogs are not drawn.

local _, ns = ...
local Colour = ns.Looks.Colour
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Gearworks\\Gearworks_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Gearworks = ns.Looks.Register("gearworks", {
	name = L["Gearworks -- riveted brass, a pressure gauge and turning cogs"],
	title = L["Gearworks"],
	description = L["riveted brass, a pressure gauge and turning cogs"],
	order = 9.9,
	-- The housing holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	-- The words stand on the enamel whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
	-- The painted frame (Looks/Painted.lua, art/looks/gearworks): what of this
	-- file's own art it replaces. The painting has its own housing, gauge
	-- bezel, valve and gearbox with its cogs; the dial, the needle, the steam,
	-- the spark, the glint and the list stay this file's. The sight tube has
	-- no room on the painted rims (rivets below, the words in the well): the
	-- dial carries the stripe's colour. The icon is smaller than the glass, so
	-- the dial's band and the needle lie in the glass round it.
	paintedHides = { "shadow", "shade", "body", "bezel", "dialBack", "tube", "bubbles", "ferrules", "stack", "contacts",
		"gearbox", "cogs", "cogLights", "keyChip" },
	paintedIconFill = 0.68,
})

-- MUST AGREE with tools/make_gearworks_textures.py
-- (tests/scenarios/look-gearworks.lua compares them): the icon fills this
-- much of the gauge's file and the dial's band ends here; the housing's
-- design height and its ends' width, in texels; the gearbox's file, which it
-- fills; the tube's middle from the housing's top and its height, in design
-- texels; a cog's tip circle in its file, the cogs' module in the gearbox's
-- texels, how far a tooth stands proud of the pitch circle in modules, their
-- teeth, the driving cog's axle in the gearbox and where the other two sit
-- round it; the needle's step
-- between two marks and its sheet; the steam's sheet and the spark's; the
-- tag's caps, the mask's fill and where the ring file's line sits.
local ICON_FRAME = 0.54
local DIAL_OUT = 0.82
local DESIGN_H = 128
local CAP_W = 64
local BOX_N = 128
local TUBE_AT = 118.5
local TUBE_H = 12
local GEAR_FILL = 0.9375
local GEAR_M = 6.6
local TOOTH_TIP = 0.6
local TEETH_A, TEETH_B, TEETH_C = 12, 8, 8
local GEAR_AX, GEAR_AY = 58, 40
local MESH_B, MESH_C = 42, 112
local NEEDLE_STEP = 54
local NEEDLE_COLS, NEEDLE_ROWS = 2, 2
local STEAM_COLS, STEAM_ROWS, STEAM_FRAMES = 4, 4, 16
local SPARK_COLS, SPARK_ROWS, SPARK_FRAMES = 4, 2, 8
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- How far past the gauge's brass a landing's second ring is seen, in units.
local WAVE_PAST = 4
-- The housing's upper rim and its lower, in design texels: the enamel lies
-- between them, a little above the housing's middle.
local RIM_TOP, RIM_BOT = 12.5, 19
-- The rivets' row and the plate's inset at the housing's left end.
local RIVET_AT, PLATE_AT = 6.5, 13

-- The needle's six marks, in degrees right of straight up: nothing at the
-- lower left, full pressure at the lower right.
local MARK = { nearby = -135, self = -81, group = -27, target = 27, asked = 81, owed = 135 }
local ZERO = -135
-- How far past its mark a swing carries, as a part of the way it came and
-- at most in degrees, and how long it takes to get there and to come back.
local SWING = { over = 0.14, most = 9, out = 0.30, back = 0.18 }
-- The tremble at its mark, owed: degrees and the seconds one way.
local TREMBLE = { degrees = 3.5, seconds = 0.07 }

-- The gauge may stand this much taller than the button, and the gearbox is
-- this much of its height (and never taller than the gauge).
local GAUGE_MAX = 1.27
local BOX_TALL = 1.09
-- The housing is this much of the button's height in from its top and its
-- bottom, so the gauge stands proud of it.
local PLATE_IN = 0.07
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the gauge and the text; with the icon off, between the
-- plate's edge and the text.
local TEXT_GAP, BARE_GAP = 6, 5
-- The words keep at least this much width before the gearbox is given up.
local GEAR_ROOM = 44
-- The enamel's own luminance under the words, its darkest and its brightest
-- (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.01, 0.11
-- The small second line is held to this on the enamel.
local SUB_CONTRAST = 7
-- A chosen panel colour is mixed this far into the housing.
local BODY_MIX = 0.25
-- The shadow: its 9-slice corner in units, and how far past the housing its
-- box reaches. The list's sheet: its corner in units.
local SHADOW_C, SHADOW_OUT = 16, 12
local PLANK_C = 8
local CREAM = { 1.00, 0.96, 0.84 }
local TAG_INK = { 1.00, 0.95, 0.82 }
local MIST = { 0.86, 0.85, 0.78 }
-- A fight's brass.
local DULL = { 0.60, 0.60, 0.62 }
-- The dial and the tube with the marker off (ivory), and a dial a refusal
-- shorted.
local NEUTRAL = { 0.88, 0.82, 0.62 }
local SPENT = { 0.38, 0.38, 0.41 }
local HOVER = { 1.00, 0.92, 0.66 }
-- Gaslight: the dial's warm second tone, the glint. Steam. The spark.
local GASLIGHT = { 1.00, 0.88, 0.58 }
local STEAM = { 0.98, 0.98, 0.96 }
-- A flash is the reason's colour taken this far to white; the dial's warm
-- second tone is gaslight taken this far to the reason.
local FLASH_WHITE, WARM_REASON = 0.5, 0.35
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the housing dims.
local FIGHT = { text = 0.78, icon = 0.70, body = 0.78 }
-- The dial at rest, lit and held after its breaths; the gaslight over it,
-- and the bubbles in the tube, over the same breath.
local DIAL = { rest = 0.68, peak = 1.00, held = 0.92 }
local WARM = { rest = 0, peak = 0.90, held = 0.30 }
local BUBBLE = { rest = 0.22, peak = 0.90, held = 0.50 }
local TUBE_ALPHA = 0.95
local BREATHS, BREATH = 3, 1.25
-- The bubbles along the tube, in files a second (towards the gauge): their
-- drift at rest and their run under pressure.
local BUBBLE_DRIFT, BUBBLE_RUN = 0.035, 0.24
-- The cogs at rest: each goes two teeth on, in this many seconds, and is the
-- same picture again. A landing spins them six teeth on; a refusal kicks
-- them half a tooth back.
local TURN_TEETH, TURN_SECONDS = 2, 7
local SPIN_TEETH, SPIN_SECONDS = 6, 0.66
local JOLT = { teeth = 0.5, back = 0.06, forth = 0.22 }
-- The glint's crossing and its wait.
local GLINT_CROSS, GLINT_WAIT, GLINT_PEAK = 1.7, 8.3, 0.50
-- The steam: frames a second for a landing's cloud and an arrival's whistle,
-- its size as a part of the button's height and at most, how far it climbs.
local PUFF = { fps = 24, whistle = 32, size = 0.68, max = 44, small = 0.55, rise = 3, peak = 0.95 }
-- The vent and the terminals are drawn this much larger than the housing's
-- own texels would have them, and no larger than a housing this tall gives.
local STACK_SCALE, CONTACT_SCALE, WORKS_MAX = 1.25, 1.3, 60
local SPARK_FPS = 24
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The painted frame's own parts (art/looks/gearworks/meta.json's notes): its
-- knurled bezel's outer edge against its glass's; in units of the bar's core
-- from the bar's right and its top, the valve's mouth, where the two cogs
-- mesh (the spark's middle) and the gearbox's left; the upper rivets' row
-- from the top; a fight's dim of the painting (less than the old housing's,
-- so the outlined key keeps its keycap); the dial's colour in the painted
-- glass, taken this far down.
local PAINT = {
	glass = 0.62, bezel = 1.68, valveX = 0.517, valveY = 0.313, meshX = 0.373, meshY = 0.49, sparkW = 0.44, sparkH = 0.22,
	works = 0.66, rivets = 0.09, fight = 0.86,
}

-- The three cogs: the file, the teeth, where it sits round the driving cog
-- (degrees clockwise from its right; nil for the driving cog itself) and
-- which way it goes round (1 with the clock).
local COGS = {
	{ file = "GearA", teeth = TEETH_A, way = 1 },
	{ file = "GearB", teeth = TEETH_B, at = MESH_B, way = -1 },
	{ file = "GearC", teeth = TEETH_C, at = MESH_C, way = -1 },
}
-- Each cog's axle in the gearbox's texels, and its tip radius.
for _, cog in ipairs(COGS) do
	cog.tip = GEAR_M * (cog.teeth / 2 + TOOTH_TIP)
	if cog.at then
		local dist = GEAR_M * (TEETH_A + cog.teeth) / 2
		cog.x = GEAR_AX + dist * math.cos(math.rad(cog.at))
		cog.y = GEAR_AY + dist * math.sin(math.rad(cog.at))
	else
		cog.x, cog.y = GEAR_AX, GEAR_AY
	end
end
Gearworks.COGS = COGS

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block inside the enamel, which is
-- the housing less its two rims, and the housing's own inset.
function Gearworks.TwoLineHeight(fontSize)
	return math.ceil((fontSize + 2 + SubSize(fontSize) + 2) / (1 - (RIM_TOP + RIM_BOT) / DESIGN_H)) + 7
end

-- The dial and its needle are the mark round the icon; the tube is the stripe.
function Gearworks.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return mode == "icon" or mode == "both", mode == "stripe" or mode == "both"
end

-- Whether a stored colour is the default one: AceDB strips a value equal to its
-- default, so untouched and chosen-as-default look the same, and only the
-- first can be meant.
local function Untouched(c, d)
	if type(c) ~= "table" or type(d) ~= "table" then return true end
	for i = 1, 4 do
		if math.abs((c[i] or 1) - (d[i] or 1)) > 0.002 then return false end
	end
	return true
end

-- Whether this client reads an English string in its own language.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

-- Relative luminance of a grey, for the enamel's own ink figures.
local function Luminance(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A texture over a box given from `rel`'s top left, y running down.
local function Box(t, rel, x0, y0, x1, y1)
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", rel, "TOPLEFT", x0, -y0)
	t:SetPoint("BOTTOMRIGHT", rel, "TOPLEFT", x1, -y1)
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- How many tiles of `unit` a length holds: a whole number when within STRETCH
-- of one (the tile is stretched to fit), else the fraction.
local function Tiles(length, unit)
	local n = math.max(0, length) / unit
	local r = math.max(1, math.floor(n + 0.5))
	if n > 0 and math.abs(r / math.max(n, 1e-6) - 1) <= STRETCH then return r end
	return n
end

-- A frame cut from one file into nine: corners from the outer quarters, edges
-- from the middle strips (the shadow, the list's sheet).
local NINE = {
	{ 0, 0.25, 0, 0.25 }, { 0.25, 0.75, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.25, 0.75 }, { 0.75, 1, 0.25, 0.75 },
	{ 0, 0.25, 0.75, 1 }, { 0.25, 0.75, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.25, 0.75, 0.25, 0.75 },
}

local function Pieces(parent, layer, sublevel, file, keep)
	local s = {}
	for i = 1, 9 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(NINE[i][1], NINE[i][2], NINE[i][3], NINE[i][4])
		s[i] = keep(t)
	end
	return s
end

local function PlacePieces(s, rel, x0, y0, x1, y1, c)
	Box(s[1], rel, x0, y0, x0 + c, y0 + c)
	Box(s[2], rel, x0 + c, y0, x1 - c, y0 + c)
	Box(s[3], rel, x1 - c, y0, x1, y0 + c)
	Box(s[4], rel, x0, y0 + c, x0 + c, y1 - c)
	Box(s[5], rel, x1 - c, y0 + c, x1, y1 - c)
	Box(s[6], rel, x0, y1 - c, x0 + c, y1)
	Box(s[7], rel, x0 + c, y1 - c, x1 - c, y1)
	Box(s[8], rel, x1 - c, y1 - c, x1, y1)
	Box(s[9], rel, x0 + c, y0 + c, x1 - c, y1 - c)
end

-- The housing: its left end, its tiled middle and its right end (the left
-- end's mirror), from the two files at the design height.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "HousingL", "HousingM", "HousingL" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	s[3]:SetTexCoord(1, 0, 0, 1)
	return s
end

-- The housing laid over a box: the ends are the design's proportion of its
-- height, the middle tiled along the rest.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN_H
	local cap = math.min(CAP_W * su, (x1 - x0) / 3)
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, x1 - cap, y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
	s[2]:SetTexCoord(0, Tiles(x1 - x0 - 2 * cap, DESIGN_H * su), 0, 1)
end

-- A horizontal three-slice from one file: caps TAG_CAPS of the height, the
-- middle stretched (the tags).
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
	local cap = height * TAG_CAPS
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

-- A texture centred at a point of `rel`'s top left, y running down.
local function At(t, rel, cx, cy, w, h)
	t:ClearAllPoints()
	t:SetPoint("CENTER", rel, "TOPLEFT", cx, -cy)
	t:SetSize(w, h or w)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights or turns, parked
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

-- A turn about the region's middle: `degrees` with the clock when positive.
local function Rotate(group, degrees, duration, order, smoothing)
	local turn = group:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(-degrees) end
	if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	turn:SetDuration(duration)
	turn:SetOrder(order or 1)
	if smoothing and turn.SetSmoothing then turn:SetSmoothing(smoothing) end
	return turn
end

-- Up to `peak` after `delay`, then down to `rest` (nothing unless said). The
-- delay is an Alpha that holds, which reads the same on every client.
local function Flash(region, peak, up, down, rest, delay)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay and delay > 0 then
		Alpha(g, rest or 0, rest or 0, delay, 1)
		order = 2
	end
	Alpha(g, rest or 0, peak, up, order, nil, "OUT")
	Alpha(g, peak, rest or 0, down, order + 1, nil, "IN")
	Park(g, region, rest or 0)
	return g
end

-- A breath: `lo` to `hi` and back, for as long as it is left to.
local function Breathe(region, lo, hi)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	Alpha(g, lo, hi, BREATH, 1, nil, "IN_OUT")
	Park(g, region, lo)
	return g
end

-- One fade from `from` to `to`, which it then holds.
local function Fade(region, from, to, duration)
	local g = region:CreateAnimationGroup()
	Alpha(g, from, to, duration, 1, nil, "OUT")
	Park(g, region, to)
	return g
end

-- The sheen: across the rim by the offset Apply gives it, up as it leaves
-- and out as it arrives, once.
local function Sheen(region, cross, peak)
	local g = region:CreateAnimationGroup()
	local move = g:CreateAnimation("Translation")
	move:SetDuration(cross)
	move:SetOrder(1)
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	g.move = move
	Alpha(g, 0, peak, cross * 0.3, 1, nil, "OUT")
	Alpha(g, peak, 0, cross * 0.7, 1, cross * 0.3, "IN")
	Park(g, region, 0)
	return g
end

-- A glint that crosses, then waits, over and over.
local function GlintLoop(region, cross, wait, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local move = g:CreateAnimation("Translation")
	move:SetDuration(cross)
	move:SetOrder(1)
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	g.move = move
	Alpha(g, 0, peak, cross * 0.3, 1, nil, "OUT")
	Alpha(g, peak, 0, cross * 0.7, 1, cross * 0.3, "IN")
	Alpha(g, 0, 0, wait, 2)
	Park(g, region, 0)
	return g
end

-- Two blinks, the second weaker: a lamp that shorts.
local function Gutter(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0.75, 0.04, 1, nil, "OUT")
	Alpha(g, 0.75, 0, 0.09, 2, nil, "IN")
	Alpha(g, 0, 0.5, 0.04, 3, nil, "OUT")
	Alpha(g, 0.5, 0, 0.16, 4, nil, "IN")
	Park(g, region, 0)
	return g
end

-- A sheet's light while its frames play: up at once, held, and out over the
-- last of its `seconds`; climbing by the offset Apply gives it (the steam).
local function Reel(region, seconds, peak, climbs)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, peak, 0.04, 1, nil, "OUT")
	Alpha(g, peak, 0, seconds - 0.04, 2, nil, "IN")
	if climbs then
		local move = g:CreateAnimation("Translation")
		move:SetDuration(seconds - 0.04)
		move:SetOrder(2)
		if move.SetSmoothing then move:SetSmoothing("OUT") end
		g.move = move
	end
	Park(g, region, 0)
	return g
end

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

local function StopAll(list)
	for _, g in ipairs(list) do g:Stop() end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Gearworks:Build(kit)
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
	local base = art:GetFrameLevel()
	-- A frame of light a few levels over the art and under the text.
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.shade = tex(art, "BACKGROUND", -5, "Shade")
	self.listBody = Pieces(art, "BACKGROUND", -7, ART .. "Plank", keep)
	self.body = Body(art, "BACKGROUND", -6, keep)
	-- The sight tube in the lower rim: the liquid, the bubbles in it (a
	-- REPEAT file, scrolled by Flow) and a brass collar at each end.
	self.tube = tex(art, "BORDER", -2, "Tube")
	self.bubbles = keep(art:CreateTexture(nil, "BORDER", nil, -1))
	self.bubbles:SetTexture(ART .. "Bubbles", "REPEAT", "REPEAT")
	self.ferrules = { tex(art, "BORDER", 0, "Ferrule"), tex(art, "BORDER", 0, "Ferrule") }
	-- What stands on the housing's top: the vent and the two terminals.
	self.stack = tex(art, "BORDER", 1, "Stack")
	self.contacts = tex(art, "BORDER", 1, "Contacts")
	-- The gearbox over the housing's right end, the cogs in it, and over each
	-- the light that stays still.
	self.gearbox = tex(art, "BORDER", 2, "Gearbox")
	self.cogs, self.cogLights = {}, {}
	for i, cog in ipairs(COGS) do
		self.cogs[i] = tex(art, "BORDER", 2 + i, cog.file)
		self.cogLights[i] = tex(art, "BORDER", 6, cog.file .. "Light")
	end
	-- The gauge, under the icon (ARTWORK 0): the dial in the reason's colour,
	-- the gaslight over it (BLEND), the brass and its marks, the needle.
	self.dialBack = tex(art, "ARTWORK", -6, "Mask")
	self.dial = tex(art, "ARTWORK", -5, "Dial")
	self.dialWarm = tex(art, "ARTWORK", -4, "Glow")
	self.dialWarm:SetAlpha(0)
	self.bezel = tex(art, "ARTWORK", -3, "Bezel")
	self.needle = tex(art, "ARTWORK", -2, "Needle")
	-- hunt35-effects reads the owed breath's second tone by these names.
	self.pulseRing, self.ringWarm = self.dialWarm, self.dialWarm

	-- The rings that spread from the glass when a buff lands and the one that
	-- snaps in when one is refused: frames over the art, under the text. No
	-- echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)
	-- The second ring is let out of the button's room, over the gauge that
	-- stands proud of it (Apply): hunt37-effects holds every scaled light to
	-- that room but the ones a look names here.
	self.skyward = { self.fx.rings[2].tex }

	-- The lights: the dial's flash and the spark (ADD), the steam's two
	-- clouds (BLEND: steam is not light).
	self.lightFrame = frame(2)
	self.dialHot = tex(self.lightFrame, "OVERLAY", 1, "Glow", "ADD")
	self.dialHot:SetAlpha(0)
	self.spark = tex(self.lightFrame, "OVERLAY", 2, "Spark", "ADD")
	self.spark:SetAlpha(0)
	self.steam = tex(self.lightFrame, "OVERLAY", 3, "Steam")
	self.steam:SetAlpha(0)
	self.whistle = tex(self.lightFrame, "OVERLAY", 3, "Steam")
	self.whistle:SetAlpha(0)
	-- The housing at rest and the greeting, none of it additive: a glint on
	-- the upper rim, once for the greeting and once for the loop (two groups
	-- on one region would fight over its alpha).
	self.idleFrame = frame(1)
	self.glint = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	self.glintOnce = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	for _, t in ipairs({ self.glint, self.glintOnce }) do
		Colour(t, GASLIGHT[1], GASLIGHT[2], GASLIGHT[3])
		t:SetAlpha(0)
	end
	-- The cursor's light: the upper rim lit.
	self.hoverFrame = frame(1)
	self.hoverLight = tex(self.hoverFrame, "OVERLAY", 1, "Edge")
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's beads, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The chips: small plates at the right end; their text is on textLayer,
	-- over them.
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Tag", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Tag", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The verdict's tick or cross, before the second line.
	self.glyph = tex(textLayer, "ARTWORK", 1, "Check")

	-- The icon's circle; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything baked, for a fight's dulling: the gauge's brass and its
	-- needle, the cogs, the vent, the terminals, the collars, the tags, the
	-- list's sheet, the glyph.
	self.baked = { self.bezel, self.needle, self.stack, self.contacts, self.ferrules[1], self.ferrules[2], self.glyph,
		self.gearbox }
	for _, s in ipairs({ self.cogs, self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end

	-- What moves by its coordinates (Looks/Flow.lua): the bubbles along the
	-- tube, the steam's two clouds and the spark, each a sheet played once.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.bubbleRun = flow:Scroll(self.bubbles, BUBBLE_DRIFT, 0, 1, 1)
	self.steamSheet = flow:Sheet(self.steam, STEAM_COLS, STEAM_ROWS, STEAM_FRAMES, PUFF.fps, false)
	self.whistleSheet = flow:Sheet(self.whistle, STEAM_COLS, STEAM_ROWS, STEAM_FRAMES, PUFF.whistle, false)
	self.sparkSheet = flow:Sheet(self.spark, SPARK_COLS, SPARK_ROWS, SPARK_FRAMES, SPARK_FPS, false)

	self:BuildAnimations(anim)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

function Gearworks:BuildAnimations(anim)
	-- The owed breath: the gaslight over the dial comes and goes, and the
	-- dial and the bubbles with it; see Attention for how long. The gaslight
	-- first: hunt35-effects times the breath by the first.
	self.pulse = {
		anim(Breathe(self.dialWarm, WARM.rest, WARM.peak)), anim(Breathe(self.dial, DIAL.rest, DIAL.peak)),
		anim(Breathe(self.bubbles, BUBBLE.rest, BUBBLE.peak)),
	}
	-- "Once": one rise and fall, 0.55 s.
	self.once = {
		anim(Flash(self.dialWarm, WARM.peak, 0.25, 0.30, 0)), anim(Flash(self.dial, DIAL.peak, 0.25, 0.30, DIAL.rest)),
		anim(Flash(self.bubbles, BUBBLE.peak, 0.25, 0.30, BUBBLE.rest)),
	}
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = {
		anim(Fade(self.dialWarm, 0, WARM.held, 0.5)), anim(Fade(self.dial, DIAL.rest, DIAL.held, 0.5)),
		anim(Fade(self.bubbles, BUBBLE.rest, BUBBLE.held, 0.5)),
	}

	-- The needle. Its swing: the frame it stood in is turned to the new mark
	-- and past, then back to it; as the turn ends (or is cut short) the frame
	-- is changed for the new mark's. The degrees are given at each play.
	local swing = self.needle:CreateAnimationGroup()
	swing.out = Rotate(swing, 0, SWING.out, 1, "OUT")
	swing.back = Rotate(swing, 0, SWING.back, 2, "IN_OUT")
	local function arrived() Gearworks:Settled() end
	swing:SetScript("OnFinished", arrived)
	swing:SetScript("OnStop", arrived)
	self.swing = anim(swing)
	-- Its tremble, owed: a hair past the mark and back, for as long as the
	-- breath runs.
	local tremble = self.needle:CreateAnimationGroup()
	tremble:SetLooping("BOUNCE")
	Rotate(tremble, TREMBLE.degrees, TREMBLE.seconds, 1, "IN_OUT")
	self.trembleAnim = anim(tremble)

	-- A favour arriving: the vent whistles (a small cloud, 0.5 s) and the
	-- dial flashes (out by 0.58 s).
	self.whistleAnim = anim(Reel(self.whistle, STEAM_FRAMES / PUFF.whistle, PUFF.peak, true))
	self.arriveFlash = anim(Flash(self.dialHot, 0.7, 0.08, 0.40, 0, 0.10))
	self.arrive = { self.whistleAnim, self.arriveFlash }

	-- A landing: the steam is let off (0.67 s), the dial flashes (0.45 s) and
	-- every cog spins six teeth on, slowing (0.66 s).
	self.steamAnim = anim(Reel(self.steam, STEAM_FRAMES / PUFF.fps, PUFF.peak, true))
	self.hotAnim = anim(Flash(self.dialHot, 0.6, 0.07, 0.38))
	self.landing = { self.steamAnim, self.hotAnim }
	-- A refusal: the spark jumps (0.33 s), the dial blinks twice in red
	-- (0.33 s) and every cog kicks back half a tooth and comes to (0.28 s).
	self.sparkAnim = anim(Reel(self.spark, SPARK_FRAMES / SPARK_FPS, 1))
	self.gutterAnim = anim(Gutter(self.dialHot))
	self.refusal = { self.sparkAnim, self.gutterAnim }
	-- A sheet's frames end with the light that shows them: its clock (Flow's
	-- one OnUpdate) stops with it, not at its next tick.
	self.whistleAnim:HookScript("OnFinished", function() Gearworks.whistleSheet:Stop() end)
	self.steamAnim:HookScript("OnFinished", function() Gearworks.steamSheet:Stop() end)
	self.sparkAnim:HookScript("OnFinished", function() Gearworks.sparkSheet:Stop() end)
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The cogs: each turns two teeth on and is the same picture again, the
	-- driving cog with the clock and the two it drives against it, all in
	-- the same seconds, so the teeth stay in mesh. hunt35-effects lets the
	-- groups of `idle` loop with nobody owed, and no others. See Idle for
	-- when they run.
	self.turns, self.spins, self.jolts = {}, {}, {}
	self.idle = {}
	for i, cog in ipairs(COGS) do
		local t = self.cogs[i]
		local tooth = 360 / cog.teeth * cog.way
		local turn = t:CreateAnimationGroup()
		turn:SetLooping("REPEAT")
		Rotate(turn, tooth * TURN_TEETH, TURN_SECONDS, 1)
		self.turns[i] = anim(turn)
		self.idle[i] = turn
		local spin = t:CreateAnimationGroup()
		Rotate(spin, tooth * SPIN_TEETH, SPIN_SECONDS, 1, "OUT")
		-- Spun down, it goes back to its round.
		spin:SetScript("OnFinished", function() Gearworks:Idle() end)
		self.spins[i] = anim(spin)
		self.landing[#self.landing + 1] = spin
		local jolt = t:CreateAnimationGroup()
		Rotate(jolt, -tooth * JOLT.teeth, JOLT.back, 1, "OUT")
		Rotate(jolt, tooth * JOLT.teeth, JOLT.forth, 2, "IN_OUT")
		self.jolts[i] = anim(jolt)
		self.refusal[#self.refusal + 1] = jolt
	end
	self.glintLoop = anim(GlintLoop(self.glint, GLINT_CROSS, GLINT_WAIT, GLINT_PEAK))
	self.idle[#self.idle + 1] = self.glintLoop
	-- The greeting: the glint, once, out by 0.7 s.
	self.sheenAnim = anim(Sheen(self.glintOnce, 0.7, GLINT_PEAK))
	self.greet = { self.sheenAnim }

	-- The cursor's light on the upper rim, both ways; from and to are set for
	-- each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Gearworks:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua), and how far left of the text it starts.
	self.pitch = sub + 7
	self.rowReach = 18

	-- The gauge: the icon's file frame, at most GAUGE_MAX of the button's
	-- height, so it stands proud of the housing above and below. The icon is
	-- the slider's size, held inside the glass.
	local gz = math.min(math.max(8, p.iconSize or 30) / ICON_FRAME, H * GAUGE_MAX)
	local iconSize = math.max(8, math.min(p.iconSize or 30, gz * ICON_FRAME))
	local cx, cy = gz / 2, H / 2
	-- The housing: inset from the button's top and bottom, from under the
	-- gauge to the right edge; with the icon off, the whole width.
	local plateIn = math.max(2, math.floor(H * PLATE_IN + 0.5))
	local ph = H - 2 * plateIn
	local su = ph / DESIGN_H
	local plateX = showIcon and math.floor(cx + gz * 0.2) or 0
	local textX = showIcon and math.ceil(gz + TEXT_GAP) or math.ceil(PLATE_AT * su) + BARE_GAP
	-- The gearbox: square, a little taller than the button, at the far end,
	-- where the words keep room beside it.
	local boxW = math.min(H * BOX_TALL, gz)
	local boxed = W - textX - boxW >= GEAR_ROOM
	self.plateIn, self.plateX, self.ph, self.su, self.boxed, self.boxW = plateIn, plateX, ph, su, boxed, boxW
	self.iconSize, self.cx, self.gz, self.textX = iconSize, cx, gz, textX
	-- The housing ends under the gearbox.
	PlaceBody(self.body, art, plateX, plateIn, boxed and (W - boxW * 0.4) or W, H - plateIn)
	-- The housing's colour: as it is, or a chosen panel colour mixed in.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local pr, pg, pb = 1, 1, 1
	if not Untouched(c, d) then
		pr = 1 + ((c[1] or 0) - 1) * BODY_MIX
		pg = 1 + ((c[2] or 0) - 1) * BODY_MIX
		pb = 1 + ((c[3] or 0) - 1) * BODY_MIX
	end
	self.bodyColour = { pr, pg, pb }
	local alpha = (type(c) == "table" and c[4]) or 1
	self.shadowAlpha = math.min(1, alpha + 0.05) * (alpha < 0.2 and 0 or 1)
	for _, t in ipairs(self.shadow) do Colour(t, 0, 0, 0, self.shadowAlpha) end
	-- The gauge's own shadow, down and to the right of it.
	Colour(self.shade, 0, 0, 0, self.shadowAlpha)
	At(self.shade, art, cx + gz * 0.03, cy + gz * 0.05, gz * 1.30)
	self.listBox = nil
	self:PlaceShadow(nil)

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	for _, t in ipairs({ self.dial, self.dialWarm, self.dialHot, self.bezel, self.needle }) do At(t, art, cx, cy, gz) end
	-- A dark back under the dial, so its breath is light and never the
	-- housing seen through it.
	At(self.dialBack, art, cx, cy, gz * DIAL_OUT + 1)
	Colour(self.dialBack, 0.05, 0.05, 0.06)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	-- The icon is round whatever "Round the icon off" says.
	local maskFile = ART .. "Mask"
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	if showIcon then
		if not self.masked then
			icon:AddMaskTexture(self.mask)
			self.masked = true
		end
		self.mask:Show()
	else
		if self.masked then
			icon:RemoveMaskTexture(self.mask)
			self.masked = nil
		end
		self.mask:Hide()
	end
	if showIcon then
		-- The rings' line, at their own size, is the dial's outer edge.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, gz * DIAL_OUT / 2 - iconSize / 2 + 1), iconSize)
		self.fx:Shape(true, ART .. "Ring", ART .. "Ring", maskFile)
		-- The room the rings have: to the text (less a margin), to the
		-- button's left edge, and to its top and bottom.
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		-- That room is the button's, and the gauge stands proud of it: held
		-- to it, neither ring gets past the icon's rim. The first stays there
		-- (it is the one a refusal snaps in). The second is the gauge's own
		-- wave: from the icon's edge across the dial and a little past the
		-- brass, short of the words (`skyward`).
		local wave = self.fx.rings[2]
		local grow = wave.landGrow
		if wave.half and grow.SetScaleFrom and grow.SetScaleTo then
			local reach = math.min(textX - cx - kit.TEXT_MARGIN, gz / 2 + WAVE_PAST)
			local from = (iconSize / 2) / (RING_PEAK * wave.half)
			local to = math.max(from, reach / (RING_EDGE * wave.half))
			grow:SetScaleFrom(from, from)
			grow:SetScaleTo(to, to)
			self.waveFrom, self.waveTo, self.waveReach = from, to, reach
		end
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	self:PlaceWorks(showIcon, above)

	-- The words stand in the enamel, which lies a little above the housing's
	-- middle (the lower rim is the wider: it holds the tube).
	local lift = ((DESIGN_H - RIM_BOT + RIM_TOP) / 2 - DESIGN_H / 2) * su
	local block = fs + 2 + sub
	self.block, self.lift = block, -lift
	self.nameY = block / 2 - fs / 2 + 0.5 - lift
	self.subY = -(block / 2 - sub / 2) + 0.5 - lift
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of the gearbox.
	local chipH = sub + 7
	self.chipH = chipH
	self.chipInset = boxed and math.ceil(boxW) + 4 or math.ceil(PLATE_AT * su) + 3
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -self.chipInset, -lift)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- A painted frame moves the key's letter onto its keycap's frame: back
	-- with the words.
	self.keyText:SetParent(kit.textLayer)
	-- Measured again in the new font and size.
	self.keyLabel, self.countText, self.measuredText = nil, nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list's rows start where the name does, clear of the gauge.
	self.rowX = math.max(textX, 24)
	local rowWidth = math.max(20, W - self.rowX - 12)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil
	-- Where the list's sheet runs and how far its rows keep off the bar
	-- (a painted frame sets them).
	self.listX0, self.listX1, self.listGap = nil, nil, 0

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.shade, self.dialBack, self.dial, self.dialWarm, self.bezel, self.needle }) do t:SetShown(showIcon) end
	self.dialHot:SetShown(showIcon)
	self.fx:SetShown(showIcon)
	self.gearbox:SetShown(boxed)
	for i, t in ipairs(self.cogs) do
		t:SetShown(boxed)
		self.cogLights[i]:SetShown(boxed)
	end
	for _, t in ipairs({ self.tube, self.bubbles, self.ferrules[1] }) do t:SetShown(self.tubeOK) end
	self.ferrules[2]:SetShown(self.tubeOK and self.farFerrule)
	for _, t in ipairs({ self.stack, self.steam, self.whistle }) do t:SetShown(self.stackOK) end
	for _, t in ipairs({ self.contacts, self.spark }) do t:SetShown(self.contactsOK) end
	Each(self.listBody, "Hide")
	for _, t in ipairs(self.beads) do t:Hide() end
	self.glyph:Hide()
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	self:Rest()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused, self.jammed = nil, nil, nil, nil, nil
	self.pulseSpent, self.calmLit = nil, nil
	-- The needle where it last stood, with no swing (nil: at nothing).
	self.swing:Stop()
	self:ShowNeedle(self.needleAt or ZERO)
	self:Dull(false)
	if held then self:Combat(true) end
	self:Idle()

	-- The count's room: a two-digit tag, the gearbox and its inset. Chip
	-- widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The works: the cogs in the gearbox, the tube and its collars, the vent and
-- its steam, the terminals and their spark, the glint's run, the cursor's
-- light.
function Gearworks:PlaceWorks(showIcon, above)
	local kit = self.kit
	local art = kit.art
	local W, H, su, plateIn, plateX = self.W, self.H, self.su, self.plateIn, self.plateX
	local cx, cy, gz, textX, boxed = self.cx, H / 2, self.gz, self.textX, self.boxed
	-- The gearbox: its file's texels are this many units; the cogs' axles
	-- are counted from its top left.
	local boxW = self.boxW
	local bu = boxW / BOX_N
	local bx, by = W - boxW, (H - boxW) / 2
	Box(self.gearbox, art, bx, by, W, by + boxW)
	for i, cog in ipairs(COGS) do
		local size = 2 * cog.tip * bu / GEAR_FILL
		At(self.cogs[i], art, bx + cog.x * bu, by + cog.y * bu, size)
		At(self.cogLights[i], art, bx + cog.x * bu, by + cog.y * bu, size)
	end

	-- Where the gauge's edge crosses a height, right of its middle.
	local function gaugeEdge(y)
		local dy = math.abs(y - cy)
		if not showIcon or dy >= gz / 2 then return nil end
		return cx + math.sqrt(gz * gz / 4 - dy * dy)
	end

	-- The tube: along the lower rim, from the gauge (or the plate's left) to
	-- the gearbox (or the housing's right end).
	local ty, th = plateIn + TUBE_AT * su, TUBE_H * su
	local tx0 = (gaugeEdge(ty) or (plateX + PLATE_AT * su)) - 1
	local tx1 = boxed and (W - boxW + 1) or (W - PLATE_AT * su)
	-- The painted frame has no tube: its bubbles never start.
	self.tubeOK = tx1 - tx0 >= 16 and not ns.Looks.Painted.On(self)
	if not self.tubeOK then self.bubbleRun:Stop() end
	Box(self.tube, art, tx0, ty - th / 2, tx1, ty + th / 2)
	Box(self.bubbles, art, tx0 + 1, ty - th / 2, tx1 - 1, ty + th / 2)
	-- The bubbles' file is four times as long as it is tall, and they are
	-- drawn half as large again along the tube.
	self.bubbleRun:Window(math.max(0.25, (tx1 - tx0 - 2) / (th * 6)), 1)
	local fw, fh = th * 0.7, th + 3 * su
	At(self.ferrules[1], art, tx0 + fw / 2 + 0.5, ty, fw, fh)
	At(self.ferrules[2], art, tx1 - fw / 2, ty, fw, fh)
	-- The far collar is under the gearbox's frame when there is one.
	self.farFerrule = not boxed

	-- The vent: on the housing's top, left of the gearbox. Its file's foot
	-- stands a little into the rim.
	local top = plateIn + 1.5 * su
	local au = math.min(su, WORKS_MAX / DESIGN_H)
	local ss = 32 * au * STACK_SCALE
	local sx = (boxed and (W - boxW) or (W - PLATE_AT * su)) - ss * 0.62
	Box(self.stack, art, sx - ss / 2, top - ss, sx + ss / 2, top)
	-- The terminals: on the housing's top, right of the gauge.
	local cw, ch = 64 * au * CONTACT_SCALE, 32 * au * CONTACT_SCALE
	local kx = textX + 2 * su
	Box(self.contacts, art, kx, top - ch, kx + cw, top)
	Box(self.spark, art, kx, top - ch, kx + cw, top)
	Colour(self.spark, 1, 0.80, 0.74)
	-- Neither with the list hung over the panel, nor where they would crowd
	-- one another.
	self.stackOK = not above and sx - ss / 2 >= textX + 2
	self.contactsOK = not above and self.stackOK and (sx - ss / 2) - (kx + cw) >= 10
	-- The steam: a cloud from the vent's mouth, climbing as it thins. The
	-- puff leaves the frame's foot a tenth of the way up it.
	local mouth = top - ss * 0.88
	local big = math.min(H * PUFF.size, PUFF.max)
	local small = big * PUFF.small
	Box(self.steam, art, sx - big / 2, mouth - big * 0.906, sx + big / 2, mouth + big * 0.094)
	Box(self.whistle, art, sx - small / 2, mouth - small * 0.906, sx + small / 2, mouth + small * 0.094)
	for _, t in ipairs({ self.steam, self.whistle }) do Colour(t, STEAM[1], STEAM[2], STEAM[3]) end
	self.steamAnim.move:SetOffset(0, PUFF.rise * H / 44)
	self.whistleAnim.move:SetOffset(0, PUFF.rise * 0.6 * H / 44)

	-- The glint's run along the upper rim, for the loop and the greeting.
	local glintW = 26
	local glintY = plateIn + RIVET_AT * su
	local glintX0 = (gaugeEdge(glintY) or (plateX + 6)) + glintW / 2
	local glintRun = (boxed and (W - boxW) or (W - 6)) - glintW / 2 - glintX0
	self.greetOK = glintRun >= 30
	At(self.glint, art, glintX0, glintY, glintW, 3)
	At(self.glintOnce, art, glintX0, glintY, glintW, 3)
	self.glintLoop.move:SetOffset(math.max(0, glintRun), 0)
	self.sheenAnim.move:SetOffset(math.max(0, glintRun), 0)

	-- The cursor's light over the upper rim.
	Box(self.hoverFrame, art, (gaugeEdge(glintY) or (plateX + 4)), plateIn, boxed and (W - boxW) or (W - 4), plateIn + RIM_TOP * su)
	Colour(self.hoverLight, HOVER[1], HOVER[2], HOVER[3])
end

-- Every light where it rests: the dial lit, the bubbles low, the rest dark.
function Gearworks:Rest()
	self.dial:SetAlpha(DIAL.rest)
	self.dialWarm:SetAlpha(0)
	self.dialHot:SetAlpha(0)
	self.bubbles:SetAlpha(BUBBLE.rest)
	self.spark:SetAlpha(0)
	self.steam:SetAlpha(0)
	self.whistle:SetAlpha(0)
	self.glint:SetAlpha(0)
	self.glintOnce:SetAlpha(0)
	self.hoverLight:SetAlpha(0)
end

-- The frame of the needle's sheet that shows it at a mark: the three marks
-- on the left are the three on the right, mirrored.
function Gearworks:ShowNeedle(deg)
	self.needleAt, self.needleShown = deg, deg
	local k = math.floor(math.abs(deg) / NEEDLE_STEP)
	local col, row = k % NEEDLE_COLS, math.floor(k / NEEDLE_COLS)
	local l, r = col / NEEDLE_COLS, (col + 1) / NEEDLE_COLS
	if deg < 0 then l, r = r, l end
	self.needle:SetTexCoord(l, r, row / NEEDLE_ROWS, (row + 1) / NEEDLE_ROWS)
end

-- The needle to a mark. With `swing` the frame it stands in is turned there,
-- a little past and back, and Settled changes the frame as the turn ends: a
-- swing is Full effects' only, never in a fight. Without one it simply
-- stands there.
function Gearworks:SetNeedle(deg, swing)
	if self.needleAt == deg then return end
	local g = self.swing
	-- A swing cut short lands where it was going, and the next starts there.
	g:Stop()
	self.trembleAnim:Stop()
	self.needleAt = deg
	local from = self.needleShown
	if swing and from and self.active and not self.combat and self.kit.FullEffects() and self.kit.icon:IsShown() then
		local d = deg - from
		local over = math.min(math.abs(d) * SWING.over, SWING.most) * (d < 0 and -1 or 1)
		-- Rotate's sense: with the clock is a negative SetDegrees.
		g.out:SetDegrees(-(d + over))
		g.back:SetDegrees(over)
		g:Play()
	else
		self:Settled()
	end
end

-- The needle has come to its mark: it is drawn there, and owed, it trembles.
function Gearworks:Settled()
	if self.needleAt and self.needleShown ~= self.needleAt then self:ShowNeedle(self.needleAt) end
	if self.trembling and self.active and not self.combat and self.kit.FullEffects() then
		if not self.trembleAnim:IsPlaying() then self.trembleAnim:Play() end
	else
		self.trembleAnim:Stop()
	end
end

-- The works at rest: the cogs turn, the glint crosses and the bubbles drift
-- on Full effects, out of a fight and with the prompt up, and all are
-- stopped otherwise (stopped, not paused: the cogs stand as they are drawn,
-- in mesh, the glint parks dark). The three cogs start and stop together, so
-- their teeth stay in step; a cog that is spinning down or kicking back is
-- left to finish, and one a refusal jammed stands until the next person.
function Gearworks:Idle()
	local on = self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()
	local cogs = on and self.boxed and not self.jammed
	if cogs then
		local busy = self.turns[1]:IsPlaying()
		for i = 1, #COGS do busy = busy or self.spins[i]:IsPlaying() or self.jolts[i]:IsPlaying() end
		if not busy then
			for _, g in ipairs(self.turns) do
				g:Stop()
				g:Play()
			end
		end
	else
		for _, g in ipairs(self.turns) do g:Stop() end
	end
	if on and self.greetOK then
		if not self.glintLoop:IsPlaying() then self.glintLoop:Play() end
	else
		self.glintLoop:Stop()
	end
	-- The bubbles drift along the tube, and stand when nothing else moves.
	if on and self.tubeOK then
		if not self.bubbleRun:IsPlaying() then self.bubbleRun:Play() end
	else
		self.bubbleRun:Stop()
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome, and only on a housing long enough to carry it.
function Gearworks:Greet()
	if not (self.active and self.greetOK) or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; and somebody new on the panel is greeted,
-- once. A favour arriving has its own lights, so the greeting is for a new
-- face only.
function Gearworks:Painted(entry)
	self:Idle()
	-- The needle's mark is read here too: Prompt leaves PaintReason out when
	-- the colour is the one it painted last, and with "Colour marker by
	-- reason" off every reason has the one colour, so the needle would stand
	-- for good at the first mark it was given.
	local mark = self.ringOn and MARK[entry and entry.reason] or ZERO
	if mark ~= self.mark then
		self.mark = mark
		if not self.outcomeOn then self:SetNeedle(mark, true) end
	end
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the housing, and under the list's sheet when it is out.
function Gearworks:PlaceShadow(list)
	local W, H = self.W, self.H
	local x0, y0, x1, y1 = (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 3, W + SHADOW_OUT + 1, H + SHADOW_OUT + 2
	if list then
		y0 = math.min(y0, list[2] - SHADOW_OUT + 2)
		y1 = math.max(y1, list[4] + SHADOW_OUT + 3)
	end
	PlacePieces(self.shadow, self.kit.art, x0, y0, x1, y1, SHADOW_C)
end

function Gearworks:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the enamel, whatever the panel colour: the legibility the
	-- shared code works out is held against the enamel's own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(CREAM[1], CREAM[2], CREAM[3], 1)
	end
	kit.name:SetShadowColor(0, 0.02, 0.02, 0.9)
	kit.name:SetShadowOffset(1, -1)
	kit.sub:SetShadowColor(0, 0.02, 0.02, 1)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are enamel whatever the panel, so their text is cream as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.92, 0.90, 0.82, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffb6b09c"
end

function Gearworks:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	self.flow:StopAll()
	-- Every parked light at rest after the Stop: a finished fade is not
	-- stopped at all, and the cursor leaves for the next look.
	self:Rest()
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
		if kit.cooldown.SetSwipeTexture then kit.cooldown:SetSwipeTexture(WHITE) end
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.outcomeOn, self.refused, self.jammed = nil, nil, nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
	self.pulseSpent, self.calmLit, self.trembling = nil, nil, nil
end

---------------------------------------------------------------------------
-- the painted frame (Looks/Painted.lua): the gauge's dial and needle, the
-- steam, the spark, the glint, the lines, the key and the list moved onto the
-- painting. Looks/Painted.lua has laid the three pieces and put the icon in
-- the socket; `g` is its Painted.Layout.
---------------------------------------------------------------------------

function Gearworks:PaintedPlace(g, p, above)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local showIcon = p.showIcon and true or false
	local H, u = self.H, g.unit
	local keyL, keyR = g.keyX - g.keyW / 2, g.keyX + g.keyW / 2
	-- The gauge is the painting's: the dial's band in the reason's colour lies
	-- in its glass round the icon, the needle on the band.
	local cx, cy = g.socketX, g.socketY
	local iconSize = g.iconSize
	local gz = iconSize / ICON_FRAME
	self.cx, self.gz, self.iconSize, self.textX = cx, gz, iconSize, g.textX
	for _, t in ipairs({ self.dial, self.dialWarm, self.dialHot, self.needle }) do At(t, art, cx, cy, gz) end
	local brass = g.socketR * PAINT.bezel
	if showIcon then
		self.fx:Place(icon, self.fx.ThinPad(iconSize, gz * DIAL_OUT / 2 - iconSize / 2 + 1), iconSize)
		local limitH = math.min(g.textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		-- The socket may sit off the button's middle: the nearer of its top
		-- and bottom holds the rings.
		self.fx:Fit(limitH, math.min(cy, H - cy) - kit.EDGE_MARGIN, kit.SHAKE_LEFT)
		-- The second ring: from the icon's edge across the glass and a little
		-- past the painted brass, short of the words.
		local wave = self.fx.rings[2]
		local grow = wave.landGrow
		if wave.half and grow.SetScaleFrom and grow.SetScaleTo then
			local reach = math.min(g.textX - cx - kit.TEXT_MARGIN, brass + WAVE_PAST)
			local from = (iconSize / 2) / (RING_PEAK * wave.half)
			local to = math.max(from, reach / (RING_EDGE * wave.half))
			grow:SetScaleFrom(from, from)
			grow:SetScaleTo(to, to)
			self.waveFrom, self.waveTo, self.waveReach = from, to, reach
		end
	end
	-- The painting's own cogs stand still; this file's are hidden, and no
	-- turn runs under them. Nor a tube.
	self.boxed, self.tubeOK = false, false
	self.bubbleRun:Stop()
	-- The steam from the painted valve's mouth, climbing as it thins; not
	-- with the list hung over the bar.
	local sx, mouth = g.right - PAINT.valveX * u, g.top + PAINT.valveY * u
	local big = math.min(H * PUFF.size, PUFF.max)
	local small = big * PUFF.small
	Box(self.steam, art, sx - big / 2, mouth - big * 0.906, sx + big / 2, mouth + big * 0.094)
	Box(self.whistle, art, sx - small / 2, mouth - small * 0.906, sx + small / 2, mouth + small * 0.094)
	self.stackOK = not above
	self.steam:SetShown(self.stackOK)
	self.whistle:SetShown(self.stackOK)
	-- A refusal's spark jumps where the painted cogs mesh.
	local mx, my = g.right - PAINT.meshX * u, g.top + PAINT.meshY * u
	local sw, sh = PAINT.sparkW * u, PAINT.sparkH * u
	Box(self.spark, art, mx - sw / 2, my - sh / 2, mx + sw / 2, my + sh / 2)
	self.contactsOK = true
	self.spark:Show()
	-- The glint along the upper rivets, from the bezel to the gearbox; the
	-- cursor's light over the upper rim.
	local glintW = 26
	local works = g.right - PAINT.works * u
	local glintY = g.top + PAINT.rivets * u
	local glintX0 = (showIcon and (cx + brass) or (g.left + 6)) + glintW / 2
	local glintRun = works - glintW / 2 - glintX0
	self.greetOK = glintRun >= 30
	At(self.glint, art, glintX0, glintY, glintW, 3)
	At(self.glintOnce, art, glintX0, glintY, glintW, 3)
	self.glintLoop.move:SetOffset(math.max(0, glintRun), 0)
	self.sheenAnim.move:SetOffset(math.max(0, glintRun), 0)
	Box(self.hoverFrame, art, glintX0 - glintW / 2, g.top, works, g.wellTop)
	-- The two lines centred on the well, the verdict's glyph with them.
	local dy = H / 2 - g.textY
	self.nameY, self.subY, self.lift = self.nameY + dy, self.subY + dy, self.lift + dy
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", g.textX - 1, self.subY)
	-- The key's letter on the painted keycap; the lines and the count's tag
	-- keep left of it.
	self.chipInset = math.ceil(self.W - keyL) + 3
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("CENTER", art, "TOPLEFT", g.keyX, -g.keyY)
	self.keyBox:SetSize(g.keyW, g.keyH)
	-- The letter is part of the keycap: a fight's dim of the words is not.
	self.keyText:SetParent(self.chipFrame)
	self.roomBase = math.ceil(self.chipH * 1.75) + self.chipInset + 7
	-- The list from the words' start to the keycap's far side, its rows
	-- clear of what the painting hangs past the bar.
	self.rowX = math.max(g.textX, 24)
	self.listX0 = math.max(2, self.rowX - 22)
	self.listX1 = math.max(self.rowX + 30, keyR + 3)
	self.listGap = math.max(0, (above and -g.y0 or (g.y1 - H)) * 0.85)
	local rowWidth = math.max(20, self.listX1 - self.rowX - 9)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		kit.fit.room[row] = rowWidth
	end
	self:Idle()
	return g.textX, self.roomBase
end

-- The key's letter in the keycap's own ink (outlined where the brass is
-- mid-toned), no larger than the keycap holds.
function Gearworks:PaintedStyled(g)
	local ink = g and g.keyInk
	if not ink then return end
	local path = self.kit.fit.path or STANDARD_TEXT_FONT
	local size = math.max(6, math.min(self.sub or 10, math.floor(g.keyH * 0.7)))
	local flags = g.keyOutline and "OUTLINE" or ""
	if not self.keyText:SetFont(path, size, flags) or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
	self.keyText:SetTextColor(ink[1], ink[2], ink[3], 1)
	self.keyText:SetShadowOffset(0, 0)
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Gearworks:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The gearbox stands at the far end.
	local inset = math.max(right, self.chipInset or 18)
	if self.keyUp then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	-- The two points never cross: the name keeps 20 units, the room at the
	-- right gives way.
	inset = math.min(inset, math.max(0, self.W - self.textX - 20))
	self.inset = inset
	self.lineRoom = math.max(20, self.W - self.textX - inset)
	fit.room[name] = self.lineRoom
	if fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -inset, self.nameY)
	else
		name:SetPoint("LEFT", self.textX, self.lift)
		name:SetPoint("RIGHT", -inset, self.lift)
	end
	-- Placed again by Fitted, which knows whether the verdict's glyph leads.
	self.subLead = nil
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
end

-- Whether the reason line holds the verdict PaintOutcome wrote: the only
-- time a glyph leads it.
function Gearworks:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Gearworks:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.sub or not self.lineRoom then return end
	local glyph = self.glyphOn and self:ShowsVerdict()
	local lead = glyph and self.glyphRoom or 0
	local room = self.lineRoom - lead
	if kit.fit.room[fs] ~= room then
		-- Fitted again at the room the glyph leaves, which lands back here.
		kit.fit.room[fs] = room
		return kit.FitLine(fs)
	end
	if self.subLead ~= lead then
		self.subLead = lead
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", self.textX + lead, self.subY)
		fs:SetPoint("RIGHT", -(self.inset or self.chipInset or 18), self.subY)
	end
	self.glyph:SetShown((glyph and fs:IsShown()) and true or false)
end

-- Whether the name, at the size the player set, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Gearworks:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	-- At the size the player set, not at the name's smallest: a tag gives way
	-- before the name is drawn smaller.
	return width * base / size <= self.W - self.textX - math.max(room, self.chipInset or 18) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil: only
-- where a press casts something (the button armed, a fight's frozen macro
-- too), never over a held panel with nothing armed, nor over an outcome.
function Gearworks:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
	-- Show my key on the prompt (prompt.keycap): the player's choice, else the look's.
	if not ns.Looks.KeyWanted(self) then return nil end
	local key = GetBindingKey(COMMAND)
	if type(key) ~= "string" or key == "" then return nil end
	if type(GetBindingText) == "function" then
		local text = ns.Looks.ShortKey(key)
		if type(text) == "string" and text ~= "" then key = text end
	end
	return key
end

-- The room the lines leave at the right for the key's tag with the count's
-- beside it.
function Gearworks:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Gearworks:Chip(on)
	local kit = self.kit
	-- The width FitLine took of the name just now. A name drawn at its
	-- smallest was not measured there, so it is measured here, once for a
	-- text at a size (kit.TextWidth is a pcall: none on a per-scan path); a
	-- secret name cannot be told from the last, and is measured each time.
	-- The tags' own words are measured only when they change.
	local width = kit.fit.drawn[kit.name]
	if not width then
		local text, size = kit.name:GetText(), kit.fit.size[kit.name]
		local secret = issecretvalue and issecretvalue(text)
		if secret or text ~= self.measuredText or size ~= self.measuredSize then
			self.measuredWidth = kit.TextWidth(kit.name)
			self.measuredText, self.measuredSize = (not secret) and text or nil, size
		end
		width = self.measuredWidth
	end
	self.nameWidth = width

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + self.chipInset + 7)
			-- On the painted keycap the key takes no room of the lines' own:
			-- the keycap is already left out of it.
			if ns.Looks.Painted.On(self) then
				self.keyW, self.keyRoom = self.paintedArt.g.keyW, self.chipInset
			end
			-- A key bound anew is a tag of a new width: Prompt places the
			-- lines again, beside it.
			kit.fit.right = nil
		end
		-- The painted keycap is there whatever the name: its letter with it.
		keyUp = ns.Looks.Painted.On(self) or self:NameFits(self.keyRoom)
	end
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		kit.fit.right = nil
	end
	if keyUp then self.keyBox:SetWidth(math.floor(self.keyW + 0.5)) end
	for _, t in ipairs(self.keyChip) do t:SetShown(keyUp) end
	self.keyText:SetShown(keyUp)

	if on then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		text = count:GetText()
		if text ~= self.countText then
			self.countText = text
			self.countW = math.max(self.chipH * 1.75, (kit.TextWidth(count) or self.sub) + 10)
		end
		kit.fit.chipRoom = math.max(self.roomBase or 0, math.ceil(self.countW) + self.chipInset + 7)
	end
	local mode
	if on then
		if keyUp then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(kit.fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local h = self.chipH
		local w = self.countW
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -self.chipInset, self.lift)
			end
			PlaceThree(self.chip, self.chipBox, h)
			count:ClearAllPoints()
			count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)
		end
		self.chipBox:SetSize(math.floor(w + 0.5), h)
	end
	self.countMode = mode
	for _, t in ipairs(self.chip) do t:SetShown(mode ~= nil) end
	kit.count:SetShown(mode ~= nil)
	-- Only a tag at the right takes room from the lines; PlaceLines gives a
	-- pair the room of both.
	return mode == "chip" or mode == "pair"
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- A dial a refusal shorted: grey until the next PaintReason.
function Gearworks:Spend()
	Colour(self.dial, SPENT[1], SPENT[2], SPENT[3])
end

-- The dial in the reason's colour and the tube (each only where the marker
-- says so, else ivory), their lights the same colour taken towards white,
-- and the reason line warmed towards it.
function Gearworks:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	if self.refused then
		self:Spend()
	elseif ns.Looks.Painted.On(self) then
		-- In the painted glass the dial is the glass tinted, not a lamp.
		Colour(self.dial, cr * PAINT.glass, cg * PAINT.glass, cb * PAINT.glass)
	else
		Colour(self.dial, cr, cg, cb)
	end
	-- The dial's warm second tone: gaslight, taken a part of the way to the
	-- reason, so it is warm whatever the reason is.
	local wr = GASLIGHT[1] + (cr - GASLIGHT[1]) * WARM_REASON
	local wg = GASLIGHT[2] + (cg - GASLIGHT[2]) * WARM_REASON
	local wb = GASLIGHT[3] + (cb - GASLIGHT[3]) * WARM_REASON
	Colour(self.dialWarm, wr, wg, wb)
	local fr, fg, fb = kit.Tint(wr, wg, wb, FLASH_WHITE)
	Colour(self.dialHot, fr, fg, fb)
	Colour(self.tube, vr, vg, vb, TUBE_ALPHA)
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.6)
	Colour(self.bubbles, ir, ig, ib)
	-- The reason line: a warm mist taken most of the way to the reason, held
	-- to its contrast on the enamel.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glyph, sr, sg, sb)
	self.tint = { cr, cg, cb }
end

function Gearworks:PaintReason(r, g, b, reason, mode)
	mode = mode or "icon"
	-- A refusal shorted the dial and greyed the icon: they take their colour
	-- back here, and a fight keeps the icon grey.
	self.refused = nil
	local ring = mode == "icon" or mode == "both"
	-- On the painted frame, which has no tube, the dial carries the stripe's
	-- colour too.
	if mode == "stripe" and ns.Looks.Painted.On(self) then ring = true end
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], false, false)
	else
		self:Tint(r, g, b, ring, mode == "stripe" or mode == "both")
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
	-- The needle at the reason's mark, where the dial carries the reason. An
	-- outcome holds it at nothing, and the cogs it jammed with it, until it
	-- is over: PaintOutcome follows this on every scan while one is live, and
	-- ClearOutcome on the scan it ends.
	self.ringOn = ring
	self.mark = ring and MARK[reason] or ZERO
	if not self.outcomeOn then
		self.jammed = nil
		self:SetNeedle(self.mark, true)
		self:Idle()
	end
end

-- The brass, the copper and the enamel dulled for a fight, or back to
-- themselves.
function Gearworks:Dull(on)
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(on or false)
		if on then
			Colour(t, DULL[1], DULL[2], DULL[3])
		else
			Colour(t, 1, 1, 1)
		end
	end
	local pc = self.bodyColour or { 1, 1, 1 }
	local f = on and FIGHT.body or 1
	Each(self.body, "SetDesaturated", on)
	for _, t in ipairs(self.body) do Colour(t, pc[1] * f, pc[2] * f, pc[3] * f) end
	-- The painted frame, when it is up, the same, a fight dimming it less.
	local pf = on and PAINT.fight or 1
	ns.Looks.Painted.Tone(self, pc[1] * pf, pc[2] * pf, pc[3] * pf, on)
end

-- The housing holds; it and the gauge dull, the cogs stop, the icon greys,
-- the words dim and the lights go out. The dial and the tube keep their
-- colour: the reason is the one coloured thing left.
function Gearworks:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Dull(on)
	kit.textLayer:SetAlpha(on and FIGHT.text or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon shows two
	-- grounds.
	local v = on and FIGHT.icon or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and FIGHT.icon or 1) end
	if on then
		self:StopAttention()
		self:StopFlourishes()
		self.swing:Stop()
		for _, g in ipairs(self.greet) do g:Stop() end
	end
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest. The needle is still and the bubbles stand.
function Gearworks:HoldPulse(spent)
	StopAll(self.pulse)
	self.trembling = nil
	self.trembleAnim:Stop()
	self.bubbleRun:Speed(BUBBLE_DRIFT, 0)
	self.dialWarm:SetAlpha(spent and WARM.held or 0)
	self.dial:SetAlpha(spent and DIAL.held or DIAL.rest)
	self.bubbles:SetAlpha(spent and BUBBLE.held or BUBBLE.rest)
end

-- The lights the three flourishes share are one set of regions: one plays at
-- a time. A cog cut short goes back to its round.
function Gearworks:StopLights()
	StopAll(self.arrive)
	StopAll(self.landing)
	StopAll(self.refusal)
	self.steamSheet:Stop()
	self.whistleSheet:Stop()
	self.sparkSheet:Stop()
end

-- A sheet from its first frame, with the light that shows it.
local function Roll(sheet, group)
	sheet:Stop()
	sheet.shown = nil
	sheet:Play()
	group:Stop()
	group:Play()
end

function Gearworks:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The vent answers a new favour, never a new face.
		if full and self.kit.icon:IsShown() and not (self.outcomeOn or self.kit.OutcomeLive()) then
			self:StopLights()
			self:Idle()
			self.arriveFlash:Play()
			if self.stackOK then Roll(self.whistleSheet, self.whistleAnim) end
		end
	end
	if flashStyle ~= "pulse" then
		-- "Once": one rise and fall for the new favour, and still after.
		if isNew and full then
			self:HoldPulse()
			PlayAll(self.once)
		elseif not self.once[1]:IsPlaying() then
			self:HoldPulse()
		end
		return
	end
	if not full then
		-- Calm: one fade up to the held light, and nothing loops.
		if not self.calmLit then
			self.calmLit = true
			-- Calm chosen while it breathed: the needle's tremble and the
			-- bubbles' run stop with the breath (HoldPulse), not only the
			-- three lights.
			self:HoldPulse()
			PlayAll(self.calm)
		end
		return
	end
	if self.pulseSpent then
		self:HoldPulse(true)
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps it
	-- going but takes its own three breaths.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		StopAll(self.calm)
		self.dialWarm:SetAlpha(WARM.rest)
		self.dial:SetAlpha(DIAL.rest)
		self.bubbles:SetAlpha(BUBBLE.rest)
		for _, g in ipairs(self.pulse) do g:Play() end
		-- Under pressure: the bubbles run and the needle trembles at its
		-- mark, once it has swung there.
		self.bubbleRun:Speed(BUBBLE_RUN, 0)
		self.trembling = true
		if not self.swing:IsPlaying() then self:Settled() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Gearworks.pulseGen or not Gearworks.active then return end
			Gearworks.pulseSpent = true
			if Gearworks.pulse[1]:IsPlaying() then
				Gearworks:HoldPulse(true)
				-- Settled: the rim says so, once.
				Gearworks:Greet()
			end
		end)
	end
end

function Gearworks:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	self.trembling = nil
	self.trembleAnim:Stop()
	self.bubbleRun:Speed(BUBBLE_DRIFT, 0)
	self.dialWarm:SetAlpha(0)
	self.dial:SetAlpha(DIAL.rest)
	self.bubbles:SetAlpha(BUBBLE.rest)
	self.calmLit = nil
	-- The prompt taken down ends here and nowhere else of the look's: the
	-- cogs, the glint and the bubbles stop under a hidden panel.
	self:Idle()
end

function Gearworks:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal shorts it: a spark jumps the terminals, the dial blinks twice
	-- in the refusal's red and is left grey, the cogs kick back and jam, and
	-- one ring snaps in onto the glass. The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		self.refused, self.jammed = true, true
		self:Spend()
		self:StopLights()
		for _, g in ipairs(self.turns) do g:Stop() end
		if self.boxed then PlayAll(self.jolts) end
		if self.contactsOK then Roll(self.sparkSheet, self.sparkAnim) end
		if shown then
			Colour(self.dialHot, o[1], o[2], o[3])
			self.gutterAnim:Play()
			self.fx:Refuse(1.00, 0.40, 0.34, 0.85)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- The steam is let off, and the works run on with it.
	if self.stackOK then Roll(self.steamSheet, self.steamAnim) end
	if self.boxed and not self.jammed then
		for _, g in ipairs(self.turns) do g:Stop() end
		PlayAll(self.spins)
	end
	if shown then
		self.hotAnim:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
end

function Gearworks:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
	self:Idle()
end

function Gearworks:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hoverLight
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.30 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	if g.fade.SetSmoothing then g.fade:SetSmoothing(on and "OUT" or "IN") end
	g:Play()
	if on then self:Greet() end
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so
-- the eye never has to find the person again. The bubbles take the outcome's
-- colour, and the needle falls to nothing: the pressure is off, or the works
-- are dead.
function Gearworks:PaintOutcome(kind, lead, sub, who, stamp)
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
	-- The owed breathing is about the favour, not the click: it stops.
	-- Attention starts it again for the next person owed.
	self:HoldPulse()
	StopAll(self.calm)
	StopAll(self.once)
	Colour(self.bubbles, o[1], o[2], o[3])
	self.refused = kind == "failed"
	if self.refused then
		self.jammed = true
		self:Spend()
		for _, g in ipairs(self.turns) do g:Stop() end
	end
	-- A cast nobody confirmed leaves the needle where it stood.
	if kind ~= "sent" then self:SetNeedle(ZERO, true) end
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], SUB_CONTRAST)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	Colour(self.glyph, vr, vg, vb)
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
	end
end

-- The outcome is over (Prompt says so at every paint without one): the
-- needle climbs back to the reason's mark and the cogs are free.
function Gearworks:ClearOutcome()
	if not self.outcomeOn then return end
	self.outcomeOn = nil
	self.jammed = nil
	self:SetNeedle(self.mark or ZERO, true)
	self:Idle()
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A sheet of dark iron in a brass strip under the housing (or over it); each
-- row wears a small lamp in its reason's colour.
function Gearworks:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.beads do
		if not (list and i <= shown) then self.beads[i]:Hide() end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.listBody, "Hide")
			self:PlaceShadow(nil)
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		Colour(self.beads[i], c[1], c[2], c[3])
		self.beads[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	-- Under a painted frame the rows keep clear of what the painting hangs
	-- past the bar (its gauge's bezel): the sheet runs on under it.
	local gap = self.listGap or 0
	local depth = shown * pitch + 8 + gap
	local H = self.H
	local y0, y1
	if above then
		y1 = self.plateIn + 2
		y0 = -depth
	else
		y0 = H - self.plateIn - 2
		y1 = H + depth
	end
	local x0 = self.listX0 or math.max(self.plateX, self.rowX - 22)
	local x1 = self.listX1 or self.W
	PlacePieces(self.listBody, art, x0, y0, x1, y1, math.min(PLANK_C, (y1 - y0) / 2))
	Each(self.listBody, "Show")
	self:PlaceShadow({ x0, y0, x1, y1 })

	local bead = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = -(5 + gap + (shown - i) * pitch + pitch / 2)
		else
			y = H + 3 + gap + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		At(self.beads[i], art, self.rowX - 9, y, bead)
	end
end
