-- A paladin's party in a dungeon, out of a fight (a player's report on WoW
-- Forever, 1.12: "players missing my blessings, and the prompt ignores
-- them"). The walk of the group (Queue.lua, BuildQueue's visit) for a party
-- member missing your blessing inside an instance, with the defaults:
--
--   * every one of them is offered a blessing;
--   * still so when the spell's own range check says nothing and the follow
--     prompt is withheld, which an instance may do (Core.lua, InRange,
--     PastFollowReach): a silence is "could not tell", which is offered;
--   * still so with Greater Blessing of Kings learned and its symbols
--     carried, when too few of one class need it for the group cast
--     (GroupBuffs.lua): the few are offered one by one, not held for it;
--   * and again a few seconds after a pull, once the fight's caution is over
--     (Core.lua, UNVERIFIED_SECONDS).
--
-- Every scenario name starts with "dungeon-party:".

local dir, H = ...
local fail, load = H.fail, H.load

local SYMBOL_OF_KINGS = 21177

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dain", "Moor" },
}
local CLASSES = { party1 = "WARRIOR", party2 = "MAGE", party3 = "PRIEST", party4 = "WARRIOR" }

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty", "IsInInstance",
	"GetItemCount", "CheckInteractDistance", "C_UnitAuras" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

-- A paladin on Forever inside a five-man with `CLASSES`, nobody wearing a
-- blessing. `env.greater`: Greater Blessing of Kings learned, symbols in the
-- bags. `env.setup(ns)` runs before the first scan.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour("camelot")
	Mock.class = "PALADIN"
	Mock.groupSize = 5
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restoreUnits = H.strangers(PARTY)
	local units = {}
	for _, name in ipairs(TOUCHED) do units[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit)
		local class = CLASSES[unit]
		if class then return class, class end
		return units.UnitClass(unit)
	end)
	rawset(_G, "UnitPowerMax", function(unit, power)
		if CLASSES[unit] == "WARRIOR" then return 0 end
		return units.UnitPowerMax(unit, power)
	end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	rawset(_G, "IsInInstance", function() return true, "party" end)
	rawset(_G, "GetItemCount", function(id)
		if env.greater and id == SYMBOL_OF_KINGS then return 40 end
		return units.GetItemCount and units.GetItemCount(id) or 0
	end)
	if env.followWithheld then
		rawset(_G, "CheckInteractDistance", function() return nil end)
	end
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			if CLASSES[unit] then return nil end
			return base.GetUnitAuraBySpellID(unit, spellId)
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			local buff = ns.FindBuff("PALADIN", key)
			for _, id in ipairs(buff and buff.ranks or {}) do known[id] = true end
			if env.rangeless then
				Mock.rangeless = Mock.rangeless or {}
				for _, id in ipairs(buff and buff.ranks or {}) do Mock.rangeless[id] = true end
			end
			if env.greater and key == "kings" then
				for _, rank in ipairs(buff and buff.groupCast or {}) do known[rank.id] = true end
			end
		end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = false
		if env.setup then env.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, units[name]) end
	restoreUnits()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Who of the party the queue offers a blessing, one by one or in a group
-- cast that names them, and what for the rest.
local function missing(ns)
	Mock.advance(4)
	local offered = {}
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.buff then offered[entry.name] = true end
		local g = entry.groupCast
		for _, name in ipairs(g and g.members or {}) do offered[name] = true end
	end
	local left = {}
	for token in pairs(PARTY) do
		if not offered[filed(token)] then left[#left + 1] = token .. " (" .. CLASSES[token] .. ")" end
	end
	table.sort(left)
	return left
end

local function expectAll(scenario, ns, how)
	local left = missing(ns)
	if #left > 0 then
		fail(scenario, how .. ": nobody offers a blessing to " .. table.concat(left, ", "))
	end
end

do
	local scenario = "dungeon-party: in a dungeon out of a fight, every member missing a blessing is offered"
	session(scenario, {}, function(ns) expectAll(scenario, ns, "with the defaults") end)
end

do
	local scenario = "dungeon-party: a silent range check and a withheld follow prompt still offer the party"
	session(scenario, { rangeless = true, followWithheld = true }, function(ns)
		expectAll(scenario, ns, "with nothing able to say how far")
	end)
end

do
	local scenario = "dungeon-party: Greater Blessing of Kings known, too few of a class: the few are offered one by one"
	session(scenario, { greater = true }, function(ns)
		expectAll(scenario, ns, "with Greater Blessing of Kings and its symbols")
	end)
end

do
	local scenario = "dungeon-party: a few seconds after a pull the party is offered again"
	session(scenario, {}, function(ns)
		Mock.inCombat = true
		ns.addon:PLAYER_REGEN_DISABLED()
		Mock.advance(20)
		Mock.inCombat = false
		ns.addon:PLAYER_REGEN_ENABLED()
		Mock.runTimers(0)
		Mock.advance(15)
		Mock.runTimers(15)
		expectAll(scenario, ns, "after a pull")
	end)
end
