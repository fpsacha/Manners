-- Manners -- the Fel look: a warlock's, and the Burning Legion's.
--
-- THE SOURCE. The warlock of Warcraft and the fel magic of the Burning Legion:
-- the green fire of Felwood and the Legion's gateways, the circle of runes a
-- warlock's Ritual of Summoning draws on the ground, the soul shard his
-- spells are paid in, the horns of the demons he binds, and the Shadow Bolt
-- he throws.
--
-- A slab of black felsteel, cracked, the cracks open onto fel fire that flows
-- behind them. At its left the SUMMONING CIRCLE: the spell icon, round, in a
-- disc of black stone with eight demonic runes cut round it, a demon's two
-- horns rising from its rim. At its right the slab ends in two more horns, a
-- claw closed on a SOUL SHARD. Fel fire burns along the slab's foot. The
-- BAND between the icon and the runes carries the reason's colour; the shard
-- and a vein along the slab's upper rim carry it too. The list is a second,
-- darker slab under (or over) the first.
--
-- Every region is a texture from Textures/Fel (tools/make_fel_textures.py).
-- The felsteel, the disc and the horns are baked, because they are
-- decoration, and so are the fire, what flows behind the cracks, the gout and
-- the bolt: fel is green and shadow is violet whatever the reason. Everything
-- that means something -- the band, the shard, the vein, the beads, the
-- glyphs -- is white or grey art coloured by SetVertexColor, so one file
-- serves all six reasons, both palettes, a custom marker colour and the
-- outcomes. The interface this file implements is described at the top of
-- Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-fel.lua):
--   * at rest, on Full effects, the fire BURNS along the slab's foot (a sheet
--     of sixteen drawn frames, Looks/Flow.lua), the fel fire behind the
--     cracks flows (a scrolled texture), embers rise from the foot and wink
--     out, and the shard glints now and then. hunt35-effects lets the groups
--     of `idle` loop with nobody owed, by name; the Flow handles are `flows`;
--   * a favour arriving LIGHTS THE CIRCLE: the eight runes one after
--     another, round from the top, and the fire leaps;
--   * owed, the circle TURNS, slowly, against the sun; a bloom over the
--     runes, the band and the shard's light breathe three times and then
--     hold lit; the fire behind the cracks runs faster;
--   * a landing is a CAST: a gout of fel flame leaps from the circle (a sheet
--     of sixteen frames, played once), a shadow bolt flies the length of the
--     slab and strikes the shard, the fire leaps, and the shared rings spread
--     from the circle;
--   * a refusal GUTTERS it: the fire sinks to a glow, the runes go dark, the
--     band is left spent, the icon greys, smoke rises from the foot and one
--     ring snaps in; a cast nobody confirmed does nothing;
--   * no additive light at rest: the gout, the bolt, the leap and the rings
--     are the only ADD regions, each lit under 0.6 s and parked at nothing;
--   * the gout rises past the slab, above it. With the list hung over the
--     panel it keeps to the panel's own height;
--   * Calm keeps to fades: no fire that moves, no flow, no embers, no turning,
--     no gout, no bolt; the fire stands as one drawn frame;
--   * a fight puts the fire out and the lights with it, dulls the felsteel,
--     dims the words and greys the icon; the band, the shard and the vein
--     keep their colour;
--   * the icon is the slider's size and always round ("Round the icon off"
--     reads nothing here).

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Fel\\Fel_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Fel = ns.Looks.Register("fel", {
	name = L["Fel -- black felsteel and fel fire, a summoning circle"],
	title = L["Fel"],
	description = L["black felsteel and fel fire, a summoning circle"],
	order = 9.5,
	-- The slab holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the felsteel whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_fel_textures.py (tests/scenarios/look-fel.lua
-- compares them): the icon fills this much of the bezel's box and the circle
-- is drawn this much larger than it; the slab's design height, its left end's
-- width, its right end's (which reaches FORK_OVER above and below the slab)
-- and its middle tile's, in texels; the shard's middle from the slab's right
-- edge and its height, in design texels; how many runes, their ring and each
-- one's own square as fractions of the circle file's half-width; the left
-- horn's box against the circle's; the two sheets; the tag's caps, the mask's
-- fill and the ring file's line.
local ICON_FRAME = 0.75
local CIRCLE_SCALE = 1.4
local DESIGN_H = 128
local CAP_W = 64
local FORK_W = 128
local FORK_OVER = 64
local TILE_W = 256
local SHARD_AT = 34
local SHARD_H = 86
local RUNES = 8
local RUNE_R = 0.80
local RUNE_BOX = 0.38
local HORN_X = 0.0625
local HORN_Y = 0.1875
local HORN_SIZE = 0.5
local FIRE_COLS = 2
local FIRE_ROWS = 8
local FIRE_FRAMES = 16
local GOUT_COLS = 4
local GOUT_ROWS = 4
local GOUT_FRAMES = 16
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- Where the right end's horns begin, in design texels from its file's left:
-- the tags and the words keep left of it.
local FORK_ROOT = 42
-- The slab is this much of the button's height in from its top and its
-- bottom, so the circle and the horns stand proud of it.
local PLATE_IN = 0.09
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the circle and the text; with the icon off, between the
-- slab's edge and the text.
local TEXT_GAP, BARE_GAP = 3, 12
-- The felsteel's own luminance under the words, its darkest and its
-- brightest (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.08, 0.22
-- A chosen panel colour is mixed this far into the slab.
local BODY_MIX = 0.25
-- The list's slab is this much darker than the first.
local LIST_TONE = 0.78
-- The shadow: its 9-slice corner in units, and how far past the slab its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local CREAM = { 0.93, 0.98, 0.86 }
local TAG_INK = { 0.90, 0.98, 0.82 }
local MIST = { 0.80, 0.86, 0.74 }
-- A fight's felsteel.
local DULL = { 0.60, 0.60, 0.62 }
-- Fel's own light: the runes, the embers, the cursor's light.
local FELLIGHT = { 0.52, 1.00, 0.28 }
-- The runes: fel's green, a little paler, so a lit rune stands off the bloom.
local RUNELIGHT = { 0.80, 1.00, 0.60 }
-- The band, the shard and the vein with the marker off, and a band a
-- refusal spent.
local NEUTRAL = { 0.62, 0.82, 0.50 }
local SPENT = { 0.38, 0.40, 0.38 }
-- A soul shard's own colour, which it keeps where the marker does not colour it.
local SOUL = { 0.68, 0.42, 0.96 }
-- A flash is the reason's colour taken this far to white.
local FLASH_WHITE = 0.5
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the slab dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.74
-- The runes and the circle's lines: dark, at rest, lit; and in a fight.
local RUNE_DARK, RUNE_REST, RUNE_LIT, RUNE_COMBAT = 0.10, 0.34, 1.00, 0.16
local SIGIL_REST, SIGIL_LIT = 0.22, 0.50
-- A rune takes this long to light, and the next begins this long after it.
local RUNE_UP, RUNE_STEP = 0.14, 0.06
-- The band at rest, lit and held after its breaths; the bloom over the
-- runes, the shard's light and the vein's soft core over the same breath.
local BAND_REST, BAND_PEAK, BAND_HELD = 0.74, 1.00, 0.92
local BLOOM_REST, BLOOM_PEAK, BLOOM_HELD = 0, 0.40, 0.18
local GLOW_REST, GLOW_PEAK, GLOW_HELD = 0.30, 0.80, 0.52
local VEIN_ALPHA = 0.90
local CORE_REST, CORE_PEAK, CORE_HELD = 0.15, 0.60, 0.35
local BREATHS, BREATH = 3, 1.25
-- The circle's turn while somebody is owed: a whole turn, against the sun,
-- in this many seconds.
local TURN_SECONDS = 44
-- The fire along the foot, kept under the second line (a flame behind a
-- letter takes the letter, and the options window's check holds every card's
-- words to their contrast over the worst texel behind them; the fire behind
-- the cracks is dimmed for the same reason): its height as a part of the
-- button's, between these; how far its foot hangs under the slab's, as a part of its height;
-- its frames a second; its alpha lit, and after a refusal.
local FIRE_H, FIRE_MIN, FIRE_MAX, FIRE_DROP = 0.27, 8, 20, 0.34
local FIRE_FPS, FIRE_ALPHA, FIRE_GUTTERED = 13, 0.96, 0.20
local FIRE_TILES = 8
-- The glow the fire stands in, along the slab's foot: its alpha.
local BED_ALPHA = 0.20
-- The fire behind the cracks: a tile of it in units, its drift in tiles a
-- second at rest, how much faster while somebody is owed, and its light at
-- rest, owed, after a refusal and in a fight.
local FLOW_TILE, FLOW_DU, FLOW_DV, FLOW_OWED = 44, 0.013, 0.026, 2.6
local FLOW_REST, FLOW_LIT, FLOW_SPENT, FLOW_COMBAT = 0.30, 0.50, 0.20, 0.13
-- The embers: how many, how far they rise as a part of the button's height,
-- their peak. No two share a measure.
local EMBERS, EMBER_RISE, EMBER_PEAK = 5, 0.95, 0.95
local EMBER_TIMES = { { 0.4, 2.3, 2.9 }, { 1.9, 2.7, 3.7 }, { 0.9, 2.1, 4.9 }, { 3.1, 2.5, 3.3 }, { 2.4, 2.9, 4.3 } }
-- The shard's glint at rest: its wait and its peak.
local GLINT_WAIT, GLINT_PEAK = 6.7, 0.85
-- The gout: its width and its height as parts of the circle, how far under
-- the circle's middle its foot is, and its frames a second.
local GOUT_W, GOUT_H, GOUT_FOOT, GOUT_FPS = 1.6, 1.5, 0.22, 30
-- The fire's leap: how much taller than the fire, and its peak for a favour
-- and for a landing.
local FLARE_H, FLARE_FAVOUR, FLARE_LAND, FLARE_FPS = 1.7, 0.50, 0.90, 22
-- The bolt: its length and height as parts of the slab's height.
local BOLT_L, BOLT_H = 2.2, 0.62
-- The smoke of a refusal: how many puffs, and how far they rise.
local PUFFS, PUFF_RISE = 3, 18
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the slab's rim round it, and
-- the slab's own inset.
function Fel.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 18)
end

-- The band is the mark round the icon; the shard and the vein are the stripe.
function Fel.AccentCarriers(p)
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

-- Relative luminance of a grey, for the felsteel's own ink figures.
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
-- from the middle strips (the shadow).
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

-- A slab: its left end, its tiled middle and its right end. `fork` is the
-- right end with its horns (the prompt's own); without it the right end is
-- the left end's mirror (the list's).
local function Body(parent, layer, sublevel, keep, fork)
	local s = {}
	for i, file in ipairs({ "SlabL", "SlabM", fork and "SlabR" or "SlabL" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	if not fork then s[3]:SetTexCoord(1, 0, 0, 1) end
	s.fork = fork
	return s
end

-- A slab laid over a box. The left end is the design's proportion of the
-- height and so is the right; the right end with its horns is FORK_W wide
-- and reaches FORK_OVER above and below the box. The middle is tiled along
-- what they leave. Returns where the right end begins.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local su = (y1 - y0) / DESIGN_H
	local right = (s.fork and FORK_W or CAP_W) * su
	local over = s.fork and FORK_OVER * su or 0
	if not s.fork then right = math.min(right, (x1 - x0) / 2) end
	local rx = x1 - right
	local cap = math.max(0, math.min(CAP_W * su, rx - x0))
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, math.max(x0 + cap, rx), y1)
	Box(s[3], rel, rx, y0 - over, x1, y1 + over)
	s[1]:SetShown(cap > 0.5)
	s[2]:SetShown(rx - x0 - cap > 0.5)
	s[2]:SetTexCoord(0, Tiles(rx - x0 - cap, TILE_W * su), 0, 1)
	return rx
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

-- Where rune `k` stands on the circle: its angle, the first at the top and
-- the rest round with the clock.
local function RuneAngle(k)
	return math.rad(-90 + 360 * (k - 1) / RUNES)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights, parked between
-- plays, so nothing is left lit when it stops
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

-- Up to `peak` after `delay`, then down to `rest` (nothing unless said). The
-- delay is an Alpha that holds, which reads the same on every client.
local function Flash(region, peak, up, down, rest, delay)
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
local function Breathe(region, lo, hi)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	Alpha(g, lo, hi, BREATH, 1, nil, "IN_OUT")
	Park(g, region, lo)
	return g
end

-- One fade from `from` to `to`, which it then holds; after `delay`, when one
-- is given.
local function Fade(region, from, to, duration, delay)
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

-- A light that runs: across by the offset Apply gives it, lit as it leaves
-- and gone as it arrives.
local function Runner(region, delay, duration, peak, smoothing)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	local move = g:CreateAnimation("Translation")
	move:SetDuration(duration)
	move:SetOrder(order)
	if move.SetSmoothing then move:SetSmoothing(smoothing or "OUT") end
	g.move = move
	Alpha(g, peak, peak, duration * 0.7, order)
	Alpha(g, peak, 0, duration * 0.3, order, duration * 0.7, "IN")
	Park(g, region, 0)
	return g
end

-- A twinkle: dark for `wait`, then up and out as it turns a quarter; over and
-- over when `loop`, else once.
local function Twinkle(region, wait, peak, up, down, loop)
	local g = region:CreateAnimationGroup()
	if loop then g:SetLooping("REPEAT") end
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, up, 2, nil, "OUT")
	Alpha(g, peak, 0, down, 3, nil, "IN")
	for order, seconds in pairs({ [2] = up, [3] = down }) do
		local turn = g:CreateAnimation("Rotation")
		if turn.SetDegrees then turn:SetDegrees(-45) end
		if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
		turn:SetDuration(seconds)
		turn:SetOrder(order)
	end
	Park(g, region, 0)
	return g
end

-- An ember: dark for `wait`, then up from the fire by the offset Apply gives
-- it, lit as it leaves and winking out before it arrives; then dark again for
-- `rest`, over and over.
local function Ember(region, wait, rise, rest, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	local move = g:CreateAnimation("Translation")
	move:SetDuration(rise)
	move:SetOrder(2)
	if move.SetSmoothing then move:SetSmoothing("OUT") end
	g.move = move
	Alpha(g, 0, peak, rise * 0.18, 2, nil, "OUT")
	Alpha(g, peak, 0, rise * 0.34, 2, rise * 0.52, "IN")
	Alpha(g, 0, 0, rest, 3)
	Park(g, region, 0)
	return g
end

-- A puff of smoke: up by the offset Apply gives it as it thins.
local function Puff(region, delay, seconds, peak)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	local move = g:CreateAnimation("Translation")
	move:SetDuration(seconds)
	move:SetOrder(order)
	if move.SetSmoothing then move:SetSmoothing("OUT") end
	g.move = move
	Alpha(g, 0, peak, seconds * 0.2, order, nil, "OUT")
	Alpha(g, peak, 0, seconds * 0.8, order, seconds * 0.2, "IN")
	Park(g, region, 0)
	return g
end

-- A turn of `degrees` in `seconds` about a point `ox`, `oy` from the
-- region's middle, over and over.
local function Turn(region, degrees, seconds)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local turn = g:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(degrees) end
	if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	turn:SetDuration(seconds)
	turn:SetOrder(1)
	g.turn = turn
	return g
end

-- The fire sinking: a flicker down to what a refusal leaves of it.
local function Gutter(region, from, to)
	local g = region:CreateAnimationGroup()
	Alpha(g, from, from * 0.35, 0.07, 1, nil, "OUT")
	Alpha(g, from * 0.35, from * 0.75, 0.06, 2, nil, "IN")
	Alpha(g, from * 0.75, to * 0.6, 0.10, 3, nil, "OUT")
	Alpha(g, to * 0.6, to * 1.8, 0.07, 4, nil, "IN")
	Alpha(g, to * 1.8, to, 0.14, 5, nil, "OUT")
	Park(g, region, to)
	return g
end

-- The gout's own light: up at once, held while its frames play, then out.
local function Erupt(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 1, 0.03, 1, nil, "OUT")
	Alpha(g, 1, 1, 0.37, 2)
	Alpha(g, 1, 0, 0.14, 3, nil, "IN")
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

function Fel:Build(kit)
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
	-- A frame of light a few levels over the art and under the text.
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	-- The fire behind the cracks, under the slab that has them: opaque, so a
	-- crack is never a hole onto the world.
	self.flowTex = tex(art, "BACKGROUND", -7, "Flow", nil, "REPEAT")
	self.listFlow = tex(art, "BACKGROUND", -7, "Flow", nil, "REPEAT")
	self.listBody = Body(art, "BACKGROUND", -6, keep)
	self.body = Body(art, "BACKGROUND", -5, keep, true)
	-- The vein along the upper rim, and the soft core that breathes in it.
	self.vein = tex(art, "BORDER", 3, "Vein")
	self.core = tex(art, "BORDER", 4, "Vein")
	-- The shard in its claw, and the light it throws.
	self.shardGlow = tex(art, "BORDER", 5, "ShardGlow")
	self.shard = tex(art, "BORDER", 6, "Shard")
	-- The circle, under the icon (ARTWORK 0): the two horns behind the disc,
	-- the disc, its drawn lines, the eight runes, the bloom over them, and the
	-- band in its bed.
	self.horns = {}
	for i = 1, 2 do
		self.horns[i] = tex(art, "ARTWORK", -7, "Horn")
		if i == 2 then self.horns[i]:SetTexCoord(1, 0, 0, 1) end
	end
	self.disc = tex(art, "ARTWORK", -6, "Circle")
	self.sigil = tex(art, "ARTWORK", -5, "Sigil")
	self.runes = {}
	for k = 1, RUNES do
		local t = tex(art, "ARTWORK", -4, "Runes")
		-- Each rune is its own corner of the one file.
		local a = RuneAngle(k)
		local u, v = 0.5 + RUNE_R * math.cos(a) / 2, 0.5 + RUNE_R * math.sin(a) / 2
		t:SetTexCoord(u - RUNE_BOX / 2, u + RUNE_BOX / 2, v - RUNE_BOX / 2, v + RUNE_BOX / 2)
		self.runes[k] = t
	end
	self.bloom = tex(art, "ARTWORK", -3, "Bloom")
	self.bloom:SetAlpha(0)
	self.band = tex(art, "ARTWORK", -2, "Band")

	-- The fire along the foot: tiles of one sheet on a frame that fades as
	-- one, over the slab and under the circle's own frame level only in that
	-- it stops short of it.
	self.fireFrame = frame(1)
	-- The glow the fire stands in.
	self.bed = tex(self.fireFrame, "ARTWORK", 0, "Edge")
	self.bed:SetVertexColor(FELLIGHT[1], FELLIGHT[2], FELLIGHT[3], BED_ALPHA)
	self.fire = {}
	for i = 1, FIRE_TILES do self.fire[i] = tex(self.fireFrame, "ARTWORK", 1, "Fire") end

	-- The rings that spread from the circle when a buff lands and the one
	-- that snaps in when one is refused: frames over the art, under the text.
	-- No echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "FxRing", RING_PEAK, RING_EDGE)

	-- The lights: the fire's leap, the gout, the bolt and the shard struck.
	self.lightFrame = frame(2)
	self.flare = {}
	for i = 1, FIRE_TILES do
		-- The fire's own frames again, taller and additive: the fire's leap.
		self.flare[i] = tex(self.lightFrame, "OVERLAY", 1, "Fire", "ADD")
		self.flare[i]:SetAlpha(0)
	end
	-- The gout leaps from BEHIND the circle: on art itself, under the disc.
	self.gout = tex(art, "BORDER", 7, "Gout", "ADD")
	self.gout:SetAlpha(0)
	self.bolt = tex(self.lightFrame, "OVERLAY", 3, "Bolt", "ADD")
	self.bolt:SetAlpha(0)
	self.hot = tex(self.lightFrame, "OVERLAY", 4, "Hot", "ADD")
	self.hot:SetAlpha(0)
	-- The gout leaves the room on purpose: fel fire leaps upward.
	-- hunt37-effects holds every other light inside the panel and off the
	-- words, and lets these through by name.
	self.skyward = { self.gout }
	-- What rises at rest and after a refusal, none of it additive: the
	-- embers, the smoke, the shard's glint (once for a greeting and once for
	-- the loop: two groups on one region would fight over its alpha).
	self.idleFrame = frame(1)
	self.embers = {}
	for i = 1, EMBERS do
		local t = tex(self.idleFrame, "OVERLAY", 1, "Ember")
		t:SetVertexColor(FELLIGHT[1], FELLIGHT[2], FELLIGHT[3], 1)
		t:SetAlpha(0)
		self.embers[i] = t
	end
	self.puffs = {}
	for i = 1, PUFFS do
		local t = tex(self.idleFrame, "OVERLAY", 2, "Smoke")
		t:SetAlpha(0)
		self.puffs[i] = t
	end
	self.star = tex(self.idleFrame, "OVERLAY", 3, "Star")
	self.starOnce = tex(self.idleFrame, "OVERLAY", 3, "Star")
	self.star:SetAlpha(0)
	self.starOnce:SetAlpha(0)
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

	-- Everything baked, for a fight's dulling: the disc and its horns, the
	-- tags, the list's slab, the glyph.
	self.baked = { self.disc, self.horns[1], self.horns[2], self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end
	self.bakedTone = {}
	for _, t in ipairs(self.listBody) do self.bakedTone[t] = LIST_TONE end

	-- What moves by its coordinates (Looks/Flow.lua): the fire behind the
	-- cracks, the fire along the foot, the gout.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.flowScroll = flow:Scroll(self.flowTex, FLOW_DU, FLOW_DV, 1, 1)
	self.fireSheets = {}
	for i, t in ipairs(self.fire) do
		self.fireSheets[i] = flow:Sheet(t, FIRE_COLS, FIRE_ROWS, FIRE_FRAMES, FIRE_FPS, true)
	end
	self.goutSheet = flow:Sheet(self.gout, GOUT_COLS, GOUT_ROWS, GOUT_FRAMES, GOUT_FPS, false)
	-- The leap's frames, which play only while it is lit.
	self.flareSheets = {}
	for i, t in ipairs(self.flare) do
		self.flareSheets[i] = flow:Sheet(t, FIRE_COLS, FIRE_ROWS, FIRE_FRAMES, FLARE_FPS, true)
	end
	-- What plays for as long as the look is at rest: `flows`.
	self.flows = { self.flowScroll }
	for _, h in ipairs(self.fireSheets) do self.flows[#self.flows + 1] = h end

	self:BuildAnimations(function(g) anims[#anims + 1] = g return g end)
end

function Fel:BuildAnimations(anim)
	-- The owed breath: the bloom over the runes, and the band, the shard's
	-- light and the vein's core with it; see Attention for how long. The bloom
	-- first: hunt35-effects times the breath by the first.
	self.pulse = {
		anim(Breathe(self.bloom, BLOOM_REST, BLOOM_PEAK)), anim(Breathe(self.band, BAND_REST, BAND_PEAK)),
		anim(Breathe(self.shardGlow, GLOW_REST, GLOW_PEAK)), anim(Breathe(self.core, CORE_REST, CORE_PEAK)),
	}
	-- "Once": one rise and fall, 0.55 s.
	self.once = {
		anim(Flash(self.bloom, BLOOM_PEAK, 0.25, 0.30, 0)), anim(Flash(self.band, BAND_PEAK, 0.25, 0.30, BAND_REST)),
		anim(Flash(self.shardGlow, GLOW_PEAK, 0.25, 0.30, GLOW_REST)), anim(Flash(self.core, CORE_PEAK, 0.25, 0.30, CORE_REST)),
	}
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = {
		anim(Fade(self.bloom, 0, BLOOM_HELD, 0.5)), anim(Fade(self.band, BAND_REST, BAND_HELD, 0.5)),
		anim(Fade(self.shardGlow, GLOW_REST, GLOW_HELD, 0.5)), anim(Fade(self.core, CORE_REST, CORE_HELD, 0.5)),
	}
	for k, t in ipairs(self.runes) do self.calm[#self.calm + 1] = anim(Fade(t, RUNE_REST, RUNE_LIT, 0.5)) end
	self.calm[#self.calm + 1] = anim(Fade(self.sigil, SIGIL_REST, SIGIL_LIT, 0.5))

	-- A favour arriving: the runes light one after another, round from the
	-- top, the last lit by 0.56 s, the circle's lines with the first; and the
	-- fire leaps (0.5 s).
	self.runeLights = {}
	for k, t in ipairs(self.runes) do
		self.runeLights[k] = anim(Fade(t, RUNE_REST, RUNE_LIT, RUNE_UP, (k - 1) * RUNE_STEP))
	end
	self.sigilLight = anim(Fade(self.sigil, SIGIL_REST, SIGIL_LIT, 0.4))
	self.leapAnims, self.flareAnims = {}, {}
	for i, t in ipairs(self.flare) do
		self.leapAnims[i] = anim(Flash(t, FLARE_FAVOUR, 0.09, 0.40))
		self.flareAnims[i] = anim(Flash(t, FLARE_LAND, 0.09, 0.40))
	end
	-- Its frames stop with its light, however that ends.
	for _, g in ipairs({ self.leapAnims[1], self.flareAnims[1] }) do
		local region = self.flare[1]
		local function done()
			region:SetAlpha(0)
			for _, h in ipairs(Fel.flareSheets) do h:Stop() end
		end
		g:SetScript("OnFinished", done)
		g:SetScript("OnStop", done)
	end
	self.arrive = { self.sigilLight }
	for _, g in ipairs(self.runeLights) do self.arrive[#self.arrive + 1] = g end
	for _, g in ipairs(self.leapAnims) do self.arrive[#self.arrive + 1] = g end

	-- A landing: the gout leaps (0.54 s), the bolt flies (0.26 s) and the
	-- shard is struck as it lands (out by 0.58 s), and the fire leaps.
	self.goutAnim = anim(Erupt(self.gout))
	self.boltAnim = anim(Runner(self.bolt, 0.04, 0.26, 1, "IN"))
	self.hotAnim = anim(Flash(self.hot, 0.9, 0.06, 0.24, 0, 0.26))
	self.strikeAnim = anim(Twinkle(self.starOnce, 0.26, 1, 0.08, 0.22))
	self.landing = { self.goutAnim, self.boltAnim, self.hotAnim, self.strikeAnim }
	for _, g in ipairs(self.flareAnims) do self.landing[#self.landing + 1] = g end

	-- A refusal: the fire gutters, 0.44 s, and smoke rises from the foot for
	-- a second after (not a light: `aftermath`).
	self.gutterAnim = anim(Gutter(self.fireFrame, FIRE_ALPHA, FIRE_GUTTERED))
	-- However it ends, the fire is left as the moment has it: a glow while
	-- the refusal stands, lit again if somebody else is on the panel by then.
	local function settle() Fel.fireFrame:SetAlpha(Fel:FireAlpha()) end
	self.gutterAnim:SetScript("OnFinished", settle)
	self.gutterAnim:SetScript("OnStop", settle)
	self.refusal = { self.gutterAnim }
	self.aftermath = {}
	for i, t in ipairs(self.puffs) do self.aftermath[i] = anim(Puff(t, 0.10 + 0.14 * (i - 1), 1.05, 0.85)) end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The circle's turn while somebody is owed: each rune about the circle's
	-- middle (Apply gives each its origin), as one.
	self.turns = {}
	for k, t in ipairs(self.runes) do self.turns[k] = anim(Turn(t, 360, TURN_SECONDS)) end

	-- At rest: the embers and the shard's glint. hunt35-effects lets the
	-- groups of this list loop with nobody owed, and no others. See Idle for
	-- when they run.
	self.emberAnims = {}
	for i, t in ipairs(self.embers) do
		local times = EMBER_TIMES[(i - 1) % #EMBER_TIMES + 1]
		self.emberAnims[i] = anim(Ember(t, times[1], times[2], times[3], EMBER_PEAK))
	end
	self.glintLoop = anim(Twinkle(self.star, GLINT_WAIT, GLINT_PEAK, 0.25, 0.55, true))
	self.idle = { self.glintLoop }
	for _, g in ipairs(self.emberAnims) do self.idle[#self.idle + 1] = g end
	-- The greeting: the shard glints, once, out by 0.8 s.
	self.greet = { anim(Twinkle(self.starOnce, 0.30, GLINT_PEAK, 0.12, 0.34)) }

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

function Fel:Apply(p, above)
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

	-- The icon: the slider's size, held inside the button. The bezel's box is
	-- the icon's frame, held inside the button's height; the circle's disc is
	-- drawn CIRCLE_SCALE larger, taller than the slab and, at the default
	-- sizes, than the button: the circle stands proud of both. When the cap
	-- bites, the hole shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local circle = bz * CIRCLE_SCALE
	-- The disc's left edge is the button's.
	local cx, cy = circle / 2, H / 2
	-- The slab: inset from the button's top and bottom, from under the
	-- circle to the right edge; with the icon off, the whole width.
	local plateIn = math.max(2, math.floor(H * PLATE_IN + 0.5))
	local ph = H - 2 * plateIn
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph, self.su = plateIn, plateX, ph, su
	local forkX = PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	self.forkX = forkX
	-- The fire behind the cracks: under the slab, inside its rim, as far as
	-- the collar its horns leave from.
	local flowX1 = math.max(plateX + 4, forkX + (FORK_ROOT + 12) * su)
	Box(self.flowTex, art, plateX + 3, plateIn + 1, flowX1, H - plateIn - 1)
	self.flowScroll:Window(math.max(1, flowX1 - plateX - 3) / FLOW_TILE, math.max(1, ph - 2) / FLOW_TILE)
	-- The slab's colour: as it is, or a chosen panel colour mixed in.
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
	Each(self.shadow, "SetVertexColor", 0, 0, 0, self.shadowAlpha)
	self.listBox = nil
	self:PlaceShadow(nil)

	local discRight = cx + circle / 2
	local textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP
	self.iconSize, self.cx, self.cy, self.bz, self.circle, self.discRight, self.textX = iconSize, cx, cy, bz, circle, discRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	At(self.disc, art, cx, cy, circle)
	At(self.sigil, art, cx, cy, circle)
	At(self.bloom, art, cx, cy, circle)
	At(self.band, art, cx, cy, circle)
	-- The runes, each in its place, and each turning about the circle's
	-- middle: the origin is that middle, seen from the rune's own.
	local ringR = RUNE_R * circle / 2
	for k, t in ipairs(self.runes) do
		local a = RuneAngle(k)
		local dx, dy = ringR * math.cos(a), ringR * math.sin(a)
		At(t, art, cx + dx, cy + dy, RUNE_BOX * circle / 2)
		local turn = self.turns[k].turn
		if turn.SetOrigin then turn:SetOrigin("CENTER", -dx, dy) end
	end
	-- The horns: the left one's box starts HORN_X of the circle outside the
	-- disc's and HORN_Y over it; the right one is its mirror.
	local hornSize = circle * HORN_SIZE
	local hx, hy = cx - circle / 2 - circle * HORN_X, cy - circle / 2 - circle * HORN_Y
	Box(self.horns[1], art, hx, hy, hx + hornSize, hy + hornSize)
	Box(self.horns[2], art, 2 * cx - hx - hornSize, hy, 2 * cx - hx, hy + hornSize)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	self.fireFrame:ClearAllPoints()
	self.fireFrame:SetAllPoints(art)
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
		-- The rings spread from the lip round the icon.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, 2), iconSize)
		self.fx:Shape(true, ART .. "FxRing", ART .. "FxRing", maskFile)
		-- The room the rings have: to the text (less a margin), to the
		-- button's left edge, and to its top and bottom.
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	-- The shard in its claw, its light, and the room the horns take at the
	-- right.
	local gemX = W - SHARD_AT * su
	local shardH = math.max(6, SHARD_H * su)
	At(self.shard, art, gemX, cy, shardH * 0.56, shardH)
	At(self.shardGlow, art, gemX, cy, shardH * 1.25)
	At(self.hot, art, gemX, cy, shardH * 1.5)
	local star = math.max(8, shardH * 1.1)
	At(self.star, art, gemX - shardH * 0.06, cy - shardH * 0.22, star)
	At(self.starOnce, art, gemX - shardH * 0.06, cy - shardH * 0.22, star)
	self.gemX, self.shardH = gemX, shardH
	self.chipInset = math.ceil(W - forkX - FORK_ROOT * su) + 2
	-- The vein: inside the upper rim, from the circle to the horns' collar.
	local veinX0 = showIcon and (discRight - 1) or (plateX + 8)
	local veinX1 = forkX + FORK_ROOT * su - 1
	local veinY = plateIn + 13.5 * su
	local veinH = math.max(3, 4 * math.min(1.6, su / 0.28))
	self.veinOK = veinX1 - veinX0 >= 16
	Box(self.vein, art, veinX0, veinY - veinH / 2, veinX1, veinY + veinH / 2)
	Box(self.core, art, veinX0, veinY - veinH / 2, veinX1, veinY + veinH / 2)

	-- The fire along the foot: whole tiles from the circle to the horns, its
	-- foot a little under the slab's.
	local fireH = math.max(FIRE_MIN, math.min(FIRE_MAX, H * FIRE_H))
	local fireX0 = showIcon and (cx + circle * 0.36) or (plateX + 5)
	local fireX1 = forkX + (FORK_ROOT + 14) * su
	local span = fireX1 - fireX0
	local tiles = math.max(1, math.min(FIRE_TILES, math.floor(span / (fireH * 4) + 0.5)))
	local tileW = span / tiles
	local foot = H - plateIn + fireH * FIRE_DROP
	self.fireOK = span >= 24
	Box(self.bed, art, fireX0 - fireH * 0.4, H - plateIn - fireH * 0.5, fireX1 + fireH * 0.2, H - plateIn + fireH * 0.5)
	self.fireTiles, self.fireH = self.fireOK and tiles or 0, fireH
	for i, t in ipairs(self.fire) do
		local x0 = fireX0 + (i - 1) * tileW
		Box(t, art, x0, foot - fireH, x0 + tileW, foot)
		-- The leap: the same run, taller; with the list hung over the panel
		-- no taller than the fire.
		local leap = fireH * (above and 1 or FLARE_H)
		Box(self.flare[i], art, x0, foot - leap, x0 + tileW, foot)
	end

	-- The embers: from the fire, between the circle and the horns, each
	-- rising when its turn comes.
	local rise = H * EMBER_RISE
	for i, t in ipairs(self.embers) do
		local x = fireX0 + span * (i - 0.5 + ((i % 2 == 0) and 0.18 or -0.12)) / EMBERS
		At(t, art, x, H - plateIn - 2, math.max(6, H * 0.20))
		self.emberAnims[i].move:SetOffset((i % 2 == 0) and 3 or -2, above and rise * 0.45 or rise)
	end
	-- The smoke: from the foot, spread along the slab.
	for i, t in ipairs(self.puffs) do
		At(t, art, fireX0 + span * (i - 0.5) / PUFFS, H - plateIn - 2, math.max(14, H * 0.62))
		self.aftermath[i].move:SetOffset((i - 2) * 3, above and PUFF_RISE * 0.4 or PUFF_RISE)
	end
	self.emberOK = span >= 40

	-- The gout: up from the circle, past the button's top; with the list
	-- hung over the panel, inside the button.
	local goutW, goutH = circle * GOUT_W, circle * GOUT_H
	local goutFoot = cy + circle * GOUT_FOOT
	if above then goutH = math.min(goutH, goutFoot) end
	Box(self.gout, art, cx - goutW / 2, goutFoot - goutH, cx + goutW / 2, goutFoot)
	-- The bolt: from the circle to the shard, along the slab's middle.
	local boltL, boltH = ph * BOLT_L, ph * BOLT_H
	local boltX0 = (showIcon and discRight or plateX + 4) + boltL * 0.2
	At(self.bolt, art, boltX0, cy, boltL, boltH)
	local run = gemX - boltL * 0.36 - boltX0
	self.boltAnim.move:SetOffset(math.max(0, run), 0)
	self.boltOK = run >= 30

	-- The cursor's light over the upper rim.
	Box(self.hoverFrame, art, plateX + 4, plateIn, forkX + FORK_ROOT * su, plateIn + 8 * su)
	self.hoverLight:SetVertexColor(FELLIGHT[1], FELLIGHT[2], FELLIGHT[3], 1)

	local block = fs + 2 + sub
	self.block = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of the horns.
	local chipH = sub + 7
	self.chipH = chipH
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -self.chipInset, 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list's rows start where the name does, clear of the circle.
	self.rowX = math.max(textX, 24)
	local rowWidth = math.max(20, W - self.rowX - 12)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	for _, t in ipairs({ self.disc, self.sigil, self.bloom, self.band, self.horns[1], self.horns[2], self.gout }) do
		t:SetShown(showIcon)
	end
	for _, t in ipairs(self.runes) do t:SetShown(showIcon) end
	self.bed:SetShown(self.fireOK)
	for i, t in ipairs(self.fire) do
		t:SetShown(i <= self.fireTiles)
		self.flare[i]:SetShown(i <= self.fireTiles)
	end
	self.fx:SetShown(showIcon)
	self.vein:SetShown(self.veinOK)
	self.core:SetShown(self.veinOK)
	Each(self.listBody, "Hide")
	self.listFlow:Hide()
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
	self:Rest()
	self:Dull(false)
	if held then self:Combat(true) end
	-- Asked afresh: the fire's tiles may be other tiles now.
	self.idleState = nil
	self:Idle()

	-- The count's room: a two-digit tag, the horns and their inset. Chip
	-- widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The runes and the circle's lines, all at one light.
function Fel:Runes(alpha, sigil)
	for _, t in ipairs(self.runes) do t:SetAlpha(alpha) end
	self.sigil:SetAlpha(sigil)
end

-- Every light where it rests: the fire lit, the runes low, the band lit, the
-- core low, the rest dark.
function Fel:Rest()
	self:Runes(RUNE_REST, SIGIL_REST)
	for _, t in ipairs(self.runes) do t:SetVertexColor(RUNELIGHT[1], RUNELIGHT[2], RUNELIGHT[3], 1) end
	self.sigil:SetVertexColor(FELLIGHT[1], FELLIGHT[2], FELLIGHT[3], 1)
	self.bloom:SetVertexColor(FELLIGHT[1], FELLIGHT[2], FELLIGHT[3], 1)
	self.band:SetAlpha(BAND_REST)
	self.bloom:SetAlpha(0)
	self.shardGlow:SetAlpha(GLOW_REST)
	self.core:SetAlpha(CORE_REST)
	self.fireFrame:SetAlpha(FIRE_ALPHA)
	self.flowTex:SetVertexColor(FLOW_REST, FLOW_REST, FLOW_REST, 1)
	self.flowTex:SetDesaturated(false)
	for _, t in ipairs(self.flare) do t:SetAlpha(0) end
	for _, t in ipairs({ self.gout, self.bolt, self.hot, self.star, self.starOnce, self.hoverLight }) do t:SetAlpha(0) end
	for _, t in ipairs(self.embers) do t:SetAlpha(0) end
	for _, t in ipairs(self.puffs) do t:SetAlpha(0) end
end

-- What the look does at rest: the fire burns, the fire behind the cracks
-- flows, the embers rise and the shard glints, on Full effects, out of a
-- fight and with the prompt up; all of it is stopped otherwise (stopped, not
-- paused: the fire stands as one drawn frame, the lights park dark). Asked at
-- every paint (Painted), so it does nothing unless something changed.
function Fel:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.refused and 2 or 0) + (self.owed and 4 or 0)
	if state == self.idleState then return end
	self.idleState = state
	-- A refusal leaves the fire a glow: it does not burn until it is relit.
	local burn = on and not self.refused
	for i, h in ipairs(self.fireSheets) do
		if burn and i <= (self.fireTiles or 0) then
			-- Started together, so every tile shows the one frame and they meet.
			if not h:IsPlaying() then h:Play() end
		else
			h:Stop()
		end
	end
	if on then
		local k = self.owed and FLOW_OWED or 1
		self.flowScroll:Speed(FLOW_DU * k, FLOW_DV * k)
		if not self.flowScroll:IsPlaying() then self.flowScroll:Play() end
	else
		self.flowScroll:Stop()
	end
	for _, g in ipairs(self.emberAnims) do
		if burn and self.emberOK then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	if on then
		if not self.glintLoop:IsPlaying() then self.glintLoop:Play() end
	else
		self.glintLoop:Stop()
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome.
function Fel:Greet()
	if not self.active or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; and somebody new on the panel is greeted,
-- once. A favour arriving has its own lights, so the greeting is for a new
-- face only.
function Fel:Painted(entry)
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the slab, and under the list's when it is out.
function Fel:PlaceShadow(list)
	local W, H = self.W, self.H
	local x0, y0, x1, y1 = (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 2, W + SHADOW_OUT + 1, H + SHADOW_OUT + 3
	if list then
		y0 = math.min(y0, list[2] - SHADOW_OUT + 2)
		y1 = math.max(y1, list[4] + SHADOW_OUT + 3)
	end
	PlacePieces(self.shadow, self.kit.art, x0, y0, x1, y1, SHADOW_C)
end

function Fel:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the felsteel, whatever the panel colour: the legibility
	-- the shared code works out is held against the felsteel's own two ends.
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
	kit.name:SetShadowColor(0, 0.03, 0, 0.95)
	kit.name:SetShadowOffset(1, -1)
	-- The tags are felsteel whatever the panel, so their text is pale as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.88, 0.93, 0.82, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffa3b396"
end

function Fel:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	self.flow:StopAll()
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
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
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
	self.pulseSpent, self.calmLit, self.owed, self.idleState, self.greeted = nil, nil, nil, nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Fel:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The horns stand at the far end.
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
function Fel:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Fel:Fitted(fs)
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

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Fel:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.chipInset or 18) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil: only
-- where a press casts something (the button armed, a fight's frozen macro
-- too), never over a held panel with nothing armed, nor over an outcome.
function Fel:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	if not (self.kit.button:GetAttribute("type1") or (ns.Prompt and ns.Prompt:InTest())) then return nil end
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
function Fel:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Fel:Chip(on)
	local kit = self.kit
	-- The width FitLine took of the name just now, measured here only where
	-- it could not; the tags' own words only when they change (kit.TextWidth
	-- is a pcall: none on a per-scan path).
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)

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

-- What a refusal leaves: the band spent, the runes dark, the fire a glow and
-- the fire behind the cracks low: until the next PaintReason.
function Fel:Spend()
	self.band:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1)
	self:Runes(RUNE_DARK, RUNE_DARK)
	self:TurnCircle(false)
	if not self.gutterAnim:IsPlaying() then self.fireFrame:SetAlpha(self:FireAlpha()) end
	self.flowTex:SetVertexColor(FLOW_SPENT, FLOW_SPENT, FLOW_SPENT, 1)
	self:Idle()
end

-- The fire's light for the moment: out in a fight, a glow after a refusal,
-- lit otherwise.
function Fel:FireAlpha()
	return self.combat and 0 or (self.refused and FIRE_GUTTERED or FIRE_ALPHA)
end

-- The fire as it burns for the moment, and the fire behind the cracks with
-- it. A fire that is guttering is left to: it settles where the moment has
-- it (BuildAnimations).
function Fel:Kindle()
	local flow = FLOW_REST
	if self.combat then
		flow = FLOW_COMBAT
	elseif self.refused then
		flow = FLOW_SPENT
	elseif self.owed then
		flow = FLOW_LIT
	end
	if not self.gutterAnim:IsPlaying() then self.fireFrame:SetAlpha(self:FireAlpha()) end
	self.flowTex:SetVertexColor(flow, flow, flow, 1)
	self.flowTex:SetDesaturated(self.combat and true or false)
	if self.listFlow then
		self.listFlow:SetVertexColor(flow * 0.7, flow * 0.7, flow * 0.7, 1)
		self.listFlow:SetDesaturated(self.combat and true or false)
	end
end

-- The band in the reason's colour, and the shard and the vein (each only
-- where the marker says so, else a pale green), their lights the same
-- colour taken towards white, and the reason line warmed towards it.
function Fel:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	-- The shard: the reason's where the marker says so, else its own violet.
	local gr, gg, gb = r, g, b
	if not stripe then gr, gg, gb = SOUL[1], SOUL[2], SOUL[3] end
	if self.refused then
		self:Spend()
	else
		self.band:SetVertexColor(cr, cg, cb, 1)
	end
	self.shard:SetVertexColor(gr, gg, gb, 1)
	self.shardGlow:SetVertexColor(gr, gg, gb, 1)
	self.vein:SetVertexColor(vr, vg, vb, VEIN_ALPHA)
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.45)
	self.core:SetVertexColor(ir, ig, ib, 1)
	local fr, fg, fb = kit.Tint(gr, gg, gb, FLASH_WHITE)
	self.hot:SetVertexColor(fr, fg, fb, 1)
	self.star:SetVertexColor(fr, fg, fb, 1)
	self.starOnce:SetVertexColor(fr, fg, fb, 1)
	-- The reason line: a pale mist taken most of the way to the reason, held
	-- to its contrast on the felsteel.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { cr, cg, cb }
end

function Fel:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal spent the band, put the runes out and sank the fire: they
	-- come back here, and a fight keeps the icon grey.
	local was = self.refused
	self.refused = nil
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	if was then
		self:Kindle()
		if not self.runeLights[1]:IsPlaying() then
			if self.owed and not self.combat then
				self:Runes(RUNE_LIT, SIGIL_LIT)
			else
				self:Runes(self.combat and RUNE_COMBAT or RUNE_REST, self.combat and RUNE_COMBAT or SIGIL_REST)
			end
		end
		self:Idle()
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The felsteel, the disc and the horns dulled for a fight, or back to
-- themselves.
function Fel:Dull(on)
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(on or false)
		local k = self.bakedTone[t] or 1
		if on then
			t:SetVertexColor(DULL[1] * k, DULL[2] * k, DULL[3] * k, 1)
		else
			t:SetVertexColor(k, k, k, 1)
		end
	end
	local pc = self.bodyColour or { 1, 1, 1 }
	local f = on and BODY_COMBAT or 1
	Each(self.body, "SetDesaturated", on)
	Each(self.body, "SetVertexColor", pc[1] * f, pc[2] * f, pc[3] * f, 1)
end

-- The slab holds; the fire goes out and the lights with it, the felsteel
-- dulls, the icon greys and the words dim. The band, the shard and the vein
-- keep their colour: the reason is the one coloured thing left.
function Fel:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Dull(on)
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
	elseif not self.refused then
		self:Runes(RUNE_REST, SIGIL_REST)
	end
	self:Kindle()
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Fel:HoldPulse(spent)
	StopAll(self.pulse)
	self.bloom:SetAlpha(spent and BLOOM_HELD or 0)
	self.band:SetAlpha(spent and BAND_HELD or BAND_REST)
	self.shardGlow:SetAlpha(spent and GLOW_HELD or GLOW_REST)
	self.core:SetAlpha(spent and CORE_HELD or CORE_REST)
end

-- The lights the three flourishes share are one set of regions: one plays at
-- a time.
function Fel:StopLights()
	StopAll(self.leapAnims)
	StopAll(self.landing)
	StopAll(self.refusal)
	self.goutSheet:Stop()
	for _, h in ipairs(self.flareSheets) do h:Stop() end
end

-- The leap's frames, started together (so the tiles meet) once its light is
-- playing; its light stops them (BuildAnimations).
function Fel:Leap()
	for i, h in ipairs(self.flareSheets) do
		if i <= (self.fireTiles or 0) then h:Play() end
	end
end

-- The circle's turn: every rune started in the one call, so they turn as one.
function Fel:TurnCircle(on)
	if on then
		if not self.turns[1]:IsPlaying() then PlayAll(self.turns) end
	else
		StopAll(self.turns)
	end
end

function Fel:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	local was = self.owed
	self.owed = true
	if not was then
		self:Kindle()
		self:Idle()
	end
	-- A refusal put the circle out: it neither turns nor breathes until the
	-- next PaintReason lights it again.
	if self.refused then
		self:TurnCircle(false)
		self:HoldPulse()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The circle is lit for a new favour, never a new face.
		if full and not self.refused then
			self:StopLights()
			StopAll(self.calm)
			self:Runes(RUNE_REST, SIGIL_REST)
			PlayAll(self.arrive)
			self:Leap()
		end
	end
	-- Lit for as long as somebody is owed, however it got there.
	if not self.refused and not self.runeLights[RUNES]:IsPlaying() and not self.calm[1]:IsPlaying() and (full or self.calmLit) then
		self:Runes(RUNE_LIT, SIGIL_LIT)
	end
	if flashStyle ~= "pulse" then
		-- "Once": one rise and fall for the new favour, and still after.
		self:TurnCircle(false)
		if isNew and full then
			self:HoldPulse()
			PlayAll(self.once)
		elseif not self.once[1]:IsPlaying() then
			self:HoldPulse()
		end
		return
	end
	if not full then
		-- Calm: one fade up to the held light, and nothing loops or turns.
		self:TurnCircle(false)
		if not self.calmLit then
			self.calmLit = true
			StopAll(self.pulse)
			PlayAll(self.calm)
		end
		return
	end
	self:TurnCircle(true)
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
		self.bloom:SetAlpha(BLOOM_REST)
		self.band:SetAlpha(BAND_REST)
		self.shardGlow:SetAlpha(GLOW_REST)
		self.core:SetAlpha(CORE_REST)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly. The
	-- circle goes on turning: it is slow, and it is what says "owed".
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Fel.pulseGen or not Fel.active then return end
			Fel.pulseSpent = true
			if Fel.pulse[1]:IsPlaying() then
				Fel:HoldPulse(true)
				-- Settled: the shard says so, once.
				Fel:Greet()
			end
		end)
	end
end

function Fel:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	StopAll(self.runeLights)
	self.sigilLight:Stop()
	self:TurnCircle(false)
	self.bloom:SetAlpha(0)
	self.band:SetAlpha(BAND_REST)
	self.shardGlow:SetAlpha(GLOW_REST)
	self.core:SetAlpha(CORE_REST)
	if self.refused then
		self:Runes(RUNE_DARK, RUNE_DARK)
	elseif self.combat then
		self:Runes(RUNE_COMBAT, RUNE_COMBAT)
	else
		self:Runes(RUNE_REST, SIGIL_REST)
	end
	self.calmLit = nil
	local was = self.owed
	self.owed = nil
	if was then self:Kindle() end
	if self.active then self:Idle() end
end

function Fel:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal gutters: the fire sinks to a glow, the runes go dark, the
	-- band is left spent, smoke rises and one ring snaps in onto the circle.
	-- The text's shake is Prompt's.
	if kind == "failed" then
		self.refused = true
		self:StopLights()
		StopAll(self.runeLights)
		self.sigilLight:Stop()
		self:TurnCircle(false)
		if self.fireOK and not self.combat then
			self.fireFrame:SetAlpha(FIRE_ALPHA)
			PlayAll(self.refusal)
			PlayAll(self.aftermath)
		end
		self:Spend()
		if shown then self.fx:Refuse(1.00, 0.40, 0.34, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	if self.fireOK then
		PlayAll(self.flareAnims)
		self:Leap()
	end
	if shown then
		-- The gout: its light and its frames together.
		self.goutAnim:Stop()
		self.goutAnim:Play()
		self.goutSheet:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- The bolt, only on a slab long enough to fly along.
	if self.boltOK then
		PlayAll({ self.boltAnim, self.hotAnim, self.strikeAnim })
	end
end

function Fel:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Fel:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hoverLight
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.34 or 0
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
-- the eye never has to find the person again. The vein's core takes the
-- outcome's colour.
function Fel:PaintOutcome(kind, lead, sub, who, stamp)
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
	self.core:SetVertexColor(o[1], o[2], o[3], 1)
	self.refused = kind == "failed"
	if self.refused then self:Spend() end
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	self.glyph:SetVertexColor(vr, vg, vb, 1)
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
	end
end

function Fel:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A second, darker slab under the first (or over it); each row wears a small
-- shard in its reason's colour.
function Fel:PaintQueue(rows, shown, above)
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
			self.listFlow:Hide()
			self:PlaceShadow(nil)
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.beads[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.beads[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	local depth = shown * pitch + 6
	local W, H = self.W, self.H
	local y0, y1
	if above then
		y1 = self.plateIn
		y0 = -depth
	else
		y0 = H - self.plateIn
		y1 = H + depth
	end
	Each(self.listBody, "Show")
	PlaceBody(self.listBody, art, self.plateX, y0, W, y1)
	-- What shows through the list's cracks: the same fire, still and lower.
	Box(self.listFlow, art, self.plateX + 3, y0 + 1, W - 3, y1 - 1)
	self.listFlow:SetTexCoord(0, (W - self.plateX - 6) / FLOW_TILE, 0, (y1 - y0 - 2) / FLOW_TILE)
	self.listFlow:Show()
	self:Kindle()
	self:PlaceShadow({ self.plateX, y0, W, y1 })

	local bead = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = -(3 + (shown - i) * pitch + pitch / 2)
		else
			y = H + 3 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		At(self.beads[i], art, self.rowX - 9, y, bead)
	end
end
