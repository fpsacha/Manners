-- Manners -- the Frost look: a frost mage's.
--
-- THE SOURCE. The frost mage of Warcraft: Frost Armor and Ice Armor, the ring
-- Frost Nova throws, Ice Barrier, the Ice Block a mage shuts himself in, and
-- the glacial ice of Northrend that the Frozen Throne is cut from: blue-white,
-- chiselled, rimed, hung with icicles.
--
-- A SLAB of glacial ice: a chiselled blue-white rim, rime on its upper side,
-- round a face of deep dark ice the words stand on. At its left a six-pointed
-- ice CRYSTAL, a shard at each corner; the spell icon, round, stands in it in
-- a frozen RING that mist drifts in. At its right the slab ends in a cluster
-- of ice shards round a socket that holds a frost RUNE. ICICLES hang under
-- it. The MIST round the icon carries the reason's colour; the rune and a
-- fine vein of light along the face's lower edge carry it too. The list is a
-- sheet of the same ice under (or over) the slab, a small crystal for each
-- name.
--
-- Every region is a texture from Textures/Frost (tools/make_frost_textures.py).
-- The ice, the crystal, the icicles and the rime are baked, because they are
-- decoration. Everything that means something -- the mist, the rune, the
-- vein, the list's crystals, the glyphs -- is white or grey art coloured by
-- SetVertexColor, so one file serves all six reasons, both palettes, a custom
-- marker colour and the outcomes. The interface this file implements is
-- described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-frost.lua):
--   * at rest, on Full effects, the mist DRIFTS in the ring (two layers of
--     one cloud scrolled against one another, Looks/Flow.lua), the ice
--     glints, snow falls past the slab and a drop falls from an icicle now
--     and then. hunt35-effects lets the groups of `idle` loop with nobody
--     owed, by name; the Flow handles are `flows`;
--   * a favour arriving makes FROST SPREAD: rime creeps along the slab's
--     upper edge from both ends at once and meets in the middle (two sheets
--     of sixteen drawn frames, played once), a light running at each front,
--     and hoar frost whitens the rim;
--   * owed, SNOWFLAKES crystallise on the rime one after another (a sheet of
--     sixteen frames each, at its own pace) and stay; a light over the mist,
--     the rune's and the vein's breathe three times and then hold lit; the
--     mist drifts faster;
--   * a landing is the ICE BLOCK: a shell of ice shuts over the icon and
--     shatters, its fractures lit, shards flying from it; Frost Nova's ring
--     flashes behind the crystal, every snowflake bursts into splinters, the
--     rune is lit, and the shared rings spread from the icon;
--   * a refusal CRACKS it: fissures run across the slab and stay, the rime
--     and its snowflakes melt away, the icicles break off and fall, the ice
--     goes dull, the mist is left spent, the icon greys and one ring snaps
--     in; a cast nobody confirmed does nothing;
--   * no additive light at rest: the block's fractures, the nova, the rune's
--     flash and the rings are the only ADD regions, each lit under 0.6 s and
--     parked at nothing;
--   * the crystal, the end's shards and the rime stand past the panel, above
--     it, and the icicles below it. With the list hung over the panel the
--     rime keeps to the panel's own height and the list keeps right of the
--     crystal; with the list hung under it the icicles are not drawn;
--   * Calm keeps to fades: no drifting mist, no glint, no snow, no drop, no
--     creeping, no shattering; the rime and its snowflakes are simply there
--     while somebody is owed, and the cracks after a refusal;
--   * a fight stills all of it and puts the lights out, dulls the ice, dims
--     the words and greys the icon; the mist, the rune and the vein keep
--     their colour;
--   * the icon is the slider's size and always round ("Round the icon off"
--     reads nothing here);
--   * the words read: the name and the reason line stand on the deep ice
--     over a full dark shadow, the reason line and the verdict held to a
--     contrast of 7, and the slab stands a little past a low button so the
--     name keeps clear of the frosted rim;
--   * a colour never lights what was dimmed: the game keeps one alpha for a
--     texture, so every colour goes through Colour, which keeps the alpha
--     the texture has.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Frost\\Frost_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Frost = ns.Looks.Register("frost", {
	name = L["Frost -- a slab of glacial ice, a frozen ring and icicles"],
	title = L["Frost"],
	description = L["a slab of glacial ice, a frozen ring and icicles"],
	order = 9.8,
	-- The slab holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the deep ice whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_frost_textures.py (tests/scenarios/look-frost.lua
-- compares them): the icon fills this much of the bezel's box and the crystal
-- is drawn this much larger than it; the slab's design height, its left
-- end's width, its right end's (which reaches END_OVER above and below the
-- slab), where in the right end the face stops and the shards begin, and its
-- middle tile's width, in texels; the rune's middle from the slab's right
-- edge, and its width, in design texels; the sheets (the rime's is two, one
-- for each half of it), and the line the rime stands on in a frame of its
-- own; the tag's caps, the mask's fill and the ring file's line.
local ICON_FRAME = 0.75
local CIRCLE_SCALE = 1.5
local DESIGN_H = 128
local CAP_W = 64
local END_W = 128
local END_OVER = 64
local END_ROOT = 34
local TILE_W = 256
local RUNE_AT = 52
local RUNE_SIZE = 56
local RIME_COLS = 2
local RIME_ROWS = 8
local RIME_FRAMES = 16
local RIME_ROOT = 0.75
local FLAKE_COLS = 4
local FLAKE_ROWS = 4
local FLAKE_FRAMES = 16
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- The slab is this much of the button's height in from its top and its
-- bottom, so the crystal stands proud of it.
local PLATE_IN = 0.05
-- The slab is no taller than this much of the button's width, unless the
-- words need more: the face they stand on is this much of its height.
local SLAB_MAX, FACE = 0.30, 0.60
-- How tall the slab may stand against the button where the words need it.
local SLAB_OVER = 1.12
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- How far right of its middle the crystal is seen, as a fraction of its box;
-- the gap between it and the text; with the icon off, between the slab's end
-- and the text.
local CRYSTAL_REACH, TEXT_GAP, BARE_GAP = 0.46, 3, 15
-- The deep ice's own luminance under the words, its darkest and its
-- brightest (as greys, a crack's pale lip counted in), for Legible; and the
-- contrast the reason line and the verdict are held to on it: 7, not the 4.5
-- of the tags, since the line is small.
local TABLE_LO, TABLE_HI = 0.03, 0.22
local SUB_CONTRAST = 7
-- A chosen panel colour is mixed this far into the slab.
local BODY_MIX = 0.25
-- The list's sheet: its nine-slice corner, in units.
local LIST_C = 9
-- The shadow: its 9-slice corner in units, and how far past the slab its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local SNOW_WHITE = { 0.95, 0.98, 1.00 }
local TAG_INK = { 0.88, 0.94, 1.00 }
local HAZE = { 0.86, 0.92, 1.00 }
-- A fight's ice; a refusal's.
local DULL = { 0.62, 0.62, 0.64 }
local DEAD = { 0.78, 0.80, 0.84 }
-- Frost's own light: the block's fractures, the nova, the fronts of the rime,
-- the cursor's light.
local FROSTLIGHT = { 0.74, 0.92, 1.00 }
-- The mist, the rune and the vein where the marker does not colour them (ice
-- has no colour of its own), and what a refusal leaves of the mist.
local SILVER = { 0.82, 0.88, 0.94 }
local SPENT = { 0.30, 0.33, 0.38 }
-- A flash is the reason's colour taken this far to white.
local FLASH_WHITE = 0.5
local OUTCOME = {
	cast = { 0.56, 0.90, 0.62 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.84, 0.88, 0.94 },
}
-- What a fight does: the text dims, the icon greys and dims, the slab dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.72
-- The light over the mist at rest, lit and held after its breaths; the
-- rune's light and the vein's soft core over the same breath.
local HALO = { rest = 0, peak = 0.62, held = 0.30 }
local GLOW = { rest = 0.24, peak = 0.80, held = 0.50, combat = 0.12 }
local CORE = { rest = 0.15, peak = 0.60, held = 0.35 }
local VEIN_ALPHA = 0.60
local BREATHS, BREATH = 3, 1.25
-- The mist: a tile of its cloud in units, each layer's drift in tiles a
-- second, how much faster while somebody is owed, and the second layer's
-- share.
local MIST = { tile = 22, du = { 0.040, -0.028 }, dv = { -0.012, 0.020 }, owed = 2.4, second = 0.55 }
-- The rime: its frames a second (both halves at once, so it is grown in
-- RIME_SECONDS), how much of the rim's frost the hoar is, where its three
-- snowflakes stand along it, each one's frames a second, and how large a
-- snowflake is against the button.
local RIME_FPS = 29
local RIME_SECONDS = RIME_FRAMES / RIME_FPS
local HOAR_ALPHA = 0.85
local FLAKES = { at = { 0.16, 0.50, 0.82 }, fps = { 22, 16, 12 }, size = 0.36 }
-- The icicles: where each hangs along the slab, how long against the
-- longest, and the least room the slab must have for it; how long the
-- longest is against the button; and which one drips.
local ICICLES = { { 0.08, 0.72, 40 }, { 0.26, 1.00, 60 }, { 0.47, 0.50, 100 }, { 0.69, 0.86, 60 }, { 0.90, 0.60, 130 } }
local ICICLE_SIZE = 0.56
local DRIP = 2
-- The cracks a refusal leaves, and how dark they stand.
local CRACK_HELD = 0.90
-- What falls at rest: five flakes of snow (wait, fall, rest, turn), no two
-- to one measure, and the drop (wait, fall, rest). And the glints: two on the
-- ring, two on the slab's rim (wait, rest).
local SNOW = { { 0.4, 3.6, 3.1, 160 }, { 1.9, 2.8, 4.4, -200 }, { 3.6, 3.1, 5.2, 140 }, { 0.9, 4.0, 3.7, -170 }, { 2.7, 3.3, 4.8, 190 } }
local DROP = { 2.2, 0.75, 5.6 }
local GLINTS = { { 1.7, 4.9 }, { 4.3, 6.1 }, { 0.6, 5.4 }, { 3.1, 6.8 } }
-- A landing's shards: where each flies (degrees, the sun's way from the
-- right; how far, in crystals), and how it turns. None flies at the words.
local SHARDS = { { 96, 0.74, 260 }, { 128, 0.84, -300 }, { 158, 0.70, 220 }, { 188, 0.80, -240 }, { 218, 0.72, 280 },
	{ 247, 0.82, -220 }, { 276, 0.68, 250 }, { 302, 0.76, -280 }, { 54, 0.84, 240 }, { 74, 0.72, -260 } }
-- The block shuts, holds and is gone; then the shards fly.
local BLOCK = { shut = 0.05, hold = 0.09, gone = 0.12, alpha = 0.92 }
local SHATTER_AT, SHARD_SECONDS = 0.14, 0.44
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the rim above and below it.
function Frost.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 18)
end

-- The mist is the mark round the icon; the rune and the vein are the stripe.
function Frost.AccentCarriers(p)
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

-- Relative luminance of a grey, for the deep ice's own ink figures.
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

-- A texture's colour, its alpha left as it stands. The game keeps ONE alpha
-- for a texture: SetVertexColor's fourth number writes over what SetAlpha
-- set, so a light dimmed or parked at nothing and then coloured with an
-- alpha of 1 would stand at full strength. Every colour given to a region
-- whose alpha means something goes through here.
local function Colour(t, r, g, b)
	t:SetVertexColor(r, g, b, t:GetAlpha() or 1)
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

-- The slab: its left end, its tiled middle and its right end, the shards.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "IceL", "IceM", "IceR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- The slab laid over a box. The left end is the design's proportion of the
-- height; the right end is END_W wide and reaches END_OVER above and below
-- the box. The middle is tiled along what they leave, and begins the tile
-- where the left end left it, so the rim runs on. `hoar`, the frost laid
-- over the middle, is given the middle's own box and tiling. Returns where
-- the right end begins.
local function PlaceBody(s, hoar, rel, x0, y0, x1, y1)
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
	Box(hoar, rel, x0 + cap, y0, math.max(x0 + cap, rx), y1)
	hoar:SetTexCoord(1 - (n % 1), 1 + math.floor(n), 0, 1)
	hoar:SetShown(rx - x0 - cap > 0.5)
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

-- A glint on the ice: dark for `wait`, up and out as it turns a quarter,
-- dark again for `rest`, over and over.
local function Glint(region, wait, rest, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, 0.30, 2, nil, "OUT")
	Alpha(g, peak, 0, 0.60, 3, nil, "IN")
	Spin(g, -45, 0.30, 2)
	Spin(g, -45, 0.60, 3)
	Alpha(g, 0, 0, rest, 4)
	Park(g, region, 0)
	return g
end

-- A flake of snow falling: nothing for `wait`, then down and aside by the
-- offsets Apply gives it, turning as it goes, seen as it leaves and gone
-- before it arrives; then nothing again for `rest`, over and over.
local function Drift(region, wait, seconds, rest, degrees)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	g.move = Move(g, seconds, 2)
	g.aside = Move(g, seconds, 2, "IN_OUT")
	Spin(g, degrees, seconds, 2)
	Alpha(g, 0, 0.9, seconds * 0.14, 2, nil, "OUT")
	Alpha(g, 0.9, 0, seconds * 0.30, 2, seconds * 0.70, "IN")
	Alpha(g, 0, 0, rest, 3)
	Park(g, region, 0)
	return g
end

-- A drop from an icicle: nothing for `wait`, it swells at the icicle's point,
-- falls by the offset Apply gives it, quickening, and is gone; then nothing
-- for `rest`, over and over.
local function Drip(region, wait, seconds, rest)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, 1, 0.6, 2, nil, "OUT")
	g.move = Move(g, seconds, 3, "IN")
	Alpha(g, 1, 1, seconds * 0.7, 3)
	Alpha(g, 1, 0, seconds * 0.3, 3, seconds * 0.7, "IN")
	Alpha(g, 0, 0, rest, 4)
	Park(g, region, 0)
	return g
end

-- A shard thrown: out by one offset (slowing) and down by another
-- (quickening), which Apply gives it, turning; lit as it leaves and gone as
-- it lands. After `delay`, when one is given.
local function Fling(region, seconds, degrees, delay)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay and delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	g.move = Move(g, seconds, order, "OUT")
	g.drop = Move(g, seconds, order, "IN")
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

-- The rime melting: a shudder down to nothing.
local function Melt(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 1, 0.45, 0.08, 1, nil, "OUT")
	Alpha(g, 0.45, 0.75, 0.07, 2, nil, "IN")
	Alpha(g, 0.75, 0, 0.27, 3, nil, "IN")
	Park(g, region, 0)
	return g
end

-- An icicle breaking off: it hangs where it hung for `delay`, then drops by
-- the offsets Apply gives it, quickening and tipping, and is gone as it lands.
local function Break(region, seconds, degrees, delay)
	local g = region:CreateAnimationGroup()
	Alpha(g, 1, 1, delay, 1)
	g.move = Move(g, seconds, 2, "IN_OUT")
	g.drop = Move(g, seconds, 2, "IN")
	Spin(g, degrees, seconds, 2, "TOP", "IN")
	Alpha(g, 1, 1, seconds * 0.62, 2)
	Alpha(g, 1, 0, seconds * 0.38, 2, seconds * 0.62, "IN")
	Park(g, region, 0)
	return g
end

-- The Ice Block: shut, held, gone.
local function Shut(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, BLOCK.alpha, BLOCK.shut, 1, nil, "OUT")
	Alpha(g, BLOCK.alpha, BLOCK.alpha, BLOCK.hold, 2)
	Alpha(g, BLOCK.alpha, 0, BLOCK.gone, 3, nil, "IN")
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

function Frost:Build(kit)
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
	-- The cracks a refusal leaves across the slab, under the words.
	self.cracks = {}
	for i = 1, 2 do
		self.cracks[i] = tex(art, "BORDER", 2, "Crack")
		self.cracks[i]:SetAlpha(0)
	end
	-- The vein along the face's lower edge, and the soft core that breathes
	-- in it.
	self.vein = tex(art, "BORDER", 3, "Vein")
	self.core = tex(art, "BORDER", 4, "Vein")
	-- The rune in its socket, and the light it throws.
	self.runeGlow = tex(art, "BORDER", 5, "RuneGlow")
	self.rune = tex(art, "BORDER", 6, "Rune")
	-- The nova flashes BEHIND the crystal, and the shards fly from behind it:
	-- on art itself, under the crystal.
	self.nova = tex(art, "BORDER", 7, "Nova", "ADD")
	self.nova:SetVertexColor(FROSTLIGHT[1], FROSTLIGHT[2], FROSTLIGHT[3], 1)
	self.nova:SetAlpha(0)
	self.shards = {}
	for i = 1, #SHARDS do
		local t = tex(art, "ARTWORK", -8, "Shard")
		t:SetAlpha(0)
		self.shards[i] = t
	end
	-- The crystal, under the icon (ARTWORK 0): the mist in its ring (two
	-- layers, cut to the ring), the light over the mist, and the lip with the
	-- shade it throws.
	self.disc = tex(art, "ARTWORK", -6, "Crystal")
	self.mistMask = art:CreateMaskTexture()
	self.mistMask:SetTexture(ART .. "MistMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mist = {}
	for i = 1, 2 do
		self.mist[i] = tex(art, "ARTWORK", -6 + i, "Mist", nil, "REPEAT")
		self.mist[i]:AddMaskTexture(self.mistMask)
	end
	self.halo = tex(art, "ARTWORK", -3, "Halo")
	self.halo:SetAlpha(0)
	self.lip = tex(art, "ARTWORK", -2, "Lip")
	-- The glints: two on the ring, over the lip's shade and under the icon,
	-- and two on the slab's rim.
	self.glints = {}
	for i = 1, #GLINTS do
		local t = tex(art, "ARTWORK", -1, "Star")
		t:SetAlpha(0)
		self.glints[i] = t
	end
	-- The icicles under the slab.
	self.icicles = {}
	for i = 1, #ICICLES do self.icicles[i] = tex(art, "ARTWORK", 2, "Icicle") end

	-- The hoar, the rime and its snowflakes, on a frame that fades as one.
	self.rimeFrame = frame(1)
	self.rimeFrame:SetAlpha(0)
	self.hoar = tex(self.rimeFrame, "ARTWORK", -1, "Hoar", nil, "REPEAT", "CLAMP")
	self.hoar:SetAlpha(HOAR_ALPHA)
	-- The rime is two halves, each a sheet of its own: the left grows from
	-- the left, the right from the right, at once.
	self.rimes = { tex(self.rimeFrame, "ARTWORK", 0, "RimeA"), tex(self.rimeFrame, "ARTWORK", 0, "RimeB") }
	self.flakes = {}
	for i = 1, #FLAKES.at do self.flakes[i] = tex(self.rimeFrame, "ARTWORK", 1, "Flake") end

	-- The rings that spread from the crystal when a buff lands and the one
	-- that snaps in when one is refused: frames over the art, under the text.
	-- No echo of the icon: nothing lies over it but the block.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "FxRing", RING_PEAK, RING_EDGE)

	-- The Ice Block over the icon, its fractures lit, and the rune lit.
	self.lightFrame = frame(2)
	self.block = tex(self.lightFrame, "OVERLAY", 1, "Block")
	self.block:SetAlpha(0)
	self.crackle = tex(self.lightFrame, "OVERLAY", 2, "Crackle", "ADD")
	self.crackle:SetVertexColor(FROSTLIGHT[1], FROSTLIGHT[2], FROSTLIGHT[3], 1)
	self.crackle:SetAlpha(0)
	self.hot = tex(self.lightFrame, "OVERLAY", 3, "Hot", "ADD")
	self.hot:SetAlpha(0)
	-- What moves at rest, after a landing and after a refusal, none of it
	-- additive: the snow, the drop, the splinters the snowflakes burst into,
	-- the icicles that fall, the rune's glint.
	self.idleFrame = frame(1)
	self.snow = {}
	for i = 1, #SNOW do
		local t = tex(self.idleFrame, "ARTWORK", 1, "Snow")
		t:SetAlpha(0)
		self.snow[i] = t
	end
	self.drop = tex(self.idleFrame, "ARTWORK", 2, "Drop")
	self.drop:SetAlpha(0)
	self.sparks = {}
	for i = 1, #FLAKES.at * 2 do
		local t = tex(self.idleFrame, "ARTWORK", 2, "Spark")
		t:SetAlpha(0)
		self.sparks[i] = t
	end
	self.falls = {}
	for i = 1, #ICICLES do
		local t = tex(self.idleFrame, "ARTWORK", 3, "Icicle")
		t:SetAlpha(0)
		self.falls[i] = t
	end
	self.star = tex(self.idleFrame, "OVERLAY", 3, "Star")
	self.star:SetAlpha(0)
	-- The light at each front of the rime as it creeps.
	self.tips = {}
	for i = 1, 2 do
		local t = tex(self.idleFrame, "OVERLAY", 2, "Mote")
		t:SetVertexColor(FROSTLIGHT[1], FROSTLIGHT[2], FROSTLIGHT[3], 1)
		t:SetAlpha(0)
		self.tips[i] = t
	end
	-- The cursor's light: the upper rim lit.
	self.hoverFrame = frame(1)
	self.hoverLight = tex(self.hoverFrame, "OVERLAY", 1, "Edge")
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's crystals, one a row, in the row's reason colour.
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

	-- The ice a fight dulls and a refusal deadens: the crystal and the
	-- icicles (`icy`; the slab is dressed with them); and what a fight dulls
	-- only: the lip, the tags, the list's sheet, the glyph.
	self.icy = { self.disc }
	for _, t in ipairs(self.icicles) do self.icy[#self.icy + 1] = t end
	self.baked = { self.lip, self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end

	-- What moves by its coordinates (Looks/Flow.lua): the mist's two layers,
	-- the rime's two halves, the snowflakes.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.mistScroll = {}
	for i, t in ipairs(self.mist) do
		self.mistScroll[i] = flow:Scroll(t, MIST.du[i], MIST.dv[i], 1, 1)
	end
	self.rimeSheets = {}
	for i, t in ipairs(self.rimes) do
		self.rimeSheets[i] = flow:Sheet(t, RIME_COLS, RIME_ROWS, RIME_FRAMES, RIME_FPS, false)
	end
	self.flakeSheets = {}
	for i, t in ipairs(self.flakes) do
		self.flakeSheets[i] = flow:Sheet(t, FLAKE_COLS, FLAKE_ROWS, FLAKE_FRAMES, FLAKES.fps[i], false)
	end
	-- What plays for as long as the look is at rest: `flows`.
	self.flows = { self.mistScroll[1], self.mistScroll[2] }

	self:BuildAnimations(function(g) anims[#anims + 1] = g return g end)
end

function Frost:BuildAnimations(anim)
	-- The owed breath: the light over the mist, and the rune's light and the
	-- vein's core with it; see Attention for how long. The halo first:
	-- hunt35-effects times the breath by the first.
	self.pulse = {
		anim(Breathe(self.halo, HALO.rest, HALO.peak)), anim(Breathe(self.runeGlow, GLOW.rest, GLOW.peak)),
		anim(Breathe(self.core, CORE.rest, CORE.peak)),
	}
	-- "Once": one rise and fall, 0.55 s.
	self.once = {
		anim(Flash(self.halo, HALO.peak, 0.25, 0.30, 0)), anim(Flash(self.runeGlow, GLOW.peak, 0.25, 0.30, GLOW.rest)),
		anim(Flash(self.core, CORE.peak, 0.25, 0.30, CORE.rest)),
	}
	-- Calm: one fade up to the held light, the rime and its snowflakes with
	-- it, and nothing after.
	self.calm = {
		anim(Fade(self.halo, 0, HALO.held, 0.5)), anim(Fade(self.runeGlow, GLOW.rest, GLOW.held, 0.5)),
		anim(Fade(self.core, CORE.rest, CORE.held, 0.5)), anim(Fade(self.rimeFrame, 0, 1, 0.5)),
	}

	-- A favour arriving: the frost comes (the rime's frames are Flow's, 0.55 s
	-- from both ends at once, the hoar with it), a light at each front as it
	-- creeps, and each snowflake's seed shows as the rime reaches it.
	self.rimeIn = anim(Fade(self.rimeFrame, 0, 1, 0.30))
	self.seedIn = {}
	for i, t in ipairs(self.flakes) do
		local reached = 2 * math.min(FLAKES.at[i], 1 - FLAKES.at[i]) * RIME_SECONDS
		self.seedIn[i] = anim(Fade(t, 0, 1, 0.12, 0.05 + reached * 0.8))
	end
	self.tipAnims = {}
	for i, t in ipairs(self.tips) do self.tipAnims[i] = anim(Runner(t, RIME_SECONDS, 0.85)) end
	self.arrive = { self.rimeIn, self.tipAnims[1], self.tipAnims[2] }
	for _, g in ipairs(self.seedIn) do self.arrive[#self.arrive + 1] = g end

	-- A landing: the block shuts over the icon and is gone (0.26 s), its
	-- fractures lit as it breaks, the nova flashes behind the crystal, the
	-- shards fly (out by 0.58 s), every snowflake bursts into two splinters
	-- and is gone, and the rune is lit (out by 0.5 s).
	self.blockAnim = anim(Shut(self.block))
	self.crackleAnim = anim(Flash(self.crackle, 0.90, 0.05, 0.30, 0, BLOCK.shut + BLOCK.hold - 0.04))
	self.novaAnim = anim(Flash(self.nova, 0.90, 0.08, 0.36, 0, SHATTER_AT))
	self.hotAnim = anim(Flash(self.hot, 0.60, 0.08, 0.30, 0, 0.12))
	self.landing = { self.blockAnim, self.crackleAnim, self.novaAnim, self.hotAnim }
	self.shardAnims = {}
	for i, t in ipairs(self.shards) do
		self.shardAnims[i] = anim(Fling(t, SHARD_SECONDS - 0.02 * (i % 4), SHARDS[i][3], SHATTER_AT))
		self.landing[#self.landing + 1] = self.shardAnims[i]
	end
	self.sparkAnims, self.shed = {}, {}
	for i, t in ipairs(self.sparks) do
		self.sparkAnims[i] = anim(Fling(t, 0.50, (i % 2 == 0) and 200 or -230, 0.03 * i))
		self.landing[#self.landing + 1] = self.sparkAnims[i]
	end
	for i, t in ipairs(self.flakes) do
		self.shed[i] = anim(Fade(t, 1, 0, 0.16, 0.03 * i))
		self.landing[#self.landing + 1] = self.shed[i]
	end

	-- A refusal: the cracks run (and stay), the rime and its snowflakes melt,
	-- 0.42 s, and the icicles break off and fall for most of a second after
	-- (not a light: `aftermath`).
	self.meltAnim = anim(Melt(self.rimeFrame))
	self.crackIn = {}
	for i, t in ipairs(self.cracks) do self.crackIn[i] = anim(Fade(t, 0, CRACK_HELD, 0.07, 0.05 * (i - 1))) end
	self.refusal = { self.meltAnim, self.crackIn[1], self.crackIn[2] }
	self.aftermath = {}
	for i, t in ipairs(self.falls) do
		self.aftermath[i] = anim(Break(t, 0.52 + 0.05 * i, (i % 2 == 0) and 24 or -30, 0.04 + 0.07 * (i - 1)))
	end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- At rest: the ice glints, the snow falls, a drop falls from an icicle.
	-- hunt35-effects lets the groups of this list loop with nobody owed, and
	-- no others. See Idle for when they run.
	self.glintAnims, self.snowAnims = {}, {}
	self.idle = {}
	for i, t in ipairs(self.glints) do
		self.glintAnims[i] = anim(Glint(t, GLINTS[i][1], GLINTS[i][2], 0.85))
		self.idle[#self.idle + 1] = self.glintAnims[i]
	end
	for i, t in ipairs(self.snow) do
		self.snowAnims[i] = anim(Drift(t, SNOW[i][1], SNOW[i][2], SNOW[i][3], SNOW[i][4]))
		self.idle[#self.idle + 1] = self.snowAnims[i]
	end
	self.dripAnim = anim(Drip(self.drop, DROP[1], DROP[2], DROP[3]))
	self.idle[#self.idle + 1] = self.dripAnim
	-- The greeting: the rune glints, once, out by 0.8 s.
	self.greet = { anim(Twinkle(self.star, 0.30, 0.9, 0.12, 0.34)) }

	-- The cursor's light on the upper rim, both ways; from and to are set
	-- for each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Frost:Apply(p, above)
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
	-- the icon's frame, held inside the button's height; the crystal is drawn
	-- CIRCLE_SCALE larger, taller than the slab and, at the default sizes,
	-- than the button: its shards stand proud of both. When the cap bites,
	-- the hole shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local circle = bz * CIRCLE_SCALE
	-- The crystal's left edge is the button's.
	local cx, cy = circle / 2, H / 2
	-- The slab: inset from the button's top and bottom, from under the
	-- crystal to the right edge; with the icon off, the whole width. Its
	-- right end is as wide as the slab is tall, so on a button much taller
	-- than it is wide the slab keeps to a part of the width (and to what the
	-- words need), and lies across the button's middle.
	local plateIn = math.max(1, math.floor(H * PLATE_IN + 0.5))
	-- The words want a face as tall as their two lines and a little over, so
	-- that the name keeps clear of the frosted rim over it: where the button
	-- is too low for that, the slab stands SLAB_OVER past it, above and below.
	local need = (fs + 2 + sub + 4) / FACE
	local ph = math.min(math.max(H - 2 * plateIn, math.min(need, H * SLAB_OVER)), math.max(W * SLAB_MAX, need))
	plateIn = (H - ph) / 2
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph, self.su = plateIn, plateX, ph, su
	local endX = PlaceBody(self.body, self.hoar, art, plateX, plateIn, W, H - plateIn)
	self.endX = endX
	-- Where the shards begin: the words, the tags and the list keep left of
	-- them.
	local rootX = endX + END_ROOT * su
	self.rootX = rootX
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
	Each(self.listShadow, "SetVertexColor", 0, 0, 0, self.shadowAlpha)
	self:PlaceShadow(nil)

	local discRight = cx + circle * CRYSTAL_REACH
	local textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP
	self.iconSize, self.cx, self.cy, self.bz, self.circle, self.discRight, self.textX = iconSize, cx, cy, bz, circle, discRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self:PlaceCrystal(showIcon)

	-- The rune in its socket, its light, and the room the shards take at the
	-- right.
	local gemX = W - RUNE_AT * su
	local runeSize = math.max(6, RUNE_SIZE * su)
	At(self.rune, art, gemX, cy, runeSize)
	At(self.runeGlow, art, gemX, cy, runeSize * 1.7)
	At(self.hot, art, gemX, cy, runeSize * 1.25)
	At(self.star, art, gemX + runeSize * 0.16, cy - runeSize * 0.20, math.max(8, runeSize * 1.1))
	self.gemX, self.runeSize = gemX, runeSize
	self.chipInset = math.ceil(W - rootX) + 2
	-- The vein: along the lower rim's lip, clear of the reason line over it,
	-- from the crystal to where the slab ends.
	local veinX0 = showIcon and (discRight - 2) or (plateX + 12)
	local veinX1 = rootX - 1
	local veinY = plateIn + 109 * su
	local veinH = math.max(2.5, 3.2 * math.min(1.6, su / 0.3))
	self.veinOK = veinX1 - veinX0 >= 16
	Box(self.vein, art, veinX0, veinY - veinH / 2, veinX1, veinY + veinH / 2)
	Box(self.core, art, veinX0, veinY - veinH / 2, veinX1, veinY + veinH / 2)

	self:PlaceGrowth(showIcon, above)
	self:PlaceMotion(showIcon, above)

	-- The cursor's light over the upper rim.
	Box(self.hoverFrame, art, plateX + 4, plateIn, rootX, plateIn + 22 * su)
	Colour(self.hoverLight, FROSTLIGHT[1], FROSTLIGHT[2], FROSTLIGHT[3])

	local block = fs + 2 + sub
	self.blockH = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of where the shards begin.
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

	-- The list's rows start where the name does, clear of the crystal, and
	-- end where the slab ends. Hung over the panel, the list keeps right of
	-- the crystal, whose shards stand where it would begin.
	self.rowX = math.max(textX, 24)
	self.listX0 = plateX + 2
	if above and showIcon then
		self.listX0 = math.max(self.listX0, circle + 1)
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
	PlaceBody(self.body, self.hoar, art, plateX, plateIn, W, H - plateIn)
	for _, t in ipairs({ self.disc, self.mist[1], self.mist[2], self.halo, self.lip, self.block, self.crackle, self.nova,
		self.glints[1], self.glints[2] }) do
		t:SetShown(showIcon)
	end
	self.mistMask:SetShown(showIcon)
	self.rimeFrame:SetShown(self.rimeOK)
	for i, t in ipairs(self.cracks) do t:SetShown(self.crackOn[i]) end
	self.fx:SetShown(showIcon)
	self.vein:SetShown(self.veinOK)
	self.core:SetShown(self.veinOK)
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
	self:Hang()
	self:Dress()
	if held then self:Combat(true) end
	-- Asked afresh: what falls may fall elsewhere now.
	self.idleState = nil
	self:Idle()

	-- The count's room: a two-digit tag, the shards and their inset. Chip
	-- widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The crystal, the mist in its ring, the icon's mask, the rings' room and the
-- lights that are the crystal's.
function Frost:PlaceCrystal(showIcon)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local cx, cy, circle, iconSize, H = self.cx, self.cy, self.circle, self.iconSize, self.H
	At(self.disc, art, cx, cy, circle)
	At(self.halo, art, cx, cy, circle)
	At(self.lip, art, cx, cy, circle)
	At(self.mistMask, art, cx, cy, circle)
	for i, t in ipairs(self.mist) do
		At(t, art, cx, cy, circle)
		self.mistScroll[i]:Window(circle / MIST.tile, circle / MIST.tile)
	end
	-- The ring's glints: one where the light lies on it and one across from
	-- it.
	local ring = circle * 0.295
	for i = 1, 2 do
		local a = math.rad(i == 1 and -128 or 40)
		At(self.glints[i], art, cx + ring * math.cos(a), cy + ring * math.sin(a), math.max(6, circle * 0.16))
	end
	-- The nova behind the crystal, the block and its fractures over the
	-- icon: none larger than its room, for none grows.
	At(self.nova, art, cx, cy, circle * 1.30)
	At(self.block, art, cx, cy, iconSize * 1.06)
	At(self.crackle, art, cx, cy, iconSize * 1.06)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	self.rimeFrame:ClearAllPoints()
	self.rimeFrame:SetAllPoints(art)
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

-- What grows on the slab and hangs from it: the icicles, the rime and its
-- snowflakes, and where a refusal's cracks run.
function Frost:PlaceGrowth(showIcon, above)
	local art = self.kit.art
	local H, plateIn, ph = self.H, self.plateIn, self.ph
	local x0 = showIcon and self.discRight or (self.plateX + 10)
	local span = self.rootX - x0
	self.growX0, self.growSpan = x0, span
	-- The upper rim's middle line, and the lower's.
	local upper, lower = plateIn + 5 * self.su + 2, H - plateIn - 5 * self.su - 1
	self.upper, self.lower = upper, lower
	-- The icicles: each hangs from the slab's under side, as long as its
	-- share of the longest; every other one is its file's mirror.
	local long = math.max(10, math.min(26, H * ICICLE_SIZE))
	local hangY = H - plateIn - 4 * self.su
	self.icicleOn, self.icicleAt, self.icicleUp = {}, {}, {}
	for i, t in ipairs(self.icicles) do
		local s = ICICLES[i]
		local h = long * s[2]
		local x = x0 + span * s[1]
		t:ClearAllPoints()
		t:SetPoint("TOP", art, "TOPLEFT", x, -hangY)
		t:SetSize(h / 2, h)
		if i % 2 == 1 then t:SetTexCoord(1, 0, 0, 1) else t:SetTexCoord(0, 1, 0, 1) end
		self.icicleOn[i] = span >= s[3]
		self.icicleAt[i] = { x, hangY, h }
		local fall = self.falls[i]
		fall:ClearAllPoints()
		fall:SetPoint("TOP", art, "TOPLEFT", x, -hangY)
		fall:SetSize(h / 2, h)
		if i % 2 == 1 then fall:SetTexCoord(1, 0, 0, 1) else fall:SetTexCoord(0, 1, 0, 1) end
		self.aftermath[i].move:SetOffset((i % 2 == 0) and 2 or -2, 0)
		self.aftermath[i].drop:SetOffset(0, -H * 0.95)
	end
	-- The drop: at the point of the icicle that drips (three eighths across
	-- its file), and as far down as the icicle is long.
	local drip = self.icicleAt[DRIP]
	At(self.drop, art, drip[1] - drip[3] * 0.0625, drip[2] + drip[3] * 0.96, math.max(4, drip[3] * 0.26))
	self.dripAnim.move:SetOffset(0, -math.max(12, H * 0.42))

	-- The rime: along the slab's upper side from the crystal to where the
	-- shards begin, a frame of each half's sheet half as long as that and an
	-- eighth of it tall, standing on the upper rim. With the list hung over
	-- the panel it is no taller than keeps it inside the button.
	local rimeH = span / 8
	if above then rimeH = math.min(rimeH, upper / RIME_ROOT) end
	local top = upper - rimeH * RIME_ROOT
	self.rimeOK = span >= 48
	Box(self.rimes[1], art, x0, top, x0 + span / 2, top + rimeH)
	Box(self.rimes[2], art, x0 + span / 2, top, x0 + span, top + rimeH)
	local bs = math.max(8, math.min(17, H * FLAKES.size))
	if above then bs = math.min(bs, upper * 1.6) end
	self.flakeAt = {}
	for i, t in ipairs(self.flakes) do
		local bx, by = x0 + span * FLAKES.at[i], upper - bs * 0.42
		if above then by = math.max(by, bs / 2) end
		At(t, art, bx, by, bs)
		self.flakeAt[i] = { bx, by }
	end
	self.flakeSize = bs
	-- The light at each front runs its half of the slab as the rime creeps.
	At(self.tips[1], art, x0, upper - bs * 0.2, bs * 1.5)
	At(self.tips[2], art, x0 + span, upper - bs * 0.2, bs * 1.5)
	self.tipAnims[1].move:SetOffset(span / 2 - 2, 0)
	self.tipAnims[2].move:SetOffset(-(span / 2 - 2), 0)

	-- The cracks: one from the crystal's side, across the slab's whole
	-- height and twice as long; on a slab with the room, a second from the
	-- far end, the first turned about.
	local cw = math.min(2 * ph, span)
	Box(self.cracks[1], art, x0 + 1, plateIn, x0 + 1 + cw, H - plateIn)
	Box(self.cracks[2], art, x0 + span - cw, plateIn, x0 + span, H - plateIn)
	self.cracks[2]:SetTexCoord(1, 0, 1, 0)
	self.crackOn = { span >= 30, span >= cw * 1.7 }
end

-- What moves: the snow, a landing's shards and splinters. Each is given
-- where it starts and where it goes.
function Frost:PlaceMotion(showIcon, above)
	local art = self.kit.art
	local H, cx, cy, circle = self.H, self.cx, self.cy, self.circle
	local x0, span = self.growX0, self.growSpan
	-- With the list hung over the panel nothing falls from above it.
	local lift = above and 0.3 or 1
	local flake = math.max(5, math.min(9, H * 0.16))
	-- The snow: one over the crystal's shoulder, two onto the slab's upper
	-- rim, one past the shards at the far end, one from under the slab. None
	-- crosses the words: each is gone by the rim, or falls clear of the face.
	local snows = {
		{ showIcon and (cx - circle * 0.34) or (x0 + 4), -16 * lift, 4, math.max(0, cy - circle * 0.30) + 16 * lift },
		{ x0 + span * 0.30, -16 * lift, 6, self.upper + 16 * lift - 2 },
		{ x0 + span * 0.66, -14 * lift, -5, self.upper + 14 * lift - 2 },
		{ self.gemX + self.runeSize * 0.62, -14 * lift, -4, H * 0.30 + 14 * lift },
		{ x0 + span * 0.56, H - 1, 6, H * 0.45 },
	}
	for i, t in ipairs(self.snow) do
		local s = snows[i]
		At(t, art, s[1], s[2], flake)
		local g = self.snowAnims[i]
		g.move:SetOffset(0, -math.max(4, s[4]))
		g.aside:SetOffset(s[3], 0)
	end
	self.snowOK = span >= 50
	-- The rim's glints: one on the upper rim, one on the lower.
	local glint = math.max(6, math.min(11, H * 0.22))
	At(self.glints[3], art, x0 + span * 0.24, self.upper - 1, glint)
	At(self.glints[4], art, x0 + span * 0.63, self.lower + 1, glint)
	-- A landing's shards: from the icon's rim, outward, and down a little as
	-- they go. With the icon off, from the slab's end.
	local ox, oy = showIcon and cx or (self.plateX + 12), cy
	local size = math.max(7, math.min(14, H * 0.26))
	for i, t in ipairs(self.shards) do
		local b = SHARDS[i]
		local a = math.rad(b[1])
		local ux, uy = math.cos(a), -math.sin(a)
		At(t, art, ox + ux * circle * 0.24, oy + uy * circle * 0.24, (i % 3 == 0) and size * 0.7 or size)
		local reach = circle * b[2]
		local up = (uy < 0) and lift or 1
		self.shardAnims[i].move:SetOffset(ux * reach, -uy * reach * up)
		self.shardAnims[i].drop:SetOffset(0, -circle * 0.14)
	end
	-- The splinters each snowflake bursts into: one to each side, up and away.
	local bs = self.flakeSize
	for i, t in ipairs(self.sparks) do
		local at = self.flakeAt[math.floor((i + 1) / 2)]
		local side = (i % 2 == 0) and 1 or -1
		At(t, art, at[1], at[2], math.max(4, bs * 0.5))
		self.sparkAnims[i].move:SetOffset(side * bs * 0.9, bs * 1.0 * lift)
		self.sparkAnims[i].drop:SetOffset(side * 2, -bs * 0.7)
	end
end

-- The mist in its colour, or what a refusal leaves of it.
function Frost:Mist(r, g, b)
	self.mist[1]:SetVertexColor(r, g, b, 1)
	local lr, lg, lb = self.kit.Tint(r, g, b, 0.30)
	self.mist[2]:SetVertexColor(lr, lg, lb, MIST.second)
end

-- Every light where it rests: the mist lit, the rune's light low, the core
-- low, the rime away, the slab whole, the rest dark.
function Frost:Rest()
	self.halo:SetAlpha(HALO.rest)
	self.runeGlow:SetAlpha(GLOW.rest)
	self.core:SetAlpha(CORE.rest)
	self.rimeFrame:SetAlpha(0)
	for _, t in ipairs(self.flakes) do t:SetAlpha(1) end
	for _, t in ipairs({ self.block, self.crackle, self.nova, self.hot, self.star, self.drop, self.hoverLight }) do t:SetAlpha(0) end
	for _, list in ipairs({ self.shards, self.sparks, self.falls, self.snow, self.glints, self.tips, self.cracks }) do
		for _, t in ipairs(list) do t:SetAlpha(0) end
	end
end

-- The rime grown and its snowflakes whole, with nothing played: for a repaint
-- of somebody already owed, a restyle, Calm.
function Frost:Grown()
	self.grown = true
	for i, t in ipairs(self.rimes) do
		self.rimeSheets[i]:Stop()
		Still(t, RIME_COLS, RIME_ROWS, RIME_FRAMES - 1)
		self.rimeSheets[i].shown = nil
	end
	for i, t in ipairs(self.flakes) do
		self.flakeSheets[i]:Stop()
		Still(t, FLAKE_COLS, FLAKE_ROWS, FLAKE_FRAMES - 1)
		self.flakeSheets[i].shown = nil
		if not self.shed[i]:IsPlaying() then t:SetAlpha(self.shedded and 0 or 1) end
	end
end

-- The rime away, and its frames stopped.
function Frost:Ungrow()
	self.grown, self.shedded = nil, nil
	for _, h in ipairs(self.rimeSheets) do h:Stop() end
	for _, h in ipairs(self.flakeSheets) do h:Stop() end
	StopAll(self.seedIn)
	StopAll(self.shed)
	self.rimeIn:Stop()
	if not self.meltAnim:IsPlaying() then self.rimeFrame:SetAlpha(0) end
end

-- Whether the list hangs under the slab, where the icicles would hang.
function Frost:ListBelow()
	return (self.listShown and not self.listAt) and true or false
end

-- The icicles that hang: those the slab has room for, until a refusal breaks
-- them off, and never into a list hung under the slab.
function Frost:Hang()
	local gone = self.refused or self:ListBelow()
	for i, t in ipairs(self.icicles) do
		local up = (self.icicleOn[i] and not gone) and true or false
		self.icicleUp[i] = up
		t:SetShown(up)
	end
end

-- What the look does at rest: the mist drifts, the ice glints, the snow
-- falls and an icicle drips, on Full effects, out of a fight and with the
-- prompt up; all of it is stopped otherwise (stopped, not paused: the mist
-- stands as it is, the lights park dark). Asked at every paint (Painted), so
-- it does nothing unless something changed.
function Frost:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local below = self:ListBelow()
	local state = (on and 1 or 0) + (self.refused and 2 or 0) + (self.owed and 4 or 0) + (below and 8 or 0)
	if state == self.idleState then return end
	self.idleState = state
	-- A refusal leaves the ice dead: nothing moves on it until the next
	-- reason clears it.
	local alive = on and not self.refused
	local icon = self.kit.icon:IsShown()
	for i, h in ipairs(self.mistScroll) do
		if alive and icon then
			local k = self.owed and MIST.owed or 1
			h:Speed(MIST.du[i] * k, MIST.dv[i] * k)
			if not h:IsPlaying() then h:Play() end
		else
			h:Stop()
		end
	end
	for i, g in ipairs(self.glintAnims) do
		local here = icon
		if i > 2 then here = self.snowOK end
		if alive and here then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for i, g in ipairs(self.snowAnims) do
		-- The last falls from under the slab, where the list may hang.
		if alive and self.snowOK and not (below and i == #self.snowAnims) then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	if alive and self.icicleUp[DRIP] then
		if not self.dripAnim:IsPlaying() then self.dripAnim:Play() end
	else
		self.dripAnim:Stop()
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome.
function Frost:Greet()
	if not self.active or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; and somebody new on the panel is greeted,
-- once. A favour arriving has its own lights, so the greeting is for a new
-- face only.
function Frost:Painted(entry)
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the slab (not under the shards, which the sky is behind),
-- and the one under the list's sheet when it is out.
function Frost:PlaceShadow(list)
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

function Frost:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the deep ice, whatever the panel colour: the legibility
	-- the shared code works out is held against the deep ice's own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(SNOW_WHITE[1], SNOW_WHITE[2], SNOW_WHITE[3], 1)
	end
	kit.name:SetShadowColor(0, 0.01, 0.04, 0.95)
	kit.name:SetShadowOffset(1, -1)
	-- The reason line is small: a full dark shadow under it, whatever the
	-- panel colour made of the shared one.
	kit.sub:SetShadowColor(0, 0.01, 0.04, 1)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are dark ice whatever the panel, so their text is pale as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.90, 0.94, 1.00, 4.5)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(r, g, b, 1)
		fs:SetShadowColor(0, 0.01, 0.04, 1)
		fs:SetShadowOffset(1, -1)
	end
	ink.rowReason = "|cffa6b8cc"
end

function Frost:Hide()
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
	self.mistMask:Hide()
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
	self.listShown, self.listAt, self.countMode, self.keyUp = nil, nil, nil, false
	self.pulseSpent, self.calmLit, self.owed, self.idleState, self.greeted = nil, nil, nil, nil, nil
	self.grown, self.shedded = nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Frost:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The shards stand at the far end.
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
function Frost:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Frost:Fitted(fs)
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
function Frost:NameFits(room)
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
function Frost:KeyLabel()
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
function Frost:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Frost:Chip(on)
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

-- The ice as the moment has it: dulled for a fight, deadened by a refusal,
-- else itself.
function Frost:Dress()
	local fight, dead = self.combat and true or false, self.refused and true or false
	for _, t in ipairs(self.icy) do
		t:SetDesaturated(fight or dead)
		if fight then
			Colour(t, DULL[1], DULL[2], DULL[3])
		elseif dead then
			Colour(t, DEAD[1], DEAD[2], DEAD[3])
		else
			Colour(t, 1, 1, 1)
		end
	end
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(fight)
		if fight then Colour(t, DULL[1], DULL[2], DULL[3]) else Colour(t, 1, 1, 1) end
	end
	-- The slab: dimmed for a fight; greyed with the rest by a refusal.
	local pc = self.bodyColour or { 1, 1, 1 }
	local fr, fg, fb = 1, 1, 1
	if fight then
		fr, fg, fb = BODY_COMBAT, BODY_COMBAT, BODY_COMBAT
	elseif dead then
		fr, fg, fb = DEAD[1], DEAD[2], DEAD[3]
	end
	Each(self.body, "SetDesaturated", fight or dead)
	for _, t in ipairs(self.body) do Colour(t, pc[1] * fr, pc[2] * fg, pc[3] * fb) end
end

-- What a refusal leaves: the slab cracked and dull, the mist spent, the rime
-- gone, the icicles broken off and nothing moving: until the next
-- PaintReason.
function Frost:Spend()
	self:Mist(SPENT[1], SPENT[2], SPENT[3])
	self.halo:SetAlpha(0)
	-- The cracks stand (their running, when that is playing, ends there).
	for i, t in ipairs(self.cracks) do
		if not self.crackIn[i]:IsPlaying() then t:SetAlpha(CRACK_HELD) end
	end
	-- The rime is gone (its melting, when that is playing, ends there), and
	-- creeps again only for whoever is owed after.
	self.grown, self.shedded = nil, nil
	if not self.meltAnim:IsPlaying() then self.rimeFrame:SetAlpha(0) end
	self:Hang()
	self:Dress()
	self:Idle()
end

-- The slab made whole after a refusal: the cracks closed, the icicles back.
function Frost:Mend()
	StopAll(self.crackIn)
	for _, t in ipairs(self.cracks) do t:SetAlpha(0) end
	self:Hang()
	self:Dress()
	self:Idle()
end

-- The mist in the reason's colour, and the rune and the vein (each only
-- where the marker says so, else ice's own silver), their lights the same
-- colour taken towards white, and the reason line coloured towards it.
function Frost:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = SILVER[1], SILVER[2], SILVER[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = SILVER[1], SILVER[2], SILVER[3] end
	if self.refused then
		self:Spend()
	else
		self:Mist(cr, cg, cb)
	end
	local hr, hg, hb = kit.Tint(cr, cg, cb, 0.45)
	Colour(self.halo, hr, hg, hb)
	local gr, gg, gb = kit.Tint(cr, cg, cb, 0.75)
	for _, t in ipairs(self.glints) do Colour(t, gr, gg, gb) end
	Colour(self.rune, vr, vg, vb)
	Colour(self.runeGlow, vr, vg, vb)
	self.vein:SetVertexColor(vr, vg, vb, VEIN_ALPHA)
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.45)
	Colour(self.core, ir, ig, ib)
	local fr, fg, fb = kit.Tint(vr, vg, vb, FLASH_WHITE)
	Colour(self.hot, fr, fg, fb)
	Colour(self.star, fr, fg, fb)
	-- The reason line: a pale haze taken most of the way to the reason, held
	-- to a strong contrast on the deep ice.
	local sr = HAZE[1] + (r - HAZE[1]) * 0.6
	local sg = HAZE[2] + (g - HAZE[2]) * 0.6
	local sb = HAZE[3] + (b - HAZE[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glyph, sr, sg, sb)
	self.tint = { cr, cg, cb }
end

function Frost:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal cracked the slab and spent the mist: they come back here, and
	-- a fight keeps the icon grey.
	local was = self.refused
	self.refused = nil
	if mode == "off" then
		self:Tint(SILVER[1], SILVER[2], SILVER[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	if was then self:Mend() end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The slab holds; everything that moves stops and the lights go out, the ice
-- dulls, the icon greys and the words dim. The mist, the rune and the vein
-- keep their colour: the reason is the one coloured thing left.
function Frost:Combat(on)
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
	self.runeGlow:SetAlpha(on and GLOW.combat or GLOW.rest)
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Frost:HoldPulse(spent)
	StopAll(self.pulse)
	self.halo:SetAlpha(spent and HALO.held or HALO.rest)
	self.runeGlow:SetAlpha(spent and GLOW.held or GLOW.rest)
	self.core:SetAlpha(spent and CORE.held or CORE.rest)
end

-- The lights the flourishes share are one set of regions: one plays at a
-- time. The cracks are not a light: they stand until the slab is mended.
function Frost:StopLights()
	StopAll(self.tipAnims)
	StopAll(self.landing)
	self.meltAnim:Stop()
end

function Frost:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	local was = self.owed
	self.owed = true
	if not was then self:Idle() end
	-- A refusal cracked the slab: nothing creeps or breathes until the next
	-- PaintReason mends it.
	if self.refused then
		self:HoldPulse()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The frost spreads for a new favour, never a new face.
		if full and self.rimeOK then
			self:StopLights()
			StopAll(self.calm)
			self.grown, self.shedded = true, nil
			for _, t in ipairs(self.flakes) do t:SetAlpha(0) end
			PlayAll(self.arrive)
			-- Both halves at once, each from its own end.
			for _, h in ipairs(self.rimeSheets) do h:Play() end
			for _, h in ipairs(self.flakeSheets) do h:Play() end
		end
	end
	-- Grown for as long as somebody is owed, however it got there.
	if not self.grown then
		self:Grown()
		self.rimeFrame:SetAlpha(1)
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
		-- Calm: one fade up to the held light, the rime with it, and nothing
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
		self.runeGlow:SetAlpha(GLOW.rest)
		self.core:SetAlpha(CORE.rest)
		if self.grown and not self.rimeIn:IsPlaying() then self.rimeFrame:SetAlpha(1) end
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly. The rime
	-- and its snowflakes are what say "owed" after.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Frost.pulseGen or not Frost.active then return end
			Frost.pulseSpent = true
			if Frost.pulse[1]:IsPlaying() then
				Frost:HoldPulse(true)
				-- Settled: the rune says so, once.
				Frost:Greet()
			end
		end)
	end
end

function Frost:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	StopAll(self.tipAnims)
	self.halo:SetAlpha(HALO.rest)
	self.runeGlow:SetAlpha(self.combat and GLOW.combat or GLOW.rest)
	self.core:SetAlpha(CORE.rest)
	self:Ungrow()
	self.calmLit = nil
	self.owed = nil
	if self.active then self:Idle() end
end

function Frost:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal cracks it: fissures run across the slab, the rime and its
	-- snowflakes melt away, the icicles break off and fall, the ice goes
	-- dull, the mist is left spent and one ring snaps in onto the crystal.
	-- The text's shake is Prompt's.
	if kind == "failed" then
		self.refused = true
		self:StopLights()
		self.rimeIn:Stop()
		StopAll(self.seedIn)
		if not self.combat then
			if self.owed and self.rimeOK then
				-- Whole, however far it had crept, and then gone.
				self:Grown()
				self.rimeFrame:SetAlpha(1)
				self.meltAnim:Play()
			end
			for i, g in ipairs(self.crackIn) do
				g:Stop()
				if self.crackOn[i] then g:Play() end
			end
			-- Only the icicles that hang fall.
			for i, g in ipairs(self.aftermath) do
				g:Stop()
				if self.icicleUp[i] then g:Play() end
			end
		end
		self:Spend()
		if shown then self.fx:Refuse(1.00, 0.40, 0.34, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- The shards fly from the icon (from the slab's end with the icon off).
	PlayAll(self.shardAnims)
	self.hotAnim:Stop()
	self.hotAnim:Play()
	if shown then
		-- The Ice Block shuts over the icon and shatters.
		self.blockAnim:Stop()
		self.blockAnim:Play()
		self.crackleAnim:Stop()
		self.crackleAnim:Play()
		self.novaAnim:Stop()
		self.novaAnim:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- Every snowflake bursts into splinters and is gone.
	if self.grown and self.rimeOK and not self.shedded then
		-- Whole, however far they had got, and then burst.
		StopAll(self.seedIn)
		self.rimeIn:Stop()
		self:Grown()
		self.rimeFrame:SetAlpha(1)
		self.shedded = true
		PlayAll(self.shed)
		PlayAll(self.sparkAnims)
	end
end

function Frost:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Frost:Hover(on)
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
-- the eye never has to find the person again. The vein's core takes the
-- outcome's colour.
function Frost:PaintOutcome(kind, lead, sub, who, stamp)
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
	if self.grown and not self.meltAnim:IsPlaying() then self.rimeFrame:SetAlpha(1) end
	Colour(self.core, o[1], o[2], o[3])
	self.refused = kind == "failed"
	if self.refused then self:Spend() end
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

function Frost:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A sheet of the same ice under the slab (or over it), from the crystal to
-- where the slab ends; each row wears a small crystal in its reason's
-- colour.
function Frost:PaintQueue(rows, shown, above)
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
			-- The icicles hang again where the list hung.
			self:Hang()
			self:Idle()
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
	-- No icicle hangs into a list under the slab.
	self:Hang()
	self:Idle()

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

	local bead = self.sub + 2
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
