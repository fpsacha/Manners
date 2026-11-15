-- A blessing for each class (1.11.26). A paladin asked on CurseForge: most
-- mages want Wisdom, and Kings first gives Kings to everybody. Who to buff,
-- under the buff order: pick a class, then the blessing its players are
-- offered first (buff.forClass, CLASS -> buff key). It goes to the head of the
-- walk for somebody of that class and nothing else changes (Core.lua,
-- PickBuffFor): one of yours on them still covers them, one they wear from
-- another paladin or cannot be given is passed over for what the order would
-- have chosen, and a pinned blessing is still the only one.
--
-- Every scenario name starts with "forclass:" so the mutations in
-- tests/mutations/forclass.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local CLIENTS = { "vanilla", "camelot" }

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
}

local THEIRS = "nameplate2"

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty", "C_UnitAuras" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

local function ids(ns, key)
	local buff = ns.FindBuff("PALADIN", key)
	return buff and buff.ranks or {}
end

-- A paladin (or `env.class`) on `env.client` with a party of `env.classes`
-- (token -> class), carrying `env.wears` (token -> { [spell id] = source }).
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = env.class or "PALADIN"
	Mock.groupSize = 4
	env.wears = env.wears or {}
	env.classes = env.classes or {}
	local names = {}
	for token in pairs(env.classes) do names[token] = PARTY[token] end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local restoreUnits = H.strangers(names)
	local known = {}
	local function isKnown(id) return known[id] == true end
	local units = {}
	for _, name in ipairs(TOUCHED) do units[name] = rawget(_G, name) end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit)
		local class = env.classes[unit]
		if class then return class, class end
		return units.UnitClass(unit)
	end)
	rawset(_G, "UnitPowerMax", function(unit, power)
		local class = env.classes[unit]
		if class == "WARRIOR" or class == "ROGUE" then return 0 end
		return units.UnitPowerMax(unit, power)
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
		if Mock.class == "PALADIN" then
			for _, key in ipairs({ "wisdom", "might", "kings" }) do
				for _, id in ipairs(ids(ns, key)) do known[id] = true end
			end
		else
			for _, buff in ipairs(ns.GetClassBuffs(Mock.class) or {}) do
				for _, id in ipairs(buff.ranks or {}) do known[id] = true end
			end
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
	-- The session's own first, then what H.strangers replaced.
	for _, name in ipairs(TOUCHED) do rawset(_G, name, units[name]) end
	restoreUnits()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
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

local MIXED = { party1 = "MAGE", party2 = "ROGUE", party3 = "DRUID" }
local function mageWisdom(ns) ns.db.profile.buff.forClass = { MAGE = "wisdom" } end

for _, client in ipairs(CLIENTS) do
	do
		local scenario = "forclass: " .. client .. ": with nothing chosen everybody gets Kings first, as ever"
		local env = { client = client, classes = MIXED }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if out.party1 ~= "kings" or out.party2 ~= "kings" or out.party3 ~= "kings" then
				fail(scenario, "offered " .. said(out) .. "; expected Kings for all three")
			end
		end)
	end

	do
		local scenario = "forclass: " .. client .. ": a mage is offered the blessing chosen for mages, a rogue the order's"
		local env = { client = client, classes = MIXED, setup = mageWisdom }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if out.party1 ~= "wisdom" then
				fail(scenario, "with Wisdom chosen for mages, offered " .. said(out))
			end
			if out.party3 ~= "kings" then
				fail(scenario, "a druid, who could use Wisdom and has nothing chosen, was offered " .. tostring(out.party3))
			end
			if out.party2 ~= "kings" then
				fail(scenario, "a rogue, whose class has nothing chosen, was offered " .. tostring(out.party2))
			end
		end)
	end

	do
		local scenario = "forclass: " .. client .. ": one of yours on them still covers them"
		local env = { client = client, classes = MIXED, setup = mageWisdom }
		session(scenario, env, function(ns)
			env.wears.party1 = { [ids(ns, "kings")[1]] = "player" }
			local out = offers(ns, env)
			if out.party1 ~= false then
				fail(scenario, "a mage wearing your Kings was offered " .. tostring(out.party1) .. ", which would replace it")
			end
		end)
	end

	do
		local scenario = "forclass: " .. client .. ": the chosen blessing worn from another paladin is passed over for the order's"
		local env = { client = client, classes = MIXED, setup = mageWisdom }
		session(scenario, env, function(ns)
			env.wears.party1 = { [ids(ns, "wisdom")[1]] = THEIRS }
			local out = offers(ns, env)
			if out.party1 ~= "kings" then
				fail(scenario, "a mage wearing another paladin's Wisdom was offered " .. tostring(out.party1) .. ", not Kings")
			end
		end)
	end

	do
		local scenario = "forclass: " .. client .. ": a blessing that cannot go to the class leaves the order's"
		local env = { client = client, classes = MIXED,
			setup = function(ns) ns.db.profile.buff.forClass = { ROGUE = "wisdom" } end }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if out.party2 ~= "kings" then
				fail(scenario, "a rogue with Wisdom chosen, which does nothing for one, was offered " .. tostring(out.party2))
			end
		end)
	end

	do
		local scenario = "forclass: " .. client .. ": a pinned blessing is still the only one"
		local env = { client = client, classes = MIXED,
			setup = function(ns)
				mageWisdom(ns)
				ns.db.profile.buff.choice = "kings"
			end }
		session(scenario, env, function(ns)
			local out = offers(ns, env)
			if out.party1 ~= "kings" then
				fail(scenario, "with Kings pinned, a mage was offered " .. tostring(out.party1))
			end
		end)
	end
end

do
	local scenario = "forclass: the choice is repaired and travels with a profile"
	local env = { client = "camelot" }
	session(scenario, env, function(ns)
		ns.db.profile.buff.forClass = "yes"
		ns.ClampSettings()
		if type(ns.db.profile.buff.forClass) ~= "table" then
			fail(scenario, "a damaged choice was left as " .. tostring(ns.db.profile.buff.forClass))
		end
		ns.db.profile.buff.forClass = { MAGE = "wisdom", mage = "kings", ROGUE = 7, [3] = "might" }
		ns.ClampSettings()
		local kept = ns.db.profile.buff.forClass
		if kept.MAGE ~= "wisdom" then fail(scenario, "a sound choice was dropped by the repair") end
		if kept.mage ~= nil or kept.ROGUE ~= nil or kept[3] ~= nil then
			fail(scenario, "the repair left a class or a key that is not one")
		end
		kept.ROGUE = "might"
		local text = ns.ExportSettings and ns.ExportSettings() or nil
		if text and not text:find("buff.forClass=MAGE=wisdom,ROGUE=might", 1, true) then
			fail(scenario, "the export does not carry the choice: " .. tostring(text))
		end
		if text and ns.ImportSettings then
			ns.db.profile.buff.forClass = {}
			ns.ImportSettings(text)
			local back = ns.db.profile.buff.forClass
			if not (back.MAGE == "wisdom" and back.ROGUE == "might") then
				fail(scenario, "the choice did not come back from its own export")
			end
		end
	end)
end

do
	local scenario = "forclass: the page picks a class, gives it a blessing and clears them all"
	local env = { client = "camelot" }
	session(scenario, env, function(ns)
		local find = function(key) return H.findOption(ns.optionsTable, key) end
		local note, pick, blessing, reset = find("classNote"), find("classPick"), find("classBlessing"), find("classReset")
		if not (note and pick and blessing and reset) then
			fail(scenario, "Who to buff lacks a control of A blessing for each class")
			return
		end
		if note.hidden() or pick.hidden() or blessing.hidden() then
			fail(scenario, "a paladin with three blessings is not shown the choice")
		end
		if not reset.hidden() then fail(scenario, "the clear button shows with nothing chosen") end
		local values = blessing.values()
		if not (values.auto and values.wisdom and values.might and values.kings) then
			fail(scenario, "the blessings to choose from lack Automatic or one of the three")
		end
		if not pick.values().MAGE then fail(scenario, "the classes to pick from lack the mage") end
		pick.set(nil, "MAGE")
		if blessing.get() ~= "auto" then fail(scenario, "a class with nothing chosen reads " .. tostring(blessing.get())) end
		blessing.set(nil, "wisdom")
		if ns.db.profile.buff.forClass.MAGE ~= "wisdom" or blessing.get() ~= "wisdom" then
			fail(scenario, "Wisdom for mages was not kept")
		end
		if not tostring(note.name()):find(ns.BuffName(ns.FindBuff("PALADIN", "wisdom")), 1, true) then
			fail(scenario, "the note does not say what was chosen: " .. tostring(note.name()))
		end
		pick.set(nil, "ROGUE")
		if blessing.get() ~= "auto" then fail(scenario, "the rogue reads the mage's blessing") end
		blessing.set(nil, "might")
		pick.set(nil, "MAGE")
		blessing.set(nil, "auto")
		if ns.db.profile.buff.forClass.MAGE ~= nil then fail(scenario, "Automatic left the mage's key behind") end
		if reset.hidden() then fail(scenario, "the clear button is hidden with a blessing chosen for rogues") end
		reset.func()
		if next(ns.db.profile.buff.forClass) ~= nil then fail(scenario, "the clear button left a class behind") end
		-- A pin is one buff alone: nothing to choose a class.
		ns.db.profile.buff.choice = "kings"
		if not pick.hidden() then fail(scenario, "the choice is shown while one blessing is pinned") end
	end)
end

do
	local scenario = "forclass: a class whose buffs stack has no such choice"
	local env = { client = "camelot", class = "PRIEST" }
	session(scenario, env, function(ns)
		local pick = H.findOption(ns.optionsTable, "classPick")
		if pick and not pick.hidden() then fail(scenario, "a priest is shown A blessing for each class") end
		if #ns.ClassBlessings() ~= 0 then fail(scenario, "a priest has blessings to choose from") end
	end)
end
