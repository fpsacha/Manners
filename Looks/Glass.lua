-- Manners -- Glass, dressed: what the default look wears over its pane.
--
-- THE SOURCE. The game's own interface. The action bar of 2004 was a bar of
-- dark glass in gilt rails with a gryphon sat at each end, and its buttons had
-- two lights every player knows: the border of light that runs round a button
-- whose spell is ready, and the star that winks as a cooldown comes up. Glass
-- is that bar with one button on it.
--
--   * with "Gryphons at the ends" switched on (Look; off as it comes), a
--     gilt gryphon at each end of the pane, looking outward, taller than the
--     pane (the wing stands over its top); its eye is an ember in the
--     reason's colour;
--   * a gilt rail, beaded, along the pane's top and bottom;
--   * light inside the glass: two sheets of caustics drifting across each
--     other under the words, slowly, at rest;
--   * somebody owed: the ready border runs round the icon in the reason's
--     colour, a bloom breathing under it, and the gryphons' eyes burn;
--   * a favour just done: the gilt catches the light, once;
--   * a buff landed: the gilt flashes and the star winks on the icon's corner.
--
-- It is a DRESSING (Looks/Looks.lua), not a look: Prompt/Panel.lua still draws
-- the pane, the bezel, the text and every light it drew before, and tests
-- them; this file adds to that and takes away only what it added.
--
-- The moving art is Looks/Flow.lua's: the caustics and the ready border are
-- textures scrolled by their coordinates, which no animation group can do. On
-- Calm nothing moves and nothing loops: the border stands still, lit. In a
-- fight the lights are out and the gilt dims.
--
-- `idle` lists the animation groups that loop with nobody owed (the eyes'
-- slow glint): the author asked for a prompt that is alive at rest, and the
-- scenarios that hold every other look to "nothing loops while it is idle"
-- pass these by name. `outside` lists the art that stands outside the panel.
--
-- The art is Textures/Glass, drawn by tools/make_glass_textures.py.
--
-- THE PAINTED FRAME. Unless *Earlier art* (prompt.classicArt) is on, the bar is
-- a painting (art/looks/glass, Looks/Painted.lua, wrapped round this dressing
-- by Prompt/Panel.lua): dark glass in gilt rails, a gilt socket for the icon, a
-- gryphon's head at each end. It replaces the pane, its light, its shadow, the
-- rails and the gryphons (`paintedHides`); what tells something stays live over
-- it: the bezel in the reason's colour inside the gilt socket, the light in the
-- glass, the ready border, the star, and Panel.lua's own lights.

local _, ns = ...
local Colour = ns.Looks.Colour
local Looks = ns.Looks

local ART = "Interface\\AddOns\\Manners\\Textures\\Glass\\Glass_"

-- ---- must agree with tools/make_glass_textures.py ----------------------
-- The eye's middle in the left gryphon's file, as fractions from its top left.
local EYE_X, EYE_Y = 91 / 256, 68 / 256
-- A tile of the rail and of the ready border is this many units long; a tile
-- of the caustics this wide and tall.
local RAIL_TILE, ANT_TILE, CAUSTIC_W, CAUSTIC_H = 16, 16, 72, 36

-- How much taller than the pane a gryphon stands, the least and the most it
-- is drawn, how far its file reaches in over the pane's end (a fraction of
-- its size) and how far it hangs below the pane's foot.
local GRYPHON_OVER, GRYPHON_MIN, GRYPHON_MAX, GRYPHON_IN, GRYPHON_DROP = 18, 34, 140, 0.10, 3
-- The eye's ember, a fraction of the gryphon's size; its alpha at rest, while
-- somebody is owed, and at the top of its slow glint.
local EYE_SIZE, EYE_REST, EYE_OWED, EYE_GLINT = 0.11, 0.55, 1.0, 0.95
-- The rail: its height, and how far it stands out past the pane's edge.
local RAIL_H, RAIL_OUT = 4, 1.5
-- The caustics: each sheet's alpha, its speed in tiles a second (the two cross).
local CAUSTIC_ALPHA = 0.085
local CAUSTIC_SPEEDS = { { 0.021, 0.008 }, { -0.013, 0.012 } }
-- The ready border: how thick, how far outside the bezel, how fast it runs
-- (tiles a second), its alpha and its bloom's (low and high of the breath).
local ANT_H, ANT_OUT, ANT_SPEED, ANT_ALPHA = 6, 1, 1.15, 1
local BLOOM_LO, BLOOM_HI, BLOOM_OUT, BREATH = 0.15, 0.45, 5, 1.1
-- The gilt catching the light: its peak for a favour and for a landing, and
-- how long it takes (under 0.6 s, as every additive light here).
local CATCH_FAVOUR, CATCH_LAND, CATCH_UP, CATCH_DOWN = 0.55, 0.9, 0.08, 0.42
-- The star: its size against the icon, its peak, its quarter turn.
local STAR_SIZE, STAR_PEAK, STAR_UP, STAR_DOWN = 0.9, 1.0, 0.10, 0.40
-- The gilt in a fight.
local COMBAT_GILT = 0.5
-- The eyes' glint at rest: one every this many seconds, each gryphon in turn.
local GLINT_EVERY, GLINT_UP, GLINT_DOWN = 7, 0.5, 1.1

local WARM = { 1.00, 0.86, 0.55 }

-- ---- must agree with art/looks/glass (units of the bar's core height) -----
-- The painted socket's gilt frame, half its side; where the well starts after
-- it (from the painting's left end) and where it stops before the right end.
local PAINT_FRAME_HALF, PAINT_WELL_IN, PAINT_WELL_END = 0.533, 1.53, 0.46
-- The painting in a fight: dimmed, less than the gilt was, so the words keep it.
local PAINT_FIGHT = 0.72
-- The light in the painted glass, against the pane's.
local PAINT_CAUSTIC = 0.6
-- The brightest ground the words are held to on the painted well (a luminance):
-- its sheen with that light over it, a little over what the painting measures.
local PAINT_INK_HI = 0.07

local Glass = { idle = {}, outside = {} }
Looks.RegisterDress("glass", Glass)

-- What the painting replaces: Panel.lua's pane, its light, its shadow and the
-- edge light laid on the pane's cut (Build copies them in from the panel), and
-- this dressing's rails and gryphons. The bezel stays: it carries the reason.
Glass.paintedHides = { "pane", "glassLight", "shadows", "edgeGlass", "railTop", "railBottom", "gryphon", "lit", "eye" }
-- Of the socket's dark glass: the bezel fills it, the icon its hole.
Glass.paintedIconFill = 0.84
Glass.PAINT_WELL_IN, Glass.PAINT_WELL_END = PAINT_WELL_IN, PAINT_WELL_END

---------------------------------------------------------------------------
-- pieces
---------------------------------------------------------------------------

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

-- A group leaves its region at `to` (the group's own `to` when it has one)
-- however it ends.
local function Park(group, region, to)
	local function park() region:SetAlpha(group.to or to or 0) end
	group:SetScript("OnFinished", park)
	group:SetScript("OnStop", park)
end

-- Up to `peak`, then down to nothing.
local function Flash(region, peak, up, down)
	local g = region:CreateAnimationGroup()
	g.up = Alpha(g, 0, peak, up, 1, nil, "OUT")
	g.down = Alpha(g, peak, 0, down, 2, nil, "OUT")
	Park(g, region, 0)
	return g
end

local function Replay(g)
	g:Stop()
	g:Play()
end

---------------------------------------------------------------------------
-- building
---------------------------------------------------------------------------

function Glass:Build(kit)
	self.kit = kit
	local art = kit.art
	local own = {}
	self.own = own
	local function keep(t) own[#own + 1] = t return t end
	local function tex(parent, layer, sublevel, file, blend, wrapH, wrapV)
		local t = parent:CreateTexture(nil, layer, nil, sublevel)
		if wrapH then t:SetTexture(ART .. file, wrapH, wrapV or "CLAMP") else t:SetTexture(ART .. file) end
		if blend then t:SetBlendMode(blend) end
		return keep(t)
	end

	-- The light in the glass and the rails are the pane's own: on art, over
	-- the pane and under the icon and its bezel.
	self.caustic = {}
	for i = 1, #CAUSTIC_SPEEDS do
		self.caustic[i] = tex(art, "BACKGROUND", -5 + i, "Caustic", "BLEND", "REPEAT", "REPEAT")
		self.caustic[i]:SetAlpha(0)
	end
	self.railTop = tex(art, "BORDER", 4, "Rail", nil, "REPEAT", "CLAMP")
	self.railBottom = tex(art, "BORDER", 4, "Rail", nil, "REPEAT", "CLAMP")

	-- Everything else stands on a frame of its own over art: the gryphons at
	-- the ends, the ready border round the bezel, the star.
	local frame = CreateFrame("Frame", nil, art)
	frame:SetAllPoints(art)
	frame:SetFrameLevel(art:GetFrameLevel() + 1)
	self.frame = frame
	self.gryphon, self.lit, self.eye = {}, {}, {}
	for i, side in ipairs({ "L", "R" }) do
		self.gryphon[i] = tex(frame, "ARTWORK", 1, "Gryphon" .. side)
		self.lit[i] = tex(frame, "ARTWORK", 3, "GryphonLit" .. side, "ADD")
		self.lit[i]:SetAlpha(0)
		self.eye[i] = tex(frame, "ARTWORK", 2, "Eye")
		self.eye[i]:SetAlpha(EYE_REST)
		self.outside[#self.outside + 1] = self.gryphon[i]
		self.outside[#self.outside + 1] = self.lit[i]
		self.outside[#self.outside + 1] = self.eye[i]
	end

	-- The ready border: a bloom and four strips of one file, each laid along
	-- its side (Flow's quarter turns), on a frame that fades as one.
	local ants = CreateFrame("Frame", nil, frame)
	ants:SetAlpha(0)
	ants:Hide()
	self.antsFrame = ants
	self.bloom = tex(ants, "ARTWORK", 1, "AntsGlow")
	self.bloom:SetAlpha(BLOOM_LO)
	self.ants = {}
	for i = 1, 4 do self.ants[i] = tex(ants, "ARTWORK", 2, "Ants", "BLEND", "REPEAT", "CLAMP") end

	self.star = tex(frame, "OVERLAY", 2, "Star", "ADD")
	self.star:SetAlpha(0)

	-- The key's letter on the painted keycap, shown only with Show my key on
	-- the prompt asking for it and a key bound (Painted.KeyShown).
	self.keyText = frame:CreateFontString(nil, "OVERLAY")
	self.keyText:SetJustifyH("CENTER")
	self.keyText:SetWordWrap(false)
	self.keyText:Hide()
	-- What the painting replaces of the panel's own (paintedHides).
	local regions = ns.Prompt and ns.Prompt.Regions and ns.Prompt:Regions()
	if regions then
		self.pane, self.glassLight, self.shadows = regions.pane, regions.glassLight, regions.shadows
		self.edgeGlass = regions.edgeLight and regions.edgeLight.glass
	end

	-- What moves by its coordinates.
	local flow = Looks.Flow.New(frame)
	self.flow = flow
	self.causticFlow, self.antFlow = {}, {}
	for i, speed in ipairs(CAUSTIC_SPEEDS) do
		self.causticFlow[i] = flow:Scroll(self.caustic[i], speed[1], speed[2], 1, 1)
	end
	for i = 1, 4 do
		-- The window slides back along the file, so the dash runs forward.
		self.antFlow[i] = flow:Scroll(self.ants[i], -ANT_SPEED, 0, 1, 1, i - 1)
	end

	-- What moves by animation.
	local anims = {}
	self.anims = anims
	local function anim(g) anims[#anims + 1] = g return g end
	-- The border fading in, and its bloom's breath.
	local show = ants:CreateAnimationGroup()
	Alpha(show, 0, 1, 0.22, 1, nil, "OUT")
	Park(show, ants, 1)
	self.antsShow = anim(show)
	local breath = self.bloom:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	Alpha(breath, BLOOM_LO, BLOOM_HI, BREATH, 1, nil, "IN_OUT")
	Park(breath, self.bloom, BLOOM_LO)
	self.breath = anim(breath)
	-- The eyes: burning while somebody is owed, and a slow glint at rest.
	self.eyeBurn, self.eyeGlint = {}, {}
	for i, eye in ipairs(self.eye) do
		local burn = eye:CreateAnimationGroup()
		burn:SetLooping("BOUNCE")
		Alpha(burn, EYE_REST, EYE_OWED, BREATH, 1, nil, "IN_OUT")
		Park(burn, eye, EYE_REST)
		self.eyeBurn[i] = anim(burn)
		local glint = eye:CreateAnimationGroup()
		glint:SetLooping("REPEAT")
		-- Held, up, down, held: one glint a turn, the second gryphon's half a
		-- turn after the first.
		local lead = (i - 1) * GLINT_EVERY / 2
		local order = 0
		if lead > 0 then
			order = order + 1
			Alpha(glint, EYE_REST, EYE_REST, lead, order)
		end
		Alpha(glint, EYE_REST, EYE_GLINT, GLINT_UP, order + 1, nil, "IN_OUT")
		Alpha(glint, EYE_GLINT, EYE_REST, GLINT_DOWN, order + 2, nil, "IN_OUT")
		Alpha(glint, EYE_REST, EYE_REST, GLINT_EVERY - GLINT_UP - GLINT_DOWN - lead, order + 3)
		Park(glint, eye, EYE_REST)
		self.eyeGlint[i] = anim(glint)
		self.idle[#self.idle + 1] = glint
	end
	-- The gilt catching the light, and the star.
	self.catch = {}
	for i, lit in ipairs(self.lit) do self.catch[i] = anim(Flash(lit, CATCH_LAND, CATCH_UP, CATCH_DOWN)) end
	local wink = Flash(self.star, STAR_PEAK, STAR_UP, STAR_DOWN)
	-- A quarter turn as it winks, in step with the light: a part with its
	-- rise and the rest with its fall.
	for order, part in ipairs({ { STAR_UP, -20 }, { STAR_DOWN, -70 } }) do
		local turn = wink:CreateAnimation("Rotation")
		turn:SetDuration(part[1])
		turn:SetOrder(order)
		if turn.SetDegrees then turn:SetDegrees(part[2]) end
		if turn.SetOrigin then turn:SetOrigin("CENTER", 0, 0) end
	end
	self.wink = anim(wink)
	-- Written down while nothing plays: what each texture rests at, so a
	-- colour never moves it (Looks.lua, ONE ALPHA).
	ns.Looks.HoldAll(self.own)
end

---------------------------------------------------------------------------
-- layout
---------------------------------------------------------------------------

function Glass:Apply(p, above)
	local kit = self.kit
	local art = kit.art
	self.p, self.active = p, true
	local W, H = p.width, p.height
	self.frame:Show()
	-- The key's letter is the painting's alone: the next paint asks again.
	self.keyText:Hide()

	-- The gryphons: each at its end, its file reaching a little in over the
	-- pane, its foot just under the pane's.
	-- "Gryphons at the ends" (Look) brings them, eyes and all; off, as the
	-- look comes, the bar ends at its rails.
	local G = math.max(GRYPHON_MIN, math.min(GRYPHON_MAX, H + GRYPHON_OVER))
	local reach = G * GRYPHON_IN
	local gryphons = p.gryphons == true
	self.gryphonSize, self.gryphons = G, gryphons
	for i = 1, 2 do
		local left = i == 1
		for _, t in ipairs({ self.gryphon[i], self.lit[i] }) do
			t:ClearAllPoints()
			t:SetSize(G, G)
			if left then
				t:SetPoint("BOTTOMRIGHT", art, "BOTTOMLEFT", reach, -GRYPHON_DROP)
			else
				t:SetPoint("BOTTOMLEFT", art, "BOTTOMRIGHT", -reach, -GRYPHON_DROP)
			end
			t:SetShown(gryphons)
		end
		local eye = self.eye[i]
		eye:ClearAllPoints()
		eye:SetSize(G * EYE_SIZE, G * EYE_SIZE)
		eye:SetPoint("CENTER", self.gryphon[i], "TOPLEFT", G * (left and EYE_X or 1 - EYE_X), -G * EYE_Y)
		eye:SetShown(gryphons)
	end

	-- The rails, whole along the pane; the bottom one upside down.
	local tiles = W / RAIL_TILE
	self.railTop:ClearAllPoints()
	self.railTop:SetPoint("TOPLEFT", art, "TOPLEFT", 0, RAIL_OUT)
	self.railTop:SetPoint("BOTTOMRIGHT", art, "TOPRIGHT", 0, RAIL_OUT - RAIL_H)
	self.railTop:SetTexCoord(0, tiles, 0, 1)
	self.railBottom:ClearAllPoints()
	self.railBottom:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", 0, -RAIL_OUT)
	self.railBottom:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT", 0, RAIL_H - RAIL_OUT)
	self.railBottom:SetTexCoord(0, tiles, 1, 0)
	self.railTop:Show()
	self.railBottom:Show()

	-- The light in the glass: inside the rails, from end to end.
	local inset = RAIL_H - RAIL_OUT
	local cw, ch = math.max(1, W - 2), math.max(1, H - 2 * inset)
	for i, t in ipairs(self.caustic) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", art, "TOPLEFT", 1, -inset)
		t:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -1, inset)
		t:Show()
		self.causticFlow[i]:Window(cw / CAUSTIC_W, ch / CAUSTIC_H)
	end

	-- The ready border, round the bezel (which Panel.lua has just placed).
	self.showIcon = p.showIcon and true or false
	if self.showIcon then
		local bezel = math.min(p.iconSize / 0.75, H - 1)
		self:PlaceBorder(bezel + 2 * ANT_OUT, p.iconSize)
	else
		self.antsFrame:Hide()
		self.star:Hide()
	end

	self.combat, self.rested = nil, nil
	self:Gilt()
	self:Rest()
end

-- The ready border `side` units square, centred on the icon, and the star on
-- the icon's corner.
function Glass:PlaceBorder(side, iconSize)
	local kit = self.kit
	local ants = self.antsFrame
	ants:ClearAllPoints()
	ants:SetSize(side, side)
	ants:SetPoint("CENTER", kit.icon, "CENTER", 0, 0)
	self.bloom:ClearAllPoints()
	self.bloom:SetPoint("TOPLEFT", ants, "TOPLEFT", -BLOOM_OUT, BLOOM_OUT)
	self.bloom:SetPoint("BOTTOMRIGHT", ants, "BOTTOMRIGHT", BLOOM_OUT, -BLOOM_OUT)
	-- Top, right, bottom, left: each strip its side's length, the dash
	-- handed from the end of one to the start of the next.
	local span = side / ANT_TILE
	local places = {
		{ "TOPLEFT", "TOPLEFT", 0, ANT_H / 2, "BOTTOMRIGHT", "TOPRIGHT", 0, -ANT_H / 2 },
		{ "TOPLEFT", "TOPRIGHT", -ANT_H / 2, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", ANT_H / 2, 0 },
		{ "TOPLEFT", "BOTTOMLEFT", 0, ANT_H / 2, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, -ANT_H / 2 },
		{ "TOPLEFT", "TOPLEFT", -ANT_H / 2, 0, "BOTTOMRIGHT", "BOTTOMLEFT", ANT_H / 2, 0 },
	}
	for i, at in ipairs(places) do
		local t = self.ants[i]
		t:ClearAllPoints()
		t:SetPoint(at[1], ants, at[2], at[3], at[4])
		t:SetPoint(at[5], ants, at[6], at[7], at[8])
		t:SetAlpha(ANT_ALPHA)
		self.antFlow[i]:Window(span, 1)
		self.antFlow[i]:Phase(-(i - 1) * span, 0)
	end
	local star = self.star
	star:ClearAllPoints()
	star:SetSize(iconSize * STAR_SIZE, iconSize * STAR_SIZE)
	star:SetPoint("CENTER", kit.icon, "TOPRIGHT", -iconSize * 0.14, -iconSize * 0.14)
	star:Show()
end

-- The gilt's own colour: as drawn, or dimmed for a fight.
function Glass:Gilt()
	local k = self.combat and COMBAT_GILT or 1
	for i = 1, 2 do Colour(self.gryphon[i], k, k, k) end
	Colour(self.railTop, k, k, k)
	Colour(self.railBottom, k, k, k)
	-- The painting dims with it, less far (nothing while it is not up).
	local t = self.combat and PAINT_FIGHT or 1
	Looks.Painted.Tone(self, t, t, t, self.combat)
end

-- What runs with nobody owed: the light in the glass and the eyes' glint, on
-- Full effects, out of a fight and with the prompt up; nothing otherwise.
-- Asked at every paint (Painted), so it does nothing unless something changed.
function Glass:Rest()
	local on = (self.active and not self.combat and self.kit.FullEffects() and self.kit.button:IsShown()) and true or false
	local state = (on and 1 or 0) + (self.owed and 2 or 0) + (self.combat and 4 or 0)
	if state == self.rested then return end
	self.rested = state
	-- The painting has gryphons of its own: these eyes are hidden under it, and
	-- its glass has a sheen of its own, which the light in it keeps fainter on.
	local eyes = not Looks.Painted.On(self)
	for i, t in ipairs(self.caustic) do
		t:SetAlpha(on and (eyes and CAUSTIC_ALPHA or CAUSTIC_ALPHA * PAINT_CAUSTIC) or 0)
		if on then
			if not self.causticFlow[i]:IsPlaying() then self.causticFlow[i]:Play() end
		else
			self.causticFlow[i]:Stop()
		end
	end
	for i, g in ipairs(self.eyeGlint) do
		local run = on and not self.owed and eyes
		if run then
			if not g:IsPlaying() then g:Play() end
		elseif g:IsPlaying() then
			g:Stop()
		end
		if not run and not self.eyeBurn[i]:IsPlaying() then
			self.eye[i]:SetAlpha(self.combat and 0 or (self.owed and EYE_OWED or EYE_REST))
		end
	end
end

-- Every paint of a person: the prompt is up, so what runs at rest may run.
function Glass:Painted()
	self:Rest()
	-- The key's letter (and, by Looks/Painted.lua's wrap, the keycap) follows a
	-- key bound or unbound since, and an outcome on the panel.
	self:Chip(true)
end

---------------------------------------------------------------------------
-- the painted frame (Looks/Painted.lua): what this dressing keeps, moved onto
-- the painting. Painted.lua has laid the pieces and put the icon in the
-- socket; `g` is its Painted.Layout. Panel.lua lays its own regions after.
---------------------------------------------------------------------------

function Glass:PaintedPlace(g, p, above)
	local art = self.kit.art
	local u = g.unit
	-- The light in the glass: inside the well, from the socket's gilt to the
	-- right end's.
	local x0 = g.left + PAINT_WELL_IN * u
	local x1 = math.max(x0 + 1, g.right - PAINT_WELL_END * u)
	local y0, y1 = g.wellTop, math.max(g.wellTop + 1, g.wellBottom)
	for i, t in ipairs(self.caustic) do
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", art, "TOPLEFT", x0, -y0)
		t:SetPoint("BOTTOMRIGHT", art, "TOPLEFT", x1, -y1)
		self.causticFlow[i]:Window((x1 - x0) / CAUSTIC_W, (y1 - y0) / CAUSTIC_H)
	end
	-- The ready border round the painted socket's gilt frame.
	if self.showIcon then self:PlaceBorder(2 * PAINT_FRAME_HALF * u + 2 * ANT_OUT, g.iconSize) end
	-- The key's letter centred on the keycap.
	self.keyText:ClearAllPoints()
	self.keyText:SetPoint("CENTER", art, "TOPLEFT", g.keyX, -g.keyY)
	self.keyText:SetWidth(g.keyW)
	return g.textX
end

-- The key's letter in the keycap's ink, no larger than the keycap holds.
function Glass:PaintedStyled(g)
	-- The words are held to the painted well at its brightest with the light in
	-- the glass over its sheen: never a ground darker than PAINT_INK_HI.
	local words = self.kit.ink
	words.hi = math.max(words.hi or 0, PAINT_INK_HI)
	local ink = g and g.keyInk
	if not ink then return end
	local path = self.kit.name:GetFont()
	local size = math.max(6, math.min(self.kit.fit.base[self.kit.name] or 13, math.floor(g.keyH * 0.7)))
	if not (path and self.keyText:SetFont(path, size, "")) or not self.keyText:GetFont() then
		self.keyText:SetFont(STANDARD_TEXT_FONT, size, "")
	end
	self.keyText:SetTextColor(ink[1], ink[2], ink[3], 1)
	self.keyText:SetShadowOffset(0, 0)
end

-- The key's letter on the painting; Painted.lua's wrap then shows the keycap,
-- or hides it and this letter with it (Painted.KeyShown). The count chip is
-- Panel.lua's.
function Glass:Chip(on)
	self.outcomeOn = self.kit and self.kit.OutcomeLive() or nil
	local key = Looks.Painted.On(self) and Looks.BoundKey()
	if key then
		local text = Looks.ShortKey(key)
		self.keyText:SetText(type(text) == "string" and text ~= "" and text or key)
	end
	self.keyText:SetShown(key and true or false)
	return on
end

function Glass:Hide()
	if not self.kit then return end
	self.active, self.owed, self.combat, self.rested = nil, nil, nil, nil
	self.flow:StopAll()
	for _, g in ipairs(self.anims) do g:Stop() end
	-- What stands on art itself is hidden piece by piece; the rest goes with
	-- its frame, and comes back with it.
	for _, t in ipairs(self.caustic) do t:Hide() end
	self.railTop:Hide()
	self.railBottom:Hide()
	self.antsFrame:SetAlpha(0)
	self.antsFrame:Hide()
	self.frame:Hide()
end

---------------------------------------------------------------------------
-- the reason
---------------------------------------------------------------------------

-- The game keeps one alpha for a texture: SetVertexColor's fourth number
-- writes over what SetAlpha set. 1.11.19 coloured the light in the glass
-- after Rest had dimmed it, and drew it at full strength over the pane, a
-- grey marble under the words. So every colour here goes through Colour
-- (Looks.lua, ONE ALPHA), which leaves each texture at the alpha it rests at
-- and never reads one back in the middle of a flash.
function Glass:PaintReason(r, g, b, reason, mode)
	self:Recolour(r, g, b, mode)
end

function Glass:Recolour(r, g, b, mode)
	local kit = self.kit
	local er, eg, eb = WARM[1], WARM[2], WARM[3]
	if mode ~= "off" then er, eg, eb = kit.Tint(r, g, b, 0.25) end
	for i = 1, 2 do Colour(self.eye[i], er, eg, eb) end
	local ar, ag, ab = kit.Tint(r, g, b, 0.72)
	for i = 1, 4 do Colour(self.ants[i], ar, ag, ab) end
	Colour(self.bloom, r, g, b)
	local cr, cg, cb = kit.Tint(r, g, b, 0.75)
	for _, t in ipairs(self.caustic) do Colour(t, cr, cg, cb) end
	Colour(self.star, kit.Tint(r, g, b, 0.6))
end

---------------------------------------------------------------------------
-- somebody owed
---------------------------------------------------------------------------

function Glass:Attention(isNew, arrived, flashStyle)
	if flashStyle == "off" or self.combat or not self.active then
		self:StopAttention()
		return
	end
	local full = self.kit.FullEffects()
	local was = self.owed
	self.owed = true
	if self.showIcon then
		local ants = self.antsFrame
		ants:Show()
		if not was then
			if full then Replay(self.antsShow) else ants:SetAlpha(1) end
		end
		-- Running on Full; on Calm the border stands, lit and still.
		for i = 1, 4 do
			if full and flashStyle == "pulse" then
				if not self.antFlow[i]:IsPlaying() then self.antFlow[i]:Play() end
			else
				self.antFlow[i]:Stop()
			end
		end
		if full and flashStyle == "pulse" then
			if not self.breath:IsPlaying() then self.breath:Play() end
		else
			self.breath:Stop()
		end
	end
	for i = 1, 2 do
		self.eyeGlint[i]:Stop()
		if full and flashStyle == "pulse" then
			if not self.eyeBurn[i]:IsPlaying() then self.eyeBurn[i]:Play() end
		else
			self.eyeBurn[i]:Stop()
			self.eye[i]:SetAlpha(EYE_OWED)
		end
	end
	-- No eyes to burn under the painting.
	if Looks.Painted.On(self) then
		for i = 1, 2 do self.eyeBurn[i]:Stop() end
	end
	-- A favour just done: the gilt catches the light, once.
	if arrived and full then self:Catch(CATCH_FAVOUR) end
end

function Glass:StopAttention()
	if not self.kit then return end
	self.owed = nil
	self.antsShow:Stop()
	self.breath:Stop()
	for i = 1, 4 do self.antFlow[i]:Stop() end
	self.antsFrame:SetAlpha(0)
	self.antsFrame:Hide()
	for i = 1, 2 do self.eyeBurn[i]:Stop() end
	if self.active then self:Rest() end
end

-- The gilt of both gryphons lit to `peak` and let go.
function Glass:Catch(peak)
	for i, g in ipairs(self.catch) do
		g:Stop()
		g.up:SetToAlpha(peak)
		g.down:SetFromAlpha(peak)
		g:Play()
	end
end

function Glass:Flourish(kind)
	if self.combat or not self.active then return end
	if kind ~= "cast" then return end
	self:Catch(CATCH_LAND)
	if self.showIcon then Replay(self.wink) end
end

function Glass:StopFlourishes()
	if not self.kit then return end
	for _, g in ipairs(self.catch) do g:Stop() end
	self.wink:Stop()
end

-- The fight holds the panel: the lights out, the gilt dimmed.
function Glass:Combat(on)
	on = on and true or false
	if (self.combat or false) == on or not self.kit then return end
	self.combat = on or nil
	if on then
		self:StopAttention()
		self:StopFlourishes()
	end
	if self.active then
		self:Gilt()
		self:Rest()
	end
end
