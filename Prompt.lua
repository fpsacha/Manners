-- Manners -- the on-screen prompt.
--
-- The button itself is a SecureActionButtonTemplate: Blizzard owns the click,
-- and SetAttribute, SetSize, SetScale and SetPoint are all protected once
-- combat starts. Every visual instead lives on `art`, an ordinary frame
-- parented to it, so animations never touch protected state.
--
-- Everything is drawn from a single white texture plus gradients, alpha and
-- motion. That is deliberate: a missing atlas or art file renders as a green
-- placeholder, and a solid texture cannot fail. Atlas and mask work is layered
-- on top only after being confirmed present at runtime.

local ADDON, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

local Prompt = {}
ns.Prompt = Prompt

local WHITE = "Interface\\Buttons\\WHITE8X8"

local button, art, textLayer
local shadowOuter, shadowInner, panel, hairTop, hairBottom
local accentTop, accentBottom, sweep, sweepFrame
local iconBack, icon, iconGlow, glowFrame, iconMask
local nameText, subText, countChip, countText, queueRows
-- Goes into every click line. A log that does not say which build produced it
-- can be diagnosed for an hour before anyone notices the game never loaded the
-- file being read.
ns.BUILD = "0.9.3"

local current, testMode, testExpiry, lastTop, appliedKey, lastClickAt, lastPreClickAt

-- Amber for a favour returned, because that is the case worth noticing.
-- The others stay quiet so the prompt does not shout at you constantly.
local REASON_COLOR = {
	owed = { 1.00, 0.78, 0.30 },
	group = { 0.38, 0.68, 1.00 },
	nearby = { 0.52, 0.54, 0.62 },
}

local REASON_KEY = { owed = "reasonOwed", group = "reasonGroup", nearby = "reasonNearby" }

---------------------------------------------------------------------------
-- capability-checked drawing helpers
---------------------------------------------------------------------------

-- SetGradient changed signature between client generations and SetGradientAlpha
-- was removed. Try both, and fall back to a flat colour that always works.
local function Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
	if tex.SetGradient and CreateColor then
		if pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
			return true
		end
	end
	if tex.SetGradientAlpha then
		if pcall(tex.SetGradientAlpha, tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2) then
			return true
		end
	end
	tex:SetVertexColor(r1, g1, b1, a1)
	return false
end

local function Solid(parent, layer, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(WHITE)
	return t
end

local function AtlasExists(name)
	if not C_Texture or not C_Texture.GetAtlasInfo then return false end
	local ok, info = pcall(C_Texture.GetAtlasInfo, name)
	return ok and info ~= nil
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------

function Prompt:Create()
	if button then return end

	button = CreateFrame("Button", "MannersPrompt", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	-- Copied exactly from the secure buttons that do work on this client.
	-- MountActions and GroupTools both use this trio, and one carries the
	-- comment "force the action to trigger on key down regardless of
	-- ActionButtonUseKeyDown":
	--
	--     RegisterForClicks("AnyDown")
	--     type = "macro"
	--     pressAndHoldAction = true
	--
	-- The two settings go together. Registering down while leaving
	-- pressAndHoldAction false leaves the click arriving, the attributes
	-- reading back correctly, and nothing cast -- which is where this was.
	button:RegisterForClicks("AnyDown")
	button:SetAttribute("pressAndHoldAction", true)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:RegisterForDrag("LeftButton")

	art = CreateFrame("Frame", nil, button)
	art:SetAllPoints()

	-- Two offset black rectangles stand in for a soft drop shadow. Real blur
	-- is not available, but two steps of falloff is enough to lift the panel
	-- off the world behind it.
	shadowOuter = Solid(art, "BACKGROUND", -8)
	shadowOuter:SetPoint("TOPLEFT", -5, 5)
	shadowOuter:SetPoint("BOTTOMRIGHT", 5, -5)
	shadowOuter:SetVertexColor(0, 0, 0, 0.18)

	shadowInner = Solid(art, "BACKGROUND", -7)
	shadowInner:SetPoint("TOPLEFT", -2, 2)
	shadowInner:SetPoint("BOTTOMRIGHT", 2, -2)
	shadowInner:SetVertexColor(0, 0, 0, 0.32)

	panel = Solid(art, "BACKGROUND", -6)
	panel:SetAllPoints()

	-- A hairline of light along the top and shade along the bottom. The
	-- cheapest possible bevel, and the thing that stops a flat rectangle
	-- reading as a debug frame.
	hairTop = Solid(art, "BORDER", 1)
	hairTop:SetHeight(1)
	hairTop:SetPoint("TOPLEFT")
	hairTop:SetPoint("TOPRIGHT")

	hairBottom = Solid(art, "BORDER", 1)
	hairBottom:SetHeight(1)
	hairBottom:SetPoint("BOTTOMLEFT")
	hairBottom:SetPoint("BOTTOMRIGHT")
	hairBottom:SetVertexColor(0, 0, 0, 0.55)

	-- The accent stripe is two textures so it can fade out towards both ends
	-- instead of stopping dead. A gradient only has two stops.
	accentTop = Solid(art, "BORDER", 2)
	accentTop:SetWidth(3)
	accentTop:SetPoint("TOPLEFT")
	accentBottom = Solid(art, "BORDER", 2)
	accentBottom:SetWidth(3)
	accentBottom:SetPoint("BOTTOMLEFT")

	-- Only frames can own an animation group, so anything that moves or fades
	-- on its own gets a frame of its own to be animated through.
	sweepFrame = CreateFrame("Frame", nil, art)
	sweepFrame:SetWidth(3)
	sweepFrame:SetHeight(14)
	sweepFrame:SetPoint("TOPLEFT")
	sweepFrame:SetAlpha(0)
	sweep = Solid(sweepFrame, "ARTWORK", 3)
	sweep:SetAllPoints()
	sweep:SetBlendMode("ADD")

	glowFrame = CreateFrame("Frame", nil, art)
	glowFrame:SetAlpha(0)
	iconGlow = Solid(glowFrame, "BACKGROUND", -3)
	iconGlow:SetAllPoints()
	iconGlow:SetBlendMode("ADD")

	-- Doubles as the icon's border and as the reason signal. A ring around the
	-- icon reads far better than a hairline stripe at the panel edge, which
	-- ends up competing with the icon rather than framing it.
	iconBack = Solid(art, "BACKGROUND", -2)
	iconBack:SetVertexColor(0, 0, 0, 0.85)

	icon = art:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Text sits on its own frame so a target change can cross-fade all of it
	-- at once rather than swapping strings mid-read.
	textLayer = CreateFrame("Frame", nil, art)
	textLayer:SetAllPoints()

	nameText = textLayer:CreateFontString(nil, "OVERLAY")
	nameText:SetJustifyH("LEFT")
	nameText:SetWordWrap(false)
	nameText:SetShadowColor(0, 0, 0, 0.9)
	nameText:SetShadowOffset(1, -1)

	subText = textLayer:CreateFontString(nil, "OVERLAY")
	subText:SetJustifyH("LEFT")
	subText:SetWordWrap(false)
	subText:SetShadowColor(0, 0, 0, 0.8)
	subText:SetShadowOffset(1, -1)

	countChip = Solid(art, "ARTWORK", 1)
	countText = textLayer:CreateFontString(nil, "OVERLAY")
	countText:SetJustifyH("CENTER")

	-- The highlight layer only reacts to the mouse on a Button, so it belongs
	-- to the button itself rather than to the art frame.
	button:SetHighlightTexture(WHITE, "ADD")
	local hl = button:GetHighlightTexture()
	if hl then hl:SetVertexColor(1, 1, 1, 0.045) end

	queueRows = {}
	for i = 1, 5 do
		local fs = art:CreateFontString(nil, "OVERLAY")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetShadowColor(0, 0, 0, 0.9)
		fs:SetShadowOffset(1, -1)
		queueRows[i] = fs
	end

	self:BuildAnimations()

	button:SetScript("OnDragStart", function(self)
		if ns.db.profile.prompt.locked or InCombatLockdown() then return end
		self:StartMoving()
	end)

	button:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		local p = ns.db.profile.prompt
		p.point, p.relPoint, p.x, p.y = point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5)

		-- Lock straight after a drag. An unlocked prompt cannot cast, and
		-- leaving it that way looks identical to a working one that simply has
		-- nobody to offer -- so the addon silently does nothing. Unlock again
		-- to nudge it further.
		p.locked = true
		Prompt:ApplyStyle()
		ns.addon:Print("moved and locked.")
	end)

	-- Remember that we tried this person so the queue moves on even if the
	-- cast failed for reasons we cannot see: line of sight, range, immunity.
	-- MountActions does the same thing: PreClick runs before the secure handler
	-- reads the attributes, and out of combat it may still change them. So the
	-- target is re-resolved at the last possible moment, and a nameplate token
	-- that has since been handed to somebody else can never be cast at.
	button:SetScript("PreClick", function()
		if InCombatLockdown() then return end

		-- Down and up both land here; one rebuild per press is enough.
		local now = GetTime()
		if lastPreClickAt and (now - lastPreClickAt) < 0.25 then return end
		lastPreClickAt = now

		-- An unlocked or disabled prompt must not cast, and PreClick is the
		-- last chance to make sure of it: it runs after Refresh has decided
		-- what to show but before the secure handler reads the attributes.
		local db = ns.db and ns.db.profile
		if not db or not db.enabled or not db.prompt.locked or testMode then
			Prompt:ApplyTarget(nil)
			return
		end

		local queue = ns.BuildQueue()
		appliedKey = nil
		Prompt:ApplyTarget(Prompt:PickTop(queue, queue[1]))
	end)

	button:SetScript("PostClick", function(self, _, down)
		-- One press delivers both a down and an up; count and settle once.
		local now = GetTime()
		if lastClickAt and (now - lastClickAt) < 0.25 then return end
		lastClickAt = now

		ns.clicks = (ns.clicks or 0) + 1
		-- Lets the error and cast handlers tell our own outcome apart from
		-- everything else the game is shouting about.
		ns.lastClickTime = now
		-- Only assembled when asked for: /manners clicks. The build stamp stays
		-- because a log that does not say which build produced it can be
		-- diagnosed for an hour before anyone notices the game never loaded
		-- the file being read.
		if ns.db and ns.db.profile.debugClicks then
			ns.addon:Print(("|cffffd100CLICK|r build=%s macro=%s"):format(
				tostring(ns.BUILD),
				tostring(button:GetAttribute("macrotext1") or "nil"):gsub("%s+", " ")))
		end
		if not (current and current.name) then return end
		ns.tried[current.name] = GetTime() + ns.db.profile.timing.retryCooldown
		-- Clicking settles the debt whether or not the cast lands; otherwise a
		-- cast blocked by line of sight leaves them owed forever.
		ns.owed[current.name] = nil
		Prompt:StopAttention()
	end)

	button:SetScript("OnEnter", function(self)
		if not current or not current.buff then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Manners")
		GameTooltip:AddDoubleLine(current.short or current.name, ns.BuffName(current.buff),
			1, 1, 1, 0.8, 0.8, 0.8)
		local why = current.reason == "owed" and "Buffed you -- return the favour."
			or current.reason == "group" and "In your group and missing it."
			or "Nearby and missing it."
		GameTooltip:AddLine(why, 0.7, 0.7, 0.7, true)
		if current.checked and current.known == nil then
			GameTooltip:AddLine("Buff state unreadable on this build -- they may already have it.",
				1, 0.5, 0.5, true)
		elseif not current.checked then
			GameTooltip:AddLine("Not checking whether they have it -- set by your options.",
				0.7, 0.7, 0.7, true)
		end
		GameTooltip:AddLine(" ")
		if ns.lastMacro then
			GameTooltip:AddLine("Will run:", 0.5, 0.5, 0.5)
			for line in ns.lastMacro:gmatch("[^\r\n]+") do
				GameTooltip:AddLine("  " .. line, 0.4, 0.8, 0.4)
			end
			GameTooltip:AddLine(" ")
		end
		GameTooltip:AddLine("Click to cast. |cffffd100/manners|r for options.", 0.5, 0.5, 0.5)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Keep the tooltip honest if the entry changes while it is open.
	-- Checked a few times a second rather than every frame; the target cannot
	-- change faster than the scan interval anyway.
	button:SetScript("OnUpdate", function(self, elapsed)
		self.sinceCheck = (self.sinceCheck or 0) + elapsed
		if self.sinceCheck < 0.2 then return end
		self.sinceCheck = 0
		if not GameTooltip:IsOwned(self) then return end
		if self.tooltipFor ~= (current and current.name) then
			self.tooltipFor = current and current.name
			local onEnter = self:GetScript("OnEnter")
			if onEnter then onEnter(self) end
		end
	end)

	button:Hide()
end

---------------------------------------------------------------------------
-- animation
---------------------------------------------------------------------------

function Prompt:BuildAnimations()
	-- Entrance: rise and fade. Short, eased out, never repeated.
	local intro = art:CreateAnimationGroup()
	local fade = intro:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(0.18)
	local rise = intro:CreateAnimation("Translation")
	rise:SetOffset(0, 6)
	rise:SetDuration(0.18)
	if rise.SetSmoothing then rise:SetSmoothing("OUT") end
	art.intro = intro

	-- Target change: dip the text rather than swapping it under the eye.
	local swap = textLayer:CreateAnimationGroup()
	local out = swap:CreateAnimation("Alpha")
	out:SetFromAlpha(1)
	out:SetToAlpha(0.15)
	out:SetDuration(0.07)
	out:SetOrder(1)
	local back = swap:CreateAnimation("Alpha")
	back:SetFromAlpha(0.15)
	back:SetToAlpha(1)
	back:SetDuration(0.13)
	back:SetOrder(2)
	if back.SetSmoothing then back:SetSmoothing("OUT") end
	textLayer.swap = swap

	-- Favour arrival: the stripe catches the light and the icon warms up.
	local sweepAnim = sweepFrame:CreateAnimationGroup()
	local sIn = sweepAnim:CreateAnimation("Alpha")
	sIn:SetFromAlpha(0)
	sIn:SetToAlpha(0.85)
	sIn:SetDuration(0.10)
	sIn:SetOrder(1)
	local sMove = sweepAnim:CreateAnimation("Translation")
	sMove:SetDuration(0.45)
	sMove:SetOrder(2)
	if sMove.SetSmoothing then sMove:SetSmoothing("IN_OUT") end
	local sOut = sweepAnim:CreateAnimation("Alpha")
	sOut:SetFromAlpha(0.85)
	sOut:SetToAlpha(0)
	sOut:SetDuration(0.45)
	sOut:SetOrder(2)
	sweepAnim.move = sMove
	-- An animation leaves the frame at its final value, so park it back at
	-- invisible or the stripe keeps a bright block stuck to it.
	sweepAnim:SetScript("OnFinished", function() sweepFrame:SetAlpha(0) end)
	sweepAnim:SetScript("OnStop", function() sweepFrame:SetAlpha(0) end)
	sweepFrame.anim = sweepAnim

	local glowAnim = glowFrame:CreateAnimationGroup()
	local gIn = glowAnim:CreateAnimation("Alpha")
	gIn:SetFromAlpha(0)
	gIn:SetToAlpha(0.55)
	gIn:SetDuration(0.12)
	gIn:SetOrder(1)
	local gOut = glowAnim:CreateAnimation("Alpha")
	gOut:SetFromAlpha(0.55)
	gOut:SetToAlpha(0)
	gOut:SetDuration(0.70)
	gOut:SetOrder(2)
	if gOut.SetSmoothing then gOut:SetSmoothing("OUT") end
	glowAnim:SetScript("OnFinished", function() glowFrame:SetAlpha(0) end)
	glowAnim:SetScript("OnStop", function() glowFrame:SetAlpha(0) end)
	glowFrame.anim = glowAnim

	-- A single flash is easy to miss if you were looking elsewhere. This one
	-- keeps breathing for as long as somebody is still owed a buff, and stops
	-- the moment they are not.
	local pulse = glowFrame:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local breathe = pulse:CreateAnimation("Alpha")
	breathe:SetFromAlpha(0.12)
	breathe:SetToAlpha(0.60)
	breathe:SetDuration(0.85)
	if breathe.SetSmoothing then breathe:SetSmoothing("IN_OUT") end
	pulse:SetScript("OnStop", function() glowFrame:SetAlpha(0) end)
	glowFrame.pulse = pulse
end

function Prompt:StopAttention()
	if glowFrame.pulse and glowFrame.pulse:IsPlaying() then glowFrame.pulse:Stop() end
	glowFrame:SetAlpha(0)
end

function Prompt:StartAttention(isNew)
	local p = ns.db.profile.prompt
	local mode = p.flashStyle or "pulse"
	if mode == "off" or not p.showIcon then
		self:StopAttention()
		return
	end

	if isNew and sweepFrame.anim and sweepFrame:IsShown() then
		sweepFrame.anim:Stop()
		sweepFrame.anim.move:SetOffset(0, -(p.height - 14))
		sweepFrame.anim:Play()
	end

	if mode == "pulse" then
		if glowFrame.pulse and not glowFrame.pulse:IsPlaying() then
			if glowFrame.anim then glowFrame.anim:Stop() end
			glowFrame.pulse:Play()
		end
	elseif isNew and glowFrame.anim then
		glowFrame.anim:Stop()
		glowFrame.anim:Play()
	end
end

---------------------------------------------------------------------------
-- styling
---------------------------------------------------------------------------

local function unpackColor(c, fallback)
	c = c or fallback
	return c[1] or 1, c[2] or 1, c[3] or 1, c[4] == nil and 1 or c[4]
end

function Prompt:AccentColor(reason)
	local p = ns.db.profile.prompt
	if not p.accentByReason then return unpackColor(p.accentColor, { 0.45, 0.4, 0.9, 1 }) end
	local c = REASON_COLOR[reason or "nearby"] or REASON_COLOR.nearby
	return c[1], c[2], c[3], 1
end

function Prompt:ApplyStyle()
	if not button then return end
	if InCombatLockdown() then
		self.pendingStyle = true
		return
	end
	self.pendingStyle = nil

	local p = ns.db.profile.prompt
	local style = p.style or "glass"
	local glass = style == "glass"

	button:SetSize(p.width, p.height)
	button:SetScale(p.scale)
	button:SetAlpha(p.alpha)
	button:ClearAllPoints()
	button:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)

	local br, bg, bb, ba = unpackColor(p.bgColor, { 0.04, 0.04, 0.06, 0.88 })

	-- panel
	if style == "minimal" then
		panel:Hide()
		shadowOuter:Hide()
		shadowInner:Hide()
		hairTop:Hide()
		hairBottom:Hide()
	else
		panel:Show()
		shadowOuter:SetShown(glass)
		shadowInner:SetShown(glass)
		-- Vertical gradients run bottom-to-top, so the darker stop goes first.
		Gradient(panel, "VERTICAL", br * 0.62, bg * 0.62, bb * 0.72, ba, br, bg, bb, ba)
		hairTop:SetShown(glass)
		hairTop:SetVertexColor(1, 1, 1, 0.10)
		hairBottom:SetShown(glass)
	end

	local mode = p.accentMode or "icon"
	local showAccent = style ~= "blizzard" and (mode == "stripe" or mode == "both")
	accentTop:SetShown(showAccent)
	accentBottom:SetShown(showAccent)
	accentTop:SetHeight(p.height / 2)
	accentBottom:SetHeight(p.height / 2)
	sweepFrame:SetShown(showAccent)

	local fontPath = LSM:Fetch("font", p.font) or STANDARD_TEXT_FONT
	local outline = style == "minimal" and "OUTLINE" or ""

	-- icon
	local textX = 10
	icon:ClearAllPoints()
	iconBack:ClearAllPoints()
	glowFrame:ClearAllPoints()
	if p.showIcon then
		icon:SetSize(p.iconSize, p.iconSize)
		icon:SetPoint("LEFT", 10, 0)
		icon:Show()

		local ring = (p.accentMode == "icon" or p.accentMode == "both") and 2 or 1
		iconBack:SetPoint("TOPLEFT", icon, "TOPLEFT", -ring, ring)
		iconBack:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", ring, -ring)
		iconBack:Show()

		glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -6, 6)
		glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 6, -6)

		-- A circular icon is available where masks are, but it reads as a
		-- portrait rather than a spell, so it stays opt-in.
		if p.roundIcon and art.CreateMaskTexture and icon.AddMaskTexture then
			if not iconMask then
				local ok, mask = pcall(art.CreateMaskTexture, art)
				if ok and mask then
					mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
						"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
					iconMask = mask
					pcall(icon.AddMaskTexture, icon, mask)
				end
			end
			if iconMask then
				iconMask:ClearAllPoints()
				iconMask:SetAllPoints(icon)
				iconMask:Show()
				iconBack:Hide()
			end
		elseif iconMask then
			iconMask:Hide()
		end

		textX = 10 + p.iconSize + 10
	else
		icon:Hide()
		iconBack:Hide()
		if iconMask then iconMask:Hide() end
	end

	-- count chip
	countChip:ClearAllPoints()
	countChip:SetPoint("RIGHT", -7, 0)
	countChip:SetSize(20, 14)
	countChip:SetShown(false)
	Gradient(countChip, "VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0.09)

	local countRoom = p.showCount and 28 or 10

	-- text
	local twoLine = p.showSub and p.height >= 34

	nameText:ClearAllPoints()
	subText:ClearAllPoints()
	nameText:SetFont(fontPath, p.fontSize, outline)
	nameText:SetTextColor(unpackColor(p.fontColor, { 1, 1, 1, 1 }))
	subText:SetFont(fontPath, math.max(7, p.fontSize - 3), outline)
	subText:SetTextColor(0.60, 0.61, 0.68, 1)

	if twoLine then
		nameText:SetPoint("TOPLEFT", textX, -8)
		nameText:SetPoint("RIGHT", -countRoom, 0)
		subText:SetPoint("BOTTOMLEFT", textX, 8)
		subText:SetPoint("RIGHT", -countRoom, 0)
		subText:Show()
	else
		nameText:SetPoint("LEFT", textX, 0)
		nameText:SetPoint("RIGHT", -countRoom, 0)
		subText:Hide()
	end

	countText:ClearAllPoints()
	countText:SetPoint("CENTER", countChip, "CENTER", 0, 0)
	countText:SetFont(fontPath, math.max(8, p.fontSize - 3), outline)
	countText:SetTextColor(0.72, 0.73, 0.80, 1)

	-- Anchoring a row by both TOPLEFT and RIGHT fights over its vertical
	-- centre, so the rows get one anchor and an explicit width instead.
	for i, fs in ipairs(queueRows) do
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", art, "BOTTOMLEFT", textX, -4 - (i - 1) * (p.fontSize + 4))
		fs:SetWidth(math.max(20, p.width - textX - 8))
		fs:SetFont(fontPath, math.max(7, p.fontSize - 3), outline)
		fs:SetTextColor(0.52, 0.53, 0.60, 1)
	end

	self:Refresh()
end

function Prompt:PaintAccent(reason)
	local p = ns.db.profile.prompt
	local mode = p.accentMode or "icon"
	local r, g, b = self:AccentColor(reason)

	-- Brightest at the middle, fading towards both ends.
	Gradient(accentTop, "VERTICAL", r, g, b, 1, r, g, b, 0.15)
	Gradient(accentBottom, "VERTICAL", r, g, b, 0.15, r, g, b, 1)
	sweep:SetVertexColor(r, g, b, 1)
	iconGlow:SetVertexColor(r, g, b, 1)

	if mode == "icon" or mode == "both" then
		iconBack:SetVertexColor(r, g, b, 0.95)
	else
		iconBack:SetVertexColor(0, 0, 0, 0.85)
	end
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------

local function ClassColored(entry, text)
	if not ns.db.profile.prompt.classColor or not entry.class then return text end
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
	if not c or not c.colorStr then return text end
	return string.format("|c%s%s|r", c.colorStr, text)
end

local function Substitute(template, entry, extra)
	local out = template or ""
	out = out:gsub("{name}", entry.short or entry.name or "?")
	out = out:gsub("{count}", tostring(extra or 0))
	out = out:gsub("{class}", entry.class or "")
	out = out:gsub("{buff}", entry.buff and ns.BuffName(entry.buff) or "")
	return out
end

function Prompt:ReasonText(entry)
	local p = ns.db.profile.prompt
	local template = p[REASON_KEY[entry.reason] or "reasonNearby"] or ""
	if entry.checked and entry.known == nil and entry.reason ~= "owed" then
		template = p.reasonUnknown or template
	end
	return Substitute(template, entry, 0)
end

function Prompt:RenderPrimary(entry, extra)
	local p = ns.db.profile.prompt
	local template = p.format or "{name}"
	local out = Substitute(template, entry, extra)
	if template:find("{name}", 1, true) then
		local plainName = entry.short or entry.name or "?"
		out = out:gsub(plainName:gsub("(%W)", "%%%1"), ClassColored(entry, plainName), 1)
	end
	return out:gsub("{reason}", self:ReasonText(entry))
end

---------------------------------------------------------------------------
-- targeting
---------------------------------------------------------------------------

-- Whoever is offered should stay offered. Re-sorting every tick swapped the
-- target while the cursor was over it, so the tooltip described one person and
-- the button was aimed at another. The current pick wins ties.
function Prompt:PickTop(queue, fallback)
	local top = fallback
	if not (current and top) then return top end
	for _, candidate in ipairs(queue) do
		if candidate.name == current.name then
			if candidate.priority <= top.priority then return candidate end
			break
		end
	end
	return top
end

function Prompt:ApplyTarget(entry)
	if InCombatLockdown() then return end

	current = entry

	if not entry or not entry.buff or testMode then
		-- Unconditionally. This used to be guarded by `appliedKey ~= nil` as an
		-- optimisation, but PreClick sets appliedKey to nil immediately before
		-- calling here -- so the guard was always false on a click and the
		-- clear never ran. An emptied queue therefore left the previous
		-- person's macro armed, and clicking cast at them instead of nobody.
		for _, attribute in ipairs({ "type1", "macrotext1", "spell1", "unit1",
			"type", "macrotext", "spell", "unit" }) do
			button:SetAttribute(attribute, nil)
		end
		appliedKey = nil
		return
	end

	-- The console expands {unit}/{name}/{spell} against whoever is offered.
	ns.lastTopEntry = entry
	ns.lastTopUnit = entry.unit

	local spell = ns.BuffName(entry.buff)

	-- /manners try: arbitrary macro text, expanded against the current
	-- candidate. Iterating on this client otherwise means one guess per
	-- /reload; this makes it one guess per click.
	if ns.tryMacro then
		local text = ns.ExpandTokens(ns.tryMacro)
		button:SetAttribute("type1", "macro")
		button:SetAttribute("macrotext1", text)
		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", text)
		ns.lastMacro = "[try] " .. text
		appliedKey = nil
		return
	end

	local lines = {}

	if entry.buff.selfCast then
		lines[#lines + 1] = "/cast " .. spell
	else
		lines[#lines + 1] = "/target " .. entry.name
		lines[#lines + 1] = "/cast " .. spell
	end

	local phrase = ns.PickPhrase(entry, 120)
	if phrase then lines[#lines + 1] = phrase end

	if not entry.buff.selfCast and ns.db.profile.filters.restoreTarget then
		lines[#lines + 1] = "/targetlasttarget"
	end

	local macro = table.concat(lines, "\n")

	-- Drop the courtesy line rather than the restore if it will not all fit.
	if #macro > ns.MACRO_LIMIT and phrase then
		local without = {}
		for _, line in ipairs(lines) do
			if line ~= phrase then without[#without + 1] = line end
		end
		macro = table.concat(without, "\n")
	end

	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)

	ns.lastMacro = macro
end

function Prompt:InvalidateMacro()
	appliedKey = nil
end

---------------------------------------------------------------------------
-- refresh
---------------------------------------------------------------------------

local function TestEntry()
	return {
		name = "Preview",
		short = "|cffffd100PREVIEW|r",
		class = "PRIEST",
		reason = "owed",
		buff = ns.ResolveBuff(true),
		known = false,
	}
end

local TEST_SECONDS = 20

function Prompt:ExitTest(why)
	if not testMode then return end
	testMode, testExpiry = false, nil
	self:ApplyTarget(nil)
	ns.addon:Print("preview off" .. (why and (" -- " .. why) or "") .. ".")
end

function Prompt:ToggleTest()
	if testMode then
		self:ExitTest()
		self:Refresh()
		return
	end
	-- Time-limited on purpose. A preview that stays until you remember to turn
	-- it off looks exactly like a working prompt while ignoring every real
	-- buff, which is a silent failure with no clue attached.
	testMode = true
	testExpiry = GetTime() + TEST_SECONDS
	self:ApplyTarget(nil)
	self:Refresh()
	ns.addon:Print(("preview on for %ds -- style it now, or |cffffd100/manners test|r to stop.")
		:format(TEST_SECONDS))
end

function Prompt:Paint(entry, extra)
	local p = ns.db.profile.prompt

	nameText:SetText(self:RenderPrimary(entry, extra))
	if subText:IsShown() then subText:SetText(self:ReasonText(entry)) end

	local showCount = p.showCount and extra > 0
	countChip:SetShown(showCount)
	countText:SetText(showCount and tostring(extra) or "")

	self:PaintAccent(entry.reason)

	if p.showIcon then
		local info = ns.BuffInfo(entry.buff)
		icon:SetTexture((info and info.icon) or 135932)
	end
end

function Prompt:Refresh()
	if not button or not ns.db then return end
	local db = ns.db.profile
	if not db then return end
	local p = db.prompt

	if not ns.caps.anyKnown and not testMode then
		button:Hide()
		self:StopAttention()
		lastTop = nil
		return
	end

	if testMode then
		if testExpiry and GetTime() > testExpiry then
			self:ExitTest("timed out")
		elseif db.enabled and p.locked and not InCombatLockdown() and #ns.BuildQueue() > 0 then
			-- Somebody real is waiting. Never let a mock-up stand in front of
			-- an actual person who just buffed you.
			self:ExitTest("somebody real turned up")
		end
	end

	if testMode then
		if not button:IsShown() then
			button:Show()
			if art.intro then art.intro:Play() end
		end
		self:Paint(TestEntry(), 2)
		self:StartAttention(false)
		for i, fs in ipairs(queueRows) do
			fs:SetText(p.showQueue and i <= p.queueRows and ("Someone " .. i) or "")
		end
		return
	end

	if not p.locked then
		self:ApplyTarget(nil)
		self:StopAttention()
		button:Show()
		nameText:SetText("|cffffd100Drag to move|r")
		if subText:IsShown() then subText:SetText("|cffff8080not buffing while unlocked|r") end
		countChip:Hide()
		countText:SetText("")
		self:PaintAccent("owed")
		for _, fs in ipairs(queueRows) do fs:SetText("") end
		return
	end

	if not db.enabled then
		button:Hide()
		self:StopAttention()
		lastTop = nil
		return
	end

	if InCombatLockdown() then
		-- Attributes are frozen, so the list cannot be trusted. Either hide, or
		-- keep showing the frozen target so a click still works.
		if p.hideInCombat or not current then button:Hide() end
		return
	end

	local queue = ns.BuildQueue()
	local top = queue[1]

	top = self:PickTop(queue, top)
	self:ApplyTarget(top)

	if not top then
		button:Hide()
		self:StopAttention()
		lastTop = nil
		return
	end

	local wasHidden = not button:IsShown()
	local isNew = top.name ~= lastTop
	lastTop = top.name

	self:Paint(top, #queue - 1)
	button:Show()

	if wasHidden then
		if art.intro then art.intro:Play() end
	elseif isNew and textLayer.swap then
		textLayer.swap:Stop()
		textLayer.swap:Play()
	end

	if isNew and db.sound.enabled and db.sound.file and db.sound.file ~= "None" then
		local sound = LSM:Fetch("sound", db.sound.file)
		if sound then PlaySoundFile(sound, "Master") end
	end

	if top.reason == "owed" then
		self:StartAttention(isNew)
	else
		self:StopAttention()
	end

	for i, fs in ipairs(queueRows) do
		local entry = p.showQueue and i <= p.queueRows and queue[i + 1]
		fs:SetText(entry and (Substitute("{name}", entry, 0) .. "  |cff707078"
			.. self:ReasonText(entry) .. "|r") or "")
	end
end

function Prompt:GetButton()
	return button
end
