-- Manners -- breaking free in a fight: a Forsaken's Will of the Forsaken on a
-- small secure button of its own beside the prompt, with a key of its own,
-- out of sight until you are feared, charmed or asleep and lit while the
-- spell is ready. Asked for by the author, a
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
-- state driver's, "[combat] fight; peace", as the consumables button's is
-- (Prompt/Supplies.lua): the snippet shows it at the pull and hides it after,
-- in the restricted environment. Lua never shows, hides, moves or arms it
-- under the lockdown, so nothing Manners itself chooses (a snooze, the prompt
-- off the screen at the pull) keeps it from being seen and pressed.
-- In a fight Lua paints only its own regions and its alpha, which the client
-- allows. The driver shows the button at the pull, but it is out of sight
-- there: alpha 0, no tooltip, the highlight a region that takes the alpha. It
-- is faded in (a plain OnUpdate, as Prompt/CureFight.lua's is) when you are
-- feared, charmed or asleep, lit while the spell is ready and dim (0.6) while
-- it cools down with the sweep, and out again after. With When the fight
-- buttons show at All fight (`prompt.fightButtons`) it sits dim (0.35) for
-- every fight, as before 1.11.34. The key casts either way: an armed button
-- fires by its binding at any alpha. A click is another matter: an invisible
-- button must not take one, so in the default setting its mouse is off (set
-- out of a fight, in Refresh and at the pull: the client refuses it under the
-- lockdown) and only the key casts; All fight, or no key bound, leaves the
-- click on. The prompt, when it is on the screen, says the same (PaintPrompt,
-- from Prompt/Refresh.lua's combat branch).
--
-- WHAT IT KNOWS
--
-- Whether you can break free: the probe's (caps.breakFree: the race by its
-- file name, the spell known), never asked per scan. Whether you need to: the
-- loss of control the client reports (C_LossOfControl, in either of its two
-- shapes), or UnitIsCharmed, read on the client's events and cached. A plain
-- read stays the authority (a plain stun with control lost is no reason). Where
-- the game withholds the answer (a secret type, record or count) or has no API
-- to ask, losing control of your character in the fight is the need itself:
-- PLAYER_CONTROL_LOST, or a LOSS_OF_CONTROL_ADDED whose type is secret, lights
-- it. That guess ends on PLAYER_CONTROL_GAINED, HasFullControl plainly true,
-- the fight's release, or UNSURE_SECONDS after the last such event where
-- HasFullControl cannot be read (GitHub issue 33). Whether it is ready: our
-- own press followed by the spell going out, else the client's own cooldown
-- where it is plain; unknown counts as ready, since a refused cast burns
-- nothing.
--
-- A press here lets the prompt's waiting press go (the pending-click guard):
-- pressed from habit while feared, the prompt files a press that never goes
-- out, and Will of the Forsaken's cast, with no target and a secret id in a
-- fight, would otherwise settle it as landed. The press is let go in the
-- PreClick, before that cast's own event; a prompt press made after it files
-- a record of its own, which its own cast event settles as any other.
--
-- WHAT A SCAN PAYS
--
-- Nothing on an idle scan: Wanted answers from a few plain fields, and the
-- work (the macro, the place, the key) is done only when something changed:
-- the probe, the switch, the size, the fight's end. The key is read again at
-- every pull, the moment it is shown.

local ns = assert(MannersAPI:ModuleContext("combat"), "Manners module API is missing")
if ns.BreakFree then return end
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
-- Forsaken); `breaks` the loss-of-control types it ends. Fear (by effect and
-- by mechanic, which the client reports under FEAR_MECHANIC), charm and sleep
-- only: a Horror (Death Coil) or a possession reported under another type
-- would light a two-minute cooldown up for nothing, so another type joins only
-- once the trail shows it on an effect this breaks. Later rows may carry a
-- class or an item instead of a race.
local ABILITIES = {
	{ key = "willoftheforsaken", spell = 7744, race = "Scourge",
		breaks = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, SLEEP = true }, cooldown = 120 },
}

local STATE = "mannersbreakfree"
-- How long the fade in and out takes.
local FADE = 0.2
local DRIVER = "[combat] fight; peace"
-- Between the prompt's right edge and this button: a mis-click casts it.
local GAP = 10
-- How long after a press of this button its spell going out is waited for.
local SUCCEED_SECONDS = 1
-- How long a loss of control the game would not name is taken as one, from the
-- last event that said control was lost, when HasFullControl cannot say.
local UNSURE_SECONDS = 10
-- The icon the client gives none for: Will of the Forsaken's own.
local FALLBACK_ICON = "Interface\\Icons\\Spell_Shadow_RaiseDead"
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"

local button, header, icon, glow, pulse, nameText, keyText, cooldown, fader
local armedMacro, placedKey, paintedKey
-- Whether the last paint was bright, and how often it turned bright this fight
-- (the fight summary on the trail).
local lit, litCount = false, 0
-- The alpha it is walking to (0: out of sight), where from and since when.
local fadeFrom, fadeTo, fadeAt = 0, 0, 0
-- Afflicted now (a type this breaks, or charmed), from the client's events.
local afflicted = false
-- When control was last lost (PLAYER_CONTROL_LOST, or a LOSS_OF_CONTROL_ADDED
-- whose type was secret), and whether `afflicted` is that guess alone: the
-- game withheld the type, or has no loss-of-control API, and control is gone.
local lostAt
local guessed = false
-- The last loss of control seen: { kind, how, at }; `how` is plain, secret or
-- no API.
local lastLoss
-- How long our own press is waited on, and the end of the cooldown it began.
local waitUntil, readyAt
-- Whether the prompt carries the break-free line now, the icon it had before
-- (for a prompt with nobody on it), and whether the prompt was last refreshed
-- for it lit.
local promptPainted = false
local iconBefore
local litShown = false
local recheckDue = false
local keyLabel
-- What the last Refresh settled: whether it applied, and the size it placed
-- by. `dirty` asks for one more (the probe, a fight's end, a first scan).
local dirty, settledOn, placedIcon, placedScale = true, nil, nil, nil

local function Profile()
	return ns.db and ns.db.profile
end

local function Active()
	return ns.ModuleActive and ns.ModuleActive("combat") == true
end

-- Whether the setting keeps the button dim in every fight (a plain field).
local function Always()
	local db = Profile()
	return db ~= nil and db.prompt.fightButtons == "always"
end

-- The race's file name ("Scourge"), or nil where the client has no UnitRace
-- or withholds the answer.
local function PlayerRace()
	local unitRace = _G.UnitRace
	if type(unitRace) ~= "function" then return nil end
	return plain(select(2, unitRace("player")))
end

local function Known()
	return caps.breakFree
end

-- Whether this character has a row, the switch is on and Manners is.
function BreakFree.Applies(db)
	db = db or Profile()
	if not (ns.ModuleActive and ns.ModuleActive("combat")) then return false end
	return caps.breakFree ~= nil and db ~= nil and db.enabled == true and db.prompt.breakFree ~= false
end

-- The probe's half (wrapped round ns.ProbeCapabilities at the end of this
-- file): the first row this character's race and spell book answer, and the
-- spell's name and icon, or nothing.
function BreakFree.Learn()
	caps.breakFree = nil
	dirty = true
	local race = PlayerRace()
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
		-- A record that is itself secret is handed back as it came, so the
		-- loop below says secret, not an empty plain loss of control.
		info = function(i)
			local data = api.GetActiveLossOfControlData(i)
			if type(plain(data)) ~= "table" then return data end
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
		elseif type(raw) ~= "nil" then
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
		afflicted, guessed = false, false
		return nil, nil
	end
	local hit, kind, how = ReadLoss(info.row)
	if not hit and info.row.breaks.CHARM and plain(UnitIsCharmed("player")) == true then
		hit = true
	end
	-- A plain read stays the authority. Only where the game withholds the type
	-- or has no API to ask, losing control of your character in the fight is
	-- the need: until control is plainly back, or nothing says it ended for
	-- UNSURE_SECONDS.
	guessed = false
	if not hit and lostAt and (how == "secret" or how == "no API") then
		local full
		if type(_G.HasFullControl) == "function" then full = plain(_G.HasFullControl()) end
		if full == false or (full == nil and GetTime() - lostAt <= UNSURE_SECONDS) then
			guessed = true
		else
			lostAt = nil
		end
	end
	afflicted = hit == true or guessed
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

-- The alpha walked to: out of sight (0), or the fade begun from where it is.
local function SetTo(to)
	if to == fadeTo then return end
	fadeFrom, fadeTo, fadeAt = button:GetAlpha(), to, GetTime()
	fader:Show()
end

local function Fade(self)
	local t = (GetTime() - fadeAt) / FADE
	if t >= 1 then
		button:SetAlpha(fadeTo)
		self:Hide()
	else
		button:SetAlpha(fadeFrom + (fadeTo - fadeFrom) * t)
	end
end

-- Its own regions and its alpha, which the client lets an addon change in a
-- fight. Out of sight unless afflicted (or All fight): bright while afflicted
-- and ready; dim, with the sweep while it cools. Answers whether it is lit.
local function Paint()
	if not button then return false end
	local info = Known()
	local now = GetTime()
	local bright = afflicted and info ~= nil and Ready(now)
	local cooling = readyAt ~= nil and now < readyAt
	local always = Always()
	local shown = always or afflicted
	local to = bright and 1 or (shown and (always and 0.35 or 0.6) or 0)
	local key = tostring(bright) .. ":" .. tostring(cooling and readyAt) .. ":" .. tostring(keyLabel)
		.. ":" .. tostring(info and info.name) .. ":" .. tostring(always) .. ":" .. tostring(to)
	if key == paintedKey then return bright end
	paintedKey = key
	if bright and not lit then litCount = litCount + 1 end
	lit = bright
	SetTo(to)
	if info then icon:SetTexture(info.icon) end
	if to == 0 then
		if pulse then pulse:Stop() end
		glow:Hide()
		nameText:SetText("")
		keyText:SetText("")
		if type(cooldown.Clear) == "function" then cooldown:Clear() end
		return bright
	end
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
	if type(cooldown.SetCooldown) ~= "function" then return bright end
	if cooling and info then
		cooldown:SetCooldown(readyAt - info.row.cooldown, info.row.cooldown)
	elseif type(cooldown.Clear) == "function" then
		cooldown:Clear()
	end
	return bright
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
	placedIcon, placedScale = p.iconSize, p.scale
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
-- own reason, here, before this press's own cast event can settle it.
local function PreClick(_, mouse)
	if mouse ~= "LeftButton" then return end
	waitUntil = GetTime() + SUCCEED_SECONDS
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you broke free instead"]) end
	BreakFree.frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	local info = Known()
	ns.Trail("press", "pressed: break free (" .. tostring(info and info.name) .. ")"
		.. (afflicted and ", afflicted" or ", not afflicted"))
end

local function OnEnter(self)
	-- Out of sight: nothing to say.
	if fadeTo == 0 then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local info = Known()
	if info and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(info.row.spell)
	elseif info then
		tip:AddLine(info.name, 1, 1, 1)
	end
	tip:AddLine(L["Manners: a left click here casts it, as its key does."], 0.75, 0.75, 0.75, true)
	ns.AddSettingsLine(tip, "appearance.breakFree")
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
	-- A key press is a down click: without this the client takes it as neither
	-- the action nor a release while ActionButtonUseKeyDown is off (Panel.lua).
	button:SetAttribute("pressAndHoldAction", true)
	button:SetAlpha(0)
	-- No click until Refresh has decided (SetMouse).
	button:EnableMouse(false)
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
	-- The highlight is a region of the button: it takes the button's alpha, so
	-- at alpha 0 nothing of it shows.
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
	fader = CreateFrame("Frame")
	fader:Hide()
	fader:SetScript("OnUpdate", Fade)
	fadeTo = 0
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

-- The key it is bound to, for its own lines and the prompt's. The key cannot
-- change in a fight (SetBinding is refused there), so it is read out of one:
-- here, and at every pull, before the lockdown.
local function ReadKey()
	local key = type(GetBindingKey) == "function" and GetBindingKey(BreakFree.COMMAND) or nil
	keyLabel = type(key) == "string" and key ~= "" and key or nil
end

-- Whether the button takes a click: all fight, or when no key is bound (then a
-- click is the only way to cast it). Otherwise it is out of sight or only just
-- in it, and a click beside the prompt must reach the world behind. The client
-- refuses EnableMouse on a protected frame under the lockdown, so only out of
-- one: at Refresh and at the pull, before it.
local function SetMouse()
	if not button or InCombatLockdown() then return end
	button:EnableMouse(Always() or keyLabel == nil)
end

-- From a scan (Core.lua, TickBody) when Wanted says something changed, and as
-- a fight ends (Release). Out of combat only: in one the driver has it, and
-- Lua paints its regions alone.
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
		settledOn, dirty = false, false
		return
	end
	if not button then self:Create() end
	if not button then return end
	local frame = BreakFree.frame
	if frame then
		frame:RegisterEvent("PLAYER_CONTROL_LOST")
		frame:RegisterEvent("PLAYER_CONTROL_GAINED")
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		if type(_G.C_LossOfControl) == "table" then
			frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
			frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
		end
	end
	Place(db.prompt)
	Arm(info.name)
	if header then
		if header:GetAttribute("manners-on") ~= true then header:SetAttribute("manners-on", true) end
		-- The next pull is a change whatever the driver last read.
		if header:GetAttribute("state-" .. STATE) ~= "peace" then header:SetAttribute("state-" .. STATE, "peace") end
	end
	-- At rest out of a fight; the driver shows it at the pull.
	if button:IsShown() then button:Hide() end
	ReadKey()
	SetMouse()
	Paint()
	-- A fight never opens at the last fight's alpha: the button is hidden here.
	button:SetAlpha(fadeTo)
	fader:Hide()
	settledOn, dirty = true, false
end

-- Whether a scan has anything to do here: out of a fight, and only when
-- something changed since the last Refresh (the probe, a fight's end, the
-- switch, Manners itself, the prompt's size). Plain field reads, no pcall,
-- no client call beyond the lockdown's: an idle scan pays nothing for it,
-- with the switch on or off.
function BreakFree:Wanted()
	-- Nobody without the ability, and no button to take down: nothing ever.
	if button == nil and caps.breakFree == nil then return false end
	if InCombatLockdown() then return false end
	if dirty then return true end
	local db = Profile()
	if not db then return false end
	local on = BreakFree.Applies(db)
	if on ~= settledOn then return true end
	if not on then return false end
	local p = db.prompt
	return p.iconSize ~= placedIcon or p.scale ~= placedScale
end

-- PLAYER_REGEN_ENABLED, out of lockdown, before the combat release's repaint
-- (Core.lua), which paints the prompt's own lines and icon over the fight's
-- break-free line: the button taken down and its driver put back to peace
-- even while the client's combat flag still runs late, and armed and placed
-- for the next fight.
function BreakFree:Release()
	promptPainted, iconBefore, litShown = false, nil, false
	-- A guess ends with the fight.
	lostAt, guessed = nil, false
	Read()
	dirty = true
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
		and R.button:IsShown() and Ready(GetTime())
	if not want then
		if promptPainted then
			promptPainted = false
			-- The person's icon when somebody is on it; with nobody (the rota
			-- gone round once, the held panel) the icon it had before, since
			-- neither of those paints one of its own.
			if p.showIcon and R.icon then
				if S.current then
					R.icon:SetTexture(EntryIcon(S.current))
				else
					R.icon:SetTexture(iconBefore)
				end
			end
			iconBefore = nil
		end
		return false
	end
	if not promptPainted and R.icon and type(R.icon.GetTexture) == "function" then
		iconBefore = R.icon:GetTexture()
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

-- The prompt is repainted when you become afflicted or stop, and when the
-- button lights up or goes dim while you stay so (the cooldown running out
-- mid-fear), so the two say the same.
local function Changed(was)
	local lit = Paint()
	if (was ~= afflicted or lit ~= litShown) and InCombatLockdown() then
		ns.Guard("break free", Prompt.Refresh, Prompt)
	end
	litShown = lit
	-- Asked again each second while it lasts: an effect can end with no event
	-- this client sends.
	if afflicted and not recheckDue and C_Timer and C_Timer.After then
		recheckDue = true
		C_Timer.After(1, Recheck)
	end
end

Recheck = function()
	recheckDue = false
	if not Active() then return end
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
	-- The pull, before the lockdown: the key as it stands for the fight.
	if event == "PLAYER_REGEN_DISABLED" then
		ReadKey()
		SetMouse()
		lit, litCount = false, 0
		paintedKey = nil
		Paint()
		-- No button where the switch is off or Manners is: nothing to fade.
		if button then
			button:SetAlpha(fadeTo)
			fader:Hide()
		end
		return
	end
	if event == "PLAYER_CONTROL_LOST" then
		lostAt = GetTime()
	elseif event == "PLAYER_CONTROL_GAINED" then
		lostAt = nil
	end
	local was = afflicted
	local kind, how = Read()
	-- A fresh report the game would not name starts the guess again, also while
	-- one is running: a second fear inside the first guess.
	if event == "LOSS_OF_CONTROL_ADDED" and how == "secret" and (not afflicted or guessed) then
		lostAt = GetTime()
		kind, how = Read()
	end
	if event == "LOSS_OF_CONTROL_ADDED" then
		lastLoss = { kind = kind or "none", how = how or "plain", at = GetTime() }
		ns.Trail("fight", ("loss of control: %s (%s)%s%s"):format(tostring(kind or "none"), tostring(how or "plain"),
			afflicted and ", break free lights up" or "",
			guessed and ", by a loss of control the game would not name" or ""))
	elseif event == "PLAYER_CONTROL_LOST" and how == "no API" then
		lastLoss = { kind = "control lost", how = "no API", at = GetTime() }
		ns.Trail("fight", "control lost (no loss-of-control API on this client)"
			.. (afflicted and ", charmed: break free lights up" or "")
			.. (guessed and ", by a loss of control the game would not name" or ""))
	end
	Changed(was)
end

do
	local frame = CreateFrame("Frame")
	BreakFree.frame = frame
	frame:SetScript("OnEvent", function(_, event, ...) ns.Guard("break free", OnEvent, event, ...) end)
	frame:RegisterEvent("PLAYER_CONTROL_LOST")
	frame:RegisterEvent("PLAYER_CONTROL_GAINED")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	-- Registered only where the client has the API: an unknown event throws.
	if type(_G.C_LossOfControl) == "table" then
		frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
		frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
	end
end

---------------------------------------------------------------------------
-- for /manners debug, the full check-up and /manners selftest launch
---------------------------------------------------------------------------

function ns.BreakFreeLines()
	local out = {}
	local info = Known()
	local race = PlayerRace()
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
	out[#out + 1] = ("break free now: afflicted %s%s; ready %s; full control %s"):format(tostring(afflicted),
		guessed and " (a loss of control the game would not name)" or "", tostring(Ready(GetTime())), tostring(full))
	if lastLoss then
		out[#out + 1] = ("last loss of control: %s (%s), %d s ago"):format(tostring(lastLoss.kind),
			tostring(lastLoss.how), math.floor(GetTime() - lastLoss.at))
	else
		out[#out + 1] = "last loss of control: none seen this session"
	end
	return out
end

-- How often the button turned bright in the last fight, and what it stands on
-- now, for the fight summary and the Mark this moment line.
function BreakFree.FightLit() return litCount end
function BreakFree.State()
	return { lit = lit, afflicted = afflicted, guessed = guessed, always = Always() }
end

function BreakFree:Button() return button end
function BreakFree:Header() return header end
-- What it shows: the spell's name over it, the key under it, the glow.
function BreakFree:Look()
	if not button then return nil end
	return { name = nameText, key = keyText, glow = glow, icon = icon, alpha = fadeTo, fader = fader }
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
