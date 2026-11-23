-- Manners -- buttons for the moment: small secure buttons armed before the
-- pull, out of sight until their moment, each with its own switch and key on
-- the In a fight page. Counterspell when your target casts, Ice Block when your
-- health is low, Blink when you are stunned or rooted (and, later, the rest of a
-- mage's set). Asked for on CurseForge; modelled on Prompt/CureFight.lua and
-- Prompt/BreakFree.lua, whose headers say why a fight needs buttons of its own.
-- What each waits for is data (Prompt/MomentsData.lua); what is true of the
-- situation is read by Prompt/MomentsSense.lua; this file is the buttons.
--
-- ONE SLOT = ONE SECURE BUTTON AND THREE UNPROTECTED CHILDREN
--
--   button   MannersMoment<slot>, a SecureActionButtonTemplate with the macro,
--            shown and hidden by one state driver ("[combat] fight; peace"),
--            never written in a fight. It has NO region of its own and its own
--            alpha is never changed.
--   face     a plain frame over it, alpha 0 at rest. Lua fades it (0.2 s): the
--            plain gate, never handed a hidden value.
--   inner    a frame on face. THE GAME paints its alpha from a hidden value
--            (SetAlphaFromBoolean, a curve evaluated by UnitHealthPercent): where
--            the client hides a value from Lua in a fight the button still lights
--            from it. The icon, glow, hover and key are regions of inner, so what
--            shows is face x inner.
--   cover    an unprotected, mouse-enabled frame over the button. While the
--            button is dark it swallows the click, so a click casts only while
--            the button is lit. A frame that is not protected can be shown and
--            hidden in a fight. Where only the game knows whether the button is
--            lit (a hidden health or mana), the cover stays up and the button
--            takes two quick clicks: the first opens it for a moment (a thin ring
--            answers), the second casts, so one stray click never casts.
--
-- With a key bound the button takes no mouse at all (clicks go to the world, no
-- cover) and the key casts always. Moments never read prompt.fightButtons: they
-- are never on the screen without their moment.
--
-- WHAT LUA MAY DO IN A FIGHT: paint regions and the alpha of the unprotected
-- children, show and hide the cover. Never Show, Hide, SetPoint, SetSize,
-- EnableMouse or SetAttribute on a button under the lockdown (Refresh and the
-- pull, before it, write those). Hidden values follow the raw naming rule at the
-- top of Prompt/MomentsSense.lua.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local R = Prompt.regions
local Sense = ns.Sense
local plain, caps = ns.plain, ns.caps
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime

local Moments = {}
ns.Moments = Moments
-- Every client's rows, for what holds them to the rules.
Moments.Sets = ns.MOMENT_SETS

local MAX = 10
local STATE = "mannersmoments"
local DRIVER = "[combat] fight; peace"
local FADE = 0.2
local FLUSH = 0.1
local RECHECK = 0.25
local OPEN_SECONDS = 1.5
local PRESS_WINDOW = 1
local SILENT_SECONDS = 1.2
local TRAIL_GAP = 2
local TRAIL_MAX = 12
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local RING = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local HOVER = "Interface\\Buttons\\ButtonHilight-Square"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The keys PART 1 serves: a row whose signals are not built yet is skipped by
-- Learn, so it has no button, no switch and no binding name of a spell.
local BUILT = { counterspell = true, iceblock = true, blink = true }

-- What Bindings.xml declares: ten bindings, one a slot.
for i = 1, MAX do
	_G["BINDING_NAME_CLICK MannersMoment" .. i .. ":LeftButton"] = L["Button for the moment %d"]:format(i)
end

local TARGET_CAST = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_SPELLCAST_EMPOWER_START",
	"UNIT_SPELLCAST_EMPOWER_STOP" }
local CAST_START = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_EMPOWER_START = true }
local CAST_STOP = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
	UNIT_SPELLCAST_INTERRUPTED = true }
-- Every name the module may register, probed once.
local ALL_EVENTS = { "PLAYER_TARGET_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
	"LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "SPELL_UPDATE_COOLDOWN", "PLAYER_CONTROL_LOST",
	"PLAYER_CONTROL_GAINED", "UNIT_SPELLCAST_SUCCEEDED" }
for _, name in ipairs(TARGET_CAST) do ALL_EVENTS[#ALL_EVENTS + 1] = name end

-- Made slots by number, the ones armed now, and what the last Refresh settled.
local slots, byId = {}, {}
local header, ev, fader
local dirtyRefresh, settledEnabled, settledCaps, settledOn = true, nil, nil, {}
local placedIcon, placedScale, placedQueue, placedSig
local fightEvents = {}
local controlOn, ownCastOn = false, false
local flushDue, recheckDue = false, false
local told = false
local lastFight = {}

local function Profile() return ns.db and ns.db.profile end

local function NewTally()
	return { lit = 0, game = 0, pressedLit = 0, pressedGame = 0, pressedDark = 0, out = 0, silent = 0,
		cover = 0, opened = 0, leak = 0 }
end

---------------------------------------------------------------------------
-- what this character can offer: the probe's half, wrapped round
-- ns.ProbeCapabilities at the end of the file
---------------------------------------------------------------------------

-- A name from the client, never typed. Rows whose first known rank has a name.
function Moments.Learn()
	caps.moments = nil
	dirtyRefresh = true
	local set = ns.MOMENTS[caps.class]
	if not set then return end
	local out = { list = {}, byKey = {}, n = 0 }
	for _, row in ipairs(set) do
		if BUILT[row.key] and row.ranks and not out.byKey[row.key] then
			for _, rank in ipairs(row.ranks) do
				if ns.SpellKnown(rank) then
					local name = ns.SpellNameFor(rank)
					if type(name) == "string" and name ~= "" then
						local icon = ns.safecall(C_Spell and C_Spell.GetSpellTexture, rank)
							or ns.safecall(_G.GetSpellTexture, rank) or FALLBACK_ICON
						local entry = { row = row, id = rank, name = name, icon = icon }
						out.list[#out.list + 1] = entry
						out.byKey[row.key] = entry
						out.n = out.n + 1
						_G["BINDING_NAME_CLICK MannersMoment" .. row.slot .. ":LeftButton"] = name
						break
					end
				end
			end
		end
	end
	if out.n > 0 then caps.moments = out end
end

-- Whether this character has a moment row learned (the options page asks).
function Moments.Has(key)
	local mine = caps.moments
	return mine ~= nil and mine.byKey[key] ~= nil
end

-- What Bindings.xml declares for a row's slot.
function Moments.Command(key)
	for _, row in ipairs(ns.MOMENTS[caps.class] or {}) do
		if row.key == key then return "CLICK MannersMoment" .. row.slot .. ":LeftButton" end
	end
	return nil
end

function Moments.Rows()
	local mine = caps.moments
	return mine and mine.list or {}
end

---------------------------------------------------------------------------
-- the trail
---------------------------------------------------------------------------

local function Trail(slot, text, always)
	local now = GetTime()
	if not always then
		if slot.trailAt and now - slot.trailAt < TRAIL_GAP then return end
		if (slot.trailCount or 0) >= TRAIL_MAX then return end
		slot.trailAt = now
		slot.trailCount = (slot.trailCount or 0) + 1
	end
	ns.Trail("fight", ("moment %s: %s"):format(slot.row.key, text))
end

-- What a lit button saw, in words (the tooltip and the trail).
local function Why(slot)
	local parts = {}
	for _, name in ipairs(slot.row.needs) do
		if name ~= "fight" then parts[#parts + 1] = Sense.WORDS[name] or name end
	end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- the cover and what is painted
---------------------------------------------------------------------------

-- Whether the cover is up: while dark, and while only the game knows for a row
-- that takes two clicks, except in the moment after the first of them.
local function CoverWanted(slot, now)
	if not slot.mouseOn then return false end
	if slot.state == "dark" then return true end
	if slot.state == "game" and slot.row.guard == "twice" then
		return not (slot.openUntil and now < slot.openUntil)
	end
	return false
end

local function FadeTo(slot, to)
	local from = slot.face:GetAlpha()
	if from == to then
		slot.fading, slot.fadeTo = false, to
		return
	end
	slot.fadeFrom, slot.fadeTo, slot.fadeAt, slot.fading = from, to, GetTime(), true
	fader:Show()
end

local function FadeTick()
	local now, any = GetTime(), false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.fading then
			local t = (now - slot.fadeAt) / FADE
			if t >= 1 then
				slot.face:SetAlpha(slot.fadeTo)
				slot.fading = false
			else
				slot.face:SetAlpha(slot.fadeFrom + (slot.fadeTo - slot.fadeFrom) * t)
				any = true
			end
		end
	end
	if not any then fader:Hide() end
end

local function GlowOn(slot, on)
	if on then
		slot.glow:Show()
		if slot.pulse and not slot.pulse:IsPlaying() then slot.pulse:Play() end
	else
		if slot.pulse then slot.pulse:Stop() end
		slot.glow:Hide()
	end
end

-- Applies a verdict to the art and the cover only: regions and unprotected
-- frames, allowed in a fight. To dark the cover goes first and no client call is
-- made; to game the client's paint comes first and the state only after it
-- returned, so a throw leaves the previous, consistent state.
local function Apply(slot, state)
	local now = GetTime()
	local was = slot.state
	if state == "dark" then
		slot.state = "dark"
		slot.cover:SetShown(CoverWanted(slot, now))
		GlowOn(slot, false)
		slot.ring:Hide()
		if was == "game" then
			-- Lua does not know whether anything was visible: nothing may linger.
			slot.face:SetAlpha(0)
			slot.fading, slot.fadeTo = false, 0
		elseif was == "lit" then
			FadeTo(slot, 0)
		end
		return
	end
	if state == "lit" then
		slot.inner:SetAlpha(1)
		slot.state = "lit"
		FadeTo(slot, 1)
		GlowOn(slot, true)
		slot.cover:SetShown(CoverWanted(slot, now))
		return
	end
	local game = slot.game
	if not game then return Apply(slot, "dark") end
	local kind, rawA, rawList, count = game[1], game[2], game[3], game[4]
	if not Sense.Paint(slot.inner, kind, rawA, rawList, count) then
		slot.why = "the game refused the paint for " .. kind
		return Apply(slot, "dark")
	end
	slot.state = "game"
	FadeTo(slot, 1)
	GlowOn(slot, true)
	slot.cover:SetShown(CoverWanted(slot, now))
end

-- A swallowed click, or the first of two.
local function CoverDown(slot)
	local now = GetTime()
	if slot.state == "game" and slot.row.guard == "twice" then
		slot.openUntil = now + OPEN_SECONDS
		slot.cover:Hide()
		slot.ring:Show()
		slot.tally.opened = slot.tally.opened + 1
		Trail(slot, "first of two clicks")
		local timer = _G.C_Timer
		if type(timer) == "table" and type(timer.After) == "function" then
			timer.After(OPEN_SECONDS, function()
				if slot.openUntil and GetTime() >= slot.openUntil then
					slot.openUntil = nil
					slot.ring:Hide()
					slot.cover:SetShown(CoverWanted(slot, GetTime()))
				end
			end)
		end
		return
	end
	slot.tally.cover = slot.tally.cover + 1
	Trail(slot, "the cover took a click (dark: " .. tostring(slot.why or "no need") .. ")")
end

---------------------------------------------------------------------------
-- judging a slot
---------------------------------------------------------------------------

local function Judge(slot, now)
	local state, why, note = Sense.Evaluate(slot, now)
	local was = slot.state
	slot.why, slot.note = why, note
	if state == "game" or state ~= was then
		Apply(slot, state)
		state = slot.state
	end
	if state == was then return end
	if state == "lit" then
		slot.tally.lit = slot.tally.lit + 1
		Trail(slot, "lit (" .. Why(slot) .. (note and ("; passed over: " .. note) or "")
			.. (slot.lockFlag ~= nil and ("; the game's lock flag for it: " .. tostring(slot.lockFlag)) or "") .. ")")
	elseif state == "game" then
		slot.tally.game = slot.tally.game + 1
		Trail(slot, "left to the game (" .. tostring(why) .. "; the rest: " .. Why(slot) .. ")")
	end
end

-- Whether a dark slot is waiting on something that changes with no event: a
-- cooldown ending, a mob walking into range.
local PENDING = { ["cooling down"] = true, ["out of range"] = true, ["not enough mana"] = true }

local function Flush()
	flushDue = false
	if not Sense.fighting then return end
	local now, pending = GetTime(), false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			if slot.reread then slot.castOn, slot.reread = nil, false end
			Judge(slot, now)
			if slot.state ~= "dark" or PENDING[slot.why] then pending = true end
		end
	end
	if pending and not recheckDue then
		local timer = _G.C_Timer
		if type(timer) == "table" and type(timer.After) == "function" then
			recheckDue = true
			timer.After(RECHECK, function()
				recheckDue = false
				ns.Guard("moments", Flush)
			end)
		end
	end
end

local function Schedule()
	if flushDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	flushDue = true
	timer.After(FLUSH, function() ns.Guard("moments", Flush) end)
end

-- Read again and painted at once, for the events that begin a moment.
local function JudgeAll(only)
	local now = GetTime()
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and (only == nil or slot.needs[only]) then Judge(slot, now) end
	end
end

-- Dark at once, with no read: the cast ended.
local function Darken(only, why)
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.needs[only] then
			slot.why = why
			if slot.state ~= "dark" then Apply(slot, "dark") end
		end
	end
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

-- A press, by its key or a left click. The press the prompt filed is not this
-- one's, so it is let go. A click that reached the button while the cover stood
-- over it (and no key can have pressed it) is a leak: counted, told, never
-- hidden.
local function PreClick(slot, mouse)
	if mouse ~= "LeftButton" then return end
	local now = GetTime()
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then
		ns.ExpirePendingClick(pending, L["you cast %s instead"]:format(slot.name))
	end
	slot.waitUntil = now + PRESS_WINDOW
	slot.went = false
	local tally, state = slot.tally, slot.state
	if slot.keyLabel == nil and slot.cover:IsShown() then
		tally.leak = tally.leak + 1
		local db = ns.db and ns.db.global
		if db then db.momentCoverLeaks = (db.momentCoverLeaks or 0) + 1 end
		Trail(slot, "the cover let a click through", true)
	end
	if state == "lit" then
		tally.pressedLit = tally.pressedLit + 1
		Trail(slot, "pressed: lit", true)
	elseif state == "game" then
		tally.pressedGame = tally.pressedGame + 1
		Trail(slot, "pressed: left to the game: " .. tostring(slot.why), true)
	else
		tally.pressedDark = tally.pressedDark + 1
		Trail(slot, "pressed: dark: " .. tostring(slot.why or "no need"), true)
	end
	if state ~= "dark" then
		slot.pressSerial = (slot.pressSerial or 0) + 1
		local serial = slot.pressSerial
		local timer = _G.C_Timer
		if type(timer) == "table" and type(timer.After) == "function" then
			timer.After(SILENT_SECONDS, function()
				if slot.pressSerial == serial and not slot.went then
					tally.silent = tally.silent + 1
					Trail(slot, "pressed lit, nothing went out", true)
				end
			end)
		end
	end
end

local function OnEnter(slot, self)
	if slot.state == "dark" then return end
	slot.hover:Show()
	if slot.state ~= "lit" then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	if type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(slot.id)
	else
		tip:AddLine(tostring(slot.name), 1, 1, 1)
	end
	tip:AddLine(Why(slot), 0.75, 0.75, 0.75, true)
	tip:AddLine(L["Manners: a left click here casts it, as its key does."], 0.75, 0.75, 0.75, true)
	local key = slot.row.key
	ns.AddSettingsLine(tip, "appearance.moment" .. key:sub(1, 1):upper() .. key:sub(2))
	slot.tipShown = true
	tip:Show()
end

local function OnLeave(slot)
	slot.hover:Hide()
	if slot.tipShown then
		slot.tipShown = false
		local tip = _G.GameTooltip
		if tip then tip:Hide() end
	end
end

-- Runs in the restricted environment: every armed button shown for the fight,
-- hidden after, except a button that keeps its own show out of a fight.
local SNIPPET = [=[
	for i = 1, 10 do
		local b = self:GetFrameRef("m" .. i)
		if b then
			local on = self:GetAttribute("manners-on-" .. i)
			if newstate == "fight" then
				if on then b:Show(true) else b:Hide(true) end
			elseif not (on and self:GetAttribute("manners-keep-" .. i)) then
				b:Hide(true)
			end
		end
	end
]=]

local function Create(n)
	if slots[n] or InCombatLockdown() then return slots[n] end
	local slot = { n = n, state = "dark", tally = NewTally(), needs = {} }
	local button = CreateFrame("Button", "MannersMoment" .. n, UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(false)
	button:RegisterForClicks("AnyDown")
	-- A key press is a down click (Prompt/Panel.lua explains).
	button:SetAttribute("pressAndHoldAction", true)
	button:EnableMouse(false)
	for i = 2, 31 do
		if i <= 5 then button:SetAttribute("type" .. i, "none") end
		button:SetAttribute("*type" .. i, "none")
	end
	local level = button:GetFrameLevel()
	local face = CreateFrame("Frame", nil, button)
	face:SetAllPoints(button)
	face:SetFrameLevel(level + 1)
	face:SetAlpha(0)
	local inner = CreateFrame("Frame", nil, face)
	inner:SetAllPoints(face)
	inner:SetFrameLevel(level + 2)
	inner:SetAlpha(1)
	local icon = inner:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(inner)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local glow = inner:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", inner, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", 8, -8)
	glow:SetVertexColor(1, 0.82, 0.2)
	glow:Hide()
	local pulse = glow:CreateAnimationGroup()
	if type(pulse.SetLooping) == "function" then pulse:SetLooping("BOUNCE") end
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.45)
	local hover = inner:CreateTexture(nil, "OVERLAY")
	hover:SetTexture(HOVER)
	hover:SetBlendMode("ADD")
	hover:SetAllPoints(inner)
	hover:Hide()
	local keyText = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("BOTTOMRIGHT", inner, "BOTTOMRIGHT", -2, 2)
	keyText:SetText("")
	local ring = face:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(RING)
	ring:SetAllPoints(face)
	ring:SetVertexColor(1, 1, 1, 0.6)
	ring:Hide()
	local cover = CreateFrame("Frame", nil, button)
	cover:SetAllPoints(button)
	cover:SetFrameLevel(level + 10)
	cover:EnableMouse(true)
	cover:SetScript("OnMouseDown", function() ns.Guard("moments", CoverDown, slot) end)
	cover:Hide()
	button:SetScript("PreClick", function(_, mouse) ns.Guard("moments", PreClick, slot, mouse) end)
	button:SetScript("OnEnter", function(self) OnEnter(slot, self) end)
	button:SetScript("OnLeave", function() OnLeave(slot) end)
	button:Hide()
	slot.button, slot.face, slot.inner, slot.cover, slot.ring = button, face, inner, cover, ring
	slot.iconTex, slot.glow, slot.pulse, slot.hover, slot.keyText = icon, glow, pulse, hover, keyText
	slots[n] = slot
	if not fader then
		fader = CreateFrame("Frame")
		fader:Hide()
		fader:SetScript("OnUpdate", FadeTick)
		Sense.Probe(inner)
	end
	if not header and type(_G.RegisterStateDriver) == "function" then
		local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made) == "table" and type(made.SetFrameRef) == "function" then
			made:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made, STATE, DRIVER)
			header = made
		end
	end
	if not ev then
		ev = CreateFrame("Frame")
		Moments.frame = ev
		ev:SetScript("OnEvent", function(_, event, unit, ...)
			-- The busiest ones of a fight come first, outside the guard's closure.
			ns.Guard("moments", Moments.OnEvent, event, unit, ...)
		end)
		Sense.ProbeEvents(ev, ALL_EVENTS)
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
		ev:RegisterEvent("UPDATE_BINDINGS")
	end
	return slot
end

---------------------------------------------------------------------------
-- the macro, keys, mouse and place: out of combat only
---------------------------------------------------------------------------

local function MacroFor(slot)
	local row = slot.row
	return (row.stop and "/stopcasting\n" or "") .. "/cast " .. slot.name
end

local function Disarm(slot)
	local button = slot.button
	if slot.armedMacro ~= nil or button:GetAttribute("macrotext1") ~= nil then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
	end
	slot.armedMacro = nil
end

local function Arm(slot)
	local macro = MacroFor(slot)
	if #macro > ns.MACRO_LIMIT then
		Disarm(slot)
		slot.tooLong = true
		return
	end
	slot.tooLong = false
	local button = slot.button
	if macro == slot.armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	slot.armedMacro = macro
end

local function ReadKey(slot)
	local key
	if type(GetBindingKey) == "function" then key = (GetBindingKey("CLICK MannersMoment" .. slot.n .. ":LeftButton")) end
	slot.keyLabel = type(key) == "string" and key ~= "" and key or nil
	local text = slot.keyLabel
	if text then text = text:gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-") end
	slot.keyText:SetText(text or "")
end

-- A button takes a click only when no key is bound (then a click is the only way
-- to cast it): with a key, clicks reach the world and no cover is used. The
-- client refuses EnableMouse on a protected frame under the lockdown.
local function SetMouse(slot)
	if InCombatLockdown() then return end
	local on = slot.keyLabel == nil
	slot.button:EnableMouse(on)
	slot.mouseOn = on
end

-- Left of the prompt, five to a row, anchored to the prompt's secure button (a
-- frame, never a region). With no room there, the side the list of names does
-- not use.
local function Place(p)
	local size = math.floor(math.max(24, math.min(48, tonumber(p.iconSize) or 30)) * (tonumber(p.scale) or 1) + 0.5)
	local step = size + 8
	local list = {}
	for n = 1, MAX do
		if slots[n] and slots[n].armed then list[#list + 1] = slots[n] end
	end
	local count = #list
	local queueAbove = Prompt.state and Prompt.state.queueAbove and true or false
	local side = "left"
	local anchor = R.button
	local scale = type(anchor.GetEffectiveScale) == "function" and tonumber(anchor:GetEffectiveScale()) or 1
	local left = anchor:GetLeft()
	if type(left) == "number" and left * scale < 10 + math.min(count, 5) * step then
		side = queueAbove and "below" or "above"
		local bottom = anchor:GetBottom()
		local rows = math.max(1, math.ceil(count / 5))
		if side == "below" and type(bottom) == "number" and bottom * scale < 10 + rows * step then
			side = "past"
		end
	end
	local sig = size .. ":" .. count .. ":" .. side
	for i, slot in ipairs(list) do
		sig = sig .. ":" .. slot.n
		local col, rowN = (i - 1) % 5, math.floor((i - 1) / 5)
		local b = slot.button
		b:ClearAllPoints()
		if side == "left" then
			b:SetPoint("RIGHT", anchor, "LEFT", -(10 + col * step), rowN * step)
		elseif side == "below" then
			b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", col * step, -(10 + rowN * step))
		elseif side == "above" then
			b:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", col * step, 10 + rowN * step)
		else
			local past = 10 + (p.showQueue and (math.max(1, tonumber(p.queueRows) or 1) * ((tonumber(p.fontSize) or 12) + 4) + 8) or 0)
			b:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", col * step, past + rowN * step)
		end
		b:SetSize(size, size)
	end
	placedSig, placedIcon, placedScale, placedQueue = sig, p.iconSize, p.scale, queueAbove
	return side
end
Moments.Place = Place

-- Where a cooldown already running before the pull is known from: plain start
-- and length say it, and Manners' own clock keeps it where the fight hides them.
local function Seed(slot, now)
	local _, start, duration = Sense.Cool(slot.id)
	if type(start) == "number" and type(duration) == "number" and duration > 1.5 then
		local left = start + duration - now
		if left > 0 then slot.readyAt = now + left end
	end
end

local function SetRegistered(on)
	if ev == nil then return end
	-- Own casts and the control events, kept while an armed row needs them.
	local wantOwn = false
	local wantControl = false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			wantOwn = true
			if slot.needs.stuck then wantControl = true end
		end
	end
	if wantOwn and not ownCastOn and Sense.accepted.UNIT_SPELLCAST_SUCCEEDED then
		ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		ownCastOn = true
	elseif ownCastOn and not wantOwn then
		ev:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		ownCastOn = false
	end
	if wantControl and not controlOn then
		for _, name in ipairs({ "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }) do
			if Sense.accepted[name] then ev:RegisterEvent(name) end
		end
		controlOn = true
	elseif controlOn and not wantControl then
		ev:UnregisterEvent("PLAYER_CONTROL_LOST")
		ev:UnregisterEvent("PLAYER_CONTROL_GAINED")
		controlOn = false
		Sense.lostAt = nil
	end
end

-- From a scan (Core.lua's TickBody) when Wanted says something changed, and as
-- a fight ends (Release). Out of combat only.
function Moments:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	local mine = caps.moments
	local switches = type(db.moments) == "table" and db.moments or {}
	local wanted = {}
	local on = db.enabled == true
	if mine and on then
		for _, entry in ipairs(mine.list) do
			if switches[entry.row.key] == true then
				wanted[entry.row.slot] = entry
				if not slots[entry.row.slot] then Create(entry.row.slot) end
			end
		end
	end
	wipe(byId)
	wipe(settledOn)
	if mine then
		for _, entry in ipairs(mine.list) do settledOn[entry.row.key] = switches[entry.row.key] == true end
	end
	local now = GetTime()
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			local entry = wanted[n]
			if entry and slot.button then
				slot.row, slot.id, slot.name, slot.entry = entry.row, entry.id, entry.name, entry
				slot.needs = Sense.NeedSet(entry.row)
				slot.armed = true
				slot.iconTex:SetTexture(entry.icon)
				byId[entry.id] = slot
				ReadKey(slot)
				SetMouse(slot)
				Arm(slot)
				Seed(slot, now)
				if header then
					header:SetFrameRef("m" .. n, slot.button)
					header:SetAttribute("manners-on-" .. n, true)
					header:SetAttribute("manners-keep-" .. n, entry.row.peace == true)
				end
			else
				slot.armed = false
				Disarm(slot)
				if header then header:SetAttribute("manners-on-" .. n, false) end
				if slot.button:IsShown() then slot.button:Hide() end
			end
		end
	end
	local any = false
	for n = 1, MAX do
		if slots[n] and slots[n].armed then any = true end
	end
	if any then
		Place(db.prompt)
		Sense.ReadScale()
	end
	-- What Wanted compares against, kept even with nothing armed so an idle scan
	-- sees no change.
	placedIcon, placedScale = db.prompt.iconSize, db.prompt.scale
	placedQueue = Prompt.state and Prompt.state.queueAbove and true or false
	if header and header:GetAttribute("state-" .. STATE) ~= "peace" then
		header:SetAttribute("state-" .. STATE, "peace")
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			slot.state, slot.why = "dark", "not in a fight"
			slot.face:SetAlpha(0)
			slot.fading, slot.fadeTo, slot.openUntil = false, 0, nil
			slot.cover:Hide()
			slot.ring:Hide()
			slot.hover:Hide()
			GlowOn(slot, false)
			if slot.armed and slot.row.peace ~= true and slot.button:IsShown() then slot.button:Hide() end
		end
	end
	SetRegistered()
	settledEnabled, settledCaps, dirtyRefresh = on, mine, false
end

-- Whether a scan has anything to do here. With nothing learned and nothing ever
-- made: one field read and no question to the client. Once made, plain fields
-- are compared and the lockdown is asked only when one changed.
function Moments:Wanted()
	local mine = caps.moments
	if (mine == nil or mine.n == 0) and next(slots) == nil then return false end
	local db = Profile()
	if not db then return false end
	local changed = dirtyRefresh
	if not changed then
		if (db.enabled == true) ~= (settledEnabled == true) or mine ~= settledCaps then
			changed = true
		else
			local p, m = db.prompt, db.moments
			if p.iconSize ~= placedIcon or p.scale ~= placedScale
				or (Prompt.state and Prompt.state.queueAbove and true or false) ~= placedQueue then
				changed = true
			elseif mine and type(m) == "table" then
				for _, entry in ipairs(mine.list) do
					if (m[entry.row.key] == true) ~= (settledOn[entry.row.key] == true) then
						changed = true
						break
					end
				end
			end
		end
	end
	return changed and not InCombatLockdown()
end

---------------------------------------------------------------------------
-- the fight: events registered at the pull, dropped at the release
---------------------------------------------------------------------------

local function Register(name, unit)
	if not Sense.accepted[name] or fightEvents[name] then return end
	if unit then ev:RegisterUnitEvent(name, unit) else ev:RegisterEvent(name) end
	fightEvents[name] = true
end

local function RegisterFight()
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			local needs = slot.needs
			if needs.casting or needs.interruptible then
				for _, name in ipairs(TARGET_CAST) do Register(name, "target") end
			end
			if needs.casting or needs.enemy or needs.inrange or needs.stealable then Register("PLAYER_TARGET_CHANGED") end
			if needs.lowhealth then
				Register("UNIT_HEALTH", "player")
				Register("UNIT_MAXHEALTH", "player")
			end
			if needs.lowmana then
				Register("UNIT_POWER_UPDATE", "player")
				Register("UNIT_MAXPOWER", "player")
			end
			if needs.stuck and type(_G.C_LossOfControl) == "table" then
				Register("LOSS_OF_CONTROL_ADDED")
				Register("LOSS_OF_CONTROL_UPDATE")
			end
			if needs.ready then Register("SPELL_UPDATE_COOLDOWN") end
		end
	end
end

-- The pull, before the lockdown: keys, mouse, clocks, the fight's events, every
-- armed button dark with its cover up, and ONE look at the situation at once, so
-- a stun, a cast or a low bar that began before the pull is seen without waiting
-- for an event.
local function Pull()
	local now = GetTime()
	local any = false
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed then
			any = true
			ReadKey(slot)
			SetMouse(slot)
			slot.tally = NewTally()
			slot.trailAt, slot.trailCount = nil, 0
			slot.onGCD, slot.flip, slot.castOn, slot.castInfo = nil, nil, nil, nil
			slot.state, slot.why, slot.openUntil = "dark", nil, nil
			Seed(slot, now)
			slot.cover:SetShown(slot.mouseOn == true)
		end
	end
	if not any then return end
	Sense.fighting = true
	RegisterFight()
	JudgeAll()
	Schedule()
end

-- PLAYER_REGEN_ENABLED, out of the lockdown: the fight's events dropped, every
-- cover down, and the buttons armed again.
function Moments:Release()
	if next(slots) == nil then return end
	Sense.fighting = false
	for name in pairs(fightEvents) do
		if ev then ev:UnregisterEvent(name) end
		fightEvents[name] = nil
	end
	wipe(lastFight)
	for n = 1, MAX do
		local slot = slots[n]
		if slot then
			lastFight[n] = { key = slot.row and slot.row.key, tally = slot.tally, why = slot.why, state = slot.state, armed = slot.armed }
			slot.cover:Hide()
			slot.ring:Hide()
			slot.openUntil = nil
			if slot.state ~= "dark" then Apply(slot, "dark") end
			slot.face:SetAlpha(0)
			slot.fading = false
		end
	end
	for n = 1, MAX do
		local slot = slots[n]
		if slot and slot.armed and slot.tally.leak > 0 and not told then
			told = true
			if ns.addon and ns.addon.Print then
				ns.addon:Print(L["Manners: a click reached a button for the moment while it was out of sight. Give that button a key under In a fight and it takes no clicks."])
			end
		end
	end
	dirtyRefresh = true
	self:Refresh()
end

-- Your own cast went out: Manners' own clock for it, the clocks it starts or
-- clears in the other rows, and the answer to a press.
local function OwnCast(spellId)
	local id = plain(spellId)
	if type(id) ~= "number" then return end
	local slot = byId[id]
	if not slot then return end
	local now = GetTime()
	local _, start, duration = Sense.Cool(id)
	local left = (type(start) == "number" and type(duration) == "number" and duration > 1.5) and (start + duration - now) or nil
	slot.readyAt = now + ((left and left > 1.5) and left or (slot.row.cooldown or 0))
	slot.castAt = now
	for n = 1, MAX do
		local other = slots[n]
		if other and other.armed and other ~= slot then
			if slot.row.shares == other.row.key then other.readyAt = slot.readyAt end
			for _, key in ipairs(slot.row.resets or {}) do
				if other.row.key == key then other.readyAt = nil end
			end
		end
	end
	if slot.waitUntil and now <= slot.waitUntil then
		slot.waitUntil = nil
		slot.went = true
		slot.tally.out = slot.tally.out + 1
		Trail(slot, "went out", true)
	end
	if Sense.fighting then Schedule() end
end

function Moments.OnEvent(event, unit, castGuid, spellId)
	if event == "PLAYER_REGEN_DISABLED" then return Pull() end
	if event == "UPDATE_BINDINGS" then
		if not InCombatLockdown() then dirtyRefresh = true end
		return
	end
	if event == "UNIT_SPELLCAST_SUCCEEDED" then return OwnCast(spellId) end
	if event == "PLAYER_CONTROL_LOST" then
		Sense.lostAt = GetTime()
		return JudgeAll("stuck")
	elseif event == "PLAYER_CONTROL_GAINED" then
		Sense.lostAt = nil
		return JudgeAll("stuck")
	end
	if not Sense.fighting then return end
	if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
		-- Only your own: the client may tell of another unit's loss of control.
		local who = plain(unit)
		if type(who) == "string" and who ~= "player" then return end
		return JudgeAll("stuck")
	end
	if event == "PLAYER_TARGET_CHANGED" then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.castOn, slot.flip = nil, nil end
		end
		return JudgeAll()
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		-- The only place isOnGCD is read: the game says not to trust it anywhere else.
		local api = _G.C_Spell
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and type(api) == "table" and type(api.GetSpellCooldown) == "function" then
				local rec = plain(api.GetSpellCooldown(slot.id))
				-- (not `and ... or nil`: a plain false is the answer that matters)
				local flag
				if type(rec) == "table" then flag = plain(rec.isOnGCD) end
				slot.onGCD = flag
			end
		end
		return Schedule()
	end
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
		return Schedule()
	end
	-- The target's cast events: the handler running for "target" is itself the
	-- plain signal; the payload is never read.
	if unit ~= "target" then return end
	if CAST_START[event] then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.castOn, slot.flip = nil, nil end
		end
		return JudgeAll("casting")
	elseif CAST_STOP[event] then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed and slot.needs.casting then slot.castOn, slot.flip, slot.reread = false, nil, true end
		end
		Darken("casting", "your target is not casting")
		return Schedule()
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		for n = 1, MAX do
			local slot = slots[n]
			if slot and slot.armed then slot.flip = event == "UNIT_SPELLCAST_INTERRUPTIBLE" end
		end
		return JudgeAll("interruptible")
	elseif event == "UNIT_SPELLCAST_FAILED" then
		return JudgeAll("casting")
	end
end

---------------------------------------------------------------------------
-- for the fight summary, the mark, /manners debug and the self-test
---------------------------------------------------------------------------

local function Armed()
	local out = {}
	for n = 1, MAX do
		if slots[n] and slots[n].armed then out[#out + 1] = slots[n] end
	end
	return out
end

local function TallyWords(slot, tally)
	if tally.lit + tally.game + tally.pressedLit + tally.pressedGame + tally.pressedDark + tally.cover == 0 then
		return ("%s dark (%s)"):format(slot.row.key, tostring(slot.why or "no need"))
	end
	return ("%s lit %d, game %d, pressed %d, out %d, cover %d"):format(slot.row.key, tally.lit, tally.game,
		tally.pressedLit + tally.pressedGame + tally.pressedDark, tally.out, tally.cover)
end

-- The second line of a fight's summary: what each button saw. Nothing armed,
-- nothing to say.
function Moments.FightWords()
	local armed = Armed()
	if #armed == 0 then return nil end
	local parts = {}
	for _, slot in ipairs(armed) do parts[#parts + 1] = TallyWords(slot, slot.tally) end
	return table.concat(parts, "; ")
end

-- One line each, for Mark this moment: the verdict now, and what is on the screen.
function Moments.MarkWords()
	local armed = Armed()
	if #armed == 0 then return { "moments: none armed" } end
	local out = {}
	for _, slot in ipairs(armed) do
		local verdict = slot.state == "lit" and "lit" or (slot.state == "game" and ("left to the game: " .. tostring(slot.why)))
			or ("dark: " .. tostring(slot.why or "no need"))
		out[#out + 1] = ("moment %s %s, shown %s, cover %s, key %s"):format(slot.row.key, verdict,
			slot.button:IsShown() and "yes" or "no", slot.cover:IsShown() and "up" or "down", tostring(slot.keyLabel or "none"))
	end
	return out
end

local function Yes(v) return v and "yes" or "no" end

function ns.MomentLines()
	local out = {}
	local rows = ns.MOMENTS[caps.class]
	if not rows then return out end
	local mine = caps.moments
	local can = Sense.can
	local db = Profile()
	local m = db and db.moments or {}
	local leaks = ns.db and ns.db.global and ns.db.global.momentCoverLeaks or 0
	local refused = {}
	for kind, why in pairs(Sense.refused) do refused[#refused + 1] = kind .. " (" .. tostring(why) .. ")" end
	table.sort(refused)
	out[1] = ("moments: class %s, %d rows here, %d learned; the game's calls: alpha from a boolean %s, evaluate %s, curves %s, health percent %s, power percent %s; percent scale %s; refused calls: %s; events this client lacks: %s; lock flag proven: %s; the cover let a click through: %s")
		:format(tostring(caps.class), #rows, mine and mine.n or 0, Yes(can.bool), Yes(can.eval), Yes(can.curve),
			Yes(can.health), Yes(can.power), tostring(Sense.scale), #refused > 0 and table.concat(refused, ", ") or "none",
			#Sense.lacking > 0 and table.concat(Sense.lacking, ", ") or "none", Yes(Sense.lockProven),
			leaks > 0 and (leaks .. " times (or a macro of yours clicked it)") or "never")
	for _, row in ipairs(rows) do
		local entry = mine and mine.byKey[row.key]
		local slot = slots[row.slot]
		local tally = slot and slot.tally or NewTally()
		if not BUILT[row.key] then
			out[#out + 1] = ("moment %s: not built yet"):format(row.key)
		elseif not entry then
			out[#out + 1] = ("moment %s: not learned"):format(row.key)
		else
			local armed = slot and slot.armed and slot.armedMacro
			out[#out + 1] = ("moment %s: spell %d %s, learned yes, switch %s, %s, key %s, slot %d, %s, now %s; last fight lit %d, game %d, pressed %d, out %d, silent %d"):format(
				row.key, entry.id, tostring(entry.name), m[row.key] == true and "on" or "off",
				armed and ("armed (" .. tostring(armed):gsub("\n", " | ") .. ")") or (slot and slot.tooLong and "macro too long, not armed" or "not armed"),
				tostring(slot and slot.keyLabel or (type(GetBindingKey) == "function" and (GetBindingKey("CLICK MannersMoment" .. row.slot .. ":LeftButton")) or "none")),
				row.slot, row.guard == "twice" and "two clicks where the game alone knows" or "one click",
				slot and (slot.state == "dark" and ("dark: " .. tostring(slot.why or "no need")) or slot.state) or "dark",
				tally.lit, tally.game, tally.pressedLit + tally.pressedGame + tally.pressedDark, tally.out, tally.silent)
		end
	end
	return out
end

-- For the self-test (Selftest.lua, group fight): one { warn, text } per row of
-- this client's set, and the counts the page's lines hang on. A fact about the
-- client is a PASS; a switched-on button that was never made, a header that is
-- not at peace, a macro that did not fit or a cover that let a click through is
-- a WARN.
function Moments.SelfRows()
	local out = {}
	local rows = ns.MOMENTS[caps.class]
	if not rows then return out end
	local mine = caps.moments
	local db = Profile()
	local m = db and db.moments or {}
	for _, row in ipairs(rows) do
		local entry = mine and mine.byKey[row.key]
		local slot = slots[row.slot]
		local text, warn
		if not BUILT[row.key] then
			text = "not built yet"
		elseif not entry then
			text = "not learned"
		elseif not (db and db.enabled == true and m[row.key] == true) then
			text = "switched off"
		elseif not (slot and slot.button) then
			text, warn = "switched on, but the button was never made", true
		elseif slot.tooLong then
			text, warn = "the armed macro does not fit in 255 characters", true
		elseif not slot.armedMacro then
			text, warn = "the button has no macro armed", true
		else
			local state = header and header:GetAttribute("state-" .. STATE)
			local key = slot.keyLabel and ("key " .. slot.keyLabel) or "no key: a click on it casts while it is lit"
			if state ~= "peace" and not (state == "fight" and Sense.fighting) then
				text, warn = ("button made, but its header says %s, not peace"):format(tostring(state)), true
			else
				text = ("button made, header %s, %s"):format(tostring(state), key)
			end
			local leaks = ns.db and ns.db.global and ns.db.global.momentCoverLeaks or 0
			if leaks > 0 then
				text = text .. ("; the cover let a click through %d times (or a macro of yours clicked it)"):format(leaks)
				warn = true
			end
		end
		out[#out + 1] = { warn = warn, text = row.key .. ": " .. text, key = row.key, command = Moments.Command(row.key),
			armed = slot and slot.armed and entry ~= nil and BUILT[row.key] }
	end
	return out
end

function Moments:Button(n) return slots[n] and slots[n].button end
function Moments:Slot(n) return slots[n] end
function Moments:Header() return header end
function Moments:Frame() return ev end
function Moments:Fader() return fader end

-- The probe, and what it learns of a mage's moments, before anything asks.
do
	local probe = ns.ProbeCapabilities
	function ns.ProbeCapabilities(...)
		local result = probe(...)
		Moments.Learn()
		return result
	end
end
