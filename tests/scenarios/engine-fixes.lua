-- Bug hunt 37, engine: buffs for one target at a time (Buffs.lua, oneTarget)
-- as the walk, the favours, the requests, the greeting and the lines read them.
--
-- Every scenario name starts with "engine-fix:".

local dir, H = ...
local fail, load = H.fail, H.load

local PARTY = {
	party1 = { "Gwen", "Hale" },
	party2 = { "Bram", "Oake" },
	party3 = { "Cora", "Vell" },
	nameplate1 = { "Anna", "Aim" },
}

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitInParty", "C_UnitAuras", "UnitSex" }

local function filed(token)
	local name = PARTY[token]
	return Mock.surnames and (name[1] .. " " .. name[2]) or name[1]
end

-- As tests/scenarios/others-buffs.lua: one session on env.client as env.class
-- knowing env.known, the party above, env.wears token -> { [id] = { left,
-- length, source } }.
local function session(scenario, env, body)
	Mock.reset()
	Mock.setFlavour(env.client)
	Mock.class = env.class
	Mock.groupSize = 4
	Mock.roles = env.roles or { party2 = "TANK" }
	env.wears = env.wears or {}
	local restoreUnits = H.strangers(PARTY)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local known = {}
	for _, id in ipairs(env.known) do known[id] = true end
	local function isKnown(id) return known[id] == true end
	rawset(_G, "IsSpellKnown", isKnown)
	rawset(_G, "IsPlayerSpell", isKnown)
	rawset(_G, "UnitClass", function(unit)
		local class = env.classes and env.classes[unit]
		if class then return class, class end
		return saved.UnitClass(unit)
	end)
	rawset(_G, "UnitInParty", function(unit)
		return type(unit) == "string" and unit:find("^party%d") ~= nil
	end)
	local base = C_UnitAuras
	rawset(_G, "C_UnitAuras", setmetatable({
		GetUnitAuraBySpellID = function(unit, spellId)
			local worn = env.wears[unit] and env.wears[unit][spellId]
			if not worn then return nil end
			return { spellId = spellId, expirationTime = Mock.now + (worn.left or 3000), duration = worn.length,
				sourceUnit = worn.source }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		if ns.Flavour.flavour ~= env.client then
			fail(scenario, "SKIPPED -- the mock is " .. tostring(ns.Flavour.flavour) .. ", not " .. env.client)
			return
		end
		H.freshPrompt(ns, scenario)
		local db = ns.db.profile
		db.sources.self = false
		db.sources.strangers = true
		db.sources.group = true
		db.sources.asked = true
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

local function offers(ns)
	Mock.advance(4)
	for token in pairs(PARTY) do
		local guid = ns.plain(UnitGUID(token))
		if guid and ns.ForgetUnitAuras then ns.ForgetUnitAuras(guid) end
	end
	local byName = {}
	for _, entry in ipairs(ns.BuildQueue()) do byName[entry.name] = entry end
	local out = {}
	for token in pairs(PARTY) do
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

local function ask(ns, token, text)
	ns.addon.CHAT_MSG_PARTY(ns.addon, "CHAT_MSG_PARTY", text, filed(token), "Common", "", "", "", 0, 0, "", 0, 1,
		"Player-1-" .. token)
end

-- #0: Forever's Oath of Light, read as yours by the cast Manners saw land, is
-- forgotten when a blessing lands on the same person.
do
	local OATH, MIGHT = 1328548, 19740
	local scenario = "engine-fix: a blessing on whoever wears your Oath of Light does not move the Oath"
	local env = { client = "camelot", class = "PALADIN", known = { OATH, MIGHT },
		wears = { party1 = { [OATH] = { left = 290, length = 300 } } } }
	session(scenario, env, function(ns)
		ns.NoteGave(filed("party1"), "oathoflight")
		local before = offers(ns)
		for _, token in ipairs({ "party2", "party3" }) do
			if before[token] == "oathoflight" then
				fail(scenario, "SKIPPED -- with the Oath noted on party1, " .. token .. " is offered it: " .. said(before))
				return
			end
		end
		-- The Might the prompt offers next lands on party1.
		env.wears.party1[MIGHT] = { left = 299, length = 300 }
		ns.NoteGave(filed("party1"), "might")
		local after = offers(ns)
		for _, token in ipairs({ "party2", "party3" }) do
			if after[token] == "oathoflight" then
				fail(scenario, "after a Might landed on party1, who wears your Oath of Light, " .. token
					.. " is offered the Oath, which takes it off party1: " .. said(after))
			end
		end
	end)
end

-- #1: a class whose only buff for others goes to one target at a time files
-- no favour at all, and blames "Skip players it does nothing for".
do
	local scenario = "engine-fix: a favour to one whose only buff is for one target is not let go"
	session(scenario, { client = "tbc", class = "SHAMAN", known = { 32594 },
		classes = { party1 = "PRIEST", party2 = "WARRIOR", party3 = "MAGE" },
		setup = function(ns)
			ns.db.profile.filters.relevantOnly = false
			ns.db.profile.verbose = true
		end }, function(ns)
		local out = offers(ns)
		if out.party2 ~= "earthshieldtank" then
			fail(scenario, "SKIPPED -- the tank is not offered Earth Shield: " .. said(out))
			return
		end
		-- The tank, who the queue would give Earth Shield, buffs you.
		local text = H.favourFrom(ns, "party2", 1243, 4001)
		if text:find("nothing you cast is any use", 1, true) then
			fail(scenario, "the tank's favour is let go as one nothing you cast is any use for, blaming \""
				.. "Skip players it does nothing for\" while it is off: " .. text)
		end
		if not (ns.owed and ns.owed[filed("party2")]) then
			fail(scenario, "no debt filed for the tank's favour (CouldOffer(true, true) = "
				.. tostring(ns.CouldOffer(true, true) and ns.CouldOffer(true, true).key) .. "): " .. text)
		end
	end)
end

-- #2: "buffs pls" served once becomes a request by name for every buff, the
-- one-target ones included.
do
	local KINGS, BEACON = 20217, 407613
	local scenario = "engine-fix: buff pls served once is no request for Beacon of Light"
	local env = { client = "vanilla", class = "PALADIN", known = { KINGS, BEACON },
		classes = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "MAGE" },
		wears = { party2 = { [BEACON] = { source = "player" } } } }
	session(scenario, env, function(ns)
		ask(ns, "party1", "buffs pls")
		local before = offers(ns)
		if before.party1 == "beacon" then
			fail(scenario, "SKIPPED -- party1 is offered Beacon before anything was served: " .. said(before))
			return
		end
		env.wears.party1 = { [KINGS] = { source = "player" } }
		ns.ServeRequest(filed("party1"), "kings")
		local after = offers(ns)
		if after.party1 == "beacon" then
			fail(scenario, "after Kings landed for party1's buff pls, party1 is offered Beacon of Light, which takes"
				.. " yours off the tank: before " .. said(before) .. "; after " .. said(after))
		end
	end)
end

-- #3: Mists' Symbiosis: 110309 is the druid's own aura (an action-bar
-- override on the caster); the partner wears a class aura (110490 and the
-- like). Auras where the game puts them.
do
	local scenario = "engine-fix: Symbiosis read where the game puts it"
	local CLASSES = { party1 = "DRUID", party2 = "WARRIOR", party3 = "MAGE", nameplate1 = "PRIEST" }
	session(scenario, { client = "mists", class = "DRUID", known = { 110309 }, classes = CLASSES, roles = {},
		wears = { player = { [110309] = { source = "player", left = 60, length = 3600 } },
			party3 = { [110490] = { source = "player", left = 60, length = 3600 } } },
		setup = function(ns) ns.db.profile.filters.whenBuffed = "refresh" end }, function(ns)
		local out = offers(ns)
		if out.party3 ~= "symbiosis" then
			fail(scenario, "the partner (party3, wearing 110490) is not offered a top-up of a Symbiosis with 60 s"
				.. " left: " .. said(out))
		end
		if out.party2 then fail(scenario, "party2 was offered " .. tostring(out.party2)) end
		if not (ns.ALL_BUFF_IDS[110490] or (ns.BUFF_BY_ID and ns.BUFF_BY_ID[110490])) then
			fail(scenario, "110490, the aura a Symbiosis partner wears, is known as no buff: another druid's"
				.. " Symbiosis on you is never a favour")
		end
	end)
end

-- #4: the greeting for a class whose only buff for others goes to one target.
do
	local scenario = "engine-fix: the greeting does not promise Earth Shield to anybody in the group"
	for _, case in ipairs({ { "tbc", "SHAMAN", 32594 }, { "vanilla", "SHAMAN", 408514 },
		{ "mainline", "PALADIN", 53563 } }) do
		session(scenario, { client = case[1], class = case[2], known = { case[3] } }, function(ns)
			ns.db.char.welcomed = nil
			Mock.printed = {}
			ns.Welcome(true)
			local text = table.concat(Mock.printed, "\n")
			if text:find("puts anybody in your group who is missing", 1, true) then
				fail(scenario, case[1] .. " " .. case[2]:lower() .. ": the greeting promises it to anybody in the"
					.. " group missing it, or who buffs you, though only the tank is offered it: " .. text)
			end
		end)
	end
end

-- #5: the new thanks for a one-target buff, said by a woman in Portuguese or
-- Italian.
do
	local scenario = "engine-fix: a woman thanks for a one-target buff in her own voice"
	for _, case in ipairs({ { "ptBR", "oathoflight", "Obrigado" }, { "ptBR", "earthshieldtank", "Obrigado" },
		{ "ptBR", "beacon", "Obrigado" }, { "ptBR", "symbiosis", "Obrigado" },
		{ "ptBR", "blisteringscales", "Obrigado" }, { "itIT", "oathoflight", "degno" } }) do
		Mock.reset()
		Mock.locale = case[1]
		local real = rawget(_G, "UnitSex")
		local ns = load(scenario)
		if ns then
			local ok, err = pcall(function()
				rawset(_G, "UnitSex", function() return 3 end)
				local RP = ns.InCharacter
				local pool = RP.GIFT[case[2]]
				local inPool = {}
				for _, text in ipairs(pool or {}) do inPool[text] = true end
				local entry = { name = "Anna", short = "Anna", reason = "owed", buff = ns.ResolveBuff(true),
					lean = "trade", gift = "Gift", giftKey = case[2] }
				local heard = {}
				for _ = 1, 400 do
					local _, text = RP.Pick(entry, "say", 250)
					if text and inPool[text] and text:find(case[3], 1, true) then heard[text] = true end
				end
				for text in pairs(heard) do
					fail(scenario, case[1] .. " " .. case[2] .. ": a woman says \"" .. text .. "\"")
				end
			end)
			if not ok then fail(scenario, "threw: " .. tostring(err)) end
		end
		rawset(_G, "UnitSex", real)
		Mock.reset()
	end
end

-- #6: the fuzzer's own /ignore list answers a name as the game does (a debt
-- whose person has no token is asked by name), so seed 1065 on Forever, which
-- failed at step 90 with "on your ignore list and was offered as owed", plays
-- clean. The model was wrong, not the addon.
do
	local scenario = "engine-fix: the fuzzer's ignore list answers a name as the game does"
	if load(scenario) then
		local chunk, err = loadfile(dir .. "/tests/fuzz_world.lua")
		if not chunk then
			fail(scenario, "load fuzz_world.lua: " .. tostring(err))
		else
			local world = chunk(dir)
			local steps = world.generate("camelot", 1065, 200)
			local first = {}
			for i = 1, 90 do first[i] = steps[i] end
			local ok, result = pcall(world.play, { dir = dir, flavour = "camelot", seed = 1065, steps = first })
			if not ok then
				fail(scenario, "the fuzzer threw: " .. tostring(result))
			elseif not result.ok then
				fail(scenario, ("%s at step %s: %s"):format(tostring(result.kind), tostring(result.step),
					tostring(result.message):gsub("\n", " / ")))
			end
			math.randomseed(os.time() + math.floor(os.clock() * 1000))
		end
	end
end
