-- Manners -- the Whisper look.
--
-- Floating type. No box and no square icon: the name stands in large, light
-- letters straight on the game world, and above it, small, the reason in
-- capitals, led by a round dot -- the buff's own spell icon cut to a bullet,
-- held in a ring of the reason's colour. The type is the design, and it keeps
-- itself legible over snow, sky or a dark dungeon with what the letters carry
-- themselves: a thin outline and a soft shadow, never a panel, a veil or a
-- glow laid behind them.
--
--       (o) YOU OWE THEM        <- the reason: capitals, the reason's colour
--       Anna Aim  +2  [F]       <- the name; the count and the bound key follow
--                                  it as small inline text
--
-- Motion: a favour arriving brings the letters up from nothing with a slight
-- rise, the reason a beat before the name; somebody owed makes the dot's ring
-- and the reason breathe; a refusal turns the reason red-amber and the name
-- shivers two units; a landed buff blooms the name -- a copy of its own
-- letters, in the colour of the outcome, spreads and fades -- and a thin line
-- sweeps out under it. Calm is fades only. The list is a few smaller lines,
-- each with a dot of its own in the reason's colour. Unlocked, four corner
-- marks show where the prompt is, to be dragged.
--
-- Art (Textures/Whisper, tools/make_whisper_textures.py) is a dot, a ring, a
-- round mask, a line and a bar for the corner marks: white, so the vertex
-- colour carries every reason, both palettes, a custom marker colour and the
-- outcomes. The interface this file implements is described at the top of
-- Looks/Looks.lua.
--
-- Choices the interface leaves open:
--   * the fonts are the player's: the font and size settings are used as they
--     stand (the name a fifth larger than the size says, the reason and the
--     small text two thirds of it, the list four fifths), in the file the
--     profile names or, where the client will not load it, the game's own --
--     which is the locale's on koKR, zhCN and zhTW. No face is named here, so a
--     Latin-only file can never be chosen for a language it lacks;
--   * the reason is set in capitals where the line is plain ASCII, by
--     wrapping the reason line's SetText while this look is in use; a line
--     with an accent or a Chinese character in it is left as it is, never half
--     capitalised (string.upper works a byte at a time);
--   * there is no panel, so the panel colour does not matter: the text is
--     light with a black outline whatever it is set to, and a font colour too
--     dark for an outline is taken towards white;
--   * the marker: "icon" and "both" put the reason's colour on the dot's ring;
--     the reason line carries it for every marker but "off"; with no spell
--     icon the dot is a plain disc of the colour;
--   * class-coloured names are taken 85% of the way to white, so the reason
--     stays the only colour on the prompt;
--   * the refusal's shake is the shared one scaled to two units while this
--     look is in use (QuietShake), put back when it is not;
--   * the count is "+n" and the key "[F]" after the name, and either is left
--     out when the name would be cut even at its smallest size.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Whisper\\Whisper_"
local COMMAND = "CLICK MannersPrompt:LeftButton"

local Whisper = ns.Looks.Register("whisper", {
	name = L["Whisper -- floating letters, the reason in small capitals"],
	title = L["Whisper"],
	description = L["floating letters, the reason in small capitals"],
	order = 4,
	-- The ground and the ink are dimmed apart, so art itself stays whole.
	combatArtAlpha = 1,
	classSoften = 0.85,
})

-- The inset at the left, in units, and the air between the dot and the reason.
local PAD = 10
local DOT_GAP = 4.5
-- The ring is drawn this far outside the icon (its file keeps the ring at
-- RING_INNER of its radius: tools/make_whisper_textures.py): a unit of air and
-- a ring about a unit wide on a 12-unit dot.
local RING_PAD = 2.5
-- What is left between the reason and the name, in units.
local GAP = 2
-- What a fight does to the icon, the text.
local INK_COMBAT, TEXT_COMBAT = 0.62, 0.82
-- The breath's two ends and the rest it comes back to; half a breath is 1.5 s.
local BREATH_LOW, BREATH_REST, BREATH_HIGH = 0.45, 0.90, 1.0
local BREATH_SECONDS = 1.5
-- How far the shared refusal shake is taken down: 5 units become 2.
local SHAKE_SCALE = 0.4
-- The reason line's colour with the marker off, and the grey of the small text.
local NEUTRAL = { 0.80, 0.81, 0.86 }
local SMALL = { 0.80, 0.81, 0.86 }
-- The list's names, and the words after them.
local ROW_INK = { 0.90, 0.91, 0.95 }
local ROW_REASON = "|cffbfc2d0"
-- The outcomes' own colours: the reason, the dot's ring, the line, the bloom.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.50, 0.30 },
	sent = { 0.91, 0.86, 0.60 },
}
-- Where the bloom's copies of the name lie, round the letters: eight, a unit
-- and a half out.
local HALO = {}
for i = 0, 7 do
	local a = i * math.pi / 4
	HALO[#HALO + 1] = { 1.5 * math.cos(a), 1.5 * math.sin(a) }
end
-- The corner marks shown while unlocked: arm length and width, in units.
local MARK_ARM, MARK_WIDTH = 9, 2
local MARK_GOLD = { 1.0, 0.82, 0.0 }

---------------------------------------------------------------------------
-- sizes
---------------------------------------------------------------------------

-- The name, the reason line and the small text, and the list's lines, from the
-- player's font size. The name never goes below the size the player set, and
-- never so large that it does not fit the panel's height.
local function Sizes(p)
	local fs = p.fontSize
	local name = math.max(fs, math.min(math.floor(fs * 1.2 + 0.5), p.height - 6))
	local reason = math.max(8, math.floor(fs * 0.66 + 0.5))
	local rows = math.max(7, math.floor(fs * 0.80 + 0.5))
	return name, reason, rows
end

local function BlockHeight(fontSize)
	local name = math.floor(fontSize * 1.2 + 0.5)
	local reason = math.max(8, math.floor(fontSize * 0.66 + 0.5))
	return 1.2 * name + GAP + 1.2 * reason
end

-- Never more than the built-in looks ask: a profile that showed two lines on
-- glass keeps them here.
function Whisper.TwoLineHeight(fontSize)
	return math.max(ns.TwoLineHeight(fontSize, "glass"), math.ceil(BlockHeight(fontSize) + 4))
end

-- The ring carries the reason for "icon" and "both"; the reason line for every
-- marker but off.
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

-- A colour taken towards white until it holds `minimum` against the black the
-- letters are outlined in: that edge is what every glyph stands against.
local function OnBlack(r, g, b, minimum)
	for _ = 1, 14 do
		if (Luminance(r, g, b) + 0.05) / 0.05 >= minimum then break end
		r, g, b = Mix(r, g, b, 0.15)
	end
	return r, g, b
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

-- Capitals, where the line is plain ASCII: colour codes are left as they are,
-- and a line with any other byte in it is not touched at all (string.upper
-- goes a byte at a time, and half a word in capitals is worse than none).
local function Capitals(text)
	if text:find("[\128-\255]") or text:find("|[TtHh]") or not text:find("[a-z]") then return text end
	if not text:find("|", 1, true) then return text:upper() end
	local out = text:upper():gsub("|C(%x%x%x%x%x%x%x%x)", function(hex) return "|c" .. hex:lower() end)
	return (out:gsub("|R", "|r"):gsub("|N", "|n"))
end

-- Letter-spaced: a space after each letter and three between words, the
-- nearest the game's fonts allow to tracking.
local function Track(caps)
	local out = caps:gsub("%S", "%0 ")
	out = out:gsub("  ", "   ")
	return (out:gsub("%s+$", ""))
end

-- A line's text with its colour codes taken off, for the bloom's copy of it.
local function Bare(text)
	if type(text) ~= "string" then return "" end
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- A font set as Prompt sets one: the file asked for, else the game's own.
local function SetFace(fs, path, size, flags)
	if not fs:SetFont(path, size, flags) or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Whisper:Build(kit)
	self.kit = kit
	local art, textLayer = kit.art, kit.textLayer
	local own = {}
	self.own = own
	local function keep(x) own[#own + 1] = x return x end
	local function tex(parent, layer, sublevel, file)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		return keep(t)
	end
	local function frame(parent, alpha, level)
		local f = keep(CreateFrame("Frame", nil, parent))
		f:SetAlpha(alpha)
		if level then f:SetFrameLevel(level) end
		return f
	end
	local base, text = art:GetFrameLevel(), textLayer:GetFrameLevel()

	-- Under the type, over the art, in this order: the dot's ring, the line that
	-- sweeps, the line the cursor lights, the corner marks. None of it is above
	-- the text's level.
	self.ringFlare = frame(art, 1, base + 1)
	self.ringBreath = frame(self.ringFlare, BREATH_REST, base + 2)
	self.ring = tex(self.ringBreath, "ARTWORK", 1, "Ring")
	self.plain = tex(self.ringBreath, "ARTWORK", 1, "Dot")
	self.lineFrame = frame(art, 0, base + 1)
	self.lineDark = tex(self.lineFrame, "ARTWORK", 0, "Line")
	self.line = tex(self.lineFrame, "ARTWORK", 1, "Line")
	self.hoverFrame = frame(art, 0, base + 1)
	self.hoverDark = tex(self.hoverFrame, "ARTWORK", 0, "Line")
	self.hoverLine = tex(self.hoverFrame, "ARTWORK", 1, "Line")
	self.marksFrame = frame(art, 1, base + 1)
	self.markDark, self.markLight = {}, {}
	for i = 1, 8 do
		self.markDark[i] = tex(self.marksFrame, "BORDER", 0, "Bar")
		self.markLight[i] = tex(self.marksFrame, "BORDER", 1, "Bar")
	end
	-- The row dots, one to a line of the list.
	self.dots = {}
	for i = 1, #kit.rows do self.dots[i] = tex(art, "ARTWORK", 1, "Dot") end

	-- The icon's shape. Not ours to keep in `own`: it is taken off the icon in
	-- Hide.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "MaskRound", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- The type. The bloom's copy of the name lies under the lines, then the
	-- reason, then the name, each in a frame of its own so each can fade and
	-- rise; the three share the text layer's box, which is the panel's. The
	-- name and the reason line are put into theirs in Apply (and taken out
	-- again in Hide).
	self.echoFrame = frame(textLayer, 0, text + 1)
	self.echoes = {}
	for i, at in ipairs(HALO) do
		local copy = keep(self.echoFrame:CreateFontString(nil, "OVERLAY"))
		copy:SetPoint("CENTER", self.echoFrame, "CENTER", at[1], at[2])
		copy:SetJustifyH("CENTER")
		copy:SetWordWrap(false)
		self.echoes[i] = copy
	end
	self.reasonFlare = frame(textLayer, 1, text + 2)
	self.reasonFlare:SetAllPoints(textLayer)
	self.reasonBreath = frame(self.reasonFlare, BREATH_REST, text + 3)
	self.reasonBreath:SetAllPoints(self.reasonFlare)
	self.nameFrame = frame(textLayer, 1, text + 4)
	self.nameFrame:SetAllPoints(textLayer)
	-- The count and the bound key, small, after the name.
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("LEFT")
	self.keyText:SetWordWrap(false)

	-- The reason in capitals, while this look is in use.
	local setText = kit.sub.SetText
	kit.sub.SetText = function(fs, value, ...)
		if self.upper then value = self:Caps(fs, setText, value) end
		return setText(fs, value, ...)
	end

	self:BuildAnimations()
end

-- The reason line as it is set: in capitals and letter-spaced where it is plain
-- ASCII and the spaced line fits the room it has (found by setting it and
-- asking how wide it came out, once for each new line: the answer is kept, as
-- the same line is set on every repaint). A line with a colour code in it is
-- in capitals but not spaced; one with an accent or a Chinese character is
-- left as it is.
function Whisper:Caps(fs, setText, text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return text end
	if text == self.capsIn then return self.capsOut end
	local caps = Capitals(text)
	local out = caps
	if caps:find("[A-Z]") and not caps:find("[\128-\255|]") then
		local spaced = Track(caps)
		setText(fs, spaced)
		local width = self.kit.TextWidth(fs)
		if width and width <= self.subRoom then out = spaced end
	end
	self.capsIn, self.capsOut = text, out
	return out
end

-- The same animation on two frames: a group for each, returned in a list.
local function Both(frames, make)
	local groups = {}
	for i, f in ipairs(frames) do groups[i] = make(f) end
	return groups
end

function Whisper:BuildAnimations()
	local ringTwo = { self.ringFlare, self.reasonFlare }

	-- Breathing while somebody owed waits: the dot's ring and the reason slide
	-- between two opacities and back, 1.5 s each way. Nothing grows or moves.
	local function breath(f)
		local group = f:CreateAnimationGroup()
		group:SetLooping("BOUNCE")
		local slide = group:CreateAnimation("Alpha")
		slide:SetFromAlpha(BREATH_LOW)
		slide:SetToAlpha(BREATH_HIGH)
		slide:SetDuration(BREATH_SECONDS)
		if slide.SetSmoothing then slide:SetSmoothing("IN_OUT") end
		group:SetScript("OnStop", function() f:SetAlpha(BREATH_REST) end)
		return group
	end
	self.breaths = { breath(self.ringBreath), breath(self.reasonBreath) }

	-- A new face with a favour owed: the dot and the reason come up from nothing,
	-- once; then the name rises into its place a beat later (the drop is instant
	-- and unseen, and the rise ends where the name belongs: a translation is
	-- undone when its group ends). Calm brings the name up by fading alone.
	self.arrivals = Both(ringTwo, function(f)
		local group = f:CreateAnimationGroup()
		local up = group:CreateAnimation("Alpha")
		up:SetFromAlpha(0)
		up:SetToAlpha(1)
		up:SetDuration(0.40)
		if up.SetSmoothing then up:SetSmoothing("OUT") end
		group:SetScript("OnFinished", function() f:SetAlpha(1) end)
		group:SetScript("OnStop", function() f:SetAlpha(1) end)
		return group
	end)
	local nameUp = self.nameFrame:CreateAnimationGroup()
	local hold = nameUp:CreateAnimation("Alpha")
	hold:SetFromAlpha(0)
	hold:SetToAlpha(0)
	hold:SetDuration(0.07)
	hold:SetOrder(1)
	local drop = nameUp:CreateAnimation("Translation")
	drop:SetOffset(0, -5)
	drop:SetDuration(0.01)
	drop:SetOrder(1)
	local rise = nameUp:CreateAnimation("Translation")
	rise:SetOffset(0, 5)
	rise:SetDuration(0.45)
	rise:SetOrder(2)
	if rise.SetSmoothing then rise:SetSmoothing("OUT") end
	local show = nameUp:CreateAnimation("Alpha")
	show:SetFromAlpha(0)
	show:SetToAlpha(1)
	show:SetDuration(0.40)
	show:SetOrder(2)
	if show.SetSmoothing then show:SetSmoothing("OUT") end
	nameUp:SetScript("OnFinished", function() self.nameFrame:SetAlpha(1) end)
	nameUp:SetScript("OnStop", function() self.nameFrame:SetAlpha(1) end)
	self.nameArrival = nameUp
	local nameCalm = self.nameFrame:CreateAnimationGroup()
	local calmUp = nameCalm:CreateAnimation("Alpha")
	calmUp:SetFromAlpha(0)
	calmUp:SetToAlpha(1)
	calmUp:SetDuration(0.30)
	if calmUp.SetSmoothing then calmUp:SetSmoothing("OUT") end
	nameCalm:SetScript("OnFinished", function() self.nameFrame:SetAlpha(1) end)
	nameCalm:SetScript("OnStop", function() self.nameFrame:SetAlpha(1) end)
	self.nameArrivalCalm = nameCalm

	-- A refusal: the dot and the reason dip and come back, in the outcome's colour.
	self.warns = Both(ringTwo, function(f)
		local warn = f:CreateAnimationGroup()
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
		warn:SetScript("OnFinished", function() f:SetAlpha(1) end)
		warn:SetScript("OnStop", function() f:SetAlpha(1) end)
		return warn
	end)

	-- A buff landed: a fine line draws itself under the name, from its left end,
	-- the bright end leading, and lets go. 0.6 s in all, the length of the
	-- outcome.
	local draw = self.lineFrame:CreateAnimationGroup()
	local lineIn = draw:CreateAnimation("Alpha")
	lineIn:SetFromAlpha(0)
	lineIn:SetToAlpha(1)
	lineIn:SetDuration(0.08)
	lineIn:SetOrder(1)
	local grow = draw:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.02, 1) end
	if grow.SetScaleTo then grow:SetScaleTo(1, 1) end
	if grow.SetOrigin then grow:SetOrigin("LEFT", 0, 0) end
	grow:SetDuration(0.30)
	grow:SetOrder(1)
	if grow.SetSmoothing then grow:SetSmoothing("OUT") end
	local lineOut = draw:CreateAnimation("Alpha")
	lineOut:SetFromAlpha(1)
	lineOut:SetToAlpha(0)
	lineOut:SetDuration(0.30)
	lineOut:SetOrder(2)
	if lineOut.SetSmoothing then lineOut:SetSmoothing("IN") end
	draw:SetScript("OnFinished", function() self.lineFrame:SetAlpha(0) end)
	draw:SetScript("OnStop", function() self.lineFrame:SetAlpha(0) end)
	self.drawAnim = draw

	-- The same on Calm: the whole line fades in where it lies and out.
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

	-- The name's bloom: a copy of its letters, in the outcome's colour, spreads
	-- a little and fades. The copy is the glow: it hugs the letters and is
	-- never a shape of its own.
	local bloom = self.echoFrame:CreateAnimationGroup()
	local swell = bloom:CreateAnimation("Scale")
	if swell.SetScaleFrom then swell:SetScaleFrom(1, 1) end
	if swell.SetScaleTo then swell:SetScaleTo(1.06, 1.06) end
	if swell.SetOrigin then swell:SetOrigin("CENTER", 0, 0) end
	swell:SetDuration(0.50)
	if swell.SetSmoothing then swell:SetSmoothing("OUT") end
	local fadeOut = bloom:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(0.50)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.50)
	if fadeOut.SetSmoothing then fadeOut:SetSmoothing("OUT") end
	bloom:SetScript("OnFinished", function() self.echoFrame:SetAlpha(0) end)
	bloom:SetScript("OnStop", function() self.echoFrame:SetAlpha(0) end)
	self.bloomAnim = bloom
	local bloomCalm = self.echoFrame:CreateAnimationGroup()
	local glowIn = bloomCalm:CreateAnimation("Alpha")
	glowIn:SetFromAlpha(0)
	glowIn:SetToAlpha(0.35)
	glowIn:SetDuration(0.15)
	glowIn:SetOrder(1)
	local glowOut = bloomCalm:CreateAnimation("Alpha")
	glowOut:SetFromAlpha(0.35)
	glowOut:SetToAlpha(0)
	glowOut:SetDuration(0.40)
	glowOut:SetOrder(2)
	bloomCalm:SetScript("OnFinished", function() self.echoFrame:SetAlpha(0) end)
	bloomCalm:SetScript("OnStop", function() self.echoFrame:SetAlpha(0) end)
	self.bloomCalm = bloomCalm

	-- The cursor's line, both ways; from and to are set for each play.
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
	local N, R, RW = Sizes(p)
	self.p, self.W, self.H, self.N, self.R, self.RW = p, W, H, N, R, RW
	self.above = above

	-- The reason and the name go into the frames that fade them.
	if not self.parented then
		kit.name:SetParent(self.nameFrame)
		kit.sub:SetParent(self.reasonBreath)
		self.parented = true
	end
	self.upper = true
	self.capsIn = nil

	local showIcon = p.showIcon and true or false
	local two = p.showSub and H >= Whisper.TwoLineHeight(fs)
	local nameH, reasonH = 1.2 * N, 1.2 * R
	self.two = two

	-- Measured from the panel's middle, up positive, for SetPoint.
	local nameY, subY, lift
	if two then
		local block = nameH + GAP + reasonH
		lift = math.min(2, math.max(0, (H - block) / 2 - 2))
		local top = block / 2 + lift
		subY = top - reasonH / 2
		nameY = top - reasonH - GAP - nameH / 2
	else
		lift = math.min(2, math.max(0, (H - nameH) / 2 - 2))
		nameY = lift
	end
	local dotY = two and subY or nameY

	-- The dot. A spell icon cut round, in its ring, or a plain disc when the
	-- icon is off: as tall as the line it leads allows, and never so large that
	-- its ring leaves the panel.
	local D, lead
	if showIcon then
		local cap = math.max(7, math.floor((two and reasonH or 0.62 * nameH) * 1.3 + 0.5))
		local room = 2 * (H / 2 - 0.5 - math.abs(dotY) - RING_PAD)
		D = math.max(7, math.min(math.floor(p.iconSize * 0.4 + 0.5), cap, math.floor(room)))
		lead = D + 2 * RING_PAD
	else
		D = math.max(5, math.floor(R * 0.7 + 0.5))
		lead = D
	end
	self.D, self.lead = D, lead
	self.dotX = PAD + lead / 2
	self.subX = math.floor(PAD + lead + DOT_GAP + 0.5)
	self.nameX = self.subX
	self.nameY, self.subY, self.dotY = nameY, subY, dotY
	self.subRoom = math.max(20, W - self.subX - PAD)
	-- The count's room: "+99" in the small size, and a unit of air before it.
	self.countRoom = math.ceil(R * 2.2 + 7)
	self.keyRoom = self.keyRoom or 0

	-- The line under the name, for a landing and for the cursor: just below the
	-- letters, held inside the panel; none where there is no room for it.
	local rectBottom = nameY - N / 2
	local lineY = math.max(nameY - nameH / 2 - 2.0, -H / 2 + 2.5)
	self.lineY = lineY
	self.lineOn = lineY + 1.5 <= rectBottom - 0.25
	for _, f in ipairs({ self.lineFrame, self.hoverFrame }) do
		f:ClearAllPoints()
		f:SetPoint("LEFT", art, "LEFT", self.nameX, lineY)
		f:SetSize(math.max(8, W - self.nameX - PAD), 1.5)
	end
	for _, t in ipairs({ self.line, self.hoverLine }) do t:SetAllPoints(t:GetParent()) end
	for _, t in ipairs({ self.lineDark, self.hoverDark }) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", t:GetParent(), "TOPLEFT", 0, 1)
		t:SetPoint("BOTTOMRIGHT", t:GetParent(), "BOTTOMRIGHT", 0, -1)
	end

	-- The dot: the icon, cut round, in its ring; or the plain disc.
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	for _, f in ipairs({ self.ringFlare, self.ringBreath }) do
		f:ClearAllPoints()
		f:SetAllPoints(art)
	end
	self.ring:ClearAllPoints()
	self.plain:ClearAllPoints()
	if showIcon then
		icon:SetSize(D, D)
		icon:SetPoint("LEFT", art, "LEFT", PAD + RING_PAD, self.dotY)
		self.ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -RING_PAD, RING_PAD)
		self.ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", RING_PAD, -RING_PAD)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep is a dot's too.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(ART .. "MaskRound") end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(true) end
		end
	else
		self.plain:SetPoint("LEFT", art, "LEFT", PAD, self.dotY)
		self.plain:SetSize(D, D)
	end

	-- The list's names start where the reason does, under it; each click area
	-- starts at its dot.
	local rowWidth = math.max(20, W - self.subX - PAD)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.pitch = math.floor(RW * 1.2 + 5.5)
	self.rowReach = self.subX - self.dotX + 5

	-- The count and the key, small, after the name; laid out by Cluster.
	kit.count:ClearAllPoints()
	kit.count:SetJustifyH("LEFT")
	self.clusterX = nil

	-- The corner marks, only while unlocked: four corners, two arms each.
	local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
	for c, corner in ipairs(corners) do
		for k = 1, 2 do
			local i = (c - 1) * 2 + k
			local dark, light = self.markDark[i], self.markLight[i]
			local horizontal = k == 1
			local w, h = MARK_ARM, MARK_WIDTH
			if not horizontal then w, h = h, w end
			local left = corner == "TOPLEFT" or corner == "BOTTOMLEFT"
			local top = corner == "TOPLEFT" or corner == "TOPRIGHT"
			local dx, dy = left and 1 or -1, top and -1 or 1
			dark:ClearAllPoints()
			dark:SetPoint(corner, art, corner, dx * 0, dy * 0)
			dark:SetSize(w + 2, h + 2)
			light:ClearAllPoints()
			light:SetPoint(corner, art, corner, dx * 1, dy * 1)
			light:SetSize(w, h)
			dark:SetVertexColor(0, 0, 0, 0.55)
			light:SetVertexColor(MARK_GOLD[1], MARK_GOLD[2], MARK_GOLD[3], 0.95)
		end
	end
	local unlocked = p.locked == false
	self.unlocked = unlocked

	self:QuietShake(true)

	-- Everything this look draws, shown, and then what waits: the frames of
	-- motion parked, the dots for PaintQueue, the dot's ring for the reason's
	-- paint.
	for _, x in ipairs(self.own) do x:Show() end
	self.marksFrame:SetShown(unlocked)
	for _, d in ipairs(self.dots) do d:Hide() end
	self.ring:SetShown(showIcon)
	self.plain:SetShown(not showIcon)
	for _, echo in ipairs(self.echoes) do echo:Hide() end
	for _, f in ipairs({ self.ringFlare, self.reasonFlare, self.nameFrame }) do f:SetAlpha(1) end
	for _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(BREATH_REST) end
	for _, f in ipairs({ self.lineFrame, self.hoverFrame, self.echoFrame }) do f:SetAlpha(0) end
	self.listShown = nil
	self:Chip(false)
	self.combat, self.hovered, self.washFor, self.outcomeOn = nil, nil, nil, nil
	self:SetInk(1, 1)

	return self.nameX, PAD + self.countRoom
end

function Whisper:Styled(p, twoLine)
	local kit = self.kit
	local fit, ink = kit.fit, kit.ink
	local N, R, RW = self.N, self.R, self.RW
	-- No panel, so no panel colour to read against: the letters are light with
	-- a black outline of their own, on any ground. The ground is taken to be
	-- the dusky world Prompt judges a see-through panel over.
	ink.light, ink.lo, ink.hi = true, 0.02, 0.02
	ink.codes = {}
	ink.sub = { NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] }
	ink.rowReason = ROW_REASON
	fit.flags = "OUTLINE"
	local path = fit.path
	local function face(fs, size)
		SetFace(fs, path, size, "OUTLINE")
		fit.base[fs], fit.size[fs] = size, size
		fs:SetShadowColor(0, 0, 0, 0.65)
		fs:SetShadowOffset(1, -1)
	end
	face(kit.name, N)
	face(kit.sub, R)
	face(kit.count, R)
	face(self.keyText, R)
	for _, fs in ipairs(kit.rows) do face(fs, RW) end

	-- The name in the colour the player set, which is light unless they made it
	-- otherwise; a colour too dark to stand in a black outline is taken towards
	-- white.
	local c = p.fontColor or {}
	local r, g, b, a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
	if (Luminance(r, g, b) + 0.05) / 0.05 < 7 then r, g, b = Mix(r, g, b, 0.9) end
	kit.name:SetTextColor(r, g, b, a)
	kit.count:SetTextColor(SMALL[1], SMALL[2], SMALL[3], 1)
	self.keyText:SetTextColor(SMALL[1], SMALL[2], SMALL[3], 1)
	for _, fs in ipairs(kit.rows) do fs:SetTextColor(ROW_INK[1], ROW_INK[2], ROW_INK[3], 1) end
end

function Whisper:Hide()
	local kit = self.kit
	if not kit then return end
	for _, x in ipairs(self.own) do x:Hide() end
	for _, group in ipairs(self.breaths) do group:Stop() end
	for _, list in ipairs({ self.arrivals, self.warns }) do
		for _, group in ipairs(list) do group:Stop() end
	end
	for _, anim in ipairs({ self.nameArrival, self.nameArrivalCalm, self.drawAnim, self.calmAnim, self.bloomAnim,
		self.bloomCalm, self.hoverAnim }) do
		anim:Stop()
	end
	-- Stop parks nothing on a fade that has already finished, and the cursor
	-- leaves for the next look.
	self.hoverFrame:SetAlpha(0)
	self.lineFrame:SetAlpha(0)
	self.echoFrame:SetAlpha(0)
	self:QuietShake(false)
	self.upper = false
	-- The lines go back under the text layer, where the built-in looks keep them.
	if self.parented then
		kit.name:SetParent(kit.textLayer)
		kit.sub:SetParent(kit.textLayer)
		self.parented = nil
	end
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
	kit.fit.room[kit.name] = nil
	kit.fit.flags = ""
	self.combat, self.hovered, self.washFor, self.listShown, self.outcomeOn = nil, nil, nil, nil, nil
end

---------------------------------------------------------------------------
-- the lines
---------------------------------------------------------------------------

function Whisper:PlaceLines()
	local kit = self.kit
	local name, sub = kit.name, kit.sub
	-- What the small text after the name keeps: the key and the count while they
	-- are up. The name keeps 20 units: the two points never cross.
	local right = PAD
	if self.keyUp then right = right + self.keyRoom end
	if self.countUp then right = right + self.countRoom end
	right = math.min(right, math.max(PAD, self.W - self.nameX - 20))
	name:SetPoint("LEFT", self.nameX, self.nameY)
	name:SetPoint("RIGHT", -right, self.nameY)
	-- The room the name is fitted to is the one kept for the small text, which
	-- Prompt's own inset does not know about.
	kit.fit.room[name] = math.max(20, self.W - self.nameX - right)
	if kit.fit.twoLine then
		sub:SetPoint("LEFT", self.subX, self.subY)
		sub:SetWidth(self.subRoom)
		kit.fit.room[sub] = self.subRoom
	end
end

-- The count and the key follow the name, a baseline with it, small. Placed
-- only where the name's width or what is up has changed: the scan repaints
-- this several times a second.
function Whisper:Cluster()
	local kit = self.kit
	local width = self.nameWidth
	if not (width and self.nameX) then return end
	if not (self.countUp or self.keyUp) then return end
	local x = math.floor(self.nameX + width + 7 + 0.5)
	if x == self.clusterX and self.keyUp == self.clusterKey and self.countUp == self.clusterCount then return end
	self.clusterX, self.clusterKey, self.clusterCount = x, self.keyUp, self.countUp
	local y = self.nameY - 0.2 * (self.N - self.R)
	if self.keyUp then
		self.keyText:ClearAllPoints()
		self.keyText:SetPoint("LEFT", kit.textLayer, "LEFT", x, y)
		x = x + self.keyRoom
	end
	if self.countUp then
		kit.count:ClearAllPoints()
		kit.count:SetPoint("LEFT", kit.textLayer, "LEFT", x, y)
	end
end

-- Called when the name has been set or refitted: where the small text after it
-- goes depends on how wide it came out.
function Whisper:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.name then return end
	self.nameWidth = kit.fit.drawn[fs] or kit.TextWidth(fs)
	self:Cluster()
end

-- Whether the name, at its smallest, still fits with `room` kept at the right.
function Whisper:NameFits(room)
	local kit = self.kit
	local fit = kit.fit
	local width, size, base = self.nameWidth, fit.size[kit.name], fit.base[kit.name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.nameX - PAD - room + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Only where
-- a press casts something: the button armed (a fight's frozen macro too,
-- unlocked or not), never over a held panel with nothing armed, nor over an
-- outcome.
function Whisper:KeyLabel()
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

-- Run on every repaint: the count and the key up or down, each stepping aside
-- for a paint in which the name would otherwise be cut. Returns whether the
-- count is up.
function Whisper:Chip(on)
	local kit = self.kit
	local fit = kit.fit
	self.nameWidth = fit.drawn[kit.name] or kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	if key ~= self.keyLabel then
		self.keyLabel = key
		if key then
			self.keyText:SetText("[" .. key .. "]")
			local w = kit.TextWidth(self.keyText) or (self.R * 3)
			self.keyRoom = math.ceil(w + 7)
		else
			self.keyRoom = 0
		end
		fit.right = nil
	end
	local keyUp = key ~= nil and self:NameFits(self.keyRoom)
	if keyUp ~= self.keyUp then
		self.keyUp = keyUp
		fit.right = nil
	end
	self.keyText:SetShown(keyUp)

	local countUp = on and self:NameFits((keyUp and self.keyRoom or 0) + self.countRoom) or false
	if countUp ~= self.countUp then
		self.countUp = countUp
		fit.right = nil
	end
	if countUp then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
	end
	kit.count:SetShown(countUp)
	self:Cluster()
	return countUp
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The ink's alpha, for the fight: the icon dims and the text a little; the
-- reason keeps its colour, so it still reads.
function Whisper:SetInk(ink, text)
	local kit = self.kit
	kit.icon:SetAlpha(ink)
	if kit.cooldown then kit.cooldown:SetAlpha(ink) end
	-- On the lines themselves, not on textLayer: Prompt's cross-fade plays on
	-- textLayer, and an animation's alpha replaces its frame's own.
	kit.name:SetAlpha(text)
	kit.sub:SetAlpha(text)
	kit.count:SetAlpha(text)
	self.keyText:SetAlpha(text)
end

-- The marks in one colour. `ring`: the dot's ring carries it. `strength`: how
-- far the reason line is taken towards it, the rest being the neutral grey.
function Whisper:Tint(r, g, b, ring, strength)
	local kit = self.kit
	if ring then
		self.ring:SetVertexColor(r, g, b, 0.95)
	else
		self.ring:SetVertexColor(1, 1, 1, 0.30)
	end
	self.plain:SetVertexColor(r, g, b, 0.95)
	self.hoverLine:SetVertexColor(r, g, b, 0.80)
	local tint = self.tint or {}
	tint[1], tint[2], tint[3] = r, g, b
	self.tint = tint
	-- The reason: its colour taken a little towards white, and held to the
	-- contrast the outline gives it.
	local k = strength or 0.18
	local sr, sg, sb = Mix(r, g, b, k)
	sr, sg, sb = OnBlack(sr, sg, sb, 7)
	kit.sub:SetTextColor(sr, sg, sb, 1)
end

function Whisper:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]
	end
	self:Tint(r, g, b, (mode == "icon" or mode == "both") and true or false, mode == "off" and 0 or 0.18)
	-- A refusal greyed the icon; a fight keeps it grey.
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

function Whisper:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	if on then
		self:SetInk(INK_COMBAT, TEXT_COMBAT)
		for _, group in ipairs(self.breaths) do group:Stop() end
		for _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(1) end
	else
		self:SetInk(1, 1)
		for _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(BREATH_REST) end
	end
	self.kit.icon:SetDesaturated(on)
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

local function PlayAll(groups)
	for _, group in ipairs(groups) do group:Play() end
end

local function StopAll(groups)
	for _, group in ipairs(groups) do group:Stop() end
end

function Whisper:Attention(isNew, _, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" then
		self:StopAttention()
		return
	end
	-- The dot and the reason come up from nothing when somebody owed gets to the
	-- top, and the name rises after them: a rise on Full, a fade on Calm.
	if isNew and not self.combat then
		StopAll(self.warns)
		StopAll(self.arrivals)
		PlayAll(self.arrivals)
		self.nameArrival:Stop()
		self.nameArrivalCalm:Stop()
		if full then self.nameArrival:Play() else self.nameArrivalCalm:Play() end
	end
	if flashStyle == "pulse" and not self.combat then
		if full then
			if not self.breaths[1]:IsPlaying() then PlayAll(self.breaths) end
		else
			-- Calm: nothing loops. The marks are held, a little brighter.
			StopAll(self.breaths)
			for _, f in ipairs({ self.ringBreath, self.reasonBreath }) do f:SetAlpha(BREATH_HIGH) end
		end
	else
		self:StopAttention()
	end
end

function Whisper:StopAttention()
	StopAll(self.breaths)
	local rest = self.combat and 1 or BREATH_REST
	self.ringBreath:SetAlpha(rest)
	self.reasonBreath:SetAlpha(rest)
end

-- The line drawn under the name in `r, g, b`, and the bloom of its letters: from
-- the left on Full, the whole line fading in and out on Calm.
function Whisper:Draw(full, r, g, b)
	local kit = self.kit
	local width = self.nameWidth or kit.TextWidth(kit.name)
	if not width then return end
	width = math.max(8, math.min(width, self.W - self.nameX - PAD))
	self.drawAnim:Stop()
	self.calmAnim:Stop()
	self.bloomAnim:Stop()
	self.bloomCalm:Stop()
	-- The bloom: a copy of the name, in the outcome's colour, over the letters'
	-- own place.
	local path, size = kit.name:GetFont()
	if path then
		local bare = Bare(kit.name:GetText())
		for _, echo in ipairs(self.echoes) do
			SetFace(echo, path, size, "")
			echo:SetWidth(width + 8)
			echo:SetText(bare)
			echo:SetTextColor(r, g, b, 1)
			echo:SetShadowOffset(0, 0)
			echo:Show()
		end
		self.echoFrame:ClearAllPoints()
		self.echoFrame:SetPoint("LEFT", kit.textLayer, "LEFT", self.nameX, self.nameY)
		self.echoFrame:SetSize(width, 1.2 * self.N)
	end
	if self.lineOn then
		self.line:SetVertexColor(r, g, b, 1)
		self.lineDark:SetVertexColor(0, 0, 0, 0.55)
		self.lineFrame:SetWidth(width)
		self.lineFrame:SetHeight(1.5)
		if full then self.drawAnim:Play() else self.calmAnim:Play() end
	end
	if full then self.bloomAnim:Play() else self.bloomCalm:Play() end
end

function Whisper:Flourish(kind)
	if kind == "failed" then
		-- The ring and the reason dip and come back red-amber (Tint, from
		-- PaintOutcome); the text's nudge is Prompt's shake, scaled by QuietShake.
		StopAll(self.arrivals)
		StopAll(self.warns)
		PlayAll(self.warns)
	elseif kind == "cast" then
		-- Nothing for a cast nobody confirmed: a flourish is a claim.
		local o = OUTCOME.cast
		self:Draw(true, Mix(o[1], o[2], o[3], 0.25))
	end
end

function Whisper:StopFlourishes()
	StopAll(self.warns)
	self.drawAnim:Stop()
	self.calmAnim:Stop()
	self.bloomAnim:Stop()
	self.bloomCalm:Stop()
end

function Whisper:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	if on and self.lineOn then
		local width = self.nameWidth or self.kit.TextWidth(self.kit.name)
		if width then
			self.hoverFrame:SetWidth(math.max(8, math.min(width, self.W - self.nameX - PAD)))
			self.hoverDark:SetVertexColor(0, 0, 0, 0.55)
		end
	end
	local anim = self.hoverAnim
	local from = self.hoverFrame:GetAlpha()
	anim:Stop()
	anim.to = (on and self.lineOn) and 1 or 0
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
	self.outcomeOn = true
	kit.SetLine(kit.name, stays and who or lead)
	self:Tint(o[1], o[2], o[3], true, 0.30)
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
	self.outcomeOn = nil
	if not self.washFor then return end
	self.washFor = nil
	self.drawAnim:Stop()
	self.calmAnim:Stop()
	self.bloomAnim:Stop()
	self.bloomCalm:Stop()
	self.lineFrame:SetAlpha(0)
	self.echoFrame:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

function Whisper:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i, dot in ipairs(self.dots) do
		if not (list and i <= shown) then dot:Hide() end
	end
	if not list then
		self.listShown = nil
		return
	end

	for i = 1, shown do
		local dot = self.dots[i]
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		dot:SetVertexColor(c[1], c[2], c[3], 0.95)
		dot:Show()
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if shown == self.listShown and above == self.listAbove then return end
	self.listShown, self.listAbove, self.above = shown, above, above
	local pitch = self.pitch
	local size = math.max(4, math.floor(self.RW * 0.42 + 0.5))
	for i = 1, shown do
		local fs, dot = kit.rows[i], self.dots[i]
		-- Row centres, counted from the panel's edge the list hangs off.
		local y, edge
		if above then
			y = 4 + (shown - i) * pitch + pitch / 2
			edge = "TOPLEFT"
		else
			y = -(4 + (i - 1) * pitch + pitch / 2)
			edge = "BOTTOMLEFT"
		end
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, edge, self.subX, y)
		dot:ClearAllPoints()
		dot:SetPoint("CENTER", art, edge, self.dotX, y)
		dot:SetSize(size, size)
	end
end
