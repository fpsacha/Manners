-- Manners -- the Archmage look: a mage's focus, a violet crystal cut to a
-- point at each end, the spell set in a hexagon of six arcane charges.
--
-- A long amethyst crystal bound in a thin electrum wire, a bevel inside the
-- wire and a dark table the words stand on. At its left the spell icon, cut
-- to a hexagon, sits in a gem setting: two wires, six prongs, and between the
-- prongs six facets, one to each side of the hexagon. Those are the CHARGES.
-- They carry the reason's colour, and a vein of the same colour runs inside
-- the crystal under the words to the far point. Everything is built on one
-- angle, sixty degrees: the crystal's ends, the icon, the setting, the tags
-- for the count and the key, the list's beads. The list is a second, darker
-- crystal under (or over) the first.
--
-- Every region is a texture from Textures/Archmage
-- (tools/make_archmage_textures.py). The crystal and the wire are baked,
-- because they are decoration; everything that means something -- the
-- charges, the vein, the beads, the glyphs, the lights -- is white or grey art
-- coloured by SetVertexColor, so one file serves all six reasons, both
-- palettes, a custom marker colour and the outcomes. The interface this file
-- implements is described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-archmage.lua):
--   * a favour arriving CHARGES the setting: the six facets flash one after
--     another, clockwise from the top, then a light runs along the vein to
--     the far point, where a star turns a quarter and goes out;
--   * owed, the charges breathe in a wave that travels round the hexagon,
--     three times round, and then hold lit; the vein, a soft halo and the
--     charges' light inside the crystal breathe with them;
--   * the crystal GREETS: when somebody new comes up, when the cursor comes
--     onto it and when the owed wave settles, a sheen crosses the top bevel
--     and three small stars twinkle one after another, once;
--   * the crystal is ALIVE at rest (the author asked for it; the other looks
--     loop nothing with nobody owed, and hunt35-effects lets this one's
--     `idle` groups through by name): a light drifts along each ridge of the
--     table, each in its own time, two glints twinkle on the bevels, and an
--     ember of the reason's colour breathes in the stone by the setting.
--     None of it is additive, none of it is on the words, and Calm and a
--     fight have none of it, nor of the greeting;
--   * a landing DISCHARGES it: all six flash at once, lightning crackles
--     round the setting (four drawn frames shown in turn, twice), a light
--     runs along each long edge of the crystal, and the star at the point
--     answers; the shared rings spread from the setting, as hexagons;
--   * a refusal UNWINDS it: the facets flicker out anticlockwise in the
--     refusal's red and are left spent and grey, the icon greys, one ring
--     snaps in; a cast nobody confirmed does nothing;
--   * no additive light at rest: the flashes, the lightning, the surge, the
--     runners, the star and the rings are the only ADD regions, each lit
--     under 0.6 s and parked at nothing; the breath, the halo, the sparkle,
--     the sheen and the hover are BLEND;
--   * Calm keeps to fades: no chase, no loop, no lightning, no runner, no
--     sparkle;
--   * a fight dulls the crystal and the wire, dims the words and greys the
--     icon; the charges and the vein keep their colour: the reason is the one
--     coloured thing left;
--   * the icon is the slider's size and always a hexagon ("Round the icon
--     off" reads nothing here); the setting is held inside the crystal.
--
-- A frame-by-frame effect needs no OnUpdate and no animation type beyond
-- Alpha: each frame is a region of its own showing one cell of a sheet, and
-- each is lit for its turn by an Alpha that holds. The lightning is that.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Archmage\\Archmage_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Archmage = ns.Looks.Register("archmage", {
	name = L["Archmage -- a violet crystal, six arcane charges"],
	title = L["Archmage"],
	description = L["a violet crystal, six arcane charges"],
	order = 8,
	-- The crystal holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the crystal whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_archmage_textures.py (tests/scenarios/look-archmage.lua
-- compares them): the icon fills this much of the bezel's file, the crystal's
-- design height and its ends' width in texels, the setting's outer corner as
-- a fraction of the bezel file's half-width, how much larger than the bezel
-- the halo is drawn, the tag's caps as a fraction of its height, the mask's
-- fill, where the ring file's corner sits, where the bevel meets the table in
-- design texels from the edge, and the vein's height in units.
local ICON_FRAME = 0.68
local DESIGN_H = 128
local CAP_W = 64
local HEX_OUT = 62 / 64
local GLOW_SCALE = 1.1
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
local BEVEL_END = 13.5
local VEIN_H = 4
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.93
-- Sixty degrees: a hexagon's height over its width, and how far a cut runs
-- along the crystal for each unit of its height.
local S3 = 0.8660254
local CUT = 0.5 / 1.7320508
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the setting and the text; with the icon off, between the
-- cut and the text.
local TEXT_GAP, BARE_GAP = 5, 5
-- The most crystal the setting keeps at its left: on a crystal much taller
-- than its icon the setting stays by the point and the words keep their room.
local SETTING_IN = 8
-- The crystal's own luminance under the words, its darkest and its brightest
-- (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.05, 0.26
-- A chosen panel colour is mixed this far into the crystal.
local BODY_MIX = 0.25
-- The list's crystal is this much darker than the first.
local LIST_TONE = 0.72
-- The shadow: its 9-slice corner in units, and how far past the crystal its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local LILAC = { 0.96, 0.93, 1.00 }
local TAG_INK = { 0.95, 0.91, 1.00 }
local MIST = { 0.90, 0.87, 0.98 }
-- The contrast the reason line and the verdict are held to: 7, not the 4.5
-- of the tags, since the line is small and sits over the brightest crystal.
local SUB_CONTRAST = 7
-- A fight's wire and crystal.
local DULL = { 0.60, 0.60, 0.64 }
-- The charges and the vein with the marker off, and a charge a refusal spent.
local NEUTRAL = { 0.58, 0.52, 0.78 }
local SPENT = { 0.36, 0.35, 0.42 }
local HOVER = { 0.72, 0.62, 1.00 }
-- The lights: a flash is the reason's colour taken this far to white.
local FLASH_WHITE = 0.55
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the crystal dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.78
-- A charge at rest, lit, and held after its turns; the vein, and the soft
-- core in it over the same breath; the halo round the setting.
local CHARGE_REST, CHARGE_PEAK, CHARGE_HELD = 0.50, 1.00, 0.85
local VEIN_ALPHA = 0.90
local CORE_REST, CORE_PEAK, CORE_HELD = 0.15, 0.60, 0.35
local HALO_REST, HALO_PEAK, HALO_HELD = 0.03, 0.16, 0.08
-- The charges' light inside the crystal, over the same breath, and how far it
-- reaches from the setting, in units.
local SPILL_REST, SPILL_PEAK, SPILL_HELD = 0.14, 0.30, 0.20
local SPILL_REACH = 46
-- The greeting: each star's place (how far along the crystal between the
-- text's start and the far cut, and 1 the top bevel, 2 the far point, 3 the
-- bottom bevel), its size in units and the seconds it waits for its turn.
-- And the sheen: how long it takes to cross the top bevel.
local SPARKLES = { { 0.38, 1, 7, 0.10 }, { 0.72, 3, 7, 0.22 }, { 1, 2, 9, 0.34 } }
local SPARKLE_PEAK = 0.75
local SHEEN_CROSS, SHEEN_PEAK = 0.6, 0.45
local STARLIGHT = { 0.93, 0.88, 1.00 }
-- The crystal at rest. The lights that drift along the ridges: which ridge
-- (1 the upper, 3 the lower, where the vein is), the seconds one takes to
-- cross and the seconds it then stays dark. The glints: where (as SPARKLES),
-- their size and the seconds they stay dark. No two times share a measure, so
-- nothing falls in step. And the ember: its two ends and one breath's length.
local DRIFTS = { { 1, 4.2, 2.3 }, { 3, 5.0, 3.1 } }
local DRIFT_PEAK = 0.75
local GLINTS = { { 0.12, 1, 7, 4.3 }, { 0.55, 3, 7, 6.1 } }
local GLINT_PEAK = 0.85
local EMBER_LO, EMBER_HI, EMBER_TURN = 0, 0.20, 3.4
-- The wave round the hexagon: one turn's length, a charge's rise and fall in
-- it, and how many turns before it holds.
local TURN, RISE, FALL, TURNS = 2.0, 0.35, 0.65, 3
-- The lightning: seconds a frame, and how often the four are shown.
local ARC_FRAME, ARC_CYCLES = 0.045, 2
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

-- The six charges, clockwise from the top: the file each is drawn from and
-- how it is flipped (left, right, top, bottom).
local CHARGES = {
	{ "ChargeT", 0, 1, 0, 1 }, { "ChargeS", 0, 1, 0, 1 }, { "ChargeS", 0, 1, 1, 0 },
	{ "ChargeT", 0, 1, 1, 0 }, { "ChargeS", 1, 0, 1, 0 }, { "ChargeS", 1, 0, 0, 1 },
}
-- The lightning's four frames in their sheet.
local ARC_CELLS = { { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 } }

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, and the bevels round it.
function Archmage.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 16)
end

-- The charges are the mark round the icon, the vein the stripe.
function Archmage.AccentCarriers(p)
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

-- Relative luminance of a grey, for the crystal's own ink figures.
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

-- The crystal: its left end, its tiled middle and its right end, from the
-- three files at the design height.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "BodyL", "BodyM", "BodyR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- A crystal laid over a box: the ends are the design's proportion of its
-- height, so the cut stays at sixty degrees, the middle tiled along the rest.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN_H
	local cap = math.min(CAP_W * su, (x1 - x0) / 2)
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
	Alpha(g, rest or 0, peak, up, order, nil, "OUT")
	Alpha(g, peak, rest or 0, down, order + 1, nil, "IN")
	Park(g, region, rest or 0)
	return g
end

-- A breath: `lo` to `hi` and back in one turn of the wave, for as long as it
-- is left to.
local function Breathe(region, lo, hi)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	Alpha(g, lo, hi, TURN / 2, 1, nil, "IN_OUT")
	Park(g, region, lo)
	return g
end

-- One charge's part in the wave: a rise and a fall once a turn, `offset`
-- seconds into it, as a loop of straight pieces. The pieces are cut where the
-- shape bends and at the turn's end, so a charge whose rise straddles the
-- turn's end still loops without a step.
local function Wave(region, offset, lo, hi)
	local function at(t)
		local u = (t - offset) % TURN
		if u < RISE then return lo + (hi - lo) * u / RISE end
		if u < RISE + FALL then return hi - (hi - lo) * (u - RISE) / FALL end
		return lo
	end
	local keys = { 0, TURN, offset % TURN, (offset + RISE) % TURN, (offset + RISE + FALL) % TURN }
	table.sort(keys)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local order = 0
	for i = 1, #keys - 1 do
		local t0, t1 = keys[i], keys[i + 1]
		if t1 - t0 > 0.001 then
			order = order + 1
			-- Read a hair inside each end, so a piece that ends on the turn's
			-- end reads the end, not the start.
			Alpha(g, at(t0 + 0.0005), at(t1 - 0.0005), t1 - t0, order)
		end
	end
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

-- One frame of a drawn effect: dark until its turn, lit for `frame` seconds,
-- dark for the rest of the cycle, `cycles` times over.
local function Frame(region, index, count, frame, cycles, peak)
	local g = region:CreateAnimationGroup()
	local order = 0
	for _ = 1, cycles do
		if index > 1 then
			order = order + 1
			Alpha(g, 0, 0, (index - 1) * frame, order)
		end
		order = order + 1
		Alpha(g, peak, peak, frame, order)
		if index < count then
			order = order + 1
			Alpha(g, 0, 0, (count - index) * frame, order)
		end
	end
	Park(g, region, 0)
	return g
end

-- A light that runs: across by the offset Apply gives it, lit as it leaves
-- and gone as it arrives.
local function Runner(region, delay, duration, peak)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	local move = g:CreateAnimation("Translation")
	move:SetDuration(duration)
	move:SetOrder(order)
	if move.SetSmoothing then move:SetSmoothing("OUT") end
	g.move = move
	Alpha(g, peak, 0, duration, order, nil, "IN")
	Park(g, region, 0)
	return g
end

-- The star: up and out as it turns, a quarter going up and a quarter coming
-- down, each of which a star of four points ends as it began.
local function Twinkle(region, delay, peak, up, down)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay > 0 then
		Alpha(g, 0, 0, delay, 1)
		order = 2
	end
	Alpha(g, 0, peak, up, order, nil, "OUT")
	Alpha(g, peak, 0, down, order + 1, nil, "IN")
	local turn = g:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(-90) end
	if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	turn:SetDuration(up)
	turn:SetOrder(order)
	local settle = g:CreateAnimation("Rotation")
	if settle.SetDegrees then settle:SetDegrees(-90) end
	if settle.SetOrigin then settle:SetOrigin("CENTER", 0, 0) end
	settle:SetDuration(down)
	settle:SetOrder(order + 1)
	if settle.SetSmoothing then settle:SetSmoothing("OUT") end
	Park(g, region, 0)
	return g
end

-- A star of the greeting: dark for `wait`, then up and out as it turns a
-- quarter, once.
local function Sparkle(region, wait, peak)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, 0.12, 2, nil, "OUT")
	Alpha(g, peak, 0, 0.34, 3, nil, "IN")
	for order, seconds in pairs({ [2] = 0.12, [3] = 0.34 }) do
		local turn = g:CreateAnimation("Rotation")
		if turn.SetDegrees then turn:SetDegrees(-45) end
		if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
		turn:SetDuration(seconds)
		turn:SetOrder(order)
	end
	Park(g, region, 0)
	return g
end

-- The sheen: across the bevel by the offset Apply gives it, up as it leaves
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

-- A light that drifts: across the ridge by the offset Apply gives it, up as it
-- leaves, held, and out as it arrives, then dark for its wait, over and over.
local function Drift(region, cross, wait, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local move = g:CreateAnimation("Translation")
	move:SetDuration(cross)
	move:SetOrder(1)
	g.move = move
	Alpha(g, 0, peak, cross * 0.25, 1, nil, "OUT")
	Alpha(g, peak, peak, cross * 0.40, 1, cross * 0.25)
	Alpha(g, peak, 0, cross * 0.35, 1, cross * 0.65, "IN")
	Alpha(g, 0, 0, wait, 2)
	Park(g, region, 0)
	return g
end

-- A glint: dark for `wait`, then up and out as it turns a quarter, over and
-- over.
local function Glint(region, wait, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, 0.25, 2, nil, "OUT")
	Alpha(g, peak, 0, 0.55, 3, nil, "IN")
	for order, seconds in pairs({ [2] = 0.25, [3] = 0.55 }) do
		local turn = g:CreateAnimation("Rotation")
		if turn.SetDegrees then turn:SetDegrees(-45) end
		if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
		turn:SetDuration(seconds)
		turn:SetOrder(order)
	end
	Park(g, region, 0)
	return g
end

-- The ember: a slow breath, for as long as it is left to.
local function Ember(region, lo, hi, turn)
	local g = region:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	Alpha(g, lo, hi, turn / 2, 1, nil, "IN_OUT")
	Park(g, region, lo)
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

function Archmage:Build(kit)
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
	self.listBody = Body(art, "BACKGROUND", -7, keep)
	self.body = Body(art, "BACKGROUND", -6, keep)
	-- The charges' light inside the crystal, on the table from the setting
	-- towards the words.
	self.spill = tex(art, "BORDER", 2, "Spill")
	-- The vein, and the soft core that breathes in it.
	self.vein = tex(art, "BORDER", 3, "Vein")
	self.core = tex(art, "BORDER", 4, "Vein")
	-- The setting, under the icon (ARTWORK 0): nothing of it lies over the
	-- spell. The six charges lie in its bed; the halo is the breath's second
	-- tone (BLEND).
	self.bezel = tex(art, "ARTWORK", -3, "Bezel")
	self.charges = {}
	for i, c in ipairs(CHARGES) do
		local t = tex(art, "ARTWORK", -2, c[1])
		t:SetTexCoord(c[2], c[3], c[4], c[5])
		self.charges[i] = t
	end
	self.halo = tex(art, "ARTWORK", -1, "Halo")
	self.halo:SetAlpha(0)
	-- hunt35-effects reads the owed breath's second tone by these names.
	self.pulseRing, self.ringWarm = self.halo, self.halo

	-- The rings that spread from the setting when a buff lands and the one
	-- that snaps in when one is refused: frames over the art, under the text.
	-- No echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)

	-- The lights over the setting: each charge's flash, the halo's, and the
	-- lightning's four frames.
	self.lightFrame = frame(2)
	self.sparks = {}
	for i, c in ipairs(CHARGES) do
		local t = tex(self.lightFrame, "OVERLAY", 1, c[1], "ADD")
		t:SetTexCoord(c[2], c[3], c[4], c[5])
		t:SetAlpha(0)
		self.sparks[i] = t
	end
	self.haloHot = tex(self.lightFrame, "OVERLAY", 2, "Halo", "ADD")
	self.haloHot:SetAlpha(0)
	-- A landing's surge into the crystal: the spill once more, additive.
	self.spillHot = tex(self.lightFrame, "OVERLAY", 0, "Spill", "ADD")
	self.spillHot:SetAlpha(0)
	self.arcs = {}
	for i, c in ipairs(ARC_CELLS) do
		local t = tex(self.lightFrame, "OVERLAY", 3, "Arcs", "ADD")
		t:SetTexCoord(c[1], c[2], c[3], c[4])
		t:SetAlpha(0)
		self.arcs[i] = t
	end
	-- The lights that run along the crystal's two long edges, each on a frame
	-- of its own, and the star at the far point.
	self.runFrames, self.runners = {}, {}
	for i = 1, 2 do
		local f = frame(2)
		local t = tex(f, "OVERLAY", 1, "Mote", "ADD")
		t:SetAllPoints(f)
		t:SetAlpha(0)
		self.runFrames[i], self.runners[i] = f, t
	end
	self.starFrame = frame(2)
	self.star = tex(self.starFrame, "OVERLAY", 1, "Star", "ADD")
	self.star:SetAllPoints(self.starFrame)
	self.star:SetAlpha(0)
	-- The greeting: three stars and the sheen on the top bevel, none of them
	-- additive.
	self.idleFrame = frame(1)
	self.twinkles = {}
	for i = 1, #SPARKLES do
		local t = tex(self.idleFrame, "OVERLAY", 2, "Star")
		t:SetVertexColor(STARLIGHT[1], STARLIGHT[2], STARLIGHT[3], 1)
		t:SetAlpha(0)
		self.twinkles[i] = t
	end
	self.sheen = tex(self.idleFrame, "OVERLAY", 1, "Vein")
	self.sheen:SetVertexColor(STARLIGHT[1], STARLIGHT[2], STARLIGHT[3], 1)
	self.sheen:SetAlpha(0)
	-- The crystal at rest: the lights that drift along the ridges, the glints
	-- on the bevels and the ember in the stone, none of them additive.
	self.drifts, self.glints = {}, {}
	for i = 1, #DRIFTS do
		local t = tex(self.idleFrame, "OVERLAY", 1, "Mote")
		t:SetAlpha(0)
		self.drifts[i] = t
	end
	for i = 1, #GLINTS do
		local t = tex(self.idleFrame, "OVERLAY", 2, "Star")
		t:SetVertexColor(STARLIGHT[1], STARLIGHT[2], STARLIGHT[3], 1)
		t:SetAlpha(0)
		self.glints[i] = t
	end
	self.ember = tex(art, "BORDER", 2, "Spill")
	self.ember:SetAlpha(0)
	-- The cursor's light: the top bevel lit.
	self.hoverFrame = frame(1)
	self.hoverLight = keep(self.hoverFrame:CreateTexture(nil, "OVERLAY", nil, 1))
	self.hoverLight:SetTexture(WHITE)
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's beads, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The chips: small crystals at the right end; their text is on textLayer,
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

	-- The icon's hexagon; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything baked, for a fight's dulling: the setting, the tags, the
	-- list's crystal, the glyph.
	self.baked = { self.bezel, self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end
	self.bakedTone = {}
	for _, t in ipairs(self.listBody) do self.bakedTone[t] = LIST_TONE end

	self:BuildAnimations(anim)
end

function Archmage:BuildAnimations(anim)
	-- The owed wave: each charge rises and falls once a turn, a sixth of a
	-- turn after the one before it, so the light travels round the hexagon;
	-- the vein's core and the halo breathe once a turn with it. See Attention
	-- for how long.
	-- The two breaths first: hunt35-effects times the breath by the first.
	self.pulse = { anim(Breathe(self.core, CORE_REST, CORE_PEAK)), anim(Breathe(self.halo, HALO_REST, HALO_PEAK)),
		anim(Breathe(self.spill, SPILL_REST, SPILL_PEAK)) }
	for i, t in ipairs(self.charges) do
		self.pulse[i + 3] = anim(Wave(t, (i - 1) * TURN / 6, CHARGE_REST, CHARGE_PEAK))
	end
	-- "Once": one rise and fall of all six together, 0.55 s.
	self.once = {}
	for i, t in ipairs(self.charges) do
		self.once[i] = anim(Flash(t, CHARGE_PEAK, 0.25, 0.30, CHARGE_REST))
	end
	self.once[7] = anim(Flash(self.core, CORE_PEAK, 0.25, 0.30, CORE_REST))
	self.once[8] = anim(Flash(self.halo, HALO_PEAK, 0.25, 0.30, 0))
	self.once[9] = anim(Flash(self.spill, SPILL_PEAK, 0.25, 0.30, SPILL_REST))
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = {}
	for i, t in ipairs(self.charges) do
		self.calm[i] = anim(Fade(t, CHARGE_REST, CHARGE_HELD, 0.5))
	end
	self.calm[7] = anim(Fade(self.core, CORE_REST, CORE_HELD, 0.5))
	self.calm[8] = anim(Fade(self.halo, 0, HALO_HELD, 0.5))
	self.calm[9] = anim(Fade(self.spill, SPILL_REST, SPILL_HELD, 0.5))

	-- A favour arriving charges the setting: the six flash one after another,
	-- 0.04 s apart, each lit 0.25 s; a light leaves along the vein as the
	-- fourth lights (0.34 s) and the star at the far point answers as it
	-- arrives. The last light is out by 0.7 s, as every look's arrival is.
	self.arrive = {}
	for i, t in ipairs(self.sparks) do
		self.arrive[i] = anim(Flash(t, 0.85, 0.05, 0.20, 0, 0.04 * (i - 1)))
	end
	self.arriveRun = anim(Runner(self.runners[2], 0.16, 0.34, 0.9))
	self.arriveStar = anim(Twinkle(self.star, 0.42, 0.85, 0.06, 0.22))
	self.arrive[7], self.arrive[8] = self.arriveRun, self.arriveStar

	-- A landing discharges it: all six at once and the halo with them
	-- (0.40 s), the lightning's four frames in turn, twice (0.36 s), a light
	-- along each long edge (0.34 s) and the star (out by 0.68 s).
	self.landing = {}
	for i, t in ipairs(self.sparks) do
		self.landing[i] = anim(Flash(t, 0.9, 0.06, 0.34))
	end
	self.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.38))
	self.landing[7] = self.hotAnim
	-- The surge into the crystal, with them.
	self.surgeAnim = anim(Flash(self.spillHot, 0.5, 0.06, 0.40))
	self.landing[8] = self.surgeAnim
	self.arcAnims = {}
	for i, t in ipairs(self.arcs) do
		self.arcAnims[i] = anim(Frame(t, i, #self.arcs, ARC_FRAME, ARC_CYCLES, 0.9))
		self.landing[#self.landing + 1] = self.arcAnims[i]
	end
	self.landRuns = { anim(Runner(self.runners[1], 0.04, 0.34, 0.85)), anim(Runner(self.runners[2], 0.08, 0.34, 0.85)) }
	self.landStar = anim(Twinkle(self.star, 0.32, 0.9, 0.06, 0.30))
	self.landing[#self.landing + 1] = self.landRuns[1]
	self.landing[#self.landing + 1] = self.landRuns[2]
	self.landing[#self.landing + 1] = self.landStar

	-- A refusal unwinds it: the six flicker out the other way round, 0.04 s
	-- apart, each lit 0.15 s.
	self.refusal = {}
	for i, t in ipairs(self.sparks) do
		self.refusal[i] = anim(Flash(t, 0.8, 0.03, 0.12, 0, 0.04 * (#self.sparks - i)))
	end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The greeting: the sheen, then the three stars one after another, the
	-- last out by 0.8 s. See Greet for when.
	self.sheenAnim = anim(Sheen(self.sheen, SHEEN_CROSS, SHEEN_PEAK))
	self.greet = { self.sheenAnim }
	for i, s in ipairs(SPARKLES) do
		self.greet[i + 1] = anim(Sparkle(self.twinkles[i], s[4], SPARKLE_PEAK))
	end

	-- The crystal at rest: see Idle for when these run. hunt35-effects lets
	-- the groups of this list loop with nobody owed, and no others.
	self.idle = { anim(Ember(self.ember, EMBER_LO, EMBER_HI, EMBER_TURN)) }
	self.driftAnims = {}
	for i, d in ipairs(DRIFTS) do
		self.driftAnims[i] = anim(Drift(self.drifts[i], d[2], d[3], DRIFT_PEAK))
		self.idle[#self.idle + 1] = self.driftAnims[i]
	end
	for i, s in ipairs(GLINTS) do
		self.idle[#self.idle + 1] = anim(Glint(self.glints[i], s[4], GLINT_PEAK))
	end

	-- The cursor's light on the top bevel, both ways; from and to are set for
	-- each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Archmage:Apply(p, above)
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

	-- The crystal is the whole button. Its cut runs this far in at each end,
	-- and its bevel meets the table this far in from the top and the bottom.
	PlaceBody(self.body, art, 0, 0, W, H)
	local cut = H * CUT
	local ridge = BEVEL_END * H / DESIGN_H
	self.cut, self.ridge = cut, ridge
	-- The crystal's colour: as it is, or a chosen panel colour mixed in.
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

	-- The icon: the slider's size, held inside the crystal. The setting is
	-- the icon's file frame; its hexagon is HEX_OUT of that across and S3 of
	-- that again tall, and is held inside the crystal's height. When the cap
	-- bites, the hole shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, (H - 1) / (HEX_OUT * S3))
	local half = bz * HEX_OUT / 2
	-- The setting sits where the crystal's own cut would put a hexagon of the
	-- crystal's height: the three are one inside another. A setting too wide
	-- for that keeps three units of crystal at its left; one much smaller than
	-- the crystal is tall keeps SETTING_IN, by the point (cut alike, it fits
	-- there at any size), where the middle would take the words' room.
	local cx = half + math.max(3, math.min(H / (2 * S3) - half, SETTING_IN))
	local cy = H / 2
	local settingRight = cx + half
	local bare = math.ceil(cut) + BARE_GAP
	local textX = showIcon and (settingRight + TEXT_GAP) or bare
	self.iconSize, self.cx, self.bz, self.settingRight, self.textX = iconSize, cx, bz, settingRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	At(self.bezel, art, cx, cy, bz)
	for i = 1, 6 do
		At(self.charges[i], art, cx, cy, bz)
		At(self.sparks[i], art, cx, cy, bz)
	end
	for _, t in ipairs(self.arcs) do At(t, art, cx, cy, bz) end
	-- The halo, GLOW_SCALE larger, held inside the crystal with the light's
	-- own margin top and bottom (THE ROOM).
	local bloom = math.min(bz * GLOW_SCALE, (H - 2 * kit.EDGE_MARGIN) / (HEX_OUT * S3))
	At(self.halo, art, cx, cy, bloom)
	At(self.haloHot, art, cx, cy, bloom)
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	-- The icon is a hexagon whatever "Round the icon off" says.
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
		-- The rings spread from the setting's edge, as hexagons.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, half - iconSize / 2 + 1), iconSize)
		self.fx:Shape(true, ART .. "Ring", ART .. "Ring", maskFile)
		-- The room the rings have: to the text (less a margin), to the
		-- crystal's left point, and to its top and bottom.
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The sweep is cut to the hexagon; its leading edge turns about the
			-- middle, as round as a hexagon lets it be.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	-- The charges' light inside the crystal: on the table, from under the
	-- setting's right corner towards the words, never past the far cut.
	-- No taller than the setting, so on a tall crystal it is a plume beside
	-- the charges and not a band down the table.
	local spillX0 = settingRight - 9
	local spillX1 = math.min(spillX0 + SPILL_REACH, W - cut)
	local spillUp = math.min(H / 2 - ridge, bz * 0.5)
	self.spillOK = showIcon and spillX1 - spillX0 >= 16
	Box(self.spill, art, spillX0, cy - spillUp, spillX1, cy + spillUp)
	Box(self.spillHot, art, spillX0, cy - spillUp, spillX1, cy + spillUp)

	-- The vein: on the lower ridge, from the setting to where the ridge turns
	-- up into the far point.
	local veinX0 = showIcon and (settingRight - 3) or (cut + ridge * 0.6)
	local veinX1 = W - cut - ridge * 0.6
	self.veinOK = veinX1 - veinX0 >= 16
	Box(self.vein, art, veinX0, H - ridge - VEIN_H / 2, veinX1, H - ridge + VEIN_H / 2)
	Box(self.core, art, veinX0, H - ridge - VEIN_H / 2, veinX1, H - ridge + VEIN_H / 2)

	-- The runners: one along the top bevel, one along the vein, from the
	-- setting to the far cut; and whether there is room for them to run.
	local lane = ridge * 0.6
	local runW, runH = 22, 5
	local runX0 = (showIcon and settingRight or cut) + 2
	local runX1 = W - cut - runW / 2 - 1
	local run = runX1 - runX0
	self.runOK = run >= 24
	At(self.runFrames[1], art, runX0, lane, runW, runH)
	At(self.runFrames[2], art, runX0, H - ridge, runW, runH)
	for _, g in ipairs({ self.arriveRun, self.landRuns[1], self.landRuns[2] }) do
		g.move:SetOffset(math.max(0, run), 0)
	end
	-- The star, inside the far point: no wider than the point is tall there.
	local starSize = math.min(14, math.max(6, H / 3))
	At(self.starFrame, art, W - starSize / 2 - 1, H / 2, starSize)

	-- The greeting: a star on the top bevel, one on the bottom bevel and one
	-- inside the far point, and the sheen's run along the top bevel.
	local span = math.max(0, W - cut - textX)
	for i, s in ipairs(SPARKLES) do
		local x, y = textX + s[1] * span, H / 2
		if s[2] == 1 then y = lane elseif s[2] == 3 then y = H - lane end
		if s[2] == 2 then x = W - cut * 0.55 end
		At(self.twinkles[i], art, x, y, math.min(s[3], H / 4))
	end
	local sheenW = 26
	local sheenRun = runX1 + runW / 2 - sheenW / 2 - (runX0 + 6)
	self.greetOK = sheenRun >= 30
	At(self.sheen, art, runX0 + 6, lane, sheenW, 3)
	self.sheenAnim.move:SetOffset(math.max(0, sheenRun), 0)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	-- The crystal at rest: a light along each ridge, from the setting to the
	-- far cut; the glints on the bevels; the ember where the spill is.
	local driftW = 22
	local driftRun = runX1 + runW / 2 - driftW / 2 - runX0
	for i, d in ipairs(DRIFTS) do
		At(self.drifts[i], art, runX0, d[1] == 1 and ridge or (H - ridge), driftW, 4)
		self.driftAnims[i].move:SetOffset(math.max(0, driftRun), 0)
	end
	for i, s in ipairs(GLINTS) do
		At(self.glints[i], art, textX + s[1] * span, s[2] == 1 and lane or (H - lane), math.min(s[3], H / 4))
	end
	Box(self.ember, art, spillX0, cy - spillUp, spillX1, cy + spillUp)
	self.idleOK = driftRun >= 30

	-- The cursor's light over the top bevel, between the cuts.
	Box(self.hoverFrame, art, cut, 4 * H / DESIGN_H, W - cut, ridge)
	self.hoverLight:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], 1)

	local block = fs + 2 + sub
	self.block = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: small crystals whose point sits in the crystal's own.
	local chipH = sub + 7
	self.chipH = chipH
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -8, 0)
	self.keyBox:SetSize(chipH * 1.9, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list: its crystal is cut like the first, so its rows keep clear of
	-- the cuts of the deepest list the settings allow.
	local deepest = (p.queueRows or 3) * self.pitch + 6
	local listCut = math.ceil(deepest * CUT)
	self.rowX = math.max(showIcon and textX or bare, listCut + 16)
	local rowWidth = math.max(20, W - self.rowX - listCut - 4)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	self.bezel:SetShown(showIcon)
	self.halo:SetShown(showIcon)
	self.lightFrame:SetShown(showIcon)
	for _, t in ipairs(self.charges) do t:SetShown(showIcon) end
	self.fx:SetShown(showIcon)
	self.vein:SetShown(self.veinOK)
	self.core:SetShown(self.veinOK)
	self.spill:SetShown(self.spillOK)
	self.spillHot:SetShown(self.spillOK)
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
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent, self.calmLit = nil, nil
	self:Dull(false)
	if held then self:Combat(true) end
	self:Idle()

	-- The count's room: a two-digit tag and its inset. Chip widens it for a
	-- longer count.
	self.roomBase = math.ceil(chipH * 1.9) + 15
	return textX, self.roomBase
end

-- Every light where it rests: the charges dim, the core low, the rest dark.
function Archmage:Rest()
	for _, t in ipairs(self.charges) do t:SetAlpha(CHARGE_REST) end
	for _, t in ipairs(self.sparks) do t:SetAlpha(0) end
	for _, t in ipairs(self.arcs) do t:SetAlpha(0) end
	for _, t in ipairs(self.runners) do t:SetAlpha(0) end
	for _, t in ipairs(self.twinkles) do t:SetAlpha(0) end
	for _, t in ipairs(self.drifts) do t:SetAlpha(0) end
	for _, t in ipairs(self.glints) do t:SetAlpha(0) end
	self.ember:SetAlpha(0)
	self.core:SetAlpha(CORE_REST)
	self.spill:SetAlpha(SPILL_REST)
	self.spillHot:SetAlpha(0)
	self.sheen:SetAlpha(0)
	self.halo:SetAlpha(0)
	self.haloHot:SetAlpha(0)
	self.star:SetAlpha(0)
	self.hoverLight:SetAlpha(0)
end

-- The crystal at rest: its lights run on Full effects out of a fight, on a
-- crystal long enough to carry them, and are stopped otherwise (stopped, not
-- paused: each parks dark).
function Archmage:Idle()
	local on = self.active and self.idleOK and not self.combat and self.kit.FullEffects()
	for i, g in ipairs(self.idle) do
		-- The ember is the setting's: none without the icon.
		local run = on and (i > 1 or self.spillOK)
		if run then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome, and only on a crystal long enough to carry it. `sheenOnly` for
-- the cursor, which has its own light.
function Archmage:Greet(sheenOnly)
	if not (self.active and self.greetOK) or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	if sheenOnly then
		self.sheenAnim:Stop()
		self.sheenAnim:Play()
	else
		for _, g in ipairs(self.greet) do
			g:Stop()
			g:Play()
		end
	end
end

-- After every paint of a person, on the scan's own tick: somebody new on the
-- panel is greeted, once. A favour arriving has its own lights, so the
-- greeting is for a new face only.
function Archmage:Painted(entry)
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the crystal, and under the list's when it is out.
function Archmage:PlaceShadow(list)
	local W, H = self.W, self.H
	local x0, y0, x1, y1 = -SHADOW_OUT + 2, -SHADOW_OUT + 2, W + SHADOW_OUT + 1, H + SHADOW_OUT + 3
	if list then
		y0 = math.min(y0, list[2] - SHADOW_OUT + 2)
		y1 = math.max(y1, list[4] + SHADOW_OUT + 3)
	end
	PlacePieces(self.shadow, self.kit.art, x0, y0, x1, y1, SHADOW_C)
end

function Archmage:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the crystal, whatever the panel colour: the legibility the
	-- shared code works out is held against the table's own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(LILAC[1], LILAC[2], LILAC[3], 1)
	end
	kit.name:SetShadowColor(0.04, 0, 0.10, 0.9)
	kit.name:SetShadowOffset(1, -1)
	-- The reason line is small and the crystal behind it bright with motes:
	-- a dark drop under it, as under the name (it read faint without one).
	kit.sub:SetShadowColor(0.04, 0, 0.10, 0.95)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are crystal whatever the panel, so their text is lilac as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.88, 0.86, 0.94, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffa39bb4"
end

function Archmage:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
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
	self.pulseSpent, self.calmLit = nil, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Archmage:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The far point takes the corner off the lines' room.
	local inset = math.max(right, 12)
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
function Archmage:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Archmage:Fitted(fs)
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
		fs:SetPoint("RIGHT", -(self.inset or 12), self.subY)
	end
	self.glyph:SetShown((glyph and fs:IsShown()) and true or false)
end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Archmage:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, 12) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil: only
-- where a press casts something (the button armed, a fight's frozen macro
-- too), never over a held panel with nothing armed, nor over an outcome.
function Archmage:KeyLabel()
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
function Archmage:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Archmage:Chip(on)
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
			local w = math.max(self.chipH * 1.9, (kit.TextWidth(self.keyText) or self.sub) + 14)
			self.keyW, self.keyRoom = w, math.ceil(w + 15)
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
			self.countW = math.max(self.chipH * 1.9, (kit.TextWidth(count) or self.sub) + 14)
		end
		kit.fit.chipRoom = math.max(self.roomBase or 0, math.ceil(self.countW) + 15)
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
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -8, 0)
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

-- A charge a refusal spent: grey until the next PaintReason.
function Archmage:Spend()
	for _, t in ipairs(self.charges) do t:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1) end
end

-- The charges and the vein in the reason's colour (each only where the
-- marker says so, else a neutral lilac), their lights the same colour taken
-- towards white, and the reason line warmed towards it.
function Archmage:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	if self.refused then
		self:Spend()
	else
		for _, t in ipairs(self.charges) do t:SetVertexColor(cr, cg, cb, 1) end
	end
	local fr, fg, fb = kit.Tint(cr, cg, cb, FLASH_WHITE)
	for _, t in ipairs(self.sparks) do t:SetVertexColor(fr, fg, fb, 1) end
	for _, t in ipairs(self.arcs) do t:SetVertexColor(fr, fg, fb, 1) end
	self.halo:SetVertexColor(cr, cg, cb, 1)
	self.haloHot:SetVertexColor(fr, fg, fb, 1)
	self.spill:SetVertexColor(cr, cg, cb, 1)
	self.ember:SetVertexColor(cr, cg, cb, 1)
	self.spillHot:SetVertexColor(fr, fg, fb, 1)
	self.vein:SetVertexColor(vr, vg, vb, VEIN_ALPHA)
	local wr, wg, wb = kit.Tint(vr, vg, vb, 0.45)
	self.core:SetVertexColor(wr, wg, wb, 1)
	local lr, lg, lb = kit.Tint(vr, vg, vb, FLASH_WHITE)
	for _, t in ipairs(self.runners) do t:SetVertexColor(lr, lg, lb, 1) end
	for _, t in ipairs(self.drifts) do t:SetVertexColor(lr, lg, lb, 1) end
	self.star:SetVertexColor(lr, lg, lb, 1)
	-- The reason line: a lilac mist taken most of the way to the reason, held
	-- to a strong contrast on the crystal (the crystal in the game is brighter
	-- than its table says, with motes running behind the words).
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { cr, cg, cb }
end

function Archmage:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal spent the charges and greyed the icon: they take their colour
	-- back here, and a fight keeps the icon grey.
	self.refused = nil
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The crystal and the wire dulled for a fight, or back to themselves.
function Archmage:Dull(on)
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(on)
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

-- The crystal holds; it and the wire dull, the icon greys, the words dim and
-- the lights go out. The charges and the vein keep their colour: the reason
-- is the one coloured thing left.
function Archmage:Combat(on)
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
		for _, g in ipairs(self.greet) do g:Stop() end
	end
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The wave, let go: held lit once it has been round its fill (`spent`),
-- else at rest.
function Archmage:HoldPulse(spent)
	StopAll(self.pulse)
	for _, t in ipairs(self.charges) do t:SetAlpha(spent and CHARGE_HELD or CHARGE_REST) end
	self.core:SetAlpha(spent and CORE_HELD or CORE_REST)
	self.halo:SetAlpha(spent and HALO_HELD or 0)
	self.spill:SetAlpha(spent and SPILL_HELD or SPILL_REST)
end

-- The lights the three flourishes share are one set of regions: one plays at
-- a time.
function Archmage:StopLights()
	StopAll(self.arrive)
	StopAll(self.landing)
	StopAll(self.refusal)
end

function Archmage:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The setting charges for a new favour, never for a new face.
		if full and self.kit.icon:IsShown() then
			self:StopLights()
			for i = 1, 6 do self.arrive[i]:Play() end
			if self.runOK and self.veinOK then
				self.arriveRun:Play()
				self.arriveStar:Play()
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
		-- Calm: one fade up to the held light, and nothing loops.
		if not self.calmLit then
			self.calmLit = true
			StopAll(self.pulse)
			PlayAll(self.calm)
		end
		return
	end
	if self.pulseSpent then
		self:HoldPulse(true)
		return
	end
	-- A repaint leaves a running wave alone; a new favour on top keeps it
	-- going but takes its own three turns.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		StopAll(self.calm)
		for _, t in ipairs(self.charges) do t:SetAlpha(CHARGE_REST) end
		self.core:SetAlpha(CORE_REST)
		self.halo:SetAlpha(HALO_REST)
		self.spill:SetAlpha(SPILL_REST)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few turns and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(TURNS * TURN, function()
			if gen ~= Archmage.pulseGen or not Archmage.active then return end
			Archmage.pulseSpent = true
			if Archmage.pulse[1]:IsPlaying() then
				Archmage:HoldPulse(true)
				-- Settled: the crystal says so, once.
				Archmage:Greet()
			end
		end)
	end
end

function Archmage:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	for _, t in ipairs(self.charges) do t:SetAlpha(CHARGE_REST) end
	self.core:SetAlpha(CORE_REST)
	self.halo:SetAlpha(0)
	self.spill:SetAlpha(SPILL_REST)
	self.calmLit = nil
end

function Archmage:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal unwinds: the charges flicker out the other way round in the
	-- refusal's red and are left spent, and one ring snaps in onto the
	-- setting. The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		self.refused = true
		self:Spend()
		if shown then
			self:StopLights()
			for _, t in ipairs(self.sparks) do t:SetVertexColor(o[1], o[2], o[3], 1) end
			PlayAll(self.refusal)
			self.fx:Refuse(1.00, 0.40, 0.34, 0.85)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	if shown then
		for i = 1, 6 do self.landing[i]:Play() end
		self.hotAnim:Play()
		if self.spillOK then self.surgeAnim:Play() end
		PlayAll(self.arcAnims)
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- The lights along the edges, only where the crystal is long enough.
	if self.runOK then
		PlayAll(self.landRuns)
		self.landStar:Play()
	end
end

function Archmage:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Archmage:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnims[1], self.hoverLight
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 0.22 or 0
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	if g.fade.SetSmoothing then g.fade:SetSmoothing(on and "OUT" or "IN") end
	g:Play()
	if on then self:Greet(true) end
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so
-- the eye never has to find the person again. The vein's core takes the
-- outcome's colour.
function Archmage:PaintOutcome(kind, lead, sub, who, stamp)
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
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], SUB_CONTRAST)
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

function Archmage:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A second, darker crystal under the first (or over it), cut like it; each
-- row wears a small gem in its reason's colour.
function Archmage:PaintQueue(rows, shown, above)
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
	local depth = shown * pitch + 6
	local W, H = self.W, self.H
	local y0, y1
	if above then
		y1 = 0
		y0 = -depth
	else
		y0 = H
		y1 = H + depth
	end
	PlaceBody(self.listBody, art, 0, y0, W, y1)
	Each(self.listBody, "Show")
	self:PlaceShadow({ 0, y0, W, y1 })

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
