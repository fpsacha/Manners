-- Manners -- the Slate look: a broadcast lower-third, every edge a slant.
--
-- Nothing on it is rounded or level. A dark plate leans to the right (its top
-- edge shifted, its two ends cut on the slant), a bold blade in the reason's
-- colour runs down its left end, and a thin bar in the same colour is the
-- plate's ledge. The spell icon sits in a frame of its own with its two sharp
-- corners cut. The name is a condensed face in capitals; the reason is a small
-- slanted tag under it, in the reason's colour, in capitals too. A diagonal
-- hatch fills the plate's far end. At rest that is all.
--
-- The ledge is also the clock. While the global cooldown runs it goes dark and
-- is cut into segments, lit, that drop out one by one towards the left; when
-- the last is gone the button is ready ("ready in" says the same in words).
-- Each segment is a texture with one fade, started with a delay from the
-- cooldown's own start and length (a wrapper on the Cooldown frame, which
-- Prompt drives), so nothing polls and nothing runs on a frame script: it
-- replaces the sweep, which Slate draws at no strength.
--
-- The motion is hard and short:
--   * a favour arriving: the ledge, the plate, the blade and the tag slide in
--     from the left one after another on a hard ease-out, the blade flashes
--     white, the icon drops in;
--   * somebody owed: the blade heats (warm white) and a streak of light runs
--     over the plate, a few times, and then it stops;
--   * a landing: the plate is washed white-to-green by a streak that crosses
--     it, the tag snaps in as the verdict in green, two hexagons spread from
--     the icon;
--   * a refusal: the plate jerks sideways in steps while a red and an amber
--     copy of it slip past (a glitch), the verdict says why in red, a hexagon
--     snaps onto the icon, the text shakes (Prompt's);
--   * a fight: the accent goes to a muted steel and the lights go out.
-- Calm is fades only: none of the above moves; the cooldown segments stay,
-- because they are information.
--
-- (A fight dims the name and the chips by their own alpha, never the tag.)
--
-- Rules it keeps (tests/scenarios/look-slate.lua, hunt35 and hunt37): nothing
-- that stays on screen is additive; nothing is rounded; every slant lies inside
-- the width and height the prompt is given and never under a line of text at
-- any width; the rings stay in the room between the icon and the text; every
-- frame of light is under the text's frame level; nothing that moves over the
-- text is scaled; the secure list names are anchored to frames, never to a
-- region; no pcall per repaint; capitals are ASCII only, so a name in another
-- script is left as it is.
-- Every region is a texture from Textures/Slate (tools/make_slate_textures.py).
-- The interface this file implements is described at the top of Looks/Looks.lua.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Slate\\Slate_"

local Slate = ns.Looks.Register("slate", {
	name = L["Slate -- slanted plates, accent blade, segmented timer"],
	title = L["Slate"],
	description = L["slanted plates, accent blade, segmented timer"],
	order = 6,
	-- The plate holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.25,
})

-- How far the top edge leans right per unit of height, and how wide a plate's
-- end is as a fraction of its height: the art is drawn for both
-- (tools/make_slate_textures.py, SLANT and CAP, must agree).
local SLANT, CAP = 0.28, 0.75
-- The widths of the blade (thick and thin slash with the gap between, in plate
-- heights, so the ground it covers), the list's notch and the streak, as
-- fractions of the height they are shown at.
local BLADE_GROUND = 0.15 + 0.07 + 0.045
local BLADE_ASPECT = BLADE_GROUND + SLANT
local NOTCH_ASPECT = 0.30 + SLANT
local STREAK_ASPECT = 0.30 + SLANT
-- Where the effect rings' line sits in their file and how far out they are
-- seen, as fractions of its half-width (FX_PEAK in the generator, and
-- hunt37-effects reads the file).
local FX_PEAK, FX_EDGE = 0.70, 0.875
-- The plate's file in three: the left end, a strip of the middle, the right end.
local PLATE_CUT = { { 0, 0.375 }, { 0.390625, 0.609375 }, { 0.625, 1 } }

-- The plate's own slate, for a panel colour nobody chose: a cool dark, a shade
-- lighter along the top.
local PLATE_TOP, PLATE_BOTTOM, PLATE_ALPHA = { 0.112, 0.124, 0.158 }, { 0.050, 0.056, 0.076 }, 0.95
local NAME_INK = { 0.97, 0.98, 1.00 }
-- The tag's text on a colour: whichever of these the colour holds best.
local INK_DARK, INK_LIGHT = { 0.035, 0.040, 0.055 }, { 1, 1, 1 }
local STEEL = { 0.50, 0.56, 0.66 }
local NEUTRAL = { 0.62, 0.67, 0.76 }
local WARM = { 1.00, 0.88, 0.66 }
-- The outcomes' own colours: the blade, the tag, the wash.
local OUTCOME = {
	cast = { 0.30, 0.88, 0.48 },
	failed = { 1.00, 0.36, 0.28 },
	sent = { 0.91, 0.82, 0.45 },
}
-- The two copies of the plate a refusal slips past it: red and amber.
local GHOSTS = { { 1.00, 0.22, 0.18 }, { 1.00, 0.72, 0.20 } }
-- What a fight does: the text dims, the icon greys and dims.
local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70
-- The owed breath: the blade's heat lifts to this and back, and the streak runs
-- once a breath, this many breaths of 2.5 s, then it all stops.
local HEAT_PEAK = 0.72
local BREATHS, BREATH = 3, 1.25
-- How bright the plate's hairline rests, and lifts to under the cursor.
local EDGE_REST = 0.60
-- The segments of the cooldown bar, at most, and how far apart they stand.
local SEGMENTS, SEGMENT_PITCH = 24, 9
local COMMAND = "CLICK MannersPrompt:LeftButton"
-- The condensed face, where the client has it: every client's own fonts list
-- it for the Latin and Cyrillic alphabets (Blizzard_Fonts_Shared/Shared/
-- GameFonts.xml, Number12Font), and not for Korean or Chinese, whose clients
-- keep the font they draw their own writing in.
local CONDENSED = "Fonts\\ARIALN.TTF"
local OWN_FACE = { koKR = true, zhCN = true, zhTW = true }

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
-- The thickness of the ledge: a ninth of the height, from 3 to 6.
local function Ledge(height) return Clamp(math.floor(height / 11 + 0.5), 3, 6) end

-- The name, the gap and the tag as one block, the room round it and the ledge.
function Slate.TwoLineHeight(fontSize)
	return math.ceil((fontSize + 2) + 2 + (SubSize(fontSize) + 6) + 6 + 4)
end

-- The ring is the icon's frame, the stripe is the blade, the plate's ledge and
-- the tag together: the blade is the look, so it carries the reason in every
-- mode but "off".
function Slate.AccentCarriers(p)
	local mode = p.accentMode or "icon"
	return (mode == "icon" or mode == "both") and p.showIcon and true or false, mode ~= "off"
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

-- The face for the names and the tag: the condensed one, unless the player
-- chose a font of their own (AceDB strips a value equal to the default, so only
-- another is a choice) or the client writes in an alphabet that file lacks.
local function Face(p)
	local d = ns.defaults and ns.defaults.profile.prompt.font
	if type(p.font) == "string" and p.font ~= d then return nil end
	if OWN_FACE[ns.LOCALE or "enUS"] then return nil end
	return CONDENSED
end

---------------------------------------------------------------------------
-- capitals: ASCII only, outside the game's escapes
---------------------------------------------------------------------------

local UPPER = {}
for i = 0, 25 do UPPER[string.char(97 + i)] = string.char(65 + i) end

-- Lua 5.1's upper() is byte by byte and takes the C locale's idea of a letter:
-- a name in another script has bytes that would be changed. Only a-z is, and
-- colour codes, hyperlinks and textures are put by while it is done.
local function Capitals(text)
	local held = {}
	local function hold(s)
		held[#held + 1] = s
		return "\1" .. #held .. "\2"
	end
	local out = text:gsub("|[cC]%x%x%x%x%x%x%x%x", hold):gsub("|[HT].-|[ht]", hold):gsub("|%a", hold)
	out = out:gsub("[a-z]", UPPER)
	return (out:gsub("\1(%d+)\2", function(n) return held[tonumber(n)] end))
end

-- A line's text in capitals, the last one asked for remembered (the scan
-- repaints the same words several times a second).
function Slate:Upper(fs, text)
	if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return text end
	local seen = self.said[fs]
	if seen and seen[1] == text then return seen[2] end
	-- The tag is a colour of its own: a colour code picked for a dark panel
	-- would be unreadable on it, so the reason's words take the tag's ink.
	local up = text
	if fs == self.kit.sub then up = up:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", "") end
	if up:find("[a-z]") then up = Capitals(up) end
	if seen then
		seen[1], seen[2] = text, up
	else
		self.said[fs] = { text, up }
	end
	return up
end

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

-- A slanted plate cut in three, from one file: TL end, middle, right end.
local function Slabs(parent, layer, sublevel, file, keep)
	local s = {}
	for i = 1, 3 do
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(file)
		t:SetTexCoord(PLATE_CUT[i][1], PLATE_CUT[i][2], 0, 1)
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

-- A plate laid over a box: the ends CAP of its height wide, so the slant is the
-- same at any size.
local function PlaceSlabs(s, rel, x0, y0, x1, y1)
	local cap = math.min(CAP * (y1 - y0), (x1 - x0) / 2)
	Box(s[1], rel, x0, y0, x0 + cap, y1)
	Box(s[2], rel, x0 + cap, y0, x1 - cap, y1)
	Box(s[3], rel, x1 - cap, y0, x1, y1)
end

-- ...and over a frame, `height` tall: for the chips, which change width.
local function PlaceSlabsIn(s, box, height)
	local cap = CAP * height
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

local function Each(s, method, ...)
	for _, t in ipairs(s) do t[method](t, ...) end
end

local function Colour(s, r, g, b, a)
	for _, t in ipairs(s) do t:SetVertexColor(r, g, b, a) end
end

---------------------------------------------------------------------------
-- motion: every animation here runs on the region it moves, parked between
-- plays, so nothing is left lit or displaced when it stops. None of it scales
-- anything that crosses the text: a slide and a fade do not need the room.
---------------------------------------------------------------------------

-- Parks `region` at `rest` alpha when the group ends or is stopped (or where
-- the group was last sent, `group.to`, for a fade that goes either way).
local function Park(group, region, rest)
	local function park() region:SetAlpha(group.to or rest or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

local function Alpha(group, from, to, duration, order, smoothing, delay)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

local function Slide(group, dx, dy, duration, order, smoothing, delay)
	local a = group:CreateAnimation("Translation")
	a:SetOffset(dx, dy)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay and delay > 0 and a.SetStartDelay then a:SetStartDelay(delay) end
	if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
	return a
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, peak, up, 1, "OUT")
	Alpha(g, peak, 0, down, 2, "OUT")
	Park(g, region, 0)
	return g
end

-- Held out of sight for `delay`, put `dx` to the left and brought in on a hard
-- ease-out: the slide of an arrival. What it moves out it moves back.
local function SlideIn(region, dx, delay, duration, rest)
	local g = region:CreateAnimationGroup()
	Alpha(g, 0, 0, delay + 0.01, 1)
	Slide(g, -dx, 0, 0.01, 1)
	Alpha(g, 0, 1, 0.06, 2, "OUT")
	Slide(g, dx, 0, duration, 2, "OUT")
	Park(g, region, rest or 1)
	return g
end

-- Steps that sum to nothing, each `step` long: the region ends where it began.
local function Jerk(region, steps, step, alphas)
	local g = region:CreateAnimationGroup()
	for i, dx in ipairs(steps) do Slide(g, dx, 0, step, i) end
	if alphas then
		for i, pair in ipairs(alphas) do Alpha(g, pair[1], pair[2], step, i) end
	end
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
	self.said = {}
	local base = art:GetFrameLevel()
	local function keep(x) own[#own + 1] = x return x end
	local function anim(g) anims[#anims + 1] = g return g end
	local function tex(parent, layer, sublevel, file)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		t:SetTexture(ART .. file)
		return keep(t)
	end
	-- A frame of light or of the plate's furniture, a few levels over the art
	-- and under the text (hunt37-effects).
	local function frame(level, parent)
		local f = CreateFrame("Frame", nil, parent or art)
		f:SetFrameLevel(base + level)
		return keep(f)
	end
	self.frame = frame

	-- The ground, on art itself: the ledge, the plate and the hatch, under the
	-- icon and the list's strips, which are art's too.
	self.ledge = Slabs(art, "BACKGROUND", -8, ART .. "Plate", keep)
	self.plate = Slabs(art, "BACKGROUND", -6, ART .. "Plate", keep)
	self.hatch = tex(art, "BACKGROUND", -5, "Hatch")

	-- The plate's hairline, on a frame of its own so the cursor can lift it.
	self.edgeFrame = frame(1)
	self.edge = Slabs(self.edgeFrame, "ARTWORK", 0, ART .. "Edge", keep)

	-- The icon: a dark plate under it (so a fade leaves a hexagon, never the
	-- world), the line round it and the flash over it.
	self.iconPlate = tex(art, "ARTWORK", -3, "IconMask")
	self.iconFrame = frame(1)
	self.iconEdge = tex(self.iconFrame, "ARTWORK", 0, "IconEdge")
	self.iconFlash = tex(self.iconFrame, "ARTWORK", 1, "IconMask")
	self.iconFlash:SetAlpha(0)

	-- The blade, its heat (warm white, which the owed breath lifts) and its
	-- flash (white, for the arrival).
	self.bladeFrame = frame(2)
	self.blade = tex(self.bladeFrame, "ARTWORK", 0, "Blade")
	self.heat = tex(self.bladeFrame, "ARTWORK", 1, "Blade")
	self.heat:SetAlpha(0)
	self.flash = tex(self.bladeFrame, "ARTWORK", 2, "Blade")
	self.flash:SetAlpha(0)
	-- The warm tone of the breath, which hunt35-effects looks for.
	self.warmRing = self.heat

	-- The streak of light that runs over the plate for somebody owed, and the
	-- two things that cross it for a landing: a wash and the white streak ahead
	-- of it.
	self.streakFrame = frame(2)
	self.streakFrame:SetAlpha(0)
	self.streak = tex(self.streakFrame, "ARTWORK", 0, "Streak")
	self.washFrame = frame(2)
	self.washFrame:SetAlpha(0)
	self.wash = Slabs(self.washFrame, "ARTWORK", 0, ART .. "Plate", keep)
	self.bandFrame = frame(2)
	self.bandFrame:SetAlpha(0)
	self.band = tex(self.bandFrame, "ARTWORK", 0, "Streak")

	-- The two copies a refusal slips past the plate.
	self.ghostFrames, self.ghosts, self.ghostEdges = {}, {}, {}
	for i = 1, 2 do
		self.ghostFrames[i] = frame(2)
		self.ghostFrames[i]:SetAlpha(0)
		self.ghosts[i] = Slabs(self.ghostFrames[i], "ARTWORK", 0, ART .. "Plate", keep)
		self.ghostEdges[i] = Slabs(self.ghostFrames[i], "ARTWORK", 1, ART .. "Edge", keep)
	end

	-- The cooldown: the ledge goes dark (a cover) and its segments are lit over
	-- it, each a texture of its own with a fade of its own.
	self.coolBox = frame(2)
	self.coolBox:SetAlpha(0)
	self.cover = Slabs(self.coolBox, "ARTWORK", 0, ART .. "Plate", keep)
	self.segs = {}
	for i = 1, SEGMENTS do
		self.segs[i] = { tex = tex(self.coolBox, "ARTWORK", 1, "Seg") }
	end

	-- The tag: a slanted plate under the name, holding the reason in the
	-- reason's colour. Its text is on textLayer.
	self.tagFrame = frame(3)
	self.tag = Slabs(self.tagFrame, "ARTWORK", 0, ART .. "Plate", keep)

	-- The rings that spread from the icon when a buff lands and the one that
	-- closes on it when one is refused, in frames over the art and under the
	-- text. No echo of the icon: the frame's own flash is the arrival's.
	self.fx = kit.FX(art, nil, true)
	for _, f in ipairs(self.fx.frames) do
		keep(f)
		f:SetFrameLevel(base + 2)
	end
	kit.RingArt(ART .. "FxRing", FX_PEAK, FX_EDGE)

	-- The chips at the right, over the plate; their text is on textLayer. The
	-- count's and the bound key's.
	self.chipFrame = frame(3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = Slabs(self.chipFrame, "ARTWORK", 1, ART .. "Plate", keep)
	self.keyChip = Slabs(self.chipFrame, "ARTWORK", 1, ART .. "Plate", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)

	-- The list: a slanted strip for each row, with a notch in the row's reason
	-- colour.
	self.strips = {}
	for i = 1, #kit.rows do
		self.strips[i] = {
			plate = Slabs(art, "BACKGROUND", -6, ART .. "Plate", keep),
			notch = tex(art, "ARTWORK", 1, "Notch"),
		}
	end

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Capitals on the lines that carry names and reasons, while this look is up.
	for _, fs in ipairs({ kit.name, kit.sub }) do self:Capitalise(fs) end
	for _, fs in ipairs(kit.rows) do self:Capitalise(fs) end

	self:BuildAnimations(anim)
	self:WrapCooldown()
end

-- The line's SetText, wrapped once: its words go through Upper while this look
-- is the one in use, and untouched otherwise.
function Slate:Capitalise(fs)
	if fs.mannersCapitals then return end
	fs.mannersCapitals = true
	local set = fs.SetText
	fs.SetText = function(line, text, ...)
		if Slate.active then text = Slate:Upper(line, text) end
		return set(line, text, ...)
	end
end

function Slate:BuildAnimations(anim)
	local icon = self.kit.icon

	-- The owed breath: the blade's heat, and the streak that runs over the
	-- plate once a breath (a few: see Attention).
	local heat = self.heat:CreateAnimationGroup()
	heat:SetLooping("BOUNCE")
	Alpha(heat, 0, HEAT_PEAK, BREATH, 1, "IN_OUT")
	Park(heat, self.heat, 0)
	local run = self.streakFrame:CreateAnimationGroup()
	run:SetLooping("REPEAT")
	self.streakMove = Slide(run, 100, 0, 0.55, 1, "IN_OUT")
	Alpha(run, 0, 0.55, 0.14, 1, "OUT")
	Alpha(run, 0.55, 0, 0.30, 1, "IN", 0.25)
	Alpha(run, 0, 0, 2 * BREATH - 0.55, 2)
	Park(run, self.streakFrame, 0)
	self.pulse = { anim(heat), anim(run) }

	-- A favour arriving: the ledge, the plate, the blade and the tag slide in
	-- one after another, the icon drops in, the blade flashes white.
	local arrive = {}
	local function into(g) arrive[#arrive + 1] = anim(g) end
	for _, t in ipairs(self.ledge) do into(SlideIn(t, 34, 0, 0.20)) end
	for _, t in ipairs(self.plate) do into(SlideIn(t, 26, 0.04, 0.18)) end
	into(SlideIn(self.hatch, 26, 0.04, 0.18))
	for _, t in ipairs(self.edge) do into(SlideIn(t, 26, 0.04, 0.18)) end
	into(SlideIn(self.bladeFrame, 16, 0.08, 0.16))
	into(SlideIn(self.tagFrame, 12, 0.12, 0.14))
	into(SlideIn(self.iconFrame, 8, 0.10, 0.12))
	local drop = icon:CreateAnimationGroup()
	Alpha(drop, 0, 0, 0.11, 1)
	Slide(drop, -8, 0, 0.01, 1)
	Alpha(drop, 0, 1, 0.06, 2, "OUT")
	Slide(drop, 8, 0, 0.12, 2, "OUT")
	Park(drop, icon, 1)
	into(drop)
	into(Flash(self.flash, 1, 0.05, 0.22))
	self.arrive = arrive
	-- What the arrival moves, to be moved back when it is stopped: the ledge's
	-- slide is the one `landing` leaves alone.

	-- A landing: a streak of white crosses the plate (a translation, from the
	-- left end to the right), a wash of green follows it and fades, the tag
	-- snaps in as the verdict, the icon flashes.
	local wash = self.washFrame:CreateAnimationGroup()
	Alpha(wash, 0, 0.38, 0.08, 1, "OUT", 0.04)
	Alpha(wash, 0.38, 0, 0.36, 2, "IN")
	Park(wash, self.washFrame, 0)
	local band = self.bandFrame:CreateAnimationGroup()
	self.bandMove = Slide(band, 100, 0, 0.24, 1, "OUT")
	Alpha(band, 0, 1, 0.04, 1, "OUT")
	Alpha(band, 1, 0, 0.12, 1, "IN", 0.14)
	Park(band, self.bandFrame, 0)
	local snap = self.tagFrame:CreateAnimationGroup()
	Alpha(snap, 0, 0, 0.01, 1)
	Slide(snap, -10, 0, 0.01, 1)
	Alpha(snap, 0, 1, 0.05, 2, "OUT")
	Slide(snap, 10, 0, 0.09, 2, "OUT")
	Park(snap, self.tagFrame, 1)
	self.landing = { anim(wash), anim(band), anim(snap), anim(Flash(self.iconFlash, 0.45, 0.05, 0.22)),
		anim(Flash(self.flash, 0.9, 0.04, 0.24)) }

	-- A refusal: the plate jerks in steps that sum to nothing and die away, a
	-- red copy and an amber one slip past it, the icon and the blade flash.
	local refusal = {}
	local plateSteps = { -3, 5, -4, 3, -2, 1 }
	local function jerk(region, steps, alphas)
		refusal[#refusal + 1] = anim(Jerk(region, steps, 0.04, alphas))
	end
	for _, t in ipairs(self.plate) do jerk(t, plateSteps) end
	jerk(self.hatch, plateSteps)
	local fades = { { 0, 0.85 }, { 0.85, 0.85 }, { 0.85, 0.7 }, { 0.7, 0.5 }, { 0.5, 0.25 }, { 0.25, 0 } }
	local ghostSteps = { { -5, 8, -6, 2, 1 }, { 6, -9, 5, -3, 1 } }
	for i, frameOf in ipairs(self.ghostFrames) do
		local g = Jerk(frameOf, ghostSteps[i], 0.04, fades)
		Park(g, frameOf, 0)
		refusal[#refusal + 1] = anim(g)
	end
	refusal[#refusal + 1] = anim(Flash(self.iconFlash, 0.45, 0.04, 0.2))
	refusal[#refusal + 1] = anim(Flash(self.flash, 0.8, 0.04, 0.22))
	self.refusal = refusal

	-- The cooldown: the whole bar is up for as long as it runs, then fades; each
	-- segment drops out at its own moment (Cool sets the moments).
	local up = self.coolBox:CreateAnimationGroup()
	self.coolHold = Alpha(up, 1, 1, 1, 1)
	Alpha(up, 1, 0, 0.14, 2, "IN")
	Park(up, self.coolBox, 0)
	self.coolRun = anim(up)
	for _, seg in ipairs(self.segs) do
		local g = seg.tex:CreateAnimationGroup()
		seg.drop = Alpha(g, 1, 0, 0.05, 1, "IN")
		Park(g, seg.tex, 0)
		seg.group = anim(g)
	end

	-- The cursor on the plate: the hairline lifts and settles. From and to are
	-- set for each play.
	local hover = self.edgeFrame:CreateAnimationGroup()
	hover.fade = Alpha(hover, 0, 1, 0.12, 1, "OUT")
	Park(hover, self.edgeFrame, EDGE_REST)
	self.hoverAnim = anim(hover)
end

-- Prompt starts and clears the cooldown on the shared frame; the bar follows it
-- by wrapping the two calls, once, and answering only while this look is up.
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

-- Whether the text on this panel colour wants to be light (a dark plate), as
-- Prompt/Text.lua works it out from the same colour, over a dusky world: the
-- plate is drawn for it before Prompt has styled the text.
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

-- The ink that holds a colour best: near black or white, whichever has the
-- greater contrast with it (at worst about 4.6:1).
local function InkOn(r, g, b)
	local l = Luminance(r, g, b)
	local dark = Ratio(l, Luminance(INK_DARK[1], INK_DARK[2], INK_DARK[3]))
	if dark >= Ratio(l, 1) then return INK_DARK end
	return INK_LIGHT
end

-- The ground the plate is drawn on: light text means a dark plate.
function Slate:Ground(p)
	local light = WantsLight(p)
	self.dark = light
	if light then
		self.edgeColor = { 1, 1, 1, 0.20 }
		self.iconPlateColor = { 0.025, 0.030, 0.042, 1 }
		self.fillColor = { 1, 1, 1, 0.12 }
		self.stripeColor = { 1, 1, 1, 0.07 }
		self.hatchColor = { 1, 1, 1, 0.15 }
	else
		self.edgeColor = { 0, 0, 0, 0.26 }
		self.iconPlateColor = { 0.93, 0.94, 0.96, 1 }
		self.fillColor = { 0, 0, 0, 0.10 }
		self.stripeColor = { 0, 0, 0, 0.07 }
		self.hatchColor = { 0, 0, 0, 0.12 }
	end
end

-- The ledge's frame, box and the cover over it: from just in from the plate's
-- left end to just past its bottom right corner, `ledge` thick under the plate.
function Slate:PlaceLedge()
	local art = self.kit.art
	local x0, x1 = 3, self.W - self.sp + 6
	local y0, y1 = self.hp, self.H
	PlaceSlabs(self.ledge, art, x0, y0, x1, y1)
	self.coolBox:ClearAllPoints()
	self.coolBox:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -y0)
	self.coolBox:SetSize(math.max(8, x1 - x0), y1 - y0)
	PlaceSlabs(self.cover, art, x0, y0, x1, y1)
	-- The segments, each a slanted bar the ledge's thickness, from a little
	-- in from either end of the bar.
	local lean = SLANT * (y1 - y0)
	local s0, s1 = x0 + 7, x1 - 7 - lean
	local n = Clamp(math.floor((s1 - s0) / SEGMENT_PITCH), 4, SEGMENTS)
	local pitch = (s1 - s0) / n
	self.segCount = n
	for i, seg in ipairs(self.segs) do
		if i <= n then
			local left = s0 + (i - 1) * pitch
			Box(seg.tex, art, left, y0, left + pitch - 1.5 + lean, y1)
		end
		seg.tex:SetShown(i <= n)
	end
end

function Slate:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local face = Face(p)
	local nameSize = face and fs + 2 or fs
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	local mode = p.accentMode or "icon"
	local twoLine = p.showSub and H >= Slate.TwoLineHeight(fs)
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above
	self.nameSize, self.twoLine = nameSize, twoLine and true or false
	self:Ground(p)

	-- The plate is as tall as the prompt less the ledge. Its slant over that
	-- height is how far the top edge is shifted.
	local ledge = Ledge(H)
	local hp = H - ledge
	local sp = SLANT * hp
	self.ledgeH, self.hp, self.sp = ledge, hp, sp

	-- The lines, from the top: the name, a gap and the tag, centred in the plate.
	local tagH = sub + 6
	local block = twoLine and (nameSize + 2 + tagH) or nameSize
	local m = (hp - block) / 2
	local nameC = m + nameSize / 2
	local tagTop = m + nameSize + 2
	self.tagH, self.tagTop = tagH, tagTop
	self.nameY = H / 2 - nameC
	self.oneY = H / 2 - hp / 2
	self.subY = H / 2 - (tagTop + tagH / 2)
	-- The room the lines keep at the right so the slant never cuts them: the
	-- plate's edge at the lowest line, the tag's own pad and half its lean.
	self.baseInset = math.ceil(twoLine and (SLANT * tagTop + 8 + SLANT * tagH / 2)
		or (SLANT * (nameC + nameSize / 2) + 8))
	-- How far apart the list's rows are, which is also how tall each name's
	-- click area is (Prompt/Rows.lua), and where it starts left of the name.
	self.pitch = sub + 8

	-- The icon: a frame S across, standing where the blade leaves room.
	local S = showIcon and Clamp(p.iconSize, 12, math.max(12, hp - 4)) or 0
	local yt = (hp - S) / 2
	local ground = BLADE_GROUND * hp
	local iconX = ground + SLANT * yt + 4
	local textX
	if showIcon then
		textX = iconX + S + 7
	else
		textX = math.ceil(ground + SLANT * (hp - m) + 6)
	end
	local cx, cy = iconX + S / 2, yt + S / 2
	self.S, self.iconX, self.textX, self.cx, self.cy = S, iconX, textX, cx, cy
	-- The tag's left edge at its middle stands 5 left of the text.
	self.tagLeft = textX - 5 - SLANT * tagH / 2

	-- The plate's colours: the look's own slate unless one was chosen.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local bc = p.bgColor
	local tr, tg, tb, ta, br, bg, bb
	if Untouched(bc, d) then
		tr, tg, tb, ta = PLATE_TOP[1], PLATE_TOP[2], PLATE_TOP[3], PLATE_ALPHA
		br, bg, bb = PLATE_BOTTOM[1], PLATE_BOTTOM[2], PLATE_BOTTOM[3]
	else
		br, bg, bb, ta = bc[1] or 0, bc[2] or 0, bc[3] or 0, bc[4] == nil and 1 or bc[4]
		local k = self.dark and 1.35 or 1.04
		tr, tg, tb = math.min(1, br * k + (self.dark and 0.012 or 0)), math.min(1, bg * k + (self.dark and 0.012 or 0)),
			math.min(1, bb * k + (self.dark and 0.014 or 0))
	end
	self.top, self.bottom, self.alpha = { tr, tg, tb }, { br, bg, bb }, ta
	for _, t in ipairs(self.plate) do kit.Gradient(t, "VERTICAL", br, bg, bb, ta, tr, tg, tb, ta) end
	PlaceSlabs(self.plate, art, 0, 0, W, hp)
	-- The hatch: the plate's right end.
	local endW = math.min(CAP * hp, W / 2)
	Box(self.hatch, art, W - endW, 0, W, hp)
	local hc = self.hatchColor
	self.hatch:SetVertexColor(hc[1], hc[2], hc[3], hc[4])
	-- The hairline.
	PlaceSlabs(self.edge, art, 0, 0, W, hp)
	local ec = self.edgeColor
	Colour(self.edge, ec[1], ec[2], ec[3], ec[4])
	self.edgeFrame:SetAlpha(EDGE_REST)
	-- The ledge and its cooldown.
	self:PlaceLedge()
	self.coolOn = nil

	-- The blade, down the plate's left end, whole height; the same shape three
	-- times (the colour, the heat, the flash).
	self.bladeFrame:ClearAllPoints()
	self.bladeFrame:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
	self.bladeFrame:SetSize(BLADE_ASPECT * hp, hp)
	for _, t in ipairs({ self.blade, self.heat, self.flash }) do
		t:ClearAllPoints()
		t:SetAllPoints(self.bladeFrame)
	end
	self.heat:SetVertexColor(WARM[1], WARM[2], WARM[3], 1)
	self.flash:SetVertexColor(1, 1, 1, 1)

	-- The light that crosses the plate: a band STREAK_ASPECT of its height wide,
	-- from its left end to its right.
	local bandW = STREAK_ASPECT * hp
	local travel = math.max(10, W - bandW)
	for _, f in ipairs({ self.streakFrame, self.bandFrame }) do
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", art, "TOPLEFT", 0, 0)
		f:SetSize(bandW, hp)
	end
	for _, t in ipairs({ self.streak, self.band }) do
		t:ClearAllPoints()
		t:SetAllPoints(t == self.streak and self.streakFrame or self.bandFrame)
	end
	self.streak:SetVertexColor(WARM[1], WARM[2], WARM[3], 1)
	self.band:SetVertexColor(1, 1, 1, 1)
	self.streakMove:SetOffset(travel, 0)
	self.bandMove:SetOffset(travel, 0)
	-- The wash and the ghosts are the plate's shape, over the plate.
	PlaceSlabs(self.wash, art, 0, 0, W, hp)
	local oc = OUTCOME.cast
	Colour(self.wash, oc[1], oc[2], oc[3], 1)
	for i, g in ipairs(self.ghosts) do
		PlaceSlabs(g, art, 0, 0, W, hp)
		Colour(g, GHOSTS[i][1], GHOSTS[i][2], GHOSTS[i][3], 0.22)
		PlaceSlabs(self.ghostEdges[i], art, 0, 0, W, hp)
		Colour(self.ghostEdges[i], GHOSTS[i][1], GHOSTS[i][2], GHOSTS[i][3], 1)
	end

	-- The icon's hexagon: the mask, the dark plate, the line, the flash.
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.iconFrame:ClearAllPoints()
	self.iconFrame:SetPoint("TOPLEFT", art, "TOPLEFT", iconX, -yt)
	self.iconFrame:SetSize(math.max(1, S), math.max(1, S))
	if showIcon then
		icon:SetSize(S, S)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		Box(self.iconPlate, art, iconX, yt, iconX + S, yt + S)
		for _, t in ipairs({ self.iconEdge, self.iconFlash }) do
			t:ClearAllPoints()
			t:SetAllPoints(self.iconFrame)
		end
		local ic = self.iconPlateColor
		self.iconPlate:SetVertexColor(ic[1], ic[2], ic[3], ic[4])
		-- The rings spread from the frame's line: a unit and a half past the
		-- icon at rest. The room they have: to the text (less a margin), to the
		-- plate's left end and to the card's top and bottom.
		local pad = (S / 2 + 1.5) / FX_PEAK - S / 2
		self.fx:Place(icon, pad, S)
		self.fx:Shape(false, ART .. "FxRing", ART .. "FxRing")
		local limitH = math.min(textX - cx - kit.TEXT_MARGIN, cx - kit.EDGE_MARGIN)
		local limitV = math.min(cy, H - cy) - kit.EDGE_MARGIN
		self.fx:Fit(limitH, limitV, kit.SHAKE_LEFT)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The sweep is drawn at no strength: the ledge's segments are the
			-- cooldown here. Its shape follows the icon all the same.
			cooldown:SetAlpha(0)
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(ART .. "IconMask") end
			if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end
		end
	end

	-- The lines: the name, and the tag's frame for the reason.
	self.glyphRoom = 0
	self.tagW, self.tagOn = nil, nil

	-- The chips, at the right: a plate of their own on the name's line, their
	-- right end held in by the plate's slant.
	local chipH = sub + 6
	self.chipH = chipH
	local chipTop = twoLine and (nameC - chipH / 2) or (hp - chipH) / 2
	self.chipTop = math.max(1, chipTop)
	self.edgeRoom = math.ceil(SLANT * (self.chipTop + chipH) + 4)
	self.chipW2 = math.ceil(chipH * 1.75)
	PlaceSlabsIn(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("TOPRIGHT", art, "TOPRIGHT", -self.edgeRoom, -self.chipTop)
	self.keyBox:SetSize(self.chipW2, chipH)
	local fc = self.fillColor
	Colour(self.chip, fc[1], fc[2], fc[3], fc[4])
	Colour(self.keyChip, fc[1], fc[2], fc[3], fc[4])
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	local base = art:GetFrameLevel()
	for _, f in ipairs({ self.edgeFrame, self.iconFrame }) do f:SetFrameLevel(base + 1) end
	for _, f in ipairs({ self.bladeFrame, self.streakFrame, self.washFrame, self.bandFrame, self.coolBox,
		self.ghostFrames[1], self.ghostFrames[2] }) do
		f:SetFrameLevel(base + 2)
	end
	self.tagFrame:SetFrameLevel(base + 3)
	self.chipFrame:SetFrameLevel(base + 3)

	-- The list: each row a strip, its name beyond the notch. Strip i stands
	-- STAGGER further in than the last.
	local pitch = self.pitch
	self.stripH = pitch - 2
	self.stagger = 5
	self.notchW = NOTCH_ASPECT * self.stripH
	self.rowOffset = self.notchW + 5
	-- A name's click area begins at the strip's notch.
	self.rowReach = self.rowOffset
	self.rowBase = 8
	local lean = SLANT * self.stripH
	for i, row in ipairs(kit.rows) do
		local x = self.rowBase + (i - 1) * self.stagger + self.rowOffset
		local width = math.max(20, W - 8 - lean - 6 - x)
		row:SetWidth(width)
		fit.room[row] = width
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip, the bar for a cooldown.
	for _, x in ipairs(self.own) do x:Show() end
	self.fx:SetShown(showIcon)
	for _, t in ipairs({ self.iconPlate, self.iconEdge, self.iconFlash }) do t:SetShown(showIcon) end
	self.iconFrame:SetShown(showIcon)
	for i, seg in ipairs(self.segs) do seg.tex:SetShown(i <= self.segCount) end
	for _, s in ipairs(self.strips) do
		Each(s.plate, "Hide")
		s.notch:Hide()
	end
	self.tagFrame:Hide()
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.outcomeOn, self.refused = nil, nil, nil, nil
	self.pulseSpent = nil
	for _, t in ipairs({ self.heat, self.flash, self.iconFlash }) do t:SetAlpha(0) end
	for _, f in ipairs({ self.streakFrame, self.washFrame, self.bandFrame, self.coolBox, self.ghostFrames[1],
		self.ghostFrames[2] }) do
		f:SetAlpha(0)
	end
	self:Accent()
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset.
	return textX, self.edgeRoom + self.chipW2 + 6
end

function Slate:Styled(p)
	local kit = self.kit
	local ink, fit = kit.ink, kit.fit
	-- The face: the condensed one, in the sizes this look draws, unless the
	-- player chose a font or the client has no such file (the line then keeps
	-- what Prompt set).
	local face = Face(p)
	local nameSize, sub = self.nameSize or p.fontSize, self.sub or SubSize(p.fontSize)
	local tried = face and kit.name:SetFont(face, nameSize, fit.flags) and kit.name:GetFont()
	-- A face the client refuses leaves the line with no font: put Prompt's back.
	if face and not tried then kit.name:SetFont(fit.path or STANDARD_TEXT_FONT, p.fontSize, fit.flags) end
	if tried then
		fit.path = face
		fit.base[kit.name], fit.size[kit.name] = nameSize, nameSize
		for _, fs in ipairs({ kit.sub, kit.count, self.keyText }) do
			if not fs:SetFont(face, sub, fit.flags) or not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, sub, fit.flags) end
		end
		fit.base[kit.sub], fit.size[kit.sub] = sub, sub
		for _, fs in ipairs(kit.rows) do
			if not fs:SetFont(face, sub, fit.flags) or not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, sub, fit.flags) end
			fit.base[fs], fit.size[fs] = sub, sub
		end
	else
		-- Prompt set the face; the key's chip follows it.
		if not self.keyText:SetFont(fit.path or STANDARD_TEXT_FONT, sub, "") or not self.keyText:GetFont() then
			self.keyText:SetFont(STANDARD_TEXT_FONT, sub, "")
		end
	end
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen and ink.light then
		kit.name:SetTextColor(NAME_INK[1], NAME_INK[2], NAME_INK[3], 1)
	end
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 0.6)
		kit.name:SetShadowOffset(1, -1)
	end
	-- The tag's text sits on the reason's colour: no shadow.
	kit.sub:SetShadowOffset(0, 0)
	-- The chips are a faint lift of the plate whatever the plate, so their text
	-- is the muted ink.
	local mr, mg, mb = kit.Legible(0.82, 0.86, 0.94, 4.5)
	if ink.light then kit.count:SetTextColor(mr, mg, mb, 1) end
	kit.count:SetShadowOffset(0, 0)
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
	-- The tag's ink follows the colour it is on.
	self:Accent()
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
	kit.sub:SetShadowOffset(1, -1)
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + kit.TEXT_LEVEL)
	kit.textLayer:SetAlpha(1)
	for _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(1) end
	self.combat, self.hovered, self.outcomeOn = nil, nil, nil
	self.countMode, self.keyUp, self.coolOn = nil, false, nil
	self.said = {}
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Slate:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local inset = math.max(right, self.baseInset)
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
	fit.room[sub] = self.lineRoom
	sub:SetPoint("LEFT", self.textX, self.subY)
	sub:SetPoint("RIGHT", -inset, self.subY)
	self.tagW = nil
end

-- The reason line was just set or refitted: the tag hugs its words, a pad each
-- side, and goes when there are none.
function Slate:Fitted(fs)
	local kit = self.kit
	if fs ~= kit.sub or not self.lineRoom then return end
	local text = fs:GetText()
	local on = fs:IsShown() and type(text) == "string" and text ~= ""
	if not on then
		if self.tagOn then
			self.tagOn = false
			self.tagFrame:Hide()
		end
		return
	end
	local w = math.min(kit.fit.drawn[fs] or kit.TextWidth(fs) or self.sub * 4, self.lineRoom)
	if w ~= self.tagW then
		self.tagW = w
		local lean = SLANT * self.tagH
		local f = self.tagFrame
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", kit.art, "TOPLEFT", self.tagLeft, -self.tagTop)
		f:SetSize(math.ceil(w + 10 + lean), self.tagH)
		PlaceSlabsIn(self.tag, f, self.tagH)
	end
	if not self.tagOn then
		self.tagOn = true
		self.tagFrame:Show()
	end
end

-- Whether the name, even at its smallest, fits beside `room` at the right.
-- Its width is taken once a paint, by Chip.
function Slate:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, self.baseInset) + 0.5
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
-- beside it: the key's room, a two-digit chip and the lean they share.
function Slate:PairRoom()
	return math.ceil((self.keyRoom or 0) + self.chipW2 - (SLANT * self.chipH - 3))
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
			local w = math.max(self.chipW2, (kit.TextWidth(self.keyText) or self.sub) + 10 + SLANT * self.chipH)
			self.keyW, self.keyRoom = w, math.ceil(self.edgeRoom + w + 6)
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
			self.countW = math.max(self.chipW2, (kit.TextWidth(count) or self.sub) + 10 + SLANT * h)
		end
		local w = self.countW
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "pair" then
				-- Right edge to the key's left, the lean they share between.
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", SLANT * h - 3, 0)
			else
				self.chipBox:SetPoint("TOPRIGHT", kit.art, "TOPRIGHT", -self.edgeRoom, -self.chipTop)
			end
			PlaceSlabsIn(self.chip, self.chipBox, h)
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
-- the cooldown bar
---------------------------------------------------------------------------

-- The cooldown began at `start` and lasts `duration`: the ledge goes dark and
-- its segments drop out, the last (the left end) at the moment the button is
-- ready, then it all fades. Each segment is a fade begun with the delay that
-- puts it out at its share of what is left, so it follows the real clock
-- without a frame script, and begun again by every new cooldown (a cast during
-- the global cooldown moves the end).
function Slate:Cool(start, duration)
	if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then return self:CoolStop() end
	local left = start + duration - GetTime()
	if left <= 0.02 then return self:CoolStop() end
	if not self.p.showIcon then return end
	self.coolOn = true
	local frac = Clamp(left / duration, 0.001, 1)
	local n = self.segCount
	self.coolRun:Stop()
	self.coolHold:SetDuration(left)
	self.coolBox:SetAlpha(1)
	for i, seg in ipairs(self.segs) do
		seg.group:Stop()
		-- The fraction of the cooldown still to run at which this segment goes
		-- out: the leftmost last.
		local at = (i - 1) / n
		if i <= n and at < frac then
			seg.tex:SetAlpha(1)
			seg.drop:SetStartDelay(math.max(0, left - at * duration))
			seg.group:Play()
		else
			seg.tex:SetAlpha(0)
		end
	end
	self.coolRun:Play()
end

function Slate:CoolStop()
	if not self.coolOn and not self.coolRun:IsPlaying() then return end
	self.coolOn = nil
	self.coolRun:Stop()
	for _, seg in ipairs(self.segs) do seg.group:Stop() end
	self.coolBox:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The accent, painted: the blade, the ledge, the tag and the icon's line in
-- one colour, which is the reason's, an outcome's (the verdict), steel in a
-- fight, or the neutral grey with the marker off. The tag's text takes the ink
-- that holds that colour best.
function Slate:Accent()
	local a = self.accent
	local kit = self.kit
	if not (a and kit) then return end
	local r, g, b = a[1], a[2], a[3]
	local mode = a.mode or "icon"
	if not a.outcome then
		if self.combat then
			r, g, b = STEEL[1], STEEL[2], STEEL[3]
		elseif mode == "off" then
			r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3]
		end
	end
	self.blade:SetVertexColor(r, g, b, 1)
	local lr, lg, lb = kit.Tint(r, g, b, -0.12)
	Colour(self.ledge, lr, lg, lb, 1)
	Colour(self.cover, 0.03, 0.035, 0.05, 0.92)
	Colour(self.tag, r, g, b, 1)
	local ink = InkOn(r, g, b)
	kit.sub:SetTextColor(ink[1], ink[2], ink[3], 1)
	-- The icon's line wears the colour where the mode says; the plate's
	-- hairline's tone where it does not.
	if mode == "icon" or mode == "both" or a.outcome then
		self.iconEdge:SetVertexColor(r, g, b, 1)
	else
		local ec = self.edgeColor
		self.iconEdge:SetVertexColor(ec[1], ec[2], ec[3], math.min(1, ec[4] * 1.4))
	end
	local sr, sg, sb = kit.Tint(r, g, b, 0.30)
	for _, seg in ipairs(self.segs) do seg.tex:SetVertexColor(sr, sg, sb, 1) end
	self.tint = { r, g, b }
end

function Slate:PaintReason(r, g, b, _, mode)
	self.accent = { r, g, b, mode = mode or "icon" }
	self:Accent()
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- The fight holds the plate: the accent goes to steel, the icon greys and dims,
-- the text dims, the lights go out.
function Slate:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	-- The name and the chips dim; the tag does not, so the reason stays readable.
	for _, fs in ipairs({ kit.name, kit.count, self.keyText }) do fs:SetAlpha(on and TEXT_COMBAT or 1) end
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the plate through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if on then
		self:StopAttention()
		for _, g in ipairs(self.arrive) do g:Stop() end
		self:StopFlourishes()
	end
	self:Accent()
end

---------------------------------------------------------------------------
-- motion
---------------------------------------------------------------------------

-- The breathing, let go: after its breaths, and on Calm.
function Slate:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.heat:SetAlpha(0)
	self.streakFrame:SetAlpha(0)
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
		self.heat:SetAlpha(0)
		self.streakFrame:SetAlpha(0)
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
	self.heat:SetAlpha(0)
	self.streakFrame:SetAlpha(0)
end

function Slate:Flourish(kind)
	local icon = self.kit.icon:IsShown()
	if kind == "failed" then
		-- A refusal: the plate jerks, the red and the amber copy slip past it,
		-- one hexagon closes on the icon. The text's shake is Prompt's.
		self.iconFlash:SetVertexColor(1.00, 0.42, 0.20, 1)
		self.flash:SetVertexColor(1.00, 0.42, 0.20, 1)
		PlayAll(self.refusal)
		if icon then self.fx:Refuse(1.00, 0.40, 0.22, 0.85) end
		return
	end
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	local o = OUTCOME.cast
	self.iconFlash:SetVertexColor(o[1], o[2], o[3], 1)
	self.flash:SetVertexColor(1, 1, 1, 1)
	for _, g in ipairs(self.landing) do
		g:Stop()
		g:Play()
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
	local g, t = self.hoverAnim, self.edgeFrame
	local from = t:GetAlpha()
	g:Stop()
	t:SetAlpha(from)
	g.to = on and 1 or EDGE_REST
	g.fade:SetFromAlpha(from)
	g.fade:SetToAlpha(g.to)
	g.fade:SetDuration(on and 0.12 or 0.18)
	g:Play()
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the tag becomes the verdict, so the eye never
-- has to find the person again. The accent takes the outcome's colour.
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
	self.accent = { o[1], o[2], o[3], mode = self.p.accentMode or "icon", outcome = true }
	self:Accent()
	self.refused = kind == "failed"
	kit.icon:SetDesaturated(self.refused or self.combat or false)
	if kit.sub:IsShown() then
		kit.SetLine(kit.sub, word)
		self:Fitted(kit.sub)
	end
end

function Slate:ClearOutcome()
	self.outcomeOn = nil
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The list hangs from the plate, three units off it, above or below: a strip
-- for each row, each further in than the last, with a notch in the row's reason
-- colour.
function Slate:PaintQueue(rows, shown, above)
	local kit = self.kit
	local art = kit.art
	local list = shown > 0
	for i, s in ipairs(self.strips) do
		if not (list and i <= shown) then
			Each(s.plate, "Hide")
			s.notch:Hide()
		end
	end
	if not list then
		self.listShown, self.listAt = nil, nil
		return
	end

	for i = 1, shown do
		local c = kit.ReasonColor(rows[i] and rows[i].reason)
		self.strips[i].notch:SetVertexColor(c[1], c[2], c[3], 1)
	end
	-- Laid out again only when the number of rows or the side changes: the
	-- scan repaints this several times a second.
	if self.listShown == shown and self.listAt == above then return end
	self.listShown, self.listAt = shown, above

	local pitch, h = self.pitch, self.stripH
	local depth = shown * pitch
	local y0
	if above then
		y0 = -3 - depth + 1
	else
		y0 = self.H + 3
	end
	local t, b = self.top, self.bottom
	local k = self.dark and 0.90 or 0.97
	local mr, mg, mb = (t[1] + b[1]) / 2 * k, (t[2] + b[2]) / 2 * k, (t[3] + b[3]) / 2 * k
	for i = 1, shown do
		local s = self.strips[i]
		local top = y0 + (i - 1) * pitch
		local x0 = self.rowBase + (i - 1) * self.stagger
		Colour(s.plate, mr, mg, mb, self.alpha)
		PlaceSlabs(s.plate, art, x0, top, self.W - 6, top + h)
		Each(s.plate, "Show")
		Box(s.notch, art, x0, top, x0 + self.notchW, top + h)
		s.notch:Show()
		-- The row's name on the strip's middle line, beyond the notch.
		local fs = kit.rows[i]
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", art, "TOPLEFT", x0 + self.rowOffset, -(top + h / 2))
	end
end
