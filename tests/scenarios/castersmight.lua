-- Might held back from mages, warlocks and priests (1.11.14). A player on
-- CurseForge had a mage whose Wisdom (another paladin's, or running low) left
-- the walk to offer Might, which does nothing for a mage, and asked for a
-- switch to refresh Wisdom or Kings only. "Don't offer Might to mages, warlocks
-- and priests" (buff.skipCasters) takes Might out of the walk for those three;
-- a warrior still gets it, and so does anybody who asks. Off by default until
-- the right-buff audit, on since (tests/scenarios/audit-right-buff.lua holds
-- the default): the scenario that held "off by default" now switches it off.
--
-- Every scenario name starts with "castersmight:" so the mutations in
-- tests/mutations/castersmight.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local CLIENTS = { "vanilla", "tbc", "camelot" }

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

local function said(out)
	local list = {}
	for token, what in pairs(out) do list[#list + 1] = token .. "=" .. tostring(what) end
	table.sort(list)
	return table.concat(list, ", ")
end

-- party1 a mage, party2 a warlock, party3 a priest and party4 a warrior, each
-- wearing another paladin's Wisdom (the warrior cannot use it, so wears none).
local FOUR = { party1 = "MAGE", party2 = "WARLOCK", party3 = "PRIEST", party4 = "WARRIOR" }

local function wearing(ns, env)
	local wisdom = ids(ns, "wisdom")[1]
	env.wears.party1 = { [wisdom] = THEIRS }
	env.wears.party2 = { [wisdom] = THEIRS }
	env.wears.party3 = { [wisdom] = THEIRS }
end

for _, client in ipairs(CLIENTS) do
	do
		-- Re-aimed by the right-buff audit: the switch is on by default now, so
		-- this one turns it off to hold what off does.
		local scenario = "castersmight: " .. client .. ": switched off, casters are offered Might as ever"
		local env = { client = client, classes = FOUR,
			setup = function(ns) ns.db.profile.buff.kingsFirst = false ns.db.profile.buff.skipCasters = false end }
		session(scenario, env, function(ns)
			if ns.defaults.profile.buff.skipCasters ~= true then fail(scenario, "the switch is not on by default") end
			wearing(ns, env)
			local out = offers(ns, env)
			for token, class in pairs(FOUR) do
				if out[token] ~= "might" then
					fail(scenario, ("%s (%s) was offered %s, not might: %s"):format(token, class, tostring(out[token]), said(out)))
					return
				end
			end
		end)
	end

	do
		local scenario = "castersmight: " .. client .. ": on, a mage, a warlock and a priest are offered Kings, a warrior still Might"
		local env = { client = client, classes = FOUR,
			setup = function(ns) ns.db.profile.buff.skipCasters = true ns.db.profile.buff.kingsFirst = false end }
		session(scenario, env, function(ns)
			wearing(ns, env)
			local out = offers(ns, env)
			local want = { party1 = "kings", party2 = "kings", party3 = "kings", party4 = "might" }
			for token, what in pairs(want) do
				if out[token] ~= what then
					fail(scenario, ("offered %s; expected party1..3=kings, party4=might"):format(said(out)))
					return
				end
			end
		end)
	end

	do
		local scenario = "castersmight: " .. client .. ": on and Might pinned, a caster is offered nothing"
		local env = { client = client, classes = FOUR,
			setup = function(ns)
				ns.db.profile.buff.skipCasters = true
				ns.db.profile.buff.kingsFirst = false
				ns.db.profile.buff.choice = "might"
			end }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if out.party1 ~= false or out.party2 ~= false or out.party3 ~= false then
				fail(scenario, "with Might pinned, a caster was offered: " .. said(out))
			end
			if out.party4 ~= "might" then fail(scenario, "the warrior was offered " .. tostring(out.party4)) end
		end)
	end

	do
		local scenario = "castersmight: " .. client .. ": on, a druid and a shaman are still offered Might"
		local env = { client = client, classes = { party1 = "DRUID", party2 = "SHAMAN", party3 = "HUNTER", party4 = "ROGUE" },
			setup = function(ns) ns.db.profile.buff.skipCasters = true ns.db.profile.buff.kingsFirst = false end }
		session(scenario, env, function(ns)
			-- Each with another paladin's Wisdom on (a rogue cannot use it), so
			-- Might is what is left to offer.
			local wisdom = ids(ns, "wisdom")[1]
			for token in pairs(env.classes) do
				if token ~= "party4" then env.wears[token] = { [wisdom] = THEIRS } end
			end
			local out = offers(ns, env)
			for token in pairs(env.classes) do
				if out[token] ~= "might" then fail(scenario, token .. " was not offered Might: " .. said(out)) return end
			end
		end)
	end
end

do
	local scenario = "castersmight: somebody who asks for Might by name is still offered it"
	local env = { client = "vanilla", classes = { party1 = "MAGE" } }
	session(scenario, env, function(ns)
		local might = ns.FindBuff("PALADIN", "might")
		local function has() return false end
		local base = { name = "Gwen", unit = "party1", inGroup = true, inParty = true, whenBuffed = "skip",
			casterOnly = true }
		if ns.PickBuffFor({ might }, base, has) ~= nil then
			fail(scenario, "SKIPPED -- Might is not held back without the ask")
			return
		end
		base.asked = true
		local got = ns.PickBuffFor({ might }, base, has)
		if not got or got.key ~= "might" then
			fail(scenario, "somebody who asked was offered " .. tostring(got and got.key) .. ", not Might")
		end
	end)
end

do
	local scenario = "castersmight: Who to buff has the switch for a paladin and for nobody else"
	for _, class in ipairs({ "PALADIN", "MAGE" }) do
		Mock.reset()
		Mock.setFlavour("vanilla")
		Mock.class = class
		local ns = load(scenario)
		if ns then
			H.freshPrompt(ns, scenario)
			local control = H.findOption(ns.optionsTable, "skipCasters")
			if not control then
				fail(scenario, "no switch on Who to buff for " .. class)
			else
				local hidden = type(control.hidden) == "function" and control.hidden() == true
				if (class == "PALADIN") == hidden then
					fail(scenario, class .. (hidden and " is not shown the switch" or " is shown the switch"))
				end
				if class == "PALADIN" then
					if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
					control.set({ "who", "skipCasters" }, true)
					if ns.db.profile.buff.skipCasters ~= true or not control.get() then fail(scenario, "the switch was not kept") end
				end
			end
		end
		Mock.reset()
	end
end
