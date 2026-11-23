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
-- evaluating a row
---------------------------------------------------------------------------

-- The words for what a lit button saw, for the trail and the tooltip.
Sense.WORDS = {
	fight = "in a fight", ready = "ready", usable = "castable", enemy = "a hostile target",
	casting = "your target is casting", interruptible = "it can be interrupted", inrange = "in range",
	lowhealth = "your health is low", lowmana = "your mana is low", stuck = "you are stunned or rooted",
	nolockout = "no Hypothermia",
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
