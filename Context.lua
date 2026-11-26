-- Shared, typed-shaped eligibility results for every prompt decision.

local _, ns = ...
local plain = ns.plain

local REQUIREMENTS = {
	buff = {
		exists = true, player = true, alive = true, connected = true,
		friendly = true,
	},
	cure = {
		exists = true, player = true, alive = true, connected = true,
		friendly = true, usable = true, notCooling = true,
	},
	own = {
		exists = true, self = true, alive = true, usable = true,
		notCooling = true, available = true,
	},
	service = {
		exists = true, player = true, alive = true, connected = true,
		friendly = true, scope = true, usable = true, available = true,
	},
}
local RESULT = {}
local MODULE = {
	buff = "core", cure = "combat", own = "mybuffs", service = "services",
}
local REJECT_MAX = 20
local rejected = {}
for i = 1, REJECT_MAX do rejected[i] = {} end
local rejectedAt, rejectedCount = 0, 0

local function Requirements(kind)
	return REQUIREMENTS[kind] or REQUIREMENTS.buff
end

local function Decision(kind, action, target, priority, reason, eligible, cacheAge)
	RESULT.eligible = eligible == true
	RESULT.action = action
	RESULT.target = target
	RESULT.priority = priority
	RESULT.reason = reason
	RESULT.cacheAge = cacheAge
	RESULT.module = MODULE[kind] or "core"
	RESULT.requirements = Requirements(kind)
	if eligible ~= true then ns.ContextReject(kind, action, target, priority, reason, cacheAge) end
	return RESULT
end

function ns.ContextDecision(kind, action, target, priority, reason, eligible, cacheAge)
	return Decision(kind, action, target, priority, reason, eligible, cacheAge)
end

local function SafeText(value)
	value = plain(value)
	if type(value) ~= "string" or value == "" then return "<withheld>" end
	if #value > 100 then return value:sub(1, 100) end
	return value
end

local function SafeNumber(value)
	value = plain(value)
	if type(value) ~= "number" or value ~= value or value < 0 or value > 86400 then return nil end
	return value
end

function ns.ContextReject(kind, action, target, priority, reason, cacheAge)
	rejectedAt = rejectedAt % REJECT_MAX + 1
	rejectedCount = math.min(REJECT_MAX, rejectedCount + 1)
	local row = rejected[rejectedAt]
	row.module = MODULE[kind] or "core"
	row.kind = type(kind) == "string" and kind or "unknown"
	row.action = SafeText(action)
	row.target = SafeText(target)
	row.priority = SafeNumber(priority)
	row.reason = SafeText(reason)
	row.cacheAge = SafeNumber(cacheAge)
end

function ns.ContextRejectionLines()
	local out = {}
	local first = rejectedAt - rejectedCount + 1
	for i = 1, rejectedCount do
		local row = rejected[(first + i - 2) % REJECT_MAX + 1]
		local age = row.cacheAge == nil and "none" or ("%.1fs"):format(row.cacheAge)
		local priority = row.priority == nil and "none" or tostring(row.priority)
		out[#out + 1] = ("context rejected: %s/%s action=%s target=%s priority=%s reason=%s cache=%s")
			:format(row.module, row.kind, row.action, row.target, priority, row.reason, age)
	end
	return out
end

local function RejectTarget(kind, unit, reason)
	if reason ~= "unseen" and reason ~= "read" then
		ns.ContextReject(kind, "target", unit, nil, reason, nil)
	end
	return false, reason, reason ~= "npc" and reason ~= "self" and reason ~= "unseen" and reason ~= "read"
end

-- The target tests common to buff, cure and service decisions. A withheld
-- target value is ineligible; it is never compared with a plain boolean.
function ns.ContextTarget(kind, unit, allowSelf, pet, owner, minLevel)
	local exists = plain(UnitExists and UnitExists(unit))
	if exists ~= true then
		return RejectTarget(kind, unit, exists == nil and "read" or "unseen")
	end
	local self = plain(UnitIsUnit and UnitIsUnit(unit, pet and "pet" or "player"))
	if self == true and not allowSelf then
		return RejectTarget(kind, unit, "self")
	end
	local player = plain(UnitIsPlayer and UnitIsPlayer(unit))
	if pet then
		if player == true then
			return RejectTarget(kind, unit, "player")
		end
	else
		if player ~= true then
			return RejectTarget(kind, unit, player == false and "npc" or "read")
		end
	end
	if pet then
		local ownerVehicle = _G.UnitHasVehicleUI
		local selfVehicle = _G.UnitInVehicle
		if (type(ownerVehicle) == "function" and plain(ownerVehicle(owner)) == true)
			or (type(selfVehicle) == "function" and plain(selfVehicle(owner)) == true) then
			return RejectTarget(kind, unit, "vehicle")
		end
	end
	local dead = plain(UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
	if dead == true then
		return RejectTarget(kind, unit, "dead")
	end
	local friendly = self == true or plain(UnitCanAssist and UnitCanAssist("player", unit))
	if friendly ~= true then
		return RejectTarget(kind, unit, friendly == false and "hostile" or "read")
	end
	local connected = plain(UnitIsConnected and UnitIsConnected(unit))
	if connected == false then
		return RejectTarget(kind, unit, "offline")
	end
	if type(minLevel) == "number" and minLevel > 1 then
		local level = plain(UnitLevel and UnitLevel(unit))
		if type(level) == "number" and level > 0 and level < minLevel then
			return RejectTarget(kind, unit, "level")
		end
	end
	return true, nil, true
end
