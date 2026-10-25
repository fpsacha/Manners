-- Manners -- the Whisper look.
--
-- Almost nothing. No box: the name and the reason stand on a soft veil of the
-- panel's colour that feathers to nothing, laid only as thick as a bright
-- world needs to keep them readable. A small spell icon, cut to a rounded
-- square and held in a hairline frame; between the name and the reason line a
-- hairline runs, and at its left end a short dash in the reason's colour. That
-- dash is the whole mark: it breathes when somebody owed waits, turns the
-- colour of an outcome, and when a buff lands a fine line draws itself across
-- the hairline, left to right, and lets go. A refusal turns the dash
-- red-amber and nudges the text two units. Calm is fades only.
--
-- Every region is a texture from Textures/Whisper (tools/make_whisper_textures.py),
-- white, so the vertex colour carries every reason, both palettes, a custom
-- marker colour and the outcomes. The interface this file implements is
-- described at the top of Looks/Looks.lua.
--
-- Choices the interface leaves open:
--   * the dash is there whatever the marker, except off; the icon's frame
--     takes the reason's colour only for "icon" and "both", and the hairline
--     takes it as well for "both";
--   * the veil is the panel colour at 88% of its opacity, and the lines are
--     held to the contrast Prompt works out for that colour. Made nearly
--     clear, the lines take an outline instead;
--   * class-coloured names are taken 85% of the way to white, so the dash
--     stays the only colour on the panel;
--   * the refusal's shake is the shared one scaled to two units while this
--     look is in use (QuietShake), put back when it is not;
--   * the count is a number after a small dot at the right of the name line,
--     left out when the name would be cut even at its smallest size;
--   * the list is the same: a dot in the reason's colour, then the name, on a
--     veil that grows to hold it.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Whisper\\Whisper_"

local Whisper = ns.Looks.Register("whisper", {
	name = L["Whisper -- no box, one hairline in the reason colour"],
	order = 4,
	-- The ground and the ink are dimmed apart, so art itself stays whole.
	combatArtAlpha = 1,
	classSoften = 0.85,
})

-- The inset at both sides, in units: where the icon starts and the lines stop.
local PAD = 12
-- The veil reaches this far past the panel on every side, feathering out; it
-- is whole from five units inside the panel's edge (Whisper_Veil's middle
-- begins 28 units in from its own).
local VEIL_OUT = 23
-- How much of the panel colour's opacity the veil keeps.
local VEIL_K = 0.80
-- The frame is drawn this far outside a 30-unit icon, scaled with the icon:
-- RING_PAD in tools/make_whisper_textures.py, which must agree.
local RING_PAD = 3
-- The dash and the hairline, in units.
local DASH_H, LINE_H = 2, 1
-- What a fight does to the icon, the text.
local INK_COMBAT, TEXT_COMBAT = 0.62, 0.82
-- The breath's two ends and the rest it comes back to; half a breath is 1.5 s.
local BREATH_LOW, BREATH_REST, BREATH_HIGH = 0.45, 0.90, 1.0
local BREATH_SECONDS = 1.5
-- How far the shared refusal shake is taken down: 5 units become 2.
local SHAKE_SCALE = 0.4
-- The reason line's grey on a dark ground: light enough to read on the veil over
-- snow, and still a step under the name's white.
local SUB_GREY = { 0.80, 0.81, 0.86 }
-- The reason with the marker switched off.
local NEUTRAL = { 0.62, 0.63, 0.68 }
-- The hairline's strength at rest, and under the cursor.
local TRACK_A, TRACK_HOVER = 0.14, 0.34
-- The outcomes' own colours: the dash, the frame, the line and the verdict.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.50, 0.30 },
	sent = { 0.91, 0.86, 0.60 },
}

-- The reason line's size, and the room the hairline needs between two lines.
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize, tight)
	if tight then return 3 end
	return math.max(5, math.floor(0.45 * fontSize + 0.5))
end
local function BlockHeight(fontSize, tight)
	return math.ceil(1.2 * fontSize + Gap(fontSize, tight) + 1.2 * SubSize(fontSize) + (tight and 4 or 10))
end

-- Never more than the built-in looks ask: a profile that showed two lines on
-- glass keeps them here, with the hairline's room drawn tight until the full
-- one fits.
function Whisper.TwoLineHeight(fontSize)
	return math.max(ns.TwoLineHeight(fontSize, "glass"), BlockHeight(fontSize, true))
end

-- The icon's frame carries the reason for "icon" and "both"; the dash is
-- there whatever the marker, off excepted.
function Whisper.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false, mode ~= "off"
end

---------------------------------------------------------------------------
-- small things
---------------------------------------------------------------------------

local function Mix(r, g, b, t)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- Relative luminance, as the web's contrast rules define it.
local function Linear(c)
	if c <= 0.03928 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end
local function Luminance(r, g, b)
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end
-- The grey of snow (a luminance of 0.85), for the worst ground a veil lies on.
local SNOW = 0.9319

local function Between(r1, g1, b1, r2, g2, b2, t)
	return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t
end

-- Nine textures cut from one file: corners `corner` units square, cut
-- `margin` texels into a `size`-texel file. Every client draws this.
local function NineSlice(parent, layer, sublevel, file, size, margin, corner)
	local s = { corner = corner }
	local u = margin / size
	local cuts = { 0, u, 1 - u, 1 }
	for row = 1, 3 do
		for col = 1, 3 do
			local t = parent:CreateTexture(nil, layer, nil, sublevel)
			t:SetTexture(file)
			t:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
			s[#s + 1] = t
		end
	end
	return s
end

-- Placed round a box, `out` units outside it on each side (left, top, right,
-- bottom). The top row hangs from `top`, the bottom row from `bottom`, which
-- are the same region unless the slice spans two (the veil under the panel
-- and its list); the two share their left and right edges.
local function PlaceSlice(s, top, bottom, l, t, r, b)
	local c = s.corner
	for _, tex in ipairs(s) do tex:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", top, "TOPLEFT", -l, t)
	s[1]:SetSize(c, c)
	s[2]:SetPoint("TOPLEFT", top, "TOPLEFT", -l + c, t)
	s[2]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r - c, t)
	s[2]:SetHeight(c)
	s[3]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r, t)
	s[3]:SetSize(c, c)
	s[4]:SetPoint("TOPLEFT", top, "TOPLEFT", -l, t - c)
	s[4]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l, -b + c)
	s[4]:SetWidth(c)
	s[5]:SetPoint("TOPLEFT", top, "TOPLEFT", -l + c, t - c)
	s[5]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r - c, -b + c)
	s[6]:SetPoint("TOPRIGHT", top, "TOPRIGHT", r, t - c)
	s[6]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r, -b + c)
	s[6]:SetWidth(c)
	s[7]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l, -b)
	s[7]:SetSize(c, c)
	s[8]:SetPoint("BOTTOMLEFT", bottom, "BOTTOMLEFT", -l + c, -b)
	s[8]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r - c, -b)
	s[8]:SetHeight(c)
	s[9]:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", r, -b)
	s[9]:SetSize(c, c)
end

local function SliceColor(s, r, g, b, a)
	for _, tex in ipairs(s) do tex:SetVertexColor(r, g, b, a) end
end

-- A one-shot fade on a frame, parked where it ends so nothing is left lit.
local function Fade(frame, to, duration, smoothing)
	local group = frame:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetDuration(duration)
	if smoothing and fade.SetSmoothing then fade:SetSmoothing(smoothing) end
	group.fade = fade
	group:SetScript("OnFinished", function() frame:SetAlpha(group.to or to or 0) end)
	return group
end

-- Whether this client reads an English string in its own language; the
-- verdict words are new, and a German player is better served by the lines
-- that are translated than by English in a German panel.
local function Known(english)
	local locale = ns.LOCALE or "enUS"
	return locale == "enUS" or locale == "enGB" or rawget(L, english) ~= nil
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Whisper:Build(kit)
	self.kit = kit
	local art = kit.art
	local own = {}
	self.own = own
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		return keep(t)
	end
	local function frame(parent, alpha)
		local f = keep(CreateFrame("Frame", nil, parent))
		f:SetAlpha(alpha)
		return f
	end

	-- The veil: under everything, on art itself, below the list's rows and the
	-- icon, which are art's too.
	self.veil = NineSlice(art, "BACKGROUND", -6, ART .. "Veil", 128, 56, 28)
	for _, t in ipairs(self.veil) do keep(t) end
	-- Where the list hangs: a box PaintQueue sizes, which the veil's bottom (or
	-- top) row follows.
	self.trayBox = keep(CreateFrame("Frame", nil, art))

	-- The hairline between the two lines, and the one that closes the panel
	-- when the list hangs from it.
	self.track = tex(art, "BORDER", 1, "Line")
	self.listRule = tex(art, "BORDER", 1, "Line")
	self.dots = {}
	for i = 1, #kit.rows do self.dots[i] = tex(art, "ARTWORK", 1, "Dot") end
	self.countDot = tex(kit.textLayer, "ARTWORK", 1, "Dot")

	-- The icon's shape. Not ours to keep in `own`: it is taken off the icon in
	-- Hide.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "Mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- What moves, each on a frame of its own: only a frame can be animated. The
	-- flare (an arrival, a refusal) holds the breath, which holds the marks, so
	-- the two multiply and never fight over one alpha.
	self.flareFrame = frame(art, 1)
	self.breathFrame = frame(self.flareFrame, BREATH_REST)
	self.dash = tex(self.breathFrame, "ARTWORK", 2, "Dash")
	self.ring = tex(self.breathFrame, "ARTWORK", 2, "Ring")
	-- The line that draws across at a landing, from its left end. A frame, so
	-- it can grow and fade.
	self.lineFrame = frame(art, 0)
	self.line = tex(self.lineFrame, "ARTWORK", 3, "Line")
	self.line:SetAllPoints(self.lineFrame)
	-- The hairline lit under the cursor.
	self.hoverFrame = frame(art, 0)
	self.hoverLine = tex(self.hoverFrame, "ARTWORK", 2, "Line")
	self.hoverLine:SetAllPoints(self.hoverFrame)

	-- Under the text, over the art, in this order: the flare's frame, the
	-- line's, the cursor's.
	local base = art:GetFrameLevel()
	for _, f in ipairs({ self.flareFrame, self.lineFrame, self.hoverFrame }) do
		f:SetFrameLevel(base + 1)
	end
	self.breathFrame:SetFrameLevel(base + 2)

	self:BuildAnimations()
end

function Whisper:BuildAnimations()
	-- Breathing while somebody owed waits: the marks' opacity slides between
	-- two ends and back, 1.5 s each way. Nothing grows or moves.
	local breath = self.breathFrame:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local slide = breath:CreateAnimation("Alpha")
	slide:SetFromAlpha(BREATH_LOW)
	slide:SetToAlpha(BREATH_HIGH)
	slide:SetDuration(BREATH_SECONDS)
	if slide.SetSmoothing then slide:SetSmoothing("IN_OUT") end
	breath:SetScript("OnStop", function() self.breathFrame:SetAlpha(BREATH_REST) end)
	self.breathAnim = breath

	-- A new face with a favour owed: the marks come up from faint, once.
	local flare = self.flareFrame:CreateAnimationGroup()
	local up = flare:CreateAnimation("Alpha")
	up:SetFromAlpha(0.25)
	up:SetToAlpha(1)
	up:SetDuration(0.5)
	if up.SetSmoothing then up:SetSmoothing("OUT") end
	flare:SetScript("OnFinished", function() self.flareFrame:SetAlpha(1) end)
	flare:SetScript("OnStop", function() self.flareFrame:SetAlpha(1) end)
	self.flareAnim = flare

	-- A refusal: the marks dip and come back, in the outcome's colour.
	local warn = self.flareFrame:CreateAnimationGroup()
	local dip = warn:CreateAnimation("Alpha")
	dip:SetFromAlpha(1)
	dip:SetToAlpha(0.3)
	dip:SetDuration(0.08)
	dip:SetOrder(1)
	local back = warn:CreateAnimation("Alpha")
	back:SetFromAlpha(0.3)
	back:SetToAlpha(1)
	back:SetDuration(0.22)
	back:SetOrder(2)
	if back.SetSmoothing then back:SetSmoothing("OUT") end
	warn:SetScript("OnFinished", function() self.flareFrame:SetAlpha(1) end)
	warn:SetScript("OnStop", function() self.flareFrame:SetAlpha(1) end)
	self.warnAnim = warn

	-- A buff landed: a fine line draws itself across, from the left end of the
	-- hairline, and lets go. 0.6 s in all, the length of the outcome.
	local draw = self.lineFrame:CreateAnimationGroup()
	local show = draw:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(1)
	show:SetDuration(0.08)
	show:SetOrder(1)
	local grow = draw:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.02, 1) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("LEFT", 0, 0) end
	grow:SetDuration(0.30)
	grow:SetOrder(1)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	local let = draw:CreateAnimation("Alpha")
	let:SetFromAlpha(1)
	let:SetToAlpha(0)
	let:SetDuration(0.30)
	let:SetOrder(2)
	if let.SetSmoothing then let:SetSmoothing("IN") end
	draw:SetScript("OnFinished", function() self.lineFrame:SetAlpha(0) end)
	draw:SetScript("OnStop", function() self.lineFrame:SetAlpha(0) end)
	self.drawAnim = draw

	-- The same on Calm: the whole line fades in where it lies and out, nothing
	-- grows.
	local calm = self.lineFrame:CreateAnimationGroup()
	local calmIn = calm:CreateAnimation("Alpha")
	calmIn:SetFromAlpha(0)
	calmIn:SetToAlpha(0.8)
	calmIn:SetDuration(0.15)
	calmIn:SetOrder(1)
	local calmOut = calm:CreateAnimation("Alpha")
	calmOut:SetFromAlpha(0.8)
	calmOut:SetToAlpha(0)
	calmOut:SetDuration(0.40)
	calmOut:SetOrder(2)
	calm:SetScript("OnFinished", function() self.lineFrame:SetAlpha(0) end)
	calm:SetScript("OnStop", function() self.lineFrame:SetAlpha(0) end)
	self.calmAnim = calm

	-- The cursor's light, both ways; from and to are set for each play.
	self.hoverAnim = Fade(self.hoverFrame, 0, 0.12, "OUT")
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

-- The refusal's shake is Prompt's, on the text: six steps of 3 to 5 units.
-- Taken down to two units for as long as this look is in use, and put back
-- exactly as it was (each step's own offset is kept the first time it is seen).
function Whisper:QuietShake(on)
	local group = self.kit.textLayer.shake
	if not (group and group.GetAnimations) then return end
	self.shakeWas = self.shakeWas or {}
	for _, step in ipairs({ group:GetAnimations() }) do
		if step.GetOffset and step.SetOffset then
			local was = self.shakeWas[step]
			if not was then
				local dx, dy = step:GetOffset()
				was = { dx or 0, dy or 0 }
				self.shakeWas[step] = was
			end
			local k = on and SHAKE_SCALE or 1
			step:SetOffset(was[1] * k, was[2] * k)
		end
	end
end

function Whisper:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local c = p.bgColor or {}
	local br, bg, bb, ba = c[1] or 0.04, c[2] or 0.04, c[3] or 0.06, c[4] == nil and 0.88 or c[4]

	local showIcon = p.showIcon and true or false
	-- Held inside the panel with its frame (a fifth again as wide, and a unit of air).
	local iconSize = math.max(8, math.min(p.iconSize, math.floor((H - 2) / 1.2)))
	local ringPad = RING_PAD * iconSize / 30
	-- Where the text starts: past the icon and its frame, or past the dot of a
	-- list row when there is no icon.
	local textX = showIcon and math.floor(PAD + iconSize + ringPad + 9) or (PAD + 6)
	local sub = SubSize(fs)
	local two = p.showSub and H >= Whisper.TwoLineHeight(fs)
	local tight = H < BlockHeight(fs)
	local nameH, subH, gap = 1.2 * fs, 1.2 * sub, Gap(fs, tight)
	self.p, self.W, self.H = p, W, H
	self.textX, self.two = textX, two
	self.sub, self.pitch = sub, sub + 7
	self.right = PAD
	self.above = above

	-- Measured from the panel's middle, up positive, for SetPoint.
	local nameY, ruleY, subY, ruleOn
	if two then
		local top = (H - (nameH + gap + subH)) / 2
		nameY = H / 2 - (top + nameH / 2)
		ruleY = H / 2 - (top + nameH + gap / 2)
		subY = H / 2 - (top + nameH + gap + subH / 2)
		ruleOn = true
	elseif H >= nameH + 10 then
		-- One line, the hairline under it, the two centred as a block.
		nameY = 2.5
		ruleY = nameY - nameH / 2 - 3
		ruleOn = true
	else
		nameY, ruleY, ruleOn = 0, 0, false
	end
	self.nameY, self.subY, self.ruleY, self.ruleOn = nameY, subY, ruleY, ruleOn
	self.subRoom = math.max(20, W - textX - PAD)

	-- The veil: the panel's colour, a little darker, over the panel and ten
	-- units past it, feathering out. Nearly clear, it all but goes, and the
	-- text is outlined instead (Styled).
	local dark = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5
	local k = dark and 0.82 or 1
	self.clear = ba < 0.35
	local va = math.min(1, ba * VEIL_K)
	SliceColor(self.veil, br * k, bg * k, bb * (dark and 0.9 or 1), va)
	-- What stands under the lines over snow: the veil's colour over a pale world.
	self.snow = Luminance(br * k * va + SNOW * (1 - va), bg * k * va + SNOW * (1 - va),
		bb * (dark and 0.9 or 1) * va + SNOW * (1 - va))
	self.trayShown, self.trayHeight = nil, nil
	PlaceSlice(self.veil, art, art, VEIL_OUT, VEIL_OUT, VEIL_OUT, VEIL_OUT)

	-- The hairline, the dash on its left end, the line that draws and the
	-- cursor's light, all on the same row.
	local lineW = math.max(8, W - PAD - textX)
	self.lineW = lineW
	local dashW = math.min(lineW, math.max(12, math.floor(fs * 1.4 + 0.5)))
	self.track:ClearAllPoints()
	self.track:SetPoint("LEFT", art, "LEFT", textX, ruleY)
	self.track:SetSize(lineW, LINE_H)
	for _, f in ipairs({ self.lineFrame, self.hoverFrame }) do
		f:ClearAllPoints()
		f:SetPoint("LEFT", art, "LEFT", textX, ruleY)
		f:SetSize(lineW, LINE_H)
	end
	for _, f in ipairs({ self.flareFrame, self.breathFrame }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end
	self.dash:ClearAllPoints()
	self.dash:SetPoint("LEFT", art, "LEFT", textX, ruleY)
	self.dash:SetSize(dashW, DASH_H)

	-- The icon, cut to its shape, in its frame.
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	local round = p.roundIcon and true or false
	local maskFile = ART .. (round and "MaskRound" or "Mask")
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.ring:SetTexture(ART .. (round and "RingRound" or "Ring"))
	self.ring:ClearAllPoints()
	if showIcon then
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("LEFT", PAD, 0)
		self.ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -ringPad, ringPad)
		self.ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", ringPad, -ringPad)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep is cut to the same shape.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(round) end
		end
	end

	-- The list's rows share the lines' left edge and stop at the same inset.
	local rowWidth = math.max(20, W - textX - PAD)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	-- Each name's click area starts at its dot.
	self.dotX = showIcon and (PAD + iconSize / 2) or (PAD + 2)
	self.rowReach = textX - self.dotX + 5

	-- The count: right-aligned on the name line, a small dot before it.
	kit.count:ClearAllPoints()
	kit.count:SetJustifyH("RIGHT")
	kit.count:SetPoint("RIGHT", kit.textLayer, "RIGHT", -PAD, two and nameY or ruleOn and nameY or 0)
	self.countDot:ClearAllPoints()
	self.countDot:SetPoint("RIGHT", kit.count, "LEFT", -3, 0)
	self.countDot:SetSize(3, 3)

	self:QuietShake(true)

	-- Everything this look draws, shown, and then what waits: the frames of
	-- motion parked, the list for PaintQueue, the frame for the reason's paint.
	for _, x in ipairs(self.own) do x:Show() end
	self.track:SetShown(ruleOn)
	self.dash:SetShown(ruleOn)
	self.listRule:Hide()
	for _, d in ipairs(self.dots) do d:Hide() end
	self.ring:SetShown(showIcon)
	self.flareFrame:SetAlpha(1)
	self.breathFrame:SetAlpha(BREATH_REST)
	self.lineFrame:SetAlpha(0)
	self.hoverFrame:SetAlpha(0)
	self.lineFrame:SetShown(ruleOn)
	self.hoverFrame:SetShown(ruleOn)
	self:Chip(false)
	self.combat, self.hovered, self.washFor = nil, nil, nil
	self:SetInk(1, 1)

	-- The count's room: two digits, the dot and a point of air.
	local chipRoom = math.ceil(sub * 1.3 + 8) + PAD
	return textX, chipRoom
end

function Whisper:Styled(p, twoLine)
	local kit = self.kit
	-- A nearly clear panel: every line outlined, as the minimal look's, and the
	-- lines FitLine shrinks keep it (fit.flags).
	if self.clear then
		kit.fit.flags = "OUTLINE"
		for _, fs in ipairs({ kit.name, kit.sub, kit.count }) do
			local path, size = fs:GetFont()
			if path then fs:SetFont(path, size, "OUTLINE") end
		end
		for _, fs in ipairs(kit.rows) do
			local path, size = fs:GetFont()
			if path then fs:SetFont(path, size, "OUTLINE") end
		end
	end
	-- The reason line is small and soft: a shadow only as wide as it needs.
	if kit.ink.light then
		kit.sub:SetShadowColor(0, 0, 0, 0.75)
		kit.sub:SetShadowOffset(1, -1)
	end
	kit.count:SetShadowColor(0, 0, 0, 0.75)
	kit.count:SetShadowOffset(kit.ink.light and 1 or 0, kit.ink.light and -1 or 0)
	local r, g, b = kit.Legible(0.86, 0.87, 0.90, 4.5)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
	kit.ink.rowReason = kit.ink.light and "|cffc4c6d2" or "|cff585860"
end

function Whisper:Hide()
	local kit = self.kit
	if not kit then return end
	for _, x in ipairs(self.own) do x:Hide() end
	for _, anim in ipairs({ self.breathAnim, self.flareAnim, self.warnAnim, self.drawAnim, self.calmAnim,
		self.hoverAnim }) do
		anim:Stop()
	end
	-- Stop parks nothing on a fade that has already finished, and the cursor
	-- leaves for the next look.
	self.hoverFrame:SetAlpha(0)
	self.lineFrame:SetAlpha(0)
	self:QuietShake(false)
	-- The shared regions, as the built-in looks expect to find them.
	local icon = kit.icon
	if self.masked then
		icon:RemoveMaskTexture(self.mask)
		self.masked = nil
	end
	self.mask:Hide()
	icon:SetAlpha(1)
	icon:SetDesaturated(false)
	if kit.cooldown then
		kit.cooldown:SetAlpha(1)
		if kit.cooldown.SetUseCircularEdge then kit.cooldown:SetUseCircularEdge(false) end
	end
	kit.count:Show()
	kit.count:SetJustifyH("CENTER")
	kit.count:SetShadowOffset(0, 0)
	kit.textLayer:SetAlpha(1)
	for _, fs in ipairs({ kit.name, kit.sub, kit.count }) do fs:SetAlpha(1) end
	-- The reason line's room is ours: the built-in looks fit theirs to the
	-- panel's width, and only do so while this is nil.
	kit.fit.room[kit.sub] = nil
	self.combat, self.hovered, self.washFor, self.trayShown = nil, nil, nil, nil
end

---------------------------------------------------------------------------
-- the lines
---------------------------------------------------------------------------

function Whisper:PlaceLines(right)
	local kit = self.kit
	local name, sub = kit.name, kit.sub
	-- The name keeps 20 units: the two points never cross.
	right = math.min(math.max(right, PAD), math.max(0, self.W - self.textX - 20))
	if kit.fit.twoLine then
		name:SetPoint("LEFT", self.textX, self.nameY)
		name:SetPoint("RIGHT", -right, self.nameY)
		sub:SetPoint("LEFT", self.textX, self.subY)
		sub:SetWidth(self.subRoom)
		kit.fit.room[sub] = self.subRoom
	else
		local y = self.ruleOn and self.nameY or 0
		name:SetPoint("LEFT", self.textX, y)
		name:SetPoint("RIGHT", -right, y)
	end
end

-- Nothing hugs the text here: the lines are as wide as the room they have.
function Whisper:Fitted() end

function Whisper:Chip(on)
	local kit = self.kit
	if on then
		-- The name wins: a count that would leave the name cut even at its
		-- smallest size is left out of this paint. The width is the one
		-- FitLine just measured.
		local name, fit = kit.name, kit.fit
		local width, size, base = fit.drawn[name] or kit.TextWidth(name), fit.size[name], fit.base[name]
		if width and size and base and size > 0 then
			local least = math.max(7, math.floor(base * 0.8 + 0.5))
			if width * least / size > self.W - self.textX - fit.chipRoom - 0.5 then on = false end
		end
	end
	self.countDot:SetShown(on)
	kit.count:SetShown(on)
	return on
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The ink's alpha, for the fight: the icon dims and the text a little; the
-- dash and the frame keep their colour, so the reason still reads.
function Whisper:SetInk(ink, text)
	local kit = self.kit
	kit.icon:SetAlpha(ink)
	if kit.cooldown then kit.cooldown:SetAlpha(ink) end
	-- On the lines themselves, not on textLayer: Prompt's cross-fade plays on
	-- textLayer, and an animation's alpha replaces its frame's own.
	kit.name:SetAlpha(text)
	kit.sub:SetAlpha(text)
	kit.count:SetAlpha(text)
end

-- The marks in one colour. `ring`: the frame carries it; `track`: the
-- hairline does too. `strength`: how far the reason line is taken towards it.
function Whisper:Tint(r, g, b, ring, track, strength)
	local kit = self.kit
	self.dash:SetVertexColor(r, g, b, 1)
	local n = kit.ink.light and 1 or 0
	if ring then
		self.ring:SetVertexColor(r, g, b, 0.9)
	else
		self.ring:SetVertexColor(n, n, n, 0.30)
	end
	self.ring:SetShown(kit.icon:IsShown() and true or false)
	if track then
		self.track:SetVertexColor(r, g, b, 0.30)
	else
		self.track:SetVertexColor(n, n, n, kit.ink.light and TRACK_A or 0.22)
	end
	self.hoverLine:SetVertexColor(r, g, b, TRACK_HOVER)
	local tint = self.tint or {}
	tint[1], tint[2], tint[3] = r, g, b
	self.tint = tint
	-- The reason line: the ground's grey, taken a little towards the colour and
	-- held to the contrast Prompt holds every line to.
	local base = kit.ink.light and SUB_GREY or kit.ink.sub or SUB_GREY
	local k = strength or 0.22
	local sr, sg, sb = Between(base[1], base[2], base[3], r, g, b, k)
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	if kit.ink.light then sr, sg, sb = self:OverSnow(sr, sg, sb) end
	kit.sub:SetTextColor(sr, sg, sb, 1)
end

-- A colour taken towards white until it holds 4.5:1 on the veil over snow, the
-- worst ground there is: the veil is the panel's colour at part of its opacity,
-- so a pale world shows through it. Set out in Apply (self.snow, the ground's
-- luminance there).
function Whisper:OverSnow(r, g, b)
	local snow = self.snow
	if not snow then return r, g, b end
	for _ = 1, 10 do
		if (Luminance(r, g, b) + 0.05) / (snow + 0.05) >= 4.6 then break end
		r, g, b = Mix(r, g, b, 0.12)
	end
	return r, g, b
end

function Whisper:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
	self:Tint(r, g, b, (mode == "icon" or mode == "both") and true or false, mode == "both")
	self.dash:SetShown(self.ruleOn and mode ~= "off" and true or false)
	-- A refusal greyed the icon; a fight keeps it grey.
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Whisper:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	if on then
		self:SetInk(INK_COMBAT, TEXT_COMBAT)
		self.breathAnim:Stop()
		self.breathFrame:SetAlpha(1)
	else
		self:SetInk(1, 1)
		self.breathFrame:SetAlpha(BREATH_REST)
	end
	self.kit.icon:SetDesaturated(on)
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

function Whisper:Attention(isNew, _, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" then
		self:StopAttention()
		return
	end
	-- The marks come up from faint when somebody owed gets to the top; a fade,
	-- so Calm has it as well.
	if isNew and not self.combat then
		self.warnAnim:Stop()
		self.flareAnim:Stop()
		self.flareAnim:Play()
	end
	if flashStyle == "pulse" and not self.combat then
		if full then
			if not self.breathAnim:IsPlaying() then self.breathAnim:Play() end
		else
			-- Calm: nothing loops. The marks are held, a little brighter.
			self.breathAnim:Stop()
			self.breathFrame:SetAlpha(BREATH_HIGH)
		end
	else
		self:StopAttention()
	end
end

function Whisper:StopAttention()
	self.breathAnim:Stop()
	self.breathFrame:SetAlpha(self.combat and 1 or BREATH_REST)
end

-- The line drawn across the hairline in `r, g, b`: from its left end on Full,
-- the whole line fading in and out on Calm.
function Whisper:Draw(full, r, g, b)
	if not self.ruleOn then return end
	self.line:SetVertexColor(r, g, b, 1)
	self.drawAnim:Stop()
	self.calmAnim:Stop()
	if full then
		self.drawAnim:Play()
	else
		self.calmAnim:Play()
	end
end

function Whisper:Flourish(kind)
	if kind == "failed" then
		-- The dash dips and comes back red-amber (Tint, from PaintOutcome); the
		-- text's nudge is Prompt's shake, scaled by QuietShake.
		self.flareAnim:Stop()
		self.warnAnim:Stop()
		self.warnAnim:Play()
	elseif kind == "cast" then
		-- Nothing for a cast nobody confirmed: a flourish is a claim.
		local o = OUTCOME.cast
		self:Draw(true, Mix(o[1], o[2], o[3], 0.25))
	end
end

function Whisper:StopFlourishes()
	self.warnAnim:Stop()
	self.drawAnim:Stop()
	self.calmAnim:Stop()
end

function Whisper:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	local anim = self.hoverAnim
	local from = self.hoverFrame:GetAlpha()
	anim:Stop()
	anim.to = on and 1 or 0
	anim.fade:SetFromAlpha(from)
	anim.fade:SetToAlpha(anim.to)
	anim.fade:SetDuration(on and 0.12 or 0.18)
	anim:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the reason line becomes the verdict, so the
-- eye never has to find the person again -- when there is a line to carry it.
-- With one line, or no verdict word in this client's language, the name line
-- says it the built-in looks' way ("buffed Anna", translated).
function Whisper:PaintOutcome(kind, lead, sub, who, stamp)
	local kit = self.kit
	local o = OUTCOME[kind] or OUTCOME.cast
	local tag = kit.sub:IsShown()
	local word
	if kind == "failed" then
		word = (sub and sub ~= "" and sub) or (Known("could not buff") and L["could not buff"])
	elseif kind == "sent" then
		-- No fallback: the built-in sub is a sentence, not a word.
		word = Known("sent, unconfirmed") and L["sent, unconfirmed"]
	else
		word = (Known("buffed") and L["buffed"]) or (sub and sub ~= "" and sub)
	end
	local stays = tag and who and word
	kit.SetLine(kit.name, stays and who or lead)
	self:Tint(o[1], o[2], o[3], true, kind == "cast", 0.55)
	self.dash:SetShown(self.ruleOn and true or false)
	kit.icon:SetDesaturated(kind == "failed" or self.combat or false)
	if tag then
		kit.SetLine(kit.sub, stays and word or (kind ~= "sent" and sub) or "")
	end
	-- Once per click: a repaint during the outcome leaves it be. On Calm the
	-- line fades where it lies (Full's is Flourish's). In a fight that is to be
	-- quiet no outcome is painted at all (Prompt/Refresh.lua), so nothing here
	-- needs to ask.
	if stamp ~= self.washFor then
		self.washFor = stamp
		if kind == "cast" and not kit.FullEffects() then
			self:Draw(false, Mix(o[1], o[2], o[3], 0.25))
		end
	end
end

function Whisper:ClearOutcome()
	if not self.washFor then return end
	self.washFor = nil
	self.drawAnim:Stop()
	self.calmAnim:Stop()
	self.lineFrame:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

function Whisper:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	if self.trayShown ~= list or (list and self.above ~= above) then
		self.trayShown, self.above = list, above
		-- The veil holds the list as well, one shape under both.
		if not list then
			PlaceSlice(self.veil, art, art, VEIL_OUT, VEIL_OUT, VEIL_OUT, VEIL_OUT)
		elseif above then
			PlaceSlice(self.veil, self.trayBox, art, VEIL_OUT, VEIL_OUT, VEIL_OUT, VEIL_OUT)
		else
			PlaceSlice(self.veil, art, self.trayBox, VEIL_OUT, VEIL_OUT, VEIL_OUT, VEIL_OUT)
		end
	end
	for i, dot in ipairs(self.dots) do
		if not (list and i <= shown) then dot:Hide() end
	end
	self.listRule:SetShown(list)
	if not list then return end

	local pitch = self.pitch
	local height = 8 + shown * pitch
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	local placed = self.trayHeight == height and self.trayAt == above
	if not placed then
		self.trayHeight, self.trayAt = height, above
		self.trayBox:ClearAllPoints()
		self.listRule:ClearAllPoints()
		if above then
			self.trayBox:SetPoint("BOTTOMLEFT", art, "TOPLEFT", 0, 0)
			self.trayBox:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, 0)
			self.listRule:SetPoint("LEFT", art, "TOPLEFT", self.textX, 0)
		else
			self.trayBox:SetPoint("TOPLEFT", art, "BOTTOMLEFT", 0, 0)
			self.trayBox:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, 0)
			self.listRule:SetPoint("LEFT", art, "BOTTOMLEFT", self.textX, 0)
		end
		self.trayBox:SetHeight(height)
		self.listRule:SetSize(self.lineW, LINE_H)
		local n = kit.ink.light and 1 or 0
		self.listRule:SetVertexColor(n, n, n, kit.ink.light and TRACK_A or 0.22)
	end

	for i = 1, shown do
		local dot = self.dots[i]
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		dot:SetVertexColor(c[1], c[2], c[3], 0.95)
		dot:Show()
	end
	if placed then return end
	for i = 1, shown do
		local fs, dot = kit.rows[i], self.dots[i]
		-- Row centres, counted from the panel's edge the list hangs off.
		local y = 4 + (i - 1) * pitch + pitch / 2
		local edge = "BOTTOMLEFT"
		if above then
			y = height - 4 - (i - 1) * pitch - pitch / 2
			edge = "TOPLEFT"
		else
			y = -y
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, edge, self.textX, y)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", art, edge, self.dotX, y)
		dot:SetSize(4, 4)
	end
end
