-- The "In character" set's race voices: a thank-you sounds like the speaker's
-- people. "If I am an undead, make it undead / joke / Forsaken RP, same for
-- all races" -- and with "Only when I buff someone back" on, the thank-you is
-- the only line anybody hears. Before the race-voice pass a thank-you for a
-- known spell was the people's own line about three times in ten: the trade
-- and gift lines and the class, spell and place lines outweighed it.
--
-- Every scenario name starts with "race-voice:" so the mutations in
-- tests/mutations/race-voice.py can name the one that has to catch them.
--
-- math.random is a fixed-seed generator here (Park-Miller, exact in doubles,
-- so the same on every machine): the shares are measured, not guessed, and a
-- run gives the same numbers every time. The memory of lines said lately
-- (RP.RECENT) stays on and every pick is remembered as a press would, which
-- is what a player hears: it costs the people's pool the most, since most of
-- the last twelve lines were its own.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local TOUCHED = { "UnitRace", "UnitFactionGroup", "UnitClass", "IsInInstance", "IsResting", "GetGameTime" }
local realRandom = math.random

local function seeded(seed)
	local state = seed
	math.random = function(m, n)
		state = (state * 16807) % 2147483647
		local r = (state - 1) / 2147483646
		if m == nil then return r end
		if n == nil then m, n = 1, m end
		return m + math.floor(r * (n - m + 1))
	end
end

-- Runs body with the world as an ordinary moment: open world, 14:00 (no
-- hour pools), not resting, the player of this faction and class; and puts
-- the client and math.random back after, whether it finished or threw.
local function with(scenario, faction, class, body)
	local original = {}
	for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
	local realClass = original.UnitClass
	rawset(_G, "UnitFactionGroup", function(unit)
		if unit == "player" then return faction, faction end
		return nil
	end)
	rawset(_G, "UnitClass", function(unit)
		if unit == "player" then return "Someone", class, 1 end
		return realClass(unit)
	end)
	rawset(_G, "UnitRace", function(unit)
		if unit == "player" then return original.UnitRace(unit) end
		return nil
	end)
	rawset(_G, "IsInInstance", function() return false, "none" end)
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "GetGameTime", function() return 14, 0 end)
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	math.random = realRandom
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A session for this race and class with speech on and "In character" loaded
-- through the dropdown, as a player would load it.
local function ready(scenario, race, class)
	Mock.reset()
	Mock.playerRace = race
	Mock.class = class
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	local preset = findOption(ns.optionsTable, "preset")
	if not (preset and preset.set) then
		fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
		return nil
	end
	preset.set({ "preset" }, "incharacter")
	return ns
end

-- Every line a table of pools holds, as written.
local function linesOf(tbl, into)
	into = into or {}
	if type(tbl) == "string" then
		into[tbl] = true
	elseif type(tbl) == "table" then
		for _, v in pairs(tbl) do linesOf(v, into) end
	end
	return into
end

-- The vanilla peoples, each with a class that gives something and the spell
-- somebody else commonly gives them.
local SPEAKERS = {
	{ "human", "Human", "Alliance", "PALADIN", "might", "Power Word: Fortitude", "fortitude" },
	{ "dwarf", "Dwarf", "Alliance", "PRIEST", "fortitude", "Mark of the Wild", "motw" },
	{ "nightelf", "NightElf", "Alliance", "DRUID", "motw", "Power Word: Fortitude", "fortitude" },
	{ "gnome", "Gnome", "Alliance", "MAGE", "intellect", "Power Word: Fortitude", "fortitude" },
	{ "orc", "Orc", "Horde", "WARRIOR", "battleshout", "Power Word: Fortitude", "fortitude" },
	{ "forsaken", "Scourge", "Horde", "MAGE", "intellect", "Power Word: Fortitude", "fortitude" },
	{ "tauren", "Tauren", "Horde", "DRUID", "motw", "Power Word: Fortitude", "fortitude" },
	{ "troll", "Troll", "Horde", "PRIEST", "fortitude", "Mark of the Wild", "motw" },
}

-- The least share of a thank-you the people's own lines must have, with the
-- memory on as in game, and with it off, as the weights alone give it.
-- Measured at 59-70% and 67-71% for these eight, against 28-32% and 30-32%
-- before the race-voice pass.
local LEAST, LEAST_UNREMEMBERED = 0.55, 0.62

-- How many of n thank-yous to a stranger, for a favour whose spell is known,
-- are the people's own lines; and the lines said, by their source.
local function thankYous(ns, family, buff, gift, giftKey, n)
	local RP = ns.InCharacter
	local own = linesOf(RP.RACE[family])
	local entry = { name = "Bramwell", short = "Bramwell", reason = "owed", buff = buff,
		class = "WARRIOR", gift = gift, giftKey = giftKey }
	local budget = ns.PhraseBudget(entry)
	local count, said, silent = 0, {}, 0
	for _ = 1, n do
		local line, source = ns.PickPhrase(entry, budget)
		if line == nil or source == nil then
			silent = silent + 1
		else
			RP.Remember(source)
			said[source] = (said[source] or 0) + 1
			if own[source] then count = count + 1 end
		end
	end
	return count, said, silent
end

-- ------------------------------------------------------------- race-voice-1
-- Every vanilla people's thank-you is in its own voice two times in three,
-- give or take: the people's lines at least LEAST of the time, with the gift
-- and trade lines, the class, the spell and the place as seasoning.
do
	local scenario = "race-voice: a thank-you sounds like the speaker's people"
	for i, sp in ipairs(SPEAKERS) do
		local family, race, faction, class, key, gift, giftKey = unpack(sp)
		with(scenario, faction, class, function()
			local ns = ready(scenario, race, class)
			if not ns then return end
			local buff = ns.FindBuff(class, key)
			if not buff then
				fail(scenario, "SKIPPED -- no " .. key .. " for a " .. class)
				return
			end
			seeded(20261004 + i)
			local N = 600
			local count, _, silent = thankYous(ns, family, buff, gift, giftKey, N)
			if silent > 0 then fail(scenario, ("%s: %d of %d thank-yous said nothing"):format(family, silent, N)) end
			local share = count / N
			if os.getenv("MANNERS_RACE_VOICE_PRINT") then
				print(("  race-voice %-9s thanks %.1f%%"):format(family, share * 100))
			end
			if share < LEAST then
				fail(scenario, ("a %s's thank-you is its own people's line %.1f%% of the time, under %.0f%%")
					:format(family, share * 100, LEAST * 100))
			end
			-- And as the weights alone give it, with nothing remembered.
			local RP = ns.InCharacter
			local recent = RP.RECENT
			RP.RECENT = 0
			RP.Remember("")
			seeded(20261004 + 100 * i)
			count = thankYous(ns, family, buff, gift, giftKey, N)
			RP.RECENT = recent
			if os.getenv("MANNERS_RACE_VOICE_PRINT") then
				print(("  race-voice %-9s thanks %.1f%% with no memory"):format(family, count / N * 100))
			end
			if count / N < LEAST_UNREMEMBERED then
				fail(scenario, ("with no memory, a %s's thank-you is its own people's line %.1f%% of the time,"
					.. " under %.0f%%"):format(family, count / N * 100, LEAST_UNREMEMBERED * 100))
			end
			noErrors(scenario, ns)
		end)
	end
end

-- ------------------------------------------------------------- race-voice-2
-- The moment that was asked about: a Forsaken returning a favour with "Only
-- when I buff someone back" on, so a thank-you is all anybody hears. It
-- sounds Forsaken most of the time, from a wide spread of Forsaken lines,
-- never from another people's, and a passer-by hears nothing.
do
	local scenario = "race-voice: a Forsaken's thank-you draws Forsaken lines"
	with(scenario, "Horde", "MAGE", function()
		local ns = ready(scenario, "Scourge", "MAGE")
		if not ns then return end
		ns.db.profile.speech.onlyWhenReturning = true
		local RP = ns.InCharacter
		local buff = ns.FindBuff("MAGE", "intellect")
		local others = {}
		for family, pools in pairs(RP.RACE) do
			if family ~= "forsaken" then linesOf(pools, others) end
		end
		local forsaken = linesOf(RP.RACE.forsaken)
		seeded(1458)
		local N = 400
		local count, said, silent = thankYous(ns, "forsaken", buff, "Power Word: Fortitude", "fortitude", N)
		if silent > 0 then fail(scenario, ("%d of %d thank-yous said nothing"):format(silent, N)) end
		if count / N < LEAST then
			fail(scenario, ("a Forsaken thank-you is Forsaken %.1f%% of the time, under %.0f%%")
				:format(count / N * 100, LEAST * 100))
		end
		local distinct = 0
		for source in pairs(said) do
			if forsaken[source] then distinct = distinct + 1 end
			if others[source] and not forsaken[source] then
				fail(scenario, "a Forsaken said another people's line: " .. source)
			end
		end
		if distinct < 20 then
			fail(scenario, ("only %d different Forsaken lines in %d thank-yous"):format(distinct, N))
		end
		local passer = { name = "Bramwell", short = "Bramwell", reason = "nearby", buff = buff }
		if ns.PickPhrase(passer, ns.PhraseBudget(passer)) ~= nil then
			fail(scenario, "with Only when I buff someone back on, a passer-by was spoken to")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------- race-voice-3
-- A favour Manners never offers (Buffs.lua, favourOnly) is thanked for what
-- it does, as an Arcane Intellect is: a Soulstone, Fear Ward, Water Walking
-- and Detect Invisibility each have their own gift lines, found by the
-- spell's id, and heard more often than the trade lines beside them.
do
	local scenario = "race-voice: a favour-only gift is thanked for what it does"
	with(scenario, "Horde", "MAGE", function()
		local ns = ready(scenario, "Scourge", "MAGE")
		if not ns then return end
		local RP = ns.InCharacter
		local recent = RP.RECENT
		RP.RECENT = 0
		local buff = ns.FindBuff("MAGE", "intellect")
		local trade = linesOf(RP.TRADE)
		local favours = {
			{ 20707, "Soulstone Resurrection", "soulstone" },
			{ 6346, "Fear Ward", "fearward" },
			{ 546, "Water Walking", "waterwalking" },
			{ 11743, "Detect Invisibility", "detectinvis" },
		}
		for _, f in ipairs(favours) do
			local id, gift, key = f[1], f[2], f[3]
			local lines = linesOf(RP.GIFT[key])
			if not next(lines) then fail(scenario, "no gift lines for " .. key) end
			ns.owed["Bramwell"] = { spell = id, expires = GetTime() + 100, at = GetTime() }
			-- Leaning on the gift and trade lines, as Roll a few's favour row
			-- does, and with no key handed in: it is found from the debt.
			local entry = { name = "Bramwell", short = "Bramwell", reason = "owed", buff = buff,
				gift = gift, lean = "trade" }
			local budget = ns.PhraseBudget(entry)
			seeded(id)
			local gifts, trades = 0, 0
			for _ = 1, 200 do
				local _, source = ns.PickPhrase(entry, budget)
				if source and lines[source] then gifts = gifts + 1 end
				if source and trade[source] then trades = trades + 1 end
			end
			if gifts == 0 then
				fail(scenario, gift .. " was never thanked for what it does")
			elseif gifts <= trades then
				fail(scenario, ("%s: gift lines %d, trade lines %d -- what it does should lead")
					:format(gift, gifts, trades))
			end
			ns.owed["Bramwell"] = nil
		end
		RP.RECENT = recent
		noErrors(scenario, ns)
	end)
end
