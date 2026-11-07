-- Bug hunt 35, the phrases area: the Forsaken thanks rewritten in 27affa0 and
-- who a /party line reaches.
--
-- - A line that calls the person thanked alive sat in forsaken.thanks, which
--   RP.Pick says to a fellow Forsaken too: it belongs with the lines for
--   outsiders.
-- - New Forsaken thanks translated in a man's voice ("j'ai été gentil", "un
--   mort") were not named in RP.MASCULINE, so a woman said them.
-- - /party to a battleground or dungeon-finder teammate outside your premade:
--   inside the instance /party reaches only the premade.
--
-- Every scenario name starts with "phrases-fix:".

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local realRandom = math.random

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- The golden-ratio counter rp.lua uses: every line of a pool comes up in turn.
local function counting()
	local rolls = 0
	math.random = function(n)
		rolls = rolls + 1
		if not n then return (rolls * 0.6180339887498949) % 1 end
		return ((rolls - 1) % n) + 1
	end
end

-- Puts back the globals a scenario below stands in.
local function standIns(names)
	local saved = {}
	for _, name in ipairs(names) do saved[name] = rawget(_G, name) end
	return function()
		for _, name in ipairs(names) do rawset(_G, name, saved[name]) end
		math.random = realRandom
	end
end

-- A Forsaken session on `locale` (nil: English) with "In character" loaded
-- through the dropdown; nameplate1 a Forsaken, nameplate2 an orc, both named
-- Mortimer; the player's sex `sex` (nil: the mock's own).
local function forsaken(scenario, locale, sex, body)
	local put = standIns({ "UnitRace", "UnitFactionGroup", "UnitSex" })
	local ok, err = pcall(function()
		Mock.reset()
		Mock.locale = locale
		Mock.playerRace = "Scourge"
		local ns = load(scenario)
		if not ns then return end
		local playerRace = rawget(_G, "UnitRace")
		local races = { nameplate1 = "Scourge", nameplate2 = "Orc" }
		rawset(_G, "UnitRace", function(unit)
			if unit == "player" then return playerRace(unit) end
			local race = races[unit]
			if race == nil then return nil end
			return race, race, 1
		end)
		rawset(_G, "UnitFactionGroup", function(unit)
			if unit == "player" then return "Horde", "Horde" end
			return nil
		end)
		if sex ~= nil then rawset(_G, "UnitSex", function() return sex end) end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = false
		speech.channel = "SAY"
		local preset = findOption(ns.optionsTable, "preset")
		if not (preset and preset.set) then
			fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
			return
		end
		preset.set({ "preset" }, "incharacter")
		Mock.unitNames = { nameplate1 = { "Mortimer" }, nameplate2 = { "Mortimer" } }
		body(ns, ns.InCharacter)
		guarded(scenario, ns)
	end)
	put()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function owedBy(ns, unit)
	return { name = ns.UnitFullName(unit) or "Mortimer", short = "Mortimer", reason = "owed",
		buff = ns.ResolveBuff(true) or ns.FindBuff("PRIEST", "stamina"), unit = unit }
end

-- The raw lines RP.Pick chose over n picks, counted by line.
local function picks(RP, entry, n)
	local seen = {}
	counting()
	for _ = 1, n do
		local _, text = RP.Pick(entry, "say", 250)
		if text then seen[text] = (seen[text] or 0) + 1 end
	end
	math.random = realRandom
	return seen
end

-- The pool's line read under this English, or nil.
local function lineOf(RP, pool, english)
	for _, text in ipairs(pool or {}) do
		if text == english or RP.EnglishOf(text) == english then return text end
	end
	return nil
end

-- ------------------------------------------------------------ phrases-fix-0
-- "Warm, generous and alive" says the person thanked is alive: nonsense to a
-- fellow Forsaken, and what the outsider pool exists to keep from one.
do
	local scenario = "phrases-fix: a Forsaken never calls another Forsaken alive"
	local ALIVE = "Warm, generous and alive, {name}. I can only match you on one. Here it is."
	forsaken(scenario, nil, nil, function(ns, RP)
		local kin = owedBy(ns, "nameplate1")
		if not RP.IsKin(kin, "forsaken") then
			fail(scenario, "SKIPPED -- the Forsaken on nameplate1 does not read as kin")
			return
		end
		local seen = picks(RP, kin, 600)
		if not next(seen) then
			fail(scenario, "SKIPPED -- nothing was picked for a Forsaken owed a favour")
			return
		end
		if seen[ALIVE] then
			fail(scenario, ("a Forsaken thanked another Forsaken with \"%s\" (%d of 600 picks)"):format(ALIVE, seen[ALIVE]))
		end
	end)
end

-- ------------------------------------------------------------ phrases-fix-1
-- A woman's Forsaken thanks in French, Italian, Spanish and Portuguese: "A gift
-- for the dead" is "un mort" / "un morto" / "un muerto" / "um morto", the
-- speaker herself in the masculine, and is not in RP.MASCULINE.
local GIFT = "A gift for the dead, {name}? Most people bring flowers. Then they run."
local NICE = "Please don't tell the Dark Lady I was nice to somebody, {name}."
for _, code in ipairs({ "frFR", "itIT", "esES", "ptBR" }) do
	local scenario = "phrases-fix: a female Forsaken is spared 'a gift for the dead' in " .. code
	forsaken(scenario, code, 3, function(ns, RP)
		local text = lineOf(RP, RP.RACE.forsaken.thanks, GIFT)
		if not text or text == GIFT then
			fail(scenario, "SKIPPED -- the line is not translated in " .. code)
			return
		end
		local seen = picks(RP, owedBy(ns, "nameplate2"), 600)
		if not next(seen) then
			fail(scenario, "SKIPPED -- nothing was picked")
			return
		end
		if seen[text] then
			fail(scenario, ("a woman said \"%s\" (%d of 600 picks)"):format(text, seen[text]))
		end
	end)
end

-- ------------------------------------------------------------ phrases-fix-3
-- French alone: "j'ai été gentil" is a man speaking.
do
	local scenario = "phrases-fix: a female Forsaken in French is never 'gentil' to the Dark Lady"
	forsaken(scenario, "frFR", 3, function(ns, RP)
		local text = lineOf(RP, RP.RACE.forsaken.thanks, NICE)
		if not text or not text:find("gentil,", 1, true) then
			fail(scenario, "SKIPPED -- the French line is not the masculine one: " .. tostring(text))
			return
		end
		local seen = picks(RP, owedBy(ns, "nameplate2"), 600)
		if seen[text] then
			fail(scenario, ("a woman said \"%s\" (%d of 600 picks)"):format(text, seen[text]))
		end
		-- And a man still says it.
		rawset(_G, "UnitSex", function() return 2 end)
		if not picks(RP, owedBy(ns, "nameplate2"), 600)[text] then
			fail(scenario, "a man never said the line in 600 picks")
		end
	end)
end

-- ------------------------------------------------------------ phrases-fix-2
-- A premade party of two in a battleground: the game's instance raid holds
-- everybody, your home party only the two of you. A random teammate (Munin,
-- in the instance raid, not in the premade) buffed you; /party reaches only
-- the premade, so the thank-you is one he never reads.
do
	local scenario = "phrases-fix: no party line to a battleground teammate outside your premade"
	local MUNIN = "Munin Hugins"
	local put = standIns({ "LE_PARTY_CATEGORY_HOME", "LE_PARTY_CATEGORY_INSTANCE", "IsInGroup", "IsInRaid",
		"UnitInRaid", "UnitInParty", "GetHomePartyInfo", "UnitInSubgroup" })
	local ok, err = pcall(function()
		Mock.reset()
		local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" } })
		local ns = load(scenario)
		if not ns then
			restore()
			return
		end
		rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
		rawset(_G, "LE_PARTY_CATEGORY_INSTANCE", 2)
		-- A home party (the premade) and an instance raid (the battleground).
		rawset(_G, "IsInGroup", function() return true end)
		rawset(_G, "IsInRaid", function(category) return category ~= 1 end)
		local realInRaid, realInParty = rawget(_G, "UnitInRaid"), rawget(_G, "UnitInParty")
		rawset(_G, "UnitInRaid", function(unit)
			if unit == "nameplate1" then return 7 end
			return realInRaid(unit)
		end)
		rawset(_G, "UnitInParty", function(unit)
			if unit == "nameplate1" then return false end
			return realInParty(unit)
		end)
		rawset(_G, "UnitInSubgroup", function(unit)
			if unit == "nameplate1" then return false end
			return true
		end)
		-- The premade: you and a friend, not Munin.
		rawset(_G, "GetHomePartyInfo", function() return { "Friendly" } end)
		H.freshPrompt(ns, scenario)
		local speech = ns.db.profile.speech
		speech.enabled = true
		speech.onlyWhenReturning = false
		speech.channel = "PARTY"
		speech.phrases = "Thanks, {name}."
		Mock.groupSize = 15
		H.owe(ns, MUNIN)
		ns.Prompt:InvalidateMacro()
		ns.addon:Tick()
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not (text and text:find(MUNIN, 1, true)) then
			fail(scenario, "SKIPPED -- Munin is not armed: " .. tostring(text))
		elseif text:find("\n/party ", 1, true) then
			fail(scenario, "the macro thanks a teammate outside the premade on /party: "
				.. (tostring(text):gsub("\n", " / ")))
		end
		Mock.groupSize = 0
		guarded(scenario, ns)
		restore()
	end)
	put()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end
