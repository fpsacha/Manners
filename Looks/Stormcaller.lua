-- Manners -- the Stormcaller look: a shaman's, and the Earthen Ring's.
--
-- THE SOURCE. The shaman of Warcraft: the totems of earth, fire, water and
-- air a shaman plants, carved and painted as the tauren and the orcs of
-- Thrall's Orgrimmar carve them (a thunderbird's wings, a scowling face,
-- tusks, feathers on thongs), the standing stones and the four elements of
-- the Earthen Ring, and the shaman's own lightning: Lightning Bolt, Chain
-- Lightning, Lightning Shield.
--
-- A SLAB of weathered stone, a face of dark slate cut into it for the words,
-- a line of lightning chiselled along its upper border and a CHANNEL cut
-- along its lower one. At its left stands a TOTEM of carved, painted wood,
-- taller than the slab: the spell icon stands in its open maw, in an inlay of
-- set stones, under its two EYES. At its right a STANDING STONE is lashed to
-- the slab with leather, the SIGILS of air, fire, water and earth cut into it
-- one above the other. Feathers hang from the totem's wings and from the
-- stone's lashing.
--
-- THE REASON is told by which element is awake: your target wakes AIR, a
-- favour owed FIRE, your group and yourself WATER, a passer-by EARTH, and
-- somebody who asked wakes all four. What runs in the channel is the awake
-- element's: lava for fire, water for water, a quick pale stream for air, a
-- slow molten crawl for earth. The totem's eyes and the inlay round the icon
-- are the mark round the icon and wear the reason's colour; the sigils and
-- the channel are the stripe, and wear it where the marker says so, and each
-- element's own colour where it does not.
--
-- Every region is a texture from Textures/Stormcaller
-- (tools/make_stormcaller_textures.py). The stone, the wood, the tusks, the
-- leather and the feathers are baked, because they are decoration. Everything
-- that means something -- the eyes, the inlay, the sigils, the channel, the
-- list's pebbles, the glyphs -- is white or grey art coloured through
-- Looks.Colour, so one file serves every reason, both palettes, a custom
-- marker colour and the outcomes. The interface this file implements is
-- described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-stormcaller.lua):
--   * at rest, on Full effects, the channel RUNS (two layers of one drawing
--     scrolled past one another, Looks/Flow.lua), the feathers stir, the
--     sleeping sigils glimmer one after another down the stone, an ember
--     rises now and then and static glints at the wings' tips. hunt35-effects
--     lets the groups of `idle` loop with nobody owed, by name; the Flow
--     handles that run at rest are `flows`;
--   * a favour arriving is a BOLT FROM THE SKY onto the totem's crest (a
--     sheet of eight drawn frames, played once), the crest lit, the four
--     sigils flashing awake in turn down the stone and a light running the
--     channel's length;
--   * owed, the totem is CHARGED: an arc stands between the wings' tips, on
--     and off (a sheet of eight frames, looping), while the eyes, the awake
--     sigil's light and the channel's breathe three times and then hold lit;
--     the channel runs faster;
--   * a landing is CHAIN LIGHTNING along the slab's upper and lower edges,
--     from the totem to the standing stone (a sheet of eight frames, each
--     played once), every sigil flashing as it arrives, the crest lit, sparks
--     thrown from the crest, and the shared rings spreading from the icon;
--   * a refusal puts the elements OUT: the eyes gutter and go dark, the
--     sigils sleep, the channel cools to grey and stands still, chips of
--     stone fall from the slab, the icon greys and one ring snaps in; a cast
--     nobody confirmed does nothing;
--   * no additive light at rest: the bolts, the crest's flash, the sigils'
--     flashes and the rings are the only ADD regions, each lit under 0.6 s
--     and parked at nothing;
--   * the totem, its wings and feathers, the standing stone, the bolt from
--     the sky and the arc stand past the panel (`skyward` names the lights
--     that do). With the list hung over the panel the upper bolt of a landing
--     is not drawn and the list keeps right of the wings;
--   * Calm keeps to fades: nothing runs, stirs, glimmers or strikes;
--   * a fight stills all of it and puts the lights low, dulls the stone and
--     the wood, dims the words and greys the icon; the eyes, the inlay, the
--     awake sigil and the channel keep their colour;
--   * the icon is the slider's size, square in the maw or round in it as
--     "Round the icon off" says.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Stormcaller\\Stormcaller_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Storm = ns.Looks.Register("stormcaller", {
	name = L["Stormcaller -- a totem, a slab of stone and the four elements"],
	title = L["Stormcaller"],
	description = L["a totem, a slab of stone and the four elements"],
	order = 9.86,
	-- The slab holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the slate whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_stormcaller_textures.py (tests/scenarios/
-- look-stormcaller.lua compares them): the icon fills this much of the
-- bezel's box and the totem's file is shown this much larger than it; where
-- in that file the maw's middle is, the post's half-width, how far right the
-- tusk reaches, the eyes' middle and their file's width, a wing's tip; the
-- slab's design height, its ends' width and its middle tile's, the rows of
-- its face and of its channel, how far into an end they reach; the standing
-- stone's box, its middle line from the slab's right edge and above the
-- slab's middle; the sigils' boxes in the stone's file; the sheets; the
-- inlay's file against the icon; the tag's caps, the mask's fill and the
-- ring files' line.
local ICON_FRAME = 0.75
local TOTEM_SCALE = 2.2
local TOTEM_ICON_Y = 0.6
local TOTEM_POST = 0.26
local TOTEM_REACH = 0.32
local EYES_Y = 0.32
local EYES_W = 0.4
local WING_X = 0.47
local WING_Y = 0.08
local DESIGN_H = 128
local CAP_W = 64
local TILE_W = 256
local FACE_0 = 22
local FACE_1 = 94
local CHANNEL_0 = 101
local CHANNEL_1 = 114
local CAP_FACE = 14
local STELE_W = 44
local STELE_H = 176
local STELE_AT = 28
local STELE_UP = 6
local SIGIL_TOP = 12
local SIGIL_STEP = 56
local BOLT_ROWS = 8
local STRIKE_COLS = 4
local STRIKE_ROWS = 2
local ARC_COLS = 2
local ARC_ROWS = 4
local RIM_SCALE = 1.14
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.773
-- The ring files as the generator prints them (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- Figures of the layout, kept in one table (a function may hold sixty
-- upvalues): the slab's height against the button's, and against its width
-- at most unless the words need more; the face's share of the slab's height
-- and where its middle is; how far a middle tile may be stretched to end on a
-- whole one; the gap between the totem and the text, and with the icon off
-- between the slab's end block and the text; a chosen panel colour's share of
-- the slab; the list's nine-slice corner; the shadow's, and how far past the
-- slab its box reaches.
local LAY = {
	slabH = 1.14, slabMax = 0.30, face = (FACE_1 - FACE_0) / DESIGN_H, faceMid = (FACE_0 + FACE_1) / 2 / DESIGN_H,
	stretch = 0.20, textGap = 3, bareGap = 5, bodyMix = 0.25, listC = 9, shadowC = 16, shadowOut = 12,
	-- A tile of what runs in the channel is this many times as long as tall.
	flowTile = 8,
	-- The stone rim of the list's tablet, which a row's pebble keeps clear of.
	listRim = 4.5,
}
-- The slate's own luminance under the words, its darkest and its brightest
-- (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.03, 0.17
local CREAM = { 0.97, 0.95, 0.88 }
local TAG_INK = { 0.93, 0.93, 0.88 }
local MIST = { 0.84, 0.86, 0.86 }
-- A fight's stone and wood.
local DULL = { 0.82, 0.83, 0.87 }
-- The four elements, in the order the stone has them from its top: each
-- one's own colour, what runs in the channel for it (1 lava, 2 water) and how
-- fast. All four awake: the spirit's colour, and water.
local AIR, FIRE, WATER, EARTH = 1, 2, 3, 4
local ELEMENT = { target = AIR, owed = FIRE, group = WATER, self = WATER, nearby = EARTH }
local NATURE = { { 0.76, 0.90, 1.00 }, { 1.00, 0.50, 0.14 }, { 0.28, 0.64, 1.00 }, { 0.82, 0.64, 0.34 } }
local RUNS = { { 2, 2.0 }, { 1, 1.0 }, { 2, 1.0 }, { 1, 0.45 } }
local SPIRIT = { 0.88, 0.86, 1.00 }
local ALL_RUNS = { 2, 1.4 }
-- The eyes and the inlay where the marker does not colour them, and what a
-- refusal leaves in the channel.
local SILVER = { 0.84, 0.87, 0.90 }
local SPENT = { 0.30, 0.31, 0.33 }
-- Lightning's own colour, which the reason's is mixed into.
local STORM = { 0.80, 0.90, 1.00 }
local OUTCOME = {
	cast = { 0.56, 0.90, 0.46 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the slab dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.74
-- The eyes at rest, at the breath's peak, held after it and in a fight; the
-- awake sigil's light and the channel's over the same breath.
local EYES = { rest = 0.74, peak = 1.00, held = 0.92, combat = 0.50 }
local GLOW = { rest = 0.34, peak = 0.84, held = 0.56, combat = 0.14 }
local CORE = { rest = 0.22, peak = 0.70, held = 0.42 }
local BREATHS, BREATH = 3, 1.25
-- The channel: each layer's drift in tiles a second, how much faster while
-- somebody is owed, the second layer's share and how much paler it is. The
-- second layer is the same drawing laid longer (`long`: the part of the first
-- one's window it shows), upside down and begun elsewhere (`phase`), so the
-- two never fall into one figure seen again and again along the channel.
local FLOW = { du = { 0.06, 0.022 }, dv = { 0, 0 }, owed = 1.7, second = 0.50, pale = 0.40, long = 0.62, phase = 0.37 }
-- The sheets' frames a second: the chain lightning (0.5 s), the bolt from
-- the sky (0.44 s), the arc.
local BOLT_FPS, STRIKE_FPS, ARC_FPS = 16, 18, 13
local BOLT_SECONDS, STRIKE_SECONDS = BOLT_ROWS / BOLT_FPS, STRIKE_COLS * STRIKE_ROWS / STRIKE_FPS
-- The arc while the breath runs: dark, on, dark.
local ARC = { wait = 0.50, on = 0.52, rest = 1.15, peak = 0.92 }
-- The sigils waking in turn when a favour arrives: the first one's wait and
-- the step between them.
local WAKE = { first = 0.14, step = 0.08 }
-- At rest. The feathers' sway (degrees, seconds one way); the sleeping
-- sigils' glimmer (the round they share, the step between them, its peak);
-- the embers (wait, rise, rest); the static at the wings' tips (wait, rest).
local SWAY = { { 7, 2.4 }, { -6, 3.1 }, { 6.5, 2.7 }, { -7, 3.4 } }
local SHIMMER = { round = 9.2, step = 1.1, first = 0.6, peak = 0.50 }
local EMBERS = { { 0.8, 2.6, 3.9 }, { 3.1, 3.0, 4.6 }, { 5.2, 2.4, 5.3 } }
local STATIC = { { 2.3, 5.7 }, { 5.9, 6.6 } }
-- A landing's sparks: where each flies from the crest (degrees, the sun's way
-- from the right; how far, in totems).
local SPARKS = { { 24, 0.34 }, { 58, 0.40 }, { 84, 0.30 }, { 112, 0.38 }, { 140, 0.33 }, { 164, 0.36 } }
local SPARK_SECONDS = 0.5
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the stone above and below it.
function Storm.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 16)
end

-- The eyes and the inlay are the mark round the icon; the sigils and the
-- channel are the stripe.
function Storm.AccentCarriers(p)
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

-- Relative luminance of a grey, for the slate's own ink figures.
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

-- A colour for a texture whose alpha means something: the game keeps one
-- alpha for a texture, so the colour is given at the alpha the texture rests
-- at (Looks.lua, ONE ALPHA).
local Colour = ns.Looks.Colour

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- How many tiles of `unit` a length holds: a whole number when within
-- LAY.stretch of one (the tile is stretched to fit), else the fraction.
local function Tiles(length, unit)
	local n = math.max(0, length) / unit
	local r = math.max(1, math.floor(n + 0.5))
	if n > 0 and math.abs(r / math.max(n, 1e-6) - 1) <= LAY.stretch then return r end
	return n
end

-- A frame cut from one file into nine: corners from the outer quarters, edges
-- from the middle strips (the shadow, the list's tablet).
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

-- The slab: its left end, its tiled middle and its right end.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "SlabL", "SlabM", "SlabR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- The slab laid over a box. Each end is the design's proportion of the
-- height; the middle is tiled along what they leave, and ends on a whole
-- tile, where the right end takes the stone up.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local su = (y1 - y0) / DESIGN_H
	local cap = math.max(0, math.min(CAP_W * su, (x1 - x0) / 2))
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, math.max(x0 + cap, x1 - cap), y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
	s[2]:SetShown(x1 - x0 - 2 * cap > 0.5)
	local n = Tiles(x1 - x0 - 2 * cap, TILE_W * su)
	s[2]:SetTexCoord(1 - (n % 1), 1 + math.floor(n), 0, 1)
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
-- motion: every animation here runs on the region it lights or moves, parked
-- between plays, so nothing is left lit when it stops
---------------------------------------------------------------------------

local Park, Alpha, Move, Spin, Flash, Breathe, Fade, Twinkle, Glint, Sway, Fling, Runner
local Held, Shimmer, Rise, Gutter, Crackle
do
	function Park(group, region, to)
		local function park() region:SetAlpha(group.to or to or 0) end
		group:SetScript("OnFinished", park)
		group:SetScript("OnStop", park)
	end

	function Alpha(group, from, to, duration, order, delay, smoothing)
		local a = group:CreateAnimation("Alpha")
		a:SetFromAlpha(from)
		a:SetToAlpha(to)
		a:SetDuration(duration)
		a:SetOrder(order or 1)
		if delay and a.SetStartDelay then a:SetStartDelay(delay) end
		if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
		return a
	end

	function Move(group, duration, order, smoothing)
		local move = group:CreateAnimation("Translation")
		move:SetDuration(duration)
		move:SetOrder(order or 1)
		if smoothing and move.SetSmoothing then move:SetSmoothing(smoothing) end
		return move
	end

	function Spin(group, degrees, duration, order, point, smoothing)
		local turn = group:CreateAnimation("Rotation")
		if turn.SetDegrees then turn:SetDegrees(degrees) end
		if turn.SetOrigin then turn:SetOrigin(point or "CENTER", 0, 0) end
		turn:SetDuration(duration)
		turn:SetOrder(order or 1)
		if smoothing and turn.SetSmoothing then turn:SetSmoothing(smoothing) end
		return turn
	end

	-- Up to `peak` after `delay`, then down to `rest` (nothing unless said).
	-- The delay is an Alpha that holds, which reads the same on every client.
	function Flash(region, peak, up, down, rest, delay)
		local g = region:CreateAnimationGroup()
		local order = 1
		if delay and delay > 0 then
			Alpha(g, rest or 0, rest or 0, delay, 1)
			order = 2
		end
		g.up = Alpha(g, rest or 0, peak, up, order, nil, "OUT")
		g.down = Alpha(g, peak, rest or 0, down, order + 1, nil, "IN")
		Park(g, region, rest or 0)
		return g
	end

	-- A breath: `lo` to `hi` and back, for as long as it is left to.
	function Breathe(region, lo, hi)
		local g = region:CreateAnimationGroup()
		g:SetLooping("BOUNCE")
		Alpha(g, lo, hi, BREATH, 1, nil, "IN_OUT")
		Park(g, region, lo)
		return g
	end

	-- One fade from `from` to `to`, which it then holds; after `delay`, when
	-- one is given.
	function Fade(region, from, to, duration, delay)
		local g = region:CreateAnimationGroup()
		local order = 1
		if delay and delay > 0 then
			Alpha(g, from, from, delay, 1)
			order = 2
		end
		Alpha(g, from, to, duration, order, nil, "OUT")
		Park(g, region, to)
		return g
	end

	-- A twinkle: dark for `wait`, then up and out as it turns a quarter, once.
	function Twinkle(region, wait, peak, up, down)
		local g = region:CreateAnimationGroup()
		Alpha(g, 0, 0, wait, 1)
		Alpha(g, 0, peak, up, 2, nil, "OUT")
		Alpha(g, peak, 0, down, 3, nil, "IN")
		Spin(g, -45, up, 2)
		Spin(g, -45, down, 3)
		Park(g, region, 0)
		return g
	end

	-- Static: dark for `wait`, a quick double flicker as it turns, dark again
	-- for `rest`, over and over.
	function Glint(region, wait, rest, peak)
		local g = region:CreateAnimationGroup()
		g:SetLooping("REPEAT")
		Alpha(g, 0, 0, wait, 1)
		Alpha(g, 0, peak, 0.07, 2, nil, "OUT")
		Alpha(g, peak, peak * 0.2, 0.08, 3, nil, "IN")
		Alpha(g, peak * 0.2, peak, 0.06, 4, nil, "OUT")
		Alpha(g, peak, 0, 0.34, 5, nil, "IN")
		Spin(g, -45, 0.15, 2)
		Spin(g, -45, 0.40, 5)
		Alpha(g, 0, 0, rest, 6)
		Park(g, region, 0)
		return g
	end

	-- A feather stirring: a few degrees about the thong it hangs by and back,
	-- over and over.
	function Sway(region, degrees, seconds)
		local g = region:CreateAnimationGroup()
		g:SetLooping("BOUNCE")
		g.turn = Spin(g, degrees, seconds, 1, "TOP", "IN_OUT")
		return g
	end

	-- A spark or a chip of stone thrown: out by one offset (slowing) and down
	-- by another (quickening), which Apply gives it; lit as it leaves and
	-- gone as it lands. After `delay`, when one is given; `fall` for what
	-- only drops.
	function Fling(region, seconds, degrees, delay, fall)
		local g = region:CreateAnimationGroup()
		local order = 1
		if delay and delay > 0 then
			Alpha(g, 0, 0, delay, 1)
			order = 2
		end
		g.move = Move(g, seconds, order, fall and "IN_OUT" or "OUT")
		g.drop = Move(g, seconds, order, "IN")
		if degrees then Spin(g, degrees, seconds, order) end
		Alpha(g, 0, 1, seconds * 0.12, order, nil, "OUT")
		Alpha(g, 1, 0, seconds * 0.38, order, seconds * 0.62, "IN")
		Park(g, region, 0)
		return g
	end

	-- A light that runs: across by the offset Apply gives it, lit as it
	-- leaves and gone as it arrives.
	function Runner(region, duration, peak)
		local g = region:CreateAnimationGroup()
		g.move = Move(g, duration, 1, "OUT")
		Alpha(g, 0, peak, duration * 0.15, 1, nil, "OUT")
		Alpha(g, peak, 0, duration * 0.30, 1, duration * 0.70, "IN")
		Park(g, region, 0)
		return g
	end

	-- A sheet's light: up at once, held while its frames play, and out with
	-- the last of them. `seconds` in all.
	function Held(region, peak, seconds)
		local g = region:CreateAnimationGroup()
		Alpha(g, 0, peak, 0.02, 1)
		Alpha(g, peak, peak, math.max(0.01, seconds - 0.14), 2)
		Alpha(g, peak, 0, 0.12, 3, nil, "IN")
		Park(g, region, 0)
		return g
	end

	-- A sleeping sigil's glimmer: dark for `wait`, up and down, dark for
	-- `rest`, over and over. The four share a round, each a step behind the
	-- one above it.
	function Shimmer(region, wait, rest, peak)
		local g = region:CreateAnimationGroup()
		g:SetLooping("REPEAT")
		Alpha(g, 0, 0, wait, 1)
		Alpha(g, 0, peak, 0.50, 2, nil, "OUT")
		Alpha(g, peak, 0, 0.80, 3, nil, "IN")
		Alpha(g, 0, 0, rest, 4)
		Park(g, region, 0)
		return g
	end

	-- An ember: nothing for `wait`, then up and aside by the offsets Apply
	-- gives it, seen as it leaves and gone before it arrives; then nothing
	-- for `rest`, over and over.
	function Rise(region, wait, seconds, rest, peak)
		local g = region:CreateAnimationGroup()
		g:SetLooping("REPEAT")
		Alpha(g, 0, 0, wait, 1)
		g.move = Move(g, seconds, 2, "OUT")
		g.aside = Move(g, seconds, 2, "IN_OUT")
		Alpha(g, 0, peak, seconds * 0.18, 2, nil, "OUT")
		Alpha(g, peak, 0, seconds * 0.50, 2, seconds * 0.50, "IN")
		Alpha(g, 0, 0, rest, 3)
		Park(g, region, 0)
		return g
	end

	-- The eyes going out: a gutter down to nothing.
	function Gutter(region, from)
		local g = region:CreateAnimationGroup()
		Alpha(g, from, from * 0.30, 0.08, 1, nil, "OUT")
		Alpha(g, from * 0.30, from * 0.70, 0.07, 2, nil, "IN")
		Alpha(g, from * 0.70, 0, 0.27, 3, nil, "IN")
		Park(g, region, 0)
		return g
	end

	-- The arc between the wings' tips: dark, standing, dark, over and over.
	function Crackle(region)
		local g = region:CreateAnimationGroup()
		g:SetLooping("REPEAT")
		Alpha(g, 0, 0, ARC.wait, 1)
		Alpha(g, 0, ARC.peak, 0.05, 2, nil, "OUT")
		Alpha(g, ARC.peak, ARC.peak, ARC.on, 3)
		Alpha(g, ARC.peak, 0, 0.12, 4, nil, "IN")
		Alpha(g, 0, 0, ARC.rest, 5)
		Park(g, region, 0)
		return g
	end
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

function Storm:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file, blend, wrapH, wrapV)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if wrapH then t:SetTexture(ART .. file, wrapH, wrapV or wrapH) else t:SetTexture(ART .. file) end
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end
	local base = art:GetFrameLevel()
	-- A frame a few levels over the art and under the text.
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end
	local function dark(t)
		t:SetAlpha(0)
		return t
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.listShadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.listBody = Pieces(art, "BACKGROUND", -6, ART .. "Plank", keep)
	self.body = Body(art, "BACKGROUND", -5, keep)
	-- What runs in the channel: lava's two layers and water's, of which one
	-- pair is drawn; and the light that breathes in it.
	self.runs = {}
	for i, file in ipairs({ "Lava", "Water" }) do
		self.runs[i] = { tex(art, "BORDER", 1, file, nil, "REPEAT"), tex(art, "BORDER", 2, file, nil, "REPEAT") }
	end
	self.core = tex(art, "BORDER", 3, "Core")

	-- The standing stone, over the slab's right end: behind each sigil its
	-- light, the sigil lit, and the glimmer a sleeping one gives at rest.
	self.stele = tex(art, "ARTWORK", -7, "Stele")
	self.glows, self.sigils, self.shims = {}, {}, {}
	for i = 1, 4 do
		self.glows[i] = dark(tex(art, "ARTWORK", -6, "Glow"))
		self.sigils[i] = dark(tex(art, "ARTWORK", -5, "Sigils"))
		self.shims[i] = dark(tex(art, "ARTWORK", -4, "Sigils"))
		local v0 = (SIGIL_TOP + SIGIL_STEP * (i - 1)) / 256
		self.sigils[i]:SetTexCoord(0, 1, v0, v0 + SIGIL_STEP / 256)
		self.shims[i]:SetTexCoord(0, 1, v0, v0 + SIGIL_STEP / 256)
	end
	-- The totem, under the icon (ARTWORK 0), and its eyes.
	self.totem = tex(art, "ARTWORK", -7, "Totem")
	self.eyes = tex(art, "ARTWORK", -6, "Eyes")
	-- The feathers: two from the left wing's tip, one from the right's, one
	-- from the stone's lashing.
	self.feathers = {}
	for i = 1, #SWAY do
		self.feathers[i] = tex(art, "ARTWORK", 2, "Feather")
		if i % 2 == 0 then self.feathers[i]:SetTexCoord(1, 0, 0, 1) end
	end

	-- The inlay round the icon, over the icon's edge: on a frame above it.
	self.rimFrame = frame(1)
	self.rim = tex(self.rimFrame, "ARTWORK", 1, "Rim")

	-- The rings that spread from the maw when a buff lands and the one that
	-- snaps in when one is refused: frames over the art, under the text. No
	-- echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "FxRing", RING_PEAK, RING_EDGE)
	kit.RingArt(ART .. "FxRingSq", RING_PEAK, RING_EDGE)

	-- The lightning and the flashes, every one additive and parked dark: the
	-- chain along the slab's upper edge and its lower, the bolt from the
	-- sky, the crest lit, each sigil's flash.
	self.lightFrame = frame(2)
	self.bolts = { dark(tex(self.lightFrame, "OVERLAY", 1, "Bolt", "ADD")), dark(tex(self.lightFrame, "OVERLAY", 1, "Bolt", "ADD")) }
	self.strike = dark(tex(self.lightFrame, "OVERLAY", 1, "Strike", "ADD"))
	self.crown = dark(tex(self.lightFrame, "OVERLAY", 2, "Glow", "ADD"))
	self.flashes = {}
	for i = 1, 4 do self.flashes[i] = dark(tex(self.lightFrame, "OVERLAY", 2, "Glow", "ADD")) end
	-- What moves at rest, while somebody is owed, after a landing and after a
	-- refusal, none of it additive: the arc, the embers, the static, the
	-- crest's glint, a landing's sparks, the light that runs the channel, a
	-- refusal's chips of stone.
	self.idleFrame = frame(1)
	self.arc = dark(tex(self.idleFrame, "OVERLAY", 1, "Arc"))
	self.embers = {}
	for i = 1, #EMBERS do self.embers[i] = dark(tex(self.idleFrame, "OVERLAY", 2, "Spark")) end
	self.stars = {}
	for i = 1, #STATIC do self.stars[i] = dark(tex(self.idleFrame, "OVERLAY", 3, "Star")) end
	self.gem = dark(tex(self.idleFrame, "OVERLAY", 3, "Star"))
	self.sparks = {}
	for i = 1, #SPARKS do self.sparks[i] = dark(tex(self.idleFrame, "OVERLAY", 2, "Spark")) end
	self.tip = dark(tex(self.idleFrame, "OVERLAY", 2, "Spark"))
	self.pebbles = {}
	for i = 1, 4 do self.pebbles[i] = dark(tex(self.idleFrame, "ARTWORK", 3, "Pebble")) end
	-- The cursor's light: the slab's upper border lit.
	self.hoverFrame = frame(1)
	self.hoverLight = dark(tex(self.hoverFrame, "OVERLAY", 1, "Edge"))
	self.hoverLight:SetAllPoints(self.hoverFrame)

	-- The list's pebbles, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The chips: small tablets at the right end; their text is on textLayer,
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

	-- A round icon's circle; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything baked that a fight dulls.
	self.baked = { self.totem, self.stele, self.glyph }
	for _, s in ipairs({ self.feathers, self.pebbles, self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end
	-- The lights that are meant to leave the panel: the bolt comes from the
	-- sky, the arc stands over the totem, the chain runs the slab's edges.
	self.skyward = { self.strike, self.arc, self.crown, self.bolts[1], self.bolts[2] }
	self.awake = { false, false, false, true }

	-- What moves by its coordinates (Looks/Flow.lua): the channel's layers,
	-- the chain lightning, the bolt from the sky, the arc.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.runScroll = {}
	for i, pair in ipairs(self.runs) do
		self.runScroll[i] = { flow:Scroll(pair[1], FLOW.du[1], FLOW.dv[1], 1, 1), flow:Scroll(pair[2], FLOW.du[2], FLOW.dv[2], 1, -1) }
		self.runScroll[i][2]:Phase(FLOW.phase, 0)
	end
	self.boltSheets = {}
	for i, t in ipairs(self.bolts) do self.boltSheets[i] = flow:Sheet(t, 1, BOLT_ROWS, BOLT_ROWS, BOLT_FPS, false) end
	self.strikeSheet = flow:Sheet(self.strike, STRIKE_COLS, STRIKE_ROWS, STRIKE_COLS * STRIKE_ROWS, STRIKE_FPS, false)
	self.arcSheet = flow:Sheet(self.arc, ARC_COLS, ARC_ROWS, ARC_COLS * ARC_ROWS, ARC_FPS, true)
	-- What plays for as long as the look is at rest: `flows`, the pair in
	-- the channel (Tint names it).
	self.flows = {}

	self:BuildAnimations(function(g) anims[#anims + 1] = g return g end)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

function Storm:BuildAnimations(anim)
	-- The owed breath: the eyes, the channel's light, the arc between the
	-- wings; and each sigil's light, of which the awake ones' breathe. The
	-- eyes first: hunt35-effects times the breath by the first.
	self.arcAnim = anim(Crackle(self.arc))
	self.pulse = { anim(Breathe(self.eyes, EYES.rest, EYES.peak)), anim(Breathe(self.core, CORE.rest, CORE.peak)), self.arcAnim }
	self.glowPulse = {}
	for i, t in ipairs(self.glows) do self.glowPulse[i] = anim(Breathe(t, GLOW.rest, GLOW.peak)) end
	-- "Once": one rise and fall, 0.55 s.
	self.once = { anim(Flash(self.eyes, EYES.peak, 0.25, 0.30, EYES.rest)), anim(Flash(self.core, CORE.peak, 0.25, 0.30, CORE.rest)) }
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = { anim(Fade(self.eyes, EYES.rest, EYES.held, 0.5)), anim(Fade(self.core, CORE.rest, CORE.held, 0.5)) }

	-- A favour arriving: the bolt from the sky (its frames are Flow's), the
	-- crest lit, the sigils flashing awake in turn down the stone (the awake
	-- ones fading in behind their flash) and a light running the channel.
	self.strikeAnim = anim(Held(self.strike, 1, STRIKE_SECONDS))
	self.crownStrike = anim(Flash(self.crown, 0.85, 0.05, 0.32, 0, 0.06))
	self.tipAnim = anim(Runner(self.tip, 0.5, 0.95))
	self.arrive = { self.strikeAnim, self.crownStrike, self.tipAnim }
	self.wake, self.wakeIn = {}, {}
	for i = 1, 4 do
		local wait = WAKE.first + WAKE.step * (i - 1)
		self.wake[i] = anim(Flash(self.flashes[i], 0.80, 0.05, 0.22, 0, wait))
		self.wakeIn[i] = anim(Fade(self.sigils[i], 0, 1, 0.12, wait))
		self.arrive[#self.arrive + 1] = self.wake[i]
	end

	-- A landing: chain lightning along the slab's two edges (0.5 s), every
	-- sigil flashing as it arrives, the crest lit, sparks from the crest.
	self.boltAnims = { anim(Held(self.bolts[1], 1, BOLT_SECONDS)), anim(Held(self.bolts[2], 0.85, BOLT_SECONDS)) }
	self.crownLand = anim(Flash(self.crown, 0.70, 0.05, 0.30))
	self.landing = { self.boltAnims[1], self.boltAnims[2], self.crownLand }
	self.struck = {}
	for i = 1, 4 do
		self.struck[i] = anim(Flash(self.flashes[i], 0.85, 0.05, 0.28, 0, 0.16 + 0.02 * i))
		self.landing[#self.landing + 1] = self.struck[i]
	end
	self.sparkAnims = {}
	for i, t in ipairs(self.sparks) do
		self.sparkAnims[i] = anim(Fling(t, SPARK_SECONDS - 0.03 * (i % 3), nil, 0.02 * (i % 4)))
		self.landing[#self.landing + 1] = self.sparkAnims[i]
	end

	-- A refusal: the eyes gutter and go out, 0.42 s, and chips of stone fall
	-- from the slab for a second after (not a light: `aftermath`).
	self.gutter = anim(Gutter(self.eyes, EYES.rest))
	self.refusal = { self.gutter }
	self.aftermath = {}
	for i, t in ipairs(self.pebbles) do
		self.aftermath[i] = anim(Fling(t, 0.70 + 0.07 * i, (i % 2 == 0) and 160 or -190, 0.02 + 0.06 * (i - 1), true))
	end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- At rest: the feathers stir, the sleeping sigils glimmer in turn, the
	-- embers rise, static glints at the wings' tips. hunt35-effects lets the
	-- groups of this list loop with nobody owed, and no others. See Idle for
	-- when they run.
	self.sways, self.shimAnims, self.emberAnims, self.staticAnims = {}, {}, {}, {}
	self.idle = {}
	for i, t in ipairs(self.feathers) do
		self.sways[i] = anim(Sway(t, SWAY[i][1], SWAY[i][2]))
		self.idle[#self.idle + 1] = self.sways[i]
	end
	for i, t in ipairs(self.shims) do
		local wait = SHIMMER.first + SHIMMER.step * (i - 1)
		self.shimAnims[i] = anim(Shimmer(t, wait, SHIMMER.round - 1.3 - wait, SHIMMER.peak))
		self.idle[#self.idle + 1] = self.shimAnims[i]
	end
	for i, t in ipairs(self.embers) do
		self.emberAnims[i] = anim(Rise(t, EMBERS[i][1], EMBERS[i][2], EMBERS[i][3], 0.90))
		self.idle[#self.idle + 1] = self.emberAnims[i]
	end
	for i, t in ipairs(self.stars) do
		self.staticAnims[i] = anim(Glint(t, STATIC[i][1], STATIC[i][2], 0.90))
		self.idle[#self.idle + 1] = self.staticAnims[i]
	end
	-- The greeting: the stone in the crest glints, once, out by 0.8 s.
	self.greet = { anim(Twinkle(self.gem, 0.30, 0.9, 0.12, 0.34)) }

	-- The cursor's light on the upper border, both ways; from and to are set
	-- for each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Storm:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	self.round = p.roundIcon and true or false
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua), and how far left of the text it starts.
	self.pitch = sub + 7
	self.rowReach = 18

	-- The icon: the slider's size, held inside the button. The bezel's box is
	-- the icon's frame, held inside the button's height; the totem's file is
	-- shown TOTEM_SCALE larger, taller than the slab and the button: the
	-- totem stands proud of both. When the cap bites, the maw shrinks under
	-- the icon, which draws over it. The post's left edge is the button's.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local totem = bz * TOTEM_SCALE
	local cx, cy = TOTEM_POST * totem, H / 2
	-- The slab: a little taller than the button, so that its face, which is
	-- above its middle (the channel lies under it), is the words' height and
	-- centred on the button. On a button much taller than it is wide the slab
	-- keeps to a part of the width (and to what the words need).
	local ph = math.min(H * LAY.slabH, math.max(W * LAY.slabMax, (fs + 2 + sub + 4) / LAY.face))
	local su = ph / DESIGN_H
	local top = cy - LAY.faceMid * ph
	-- From under the totem's post to the right edge; with the icon off, the
	-- whole width.
	local plateX = showIcon and (cx * 0.4) or 0
	self.top, self.plateX, self.ph, self.su, self.bottom = top, plateX, ph, su, top + ph
	PlaceBody(self.body, art, plateX, top, W, top + ph)
	-- The slab's colour: as it is, or a chosen panel colour mixed in.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local pr, pg, pb = 1, 1, 1
	if not Untouched(c, d) then
		pr = 1 + ((c[1] or 0) - 1) * LAY.bodyMix
		pg = 1 + ((c[2] or 0) - 1) * LAY.bodyMix
		pb = 1 + ((c[3] or 0) - 1) * LAY.bodyMix
	end
	self.bodyColour = { pr, pg, pb }
	local alpha = (type(c) == "table" and c[4]) or 1
	self.shadowAlpha = math.min(1, alpha + 0.05) * (alpha < 0.2 and 0 or 1)
	for _, t in ipairs(self.shadow) do Colour(t, 0, 0, 0, self.shadowAlpha) end
	for _, t in ipairs(self.listShadow) do Colour(t, 0, 0, 0, self.shadowAlpha) end
	self:PlaceShadow(nil)

	local reach = cx + TOTEM_REACH * totem
	local textX = showIcon and (reach + LAY.textGap) or ((CAP_W - CAP_FACE) * su + LAY.bareGap)
	self.iconSize, self.cx, self.cy, self.bz, self.totemSize, self.textX = iconSize, cx, cy, bz, totem, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self:PlaceTotem(showIcon)
	self:PlaceStele()
	self:PlaceChannel(showIcon)
	self:PlaceMotion(showIcon, above)

	-- The cursor's light over the upper border.
	Box(self.hoverFrame, art, showIcon and (cx + TOTEM_POST * totem) or (plateX + 4), top, self.rootX, top + FACE_0 * su)
	Colour(self.hoverLight, STORM[1], STORM[2], STORM[3])

	local block = fs + 2 + sub
	self.block = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of the standing stone.
	local chipH = sub + 7
	self.chipH = chipH
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -self.chipInset, 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText, self.measuredText = nil, nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list's rows start where the name does, clear of the totem, and end
	-- where the standing stone begins. Hung over the panel, the list keeps
	-- right of the totem's wing and the feather on it.
	-- The tablet begins far enough left of them to hold each row's pebble,
	-- behind the totem's jaw: a pebble is sub + 1 across, its middle 9 left
	-- of its row's words, and lies on the tablet's slate, clear of its rim.
	local reach = 9 + (sub + 1) / 2 + LAY.listRim
	self.rowX = math.max(textX, 24)
	self.listX0 = math.min(showIcon and (cx + TOTEM_POST * totem + 2) or (plateX + 2), self.rowX - reach)
	if above and showIcon then
		self.listX0 = math.max(self.listX0, cx + totem * 0.5 + 3)
		self.rowX = math.max(self.rowX, self.listX0 + reach)
	end
	self.listX1 = math.max(self.rowX + 30, self.rootX + 3)
	local rowWidth = math.max(20, self.listX1 - self.rowX - 9)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	PlaceBody(self.body, art, plateX, top, W, top + ph)
	for _, t in ipairs({ self.totem, self.eyes, self.rim, self.strike, self.arc, self.crown, self.gem, self.feathers[1],
		self.feathers[2], self.feathers[3], self.stars[1], self.stars[2] }) do
		t:SetShown(showIcon)
	end
	for _, t in ipairs(self.sparks) do t:SetShown(showIcon) end
	self.fx:SetShown(showIcon)
	for _, t in ipairs({ self.stele, self.feathers[4] }) do t:SetShown(self.steleOK) end
	for _, list in ipairs({ self.glows, self.sigils, self.shims, self.flashes }) do
		for _, t in ipairs(list) do t:SetShown(self.steleOK) end
	end
	for _, pair in ipairs(self.runs) do
		for _, t in ipairs(pair) do t:Hide() end
	end
	self.core:SetShown(self.channelOK)
	self.tip:SetShown(self.channelOK)
	self.bolts[1]:SetShown(self.boltOK and not above)
	self.bolts[2]:SetShown(self.boltOK)
	Each(self.listBody, "Hide")
	Each(self.listShadow, "Hide")
	for _, t in ipairs(self.beads) do t:Hide() end
	self.glyph:Hide()
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent, self.calmLit, self.owed = nil, nil, nil
	self.liquid = nil
	self:Rest()
	self:Dress()
	self:Tint()
	if held then self:Combat(true) end
	-- Asked afresh: what stirs may stand elsewhere now.
	self.idleState = nil
	self:Idle()

	-- The count's room: a two-digit tag, the standing stone and its inset.
	-- Chip widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The totem, its eyes, the inlay and the icon's shape, the rings' room, and
-- the lights and the feathers that are the totem's.
function Storm:PlaceTotem(showIcon)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local cx, cy, size, iconSize, H = self.cx, self.cy, self.totemSize, self.iconSize, self.H
	local round = self.round
	local topY = cy - TOTEM_ICON_Y * size
	self.totemTop = topY
	At(self.totem, art, cx, topY + size / 2, size)
	At(self.eyes, art, cx, topY + EYES_Y * size, EYES_W * size, EYES_W * size / 2)
	self.rimFrame:ClearAllPoints()
	self.rimFrame:SetAllPoints(art)
	self.rim:SetTexture(ART .. (round and "RimRound" or "Rim"))
	At(self.rim, art, cx, cy, iconSize * RIM_SCALE)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	-- The wings' tips, where the feathers hang and the arc stands.
	local wingX, wingY = WING_X * size, topY + WING_Y * size
	self.wingX, self.wingY = wingX, wingY
	local long = math.max(10, size * 0.27)
	local hang = {
		{ cx - wingX + 1, wingY + 1, long },
		{ cx - wingX + size * 0.09, wingY + size * 0.05, long * 0.78 },
		-- The right wing's hangs over the slab's border and no lower: the
		-- words begin under it.
		{ cx + wingX - 1, wingY + 1, math.max(6, math.min(long * 0.72, self.top + FACE_0 * self.su - wingY - 2)) },
	}
	for i = 1, 3 do
		local f = self.feathers[i]
		f:ClearAllPoints()
		f:SetPoint("TOP", art, "TOPLEFT", hang[i][1], -hang[i][2])
		f:SetSize(hang[i][3] / 2, hang[i][3])
	end
	-- The arc: its ends on the wings' tips, a frame of its sheet four times
	-- as wide as tall, its ends 7 texels in from each side of 128 and 6 up
	-- from the foot of 32.
	local arcW = 2 * wingX * 128 / 114
	local arcH = arcW / 4
	Box(self.arc, art, cx - arcW / 2, wingY - arcH * 26 / 32, cx + arcW / 2, wingY + arcH * 6 / 32)
	for i, t in ipairs(self.stars) do
		At(t, art, cx + (i == 1 and -1 or 1) * wingX, wingY, math.max(8, size * 0.20))
	end
	-- The crest: its stone, the light over it, and the bolt that comes down
	-- onto it (a frame twice as tall as wide, its foot 8 texels up of 128).
	local crestY = topY + size * 0.14
	self.crestY = crestY
	At(self.gem, art, cx, crestY, math.max(8, size * 0.22))
	At(self.crown, art, cx, crestY + size * 0.04, size * 0.95)
	local sh = size * 0.62
	Box(self.strike, art, cx - sh / 4, crestY - sh * 120 / 128, cx + sh / 4, crestY + sh * 8 / 128)
	-- The icon: round where the switch says so.
	local maskFile = ART .. "Mask"
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	if showIcon and round then
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
		-- The rings spread from the inlay round the icon.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, 2), iconSize)
		self.fx:Shape(round, ART .. "FxRing", ART .. "FxRingSq", round and maskFile or nil)
		-- The room the rings have: to the text (less a margin), to the
		-- button's left edge, and to its top and bottom.
		local limitH = math.min(self.textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(round and maskFile or WHITE) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end
end

-- The standing stone over the slab's right end, its sigils and their lights,
-- the feather on its lashing, and the room it takes at the right.
function Storm:PlaceStele()
	local art = self.kit.art
	local W, su = self.W, self.su
	local w, h = STELE_W * su, STELE_H * su
	local x, y = W - STELE_AT * su, self.top + self.ph / 2 - STELE_UP * su
	At(self.stele, art, x, y, w, h)
	local y0 = y - h / 2
	local step = SIGIL_STEP / 256 * h
	self.sigilAt = {}
	for i = 1, 4 do
		local sy = y0 + (SIGIL_TOP + SIGIL_STEP * (i - 1)) / 256 * h
		Box(self.sigils[i], art, x - w / 2, sy, x + w / 2, sy + step)
		Box(self.shims[i], art, x - w / 2, sy, x + w / 2, sy + step)
		At(self.glows[i], art, x, sy + step / 2, w * 1.25)
		At(self.flashes[i], art, x, sy + step / 2, w * 1.7)
		self.sigilAt[i] = sy + step / 2
	end
	self.steleX, self.steleTop, self.steleW = x, y0, w
	-- The words, the tags and the list keep left of the stone.
	self.rootX = x - w / 2 - 1
	self.chipInset = math.ceil(W - self.rootX) + 2
	-- Only where the slab is long enough to carry it beside the totem.
	self.steleOK = self.rootX - self.textX >= 24
	if not self.steleOK then
		self.rootX = W - 6
		self.chipInset = 8
	end
	-- The feather on the lower lashing, down the stone's outer side.
	local long = math.max(8, h * 0.26)
	local f = self.feathers[4]
	f:ClearAllPoints()
	f:SetPoint("TOP", art, "TOPLEFT", x + w * 0.40, -(self.sigilAt[3] + step / 2 - 1))
	f:SetSize(long / 2, long)
end

-- The channel: what runs in it, the light that breathes in it and the one
-- that runs its length; and the chain lightning along the slab's two edges.
function Storm:PlaceChannel(showIcon)
	local art = self.kit.art
	local su, top = self.su, self.top
	local x0 = showIcon and (self.cx + TOTEM_POST * self.totemSize - 1) or ((CAP_W - CAP_FACE + 1) * su)
	local x1 = self.W - (CAP_W - CAP_FACE + 1) * su
	local y0, y1 = top + (CHANNEL_0 + 1) * su, top + (CHANNEL_1 - 1) * su
	self.channelOK = x1 - x0 >= 16
	local tile = (y1 - y0) * LAY.flowTile
	for i, pair in ipairs(self.runs) do
		for k, t in ipairs(pair) do
			Box(t, art, x0, y0, x1, y1)
			-- The second layer: longer, and upside down.
			if k == 2 then
				self.runScroll[i][k]:Window((x1 - x0) / tile * FLOW.long, -1)
			else
				self.runScroll[i][k]:Window((x1 - x0) / tile, 1)
			end
		end
	end
	Box(self.core, art, x0, y0 - 2 * su, x1, y1 + 2 * su)
	local dot = math.max(7, (y1 - y0) * 2.6)
	At(self.tip, art, x0 + 2, (y0 + y1) / 2, dot)
	self.tipAnim.move:SetOffset(x1 - x0 - 4, 0)
	self.chX0, self.chX1, self.chY = x0, x1, (y0 + y1) / 2
	-- The chain: from the totem's wing to the standing stone, a frame of its
	-- sheet eight times as long as tall, the upper one over the slab's upper
	-- edge and clear of the words, the lower under its lower edge.
	local bx0 = showIcon and (self.cx + TOTEM_POST * self.totemSize - 4) or (self.plateX + 4)
	local bx1 = self.steleOK and (self.steleX + 2) or (self.W - 2)
	local bh = (bx1 - bx0) / 8
	self.boltOK = bx1 - bx0 >= 60
	local up = top - bh * 0.30
	Box(self.bolts[1], art, bx0, up - bh / 2, bx1, up + bh / 2)
	local down = top + self.ph + bh * 0.26
	Box(self.bolts[2], art, bx0, down - bh / 2, bx1, down + bh / 2)
end

-- What moves: the embers, a landing's sparks, a refusal's chips of stone.
-- Each is given where it starts and where it goes.
function Storm:PlaceMotion(showIcon, above)
	local art = self.kit.art
	local cx, size = self.cx, self.totemSize
	-- With the list hung over the panel nothing rises far over it.
	local lift = above and 0.35 or 1
	local mote = math.max(5, math.min(11, self.H * 0.17))
	-- The embers: from the crest, from the standing stone's head, and from
	-- the channel's far end, each up and a little aside.
	local from = {
		{ showIcon and cx or (self.plateX + 10), showIcon and (self.crestY - size * 0.06) or self.top, 5, 13 * lift },
		{ self.steleOK and self.steleX or (self.W - 8), self.steleOK and (self.steleTop + 2) or self.top, -4, 11 * lift },
		{ self.chX1 - (self.chX1 - self.chX0) * 0.18, self.chY, 4, 6 },
	}
	for i, t in ipairs(self.embers) do
		local s = from[i]
		At(t, art, s[1], s[2], mote)
		self.emberAnims[i].move:SetOffset(0, s[4])
		self.emberAnims[i].aside:SetOffset(s[3], 0)
	end
	-- A landing's sparks: from the crest, up and outward, and down a little
	-- as they go.
	for i, t in ipairs(self.sparks) do
		local a = math.rad(SPARKS[i][1])
		local ux, uy = math.cos(a), math.sin(a)
		At(t, art, cx + ux * size * 0.10, self.crestY - uy * size * 0.06, mote)
		self.sparkAnims[i].move:SetOffset(ux * size * SPARKS[i][2], uy * size * SPARKS[i][2] * lift)
		self.sparkAnims[i].drop:SetOffset(0, -size * 0.10)
	end
	-- The chips of stone: from the slab's lower edge, down and aside.
	local x0, x1 = self.chX0, self.chX1
	for i, t in ipairs(self.pebbles) do
		At(t, art, x0 + (x1 - x0) * (0.14 + 0.24 * (i - 1)), self.bottom - 1, math.max(4, mote * 0.8))
		self.aftermath[i].move:SetOffset((i % 2 == 0) and 5 or -6, 0)
		self.aftermath[i].drop:SetOffset(0, -self.H * 0.42)
	end
end

-- Every light where it rests while nothing plays: the eyes lit, the awake
-- sigils and their light, the channel's low, the rest dark. `held`: lit as
-- the breath leaves them.
function Storm:Lights(held)
	local out = self.refused and true or false
	local fight = self.combat and true or false
	-- The eyes going out are left to go out: the gutter ends dark.
	if not self.gutter:IsPlaying() then
		self.eyes:SetAlpha(out and 0 or (fight and EYES.combat or (held and EYES.held or EYES.rest)))
	end
	self.core:SetAlpha((out or fight) and 0 or (held and CORE.held or CORE.rest))
	for i = 1, 4 do
		local on = self.awake[i] and not out
		self.sigils[i]:SetAlpha(on and 1 or 0)
		self.glows[i]:SetAlpha(on and (fight and GLOW.combat or (held and GLOW.held or GLOW.rest)) or 0)
	end
end

-- Every light where it rests, and everything parked dark.
function Storm:Rest()
	self:Lights()
	for _, t in ipairs({ self.arc, self.strike, self.crown, self.gem, self.tip, self.hoverLight, self.bolts[1], self.bolts[2] }) do
		t:SetAlpha(0)
	end
	for _, list in ipairs({ self.shims, self.flashes, self.embers, self.stars, self.sparks, self.pebbles }) do
		for _, t in ipairs(list) do t:SetAlpha(0) end
	end
end

-- What the look does at rest: the channel runs, the feathers stir, the
-- sleeping sigils glimmer, the embers rise and static glints, on Full
-- effects, out of a fight and with the prompt up; all of it is stopped
-- otherwise (stopped, not paused: the channel stands as it is, the lights
-- park dark). Asked at every paint (Painted), so it does nothing unless
-- something changed.
function Storm:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.refused and 2 or 0) + (self.owed and 4 or 0) + 8 * (self.liquid or 0)
	for i = 1, 4 do
		if self.awake[i] then state = state + 32 * 2 ^ i end
	end
	if state == self.idleState then return end
	self.idleState = state
	-- A refusal leaves the elements out: nothing stirs until the next reason
	-- wakes them.
	local alive = on and not self.refused
	for i, pair in ipairs(self.runScroll) do
		for k, h in ipairs(pair) do
			if alive and self.channelOK and i == self.liquid then
				local speed = (self.speed or 1) * (self.owed and FLOW.owed or 1)
				h:Speed(FLOW.du[k] * speed, FLOW.dv[k] * speed)
				if not h:IsPlaying() then h:Play() end
			else
				h:Stop()
			end
		end
	end
	local totemUp = self.kit.icon:IsShown()
	for i, g in ipairs(self.sways) do
		local there = (i == 4) and self.steleOK or (i < 4 and totemUp)
		if alive and there then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for i, g in ipairs(self.shimAnims) do
		if alive and self.steleOK and not self.awake[i] then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for _, g in ipairs(self.emberAnims) do
		if alive and self.channelOK then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for _, g in ipairs(self.staticAnims) do
		if alive and totemUp then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome.
function Storm:Greet()
	if not self.active or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; the element is the one this person's reason
-- wakes (a marker of one colour for every reason paints no new colour, so
-- PaintReason is not told); and somebody new on the panel is greeted, once.
-- A favour arriving has its own lights, so the greeting is for a new face
-- only.
function Storm:Painted(entry)
	local reason = entry and entry.reason
	if reason and reason ~= self.reason and not self.outcomeOn then
		self.reason = reason
		self:Tint()
	end
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (reason == "owed") then self:Greet() end
end

-- The shadow under the slab, and the one under the list's tablet when it is
-- out.
function Storm:PlaceShadow(list)
	local art = self.kit.art
	local top = self.top or 0
	PlacePieces(self.shadow, art, (self.plateX or 0) - LAY.shadowOut + 2, top - LAY.shadowOut + 1, self.W + LAY.shadowOut - 2,
		top + (self.ph or self.H) + LAY.shadowOut + 1, LAY.shadowC)
	Each(self.listShadow, "SetShown", list ~= nil)
	if list then
		PlacePieces(self.listShadow, art, list[1] - LAY.shadowOut + 2, list[2] - LAY.shadowOut + 2, list[3] + LAY.shadowOut - 1,
			list[4] + LAY.shadowOut + 1, LAY.shadowC)
	end
end

function Storm:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the slate, whatever the panel colour: the legibility the
	-- shared code works out is held against the slate's own two ends.
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
	kit.name:SetShadowColor(0, 0.01, 0.03, 0.95)
	kit.name:SetShadowOffset(1, -1)
	kit.sub:SetShadowColor(0, 0.01, 0.03, 1)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are slate whatever the panel, so their text is pale as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.92, 0.92, 0.86, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffa9adb3"
end

function Storm:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	self.flow:StopAll()
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	-- Every parked light at rest after the Stop: a finished fade is not
	-- stopped at all, and the cursor leaves for the next look.
	self.refused, self.combat = nil, nil
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
	self.hovered, self.outcomeOn = nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
	self.pulseSpent, self.calmLit, self.owed, self.idleState, self.greeted = nil, nil, nil, nil, nil
	self.reason, self.liquid = nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Storm:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The standing stone is at the far end.
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
		name:SetPoint("LEFT", self.textX, 0)
		name:SetPoint("RIGHT", -inset, 0)
	end
	-- Placed again by Fitted, which knows whether the verdict's glyph leads.
	self.subLead = nil
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
end

-- Whether the reason line holds the verdict PaintOutcome wrote: the only
-- time a glyph leads it.
function Storm:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Storm:Fitted(fs)
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
function Storm:NameFits(room)
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
function Storm:KeyLabel()
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
function Storm:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Storm:Chip(on)
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
			-- A key bound anew is a tag of a new width: Prompt places the
			-- lines again, beside it.
			kit.fit.right = nil
		end
		keyUp = self:NameFits(self.keyRoom)
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
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -self.chipInset, 0)
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

-- The stone and the wood as the moment has them: dulled for a fight, else
-- themselves.
function Storm:Dress()
	local fight = self.combat and true or false
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(fight)
		if fight then Colour(t, DULL[1], DULL[2], DULL[3]) else Colour(t, 1, 1, 1) end
	end
	local pc = self.bodyColour or { 1, 1, 1 }
	local k = fight and BODY_COMBAT or 1
	Each(self.body, "SetDesaturated", fight)
	for _, t in ipairs(self.body) do Colour(t, pc[1] * k, pc[2] * k, pc[3] * k) end
end

-- What runs in the channel, in its colour: the pair of layers for `liquid`
-- drawn, the second paler and thinner, the other pair away.
function Storm:Channel(liquid, r, g, b)
	local lr, lg, lb = self.kit.Tint(r, g, b, FLOW.pale)
	for i, pair in ipairs(self.runs) do
		local on = i == liquid and self.channelOK
		pair[1]:SetShown(on)
		pair[2]:SetShown(on)
		if on then
			Colour(pair[1], r, g, b)
			Colour(pair[2], lr, lg, lb, FLOW.second)
		end
	end
	self.flows = self.runScroll[liquid] or {}
end

-- What a refusal leaves: the eyes out, the sigils asleep, the channel cooled
-- to grey and standing still: until the next PaintReason.
function Storm:Spend()
	self:Channel(self.liquid or 1, SPENT[1], SPENT[2], SPENT[3])
	StopAll(self.glowPulse)
	StopAll(self.wakeIn)
	self:Lights()
	self:Idle()
end

-- The element this reason wakes, and everything in its colours. The eyes and
-- the inlay wear the reason's where the marker is the mark round the icon,
-- else silver; the sigils and the channel wear it where the marker is the
-- stripe, else each element's own. The reason line is warmed towards it.
function Storm:Tint()
	local kit = self.kit
	local c = self.rgb or SILVER
	local r, g, b = c[1], c[2], c[3]
	local mode = self.mode or "icon"
	local ring = mode == "icon" or mode == "both"
	local stripe = mode == "stripe" or mode == "both"
	local reason = self.reason or "nearby"
	local all = reason == "asked"
	local element = ELEMENT[reason] or EARTH
	local changed = false
	for i = 1, 4 do
		local on = all or i == element
		if on ~= self.awake[i] then changed = true end
		self.awake[i] = on
	end

	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end
	Colour(self.rim, cr, cg, cb)
	local er, eg, eb = kit.Tint(cr, cg, cb, 0.30)
	Colour(self.eyes, er, eg, eb)
	self.tint = { cr, cg, cb }

	for i = 1, 4 do
		local n = NATURE[i]
		local sr, sg, sb = n[1], n[2], n[3]
		if stripe then sr, sg, sb = r, g, b end
		local lr, lg, lb = kit.Tint(sr, sg, sb, 0.25)
		Colour(self.sigils[i], lr, lg, lb)
		Colour(self.glows[i], sr, sg, sb)
		Colour(self.shims[i], lr, lg, lb)
		local fr, fg, fb = kit.Tint(sr, sg, sb, 0.5)
		Colour(self.flashes[i], fr, fg, fb)
	end
	-- The channel: the awake element's, or the spirit's when all four are.
	local n = all and SPIRIT or NATURE[element]
	local runs = all and ALL_RUNS or RUNS[element]
	local vr, vg, vb = n[1], n[2], n[3]
	if stripe then vr, vg, vb = r, g, b end
	self.liquid, self.speed = runs[1], runs[2]
	if self.refused then
		self:Channel(self.liquid, SPENT[1], SPENT[2], SPENT[3])
	else
		self:Channel(self.liquid, vr, vg, vb)
	end
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.45)
	Colour(self.core, ir, ig, ib)
	Colour(self.tip, ir, ig, ib)
	for _, t in ipairs(self.embers) do Colour(t, ir, ig, ib) end
	-- Lightning: its own pale blue, the reason's colour in it.
	local br = STORM[1] + (r - STORM[1]) * 0.35
	local bg = STORM[2] + (g - STORM[2]) * 0.35
	local bb = STORM[3] + (b - STORM[3]) * 0.35
	for _, t in ipairs({ self.bolts[1], self.bolts[2], self.strike, self.arc, self.crown, self.stars[1], self.stars[2], self.gem }) do
		Colour(t, br, bg, bb)
	end
	for _, t in ipairs(self.sparks) do Colour(t, br, bg, bb) end
	-- The reason line: a pale mist taken most of the way to the reason, held
	-- to its contrast on the slate.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, 7)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glyph, sr, sg, sb)

	-- Another element awake: the lights are where the new one has them, and
	-- a running breath goes on in the new one's light.
	if changed or not self.lit then
		self.lit = true
		StopAll(self.glowPulse)
		StopAll(self.wakeIn)
		self:Lights(self.owed and (self.pulseSpent or self.calmLit))
		if self.pulse[1]:IsPlaying() then
			for i = 1, 4 do
				if self.awake[i] and not self.refused then self.glowPulse[i]:Play() end
			end
		end
		self:Idle()
	end
end

function Storm:PaintReason(r, g, b, reason, mode)
	-- A refusal put the elements out: they wake again here, and a fight
	-- keeps the icon grey.
	local was = self.refused
	self.refused = nil
	self.mode = mode or "icon"
	if self.mode == "off" then
		self.rgb = SILVER
	else
		self.rgb = { r, g, b }
	end
	if reason then self.reason = reason end
	if was then self.lit = nil end
	self:Tint()
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The slab holds; everything that moves stops and the lights go low, the
-- stone and the wood dull, the icon greys and the words dim. The eyes, the
-- inlay, the awake sigil and the channel keep their colour: the reason is
-- the one coloured thing left.
function Storm:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Dress()
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon shows two
	-- grounds.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	if on then
		self:StopAttention()
		self:StopFlourishes()
		StopAll(self.greet)
		StopAll(self.aftermath)
	end
	self:Lights()
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest. The arc goes with it.
function Storm:HoldPulse(spent)
	StopAll(self.pulse)
	StopAll(self.glowPulse)
	self.arcSheet:Stop()
	self.arc:SetAlpha(0)
	self:Lights(spent)
end

-- The lights the flourishes share are one set of regions: one plays at a
-- time.
function Storm:StopLights()
	StopAll(self.arrive)
	StopAll(self.wakeIn)
	StopAll(self.landing)
	StopAll(self.refusal)
	self.strikeSheet:Stop()
	for _, h in ipairs(self.boltSheets) do h:Stop() end
end

function Storm:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	local was = self.owed
	self.owed = true
	if not was then self:Idle() end
	-- A refusal put the elements out: nothing strikes or breathes until the
	-- next PaintReason wakes them.
	if self.refused then
		self:HoldPulse()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The bolt comes for a new favour, never a new face.
		if full and not (self.outcomeOn or self.kit.OutcomeLive()) then
			self:StopLights()
			StopAll(self.calm)
			if self.kit.icon:IsShown() then
				self.strikeSheet:Play()
				self.strikeAnim:Play()
				self.crownStrike:Play()
			end
			if self.channelOK then self.tipAnim:Play() end
			if self.steleOK then
				for i = 1, 4 do
					self.wake[i]:Play()
					if self.awake[i] then
						self.sigils[i]:SetAlpha(0)
						self.wakeIn[i]:Play()
					end
				end
			end
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
		-- Calm: one fade up to the held light, and nothing loops or plays.
		if not self.calmLit then
			self.calmLit = true
			StopAll(self.pulse)
			StopAll(self.glowPulse)
			-- Effects turned to Calm in the middle of a breath: the arc's
			-- frames were still being played, with Flow's clock under them.
			self.arcSheet:Stop()
			PlayAll(self.calm)
			for i = 1, 4 do
				if self.awake[i] then self.glows[i]:SetAlpha(GLOW.held) end
			end
		end
		return
	end
	if self.pulseSpent then
		if self.pulse[1]:IsPlaying() then self:HoldPulse(true) end
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps it
	-- going but takes its own three breaths.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		StopAll(self.calm)
		self.eyes:SetAlpha(EYES.rest)
		self.core:SetAlpha(CORE.rest)
		for _, g in ipairs(self.pulse) do g:Play() end
		if self.kit.icon:IsShown() then self.arcSheet:Play() end
		for i = 1, 4 do
			if self.awake[i] then self.glowPulse[i]:Play() end
		end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly. The
	-- lights held, and the awake sigil, are what say "owed" after.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Storm.pulseGen or not Storm.active then return end
			Storm.pulseSpent = true
			if Storm.pulse[1]:IsPlaying() then
				Storm:HoldPulse(true)
				-- Settled: the crest's stone says so, once.
				Storm:Greet()
			end
		end)
	end
end

function Storm:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.calm)
	StopAll(self.once)
	self.tipAnim:Stop()
	self:HoldPulse()
	self.calmLit = nil
	self.owed = nil
	if self.active then self:Idle() end
end

function Storm:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal puts the elements out: the eyes gutter and go dark, the
	-- sigils sleep, the channel cools and stands still, chips of stone fall
	-- and one ring snaps in onto the maw. The text's shake is Prompt's.
	if kind == "failed" then
		local lit = not self.refused and not self.combat
		self.refused = true
		self:StopLights()
		StopAll(self.pulse)
		StopAll(self.glowPulse)
		self.arcSheet:Stop()
		self.arc:SetAlpha(0)
		if not self.combat then
			if lit and shown then PlayAll(self.refusal) end
			if self.channelOK then PlayAll(self.aftermath) end
		end
		self:Spend()
		if shown then self.fx:Refuse(1.00, 0.40, 0.34, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- The chain runs the slab's edges, the lower a frame ahead of the upper
	-- so the two are never one drawing; the sigils flash as it reaches them.
	if self.boltOK then
		for i, h in ipairs(self.boltSheets) do
			if i == 2 or not self.above then
				h:Play()
				if i == 2 then
					h.t0 = h.t0 - 1 / BOLT_FPS
					h:Write(GetTime())
				end
				self.boltAnims[i]:Play()
			end
		end
	end
	if self.steleOK then PlayAll(self.struck) end
	if shown then
		self.crownLand:Play()
		PlayAll(self.sparkAnims)
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
end

function Storm:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Storm:Hover(on)
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
-- the eye never has to find the person again. The channel's light takes the
-- outcome's colour.
function Storm:PaintOutcome(kind, lead, sub, who, stamp)
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
	StopAll(self.calm)
	StopAll(self.once)
	self.refused = kind == "failed"
	self:HoldPulse()
	Colour(self.core, o[1], o[2], o[3])
	if self.refused then self:Spend() end
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 7)
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

function Storm:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A tablet of the same slate under the slab (or over it), from the totem to
-- the standing stone; each row wears a pebble in its reason's colour.
function Storm:PaintQueue(rows, shown, above)
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
	local depth = shown * pitch + 7
	-- The slab's own edges: it stands a little past the button's.
	local low, high = math.max(self.H, self.bottom), math.min(0, self.top)
	local y0, y1
	if above then
		y1 = high + 4
		y0 = high - depth
	else
		y0 = low - 4
		y1 = low + depth
	end
	Each(self.listBody, "Show")
	local x0 = self.listX0
	PlacePieces(self.listBody, art, x0, y0, self.listX1, y1, math.min(LAY.listC, (y1 - y0) / 2))
	self:PlaceShadow({ x0, y0, self.listX1, y1 })

	local bead = self.sub + 1
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = high - (4 + (shown - i) * pitch + pitch / 2)
		else
			y = low + 3 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		At(self.beads[i], art, self.rowX - 9, y, bead)
	end
end
