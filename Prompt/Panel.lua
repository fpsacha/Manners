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
		Try(R.cooldown, "SetDrawEdge", false)
		Try(R.cooldown, "SetDrawBling", false)
		Try(R.cooldown, "SetHideCountdownNumbers", true)
		Try(R.cooldown, "SetSwipeColor", 0, 0, 0, 0.62)
		R.cooldown:Hide()
	end

	-- The ring that pops outward when a buff lands. Its own frame so it can
	-- grow; drawn from the same strips as the glow, bright at the inside edge.
	R.burstFrame = CreateFrame("Frame", nil, R.art)
	R.burstFrame:SetAlpha(0)
	R.burstHalo = Halo(R.burstFrame, "OVERLAY", 2)

	-- A band of light that crosses the panel once. Two halves, each fading
	-- towards its outer edge, so the band has a soft middle and no hard sides.
	R.shineFrame = CreateFrame("Frame", nil, R.art)
	R.shineFrame:SetAlpha(0)
	R.shineLeft = Solid(R.shineFrame, "OVERLAY", 1)
	R.shineLeft:SetBlendMode("ADD")
	R.shineLeft:SetPoint("TOPLEFT")
	R.shineLeft:SetPoint("BOTTOMRIGHT", R.shineFrame, "BOTTOM", 0, 0)
	R.shineRight = Solid(R.shineFrame, "OVERLAY", 1)
	R.shineRight:SetBlendMode("ADD")
	R.shineRight:SetPoint("TOPLEFT", R.shineFrame, "TOP", 0, 0)
	R.shineRight:SetPoint("BOTTOMRIGHT")

	-- Text sits on its own frame so a target change can cross-fade all of it
	-- at once rather than swapping strings mid-read.
	R.textLayer = CreateFrame("Frame", nil, R.art)
	R.textLayer:SetAllPoints()

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
	end

	self:BuildAnimations()

	-- Everything only the three looks drawn here use, which a look from
	-- Looks/ hides (ApplyLook) and ApplyStyle puts back.
	local parts = { R.panel, R.sheen, R.hairTop, R.hairBottom, R.accentTop, R.accentBottom, R.sweepFrame,
		R.glowFrame, R.iconBack, R.iconEdge, R.iconShade, R.burstFrame, R.shineFrame, R.countChip, R.resultFill,
		R.queueBack, R.queueHair }
	for _, list in ipairs({ R.shadows, R.edges, R.queueBars }) do
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
	R.burstFrame:Show()
	R.shineFrame:Show()
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
		Gradient(R.sheen, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.07 * ba)
		R.hairTop:SetShown(glass)
		R.hairTop:SetVertexColor(1, 1, 1, 0.12)
		R.hairBottom:SetShown(glass)
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
	if p.showIcon then
		R.icon:SetSize(p.iconSize, p.iconSize)
		R.icon:SetPoint("LEFT", 10, 0)
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
		local sy = math.max(2, math.min(8, math.floor((p.height - p.iconSize) / 2) - outer))
		local sx = math.max(2, math.min(8, 10 - outer))
		local roundSize = round and p.iconSize or nil
		R.glowFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.glowFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		PlaceHalo(R.glowHalo, R.glowFrame, sx, sy, outer, roundSize)
		R.burstFrame:ClearAllPoints()
		R.burstFrame:SetPoint("TOPLEFT", R.icon, "TOPLEFT")
		R.burstFrame:SetPoint("BOTTOMRIGHT", R.icon, "BOTTOMRIGHT")
		PlaceHalo(R.burstHalo, R.burstFrame, 4, 4, outer, roundSize)

		textX = 10 + p.iconSize + 10
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

	-- The band of light is about a fifth of the panel wide and crosses all of
	-- it, so the distance it travels is the width less its own.
	local shineWidth = math.max(16, math.min(48, math.floor(p.width * 0.18)))
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
	-- Kept for PaintQueue, which re-places the rows when the list hangs above
	-- and therefore needs the same inset this loop uses.
	S.queueTextX = textX
	local rowHeight = p.fontSize + 4
	local rowCount = math.max(1, p.queueRows or 1)
	for i, fs in ipairs(R.queueRows) do
		fs:ClearAllPoints()
		if S.queueAbove then
			-- Counted down from the top of the block, so the list reads top to
			-- bottom.
			fs:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT", textX, 4 + (rowCount - i) * rowHeight)
		else
			fs:SetPoint("TOPLEFT", R.art, "BOTTOMLEFT", textX, -4 - (i - 1) * rowHeight)
		end
		-- The font and the colour are StyleText's; the width is the room
		-- FitLine shrinks a long row into.
		local width = math.max(20, p.width - textX - 8)
		fs:SetWidth(width)
		fit.room[fs] = width

		-- Anchored to its own row, so the bar follows the list whichever way it
		-- hangs and whatever the font size is.
		local bar = R.queueBars[i]
		bar:ClearAllPoints()
		bar:SetSize(3, math.max(6, p.fontSize - 2))
		bar:SetPoint("RIGHT", fs, "LEFT", -4, 0)
	end

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
	for _, f in ipairs({ R.glowFrame, R.sweepFrame, R.shineFrame, R.burstFrame }) do
		if f.pulse then f.pulse:Stop() end
		if f.anim then f.anim:Stop() end
	end
	for _, part in ipairs(self.builtinParts) do part:Hide() end
	if R.iconMask then R.iconMask:Hide() end
	local hl = R.button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0) end
	local above = QueueGoesAbove()
	S.queueAbove = above
	local textX, chipRoom = look:Apply(p, above)
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
