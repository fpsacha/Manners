-- Manners -- the Wild look: a druid's, and the Cenarion Circle's.
--
-- THE SOURCE. The druid of Warcraft and the Cenarion Circle of Moonglade: the
-- living wood the night elves grow their halls from, Cenarius' and Malorne's
-- antlers, the moonwells whose water holds Elune's light, the crescent moon,
-- the wisps of Ashenvale, and the paw of the druid's own buff, Mark of the
-- Wild, which gives the look its name.
--
-- A BOUGH of living wood: bark, mossed on its upper side, round a face of
-- dark heartwood the words stand on. At its left a WREATH of two branches
-- woven round one another, in leaf, with a stag's two antlers rising from it;
-- the spell icon, round, stands in the wreath in a ring of MOONWELL water.
-- At its right the bough ends in a crozier, a branch curled into a ring
-- that holds a crescent MOON. The WATER round the icon carries the reason's
-- colour; the moon and a fine inlay along the face's lower edge carry it
-- too. The list is a plank of the same wood under (or over) the bough, a
-- small leaf for each name.
--
-- Every region is a texture from Textures/Wild (tools/make_wild_textures.py).
-- The wood, the antlers and every leaf are baked, because they are
-- decoration. Everything that means something -- the water, the moon, the
-- inlay, the list's leaves, the glyphs -- is white or grey art coloured by
-- SetVertexColor, so one file serves all six reasons, both palettes, a custom
-- marker colour and the outcomes. The interface this file implements is
-- described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-wild.lua):
--   * at rest, on Full effects, the moonwell's water RIPPLES (two layers of
--     one caustic scrolled against one another, Looks/Flow.lua), the sprigs
--     along the bough stir, a leaf drifts down now and then, and fireflies
--     and a wisp wander. hunt35-effects lets the groups of `idle` loop with
--     nobody owed, by name; the Flow handles are `flows`;
--   * a favour arriving GROWS A VINE along the bough's upper side, from the
--     wreath to the crozier (a sheet of eight drawn frames, played once), a
--     light running at its tip, and its buds show as it reaches them;
--   * owed, BLOSSOMS open on the vine one after another (a sheet of sixteen
--     frames each, at its own pace) and stay open; a light over the water,
--     the moon's and the inlay's breathe three times and then hold lit; the
--     water ripples faster;
--   * a landing is the MARK OF THE WILD: its paw lights over the icon, a
--     bloom of green-gold light opens behind the wreath, leaves and petals
--     fly from the wreath and from every blossom, the moon is lit, and the
--     shared rings spread from the icon;
--   * a refusal WITHERS it: the vine and its blossoms shrivel away, the
--     leaves brown, husks fall from every sprig, the water is left spent, the
--     icon greys and one ring snaps in; a cast nobody confirmed does nothing;
--   * no additive light at rest: the paw, the bloom, the moon's flash and
--     the rings are the only ADD regions, each lit under 0.6 s and parked at
--     nothing;
--   * the antlers, the sprigs and the vine stand past the panel, above it
--     (and a sprig or two below). With the list hung over the panel the vine
--     keeps to the panel's own height, the sprigs on the bough's upper side
--     are not drawn, and the list keeps right of the antlers;
--   * Calm keeps to fades: no ripple, no stirring, no drifting leaf, no
--     firefly, no growing, no flying leaves; the vine and its blossoms are
--     simply there while somebody is owed;
--   * a fight stills all of it and puts the lights out, dulls the wood and
--     the leaves, dims the words and greys the icon; the water, the moon and
--     the inlay keep their colour;
--   * the icon is the slider's size and always round ("Round the icon off"
--     reads nothing here).

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Wild\\Wild_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Wild = ns.Looks.Register("wild", {
	name = L["Wild -- a bough of living wood, antlers and a moonwell"],
	title = L["Wild"],
	description = L["a bough of living wood, antlers and a moonwell"],
	order = 9.7,
	-- The bough holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the heartwood whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_wild_textures.py (tests/scenarios/look-wild.lua
-- compares them): the icon fills this much of the bezel's box and the wreath
-- is drawn this much larger than it; the bough's design height, its left
-- end's width, its right end's (which reaches END_OVER above and below the
-- bough), where in the right end the face stops and the crozier begins, and
-- its middle tile's width, in texels; the moon's middle from the bough's right edge and above its
-- middle line, and its width, in design texels; the left antler's box
-- against the wreath's; the two sheets, and where the vine's stem lies in a
-- frame of its own; the tag's caps, the mask's fill and the ring file's line.
local ICON_FRAME = 0.75
local CIRCLE_SCALE = 1.45
local DESIGN_H = 128
local CAP_W = 64
local END_W = 128
local END_OVER = 64
local END_ROOT = 6
local TILE_W = 256
local MOON_AT = 62
local MOON_UP = 28
local MOON_SIZE = 60
local ANTLER_X = 0.27
local ANTLER_Y = 0.38
local ANTLER_SIZE = 0.90
local VINE_ROWS = 8
local VINE_FRAMES = 8
local VINE_STEM = 0.75
local BLOSSOM_COLS = 4
local BLOSSOM_ROWS = 4
local BLOSSOM_FRAMES = 16
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- The bough is this much of the button's height in from its top and its
-- bottom, so the wreath stands proud of it.
local PLATE_IN = 0.05
-- The bough is no taller than this much of the button's width, unless the
-- words need more: the face they stand on is this much of its height.
local BOUGH_MAX, FACE = 0.30, 0.60
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the wreath and the text; with the icon off, between the
-- bough's end and the text.
local TEXT_GAP, BARE_GAP = 3, 13
-- The heartwood's own luminance under the words, its darkest and its
-- brightest (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.05, 0.21
-- A chosen panel colour is mixed this far into the bough.
local BODY_MIX = 0.25
-- The list's plank: its nine-slice corner, in units.
local LIST_C = 9
-- The shadow: its 9-slice corner in units, and how far past the bough its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local CREAM = { 0.97, 0.95, 0.86 }
local TAG_INK = { 0.95, 0.92, 0.80 }
local MIST = { 0.86, 0.86, 0.76 }
-- A fight's wood and leaves; a refusal's.
local DULL = { 0.62, 0.62, 0.64 }
local SERE = { 0.92, 0.66, 0.36 }
local WOOD_SERE = { 1.00, 0.80, 0.60 }
-- Nature's own light: the bloom, the paw, the fireflies. And the moon's: the
-- wisp, the cursor's light.
local SUNLIGHT = { 0.84, 1.00, 0.42 }
local MOONLIGHT = { 0.80, 0.90, 1.00 }
-- The water, the moon and the inlay where the marker does not colour them
-- (moonlight has no colour of its own), and what a refusal leaves of them.
local SILVER = { 0.84, 0.87, 0.90 }
local SPENT = { 0.34, 0.35, 0.37 }
-- A flash is the reason's colour taken this far to white.
local FLASH_WHITE = 0.5
local OUTCOME = {
	cast = { 0.56, 0.90, 0.46 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the bough dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.74
-- The light over the water at rest, lit and held after its breaths; the
-- moon's light and the inlay's soft core over the same breath.
local HALO = { rest = 0, peak = 0.62, held = 0.30 }
local GLOW = { rest = 0.26, peak = 0.80, held = 0.50, combat = 0.12 }
local CORE = { rest = 0.15, peak = 0.60, held = 0.35 }
local INLAY_ALPHA = 0.60
local BREATHS, BREATH = 3, 1.25
-- The water: a tile of its caustic in units, each layer's drift in tiles a
-- second, how much faster while somebody is owed, and the second layer's
-- share.
local WATER = { tile = 19, du = { 0.034, -0.026 }, dv = { 0.022, 0.030 }, owed = 2.4, second = 0.55 }
-- The vine: its frames a second, where its three blossoms stand along it,
-- each one's frames a second, and how large a blossom is against the button.
local VINE_FPS = 14
local BLOSSOMS = { at = { 0.23, 0.52, 0.79 }, fps = { 22, 16, 12 }, size = 0.30 }
-- The sprigs: how large against the button, and each one's sway (degrees,
-- seconds one way).
local SPRIG = { size = 0.36, sway = { { 8, 2.3 }, { -7, 2.9 }, { 7.5, 3.4 }, { -8, 2.6 }, { 7, 3.1 } } }
-- What drifts at rest: three leaves (wait, fall, rest, turn), four motes
-- (wait, three legs, rest). No two share a measure.
local DRIFT = { { 0.6, 3.4, 4.2, 220 }, { 2.8, 4.2, 5.0, -260 }, { 5.5, 3.0, 6.3, 180 } }
local MOTES = { { 0.3, 2.6, 2.2, 2.9, 2.3 }, { 2.1, 3.1, 2.4, 2.6, 3.7 }, { 1.2, 2.8, 3.0, 2.4, 4.4 }, { 3.7, 2.4, 2.7, 3.2, 3.1 } }
local MOTE_PEAK = 0.95
-- A landing's leaves and petals: where each flies (degrees, the sun's way
-- from the right; how far, in wreaths), and how it turns.
local BURST = { { 96, 0.86, 260 }, { 128, 0.98, -300 }, { 158, 0.80, 220 }, { 188, 0.92, -240 }, { 218, 0.84, 280 },
	{ 247, 0.94, -220 }, { 276, 0.78, 250 }, { 302, 0.88, -280 }, { 54, 0.96, 240 }, { 74, 0.82, -260 } }
local BURST_SECONDS = 0.58
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the bark above and below it.
function Wild.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 18)
end

-- The water is the mark round the icon; the moon and the inlay are the stripe.
function Wild.AccentCarriers(p)
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

-- Relative luminance of a grey, for the heartwood's own ink figures.
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
-- from the middle strips (the shadow, the list's plank).
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

-- The bough: its left end, its tiled middle and its right end, the crozier.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "BoughL", "BoughM", "BoughR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- The bough laid over a box. The left end is the design's proportion of the
-- height; the right end is END_W wide and reaches END_OVER above and below
-- the box. The middle is tiled along what they leave, and begins the tile
-- where the left end left it, so the bark runs on. Returns where the right
-- end begins.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local su = (y1 - y0) / DESIGN_H
	local over = END_OVER * su
	local rx = x1 - END_W * su
	local cap = math.max(0, math.min(CAP_W * su, rx - x0))
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, math.max(x0 + cap, rx), y1)
	Box(s[3], rel, rx, y0 - over, x1, y1 + over)
	s[1]:SetShown(cap > 0.5)
	s[2]:SetShown(rx - x0 - cap > 0.5)
	-- The tile ends where the right end takes it up: on a whole tile.
	local n = Tiles(rx - x0 - cap, TILE_W * su)
	s[2]:SetTexCoord(1 - (n % 1), 1 + math.floor(n), 0, 1)
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

-- One frame of a sheet, shown still (Calm, a restyle with somebody owed).
local function Still(tex, cols, rows, frame)
	local col, row = frame % cols, math.floor(frame / cols)
	tex:SetTexCoord(col / cols, (col + 1) / cols, row / rows, (row + 1) / rows)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights or moves, parked
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

local function Move(group, duration, order, smoothing)
	local move = group:CreateAnimation("Translation")
	move:SetDuration(duration)
	move:SetOrder(order or 1)
	if smoothing and move.SetSmoothing then move:SetSmoothing(smoothing) end
	return move
end

local function Spin(group, degrees, duration, order, point, smoothing)
	local turn = group:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(degrees) end
	if turn.SetOrigin then turn:SetOrigin(point or "CENTER", 0, 0) end
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

-- A twinkle: dark for `wait`, then up and out as it turns a quarter, once.
local function Twinkle(region, wait, peak, up, down)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, up, 2, nil, "OUT")
	Alpha(g, peak, 0, down, 3, nil, "IN")
	Spin(g, -45, up, 2)
	Spin(g, -45, down, 3)
	Park(g, region, 0)
	return g
end

-- A sprig stirring: a few degrees about its root and back, over and over.
local function Sway(region, degrees, seconds, root)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	g.turn = Spin(g, degrees, seconds, 1, root, "IN_OUT")
	return g
end

-- A leaf drifting down: nothing for `wait`, then down and aside by the
-- offsets Apply gives it, turning as it goes, seen as it leaves and gone
-- before it arrives; then nothing again for `rest`, over and over.
local function Drift(region, wait, seconds, rest, degrees)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	g.move = Move(g, seconds, 2, "IN")
	g.aside = Move(g, seconds, 2, "IN_OUT")
	Spin(g, degrees, seconds, 2)
	Alpha(g, 0, 1, seconds * 0.14, 2, nil, "OUT")
	Alpha(g, 1, 0, seconds * 0.30, 2, seconds * 0.70, "IN")
	Alpha(g, 0, 0, rest, 3)
	Park(g, region, 0)
	return g
end

-- A firefly, a wisp: dark for `wait`, then three legs of a wander by the
-- offsets Apply gives them, glowing as it sets out, dimming and brightening
-- on its way and gone as it ends; then dark for `rest`, over and over.
local function Wander(region, wait, a, b, c, rest, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	g.legs = { Move(g, a, 2, "IN_OUT"), Move(g, b, 3, "IN_OUT"), Move(g, c, 4, "IN_OUT") }
	Alpha(g, 0, peak, a * 0.4, 2, nil, "OUT")
	Alpha(g, peak, peak * 0.3, b * 0.5, 3, nil, "IN_OUT")
	Alpha(g, peak * 0.3, peak, b * 0.5, 3, b * 0.5, "IN_OUT")
	Alpha(g, peak, 0, c * 0.6, 4, c * 0.4, "IN")
	Alpha(g, 0, 0, rest, 5)
	Park(g, region, 0)
	return g
end

-- A leaf or a petal thrown: out by one offset (slowing) and down by another
-- (quickening), which Apply gives it, turning; lit as it leaves and gone as
-- it lands. After `delay`, when one is given.
local function Fling(region, seconds, degrees, delay, fall)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay and delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	g.move = Move(g, seconds, order, fall and "IN_OUT" or "OUT")
	g.drop = Move(g, seconds, order, (not fall) and "IN" or nil)
	Spin(g, degrees, seconds, order)
	Alpha(g, 0, 1, seconds * 0.12, order, nil, "OUT")
	Alpha(g, 1, 0, seconds * 0.38, order, seconds * 0.62, "IN")
	Park(g, region, 0)
	return g
end

-- A light that runs: across by the offset Apply gives it, lit as it leaves
-- and gone as it arrives.
local function Runner(region, duration, peak)
	local g = region:CreateAnimationGroup()
	g.move = Move(g, duration, 1)
	Alpha(g, 0, peak, duration * 0.15, 1, nil, "OUT")
	Alpha(g, peak, 0, duration * 0.30, 1, duration * 0.70, "IN")
	Park(g, region, 0)
	return g
end

-- The vine shrivelling: a shudder down to nothing.
local function Wither(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 1, 0.45, 0.08, 1, nil, "OUT")
	Alpha(g, 0.45, 0.75, 0.07, 2, nil, "IN")
	Alpha(g, 0.75, 0, 0.27, 3, nil, "IN")
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

function Wild:Build(kit)
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

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.listShadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.listBody = Pieces(art, "BACKGROUND", -6, ART .. "Plank", keep)
	self.body = Body(art, "BACKGROUND", -5, keep)
	-- The inlay along the face's lower edge, and the soft core that breathes
	-- in it.
	self.inlay = tex(art, "BORDER", 3, "Inlay")
	self.core = tex(art, "BORDER", 4, "Inlay")
	-- The moon in its crozier, and the light it throws.
	self.moonGlow = tex(art, "BORDER", 5, "MoonGlow")
	self.moon = tex(art, "BORDER", 6, "Moon")
	-- The bloom opens BEHIND the wreath, and the leaves fly from behind it: on
	-- art itself, under the wreath.
	self.bloom = tex(art, "BORDER", 7, "Bloom", "ADD")
	self.bloom:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
	self.bloom:SetAlpha(0)
	self.burst = {}
	for i = 1, #BURST do
		local t = tex(art, "ARTWORK", -8, (i % 3 == 0) and "Petal" or "Leaf")
		t:SetAlpha(0)
		self.burst[i] = t
	end
	-- The wreath, under the icon (ARTWORK 0): the antlers behind it, the
	-- wreath, the water in its bed (two layers, cut to the bed's ring), the
	-- light over the water, and the lip with the shade it throws.
	self.antlers = {}
	for i = 1, 2 do
		self.antlers[i] = tex(art, "ARTWORK", -7, "Antler")
		if i == 2 then self.antlers[i]:SetTexCoord(1, 0, 0, 1) end
	end
	self.disc = tex(art, "ARTWORK", -6, "Circle")
	self.waterMask = art:CreateMaskTexture()
	self.waterMask:SetTexture(ART .. "WaterMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.water = {}
	for i = 1, 2 do
		self.water[i] = tex(art, "ARTWORK", -6 + i, "Water", nil, "REPEAT")
		self.water[i]:AddMaskTexture(self.waterMask)
	end
	self.halo = tex(art, "ARTWORK", -3, "Halo")
	self.halo:SetAlpha(0)
	self.lip = tex(art, "ARTWORK", -2, "Lip")
	-- The sprigs: one on the wreath, two on the bough's upper side, one under
	-- it and one on the crozier, over the wood and clear of the icon.
	self.sprigs = {}
	for i = 1, #SPRIG.sway do self.sprigs[i] = tex(art, "ARTWORK", 2, "Sprig") end

	-- The vine and its blossoms, on a frame that fades as one.
	self.vineFrame = frame(1)
	self.vineFrame:SetAlpha(0)
	self.vine = tex(self.vineFrame, "ARTWORK", 0, "Vine")
	self.blossoms = {}
	for i = 1, #BLOSSOMS.at do self.blossoms[i] = tex(self.vineFrame, "ARTWORK", 1, "Blossom") end

	-- The rings that spread from the wreath when a buff lands and the one
	-- that snaps in when one is refused: frames over the art, under the text.
	-- No echo of the icon: nothing lies over it but the paw.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "FxRing", RING_PEAK, RING_EDGE)

	-- The lights: the Mark of the Wild's paw over the icon, the moon lit.
	self.lightFrame = frame(2)
	self.paw = tex(self.lightFrame, "OVERLAY", 2, "Paw", "ADD")
	self.paw:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
	self.paw:SetAlpha(0)
	self.hot = tex(self.lightFrame, "OVERLAY", 3, "Hot", "ADD")
	self.hot:SetAlpha(0)
	-- What moves at rest, after a landing and after a refusal, none of it
	-- additive: the drifting leaves, the fireflies and the wisp, the petals
	-- the blossoms shed, the husks, the moon's glint.
	self.idleFrame = frame(1)
	self.drift = {}
	for i = 1, #DRIFT do
		local t = tex(self.idleFrame, "ARTWORK", 1, "Leaf")
		t:SetAlpha(0)
		self.drift[i] = t
	end
	self.motes = {}
	for i = 1, #MOTES do
		local t = tex(self.idleFrame, "OVERLAY", 1, "Mote")
		-- The third is a wisp, the moon's; the others are fireflies.
		local c = (i == 3) and MOONLIGHT or SUNLIGHT
		t:SetVertexColor(c[1], c[2], c[3], 1)
		t:SetAlpha(0)
		self.motes[i] = t
	end
	self.petals = {}
	for i = 1, #BLOSSOMS.at * 2 do
		local t = tex(self.idleFrame, "ARTWORK", 2, "Petal")
		t:SetAlpha(0)
		self.petals[i] = t
	end
	self.husks = {}
	for i = 1, #SPRIG.sway do
		local t = tex(self.idleFrame, "ARTWORK", 3, "Husk")
		t:SetAlpha(0)
		self.husks[i] = t
	end
	self.star = tex(self.idleFrame, "OVERLAY", 3, "Star")
	self.star:SetAlpha(0)
	-- The light at the vine's tip as it grows.
	self.tip = tex(self.idleFrame, "OVERLAY", 2, "Mote")
	self.tip:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
	self.tip:SetAlpha(0)
	-- The cursor's light: the upper bark lit.
	self.hoverFrame = frame(1)
	self.hoverLight = tex(self.hoverFrame, "OVERLAY", 1, "Edge")
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's leaves, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The chips: small plaques at the right end; their text is on textLayer,
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

	-- Everything baked that a fight dulls and a refusal browns: the wreath
	-- and the sprigs (`leafy`; the bough is dressed with them); and what a
	-- fight dulls only: the antlers, the lip, the tags, the list's plank,
	-- the glyph.
	self.leafy = { self.disc }
	for _, t in ipairs(self.sprigs) do self.leafy[#self.leafy + 1] = t end
	self.baked = { self.antlers[1], self.antlers[2], self.lip, self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end

	-- What moves by its coordinates (Looks/Flow.lua): the water's two layers,
	-- the vine, the blossoms.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.waterScroll = {}
	for i, t in ipairs(self.water) do
		self.waterScroll[i] = flow:Scroll(t, WATER.du[i], WATER.dv[i], 1, 1)
	end
	self.vineSheet = flow:Sheet(self.vine, 1, VINE_ROWS, VINE_FRAMES, VINE_FPS, false)
	self.blossomSheets = {}
	for i, t in ipairs(self.blossoms) do
		self.blossomSheets[i] = flow:Sheet(t, BLOSSOM_COLS, BLOSSOM_ROWS, BLOSSOM_FRAMES, BLOSSOMS.fps[i], false)
	end
	-- What plays for as long as the look is at rest: `flows`.
	self.flows = { self.waterScroll[1], self.waterScroll[2] }

	self:BuildAnimations(function(g) anims[#anims + 1] = g return g end)
end

function Wild:BuildAnimations(anim)
	-- The owed breath: the light over the water, and the moon's light and the
	-- inlay's core with it; see Attention for how long. The halo first:
	-- hunt35-effects times the breath by the first.
	self.pulse = {
		anim(Breathe(self.halo, HALO.rest, HALO.peak)), anim(Breathe(self.moonGlow, GLOW.rest, GLOW.peak)),
		anim(Breathe(self.core, CORE.rest, CORE.peak)),
	}
	-- "Once": one rise and fall, 0.55 s.
	self.once = {
		anim(Flash(self.halo, HALO.peak, 0.25, 0.30, 0)), anim(Flash(self.moonGlow, GLOW.peak, 0.25, 0.30, GLOW.rest)),
		anim(Flash(self.core, CORE.peak, 0.25, 0.30, CORE.rest)),
	}
	-- Calm: one fade up to the held light, the vine and its blossoms with it,
	-- and nothing after.
	self.calm = {
		anim(Fade(self.halo, 0, HALO.held, 0.5)), anim(Fade(self.moonGlow, GLOW.rest, GLOW.held, 0.5)),
		anim(Fade(self.core, CORE.rest, CORE.held, 0.5)), anim(Fade(self.vineFrame, 0, 1, 0.5)),
	}

	-- A favour arriving: the vine comes (its frames are Flow's, 0.57 s), a
	-- light at its tip as it grows, and each blossom's bud shows as the vine
	-- reaches it.
	self.vineIn = anim(Fade(self.vineFrame, 0, 1, 0.08))
	self.budIn = {}
	for i, t in ipairs(self.blossoms) do
		self.budIn[i] = anim(Fade(t, 0, 1, 0.12, 0.10 + BLOSSOMS.at[i] * VINE_FRAMES / VINE_FPS))
	end
	self.tipAnim = anim(Runner(self.tip, VINE_FRAMES / VINE_FPS, 0.85))
	self.arrive = { self.vineIn, self.tipAnim }
	for _, g in ipairs(self.budIn) do self.arrive[#self.arrive + 1] = g end

	-- A landing: the paw lights over the icon (0.5 s), the bloom opens behind
	-- the wreath (0.55 s), the leaves and petals fly (0.58 s), every blossom
	-- sheds two petals and is gone, and the moon is lit (out by 0.5 s).
	self.pawAnim = anim(Flash(self.paw, 0.80, 0.07, 0.43))
	self.bloomAnim = anim(Flash(self.bloom, 0.90, 0.10, 0.45))
	self.hotAnim = anim(Flash(self.hot, 0.60, 0.08, 0.30, 0, 0.12))
	self.landing = { self.pawAnim, self.bloomAnim, self.hotAnim }
	self.burstAnims = {}
	for i, t in ipairs(self.burst) do
		self.burstAnims[i] = anim(Fling(t, BURST_SECONDS - 0.02 * (i % 4), BURST[i][3], 0.02 * (i % 3)))
		self.landing[#self.landing + 1] = self.burstAnims[i]
	end
	self.petalAnims, self.shed = {}, {}
	for i, t in ipairs(self.petals) do
		self.petalAnims[i] = anim(Fling(t, 0.52, (i % 2 == 0) and 200 or -230, 0.03 * i))
		self.landing[#self.landing + 1] = self.petalAnims[i]
	end
	for i, t in ipairs(self.blossoms) do
		self.shed[i] = anim(Fade(t, 1, 0, 0.16, 0.03 * i))
		self.landing[#self.landing + 1] = self.shed[i]
	end

	-- A refusal: the vine and its blossoms shrivel, 0.42 s, and husks fall
	-- from the sprigs for a second after (not a light: `aftermath`).
	self.witherAnim = anim(Wither(self.vineFrame))
	self.refusal = { self.witherAnim }
	self.aftermath = {}
	for i, t in ipairs(self.husks) do
		self.aftermath[i] = anim(Fling(t, 0.84 + 0.06 * i, (i % 2 == 0) and 150 or -170, 0.03 + 0.05 * (i - 1), true))
	end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- At rest: the sprigs stir, the leaves drift, the fireflies and the wisp
	-- wander. hunt35-effects lets the groups of this list loop with nobody
	-- owed, and no others. See Idle for when they run.
	self.sways, self.driftAnims, self.moteAnims = {}, {}, {}
	self.idle = {}
	for i, t in ipairs(self.sprigs) do
		self.sways[i] = anim(Sway(t, SPRIG.sway[i][1], SPRIG.sway[i][2], "BOTTOM"))
		self.idle[#self.idle + 1] = self.sways[i]
	end
	for i, t in ipairs(self.drift) do
		self.driftAnims[i] = anim(Drift(t, DRIFT[i][1], DRIFT[i][2], DRIFT[i][3], DRIFT[i][4]))
		self.idle[#self.idle + 1] = self.driftAnims[i]
	end
	for i, t in ipairs(self.motes) do
		local m = MOTES[i]
		self.moteAnims[i] = anim(Wander(t, m[1], m[2], m[3], m[4], m[5], MOTE_PEAK))
		self.idle[#self.idle + 1] = self.moteAnims[i]
	end
	-- The greeting: the moon glints, once, out by 0.8 s.
	self.greet = { anim(Twinkle(self.star, 0.30, 0.9, 0.12, 0.34)) }

	-- The cursor's light on the upper bark, both ways; from and to are set
	-- for each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Wild:Apply(p, above)
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
	-- the icon's frame, held inside the button's height; the wreath is drawn
	-- CIRCLE_SCALE larger, taller than the bough and, at the default sizes,
	-- than the button: the wreath stands proud of both. When the cap bites,
	-- the hole shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local circle = bz * CIRCLE_SCALE
	-- The wreath's left edge is the button's.
	local cx, cy = circle / 2, H / 2
	-- The bough: inset from the button's top and bottom, from under the
	-- wreath to the right edge; with the icon off, the whole width. Its right
	-- end is as wide as the bough is tall, so on a button much taller than it
	-- is wide the bough keeps to a part of the width (and to what the words
	-- need), and lies across the button's middle.
	local plateIn = math.max(1, math.floor(H * PLATE_IN + 0.5))
	local ph = math.min(H - 2 * plateIn, math.max(W * BOUGH_MAX, (fs + 2 + sub + 4) / FACE))
	plateIn = (H - ph) / 2
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph, self.su = plateIn, plateX, ph, su
	local endX = PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	self.endX = endX
	-- Where the crozier begins: the words, the tags and the list keep left
	-- of it.
	local rootX = endX + END_ROOT * su
	self.rootX = rootX
	-- The bough's colour: as it is, or a chosen panel colour mixed in.
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
	Each(self.listShadow, "SetVertexColor", 0, 0, 0, self.shadowAlpha)
	self:PlaceShadow(nil)

	local discRight = cx + circle / 2
	local textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP
	self.iconSize, self.cx, self.cy, self.bz, self.circle, self.discRight, self.textX = iconSize, cx, cy, bz, circle, discRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self:PlaceWreath(showIcon)

	-- The moon in its crozier, its light, and the room the crozier takes at
	-- the right.
	local gemX = W - MOON_AT * su
	local moonY = cy - MOON_UP * su
	local moonSize = math.max(6, MOON_SIZE * su)
	At(self.moon, art, gemX, moonY, moonSize)
	At(self.moonGlow, art, gemX, moonY, moonSize * 1.7)
	At(self.hot, art, gemX, moonY, moonSize * 1.25)
	At(self.star, art, gemX + moonSize * 0.16, moonY + moonSize * 0.20, math.max(8, moonSize * 1.1))
	self.gemX, self.moonY, self.moonSize = gemX, moonY, moonSize
	self.chipInset = math.ceil(W - rootX) + 2
	-- The inlay: along the face's lower edge, under the reason line, from the
	-- wreath to where the bough ends.
	local inlayX0 = showIcon and (discRight - 2) or (plateX + 10)
	local inlayX1 = rootX - 1
	local inlayY = plateIn + 105 * su
	local inlayH = math.max(2.5, 3.2 * math.min(1.6, su / 0.3))
	self.inlayOK = inlayX1 - inlayX0 >= 16
	Box(self.inlay, art, inlayX0, inlayY - inlayH / 2, inlayX1, inlayY + inlayH / 2)
	Box(self.core, art, inlayX0, inlayY - inlayH / 2, inlayX1, inlayY + inlayH / 2)

	self:PlaceGrowth(showIcon, above)
	self:PlaceMotion(showIcon, above)

	-- The cursor's light over the upper bark.
	Box(self.hoverFrame, art, plateX + 4, plateIn, rootX, plateIn + 22 * su)
	self.hoverLight:SetVertexColor(MOONLIGHT[1], MOONLIGHT[2], MOONLIGHT[3], 1)

	local block = fs + 2 + sub
	self.block = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of where the bough narrows.
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

	-- The list's rows start where the name does, clear of the wreath, and end
	-- where the bough ends. Hung over the panel, the list keeps right of the
	-- antlers, which stand where it would begin.
	self.rowX = math.max(textX, 24)
	self.listX0 = plateX + 2
	if above and showIcon then
		self.listX0 = math.max(self.listX0, circle * (1 + ANTLER_X) + 1)
		self.rowX = math.max(self.rowX, self.listX0 + 17)
	end
	self.listX1 = math.max(self.rowX + 30, rootX + 3)
	local rowWidth = math.max(20, self.listX1 - self.rowX - 9)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	for _, t in ipairs({ self.disc, self.antlers[1], self.antlers[2], self.water[1], self.water[2], self.halo, self.lip,
		self.paw, self.bloom }) do
		t:SetShown(showIcon)
	end
	self.waterMask:SetShown(showIcon)
	for i, t in ipairs(self.sprigs) do t:SetShown(self.sprigOn[i]) end
	self.vineFrame:SetShown(self.vineOK)
	self.fx:SetShown(showIcon)
	self.inlay:SetShown(self.inlayOK)
	self.core:SetShown(self.inlayOK)
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
	self.pulseSpent, self.calmLit, self.owed, self.grown, self.shedded = nil, nil, nil, nil, nil
	self:Rest()
	self:Dress()
	if held then self:Combat(true) end
	-- Asked afresh: what stirs may stand elsewhere now.
	self.idleState = nil
	self:Idle()

	-- The count's room: a two-digit tag, the crozier and its inset. Chip
	-- widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The wreath, its antlers, the water in its bed, the icon's mask, the rings'
-- room and the lights that are the wreath's.
function Wild:PlaceWreath(showIcon)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local cx, cy, circle, iconSize, H = self.cx, self.cy, self.circle, self.iconSize, self.H
	At(self.disc, art, cx, cy, circle)
	At(self.halo, art, cx, cy, circle)
	At(self.lip, art, cx, cy, circle)
	At(self.waterMask, art, cx, cy, circle)
	for i, t in ipairs(self.water) do
		At(t, art, cx, cy, circle)
		self.waterScroll[i]:Window(circle / WATER.tile, circle / WATER.tile)
	end
	-- The antlers: the left one's box starts ANTLER_X of the wreath outside
	-- the wreath's and ANTLER_Y over it; the right one is its mirror.
	local size = circle * ANTLER_SIZE
	local hx, hy = cx - circle / 2 - circle * ANTLER_X, cy - circle / 2 - circle * ANTLER_Y
	Box(self.antlers[1], art, hx, hy, hx + size, hy + size)
	Box(self.antlers[2], art, 2 * cx - hx - size, hy, 2 * cx - hx, hy + size)
	-- The bloom behind the wreath, the paw over the icon: neither larger
	-- than its room, for neither grows.
	At(self.bloom, art, cx, cy, circle * 1.42)
	At(self.paw, art, cx, cy, iconSize * 0.84)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	self.vineFrame:ClearAllPoints()
	self.vineFrame:SetAllPoints(art)
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
		local limitH = math.min(self.textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
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
end

-- What grows on the bough: the sprigs, the vine and its blossoms.
function Wild:PlaceGrowth(showIcon, above)
	local art = self.kit.art
	local H, plateIn, cx, cy, circle = self.H, self.plateIn, self.cx, self.cy, self.circle
	local x0 = showIcon and self.discRight or (self.plateX + 8)
	local span = self.rootX - x0
	self.growX0, self.growSpan = x0, span
	-- The upper bark's middle line, and the lower's.
	local upper, lower = plateIn + 5 * self.su + 2, H - plateIn - 5 * self.su - 1
	self.upper, self.lower = upper, lower
	-- The sprigs: each rooted at a point, standing up from it or hanging
	-- (its file turned over, its root then at its top). On the wreath's left
	-- shoulder; two on the bough's upper side; one under it; one on the
	-- crozier's crown.
	local size = math.max(8, math.min(22, H * SPRIG.size))
	local crown = self.moonY - (MOON_SIZE * 0.5 + 19) * self.su
	local spots = {
		{ cx - circle * 0.17, cy + circle * 0.42, true, showIcon },
		{ x0 + span * 0.33, upper, false, span >= 60 and not above },
		{ x0 + span * 0.70, lower, true, span >= 60 },
		{ x0 + span * 0.86, upper, false, span >= 110 and not above },
		{ self.gemX + self.moonSize * 0.14, crown + 3, false, not above },
	}
	self.sprigOn, self.sprigAt = {}, spots
	for i, t in ipairs(self.sprigs) do
		local s = spots[i]
		local hang = s[3]
		t:ClearAllPoints()
		t:SetPoint(hang and "TOP" or "BOTTOM", art, "TOPLEFT", s[1], -s[2])
		t:SetSize(size, size)
		-- Every other one is its file's mirror, so no two lean alike.
		local l, r = 0, 1
		if i % 2 == 0 then l, r = 1, 0 end
		if hang then t:SetTexCoord(l, r, 1, 0) else t:SetTexCoord(l, r, 0, 1) end
		local turn = self.sways[i].turn
		if turn.SetOrigin then turn:SetOrigin(hang and "TOP" or "BOTTOM", 0, 0) end
		self.sprigOn[i] = s[4] and true or false
	end
	self.sprigSize = size

	-- The vine: along the bough's upper side from the wreath to where the
	-- bough narrows, a frame of its sheet as long as that and an eighth as
	-- tall, its stem on the upper bark. With the list hung over the panel it
	-- is no taller than keeps it inside the button.
	local vineH = span / 8
	if above then vineH = math.min(vineH, upper / VINE_STEM) end
	local top = upper - vineH * VINE_STEM
	self.vineOK = span >= 48
	Box(self.vine, art, x0 - 3, top, x0 - 3 + span, top + vineH)
	local bs = math.max(7, math.min(18, H * BLOSSOMS.size))
	if above then bs = math.min(bs, upper * 1.6) end
	self.blossomAt = {}
	for i, t in ipairs(self.blossoms) do
		local bx, by = x0 - 3 + span * BLOSSOMS.at[i], upper - bs * 0.30
		if above then by = math.max(by, bs / 2) end
		At(t, art, bx, by, bs)
		self.blossomAt[i] = { bx, by }
	end
	self.blossomSize = bs
	-- The light at the vine's tip runs its length as it grows.
	At(self.tip, art, x0, upper - bs * 0.2, bs * 1.5)
	self.tipAnim.move:SetOffset(span - 4, 0)
end

-- What moves: the drifting leaves, the fireflies, a landing's leaves and
-- petals, a refusal's husks. Each is given where it starts and where it
-- goes.
function Wild:PlaceMotion(showIcon, above)
	local art = self.kit.art
	local H, cx, cy, circle = self.H, self.cx, self.cy, self.circle
	local x0, span = self.growX0, self.growSpan
	-- With the list hung over the panel nothing rises over it or falls from
	-- above it.
	local lift = above and 0.3 or 1
	local leaf = math.max(6, math.min(13, H * 0.19))
	-- The drifting leaves: one from the crozier, down past the moon; one on
	-- the wind, over the bough's upper side; one from under the wreath.
	local drifts = {
		{ self.gemX - self.moonSize * 0.2, self.moonY + self.moonSize * 0.6, -7, H * 0.80 },
		{ x0 + span * 0.10, self.upper - 9 * lift, span * 0.55, 6 * lift },
		{ showIcon and (cx - circle * 0.30) or (x0 + 6), H - 2, -6, H * 0.50 },
	}
	for i, t in ipairs(self.drift) do
		local s = drifts[i]
		At(t, art, s[1], s[2], leaf)
		local g = self.driftAnims[i]
		g.move:SetOffset(0, -s[4])
		g.aside:SetOffset(s[3], 0)
	end
	self.driftOK = span >= 50
	-- The fireflies: over the antlers, over the bough, under it; the wisp by
	-- the moon. Each wanders three legs and ends near where it began.
	local mote = math.max(6, math.min(16, H * 0.28))
	local wander = {
		{ cx + circle * 0.10, cy - circle * 0.5 - 7 * lift, { 9, 5 * lift }, { -13, -3 * lift }, { 7, -5 * lift } },
		{ x0 + span * 0.46, self.upper - 5 * lift, { 13, 5 * lift }, { 9, -4 * lift }, { -9, 4 * lift } },
		{ self.gemX - self.moonSize * 0.7, self.moonY + self.moonSize * 0.9, { 5, 9 * lift }, { 8, 5 * lift }, { -9, 4 * lift } },
		{ x0 + span * 0.26, H + 4, { -9, -4 }, { 12, -3 }, { 6, 5 } },
	}
	for i, t in ipairs(self.motes) do
		local s = wander[i]
		At(t, art, s[1], s[2], mote)
		local legs = self.moteAnims[i].legs
		for k = 1, 3 do legs[k]:SetOffset(s[2 + k][1], s[2 + k][2]) end
	end
	-- A landing's leaves and petals: from the wreath's ring, outward, and
	-- down a little as they go. With the icon off, from the bough's end.
	local ox, oy = showIcon and cx or (self.plateX + 10), cy
	for i, t in ipairs(self.burst) do
		local b = BURST[i]
		local a = math.rad(b[1])
		local ux, uy = math.cos(a), -math.sin(a)
		local size = (i % 3 == 0) and leaf * 0.62 or leaf
		At(t, art, ox + ux * circle * 0.34, oy + uy * circle * 0.34, size)
		local reach = circle * b[2]
		local up = (uy < 0) and lift or 1
		self.burstAnims[i].move:SetOffset(ux * reach, -uy * reach * up)
		self.burstAnims[i].drop:SetOffset(0, -circle * 0.16)
	end
	-- The petals each blossom sheds: one to each side, up and away.
	local bs = self.blossomSize
	for i, t in ipairs(self.petals) do
		local at = self.blossomAt[math.floor((i + 1) / 2)]
		local side = (i % 2 == 0) and 1 or -1
		At(t, art, at[1], at[2], math.max(4, bs * 0.5))
		self.petalAnims[i].move:SetOffset(side * bs * 0.9, bs * 1.1 * lift)
		self.petalAnims[i].drop:SetOffset(side * 2, -bs * 0.7)
	end
	-- The husks: one from each sprig, down and aside.
	for i, t in ipairs(self.husks) do
		local s = self.sprigAt[i]
		local hang = s[3]
		At(t, art, s[1], s[2] + (hang and self.sprigSize * 0.6 or -self.sprigSize * 0.2), leaf)
		self.aftermath[i].move:SetOffset((i % 2 == 0) and 6 or -7, 0)
		self.aftermath[i].drop:SetOffset(0, -H * (hang and 0.55 or 0.95))
	end
end

-- The water in its colour, or what a refusal leaves of it.
function Wild:Water(r, g, b)
	self.water[1]:SetVertexColor(r, g, b, 1)
	local lr, lg, lb = self.kit.Tint(r, g, b, 0.30)
	self.water[2]:SetVertexColor(lr, lg, lb, WATER.second)
end

-- Every light where it rests: the water lit, the moon's light low, the core
-- low, the vine away, the rest dark.
function Wild:Rest()
	self.halo:SetAlpha(HALO.rest)
	self.moonGlow:SetAlpha(GLOW.rest)
	self.core:SetAlpha(CORE.rest)
	self.vineFrame:SetAlpha(0)
	for _, t in ipairs(self.blossoms) do t:SetAlpha(1) end
	for _, t in ipairs({ self.paw, self.bloom, self.hot, self.star, self.tip, self.hoverLight }) do t:SetAlpha(0) end
	for _, list in ipairs({ self.burst, self.petals, self.husks, self.drift, self.motes }) do
		for _, t in ipairs(list) do t:SetAlpha(0) end
	end
end

-- The vine grown and its blossoms open, with nothing played: for a repaint
-- of somebody already owed, a restyle, Calm.
function Wild:Grown()
	self.grown = true
	self.vineSheet:Stop()
	Still(self.vine, 1, VINE_ROWS, VINE_FRAMES - 1)
	self.vineSheet.shown = nil
	for i, t in ipairs(self.blossoms) do
		self.blossomSheets[i]:Stop()
		Still(t, BLOSSOM_COLS, BLOSSOM_ROWS, BLOSSOM_FRAMES - 1)
		self.blossomSheets[i].shown = nil
		if not self.shed[i]:IsPlaying() then t:SetAlpha(self.shedded and 0 or 1) end
	end
end

-- The vine away, and its frames stopped.
function Wild:Ungrow()
	self.grown, self.shedded = nil, nil
	self.vineSheet:Stop()
	for _, h in ipairs(self.blossomSheets) do h:Stop() end
	StopAll(self.budIn)
	StopAll(self.shed)
	self.vineIn:Stop()
	if not self.witherAnim:IsPlaying() then self.vineFrame:SetAlpha(0) end
end

-- What the look does at rest: the water ripples, the sprigs stir, the leaves
-- drift and the fireflies wander, on Full effects, out of a fight and with
-- the prompt up; all of it is stopped otherwise (stopped, not paused: the
-- water stands as it is, the lights park dark). Asked at every paint
-- (Painted), so it does nothing unless something changed.
function Wild:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.refused and 2 or 0) + (self.owed and 4 or 0)
	if state == self.idleState then return end
	self.idleState = state
	-- A refusal leaves the wood withered: nothing stirs on it until the next
	-- reason greens it.
	local alive = on and not self.refused
	for i, h in ipairs(self.waterScroll) do
		if alive and self.kit.icon:IsShown() then
			local k = self.owed and WATER.owed or 1
			h:Speed(WATER.du[i] * k, WATER.dv[i] * k)
			if not h:IsPlaying() then h:Play() end
		else
			h:Stop()
		end
	end
	for i, g in ipairs(self.sways) do
		if alive and self.sprigOn[i] then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for _, list in ipairs({ self.driftAnims, self.moteAnims }) do
		for _, g in ipairs(list) do
			if alive and self.driftOK then
				if not g:IsPlaying() then g:Play() end
			else
				g:Stop()
			end
		end
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome.
function Wild:Greet()
	if not self.active or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; and somebody new on the panel is greeted,
-- once. A favour arriving has its own lights, so the greeting is for a new
-- face only.
function Wild:Painted(entry)
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the bough (not under the crozier, which the sky is
-- behind), and the one under the list's plank when it is out.
function Wild:PlaceShadow(list)
	local art = self.kit.art
	local top = self.plateIn or 0
	PlacePieces(self.shadow, art, (self.plateX or 0) - SHADOW_OUT + 2, top - SHADOW_OUT + 1, (self.rootX or self.W) + SHADOW_OUT + 4,
		self.H - top + SHADOW_OUT + 1, SHADOW_C)
	Each(self.listShadow, "SetShown", list ~= nil)
	if list then
		PlacePieces(self.listShadow, art, list[1] - SHADOW_OUT + 2, list[2] - SHADOW_OUT + 2, list[3] + SHADOW_OUT - 1,
			list[4] + SHADOW_OUT + 1, SHADOW_C)
	end
end

function Wild:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the heartwood, whatever the panel colour: the legibility
	-- the shared code works out is held against the heartwood's own two ends.
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
	kit.name:SetShadowColor(0.03, 0.02, 0, 0.95)
	kit.name:SetShadowOffset(1, -1)
	-- The tags are dark wood whatever the panel, so their text is pale as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.93, 0.90, 0.80, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffb3ab96"
end

function Wild:Hide()
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
	self.waterMask:Hide()
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
	self.grown, self.shedded = nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Wild:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The crozier stands at the far end.
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
function Wild:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Wild:Fitted(fs)
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
function Wild:NameFits(room)
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
function Wild:KeyLabel()
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
function Wild:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Wild:Chip(on)
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

-- The wood and the leaves as the moment has them: dulled for a fight,
-- browned by a refusal, else themselves.
function Wild:Dress()
	local fight, sere = self.combat and true or false, self.refused and true or false
	for _, t in ipairs(self.leafy) do
		t:SetDesaturated(fight or sere)
		if fight then
			t:SetVertexColor(DULL[1], DULL[2], DULL[3], 1)
		elseif sere then
			t:SetVertexColor(SERE[1], SERE[2], SERE[3], 1)
		else
			t:SetVertexColor(1, 1, 1, 1)
		end
	end
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(fight)
		if fight then t:SetVertexColor(DULL[1], DULL[2], DULL[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
	end
	-- The bough: dimmed for a fight; its moss and its leaves browned with
	-- the rest by a refusal.
	local pc = self.bodyColour or { 1, 1, 1 }
	local fr, fg, fb = 1, 1, 1
	if fight then
		fr, fg, fb = BODY_COMBAT, BODY_COMBAT, BODY_COMBAT
	elseif sere then
		fr, fg, fb = WOOD_SERE[1], WOOD_SERE[2], WOOD_SERE[3]
	end
	Each(self.body, "SetDesaturated", fight or sere)
	Each(self.body, "SetVertexColor", pc[1] * fr, pc[2] * fg, pc[3] * fb, 1)
end

-- What a refusal leaves: the water spent, the leaves brown, the vine gone and
-- nothing stirring: until the next PaintReason.
function Wild:Spend()
	self:Water(SPENT[1], SPENT[2], SPENT[3])
	self.halo:SetAlpha(0)
	-- The vine is gone (its shrivelling, when that is playing, ends there),
	-- and grows again only for whoever is owed after.
	self.grown, self.shedded = nil, nil
	if not self.witherAnim:IsPlaying() then self.vineFrame:SetAlpha(0) end
	self:Dress()
	self:Idle()
end

-- The water in the reason's colour, and the moon and the inlay (each only
-- where the marker says so, else moonlight's own silver), their lights the
-- same colour taken towards white, and the reason line warmed towards it.
function Wild:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = SILVER[1], SILVER[2], SILVER[3] end
	if self.refused then
		self:Spend()
	else
		self:Water(cr, cg, cb)
	end
	local hr, hg, hb = kit.Tint(cr, cg, cb, 0.45)
	self.halo:SetVertexColor(hr, hg, hb, 1)
	self.moon:SetVertexColor(vr, vg, vb, 1)
	self.moonGlow:SetVertexColor(vr, vg, vb, 1)
	self.inlay:SetVertexColor(vr, vg, vb, INLAY_ALPHA)
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.45)
	self.core:SetVertexColor(ir, ig, ib, 1)
	local fr, fg, fb = kit.Tint(vr, vg, vb, FLASH_WHITE)
	self.hot:SetVertexColor(fr, fg, fb, 1)
	self.star:SetVertexColor(fr, fg, fb, 1)
	-- The reason line: a pale mist taken most of the way to the reason, held
	-- to its contrast on the heartwood.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { cr, cg, cb }
end

function Wild:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal spent the water and browned the leaves: they come back here,
	-- and a fight keeps the icon grey.
	local was = self.refused
	self.refused = nil
	if mode == "off" then
		self:Tint(SILVER[1], SILVER[2], SILVER[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	if was then
		self:Dress()
		self:Idle()
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The bough holds; everything that moves stops and the lights go out, the
-- wood and the leaves dull, the icon greys and the words dim. The water, the
-- moon and the inlay keep their colour: the reason is the one coloured thing
-- left.
function Wild:Combat(on)
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
	self.moonGlow:SetAlpha(on and GLOW.combat or GLOW.rest)
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Wild:HoldPulse(spent)
	StopAll(self.pulse)
	self.halo:SetAlpha(spent and HALO.held or HALO.rest)
	self.moonGlow:SetAlpha(spent and GLOW.held or GLOW.rest)
	self.core:SetAlpha(spent and CORE.held or CORE.rest)
end

-- The lights the flourishes share are one set of regions: one plays at a
-- time.
function Wild:StopLights()
	self.tipAnim:Stop()
	StopAll(self.landing)
	StopAll(self.refusal)
end

function Wild:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	local was = self.owed
	self.owed = true
	if not was then self:Idle() end
	-- A refusal withered the vine: nothing grows or breathes until the next
	-- PaintReason greens the wood again.
	if self.refused then
		self:HoldPulse()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The vine grows for a new favour, never a new face.
		if full and self.vineOK then
			self:StopLights()
			StopAll(self.calm)
			self.grown, self.shedded = true, nil
			for _, t in ipairs(self.blossoms) do t:SetAlpha(0) end
			PlayAll(self.arrive)
			self.vineSheet:Play()
			for _, h in ipairs(self.blossomSheets) do h:Play() end
		end
	end
	-- Grown for as long as somebody is owed, however it got there.
	if not self.grown then
		self:Grown()
		self.vineFrame:SetAlpha(1)
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
		-- Calm: one fade up to the held light, the vine with it, and nothing
		-- loops or plays.
		if not self.calmLit then
			self.calmLit = true
			StopAll(self.pulse)
			self:Grown()
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
		self.halo:SetAlpha(HALO.rest)
		self.moonGlow:SetAlpha(GLOW.rest)
		self.core:SetAlpha(CORE.rest)
		if self.grown and not self.vineIn:IsPlaying() then self.vineFrame:SetAlpha(1) end
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly. The vine
	-- and its blossoms are what say "owed" after.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Wild.pulseGen or not Wild.active then return end
			Wild.pulseSpent = true
			if Wild.pulse[1]:IsPlaying() then
				Wild:HoldPulse(true)
				-- Settled: the moon says so, once.
				Wild:Greet()
			end
		end)
	end
end

function Wild:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	self.tipAnim:Stop()
	self.halo:SetAlpha(HALO.rest)
	self.moonGlow:SetAlpha(self.combat and GLOW.combat or GLOW.rest)
	self.core:SetAlpha(CORE.rest)
	self:Ungrow()
	self.calmLit = nil
	self.owed = nil
	if self.active then self:Idle() end
end

function Wild:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal withers: the vine and its blossoms shrivel away, the leaves
	-- brown, husks fall, the water is left spent and one ring snaps in onto
	-- the wreath. The text's shake is Prompt's.
	if kind == "failed" then
		self.refused = true
		self:StopLights()
		self.vineIn:Stop()
		StopAll(self.budIn)
		if not self.combat then
			if self.owed and self.vineOK then
				-- Whole, however far it had grown, and then gone.
				self:Grown()
				self.vineFrame:SetAlpha(1)
				PlayAll(self.refusal)
			end
			-- Only the sprigs that are drawn shed.
			for i, g in ipairs(self.aftermath) do
				g:Stop()
				if self.sprigOn[i] then g:Play() end
			end
		end
		self:Spend()
		if shown then self.fx:Refuse(1.00, 0.40, 0.34, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- The leaves fly from the wreath (from the bough's end with the icon off).
	PlayAll(self.burstAnims)
	self.hotAnim:Stop()
	self.hotAnim:Play()
	if shown then
		self.pawAnim:Stop()
		self.pawAnim:Play()
		self.bloomAnim:Stop()
		self.bloomAnim:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- Every open blossom sheds its petals and is gone.
	if self.grown and self.vineOK and not self.shedded then
		-- Open, however far they had got, and then shed.
		StopAll(self.budIn)
		self.vineIn:Stop()
		self:Grown()
		self.vineFrame:SetAlpha(1)
		self.shedded = true
		PlayAll(self.shed)
		PlayAll(self.petalAnims)
	end
end

function Wild:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Wild:Hover(on)
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
-- the eye never has to find the person again. The inlay's core takes the
-- outcome's colour.
function Wild:PaintOutcome(kind, lead, sub, who, stamp)
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
	if self.grown and not self.witherAnim:IsPlaying() then self.vineFrame:SetAlpha(1) end
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

function Wild:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A plank of the same wood under the bough (or over it), from the wreath to
-- where the bough narrows; each row wears a small leaf in its reason's
-- colour.
function Wild:PaintQueue(rows, shown, above)
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
		self.beads[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.beads[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	local depth = shown * pitch + 7
	local H = self.H
	local y0, y1
	if above then
		y1 = self.plateIn + 4
		y0 = -depth
	else
		y0 = H - self.plateIn - 4
		y1 = H + depth
	end
	Each(self.listBody, "Show")
	local x0 = self.listX0
	PlacePieces(self.listBody, art, x0, y0, self.listX1, y1, math.min(LIST_C, (y1 - y0) / 2))
	self:PlaceShadow({ x0, y0, self.listX1, y1 })

	local bead = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = -(4 + (shown - i) * pitch + pitch / 2)
		else
			y = H + 3 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		At(self.beads[i], art, self.rowX - 9, y, bead)
	end
end
