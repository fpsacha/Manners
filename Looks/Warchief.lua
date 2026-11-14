-- Manners -- the Warchief look: the Horde's, Orgrimmar's black iron and red
-- hide, tusks and a war banner, the crest in the forge's glow.
--
-- A slab of dark riveted iron with a row of iron spikes standing on its upper
-- rim, above the panel. At its left the spell icon, cut to the slab's own
-- chamfered square, in a heavy iron frame between two ivory tusks that rise
-- past the slab. On the iron behind the name the Horde's crest in worn red
-- paint. At the far end a tattered war banner on an iron rod, the crest on it
-- in black, hanging past the slab's foot. Between the icon and its frame lies
-- the BRAND, a band that carries the reason's colour; a daub of war paint
-- along the lower rim carries it too. The list is a sheet of red hide under
-- (or over) the slab. While somebody is owed, SOOT lies under each line of
-- words, a soft dark patch as long as the line, over the crest and its
-- lights: the crest may glow as it likes, and the words keep their contrast.
--
-- Every region is a texture from Textures/Warchief
-- (tools/make_warchief_textures.py). The iron, the ivory, the hide and the
-- banner are baked, because they are decoration; everything that means
-- something -- the brand, the paint, the beads, the glyphs, the lights -- is
-- white or grey art coloured through Looks.Colour, so one file serves all six
-- reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-warchief.lua):
--   * a favour arriving STRIKES the crest: it flashes white-hot, the frame
--     with it, and forge sparks fly from the crest (a film of sixteen
--     frames, Looks/Flow.lua); the soot comes up under the words with it;
--   * owed, the crest GLOWS like iron out of the forge: it and the brand
--     breathe, three breaths, coals crawling inside the crest (two fields
--     scrolled across one another, Flow) and embers rising from it past
--     the spikes, and then it holds lit, the embers gone;
--   * a landing is a DRUM BEAT: the frame's light and the brand's thump
--     twice, sparks fly from the icon, and the shared rings spread from the
--     frame;
--   * a refusal QUENCHES it: the brand blinks twice in the refusal's red and
--     is left spent, the crest goes cold and grey, the icon greys, one ring
--     snaps in; a cast nobody confirmed does nothing;
--   * at rest, on Full effects, the banner STIRS in the wind (a film of eight
--     frames, Flow) and a glint crosses the upper rim now and then; somebody
--     new on the panel is greeted with the glint. hunt35-effects lets the
--     groups of `idle` loop with nobody owed, by name; the Flow handles that
--     play at rest are `flows`; the author asked for a look that is alive at
--     rest;
--   * no additive light at rest: the strike, the beat, the sparks, the
--     brand's blink and the rings are the only ADD regions, each lit under
--     0.6 s and parked at nothing; the glow, the coals, the glint and the
--     hover are BLEND;
--   * the sparks fly past the panel and the strike lights the iron under the
--     words: `skyward` names them for hunt37-effects;
--   * Calm keeps to fades: no banner in the wind, no coals crawling, no
--     sparks, no glint;
--   * a fight dulls the iron, the ivory, the hide and the banner, stills the
--     banner, dims the words and greys the icon; the brand and the paint keep
--     their colour;
--   * the icon is the slider's size and always the slab's chamfered square
--     ("Round the icon off" reads nothing here);
--   * the spikes stand above the panel and the banner hangs below it: with
--     the list hung over the panel the spikes are put away, and a list hung
--     under it ends where the banner begins.

local _, ns = ...
local Colour = ns.Looks.Colour
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Warchief\\Warchief_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Warchief = ns.Looks.Register("warchief", {
	name = L["Warchief -- black iron and tusks, the Horde's crest in the forge's glow"],
	title = L["Warchief"],
	description = L["black iron and tusks, the Horde's crest in the forge's glow"],
	order = 9.9,
	-- The slab holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the iron whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_warchief_textures.py
-- (tests/scenarios/look-warchief.lua compares them): the icon fills this much
-- of the frame's file and its corners are cut this much of its half-width,
-- the slab's design height and the width of its ends' and its middle's files
-- in texels, the spikes' file as a multiple of its height, how much larger
-- than the frame the halo is drawn, the tag's caps as a fraction of its
-- height, the mask's fill, where the ring file's line sits, the rim's width
-- in design texels, the two films' frames across, down and in all, and where
-- the frame's edge lies in the tusk's file, and how dark the soot under a
-- line of words is at its middle.
local ICON_FRAME = 0.70
local ICON_CUT = 0.22
local DESIGN_H = 128
local CAP_W = 64
local MID_W = 256
local SPIKE_TILE = 4
local GLOW_SCALE = 1.12
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
local RIM = 8
local BANNER_COLS = 4
local BANNER_ROWS = 2
local BANNER_FRAMES = 8
local SPARK_COLS = 4
local SPARK_ROWS = 4
local SPARK_FRAMES = 16
local TUSK_EDGE = 0.40
local SOOT = 0.84
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- The films: the banner's frames a second (one beat of the wind is its eight
-- frames) and the sparks' (sixteen frames, out in 0.53 s).
local BANNER_FPS, SPARK_FPS = 9, 30
local SPARK_SECONDS = SPARK_FRAMES / SPARK_FPS
-- The slab is this much of the button's height in from its top and bottom.
local PLATE_IN = 0.05
-- The tusks: their height as a part of the frame's, how far under the
-- frame's foot their roots reach, as a part of the frame.
local TUSK_H, TUSK_FOOT = 1.28, 0.04
-- The spikes: their height as a part of the button's, and at most.
local SPIKE_H, SPIKE_MAX = 0.32, 30
-- The banner: its height as a part of the button's and at most; how much of
-- its file's width the cloth and the rod leave clear at each side; how far
-- above the slab's top the file starts, as a part of its height.
local BANNER_H, BANNER_MAX, BANNER_CLEAR, BANNER_UP = 1.34, 130, 0.10, 0.085
-- The crest: its side as a part of the slab's height, and where its middle
-- lies along the words' room.
local CREST_SIDE, CREST_AT = 1.10, 0.60
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the right tusk and the text; with the icon off, between
-- the slab's edge and the text.
local TEXT_GAP, BARE_GAP = 3, 12
-- The ground under the words, its darkest and its brightest (as greys), for
-- Legible: the hammered iron at its darkest, the crest lit and held at its
-- brightest (tools/audit_look_contrast.py --json measures both): the crest's
-- red paint, which the words stand on at rest. Lit, the crest is under the
-- soot, which is darker than the paint.
local TABLE_LO, TABLE_HI = 0.02, 0.22
-- The reason line is the small one, and the one players lose: its colour is
-- held to this contrast on the iron (tools/LOOKS.md), not to the 4.5 a line of
-- words is measured against.
local SUB_CONTRAST = 7
-- A chosen panel colour is mixed this far into the slab.
local BODY_MIX = 0.25
-- The shadow and the list's sheet: their 9-slice corners in units, and how
-- far past the slab the shadow's box reaches.
local SHADOW_C, SHADOW_OUT, LIST_C = 16, 12, 8
local BONE = { 0.97, 0.94, 0.86 }
local TAG_INK = { 1.00, 0.95, 0.86 }
local MIST = { 0.88, 0.83, 0.76 }
-- A fight's iron, ivory and hide.
local DULL = { 0.60, 0.60, 0.62 }
-- The brand and the paint with the marker off, and a brand a refusal spent.
local NEUTRAL = { 0.78, 0.58, 0.40 }
local SPENT = { 0.36, 0.35, 0.36 }
local HOVER = { 1.00, 0.86, 0.66 }
-- Iron out of the forge: the crest's glow, the coals in it, the sparks.
local EMBER = { 1.00, 0.40, 0.09 }
local COAL = { 1.00, 0.62, 0.22 }
local SPARK = { 1.00, 0.74, 0.38 }
-- A flash is the glow's colour taken this far to white; the glow is the
-- ember taken this far to the reason.
local FLASH_WHITE, EMBER_REASON = 0.55, 0.30
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims, the slab dims.
-- The text only a little: "held -- in combat" is grey already, and on iron
-- dulled this far a deeper dim took the small line under 6:1.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.90, 0.70, 0.78
-- The lights that breathe when somebody is owed, in the order the breath is
-- built: what each rests at with nobody owed, the breath's low and its peak,
-- and what it holds after its breaths. The crest's glow first:
-- hunt35-effects times the breath by the first.
local LIGHTS = {
	{ "crestGlow", 0, 0.14, 0.50, 0.30 },
	{ "brand", 0.74, 0.74, 1.00, 0.92 },
	{ "halo", 0, 0.03, 0.20, 0.10 },
	{ "coalA", 0, 0.08, 0.36, 0.22 },
	{ "coalB", 0, 0.06, 0.28, 0.17 },
}
local PAINT_ALPHA = 0.92
-- The paint is never taller than this, in units.
local PAINT_MAX = 7
local BREATHS, BREATH = 3, 1.25
-- The coals: how many times each field tiles across the crest, and how fast
-- each crawls, in files a second. The two cross one another.
local COALS = { span = { 1.5, 2.1 }, du = { 0.012, -0.021 }, dv = { 0.050, 0.031 } }
-- The embers that rise from the crest while it breathes: where each starts
-- across the crest (a part of its side from its middle), how long each
-- waits before it rises again, how long the rise takes, and how far it goes
-- as a part of the button's height. No two waits share a measure.
local EMBERS = { at = { -0.30, 0.22, -0.06, 0.34 }, wait = { 0.10, 0.75, 1.45, 2.05 }, rise = 1.7, far = 0.80, peak = 0.90 }
-- The glint's crossing and its wait, at rest.
local GLINT_CROSS, GLINT_WAIT, GLINT_PEAK = 1.7, 7.3, 0.85
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block inside the slab's two rims.
function Warchief.TwoLineHeight(fontSize)
	return math.ceil((fontSize + 2 + SubSize(fontSize) + 4) / 0.76)
end

-- The brand is the mark round the icon; the paint is the stripe.
function Warchief.AccentCarriers(p)
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

-- Relative luminance of a grey, for the iron's own ink figures.
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

-- The slab: its left end, its tiled middle and its right end, from the three
-- files at the design height.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "PlateL", "PlateM", "PlateR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- The slab laid over a box: the ends are the design's proportion of its
-- height, the middle tiled along the rest.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local h = y1 - y0
	local su = h / DESIGN_H
	local cap = math.min(CAP_W * su, (x1 - x0) / 2)
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, x1 - cap, y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
	s[2]:SetTexCoord(0, Tiles(x1 - x0 - 2 * cap, MID_W * su), 0, 1)
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

-- One frame of a film, standing still.
local function Still(t, cols, rows, frame)
	local col, row = frame % cols, math.floor(frame / cols)
	t:SetTexCoord(col / cols, (col + 1) / cols, row / rows, (row + 1) / rows)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it lights, parked between
-- plays, so nothing is left lit when it stops
---------------------------------------------------------------------------

local Flash, Breathe, Fade, Sheen, GlintLoop, Gutter, Beat, Burn, PlayAll, StopAll
do
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

	-- Up to `peak`, then down to `rest` (nothing unless said).
	function Flash(region, peak, up, down, rest)
		local g = region:CreateAnimationGroup()
		Alpha(g, rest or 0, peak, up, 1, nil, "OUT")
		Alpha(g, peak, rest or 0, down, 2, nil, "IN")
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

	-- One fade from `from` to `to`, which it then holds.
	function Fade(region, from, to, duration)
		local g = region:CreateAnimationGroup()
		Alpha(g, from, to, duration, 1, nil, "OUT")
		Park(g, region, to)
		return g
	end

	-- The sheen: along the rim by the offset Apply gives it, up as it leaves
	-- and out as it arrives, once.
	function Sheen(region, cross, peak)
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
	function GlintLoop(region, cross, wait, peak)
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

	-- Two blinks, the second weaker: a light that is quenched. 0.33 s.
	function Gutter(region)
		local g = region:CreateAnimationGroup()
		Alpha(g, 0, 0.85, 0.04, 1, nil, "OUT")
		Alpha(g, 0.85, 0, 0.09, 2, nil, "IN")
		Alpha(g, 0, 0.55, 0.04, 3, nil, "OUT")
		Alpha(g, 0.55, 0, 0.16, 4, nil, "IN")
		Park(g, region, 0)
		return g
	end

	-- A drum's two beats: a hard one, the skin still ringing, and a second
	-- that dies away. 0.52 s.
	function Beat(region, first, second)
		local g = region:CreateAnimationGroup()
		Alpha(g, 0, first, 0.04, 1, nil, "OUT")
		Alpha(g, first, first * 0.15, 0.14, 2, nil, "IN")
		Alpha(g, first * 0.15, second, 0.04, 3, nil, "OUT")
		Alpha(g, second, 0, 0.30, 4, nil, "IN")
		Park(g, region, 0)
		return g
	end

	-- Lit for as long as a film runs, then out: `seconds` in all.
	function Burn(region, peak, seconds)
		local g = region:CreateAnimationGroup()
		Alpha(g, peak, peak, seconds - 0.08, 1)
		Alpha(g, peak, 0, 0.08, 2, nil, "IN")
		Park(g, region, 0)
		return g
	end

	-- An ember: dark for `wait`, then up by the offset Apply gives it, lit as
	-- it leaves and gone as it arrives, over and over.
	function Warchief.RiseGroup(region, wait, seconds, peak)
		local g = region:CreateAnimationGroup()
		g:SetLooping("REPEAT")
		Alpha(g, 0, 0, wait, 1)
		local move = g:CreateAnimation("Translation")
		move:SetDuration(seconds)
		move:SetOrder(2)
		if move.SetSmoothing then move:SetSmoothing("OUT") end
		g.move = move
		Alpha(g, 0, peak, seconds * 0.2, 2, nil, "OUT")
		Alpha(g, peak, 0, seconds * 0.8, 2, seconds * 0.2, "IN")
		Park(g, region, 0)
		return g
	end

	function PlayAll(list)
		for _, g in ipairs(list) do
			g:Stop()
			g:Play()
		end
	end

	function StopAll(list)
		for _, g in ipairs(list) do g:Stop() end
	end

	-- The cursor's light, both ways; from and to are set for each play.
	function Warchief.HoverGroup(region)
		local g = region:CreateAnimationGroup()
		g.fade = Alpha(g, 0, 1, 0.12, 1, nil, "OUT")
		Park(g, region, 0)
		return g
	end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Warchief:Build(kit)
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
	-- The list's own shadow: a list hung under the slab ends where the banner
	-- begins, and one shadow round both would lie black beside it.
	self.listShadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", keep)
	self.list = Pieces(art, "BACKGROUND", -7, ART .. "List", keep)
	self.body = Body(art, "BACKGROUND", -6, keep)
	-- The crest on the iron: the paint, the coals that show through its shape
	-- while it glows (two fields, tiled, scrolled by Flow), and the glow.
	self.crest = tex(art, "BORDER", 1, "Crest")
	self.coalMask = art:CreateMaskTexture()
	self.coalMask:SetTexture(ART .. "CrestHot", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.coalA = tex(art, "BORDER", 2, "Coals", nil, "REPEAT")
	self.coalB = tex(art, "BORDER", 3, "Coals", nil, "REPEAT")
	for _, t in ipairs({ self.coalA, self.coalB }) do
		t:AddMaskTexture(self.coalMask)
		t:SetAlpha(0)
	end
	self.crestGlow = tex(art, "BORDER", 4, "CrestGlow")
	self.crestGlow:SetAlpha(0)
	-- The daub of war paint along the lower rim, and the spikes on the upper.
	self.paint = tex(art, "BORDER", 5, "Paint")
	self.spikes = tex(art, "BORDER", 6, "Spikes", nil, "REPEAT", "CLAMP")
	-- The icon's frame, under the icon (ARTWORK 0): a soft halo, the iron,
	-- the brand in its bed; the tusks and the banner over them.
	self.halo = tex(art, "ARTWORK", -5, "Halo")
	self.halo:SetAlpha(0)
	self.frame = tex(art, "ARTWORK", -3, "Frame")
	self.brand = tex(art, "ARTWORK", -2, "Brand")
	self.tusks = { tex(art, "ARTWORK", 2, "Tusk"), tex(art, "ARTWORK", 2, "Tusk") }
	self.tusks[2]:SetTexCoord(1, 0, 0, 1)
	self.banner = tex(art, "ARTWORK", 3, "Banner")
	-- hunt35-effects reads the owed breath's second tone by these names.
	self.pulseRing, self.ringWarm = self.crestGlow, self.crestGlow

	-- The rings that spread from the frame when a buff lands and the one that
	-- snaps in when one is refused: frames over the art, under the text. No
	-- echo of the icon: nothing lies over it.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "Ring", RING_PEAK, RING_EDGE)

	-- The lights: the frame's flash, the brand's, the crest struck, the sparks.
	self.lightFrame = frame(2)
	self.haloHot = tex(self.lightFrame, "OVERLAY", 1, "Halo", "ADD")
	self.brandHot = tex(self.lightFrame, "OVERLAY", 2, "Brand", "ADD")
	self.brandBeat = tex(self.lightFrame, "OVERLAY", 2, "Brand", "ADD")
	self.crestHot = tex(self.lightFrame, "OVERLAY", 3, "CrestHot", "ADD")
	self.sparks = tex(self.lightFrame, "OVERLAY", 4, "Sparks", "ADD")
	for _, t in ipairs({ self.haloHot, self.brandHot, self.brandBeat, self.crestHot, self.sparks }) do t:SetAlpha(0) end
	-- The lights that leave the room on purpose (the sparks fly past the
	-- panel; the crest is struck where it lies, under the words):
	-- hunt37-effects holds every other light inside the panel and off the
	-- words, and lets these through by name.
	self.skyward = { self.sparks, self.crestHot }
	-- The glint on the upper rim, once for the greeting and once for the loop
	-- (two groups on one region would fight over its alpha). Not additive.
	self.idleFrame = frame(1)
	self.glint = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	self.glintOnce = tex(self.idleFrame, "OVERLAY", 1, "Glint")
	for _, t in ipairs({ self.glint, self.glintOnce }) do
		Colour(t, HOVER[1], HOVER[2], HOVER[3])
		t:SetAlpha(0)
	end
	-- The embers that rise from the crest while it breathes. Not additive.
	self.motes = {}
	for i = 1, #EMBERS.at do
		self.motes[i] = tex(self.idleFrame, "OVERLAY", 2, "Mote")
		Colour(self.motes[i], COAL[1], COAL[2], COAL[3])
		self.motes[i]:SetAlpha(0)
	end
	-- The cursor's light: the upper rim lit.
	self.hoverFrame = frame(1)
	self.hoverLight = tex(self.hoverFrame, "OVERLAY", 1, "Edge")
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's fangs, one a row, in the row's reason colour.
	self.beads = {}
	for i = 1, #kit.rows do self.beads[i] = tex(art, "ARTWORK", 1, "Bead") end

	-- The soot under each line of words (the name's, the reason's): over the
	-- crest and every light on it, under the text.
	self.sootFrame = frame(3)
	self.soot = {}
	for i = 1, 2 do
		self.soot[i] = { box = keep(CreateFrame("Frame", nil, self.sootFrame)),
			slice = ThreeSlice(self.sootFrame, "BACKGROUND", 1, ART .. "Soot", keep) }
	end

	-- The chips: tags of hide at the right end; their text is on textLayer,
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

	-- The icon's chamfered square; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything baked, for a fight's dulling.
	self.baked = { self.frame, self.tusks[1], self.tusks[2], self.spikes, self.banner, self.crest }
	for _, s in ipairs({ self.body, self.chip, self.keyChip, self.list }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end

	-- What moves by its coordinates (Looks/Flow.lua): the banner's film, the
	-- sparks' and the coals' two fields.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.bannerSheet = flow:Sheet(self.banner, BANNER_COLS, BANNER_ROWS, BANNER_FRAMES, BANNER_FPS, true)
	self.sparkSheet = flow:Sheet(self.sparks, SPARK_COLS, SPARK_ROWS, SPARK_FRAMES, SPARK_FPS, false)
	self.coalScroll = {
		flow:Scroll(self.coalA, COALS.du[1], COALS.dv[1], COALS.span[1], COALS.span[1]),
		flow:Scroll(self.coalB, COALS.du[2], COALS.dv[2], COALS.span[2], COALS.span[2]),
	}
	-- What plays for as long as the look is at rest: `flows`.
	self.flows = { self.bannerSheet }

	self:BuildAnimations(anim)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

function Warchief:BuildAnimations(anim)
	-- The owed breath, "Once" (one rise and fall, 0.55 s) and Calm (one fade
	-- up to the held light, and nothing after): one group of each for every
	-- light of LIGHTS, in its order. See Attention for how long.
	self.pulse, self.once, self.calm = {}, {}, {}
	for i, l in ipairs(LIGHTS) do
		local region = self[l[1]]
		self.pulse[i] = anim(Breathe(region, l[3], l[4]))
		self.once[i] = anim(Flash(region, l[4], 0.25, 0.30, l[2]))
		self.calm[i] = anim(Fade(region, l[2], l[5], 0.5))
	end

	-- The embers: they rise for as long as the breath runs, and no longer.
	self.rise = {}
	for i, t in ipairs(self.motes) do
		self.rise[i] = anim(Warchief.RiseGroup(t, EMBERS.wait[i], EMBERS.rise, EMBERS.peak))
	end

	-- A favour arriving: the crest is struck (0.48 s), the frame flashes with
	-- it and the sparks fly for as long as their film runs (0.53 s).
	self.strikeAnim = anim(Flash(self.crestHot, 0.80, 0.06, 0.42))
	self.sparkAnim = anim(Burn(self.sparks, 1, SPARK_SECONDS))
	self.arrive = { self.strikeAnim, anim(Flash(self.haloHot, 0.60, 0.06, 0.40)), self.sparkAnim }

	-- A landing: the drum's two beats on the frame's light and the brand's
	-- (0.52 s), and the sparks. Nothing on the crest: nobody is owed any
	-- more, and the soot is down.
	self.beatAnim = anim(Beat(self.haloHot, 0.85, 0.60))
	self.landing = { self.beatAnim, anim(Beat(self.brandBeat, 0.70, 0.45)), anim(Burn(self.sparks, 1, SPARK_SECONDS)) }

	-- The soot under the words: up at once as the crest lights, down slowly
	-- when it goes out. One of the two plays at a time (SootUp).
	self.sootIn = anim(Fade(self.sootFrame, 0, 1, 0.06))
	self.sootOut = anim(Fade(self.sootFrame, 1, 0, 0.40))

	-- A refusal: the brand blinks twice in red and is gone, 0.33 s.
	self.gutterAnim = anim(Gutter(self.brandHot))
	self.refusal = { self.gutterAnim }
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- At rest: the glint crosses the upper rim. hunt35-effects lets the
	-- groups of this list loop with nobody owed, and no others. See Idle for
	-- when it runs.
	self.glintLoop = anim(GlintLoop(self.glint, GLINT_CROSS, GLINT_WAIT, GLINT_PEAK))
	self.idle = { self.glintLoop }
	-- The greeting: the glint, once, out by 0.7 s.
	self.sheenAnim = anim(Sheen(self.glintOnce, 0.7, GLINT_PEAK))
	self.greet = { self.sheenAnim }

	self.hoverAnims = { anim(Warchief.HoverGroup(self.hoverLight)) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Warchief:Apply(p, above)
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

	-- The icon: the slider's size, held inside the button. The frame is the
	-- icon's file frame, held inside the button's height; when the cap bites,
	-- the hole shrinks under the icon, which draws over it. A tusk stands
	-- either side of the frame, TUSK_EDGE of its width outside it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local tuskH = bz * TUSK_H
	local tuskW = tuskH / 2
	local reach = tuskW * TUSK_EDGE
	-- The left tusk touches the button's left edge.
	local cx, cy = reach + bz / 2, H / 2
	-- The slab: inset from the button's top and bottom, from under the frame
	-- to the right edge; with the icon off, the whole width.
	local plateIn = math.max(1, math.floor(H * PLATE_IN + 0.5))
	local ph = H - 2 * plateIn
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph, self.su = plateIn, plateX, ph, su
	PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
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
	for _, t in ipairs(self.shadow) do Colour(t, 0, 0, 0, self.shadowAlpha) end
	for _, t in ipairs(self.listShadow) do Colour(t, 0, 0, 0, self.shadowAlpha) end
	self:PlaceShadow(nil)

	local frameRight = cx + bz / 2
	local textX = showIcon and (frameRight + reach + TEXT_GAP) or BARE_GAP
	self.iconSize, self.cx, self.bz, self.frameRight, self.textX = iconSize, cx, bz, frameRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	At(self.frame, art, cx, cy, bz)
	At(self.brand, art, cx, cy, bz)
	At(self.brandHot, art, cx, cy, bz)
	At(self.brandBeat, art, cx, cy, bz)
	-- The halo, GLOW_SCALE larger, held inside the button with the light's
	-- own margin top and bottom (THE ROOM).
	local bloom = math.min(bz * GLOW_SCALE, H - 2 * kit.EDGE_MARGIN)
	At(self.halo, art, cx, cy, bloom)
	At(self.haloHot, art, cx, cy, bloom)
	-- The tusks: their roots a little under the frame's foot, their tips
	-- above it; the right one the left one's mirror.
	local tuskY1 = cy + bz / 2 + bz * TUSK_FOOT
	Box(self.tusks[1], art, cx - bz / 2 - reach, tuskY1 - tuskH, cx - bz / 2 - reach + tuskW, tuskY1)
	Box(self.tusks[2], art, frameRight + reach - tuskW, tuskY1 - tuskH, frameRight + reach, tuskY1)
	Colour(self.sparks, SPARK[1], SPARK[2], SPARK[3])
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	-- The icon is the slab's chamfered square whatever "Round the icon off"
	-- says.
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
		-- The rings spread from the frame's edge.
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
			-- The sweep's edge turns about the middle: the cut corners are
			-- nearer a circle than a square.
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	end

	-- The banner at the far end: its rod just over the slab's upper rim, its
	-- torn foot past the slab's lower one. Its room is what the cloth takes
	-- of the slab's right end.
	local bannerH = math.min(H * BANNER_H, BANNER_MAX)
	local bannerW = bannerH / 2
	local bannerX1 = W + bannerW * BANNER_CLEAR * 0.5
	local bannerY0 = plateIn - bannerH * BANNER_UP
	Box(self.banner, art, bannerX1 - bannerW, bannerY0, bannerX1, bannerY0 + bannerH)
	self.bannerOK = W - textX >= bannerW + 40
	self.bannerRoom = self.bannerOK and math.ceil(W - (bannerX1 - bannerW) - bannerW * BANNER_CLEAR) or 6
	self.chipInset = self.bannerRoom + 3

	-- The spikes on the upper rim, above the panel: whole tiles from the
	-- right tusk to the banner.
	local spikeH = math.min(H * SPIKE_H, SPIKE_MAX)
	local spikeX0 = showIcon and (frameRight + reach + 1) or (plateX + CAP_W * su * 0.5)
	local spikeX1 = W - self.bannerRoom - 1
	self.spikesOK = spikeX1 - spikeX0 >= spikeH * 3
	Box(self.spikes, art, spikeX0, plateIn - spikeH + su * 4, spikeX1, plateIn + su * 4)
	self.spikes:SetTexCoord(0, math.max(1, math.floor((spikeX1 - spikeX0) / (spikeH * SPIKE_TILE) + 0.5)), 0, 1)

	-- The crest on the iron behind the words, between the text's start and
	-- the banner; the coals show through its shape, each field tiled as many
	-- times across it as COALS says.
	local room = W - self.bannerRoom - textX
	self.crestSide = math.min(ph * CREST_SIDE, room)
	self.crestOK = room >= 30
	self:PlaceCrest()
	-- The embers rise past the upper rim; with the list hung over the panel,
	-- no further than the rim.
	local far = above and (cy - plateIn) * 0.6 or H * EMBERS.far
	for i in ipairs(self.motes) do
		self.rise[i].move:SetOffset((i % 2 == 0 and 2 or -2), far)
	end

	-- The paint: along the lower rim, from the right tusk to the banner.
	local paintX0 = showIcon and (frameRight + reach * 0.4) or (plateX + 8)
	local paintX1 = W - self.bannerRoom - 2
	local paintY = H - plateIn - RIM * su * 0.55
	-- A daub, not a flood: on a tall slab it keeps to the rim.
	local paintH = math.max(3, math.min(RIM * su * 2.0, PAINT_MAX))
	self.paintOK = paintX1 - paintX0 >= 16
	Box(self.paint, art, paintX0, paintY - paintH / 2, paintX1, paintY + paintH / 2)

	-- The glint's run along the upper rim, for the loop and the greeting.
	local glintW = 26
	local glintY = plateIn + RIM * su * 0.5
	local glintX0 = (showIcon and (frameRight + reach) or plateX + 6) + glintW / 2
	local glintRun = W - self.bannerRoom - glintW / 2 - glintX0
	self.greetOK = glintRun >= 30
	At(self.glint, art, glintX0, glintY, glintW, 3)
	At(self.glintOnce, art, glintX0, glintY, glintW, 3)
	self.glintLoop.move:SetOffset(math.max(0, glintRun), 0)
	self.sheenAnim.move:SetOffset(math.max(0, glintRun), 0)

	-- The cursor's light over the upper rim.
	Box(self.hoverFrame, art, plateX + 4, plateIn, W - 4, plateIn + RIM * su * 1.4)
	Colour(self.hoverLight, HOVER[1], HOVER[2], HOVER[3])

	local block = fs + 2 + sub
	self.block = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of the banner.
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
	self.sootFrame:SetFrameLevel(base + 3)
	self.sootFrame:ClearAllPoints()
	self.sootFrame:SetAllPoints(art)
	for _, s in ipairs(self.soot) do
		s.text, s.w, s.at = nil, nil, nil
		Each(s.slice, "Hide")
	end
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list's rows start where the name does, clear of the tusks, and end
	-- before the banner.
	self.rowX = math.max(textX, 24)
	local rowWidth = math.max(20, W - self.rowX - self.bannerRoom - 10)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.frame, self.brand, self.halo, self.tusks[1], self.tusks[2] }) do t:SetShown(showIcon) end
	self.lightFrame:SetShown(true)
	for _, t in ipairs({ self.haloHot, self.brandHot, self.brandBeat }) do t:SetShown(showIcon) end
	self.sootIn:Stop()
	self.sootOut:Stop()
	self.sootFrame:SetAlpha(0)
	self.sootOn = nil
	self.fx:SetShown(showIcon)
	self.banner:SetShown(self.bannerOK)
	self.spikes:SetShown(self.spikesOK)
	for _, t in ipairs({ self.crest, self.crestGlow, self.crestHot, self.coalA, self.coalB }) do t:SetShown(self.crestOK) end
	self.coalMask:SetShown(self.crestOK)
	self.paint:SetShown(self.paintOK)
	Each(self.list, "Hide")
	Each(self.listShadow, "Hide")
	for _, t in ipairs(self.beads) do t:Hide() end
	self.glyph:Hide()
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	for _, s in ipairs(self.soot) do
		s.up = false
		Each(s.slice, "Hide")
	end
	self:Rest()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent, self.calmLit, self.lit, self.idleState = nil, nil, nil, nil
	self:Dull(false)
	if held then self:Combat(true) end
	self:Idle()

	-- The count's room: a two-digit tag, the banner and its inset. Chip widens
	-- it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The crest's place: CREST_AT of the way along the room the words have,
-- between the text's start and the banner. It is painted on the iron and
-- stays where it is: a tag that comes up is riveted over it. The embers
-- start from its upper half.
function Warchief:PlaceCrest()
	local art = self.kit.art
	local side, textX, cy = self.crestSide, self.textX, self.H / 2
	local right = self.W - self.bannerRoom
	local x = textX + (right - textX) * CREST_AT
	x = math.max(textX + side / 2, math.min(x, right - side / 2))
	for _, t in ipairs({ self.crest, self.crestGlow, self.crestHot, self.coalA, self.coalB, self.coalMask }) do
		At(t, art, x, cy, side)
	end
	self.crestX = x
	for i, t in ipairs(self.motes) do
		At(t, art, x + side * EMBERS.at[i], cy - side * 0.10, math.max(3, self.H * 0.11))
	end
end

-- The lights of the owed breath at one of their three stands: 2 at rest with
-- nobody owed, 3 the breath's low, 5 held.
function Warchief:Stand(column)
	for _, l in ipairs(LIGHTS) do self[l[1]]:SetAlpha(l[column]) end
end

-- Every light where it rests: the brand lit, the rest dark.
function Warchief:Rest()
	self:Stand(2)
	for _, t in ipairs({ self.haloHot, self.brandHot, self.brandBeat, self.crestHot, self.sparks, self.glint, self.glintOnce }) do
		t:SetAlpha(0)
	end
	for _, t in ipairs(self.motes) do t:SetAlpha(0) end
	self.hoverLight:SetAlpha(0)
end

-- What the look does at rest: the banner stirs and the glint crosses, on Full
-- effects, out of a fight and with the prompt up; and the coals crawl for as
-- long as the crest is lit. All of it is stopped otherwise (stopped, not
-- paused: the banner hangs as it stands, the lights park dark). Asked at
-- every paint (Painted), so it does nothing unless something changed.
function Warchief:Idle()
	local kit = self.kit
	local on = (self.active and not self.combat and kit.FullEffects() and kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.lit and 2 or 0) + (self.refused and 4 or 0)
	if state == self.idleState then return end
	self.idleState = state
	if on and self.bannerOK then
		if not self.bannerSheet:IsPlaying() then self.bannerSheet:Play() end
	else
		self.bannerSheet:Stop()
	end
	for _, h in ipairs(self.coalScroll) do
		if on and self.lit and self.crestOK then
			if not h:IsPlaying() then h:Play() end
		else
			h:Stop()
		end
	end
	if on and self.greetOK then
		if not self.glintLoop:IsPlaying() then self.glintLoop:Play() end
	else
		self.glintLoop:Stop()
	end
end

-- The greeting, once: on Full effects only, never in a fight nor over an
-- outcome, and only on a slab long enough to carry it.
function Warchief:Greet()
	if not (self.active and self.greetOK) or self.combat or self.outcomeOn then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up, so
-- what runs at rest may run; and somebody new on the panel is greeted, once.
-- A favour arriving has its own lights, so the greeting is for a new face
-- only.
function Warchief:Painted(entry)
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the slab, and the list's own under its sheet when it is
-- out: each keeps to its own box, so a sheet narrower than the slab leaves no
-- black beside it.
function Warchief:PlaceShadow(list)
	local W, H = self.W, self.H
	local art = self.kit.art
	PlacePieces(self.shadow, art, (self.plateX or 0) - SHADOW_OUT + 2, -SHADOW_OUT + 3, W + SHADOW_OUT + 1, H + SHADOW_OUT + 2, SHADOW_C)
	if list then
		PlacePieces(self.listShadow, art, list[1] - SHADOW_OUT + 2, list[2] - SHADOW_OUT + 2, list[3] + SHADOW_OUT + 1, list[4] + SHADOW_OUT + 3, SHADOW_C)
	end
	Each(self.listShadow, "SetShown", list ~= nil)
end

function Warchief:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the iron, whatever the panel colour: the legibility the
	-- shared code works out is held against the iron's own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(BONE[1], BONE[2], BONE[3], 1)
	end
	kit.name:SetShadowColor(0.02, 0, 0, 1)
	kit.name:SetShadowOffset(1, -1)
	-- The reason line is small, and the crest glows behind it: a full dark
	-- shadow under it, whatever the panel colour made of the shared one.
	kit.sub:SetShadowColor(0.02, 0, 0, 1)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are hide whatever the panel, so their text is bone as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.94, 0.90, 0.82, 4.5)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(r, g, b, 1)
		fs:SetShadowColor(0.02, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	end
	ink.rowReason = "|cffc4b5a3"
end

function Warchief:Hide()
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
	self.coalMask:Hide()
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
	self.pulseSpent, self.calmLit, self.lit, self.idleState, self.greeted = nil, nil, nil, nil, nil
	self.sootFrame:SetAlpha(0)
	self.sootOn = nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Warchief:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The banner hangs at the far end.
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
	-- The soot goes where the lines went.
	for _, s in ipairs(self.soot) do s.at = nil end
end

-- The soot under a line: as long as the line is drawn, the verdict's glyph
-- (`lead`) with it (its width as FitLine
-- took it; measured here only when FitLine could not, and then once a
-- text), a little taller than its letters, soft at every edge. Nothing under
-- a line that is not up, nor on a slab too short for the crest.
function Warchief:Soot(i, fs, lead)
	local kit = self.kit
	local s = self.soot[i]
	local text = fs:GetText()
	local up = (self.crestOK and fs:IsShown() and type(text) == "string" and text ~= "") and true or false
	if up then
		local w = kit.fit.drawn[fs]
		if not w then
			if text ~= s.text then s.text, s.w = text, kit.TextWidth(fs) end
			w = s.w
		end
		w = math.min(w or self.lineRoom, self.lineRoom)
		local size = kit.fit.size[fs] or self.sub
		local y = 0
		if kit.fit.twoLine then y = i == 1 and self.nameY or self.subY end
		-- Placed again only when the line moved or changed its length: this
		-- runs at every repaint, and builds nothing.
		if s.at ~= w or s.size ~= size or s.y ~= y or s.lead ~= lead then
			s.at, s.size, s.y, s.lead = w, size, y, lead
			local h = size * 1.6 + 4
			s.box:ClearAllPoints()
			s.box:SetPoint("LEFT", kit.textLayer, "LEFT", self.textX - h * TAG_CAPS * 0.55, y)
			s.box:SetSize(lead + w + h * TAG_CAPS * 1.1, h)
			PlaceThree(s.slice, s.box, h)
		end
	end
	if up ~= s.up then
		s.up = up
		Each(s.slice, "SetShown", up)
	end
end

-- Whether the reason line holds the verdict PaintOutcome wrote: the only
-- time a glyph leads it.
function Warchief:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Warchief:Fitted(fs)
	local kit = self.kit
	if not self.lineRoom then return end
	if fs == kit.name then return self:Soot(1, fs, 0) end
	if fs ~= kit.sub then return end
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
	self:Soot(2, fs, lead)
end

-- Whether the name, at the size the player set, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Warchief:NameFits(room)
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
function Warchief:KeyLabel()
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
function Warchief:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Warchief:Chip(on)
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
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 12)
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
			self.countW = math.max(self.chipH * 1.75, (kit.TextWidth(count) or self.sub) + 12)
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

-- A brand a refusal spent, and the crest gone cold with it: until the next
-- PaintReason.
function Warchief:Spend()
	Colour(self.brand, SPENT[1], SPENT[2], SPENT[3])
	self.crest:SetDesaturated(true)
end

-- The brand in the reason's colour, and the paint (each only where the marker
-- says so, else a dull ochre), the crest's glow the ember taken a part of the
-- way to the reason, the flashes the same taken towards white, and the reason
-- line warmed towards the reason.
function Warchief:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	if self.refused then
		self:Spend()
	else
		Colour(self.brand, cr, cg, cb)
		self.crest:SetDesaturated(self.combat and true or false)
	end
	Colour(self.halo, cr, cg, cb)
	-- Iron out of the forge is the ember's colour whatever the reason; the
	-- reason only leans on it.
	local er = EMBER[1] + (cr - EMBER[1]) * EMBER_REASON
	local eg = EMBER[2] + (cg - EMBER[2]) * EMBER_REASON
	local eb = EMBER[3] + (cb - EMBER[3]) * EMBER_REASON
	Colour(self.crestGlow, er, eg, eb)
	Colour(self.coalA, COAL[1], COAL[2], COAL[3])
	Colour(self.coalB, COAL[1], COAL[2], COAL[3])
	local fr, fg, fb = kit.Tint(er, eg, eb, FLASH_WHITE)
	Colour(self.crestHot, fr, fg, fb)
	Colour(self.haloHot, fr, fg, fb)
	Colour(self.brandHot, fr, fg, fb)
	Colour(self.brandBeat, fr, fg, fb)
	Colour(self.paint, vr, vg, vb, PAINT_ALPHA)
	-- The reason line: a warm mist taken most of the way to the reason, held
	-- to its contrast on the iron.
	local sr = MIST[1] + (r - MIST[1]) * 0.6
	local sg = MIST[2] + (g - MIST[2]) * 0.6
	local sb = MIST[3] + (b - MIST[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glyph, sr, sg, sb)
	self.tint = { cr, cg, cb }
end

function Warchief:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal spent the brand and greyed the crest and the icon: they take
	-- their colour back here, and a fight keeps the icon grey.
	self.refused = nil
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The iron, the ivory, the hide and the banner dulled for a fight, or back
-- to themselves.
function Warchief:Dull(on)
	local pc = self.bodyColour or { 1, 1, 1 }
	local slab = {}
	for _, t in ipairs(self.body) do slab[t] = true end
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(on or (t == self.crest and self.refused) or false)
		if slab[t] then
			local f = on and BODY_COMBAT or 1
			Colour(t, pc[1] * f, pc[2] * f, pc[3] * f)
		elseif on then
			Colour(t, DULL[1], DULL[2], DULL[3])
		else
			Colour(t, 1, 1, 1)
		end
	end
end

-- The slab holds; it, the tusks and the banner dull, the banner hangs still,
-- the icon greys, the words dim and the lights go out. The brand and the
-- paint keep their colour: the reason is the one coloured thing left.
function Warchief:Combat(on)
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
	end
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Warchief:HoldPulse(spent)
	StopAll(self.pulse)
	StopAll(self.rise)
	self:Stand(spent and 5 or 2)
	self.lit = spent and true or nil
	self:Idle()
end

-- The soot under the words, up while the crest may be lit (somebody owed is
-- on top) and down otherwise: a fade either way, never a loop.
function Warchief:SootUp(on)
	on = on and true or false
	if self.sootOn == on then return end
	self.sootOn = on
	self.sootIn:Stop()
	self.sootOut:Stop()
	self.sootFrame:SetAlpha(on and 0 or 1)
	if on then self.sootIn:Play() else self.sootOut:Play() end
end

-- The sparks fly from where the blow fell: `x`, `y` from the art's top left,
-- in a square `size` across.
function Warchief:Sparks(x, y, size)
	At(self.sparks, self.kit.art, x, y, size)
	self.sparkSheet:Play()
end

-- The lights the three flourishes share are one set of regions: one plays at
-- a time.
function Warchief:StopLights()
	StopAll(self.arrive)
	StopAll(self.landing)
	StopAll(self.refusal)
	self.sparkSheet:Stop()
end

function Warchief:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	-- The crest may light from here on: the soot comes up under the words.
	self:SootUp(true)
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The forge answers a new favour, never a new face: the crest is
		-- struck and the sparks fly from it.
		if full and self.crestOK then
			self:StopLights()
			PlayAll(self.arrive)
			self:Sparks(self.crestX, self.H / 2, self.crestSide * 1.9)
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
			-- Calm chosen while it breathed: the embers stop with the
			-- breath, which alone had sent them up.
			StopAll(self.rise)
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
		self:Stand(3)
		for _, g in ipairs(self.pulse) do g:Play() end
		if self.crestOK then PlayAll(self.rise) end
		self.lit = true
		self:Idle()
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Warchief.pulseGen or not Warchief.active then return end
			Warchief.pulseSpent = true
			if Warchief.pulse[1]:IsPlaying() then
				Warchief:HoldPulse(true)
				-- Settled: the rim says so, once.
				Warchief:Greet()
			end
		end)
	end
end

function Warchief:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.rise)
	StopAll(self.calm)
	StopAll(self.once)
	self:Stand(2)
	self.calmLit, self.lit = nil, nil
	if self.sootOn then self:SootUp(false) end
	self:Idle()
end

function Warchief:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal quenches it: the brand blinks twice in the refusal's red and
	-- is left spent, the crest goes cold, and one ring snaps in onto the
	-- frame. The text's shake is Prompt's.
	if kind == "failed" then
		local o = OUTCOME.failed
		self.refused = true
		self:Spend()
		if shown then
			self:StopLights()
			Colour(self.brandHot, o[1], o[2], o[3])
			PlayAll(self.refusal)
			self.fx:Refuse(1.00, 0.40, 0.34, 0.85)
		end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- The drum: two beats on the frame's light and the brand's, the sparks
	-- from the icon, and the rings from the frame.
	if shown then
		PlayAll(self.landing)
		self:Sparks(self.cx, self.H / 2, self.bz * 2)
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
end

function Warchief:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Warchief:Hover(on)
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
-- the eye never has to find the person again. The paint takes the outcome's
-- colour.
function Warchief:PaintOutcome(kind, lead, sub, who, stamp)
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
	-- The owed glow is about the favour, not the click: it goes out.
	-- Attention lights it again for the next person owed.
	self:HoldPulse()
	StopAll(self.calm)
	StopAll(self.once)
	self:Stand(2)
	self.strikeAnim:Stop()
	if self.sootOn then self:SootUp(false) end
	Colour(self.paint, o[1], o[2], o[3], PAINT_ALPHA)
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

function Warchief:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A sheet of red hide under the slab (or over it); each row wears a fang in
-- its reason's colour. Hung under the slab it ends where the banner begins;
-- hung over it, the spikes are put away.
function Warchief:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.beads do
		if not (list and i <= shown) then self.beads[i]:Hide() end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.list, "Hide")
			self.spikes:SetShown(self.spikesOK)
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
	local W, H = self.W, self.H
	local x0, x1 = self.plateX + 3, W - 3
	local y0, y1
	if above then
		y1 = self.plateIn + 2
		y0 = -depth
	else
		y0 = H - self.plateIn - 2
		y1 = H + depth
		if self.bannerOK then x1 = W - self.bannerRoom - 1 end
	end
	PlacePieces(self.list, art, x0, y0, x1, y1, LIST_C)
	Each(self.list, "Show")
	self.spikes:SetShown(self.spikesOK and not above)
	self:PlaceShadow({ x0, y0, x1, y1 })

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
