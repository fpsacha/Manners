-- Manners -- your cure in a fight: a small secure button of its own beside the
-- prompt (or beside the break-free button), with a key of its own, that is
-- never on the screen for nothing. It is out of sight, at alpha 0 with no
-- tooltip and no highlight, for every fight, until Manners has SEEN in that
-- fight somebody it can help with your class's cure: a friendly player in
-- reach carrying a poison, a disease, a curse or a harmful spell your armed
-- cure takes off. Then it fades in naming the spell, who, and why, and it
-- fades out again the moment nobody needs it. Asked for on CurseForge ("Can I
-- set up decurse in combat while keeping buffs out of combat?"). Modelled on
-- Prompt/BreakFree.lua and Prompt/MendPet.lua, whose headers say why a fight
-- needs a button of its own: the prompt is locked by the lockdown and its key
-- keeps to buffs.
--
-- WHAT IT CASTS
--
-- One macro, written out of combat. Off Forever (caps.conditionalTargeting),
-- where the client parses a unit in a conditional:
--     /cast [@mouseover,help,nodead][help,nodead][@player] <cure>
-- so a press cures the player under your mouse, else a friendly target, else
-- you; a class with two cures (a druid, a priest or a shaman on the older
-- clients, a retail restoration druid) casts the second with Shift held, the
-- same clause under [mod:shift,...] in front. On Forever, where [@unit] does
-- not resolve, a bare /cast: it lands on a friendly target, else on you. No
-- /target, no spoken line, no hand-back; only the left button casts.
--
-- WHAT MOVES IN A FIGHT, AND WHAT DOES IT
--
-- Lua writes the macro, the place and the size out of combat only (the scan,
-- Core.lua's TickBody, and the fight's end, Release). Whether it is on the
-- screen at all is a state driver's, "[combat] fight; peace": it shows the
-- button at the pull at alpha 0 for every fight, and hides it after. Lua
-- never shows, hides, moves or arms it under the lockdown; it paints only its
-- own alpha, text and textures, which the client allows in a fight. A click
-- on its empty place in a fight still casts, since alpha 0 takes clicks and
-- the mouse of a protected frame cannot be changed in combat; its key casts
-- whether it is shown or not.
--
-- WHAT IT KNOWS, AND WHERE IT CANNOT
--
-- Secure code reads no aura and no cooldown, so who needs a cure is Lua's: the
-- harmful auras of you, your target and focus, and your party or raid, read in
-- the fight through ns.CureFightRead (Cures.lua), which leaves out what the
-- cure cannot lift: a debuff on the deny list, a debuff about to end, one the
-- client says you cannot remove, and a kind whose cure would also lift a
-- debuff never removed. Where the client withholds auras in a fight (Forever
-- and retail: caps.secretRestrictions) only you and your target are read, a
-- withheld aura or field is passed over and compared with nothing, and the
-- button is expected to stay out of sight; its key still casts (your friendly
-- target, else you). Nothing is decided by the client's name: if the client
-- hands your own debuffs back plain, the button shows. /manners debug counts
-- the reads and the withheld reads of the last fight, which settles it.
--
-- WHAT IT COSTS
--
-- Events only, and only between the pull and the release. UNIT_AURA is
-- filtered by a table lookup outside the Guard; for somebody not shown, only
-- an added harmful aura asks for a read, and so does any change on somebody
-- whose cure is held back by a debuff never removed (the debuff may go). Reads
-- are coalesced once each 0.1 s,
-- at most ten units a flush, one walk of the harmful list each. While anybody
-- is found needing a cure, a 0.5 s recheck asks reach and time again. Nothing
-- on the scan with the switch off and the button never made: Wanted reads one
-- field of the profile.
--
-- A press here lets the prompt's waiting press go (the pending-click guard),
-- as the break-free button does.

local _, ns = ...
local L = ns.L
local Prompt = ns.Prompt
local R = Prompt.regions
local InCombatLockdown = _G.InCombatLockdown
local GetTime = _G.GetTime
local plain, caps = ns.plain, ns.caps
local issecretvalue = _G.issecretvalue

local CureFight = {}
ns.CureFight = CureFight

-- What Bindings.xml declares.
CureFight.COMMAND = "CLICK MannersCureFight:LeftButton"
_G["BINDING_NAME_CLICK MannersCureFight:LeftButton"] = L["Cure in a fight"]

local STATE = "mannerscurefight"
local DRIVER = "[combat] fight; peace"
-- Between the prompt's (or the break-free button's) right edge and this button.
local GAP = 10
-- Reads are coalesced: one flush each tenth of a second, ten units at most.
local FLUSH = 0.1
-- While anybody needs a cure: reach and time asked again this often.
local RECHECK = 0.5
local FADE = 0.2
local MAX_READS = 10
-- How long after a press of this button its spell going out is waited for.
local SUCCEED_SECONDS = 1
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local FIGHT_EVENTS = { "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED" }

local RAID, PARTY = {}, {}
for i = 1, 40 do RAID[i] = "raid" .. i end
for i = 1, 4 do PARTY[i] = "party" .. i end

local button, header, icon, glow, pulse, nameText, keyText, cooldown, fader
local armedMacro, armedSpells, armedTwo, armedKinds, placedKey, paintedKey, keyLabel
local placedBeside = false
local dirtyRefresh, settledOn, placedIcon, placedScale = true, nil, nil, nil
-- In a fight: the tokens read, those waiting for a read, and who needs a cure
-- ([token] = { kind, debuff, ends, guid, name, spell }). `held`: tokens whose
-- read found a kind the cure could take off, held back by a debuff never
-- removed (or one that could not be read); that debuff going asks for a read.
local watched, dirty, needy, held = {}, {}, {}, {}
local flushDue, recheckDue = false, false
local visible, fadeFrom, fadeTo, fadeAt, shownAt = false, 0, 0, 0, nil
local waitUntil
-- The last fight, for /manners debug.
local last = { reads = 0, secret = 0, seen = 0, shownFor = 0 }
local reasonOf, seenGuid = {}, {}
local Paint, Flush

local function Profile()
	return ns.db and ns.db.profile
end

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Whether this character has a cure to offer in a fight and the switch is on.
function CureFight.Applies(db)
	db = db or Profile()
	if not (db ~= nil and db.enabled == true and db.prompt.cureFight == true) then return false end
	if not ns.ClassHasCures() then return false end
	local list = ns.CureFightSpells()
	return list ~= nil and list[1] ~= nil
end

local function Clause(name, shift)
	local m = shift and "mod:shift," or ""
	if caps.conditionalTargeting then
		return ("[%s@mouseover,help,nodead][%shelp,nodead][%s@player] %s"):format(m, m, m, name)
	end
	return (shift and "[mod:shift] " or "") .. name
end

-- Two spells only while Shift is free to choose between them: a key bound
-- with Shift in it would always cast the second.
local function MacroFor(list)
	local one = "/cast " .. Clause(list[1].name, false)
	if not list[2] then return one, false end
	if keyLabel and keyLabel:upper():find("SHIFT%-") then return one, false end
	local both = "/cast " .. Clause(list[2].name, true) .. "; " .. Clause(list[1].name, false)
	if #both > ns.MACRO_LIMIT then return one, false end
	return both, true
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

-- The cure and nothing else: no target, no line, no other press.
local function Arm(macro)
	if macro == armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	armedMacro = macro
end

-- Beside the break-free button where there is one, else the prompt's right edge:
-- anchored to a frame (never a region: CLAUDE.md), the size of the prompt's icon.
local function Place(p)
	placedIcon, placedScale = p.iconSize, p.scale
	local size = math.floor(math.max(24, math.min(48, tonumber(p.iconSize) or 30)) * (tonumber(p.scale) or 1) + 0.5)
	local bf = ns.BreakFree
	local beside = bf and bf.Applies() and bf:Button() or nil
	placedBeside = beside ~= nil
	local key = size .. ":" .. tostring(placedBeside)
	if key == placedKey then return end
	placedKey = key
	button:ClearAllPoints()
	button:SetPoint("LEFT", beside or R.button, "RIGHT", GAP, 0)
	button:SetSize(size, size)
end

-- Out of sight or shown, by alpha and its own regions alone (the client lets
-- an addon change both in a fight). `ready`: the cure can be cast now, else
-- it is shown dim.
local function SetVisible(on, ready)
	local to = on and (ready and 1 or 0.6) or 0
	if on and not visible then shownAt = GetTime() end
	if not on and visible and shownAt then
		last.shownFor = last.shownFor + (GetTime() - shownAt)
		shownAt = nil
	end
	visible = on
	if on and ready then
		glow:Show()
		if pulse and not pulse:IsPlaying() then pulse:Play() end
	else
		if pulse then pulse:Stop() end
		glow:Hide()
	end
	if not on then
		nameText:SetText("")
		keyText:SetText("")
		if type(cooldown.Clear) == "function" then cooldown:Clear() end
	end
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

-- The cure's cooldown by the client's own figure: the seconds left and the
-- whole length, or 0, 0 where it gives none (in a fight on Forever its fields
-- are secret) or it is only the global cooldown. Called directly where no
-- value is withheld, protected where one may be.
local function CooldownLeft(id, now)
	local get = C_Spell and C_Spell.GetSpellCooldown
	local guarded = caps.secretRestrictions == true
	local start, duration
	if type(get) == "function" then
		local ok, info = true, nil
		if guarded then ok, info = pcall(get, id) else info = get(id) end
		if ok and type(info) == "table" then start, duration = plain(info.startTime), plain(info.duration) end
	elseif type(_G.GetSpellCooldown) == "function" then
		local ok, s, d = true, nil, nil
		if guarded then ok, s, d = pcall(_G.GetSpellCooldown, id) else s, d = _G.GetSpellCooldown(id) end
		if ok then start, duration = plain(s), plain(d) end
	end
	if type(start) ~= "number" or type(duration) ~= "number" or duration <= 1.5 then return 0, 0 end
	return math.max(0, start + duration - now), duration
end

local function OutOfMana(id)
	local check = C_Spell and C_Spell.IsSpellUsable
	if type(check) ~= "function" then check = _G.IsUsableSpell end
	if type(check) ~= "function" then return false end
	local usable, noMana
	if caps.secretRestrictions == true then
		usable, noMana = ns.safecall(check, id)
	else
		usable, noMana = check(id)
	end
	return plain(usable) == false and plain(noMana) == true
end

-- Somebody the cure could be cast at: you, or a friendly player who is alive
-- and connected. Every answer may be withheld, and a withheld one is no.
local function Eligible(unit)
	if plain(UnitExists(unit)) ~= true then return false end
	if unit ~= "player" then
		if plain(UnitIsPlayer(unit)) ~= true or plain(UnitCanAssist("player", unit)) ~= true then return false end
		if plain(UnitIsDeadOrGhost(unit)) == true or plain(UnitIsConnected(unit)) == false then return false end
	end
	return true
end

-- Where the client may withhold auras, only you and your target are read
-- (the group would come back withheld too). In a raid your own raid token is
-- left out: UNIT_AURA comes for it and for "player" alike.
local function Watch()
	wipe(watched)
	watched.player, watched.target, watched.focus = true, true, true
	if caps.secretRestrictions == true then
		watched.focus = nil
		return
	end
	local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
	if plain(IsInRaid and IsInRaid()) == true then
		for i = 1, math.min(n, 40) do
			if plain(UnitIsUnit(RAID[i], "player")) ~= true then watched[RAID[i]] = true end
		end
	else
		for i = 1, math.min(n - 1, 4) do watched[PARTY[i]] = true end
	end
end

local function Schedule()
	if flushDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	flushDue = true
	timer.After(FLUSH, function() ns.Guard("cure in a fight", Flush) end)
end

local function Recheck()
	if recheckDue then return end
	local timer = _G.C_Timer
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	recheckDue = true
	timer.After(RECHECK, function()
		recheckDue = false
		paintedKey = nil
		ns.Guard("cure in a fight", Paint)
	end)
end

-- One unit's harmful auras, read now, and what the armed cure could take off.
local function ReadOne(unit, now)
	if not Eligible(unit) then
		needy[unit] = nil
		held[unit] = nil
		return
	end
	local kind, debuff, ends, secret, back
	if caps.secretRestrictions == true then
		local ok, k, d, e, s, h = pcall(ns.CureFightRead, unit, now, armedKinds)
		if ok then kind, debuff, ends, secret, back = k, d, e, s, h else secret = true end
	else
		kind, debuff, ends, secret, back = ns.CureFightRead(unit, now, armedKinds)
	end
	last.reads = last.reads + 1
	if secret then last.secret = last.secret + 1 end
	local spell = kind and ((armedSpells[1].kinds[kind] and armedSpells[1]) or (armedTwo and armedSpells[2].kinds[kind] and armedSpells[2])) or nil
	if not spell then
		needy[unit] = nil
		held[unit] = back == true or nil
		return
	end
	held[unit] = nil
	local rec = needy[unit]
	if not rec then
		rec = {}
		needy[unit] = rec
		last.seen = last.seen + 1
	end
	rec.kind, rec.debuff, rec.ends, rec.spell = kind, debuff, ends, spell
	rec.guid = plain(UnitGUID(unit))
	rec.name = ns.UnitFullName(unit) or plain(UnitName(unit))
end

Flush = function()
	flushDue = false
	if not InCombatLockdown() then return end
	local now, reads = GetTime(), 0
	for unit in pairs(dirty) do
		if reads >= MAX_READS then break end
		dirty[unit] = nil
		reads = reads + 1
		if watched[unit] then ReadOne(unit, now) end
	end
	if next(dirty) then Schedule() end
	Paint()
end

-- Who to show: your target, then you, then a tank, then whoever's debuff
-- lasts longest; one person under two tokens once. A debuff whose time is
-- up is dropped and read again (it may have been renewed with no event).
local function Pick(now)
	wipe(seenGuid)
	local best, bestRank, bestEnds, count, expired = nil, nil, nil, 0, false
	for unit, rec in pairs(needy) do
		local key = rec.guid or unit
		if rec.ends - now <= 0 then
			needy[unit] = nil
			dirty[unit] = true
			expired = true
		elseif not seenGuid[key]
			and (unit == "player" or ns.InRange(unit, rec.spell.cure) ~= false) then
			seenGuid[key] = true
			count = count + 1
			local rank = 4
			if unit == "target" or plain(UnitIsUnit(unit, "target")) == true then rank = 1
			elseif unit == "player" or plain(UnitIsUnit(unit, "player")) == true then rank = 2
			elseif ns.IsTankUnit(unit) then rank = 3 end
			if not best or rank < bestRank or (rank == bestRank and rec.ends > bestEnds) then
				best, bestRank, bestEnds = unit, rank, rec.ends
			end
		end
	end
	if expired then Schedule() end
	return best, count
end

-- What a press would do, in the player's words.
local function KeyLine(unit, spell)
	local shift = armedTwo and spell == armedSpells[2]
	local canAssist = plain(UnitCanAssist("player", "target")) == true
	-- Where the macro has [nodead] a dead friend is passed over and the press
	-- lands on you; Forever's bare /cast does go to them.
	local friendTarget = canAssist and not (caps.conditionalTargeting and plain(UnitIsDeadOrGhost("target")) == true)
	local hostileTarget = plain(UnitExists("target")) == true and not canAssist
	local mine = unit == "player" or plain(UnitIsUnit(unit, "player")) == true
	local key = keyLabel and (shift and L["Shift-%s"]:format(keyLabel) or keyLabel)
	if unit == "target" or plain(UnitIsUnit(unit, "target")) == true then
		if key then return L["press %s to cure your target"]:format(key) end
		return shift and L["shift-click to cure your target"] or L["click to cure your target"]
	end
	-- On Forever a bare cast of a spell that also hits enemies goes to a hostile target.
	local selfLands = not friendTarget and not (hostileTarget and spell.anyTarget and not caps.conditionalTargeting)
	if mine and selfLands then
		if key then return L["press %s to cure yourself"]:format(key) end
		return shift and L["shift-click to cure yourself"] or L["click to cure yourself"]
	end
	local who = mine and L["yourself"] or ns.ShortName(tostring(needy[unit].name))
	if caps.conditionalTargeting then
		if key then return L["point at %s and press %s"]:format(who, key) end
		return (shift and L["point at %s and shift-click"] or L["point at %s and click"]):format(who)
	end
	if key then return L["target %s and press %s"]:format(who, key) end
	return (shift and L["target %s and shift-click"] or L["target %s and click"]):format(who)
end

-- Its own regions and its alpha. Answers whether somebody needs a cure.
Paint = function()
	if not button then return false end
	local fighting = InCombatLockdown()
	local now = GetTime()
	local unit, count
	if fighting then unit, count = Pick(now) end
	-- Reach and time are asked again while anybody needs a cure, shown or not.
	if fighting and next(needy) then Recheck() end
	local rec = unit and needy[unit]
	if not rec then
		paintedKey = nil
		SetVisible(false)
		return false
	end
	local spell = rec.spell
	local id = spell.cure.info and spell.cure.info.topRank
	local left, length = 0, 0
	if id then left, length = CooldownLeft(id, now) end
	local mana = id ~= nil and OutOfMana(id)
	local ready = left <= 0 and not mana
	local key = unit .. ":" .. rec.kind .. ":" .. tostring(ready) .. ":" .. count .. ":" .. tostring(keyLabel)
		.. ":" .. tostring(plain(UnitGUID("target")))
	if key ~= paintedKey then
		paintedKey = key
		icon:SetTexture(spell.cure.info and spell.cure.info.icon or FALLBACK_ICON)
		local who = unit == "player" and L["You"] or ns.ShortName(tostring(rec.name))
		if count > 1 then who = L["%s, and %d more"]:format(who, count - 1) end
		reasonOf.cure = rec.kind
		nameText:SetText("|cffffd100" .. tostring(spell.name) .. "|r: " .. who .. " (" .. ns.CureReason(reasonOf) .. ")")
		if ready then
			keyText:SetText(KeyLine(unit, spell))
		elseif left > 0 then
			keyText:SetText(L["your cure is cooling down"])
		else
			keyText:SetText(L["not enough mana for the cure"])
		end
		if left > 0 and type(cooldown.SetCooldown) == "function" then cooldown:SetCooldown(now + left - length, length) end
	end
	SetVisible(true, ready)
	return true
end

-- A press, by its key or a left click: in a fight too. The press the prompt
-- filed is not this one's, so it is let go with its own reason.
local function PreClick(_, mouse)
	if mouse ~= "LeftButton" then return end
	waitUntil = GetTime() + SUCCEED_SECONDS
	local pending = ns.pendingClick
	if pending and ns.ExpirePendingClick then ns.ExpirePendingClick(pending, L["you cured somebody instead"]) end
	ns.Trail("press", "pressed: cure in a fight")
end

-- No tooltip while it is out of sight.
local function OnEnter(self)
	if not visible then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local first = armedSpells and armedSpells[1]
	local id = first and first.cure.info and first.cure.info.topRank
	if id and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(id)
	elseif first then
		tip:AddLine(tostring(first.name), 1, 1, 1)
	end
	tip:AddLine(caps.conditionalTargeting and L["Casts at the player under your mouse, else your target, else you."]
		or L["Casts at your target when it is a friend, else at you."], 0.75, 0.75, 0.75, true)
	if armedTwo then tip:AddLine(L["Hold Shift for %s."]:format(tostring(armedSpells[2].name)), 0.75, 0.75, 0.75, true) end
	tip:AddLine(L["Manners: a left click here casts it, as its key does."], 0.75, 0.75, 0.75, true)
	tip:Show()
end

local function OnLeave()
	local tip = _G.GameTooltip
	if tip then tip:Hide() end
end

-- Runs in the restricted environment: shown for the fight, hidden after.
local SNIPPET = [=[
	local cure = self:GetFrameRef("cure")
	if not cure then return end
	if newstate == "fight" and self:GetAttribute("manners-on") then
		cure:Show(true)
	else
		cure:Hide(true)
	end
]=]

-- Made the first time it is wanted, out of combat.
function CureFight:Create()
	if button or InCombatLockdown() then return end
	button = CreateFrame("Button", "MannersCureFight", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:RegisterForClicks("AnyDown")
	-- A key press is a down click: without this the client takes it as neither
	-- the action nor a release while ActionButtonUseKeyDown is off (Panel.lua).
	button:SetAttribute("pressAndHoldAction", true)
	button:SetAlpha(0)
	-- No click until Refresh has decided (SetMouse).
	button:EnableMouse(false)
	icon =button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local first = ns.CureFightSpells()
	first = first and first[1]
	icon:SetTexture(first and first.cure.info and first.cure.info.icon or FALLBACK_ICON)
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
	-- Its two lines go to its right, clear of a break-free button's lines.
	nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("BOTTOMLEFT", button, "RIGHT", 4, 1)
	nameText:SetText("")
	keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("TOPLEFT", button, "RIGHT", 4, -1)
	keyText:SetText("")
	local okC, made = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown = okC and made or { SetCooldown = function() end }
	if okC then cooldown:SetAllPoints(button) end
	-- The highlight is a region of the button: it takes the button's alpha, so
	-- at alpha 0 nothing of it shows.
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
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
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made2 = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made2) == "table" and type(made2.SetFrameRef) == "function" then
			made2:SetFrameRef("cure", button)
			made2:SetAttribute("manners-on", false)
			made2:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made2, STATE, DRIVER)
			header = made2
		end
	end
	local frame = CureFight.frame
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("UPDATE_BINDINGS")
end

-- The key it is bound to; read out of a fight and at every pull, before the lockdown.
local function ReadKey()
	local key = type(GetBindingKey) == "function" and GetBindingKey(CureFight.COMMAND) or nil
	keyLabel = type(key) == "string" and key ~= "" and key or nil
end

-- Whether the button takes a click: only when no key is bound (then a click is
-- the only way to cast it). With a key it is out of sight or only just in it,
-- and a click beside the prompt must reach the world behind. The client refuses
-- EnableMouse on a protected frame under the lockdown, so only out of one: at
-- Refresh and at the pull, before it.
local function SetMouse()
	if not button or InCombatLockdown() then return end
	button:EnableMouse(keyLabel == nil)
end

-- From a scan (Core.lua, TickBody) when Wanted says something changed, and as a
-- fight ends (Release). Out of combat only.
function CureFight:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	if not CureFight.Applies(db) then
		if button then
			Disarm()
			if header and header:GetAttribute("manners-on") then header:SetAttribute("manners-on", false) end
			if button:IsShown() then button:Hide() end
		end
		armedSpells, armedTwo, armedKinds = nil, false, nil
		settledOn, dirtyRefresh = false, false
		return
	end
	if not button then self:Create() end
	if not button then return end
	ReadKey()
	SetMouse()
	local list = ns.CureFightSpells()
	local macro, two = MacroFor(list)
	armedSpells, armedTwo = list, two
	-- The kinds a press can cast: the second spell's only while Shift is free.
	armedKinds = {}
	for kind in pairs(list[1].kinds) do armedKinds[kind] = true end
	if two then
		for kind in pairs(list[2].kinds) do armedKinds[kind] = true end
	end
	Place(db.prompt)
	Arm(macro)
	if header then
		if header:GetAttribute("manners-on") ~= true then header:SetAttribute("manners-on", true) end
		if header:GetAttribute("state-" .. STATE) ~= "peace" then header:SetAttribute("state-" .. STATE, "peace") end
	end
	if button:IsShown() then button:Hide() end
	paintedKey = nil
	SetVisible(false)
	button:SetAlpha(0)
	fadeTo = 0
	fader:Hide()
	settledOn, dirtyRefresh = true, false
end

-- Whether a scan has anything to do here. With the switch off and nothing
-- made, one field of the profile and no question to the client.
function CureFight:Wanted()
	local db = Profile()
	if not db then return false end
	if button == nil and db.prompt.cureFight ~= true then return false end
	if InCombatLockdown() then return false end
	if dirtyRefresh then return true end
	local on = CureFight.Applies(db) and true or false
	if on ~= settledOn then return true end
	if not on then return false end
	if ns.CureFightSpells() ~= armedSpells then return true end
	local p = db.prompt
	if p.iconSize ~= placedIcon or p.scale ~= placedScale then return true end
	-- `or nil`: Applies answers false, which is not nil.
	local bf = ns.BreakFree
	local beside = bf and bf.Applies() and bf:Button() or nil
	return (beside ~= nil) ~= placedBeside
end

-- The pull, before the lockdown: who is read, and the fight's events.
local function Pull()
	if not (settledOn and button) then return end
	ReadKey()
	SetMouse()
	last.reads, last.secret, last.seen, last.shownFor = 0, 0, 0, 0
	wipe(needy)
	wipe(dirty)
	wipe(held)
	Watch()
	for token in pairs(watched) do dirty[token] = true end
	local frame = CureFight.frame
	for _, event in ipairs(FIGHT_EVENTS) do frame:RegisterEvent(event) end
	paintedKey = nil
	SetVisible(false)
	button:SetAlpha(0)
	fadeTo = 0
	fader:Hide()
	Schedule()
end

-- PLAYER_REGEN_ENABLED, out of lockdown: the events dropped, the button taken
-- down and armed again.
function CureFight:Release()
	local frame = CureFight.frame
	for _, event in ipairs(FIGHT_EVENTS) do frame:UnregisterEvent(event) end
	wipe(needy)
	wipe(dirty)
	wipe(held)
	paintedKey = nil
	if button then
		SetVisible(false)
		button:SetAlpha(0)
		fadeTo = 0
		fader:Hide()
	end
	dirtyRefresh = true
	self:Refresh()
end

-- UNIT_AURA, outside the Guard: a table lookup for anybody not watched, and
-- for somebody not shown (and not held back by a debuff never removed) only an
-- added harmful aura (or a full update, or no payload) asks for a read.
local function OnAura(unit, info)
	if not watched[unit] then return end
	if not needy[unit] and not held[unit] and type(info) == "table" and not Secret(info) and plain(info.isFullUpdate) ~= true then
		local added = info.addedAuras
		if type(added) ~= "table" or Secret(added) then return end
		local harmful = false
		for i = 1, #added do
			local aura = added[i]
			if Secret(aura) or type(aura) ~= "table" or plain(aura.isHarmful) ~= false then
				harmful = true
				break
			end
		end
		if not harmful then return end
	end
	dirty[unit] = true
	Schedule()
end

local function OnEvent(event, unit)
	if event == "PLAYER_REGEN_DISABLED" then
		Pull()
	elseif event == "UPDATE_BINDINGS" then
		if not InCombatLockdown() then dirtyRefresh = true end
	elseif event == "PLAYER_TARGET_CHANGED" then
		dirty.target = true
		paintedKey = nil
		Schedule()
	elseif event == "PLAYER_FOCUS_CHANGED" then
		if watched.focus then dirty.focus = true Schedule() end
	elseif event == "GROUP_ROSTER_UPDATE" then
		Watch()
		for token in pairs(needy) do
			if not watched[token] then needy[token] = nil end
		end
		for token in pairs(held) do
			if not watched[token] then held[token] = nil end
		end
		for token in pairs(watched) do dirty[token] = true end
		Schedule()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not (waitUntil and GetTime() <= waitUntil) then return end
		waitUntil = nil
		paintedKey = nil
		Paint()
		ns.Trail("fight", "cure in a fight went out")
	end
end

do
	local frame = CreateFrame("Frame")
	CureFight.frame = frame
	frame:SetScript("OnEvent", function(_, event, unit, info)
		-- The busiest event of a raid's fight: a table lookup, outside the Guard.
		if event == "UNIT_AURA" then return OnAura(unit, info) end
		if event == "UNIT_SPELLCAST_SUCCEEDED" and unit ~= "player" then return end
		ns.Guard("cure in a fight", OnEvent, event, unit)
	end)
end

-- For /manners debug.
function ns.CureFightLines()
	local out = {}
	if not ns.ClassHasCures() then return out end
	local db = Profile()
	local list = ns.CureFightSpells()
	local spells = (list and list[1]) and (tostring(list[1].name) .. (list[2] and (", Shift " .. tostring(list[2].name)) or "")) or "none learned"
	local armed = button and button:GetAttribute("macrotext1")
	out[1] = ("cure in a fight: switch %s; spells %s; %s; key %s; driver %s; shown %s"):format(
		(db and db.prompt.cureFight == true) and "on" or "off", spells,
		armed and ("armed (" .. tostring(armed) .. ")") or (button and "made, not armed" or "not made"),
		tostring(keyLabel or (type(GetBindingKey) == "function" and GetBindingKey(CureFight.COMMAND)) or "none"),
		tostring(header and header:GetAttribute("state-" .. STATE) or "none"),
		tostring(button ~= nil and button:IsShown()))
	out[2] = ("cure in a fight, last fight: %d reads, %d withheld, %d needing a cure, seen for %d s"):format(
		last.reads, last.secret, last.seen, math.floor(last.shownFor))
	return out
end

function CureFight:Button() return button end
function CureFight:Header() return header end
-- What it shows: the spell's name and the key line, the glow, and where it is
-- fading to (alpha is the target; the fader walks the button there).
function CureFight:Look()
	if not button then return nil end
	return { name = nameText, key = keyText, glow = glow, icon = icon, alpha = fadeTo, fader = fader }
end
