-- Kings and a Fish Bowl (GitHub issue 12). On WoW Forever a camp's Fish Bowl
-- gives everybody sitting near it Boosted Stats (spell 1230098, 8% to all
-- stats), "mutually exclusive with Blessing of Kings": Kings replaces it. With
-- "Don't put Kings over a Fish Bowl's Boosted Stats" (buff.spareFishBowl, off
-- by default), somebody wearing it is offered the paladin's other blessings
-- first, and Kings only when nothing else of his is missing for them.
--
-- Every scenario name starts with "fishbowl:" so the mutations in
-- tests/mutations/fishbowl.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local BOOSTED = 1230098


local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	party4 = { "Dana", "Ives" },
}

local OURS, THEIRS, NOBODY = "player", "nameplate2", true

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty", "C_UnitAuras" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

local function ids(ns, key)
	local buff = ns.FindBuff("PALADIN", key)
	return buff and buff.ranks or {}
end

-- A paladin on `env.client` with a party of `env.classes` (token -> class),
-- carrying `env.wears` (token -> { [spell id] = source }).
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = "PALADIN"
	Mock.groupSize = 5
	env.wears = env.wears or {}
	local names = {}
	for token in pairs(env.classes) do names[token] = PARTY[token] end
	local restoreUnits = H.strangers(names)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit)
		local class = env.classes[unit]
		if class then return class, class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitPowerMax", function(unit, power)
		local class = env.classes[unit]
		if class == "WARRIOR" or class == "ROGUE" then return 0 end
		return saved.UnitPowerMax(unit, power)
	end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local carrying = env.wears[unit]
			if unit == "player" and carrying == nil then return base.GetUnitAuraBySpellID(unit, spellId) end
			local source = carrying and carrying[spellId]
			if not source then return nil end
			return { spellId = spellId, expirationTime = Mock.now + 3600, duration = 3600,
				sourceUnit = type(source) == "string" and source or nil }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			for _, id in ipairs(ids(ns, key)) do known[id] = true end
		end
		H.freshPrompt(ns, scenario)
		ns.db.profile.sources.self = false
		ns.db.profile.sources.strangers = false
		ns.db.profile.sources.group = true
		if env.setup then env.setup(ns) end
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.addon:Tick()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	restoreUnits()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function offers(ns, env)
	Mock.advance(4)
	local byName = {}
	for _, entry in ipairs(ns.BuildQueue()) do byName[entry.name] = entry end
	local out = {}
	for token in pairs(env.classes) do
		local entry = byName[filed(token)]
		out[token] = entry and entry.buff and entry.buff.key or false
	end
	return out
end

local function wearing(ns, extra)
	local out = { [BOOSTED] = true }
	for _, key in ipairs(extra or {}) do
		for _, id in ipairs(ids(ns, key)) do out[id] = THEIRS end
	end
	return out
end

do
	local scenario = "fishbowl: off by default, Kings goes over the Fish Bowl as before"
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	env.setup = function(ns) env.wears.party1 = wearing(ns) end
	session(scenario, env, function(ns)
		if ns.db.profile.buff.spareFishBowl ~= false then fail(scenario, "the switch is on by default") end
		local got = offers(ns, env)
		if got.party1 ~= "kings" then fail(scenario, "a warrior by a Fish Bowl was offered " .. tostring(got.party1)) end
	end)
end

do
	local scenario = "fishbowl: on, somebody by a Fish Bowl gets another blessing first"
	local env = { client = "camelot", classes = { party1 = "WARRIOR", party2 = "WARRIOR" } }
	env.setup = function(ns)
		env.wears.party1 = wearing(ns)
		ns.db.profile.buff.spareFishBowl = true
	end
	session(scenario, env, function(ns)
		local got = offers(ns, env)
		if got.party1 == "kings" or not got.party1 then
			fail(scenario, "a warrior by a Fish Bowl was offered " .. tostring(got.party1))
		end
		if got.party2 ~= "kings" then fail(scenario, "a warrior with no Fish Bowl was offered " .. tostring(got.party2)) end
	end)
end

do
	local scenario = "fishbowl: on, Kings once nothing else is missing for them"
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	env.setup = function(ns)
		env.wears.party1 = wearing(ns, { "wisdom", "might" })
		ns.db.profile.buff.spareFishBowl = true
	end
	session(scenario, env, function(ns)
		local got = offers(ns, env)
		if got.party1 ~= "kings" then
			fail(scenario, "with Wisdom and Might on them from others, they were offered " .. tostring(got.party1))
		end
	end)
end

do
	local scenario = "fishbowl: the switch is on Who to buff for a Forever paladin, and only there"
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	session(scenario, env, function(ns)
		local option = H.findOption(ns.optionsTable, "spareFishBowl")
		if not option then fail(scenario, "Who to buff has no Fish Bowl switch") return end
		if option.hidden() then fail(scenario, "the switch is hidden from a paladin on WoW Forever") end
		option.set({ "who", "spareFishBowl" }, true)
		if ns.db.profile.buff.spareFishBowl ~= true or option.get() ~= true then
			fail(scenario, "turning it on was not stored")
		end
	end)
	local era = { client = "vanilla", classes = { party1 = "WARRIOR" } }
	session(scenario, era, function(ns)
		local option = H.findOption(ns.optionsTable, "spareFishBowl")
		if option and not option.hidden() then fail(scenario, "the switch shows on Classic Era, which has no Fish Bowl") end
	end)
end
