-- Manners -- the Ebon look: a death knight's.
--
-- THE SOURCE. The death knight of Warcraft: the runeblades forged in Acherus,
-- the Ebon Hold, and the saronite of Icecrown Citadel they are made of; the
-- runeforge that cuts a rune into the steel; the runes a death knight spends
-- and waits for; the skulls and horns of the Scourge's armour, and the cold
-- fire in their eyes.
--
-- A RUNEBLADE of dark saronite lying across the screen, its point to the
-- right. Its GUARD stands across it at the left, taller than the blade: an
-- eight-sided socket that holds the spell icon (cut to the socket's eight
-- sides), crowned by a pale SKULL between two swept horns, fangs under it.
-- The blade is blued steel in a fuller between two ground edges, and the
-- words stand in the fuller. Towards the point three RUNES are cut into the
-- flat, each smaller than the last as the blade narrows. SOULFIRE burns
-- behind the skull, light lies in the channel round the icon and in the
-- skull's eyes: those three carry the reason's colour. The runes carry it
-- too where the marker says so, and are the runeforge's cold blue where it
-- does not. Cold vapour rolls off both edges. The list is a plate of the
-- same steel under (or over) the blade, a small lozenge for each name.
--
-- Every region is a texture from Textures/Ebon (tools/make_ebon_textures.py).
-- The saronite, the steel, the skull and the horns are baked, because they
-- are decoration. Everything that means something -- the soulfire, the eyes,
-- the light in the socket, the runes, the list's lozenges, the glyphs -- is
-- white or grey art coloured through Looks.Colour, so one file serves all
-- six reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- What moves, and when (tests/scenarios/look-ebon.lua):
--   * at rest, on Full effects, the soulfire BURNS behind the skull (a sheet
--     of eight drawn frames, looped, Looks/Flow.lua), cold vapour ROLLS off
--     the blade's two edges (two layers of one cloud scrolled against one
--     another, cut to a band along each edge), the runes light one after
--     another, guard to point, over and over, a sheen runs along each ground
--     edge and the point glints. hunt35-effects lets the groups of `idle`
--     loop with nobody owed, by name; the Flow handles are `flows`;
--   * a favour arriving KINDLES the runes: one after another, guard to
--     point, each goes white-hot for a moment and stays lit, a light running
--     the upper edge ahead of them;
--   * owed, the runes stand fully lit, the soulfire burns taller and
--     quicker, the eyes blaze; the light over the socket and the runes'
--     light breathe three times and then hold lit;
--   * a landing is the RUNEFORGE: the socket goes white-hot, a ring of light
--     leaves it, a lance runs up to the skull and down the fang (a sheet of
--     sixteen drawn frames, played once), every rune flashes, guard to
--     point, sparks fly from the blade's edge, the point glints, and the
--     shared rings spread from the icon;
--   * a refusal puts the blade OUT: the runes gutter, point to guard, and go
--     dark, a wisp of vapour leaving each; the soulfire is snuffed and the
--     eyes go dark; a notch stands in the upper edge; the steel goes dull,
--     the vapour is gone, the icon greys and one ring snaps in; a cast
--     nobody confirmed does nothing;
--   * no additive light at rest: the socket's and the runes' white heat and
--     the rings are the only ADD regions, each lit under 0.6 s and parked at
--     nothing;
--   * the guard stands past the panel, above and below it, and the soulfire
--     above that. With the list hung over the panel no vapour rises into it
--     and the list keeps right of the guard; with the list hung under it no
--     vapour falls into it;
--   * Calm keeps to fades: the soulfire stands still, no vapour moves, no
--     rune chases, no sheen, no sparks; the runes are simply lit while
--     somebody is owed, and dark after a refusal;
--   * a fight stills all of it and puts the lights out, dulls the steel,
--     dims the words and greys the icon; the soulfire, the eyes, the socket
--     and the runes keep their colour;
--   * the icon is the slider's size and always cut to the socket's eight
--     sides ("Round the icon off" reads nothing here);
--   * the words read: the name and the reason line stand on the blued steel
--     over a full dark shadow, the reason line and the verdict held to a
--     contrast of 7, and nothing bright lies under them at any moment;
--   * a colour never lights what was dimmed: the game keeps one alpha for a
--     texture, so every colour goes through Colour, which keeps the alpha
--     the texture has.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Ebon\\Ebon_"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local Ebon = ns.Looks.Register("ebon", {
	name = L["Ebon -- a runeblade of saronite, a skull over the socket, runes that kindle"],
	title = L["Ebon"],
	description = L["a runeblade of saronite, a skull over the socket, runes that kindle"],
	order = 9.9,
	-- The blade holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.5,
	-- The words stand on the blued steel whatever the panel colour says.
	inkOnDark = true,
	subOnDark = true,
})

-- MUST AGREE with tools/make_ebon_textures.py (tests/scenarios/look-ebon.lua
-- compares them): the icon fills this much of the socket's box and the guard
-- is drawn this much larger than it; the socket's side from the guard's
-- middle, as a fraction of the guard's box; the blade's design height, its
-- left end's width, its point's length, where on the point the runes begin,
-- and its middle tile's width, in texels; each rune's middle from the
-- point's left, and its width, in design texels; how much of the blade's
-- height the words have; the sheets; where the skull's eyes are and how
-- large, and where the soulfire stands, as fractions of the guard's box; the
-- tag's caps, the mask's fill and the ring file's line.
local ICON_FRAME = 0.75
local CIRCLE_SCALE = 1.8
local GUARD_HALF = 0.305
local DESIGN_H = 128
local CAP_W = 64
local END_W = 144
local END_ROOT = 8
local TILE_W = 256
local RUNE_AT = { 32, 76, 108 }
local RUNE_SIZE = { 64, 50, 34 }
local FACE = 0.70
local FLAME_COLS = 4
local FLAME_ROWS = 2
local FLAME_FRAMES = 8
local FORGE_COLS = 4
local FORGE_ROWS = 4
local FORGE_FRAMES = 16
local EYE_UP = 0.352
local EYE_OUT = 0.0527
local EYE_SIZE = 0.10
local FLAME_FOOT = 0.33
local TAG_CAPS = 0.5
local MASK_FILL = 0.985
local RING_AT = 0.78
-- The ring file as the generator prints it (--reach): where the line is
-- brightest and how far out it is seen, as fractions of the half-width.
local RING_PEAK, RING_EDGE = 0.773, 0.914
-- The blade's edges stand this far in from its file's top and bottom, and
-- each is ground back over this many texels (the generator's EDGE, BEVEL).
local EDGE_IN, BEVEL = 2, 13
-- The blade is this much of the button's height in from its top and its
-- bottom, so the guard stands proud of it.
local PLATE_IN = 0.05
-- The blade is no taller than this much of the button's width, unless the
-- words need more.
local BLADE_MAX = 0.30
-- How tall the blade may stand against the button where the words need it.
local BLADE_OVER = 1.12
-- How far a middle tile may be stretched to end on a whole one.
local STRETCH = 0.20
-- The gap between the guard and the text; with the icon off, between the
-- blade's end and the text.
local TEXT_GAP, BARE_GAP = 4, 15
-- The blued steel's own luminance under the words, its darkest and its
-- brightest (as greys), for Legible; and the contrast the reason line and
-- the verdict are held to on it: 7, not the 4.5 of the tags, since the line
-- is small.
local TABLE_LO, TABLE_HI = 0.01, 0.16
local SUB_CONTRAST = 7
-- A chosen panel colour is mixed this far into the blade.
local BODY_MIX = 0.25
-- The list's plate: its nine-slice corner, in units.
local LIST_C = 9
-- The shadow: its 9-slice corner in units, and how far past the blade its
-- box reaches.
local SHADOW_C, SHADOW_OUT = 16, 12
local BONE_WHITE = { 0.93, 0.96, 0.98 }
local TAG_INK = { 0.86, 0.93, 0.98 }
local HAZE = { 0.84, 0.91, 0.98 }
-- A fight's steel; a refusal's.
local DULL = { 0.62, 0.62, 0.64 }
local DEAD = { 0.74, 0.76, 0.80 }
-- The runeforge's own light: the cold blue of a rune nobody coloured, the
-- runner on the edge, the sparks, the cursor's light.
local RUNEFROST = { 0.62, 0.82, 0.98 }
local FORGELIGHT = { 0.80, 0.93, 1.00 }
-- The vapour's own colour; what a refusal leaves of the socket's light.
local VAPOUR_WHITE = { 0.80, 0.90, 1.00 }
local SPENT = { 0.30, 0.33, 0.38 }
-- A flash is the reason's colour taken this far to white.
local FLASH_WHITE = 0.5
local OUTCOME = {
	cast = { 0.56, 0.90, 0.62 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.84, 0.88, 0.94 },
}
-- What a fight does: the text dims, the icon greys and dims, the blade dims.
local TEXT_COMBAT, ICON_COMBAT, BODY_COMBAT = 0.78, 0.70, 0.72
-- The light over the socket at rest, lit and held after its breaths; each
-- rune's soft light over the same breath.
local HALO = { rest = 0, peak = 0.66, held = 0.32 }
local GLOW = { rest = 0.14, peak = 0.62, held = 0.36, combat = 0.06 }
-- The light in the channel, and the eyes.
local SOCKET_ALPHA = 0.92
local EYES = { rest = 0.82, owed = 1, combat = 0.6 }
-- A rune's light: at rest, with somebody owed, in a fight, before it takes.
local RUNE = { rest = 0.58, owed = 1, combat = 0.5, dark = 0.12 }
local BREATHS, BREATH = 3, 1.25
-- The soulfire: how tall it stands against the guard, how wide against its
-- height, how much taller with somebody owed, its frames a second at rest
-- and owed, how strong at rest, owed and in a fight, and how large its heart
-- is against it.
local FLAME = { tall = 0.27, wide = 1.93, owed = 1.06, fps = 11, quick = 16, rest = 0.85, lit = 1, combat = 0.45, heart = 0.70 }
-- The vapour: a tile of its cloud in units, how much longer than tall it is
-- drawn, each layer's drift in tiles a second along the blade and away from
-- it, how strong each layer is, and how much of that the upper edge's has.
local VAPOUR = { tile = 40, long = 2.2, du = { 0.026, -0.018 }, dv = { 0.040, 0.024 }, alpha = { 0.62, 0.40 }, upper = 0.60 }
-- The runes' chase at rest: each lights in turn (when, how long it waits
-- after), and how bright the light over it gets.
local CHASE = { 0.9, 1.25, 1.6, rest = 4.6, peak = 0.85 }
-- A favour arriving: each rune takes this long after the one before it.
local KINDLE_STEP = 0.12
-- The sheen on each ground edge (wait, run, rest), and the glints: on the
-- point and on the skull's brow (wait, rest).
local SHEEN = { { 2.4, 1.1, 5.2 }, { 5.6, 1.3, 6.4 } }
local GLINTS = { { 1.6, 5.8 }, { 4.4, 7.2 } }
-- A landing's sparks: where each leaves the upper edge (a fraction of the
-- way along it), how far it flies (aside, up, in blade heights), how it
-- turns. None flies down across the words.
local SPARKS = { { 0.10, -0.30, 0.34, 200 }, { 0.26, 0.16, 0.46, -240 }, { 0.42, -0.14, 0.38, 220 }, { 0.58, 0.22, 0.50, -200 },
	{ 0.74, -0.10, 0.36, 260 }, { 0.90, 0.26, 0.42, -220 }, { 0.34, 0.34, 0.28, 180 }, { 0.66, -0.34, 0.30, -260 } }
local SPARK_SECONDS = 0.50
-- The notch a refusal leaves, and how dark it stands.
local NOTCH_AT, NOTCH_HELD = 0.40, 0.92
-- The forge's sheet: its frames a second (0.53 s in all).
local FORGE_FPS = 30
local FORGE_SECONDS = FORGE_FRAMES / FORGE_FPS
-- Each rune's own file.
local RUNE_FILES = { "Rune1", "Rune2", "Rune3" }
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function SubSize(fontSize) return math.max(7, fontSize - 3) end

-- The name, a gap and the reason as one block, the ground edges above and
-- below it.
function Ebon.TwoLineHeight(fontSize)
	return math.ceil(fontSize + 2 + SubSize(fontSize) + 14)
end

-- The soulfire, the eyes and the socket's light are the mark round the icon;
-- the runes are the stripe.
function Ebon.AccentCarriers(p)
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

-- Relative luminance of a grey, for the blued steel's own ink figures.
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
local Colour = ns.Looks.Colour

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
-- from the middle strips (the shadow, the list's plate).
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

-- The blade: its left end, its tiled middle and its point.
local function Body(parent, layer, sublevel, keep)
	local s = {}
	for i, file in ipairs({ "BladeL", "BladeM", "BladeR" }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if i == 2 then t:SetTexture(ART .. file, "REPEAT", "CLAMP") else t:SetTexture(ART .. file) end
		s[i] = keep(t)
	end
	return s
end

-- The blade laid over a box. The left end is the design's proportion of the
-- height, and so is the point, END_W of the design long. The middle is tiled
-- along what they leave, and ends on a whole tile where the point takes it
-- up, so the steel's flow runs on. Returns where the point begins.
local function PlaceBody(s, rel, x0, y0, x1, y1)
	local su = (y1 - y0) / DESIGN_H
	local rx = math.max(x0, x1 - END_W * su)
	local cap = math.max(0, math.min(CAP_W * su, rx - x0))
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, math.max(x0 + cap, rx), y1)
	Box(s[3], rel, rx, y0, x1, y1)
	s[1]:SetShown(cap > 0.5)
	s[2]:SetShown(rx - x0 - cap > 0.5)
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

-- One frame of a sheet, shown still (Calm, a fight).
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

-- A glint on the steel: dark for `wait`, up and out as it turns a quarter,
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

-- A rune's turn in the chase: dark for `wait`, up and slowly out, dark for
-- `rest`, over and over. The three keep one measure, so the light walks.
local function Chase(region, wait, rest, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	Alpha(g, 0, peak, 0.22, 2, nil, "OUT")
	Alpha(g, peak, 0, 0.90, 3, nil, "IN")
	Alpha(g, 0, 0, rest, 4)
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

-- The sheen on a ground edge: nothing for `wait`, it runs the edge by the
-- offset Apply gives it, nothing for `rest`, over and over.
local function Sweep(region, wait, seconds, rest, peak)
	local g = region:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	Alpha(g, 0, 0, wait, 1)
	g.move = Move(g, seconds, 2, "IN_OUT")
	Alpha(g, 0, peak, seconds * 0.25, 2, nil, "OUT")
	Alpha(g, peak, 0, seconds * 0.35, 2, seconds * 0.65, "IN")
	Alpha(g, 0, 0, rest, 3)
	Park(g, region, 0)
	return g
end

-- A spark thrown: out by one offset (slowing) and down by another
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

-- A rune guttering: it stands for `delay`, shudders, flares once more and is
-- out.
local function Gutter(region, delay)
	local g = region:CreateAnimationGroup()
	local order = 1
	if delay and delay > 0 then
		Alpha(g, 1, 1, delay, 1)
		order = 2
	end
	Alpha(g, 1, 0.30, 0.07, order, nil, "OUT")
	Alpha(g, 0.30, 0.85, 0.06, order + 1, nil, "IN")
	Alpha(g, 0.85, 0, 0.17, order + 2, nil, "IN")
	Park(g, region, 0)
	return g
end

-- A wisp leaving a rune: nothing for `delay`, then up by the offset Apply
-- gives it, swelling into sight and thinning away.
local function Rise(region, seconds, delay)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0, delay, 1)
	g.move = Move(g, seconds, 2, "OUT")
	Alpha(g, 0, 0.70, seconds * 0.25, 2, nil, "OUT")
	Alpha(g, 0.70, 0, seconds * 0.60, 2, seconds * 0.40, "IN")
	Park(g, region, 0)
	return g
end

-- The forge's sheet seen: up at once, held while its frames play, and out
-- with the last of them.
local function Struck(region)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 1, 0.03, 1, nil, "OUT")
	Alpha(g, 1, 1, FORGE_SECONDS - 0.16, 2)
	Alpha(g, 1, 0, 0.13, 3, nil, "IN")
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

function Ebon:Build(kit)
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
	-- The notch a refusal leaves in the upper edge.
	self.notch = tex(art, "BORDER", 1, "Notch")
	self.notch:SetAlpha(0)
	-- The runes in their cuts: each one's soft light, the light in the cut,
	-- and the brighter light the chase lays over it.
	self.runeGlow, self.runes, self.runeLit = {}, {}, {}
	for i = 1, #RUNE_AT do
		self.runeGlow[i] = tex(art, "BORDER", 2, "RuneGlow")
		self.runes[i] = tex(art, "BORDER", 3, RUNE_FILES[i])
		self.runeLit[i] = tex(art, "BORDER", 4, RUNE_FILES[i])
		self.runeLit[i]:SetAlpha(0)
	end
	-- The vapour off the two edges: two layers each, cut to a band along its
	-- edge. Under the guard and over the blade.
	self.vapourMask = { art:CreateMaskTexture(), art:CreateMaskTexture() }
	self.vapourMask[1]:SetTexture(ART .. "VapourMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.vapourMask[2]:SetTexture(ART .. "VapourMaskUp", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.vapour = {}
	for i = 1, 4 do
		local t = tex(art, "BORDER", 5 + (i - 1) % 2, "Vapour", nil, "REPEAT")
		t:AddMaskTexture(self.vapourMask[i <= 2 and 1 or 2])
		self.vapour[i] = t
	end
	-- The soulfire BEHIND the skull, then the guard, under the icon (ARTWORK
	-- 0): the light in its channel, the light over that, the eyes.
	self.flame = tex(art, "ARTWORK", -8, "Flame")
	-- Its heart: the same fire again, smaller and paler, inside it.
	self.heart = tex(art, "ARTWORK", -7, "Flame")
	self.guard = tex(art, "ARTWORK", -6, "Guard")
	self.socket = tex(art, "ARTWORK", -5, "Socket")
	self.halo = tex(art, "ARTWORK", -4, "Halo")
	self.halo:SetAlpha(0)
	self.eyes = { tex(art, "ARTWORK", -3, "Eye"), tex(art, "ARTWORK", -3, "Eye") }

	-- The rings that spread from the socket when a buff lands and the one
	-- that snaps in when one is refused: frames over the art, under the text.
	-- No echo of the icon: nothing lies over it but the forge's heat.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		f:SetFrameLevel(base + 2)
		keep(f)
	end
	kit.RingArt(ART .. "FxRing", RING_PEAK, RING_EDGE)

	-- The runeforge over the guard, the socket's white heat and each rune's.
	self.lightFrame = frame(2)
	self.forge = tex(self.lightFrame, "OVERLAY", 1, "Forge")
	self.forge:SetAlpha(0)
	self.hot = tex(self.lightFrame, "OVERLAY", 2, "Hot", "ADD")
	self.hot:SetAlpha(0)
	self.runeHot = {}
	for i = 1, #RUNE_AT do
		local t = tex(self.lightFrame, "OVERLAY", 3, "Hot", "ADD")
		t:SetAlpha(0)
		self.runeHot[i] = t
	end
	-- What moves at rest, after a landing and after a refusal, none of it
	-- additive: the sheen, the glints, the runner, the sparks, the wisps.
	self.idleFrame = frame(1)
	self.sheen = {}
	for i = 1, #SHEEN do
		local t = tex(self.idleFrame, "ARTWORK", 1, "Sheen")
		t:SetAlpha(0)
		self.sheen[i] = t
	end
	self.glints = {}
	for i = 1, #GLINTS do
		local t = tex(self.idleFrame, "ARTWORK", 2, "Star")
		t:SetAlpha(0)
		self.glints[i] = t
	end
	self.runner = tex(self.idleFrame, "ARTWORK", 2, "Vein")
	self.runner:SetAlpha(0)
	self.sparks = {}
	for i = 1, #SPARKS do
		local t = tex(self.idleFrame, "ARTWORK", 3, "Spark")
		t:SetAlpha(0)
		self.sparks[i] = t
	end
	self.wisps = {}
	for i = 1, #RUNE_AT do
		local t = tex(self.idleFrame, "ARTWORK", 3, "Wisp")
		t:SetAlpha(0)
		self.wisps[i] = t
	end
	self.star = tex(self.idleFrame, "OVERLAY", 3, "Star")
	self.star:SetAlpha(0)
	-- The cursor's light: the upper edge lit.
	self.hoverFrame = frame(1)
	self.hoverLight = tex(self.hoverFrame, "OVERLAY", 1, "Edge")
	self.hoverLight:SetAllPoints(self.hoverFrame)
	self.hoverLight:SetAlpha(0)

	-- The list's lozenges, one a row, in the row's reason colour.
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

	-- The icon's eight sides; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- What a fight dulls only: the tags, the list's plate, the glyph. The
	-- blade and the guard are dressed with them, and deadened by a refusal.
	self.baked = { self.glyph }
	for _, s in ipairs({ self.chip, self.keyChip, self.listBody }) do
		for _, t in ipairs(s) do self.baked[#self.baked + 1] = t end
	end

	-- What moves by its coordinates (Looks/Flow.lua): the soulfire's frames,
	-- the vapour's four layers, the forge's frames.
	local flow = ns.Looks.Flow.New(art)
	self.flow = flow
	self.flameSheet = flow:Sheet(self.flame, FLAME_COLS, FLAME_ROWS, FLAME_FRAMES, FLAME.fps, true)
	self.heartSheet = flow:Sheet(self.heart, FLAME_COLS, FLAME_ROWS, FLAME_FRAMES, FLAME.fps, true)
	self.vapourScroll = {}
	for i, t in ipairs(self.vapour) do
		local k = (i - 1) % 2 + 1
		-- Away from the blade: down under it, up over it.
		local away = (i <= 2) and -1 or 1
		self.vapourScroll[i] = flow:Scroll(t, VAPOUR.du[k], VAPOUR.dv[k] * away, 1, 1)
	end
	self.forgeSheet = flow:Sheet(self.forge, FORGE_COLS, FORGE_ROWS, FORGE_FRAMES, FORGE_FPS, false)
	-- What plays for as long as the look is at rest: `flows`.
	self.flows = { self.flameSheet, self.heartSheet, self.vapourScroll[1], self.vapourScroll[2], self.vapourScroll[3], self.vapourScroll[4] }

	self:BuildAnimations(function(g) anims[#anims + 1] = g return g end)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

function Ebon:BuildAnimations(anim)
	-- The owed breath: the light over the socket, and each rune's soft light
	-- with it; see Attention for how long. The halo first: hunt35-effects
	-- times the breath by the first.
	self.pulse = { anim(Breathe(self.halo, HALO.rest, HALO.peak)) }
	-- "Once": one rise and fall, 0.55 s.
	self.once = { anim(Flash(self.halo, HALO.peak, 0.25, 0.30, 0)) }
	-- Calm: one fade up to the held light, and nothing after.
	self.calm = { anim(Fade(self.halo, 0, HALO.held, 0.5)) }
	for i, t in ipairs(self.runeGlow) do
		self.pulse[i + 1] = anim(Breathe(t, GLOW.rest, GLOW.peak))
		self.once[i + 1] = anim(Flash(t, GLOW.peak, 0.25, 0.30, GLOW.rest))
		self.calm[i + 1] = anim(Fade(t, GLOW.rest, GLOW.held, 0.5))
	end

	-- A favour arriving: a light runs the upper edge, and the runes take one
	-- after another behind it, guard to point: each goes white-hot (ADD, out
	-- by 0.3 s) and stays lit. All of it is over by 0.6 s.
	self.runAnim = anim(Runner(self.runner, 0.46, 0.90))
	self.kindle, self.kindleHot = {}, {}
	self.arrive = { self.runAnim }
	for i = 1, #RUNE_AT do
		local wait = 0.06 + KINDLE_STEP * (i - 1)
		self.kindle[i] = anim(Fade(self.runes[i], RUNE.dark, RUNE.owed, 0.16, wait))
		self.kindleHot[i] = anim(Flash(self.runeHot[i], 0.85, 0.05, 0.25, 0, wait))
		self.arrive[#self.arrive + 1] = self.kindle[i]
		self.arrive[#self.arrive + 1] = self.kindleHot[i]
	end

	-- A landing: the runeforge's sheet over the guard (its frames are Flow's,
	-- 0.53 s), the socket white-hot (out by 0.35 s), every rune flashing in
	-- turn (out by 0.5 s), the sparks (out by 0.6 s) and the point's glint.
	self.forgeAnim = anim(Struck(self.forge))
	self.hotAnim = anim(Flash(self.hot, 0.80, 0.05, 0.30, 0))
	self.landing = { self.forgeAnim, self.hotAnim }
	self.strike = {}
	for i = 1, #RUNE_AT do
		self.strike[i] = anim(Flash(self.runeHot[i], 0.90, 0.05, 0.28, 0, 0.05 + 0.06 * (i - 1)))
		self.landing[#self.landing + 1] = self.strike[i]
	end
	self.sparkAnims = {}
	for i, t in ipairs(self.sparks) do
		self.sparkAnims[i] = anim(Fling(t, SPARK_SECONDS - 0.03 * (i % 3), SPARKS[i][4], 0.02 * (i % 4)))
		self.landing[#self.landing + 1] = self.sparkAnims[i]
	end
	self.tipAnim = anim(Twinkle(self.star, 0.16, 0.95, 0.10, 0.30))
	self.landing[#self.landing + 1] = self.tipAnim

	-- A refusal: the runes gutter, point to guard, and are out by 0.42 s; the
	-- soulfire is snuffed and the notch struck. A wisp leaves each rune for
	-- most of a second after (not a light: `aftermath`).
	self.gutter = {}
	self.refusal = {}
	for i = 1, #RUNE_AT do
		self.gutter[i] = anim(Gutter(self.runes[i], 0.06 * (#RUNE_AT - i)))
		self.refusal[#self.refusal + 1] = self.gutter[i]
	end
	self.snuff = anim(Fade(self.flame, FLAME.rest, 0, 0.22))
	self.notchIn = anim(Fade(self.notch, 0, NOTCH_HELD, 0.07))
	self.refusal[#self.refusal + 1] = self.snuff
	self.refusal[#self.refusal + 1] = self.notchIn
	self.aftermath = {}
	for i, t in ipairs(self.wisps) do
		self.aftermath[i] = anim(Rise(t, 0.80 + 0.06 * i, 0.10 + 0.06 * (#RUNE_AT - i)))
	end
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- At rest: the runes light one after another, a sheen runs each ground
	-- edge, the point and the skull's brow glint. hunt35-effects lets the
	-- groups of this list loop with nobody owed, and no others. See Idle for
	-- when they run.
	self.chase, self.sheenAnims, self.glintAnims = {}, {}, {}
	self.idle = {}
	for i, t in ipairs(self.runeLit) do
		-- One measure for the three: each waits its turn and then for the
		-- others.
		self.chase[i] = anim(Chase(t, CHASE[i], CHASE.rest - CHASE[i] + CHASE[1], CHASE.peak))
		self.idle[#self.idle + 1] = self.chase[i]
	end
	for i, t in ipairs(self.sheen) do
		self.sheenAnims[i] = anim(Sweep(t, SHEEN[i][1], SHEEN[i][2], SHEEN[i][3], 0.85))
		self.idle[#self.idle + 1] = self.sheenAnims[i]
	end
	for i, t in ipairs(self.glints) do
		self.glintAnims[i] = anim(Glint(t, GLINTS[i][1], GLINTS[i][2], 0.85))
		self.idle[#self.idle + 1] = self.glintAnims[i]
	end
	-- The greeting: the point glints, once, out by 0.8 s.
	self.greet = { anim(Twinkle(self.star, 0.30, 0.9, 0.12, 0.34)) }

	-- The cursor's light on the upper edge, both ways; from and to are set
	-- for each play.
	local hover = self.hoverLight:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hoverLight, 0)
	self.hoverAnims = { anim(hover) }
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Ebon:Apply(p, above)
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

	-- The icon: the slider's size, held inside the button. The socket's box
	-- is the icon's frame, held inside the button's height; the guard is
	-- drawn CIRCLE_SCALE larger, taller than the blade and than the button:
	-- its skull and its fangs stand proud of both. When the cap bites, the
	-- hole shrinks under the icon, which draws over it.
	local iconSize = math.max(8, math.min(p.iconSize or 30, H - 2))
	local bz = math.min(iconSize / ICON_FRAME, H - 1)
	local circle = bz * CIRCLE_SCALE
	-- The socket's left side is the button's.
	local cx, cy = circle * GUARD_HALF, H / 2
	-- The blade: inset from the button's top and bottom, from under the
	-- guard to the right edge; with the icon off, the whole width. Its point
	-- is as long as the blade is tall and a little over, so on a button much
	-- taller than it is wide the blade keeps to a part of the width (and to
	-- what the words need), and lies across the button's middle.
	local plateIn = math.max(1, math.floor(H * PLATE_IN + 0.5))
	-- The words want a flat as tall as their two lines and a little over, so
	-- that they keep clear of the ground edges: where the button is too low
	-- for that, the blade stands BLADE_OVER past it, above and below.
	local need = (fs + 2 + sub + 4) / FACE
	local ph = math.min(math.max(H - 2 * plateIn, math.min(need, H * BLADE_OVER)), math.max(W * BLADE_MAX, need))
	plateIn = (H - ph) / 2
	local su = ph / DESIGN_H
	local plateX = showIcon and cx or 0
	self.plateIn, self.plateX, self.ph, self.su = plateIn, plateX, ph, su
	local endX = PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	self.endX = endX
	-- Where the runes begin: the words, the tags and the list keep left of
	-- them.
	local rootX = endX + END_ROOT * su
	self.rootX = rootX
	-- The blade's colour: as it is, or a chosen panel colour mixed in.
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

	local discRight = cx + circle * GUARD_HALF
	local textX = showIcon and (discRight + TEXT_GAP) or BARE_GAP
	self.iconSize, self.cx, self.cy, self.bz, self.circle, self.discRight, self.textX = iconSize, cx, cy, bz, circle, discRight, textX

	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self:PlaceGuard(showIcon)

	-- The runes in their cuts, and the room the point takes at the right.
	self.runeX, self.runeSize = {}, {}
	for i = 1, #RUNE_AT do
		local x, size = endX + RUNE_AT[i] * su, math.max(5, RUNE_SIZE[i] * su)
		self.runeX[i], self.runeSize[i] = x, size
		At(self.runes[i], art, x, cy, size)
		At(self.runeLit[i], art, x, cy, size)
		At(self.runeGlow[i], art, x, cy, size * 1.5)
		At(self.runeHot[i], art, x, cy, size * 1.25)
	end
	-- A blade too short for its point has no runes.
	self.runesOK = W - plateX >= END_W * su + 12
	self.chipInset = math.ceil(W - rootX) + 2

	self:PlaceEdges(showIcon, above)
	self:PlaceMotion(showIcon, above)

	-- The cursor's light over the upper edge.
	Box(self.hoverFrame, art, plateX + 4, plateIn, rootX, plateIn + (EDGE_IN + BEVEL + 5) * su)
	Colour(self.hoverLight, FORGELIGHT[1], FORGELIGHT[2], FORGELIGHT[3])

	local block = fs + 2 + sub
	self.blockH = block
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The tags: left of where the runes begin.
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

	-- The list's rows start right of the guard, whose skull and fangs stand
	-- where a list would begin, and end where the runes begin.
	self.listX0 = showIcon and (discRight - 1) or (plateX + 2)
	self.rowX = math.max(textX, self.listX0 + 17)
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
	self.vapourMask[1]:Show()
	self.vapourMask[2]:Show()
	PlaceBody(self.body, art, plateX, plateIn, W, H - plateIn)
	for _, t in ipairs({ self.flame, self.heart, self.guard, self.socket, self.halo, self.eyes[1], self.eyes[2], self.forge, self.hot,
		self.glints[2] }) do
		t:SetShown(showIcon)
	end
	for i = 1, #RUNE_AT do
		for _, t in ipairs({ self.runes[i], self.runeLit[i], self.runeGlow[i], self.runeHot[i], self.wisps[i] }) do
			t:SetShown(self.runesOK)
		end
	end
	self.notch:SetShown(self.notchOK)
	self.fx:SetShown(showIcon)
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
	self:Rest()
	self:Breath()
	self:Dress()
	if held then self:Combat(true) end
	-- Asked afresh: what moves may move elsewhere now.
	self.idleState = nil
	self:Idle()

	-- The count's room: a two-digit tag, the point and its inset. Chip
	-- widens it for a longer count.
	self.roomBase = math.ceil(chipH * 1.75) + self.chipInset + 7
	return textX, self.roomBase
end

-- The guard, the light in its socket, the eyes, the soulfire, the icon's
-- mask, the rings' room and the lights that are the guard's.
function Ebon:PlaceGuard(showIcon)
	local kit = self.kit
	local art, icon = kit.art, kit.icon
	local cx, cy, circle, iconSize, H = self.cx, self.cy, self.circle, self.iconSize, self.H
	At(self.guard, art, cx, cy, circle)
	At(self.socket, art, cx, cy, circle)
	At(self.halo, art, cx, cy, circle)
	for i, t in ipairs(self.eyes) do
		At(t, art, cx + (i == 1 and -1 or 1) * circle * EYE_OUT, cy - circle * EYE_UP, math.max(3, circle * EYE_SIZE))
	end
	-- The soulfire stands on the skull's crown, behind it.
	self.flameH = math.max(8, circle * FLAME.tall)
	self.flameFoot = cy - circle * FLAME_FOOT
	-- The forge over the whole guard, the white heat over the icon: neither
	-- larger than its room, for neither grows.
	At(self.forge, art, cx, cy, circle)
	At(self.hot, art, cx, cy, iconSize * 1.5)
	-- The skull's brow glints.
	At(self.glints[2], art, cx - circle * 0.04, cy - circle * 0.40, math.max(6, circle * 0.15))
	self.lightFrame:ClearAllPoints()
	self.lightFrame:SetAllPoints(art)
	self.idleFrame:ClearAllPoints()
	self.idleFrame:SetAllPoints(art)
	-- The icon is cut to the socket's eight sides whatever "Round the icon
	-- off" says.
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
		-- The rings spread from the channel round the icon.
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

-- What lies along the blade's two ground edges: the vapour, the sheen, the
-- runner, the notch.
function Ebon:PlaceEdges(showIcon, above)
	local art = self.kit.art
	local H, W, plateIn, ph, su = self.H, self.W, self.plateIn, self.ph, self.su
	local x0 = showIcon and self.discRight or (self.plateX + 10)
	local span = self.rootX - x0
	self.growX0, self.growSpan = x0, span
	-- The middle line of each ground edge, and how broad one is.
	local bevel = BEVEL * su
	local upper, lower = plateIn + (EDGE_IN + BEVEL / 2) * su, H - plateIn - (EDGE_IN + BEVEL / 2) * su
	self.upper, self.lower, self.bevel = upper, lower, bevel
	-- The vapour: a band along each edge, a quarter of it over the edge and
	-- the rest off the blade, from the guard to the point.
	local vh = math.max(8, math.min(17, H * 0.32))
	local vx0, vx1 = x0 + 2, W - 2
	local yb, yt = H - plateIn - EDGE_IN * su, plateIn + EDGE_IN * su
	for i, t in ipairs(self.vapour) do
		if i <= 2 then
			Box(t, art, vx0, yb - vh * 0.25, vx1, yb + vh * 0.75)
		else
			Box(t, art, vx0, yt - vh * 0.75, vx1, yt + vh * 0.25)
		end
		self.vapourScroll[i]:Window((vx1 - vx0) / (VAPOUR.tile * VAPOUR.long), vh / VAPOUR.tile)
		-- The two layers of one band start apart, so they never lie on one
		-- another.
		if i % 2 == 0 then self.vapourScroll[i]:Phase(0.37, 0.61) end
	end
	Box(self.vapourMask[1], art, vx0, yb - vh * 0.25, vx1, yb + vh * 0.75)
	Box(self.vapourMask[2], art, vx0, yt - vh * 0.75, vx1, yt + vh * 0.25)
	self.vapourOK = vx1 - vx0 >= 40
	-- The sheen: one along the upper edge, guard to point, one along the
	-- lower, point to guard.
	local sw, sh = math.max(16, ph * 1.1), math.max(4, bevel * 1.8)
	At(self.sheen[1], art, x0 + sw / 2, upper, sw, sh)
	At(self.sheen[2], art, x0 + span - sw / 2, lower, sw, sh)
	self.sheenAnims[1].move:SetOffset(math.max(0, span - sw), 0)
	self.sheenAnims[2].move:SetOffset(-math.max(0, span - sw), 0)
	self.sheenOK = span >= 50
	-- The runner: along the upper edge as the runes take.
	At(self.runner, art, x0, upper, math.max(14, ph * 0.9), math.max(4, bevel * 2.2))
	self.runAnim.move:SetOffset(math.max(0, span), 0)
	-- The notch: struck out of the upper edge, hair cracks under it.
	local nh = ph * 0.42
	local nx = x0 + span * NOTCH_AT
	local ny = plateIn + EDGE_IN * su - 0.5
	Box(self.notch, art, nx - nh / 4, ny, nx + nh / 4, ny + nh)
	self.notchOK = span >= 30
end

-- What moves: the glints, a landing's sparks, the wisps. Each is given where
-- it starts and where it goes.
function Ebon:PlaceMotion(showIcon, above)
	local art = self.kit.art
	local H, W, cy, ph, su = self.H, self.W, self.cy, self.ph, self.su
	local x0, span = self.growX0, self.growSpan
	-- With the list hung over the panel nothing flies far above it.
	local lift = above and 0.35 or 1
	-- The point's glint, and the greeting's.
	local tip = math.max(8, ph * 0.46)
	At(self.glints[1], art, W - 5 * su, cy, tip)
	At(self.star, art, W - 5 * su, cy, tip * 1.25)
	-- A landing's sparks: off the upper edge, up and aside, falling as they
	-- go.
	local size = math.max(5, math.min(10, H * 0.20))
	for i, t in ipairs(self.sparks) do
		local s = SPARKS[i]
		At(t, art, x0 + span * s[1], self.upper, (i % 3 == 0) and size * 0.7 or size)
		self.sparkAnims[i].move:SetOffset(s[2] * ph, s[3] * ph * lift)
		self.sparkAnims[i].drop:SetOffset(0, -ph * 0.16)
	end
	-- The wisps: one from each rune, up and a little aside.
	for i, t in ipairs(self.wisps) do
		local sz = math.max(7, self.runeSize[i] * 0.9)
		At(t, art, self.runeX[i], cy - sz * 0.3, sz)
		self.aftermath[i].move:SetOffset((i % 2 == 0) and 3 or -2, math.max(8, H * 0.5) * lift)
	end
end

-- The soulfire, the eyes and the socket's light in their colour.
function Ebon:Fire(r, g, b)
	Colour(self.flame, r, g, b)
	local hr, hg, hb = self.kit.Tint(r, g, b, 0.72)
	Colour(self.heart, hr, hg, hb)
	Colour(self.socket, r, g, b)
	local er, eg, eb = self.kit.Tint(r, g, b, 0.35)
	for _, t in ipairs(self.eyes) do Colour(t, er, eg, eb) end
end

-- The soulfire as tall as the moment has it: taller, and quicker, with
-- somebody owed.
function Ebon:Stoke()
	local owed = self.owed and not self.refused and not self.combat
	local h = self.flameH * (owed and FLAME.owed or 1)
	self.flame:ClearAllPoints()
	self.flame:SetPoint("BOTTOM", self.kit.art, "TOPLEFT", self.cx, -self.flameFoot)
	self.flame:SetSize(h * FLAME.wide, h)
	self.heart:ClearAllPoints()
	self.heart:SetPoint("BOTTOM", self.kit.art, "TOPLEFT", self.cx, -self.flameFoot)
	self.heart:SetSize(h * FLAME.wide * FLAME.heart, h * FLAME.heart)
	self.flameSheet.fps = owed and FLAME.quick or FLAME.fps
	self.heartSheet.fps = self.flameSheet.fps
end

-- Every light that rests at more than nothing, as the moment has it: a
-- refusal puts them out, a fight dims them, somebody owed lights them full.
function Ebon:Breath()
	local dead, fight, owed = self.refused, self.combat, self.owed
	local flame, eyes, rune = FLAME.rest, EYES.rest, RUNE.rest
	if dead then
		flame, eyes, rune = 0, 0, 0
	elseif fight then
		flame, eyes, rune = FLAME.combat, EYES.combat, RUNE.combat
	elseif owed then
		flame, eyes, rune = FLAME.lit, EYES.owed, RUNE.owed
	end
	if not self.snuff:IsPlaying() then self.flame:SetAlpha(flame) end
	self.heart:SetAlpha(flame)
	for _, t in ipairs(self.eyes) do t:SetAlpha(eyes) end
	for i, t in ipairs(self.runes) do
		if not (self.kindle[i]:IsPlaying() or self.gutter[i]:IsPlaying()) then t:SetAlpha(rune) end
	end
	self.socket:SetAlpha(dead and SOCKET_ALPHA * 0.6 or SOCKET_ALPHA)
	-- The vapour: gone from a blade put out, and from the side a list hangs on.
	local list, at = self.listShown, self.listAt
	for i, t in ipairs(self.vapour) do
		local k = (i - 1) % 2 + 1
		local a = VAPOUR.alpha[k] * (i > 2 and VAPOUR.upper or 1)
		if dead or not self.vapourOK then a = 0 end
		if list and ((i <= 2 and not at) or (i > 2 and at)) then a = 0 end
		t:SetAlpha(a)
	end
	self:Stoke()
end

-- Every light where it rests: the lights that rest at nothing dark, the
-- runes' soft light low, the notch closed.
function Ebon:Rest()
	self.halo:SetAlpha(HALO.rest)
	for _, t in ipairs(self.runeGlow) do t:SetAlpha(GLOW.rest) end
	for _, t in ipairs({ self.forge, self.hot, self.star, self.runner, self.hoverLight, self.notch }) do t:SetAlpha(0) end
	for _, list in ipairs({ self.runeHot, self.runeLit, self.sparks, self.wisps, self.sheen, self.glints }) do
		for _, t in ipairs(list) do t:SetAlpha(0) end
	end
end

-- Whether the list hangs under the blade, where the vapour would fall.
function Ebon:ListBelow()
	return (self.listShown and not self.listAt) and true or false
end

-- What the look does at rest: the soulfire burns, the vapour rolls, the
-- runes chase, the sheen runs and the point glints, on Full effects, out of
-- a fight and with the prompt up; all of it is stopped otherwise (stopped,
-- not paused: the fire stands as it is, the lights park dark). Asked at
-- every paint (Painted), so it does nothing unless something changed.
function Ebon:Idle()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local below = self:ListBelow()
	local state = (on and 1 or 0) + (self.refused and 2 or 0) + (self.owed and 4 or 0) + (below and 8 or 0)
		+ ((self.listShown and self.listAt) and 16 or 0)
	if state == self.idleState then return end
	self.idleState = state
	-- A refusal puts the blade out: nothing moves on it until the next
	-- reason lights it.
	local alive = on and not self.refused
	local icon = self.kit.icon:IsShown()
	self:Stoke()
	if alive and icon then
		-- Together, so the heart is the fire's own.
		if not self.flameSheet:IsPlaying() then
			self.flameSheet:Play()
			self.heartSheet:Play()
		end
	else
		self.flameSheet:Stop()
		self.heartSheet:Stop()
		if not on then
			-- Still: the first frame, whichever it stopped on.
			Still(self.flame, FLAME_COLS, FLAME_ROWS, 0)
			Still(self.heart, FLAME_COLS, FLAME_ROWS, 0)
			self.flameSheet.shown, self.heartSheet.shown = nil, nil
		end
	end
	for i, h in ipairs(self.vapourScroll) do
		local hung = self.listShown and ((i <= 2 and not self.listAt) or (i > 2 and self.listAt))
		if alive and self.vapourOK and not hung then
			if not h:IsPlaying() then h:Play() end
		else
			h:Stop()
		end
	end
	-- The chase is the runes at rest: owed, they stand lit.
	for _, g in ipairs(self.chase) do
		if alive and self.runesOK and not self.owed then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for _, g in ipairs(self.sheenAnims) do
		if alive and self.sheenOK then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
	for i, g in ipairs(self.glintAnims) do
		local here = (i == 1) or icon
		if alive and here then
			if not g:IsPlaying() then g:Play() end
		else
			g:Stop()
		end
	end
end

-- The greeting, once: on Full effects only, never in a fight, over an
-- outcome nor on a blade put out.
function Ebon:Greet()
	if not self.active or self.combat or self.outcomeOn or self.refused then return end
	if not self.kit.FullEffects() then return end
	PlayAll(self.greet)
end

-- After every paint of a person, on the scan's own tick: the prompt is up,
-- so what runs at rest may run; and somebody new on the panel is greeted,
-- once. A favour arriving has its own lights, so the greeting is for a new
-- face only.
function Ebon:Painted(entry)
	self:Idle()
	local name = entry and entry.name
	if name == self.greeted then return end
	self.greeted = name
	if name and not (entry.reason == "owed") then self:Greet() end
end

-- The shadow under the blade, and the one under the list's plate when it is
-- out.
function Ebon:PlaceShadow(list)
	local art = self.kit.art
	local top = self.plateIn or 0
	PlacePieces(self.shadow, art, (self.plateX or 0) - SHADOW_OUT + 2, top - SHADOW_OUT + 1, (self.endX or self.W) + SHADOW_OUT + 8,
		self.H - top + SHADOW_OUT + 1, SHADOW_C)
	Each(self.listShadow, "SetShown", list ~= nil)
	if list then
		PlacePieces(self.listShadow, art, list[1] - SHADOW_OUT + 2, list[2] - SHADOW_OUT + 2, list[3] + SHADOW_OUT - 1,
			list[4] + SHADOW_OUT + 1, SHADOW_C)
	end
end

function Ebon:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	-- The ground is the blued steel, whatever the panel colour: the
	-- legibility the shared code works out is held against its own two ends.
	ink.light = true
	ink.lo, ink.hi = Luminance(TABLE_LO), Luminance(TABLE_HI)
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen then
		kit.name:SetTextColor(BONE_WHITE[1], BONE_WHITE[2], BONE_WHITE[3], 1)
	end
	kit.name:SetShadowColor(0, 0.01, 0.02, 0.95)
	kit.name:SetShadowOffset(1, -1)
	-- The reason line is small: a full dark shadow under it, whatever the
	-- panel colour made of the shared one.
	kit.sub:SetShadowColor(0, 0.01, 0.02, 1)
	kit.sub:SetShadowOffset(1, -1)
	-- The tags are dark steel whatever the panel, so their text is pale as it is.
	local tr, tg, tb = kit.Legible(TAG_INK[1], TAG_INK[2], TAG_INK[3], 4.5)
	kit.count:SetTextColor(tr, tg, tb, 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(tr, tg, tb, 1)
	self.keyText:SetShadowOffset(0, 0)
	local r, g, b = kit.Legible(0.90, 0.94, 0.98, 4.5)
	for _, fs in ipairs(kit.rows) do
		fs:SetTextColor(r, g, b, 1)
		fs:SetShadowColor(0, 0.01, 0.02, 1)
		fs:SetShadowOffset(1, -1)
	end
	ink.rowReason = "|cffa3b3c2"
end

function Ebon:Hide()
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
	self.vapourMask[1]:Hide()
	self.vapourMask[2]:Hide()
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
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Ebon:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	-- The runes stand at the far end.
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
function Ebon:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Ebon:Fitted(fs)
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
function Ebon:NameFits(room)
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
function Ebon:KeyLabel()
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
function Ebon:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - self.chipInset - 3
end

-- Run on every repaint. The count's tag at the right, or, with the key's tag
-- there, a tag beside it; the key's tag when a key is bound. Either steps
-- aside for a paint in which the name would otherwise be cut.
function Ebon:Chip(on)
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

-- The steel as the moment has it: dulled for a fight, deadened by a refusal,
-- else itself.
function Ebon:Dress()
	local fight, dead = self.combat and true or false, self.refused and true or false
	self.guard:SetDesaturated(fight or dead)
	if fight then
		Colour(self.guard, DULL[1], DULL[2], DULL[3])
	elseif dead then
		Colour(self.guard, DEAD[1], DEAD[2], DEAD[3])
	else
		Colour(self.guard, 1, 1, 1)
	end
	for _, t in ipairs(self.baked) do
		t:SetDesaturated(fight)
		if fight then Colour(t, DULL[1], DULL[2], DULL[3]) else Colour(t, 1, 1, 1) end
	end
	-- The blade: dimmed for a fight; greyed with the rest by a refusal.
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

-- What a refusal leaves: the runes out, the soulfire snuffed, the eyes dark,
-- the socket's light spent, the notch struck, the steel dull and nothing
-- moving: until the next PaintReason.
function Ebon:Spend()
	Colour(self.socket, SPENT[1], SPENT[2], SPENT[3])
	self.halo:SetAlpha(0)
	for _, t in ipairs(self.runeGlow) do t:SetAlpha(0) end
	-- The notch stands (its striking, when that is playing, ends there).
	if not self.notchIn:IsPlaying() then self.notch:SetAlpha(NOTCH_HELD) end
	self:Breath()
	self:Dress()
	self:Idle()
end

-- The blade made whole after a refusal: the notch closed, the lights back.
function Ebon:Mend()
	self.notchIn:Stop()
	self.notch:SetAlpha(0)
	StopAll(self.gutter)
	self.snuff:Stop()
	for _, t in ipairs(self.runeGlow) do t:SetAlpha(self.combat and GLOW.combat or GLOW.rest) end
	self:Breath()
	self:Dress()
	self:Idle()
end

-- The soulfire, the eyes and the socket's light in the reason's colour, and
-- the runes (each only where the marker says so, else the runeforge's own
-- cold blue), their lights the same colour taken towards white, and the
-- reason line coloured towards it.
function Ebon:Tint(r, g, b, ring, stripe)
	local kit = self.kit
	local cr, cg, cb = r, g, b
	if not ring then cr, cg, cb = RUNEFROST[1], RUNEFROST[2], RUNEFROST[3] end
	local vr, vg, vb = r, g, b
	if not stripe then vr, vg, vb = RUNEFROST[1], RUNEFROST[2], RUNEFROST[3] end
	self:Fire(cr, cg, cb)
	local hr, hg, hb = kit.Tint(cr, cg, cb, 0.45)
	Colour(self.halo, hr, hg, hb)
	local lr, lg, lb = kit.Tint(vr, vg, vb, 0.55)
	local fr, fg, fb = kit.Tint(vr, vg, vb, FLASH_WHITE)
	for i = 1, #RUNE_AT do
		Colour(self.runes[i], vr, vg, vb)
		Colour(self.runeGlow[i], vr, vg, vb)
		Colour(self.runeLit[i], lr, lg, lb)
		Colour(self.runeHot[i], fr, fg, fb)
	end
	local wr, wg, wb = kit.Tint(cr, cg, cb, FLASH_WHITE)
	Colour(self.hot, wr, wg, wb)
	Colour(self.forge, wr, wg, wb)
	Colour(self.runner, fr, fg, fb)
	Colour(self.star, fr, fg, fb)
	for _, t in ipairs(self.sparks) do Colour(t, fr, fg, fb) end
	for _, t in ipairs(self.glints) do Colour(t, FORGELIGHT[1], FORGELIGHT[2], FORGELIGHT[3]) end
	for _, t in ipairs(self.sheen) do Colour(t, FORGELIGHT[1], FORGELIGHT[2], FORGELIGHT[3]) end
	for _, t in ipairs(self.wisps) do Colour(t, VAPOUR_WHITE[1], VAPOUR_WHITE[2], VAPOUR_WHITE[3]) end
	for _, t in ipairs(self.vapour) do Colour(t, VAPOUR_WHITE[1], VAPOUR_WHITE[2], VAPOUR_WHITE[3]) end
	-- The reason line: a pale haze taken most of the way to the reason, held
	-- to a strong contrast on the blued steel.
	local sr = HAZE[1] + (r - HAZE[1]) * 0.6
	local sg = HAZE[2] + (g - HAZE[2]) * 0.6
	local sb = HAZE[3] + (b - HAZE[3]) * 0.6
	sr, sg, sb = kit.Legible(sr, sg, sb, SUB_CONTRAST)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	Colour(self.glyph, sr, sg, sb)
	self.tint = { cr, cg, cb }
end

function Ebon:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	-- A refusal put the blade out: it is lit again here, and a fight keeps
	-- the icon grey.
	local was = self.refused
	self.refused = nil
	if mode == "off" then
		self:Tint(RUNEFROST[1], RUNEFROST[2], RUNEFROST[3], false, false)
	else
		self:Tint(r, g, b, mode == "icon" or mode == "both", mode == "stripe" or mode == "both")
	end
	if was then self:Mend() end
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The blade holds; everything that moves stops and the lights go out, the
-- steel dulls, the icon greys and the words dim. The soulfire, the eyes, the
-- socket and the runes keep their colour: the reason is the one coloured
-- thing left.
function Ebon:Combat(on)
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
	if not self.refused then
		for _, t in ipairs(self.runeGlow) do t:SetAlpha(on and GLOW.combat or GLOW.rest) end
	end
	self:Breath()
	self:Idle()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breath, let go: held lit once it has breathed its fill (`spent`), else
-- at rest.
function Ebon:HoldPulse(spent)
	StopAll(self.pulse)
	self.halo:SetAlpha(spent and HALO.held or HALO.rest)
	for _, t in ipairs(self.runeGlow) do t:SetAlpha(spent and GLOW.held or GLOW.rest) end
end

-- The lights the flourishes share are one set of regions: one plays at a
-- time. The notch is not a light: it stands until the blade is mended.
function Ebon:StopLights()
	StopAll(self.arrive)
	StopAll(self.landing)
	StopAll(self.gutter)
	self.snuff:Stop()
	self.forgeSheet:Stop()
end

function Ebon:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	local was = self.owed
	self.owed = true
	if not was then
		self:Breath()
		self:Idle()
	end
	-- A refusal put the blade out: nothing kindles or breathes until the
	-- next PaintReason lights it.
	if self.refused then
		StopAll(self.pulse)
		self.halo:SetAlpha(0)
		return
	end
	if isNew then
		self.pulseSpent, self.calmLit = nil, nil
		-- The runes kindle for a new favour, never a new face.
		if full and self.runesOK then
			self:StopLights()
			StopAll(self.calm)
			self:Breath()
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
		-- Calm: one fade up to the held light, and nothing loops or plays.
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
		self.halo:SetAlpha(HALO.rest)
		for _, t in ipairs(self.runeGlow) do t:SetAlpha(GLOW.rest) end
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly. The
	-- runes lit and the soulfire tall are what say "owed" after.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Ebon.pulseGen or not Ebon.active then return end
			Ebon.pulseSpent = true
			if Ebon.pulse[1]:IsPlaying() then
				Ebon:HoldPulse(true)
				-- Settled: the point says so, once.
				Ebon:Greet()
			end
		end)
	end
end

function Ebon:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	StopAll(self.pulse)
	StopAll(self.calm)
	StopAll(self.once)
	StopAll(self.arrive)
	self.halo:SetAlpha(HALO.rest)
	for _, t in ipairs(self.runeGlow) do
		t:SetAlpha((self.refused and 0) or (self.combat and GLOW.combat) or GLOW.rest)
	end
	self.calmLit = nil
	-- Run by nearly every scan: the lights are put back only when somebody
	-- was owed.
	local was = self.owed
	self.owed = nil
	if was then self:Breath() end
	if self.active then self:Idle() end
end

function Ebon:Flourish(kind)
	local shown = self.kit.icon:IsShown()
	-- A refusal puts the blade out: the runes gutter, point to guard, a wisp
	-- leaving each; the soulfire is snuffed, the eyes go dark, a notch
	-- stands in the upper edge, the steel goes dull and one ring snaps in
	-- onto the socket. The text's shake is Prompt's.
	if kind == "failed" then
		local lit = not self.refused
		self.refused = true
		self:StopLights()
		StopAll(self.pulse)
		StopAll(self.calm)
		StopAll(self.once)
		-- Nothing glints on a blade put out.
		StopAll(self.greet)
		if not self.combat and lit then
			if self.runesOK then
				PlayAll(self.gutter)
				PlayAll(self.aftermath)
			end
			if shown then
				self.snuff:Stop()
				self.snuff:Play()
			end
			if self.notchOK then
				self.notchIn:Stop()
				self.notchIn:Play()
			end
		end
		self:Spend()
		if shown then self.fx:Refuse(1.00, 0.40, 0.34, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	self:StopLights()
	-- Sparks fly from the blade's edge and the point glints.
	PlayAll(self.sparkAnims)
	self.tipAnim:Stop()
	self.tipAnim:Play()
	if self.runesOK then PlayAll(self.strike) end
	if shown then
		-- The runeforge: the socket white-hot, the ring, the lance.
		self.forgeAnim:Stop()
		self.forgeAnim:Play()
		self.forgeSheet:Play()
		self.hotAnim:Stop()
		self.hotAnim:Play()
		local t = self.tint or OUTCOME.cast
		self.fx:Land(t[1], t[2], t[3], 0.70)
	end
end

function Ebon:StopFlourishes()
	self:StopLights()
	self.fx:Stop()
end

function Ebon:Hover(on)
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
-- the eye never has to find the person again. The light over the socket
-- takes the outcome's colour.
function Ebon:PaintOutcome(kind, lead, sub, who, stamp)
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
	Colour(self.halo, o[1], o[2], o[3])
	self.refused = kind == "failed"
	if self.refused then
		self:Spend()
	elseif not self.combat then
		self.halo:SetAlpha(HALO.held)
	end
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

function Ebon:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- A plate of the same steel under the blade (or over it), from the guard to
-- where the runes begin; each row wears a small lozenge in its reason's
-- colour.
function Ebon:PaintQueue(rows, shown, above)
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
			-- The vapour rolls again where the list hung.
			self:Breath()
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
	-- No vapour rolls into the list.
	self:Breath()
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
