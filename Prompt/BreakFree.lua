-- Manners -- breaking free in a fight: a Forsaken's Will of the Forsaken on a
-- small secure button of its own beside the prompt, with a key of its own,
-- shown for the length of every fight and lit up while you are feared,
-- charmed or asleep and the spell is ready. Asked for by the author, a
-- Forsaken mage on Forever: "in combat, if I sleep or whatever, I need to be
-- able to get the prompt for this", and "it should not lock the prompt if
-- it's a debuff or buff that needs to happen in a fight".
--
-- WHY A BUTTON OF ITS OWN
--
-- A fight locks the prompt: its macro is whatever the pull left on it
-- (CLAUDE.md, Combat), and nothing secure can learn that you are feared (a
-- snippet reads no aura and no loss of control: Prompt/Fight.lua says what the
-- restricted environment has). So the prompt's key keeps to buffs, and Will of
-- the Forsaken gets a button that casts that one spell and nothing else,
-- armed out of combat whenever this applies. A hidden armed button firing it
-- from its own key casts exactly what the player bound, at nobody else.
--
-- WHAT MOVES IN A FIGHT, AND WHAT DOES IT
--
-- Lua writes the macro, the place and the size out of combat only, on the
-- scan (Core.lua, TickBody) and as a fight ends (Release). Its visibility is a
-- state driver's, "[combat] fight; peace", as the consumables button and Hide
-- the prompt in combat use (Prompt/Supplies.lua, Prompt/Fight.lua): the
-- snippet shows it at the pull and hides it after, in the restricted
-- environment. Lua never shows, hides, moves or arms it under the lockdown,
-- so nothing Manners itself chooses (Hide the prompt in combat, a snooze, the
-- prompt off the screen at the pull) keeps it from being seen and pressed.
-- In a fight Lua paints only its own regions and its alpha, which the client
-- allows: bright while you are afflicted and it is ready, dim otherwise, a
-- cooldown sweep while it cools down. The prompt, when it is on the screen,
-- says the same (PaintPrompt, from Prompt/Refresh.lua's combat branch).
--
-- WHAT IT KNOWS
--
-- Whether you can break free: the probe's (caps.breakFree: the race by its
-- file name, the spell known), never asked per scan. Whether you need to: the
-- loss of control the client reports (C_LossOfControl, in either of its two
-- shapes), or UnitIsCharmed, read on the client's events and cached; a secret
-- or a missing answer is never a reason. Whether it is ready: our own press
-- followed by the spell going out, else the client's own cooldown where it is
-- plain; unknown counts as ready, since a refused cast burns nothing.
--
-- A press here also tells Clicks.lua that the next cast is not the prompt's
-- (the pending-click guard): pressed from habit while feared, the prompt
-- files a press that never goes out, and Will of the Forsaken's cast, with no
-- target and a secret id in a fight, would otherwise settle it as landed.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local R, S, lib = Prompt.regions, Prompt.state, Prompt.lib
local SetLine, EntryIcon = lib.SetLine, lib.EntryIcon
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local plain = ns.plain
local caps = ns.caps

local BreakFree = {}
ns.BreakFree = BreakFree

-- What Bindings.xml declares.
BreakFree.COMMAND = "CLICK MannersBreakFree:LeftButton"

-- The abilities that break a loss of control, one row each. `race` is the
-- client's race file name (ChrRaces.ClientFileString: Scourge is the
-- Forsaken); `breaks` the loss-of-control types it ends. Fear, charm and sleep
-- only: a Horror (Death Coil) or a possession reported under another type
-- would light a two-minute cooldown up for nothing, so another type joins only
-- once the trail shows it on an effect this breaks. Later rows may carry a
-- class or an item instead of a race.
local ABILITIES = {
	{ key = "willoftheforsaken", spell = 7744, race = "Scourge",
		breaks = { FEAR = true, CHARM = true, SLEEP = true }, cooldown = 120 },
}

local STATE = "mannersbreakfree"
local DRIVER = "[combat] fight; peace"
-- Between the prompt's right edge and this button: a mis-click casts it.
local GAP = 10
-- How long after a press of this button a cast event is taken for its own,
-- and how long its spell going out is waited for.
local PRESS_SECONDS = 0.6
local SUCCEED_SECONDS = 1
-- The icon the client gives none for: Will of the Forsaken's own.
local FALLBACK_ICON = "Interface\\Icons\\Spell_Shadow_RaiseDead"
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"

local button, header, icon, glow, pulse, nameText, keyText, cooldown
local armedMacro, placedKey, paintedKey
-- Afflicted now (a type this breaks, or charmed), from the client's events.
local afflicted = false
-- The last loss of control seen: { kind, how, at }; `how` is plain, secret or
-- no API.
local lastLoss
-- Our own press, and the end of the cooldown it began.
local pressAt, waitUntil, readyAt
-- Whether the prompt carries the break-free line now.
local promptPainted = false
local recheckDue = false
local keyLabel

local function Profile()
	return ns.db and ns.db.profile
end

local function Known()
	return caps.breakFree
end

-- Whether this character has a row, the switch is on and Manners is.
function BreakFree.Applies(db)
	db = db or Profile()
	return caps.breakFree ~= nil and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false
end

-- The probe's half (wrapped round ns.ProbeCapabilities at the end of this
-- file): the first row this character's race and spell book answer, and the
-- spell's name and icon, or nothing.
function BreakFree.Learn()
	caps.breakFree = nil
	local race = plain(select(2, UnitRace("player")))
	if type(race) ~= "string" then return end
	for _, row in ipairs(ABILITIES) do
		if row.race == race and ns.SpellKnown(row.spell) then
			local name = ns.SpellNameFor(row.spell)
			if type(name) == "string" and name ~= "" then
				local texture = ns.safecall(C_Spell and C_Spell.GetSpellTexture, row.spell)
					or ns.safecall(_G.GetSpellTexture, row.spell)
				caps.breakFree = { row = row, name = name, icon = texture or FALLBACK_ICON }
				return
			end
		end
	end
end

---------------------------------------------------------------------------
-- what the client says of you
---------------------------------------------------------------------------

-- The loss of control the client reports, in whichever shape it has: the
-- table form (GetActiveLossOfControlDataCount, GetActiveLossOfControlData) or
-- the older one (GetNumEvents, GetEventInfo, whose first return is the type).
-- Answers whether one is a type `row` breaks, the first type seen, and how it
-- came. Called directly after type() checks (an event's path, under the
-- frame's Guard): a secret is made plain, and plain secret is never a reason.
local function ReadLoss(row)
	local api = _G.C_LossOfControl
	if type(api) ~= "table" then return false, nil, "no API" end
	local count, info
	if type(api.GetActiveLossOfControlDataCount) == "function" and type(api.GetActiveLossOfControlData) == "function" then
		count = plain(api.GetActiveLossOfControlDataCount())
		info = function(i)
			local data = plain(api.GetActiveLossOfControlData(i))
			if type(data) ~= "table" then return data end
			return data.locType
		end
	elseif type(api.GetNumEvents) == "function" and type(api.GetEventInfo) == "function" then
		count = plain(api.GetNumEvents())
		info = function(i) return (api.GetEventInfo(i)) end
	else
		return false, nil, "no API"
	end
	if type(count) ~= "number" then return false, "?", "secret" end
	local first, how
	for i = 1, math.min(count, 8) do
		local raw = info(i)
		local kind = plain(raw)
		if type(kind) == "string" then
			if row.breaks[kind] then return true, kind, "plain" end
			first, how = first or kind, how or "plain"
		elseif raw ~= nil then
			first, how = first or "?", how or "secret"
		end
	end
	return false, first, how
end

-- Afflicted by something the row breaks: a loss of control of its types, or
-- charmed by UnitIsCharmed alone (a charm the client reports nowhere else).
-- Kept in `afflicted`; asked on the client's events, never per scan.
local function Read()
	local info = Known()
	if not info then
		afflicted = false
		return nil, nil
	end
	local hit, kind, how = ReadLoss(info.row)
	if not hit and info.row.breaks.CHARM and plain(UnitIsCharmed("player")) == true then
		hit = true
	end
	afflicted = hit == true
	return kind, how
end

-- The spell's cooldown by the client's own figure, or nil where it gives none
-- (in a fight on Forever its fields are secret). The call may be handed a
-- secret back, so it is protected, as Clicks.lua's own reading is.
local function CooldownLeft(spell, now)
	local get = C_Spell and C_Spell.GetSpellCooldown
	local start, duration
	if type(get) == "function" then
		local ok, info = pcall(get, spell)
		if ok and type(info) == "table" then start, duration = plain(info.startTime), plain(info.duration) end
	elseif type(_G.GetSpellCooldown) == "function" then
		local ok, s, d = pcall(_G.GetSpellCooldown, spell)
		if ok then start, duration = plain(s), plain(d) end
	end
	if type(start) ~= "number" or type(duration) ~= "number" then return nil end
	-- The global cooldown is no cooldown of its own.
	if duration <= 1.5 then return 0 end
	return math.max(0, start + duration - now)
end

-- Ready, as far as anything says: our own record of the cooldown first, then
-- the client's figure where it is plain. Unknown is ready.
local function Ready(now)
	if readyAt then
		if now < readyAt then return false end
		readyAt = nil
	end
	local info = Known()
	if not info then return false end
	local left = CooldownLeft(info.row.spell, now)
	if left and left > 0 then return false end
	return true
end

---------------------------------------------------------------------------
-- the button
---------------------------------------------------------------------------

-- Its own regions and its alpha, which the client lets an addon change in a
-- fight. Bright while afflicted and ready; dim, with the sweep while it cools.
local function Paint()
	if not button then return end
	local info = Known()
	local now = GetTime()
	local bright = afflicted and info ~= nil and Ready(now)
	local cooling = readyAt ~= nil and now < readyAt
	local key = tostring(bright) .. ":" .. tostring(cooling and readyAt) .. ":" .. tostring(keyLabel)
		.. ":" .. tostring(info and info.name)
	if key == paintedKey then return end
	paintedKey = key
	button:SetAlpha(bright and 1 or 0.35)
	if info then icon:SetTexture(info.icon) end
	if bright then
		glow:Show()
		if pulse and not pulse:IsPlaying() then pulse:Play() end
		nameText:SetText("|cffffd100" .. tostring(info.name) .. "|r")
		keyText:SetText(keyLabel and L["press %s to break free"]:format(keyLabel) or L["click to break free"])
	else
		if pulse then pulse:Stop() end
		glow:Hide()
		nameText:SetText("")
		keyText:SetText("")
	end
	if type(cooldown.SetCooldown) ~= "function" then return end
	if cooling and info then
		cooldown:SetCooldown(readyAt - info.row.cooldown, info.row.cooldown)
	elseif type(cooldown.Clear) == "function" then
		cooldown:Clear()
	end
end

local function Disarm()
	if armedMacro ~= nil then
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
		armedMacro = nil
	end
end

-- The one spell, and nothing else: no target, no line, no other press.
local function Arm(name)
	local macro = "/cast " .. name
	if macro == armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	armedMacro = macro
end

-- Beside the prompt's right edge, the size of its icon. Anchored to the
-- prompt's button, a frame (never a region: CLAUDE.md), which holds even
-- while the prompt is hidden.
local function Place(p)
	local size = math.floor(math.max(24, math.min(48, tonumber(p.iconSize) or 30)) * (tonumber(p.scale) or 1) + 0.5)
	local key = tostring(size)
	if key == placedKey then return end
	placedKey = key
	button:ClearAllPoints()
	button:SetPoint("LEFT", R.button, "RIGHT", GAP, 0)
	button:SetSize(size, size)
end

-- A press, by its key or a left click: in a fight too (an insecure PreClick
-- on a secure button is the client's to allow, as the consumables button's
-- is). The press the prompt filed is not this one's, so it is let go with its
-- own reason, and the next cast event is held from settling anything.
local function PreClick(_, mouse)
	if mouse ~= "LeftButton" then return end
	local now = GetTime()
	pressAt, waitUntil = now, now + SUCCEED_SECONDS
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you broke free instead"]) end
	BreakFree.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	local info = Known()
	ns.Trail("press", "pressed: break free (" .. tostring(info and info.name) .. ")"
		.. (afflicted and ", afflicted" or ", not afflicted"))
end

local function OnEnter(self)
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local info = Known()
	if info and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(info.row.spell)
	elseif info then
		tip:AddLine(info.name, 1, 1, 1)
	end
	tip:AddLine(L["Manners: a left click here casts it, as its key does. The prompt's own key keeps to buffs."], 0.75, 0.75, 0.75, true)
	tip:Show()
end

local function OnLeave()
	local tip = _G.GameTooltip
	if tip then tip:Hide() end
end

-- Runs in the restricted environment: shown for the fight, hidden after.
local SNIPPET = [=[
	local wotf = self:GetFrameRef("wotf")
	if not wotf then return end
	if newstate == "fight" and self:GetAttribute("manners-on") then
		wotf:Show(true)
	else
		wotf:Hide(true)
	end
]=]

-- Made the first time it is wanted, out of combat: a login or a /reload in a
-- fight makes it at the first moment after.
function BreakFree:Create()
	if button or InCombatLockdown() then return end
	button = CreateFrame("Button", "MannersBreakFree", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:RegisterForClicks("AnyDown")
	icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:SetTexture(FALLBACK_ICON)
	glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
	glow:SetVertexColor(1, 0.82, 0.2)
	glow:Hide()
	pulse = glow:CreateAnimationGroup()
	if type(pulse.SetLooping) == "function" then pulse:SetLooping("BOUNCE") end
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.45)
	nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 4)
	nameText:SetText("")
	keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -3)
	keyText:SetText("")
	local okC, made = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown = okC and made or { SetCooldown = function() end }
	if okC then cooldown:SetAllPoints(button) end
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	-- Only the left button casts: every other one is told to do nothing, the
	-- modifier-prefixed lookups too (Prompt/Macro.lua says why).
	for index = 2, 31 do
		if index <= 5 then button:SetAttribute("type" .. index, "none") end
		button:SetAttribute("*type" .. index, "none")
	end
	button:SetScript("PreClick", PreClick)
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)
	button:Hide()
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made2 = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made2) == "table" and type(made2.SetFrameRef) == "function" then
			made2:SetFrameRef("wotf", button)
			made2:SetAttribute("manners-on", false)
			made2:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made2, STATE, DRIVER)
			header = made2
		end
	end
end

-- On every scan (Core.lua, TickBody) and as a fight ends (Release). Out of
-- combat only: in one the driver has it, and Lua paints its regions alone.
function BreakFree:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	local info = Known()
	if not BreakFree.Applies(db) then
		if button then
			Disarm()
			if header and header:GetAttribute("manners-on") then header:SetAttribute("manners-on", false) end
			if button:IsShown() then button:Hide() end
		end
		return
	end
	if not button then self:Create() end
	if not button then return end
	Place(db.prompt)
	Arm(info.name)
	if header then
		if header:GetAttribute("manners-on") ~= true then header:SetAttribute("manners-on", true) end
		-- The next pull is a change whatever the driver last read.
		if header:GetAttribute("state-" .. STATE) ~= "peace" then header:SetAttribute("state-" .. STATE, "peace") end
	end
	-- At rest out of a fight; the driver shows it at the pull.
	if button:IsShown() then button:Hide() end
	-- The key cannot change in a fight (SetBinding is refused there), so it
	-- is read here.
	local key = type(GetBindingKey) == "function" and GetBindingKey(BreakFree.COMMAND) or nil
	keyLabel = type(key) == "string" and key ~= "" and key or nil
	Paint()
end

-- Whether a scan has anything to do here: out of a fight, with the ability
-- or a button to take down. With neither, a scan pays nothing for it.
function BreakFree:Wanted()
	return (button ~= nil or caps.breakFree ~= nil) and not InCombatLockdown()
end

-- PLAYER_REGEN_ENABLED, out of lockdown, before the combat release's repaint
-- (Core.lua), which paints the prompt's own lines and icon over the fight's
-- break-free line: the button taken down and its driver put back to peace
-- even while the client's combat flag still runs late, and armed and placed
-- for the next fight.
function BreakFree:Release()
	promptPainted = false
	self:Refresh()
end

---------------------------------------------------------------------------
-- the prompt, when it is on the screen
---------------------------------------------------------------------------

-- From Prompt/Refresh.lua's combat branch, after it painted the hold, in both
-- of its arms (somebody on the button, or nobody): while you are afflicted and
-- the spell is ready, the panel names it and the key that casts it, and the
-- hold's dim comes off. Art only. Nothing when the prompt is off the screen
-- (the button beside it says it all), and the icon put back after.
function BreakFree.PaintPrompt(prompt, p)
	local info = Known()
	local want = afflicted and info ~= nil and button ~= nil and BreakFree.Applies()
		and R.button:IsShown() and not prompt:HiddenForFight() and Ready(GetTime())
	if not want then
		if promptPainted then
			promptPainted = false
			if p.showIcon and R.icon and S.current then R.icon:SetTexture(EntryIcon(S.current)) end
		end
		return false
	end
	promptPainted = true
	if p.showIcon and R.icon then R.icon:SetTexture(info.icon) end
	SetLine(R.nameText, "|cffffd100" .. L["Break free: %s"]:format(info.name) .. "|r")
	S.outcomePainted = nil
	if R.subText:IsShown() then
		SetLine(R.subText, keyLabel and L["press %s to break free"]:format(keyLabel)
			or L["click the button beside the prompt to break free"])
	end
	prompt:PaintAccent("owed")
	prompt:SetCombatHold(false)
	return true
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

local Recheck

local function Changed(was)
	Paint()
	if was ~= afflicted and InCombatLockdown() then ns.Guard("break free", Prompt.Refresh, Prompt) end
	-- Asked again each second while it lasts: an effect can end with no event
	-- this client sends.
	if afflicted and not recheckDue and C_Timer and C_Timer.After then
		recheckDue = true
		C_Timer.After(1, Recheck)
	end
end

Recheck = function()
	recheckDue = false
	ns.Guard("break free", function()
		local was = afflicted
		Read()
		Changed(was)
	end)
end

local function OnEvent(event, unit, _, spellId)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" then return end
		local now = GetTime()
		if not (waitUntil and now <= waitUntil) then
			BreakFree.frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
			waitUntil = nil
			return
		end
		local info = Known()
		local id = plain(spellId)
		if not info or (id ~= nil and id ~= info.row.spell) then return end
		-- Our press went out: the cooldown it began, by the client's figure
		-- where it is plain, else the spell's own length.
		local left = CooldownLeft(info.row.spell, now)
		readyAt = now + ((left and left > 1.5) and left or info.row.cooldown)
		waitUntil = nil
		BreakFree.frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		ns.Trail("fight", "break free went out: " .. tostring(info.name))
		Changed(afflicted)
		if InCombatLockdown() then ns.Guard("break free", Prompt.Refresh, Prompt) end
		return
	end
	if not Known() then return end
	local was = afflicted
	local kind, how = Read()
	if event == "LOSS_OF_CONTROL_ADDED" then
		lastLoss = { kind = kind or "none", how = how or "plain", at = GetTime() }
		ns.Trail("fight", ("loss of control: %s (%s)%s"):format(tostring(kind or "none"), tostring(how or "plain"),
			afflicted and ", break free lights up" or ""))
	elseif event == "PLAYER_CONTROL_LOST" and how == "no API" then
		lastLoss = { kind = "control lost", how = "no API", at = GetTime() }
		ns.Trail("fight", "control lost (no loss-of-control API on this client)"
			.. (afflicted and ", charmed: break free lights up" or ""))
	end
	Changed(was)
end

do
	local frame = CreateFrame("Frame")
	BreakFree.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) ns.Guard("break free", OnEvent, event, ...) end)
	frame:RegisterEvent("PLAYER_CONTROL_LOST")
	frame:RegisterEvent("PLAYER_CONTROL_GAINED")
	-- Registered only where the client has the API: an unknown event throws.
	if type(_G.C_LossOfControl) == "table" then
		frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
		frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
	end
end

-- Whether a press of this button came within the moment its own cast event
-- answers in: Clicks.lua's SettlePendingClick settles nothing then.
function BreakFree.JustPressed(now)
	return pressAt ~= nil and (now or GetTime()) - pressAt <= PRESS_SECONDS
end

---------------------------------------------------------------------------
-- for /manners debug, the full check-up and /manners selftest launch
---------------------------------------------------------------------------

function ns.BreakFreeLines()
	local out = {}
	local info = Known()
	local race = plain(select(2, UnitRace("player")))
	if not info then
		local row
		for _, r in ipairs(ABILITIES) do if r.race == race then row = r end end
		-- Nothing at all for a character no row is for.
		if row then
			out[1] = ("break free: spell %d not known yet (race %s), nothing armed"):format(row.spell, tostring(race))
		end
		return out
	end
	local db = Profile()
	local api = _G.C_LossOfControl
	local shape = type(api) ~= "table" and "no API"
		or (type(api.GetActiveLossOfControlData) == "function" and "data table")
		or (type(api.GetEventInfo) == "function" and "event info") or "no API"
	out[#out + 1] = ("break free: %s found (spell %d); switch %s; loss-of-control API: %s"):format(info.name,
		info.row.spell, (db and db.prompt.breakFree ~= false) and "on" or "off", shape)
	local armed = button and button:GetAttribute("macrotext1")
	out[#out + 1] = ("break free button: %s; key %s; driver %s; shown %s"):format(
		armed and ("armed (" .. tostring(armed) .. ")") or (button and "made, not armed" or "not made"),
		tostring(keyLabel or (type(GetBindingKey) == "function" and GetBindingKey(BreakFree.COMMAND)) or "none"),
		tostring(header and header:GetAttribute("state-" .. STATE) or "none"),
		tostring(button ~= nil and button:IsShown()))
	local full = type(_G.HasFullControl) == "function" and plain(_G.HasFullControl()) or nil
	out[#out + 1] = ("break free now: afflicted %s; ready %s; full control %s"):format(tostring(afflicted),
		tostring(Ready(GetTime())), tostring(full))
	if lastLoss then
		out[#out + 1] = ("last loss of control: %s (%s), %d s ago"):format(tostring(lastLoss.kind),
			tostring(lastLoss.how), math.floor(GetTime() - lastLoss.at))
	else
		out[#out + 1] = "last loss of control: none seen this session"
	end
	return out
end

function BreakFree:Button() return button end
function BreakFree:Header() return header end
-- What it shows: the spell's name over it, the key under it, the glow.
function BreakFree:Look()
	if not button then return nil end
	return { name = nameText, key = keyText, glow = glow, icon = icon }
end

-- The probe, and what it learns of breaking free, before anything asks.
do
	local probe = ns.ProbeCapabilities
	function ns.ProbeCapabilities(...)
		local result = probe(...)
		BreakFree.Learn()
		return result
	end
end
