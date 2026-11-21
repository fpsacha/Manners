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

local SYMBOL_OF_KINGS = 21177

local TOUCHED = { "IsSpellKnown", "IsPlayerSpell", "UnitClass", "UnitPowerMax", "UnitInParty", "C_UnitAuras",
	"GetItemCount", "GetItemInfo" }

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
	-- `env.greater`: the Greater Blessings known too, with Symbols of Kings in
	-- the bags (GitHub issue 17).
	if env.greater then
		rawset(_G, "GetItemCount", function(id) return id == SYMBOL_OF_KINGS and 10 or 0 end)
		rawset(_G, "GetItemInfo", function(id) return id == SYMBOL_OF_KINGS and "Symbol of Kings" or nil end)
	end
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
			return { spellId = spellId, auraInstanceID = spellId, expirationTime = Mock.now + 3600, duration = 3600,
				sourceUnit = type(source) == "string" and source or nil }
		end,
	}, { __index = base }))

	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		for _, key in ipairs({ "wisdom", "might", "kings" }) do
			for _, id in ipairs(ids(ns, key)) do known[id] = true end
			local buff = env.greater and ns.FindBuff("PALADIN", key)
			for _, rank in ipairs(buff and buff.groupCast or {}) do known[rank.id] = true end
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

-- ---------------------------------------------------------------------------
-- GitHub issue 17. The Greater Blessing of Kings lands on everybody of the
-- class, the one by the Fish Bowl too, whom the walk had given another
-- blessing: with the switch on, one such member keeps it back and the others
-- keep their single Kings. And under the switch, "Never put Kings over
-- Boosted Stats" (buff.neverFishBowl): no Kings at all while they wear it.
-- ---------------------------------------------------------------------------

local FOUR = { party1 = "WARRIOR", party2 = "WARRIOR", party3 = "WARRIOR", party4 = "WARRIOR" }

local function groupCast(ns)
	Mock.advance(4)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.groupCast then return entry end
	end
	return nil
end

do
	local scenario = "fishbowl: on, no Greater Blessing of Kings for a class with somebody by a Fish Bowl"
	local env = { client = "camelot", greater = true, classes = FOUR }
	env.setup = function(ns)
		env.wears.party1 = wearing(ns)
		ns.db.profile.buff.spareFishBowl = true
	end
	session(scenario, env, function(ns)
		local cast = groupCast(ns)
		if cast and cast.buff.key == "kings" then
			fail(scenario, "a Greater Blessing of Kings was offered with a warrior sitting by a Fish Bowl")
		end
		local got = offers(ns, env)
		if got.party1 == "kings" or not got.party1 then
			fail(scenario, "the warrior by the Fish Bowl was offered " .. tostring(got.party1))
		end
		for _, token in ipairs({ "party2", "party3", "party4" }) do
			if got[token] ~= "kings" then
				fail(scenario, token .. " was offered " .. tostring(got[token]) .. ", not a single Kings")
			end
		end
	end)
end

do
	local scenario = "fishbowl: the Greater Blessing of Kings is still offered with no Fish Bowl, or the switch off"
	local env = { client = "camelot", greater = true, classes = FOUR }
	-- The fourth wears your Kings already: covered, never queued, and so the
	-- one the Fish Bowl is asked about.
	env.setup = function(ns)
		ns.db.profile.buff.spareFishBowl = true
		env.wears.party4 = {}
		for _, id in ipairs(ids(ns, "kings")) do env.wears.party4[id] = OURS end
	end
	session(scenario, env, function(ns)
		local cast = groupCast(ns)
		if not (cast and cast.buff.key == "kings") then
			fail(scenario, "switch on, nobody by a Fish Bowl: no Greater Blessing of Kings for the three without it")
		end
	end)
	local off = { client = "camelot", greater = true, classes = FOUR }
	off.setup = function(ns) off.wears.party1 = wearing(ns) end
	session(scenario, off, function(ns)
		local cast = groupCast(ns)
		if not (cast and cast.buff.key == "kings") then
			fail(scenario, "switch off, one by a Fish Bowl: no Greater Blessing of Kings, which is not as before")
		end
	end)
end

do
	local scenario = "fishbowl: never Kings, somebody by a Fish Bowl with nothing else missing is left alone"
	local env = { client = "camelot", classes = { party1 = "WARRIOR", party2 = "WARRIOR" } }
	env.setup = function(ns)
		env.wears.party1 = wearing(ns, { "wisdom", "might" })
		ns.db.profile.buff.spareFishBowl = true
		ns.db.profile.buff.neverFishBowl = true
	end
	session(scenario, env, function(ns)
		local got = offers(ns, env)
		if got.party1 then fail(scenario, "they were offered " .. tostring(got.party1) .. " over the Fish Bowl") end
		if got.party2 ~= "kings" then fail(scenario, "a warrior with no Fish Bowl was offered " .. tostring(got.party2)) end
		-- The Fish Bowl's buff gone: Kings again.
		env.wears.party1[BOOSTED] = nil
		got = offers(ns, env)
		if got.party1 ~= "kings" then
			fail(scenario, "with Boosted Stats gone they were offered " .. tostring(got.party1) .. ", not Kings")
		end
	end)
end

do
	local scenario = "fishbowl: never Kings is read only while the first switch is on"
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	env.setup = function(ns)
		env.wears.party1 = wearing(ns)
		ns.db.profile.buff.neverFishBowl = true
	end
	session(scenario, env, function(ns)
		local got = offers(ns, env)
		if got.party1 ~= "kings" then
			fail(scenario, "with the first switch off they were offered " .. tostring(got.party1) .. ", not Kings")
		end
	end)
end

do
	local scenario = "fishbowl: the strict switch sits under the first one on Who to buff"
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	session(scenario, env, function(ns)
		local option = H.findOption(ns.optionsTable, "neverFishBowl")
		if not option then fail(scenario, "Who to buff has no strict switch") return end
		if ns.db.profile.buff.neverFishBowl ~= false then fail(scenario, "the strict switch is on by default") end
		if option.hidden() then fail(scenario, "the strict switch is hidden from a paladin on WoW Forever") end
		if option.disabled() ~= true then fail(scenario, "it is not greyed while the first switch is off") end
		ns.db.profile.buff.spareFishBowl = true
		if option.disabled() ~= false then fail(scenario, "it stays greyed with the first switch on") end
		option.set({ "who", "neverFishBowl" }, true)
		if ns.db.profile.buff.neverFishBowl ~= true or option.get() ~= true then
			fail(scenario, "turning it on was not stored")
		end
		local layout = ns.WindowLayout
		local at, firstAt, indent, inFold = nil, nil, nil, true
		for _, section in ipairs(layout.pages.who.sections) do
			for i, item in ipairs(section.items) do
				local path = type(item) == "table" and item[1] or item
				if path == "who.spareFishBowl" then firstAt = i; inFold = inFold and section.key == "who.castFine" end
				if path == "who.neverFishBowl" then
					at, indent = i, type(item) == "table" and item.indent
					inFold = inFold and section.key == "who.castFine"
				end
			end
		end
		if not inFold then fail(scenario, "the two switches are not in the Other people's buffs fold") end
		if not (at and firstAt and at == firstAt + 1 and indent == true) then
			fail(scenario, "it is not placed one step in, right under the first switch")
		end
		if layout.parents["who.neverFishBowl"] ~= "who.spareFishBowl" then
			fail(scenario, "search is not told which switch to turn on first")
		end
	end)
	local era = { client = "vanilla", classes = { party1 = "WARRIOR" } }
	session(scenario, era, function(ns)
		local option = H.findOption(ns.optionsTable, "neverFishBowl")
		if option and not option.hidden() then fail(scenario, "it shows on Classic Era, which has no Fish Bowl") end
	end)
end

-- ---------------------------------------------------------------------------
-- GitHub issue 20. Your own pick carries no unit (opts.own), and on Forever
-- Boosted Stats is hidden: a Fish Bowl shows as Camp Benefits (1229741), whose
-- tooltip has a line "<Fish Bowl>: All stats increased by ...".
-- ---------------------------------------------------------------------------

local CAMP_BENEFITS, FEATURE = 1229741, 1307245

local function campSession(scenario, lineText, body)
	local env = { client = "camelot", classes = { party1 = "WARRIOR" } }
	local savedTip, savedSpell = rawget(_G, "C_TooltipInfo"), rawget(_G, "C_Spell")
	env.setup = function(ns)
		ns.db.profile.buff.spareFishBowl = true
		env.wears.player = { [CAMP_BENEFITS] = "player" }
		env.wears.party1 = { [CAMP_BENEFITS] = THEIRS }
		rawset(_G, "C_TooltipInfo", {
			GetUnitBuffByAuraInstanceID = function()
				return { lines = { { leftText = "Camp Benefits" }, { leftText = lineText } } }
			end,
		})
		local base = savedSpell or {}
		rawset(_G, "C_Spell", setmetatable({
			GetSpellName = function(id) if id == FEATURE then return "Fish Bowl" end return base.GetSpellName and base.GetSpellName(id) end,
		}, { __index = base }))
	end
	session(scenario, env, body)
	rawset(_G, "C_TooltipInfo", savedTip)
	rawset(_G, "C_Spell", savedSpell)
end

do
	local scenario = "fishbowl: Camp Benefits naming the Fish Bowl holds Kings off you and off others"
	campSession(scenario, "Fish Bowl: All stats increased by 8%.", function(ns)
		if ns.SparesFishBowl({ own = true }) ~= true then fail(scenario, "your own pick was not held back at a Fish Bowl") end
		if ns.SparesFishBowl({ unit = "party1" }) ~= true then fail(scenario, "somebody else by a Fish Bowl was not held back") end
	end)
end

do
	local scenario = "fishbowl: Camp Benefits without the Fish Bowl line holds nothing back"
	campSession(scenario, "Lodestone: Might increased.", function(ns)
		if ns.SparesFishBowl({ own = true }) == true then fail(scenario, "held back with only another camp feature on") end
		ns.db.profile.buff.spareFishBowl = false
		if ns.SparesFishBowl({ own = true }) == true then fail(scenario, "held back with the switch off") end
	end)
end
