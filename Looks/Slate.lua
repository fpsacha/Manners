-- Manners -- the Slate look: a contemporary game-HUD card, drawn crisp and
-- still, that moves smoothly when something happens.
--
-- A dark, slightly translucent card with properly rounded corners, a hairline
-- highlight just inside its edge (brightest along the top, where the light
-- falls) and a soft drop shadow. The spell icon sits in a rounded square of its
-- own, hugged by a thin ring in the reason's colour; with "Colour marker" on
-- stripe or both a slim pill down the card's left carries the reason as well.
-- The name is bright and the reason a size smaller, in a muted tone warmed
-- towards its colour. Nothing else is on the card at rest.
--
-- Along the bottom edge runs a thin line, empty unless something is timed:
--   * while the global cooldown runs, a line in the reason's colour burns down
--     over a faint track, to the moment the button is ready ("ready in" says
--     the same in words). It is a Scale animation from the left edge, started
--     from the cooldown's own start and duration (a wrapper on the Cooldown
--     frame, which Prompt drives), so nothing polls and nothing runs on a
--     frame script: it replaces the sweep, which Slate draws at no strength;
--   * a landed buff fills it with green, left to right, once;
--   * a refusal flashes it red-amber and shakes the pill, damped.
--
-- The motion is physical and short:
--   * a favour arriving: the icon pops in (a small overshoot) and the accent
--     pill slides in, with a breath of the reason's light behind the icon;
--   * somebody owed: the light behind the icon and the card's highlight breathe
--     (warm white) a few times and settle;
--   * a landing: two rings spread from the icon, the icon dips and bounces
--     inside its frame, the check pops in beside the verdict, the line fills;
--   * a refusal: a red-amber ring closes on the icon, the line flashes, the
--     pill and the text shake.
-- Calm is fades only: none of the above moves; the cooldown line stays, because
-- it is information.
--
-- Rules it keeps (tests/scenarios/look-slate.lua, readable-*.lua, hunt35 and
-- hunt37): nothing that stays on screen is additive; the light is baked white
-- art coloured by SetVertexColor; the rings and the icon's bounce stay in the
-- room between the icon and the text and inside the card's top and bottom;
-- every frame of light sits under the text's frame level; the secure list
-- names are anchored to frames, never to a region; no pcall per repaint.
-- Every region is a texture from Textures/Slate (tools/make_slate_textures.py).
-- The interface this file implements is described at the top of Looks/Looks.lua.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Slate\\Slate_"

local Slate = ns.Looks.Register("slate", {
	name = L["Slate -- modern card, soft shadow, thin progress line"],
	order = 6,
	-- The card holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.25,
})

-- The icon's corner, as a fraction of its side: ICON_RADIUS in the generator.
-- The ring's width in texels at 64 (RING_TEXELS there): the ring file is drawn
-- so its inner edge is the icon's, which is 58 of its 64 texels across.
local RING_FRACTION = 3 / 58
-- Where the effect rings' line sits in their file and how far out they are
-- seen, as fractions of its half-width (FX_PEAK in the generator, and
-- hunt37-effects reads the files).
local FX_PEAK, FX_EDGE = 0.70, 0.875

-- The card's own slate, for a panel colour nobody chose: a cool dark, a shade
-- lighter at the top. Both ends hold the reason line at 4.5:1.
local SLATE_TOP, SLATE_BOTTOM, SLATE_ALPHA = { 0.088, 0.098, 0.122 }, { 0.058, 0.066, 0.086 }, 0.93
local NAME_INK = { 0.97, 0.98, 1.00 }
local MUTED = { 0.64, 0.68, 0.76 }
local NEUTRAL = { 0.62, 0.67, 0.76 }
local WARM = { 1.00, 0.88, 0.66 }
-- The outcomes' own colours: the line, the ring, the verdict.
local OUTCOME = {
	cast = { 0.40, 0.86, 0.52 },
	failed = { 1.00, 0.40, 0.30 },
	sent = { 0.91, 0.86, 0.60 },
}
-- What a fight does: the text dims, the icon greys and dims.
local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70
-- The owed breath: the light behind the icon lit to this and back, this many
-- breaths of 2.5 s, then it settles.
local PULSE_PEAK, WARM_PEAK = 0.62, 0.40
local BREATHS, BREATH = 3, 1.25
-- How far the icon pops past its size, and the rest of its bounce.
local POP_OVER, DIP = 1.12, 0.90
-- How bright the card's highlight rests (of its colour's strength), and lifts to
-- under the cursor.
local RIM_REST = 0.60
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize) return math.max(1.5, fontSize * 0.16) end

-- The name, the gap and the reason as one block, and the card's room round it
-- and the line along the bottom.
function Slate.TwoLineHeight(fontSize)
	return math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 12)
end

-- The ring carries the reason on "icon" and "both", the pill on "stripe" and
-- "both"; nothing does with the marker off.
function Slate.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false,
		(mode == "stripe" or mode == "both")
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

-- Whether this client reads an English string in its own language: a German
-- player is better served by the lines that are translated than by English.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A frame cut from one file: corners from the outer quarters, edges from a thin
-- strip of the middle, so they stretch without warping. TL T TR L R BL B BR,
-- and a centre when asked for.
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.46, 0.54, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.46, 0.54 }, { 0.75, 1, 0.46, 0.54 },
	{ 0, 0.25, 0.75, 1 }, { 0.46, 0.54, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.46, 0.54, 0.46, 0.54 },
}

local function Pieces(parent, layer, sublevel, file, centre, keep)
	local s = {}
	for i = 1, centre and 9 or 8 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(CUT[i][1], CUT[i][2], CUT[i][3], CUT[i][4])
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
	if s[9] then Box(s[9], rel, x0 + c, y0 + c, x1 - c, y1 - c) end
end

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

-- A capsule cut in three: caps half the height wide from the file's outer
-- quarters, the middle stretched. `upright` for the file drawn standing.
local function ThreeSlice(parent, layer, sublevel, file, upright, keep)
	local s = {}
	for i, cut in ipairs({ { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }) do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		if upright then
			t:SetTexCoord(0, 1, cut[1], cut[2])
		else
			t:SetTexCoord(cut[1], cut[2], 0, 1)
		end
		s[i] = keep(t)
	end
	return s
end

-- A capsule laid along `box` (a frame) `height` thick: the caps square.
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

-- ...and standing in `box`, `width` across.
local function PlaceUpright(s, box, width)
	local cap = width / 2
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[1]:SetHeight(cap)
	s[3]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[3]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[3]:SetHeight(cap)
	s[2]:SetPoint("TOPLEFT", s[1], "BOTTOMLEFT", 0, 0)
	s[2]:SetPoint("BOTTOMRIGHT", s[3], "TOPRIGHT", 0, 0)
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it moves, parked between
-- plays, so nothing is left lit or displaced when it stops
---------------------------------------------------------------------------

-- Parks `region` at `rest` alpha when the group ends or is stopped (or where
-- the group was last sent, `group.to`, for a fade that goes either way).
local function Park(group, region, rest)
	local function park() region:SetAlpha(group.to or rest or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, smoothing)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Scales about the region's middle, or about `origin` ("LEFT": the edge a bar
-- grows from).
local function Grow(group, fx, fy, tx, ty, duration, order, smoothing, origin)
	local a = group:CreateAnimation("Scale")
	if a.SetScaleFrom then a:SetScaleFrom(fx, fy) end
	if a.SetScaleTo then a:SetScaleTo(tx, ty) end
	if a.SetOrigin then a:SetOrigin(origin or "CENTER", 0, 0) end
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, smoothing)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- A scale animation's ends changed after it was made, held to `cap`: a client
-- without the methods leaves it as drawn.
local function Rescale(a, from, to, cap)
	if from and a.SetScaleFrom then a:SetScaleFrom(math.min(from, cap), math.min(from, cap)) end
	if to and a.SetScaleTo then a:SetScaleTo(math.min(to, cap), math.min(to, cap)) end
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, peak, up, 1, "OUT")
	Alpha(g, peak, 0, down, 2, "OUT")
	Park(g, region, 0)
	return g
end

local function PlayAll(list)
	for _, g in ipairs(list) do
		g:Stop()
		g:Play()
	end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Slate:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own, anims = {}, {}
	self.own, self.anims = own, anims
	local base = art:GetFrameLevel()
	local function keep(x) own[#own + 1] = x return x end
	local function anim(g) anims[#anims + 1] = g return g end
	local function tex(parent, layer, sublevel, file)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		return keep(t)
	end
	-- A frame of light or of the card's furniture, a level over the art and
	-- under the text (hunt37-effects).
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end

	-- The ground, on art itself: the shadow, then the card, under the icon and
	-- the list's rows, which are art's too. A tray hangs from the card for the
	-- list, in the same pieces.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", true, keep)
	self.body = Pieces(art, "BACKGROUND", -6, ART .. "Card", true, keep)
	self.trayShadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", true, keep)
	self.trayBody = Pieces(art, "BACKGROUND", -6, ART .. "Card", true, keep)

	-- The hairline just inside the edge, of the card and of the tray, on a frame
	-- of its own so the cursor can lift it; and the same line in warm white,
	-- which breathes for somebody owed.
	self.rimFrame = frame(1)
	self.rim = Pieces(self.rimFrame, "ARTWORK", 0, ART .. "Rim", false, keep)
	self.trayRim = Pieces(self.rimFrame, "ARTWORK", 0, ART .. "Rim", false, keep)
	self.warmFrame = frame(1)
	self.warmFrame:SetAlpha(0)
	self.warmRim = Pieces(self.warmFrame, "ARTWORK", 1, ART .. "Rim", false, keep)
	-- The warm tone of the breath, which hunt35-effects looks for.
	self.warmRing = self.warmRim[1]

	-- The icon: a plate under it (so a bounce that shrinks it leaves a rounded
	-- ground, never the world), the ring that hugs it, the reason's light
	-- behind and a second layer of the same light for the arrival, the landing
	-- and the refusal. The icon itself is art's own (ARTWORK 0).
	self.glow = tex(art, "BACKGROUND", -3, "IconGlow")
	self.flash = tex(art, "BACKGROUND", -2, "IconGlow")
	self.glow:SetAlpha(0)
	self.flash:SetAlpha(0)
	self.plate = tex(art, "ARTWORK", -3, "IconMask")
	self.ring = tex(art, "ARTWORK", -2, "IconRing")

	-- The accent pill down the left.
	self.barFrame = frame(1)
	self.bar = ThreeSlice(self.barFrame, "ARTWORK", 0, ART .. "PillV", true, keep)

	-- The line along the bottom: the cooldown (a track and the line burning
	-- down over it, together under one fade), the landing's fill and the
	-- refusal's flash, each a frame of its own over the same run, so each
	-- animates alone.
	self.coolBox = frame(1)
	self.coolBox:SetAlpha(0)
	self.track = ThreeSlice(self.coolBox, "ARTWORK", 0, ART .. "Pill", false, keep)
	self.coolFill = frame(2, self.coolBox)
	self.cool = ThreeSlice(self.coolFill, "ARTWORK", 0, ART .. "Pill", false, keep)
	self.landFill = frame(2)
	self.landFill:SetAlpha(0)
	self.land = ThreeSlice(self.landFill, "ARTWORK", 0, ART .. "Pill", false, keep)
	self.refuseFill = frame(2)
	self.refuseFill:SetAlpha(0)
	self.refuse = ThreeSlice(self.refuseFill, "ARTWORK", 0, ART .. "Pill", false, keep)

	-- The rings that spread from the icon when a buff lands and the one that
	-- closes on it when one is refused, in frames over the art and under the
	-- text. No echo of the icon: the bounce is the icon's own.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		keep(f)
		f:SetFrameLevel(base + 2)
	end
	kit.RingArt(ART .. "FxRing", FX_PEAK, FX_EDGE)
	kit.RingArt(ART .. "FxRingRound", FX_PEAK, FX_EDGE)

	-- The chips at the right, over the card; their text is on textLayer. The
	-- count's and the bound key's.
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Pill", false, keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Pill", false, keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The verdict's tick or cross, before the second line.
	self.glyph = tex(textLayer, "ARTWORK", 1, "Check")

	-- The list's markers.
	self.dots = {}
	for i = 1, #kit.rows do self.dots[i] = tex(art, "ARTWORK", 1, "Dot") end

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	self:BuildAnimations(anim)
	self:WrapCooldown()
end

function Slate:BuildAnimations(anim)
	local icon = self.kit.icon

	-- The owed breath: the reason's light behind the icon and the card's
	-- highlight, warm, on the same breath (a few breaths: see Attention).
	local pulse = self.glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	Alpha(pulse, 0, PULSE_PEAK, BREATH, 1, "IN_OUT")
	Park(pulse, self.glow, 0)
	local warm = self.warmFrame:CreateAnimationGroup()
	warm:SetLooping("BOUNCE")
	Alpha(warm, 0, 1, BREATH, 1, "IN_OUT")
	Park(warm, self.warmFrame, 0)
	self.pulse = { anim(pulse), anim(warm) }

	-- A favour arriving: the icon pops in, the pill slides in, a breath of
	-- light behind the icon.
	local pop = icon:CreateAnimationGroup()
	Alpha(pop, 0, 1, 0.12, 1, "OUT")
	self.popIn = Grow(pop, 0.78, 0.78, POP_OVER, POP_OVER, 0.13, 1, "OUT")
	self.popSettle = Grow(pop, POP_OVER, POP_OVER, 1, 1, 0.12, 2, "IN_OUT")
	Park(pop, icon, 1)
	local slide = self.barFrame:CreateAnimationGroup()
	Alpha(slide, 0, 0, 0.01, 1)
	Slide(slide, -6, 0, 0.01, 1)
	Alpha(slide, 0, 1, 0.20, 2, "OUT")
	Slide(slide, 6, 0, 0.20, 2, "OUT")
	Park(slide, self.barFrame, 1)
	self.arrive = { anim(pop), anim(slide), anim(Flash(self.flash, 1, 0.09, 0.36)) }

	-- A landing: the line fills, the icon dips and bounces in its frame, the
	-- tick pops, the icon's light flares.
	local fill = self.landFill:CreateAnimationGroup()
	self.fillGrow = Grow(fill, 0.001, 1, 1, 1, 0.30, 1, "OUT", "LEFT")
	Alpha(fill, 1, 1, 0.30, 1)
	Alpha(fill, 1, 0, 0.18, 2, "IN")
	Park(fill, self.landFill, 0)
	local bounce = icon:CreateAnimationGroup()
	Grow(bounce, 1, 1, DIP, DIP, 0.07, 1, "IN_OUT")
	self.bounceUp = Grow(bounce, DIP, DIP, POP_OVER, POP_OVER, 0.11, 2, "OUT")
	self.bounceSettle = Grow(bounce, POP_OVER, POP_OVER, 1, 1, 0.12, 3, "IN_OUT")
	Park(bounce, icon, 1)
	local tick = self.glyph:CreateAnimationGroup()
	Alpha(tick, 0, 1, 0.08, 1)
	Grow(tick, 0.5, 0.5, 1.2, 1.2, 0.12, 1, "OUT")
	Grow(tick, 1.2, 1.2, 1, 1, 0.10, 2, "IN_OUT")
	Park(tick, self.glyph, 1)
	self.landing = { anim(fill), anim(bounce), anim(tick), anim(Flash(self.flash, 0.7, 0.08, 0.37)) }

	-- A refusal: the line flashes red-amber, the pill shakes (steps that sum
	-- to nothing and die away), the icon's light flares hot.
	local flare = self.refuseFill:CreateAnimationGroup()
	Alpha(flare, 0, 0.95, 0.05, 1, "OUT")
	Alpha(flare, 0.95, 0, 0.25, 2, "IN")
	Park(flare, self.refuseFill, 0)
	local shake = self.barFrame:CreateAnimationGroup()
	for i, dx in ipairs({ -2, 3, -3, 2, -1, 1 }) do Slide(shake, dx, 0, 0.045, i) end
	self.refusal = { anim(flare), anim(shake), anim(Flash(self.flash, 0.8, 0.05, 0.25)) }

	-- The cooldown line: it burns down from where the cooldown has got to, to
	-- nothing, then the whole line fades. Started by Cool.
	local run = self.coolBox:CreateAnimationGroup()
	self.coolHold = Alpha(run, 1, 1, 1, 1)
	Alpha(run, 1, 0, 0.18, 2, "IN")
	Park(run, self.coolBox, 0)
	local burn = self.coolFill:CreateAnimationGroup()
	self.coolBurn = Grow(burn, 1, 1, 0.001, 1, 1, 1, nil, "LEFT")
	self.coolRun, self.coolScale = anim(run), anim(burn)

	-- The cursor on the card: the highlight lifts and settles. From and to
	-- are set for each play.
	local hover = self.rimFrame:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, "OUT")
	Park(hover, self.rimFrame, RIM_REST)
	self.hoverAnim = anim(hover)
end

-- Prompt starts and clears the cooldown on the shared frame; the line follows
-- it by wrapping the two calls, once, and answering only while this look is up.
function Slate:WrapCooldown()
	local cd = self.kit.cooldown
	if not cd or cd.mannersSlate then return end
	local set, clear = cd.SetCooldown, cd.Clear
	if type(set) ~= "function" or type(clear) ~= "function" then return end
	cd.mannersSlate = true
	cd.SetCooldown = function(frame, start, duration, ...)
		local out = set(frame, start, duration, ...)
		if Slate.active then Slate:Cool(start, duration) end
		return out
	end
	cd.Clear = function(frame, ...)
		local out = clear(frame, ...)
		if Slate.active then Slate:CoolStop() end
		return out
	end
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- Whether the text on this panel colour wants to be light (a dark card), as
-- Prompt/Text.lua works it out from the same colour, over a dusky world: the
-- card is drawn for it before Prompt has styled the text.
local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function Luminance(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local function Ratio(a, b)
	if a < b then a, b = b, a end
	return (a + 0.05) / (b + 0.05)
end

local function WantsLight(p)
	local c = type(p.bgColor) == "table" and p.bgColor or {}
	local r, g, b, a = c[1] or 0.04, c[2] or 0.04, c[3] or 0.06, c[4] or 0.88
	local function over(v, k) return v * k * a + 0.15 * (1 - a) end
	local lo = Luminance(over(r, 0.62), over(g, 0.62), over(b, 0.72))
	local hi = Luminance(over(r, 1), over(g, 1), over(b, 1))
	return math.min(Ratio(1, lo), Ratio(1, hi)) >= math.min(Ratio(0, lo), Ratio(0, hi))
end

-- The ground the card is drawn on: light text means a dark card.
function Slate:Ground(p)
	local light = WantsLight(p)
	self.dark = light
	if light then
		self.rimColor = { 1, 1, 1, 0.24 }
		self.plateColor = { 0.025, 0.030, 0.042, 1 }
		self.fillColor = { 1, 1, 1, 0.10 }
		self.trackColor = { 1, 1, 1, 0.07 }
		self.shadowK = 1
	else
		self.rimColor = { 0, 0, 0, 0.26 }
		self.plateColor = { 0.93, 0.94, 0.96, 1 }
		self.fillColor = { 0, 0, 0, 0.09 }
		self.trackColor = { 0, 0, 0, 0.08 }
		self.shadowK = 0.45
	end
end

function Slate:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	local round = p.roundIcon and true or false
	local mode = p.accentMode or "icon"
	local barOn = mode == "stripe" or mode == "both"
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	self.round = round
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua), and where it starts left of the name.
	self.pitch = sub + 7
	self.rowReach = 15
	self:Ground(p)

	local c = Clamp(math.floor(H * 0.25 + 0.5), 7, 14)
	self.c = c
	local S = showIcon and Clamp(p.iconSize, 12, math.max(12, H - 8)) or 0
	local vpad = (H - S) / 2
	self.S, self.vpad = S, vpad
	-- The accent pill: 3 units wide, 7 in, as tall as the card less its
	-- corners' room.
	local BAR_X, BAR_W = 7, 3
	local barInset = Clamp(math.floor(H * 0.2 + 0.5), 7, 13)
	local iconX = barOn and (BAR_X + BAR_W + 7) or Clamp(math.floor(vpad + 0.5), 7, 12)
	local textX = showIcon and (iconX + S + 10) or (barOn and 19 or 14)
	local cx, cy = iconX + S / 2, H / 2
	self.iconX, self.textX, self.cx, self.cy = iconX, textX, cx, cy

	-- The card's colours: the look's own slate unless one was chosen.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local bc = p.bgColor
	local tr, tg, tb, ta, br, bg, bb
	if Untouched(bc, d) then
		tr, tg, tb, ta = SLATE_TOP[1], SLATE_TOP[2], SLATE_TOP[3], SLATE_ALPHA
		br, bg, bb = SLATE_BOTTOM[1], SLATE_BOTTOM[2], SLATE_BOTTOM[3]
	else
		br, bg, bb, ta = bc[1] or 0, bc[2] or 0, bc[3] or 0, bc[4] == nil and 1 or bc[4]
		local k = self.dark and 1.35 or 1.04
		tr, tg, tb = math.min(1, br * k + (self.dark and 0.012 or 0)), math.min(1, bg * k + (self.dark and 0.012 or 0)),
			math.min(1, bb * k + (self.dark and 0.014 or 0))
	end
	self.top, self.bottom, self.alpha = { tr, tg, tb }, { br, bg, bb }, ta
	-- The card's gradient, piece by piece so it runs unbroken from the top to
	-- the bottom: a piece takes the colour at each of its ends.
	local function at(y)
		local t = Clamp(y / H, 0, 1)
		return tr + (br - tr) * t, tg + (bg - tg) * t, tb + (bb - tb) * t
	end
	local rows = { { 1, 2, 3, 0, c }, { 4, 9, 5, c, H - c }, { 6, 7, 8, H - c, H } }
	for _, row in ipairs(rows) do
		local r1, g1, b1 = at(row[5])
		local r2, g2, b2 = at(row[4])
		for k = 1, 3 do kit.Gradient(self.body[row[k]], "VERTICAL", r1, g1, b1, ta, r2, g2, b2, ta) end
	end
	PlacePieces(self.body, art, 0, 0, W, H, c)
	-- The hairline: lighter than the card on a dark one, darker on a light one.
	local rc = self.rimColor
	PlacePieces(self.rim, art, 0, 0, W, H, c)
	Each(self.rim, "SetVertexColor", rc[1], rc[2], rc[3], rc[4])
	self.rimFrame:SetAlpha(RIM_REST)
	PlacePieces(self.warmRim, art, 0, 0, W, H, c)
	Each(self.warmRim, "SetVertexColor", WARM[1], WARM[2], WARM[3], WARM_PEAK)
	-- The drop shadow: 7 units past the card at the sides, three lower.
	local shadowA = (ta < 0.2) and 0 or 0.62 * self.shadowK
	self.shadowA = shadowA
	Each(self.shadow, "SetVertexColor", 0, 0, 0, shadowA)
	self.shadowBox = { -7, -4, W + 7, H + 10 }
	self.drawnList = nil
	self:PlaceShadow()

	-- The accent pill.
	local barH = math.max(8, H - 2 * barInset)
	self.barFrame:ClearAllPoints()
	self.barFrame:SetPoint("LEFT", art, "LEFT", BAR_X, 0)
	self.barFrame:SetSize(BAR_W, barH)
	PlaceUpright(self.bar, self.barFrame, BAR_W)

	-- The icon, in a rounded square or a circle: the file for the shape.
	local shape = round and "Round" or ""
	local maskFile = ART .. "IconMask" .. shape
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.plate:SetTexture(maskFile)
	self.ring:SetTexture(ART .. "IconRing" .. shape)
	for _, t in ipairs({ self.glow, self.flash }) do t:SetTexture(ART .. "IconGlow" .. shape) end
	local ringW = math.max(0.6, S * RING_FRACTION)
	-- How far the light behind the icon reaches: a fifth of the icon, but not
	-- past the card's top and bottom.
	local glowW = math.max(2, math.min(S * 0.26, vpad - 1.2))
	self.ringW, self.glowW = ringW, glowW
	if showIcon then
		icon:SetSize(S, S)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		self.plate:ClearAllPoints()
		self.plate:SetAllPoints(icon)
		self.ring:ClearAllPoints()
		self.ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -ringW, ringW)
		self.ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", ringW, -ringW)
		for _, t in ipairs({ self.glow, self.flash }) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", icon, "TOPLEFT", -glowW, glowW)
			t:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glowW, -glowW)
		end
		-- The rings spread from where the ring sits: their line a unit past it
		-- at rest. The room they have: to the text (less a margin), to the
		-- card's left edge and to its top and bottom. The icon's own pop and
		-- bounce are held to it as well.
		local pad = (S / 2 + ringW + 1) / FX_PEAK - S / 2
		self.fx:Place(icon, pad, S)
		self.fx:Shape(round, ART .. "FxRingRound", ART .. "FxRing")
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = H / 2 - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cap = kit.CapScale(math.min(limitH, limitV), S / 2, 1)
		Rescale(self.popIn, 0.78, POP_OVER, cap)
		Rescale(self.popSettle, POP_OVER, 1, cap)
		Rescale(self.bounceUp, DIP, POP_OVER, cap)
		Rescale(self.bounceSettle, POP_OVER, 1, cap)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The sweep is drawn at no strength: the line along the bottom is
			-- the cooldown here. Its shape follows the icon all the same.
			cooldown:SetAlpha(0)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end

	-- The line along the bottom: from under the text (or the card's corner with
	-- no icon) to the other corner, 2.4 thick, 4.6 up.
	local x0 = showIcon and (textX - 4) or (c + 1)
	local x1 = W - c - 1
	if x1 - x0 < 24 then x0 = math.min(x0, c + 1) end
	local lineH = 2.4
	self.lineH, self.lineX0, self.lineX1 = lineH, x0, x1
	for _, f in ipairs({ self.coolBox, self.landFill, self.refuseFill }) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -(H - 4.6 - lineH / 2))
		f:SetSize(math.max(10, x1 - x0), lineH)
	end
	self.coolFill:ClearAllPoints()
	self.coolFill:SetAllPoints(self.coolBox)
	PlaceThree(self.track, self.coolBox, lineH)
	PlaceThree(self.cool, self.coolFill, lineH)
	PlaceThree(self.land, self.landFill, lineH)
	PlaceThree(self.refuse, self.refuseFill, lineH)
	Each(self.track, "SetVertexColor", self.trackColor[1], self.trackColor[2], self.trackColor[3], self.trackColor[4])
	Each(self.land, "SetVertexColor", OUTCOME.cast[1], OUTCOME.cast[2], OUTCOME.cast[3], 1)
	Each(self.refuse, "SetVertexColor", OUTCOME.failed[1], OUTCOME.failed[2], OUTCOME.failed[3], 1)
	self.coolOn = nil

	-- The text: the name and the reason as one block, a unit above the middle
	-- so the line along the bottom has its room.
	local gap = Gap(fs)
	local block = fs + gap + sub
	self.nameY = block / 2 - fs / 2 + 1.5
	self.subY = -(block / 2 - sub / 2) + 1.5
	self.oneY = 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The chips, at the right.
	local chipH = sub + 6
	self.chipH = chipH
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -10, 0.5)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	local fc = self.fillColor
	Each(self.chip, "SetVertexColor", fc[1], fc[2], fc[3], fc[4])
	Each(self.keyChip, "SetVertexColor", fc[1], fc[2], fc[3], fc[4])
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	for _, f in ipairs({ self.rimFrame, self.warmFrame, self.barFrame, self.coolBox }) do f:SetFrameLevel(base + 1) end
	self.chipFrame:SetFrameLevel(base + 3)

	-- The list: where the names start, and how wide they may run.
	self.rowX = math.max(textX, 28)
	-- A name's click area begins at its dot, which stands in the icon's column.
	self.rowReach = showIcon and (self.rowX - cx + 7) or 15
	local rowWidth = math.max(20, W - self.rowX - 14)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip, the line for a cooldown.
	for _, x in ipairs(self.own) do x:Show() end
	self.barFrame:SetShown(barOn)
	self.fx:SetShown(showIcon)
	for _, t in ipairs({ self.plate, self.ring, self.glow, self.flash }) do t:SetShown(showIcon) end
	for _, s in ipairs({ self.trayShadow, self.trayBody, self.trayRim }) do Each(s, "Hide") end
	self.glyph:Hide()
	for i = 1, #self.dots do self.dots[i]:Hide() end
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	self.glow:SetAlpha(0)
	self.flash:SetAlpha(0)
	self.warmFrame:SetAlpha(0)
	self:Plate()
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset.
	return textX, math.ceil(chipH * 1.75) + 15
end

-- The plate and the icon's tint, which the fight changes.
function Slate:Plate()
	local pc = self.plateColor
	self.plate:SetVertexColor(pc[1], pc[2], pc[3], pc[4])
end

function Slate:PlaceShadow(tray)
	local b = self.shadowBox
	local cs = Clamp(math.min(16, (b[4] - b[2]) / 2 - 0.5, (b[3] - b[1]) / 2 - 0.5), 4, 16)
	PlacePieces(self.shadow, self.kit.art, b[1], b[2], b[3], b[4], cs)
	if tray then
		local cst = Clamp(math.min(16, (tray[4] - tray[2]) / 2 - 0.5), 4, 16)
		PlacePieces(self.trayShadow, self.kit.art, tray[1] - 7, tray[2] - 4, tray[3] + 7, tray[4] + 10, cst)
	end
end

function Slate:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen and ink.light then
		kit.name:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3], 1)
	end
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 0.55)
		kit.name:SetShadowOffset(0, -1)
		kit.sub:SetShadowColor(0, 0, 0, 0.45)
		kit.sub:SetShadowOffset(0, -1)
	end
	-- The chips are a faint lift of the card whatever the card, so their text
	-- is the muted ink.
	local mr, mg, mb = kit.Legible(0.82, 0.86, 0.94, 4.5)
	if ink.light then kit.count:SetTextColor(mr, mg, mb, 1) end
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(mr, mg, mb, 1)
	self.keyText:SetShadowOffset(0, 0)
	if ink.light then
		local r, g, b = kit.Legible(0.90, 0.92, 0.97, 4.5)
		for _, fs in ipairs(kit.rows) do
			fs:SetTextColor(r, g, b, 1)
			fs:SetShadowColor(0, 0, 0, 0.5)
			fs:SetShadowOffset(0, -1)
		end
		ink.rowReason = "|cff8a91a3"
	end
end

function Slate:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
	self.fx:Stop()
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
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.listShown, self.countMode, self.keyUp, self.coolOn = nil, nil, false, nil
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Slate:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
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
		name:SetPoint("LEFT", self.textX, self.oneY)
		name:SetPoint("RIGHT", -inset, self.oneY)
	end
	-- Placed again by Fitted, which knows whether the verdict's glyph leads.
	self.subLead = nil
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
end

-- Whether the reason line holds the verdict PaintOutcome wrote: the only
-- time a glyph leads it.
function Slate:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Slate:Fitted(fs)
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
function Slate:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, 12) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only
-- where a press casts something: the button armed (a fight's frozen macro
-- too, unlocked or not), never over a held panel with nothing armed, nor over
-- an outcome.
function Slate:KeyLabel()
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
function Slate:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint. The count's chip at the right, or, with the key's chip
-- there, a chip beside the key's; the key's chip when a key is bound. Either
-- steps aside for a paint in which the name would otherwise be cut.
function Slate:Chip(on)
	local kit = self.kit
	-- The width FitLine took of the name just now, measured here only where it
	-- could not; the chips' own words only when they change (Looks.lua: no
	-- pcall on a per-repaint path).
	self.nameWidth = kit.fit.drawn[kit.name] or kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + 16)
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
		end
		local w = self.countW
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -10, 0.5)
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
	-- Only a chip at the right takes room from the lines; PlaceLines gives a
	-- pair the room of both.
	return mode == "chip" or mode == "pair"
end

---------------------------------------------------------------------------
-- the cooldown line
---------------------------------------------------------------------------

-- The cooldown began at `start` and lasts `duration`: the line burns down from
-- what is left to nothing, then fades. A Scale from the left edge, so it
-- follows the real clock without a frame script, and begun again by every new
-- cooldown (a cast during the global cooldown moves the end).
function Slate:Cool(start, duration)
	if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then return self:CoolStop() end
	local left = start + duration - GetTime()
	if left <= 0.02 then return self:CoolStop() end
	if not self.p.showIcon then return end
	self.coolOn = true
	local frac = Clamp(left / duration, 0.001, 1)
	self.coolRun:Stop()
	self.coolScale:Stop()
	self.coolHold:SetDuration(left)
	self.coolBurn:SetDuration(left)
	if self.coolBurn.SetScaleFrom then self.coolBurn:SetScaleFrom(frac, 1) end
	self.coolBox:SetAlpha(1)
	self.coolRun:Play()
	self.coolScale:Play()
end

function Slate:CoolStop()
	if not self.coolOn and not self.coolRun:IsPlaying() then return end
	self.coolOn = nil
	self.coolRun:Stop()
	self.coolScale:Stop()
	self.coolBox:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The reason line: the muted grey warmed towards the colour and held to its
-- contrast; on a light card the plain grey, which the tint would cost.
function Slate:SubInk(r, g, b)
	local kit = self.kit
	local sr, sg, sb
	if kit.ink.light then
		sr = MUTED[1] + (r - MUTED[1]) * 0.30
		sg = MUTED[2] + (g - MUTED[2]) * 0.30
		sb = MUTED[3] + (b - MUTED[3]) * 0.30
	else
		local s = kit.ink.sub or MUTED
		sr, sg, sb = s[1], s[2], s[3]
	end
	return kit.Legible(sr, sg, sb, 4.5)
end

-- The reason's colour on the pill, the ring, the light and the line; the reason
-- line warmed towards it. An outcome calls it with its own colour.
function Slate:Tint(r, g, b, mode, outcome)
	local kit = self.kit
	local ringOn = mode == "icon" or mode == "both"
	Each(self.bar, "SetVertexColor", r, g, b, 1)
	if ringOn or outcome then
		self.ring:SetVertexColor(r, g, b, 0.95)
	else
		local rc = self.rimColor
		self.ring:SetVertexColor(rc[1], rc[2], rc[3], rc[4] * 1.2)
	end
	self.glow:SetVertexColor(r, g, b, 1)
	local lr, lg, lb = kit.Tint(r, g, b, 0.18)
	Each(self.cool, "SetVertexColor", lr, lg, lb, 1)
	local sr, sg, sb = self:SubInk(r, g, b)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { r, g, b }
end

function Slate:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3], mode)
	else
		self:Tint(r, g, b, mode)
	end
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The card holds; the icon greys and dims, the text dims, the lights go out.
-- The accent pill, the ring and the line keep their colour: the reason is the
-- one coloured thing left.
function Slate:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the card through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if on then
		self:StopAttention()
		for _, g in ipairs(self.arrive) do g:Stop() end
		self:StopFlourishes()
	end
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breathing, let go: after its breaths, and on Calm.
function Slate:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.warmFrame:SetAlpha(0)
end

function Slate:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- The arrival: once per new favour, never over an outcome and never
		-- on Calm (fades only).
		if full and not self.outcomeOn then
			local t = self.tint or NEUTRAL
			self.flash:SetVertexColor(t[1], t[2], t[3], 1)
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
	-- A repaint leaves a running breath alone; a new favour on top takes its
	-- own few breaths, not what is left of the last face's.
	local playing = self.pulse[1]:IsPlaying()
	if playing and not isNew then return end
	if not playing then
		self.glow:SetAlpha(0)
		self.warmFrame:SetAlpha(0)
		for _, g in ipairs(self.pulse) do g:Play() end
	end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Slate.pulseGen or not Slate.active then return end
			Slate.pulseSpent = true
			if Slate.pulse[1]:IsPlaying() then Slate:HoldPulse() end
		end)
	end
end

function Slate:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.glow:SetAlpha(0)
	self.warmFrame:SetAlpha(0)
end

function Slate:Flourish(kind)
	local icon = self.kit.icon:IsShown()
	if kind == "failed" then
		-- A refusal: the line flashes red-amber, the pill shakes, one ring closes
		-- on the icon. The text's shake is Prompt's.
		self.flash:SetVertexColor(1.00, 0.42, 0.20, 1)
		PlayAll(self.refusal)
		if icon then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	local o = OUTCOME.cast
	self.flash:SetVertexColor(o[1], o[2], o[3], 1)
	-- The icon's own bounce only where there is an icon.
	for i, g in ipairs(self.landing) do
		if icon or i ~= 2 then
			g:Stop()
			g:Play()
		end
	end
	if icon then self.fx:Land(o[1], o[2], o[3], 0.70) end
end

function Slate:StopFlourishes()
	for _, g in ipairs(self.landing) do g:Stop() end
	for _, g in ipairs(self.refusal) do g:Stop() end
	self.fx:Stop()
end

function Slate:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local g, t = self.hoverAnim, self.rimFrame
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 1 or RIM_REST
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the reason line becomes the verdict, so the
-- eye never has to find the person again. The ring and the pill take the
-- outcome's colour.
function Slate:PaintOutcome(kind, lead, sub, who, stamp)
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
	self:Tint(o[1], o[2], o[3], self.p.accentMode or "icon", true)
	-- The verdict in the outcome's colour, not the reason's.
	local vr, vg, vb = kit.Legible(o[1], o[2], o[3], 4.5)
	kit.sub:SetTextColor(vr, vg, vb, 1)
	self.glyph:SetVertexColor(vr, vg, vb, 1)
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	self.glyph:SetTexture(ART .. (kind == "failed" and "Cross" or "Check"))
	self.glyphOn = kind ~= "sent"
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self.verdict = kit.sub:GetText()
		self:Fitted(kit.sub)
	end
end

function Slate:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list hangs from the card on a tray of its own, three units off it, above
-- or below; each row wears a dot in its reason's colour.
function Slate:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i = 1, #self.dots do
		if not (list and i <= shown) then self.dots[i]:Hide() end
	end
	if not list then
		if self.listShown then
			self.listShown, self.listAt = nil, nil
			for _, s in ipairs({ self.trayShadow, self.trayBody, self.trayRim }) do Each(s, "Hide") end
		end
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.dots[i]:SetVertexColor(c[1], c[2], c[3], 1)
		self.dots[i]:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch = self.pitch
	local pad = 6
	local depth = pad * 2 + shown * pitch
	local x0, x1 = 4, self.W - 4
	local y0, y1
	if above then
		y1 = -3
		y0 = y1 - depth
	else
		y0 = self.H + 3
		y1 = y0 + depth
	end
	local ct = Clamp(math.min(self.c, depth / 2), 4, 14)
	-- The tray's card: the card's middle colour, a shade deeper.
	local t, b = self.top, self.bottom
	local k = self.dark and 0.86 or 0.97
	local mr, mg, mb = (t[1] + b[1]) / 2 * k, (t[2] + b[2]) / 2 * k, (t[3] + b[3]) / 2 * k
	Each(self.trayBody, "SetVertexColor", mr, mg, mb, self.alpha)
	PlacePieces(self.trayBody, art, x0, y0, x1, y1, ct)
	PlacePieces(self.trayRim, art, x0, y0, x1, y1, ct)
	local rc = self.rimColor
	Each(self.trayRim, "SetVertexColor", rc[1], rc[2], rc[3], rc[4] * 0.8)
	Each(self.trayShadow, "SetVertexColor", 0, 0, 0, self.shadowA * 0.8)
	for _, s in ipairs({ self.trayShadow, self.trayBody, self.trayRim }) do Each(s, "Show") end
	self:PlaceShadow({ x0, y0, x1, y1 })

	local dot = math.max(5, math.floor(self.sub * 0.6 + 0.5))
	-- The dots stand in the icon's column, the names in the name's.
	local dotX = self.S > 0 and self.cx or (self.rowX - 9)
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y = y0 + pad + (i - 1) * pitch + pitch / 2
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", self.rowX, -y)
		local d = self.dots[i]
		d:ClearAllPoints()
		d:SetPoint("CENTER", art, "TOPLEFT", dotX, -y)
		d:SetSize(dot, dot)
	end
end
