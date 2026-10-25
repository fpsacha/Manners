-- Manners -- the prompt's panel: its regions built once, and styled for the
-- player's settings -- the three looks drawn here (glass, framed, minimal), or
-- handed to a look from Looks/.

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local InCombatLockdown = _G.InCombatLockdown
local LSM, WHITE, OUTCOME_SECONDS = lib.LSM, lib.WHITE, lib.OUTCOME_SECONDS
local Gradient, Solid, Try, unpackColor = lib.Gradient, lib.Solid, lib.Try, lib.unpackColor
local Halo, PlaceHalo, PaintHalo, ReasonColor = lib.Halo, lib.PlaceHalo, lib.PaintHalo, lib.ReasonColor
local ink, fit, GREYS, EDGE_ROOM, TEXT_CONTRAST = lib.ink, lib.fit, lib.GREYS, lib.EDGE_ROOM, lib.TEXT_CONTRAST
local Legible, TextWidth, SetLine, FitLine = lib.Legible, lib.TextWidth, lib.SetLine, lib.FitLine
local StyleText, FullEffects, BUTTON_SCRIPTS = lib.StyleText, lib.FullEffects, lib.BUTTON_SCRIPTS
local RING, RING_SQ, SWEEP, GLOSS, BEVEL = lib.RING, lib.RING_SQ, lib.SWEEP, lib.GLOSS, lib.BEVEL
local Tint, WARM_WHITE = lib.Tint, lib.WARM_WHITE
-- The client's own round mask: the shape of a round icon, its sweep and the
-- icon's echo.
local PORTRAIT_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
-- The glass's inner bevel is a nine-slice of Textures/Bevel.tga: 6 of its 32
-- texels at each corner, drawn 3 units square.
local BEVEL_MARGIN, BEVEL_SIZE, BEVEL_CORNER = 6, 32, 3
-- The glass's reflection, at the panel's own opacity: Textures/Gloss.tga is
-- brightest at its top left, and this is that brightness.
local GLOSS_ALPHA = 0.13
-- Where the icon sits and how far the text starts from it, in units.
local ICON_X, ICON_GAP = 10, 10

-- Nine textures cut from one file, as the looks' own slices are.
local function BevelSlice(parent, layer, sublevel)
	local s = {}
	local u = BEVEL_MARGIN / BEVEL_SIZE
	local cuts = { 0, u, 1 - u, 1 }
	for row = 1, 3 do
		for col = 1, 3 do
			local t = parent:CreateTexture(nil, layer, nil, sublevel)
			t:SetTexture(BEVEL)
			t:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
			s[#s + 1] = t
		end
	end
	return s
end

local function PlaceBevel(s, box)
	local c = BEVEL_CORNER
	for _, t in ipairs(s) do t:ClearAllPoints() end
	s[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	s[1]:SetSize(c, c)
	s[2]:SetPoint("TOPLEFT", box, "TOPLEFT", c, 0)
	s[2]:SetPoint("TOPRIGHT", box, "TOPRIGHT", -c, 0)
	s[2]:SetHeight(c)
	s[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
	s[3]:SetSize(c, c)
	s[4]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -c)
	s[4]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, c)
	s[4]:SetWidth(c)
	s[5]:SetPoint("TOPLEFT", box, "TOPLEFT", c, -c)
	s[5]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -c, c)
	s[6]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -c)
	s[6]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, c)
	s[6]:SetWidth(c)
	s[7]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	s[7]:SetSize(c, c)
	s[8]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", c, 0)
	s[8]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -c, 0)
	s[8]:SetHeight(c)
	s[9]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	s[9]:SetSize(c, c)
end

-- The drop shadow: steps of falloff from a crisp dark rim out to almost
-- nothing, each a little lower, so the light reads as coming from above.
local SHADOW_STEPS = {
	-- spread, alpha, drop
	{ 1, 0.50, 0 },
	{ 3, 0.16, 1 },
	{ 6, 0.09, 2 },
	{ 10, 0.05, 3 },
}

-- Below the panel normally, above it when the prompt sits in the bottom third
-- of the screen. Every call is guarded (an unplaced frame has no centre), and
-- the centre is converted from the prompt's scaled units to UIParent's.
local function QueueGoesAbove()
	local okCentre, _, y = pcall(R.button.GetCenter, R.button)
	if not okCentre or type(y) ~= "number" then return false end
	local okHeight, screenHeight = pcall(UIParent.GetHeight, UIParent)
	if not okHeight or type(screenHeight) ~= "number" or screenHeight <= 0 then return false end
	local ratio = ns.db.profile.prompt.scale
	local okOwn, own = pcall(R.button.GetEffectiveScale, R.button)
	local okParent, parent = pcall(UIParent.GetEffectiveScale, UIParent)
	if okOwn and okParent and type(own) == "number" and type(parent) == "number"
		and parent > 0 then
		ratio = own / parent
	end
	if type(ratio) ~= "number" or ratio <= 0 then ratio = 1 end
	return y * ratio < screenHeight / 3
end

function Prompt:Create()
	if R.button then return end

	R.button = CreateFrame("Button", "MannersPrompt", UIParent, "SecureActionButtonTemplate")
	R.button:SetFrameStrata("MEDIUM")
	-- Copied from the secure buttons that work on this client (MountActions,
	-- GroupTools): "AnyDown" with pressAndHoldAction. Registering down without
	-- pressAndHoldAction delivers the click and casts nothing.
	-- Kept on R as well: the client has no call that reads it back, and
	-- /manners selftest reports what the button was registered for.
	R.clicks = "AnyDown"
	R.button:RegisterForClicks(R.clicks)
	R.button:SetAttribute("pressAndHoldAction", true)
	R.button:SetMovable(true)
	R.button:SetClampedToScreen(true)
	R.button:RegisterForDrag("LeftButton")

	R.art = CreateFrame("Frame", nil, R.button)
	R.art:SetAllPoints()

	-- Stacked black rectangles stand in for a soft drop shadow: four steps of
	-- falloff, each a pixel lower, with a crisp dark rim innermost to keep the
	-- edge clean over a bright floor.
	R.shadows = {}
	for i, step in ipairs(SHADOW_STEPS) do
		local spread, alpha, drop = step[1], step[2], step[3]
		-- Outermost first, so it sits underneath; sublevels -8 to -7 are all
		-- the layer has below the panel, and two share one where they must.
		local t = Solid(R.art, "BACKGROUND", i <= 2 and -7 or -8)
		t:SetPoint("TOPLEFT", -spread, spread - drop)
		t:SetPoint("BOTTOMRIGHT", spread, -spread - drop)
		t:SetVertexColor(0, 0, 0, alpha)
		R.shadows[i] = t
	end

	R.panel = Solid(R.art, "BACKGROUND", -6)
	R.panel:SetAllPoints()

	-- Light falling on the top half of the glass. The panel's own gradient
	-- darkens towards the bottom; this is the other half of the same idea.
	R.sheen = Solid(R.art, "BORDER", 0)
	R.sheen:SetTexture(GLOSS)
	R.sheen:SetPoint("TOPLEFT")
	R.sheen:SetPoint("TOPRIGHT")

	-- A hairline of light along the top and shade along the bottom: the
	-- cheapest bevel.
	R.hairTop = Solid(R.art, "BORDER", 1)
	R.hairTop:SetHeight(1)
	R.hairTop:SetPoint("TOPLEFT")
	R.hairTop:SetPoint("TOPRIGHT")

	R.hairBottom = Solid(R.art, "BORDER", 1)
	R.hairBottom:SetHeight(1)
	R.hairBottom:SetPoint("BOTTOMLEFT")
	R.hairBottom:SetPoint("BOTTOMRIGHT")
	R.hairBottom:SetVertexColor(0, 0, 0, 0.55)

	-- The glass's inner bevel: a lit line along the top and down the sides, a
	-- shade along the bottom, each softening inward. Over the hairlines and
	-- under the framed look's border, which it never shares a look with.
	R.bevel = BevelSlice(R.art, "BORDER", 2)
	PlaceBevel(R.bevel, R.art)
	for _, t in ipairs(R.bevel) do t:Hide() end

	-- A line all the way round, for the framed look. Above the bevel and the
	-- stripe, which it replaces. Anchored corner to corner, so it follows a
	-- resize without ApplyStyle measuring it. Four rectangles of the white
	-- texture, because a backdrop needs BackdropTemplate and a border needs art
	-- or an atlas, either of which this client may lack.
	R.edges = {}
	for _, at in ipairs({
		{ "TOPLEFT", "TOPRIGHT", height = 1 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", height = 1 },
		{ "TOPLEFT", "BOTTOMLEFT", width = 1 },
		{ "TOPRIGHT", "BOTTOMRIGHT", width = 1 },
	}) do
		local edge = Solid(R.art, "BORDER", 3)
		if at.height then edge:SetHeight(at.height) else edge:SetWidth(at.width) end
		edge:SetPoint(at[1])
		edge:SetPoint(at[2])
		edge:Hide()
		R.edges[#R.edges + 1] = edge
	end

	-- The accent stripe is two textures so it can fade out towards both ends
	-- instead of stopping dead. A gradient only has two stops.
	R.accentTop = Solid(R.art, "BORDER", 2)
	R.accentTop:SetWidth(3)
	R.accentTop:SetPoint("TOPLEFT")
	R.accentBottom = Solid(R.art, "BORDER", 2)
	R.accentBottom:SetWidth(3)
	R.accentBottom:SetPoint("BOTTOMLEFT")

	-- Only frames can own an animation group, so anything that moves or fades
	-- on its own gets a frame of its own to be animated through.
	R.sweepFrame = CreateFrame("Frame", nil, R.art)
	R.sweepFrame:SetWidth(3)
	R.sweepFrame:SetHeight(14)
	R.sweepFrame:SetPoint("TOPLEFT")
	R.sweepFrame:SetAlpha(0)
	R.sweep = Solid(R.sweepFrame, "ARTWORK", 3)
	R.sweep:SetAllPoints()
	R.sweep:SetBlendMode("ADD")

	-- A halo round the icon, starting at the ring so the icon stays readable at
	-- every point of the pulse, on a frame of its own: a child frame draws over
	-- its parent. Sized to the icon itself; the halo is drawn outside it.
	R.glowFrame = CreateFrame("Frame", nil, R.art)
	R.glowFrame:SetAlpha(0)
	R.glowHalo = Halo(R.glowFrame, "BACKGROUND", -3)

	-- And a tight rim of warm white hugging the ring, on its own frame so it
	-- breathes with the glow: the reason's colour outside, light inside.
	R.rimFrame = CreateFrame("Frame", nil, R.art)
	R.rimFrame:SetAlpha(0)
	R.rimHalo = Halo(R.rimFrame, "BACKGROUND", -2)

	-- Doubles as the icon's border and the reason signal: a ring round the icon
	-- reads better than a stripe at the panel's edge.
	R.iconBack = Solid(R.art, "BACKGROUND", -2)
	R.iconBack:SetVertexColor(0, 0, 0, 0.85)
	-- A dark line between the icon and its ring, and a shade over the icon's
	-- lower half, so the ring reads as a frame rather than a flat square.
	R.iconEdge =Solid(R.art, "BACKGROUND", -1)
	R.iconEdge:SetVertexColor(0, 0, 0, 0.9)

	R.icon = R.art:CreateTexture(nil, "ARTWORK")
	R.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	R.iconShade = Solid(R.art, "ARTWORK", 1)

	-- The global cooldown swept over the icon. A Cooldown frame is not
	-- protected and animates itself; made in a pcall, as the template is not
	-- ours.
	local okCooldown, made = pcall(CreateFrame, "Cooldown", nil, R.art, "CooldownFrameTemplate")
	if okCooldown and made then
		R.cooldown = made
		-- A thin line of light on the sweep's leading edge, where the client
		-- draws one (the colour of it is the newest clients' to set).
		Try(R.cooldown, "SetDrawEdge", true)
		Try(R.cooldown, "SetDrawBling", false)
		Try(R.cooldown, "SetHideCountdownNumbers", true)
		Try(R.cooldown, "SetSwipeColor", 0, 0, 0, 0.62)
		if R.cooldown.SetEdgeColor then R.cooldown:SetEdgeColor(1, 0.95, 0.80, 0.95) end
		R.cooldown:Hide()
	end

	-- The halo that flares when a favour arrives, a buff lands or one is
	-- refused. Its own frame so it can grow; drawn from the same strips as the
	-- glow, bright at the inside edge.
	R.burstFrame = CreateFrame("Frame", nil, R.art)
	R.burstFrame:SetAlpha(0)
	R.burstHalo = Halo(R.burstFrame, "OVERLAY", 2)

	-- The rings that spread from the icon when a buff lands, the one that
	-- snaps in when a refusal comes, and the icon's echo as a favour arrives
	-- (Prompt/Effects.lua; the looks make their own from the same builder).
	R.fx = lib.NewFX(R.art)

	-- A band of light that crosses the panel once: a tail that gathers and a
	-- thin bright leading edge, from Textures/Sweep.tga.
	R.shineFrame = CreateFrame("Frame", nil, R.art)
	R.shineFrame:SetAlpha(0)
	R.shineBand = R.shineFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	R.shineBand:SetTexture(SWEEP)
	R.shineBand:SetBlendMode("ADD")
	R.shineBand:SetAllPoints(R.shineFrame)

	-- Text sits on its own frame so a target change can cross-fade all of it
	-- at once rather than swapping strings mid-read.
	R.textLayer = CreateFrame("Frame", nil, R.art)
	R.textLayer:SetAllPoints()
	-- Over every frame of light, by level and not by the order they were made
	-- in: the rings, the halo and the band across the panel pass under the
	-- letters.
	R.textLayer:SetFrameLevel(R.art:GetFrameLevel() + lib.TEXT_LEVEL)

	R.nameText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.nameText:SetJustifyH("LEFT")
	R.nameText:SetWordWrap(false)
	R.nameText:SetShadowColor(0, 0, 0, 0.9)
	R.nameText:SetShadowOffset(1, -1)

	R.subText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.subText:SetJustifyH("LEFT")
	R.subText:SetWordWrap(false)
	R.subText:SetShadowColor(0, 0, 0, 0.8)
	R.subText:SetShadowOffset(1, -1)

	R.countChip = Solid(R.art, "ARTWORK", 1)
	R.countText = R.textLayer:CreateFontString(nil, "OVERLAY")
	R.countText:SetJustifyH("CENTER")

	-- A flood of colour over the whole panel for the half-second after a click:
	-- the panel is where the eye already is. Above every other art layer and
	-- below textLayer (a frame, so drawn over all of them): the wash reads as
	-- light on the panel, not a box over the name.
	R.resultFill = Solid(R.art, "ARTWORK", 2)
	R.resultFill:SetAllPoints()
	R.resultFill:Hide()

	-- The highlight layer only reacts to the mouse on a Button, so it belongs
	-- to the button itself rather than to the art frame.
	R.button:SetHighlightTexture(WHITE, "ADD")
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	-- The list of who is next hangs outside the panel, so it gets a background
	-- of its own -- the panel's at a lower alpha, divided by a hairline -- or
	-- the rows are text lying on the world.
	R.queueBack = Solid(R.art, "BACKGROUND", -6)
	R.queueBack:Hide()
	R.queueHair = Solid(R.art, "BORDER", 1)
	R.queueHair:Hide()

	R.queueRows = {}
	R.queueBars = {}
	R.queueIcons = {}
	for i = 1, 5 do
		local fs = R.art:CreateFontString(nil, "OVERLAY")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetShadowColor(0, 0, 0, 0.9)
		fs:SetShadowOffset(1, -1)
		R.queueRows[i] = fs
		-- Three pixels of the reason colour before each row: priority is the
		-- one thing about the list worth knowing at a glance.
		local bar = Solid(R.art, "ARTWORK", 1)
		bar:Hide()
		R.queueBars[i] = bar
		-- The icon of the buff the row offers, between the bar and the name.
		local icon = R.art:CreateTexture(nil, "ARTWORK")
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:Hide()
		R.queueIcons[i] = icon
	end
	-- And each name as a button of its own, to press (Rows.lua).
	self:CreateRows()

	self:BuildAnimations()

	-- Everything only the three looks drawn here use, which a look from
	-- Looks/ hides (ApplyLook) and ApplyStyle puts back.
	local parts = { R.panel, R.sheen, R.hairTop, R.hairBottom, R.accentTop, R.accentBottom, R.sweepFrame,
		R.glowFrame, R.rimFrame, R.iconBack, R.iconEdge, R.iconShade, R.burstFrame, R.shineFrame, R.countChip,
		R.resultFill, R.queueBack, R.queueHair }
	for _, list in ipairs({ R.shadows, R.edges, R.queueBars, R.queueIcons, R.bevel, R.fx.frames }) do
		for _, part in ipairs(list) do parts[#parts + 1] = part end
	end
	self.builtinParts = parts

	for _, script in ipairs(BUTTON_SCRIPTS) do
		R.button:SetScript(script[1], script[2])
	end

	R.button:Hide()
end

function Prompt:AccentColor(reason)
	local p = ns.db.profile.prompt
	if not p.accentByReason then return unpackColor(p.accentColor, { 0.45, 0.4, 0.9, 1 }) end
	local c = ReasonColor(reason)
	return c[1], c[2], c[3], 1
end

function Prompt:ApplyStyle()
	if not R.button then return end
	if InCombatLockdown() then
		self.pendingStyle = true
		return
	end
	self.pendingStyle = nil

	local p = ns.db.profile.prompt
	local style = p.style or "glass"
	local glass = style == "glass"
	-- A look from Looks/, or nil for the three drawn here. The one it replaces
	-- takes down everything it drew and gives back what it borrowed.
	local look = ns.Looks.Get(style)
	if S.activeLook and S.activeLook ~= look then S.activeLook:Hide() end
	S.activeLook = look

	R.button:SetSize(p.width, p.height)
	R.button:SetScale(p.scale)
	R.button:SetAlpha(p.alpha)
	R.button:ClearAllPoints()
	-- Stored offsets are in UIParent's units and SetPoint reads the frame's own
	-- scaled ones, so they are divided by the scale. FinishDrag converts back.
	R.button:SetPoint(p.point, UIParent, p.relPoint, p.x / p.scale, p.y / p.scale)
	if look then return self:ApplyLook(p, look) end

	-- Put back what a look of its own hid: the three frames of light, and the
	-- button's square highlight, which it draws rounded itself.
	R.glowFrame:Show()
	R.rimFrame:Show()
	R.burstFrame:Show()
	R.shineFrame:Show()
	R.fx:SetShown(true)
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })

	-- panel
	if style == "minimal" then
		R.panel:Hide()
		for _, t in ipairs(R.shadows) do t:Hide() end
		R.sheen:Hide()
		R.hairTop:Hide()
		R.hairBottom:Hide()
		for _, t in ipairs(R.bevel) do t:Hide() end
	else
		R.panel:Show()
		-- The framed look keeps its flat panel and its border, and gets only
		-- the dark rim of the shadow under it: the rest is the glass's depth.
		for i, t in ipairs(R.shadows) do t:SetShown(glass or i == 1) end
		-- Vertical gradients run bottom-to-top, so the darker stop goes first.
		Gradient(R.panel, "VERTICAL", br * 0.62, bg * 0.62, bb * 0.72, ba, br, bg, bb, ba)
		-- Scaled by the panel's own opacity, so a panel the player has made
		-- mostly see-through does not keep a bright band floating on its own.
		R.sheen:SetShown(glass)
		R.sheen:SetHeight(math.max(4, math.floor(p.height * 0.5)))
		R.sheen:SetVertexColor(1, 1, 1, GLOSS_ALPHA * ba)
		R.hairTop:SetShown(glass)
		R.hairTop:SetVertexColor(1, 1, 1, 0.12)
		R.hairBottom:SetShown(glass)
		-- The bevel's light and shade are in the file; the panel's own opacity
		-- scales them, as it does the sheen.
		for _, t in ipairs(R.bevel) do
			t:SetShown(glass)
			t:SetVertexColor(1, 1, 1, ba)
		end
	end

	-- The border, on the framed look only: pushed away from the panel colour --
	-- lighter for a dark panel, darker for a light one -- so it shows on any.
	local framed = style == "framed"
	-- Rec. 601 weights: green carries most apparent brightness, so a flat
	-- average calls a saturated blue panel mid-grey.
	local lighten = (0.299 * br + 0.587 * bg + 0.114 * bb) <= 0.5
	local function edgeOf(c, amount)
		if lighten then return c + (1 - c) * amount end
		return c * (1 - amount)
	end
	-- Blue goes a little further towards light and less towards dark, so the
	-- edge lands slightly cooler than the panel either way: a dead-neutral
	-- border on a tinted panel reads as grey dirt.
	local er, eg, eb = edgeOf(br, 0.50), edgeOf(bg, 0.50),
		edgeOf(bb, lighten and 0.55 or 0.45)
	for _, edge in ipairs(R.edges) do
		edge:SetShown(framed)
		edge:SetVertexColor(er, eg, eb, math.min(1, ba + 0.10))
	end

	local mode = p.accentMode or "icon"
	-- Not on the framed look: the stripe would run a pixel inside the left edge
	-- and read as a drawing mistake. The ring still carries the colour.
	local showAccent = not framed and (mode == "stripe" or mode == "both")
	R.accentTop:SetShown(showAccent)
	R.accentBottom:SetShown(showAccent)
	R.accentTop:SetHeight(p.height / 2)
	R.accentBottom:SetHeight(p.height / 2)
	R.sweepFrame:SetShown(showAccent)

	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT

	-- icon
	local textX = 10
	R.icon:ClearAllPoints()
	R.iconBack:ClearAllPoints()
	R.glowFrame:ClearAllPoints()
	R.rimFrame:ClearAllPoints()
	if p.showIcon then
		R.icon:SetSize(p.iconSize, p.iconSize)
		R.icon:SetPoint("LEFT", ICON_X, 0)
		R.icon:Show()

		-- The coloured ring, and a pixel of dark between it and the art.
		local ring = (p.accentMode == "icon" or p.accentMode == "both") and 2 or 1
		local outer = ring + 1
		R.iconBack:SetPoint("TOPLEFT", R.icon, "TOPLEFT", -outer, outer)
		R.iconBack:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT", outer, -outer)
		R.iconBack:Show()
		R.iconEdge:ClearAllPoints()
		R.iconEdge:SetPoint("TOPLEFT", R.icon, "TOPLEFT", -1, 1)
		R.iconEdge:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT", 1, -1)
		R.iconEdge:Show()
		-- Darkest at the bottom edge and gone by the middle: the icon reads as
		-- set into the panel rather than printed on it.
		R.iconShade:ClearAllPoints()
		R.iconShade:SetPoint("BOTTOMLEFT", R.icon, "BOTTOMLEFT")
		R.iconShade:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		R.iconShade:SetHeight(math.max(2, math.floor(p.iconSize * 0.55)))
		Gradient(R.iconShade, "VERTICAL", 0, 0, 0, 0.38, 0, 0, 0, 0)
		R.iconShade:Show()

		if R.cooldown then
			R.cooldown:ClearAllPoints()
			R.cooldown:SetAllPoints(R.icon)
		end

		-- A circular icon is available where masks are, but it reads as a
		-- portrait rather than a spell, so it stays opt-in.
		local round = false
		if p.roundIcon and R.art.CreateMaskTexture and R.icon.AddMaskTexture then
			if not R.iconMask then
				local ok, mask = pcall(R.art.CreateMaskTexture, R.art)
				if ok and mask then
					mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
						"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					R.iconMask = mask
					pcall(R.icon.AddMaskTexture, R.icon, mask)
				end
			end
			if R.iconMask then
				R.iconMask:ClearAllPoints()
				R.iconMask:SetAllPoints(R.icon)
				R.iconMask:Show()
				R.iconBack:Hide()
				-- Square pieces under and over a round icon would poke out
				-- at its corners.
				R.iconEdge:Hide()
				R.iconShade:Hide()
				-- The mask art doubles as the swipe texture, as the client's
				-- own round buttons do.
				if R.cooldown then
					Try(R.cooldown, "SetSwipeTexture", "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
				end
				round = true
			end
		else
			if R.iconMask then R.iconMask:Hide() end
			if R.cooldown then Try(R.cooldown, "SetSwipeTexture", WHITE) end
		end

		-- The halo starts where the ring stops and ends at the panel's edge
		-- (past it, light read as bars stuck to the prompt), reaching further
		-- sideways where there is more room. A round icon wears the ring
		-- instead.
		-- Where the room runs out, so does the light: the distance from the
		-- icon's middle to the text (less a margin), to the panel's left edge
		-- and to its top and bottom edges (less a margin) is what the rings,
		-- the echo and the halo that flares are held inside (Effects.lua).
		local half = p.iconSize / 2
		local limitH = half + math.min(ICON_GAP - lib.TEXT_MARGIN, ICON_X - lib.EDGE_MARGIN)
		local limitV = p.height / 2 - lib.EDGE_MARGIN
		local limit = math.min(limitH, limitV)
		local sy = math.max(0, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer))
		local sx = math.max(2, math.min(8, 10 - outer))
		local roundSize = round and p.iconSize or nil
		R.glowFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.glowFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		PlaceHalo(R.glowHalo, R.glowFrame, sx, sy, outer, roundSize)
		R.burstFrame:ClearAllPoints()
		R.burstFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.burstFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		local deep = self:FitBurst(limit, half, outer, round and p.iconSize / lib.GLOW_RING_AT / 2 or nil)
		PlaceHalo(R.burstHalo, R.burstFrame, deep, deep, outer, roundSize)
		-- The rim of warm white hugs the ring, a few units deep.
		R.rimFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.rimFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		local rim = math.max(0, math.min(3, limit - half - outer))
		PlaceHalo(R.rimHalo, R.rimFrame, rim, rim, outer, roundSize)
		PaintHalo(R.rimHalo, WARM_WHITE[1], WARM_WHITE[2], WARM_WHITE[3], 1)
		-- The rings spread from just outside the ring, in the shape of the
		-- icon, and the icon's echo wears the same shape.
		R.fx:Place(R.icon, R.fx.ThinPad(p.iconSize, outer + 1), p.iconSize)
		R.fx:Shape(round, RING, RING_SQ, round and PORTRAIT_MASK or nil)
		R.fx:Fit(limitH, limitV, lib.SHAKE_LEFT)
		-- A round sweep keeps its leading edge round.
		if R.cooldown and R.cooldown.SetUseCircularEdge then R.cooldown:SetUseCircularEdge(round) end

		textX = ICON_X + p.iconSize + ICON_GAP
	else
		R.icon:Hide()
		R.iconBack:Hide()
		R.iconEdge:Hide()
		R.iconShade:Hide()
		if R.iconMask then R.iconMask:Hide() end
	end
	-- Whether there is an icon to sweep, and a cooldown running to sweep it
	-- with, is SyncCooldown's to decide; the settings behind both just changed.
	self:SyncCooldown()

	-- The band of light is about a quarter of the panel wide and crosses all of
	-- it, so the distance it travels is the width less its own.
	local shineWidth = math.max(24, math.min(72, math.floor(p.width * 0.26)))
	R.shineFrame:ClearAllPoints()
	R.shineFrame:SetPoint("LEFT", R.art, "LEFT", 0, 0)
	R.shineFrame:SetSize(shineWidth, p.height)
	if R.shineFrame.anim then R.shineFrame.anim.move:SetOffset(p.width - shineWidth, 0) end

	-- count chip: sized from the font, so large fonts do not spill out of it;
	-- at the default 13 it is the old 20 by 14, with 28 reserved.
	local countSize = math.max(8, p.fontSize - 3)
	-- A digit is about half the font's size across: room for four.
	local chipWidth = countSize * 2
	-- Kept inside the panel at the top of the slider, where a chip grown from
	-- the font would otherwise stand taller than the prompt it is drawn on.
	local chipHeight = math.min(countSize + 4, math.max(8, p.height - 6))
	R.countChip:ClearAllPoints()
	R.countChip:SetPoint("RIGHT", -7, 0)
	R.countChip:SetSize(chipWidth, chipHeight)
	R.countChip:SetShown(false)
	Gradient(R.countChip, "VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0.09)

	-- What the lines keep clear while the chip is up: the chip, its 7px inset
	-- and a point of gap.
	local chipRoom = p.showCount and (chipWidth + 8) or EDGE_ROOM

	-- text
	-- Two lines need both fonts plus the insets: see ns.TwoLineHeight.
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize)

	R.countText:ClearAllPoints()
	R.countText:SetPoint("CENTER", R.countChip, "CENTER", 0, 0)
	-- Fonts, colours, shadows and the lines' anchors, from the panel colour.
	-- The count's font is the size the chip was just sized from.
	StyleText(p, style, fontPath, textX, chipRoom, twoLine, countSize)
	-- The grey just written over the reason line's tint, and the ring and the
	-- stripe may have changed shape: the next PaintAccent paints in full.
	S.accentPainted = nil

	-- Rows get one anchor and an explicit width: TOPLEFT and RIGHT together
	-- fight over the vertical centre. Which way the list hangs is settled here.
	S.queueAbove = QueueGoesAbove()
	-- With the spell icon on, each row wears the icon of its own buff, sized
	-- from the row's font, in the margin left of its text, under the prompt's
	-- own icon: the text keeps the whole width it had, which a long name and
	-- its reason need (pushed right by the icon, one was drawn cut).
	local iconW = p.showIcon and (math.max(7, p.fontSize - 3) + 2) or 0
	-- No wider than that margin holds with the bar beside it (a small prompt
	-- icon under a large font), and none where too little is left.
	if iconW > textX - 12 then iconW = textX - 12 end
	if iconW < 7 then iconW = 0 end
	local rowX = textX
	-- Kept for PaintQueue, which re-places the rows when the list hangs above
	-- and therefore needs the same inset this loop uses.
	S.queueTextX = rowX
	local rowHeight = p.fontSize + 4
	local rowCount = math.max(1, p.queueRows or 1)
	for i, fs in ipairs(R.queueRows) do
		fs:ClearAllPoints()
		if S.queueAbove then
			-- Counted down from the top of the block, so the list reads top to
			-- bottom.
			fs:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", rowX, 4 + (rowCount - i) * rowHeight)
		else
			fs:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", rowX, -4 - (i - 1) * rowHeight)
		end
		-- The font and the colour are StyleText's; the width is the room
		-- FitLine shrinks a long row into.
		local width = math.max(20, p.width - rowX - 8)
		fs:SetWidth(width)
		fit.room[fs] = width

		-- Anchored to its own row, so the icon and the bar follow the list
		-- whichever way it hangs and whatever the font size is.
		local icon = R.queueIcons[i]
		icon:ClearAllPoints()
		if iconW > 0 then
			icon:SetSize(iconW, iconW)
			icon:SetPoint("RIGHT", fs, "LEFT", -3, 0)
		end
		local bar = R.queueBars[i]
		bar:ClearAllPoints()
		bar:SetSize(3, math.max(6, p.fontSize - 2))
		bar:SetPoint("RIGHT", iconW > 0 and icon or fs, "LEFT", -4, 0)
	end
	-- The click area of each name, from the bar to the end of its text.
	self:PlaceRows(p, nil, 7 + (iconW > 0 and iconW + 3 or 0) + 1)

	-- The background behind the list; PaintQueue sets its depth from the rows
	-- filled.
	R.queueBack:ClearAllPoints()
	R.queueHair:ClearAllPoints()
	R.queueHair:SetHeight(1)
	if S.queueAbove then
		R.queueBack:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", 0, 0)
		R.queueBack:SetPoint("BOTTOMRIGHT", R.art, "TOPRIGHT", 0, 0)
		R.queueHair:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", 0, 0)
		R.queueHair:SetPoint("BOTTOMRIGHT", R.art, "TOPRIGHT", 0, 0)
	else
		R.queueBack:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", 0, 0)
		R.queueBack:SetPoint("TOPRIGHT", R.art, "BOTTOMRIGHT", 0, 0)
		R.queueHair:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", 0, 0)
		R.queueHair:SetPoint("TOPRIGHT", R.art, "BOTTOMRIGHT", 0, 0)
	end
	-- A shade darker than the panel and slightly more transparent, with a
	-- hairline of light so the two rectangles do not read as one. Only a shade
	-- on a light panel, where halving went to a mud neither text colour reads
	-- on.
	local shade = ink.light and 0.55 or 0.90
	R.queueBack:SetVertexColor(br * shade, bg * shade, bb * (ink.light and 0.66 or 0.92),
		math.min(1, ba * 0.9))
	R.queueHair:SetVertexColor(1, 1, 1, 0.07)

	self:Refresh()
end

-- ApplyStyle for a look from Looks/: the regions only the three looks here
-- use hidden, the shared ones handed over, the text styled as for any panel.
-- Out of ApplyStyle, for its upvalues.
function Prompt:ApplyLook(p, look)
	if not look.kit then look:Build(self:LookKit()) end
	-- The built-in looks' animations stopped, not only hidden: a pulse left
	-- looping on a hidden frame still loops, Calm or not.
	for _, f in ipairs({ R.glowFrame, R.rimFrame, R.sweepFrame, R.shineFrame, R.burstFrame }) do
		if f.pulse then f.pulse:Stop() end
		if f.anim then f.anim:Stop() end
		if f.arrive then f.arrive:Stop() end
		if f.reject then f.reject:Stop() end
	end
	R.fx:Stop()
	for _, part in ipairs(self.builtinParts) do part:Hide() end
	if R.iconMask then R.iconMask:Hide() end
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0) end
	local above = QueueGoesAbove()
	S.queueAbove = above
	local textX, chipRoom = look:Apply(p, above)
	-- The look lays the rows out itself (PaintQueue); each name's click area
	-- hangs off the row's own text.
	self:PlaceRows(p, look)
	local twoLine = p.showSub and p.height >= ns.TwoLineHeight(p.fontSize, p.style)
	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
	StyleText(p, p.style, fontPath, textX, chipRoom or EDGE_ROOM, twoLine, math.max(7, p.fontSize - 3))
	if look.Styled then look:Styled(p, twoLine) end
	S.accentPainted = nil
	self:SyncCooldown()
	self:Refresh()
end

-- What a look is handed to draw with: see Looks/Looks.lua.
function Prompt:LookKit()
	if not self.kit then
		self.kit = {
			button = R.button, art = R.art, textLayer = R.textLayer, icon = R.icon, cooldown = R.cooldown,
			name = R.nameText, sub = R.subText, count = R.countText, rows = R.queueRows,
			fit = fit, ink = ink,
			Gradient = Gradient, Legible = Legible, TextWidth = TextWidth,
			SetLine = SetLine, FitLine = FitLine, FullEffects = FullEffects,
			ReasonColor = ReasonColor, OUTCOME_SECONDS = OUTCOME_SECONDS,
			-- The rings and the glows' tints, which a look draws in its own art.
			FX = lib.NewFX, Tint = Tint, WARM_WHITE = WARM_WHITE,
			-- How far they may spread (Prompt/Effects.lua): the files a look
			-- draws its rings in, the scale at which a texture reaches a
			-- limit, the margins kept from the text and the panel's edges,
			-- how far a refusal's shake swings the text, and the level of
			-- textLayer above art, over every frame of light.
			RingArt = lib.RingArt, CapScale = lib.CapScale, CapLock = lib.CapLock, TEXT_MARGIN = lib.TEXT_MARGIN,
			EDGE_MARGIN = lib.EDGE_MARGIN, SHAKE_LEFT = lib.SHAKE_LEFT, TEXT_LEVEL = lib.TEXT_LEVEL,
		}
	end
	return self.kit
end

function Prompt:PaintAccent(reason)
	local p = ns.db.profile.prompt
	local mode = p.accentMode or "icon"
	local r, g, b = self:AccentColor(reason)

	-- Runs on every repaint and the colour rarely changes, so the same colour
	-- again is nothing to do. ApplyStyle and a refusal's red ring forget the
	-- key when they write over these textures.
	local key = ("%s:%.3f:%.3f:%.3f:%s"):format(mode, r, g, b, tostring(S.tintSub))
	if key == S.accentPainted then return end
	S.accentPainted = key
	if S.activeLook then return S.activeLook:PaintReason(r, g, b, reason, mode) end

	-- Brightest at the middle, fading towards both ends.
	Gradient(R.accentTop, "VERTICAL", r, g, b, 1, r, g, b, 0.15)
	Gradient(R.accentBottom, "VERTICAL", r, g, b, 0.15, r, g, b, 1)
	R.sweep:SetVertexColor(r, g, b, 1)
	PaintHalo(R.glowHalo, r, g, b, 1)

	if mode == "icon" or mode == "both" then
		-- A little brighter at the top of the ring, lit from above, so it reads
		-- as a rim.
		Gradient(R.iconBack, "VERTICAL", r * 0.78, g * 0.78, b * 0.78, 0.95,
			math.min(1, r * 1.12), math.min(1, g * 1.12), math.min(1, b * 1.12), 0.95)
	else
		R.iconBack:SetVertexColor(0, 0, 0, 0.85)
	end

	-- The reason line, warmed a little towards the same colour so the two agree
	-- at a glance -- but not with accents off, nor on a light panel where the
	-- tint costs contrast. The tinted grey is held to the plain one's contrast.
	local mix = (S.tintSub and mode ~= "off") and 0.35 or 0
	local base = ink.sub or GREYS.panel.sub
	local sr, sg, sb = Legible(base[1] + (r - base[1]) * mix, base[2] + (g - base[2]) * mix,
		base[3] + (b - base[3]) * mix, TEXT_CONTRAST)
	R.subText:SetTextColor(sr, sg, sb, 1)
end

-- The pieces of the panel, handed out so tests can read back what the prompt
-- wrote: many failures here have no symptom but how they look.
function Prompt:Regions()
	return {
		art = R.art,
		name = R.nameText,
		sub = R.subText,
		count = R.countText,
		-- The chip beside its number: both are sized from one font, and a chip
		-- smaller than its digits throws nothing.
		chip = R.countChip,
		fill = R.resultFill,
		-- The framed look's four edges.
		edges = R.edges,
		-- The two carriers of the reason colour, each switched off from
		-- elsewhere (the stripe by the framed look, the ring by hiding or
		-- rounding the icon).
		iconBack = R.iconBack,
		accentTop = R.accentTop,
		-- What "When someone buffs you" animates: whether one played is the
		-- only evidence the setting does anything.
		sweep = R.sweepFrame,
		glow = R.glowFrame,
		glowStrips = R.glowHalo and R.glowHalo.strips,
		glowRound = R.glowHalo and R.glowHalo.round,
		burstStrips = R.burstHalo and R.burstHalo.strips,
		burstRound = R.burstHalo and R.burstHalo.round,
		-- The look's effects, for the same reason. The cooldown is nil on a
		-- client without the template.
		cooldown = R.cooldown,
		burst = R.burstFrame,
		shine = R.shineFrame,
		-- The band's own texture, whose vertex colour carries its strength.
		shineBand = R.shineBand,
		-- The warm white rim that breathes with the glow, the rings and the
		-- icon's echo, the settle, Calm's entrance and the glass's bevel.
		rim = R.rimFrame,
		rimStrips = R.rimHalo and R.rimHalo.strips,
		fx = R.fx,
		settle = R.art and R.art.settle,
		introCalm = R.art and R.art.introCalm,
		bevel = R.bevel,
		shake = R.textLayer and R.textLayer.shake,
		intro = R.art and R.art.intro,
		outro = R.art and R.art.outro,
		comeback = R.art and R.art.comeback,
		shadows = R.shadows,
		sheen = R.sheen,
		iconEdge = R.iconEdge,
		iconShade = R.iconShade,
		icon = R.icon,
		queueBack = R.queueBack,
		queueHair = R.queueHair,
		rows = R.queueRows,
		bars = R.queueBars,
		-- The icon at each row's left (the three looks drawn here), and each
		-- name's button: both for tests to read what was drawn and what can be
		-- pressed.
		rowIcons = R.queueIcons,
		rowButtons = R.rowButtons,
		-- The rest of what only the three looks here draw, and the look from
		-- Looks/ in use (nil for those three), whose own regions are its `own`.
		panel = R.panel,
		hairTop = R.hairTop,
		hairBottom = R.hairBottom,
		accentBottom = R.accentBottom,
		builtin = Prompt.builtinParts,
		look = S.activeLook,
		textLayer = R.textLayer,
	}
end
