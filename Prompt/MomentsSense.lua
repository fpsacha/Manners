-- Manners -- the buttons for the moment, what they can tell (Prompt/Moments.lua
-- builds the buttons; Prompt/MomentsData.lua says what each waits for).
--
-- Every signal is Sense[name](slot, now) and answers one of
--     "yes"            plainly true
--     "no", why        plainly false; why is a constant English string for the log
--     "game", what     hidden by the client: slot.game = { kind, rawA, rawList }
--                      holds the hidden value for the CLIENT to paint the art from
--     "blind", what    hidden, and this client has no call that takes it
-- Evaluate walks a row's needs in order and stops at the first "no", so the
-- secret route is never taken when a plain fact already says no.
--
-- THE NAMING RULE for hidden values (tests/validate.py checks it, here and in
-- Moments.lua). Every local or field that may hold a value the client hides is
-- named raw<Something>, and a raw name may only be assigned, listed in a local
-- or return, put in a table constructor, or handed on as a bare call argument:
-- never next to ==, ~=, <, >, and, or, not, if, while, a dot, an index or
-- arithmetic. That is what stops `if rawName then`, which the test client
-- cannot make throw. A stored hidden value therefore lives in a positional
-- table ({ kind, rawA }) and is read back into another raw local.
--
-- What the client lets an addon do with a hidden value (Blizzard's own UI
-- source, github.com/Gethe/wow-ui-source, branch forever): ask its type();
-- hand it to Frame:SetAlphaFromBoolean or Frame:SetAlpha, to
-- C_CurveUtil.EvaluateColorValueFromBoolean, and take UnitHealthPercent or
-- UnitPowerPercent through a curve. Nothing else: no test, no comparison.

local _, ns = ...
local plain = ns.plain
local issecretvalue = _G.issecretvalue
local InCombatLockdown = _G.InCombatLockdown

local Sense = {}
ns.Sense = Sense

-- What this client can do, asked once (Sense.Probe).
local can = {}
Sense.can = can
-- Event names the frame accepted, and those it refused (Sense.ProbeEvents).
Sense.accepted, Sense.lacking = {}, {}
-- Paint kinds tried once, and those the game refused (and what it said).
local tried, refused = {}, {}
Sense.tried, Sense.refused = tried, refused
-- Whether the game's per-spell lock flag has been seen reading "not locked"
-- during a loss of control: only then may a locked flag veto Blink.
Sense.lockProven = false
-- When control was last lost (PLAYER_CONTROL_LOST), for a client that cannot
-- say what took it. Set by Moments.lua's events.
Sense.lostAt = nil
-- The fight, as Moments.lua knows it: set at the pull (when the lockdown may
-- not yet answer true) and cleared at the release.
Sense.fighting = false
-- Whether you are moving, kept by the two movement events while a row wants
-- them (Prompt/Moments.lua).
Sense.moving = false
-- 1, or 100 where UnitHealthPercent answers in percent.
Sense.scale = 1

local MANA = 0
local UNSURE_SECONDS = 10

local function Profile()
	return ns.db and ns.db.profile
end

function Sense.Probe(frame)
	can.bool = type(frame.SetAlphaFromBoolean) == "function"
	local utils = _G.C_CurveUtil
	can.eval = type(utils) == "table" and type(utils.EvaluateColorValueFromBoolean) == "function"
	can.curve = type(utils) == "table" and type(utils.CreateCurve) == "function"
		and type(_G.Enum) == "table" and type(Enum.LuaCurveType) == "table"
	can.health = type(_G.UnitHealthPercent) == "function"
	can.power = type(_G.UnitPowerPercent) == "function"
end

-- Each event name the module may register is tried once, under pcall (an unknown
-- name throws), so one the client lacks can never abort a pull's registrations.
function Sense.ProbeEvents(frame, names)
	wipe(Sense.accepted)
	wipe(Sense.lacking)
	for _, name in ipairs(names) do
		local ok
		if name:find("^UNIT_") then
			ok = pcall(frame.RegisterUnitEvent, frame, name, "target")
		else
			ok = pcall(frame.RegisterEvent, frame, name)
		end
		if ok then
			frame:UnregisterEvent(name)
			Sense.accepted[name] = true
		else
			Sense.lacking[#Sense.lacking + 1] = name
		end
	end
end

-- Out of a fight, once a profile or a probe: whether health percent is a
-- fraction or a percent.
function Sense.ReadScale()
	Sense.scale = 1
	if type(_G.UnitHealthPercent) ~= "function" then return end
	local ok, value = pcall(_G.UnitHealthPercent, "player", false)
	value = ok and plain(value) or nil
	if type(value) == "number" and value > 1.5 then Sense.scale = 100 end
end

---------------------------------------------------------------------------
-- curves: a Linear curve with a steep edge, so nothing depends on how a Step
-- curve snaps. `low` is 1 under the threshold and 0 over it.
---------------------------------------------------------------------------

local curves = {}

function Sense.Curve(kind, threshold)
	if not can.curve then return nil end
	local key = kind .. ":" .. tostring(threshold) .. ":" .. Sense.scale
	local made = curves[key]
	if made ~= nil then return made or nil end
	local t = (tonumber(threshold) or 20) / 100 * Sense.scale
	local edge = 0.001 * Sense.scale
	local ok, curve = pcall(function()
		local c = _G.C_CurveUtil.CreateCurve()
		c:SetType(Enum.LuaCurveType.Linear)
		c:AddPoint(0, 1)
		c:AddPoint(math.max(0, t - edge), 1)
		c:AddPoint(t, 0)
		c:AddPoint(Sense.scale, 0)
		return c
	end)
	curves[key] = ok and curve or false
	return ok and curve or nil
end

---------------------------------------------------------------------------
-- painting from a hidden value: the client's own calls, tried once per kind
---------------------------------------------------------------------------

local function PaintCall(inner, kind, rawA, held, count)
	if kind == "not" then
		if type(rawA) ~= "boolean" then error("not a boolean", 0) end
		inner:SetAlphaFromBoolean(rawA, 0, 1)
	elseif kind == "is" then
		if type(rawA) ~= "boolean" then error("not a boolean", 0) end
		inner:SetAlphaFromBoolean(rawA, 1, 0)
	elseif kind == "num" then
		if type(rawA) ~= "number" then error("not a number", 0) end
		inner:SetAlpha(rawA)
	elseif kind == "any" then
		local acc = 0
		for i = 1, count or 0 do
			local rawSteal = held[i]
			if type(rawSteal) == "boolean" then
				acc = _G.C_CurveUtil.EvaluateColorValueFromBoolean(rawSteal, 1, acc)
			end
		end
		inner:SetAlpha(acc)
	end
end

-- The first use of each kind in a session goes through one pcall (a call handed
-- a possibly hidden value); when it fails the kind is marked refused, one trail
-- line says which call the game refused, and the signal answers "blind" from
-- then on. After one success the calls are direct.
function Sense.Paint(inner, kind, rawA, held, count)
	if refused[kind] then return false end
	if tried[kind] then
		PaintCall(inner, kind, rawA, held, count)
		return true
	end
	local ok, err = pcall(PaintCall, inner, kind, rawA, held, count)
	tried[kind] = true
	if not ok then
		refused[kind] = tostring(err)
		ns.Trail("fight", "the game refused " .. kind .. " paint: " .. tostring(err))
		return false
	end
	return true
end

-- Whether the game can be handed a hidden value of this kind to paint.
local function CanPaint(kind)
	if refused[kind] then return false end
	if kind == "not" or kind == "is" then return can.bool == true end
	if kind == "any" then return can.eval == true end
	return true
end

---------------------------------------------------------------------------
-- the signals
---------------------------------------------------------------------------

local function Yes() return "yes" end

-- In a fight (Moments.lua says so at the pull, before the lockdown answers).
function Sense.fight()
	if Sense.fighting or InCombatLockdown() then return "yes" end
	return "no", "not in a fight"
end

-- Out of a fight only (Moments.lua says so at the pull, before the lockdown
-- answers): the reverse of `fight`, for the drink.
function Sense.calm()
	if Sense.fighting or InCombatLockdown() then return "no", "in a fight" end
	return "yes"
end

-- A spell's cooldown, by the client's own figures: isActive (a plain boolean or
-- nil), start, duration. Where C_Spell has none, the older call's numbers.
local function Cool(id)
	local spellApi = _G.C_Spell
	if type(spellApi) == "table" and type(spellApi.GetSpellCooldown) == "function" then
		local rec = plain(spellApi.GetSpellCooldown(id))
		if type(rec) == "table" then
			return plain(rec.isActive), plain(rec.startTime), plain(rec.duration)
		end
		return nil, nil, nil
	end
	if type(_G.GetSpellCooldown) == "function" then
		local start, duration = _G.GetSpellCooldown(id)
		return nil, plain(start), plain(duration)
	end
	return nil, nil, nil
end

-- Whether the spell's own cooldown is running: true, false, or nil where the
-- game's figures say nothing. isOnGCD is never read here: only the cooldown
-- event's handler reads it (slot.onGCD), because the game says not to trust it
-- anywhere else.
local function Cooling(slot, id, now)
	local active, start, duration = Cool(id)
	if active == false then
		slot.readyAt = nil
		return false
	end
	if active == true then
		if slot.onGCD == false then return true end
		if slot.onGCD == true then return false end
	end
	if type(start) == "number" and type(duration) == "number" then
		if duration > 1.5 then return start + duration > now end
		return false
	end
	return nil
end
Sense.Cooling = Cooling
Sense.Cool = Cool

function Sense.ready(slot, now)
	local cooling = Cooling(slot, slot.id, now)
	if cooling == true then return "no", "cooling down" end
	if cooling == false then return "yes" end
	-- Nothing readable: Manners' own clock, begun by your own cast.
	if slot.readyAt and now < slot.readyAt then return "no", "cooling down" end
	return "yes"
end

function Sense.usable(slot)
	local spellApi = _G.C_Spell
	local check = type(spellApi) == "table" and spellApi.IsSpellUsable or _G.IsUsableSpell
	if type(check) ~= "function" then return "yes" end
	local usable, noMana = check(slot.id)
	usable, noMana = plain(usable), plain(noMana)
	if usable == false then
		if noMana == true then return "no", "not enough mana" end
		return "no", "the game says it cannot be cast now"
	end
	return "yes"
end

function Sense.enemy()
	if plain(UnitExists("target")) ~= true then return "no", "no target" end
	if plain(UnitCanAttack("player", "target")) ~= true then return "no", "your target is not hostile" end
	if plain(UnitIsDeadOrGhost("target")) == true then return "no", "your target is dead" end
	return "yes"
end

-- A cast or a channel on the target. The first return that names one wins; its
-- hidden flag is kept in slot.castInfo for `interruptible`.
function Sense.casting(slot)
	if slot.castOn == false then return "no", "your target is not casting" end
	local rawName, _, _, _, _, _, _, rawNotInt = UnitCastingInfo("target")
	if type(rawName) == "nil" then
		rawName, _, _, _, _, _, rawNotInt = UnitChannelInfo("target")
	end
	if type(rawName) == "nil" then
		slot.castInfo = nil
		return "no", "your target is not casting"
	end
	slot.castInfo = { rawNotInt }
	return "yes"
end

function Sense.interruptible(slot)
	if slot.flip == true then return "yes" end
	if slot.flip == false then return "no", "it cannot be interrupted" end
	local info = slot.castInfo
	local rawNotInt
	if info then rawNotInt = info[1] end
	local shape = type(rawNotInt)
	if shape == "nil" then return "yes" end
	if shape ~= "boolean" then return "blind", "whether it can be interrupted" end
	if issecretvalue(rawNotInt) then
		if CanPaint("not") then
			slot.game = { "not", rawNotInt }
			return "game", "whether it can be interrupted"
		end
		return "blind", "whether it can be interrupted"
	end
	if plain(rawNotInt) == true then return "no", "it cannot be interrupted" end
	return "yes"
end

function Sense.inrange(slot)
	local spellApi = _G.C_Spell
	local check = type(spellApi) == "table" and spellApi.IsSpellInRange or _G.IsSpellInRange
	if type(check) ~= "function" then return "yes" end
	if plain(check(slot.id, "target")) == false then return "no", "out of range" end
	return "yes"
end

-- Your health or mana under the share the settings say. Plain numbers decide;
-- where the game hides them, the game's own percent call evaluated through a
-- curve paints the art ("num": the value is already 1 when the moment is on).
local function Low(slot, which)
	local db = Profile()
	local moments = db and db.moments
	local threshold = moments and moments[which] or 20
	local cur, max
	if which == "health" then
		cur, max = UnitHealth("player"), UnitHealthMax("player")
	else
		cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
	end
	cur, max = plain(cur), plain(max)
	-- A bar of zero is no low bar (a monk outside the healing spec has no mana).
	if type(max) == "number" and max == 0 then return "no", "you have no mana" end
	if type(cur) == "number" and type(max) == "number" and max > 0 then
		if cur / max * 100 < threshold then return "yes" end
		return "no", which == "health" and "your health is not low" or "your mana is not low"
	end
	local percent = which == "health" and can.health or can.power
	local curve = percent and Sense.Curve(which, threshold)
	if not curve then return "blind", "your " .. which end
	local rawPct
	if which == "health" then
		rawPct = _G.UnitHealthPercent("player", false, curve)
	else
		rawPct = _G.UnitPowerPercent("player", MANA, false, curve)
	end
	if type(rawPct) == "nil" then return "blind", "your " .. which end
	if issecretvalue(rawPct) then
		slot.game = { "num", rawPct }
		return "game", "your " .. which .. " is hidden"
	end
	local value = plain(rawPct)
	if type(value) ~= "number" then return "blind", "your " .. which end
	if value >= 0.5 then return "yes" end
	return "no", which == "health" and "your health is not low" or "your mana is not low"
end

function Sense.lowhealth(slot) return Low(slot, "health") end
function Sense.lowmana(slot) return Low(slot, "mana") end

-- The game's per-spell lock flag, read only while a loss of control is on you:
-- true, false or nil. Seen false once, it is proven to tell cases apart.
local function LockFlag(slot)
	local spellApi = _G.C_Spell
	if type(spellApi) ~= "table" or type(spellApi.GetSpellLossOfControlCooldownInfo) ~= "function" then return nil end
	local rec = plain(spellApi.GetSpellLossOfControlCooldownInfo(slot.id))
	if type(rec) ~= "table" then return nil end
	local flag = plain(rec.isActive)
	if flag == false then Sense.lockProven = true end
	return flag
end

-- A stun or a root: the loss of control the client reports, the kind plain
-- where it will say, else any loss of control (lighting while feared costs
-- nothing: the cast is refused). Where the client has no loss-of-control API,
-- by the control events and HasFullControl, ended by PLAYER_CONTROL_GAINED or
-- ten seconds.
function Sense.stuck(slot, now)
	local breakFree = ns.BreakFree
	local read = breakFree and breakFree.ReadLoss
	if not read then return "blind", "a loss of control" end
	local hit, kind, how, count = read(slot.row)
	slot.lossHow, slot.lockFlag = how, nil
	if hit then
		slot.lockFlag = LockFlag(slot)
		return "yes"
	end
	if how == "plain" then
		slot.lockFlag = LockFlag(slot)
		return "no", "not a stun or a root"
	end
	if how == "secret" and type(count) == "number" and count > 0 then
		local flag = LockFlag(slot)
		slot.lockFlag = flag
		if flag == true and Sense.lockProven then
			return "no", "the game locks it under this loss of control"
		end
		return "blind", "a loss of control the game would not name"
	end
	if how == nil and kind == nil then return "no", "you have control" end
	-- The count itself is hidden, or the client has no such API: only a control
	-- lost event says control is gone.
	local lostAt = Sense.lostAt
	if lostAt then
		local full
		if type(_G.HasFullControl) == "function" then full = plain(_G.HasFullControl()) end
		if full == true or now - lostAt > UNSURE_SECONDS then
			Sense.lostAt = nil
			return "no", "you have control"
		end
		return "blind", "a loss of control the game would not name"
	end
	return "no", "you have control"
end

-- Hypothermia, where the client has it: a plain aura where readable, else the
-- row's own lockout from your own cast. A nil in a fight is never read as absent
-- on its own.
function Sense.nolockout(slot, now)
	local lock = slot.row.lockout
	if not lock then return "yes" end
	local auras = _G.C_UnitAuras
	if type(auras) == "table" and type(auras.GetPlayerAuraBySpellID) == "function" then
		if type(plain(auras.GetPlayerAuraBySpellID(lock.aura))) == "table" then return "no", "Hypothermia" end
	end
	if slot.castAt and now - slot.castAt < lock.seconds then return "no", "Hypothermia" end
	return "yes"
end

---------------------------------------------------------------------------
-- the gem: bags counted at the pull and on the fight's bag events, never per flush
---------------------------------------------------------------------------

-- How many of each of the row's items the bags hold, by a direct call after a
-- type() check (no pcall, no safecall: this runs in a fight on a bag event); a
-- count the client will not give counts as none.
function Sense.CountItems(slot)
	local counts = slot.count or {}
	slot.count = counts
	local api = _G.C_Item
	local call = type(api) == "table" and type(api.GetItemCount) == "function" and api.GetItemCount or _G.GetItemCount
	for _, id in ipairs(slot.row.items or {}) do
		local n
		if type(call) == "function" then n = plain(call(id)) end
		counts[id] = type(n) == "number" and n or 0
	end
	return counts
end

-- An item's cooldown by the client's own figures: true running, false over or
-- never begun, nil where the figures say nothing (hidden in a fight).
local function ItemCooling(id, now)
	local active, start, duration
	local spellApi = _G.C_Spell
	if type(spellApi) == "table" and type(spellApi.GetItemCooldown) == "function" then
		local rec = plain(spellApi.GetItemCooldown(id))
		if type(rec) == "table" then
			active, start, duration = plain(rec.isActive), plain(rec.startTime), plain(rec.duration)
		end
	end
	if active == nil and start == nil then
		local container, itemApi = _G.C_Container, _G.C_Item
		local call = type(container) == "table" and container.GetItemCooldown
			or type(itemApi) == "table" and itemApi.GetItemCooldown or _G.GetItemCooldown
		if type(call) == "function" then
			local a, b = call(id)
			start, duration = plain(a), plain(b)
		end
	end
	if active == true then return true end
	if active == false then return false end
	if type(start) == "number" and type(duration) == "number" then
		if duration > 1.5 and start + duration > now then return true end
		return false
	end
	return nil
end

-- A gem of a kind this client names is in the bags and off its cooldown.
function Sense.itemready(slot, now)
	local counts = slot.count
	local anyCount, plainReady, unknown = false, false, false
	for _, id in ipairs(slot.row.items or {}) do
		if counts and (counts[id] or 0) > 0 then
			anyCount = true
			local cooling = ItemCooling(id, now)
			if cooling == false then plainReady = true
			elseif cooling == nil then unknown = true end
		end
	end
	if not anyCount then return "no", "no gem in your bags" end
	if plainReady then return "yes" end
	if unknown then
		-- Nothing readable: Manners' own clock, begun by your own use of it.
		if slot.readyAt and now < slot.readyAt then return "no", "the gem is cooling down" end
		return "yes"
	end
	return "no", "the gem is cooling down"
end

---------------------------------------------------------------------------
-- the drink: out of a fight only, so every call here may be a plain one
---------------------------------------------------------------------------

local drinkNames, drinkSpell, drinkItem = {}, {}, {}

-- The client's name for the row's drink spell ("Drink"), kept; a name the client
-- has not loaded yet is not kept.
function Sense.DrinkName(slot)
	local id = slot.row.drink
	local name = drinkNames[id]
	if name == nil then
		name = ns.SpellNameFor(id)
		if type(name) ~= "string" or name == "" then return nil end
		drinkNames[id] = name
	end
	return name
end

-- Whether an own cast's spell id is a drink (a drink item casts its own spell
-- of the same name), kept per id like the pet's meals are.
function Sense.DrinkSpell(slot, id)
	if type(id) ~= "number" then return false end
	local known = drinkSpell[id]
	if known ~= nil then return known end
	local drink = Sense.DrinkName(slot)
	if not drink then return false end
	local name = ns.SpellNameFor(id)
	if type(name) ~= "string" then return false end
	known = name == drink
	drinkSpell[id] = known
	return known
end

local function Usable(id)
	local api = _G.C_Item
	local call = type(api) == "table" and api.IsUsableItem or _G.IsUsableItem
	if type(call) ~= "function" then return true end
	return plain(call(id)) ~= false
end

-- Whether the item's use spell is a drink: its use spell's name against the
-- client's "Drink". A name the client has not loaded is not kept, so the next
-- count asks again. Food's use spell is "Food", never a drink. Honest limit: on
-- Mists and retail a drink whose spell is "Refreshment" or "Food & Drink" is not
-- recognised here (a conjured one still is, from the mage's own list).
local function IsDrinkItem(slot, id)
	local known = drinkItem[id]
	if known ~= nil then return known end
	local api = _G.C_Item
	local call = type(api) == "table" and api.GetItemSpell or _G.GetItemSpell
	local drink = Sense.DrinkName(slot)
	if type(call) ~= "function" or not drink then return false end
	local name = plain(call(id))
	if type(name) ~= "string" or name == "" then return false end
	known = name == drink
	drinkItem[id] = known
	return known
end

-- The level an item asks of whoever uses it.
local function MinLevel(id)
	local api = _G.C_Item
	local call = type(api) == "table" and api.GetItemInfo or _G.GetItemInfo
	if type(call) ~= "function" then return 0 end
	local level = plain((select(5, call(id))))
	return type(level) == "number" and level or 0
end

-- Walks the bags once, out of a fight (a refresh, or the flush after a bag
-- event; never at the pull, never in a fight, never per mana event): the best
-- drink there. Your conjured water first, the best your level allows (the
-- mage's own list, best first), then any other drink the bags hold, the highest
-- level it asks first. An item the client calls unusable is passed over. Direct
-- calls after type() checks, no pcall. True when the pick changed.
function Sense.CountDrinks(slot)
	local held = {}
	local container = _G.C_Container
	local slotsIn = type(container) == "table" and container.GetContainerNumSlots or _G.GetContainerNumSlots
	local itemIn = type(container) == "table" and container.GetContainerItemID or _G.GetContainerItemID
	if type(slotsIn) == "function" and type(itemIn) == "function" then
		for bag = 0, 4 do
			local n = plain(slotsIn(bag))
			if type(n) == "number" then
				for i = 1, n do
					local id = plain(itemIn(bag, i))
					if type(id) == "number" then held[id] = true end
				end
			end
		end
	end
	local level = type(_G.UnitLevel) == "function" and plain(_G.UnitLevel("player")) or nil
	if type(level) ~= "number" then level = nil end
	local pick
	local conjured = {}
	local courtesy = ns.Courtesy
	local rows = courtesy and courtesy.WaterRows and courtesy.WaterRows() or {}
	for _, row in ipairs(rows) do
		for _, item in ipairs(row.items) do conjured[item] = true end
	end
	for _, row in ipairs(rows) do
		if not pick and (row.level == nil or level == nil or row.level <= level) then
			for _, item in ipairs(row.items) do
				if held[item] and (level == nil or ((row.needs and row.needs[item]) or 0) <= level) and Usable(item) then
					pick = item
					break
				end
			end
		end
	end
	if not pick then
		local best
		for id in pairs(held) do
			if not conjured[id] and IsDrinkItem(slot, id) then
				local need = MinLevel(id)
				if (level == nil or need <= level) and Usable(id)
					and (not best or need > best.need or (need == best.need and id < best.id)) then
					best = { id = id, need = need }
				end
			end
		end
		pick = best and best.id
	end
	local changed = slot.drinkPick ~= pick
	slot.drinkPick = pick
	slot.drinkIcon = nil
	if pick then
		local api = _G.C_Item
		local icon = type(api) == "table" and type(api.GetItemIconByID) == "function" and api.GetItemIconByID(pick)
		if not icon and type(_G.GetItemIcon) == "function" then icon = _G.GetItemIcon(pick) end
		slot.drinkIcon = icon or nil
	end
	return changed
end

-- A drink is in the bags (a field: the bags are walked by CountDrinks, never here).
function Sense.drinkheld(slot)
	if not slot.drinkPick then return "no", "no drink in your bags" end
	return "yes"
end

-- Standing still, alive, on your feet: a few plain calls, an unreadable answer
-- counts as "not".
function Sense.still(slot)
	if plain(UnitIsDeadOrGhost("player")) == true then return "no", "you are dead" end
	if Sense.moving then return "no", "you are moving" end
	if type(_G.IsMounted) == "function" and plain(_G.IsMounted()) == true then return "no", "you are mounted" end
	if type(_G.IsSwimming) == "function" and plain(_G.IsSwimming()) == true then return "no", "you are swimming" end
	if (type(_G.UnitOnTaxi) == "function" and plain(_G.UnitOnTaxi("player")) == true)
		or (type(_G.IsFlying) == "function" and plain(_G.IsFlying()) == true) then
		return "no", "you are on a taxi"
	end
	if slot.row.forms and type(_G.GetShapeshiftForm) == "function" then
		local form = plain(_G.GetShapeshiftForm())
		if type(form) == "number" and form > 0 then return "no", "you are shapeshifted" end
	end
	return "yes"
end

-- Not drinking already, whichever shape the Drink aura comes back in. Plain: a
-- table says you are drinking, and a plain absence ends the clock early (you
-- drank to full). Hidden or thrown: the clock of your own drink (a cast of the
-- drink spell, a press of the button), ended by moving.
function Sense.notdrinking(slot, now)
	local name = Sense.DrinkName(slot)
	local auras = _G.C_UnitAuras
	if name and type(auras) == "table" and type(auras.GetAuraDataBySpellName) == "function" then
		-- A restricted read: a throw is told from a plain nil, so only a plain
		-- absence ends the clock.
		local ok, rawAura = pcall(auras.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if ok and not issecretvalue(rawAura) then
			if type(rawAura) == "table" then return "no", "you are drinking" end
			slot.castAt = nil
		end
	end
	if slot.castAt and now - slot.castAt < (slot.row.seconds or 0) then return "no", "you are drinking" end
	return "yes"
end

---------------------------------------------------------------------------
-- falling: no event says so on any client, so a watch asks IsFalling (Moments.lua)
---------------------------------------------------------------------------

local FALL_SECONDS = 1.0
-- Since when the watch has read "falling" without a break, and whether the
-- game hid the answer at the last read.
Sense.fallSince, Sense.fallSecret = nil, false

-- One read of IsFalling, for the watch: keeps fallSince and fallSecret. Answers
-- whether you are falling plainly.
function Sense.ReadFall(now)
	if type(_G.IsFalling) ~= "function" then
		Sense.fallSince, Sense.fallSecret = nil, false
		return false
	end
	local rawFall = _G.IsFalling()
	if issecretvalue(rawFall) then
		Sense.fallSince, Sense.fallSecret = nil, true
		return false
	end
	Sense.fallSecret = false
	if plain(rawFall) == true then
		if not Sense.fallSince then Sense.fallSince = now end
		return true
	end
	Sense.fallSince = nil
	return false
end

function Sense.falling(slot, now)
	if Sense.fallSecret then return "no", "the game would not say whether you fall" end
	local since = Sense.fallSince
	if not since or now - since < FALL_SECONDS then return "no", "you are not falling" end
	if type(_G.IsFlying) == "function" and plain(_G.IsFlying()) == true then return "no", "you are flying" end
	if type(_G.UnitOnTaxi) == "function" and plain(_G.UnitOnTaxi("player")) == true then return "no", "you are on a taxi" end
	if plain(UnitIsDeadOrGhost("player")) == true then return "no", "you are dead" end
	if slot.castAt and now - slot.castAt < (slot.row.seconds or 0) then return "no", "it is on you" end
	return "yes"
end

---------------------------------------------------------------------------
-- the wards: what has just hit you, by school
---------------------------------------------------------------------------

local HIT_SECONDS = 10
-- The schools a ward answers (Fire 4, Frost 16), when each last hit you.
Sense.lastHit = {}
local WARD_SCHOOLS = { 4, 16 }

-- Whether a school mask holds a school (the schools are powers of two).
local function HasSchool(mask, school) return mask % (school * 2) >= school end

-- UNIT_COMBAT on you: a wound of a school the game states plainly. A hidden
-- mask is ignored.
function Sense.Hit(action, rawMask, now)
	if plain(action) ~= "WOUND" then return end
	local mask = plain(rawMask)
	if type(mask) ~= "number" or mask <= 0 then return end
	for _, school in ipairs(WARD_SCHOOLS) do
		if HasSchool(mask, school) then Sense.lastHit[school] = now end
	end
end

-- Damage of the row's school hit you in the last ten seconds, and no other
-- ward school hit more recently. Or your target is casting now and, this
-- fight, the last ward school to hit you was this one: the game never shows a
-- cast's own school, so what the fight has thrown at you is the guess (the
-- owner asked for the ward while the enemy casts). Nothing hit yet: dark.
function Sense.schoolhit(slot, now)
	local school = slot.row.school
	local at = school and Sense.lastHit[school]
	if not at then return "no", "nothing of that kind has hit you" end
	local recent = now - at <= HIT_SECONDS
	for other, when in pairs(Sense.lastHit) do
		if other ~= school and when > at and (not recent or now - when <= HIT_SECONDS) then
			return "no", "another kind hit you more recently"
		end
	end
	if recent then return "yes" end
	if Sense.casting(slot) == "yes" then return "yes" end
	return "no", "your target is not casting and nothing of that kind hit you lately"
end

---------------------------------------------------------------------------
-- Spellsteal and Cold Snap
---------------------------------------------------------------------------

local STEAL_MAX = 8

-- A buff on the target the game marks as stealable. Plain where the auras are
-- readable; where they are withheld, the plain list of buff ids is walked and
-- each record's hidden flag is handed to the game, ORed ("any").
function Sense.stealable(slot)
	local auras = _G.C_UnitAuras
	if type(auras) ~= "table" then return "blind", "your target's buffs" end
	local byIndex = auras.GetAuraDataByIndex
	local withheld = false
	if type(byIndex) == "function" then
		for i = 1, 40 do
			local rec = byIndex("target", i, "HELPFUL")
			if type(rec) ~= "table" then
				if issecretvalue(rec) then withheld = true end
				break
			end
			if issecretvalue(rec) then
				withheld = true
				break
			end
			local rawFlag = rec.isStealable
			if issecretvalue(rawFlag) then
				withheld = true
				break
			end
			if plain(rawFlag) == true then return "yes" end
		end
	end
	local listed = auras.GetUnitAuraInstanceIDs
	if type(listed) ~= "function" then
		if withheld then return "blind", "your target's buffs" end
		return "no", "nothing to steal"
	end
	local ids = listed("target", "HELPFUL")
	if type(ids) ~= "table" or issecretvalue(ids) then return "blind", "your target's buffs" end
	if #ids == 0 then return "no", "your target has no buffs" end
	local byId = auras.GetAuraDataByAuraInstanceID
	if type(byId) ~= "function" then return "blind", "your target's buffs" end
	local held, count, sawPlain = {}, 0, false
	for i = 1, math.min(#ids, STEAL_MAX) do
		local rec = byId("target", ids[i])
		if type(rec) == "table" and not issecretvalue(rec) then
			local rawSteal = rec.isStealable
			if type(rawSteal) == "boolean" then
				if issecretvalue(rawSteal) then
					count = count + 1
					held[count] = rawSteal
				else
					sawPlain = true
					if plain(rawSteal) == true then return "yes" end
				end
			end
		end
	end
	if count > 0 then
		if CanPaint("any") then
			slot.game = { "any", nil, held, count }
			return "game", "whether a buff of your target can be stolen"
		end
		return "blind", "whether a buff of your target can be stolen"
	end
	if sawPlain then return "no", "nothing to steal" end
	return "blind", "your target's buffs"
end

-- Cold Snap brings back the partner spell: lit only while that one is plainly on
-- cooldown, by the game's own figures or Manners' own clock for it. A partner
-- that is ready, or whose cooldown the fight hides and no clock of ours knows,
-- keeps it dark.
function Sense.partnercooling(slot, now)
	local partner = slot.partner
	if not partner then return "no", "the spell it brings back is not known" end
	local cooling = Cooling(partner, partner.id, now)
	if cooling == true then return "yes" end
	if cooling == false then return "no", "the spell it brings back is ready" end
	if partner.readyAt and now < partner.readyAt then return "yes" end
	return "no", "the spell it brings back is ready, or its cooldown is hidden"
end

---------------------------------------------------------------------------
-- evaluating a row
---------------------------------------------------------------------------

-- The words for what a lit button saw, for the trail and the tooltip.
Sense.WORDS = {
	fight = "in a fight", ready = "ready", usable = "castable", enemy = "a hostile target",
	casting = "your target is casting", interruptible = "it can be interrupted", inrange = "in range",
	lowhealth = "your health is low", lowmana = "your mana is low", stuck = "you are stunned or rooted",
	nolockout = "no Hypothermia", itemready = "a gem in your bags, ready", falling = "you have been falling for a second",
	partnercooling = "the spell it brings back is cooling down", stealable = "a buff you can steal",
	schoolhit = "that kind of damage just hit you", calm = "out of a fight", drinkheld = "a drink in your bags",
	still = "standing still", notdrinking = "not drinking already",
}

-- "lit", "game" or "dark" and, for dark, why; the third answer names what was
-- passed over where a hidden value had no route.
function Sense.Evaluate(slot, now)
	local row = slot.row
	local needs = row.needs
	slot.game = nil
	local game, gameWhat, passed
	for i = 1, #needs do
		local name = needs[i]
		local signal = Sense[name]
		if type(signal) ~= "function" then return "dark", "no signal " .. name end
		local verdict, why = signal(slot, now)
		if verdict == "no" then
			slot.game = nil
			return "dark", why
		elseif verdict == "blind" then
			if row.blind ~= "weak" then
				slot.game = nil
				return "dark", "hidden, and nothing on this client takes it: " .. tostring(why)
			end
			passed = passed and (passed .. ", " .. tostring(why)) or tostring(why)
		elseif verdict == "game" then
			if game == nil then
				game, gameWhat = slot.game, why
			end
		end
		slot.game = nil
	end
	if game then
		slot.game = game
		return "game", gameWhat, passed
	end
	return "lit", nil, passed
end

-- The signals a row's needs cover, as a set (for the events Pull registers).
function Sense.NeedSet(row)
	local set = {}
	for _, name in ipairs(row.needs) do set[name] = true end
	return set
end
