-- Manners -- the Toast look: a warm banner pinned by a round gilded medallion,
-- in the grammar of the game's own achievement toasts.
--
-- A dark, warm banner with a gilded rail and corner studs. A gold medallion
-- pins its left end; the spell icon sits in the middle of it, inside a ring of
-- enamel in the reason colour, and a soft light in the same colour comes from
-- behind it. The name is the title, the reason the subtitle. It is still at
-- rest; it moves when something happens.
--
-- Every region is a texture from Textures/Toast (tools/make_toast_textures.py).
-- The gold is baked, because it is decoration; everything that means something
-- -- the enamel, the lights, the list's gems, the favour clock, the outcome --
-- is white or grey art coloured by SetVertexColor, so one file serves all six
-- reasons, both palettes, a custom marker colour and the outcomes. The
-- interface this file implements is described at the top of Looks/Looks.lua.
--
-- Where it departs from the approved design (design14/toast/SPEC.md), on the
-- judges' word:
--   * a dark seam either side of the enamel, and the enamel flat, bright and
--     more saturated than the gold with a pale highlight, so the owed gold
--     (and the colour-blind yellow) never reads as more metal;
--   * the rails' sparks, the streak and the corner's twinkle only for a new
--     favour, never for every new face on the panel; a new face gets the
--     text's own dip and nothing else;
--   * below height 40 a single rail and smaller studs, so the gilding does not
--     turn to mush at the smallest sizes;
--   * the text at its regular weight (a FontString has no other), the
--     hierarchy carried by size, ink and shadow;
--   * the result as a verdict on the second line -- "buffed" with a tick, or
--     the game's own words with a cross -- and the name left where it was;
--   * the favour clock: a thin ember in the reason colour, hotter than the
--     enamel, over a line of ash along the bottom rail, burning down as the
--     time to return the favour runs out. Brought
--     up to date on the scan's own repaint, never on a frame script; kept
--     under Calm, because it is information, and in a fight, dimmed;
--   * the bound key on a chip at the right, like the count's, when a key is
--     bound; the count then moves onto the medallion as a small coin, or
--     with no medallion beside the key's chip. Either chip steps aside for a paint in which the name would otherwise be cut;
--   * the owed pulse breathes three times and then holds still;
--   * a fight turns the gold to iron and greys the icon, the text dims, and
--     the enamel keeps its colour: the one bright thing left is the reason;
--   * the medallion stays inside the button: the banner is drawn a few units
--     inside the panel's height instead, so the whole look takes clicks and
--     the drag and the screen clamp see what the player sees. The medallion
--     is the panel's height, the icon most of it and the gold thin, so the
--     icon is sized by the height (Options says so);
--   * the owed gold fired to a honey amber, darker than the metal, since
--     saturation alone did not part it from the gold at the game's scale;
--   * with the icon off, a jewel at the banner's end carries the reason;
--   * a class-coloured name is taken a third of the way to white.

local _, ns = ...
local L = ns.L

local ART = "Interface\\AddOns\\Manners\\Textures\\Toast\\Toast_"

local Toast = ns.Looks.Register("toast", {
	name = L["Toast -- warm banner, gilded medallion"],
	order = 2,
	-- The banner holds in a fight; the look dims its own parts.
	combatArtAlpha = 1,
	classSoften = 0.35,
})

-- The icon is this much of the medallion across (ICON_R in the generator).
local ICON_OF = 0.63
-- Where the rails run, in units in from the frame's edge for a 12-unit
-- corner, scaled with the corner: the outer rail, the stud, and the favour
-- clock's line, on the dark of the banner just inside the innermost rail --
-- on the gold itself the owed gold, which is nearly every clock, vanished.
local RAIL = { outer = 1.35, clock = 5.4, stud = 3.3,
	slimOuter = 1.25, slimClock = 3.4, slimStud = 3.05 }
-- The banner's own warm pair, for a panel colour nobody chose.
local WARM_TOP, WARM_BOTTOM, WARM_ALPHA = { 0.205, 0.145, 0.100 }, { 0.070, 0.050, 0.042 }, 0.95
local IVORY = { 1.00, 0.965, 0.90 }
local WARM_GREY = { 0.80, 0.75, 0.66 }
local PALE_GOLD = { 1.00, 0.86, 0.52 }
local IRON = { 0.62, 0.62, 0.64 }
-- The enamel with the marker switched off.
local NEUTRAL = { 0.46, 0.40, 0.35 }
-- The outcomes' own colours: the enamel, the verdict, the wash.
local OUTCOME = {
	cast = { 0.52, 0.90, 0.52 },
	failed = { 1.00, 0.40, 0.34 },
	sent = { 0.91, 0.86, 0.60 },
}
local WASH = { cast = 0.24, failed = 0.15, sent = 0.14 }
-- What a fight does: the text dims, the icon greys and dims.
local TEXT_COMBAT, ICON_COMBAT = 0.78, 0.70
-- The owed pulse: this many breaths of 3.2 s, then it holds still.
local BREATHS = 3
local BREATH = 1.6
local COMMAND = "CLICK MannersPrompt:LeftButton"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function SubSize(fontSize) return math.max(7, fontSize - 3) end
local function Gap(fontSize) return math.max(1.5, fontSize * 0.16) end

-- The name, the gap and the reason as one block, and the frame round it.
function Toast.TwoLineHeight(fontSize)
	return math.ceil(1.1 * fontSize + Gap(fontSize) + 1.1 * SubSize(fontSize) + 10)
end

-- The enamel carries the reason, and with the icon off the jewel at the
-- banner's end does; nothing does with the marker off.
function Toast.AccentCarriers(p)
	return (p.accentMode or "icon") ~= "off", false
end

-- The medallion is the banner's height, never shorter (its rails run in under
-- it), so the icon is sized by the height and not by the slider. Options says
-- so with this.
function Toast.IconSize(p)
	return math.floor(ICON_OF * (p.height or 44) + 0.5)
end

-- More colourful than the palette's own: enamel is glass fired on metal, and
-- the owed gold has to part company with the gold round it.
local function Enamel(r, g, b)
	local l = 0.299 * r + 0.587 * g + 0.114 * b
	local k = 1.35
	return Clamp(l + (r - l) * k, 0, 1), Clamp(l + (g - l) * k, 0, 1), Clamp(l + (b - l) * k, 0, 1)
end

local function Mix(r, g, b, t)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- The enamel for a reason colour. A warm gold (the owed reason) is fired
-- deeper, to a dark honey amber, about (0.75, 0.41, 0.10): saturation alone
-- did not part it from the gold round it at the game's scale, where the two
-- were one thick ring. At one pixel a unit its mean luminance is a third
-- under the outer ring's, at 44 and at 36 high, and it still reads as the
-- owed hue. The colour-blind set's orange and lemon are not warm golds and
-- pass unchanged.
local function Fired(r, g, b)
	local er, eg, eb = Enamel(r, g, b)
	if er > 0.9 and eb < 0.3 and eg > 0.6 * er and eg < 0.9 * er then
		eg = eg * 0.70
		er, eg, eb = er * 0.75, eg * 0.75, eb * 0.75
	end
	return er, eg, eb
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
-- thin middle strip, so they stretch without warping. TL T TR L R BL B BR,
-- and a centre when asked for.
local CUT = {
	{ 0, 0.25, 0, 0.25 }, { 0.46, 0.54, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
	{ 0, 0.25, 0.46, 0.54 }, { 0.75, 1, 0.46, 0.54 },
	{ 0, 0.25, 0.75, 1 }, { 0.46, 0.54, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
	{ 0.46, 0.54, 0.46, 0.54 },
}

local function Pieces(parent, layer, sublevel, file, blend, centre, keep)
	local s = {}
	for i = 1, centre and 9 or 8 do
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

-- The pieces round a box, corners `c` square. `open`: the left column is
-- left out and the top and bottom edges run to the box's left side, which is
-- under the medallion.
local function PlacePieces(s, rel, x0, y0, x1, y1, c, open)
	local lx = open and x0 or x0 + c
	Box(s[1], rel, x0, y0, x0 + c, y0 + c)
	Box(s[2], rel, lx, y0, x1 - c, y0 + c)
	Box(s[3], rel, x1 - c, y0, x1, y0 + c)
	Box(s[4], rel, x0, y0 + c, x0 + c, y1 - c)
	Box(s[5], rel, x1 - c, y0 + c, x1, y1 - c)
	Box(s[6], rel, x0, y1 - c, x0 + c, y1)
	Box(s[7], rel, lx, y1 - c, x1 - c, y1)
	Box(s[8], rel, x1 - c, y1 - c, x1, y1)
	if s[9] then Box(s[9], rel, x0 + c, y0 + c, x1 - c, y1 - c) end
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
-- motion: every animation here runs on the texture it lights, parked at
-- alpha 0 between plays, so nothing is left lit when it stops
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

-- A spark down a rail: in, along, out.
local function Travel(region, delay)
	local g = region:CreateAnimationGroup()
	local move = g:CreateAnimation("Translation")
	move:SetDuration(0.9)
	if move.SetStartDelay then move:SetStartDelay(delay) end
	if move.SetSmoothing then move:SetSmoothing("IN_OUT") end
	Alpha(g, 0, 1, 0.2, 1, delay)
	Alpha(g, 1, 0, 0.3, 1, delay + 0.6)
	g.move = move
	Park(g, region, 0)
	return g
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Toast:Build(kit)
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
	local function light(file, sublevel, parent)
		local t = tex(parent or art, "BORDER", sublevel, file, "ADD")
		t:SetAlpha(0)
		return t
	end

	-- The ground, on art itself: below the icon and the list's rows, which
	-- are art's too. A frame of its own would draw over both.
	self.shadow = Pieces(art, "BACKGROUND", -8, ART .. "Shadow", nil, true, keep)
	self.drawerBody = tex(art, "BACKGROUND", -7, "Body")
	self.body = tex(art, "BACKGROUND", -6, "Body")
	-- An opaque well in the icon's shape, under it: the banner begins at the
	-- medallion's centre, and whenever the icon or the panel is less than
	-- opaque (a fight, the panel fading in and out) nothing behind it may
	-- show, or the icon splits down the middle.
	self.well = tex(art, "BACKGROUND", -5, "IconMask")
	self.drawer = Pieces(art, "BORDER", -2, ART .. "Drawer", nil, false, keep)
	self.border = Pieces(art, "BORDER", 2, ART .. "Border", nil, false, keep)

	-- The light behind the medallion, at rest and breathing; the outcome's
	-- wash and the cursor's.
	self.bloom = tex(art, "BORDER", 0, "Bloom", "ADD")
	self.bloomPulse = light("Bloom", 0)
	self.bloomArrive = light("Bloom", 0)
	self.wash = light("Wash", -1)
	self.hoverWash = light("Wash", -1)
	-- Round the medallion: above the border, below the icon.
	self.ringPulse = light("RingGlow", 3)
	self.ringArrive = light("RingGlow", 3)
	self.ringHover = light("RingGlow", 3)
	self.burst = light("RingGlow", 4)
	-- What runs over the gilding.
	self.flare = Pieces(art, "BORDER", 5, ART .. "BorderGlow", "ADD", false, keep)
	Each(self.flare, "SetAlpha", 0)
	self.streak = light("Streak", 1)
	self.glints = {}
	for i = 1, 4 do self.glints[i] = light("Glint", 6) end
	self.twinkle = light("Spark", 7)

	-- The favour clock, on the bottom rail: the time spent as a line of dark
	-- ash its whole length, the time left burning over it.
	self.ash = tex(art, "ARTWORK", 1, "Ember")
	self.ash:SetTexCoord(0.25, 0.75, 0, 1)
	self.ember = tex(art, "ARTWORK", 2, "Ember", "ADD")
	self.ember:SetTexCoord(0.25, 0.75, 0, 1)
	self.bead = tex(art, "ARTWORK", 3, "Glint", "ADD")

	-- The list's gems, and with the icon off one at the banner's end, which
	-- carries the reason in the medallion's place.
	self.gems, self.gemSets = {}, {}
	for i = 1, #kit.rows do
		self.gems[i] = tex(art, "ARTWORK", 1, "Gem")
		self.gemSets[i] = tex(art, "ARTWORK", 2, "GemSet")
	end
	self.jewel = tex(art, "ARTWORK", 1, "Gem")
	self.jewelSet = tex(art, "ARTWORK", 2, "GemSet")

	-- The medallion: the enamel and the gold, on a frame over the icon so it
	-- can settle onto it as the panel arrives.
	local base = art:GetFrameLevel()
	self.medallion = keep(CreateFrame("Frame", nil, art))
	self.medallion:SetFrameLevel(base + 2)
	self.band = tex(self.medallion, "ARTWORK", 1, "RingBand")
	self.ring = tex(self.medallion, "ARTWORK", 2, "Ring")

	-- The chips: over the medallion, where the count's coin sits; their text
	-- is on textLayer, over them.
	self.chipFrame = keep(CreateFrame("Frame", nil, art))
	self.chipFrame:SetFrameLevel(base + 3)
	self.chipBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.keyBox = keep(CreateFrame("Frame", nil, self.chipFrame))
	self.chip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyChip = ThreeSlice(self.chipFrame, "ARTWORK", 1, ART .. "Chip", keep)
	self.keyText = keep(textLayer:CreateFontString(nil, "OVERLAY"))
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:SetPoint("CENTER", self.keyBox, "CENTER", 0, 0)
	-- The verdict's tick or cross, before the second line.
	self.glyph = tex(textLayer, "ARTWORK", 1, "Check")

	-- The icon's shape; taken off it in Hide, so not in `own`.
	self.mask = art:CreateMaskTexture()
	self.mask:SetTexture(ART .. "IconMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

	-- Everything gold, for the iron of a fight.
	self.gold = { self.ring, self.jewelSet }
	for _, s in ipairs({ self.border, self.drawer, self.chip, self.keyChip, self.gemSets }) do
		for _, t in ipairs(s) do self.gold[#self.gold + 1] = t end
	end

	self:BuildAnimations(anim)

	-- The medallion settles onto the icon as the panel comes up, on Full.
	local intro = art.intro
	if intro and intro.HookScript then
		intro:HookScript("OnPlay", function()
			if Toast.active and kit.FullEffects() and kit.icon:IsShown() then
				Toast.popAnim:Stop()
				Toast.popAnim:Play()
			end
		end)
	end
end

function Toast:BuildAnimations(anim)
	-- The owed pulse: the light behind the medallion and a ring round it
	-- breathe together, slowly; see Attention for how long.
	self.pulse = {}
	for _, t in ipairs({ self.bloomPulse, self.ringPulse }) do
		local g = t:CreateAnimationGroup()
		g:SetLooping("BOUNCE")
		Alpha(g, 0.45, 1, BREATH, 1, nil, "IN_OUT")
		self.pulse[#self.pulse + 1] = anim(g)
	end

	-- The favour just done: the light swells and settles.
	self.arrive = {
		anim(Flash(self.bloomArrive, 1, 0.3, 0.9, nil, "IN_OUT")),
		anim(Flash(self.ringArrive, 1, 0.3, 0.9, nil, "IN_OUT")),
	}

	-- A new favour: sparks down both rails, the lower pair a beat behind, a
	-- light across the banner, and the corner stud twinkles as they arrive.
	self.sweep = {}
	for i, t in ipairs(self.glints) do
		self.sweep[i] = anim(Travel(t, i <= 2 and 0.15 or 0.24))
	end
	local streak = self.streak:CreateAnimationGroup()
	streak.move = streak:CreateAnimation("Translation")
	streak.move:SetDuration(0.8)
	if streak.move.SetStartDelay then streak.move:SetStartDelay(0.15) end
	if streak.move.SetSmoothing then streak.move:SetSmoothing("IN_OUT") end
	Alpha(streak, 0, 0.34, 0.4, 1, 0.15)
	Alpha(streak, 0.34, 0, 0.4, 1, 0.55)
	Park(streak, self.streak, 0)
	self.streakAnim = anim(streak)
	local twinkle = self.twinkle:CreateAnimationGroup()
	local grow = twinkle:CreateAnimation("Scale")
	if grow.SetScaleFrom then grow:SetScaleFrom(0.6, 0.6) end
	if grow.SetScaleTo then grow:SetScaleTo(1.2, 1.2) end
	if grow.SetOrigin then grow:SetOrigin("CENTER", 0, 0) end
	grow:SetDuration(0.4)
	if grow.SetStartDelay then grow:SetStartDelay(1.1) end
	-- Turned an eighth as it flares, where the client has the animation.
	local turn = twinkle:CreateAnimation("Rotation")
	if turn and turn.SetDegrees then
		turn:SetDegrees(45)
		if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
		turn:SetDuration(0.4)
		if turn.SetStartDelay then turn:SetStartDelay(1.1) end
	end
	Alpha(twinkle, 0, 1, 0.15, 1, 1.1, "OUT")
	Alpha(twinkle, 1, 0, 0.25, 1, 1.25, "IN")
	Park(twinkle, self.twinkle, 0)
	self.twinkleAnim = anim(twinkle)

	-- A buff that landed: the gilding flares, a ring bursts off the medallion.
	self.flareAnims = {}
	for i, t in ipairs(self.flare) do self.flareAnims[i] = anim(Flash(t, 0.75, 0.08, 0.45)) end
	local burst = self.burst:CreateAnimationGroup()
	local bGrow = burst:CreateAnimation("Scale")
	if bGrow.SetScaleFrom then bGrow:SetScaleFrom(1, 1) end
	if bGrow.SetScaleTo then bGrow:SetScaleTo(1.45, 1.45) end
	if bGrow.SetOrigin then bGrow:SetOrigin("CENTER", 0, 0) end
	bGrow:SetDuration(0.5)
	if bGrow.SetSmoothing then bGrow:SetSmoothing("OUT") end
	Alpha(burst, 0.9, 0, 0.5, 1, nil, "OUT")
	Park(burst, self.burst, 0)
	self.burstAnim = anim(burst)

	-- The outcome's wash, fading over the outcome's time.
	local wash = self.wash:CreateAnimationGroup()
	Alpha(wash, 1, 0, self.kit.OUTCOME_SECONDS, 1, nil, "OUT")
	Park(wash, self.wash, 0)
	self.washAnim = anim(wash)

	-- The cursor's light, both ways; from and to are set for each play.
	self.hoverAnims = {}
	for i, t in ipairs({ self.hoverWash, self.ringHover }) do
		local g = t:CreateAnimationGroup()
		g.fade = Alpha(g, 0, 1, 0.12, 1, nil, "OUT")
		Park(g, t, 0)
		self.hoverAnims[i] = anim(g)
	end

	-- The medallion settling onto the icon.
	local pop = self.medallion:CreateAnimationGroup()
	local settle = pop:CreateAnimation("Scale")
	if settle.SetScaleFrom then settle:SetScaleFrom(1.12, 1.12) end
	if settle.SetScaleTo then settle:SetScaleTo(1, 1) end
	if settle.SetOrigin then settle:SetOrigin("CENTER", 0, 0) end
	settle:SetDuration(0.32)
	if settle.SetSmoothing then settle:SetSmoothing("OUT") end
	self.popAnim = anim(pop)
end

---------------------------------------------------------------------------
-- laying out
---------------------------------------------------------------------------

function Toast:Apply(p, above)
	local kit = self.kit
	local art, icon, fit = kit.art, kit.icon, kit.fit
	local W, H, fs = p.width, p.height, p.fontSize
	local sub = SubSize(fs)
	local showIcon = p.showIcon and true or false
	self.active = true
	self.p, self.W, self.H, self.sub, self.above = p, W, H, sub, above

	-- The banner sits a few units inside the panel's height, so the medallion
	-- that overhangs it is still inside the button: the whole look takes the
	-- click and the drag.
	local ov = Clamp(math.floor(H * 0.065 + 0.5), 2, 4)
	local top, bottom = ov, H - ov
	local BH = bottom - top
	local slim = H < 40
	local C = Clamp(math.floor(BH * 0.30 + 0.5), 8, 16)
	-- The medallion is the panel's height: the banner's rails and body run in
	-- under it to its centre, so a medallion any shorter than the banner left
	-- their ends showing above and below it. The icon is sized by the height
	-- (Toast.IconSize), which Options says.
	local M = showIcon and H or 0
	local cx, cy = M / 2, H / 2
	local left = showIcon and cx or 0
	-- With the icon off, a jewel at the banner's end carries the reason.
	local jewel = sub + 8
	-- Clear of the frame's inner rail.
	local jewelX = C / 2 + 7
	local textX = showIcon and (M + 6) or math.floor(jewelX + jewel / 2 + 7 + 0.5)
	self.ov, self.top, self.bottom, self.C, self.M, self.cx, self.cy = ov, top, bottom, C, M, cx, cy
	self.left, self.textX, self.slim = left, textX, slim

	-- The panel colour: the look's own warm pair unless one was chosen.
	local d = ns.defaults and ns.defaults.profile.prompt.bgColor
	local c = p.bgColor
	local tr, tg, tb, ta, br, bg, bb
	if Untouched(c, d) then
		tr, tg, tb, ta = WARM_TOP[1], WARM_TOP[2], WARM_TOP[3], WARM_ALPHA
		br, bg, bb = WARM_BOTTOM[1], WARM_BOTTOM[2], WARM_BOTTOM[3]
	else
		tr, tg, tb, ta = c[1] or 0, c[2] or 0, c[3] or 0, c[4] == nil and 1 or c[4]
		br, bg, bb = tr * 0.62, tg * 0.62, tb * 0.66
	end
	self.bodyTop, self.bodyBottom = { tr, tg, tb, ta }, { br, bg, bb, ta }
	self.shadowAlpha = math.min(1, ta + 0.05) * (ta < 0.2 and 0 or 1)
	kit.Gradient(self.body, "VERTICAL", br, bg, bb, ta, tr, tg, tb, ta)
	Box(self.body, art, left + 0.6, top + 0.6, W - 0.6, bottom - 0.6)
	kit.Gradient(self.drawerBody, "VERTICAL", br * 0.9, bg * 0.9, bb * 0.9, ta * 0.97,
		tr * 0.8, tg * 0.8, tb * 0.8, ta * 0.97)

	-- The frame: the double rail from height 40 up, one rail under it.
	local frameFile = ART .. (slim and "BorderSlim" or "Border")
	Each(self.border, "SetTexture", frameFile)
	Each(self.flare, "SetTexture", frameFile .. "Glow")
	PlacePieces(self.border, art, left, top, W, bottom, C, showIcon)
	PlacePieces(self.flare, art, left, top, W, bottom, C, showIcon)
	for i = 1, 8 do
		local side = i == 1 or i == 4 or i == 6
		self.border[i]:SetShown(not (showIcon and side))
		self.flare[i]:SetShown(not (showIcon and side))
	end
	self.shadowBox = { left - 12 + 4, top - 9, W + 12, bottom + 15 }
	Each(self.shadow, "SetVertexColor", 1, 1, 1, self.shadowAlpha)
	self.drawnList = nil
	self:PlaceShadow(nil)

	-- The rails, for the sparks and the clock.
	local k = C / 12
	local outer = (slim and RAIL.slimOuter or RAIL.outer) * k
	local clockAt = (slim and RAIL.slimClock or RAIL.clock) * k
	local studAt = (slim and RAIL.slimStud or RAIL.stud) * k

	-- The light behind the medallion: from its centre, rightwards, never
	-- above or below the banner. The whole file, which rises from nothing at
	-- its left edge, so the light grows out from under the medallion and no
	-- edge of it lies under the medallion to show through a fade.
	for _, t in ipairs({ self.bloom, self.bloomPulse, self.bloomArrive }) do
		t:SetTexCoord(0, 1, 0, 1)
		t:ClearAllPoints()
		t:SetPoint("LEFT", art, "TOPLEFT", left, -cy)
		t:SetSize(2.03 * BH, BH - 3)
	end
	for _, t in ipairs({ self.wash, self.hoverWash }) do
		Box(t, art, left + 1, top + 1, W - 1, bottom - 1)
	end

	-- The medallion and the icon in it.
	icon:ClearAllPoints()
	icon:SetShown(showIcon)
	self.medallion:SetShown(showIcon)
	local round = p.roundIcon and true or false
	local maskFile = ART .. (round and "IconMask" or "SealMask")
	self.mask:SetTexture(maskFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	self.mask:ClearAllPoints()
	self.mask:SetAllPoints(icon)
	self.mask:SetShown(showIcon)
	if not self.masked then
		icon:AddMaskTexture(self.mask)
		self.masked = true
	end
	self.band:SetTexture(ART .. (round and "RingBand" or "SealBand"))
	self.ring:SetTexture(ART .. (round and "Ring" or "Seal"))
	self.well:SetTexture(maskFile)
	self.well:SetVertexColor(WARM_BOTTOM[1], WARM_BOTTOM[2], WARM_BOTTOM[3], 1)
	self.well:ClearAllPoints()
	self.well:SetAllPoints(icon)
	local iconSize = M * ICON_OF
	self.medallion:ClearAllPoints()
	self.medallion:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
	self.medallion:SetSize(math.max(1, M), math.max(1, M))
	for _, t in ipairs({ self.band, self.ring }) do
		t:ClearAllPoints()
		t:SetAllPoints(self.medallion)
	end
	for _, t in ipairs({ self.ringPulse, self.ringArrive, self.ringHover, self.burst }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		t:SetSize(1.45 * M, 1.45 * M)
	end
	if showIcon then
		icon:SetSize(iconSize, iconSize)
		icon:SetPoint("CENTER", art, "TOPLEFT", cx, -cy)
		local cooldown = kit.cooldown
		if cooldown then
			cooldown:ClearAllPoints()
			cooldown:SetAllPoints(icon)
			-- The mask doubles as the swipe, so the sweep has the icon's shape.
			if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(maskFile) end
		end
	end

	-- The sparks: from the medallion's edge to the far corner, on each rail.
	local from = showIcon and M - 4 or C / 2
	local run = math.max(10, W - C - from)
	local gw, gh = 1.7 * BH, 0.30 * BH
	for i, t in ipairs(self.glints) do
		local y = (i <= 2) and (top + outer) or (bottom - outer)
		local core = (i % 2) == 0
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", from, -y)
		t:SetSize(core and gw / 2 or gw, core and gh / 2 or gh)
		t:SetVertexColor(1, core and 1 or 0.92, core and 0.92 or 0.70, 1)
		self.sweep[i].move:SetOffset(run, 0)
	end
	-- The light across the banner, kept on it from end to end.
	local sw = 1.3 * BH
	self.streak:ClearAllPoints()
	self.streak:SetPoint("TOPLEFT", art, "TOPLEFT", left, -(top + 1))
	self.streak:SetSize(sw, BH - 2)
	self.streak:SetVertexColor(1, 0.93, 0.78, 1)
	self.streakAnim.move:SetOffset(math.max(0, W - left - sw), 0)
	self.twinkle:ClearAllPoints()
	self.twinkle:SetPoint("CENTER", art, "TOPLEFT", W - studAt, -(top + studAt))
	self.twinkle:SetSize(1.5 * C, 1.5 * C)
	self.twinkle:SetVertexColor(1, 0.95, 0.8, 1)
	Each(self.flare, "SetVertexColor", 1, 0.85, 0.55, 1)
	self.hoverWash:SetVertexColor(1, 0.92, 0.75, 0.07)

	-- The favour clock: from the medallion to the far corner, along the
	-- bottom rail.
	self.clockX = showIcon and M - 2 or C
	self.clockLen = math.max(10, W - C * 0.8 - self.clockX)
	self.clockH = math.max(3, 0.36 * C)
	self.ember:ClearAllPoints()
	self.ember:SetPoint("LEFT", art, "TOPLEFT", self.clockX, -(bottom - clockAt))
	self.ember:SetHeight(self.clockH)
	self.ash:ClearAllPoints()
	self.ash:SetPoint("LEFT", art, "TOPLEFT", self.clockX, -(bottom - clockAt))
	self.ash:SetSize(self.clockLen, self.clockH)
	self.ash:SetVertexColor(0.30, 0.12, 0.05, 0.55)
	-- The burning end: a spark big enough to see at the game's own scale.
	self.bead:ClearAllPoints()
	self.bead:SetPoint("CENTER", self.ember, "RIGHT", 0, 0)
	self.bead:SetSize(self.clockH * 4.5, self.clockH * 2)
	self.clockW = nil

	-- The jewel at the banner's end, with the icon off.
	for _, t in ipairs({ self.jewel, self.jewelSet }) do
		t:ClearAllPoints()
		t:SetPoint("CENTER", art, "TOPLEFT", jewelX, -cy)
		t:SetSize(jewel, jewel)
	end

	-- The lines: centred as one block.
	local gap = Gap(fs)
	local block = fs + gap + sub
	self.nameY = block / 2 - fs / 2 + 0.5
	self.subY = -(block / 2 - sub / 2) + 0.5
	self.glyphRoom = sub + 3
	self.glyph:ClearAllPoints()
	self.glyph:SetPoint("LEFT", kit.textLayer, "LEFT", textX - 1, self.subY)
	self.glyph:SetSize(sub + 1, sub + 1)
	self.verdict, self.glyphOn, self.subLead = nil, nil, 0

	-- The chips.
	local chipH = sub + 7
	self.chipH = chipH
	self.coinH = math.max(10, sub + 3)
	PlaceThree(self.keyChip, self.keyBox, chipH)
	self.keyBox:ClearAllPoints()
	self.keyBox:SetPoint("RIGHT", art, "RIGHT", -9, 0)
	self.keyBox:SetSize(chipH * 1.75, chipH)
	self.countMode, self.keyUp = nil, false
	-- Measured again in the new font and size.
	self.keyLabel, self.countText = nil, nil

	-- The levels: the medallion over the icon's glows, the chips over the
	-- medallion, the text over everything.
	local base = art:GetFrameLevel()
	self.medallion:SetFrameLevel(base + 2)
	self.chipFrame:SetFrameLevel(base + 3)
	kit.textLayer:SetFrameLevel(base + 4)

	-- The list: rows after the gems, the gems in the drawer.
	self.rowX = showIcon and textX or C + 14
	local rowWidth = math.max(20, W - self.rowX - 12)
	for _, row in ipairs(kit.rows) do
		row:SetWidth(rowWidth)
		fit.room[row] = rowWidth
	end
	self.listShown, self.listAt = nil, nil

	-- Everything shown, then what waits: the lights parked at nothing, the
	-- list for PaintQueue, the chips for Chip, the clock for its debt.
	for _, x in ipairs(self.own) do x:Show() end
	self.medallion:SetShown(showIcon)
	for _, t in ipairs({ self.ringPulse, self.ringArrive, self.ringHover, self.burst }) do
		t:SetShown(showIcon)
	end
	for i = 1, 8 do
		local side = i == 1 or i == 4 or i == 6
		self.border[i]:SetShown(not (showIcon and side))
		self.flare[i]:SetShown(not (showIcon and side))
	end
	Each(self.drawer, "Hide")
	self.drawerBody:Hide()
	for i = 1, #self.gems do
		self.gems[i]:Hide()
		self.gemSets[i]:Hide()
	end
	self.glyph:Hide()
	self.ash:Hide()
	self.ember:Hide()
	self.bead:Hide()
	self.well:SetShown(showIcon)
	self.jewel:SetShown(not showIcon)
	self.jewelSet:SetShown(not showIcon)
	for _, t in ipairs(self.chip) do t:Hide() end
	for _, t in ipairs(self.keyChip) do t:Hide() end
	self.keyText:Hide()
	-- A fight's hold outlives a restyle: Prompt only says so again when it
	-- changes, so the look puts it back itself.
	local held = self.combat
	self.combat, self.hovered, self.washFor, self.outcomeOn, self.refused = nil, nil, nil, nil, nil
	self.pulseSpent = nil
	self:Iron(false)
	if held then self:Combat(true) end

	-- The count's room: a two-digit chip and its inset.
	return textX, math.ceil(chipH * 1.75) + 15
end

-- The shadow under the banner and, while it is up, the drawer.
function Toast:PlaceShadow(drawer)
	local b = self.shadowBox
	local y0, y1 = b[2], b[4]
	if drawer then
		y0 = math.min(y0, drawer[2] - 9)
		y1 = math.max(y1, drawer[4] + 15)
	end
	PlacePieces(self.shadow, self.kit.art, b[1], y0, b[3], y1, 16)
end

-- The text as this look wants it, over what Prompt's StyleText set.
function Toast:Styled(p)
	local kit = self.kit
	local ink = kit.ink
	local d = ns.defaults and ns.defaults.profile.prompt.fontColor
	local chosen = type(p.fontColor) == "table" and type(d) == "table"
		and (math.abs((p.fontColor[1] or 1) - (d[1] or 1)) > 0.002
			or math.abs((p.fontColor[2] or 1) - (d[2] or 1)) > 0.002
			or math.abs((p.fontColor[3] or 1) - (d[3] or 1)) > 0.002)
	if not chosen and ink.light then
		kit.name:SetTextColor(IVORY[1], IVORY[2], IVORY[3], 1)
	end
	if ink.light then
		kit.name:SetShadowColor(0, 0, 0, 0.9)
		kit.name:SetShadowOffset(1, -1)
	end
	-- The chips are dark enamel whatever the panel, so their text is pale gold
	-- as it is.
	kit.count:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	kit.count:SetShadowOffset(0, 0)
	local path, size = kit.fit.path or STANDARD_TEXT_FONT, SubSize(p.fontSize)
	if not self.keyText:SetFont(path, size, "") or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(PALE_GOLD[1], PALE_GOLD[2], PALE_GOLD[3], 1)
	self.keyText:SetShadowOffset(0, 0)
	if ink.light then
		local r, g, b = kit.Legible(0.93, 0.90, 0.83, 4.5)
		for _, fs in ipairs(kit.rows) do fs:SetTextColor(r, g, b, 1) end
		ink.rowReason = "|cffa19685"
	end
end

function Toast:Hide()
	local kit = self.kit
	if not kit then return end
	self.active = nil
	for _, g in ipairs(self.anims) do g:Stop() end
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
	if kit.cooldown then kit.cooldown:SetAlpha(1) end
	kit.count:Show()
	kit.fit.room[kit.name], kit.fit.room[kit.sub] = nil, nil
	kit.textLayer:SetFrameLevel(kit.art:GetFrameLevel() + 1)
	kit.textLayer:SetAlpha(1)
	self.combat, self.hovered, self.washFor, self.outcomeOn = nil, nil, nil, nil
	self.listShown, self.countMode, self.keyUp = nil, nil, false
end

---------------------------------------------------------------------------
-- the lines and the chips
---------------------------------------------------------------------------

function Toast:PlaceLines(right)
	local kit = self.kit
	local name, sub, fit = kit.name, kit.sub, kit.fit
	local inset = math.max(right, 12)
	if self.keyUp then inset = math.max(inset, self.keyRoom or 0) end
	if self.countMode == "pair" then inset = math.max(inset, self:PairRoom()) end
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
function Toast:ShowsVerdict()
	return self.verdict ~= nil and self.kit.sub:GetText() == self.verdict
end

function Toast:Fitted(fs)
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
-- Its width is measured once a paint, by Chip.
function Toast:NameFits(room)
	local kit = self.kit
	local name, fit = kit.name, kit.fit
	local width, size, base = self.nameWidth, fit.size[name], fit.base[name]
	if not (width and size and base and size > 0) then return true end
	local least = math.max(7, math.floor(base * 0.8 + 0.5))
	return width * least / size <= self.W - self.textX - math.max(room, 12) + 0.5
end

-- The key bound to the prompt, as the game spells it short, or nil. Not while
-- unlocked, when a press buffs nobody, nor over an outcome.
function Toast:KeyLabel()
	if self.outcomeOn or type(GetBindingKey) ~= "function" then return nil end
	local p = ns.db and ns.db.profile.prompt
	if not (p and p.locked) then return nil end
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
function Toast:PairRoom()
	return (self.keyRoom or 0) + (self.kit.fit.chipRoom or 0) - 5
end

-- Run on every repaint, which is also the clock's tick. The count's chip at
-- the right, or, with the key's chip there, as a coin on the medallion (with
-- no medallion, a chip beside the key's); the key's chip when a key is bound.
-- Either steps aside for a paint in which the name would otherwise be cut.
function Toast:Chip(on)
	local kit = self.kit
	self:Clock()
	-- Measured here and nowhere else on the way through a paint; the chips'
	-- own words only when they change.
	self.nameWidth = kit.TextWidth(kit.name)

	local key = self:KeyLabel()
	local keyUp = false
	if key then
		if key ~= self.keyLabel then
			self.keyLabel = key
			self.keyText:SetText(key)
			local w = math.max(self.chipH * 1.75, (kit.TextWidth(self.keyText) or self.sub) + 10)
			self.keyW, self.keyRoom = w, math.ceil(w + 15)
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
		if keyUp and self.M > 0 then
			mode = "coin"
		elseif keyUp then
			-- No medallion to hold the coin, which would hang off the
			-- banner's end: the count's chip beside the key's.
			if self:NameFits(self:PairRoom()) then mode = "pair" end
		elseif self:NameFits(kit.fit.chipRoom or 0) then
			mode = "chip"
		end
	end
	if mode then
		local count = kit.count
		local text = count:GetText()
		if type(text) == "string" and text:match("^%d+$") then count:SetText("+" .. text) end
		local h = mode == "coin" and self.coinH or self.chipH
		text = count:GetText()
		if text ~= self.countText or mode ~= self.countMode then
			self.countText = text
			self.countW = math.max(h * 1.75, (kit.TextWidth(count) or self.sub) + (mode == "coin" and 6 or 10))
		end
		local w = self.countW
		if mode ~= self.countMode then
			self.chipBox:ClearAllPoints()
			if mode == "coin" then
				self.chipBox:SetPoint("CENTER", kit.art, "TOPLEFT", self.cx + 0.36 * self.M,
					-(self.cy + 0.32 * self.M))
			elseif mode == "pair" then
				self.chipBox:SetPoint("RIGHT", self.keyBox, "LEFT", -4, 0)
			else
				self.chipBox:SetPoint("RIGHT", kit.art, "RIGHT", -9, 0)
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

-- The favour clock: how much of the time to return the favour is left, as a
-- line of ember along the bottom rail that burns down towards the medallion.
-- A preview shows it part-burnt, so it can be seen while styling.
function Toast:Clock()
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
	if not frac then
		if self.clockW then
			self.clockW = nil
			self.ash:Hide()
			self.ember:Hide()
			self.bead:Hide()
		end
		return
	end
	local width = math.max(1, frac * self.clockLen)
	if not self.clockW or math.abs(width - self.clockW) >= 0.25 then
		self.clockW = width
		self.ember:SetWidth(width)
	end
	self.ash:Show()
	self.ember:Show()
	self.bead:Show()
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The enamel, its light and the clock in one colour; the reason line warmed
-- towards it. An outcome leaves the clock alone: it is about the favour, not
-- the click.
function Toast:Tint(r, g, b, outcome)
	local kit = self.kit
	local er, eg, eb = Fired(r, g, b)
	self.band:SetVertexColor(er, eg, eb, 1)
	self.jewel:SetVertexColor(er, eg, eb, 1)
	-- Light added to a light panel only greys it, so there it is a hint.
	local bloom = kit.ink.light and 0.32 or 0.13
	self.bloom:SetVertexColor(r, g, b, bloom)
	self.bloomPulse:SetVertexColor(r, g, b, 0.26)
	self.bloomArrive:SetVertexColor(r, g, b, 0.43)
	self.ringPulse:SetVertexColor(r, g, b, 0.22)
	self.ringArrive:SetVertexColor(r, g, b, 0.45)
	self.ringHover:SetVertexColor(r, g, b, 0.30)
	self.burst:SetVertexColor(r, g, b, 1)
	if not outcome then
		-- The time left burns hotter than the enamel, towards white, so it
		-- is a live line over its ash and not one more gold rail.
		self.ember:SetVertexColor(Mix(er, eg, eb, 0.35))
		self.bead:SetVertexColor(Mix(r, g, b, 0.45))
	end
	-- The subtitle: warm grey taken most of the way to the reason, held to its
	-- contrast; on a light panel the plain grey, which the tint would cost.
	local sr, sg, sb
	if not kit.ink.light then
		local s = kit.ink.sub or WARM_GREY
		sr, sg, sb = s[1], s[2], s[3]
	else
		sr = WARM_GREY[1] + (r - WARM_GREY[1]) * 0.6
		sg = WARM_GREY[2] + (g - WARM_GREY[2]) * 0.6
		sb = WARM_GREY[3] + (b - WARM_GREY[3]) * 0.6
	end
	sr, sg, sb = kit.Legible(sr, sg, sb, 4.5)
	kit.sub:SetTextColor(sr, sg, sb, 1)
	self.glyph:SetVertexColor(sr, sg, sb, 1)
	self.tint = { r, g, b }
end

function Toast:PaintReason(r, g, b, _, mode)
	mode = mode or "icon"
	if mode == "off" then
		-- Neutral enamel, and the light a warm white at half strength.
		self:Tint(NEUTRAL[1], NEUTRAL[2], NEUTRAL[3])
		self.bloom:SetVertexColor(1, 0.92, 0.80, (self.kit.ink.light and 0.16 or 0.07))
		self.ember:SetVertexColor(1, 0.86, 0.60, 0.9)
	else
		-- "stripe" is "both" here: the toast has no stripe, and the enamel is
		-- where its reason is.
		self:Tint(r, g, b)
	end
	-- A refusal greyed the icon; a fight keeps it grey.
	self.refused = nil
	self.kit.icon:SetDesaturated(self.combat and true or false)
end

-- Gold, or the iron of a fight.
function Toast:Iron(on)
	for _, t in ipairs(self.gold) do
		t:SetDesaturated(on)
		if on then t:SetVertexColor(IRON[1], IRON[2], IRON[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
	end
end

-- The banner holds; the gold goes to iron, the icon greys, the text dims and
-- the lights go out. The enamel keeps its colour, and the clock burns on,
-- dimmed: the reason is the one bright thing left.
function Toast:Combat(on)
	on = on and true or false
	if self.combat == on then return end
	self.combat = on
	local kit = self.kit
	self:Iron(on)
	kit.textLayer:SetAlpha(on and TEXT_COMBAT or 1)
	kit.icon:SetDesaturated(on or self.refused or false)
	-- Dimmed by its colour, never its alpha: a see-through icon showed the
	-- world through one half and the banner through the other.
	local v = on and ICON_COMBAT or 1
	kit.icon:SetVertexColor(v, v, v)
	if kit.cooldown then kit.cooldown:SetAlpha(on and ICON_COMBAT or 1) end
	self.bloom:SetAlpha(on and 0 or 1)
	self.ember:SetAlpha(on and 0.7 or 1)
	self.bead:SetAlpha(on and 0.7 or 1)
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

-- The rails catch the light: a new favour, on Full.
function Toast:Sweep()
	PlayAll(self.sweep)
	self.streakAnim:Stop()
	self.streakAnim:Play()
	self.twinkleAnim:Stop()
	self.twinkleAnim:Play()
end

-- The breathing, held still: after its breaths, and on Calm.
function Toast:HoldPulse()
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.bloomPulse:SetAlpha(0.45)
	self.ringPulse:SetAlpha(0.45)
end

function Toast:Attention(isNew, arrived, flashStyle)
	local full = self.kit.FullEffects()
	if flashStyle == "off" or self.combat then
		self:StopAttention()
		return
	end
	if isNew then
		self.pulseSpent = nil
		-- Sparks down the rails for a new favour, never for a new face.
		if full then self:Sweep() end
	end
	-- The favour just done, or a new favour on "once": the light swells.
	if full and (arrived or (isNew and flashStyle == "once")) then PlayAll(self.arrive) end
	if flashStyle ~= "pulse" then
		self:StopAttention()
		return
	end
	if not full or self.pulseSpent then
		-- Calm, or breathed its fill: nothing loops. The glow is held.
		self:HoldPulse()
		return
	end
	if self.pulse[1]:IsPlaying() then return end
	self.bloomPulse:SetAlpha(0.45)
	self.ringPulse:SetAlpha(0.45)
	for _, g in ipairs(self.pulse) do g:Play() end
	-- A few breaths and then still: a loop that runs for as long as somebody
	-- waits is the one thing on an always-on panel that ages badly.
	self.pulseGen = (self.pulseGen or 0) + 1
	local gen = self.pulseGen
	if C_Timer and C_Timer.After then
		C_Timer.After(BREATHS * BREATH * 2, function()
			if gen ~= Toast.pulseGen or not Toast.active then return end
			Toast.pulseSpent = true
			if Toast.pulse[1]:IsPlaying() then Toast:HoldPulse() end
		end)
	end
end

function Toast:StopAttention()
	self.pulseGen = (self.pulseGen or 0) + 1
	for _, g in ipairs(self.pulse) do g:Stop() end
	self.bloomPulse:SetAlpha(0)
	self.ringPulse:SetAlpha(0)
end

function Toast:Flourish(kind)
	-- Nothing for a cast nobody confirmed: a flourish is a claim.
	if kind ~= "cast" then return end
	PlayAll(self.flareAnims)
	if self.kit.icon:IsShown() then
		local o = OUTCOME.cast
		self.burst:SetVertexColor(o[1], o[2], o[3], 1)
		self.burstAnim:Stop()
		self.burstAnim:Play()
	end
end

function Toast:StopFlourishes()
	for _, g in ipairs(self.flareAnims) do g:Stop() end
	self.burstAnim:Stop()
	for _, g in ipairs(self.sweep) do g:Stop() end
	self.streakAnim:Stop()
	self.twinkleAnim:Stop()
end

function Toast:Hover(on)
	on = on and true or false
	if self.hovered == on then return end
	self.hovered = on
	for i, g in ipairs(self.hoverAnims) do
		local t = i == 1 and self.hoverWash or self.ringHover
		local from = t:GetAlpha()
		g:Stop()
		t:SetAlpha(from)
		g.to = on and 1 or 0
		g.fade:SetFromAlpha(from)
		g.fade:SetToAlpha(g.to)
		g.fade:SetDuration(on and 0.12 or 0.18)
		g:Play()
	end
end

---------------------------------------------------------------------------
-- outcomes
---------------------------------------------------------------------------

-- The name stays where it was and the subtitle becomes the verdict, so the
-- eye never has to find the person again. The enamel and the wash take the
-- outcome's colour.
function Toast:PaintOutcome(kind, lead, sub, who, stamp)
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
	self:Tint(o[1], o[2], o[3], true)
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
	-- The wash, once per click: a repaint during the outcome leaves it be.
	if stamp ~= self.washFor then
		self.washFor = stamp
		self.wash:SetVertexColor(o[1], o[2], o[3], WASH[kind] or WASH.cast)
		self.washAnim:Stop()
		self.wash:SetAlpha(1)
		if kit.FullEffects() then
			self.washAnim.to = 0
			self.washAnim:Play()
		end
	end
end

function Toast:ClearOutcome()
	self.outcomeOn = nil
	if not self.washFor then return end
	self.washFor = nil
	self.washAnim:Stop()
	self.wash:SetAlpha(0)
end

---------------------------------------------------------------------------
-- the list
---------------------------------------------------------------------------

-- The drawer slides out from under the banner's rail, above or below; each
-- row wears a gem in its reason's colour.
function Toast:PaintQueue(rows, shown, above)
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
			self.drawerBody:Hide()
			self:PlaceShadow(nil)
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

	local pitch = self.sub + 6
	local depth = 3 + 4 + shown * pitch + 5
	local x0 = self.M > 0 and self.cx + 4 or 5.5
	local x1 = self.W - 5.5
	local y0, y1
	if above then
		y1 = self.top + 3
		y0 = y1 - depth
	else
		y0 = self.bottom - 3
		y1 = y0 + depth
	end
	PlacePieces(self.drawer, art, x0, y0, x1, y1, 8)
	for i = 1, 8 do
		local topRow = i <= 3
		local bottomRow = i >= 6
		self.drawer[i]:SetShown(not ((above and bottomRow) or (not above and topRow)))
	end
	Box(self.drawerBody, art, x0 + 0.5, y0 + 0.5, x1 - 0.5, y1 - 0.5)
	self.drawerBody:Show()
	self:PlaceShadow({ x0, y0, x1, y1 })

	local gem = self.sub + 3
	for i = 1, shown do
		local fs = kit.rows[i]
		-- Row centres, reading downwards either way.
		local y
		if above then
			y = self.top - 4 - (shown - i) * pitch - pitch / 2
		else
			y = self.bottom + 4 + (i - 1) * pitch + pitch / 2
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
