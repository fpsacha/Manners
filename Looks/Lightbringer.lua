-- Manners -- the Lightbringer look: a paladin's, the Silver Hand's colours as
-- Lordaeron wore them, the spell set in a sun of the Light.
--
-- A plate of polished silver with a gold fillet inside its rim and a field of
-- royal-blue enamel the words stand on. At its left the spell icon, round, in
-- a gold bezel; behind the bezel a sun of sixteen gold rays, taller than the
-- plate, so the sun stands proud of it above and below. Between the icon and
-- the gold lies the NIMBUS, a ring that carries the reason's colour; a gem in
-- a gold boss at the plate's far end and a fine inlay along its lower fillet
-- carry it too. The list is a second, darker plate under (or over) the first.
--
-- Every region is a texture from Textures/Lightbringer
-- (tools/make_lightbringer_textures.py). The silver, the gold and the enamel
-- are baked, because they are decoration; everything that means something --
-- the nimbus, the gem, the inlay, the beads, the glyphs, the lights -- is
-- white or grey art coloured by SetVertexColor, so one file serves all six
-- reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-lightbringer.lua):
--   * a favour arriving is ANSWERED from above: a pillar of light comes down
--     on the sun and its rays flash;
--   * owed, the sun breathes: the rays warm and cool, the nimbus and a soft
--     halo with them, three breaths, and then it holds lit;
--   * a landing is a BLESSING: the rays burst outward, two wings of light
--     spread from the sun, motes rise from the plate's upper rim, and the
--     shared rings spread from the bezel;
--   * a refusal GUTTERS it: the rays blink twice in the refusal's red and go
--     grey, the nimbus is left spent, the icon greys, one ring snaps in; a
--     cast nobody confirmed does nothing;
--   * at rest, on Full effects, the sun TURNS, an eighth of a turn at a time
--     (which sixteen rays end as they began), a glint crosses the upper
--     fillet now and then and the gem twinkles; somebody new on the panel is
--     greeted with the glint and the twinkle at once. hunt35-effects lets the
--     groups of `idle` loop with nobody owed, by name; the author asked for a
--     look that is alive at rest;
--   * no additive light at rest: the pillar, the wings, the bursts, the motes
--     and the rings are the only ADD regions, each lit under 0.6 s and parked
--     at nothing; the breath, the halo, the glint and the hover are BLEND;
--   * the pillar and the wings reach past the plate, above it: the Light
--     comes from above. With the list hung over the panel the pillar starts
--     at the panel's own top and the wings are not drawn;
--   * Calm keeps to fades: no turning, no pillar, no wings, no motes;
--   * a fight dulls the silver, the gold and the enamel, dims the words and
--     greys the icon; the nimbus, the gem and the inlay keep their colour;
--   * the icon is the slider's size and always round ("Round the icon off"
--     reads nothing here).

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Lightbringer\\Lightbringer_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Lightbringer = ns.Looks.Register("lightbringer", {
	name = L["Lightbringer -- silver and blue enamel, a sun of the Light"],
	title = L["Lightbringer"],
	description = L["silver and blue enamel, a sun of the Light"],
	order = 9,
	-- The plate holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the enamel whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_lightbringer_textures.py
-- (tests/scenarios/look-lightbringer.lua compares them): the icon fills this
-- much of the bezel's file, the plate's design height and its ends' width in
-- texels, how much larger than the bezel the rays and the halo are drawn, a long
-- ray's tip as a fraction of the rays file's half-width, the
-- tag's caps as a fraction of its height, the mask's fill, where the ring
-- file's line sits, and the gem's socket in design texels from the plate's
-- right edge.
local ICON_FRAME = 0.75
local DESIGN_H = 128
local CAP_W = 64
local RAY_SCALE = 1.5
local RAY_TIP = 62 / 64
local GLOW_SCALE = 1.1
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
local GEM_AT = 30
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- The gem's own width and its boss's, in design texels; where the fillet and
-- the inlay beside it lie, in design texels from the plate's edge.
local GEM_W, BOSS_W = 19.2, 34
-- The gem and its boss are drawn for a plate up to this tall; on a taller
-- one they keep that size.
local GEM_PLATE = 44
local FILLET_AT, INLAY_AT = 9.2, 14
local INLAY_H = 4
-- The plate is this much of the button's height in from its top and its
-- bottom, so the sun stands proud of it.
local PLATE_IN = 0.09
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the bezel and the text; with the icon off, between the
-- plate's edge and the text.
local TEXT_GAP, BARE_GAP = 6, 12
-- The enamel's own luminance under the words, its darkest and its brightest
-- (as greys), for Legible.
local TABLE_LO, TABLE_HI = 0.07, 0.22
-- A chosen panel colour is mixed this far into the plate.
local BODY_MIX = 0.25
-- The list's plate is this much darker than the first.
local LIST_TONE = 0.75
-- The shadow: its 9-slice corner in units, and how far past the plate its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local CREAM = { 1.00, 0.97, 0.88 }
local TAG_INK = { 1.00, 0.96, 0.86 }
local MIST = { 0.86, 0.84, 0.78 }
-- A fight's silver and gold.
local DULL = { 0.62, 0.62, 0.64 }
-- The nimbus, the gem and the inlay with the marker off, and a nimbus a
-- refusal spent.
local NEUTRAL = { 0.84, 0.76, 0.54 }
local SPENT = { 0.40, 0.40, 0.44 }
local HOVER = { 1.00, 0.94, 0.72 }
-- The Light's own colour: the pillar, the wings, the motes, the glint.
local SUNLIGHT = { 1.00, 0.93, 0.70 }
-- A flash is the reason's colour taken this far to white; the rays' warm
-- second tone is the Light taken this far to the reason.
local FLASH_WHITE, WARM_REASON = 0.5, 0.35
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the plate dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.78
-- The nimbus at rest, lit and held after its breaths; the rays' warm second
-- tone, the halo and the inlay's soft core over the same breath.
local NIMBUS_REST, NIMBUS_PEAK, NIMBUS_HELD = 0.72, 1.00, 0.92
local WARM_REST, WARM_PEAK, WARM_HELD = 0, 0.45, 0.22
local HALO_REST, HALO_PEAK, HALO_HELD = 0.03, 0.18, 0.09
local INLAY_ALPHA = 0.90
local CORE_REST, CORE_PEAK, CORE_HELD = 0.15, 0.60, 0.35
local BREATHS, BREATH = 3, 1.25
-- The sun at rest: how far it turns before it is the same picture again, in
-- degrees, and the seconds that takes; the glint's crossing and its wait;
-- the gem's wait between twinkles. No two times share a measure.
local RAY_TURN, RAY_SECONDS = 45, 16
local GLINT_CROSS, GLINT_WAIT, GLINT_PEAK = 1.6, 6.3, 0.55
local GEM_WAIT, GEM_PEAK = 7.7, 0.85
-- The wings: their size as a part of the button's height, and at most; how
-- far in from the bezel's middle their roots are, as a part of the bezel.
local WING_H, WING_MAX, WING_ROOT = 1.35, 64, 0.18
-- The pillar: how far above the button it starts, as a part of its height,
-- and its width as a part of the bezel.
local PILLAR_UP, PILLAR_W = 1.2, 0.8
-- The motes that rise when a buff lands: how many, and how far.
local MOTES, MOTE_RISE = 4, 10
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the plate's rim and fillet
-- round it, and the plate's own inset.
function Lightbringer.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 18)
end

-- The nimbus is the mark round the icon; the gem and the inlay are the stripe.
function Lightbringer.AccentCarriers(p)
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

-- A plate: its left end, its tiled middle and its right end, from the three
-- files at the design height.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "PlateL", "PlateM", "PlateR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "REPEAT") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- A plate laid over a box: the ends are the design's proportion of its
-- height, the middle tiled along the rest.
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

-- The gem's twinkle in the greeting: dark for `wait`, then up and out as it
-- turns a quarter, once.
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

-- The gem's twinkle at rest: dark for `wait`, then up and out as it turns a
-- quarter, over and over.
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

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

local function StopAll(list)
	for _, g in ipairs(list) do g:Stop() end
end

-- A turn of `degrees` in `seconds`, over and over: for art that is the same
-- picture again after it.
local function Turn(region, degrees, seconds)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local turn = g:CreateAnimation("Rotation")
	if turn.SetDegrees then turn:SetDegrees(-degrees) end
	if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	turn:SetDuration(seconds)
	turn:SetOrder(1)
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

-- A wing: up as it spreads from its root, then out.
local function Spread(region, origin)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0.9, 0.10, 1, nil, "OUT")
	Alpha(g, 0.9, 0, 0.45, 2, nil, "IN")
	local grow = g:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.35, 0.6) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin(origin, 0, 0) end
	grow:SetDuration(0.10)
	grow:SetOrder(1)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	Park(g, region, 0)
	return g
end

-- The pillar: down from above as it lights, then out.
local function Descend(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0.85, 0.10, 1, nil, "OUT")
	Alpha(g, 0.85, 0, 0.48, 2, nil, "IN")
	local grow = g:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(1, 0.15) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("TOP", 0, 0) end
	grow:SetDuration(0.10)
	grow:SetOrder(1)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	Park(g, region, 0)
	return g
end

-- The rays' burst: up as they swell, then out.
local function Burst(region, peak)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, peak, 0.06, 1, nil, "OUT")
	Alpha(g, peak, 0, 0.40, 2, nil, "IN")
	local swell = g:CreateAnimation("Scale")
	if swell.SetScaleFrom then swell:SetScaleFrom(1, 1) end
	if swell.SetScaleTo then swell:SetScaleTo(1.06, 1.06) end
	if swell.SetOrigin then swell:SetOrigin("CENTER", 0, 0) end
	swell:SetDuration(0.40)
	swell:SetOrder(2)
	if swell.SetSmoothing then swell:SetSmoothing("OUT") end
	Park(g, region, 0)
	return g
end

-- Two blinks, the second weaker: a light that gutters.
local function Gutter(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0.75, 0.04, 1, nil, "OUT")
	Alpha(g, 0.75, 0, 0.09, 2, nil, "IN")
	Alpha(g, 0, 0.5, 0.04, 3, nil, "OUT")
	Alpha(g, 0.5, 0, 0.16, 4, nil, "IN")
	Park(g, region, 0)
	return g
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Lightbringer:Build(kit)
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
	-- The list's plate has no gem: its right end is the left end's mirror.
	self.listBody[3]:SetTexture(ART .. "PlateL")
	self.listBody[3]:SetTexCoord(1, 0, 0, 1)
	self.body = Body(art, "BACKGROUND", -6, keep)
	-- The inlay along the lower fillet, and the soft core that breathes in it.
	self.inlay = tex(art, "BORDER", 3, "Inlay")
	self.core = tex(art, "BORDER", 4, "Inlay")
	-- The gem in its boss at the far end.
	self.gem = tex(art, "BORDER", 5, "Gem")
	-- The sun, under the icon (ARTWORK 0): the rays, their warm second tone
	-- (BLEND), the bezel over them, the nimbus in its bed, a soft halo.
	self.rays = tex(art, "ARTWORK", -5, "Rays")
	self.raysWarm = tex(art, "ARTWORK", -4, "RaysLight")
	self.raysWarm:SetAlpha(0)
	self.sun = tex(art, "ARTWORK", -3, "Sun")
	self.nimbus = tex(art, "ARTWORK", -2, "Nimbus")
	self.halo = tex(art, "ARTWORK", -1, "Halo")
	self.halo:SetAlpha(0)
	-- hunt35-effects reads the owed breath's second tone by these names.
	self.pulseRing, self.ringWarm = self.raysWarm, self.raysWarm

	-- The rings that spread from the bezel when a buff lands and the one that
	-- snaps in when one is refused: frames over the art, under the text. No
	-- echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)

	-- The lights: the rays' flash, the halo's, the pillar, the two wings (the
	-- second the first's mirror) and the motes.
	self.lightFrame = frame(2)
	self.raysHot = tex(self.lightFrame, "OVERLAY", 1, "RaysLight", "ADD")
	self.raysHot:SetAlpha(0)
	self.haloHot = tex(self.lightFrame, "OVERLAY", 2, "Halo", "ADD")
	self.haloHot:SetAlpha(0)
	self.pillar = tex(self.lightFrame, "OVERLAY", 3, "Pillar", "ADD")
	self.pillar:SetAlpha(0)
	self.wings = {}
	for i = 1, 2 do
		local t = tex(self.lightFrame, "OVERLAY", 4, "Wing", "ADD")
		if i == 2 then t:SetTexCoord(1, 0, 0, 1) end
		t:SetAlpha(0)
		self.wings[i] = t
	end
	-- The lights that leave the room on purpose (the pillar and the wings
	-- come from above; the rays are taller than the panel as they are drawn):
	-- hunt37-effects holds every other light inside the panel and off the
	-- words, and lets these through by name.
	self.skyward = { self.pillar, self.wings[1], self.wings[2], self.raysHot }
	self.motes = {}
	for i = 1, MOTES do
		local t = tex(self.lightFrame, "OVERLAY", 5, "Star", "ADD")
		t:SetAlpha(0)
		self.motes[i] = t
	end
	-- The sun at rest and the greeting, none of it additive: a glint on the
	-- upper fillet and the gem's twinkle, each once for the greeting and once
	-- for the loop (two groups on one region would fight over its alpha).
	self.idleFrame = frame(1)
	self.glint = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	self.glintOnce = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	self.gemStar = tex(self.idleFrame, "OVERLAY", 2, "Star")
	self.gemStarOnce = tex(self.idleFrame, "OVERLAY", 2, "Star")
	for _, t in ipairs({ self.glint, self.glintOnce, self.gemStar, self.gemStarOnce }) do
		t:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
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

	-- Everything baked, for a fight's dulling: the sun and its rays, the
	-- tags, the list's plate, the glyph.
	self.baked = { self.sun, self.rays, self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end
	self.bakedTone = {}
	for _, t in ipairs(self.listBody) do self.bakedTone[t] = LIST_TONE end

	self:BuildAnimations(anim)
end

function Lightbringer:BuildAnimations(anim)
	-- The owed breath: the rays warm and cool, and the nimbus, the halo and
	-- the inlay's core with them; see Attention for how long. The rays first:
	-- hunt35-effects times the breath by the first.
	self.pulse = {
		anim(Breathe(self.raysWarm, WARM_REST, WARM_PEAK)), anim(Breathe(self.nimbus, NIMBUS_REST, NIMBUS_PEAK)),
		anim(Breathe(self.halo, HALO_REST, HALO_PEAK)), anim(Breathe(self.core, CORE_REST, CORE_PEAK)),
	}
	-- "Once": one rise and fall, 0.55 s.
	self.once = {
		anim(Flash(self.raysWarm, WARM_PEAK, 0.25, 0.30, 0)), anim(Flash(self.nimbus, NIMBUS_PEAK, 0.25, 0.30, NIMBUS_REST)),
		anim(Flash(self.halo, HALO_PEAK, 0.25, 0.30, 0)), anim(Flash(self.core, CORE_PEAK, 0.25, 0.30, CORE_REST)),
	}
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = {
		anim(Fade(self.raysWarm, 0, WARM_HELD, 0.5)), anim(Fade(self.nimbus, NIMBUS_REST, NIMBUS_HELD, 0.5)),
		anim(Fade(self.halo, 0, HALO_HELD, 0.5)), anim(Fade(self.core, CORE_REST, CORE_HELD, 0.5)),
	}

	-- A favour arriving: the pillar comes down (0.58 s) and the rays flash as
	-- it lands (out by 0.58 s).
	self.pillarAnim = anim(Descend(self.pillar))
	self.arriveFlash = anim(Flash(self.raysHot, 0.7, 0.08, 0.40, 0, 0.10))
	self.arrive = { self.pillarAnim, self.arriveFlash }

	-- A landing: the rays burst (0.46 s), the halo with them, the wings
	-- spread (0.55 s) and the motes rise one after another, the last out by
	-- 0.65 s.
	self.burstRays = anim(Burst(self.raysHot, 0.9))
	self.hotAnim = anim(Flash(self.haloHot, 0.6, 0.07, 0.38))
	self.wingAnims = { anim(Spread(self.wings[1], "BOTTOMLEFT")), anim(Spread(self.wings[2], "BOTTOMRIGHT")) }
	self.moteAnims = {}
	for i, t in ipairs(self.motes) do
		self.moteAnims[i] = anim(Runner(t, 0.05 * i, 0.40, 0.85))
	end
	self.landing = { self.burstRays, self.hotAnim, self.wingAnims[1], self.wingAnims[2] }
	for _, g in ipairs(self.moteAnims) do self.landing[#self.landing + 1] = g end

	-- A refusal: the rays blink twice in red and are gone, 0.33 s.
	self.gutterAnim = anim(Gutter(self.raysHot))
	self.refusal = { self.gutterAnim }
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The sun at rest: its three layers turn as one, the glint crosses and
	-- the gem twinkles. hunt35-effects lets the groups of this list loop
	-- with nobody owed, and no others. See Idle for when they run.
	self.turns = {
		anim(Turn(self.rays, RAY_TURN, RAY_SECONDS)), anim(Turn(self.raysWarm, RAY_TURN, RAY_SECONDS)),
		anim(Turn(self.raysHot, RAY_TURN, RAY_SECONDS)),
	}
	self.glintLoop = anim(GlintLoop(self.glint, GLINT_CROSS, GLINT_WAIT, GLINT_PEAK))
	self.gemLoop = anim(Glint(self.gemStar, GEM_WAIT, GEM_PEAK))
	self.idle = { self.turns[1], self.turns[2], self.turns[3], self.glintLoop, self.gemLoop }
	-- The greeting: the glint and the gem's twinkle, once, out by 0.8 s.
	self.sheenAnim = anim(Sheen(self.glintOnce, 0.7, GLINT_PEAK))
	self.greet = { self.sheenAnim, anim(Sparkle(self.gemStarOnce, 0.30, GEM_PEAK)) }

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

function Lightbringer:Apply(p, above)
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

	-- The icon: the slider's size, held inside the button. The bezel is the
	-- icon's file frame, held inside the button's height; the rays are drawn
	-- RAY_SCALE larger, taller than the plate and, at the default sizes, than
	-- the button: the sun stands proud of both. When the cap bites, the hole
	-- shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local raysSize = bz * RAY_SCALE
	-- The sun's left ray touches the button's left edge.
	local cx, cy = raysSize / 2, H / 2
	-- The plate: inset from the button's top and bottom, from under the sun
	-- to the right edge; with the icon off, the whole width.
	local plateIn = math.max(2, math.floor(H * PLATE_IN + 0.5))
	local ph = H - 2 * plateIn
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph = plateIn, plateX, ph
	PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	-- The plate's colour: as it is, or a chosen panel colour mixed in.
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

	local bezelRight = cx + bz / 2
	-- The words start past the sun's longest ray, burst and all.
	local rayRight = cx + raysSize / 2 * RAY_TIP * 1.06
	local textX = showIcon and math.max(bezelRight + TEXT_GAP, rayRight + 2) or BARE_GAP
	self.iconSize, self.cx, self.bz, self.raysSize, self.bezelRight, self.textX = iconSize, cx, bz, raysSize, bezelRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	At(self.rays, art, cx, cy, raysSize)
	At(self.raysWarm, art, cx, cy, raysSize)
	At(self.raysHot, art, cx, cy, raysSize)
	At(self.sun, art, cx, cy, bz)
	At(self.nimbus, art, cx, cy, bz)
	-- The halo, GLOW_SCALE larger, held inside the button with the light's
	-- own margin top and bottom (THE ROOM).
	local bloom = math.min(bz * GLOW_SCALE, H - 2 * kit.EDGE_MARGIN)
	At(self.halo, art, cx, cy, bloom)
	At(self.haloHot, art, cx, cy, bloom)
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
		-- The rings spread from the bezel's edge.
		self.fx:Place(icon, self.fx.ThinPad(iconSize, bz / 2 - iconSize / 2 + 1), iconSize)
		self.fx:Shape(true, ART .. "Ring", ART .. "Ring", maskFile)
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

	-- The gem in its boss, and the room the boss takes at the right.
	local gemX = W - GEM_AT * su
	local gemW = math.max(4, GEM_W * math.min(ph, GEM_PLATE) / DESIGN_H)
	At(self.gem, art, gemX, cy, gemW)
	self.gemX = gemX
	self.chipInset = math.ceil((GEM_AT + BOSS_W / 2) * su) + 3
	-- The inlay: beside the lower fillet, from the bezel to the boss.
	local inlayX0 = showIcon and (bezelRight - 2) or (plateX + 8)
	local inlayX1 = gemX - BOSS_W / 2 * su - 2
	local inlayY = H - plateIn - INLAY_AT * su
	self.inlayOK = inlayX1 - inlayX0 >= 16
	Box(self.inlay, art, inlayX0, inlayY - INLAY_H / 2, inlayX1, inlayY + INLAY_H / 2)
	Box(self.core, art, inlayX0, inlayY - INLAY_H / 2, inlayX1, inlayY + INLAY_H / 2)

	-- The pillar: down onto the sun's middle, from above the button; with
	-- the list hung over the panel, from the button's own top.
	local pillarW = bz * PILLAR_W
	local pillarUp = above and 0 or H * PILLAR_UP
	Box(self.pillar, art, cx - pillarW / 2, -pillarUp, cx + pillarW / 2, cy)
	self.pillar:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
	-- The wings: their roots a little either side of the sun's middle, spread
	-- up and out; not with the list hung over the panel.
	local wing = math.min(H * WING_H, WING_MAX)
	local root = bz * WING_ROOT
	Box(self.wings[1], art, cx + root, cy - wing, cx + root + wing, cy)
	Box(self.wings[2], art, cx - root - wing, cy - wing, cx - root, cy)
	for _, t in ipairs(self.wings) do t:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1) end
	self.wingsOK = showIcon and not above
	-- The motes: along the plate's upper rim, between the text's start and
	-- the boss, each rising when its turn comes.
	local span = math.max(0, gemX - BOSS_W / 2 * su - textX)
	local rise = above and 3 or MOTE_RISE
	for i, t in ipairs(self.motes) do
		At(t, art, textX + span * (i - 0.5) / MOTES, plateIn + 1, 6)
		t:SetVertexColor(SUNLIGHT[1], SUNLIGHT[2], SUNLIGHT[3], 1)
		self.moteAnims[i].move:SetOffset(0, rise)
	end
	self.motesOK = span >= 40

	-- The glint's run along the upper fillet, for the loop and the greeting,
	-- and the gem's twinkle.
	local glintW = 26
	local glintY = plateIn + FILLET_AT * su
	local glintX0 = (showIcon and bezelRight or plateX + 6) + glintW / 2
	local glintRun = gemX - BOSS_W / 2 * su - glintW / 2 - glintX0
	self.greetOK = glintRun >= 30
	At(self.glint, art, glintX0, glintY, glintW, 3)
	At(self.glintOnce, art, glintX0, glintY, glintW, 3)
	self.glintLoop.move:SetOffset(math.max(0, glintRun), 0)
	self.sheenAnim.move:SetOffset(math.max(0, glintRun), 0)
	local star = math.max(6, gemW * 1.8)
	At(self.gemStar, art, gemX, cy, star)
	At(self.gemStarOnce, art, gemX, cy, star)

	-- The cursor's light over the upper rim.
	Box(self.hoverFrame, art, plateX + 4, plateIn, W - 4, plateIn + 8 * su)
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

	-- The tags: left of the gem's boss.
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

	-- The list's rows start where the name does, clear of the sun.
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
	for _, t in ipairs({ self.rays, self.raysWarm, self.sun, self.nimbus, self.halo }) do t:SetShown(showIcon) end
	self.lightFrame:SetShown(showIcon)
	self.fx:SetShown(showIcon)
	self.inlay:SetShown(self.inlayOK)
	self.core:SetShown(self.inlayOK)
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

	-- The count's room: a two-digit tag, the boss and its inset. Chip widens
	-- it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- Every light where it rests: the nimbus lit, the core low, the rest dark.
function Lightbringer:Rest()
	self.nimbus:SetAlpha(NIMBUS_REST)
	self.raysWarm:SetAlpha(0)
	self.raysHot:SetAlpha(0)
	self.halo:SetAlpha(0)
	self.haloHot:SetAlpha(0)
	self.core:SetAlpha(CORE_REST)
	self.pillar:SetAlpha(0)
	for _, t in ipairs(self.wings) do t:SetAlpha(0) end
	for _, t in ipairs(self.motes) do t:SetAlpha(0) end
	for _, t in ipairs({ self.glint, self.glintOnce, self.gemStar, self.gemStarOnce }) do t:SetAlpha(0) end
	self.hoverLight:SetAlpha(0)
end

-- The sun at rest: it turns, the glint crosses and the gem twinkles on Full
-- effects out of a fight, and all are stopped otherwise (stopped, not paused:
-- the rays stand as they are drawn, the lights park dark). The three layers
-- of the rays start and stop together, so they turn as one.
function Lightbringer:Idle()
	local on = self.active and not self.combat and self.kit.FullEffects()
	local sun = on and self.kit.icon:IsShown()
	if sun then
		if not self.turns[1]:IsPlaying() then
			for _, g in ipairs(self.turns) do
				g:Stop()
				g:Play()
			end
		end
	else
		for _, g in ipairs(self.turns) do g:Stop() end
	end
	for _, g in ipairs({ self.glintLoop, self.gemLoop }) do
		if on and self.greetOK then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome, and only on a plate long enough to carry it. `sheenOnly` for the
-- cursor, which has its own light.
function Lightbringer:Greet(sheenOnly)
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
function Lightbringer:Painted(entry)
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the plate, and under the list's when it is out.
function Lightbringer:PlaceShadow(list)
	local W, H = self.W, self.H
	local x0, y0, x1, y1 = (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 2, W + SHADOW_OUT + 1, H + SHADOW_OUT + 3
	if list then
		y0 = math.min(y0, list[2] - SHADOW_OUT + 2)
		y1 = math.max(y1, list[4] + SHADOW_OUT + 3)
	end
	PlacePieces(self.shadow, self.kit.art, x0, y0, x1, y1, SHADOW_C)
end

function Lightbringer:Styled(p)
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
	kit.name:SetShadowColor(0, 0.02, 0.10, 0.9)
	kit.name:SetShadowOffset(1, -1)
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
	local r, g, b = kit.Legible(0.92, 0.90, 0.84, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	ink.rowReason = "|cffb4ad9b"
end

function Lightbringer:Hide()
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

function Lightbringer:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The gem's boss stands at the far end.
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
function Lightbringer:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Lightbringer:Fitted(fs)
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
function Lightbringer:NameFits(room)
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
function Lightbringer:KeyLabel()
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
function Lightbringer:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Lightbringer:Chip(on)
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

-- A nimbus a refusal spent, and the rays gone grey with it: until the next
-- PaintReason.
function Lightbringer:Spend()
	self.nimbus:SetVertexColor(SPENT[1], SPENT[2], SPENT[3], 1)
	self.rays:SetDesaturated(true)
end

-- The nimbus in the reason's colour, and the gem and the inlay (each only
-- where the marker says so, else a pale gold), their lights the same colour
-- taken towards white, and the reason line warmed towards it.
function Lightbringer:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	if self.refused then
		self:Spend()
	else
		self.nimbus:SetVertexColor(cr, cg, cb, 1)
		self.rays:SetDesaturated(self.combat and true or false)
	end
	self.halo:SetVertexColor(cr, cg, cb, 1)
	-- The rays' warm second tone: the Light, taken a part of the way to the
	-- reason, so it is warm whatever the reason is.
	local wr = SUNLIGHT[1] + (cr - SUNLIGHT[1]) * WARM_REASON
	local wg = SUNLIGHT[2] + (cg - SUNLIGHT[2]) * WARM_REASON
	local wb = SUNLIGHT[3] + (cb - SUNLIGHT[3]) * WARM_REASON
	self.raysWarm:SetVertexColor(wr, wg, wb, 1)
	local fr, fg, fb = kit.Tint(wr, wg, wb, FLASH_WHITE)
	self.raysHot:SetVertexColor(fr, fg, fb, 1)
	self.haloHot:SetVertexColor(fr, fg, fb, 1)
	self.gem:SetVertexColor(vr, vg, vb, 1)
	self.inlay:SetVertexColor(vr, vg, vb, INLAY_ALPHA)
	local ir, ig, ib = kit.Tint(vr, vg, vb, 0.45)
	self.core:SetVertexColor(ir, ig, ib, 1)
	-- The reason line: a warm mist taken most of the way to the reason, held
	-- to its contrast on the enamel.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { cr, cg, cb }
end

function Lightbringer:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal spent the nimbus and greyed the rays and the icon: they take
	-- their colour back here, and a fight keeps the icon grey.
	self.refused = nil
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The silver, the gold and the enamel dulled for a fight, or back to
-- themselves.
function Lightbringer:Dull(on)
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(on or (t == self.rays and self.refused) or false)
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

-- The plate holds; it and the sun dull, the icon greys, the words dim and the
-- lights go out. The nimbus, the gem and the inlay keep their colour: the
-- reason is the one coloured thing left.
function Lightbringer:Combat(on)
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

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Lightbringer:HoldPulse(spent)
	StopAll(self.pulse)
	self.raysWarm:SetAlpha(spent and WARM_HELD or 0)
	self.nimbus:SetAlpha(spent and NIMBUS_HELD or NIMBUS_REST)
	self.halo:SetAlpha(spent and HALO_HELD or 0)
	self.core:SetAlpha(spent and CORE_HELD or CORE_REST)
end

-- The lights the three flourishes share are one set of regions: one plays at
-- a time.
function Lightbringer:StopLights()
	StopAll(self.arrive)
	StopAll(self.landing)
	StopAll(self.refusal)
end

function Lightbringer:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The Light answers a new favour, never a new face.
		if full and self.kit.icon:IsShown() then
			self:StopLights()
			PlayAll(self.arrive)
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
	-- A repaint leaves a running breath alone; a new favour on top keeps it
	-- going but takes its own three breaths.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		StopAll(self.calm)
		self.raysWarm:SetAlpha(WARM_REST)
		self.nimbus:SetAlpha(NIMBUS_REST)
		self.halo:SetAlpha(HALO_REST)
		self.core:SetAlpha(CORE_REST)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Lightbringer.pulseGen or not Lightbringer.active then return end
			Lightbringer.pulseSpent = true
			if Lightbringer.pulse[1]:IsPlaying() then
				Lightbringer:HoldPulse(true)
				-- Settled: the gem says so, once.
				Lightbringer:Greet()
			end
		end)
	end
end

function Lightbringer:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	self.raysWarm:SetAlpha(0)
	self.nimbus:SetAlpha(NIMBUS_REST)
	self.halo:SetAlpha(0)
	self.core:SetAlpha(CORE_REST)
	self.calmLit = nil
end

function Lightbringer:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal gutters: the rays blink twice in the refusal's red and go
	-- grey, the nimbus is left spent, and one ring snaps in onto the bezel.
	-- The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		self.refused = true
		self:Spend()
		if shown then
			self:StopLights()
			self.raysHot:SetVertexColor(o[1], o[2], o[3], 1)
			PlayAll(self.refusal)
			self.fx:Refuse(1.00, 0.40, 0.34, 0.85)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	if shown then
		self.burstRays:Play()
		self.hotAnim:Play()
		-- The wings, where the Light has room above the panel.
		if self.wingsOK then PlayAll(self.wingAnims) end
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
	-- The motes, only on a plate long enough for them.
	if self.motesOK then PlayAll(self.moteAnims) end
end

function Lightbringer:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Lightbringer:Hover(on)
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
	if on then self:Greet(true) end
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the second line becomes the verdict, so
-- the eye never has to find the person again. The inlay's core takes the
-- outcome's colour.
function Lightbringer:PaintOutcome(kind, lead, sub, who, stamp)
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

function Lightbringer:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A second, darker plate under the first (or over it); each row wears a
-- small gem in its reason's colour.
function Lightbringer:PaintQueue(rows, shown, above)
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
		y1 = self.plateIn
		y0 = -depth
	else
		y0 = H - self.plateIn
		y1 = H + depth
	end
	PlaceBody(self.listBody, art, self.plateX, y0, W, y1)
	Each(self.listBody, "Show")
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
