-- Manners -- your cure in a fight: a small secure button of its own beside the
-- prompt (or beside the break-free button), with a key of its own, that is
-- never on the screen for nothing. It is out of sight, at alpha 0 with no
-- tooltip and no highlight, for every fight, until Manners has DETECTED in that
-- fight somebody it can help with your class's cure: a friendly player in
-- reach carrying a poison, a disease, a curse or a harmful spell your armed
-- cure takes off. Then it fades in naming the spell, who, and why, and it
-- fades out again the moment nobody needs it. Asked for on CurseForge ("Can I
-- set up decurse in combat while keeping buffs out of combat?"). Modelled on
-- Prompt/BreakFree.lua and Prompt/MendPet.lua, whose headers say why a fight
-- needs a button of its own: the prompt is locked by the lockdown and its key
-- keeps to buffs.
--
-- WHAT IT CASTS, AND HOW MANY BUTTONS
--
-- One macro a button, written out of combat. Off Forever (caps.conditionalTargeting),
-- where the client parses a unit in a conditional:
--     /cast [@mouseover,help,nodead][help,nodead][@player] <cure>
-- so a press cures the player under your mouse, else a friendly target, else
-- you. On Forever, where [@unit] does not resolve, a bare /cast: it lands on a
-- friendly target, else on you. No /target, no spoken line, no hand-back; only
-- the left button casts.
--
-- A class with two cures (a druid, a priest or a shaman on the older clients,
-- a retail restoration druid) gets, with prompt.cureFightEach on (the default),
-- a button for each: MannersCureFight casts the first cure, MannersCureFight2
-- the second, below it, with a key of its own, and each shows only for the kinds
-- its cure takes off. With the switch off, or a class with one cure, there is
-- one button and the second cure is on Shift, the same clause under
-- [mod:shift,...] in front. Both are SLOTS below: one table each, one header
-- drives both.
--
-- WHAT MOVES IN A FIGHT, AND WHAT DOES IT
--
-- Lua writes the macros, the places and the size out of combat only (the scan,
-- Core.lua's TickBody, and the fight's end, Release). Whether a button is on
-- the screen at all is a state driver's, "[combat] fight; peace": it shows the
-- first button (and the second, when manners-two is set) at the pull at alpha
-- 0 for every fight, and hides them after. Lua never shows, hides, moves or
-- arms either under the lockdown; it paints only their own alpha, text and
-- textures, which the client allows in a fight. A click on an empty place in a
-- fight still casts, since alpha 0 takes clicks and the mouse of a protected
-- frame cannot be changed in combat; a key casts whether its button is shown
-- or not.
--
-- WHAT IT KNOWS, AND WHERE IT CANNOT
--
-- Secure code reads no aura and no cooldown, so who needs a cure is Lua's: the
-- harmful auras of you, your target and focus, and your party or raid, read in
-- the fight through ns.CureFightRead (Cures.lua), which leaves out what the
-- cure cannot lift: a debuff on the deny list, a debuff about to end, one the
-- client says you cannot remove, and a kind whose cure would also lift a
-- debuff never removed. Where the client withholds auras in a fight (Forever
-- and retail: caps.secretRestrictions) the contents of an aura come back
-- secret and are passed over, compared with nothing; but the game's own LIST of
-- the harmful auras you can remove ("HARMFUL|RAID", AuraUtil.AuraFilters.Raid)
-- is plain, so its length says somebody carries one. Where that list exists the
-- group and focus are read too, and somebody on the list whose auras are all
-- withheld is shown as a debuff you can remove, the kind unnamed: something
-- real was detected, and the player picks the button. Nothing is decided by
-- the client's name: if the client hands the debuffs back plain, the kind is
-- read as on any client. /manners debug counts the reads, the withheld reads
-- and those seen from the game's list in the last fight.
--
-- WHAT IT COSTS
--
-- Events only, and only between the pull and the release. UNIT_AURA is
-- filtered by a table lookup outside the Guard; for somebody not shown, only
-- an added harmful aura asks for a read, and so does any change on somebody
-- whose cure is held back by a debuff never removed (the debuff may go). Reads
-- are coalesced once each 0.1 s,
-- at most ten units a flush, one walk of the harmful list each (an empty game
-- list ends the read at once). While anybody is found needing a cure, a 0.5 s
-- recheck asks reach and time again. Nothing on the scan with the switch off
-- and the button never made: Wanted reads one field of the profile.
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
CureFight.COMMAND2 = "CLICK MannersCureFight2:LeftButton"
_G["BINDING_NAME_CLICK MannersCureFight:LeftButton"] = L["Cure in a fight"]
_G["BINDING_NAME_CLICK MannersCureFight2:LeftButton"] = L["Second cure in a fight"]

local STATE = "mannerscurefight"
local DRIVER = "[combat] fight; peace"
-- Between the prompt's (or the break-free button's) right edge and this button,
-- and between the two cure buttons.
local GAP = 10
-- Reads are coalesced: one flush each tenth of a second, ten units at most.
local FLUSH = 0.1
-- While anybody needs a cure: reach and time asked again this often.
local RECHECK = 0.5
local FADE = 0.2
local MAX_READS = 10
-- Somebody the game's list says carries a removable debuff of a kind nobody
-- could read: shown for this long, then read again.
local UNKNOWN_SECONDS = 3
-- How long after a press of this button its spell going out is waited for.
local SUCCEED_SECONDS = 1
local GLOW = "Interface\\AddOns\\Manners\\Textures\\RingSq"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local FIGHT_EVENTS = { "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_SPELLCAST_SUCCEEDED" }

local RAID, PARTY = {}, {}
for i = 1, 40 do RAID[i] = "raid" .. i end
for i = 1, 4 do PARTY[i] = "party" .. i end

-- One button and all it keeps: [1] MannersCureFight, [2] MannersCureFight2.
-- button, icon, glow, pulse, nameText, keyText, cooldown, fader: its frame and
-- regions. visible, fadeFrom, fadeTo, fadeAt, shownAt: what it shows and where
-- it is fading to. paintedKey, keyLabel, armedMacro, placedKey: what was last
-- painted, the key it is bound to, the macro on it and where it was put. list:
-- the cures it casts, in order; spells: the same as a set.
local slots = {}
for index = 1, 2 do
	slots[index] = { index = index, visible = false, fadeFrom = 0, fadeTo = 0, fadeAt = 0,
		command = index == 1 and CureFight.COMMAND or CureFight.COMMAND2 }
end

local header, armedList, armedTwo, armedKinds
local placedBeside, placedEach = false, false
local dirtyRefresh, settledOn, placedIcon, placedScale = true, nil, nil, nil
-- In a fight: the tokens read, those waiting for a read, and who needs a cure
-- ([token] = { kind, debuff, ends, guid, name, spell }; kind and spell nil
-- for somebody the game's list names with every aura withheld). `held`: tokens
-- whose read found a kind the cure could take off, held back by a debuff never
-- removed (or one that could not be read); that debuff going asks for a read.
local watched, dirty, needy, held = {}, {}, {}, {}
local flushDue, recheckDue = false, false
local waitUntil
-- The last fight, for /manners debug.
-- `listAsked` reads that asked the game's list of removable debuffs, `listWithheld`
-- of them with no count back (withheld, or no table), `listEmpty` with an empty list,
-- `threw` reads that threw.
local last = { reads = 0, secret = 0, seen = 0, shownFor = 0, listed = 0, shows = 0,
	listAsked = 0, listWithheld = 0, listEmpty = 0, threw = 0 }
local reasonOf, seenGuid = {}, {}
local Paint, Flush

local function Profile()
	return ns.db and ns.db.profile
end

local function Secret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Whether this character has a cure to offer in a fight and the switch is on.
-- The last fight's counts, for the fight summary and the Mark this moment line.
function CureFight.LastFight() return last end
-- Whether the first button's macro holds the Shift clause (two cures, one button).
function CureFight.ShiftClause() return armedTwo == true end

function CureFight.Applies(db)
	db = db or Profile()
	if not (db ~= nil and db.enabled == true and db.prompt.cureFight == true) then return false end
	if not ns.ClassHasCures() then return false end
	local list = ns.CureFightSpells()
	return list ~= nil and list[1] ~= nil
end

-- A button for each cure: the switch is on and there is a second cure.
local function EachCure(db, list)
	return db.prompt.cureFightEach == true and list ~= nil and list[2] ~= nil
end

-- Whether the game lists the harmful auras you can remove (Cures.lua reads it).
local function CanList()
	local auras = _G.C_UnitAuras
	return type(auras) == "table" and type(auras.GetUnitAuraInstanceIDs) == "function"
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
	if slots[1].shiftKey then return one, false end
	local both = "/cast " .. Clause(list[2].name, true) .. "; " .. Clause(list[1].name, false)
	if #both > ns.MACRO_LIMIT then return one, false end
	return both, true
end

local function Disarm(slot)
	if slot.armedMacro ~= nil then
		local button = slot.button
		button:SetAttribute("type1", nil)
		button:SetAttribute("macrotext1", nil)
		button:SetAttribute("type", nil)
		button:SetAttribute("macrotext", nil)
		slot.armedMacro = nil
	end
end

-- The cure and nothing else: no target, no line, no other press.
local function Arm(slot, macro)
	local button = slot.button
	if macro == slot.armedMacro and button:GetAttribute("macrotext1") == macro then return end
	button:SetAttribute("type1", "macro")
	button:SetAttribute("macrotext1", macro)
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", macro)
	slot.armedMacro = macro
end

-- Beside the break-free button where there is one, else the prompt's right edge:
-- anchored to a frame (never a region: CLAUDE.md), the size of the prompt's
-- icon. The second button goes below the first.
local function Place(p)
	placedIcon, placedScale = p.iconSize, p.scale
	local size = math.floor(math.max(24, math.min(48, tonumber(p.iconSize) or 30)) * (tonumber(p.scale) or 1) + 0.5)
	local bf = ns.BreakFree
	local beside = bf and bf.Applies() and bf:Button() or nil
	placedBeside = beside ~= nil
	local first, second = slots[1], slots[2]
	local key = size .. ":" .. tostring(placedBeside)
	if key ~= first.placedKey then
		first.placedKey = key
		first.button:ClearAllPoints()
		first.button:SetPoint("LEFT", beside or R.button, "RIGHT", GAP, 0)
		first.button:SetSize(size, size)
	end
	if second.button and tostring(size) ~= second.placedKey then
		second.placedKey = tostring(size)
		second.button:ClearAllPoints()
		second.button:SetPoint("TOP", first.button, "BOTTOM", 0, -GAP)
		second.button:SetSize(size, size)
	end
end

-- Out of sight or shown, by alpha and its own regions alone (the client lets
-- an addon change both in a fight). `ready`: the cure can be cast now, else
-- it is shown dim.
local function SetVisible(slot, on, ready)
	local to = on and (ready and 1 or 0.6) or 0
	if on and not slot.visible then
		slot.shownAt = GetTime()
		last.shows = last.shows + 1
	end
	if not on and slot.visible and slot.shownAt then
		last.shownFor = last.shownFor + (GetTime() - slot.shownAt)
		slot.shownAt = nil
	end
	slot.visible = on
	if on and ready then
		slot.glow:Show()
		if slot.pulse and not slot.pulse:IsPlaying() then slot.pulse:Play() end
	else
		if slot.pulse then slot.pulse:Stop() end
		slot.glow:Hide()
	end
	if not on then
		slot.nameText:SetText("")
		slot.keyText:SetText("")
		if type(slot.cooldown.Clear) == "function" then slot.cooldown:Clear() end
	end
	if to == slot.fadeTo then return end
	slot.fadeFrom, slot.fadeTo, slot.fadeAt = slot.button:GetAlpha(), to, GetTime()
	slot.fader:Show()
end

local function Fade(slot, frame)
	local t = (GetTime() - slot.fadeAt) / FADE
	if t >= 1 then
		slot.button:SetAlpha(slot.fadeTo)
		frame:Hide()
	else
		slot.button:SetAlpha(slot.fadeFrom + (slot.fadeTo - slot.fadeFrom) * t)
	end
end

-- Out of sight again, by alpha and its own regions: the fight's start and end,
-- and the settings counting (Refresh). Out of combat for the button's own Hide.
local function Hush(slot)
	if not slot.button then return end
	slot.paintedKey = nil
	SetVisible(slot, false)
	slot.button:SetAlpha(0)
	slot.fadeTo = 0
	slot.fader:Hide()
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

-- Where the client may withhold auras and gives no list of the ones you can
-- remove, only you and your target are read (the group would come back
-- withheld too). Where the list is there, the group and focus are read as on a
-- plain client. In a raid your own raid token is left out: UNIT_AURA comes for
-- it and for "player" alike.
local function Watch()
	wipe(watched)
	watched.player, watched.target, watched.focus = true, true, true
	if caps.secretRestrictions == true and not CanList() then
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
		slots[1].paintedKey, slots[2].paintedKey = nil, nil
		ns.Guard("cure in a fight", Paint)
	end)
end

-- The armed cure that takes off a kind, over both buttons.
local function SpellFor(kind)
	for index = 1, 2 do
		local list = slots[index].list
		if list then
			for i = 1, #list do
				if list[i].kinds[kind] then return list[i] end
			end
		end
	end
	return nil
end

-- One unit's harmful auras, read now, and what the armed cure could take off.
local function ReadOne(unit, now)
	if not Eligible(unit) then
		needy[unit] = nil
		held[unit] = nil
		return
	end
	local kind, debuff, ends, secret, back, listed, threw
	local asked = caps.secretRestrictions == true and CanList()
	if caps.secretRestrictions == true then
		local ok, k, d, e, s, h, n = pcall(ns.CureFightRead, unit, now, armedKinds)
		if ok then
			kind, debuff, ends, secret, back, listed = k, d, e, s, h, n
		else
			secret, threw = true, true
			last.threw = last.threw + 1
		end
	else
		kind, debuff, ends, secret, back, listed = ns.CureFightRead(unit, now, armedKinds)
	end
	last.reads = last.reads + 1
	if secret then last.secret = last.secret + 1 end
	if asked and not threw then
		last.listAsked = last.listAsked + 1
		if listed == nil then
			last.listWithheld = last.listWithheld + 1
		elseif listed == 0 then
			last.listEmpty = last.listEmpty + 1
		end
	end
	local spell = kind and SpellFor(kind) or nil
	if not spell then
		-- Nothing readable, but the game's own list says this one carries a
		-- debuff you can remove: shown without a kind. A plain read that found
		-- nothing (the deny list, under two seconds, the client's no) wins.
		if not (secret and type(listed) == "number" and listed > 0) then
			needy[unit] = nil
			held[unit] = back == true or nil
			return
		end
		last.listed = last.listed + 1
	end
	held[unit] = nil
	local rec = needy[unit]
	if not rec then
		rec = {}
		needy[unit] = rec
		last.seen = last.seen + 1
	end
	if spell then
		rec.kind, rec.debuff, rec.ends, rec.spell = kind, debuff, ends, spell
	else
		rec.kind, rec.debuff, rec.spell, rec.ends = nil, nil, nil, now + UNKNOWN_SECONDS
	end
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

-- Who to show on a button: your target, then you, then a tank, then whoever's
-- debuff lasts longest; one person under two tokens once. Only those a cure of
-- this button's takes off (somebody with a kind unnamed is for every button).
-- A debuff whose time is up is dropped and read again (it may have been
-- renewed with no event).
local function Pick(now, slot)
	wipe(seenGuid)
	local best, bestRank, bestEnds, count, expired = nil, nil, nil, 0, false
	for unit, rec in pairs(needy) do
		local key = rec.guid or unit
		if rec.ends - now <= 0 then
			dirty[unit] = true
			expired = true
			-- Somebody shown from the game's list alone stays until that read:
			-- the list, not a time, says whether the debuff is still on.
			if rec.spell ~= nil or not watched[unit] then needy[unit] = nil end
		end
		if needy[unit] == rec and (rec.spell == nil or slot.spells[rec.spell]) and not seenGuid[key]
			and (unit == "player" or ns.InRange(unit, rec.spell and rec.spell.cure or slot.list[1].cure) ~= false) then
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

-- The name shown for somebody; the client may withhold it.
local function NameOf(rec)
	if rec.name == nil then return L["Somebody"] end
	return ns.ShortName(tostring(rec.name))
end

-- What a press would do, in the player's words.
local function KeyLine(slot, unit, spell)
	local shift = slot.index == 1 and armedTwo and spell == armedList[2]
	local canAssist = plain(UnitCanAssist("player", "target")) == true
	-- Where the macro has [nodead] a dead friend is passed over and the press
	-- lands on you; Forever's bare /cast does go to them.
	local friendTarget = canAssist and not (caps.conditionalTargeting and plain(UnitIsDeadOrGhost("target")) == true)
	local hostileTarget = plain(UnitExists("target")) == true and not canAssist
	local mine = unit == "player" or plain(UnitIsUnit(unit, "player")) == true
	local keyLabel = slot.keyLabel
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
	local who = mine and L["yourself"] or NameOf(needy[unit])
	if caps.conditionalTargeting then
		if key then return L["point at %s and press %s"]:format(who, key) end
		return (shift and L["point at %s and shift-click"] or L["point at %s and click"]):format(who)
	end
	if key then return L["target %s and press %s"]:format(who, key) end
	return (shift and L["target %s and shift-click"] or L["target %s and click"]):format(who)
end

-- One button's own regions and its alpha. Answers whether somebody needs its cure.
local function PaintSlot(slot, fighting, now)
	local unit, count
	if fighting then unit, count = Pick(now, slot) end
	local rec = unit and needy[unit]
	if not rec then
		slot.paintedKey = nil
		SetVisible(slot, false)
		return false
	end
	local spell = rec.spell or slot.list[1]
	local id = spell.cure.info and spell.cure.info.topRank
	local left, length = 0, 0
	if id then left, length = CooldownLeft(id, now) end
	local mana = id ~= nil and OutOfMana(id)
	local ready = left <= 0 and not mana
	local key = unit .. ":" .. tostring(rec.kind) .. ":" .. tostring(ready) .. ":" .. count .. ":" .. tostring(slot.keyLabel)
		.. ":" .. tostring(plain(UnitGUID("target")))
	if key ~= slot.paintedKey then
		slot.paintedKey = key
		slot.icon:SetTexture(spell.cure.info and spell.cure.info.icon or FALLBACK_ICON)
		local who = unit == "player" and L["You"] or NameOf(rec)
		if count > 1 then who = L["%s, and %d more"]:format(who, count - 1) end
		local reason = L["a debuff you can remove"]
		if rec.kind then
			reasonOf.cure = rec.kind
			reason = ns.CureReason(reasonOf)
		end
		slot.nameText:SetText("|cffffd100" .. tostring(spell.name) .. "|r: " .. who .. " (" .. reason .. ")")
		if ready then
			slot.keyText:SetText(KeyLine(slot, unit, spell))
		elseif left > 0 then
			slot.keyText:SetText(L["your cure is cooling down"])
		else
			slot.keyText:SetText(L["not enough mana for the cure"])
		end
		if left > 0 and type(slot.cooldown.SetCooldown) == "function" then slot.cooldown:SetCooldown(now + left - length, length) end
	end
	SetVisible(slot, true, ready)
	return true
end

-- Both buttons' regions and alphas. Answers whether somebody needs a cure.
Paint = function()
	if not slots[1].button then return false end
	local fighting = InCombatLockdown()
	local now = GetTime()
	local any = false
	for index = 1, 2 do
		local slot = slots[index]
		if slot.button and slot.list then
			if PaintSlot(slot, fighting, now) then any = true end
		end
	end
	-- Reach and time are asked again while anybody needs a cure, shown or not.
	if fighting and next(needy) then Recheck() end
	return any
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
local function OnEnter(slot, self)
	if not slot.visible then return end
	local tip = _G.GameTooltip
	if not tip then return end
	tip:SetOwner(self, "ANCHOR_TOP")
	local first = slot.list and slot.list[1]
	local id = first and first.cure.info and first.cure.info.topRank
	if id and type(tip.SetSpellByID) == "function" then
		tip:SetSpellByID(id)
	elseif first then
		tip:AddLine(tostring(first.name), 1, 1, 1)
	end
	tip:AddLine(caps.conditionalTargeting and L["Casts at the player under your mouse, else your target, else you."]
		or L["Casts at your target when it is a friend, else at you."], 0.75, 0.75, 0.75, true)
	if slot.index == 1 and armedTwo then tip:AddLine(L["Hold Shift for %s."]:format(tostring(armedList[2].name)), 0.75, 0.75, 0.75, true) end
	tip:AddLine(L["Manners: a left click here casts it, as its key does."], 0.75, 0.75, 0.75, true)
	ns.AddSettingsLine(tip, "appearance.cureFight")
	tip:Show()
end

local function OnLeave()
	local tip = _G.GameTooltip
	if tip then tip:Hide() end
end

-- Runs in the restricted environment: shown for the fight, hidden after. The
-- second button follows the same test, when manners-two says it is wanted.
local SNIPPET = [=[
	local cure = self:GetFrameRef("cure")
	if not cure then return end
	local on = newstate == "fight" and self:GetAttribute("manners-on")
	if on then
		cure:Show(true)
	else
		cure:Hide(true)
	end
	local two = self:GetFrameRef("cure2")
	if two then
		if on and self:GetAttribute("manners-two") then
			two:Show(true)
		else
			two:Hide(true)
		end
	end
]=]

-- Made the first time it is wanted, out of combat: the first button with the
-- header, or (index 2) the second.
function CureFight:Create(index)
	index = index or 1
	local slot = slots[index]
	if not slot or slot.button or InCombatLockdown() then return end
	if index == 2 and not slots[1].button then return end
	local button = CreateFrame("Button", index == 1 and "MannersCureFight" or "MannersCureFight2", UIParent, "SecureActionButtonTemplate")
	button:SetFrameStrata("MEDIUM")
	button:SetClampedToScreen(true)
	button:RegisterForClicks("AnyDown")
	-- A key press is a down click: without this the client takes it as neither
	-- the action nor a release while ActionButtonUseKeyDown is off (Panel.lua).
	button:SetAttribute("pressAndHoldAction", true)
	button:SetAlpha(0)
	-- No click until Refresh has decided (SetMouse).
	button:EnableMouse(false)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local list = ns.CureFightSpells()
	local first = list and (list[index] or list[1])
	icon:SetTexture(first and first.cure.info and first.cure.info.icon or FALLBACK_ICON)
	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
	glow:SetVertexColor(1, 0.82, 0.2)
	glow:Hide()
	local pulse = glow:CreateAnimationGroup()
	if type(pulse.SetLooping) == "function" then pulse:SetLooping("BOUNCE") end
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.45)
	-- Its two lines go to its right, clear of a break-free button's lines.
	local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("BOTTOMLEFT", button, "RIGHT", 4, 1)
	nameText:SetText("")
	local keyText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keyText:SetPoint("TOPLEFT", button, "RIGHT", 4, -1)
	keyText:SetText("")
	local okC, made = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate")
	local cooldown = okC and made or { SetCooldown = function() end }
	if okC then cooldown:SetAllPoints(button) end
	-- The highlight is a region of the button: it takes the button's alpha, so
	-- at alpha 0 nothing of it shows.
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	for i = 2, 31 do
		if i <= 5 then button:SetAttribute("type" .. i, "none") end
		button:SetAttribute("*type" .. i, "none")
	end
	button:SetScript("PreClick", PreClick)
	button:SetScript("OnEnter", function(self) OnEnter(slot, self) end)
	button:SetScript("OnLeave", OnLeave)
	button:Hide()
	local fader = CreateFrame("Frame")
	fader:Hide()
	fader:SetScript("OnUpdate", function(self) Fade(slot, self) end)
	slot.button, slot.icon, slot.glow, slot.pulse = button, icon, glow, pulse
	slot.nameText, slot.keyText, slot.cooldown, slot.fader = nameText, keyText, cooldown, fader
	if index == 2 then
		if header and type(header.SetFrameRef) == "function" then header:SetFrameRef("cure2", button) end
		return
	end
	if type(_G.RegisterStateDriver) == "function" then
		local ok, made2 = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
		if ok and type(made2) == "table" and type(made2.SetFrameRef) == "function" then
			made2:SetFrameRef("cure", button)
			made2:SetAttribute("manners-on", false)
			made2:SetAttribute("manners-two", false)
			made2:SetAttribute("_onstate-" .. STATE, SNIPPET)
			_G.RegisterStateDriver(made2, STATE, DRIVER)
			header = made2
		end
	end
	local frame = CureFight.frame
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("UPDATE_BINDINGS")
end

-- The key each button is bound to; read out of a fight and at every pull,
-- before the lockdown.
local function ReadKey(slot)
	local keys = type(GetBindingKey) == "function" and { GetBindingKey(slot.command) } or {}
	local key = keys[1]
	slot.keyLabel = type(key) == "string" and key ~= "" and key or nil
	-- Any of the command's keys with Shift in it (the Key Bindings allow two).
	slot.shiftKey = false
	for i = 1, #keys do
		if type(keys[i]) == "string" and keys[i]:upper():find("SHIFT%-") then slot.shiftKey = true end
	end
end

-- Whether a button takes a click: only when no key is bound (then a click is
-- the only way to cast it). With a key it is out of sight or only just in it,
-- and a click beside the prompt must reach the world behind. The client refuses
-- EnableMouse on a protected frame under the lockdown, so only out of one: at
-- Refresh and at the pull, before it. `used`: the button is one of this fight's.
local function SetMouse(slot, used)
	if not slot.button or InCombatLockdown() then return end
	slot.button:EnableMouse(used ~= false and slot.keyLabel == nil)
end

-- From a scan (Core.lua, TickBody) when Wanted says something changed, and as a
-- fight ends (Release). Out of combat only.
function CureFight:Refresh()
	if InCombatLockdown() then return end
	local db = Profile()
	if not db then return end
	local first, second = slots[1], slots[2]
	if not CureFight.Applies(db) then
		for index = 1, 2 do
			local slot = slots[index]
			if slot.button then
				Disarm(slot)
				if slot.button:IsShown() then slot.button:Hide() end
			end
			slot.list, slot.spells = nil, nil
		end
		if header then
			if header:GetAttribute("manners-on") then header:SetAttribute("manners-on", false) end
			if header:GetAttribute("manners-two") then header:SetAttribute("manners-two", false) end
		end
		armedList, armedTwo, armedKinds, placedEach = nil, false, nil, false
		settledOn, dirtyRefresh = false, false
		return
	end
	if not first.button then self:Create() end
	if not first.button then return end
	local list = ns.CureFightSpells()
	local each = EachCure(db, list)
	if each and not second.button then self:Create(2) end
	if each and not second.button then each = false end
	ReadKey(first)
	local macro, two
	if each then
		ReadKey(second)
		-- The first button keeps the old two-cure macro, so Shift on its key
		-- still casts the second cure; it advertises and shows only its own.
		macro = MacroFor(list)
		two = false
		first.list, second.list = { list[1] }, { list[2] }
	else
		macro, two = MacroFor(list)
		first.list = two and { list[1], list[2] } or { list[1] }
		second.list = nil
	end
	for index = 1, 2 do
		local slot = slots[index]
		slot.spells = nil
		if slot.list then
			slot.spells = {}
			for _, spell in ipairs(slot.list) do slot.spells[spell] = true end
		end
	end
	SetMouse(first)
	if second.button then SetMouse(second, each) end
	armedList, armedTwo, placedEach = list, two, each
	-- The kinds a press can cast: the second spell's only while Shift is free,
	-- or while it has a button of its own.
	armedKinds = {}
	for index = 1, 2 do
		local slotList = slots[index].list
		if slotList then
			for _, spell in ipairs(slotList) do
				for kind in pairs(spell.kinds) do armedKinds[kind] = true end
			end
		end
	end
	Place(db.prompt)
	Arm(first, macro)
	if each then
		Arm(second, "/cast " .. Clause(list[2].name, false))
	elseif second.button then
		Disarm(second)
	end
	if header then
		if header:GetAttribute("manners-on") ~= true then header:SetAttribute("manners-on", true) end
		if header:GetAttribute("manners-two") ~= each then header:SetAttribute("manners-two", each) end
		if header:GetAttribute("state-" .. STATE) ~= "peace" then header:SetAttribute("state-" .. STATE, "peace") end
	end
	for index = 1, 2 do
		local slot = slots[index]
		if slot.button then
			if slot.button:IsShown() then slot.button:Hide() end
			Hush(slot)
		end
	end
	settledOn, dirtyRefresh = true, false
end

-- Whether a scan has anything to do here. With nothing made, one field of the
-- profile and the class's cached cures and no question to the client (a switch
-- off, a class with no cure, a mage below Remove Lesser Curse); once made, the
-- comparisons come first and the lockdown is asked only when one changed.
function CureFight:Wanted()
	local db = Profile()
	if not db then return false end
	if slots[1].button == nil and (db.prompt.cureFight ~= true or not ns.ClassHasCures() or ns.CureFightSpells() == nil) then
		return false
	end
	local changed = dirtyRefresh
	if not changed then
		local on = CureFight.Applies(db) and true or false
		if on ~= settledOn then
			changed = true
		elseif on then
			local p = db.prompt
			if ns.CureFightSpells() ~= armedList or p.iconSize ~= placedIcon or p.scale ~= placedScale
				or EachCure(db, armedList) ~= placedEach then
				changed = true
			else
				-- `or nil`: Applies answers false, which is not nil.
				local bf = ns.BreakFree
				local beside = bf and bf.Applies() and bf:Button() or nil
				changed = (beside ~= nil) ~= placedBeside
			end
		end
	end
	return changed and not InCombatLockdown()
end

-- The pull, before the lockdown: who is read, and the fight's events.
local function Pull()
	if not (settledOn and slots[1].button) then return end
	for index = 1, 2 do
		local slot = slots[index]
		if slot.button then
			ReadKey(slot)
			SetMouse(slot, slot.list ~= nil)
		end
	end
	last.reads, last.secret, last.seen, last.shownFor, last.listed, last.shows = 0, 0, 0, 0, 0, 0
	last.listAsked, last.listWithheld, last.listEmpty, last.threw = 0, 0, 0, 0
	wipe(needy)
	wipe(dirty)
	wipe(held)
	Watch()
	for token in pairs(watched) do dirty[token] = true end
	local frame = CureFight.frame
	for _, event in ipairs(FIGHT_EVENTS) do frame:RegisterEvent(event) end
	Hush(slots[1])
	Hush(slots[2])
	Schedule()
end

-- PLAYER_REGEN_ENABLED, out of lockdown: the events dropped, the buttons taken
-- down and armed again.
function CureFight:Release()
	local frame = CureFight.frame
	for _, event in ipairs(FIGHT_EVENTS) do frame:UnregisterEvent(event) end
	wipe(needy)
	wipe(dirty)
	wipe(held)
	Hush(slots[1])
	Hush(slots[2])
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
		-- A withheld list of what was added may hold a harmful aura: read.
		local harmful = Secret(added)
		if not harmful then
			if type(added) ~= "table" then return end
			for i = 1, #added do
				local aura = added[i]
				if Secret(aura) or type(aura) ~= "table" or plain(aura.isHarmful) ~= false then
					harmful = true
					break
				end
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
		slots[1].paintedKey, slots[2].paintedKey = nil, nil
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
		slots[1].paintedKey, slots[2].paintedKey = nil, nil
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
	local first, second = slots[1], slots[2]
	local joiner = (second.armedMacro ~= nil) and ", " or ", Shift "
	local spells = (list and list[1]) and (tostring(list[1].name) .. (list[2] and (joiner .. tostring(list[2].name)) or "")) or "none learned"
	local armed = first.button and first.button:GetAttribute("macrotext1")
	out[1] = ("cure in a fight: switch %s; spells %s; %s; key %s; driver %s; shown %s"):format(
		(db and db.prompt.cureFight == true) and "on" or "off", spells,
		armed and ("armed (" .. tostring(armed) .. ")") or (first.button and "made, not armed" or "not made"),
		tostring(first.keyLabel or (type(GetBindingKey) == "function" and GetBindingKey(CureFight.COMMAND)) or "none"),
		tostring(header and header:GetAttribute("state-" .. STATE) or "none"),
		tostring(first.button ~= nil and first.button:IsShown()))
	if second.armedMacro ~= nil then
		out[1] = out[1] .. ("; second %s key %s"):format(tostring(second.list and second.list[1] and second.list[1].name),
			tostring(second.keyLabel or (type(GetBindingKey) == "function" and GetBindingKey(CureFight.COMMAND2)) or "none"))
	end
	out[2] = ("cure in a fight, last fight: %d reads, %d withheld, %d needing a cure, seen for %d s, %d from the game's list; the game's list of debuffs you can remove: %s, asked %d times, %d withheld, %d empty; %d reads threw"):format(
		last.reads, last.secret, last.seen, math.floor(last.shownFor), last.listed,
		CanList() and (caps.secretRestrictions == true and "yes" or "yes, not needed here") or "no",
		last.listAsked, last.listWithheld, last.listEmpty, last.threw)
	return out
end

function CureFight:Button(index) return slots[index or 1].button end
function CureFight:Header() return header end
-- What it shows: the spell's name and the key line, the glow, and where it is
-- fading to (alpha is the target; the fader walks the button there).
function CureFight:Look(index)
	local slot = slots[index or 1]
	if not slot.button then return nil end
	return { name = slot.nameText, key = slot.keyText, glow = slot.glow, icon = slot.icon, alpha = slot.fadeTo, fader = slot.fader }
end
