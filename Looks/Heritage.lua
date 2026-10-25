-- Manners -- the Heritage look: the prompt as the game's first interface would
-- have drawn it.
--
-- A dark marbled stone ground in a beaded gold frame with a boss in each
-- corner, the way the original dialogs and tooltips were framed. The spell
-- icon sits in a bevelled slot like an action button's: a socket, the button's
-- rim over its edge, a gloss from the upper left. The name is the game's own
-- gold; the reason is the plain light grey of a tooltip's second line. It is
-- still at rest, and moves in the idiom of the action bars:
--   * owed: the button's proc glow, and the gold of the frame, breathe three
--     times and settle;
--   * arriving: the panel fades in (Prompt's entrance) and the frame catches
--     the light, a glint running along its top;
--   * landed: the spell-activation flash on the icon, a ring of light spreading
--     from the slot, the frame brightening for a moment;
--   * refused: the icon takes the red of an out-of-range button, a ring snaps
--     in onto the slot, the frame flares red, and the text shakes (Prompt's);
--   * the cooldown is the action button's own dark clockwise sweep, square.
-- "Calm" is fades only: the entrance, and nothing loops or moves.
--
-- Where the reason lives:
--   * the slot's tint: a thin ring just inside the rim in the reason colour,
--     as an equipped item's button wears its coloured border (the "ring");
--   * a status bar along the foot of the frame in the reason colour, like a
--     casting bar's, which empties as the time to return a favour runs out
--     (the "stripe", and what carries the reason with the icon off);
--   * the reason line, warmed a little towards the same colour.
--
-- Every region is a texture from Textures/Heritage (tools/make_heritage_textures.py),
-- none of the client's: a game texture cannot be drawn by the preview, and the
-- clients do not keep the same ones. The gold is baked, because it is
-- decoration; what means something -- the tint, the bar, the gems, the lights
-- -- is white or grey art coloured by SetVertexColor, so one file serves all
-- six reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- Rules it keeps:
--   * no additive light at rest: the lights are ADD, parked at nothing, and
--     none stays lit for long (the breath is three breaths and a rest, a
--     flourish is gone within 0.6 s). tools/render_prompt.py draws ADD far
--     more gently than the client does;
--   * the text stands on stone: nothing is drawn under the lines but the
--     ground, and the stone is dark enough for the dimmest reason line;
--   * the icon is square whatever "Round the icon off" says: an action button
--     is square, and the slot sizes the icon from the panel's height (Options
--     says so), so the whole look takes clicks and the drag;
--   * a class-coloured name is taken two-fifths of the way to white, so the
--     darker classes read on the stone.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Heritage\\Heritage_"

local Heritage = ns.Looks.Register("heritage", {
	name = L["Heritage -- stone and gold, like the first interface"],
	order = 5,
	-- The frame holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	-- The stone is darker than the panels the class colours were picked for:
	-- a name is taken part of the way to white, so a death knight's red and a
	-- warlock's purple still read on it.
	classSoften = 0.40,
})

-- The frame's geometry as fractions of its corner piece (the 256-texel file
-- is cut at 64): where the gold ends, and where the dark line inside it does.
-- BAND and INNER_DARK in tools/make_heritage_textures.py, which must agree.
local BAND, INNER_DARK = 24 / 64, 26.4 / 64
-- The slot's rim ends here as a fraction of its corner piece (16 texels): SLOT_RIM
-- in the generator. The tint ring lies just inside it.
local SLOT_RIM = 5.2 / 16
-- The ground's own tint, for a panel colour nobody chose: the marble file is
-- grey, mean about 0.6, so these give a stone whose mean is a dark slate.
local STONE_TOP, STONE_BOTTOM, STONE_ALPHA = { 0.30, 0.30, 0.335 }, { 0.215, 0.215, 0.245 }, 1
-- How much of a chosen panel colour the marble's grey takes away: its mean.
local STONE_MEAN = 0.60
-- The slot's share of the proc glow's file (PROC_AT in the generator).
local PROC_AT = 0.64
-- The game's own gold for a name, the tooltip's grey for the reason.
local NAME_GOLD = { 1.00, 0.82, 0.00 }
local SUB_GREY = { 0.82, 0.82, 0.80 }
local PALE_GOLD = { 1.00, 0.86, 0.52 }
local WARM_GOLD = { 1.00, 0.84, 0.50 }
local IRON = { 0.62, 0.62, 0.64 }
-- The reason ring and the bar with the marker off.
local NEUTRAL = { 0.52, 0.46, 0.38 }
-- The outcomes' own colours.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
-- The icon of an out-of-range button, and what a fight does to the text and icon.
local OUT_OF_RANGE = { 1.00, 0.36, 0.32 }
local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70
-- The owed breath: the glow lit to these and back, this many breaths of
-- 2.6 s, then it settles.
local PROC_PEAK, FRAME_PEAK = 0.32, 0.20
local BREATHS = 3
local BREATH = 1.3
-- The longest an additive flourish may stay lit, in seconds.
local FLOURISH = 0.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize) return math.max(1.5, fontSize * 0.16) end

-- The frame's corner piece for a panel `H` high: the gold's width is BAND of it.
local function Corner(H) return Clamp(math.floor(H * 0.28 + 0.5), 11, 24) end
-- The frame's inner clear edge, and the gap between it and the slot.
local function Band(H) return Corner(H) * BAND end
local function SlotGap(H) return math.max(1.5, H * 0.035) end

-- The slot and its icon for a panel `H` high, in UI units: the slot's size,
-- its rim's width and the icon's size.
local function SlotSize(H, W)
	local s = H - 2 * (Band(H) + SlotGap(H))
	-- A narrow panel keeps the room for its name: the slot is never more than
	-- a third of the width, nor smaller than a button can be read at.
	if W then s = math.min(s, math.max(18, W * 0.34)) end
	local rim = Clamp(s * 0.065, 1.2, 2.4)
	return s, rim, math.floor(s - 2 * rim + 0.5)
end

-- The height the bar's room takes from the lines, and its gap to the frame.
local function BarHeight(H) return Clamp(math.floor(H * 0.07 + 0.5), 3, 5) end

-- The room the lines have between the frame and the bar, at height `h`.
local function LineRoom(h)
	return h - 2 * Band(h) - 5.1 - BarHeight(h)
end

-- The height two lines need on this look: the block, the frame's two bands,
-- and the bar under them.
function Heritage.TwoLineHeight(fontSize)
	local block = fontSize + Gap(fontSize) + SubSize(fontSize)
	for h = 28, 200 do
		if LineRoom(h) >= block + 1.5 then return h end
	end
	return 200
end

-- The slot's tint carries the reason with the icon on, the bar without it or
-- on "stripe"; nothing does with the marker off.
local function Carriers(p)
	local mode = p.accentMode or "icon"
	local icon = p.showIcon and true or false
	local ring = icon and (mode == "icon" or mode == "both")
	local bar = mode ~= "off" and (mode == "stripe" or mode == "both" or not icon)
	return ring, bar
end

function Heritage.AccentCarriers(p)
	return Carriers(p)
end

-- The slot sizes the icon from the panel's height, so Options says so.
function Heritage.IconSize(p)
	local _, _, icon = SlotSize(p.height or 44, p.width)
	return icon
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

-- The luminance of the stone at its brightest end, where the lines stand: the
-- file's brightest hundredth, tinted as the look tints it, and the light
-- that can lie over the lines (tests/scenarios/look-heritage.lua reads the
-- file and holds this to it).
local GROUND = 0.056

local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

-- A colour taken towards white until it reads on the stone at `minimum`:
-- Prompt's own Legible judges against the dark panel it assumes, which the
-- stone is brighter than.
local function Lift(r, g, b, minimum)
	local function ratio(t)
		local l = 0.2126 * Linear(r + (1 - r) * t) + 0.7152 * Linear(g + (1 - g) * t) + 0.0722 * Linear(b + (1 - b) * t)
		return (l + 0.05) / (GROUND + 0.05)
	end
	if ratio(0) >= minimum then return r, g, b end
	local lo, hi = 0, 1
	for _ = 1, 12 do
		local t = (lo + hi) / 2
		if ratio(t) >= minimum then hi = t else lo = t end
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
-- pieces
---------------------------------------------------------------------------

-- A frame cut from one file: corners from the outer quarters, edges from a
-- thin middle strip, so they stretch without warping. TL T TR L R BL B BR.
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.46, 0.54, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.46, 0.54 }, { 0.75, 1, 0.46, 0.54 },
	{ 0, 0.25, 0.75, 1 }, { 0.46, 0.54, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
}

local function Pieces(parent, layer, sublevel, file, blend, keep)
	local s = {}
	for i = 1, 8 do
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

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down, delay, smoothing)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, 0, peak, up, 1, delay, "OUT")
	g.down = Alpha(g, peak, 0, down, 2, nil, smoothing or "OUT")
	Park(g, region, 0)
	return g
end

-- A glint along the frame: in, along, out, all within FLOURISH of its start.
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
	local function frame(level)
		local f = keep(CreateFrame("Frame", nil, art))
		f:SetFrameLevel(art:GetFrameLevel() + level)
		return f
	end

	-- The ground: stone, on art itself, below the icon and the list's rows
	-- (which are art's too); the drawer's own stone under the list.
	self.drawerVeil = tex(art, "BACKGROUND", -9, "White")
	self.veil = tex(art, "BACKGROUND", -8, "White")
	self.drawerStone = tex(art, "BACKGROUND", -7, "Stone")
	self.stone = tex(art, "BACKGROUND", -6, "Stone")
	self.drawer = Pieces(art, "BORDER", 2, ART .. "Frame", nil, keep)
	self.frame = Pieces(art, "BORDER", 3, ART .. "Frame", nil, keep)

	-- The frame catching the light: its gilding, as light, on frames of their
	-- own (so one animation lights all eight pieces): one for a flourish (the
	-- arrival, a landing, a refusal), one that breathes while somebody is owed.
	self.flareFrame = frame(1)
	self.flareFrame:SetAlpha(0)
	self.flare = Pieces(self.flareFrame, "ARTWORK", 0, ART .. "FrameGlow", "ADD", keep)
	self.breathFrame = frame(1)
	self.breathFrame:SetAlpha(0)
	self.breath = Pieces(self.breathFrame, "ARTWORK", 0, ART .. "FrameGlow", "ADD", keep)
	-- A glint along the top of the frame, for a new favour.
	self.glint = tex(art, "BORDER", 6, "Glint", "ADD")
	self.glint:SetAlpha(0)

	-- The rings that spread from the slot when a buff lands and the one that
	-- snaps in when one is refused, in frames over the art and under the text.
	-- No echo: the icon stays clean.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do keep(f) end
	kit.RingArt(ART .. "Ring", 0.74, 0.89)

	-- The slot: the proc glow that breathes behind it, the socket under the
	-- icon (ARTWORK 0), then over the icon the tint, the rim and the gloss.
	self.proc = tex(art, "ARTWORK", -5, "Proc", "ADD")
	self.ringWarm = tex(art, "ARTWORK", -4, "Proc", "ADD")
	self.socket = tex(art, "ARTWORK", -2, "SlotBack")
	self.proc:SetAlpha(0)
	self.ringWarm:SetAlpha(0)
	self.tint = Pieces(art, "ARTWORK", 1, ART .. "SlotTint", nil, keep)
	self.rim = Pieces(art, "ARTWORK", 2, ART .. "Slot", nil, keep)
	self.gloss = tex(art, "ARTWORK", 3, "Gloss")
	-- The spell-activation flash on the icon, the cursor's light on it, and
	-- the red of a refusal: flat fills over the icon.
	self.flash = tex(art, "ARTWORK", 4, "White", "ADD")
	self.hilite = tex(art, "ARTWORK", 4, "White")
	self.flash:SetAlpha(0)
	self.hilite:SetAlpha(0)

	-- The bar along the foot: a dark track, and the fill over it.
	self.track = tex(art, "ARTWORK", 0, "White")
	self.fill = tex(art, "ARTWORK", 1, "White")
	self.barLight = tex(art, "ARTWORK", 2, "White")

	-- The list's gems, one per row.
	self.gems, self.gemSets = {}, {}
	for i = 1, #kit.rows do
		self.gems[i] = tex(art, "ARTWORK", 1, "Gem")
		self.gemSets[i] = tex(art, "ARTWORK", 2, "GemSet")
	end

	-- The count's chip, over the stone; its text is on textLayer, over it.
	local base = art:GetFrameLevel()
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	for _, f in ipairs(self.fx.frames) do f:SetFrameLevel(base + 2) end

	-- Everything gold, for the iron of a fight.
	self.gold = {}
	for _, s in ipairs({ self.frame, self.drawer, self.rim, self.chip, self.keyChip, self.gemSets }) do
		for _, t in ipairs(s) do self.gold[#self.gold + 1] = t end
	end

	self:BuildAnimations(anim)
end

function Heritage:BuildAnimations(anim)
	-- The owed breath: the slot's proc glow in the reason's colour, the same
	-- glow warmed towards pale gold, and the frame's own gold, on one breath
	-- (2.6 s round); see Attention for how many.
	local proc = self.proc:CreateAnimationGroup()
	proc:SetLooping("BOUNCE")
	Alpha(proc, 0, PROC_PEAK, BREATH, 1, nil, "IN_OUT")
	local warm = self.ringWarm:CreateAnimationGroup()
	warm:SetLooping("BOUNCE")
	Alpha(warm, 0, 1, BREATH, 1, nil, "IN_OUT")
	local frame = self.breathFrame:CreateAnimationGroup()
	frame:SetLooping("BOUNCE")
	Alpha(frame, 0, FRAME_PEAK, BREATH, 1, nil, "IN_OUT")
	self.pulse = { anim(proc), anim(warm), anim(frame) }

	-- The frame catches the light as a favour arrives, and as a buff lands or
	-- is refused; and a glint runs along the top for a favour.
	self.arrive = { anim(Flash(self.flareFrame, 0.55, 0.10, 0.42)) }
	self.flareAnims = self.arrive
	self.sweep = { anim(Travel(self.glint, 0.04)) }
	-- The activation flash on the icon: quick up, slower down.
	self.flashAnims = { anim(Flash(self.flash, 0.55, 0.07, 0.30)) }
	-- The first of the two rings, which the scenarios watch for a landed buff.
	self.burstAnim = self.fx.rings[1].land

	-- The cursor's light on the icon, both ways; from and to are set for each
	-- play.
	local hover = self.hilite:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, nil, "OUT")
	Park(hover, self.hilite, 0)
	self.hoverAnims = { anim(hover) }
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
	local ringOn, barOn = Carriers(p)
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	self.ringOn, self.barOn = ringOn, barOn
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua).
	self.pitch = sub + 6

	local C = Corner(H)
	local e = Band(H)
	local g = SlotGap(H)
	self.C, self.e = C, e

	-- The ground, inset a unit inside the frame's rounded corners. The stone's
	-- grey has a mean of about 0.6, so a dark panel colour tints it to that
	-- colour; a light one cannot (a vertex colour only darkens), and is laid
	-- as a flat fill with the stone's veins faintly over it.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local tr, tg, tb, ta, br, bg, bb
	local light = false
	if Untouched(c, d) then
		tr, tg, tb, ta = STONE_TOP[1], STONE_TOP[2], STONE_TOP[3], STONE_ALPHA
		br, bg, bb = STONE_BOTTOM[1], STONE_BOTTOM[2], STONE_BOTTOM[3]
	else
		local r, g, b = c[1] or 0, c[2] or 0, c[3] or 0
		ta = c[4] == nil and 1 or c[4]
		light = 0.299 * r + 0.587 * g + 0.114 * b > STONE_MEAN * 0.75
		if light then
			tr, tg, tb = r, g, b
			br, bg, bb = r * 0.80, g * 0.80, b * 0.82
		else
			local k = 1 / STONE_MEAN
			tr, tg, tb = math.min(1, r * k), math.min(1, g * k), math.min(1, b * k)
			br, bg, bb = tr * 0.72, tg * 0.72, tb * 0.74
		end
	end
	self.light = light
	if light then
		kit.Gradient(self.veil, "VERTICAL", br, bg, bb, ta, tr, tg, tb, ta)
		kit.Gradient(self.drawerVeil, "VERTICAL", br * 0.94, bg * 0.94, bb * 0.94, ta, tr * 0.97, tg * 0.97, tb * 0.97, ta)
		kit.Gradient(self.stone, "VERTICAL", 1, 1, 1, ta * 0.30, 1, 1, 1, ta * 0.30)
		kit.Gradient(self.drawerStone, "VERTICAL", 1, 1, 1, ta * 0.30, 1, 1, 1, ta * 0.30)
	else
		kit.Gradient(self.stone, "VERTICAL", br, bg, bb, ta, tr, tg, tb, ta)
		kit.Gradient(self.drawerStone, "VERTICAL", br * 0.92, bg * 0.92, bb * 0.92, ta, tr * 0.94, tg * 0.94, tb * 0.94, ta)
	end
	Box(self.stone, art, 1, 1, W - 1, H - 1)
	Box(self.veil, art, 1, 1, W - 1, H - 1)

	PlacePieces(self.frame, art, 0, 0, W, H, C)
	PlacePieces(self.flare, art, 0, 0, W, H, C)
	PlacePieces(self.breath, art, 0, 0, W, H, C)
	Each(self.flare, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	Each(self.breath, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	self.drawnList = nil

	-- The slot, vertically centred, inside the frame.
	local S, rim, iconSize = SlotSize(H, W)
	local sx = e + g + 1.5
	local cx, cy = sx + S / 2, H / 2
	self.S, self.cx, self.cy, self.iconSize = S, cx, cy, iconSize
	local sc = Clamp(rim / SLOT_RIM, 4, 12)
	-- Where the lines start: after the slot, and the rings' room ends there.
	local textX = showIcon and (sx + S + 7) or math.floor(e + 9 + 0.5)
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	if showIcon then
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		Box(self.socket, art, sx, cy - S / 2, sx + S, cy + S / 2)
		PlacePieces(self.rim, art, sx, cy - S / 2, sx + S, cy + S / 2, sc)
		PlacePieces(self.tint, art, sx, cy - S / 2, sx + S, cy + S / 2, sc)
		Box(self.gloss, art, cx - iconSize / 2, cy - iconSize / 2, cx + iconSize / 2, cy + iconSize / 2)
		self.gloss:SetVertexColor(1, 1, 1, 0.22)
		for _, t in ipairs({ self.flash, self.hilite }) do
			Box(t, art, cx - iconSize / 2, cy - iconSize / 2, cx + iconSize / 2, cy + iconSize / 2)
		end
		self.flash:SetVertexColor(1, 0.92, 0.60, 1)
		self.hilite:SetVertexColor(1, 0.88, 0.50, 0.22)
		-- The proc glow hugs the slot: its file is PROC_AT slot.
		for _, t in ipairs({ self.proc, self.ringWarm }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
			t:SetSize(S / PROC_AT, S / PROC_AT)
		end
		self.ringWarm:SetVertexColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 0.20)
		-- The rings spread from the slot's rim, in the rounded square's art.
		self.fx:Place(icon, (1.34 * S - iconSize) / 2, iconSize)
		self.fx:Shape(false, ART .. "Ring", ART .. "Ring")
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- Square: the action button's sweep, dark and clockwise.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(ART .. "White") end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end
		end
	end
	self.textX = textX

	-- The bar along the foot of the frame.
	local barH = BarHeight(H)
	self.barH = barH
	local barBottom = H - e - 1.8
	local barTop = barBottom - barH
	self.barX0, self.barX1 = textX, W - e - 6
	self.barLen = math.max(8, self.barX1 - self.barX0)
	self.barTop, self.barBottom = barTop, barBottom
	Box(self.track, art, self.barX0 - 0.7, barTop - 0.7, self.barX1 + 0.7, barBottom + 0.7)
	self.track:SetVertexColor(0, 0, 0, 0.62)
	self.fill:ClearAllPoints()
	self.fill:SetPoint("TOPLEFT", art, "TOPLEFT", self.barX0, -barTop)
	self.fill:SetHeight(barH)
	self.fill:SetWidth(self.barLen)
	-- The bar lit from above: a darker foot, a paler head.
	kit.Gradient(self.fill, "VERTICAL", 0.62, 0.62, 0.62, 1, 1, 1, 1, 1)
	self.barLight:ClearAllPoints()
	self.barLight:SetPoint("TOPLEFT", self.fill, "TOPLEFT", 0, 0)
	self.barLight:SetHeight(math.max(0.8, barH * 0.28))
	self.barLight:SetWidth(self.barLen)
	self.barLight:SetVertexColor(1, 1, 1, 0.22)
	self.barW = nil

	-- The text block, centred between the frame and the bar.
	local top = e + 1.5
	local bottom = barTop - 1.8
	local mid = (top + bottom) / 2
	local gap = Gap(fs)
	local block = fs + gap + sub
	self.shift = H / 2 - mid
	self.nameY = self.shift + block / 2 - fs / 2 + 0.5
	self.subY = self.shift - (block / 2 - sub / 2) + 0.5

	-- The chips are as tall as a line and its air, and never taller than the
	-- room between the frame and the bar.
	local chipH = math.max(8, math.min(sub + 6, math.floor(bottom - top - 1)))
	self.chipH = chipH
	PlaceThree(self.chip, self.chipBox, chipH)
	self.chipBox:ClearAllPoints()
	self.chipBox:SetPoint("RIGHT", art, "RIGHT", -(e + 5), self.shift)
	self.chipBox:SetSize(chipH * 1.75, chipH)
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -(e + 5), self.shift)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.countText, self.keyLabel = nil, nil

	local base = art:GetFrameLevel()
	self.chipFrame:SetFrameLevel(base + 3)
	self.flareFrame:SetFrameLevel(base + 1)
	self.breathFrame:SetFrameLevel(base + 1)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The glint runs along the frame's top rail.
	local gw, gh = math.max(24, H * 0.9), math.max(5, e * 1.7)
	self.glint:ClearAllPoints()
	self.glint:SetPoint("CENTER", art, "TOPLEFT", C, -(e * 0.5))
	self.glint:SetSize(gw, gh)
	self.glint:SetVertexColor(1, 0.92, 0.66, 0.9)
	self.sweep[1].move:SetOffset(math.max(10, W - 2 * C), 0)

	self.rowX = textX
	local rowWidth = math.max(20, W - self.rowX - e - 8)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chip for Chip, the bar for PaintReason.
	for _, x in ipairs(self.own) do x:Show() end
	for _, t in ipairs({ self.proc, self.ringWarm, self.socket, self.gloss, self.flash, self.hilite }) do
		t:SetShown(showIcon)
	end
	Each(self.rim, "SetShown", showIcon)
	Each(self.tint, "SetShown", showIcon and ringOn)
	self.fx:SetShown(showIcon)
	-- The bar comes up with the first Clock of a paint.
	self.track:Hide()
	self.fill:Hide()
	self.barLight:Hide()
	self.barUp = false
	Each(self.drawer, "Hide")
	self.drawerStone:Hide()
	self.drawerVeil:Hide()
	self.veil:SetShown(self.light)
	for i = 1, #self.gems do
		self.gems[i]:Hide()
		self.gemSets[i]:Hide()
	end
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self:Iron(false)
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset.
	return textX, math.ceil(chipH * 1.75) + e + 9
end

function Heritage:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen and ink.light then
		-- The game's gold, held to the same contrast as any other line.
		local r, g, b = Lift(NAME_GOLD[1], NAME_GOLD[2], NAME_GOLD[3], 4.5)
		kit.name:SetTextColor(r, g, b, 1)
	end
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 0.95)
		kit.name:SetShadowOffset(1, -1)
		kit.sub:SetShadowColor(0, 0, 0, 0.9)
		kit.sub:SetShadowOffset(1, -1)
	end
	-- The chip is dark whatever the panel, so its text is pale gold as it is.
	kit.count:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	if ink.light then
		local r, g, b = Lift(0.90, 0.89, 0.84, 4.5)
		for _, fs in ipairs(kit.rows) do
			fs:SetTextColor(r, g, b, 1)
			fs:SetShadowColor(0, 0, 0, 0.9)
			fs:SetShadowOffset(1, -1)
		end
		ink.rowReason = "|cffa4a399"
	end
end

function Heritage:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
	for _, t in ipairs({ self.proc, self.ringWarm, self.flash, self.hilite, self.glint }) do t:SetAlpha(0) end
	self.flareFrame:SetAlpha(0)
	self.breathFrame:SetAlpha(0)
	for _, x in ipairs(self.own) do x:Hide() end
	self.pulseGen = (self.pulseGen or 0) + 1
	-- The shared regions, as the other looks expect to find them.
	local icon = kit.icon
	icon:SetAlpha(1)
	icon:SetVertexColor(1, 1, 1)
	icon:SetDesaturated(false)
	if kit.cooldown then kit.cooldown:SetAlpha(1) end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	kit.sub:SetShadowOffset(0, 0)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the chip
---------------------------------------------------------------------------

function Heritage:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local inset = math.max(right, self.e + 6)
	if self.keyUp then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
	if self.countMode == "chip" then inset = math.max(inset, self.chipRoom or 0) end
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
		name:SetPoint("LEFT", self.textX, self.shift)
		name:SetPoint("RIGHT", -inset, self.shift)
	end
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
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
	return width * least / size <= self.W - self.textX - math.max(room, self.e + 6) + 0.5
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

-- The room the lines leave at the right for the key's chip with the count's
-- beside it: the key's room, a two-digit chip and the gap between them.
function Heritage:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint, which is also the bar's tick. The count's chip at the
-- right, or, with the key's chip there, a chip beside the key's; the key's
-- chip when a key is bound. Either steps aside for a paint in which the name
-- would otherwise be cut.
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
			self.keyW, self.keyRoom = w, math.ceil(w) + self.e + 9
			-- A key bound anew is a chip of a new width: Prompt places the
			-- lines again, beside it.
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
		if keyUp then
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(kit.fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		local h = self.chipH
		text = count:GetText()
		if text ~= self.countText or mode ~= self.countMode then
			self.countText = text
			self.countW = math.max(h * 1.75, (kit.TextWidth(count) or self.sub) + 10)
			self.chipRoom = math.ceil(self.countW) + self.e + 9
		end
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -(self.e + 5), self.shift)
			end
			count:ClearAllPoints()
			count:SetPoint("CENTER", self.chipBox, "CENTER", 0, 0)
		end
		self.chipBox:SetSize(math.floor(self.countW + 0.5), h)
	end
	self.countMode = mode
	for _, t in ipairs(self.chip) do t:SetShown(mode ~= nil) end
	kit.count:SetShown(mode ~= nil)
	-- Only a chip at the right takes room from the lines; PlaceLines gives a
	-- pair the room of both.
	return mode == "chip" or mode == "pair"
end

-- The bar's fill: how much of the time to return the favour is left, burning
-- down from the right; full, and quieter, where the bar only carries the
-- reason, and not there at all for anybody else when the ring carries it. A
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
	local up = (self.barOn or live) and true or false
	local width = math.max(1.2, (frac or 1) * self.barLen)
	if self.barUp == up and self.barLive == live and self.barW and math.abs(width - self.barW) < 0.25 then return end
	if self.barUp ~= up then
		self.barUp = up
		self.track:SetShown(up)
		self.fill:SetShown(up)
		self.barLight:SetShown(up)
	end
	self.barW, self.barLive = width, live
	self.fill:SetWidth(width)
	self.barLight:SetWidth(width)
	self:BarAlpha()
end

-- The fill's strength: lit for a favour with a clock, quieter for the rest,
-- dimmed in a fight.
function Heritage:BarAlpha()
	local k = self.combat and 0.7 or 1
	self.fill:SetAlpha((self.barLive and 0.95 or 0.62) * k)
	self.barLight:SetAlpha(k)
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The ring, the bar and the reason line in one colour. An outcome leaves the
-- bar's length alone: it is about the favour, not the click.
function Heritage:Tint(r, g, b, outcome)
	local kit = self.kit
	for _, t in ipairs(self.tint) do t:SetVertexColor(r, g, b, 1) end
	for _, t in ipairs({ self.fill }) do
		kit.Gradient(t, "VERTICAL", r * 0.62, g * 0.62, b * 0.62, 1, math.min(1, r * 1.08), math.min(1, g * 1.08),
			math.min(1, b * 1.08), 1)
	end
	-- The proc glow in the colour a little paler, so it reads as light.
	local pr, pg, pb = kit.Tint(r, g, b, 0.25)
	self.proc:SetVertexColor(pr, pg, pb, 1)
	-- The reason line: the tooltip's grey taken part of the way to the colour,
	-- held to its contrast; on a light panel the plain grey, which the tint
	-- would cost.
	local sr, sg, sb
	if not kit.ink.light then
		local s = kit.ink.sub or SUB_GREY
		sr, sg, sb = s[1], s[2], s[3]
	else
		local k = outcome and 0.6 or 0.38
		sr = SUB_GREY[1] + (r - SUB_GREY[1]) * k
		sg = SUB_GREY[2] + (g - SUB_GREY[2]) * k
		sb = SUB_GREY[3] + (b - SUB_GREY[3]) * k
	end
	if kit.ink.light then
		sr, sg, sb = Lift(sr, sg, sb, 4.5)
	else
		sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	end
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.tinted = { r, g, b }
end

function Heritage:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		-- The glow's own colour: the warm white of a lit button.
		self.proc:SetVertexColor(WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
	else
		self:Tint(r, g, b)
	end
	-- A refusal reddened the icon; a fight keeps it dim.
	self.refused = nil
	local k = self.combat and ICON_COMBAT or 1
	self.kit.icon:SetVertexColor(k, k, k)
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Heritage:Iron(on)
	for _, t in ipairs(self.gold) do
		t:SetDesaturated(on)
		if on then
			t:SetVertexColor(IRON[1], IRON[2], IRON[3], 1)
		else
			t:SetVertexColor(1, 1, 1, 1)
		end
	end
end

-- The frame holds; the gold goes to iron, the icon greys and dims, the text
-- dims and the lights go out. The ring and the bar keep their colour: the
-- reason is the one coloured thing left.
function Heritage:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Iron(on)
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	local v = on and ICON_COMBAT or 1
	if self.refused then
		kit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)
	else
		kit.icon:SetVertexColor(v, v, v)
	end
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	self:BarAlpha()
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
	self.proc:SetAlpha(0)
	self.ringWarm:SetAlpha(0)
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
		-- The frame catches the light for a new favour, never for a new face;
		-- and a glint runs along its top.
		if full then
			Each(self.flare, "SetVertexColor", WARM_GOLD[1], WARM_GOLD[2], WARM_GOLD[3], 1)
			PlayAll(self.sweep)
			PlayAll(self.arrive)
		end
	end
	if flashStyle ~= "pulse" then
		self:StopAttention()
		return
	end
	if not full or self.pulseSpent then
		-- Calm, or breathed its fill: nothing loops.
		self:HoldPulse()
		return
	end
	-- A repaint leaves a running breath alone; a new favour on top keeps the
	-- breathing going but takes its own three breaths, not what is left of the
	-- last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self.proc:SetAlpha(0)
		self.ringWarm:SetAlpha(0)
		self.breathFrame:SetAlpha(0)
		self.pulse[1]:Play()
		self.pulse[2]:Play()
		self.pulse[3]:Play()
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
	self.proc:SetAlpha(0)
	self.ringWarm:SetAlpha(0)
	self.breathFrame:SetAlpha(0)
end

-- The breath's lights are ADD at the peaks set here: the amplitudes ride on
-- the vertex alphas, the animation on the texture's own alpha.
function Heritage:Flourish(kind)
	-- A refusal: the frame flares red and amber, a ring snaps in onto the slot,
	-- and the icon's flash is red. The text's shake is Prompt's.
	if kind == "failed" then
		Each(self.flare, "SetVertexColor", 1, 0.34, 0.20, 1)
		PlayAll(self.flareAnims)
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
	if self.kit.icon:IsShown() then
		-- The spell-activation flash, and the light that goes out from it.
		self.flash:SetVertexColor(1, 0.92, 0.60, 1)
		PlayAll(self.flashAnims)
		self.fx:Land(1.0, 0.88, 0.50, 0.75)
	end
end

function Heritage:StopFlourishes()
	for _, g in ipairs(self.flareAnims) do g:Stop() end
	for _, g in ipairs(self.flashAnims) do g:Stop() end
	self.fx:Stop()
	for _, g in ipairs(self.sweep) do g:Stop() end
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
-- eye never has to find the person again. The ring and the bar take the
-- outcome's colour; a refusal reddens the icon, as an out-of-range button is.
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
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb
	if kit.ink.light then
		vr, vg, vb = Lift(o[1], o[2], o[3], 4.5)
	else
		vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	end
	kit.sub:SetTextColor(vr, vg, vb, 1)
	self.refused = kind == "failed"
	local v = self.combat and ICON_COMBAT or 1
	if self.refused then
		kit.icon:SetVertexColor(OUT_OF_RANGE[1] * v, OUT_OF_RANGE[2] * v, OUT_OF_RANGE[3] * v)
	else
		kit.icon:SetVertexColor(v, v, v)
	end
	kit.icon:SetDesaturated(self.combat and true or false)
	if kit.sub:IsShown() then kit.SetLine(kit.sub, word) end
end

function Heritage:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The drawer hangs off the frame, above or below, as the frame's own
-- continuation: its sides run on from the frame's, and the frame's rail is the
-- divider. Each row wears a gem in its reason's colour.
function Heritage:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.gems do
		if not (list and i <= shown) then
			self.gems[i]:Hide()
			self.gemSets[i]:Hide()
		end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			Each(self.drawer, "Hide")
			self.drawerStone:Hide()
			self.drawerVeil:Hide()
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.gems[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.gems[i]:Show()
		self.gemSets[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch, C, e = self.pitch, self.C, self.e
	-- The drawer is a frame of its own whose row nearest the panel is left
	-- out: the panel's rail stands in for it, and its sides run on from the
	-- panel's. Its interior is the rows and a little air over and under them.
	local depth = e + 3 + shown * pitch + 3
	local y0, y1
	if above then
		y0, y1 = -depth, C
	else
		y0, y1 = self.H - C, self.H + depth
	end
	PlacePieces(self.drawer, art, 0, y0, self.W, y1, C)
	for i = 1, 8 do
		local topRow = i <= 3
		local bottomRow = i >= 6
		self.drawer[i]:SetShown(not ((above and bottomRow) or (not above and topRow)))
	end
	Box(self.drawerStone, art, 1, y0 + 1, self.W - 1, y1 - 1)
	Box(self.drawerVeil, art, 1, y0 + 1, self.W - 1, y1 - 1)
	self.drawerStone:Show()
	self.drawerVeil:SetShown(self.light)

	local gem = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = -3 - (shown - i) * pitch - pitch / 2
		else
			y = self.H + 3 + (i - 1) * pitch + pitch / 2
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		for _, t in ipairs({ self.gems[i], self.gemSets[i] }) do
			t:ClearAllPoints()
			t:SetPoint("CENTER", art, "TOPLEFT", self.rowX - 9, -y)
			t:SetSize(gem, gem)
		end
	end
end
