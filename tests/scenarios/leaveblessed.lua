-- Skip players another paladin has blessed (1.11.11). A player asked on
-- CurseForge: in a group where the paladins share out the blessings, Manners
-- offered Kings to somebody who already carried another paladin's Might, since
-- blessings from two paladins stack. With the switch on (Who to buff, under
-- Kings first; off by default), anybody carrying any blessing from another
-- paladin is left alone, a pinned blessing included -- except somebody who asked
-- for one by name. A blessing from nobody the client names is read as ours, as it
-- always was, and one of ours is covered as ever.
--
-- Every scenario name starts with "leaveblessed:" so the mutations in
-- tests/mutations/leaveblessed.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local CLIENTS = { "vanilla", "tbc", "camelot" }

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
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
	Mock.groupSize = 4
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

-- party1 wears another paladin's Might, party2 nothing, party3 our own Might.
local THREE = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR" }

for _, client in ipairs(CLIENTS) do
	for _, on in ipairs({ false, true }) do
		local scenario = "leaveblessed: " .. client .. ": another paladin's Might "
			.. (on and "leaves them alone with the switch on" or "still gets Kings with the switch off")
		local env = { client = client, classes = THREE,
			setup = function(ns) ns.db.profile.buff.leaveBlessed = on end }
		session(scenario, env, function(ns)
			local might = ids(ns, "might")[1]
			env.wears.party1 = { [might] = THEIRS }
			env.wears.party3 = { [might] = OURS }
			local out = offers(ns, env)
			local want = { party1 = (not on) and "kings" or false, party2 = "kings", party3 = false }
			for token, what in pairs(want) do
				if out[token] ~= what then
					fail(scenario, ("offered %s; expected party1=%s, party2=kings, party3=false")
						:format(said(out), tostring(want.party1)))
					break
				end
			end
		end)
	end

	do
		local scenario = "leaveblessed: " .. client .. ": a pinned Kings is held back from another paladin's Wisdom"
		local env = { client = client, classes = { party1 = "MAGE", party2 = "MAGE" },
			setup = function(ns)
				ns.db.profile.buff.leaveBlessed = true
				ns.db.profile.buff.choice = "kings"
			end }
		session(scenario, env, function(ns)
			env.wears.party1 = { [ids(ns, "wisdom")[1]] = THEIRS }
			local out = offers(ns, env)
			if out.party1 ~= false or out.party2 ~= "kings" then
				fail(scenario, "with Kings pinned, offered " .. said(out) .. "; expected party1=false, party2=kings")
			end
		end)
	end

	do
		local scenario = "leaveblessed: " .. client .. ": a blessing from nobody named is ours, as ever"
		local env = { client = client, classes = { party1 = "WARRIOR" },
			setup = function(ns) ns.db.profile.buff.leaveBlessed = true end }
		session(scenario, env, function(ns)
			env.wears.party1 = { [ids(ns, "might")[1]] = NOBODY }
			local out = offers(ns, env)
			if out.party1 ~= false then
				fail(scenario, "somebody wearing Might from nobody named was offered " .. tostring(out.party1))
			end
		end)
	end
end

-- Straight through PickBuffFor: somebody who asked by name is still offered.
do
	local scenario = "leaveblessed: somebody who asks for a blessing is still offered it"
	local env = { client = "vanilla", classes = { party1 = "WARRIOR" },
		setup = function(ns) ns.db.profile.buff.leaveBlessed = true end }
	session(scenario, env, function(ns)
		local kings, might = ns.FindBuff("PALADIN", "kings"), ns.FindBuff("PALADIN", "might")
		local function has(buff)
			if buff.key == "might" then return true, 3000, false end
			return false
		end
		local candidates = { kings, might }
		local base = { name = "Gwen", unit = "party1", inGroup = true, inParty = true, whenBuffed = "skip" }
		local quiet = ns.PickBuffFor(candidates, base, has)
		if quiet ~= nil then fail(scenario, "SKIPPED -- not left alone without the ask: " .. tostring(quiet and quiet.key)) return end
		local asked = {}
		for k, v in pairs(base) do asked[k] = v end
		asked.asked = true
		local got = ns.PickBuffFor(candidates, asked, has)
		if not got or got.key ~= "kings" then
			fail(scenario, "somebody who asked was offered " .. tostring(got and got.key) .. ", not Kings")
		end
	end)
end

do
	local scenario = "leaveblessed: Who to buff has the switch for a paladin, off by default"
	local env = { client = "vanilla", classes = { party1 = "WARRIOR" } }
	session(scenario, env, function(ns)
		if ns.defaults.profile.buff.leaveBlessed ~= false then fail(scenario, "the switch is not off by default") end
		local control = H.findOption(ns.optionsTable, "leaveBlessed")
		if not control then fail(scenario, "Who to buff has no switch for it") return end
		if control.hidden and control.hidden() then fail(scenario, "the switch is hidden from a paladin") end
		if control.get() then fail(scenario, "the switch is on in a new profile") end
		control.set({ "who", "leaveBlessed" }, true)
		if ns.db.profile.buff.leaveBlessed ~= true or not control.get() then fail(scenario, "the switch was not kept") end
	end)
end

do
	local scenario = "leaveblessed: a mage is not shown the switch"
	Mock.reset()
	Mock.setFlavour("vanilla")
	Mock.class = "MAGE"
	local ns = load(scenario)
	if ns then
		H.freshPrompt(ns, scenario)
		local control = H.findOption(ns.optionsTable, "leaveBlessed")
		if not control then
			fail(scenario, "SKIPPED -- no switch to look at")
		elseif not (control.hidden and control.hidden()) then
			fail(scenario, "a mage is shown the paladin's switch")
		end
	end
	Mock.reset()
end
