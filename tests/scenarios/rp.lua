-- The "In character" phrase set (Phrases.lua): a line picked at the click for
-- the player's people, their faction, their class, the reason for the buff and
-- the moment -- the spell, what they gave you, how often you two have traded,
-- where you are, the hour and who is being helped.
--
-- Called by scenarios.lua with the addon directory and its helpers. The mock
-- knows the player's race (Mock.playerRace) and class (Mock.class) and nothing
-- about factions, other people's races, instances, resting, the map or the
-- realm's clock, so those are set here for the length of one scenario and put back
-- after it, rather than added to mockapi.lua.
--
-- math.random is swapped for a counter where the scenario counts lines: with a
-- real roll a line that should come up could miss by luck, and a weighting
-- could pass by luck. The set rolls math.random() for a fraction of the whole
-- draw, and the counter answers with the golden-ratio sequence, which spreads
-- evenly over any number of rolls, so every candidate is visited in proportion
-- to its share.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, pressButton = H.findOption, H.pressButton

local TOUCHED = { "UnitRace", "UnitFactionGroup", "UnitClass", "IsInInstance", "IsResting",
	"GetGameTime", "C_Map" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
local realRandom = math.random

-- Runs one scenario with the player's faction and other people's races in
-- place, and puts them back, and math.random and the world too, whether it
-- finished or threw. `races` maps a unit token to a race file name or
-- Mock.SECRET; `classes`, when given, a unit token to a class token (or
-- Mock.SECRET), "player" included.
local function with(scenario, faction, races, body, classes)
	local playerRace = original.UnitRace
	local realClass = original.UnitClass
	rawset(_G, "UnitFactionGroup", function(unit)
		if unit == "player" then return faction, faction end
		return nil
	end)
	if faction == "absent" then rawset(_G, "UnitFactionGroup", nil) end
	rawset(_G, "UnitRace", function(unit)
		if unit == "player" then return playerRace(unit) end
		local race = races and races[unit]
		if race == nil then return nil end
		return race, race, 1
	end)
	rawset(_G, "UnitClass", function(unit)
		local class = classes and classes[unit]
		if class ~= nil then return "Someone", class end
		return realClass(unit)
	end)
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	math.random = realRandom
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Where the player is and the hour, as the client would answer. `place` is
-- "city", "wild", "party", "raid", "pvp", "arena", "scenario", or nil for no
-- IsInInstance at all.
local function world(place, hour)
	local inside = place ~= nil and place ~= "city" and place ~= "wild"
	if place == nil then
		rawset(_G, "IsInInstance", nil)
		rawset(_G, "IsResting", nil)
	else
		rawset(_G, "IsInInstance", function() return inside, inside and place or "none" end)
		rawset(_G, "IsResting", function() return place == "city" end)
	end
	if hour == nil then
		rawset(_G, "GetGameTime", nil)
	else
		rawset(_G, "GetGameTime", function() return hour, 17 end)
	end
end

local function counting()
	local rolls = 0
	math.random = function(n)
		rolls = rolls + 1
		if not n then return (rolls * 0.6180339887498949) % 1 end
		return ((rolls - 1) % n) + 1
	end
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- A session for this race with speech on and "In character" loaded through the
-- dropdown, as a player would load it.
local function ready(scenario, race)
	Mock.reset()
	Mock.playerRace = race
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

local function someBuff(ns)
	return ns.ResolveBuff(true) or ns.FindBuff("MAGE", "intellect")
end

local function person(ns, reason, unit)
	return { name = "Bram", short = "Bram", reason = reason, buff = someBuff(ns), unit = unit }
end

-- Every line a pool holds, as it would be said to this person, filed under tag.
local function render(ns, entry, pool, into, tag, gift)
	if type(pool) == "string" then pool = { pool } end
	for _, text in ipairs(pool or {}) do
		local said = ns.Swap(ns.Swap(text, "{name}", entry.short), "{buff}", ns.BuffName(entry.buff))
		said = ns.Swap(said, "{gift}", gift)
		into[said] = tag
	end
end

-- The pools that join every moment of this speaker's in the mock's quiet world
-- (no place, no hour, nobody's class): their class's lines and the spell's.
local function speaker(ns, entry, kind, into)
	local RP = ns.InCharacter
	local _, class = UnitClass("player")
	render(ns, entry, RP.PoolFor(RP.CLASS[class], kind), into, "class")
	render(ns, entry, entry.buff and RP.SPELL[entry.buff.key], into, "spell")
end

-- n lines picked for this person, counted by the tag of the pool each came
-- from; a line from no pool expected is counted under "stray" and kept.
local function tally(ns, entry, expected, n, budget)
	local counts, strays = {}, {}
	for _ = 1, n do
		local line = ns.PickPhrase(entry, budget or 250)
		local said = line and line:match("^/say (.+)$")
		local tag = said and expected[said] or "stray"
		if tag == "stray" then strays[#strays + 1] = tostring(line) end
		counts[tag] = (counts[tag] or 0) + 1
	end
	return counts, strays
end

-- Every pool of the moment, by name, for the checks that go through them.
local function contextPools(RP)
	local out = {}
	for class, pools in pairs(RP.CLASS) do
		for kind, pool in pairs(pools) do out["CLASS." .. class .. "." .. kind] = pool end
	end
	for key, pool in pairs(RP.SPELL) do out["SPELL." .. key] = pool end
	out.TRADE = RP.TRADE
	for key, pool in pairs(RP.GIFT) do out["GIFT." .. key] = pool end
	for class, pool in pairs(RP.SAME) do out["SAME." .. class] = pool end
	for key, pool in pairs(RP.HISTORY) do out["HISTORY." .. key] = pool end
	for key, pool in pairs(RP.PLACE) do out["PLACE." .. key] = pool end
	for key, pool in pairs(RP.TIME) do out["TIME." .. key] = pool end
	for key, pool in pairs(RP.TARGET) do out["TARGET." .. key] = pool end
	for key, classes in pairs(RP.ONTO) do
		for class, pool in pairs(classes) do out["ONTO." .. key .. "." .. class] = pool end
	end
	return out
end

-- A list of lines and another, as one.
local function joined(a, b)
	local out = {}
	for _, text in ipairs(a or {}) do out[#out + 1] = text end
	for _, text in ipairs(b or {}) do out[#out + 1] = text end
	return out
end

-- Every line of every pool, for the checks that go through all of them.
local function everyLine(RP)
	local out = {}
	local function take(pool)
		if type(pool) == "string" then out[#out + 1] = pool return end
		for _, text in ipairs(pool or {}) do out[#out + 1] = text end
	end
	for _, people in pairs(RP.RACE) do
		take(people.thanks) take(people.asked) take(people.offer) take(people.kin)
		take(people.group) take(people.night) take(people.morning) take(people.city)
		for _, pool in pairs(people.outsider or {}) do take(pool) end
	end
	take(RP.KIN)
	for _, side in pairs(RP.FACTION) do
		take(side.thanks) take(side.asked) take(side.offer) take(side.group)
	end
	for _, pool in pairs(RP.GENERAL) do take(pool) end
	for _, pool in pairs(contextPools(RP)) do take(pool) end
	return out
end

-- Every pool the picking reads, by name, the peoples' and sides' included.
local function allPools(RP)
	local out = contextPools(RP)
	for family, people in pairs(RP.RACE) do
		for kind, pool in pairs(people) do
			if kind == "outsider" then
				for moment, lines in pairs(pool) do out["RACE." .. family .. ".outsider." .. moment] = lines end
			else
				out["RACE." .. family .. "." .. kind] = pool
			end
		end
	end
	out.KIN = RP.KIN
	for side, pools in pairs(RP.FACTION) do
		for kind, pool in pairs(pools) do out["FACTION." .. side .. "." .. kind] = pool end
	end
	for kind, pool in pairs(RP.GENERAL) do out["GENERAL." .. kind] = pool end
	return out
end

-- ------------------------------------------------------------------ rp-1
-- Every race the client has, and the people whose voice it speaks with. A
-- race missing here speaks only the general lines, which reads as the set
-- being broken for that race.
do
	local scenario = "rp: every race speaks with its own people"
	local WANT = {
		Dwarf = "dwarf", DarkIronDwarf = "dwarf", EarthenDwarf = "dwarf",
		Human = "human", KulTiran = "human", NightElf = "nightelf", VoidElf = "voidelf",
		Gnome = "gnome", Mechagnome = "gnome", Draenei = "draenei",
		LightforgedDraenei = "draenei", Worgen = "worgen", Orc = "orc", MagharOrc = "orc",
		Scourge = "forsaken", Tauren = "tauren", HighmountainTauren = "tauren",
		Troll = "troll", ZandalariTroll = "troll", BloodElf = "bloodelf",
		Nightborne = "nightborne", Goblin = "goblin", Vulpera = "vulpera",
		Pandaren = "pandaren", Dracthyr = "dracthyr", Haranir = "haranir",
	}
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		for race, family in pairs(WANT) do
			Mock.playerRace = race
			local got = RP.Player()
			if got ~= family then
				fail(scenario, race .. " speaks as " .. tostring(got) .. ", not " .. family)
			end
			-- Every people but the Haranir has lines for every moment, and
			-- more than one for kin.
			local lines = RP.RACE[family]
			if family ~= "haranir" then
				if not (lines and lines.thanks and lines.asked and lines.offer
					and type(lines.kin) == "table" and #lines.kin >= 2) then
					fail(scenario, family .. " is missing a kind of line")
				end
			elseif lines then
				fail(scenario, "the Haranir were given lines of their own to guess at")
			end
		end
		if type(RP.KIN) ~= "table" or #RP.KIN < 2 then
			fail(scenario, "the kin lines for a people without their own are not a list")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-2
-- A dwarf mage of the Alliance thanking somebody: dwarvish thanks most, then
-- the rest, and nothing from anybody else. Somebody from another realm is
-- called by their short name, as every other set calls them, never
-- "Bram-Realm".
do
	local scenario = "rp: a dwarf of the Alliance thanks like one"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "DarkIronDwarf")
		if not ns then return end
		local RP = ns.InCharacter
		local entry = person(ns, "owed")
		entry.name = "Bram-Realm"
		local expected = {}
		render(ns, entry, RP.RACE.dwarf.thanks, expected, "race")
		render(ns, entry, RP.FACTION.Alliance.thanks, expected, "faction")
		render(ns, entry, RP.GENERAL.thanks, expected, "general")
		speaker(ns, entry, "thanks", expected)
		counting()
		local counts, strays = tally(ns, entry, expected, 600)
		for _, line in ipairs(strays) do
			if line:find("-Realm", 1, true) then
				fail(scenario, "called somebody by their realm-qualified name: " .. line)
				break
			end
		end
		if strays[1] then
			fail(scenario, "said a line that is not a dwarf's, the Alliance's, a mage's or anybody's thanks: "
				.. strays[1])
		end
		for _, tag in ipairs({ "race", "faction", "general", "class", "spell" }) do
			if not counts[tag] then fail(scenario, "never said a " .. tag .. " line") end
		end
		local race = counts.race or 0
		for _, tag in ipairs({ "faction", "general", "class", "spell" }) do
			if race <= (counts[tag] or 0) then
				fail(scenario, ("the dwarf's own lines are not the most heard: %d race, %d %s")
					:format(race, counts[tag] or 0, tag))
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-3
-- An orc of the Horde offering: the Horde's lines and never the Alliance's.
do
	local scenario = "rp: an orc of the Horde offers like one"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "MagharOrc")
		if not ns then return end
		local RP = ns.InCharacter
		local entry = person(ns, "nearby")
		local expected = {}
		render(ns, entry, RP.RACE.orc.offer, expected, "race")
		render(ns, entry, RP.FACTION.Horde.offer, expected, "faction")
		render(ns, entry, RP.GENERAL.offer, expected, "general")
		speaker(ns, entry, "offer", expected)
		counting()
		local counts, strays = tally(ns, entry, expected, 400)
		if strays[1] then fail(scenario, "an orc of the Horde said: " .. strays[1]) end
		if not (counts.race and counts.faction and counts.general) then
			fail(scenario, "some of the orc's, the Horde's or the general offers never came up")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-4
-- Each reason has its own lines: an answer is not a thank-you, and a group
-- member hears the people's own group lines and the side's, never either's
-- offers to a stranger on the road. The class's lines follow the reason too.
-- A people with no group lines speaks its offers, and so does a side.
do
	local scenario = "rp: reasons pick their own lines"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "HighmountainTauren")
		if not ns then return end
		local RP = ns.InCharacter
		local mage = RP.CLASS.MAGE
		local cases = {
			{ reason = "asked", pools = { RP.RACE.tauren.asked, RP.FACTION.Horde.asked, RP.GENERAL.asked,
				mage.asked } },
			{ reason = "target", pools = { RP.RACE.tauren.offer, RP.FACTION.Horde.offer, RP.GENERAL.offer,
				mage.offer } },
			{ reason = "group", pools = { RP.RACE.tauren.group, RP.FACTION.Horde.group,
				RP.GENERAL.group, mage.group } },
			{ reason = "owed", pools = { RP.RACE.tauren.thanks, RP.FACTION.Horde.thanks, RP.GENERAL.thanks,
				mage.thanks } },
		}
		counting()
		for _, case in ipairs(cases) do
			local entry = person(ns, case.reason)
			local expected = {}
			render(ns, entry, RP.SPELL[entry.buff.key], expected, "spell")
			for i, pool in ipairs(case.pools) do render(ns, entry, pool, expected, "pool" .. i) end
			local counts, strays = tally(ns, entry, expected, 400)
			if strays[1] then
				fail(scenario, "for reason " .. case.reason .. " it said: " .. strays[1])
			end
			for i = 1, #case.pools do
				if not counts["pool" .. i] then
					fail(scenario, "for reason " .. case.reason .. ", pool " .. i .. " never came up")
				end
			end
		end
		-- Without group lines of their own, the people's offers.
		local own = RP.RACE.tauren.group
		RP.RACE.tauren.group = nil
		local entry = person(ns, "group")
		local offers = {}
		render(ns, entry, RP.RACE.tauren.offer, offers, "offer")
		local counts = tally(ns, entry, offers, 300)
		RP.RACE.tauren.group = own
		if not counts.offer then
			fail(scenario, "a people with no group lines said nothing of its own to the group")
		end
		-- And a side with none (its translation still to come): its offers.
		local sides = RP.FACTION.Horde.group
		RP.FACTION.Horde.group = nil
		offers = {}
		render(ns, entry, RP.FACTION.Horde.offer, offers, "offer")
		counts = tally(ns, entry, offers, 300)
		RP.FACTION.Horde.group = sides
		if not counts.offer then
			fail(scenario, "a side with no group lines said nothing of its own to the group")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-5
-- A race the addon has never heard of, and the Haranir, who have no lines of
-- their own: the faction's and the general ones, and still something said.
for _, race in ipairs({ "Murloc", "Haranir" }) do
	local scenario = "rp: a race without lines speaks for its faction (" .. race .. ")"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, race)
		if not ns then return end
		local RP = ns.InCharacter
		local entry = person(ns, "owed")
		local expected = {}
		render(ns, entry, RP.FACTION.Alliance.thanks, expected, "faction")
		render(ns, entry, RP.GENERAL.thanks, expected, "general")
		speaker(ns, entry, "thanks", expected)
		counting()
		local counts, strays = tally(ns, entry, expected, 200)
		if strays[1] then fail(scenario, "said: " .. strays[1]) end
		if not (counts.faction and counts.general) then
			fail(scenario, "fell silent, or lost the faction's or the general lines")
		end
		if ns.PhraseSetText("incharacter") ~= RP.Examples(nil, "Alliance", "MAGE") then
			fail(scenario, "the box's examples are not the faction's and the general ones")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-6
-- A pandaren still on the Wandering Isle is Neutral, and so is anybody whose
-- faction the client will not say: the Neutral lines, never a side's.
for _, faction in ipairs({ "Neutral", "absent" }) do
	local scenario = "rp: a pandaren with no faction yet (" .. faction .. ")"
	with(scenario, faction, nil, function()
		local ns = ready(scenario, "Pandaren")
		if not ns then return end
		local RP = ns.InCharacter
		for _, reason in ipairs({ "owed", "group" }) do
			local entry = person(ns, reason)
			local expected = {}
			local kind = reason == "owed" and "thanks" or "group"
			render(ns, entry, RP.PoolFor(RP.RACE.pandaren, kind), expected, "race")
			render(ns, entry, RP.FACTION.Neutral[kind], expected, "faction")
			render(ns, entry, RP.GENERAL[kind], expected, "general")
			speaker(ns, entry, kind, expected)
			counting()
			local counts, strays = tally(ns, entry, expected, 300)
			if strays[1] then fail(scenario, "a Neutral pandaren said: " .. strays[1]) end
			if not (counts.race and counts.faction) then
				fail(scenario, "the pandaren's or the Neutral lines never came up for " .. reason)
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-7
-- Somebody of the same people is greeted as kin -- a Dark Iron dwarf is a
-- dwarf's cousin -- but only while the unit token still holds them, and never
-- somebody of another people. Every kin line comes up.
do
	local scenario = "rp: kin is greeted as kin"
	with(scenario, "Alliance", { nameplate1 = "DarkIronDwarf", nameplate2 = "Orc" }, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local RP = ns.InCharacter
		Mock.unitNames = { nameplate1 = { "Bram" }, nameplate2 = { "Bram" } }
		local kin = {}
		render(ns, person(ns, "owed"), RP.RACE.dwarf.kin, kin, "kin")
		local function heard(unit, name)
			local entry = person(ns, "owed", unit)
			entry.name = name or ns.UnitFullName(unit)
			counting()
			local hits, which = 0, {}
			for _ = 1, 200 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				if said and kin[said] then
					hits = hits + 1
					which[said] = true
				end
			end
			return hits, which
		end
		local hits, which = heard("nameplate1")
		if hits == 0 then
			fail(scenario, "a Dark Iron dwarf was never greeted as a dwarf's kin")
		end
		for line in pairs(kin) do
			if not which[line] then fail(scenario, "the kin line never came up: " .. line) end
		end
		if heard("nameplate2") > 0 then
			fail(scenario, "an orc was greeted as a dwarf's kin")
		end
		-- The token has moved on to somebody else since the queue was built.
		if heard("nameplate1", "Somebody Else") > 0 then
			fail(scenario, "kin was read off a unit token now holding somebody else")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-8
-- A stranger's race is often a secret on this client: they are not kin as far
-- as anybody can tell, and nothing throws.
--
-- The mock's secret is a plain table, which compares and indexes harmlessly
-- where the client's would throw, so an unplained secret would pass unseen.
-- Here it is filed as a dwarf: read without ns.plain, it would be kin. The
-- table belongs to this scenario's own load, so nothing needs putting back.
do
	local scenario = "rp: a secret race is not read"
	with(scenario, "Alliance", { nameplate1 = Mock.SECRET }, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local RP = ns.InCharacter
		RP.FAMILY[Mock.SECRET] = "dwarf"
		Mock.unitNames = { nameplate1 = { "Bram" } }
		local entry = person(ns, "owed", "nameplate1")
		entry.name = ns.UnitFullName("nameplate1")
		if RP.IsKin(entry, "dwarf") then fail(scenario, "a secret race was taken for kin") end
		local kin = {}
		render(ns, entry, RP.RACE.dwarf.kin, kin, "kin")
		counting()
		for _ = 1, 60 do
			local ok, line = pcall(ns.PickPhrase, entry, 250)
			if not ok then
				fail(scenario, "threw on a secret race: " .. tostring(line))
				break
			end
			local said = line and line:match("^/say (.+)$")
			if not said then
				fail(scenario, "fell silent on a secret race")
				break
			end
			if kin[said] then
				fail(scenario, "greeted as kin on a secret race")
				break
			end
		end
		-- And every value secret: still no throw, still no kin.
		Mock.allSecret = true
		local ok, err = pcall(ns.PickPhrase, entry, 250)
		if not ok then fail(scenario, "threw with every value secret: " .. tostring(err)) end
		Mock.allSecret = false
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-9
-- The line is chosen when the prompt settles on somebody and kept for them:
-- the tooltip, a repaint and the press all carry the same one, as with every
-- other set.
do
	local scenario = "rp: the line stays with the person"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "Troll")
		if not ns then return end
		local RP = ns.InCharacter
		Mock.advance(60)
		local template = ns.BuildQueue()[1]
		if not (template and template.buff) then
			fail(scenario, "SKIPPED -- nobody to build a candidate from")
			return
		end
		local ana = {}
		for k, v in pairs(template) do ana[k] = v end
		ana.name, ana.short, ana.reason, ana.priority = "Ana Field", "Ana Field", "owed", 1
		ana.targetName = ns.TargetName(ana.name)
		ana.unit = "nameplate1"
		-- The nameplate names her: a press speaks only to somebody a token
		-- holds now (speech-range-6).
		Mock.unitNames = { nameplate1 = { "Ana", "Field" } }
		ns.BuildQueue = function() return { ana } end
		wipe(ns.tried)
		counting()
		ns.Prompt:InvalidateMacro()
		ns.Prompt:Refresh()
		local button = ns.Prompt:GetButton()
		local function spoken()
			return tostring(button:GetAttribute("macrotext1") or ""):match("/say ([^\n]+)")
		end
		local first = spoken()
		if not first then
			fail(scenario, "the macro carries no spoken line: " .. tostring(button:GetAttribute("macrotext1")))
			return
		end
		local expected = {}
		render(ns, ana, RP.RACE.troll.thanks, expected, true)
		render(ns, ana, RP.FACTION.Horde.thanks, expected, true)
		render(ns, ana, RP.GENERAL.thanks, expected, true)
		speaker(ns, ana, "thanks", expected)
		for _, pool in pairs(RP.TARGET) do render(ns, ana, pool, expected, true) end
		if not expected[first] then fail(scenario, "the macro says a line that is not a troll's thanks: " .. first) end
		for i = 1, 5 do
			Mock.advance(1)
			ns.Prompt:Refresh()
			if spoken() ~= first then
				fail(scenario, "repaint " .. i .. " changed the line from |" .. first .. "| to |"
					.. tostring(spoken()) .. "|")
				break
			end
		end
		local ran = pressButton(ns)
		local said = tostring(ran or ""):match("/say ([^\n]+)")
		if said ~= first then
			fail(scenario, "the press said |" .. tostring(said) .. "| after the prompt settled on |" .. first .. "|")
		end
		wipe(ns.owed)
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-10
-- A long name, the longest spells, and a /target line with the target handed
-- back: every line of every pool still fits the macro, every moment of every
-- people still has something to say with the whole world known at once, and
-- a pick is never over the room it is given, however little.
do
	local scenario = "rp: every line fits the macro with a long name"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		Mock.advance(60)
		local template = ns.BuildQueue()[1]
		if not (template and template.buff) then
			fail(scenario, "SKIPPED -- nobody to build a candidate from")
			return
		end
		ns.db.profile.filters.restoreTarget = true
		ns.db.profile.speech.channel = "EMOTE"
		local long = {}
		for k, v in pairs(template) do long[k] = v end
		long.name, long.short = "Bartholomewz Stonehammers", "Bartholomewz Stonehammers"
		long.targetName = ns.TargetName(long.name)
		long.unit = "nameplate1"
		long.reason = "owed"
		-- The longest name any buff on any client has, standing in for the
		-- spell going out -- the /cast line grows with it, so the room shrinks
		-- -- and for what they gave.
		local gift = "Legacy of the White Tiger"
		for _, buffs in pairs(ns.BUFFS or {}) do
			for _, buff in ipairs(buffs) do
				local named = ns.BuffName(buff)
				if type(named) == "string" and #named > #gift then gift = named end
			end
		end
		local realName = ns.BuffName
		ns.BuffName = function() return gift end
		local budget = ns.PhraseBudget(long)
		local spell = ns.BuffName(long.buff)
		for _, text in ipairs(everyLine(RP)) do
			local said = ns.Swap(ns.Swap(ns.Swap(text, "{name}", long.short), "{buff}", spell), "{gift}", gift)
			if #("/emote " .. said) > budget then
				fail(scenario, ("%d characters left, and |%s| needs %d"):format(budget, said, #said + 7))
			end
		end
		-- Everything known at once: an inn at night, a warrior, a trade, a
		-- regular. One race of every people, and one with none, on every side.
		world("city", 23)
		long.class, long.gift, long.met = "WARRIOR", gift, 6
		local RACES = { "Dwarf", "Human", "NightElf", "VoidElf", "Gnome", "Draenei", "Worgen",
			"Orc", "Scourge", "Tauren", "Troll", "BloodElf", "Nightborne", "Goblin", "Vulpera",
			"Pandaren", "Dracthyr", "Haranir", "Murloc" }
		for _, faction in ipairs({ "Alliance", "Horde", "Neutral" }) do
			rawset(_G, "UnitFactionGroup", function() return faction, faction end)
			for _, race in ipairs(RACES) do
				Mock.playerRace = race
				for _, reason in ipairs({ "owed", "asked", "group", "nearby", "target" }) do
					long.reason = reason
					local line = ns.PickPhrase(long, budget)
					if not line then
						fail(scenario, ("a %s of the %s has nothing to say for %s with a long name")
							:format(race, faction, reason))
					elseif #line > budget then
						fail(scenario, ("a line of %d went into %d characters: %s"):format(#line, budget, line))
					end
				end
			end
		end
		counting()
		for room = 10, 60, 5 do
			for _ = 1, 20 do
				local line = ns.PickPhrase(long, room)
				if line and #line > room then
					fail(scenario, ("a line of %d went into %d characters: %s"):format(#line, room, line))
				end
			end
		end
		ns.BuffName = realName
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-11
-- What players will read: short, safe in a macro, in character, not doubled
-- up -- not even as the same words punctuated differently -- and every pool
-- of the moment holding more than one line.
--
-- Doubled lines are looked for in the file as well as in the pools, so a line
-- pasted into a table the engine never reads is caught too. RP.LEGACY is left
-- out: it repeats beta.9's lines on purpose.
do
	local scenario = "rp: the lines are short and safe in a macro"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local lines = everyLine(RP)
		if #lines < 2300 then
			fail(scenario, #lines .. " lines in all, fewer than the set was written with")
		end
		-- The only lines {gift} is filled for.
		local trade = {}
		for _, text in ipairs(RP.TRADE) do trade[text] = true end
		for _, pool in pairs(RP.GIFT) do
			for _, text in ipairs(pool) do trade[text] = true end
		end
		local seen, words = {}, {}
		for _, text in ipairs(lines) do
			-- A twelve-letter name and a long spell, given and returned: one
			-- breath, as the lines were written to.
			local said = text:gsub("{name}", "Bartholomewz"):gsub("{buff}", "Power Word: Fortitude")
				:gsub("{gift}", "Power Word: Fortitude")
			if #said > 85 then fail(scenario, #said .. " characters: " .. said) end
			local bareWords = text:gsub("{%a+}", ""):lower():gsub("[^%a]", "")
			if words[bareWords] and not seen[text] then
				fail(scenario, "written twice in other words: |" .. words[bareWords] .. "| and |" .. text .. "|")
			end
			words[bareWords] = text
			if text:find("[|%[%]\r\n]") or text:find("^%s*/") or text:match("^%s*$") then
				fail(scenario, "not safe in a macro: " .. text)
			end
			local bare = text:gsub("{name}", ""):gsub("{buff}", ""):gsub("{gift}", "")
			if bare:find("[{}]") then fail(scenario, "a token the set does not swap: " .. text) end
			if bare:lower():find("buff", 1, true) then
				fail(scenario, "says \"buff\" out of character: " .. text)
			end
			if text:find("{gift}", 1, true) and not trade[text] then
				fail(scenario, "{gift} outside the trade and gift lines, where nothing fills it: " .. text)
			end
			if seen[text] then fail(scenario, "written twice: " .. text) end
			seen[text] = true
		end
		for where, pool in pairs(contextPools(RP)) do
			if type(pool) ~= "table" or #pool < 2 then
				fail(scenario, where .. " has fewer than 2 lines")
			end
		end
		-- Every L["..."] in the file, outside RP.LEGACY.
		local file = io.open(dir .. "/Phrases.lua", "rb")
		local source = file and file:read("*a") or ""
		if file then file:close() end
		local from, to = source:find("\nRP%.LEGACY = {.-\n}\n")
		if not from then
			fail(scenario, "SKIPPED -- RP.LEGACY is not in Phrases.lua to leave out")
		else
			source = source:sub(1, from) .. source:sub(to)
		end
		-- Comments name L["..."] as the shape a line takes; they are not lines.
		source = ("\n" .. source):gsub("\n[ \t]*%-%-[^\n]*", "\n")
		local literals, count = {}, 0
		for text in source:gmatch('L%["(.-)"%]') do
			count = count + 1
			if literals[text] then fail(scenario, "written twice in Phrases.lua: " .. text) end
			literals[text] = true
		end
		if count < #lines then
			fail(scenario, ("only %d literals found in Phrases.lua for %d lines"):format(count, #lines))
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-12
-- Nobody who has not picked the set hears anything new: the box speaks as it
-- always did, and In character is not even asked. A box edited away from the
-- set, or the set's text pasted under another set, is the player's own lines.
do
	local scenario = "rp: without the set the box speaks as before"
	with(scenario, "Alliance", nil, function()
		Mock.reset()
		Mock.playerRace = "Dwarf"
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		local speech = ns.db.profile.speech
		speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
		local realPick = ns.InCharacter.Pick
		local asked = 0
		ns.InCharacter.Pick = function(...) asked = asked + 1 return realPick(...) end
		local entry = person(ns, "owed")
		local roleplay = {}
		render(ns, entry, ns.PHRASE_SETS.roleplay.lines, roleplay, true)
		for _ = 1, 40 do
			local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
			if not (said and roleplay[said]) then
				fail(scenario, "an untouched profile said " .. tostring(said))
				break
			end
		end
		speech.presetChoice, speech.phrases = "incharacter", "Hi {name}!"
		if ns.PickPhrase(entry, 250) ~= "/say Hi Bram!" then
			fail(scenario, "a box edited away from In character did not speak its own line")
		end
		speech.presetChoice, speech.phrases = "polite", ns.InCharacter.Text()
		local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
		local box = {}
		for line in ns.InCharacter.Text():gmatch("[^\n]+") do render(ns, entry, { line }, box, true) end
		if not (said and box[said]) then
			fail(scenario, "the examples pasted under another set did not speak as typed lines: " .. tostring(said))
		end
		if asked > 0 then
			fail(scenario, "In character was asked " .. asked .. " times for a profile that never chose it")
		end
		ns.InCharacter.Pick = realPick
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-13
-- The set through the options: loaded from the dropdown, the box shows this
-- character's examples and a note, and the dropdown names it -- on every
-- character sharing the profile, whatever their people or class. Editing the
-- box makes the lines your own, and emptying it goes back to the set.
do
	local scenario = "rp: load the set, share it, edit it"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "NightElf")
		if not ns then return end
		local RP = ns.InCharacter
		local preset = findOption(ns.optionsTable, "preset")
		local phrases = findOption(ns.optionsTable, "phrases")
		local note = findOption(ns.optionsTable, "inCharacterNote")
		if not (phrases and phrases.get and phrases.set and note) then
			fail(scenario, "SKIPPED -- the phrase box or the note is not on the page")
			return
		end
		local listed = preset.values and preset.values() or {}
		local order = preset.sorting and preset.sorting() or {}
		local inOrder = false
		for _, key in ipairs(order) do inOrder = inOrder or key == "incharacter" end
		if not (listed.incharacter and inOrder) then
			fail(scenario, "In character is not among the sets the dropdown lists")
		end
		local speech = ns.db.profile.speech
		if speech.phrases ~= RP.Examples("nightelf", "Alliance", "MAGE") then
			fail(scenario, "loading the set filled the box with |" .. tostring(speech.phrases) .. "|")
		end
		if preset.get({ "preset" }) ~= "incharacter" then
			fail(scenario, "the dropdown reads " .. tostring(preset.get({ "preset" })) .. " over the set just loaded")
		end
		if note.hidden() then fail(scenario, "the note saying how lines are picked is hidden") end
		local elune = RP.RACE.nightelf.thanks[1]
		if not tostring(phrases.get({ "phrases" })):find(elune, 1, true) then
			fail(scenario, "the box does not show a night elf's lines")
		end

		-- An orc warrior of the Horde on the same profile, last saved by a
		-- dracthyr priest (whose box nothing here has read yet).
		Mock.playerRace = "Orc"
		Mock.class = "WARRIOR"
		rawset(_G, "UnitFactionGroup", function() return "Horde", "Horde" end)
		speech.phrases = RP.Examples("dracthyr", "Neutral", "PRIEST")
		if not RP.Active(speech) then
			fail(scenario, "a dracthyr priest's untouched set counted as edited on an orc sharing the profile")
		end
		if phrases.get({ "phrases" }) ~= RP.Examples("orc", "Horde", "WARRIOR") then
			fail(scenario, "the orc's box shows |" .. tostring(phrases.get({ "phrases" })) .. "|")
		end
		if preset.get({ "preset" }) ~= "incharacter" then
			fail(scenario, "the orc's dropdown reads " .. tostring(preset.get({ "preset" })))
		end
		counting()
		local entry = person(ns, "owed")
		local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
		local expected = {}
		render(ns, entry, RP.RACE.orc.thanks, expected, true)
		render(ns, entry, RP.FACTION.Horde.thanks, expected, true)
		render(ns, entry, RP.GENERAL.thanks, expected, true)
		speaker(ns, entry, "thanks", expected)
		if not (said and expected[said]) then
			fail(scenario, "the orc sharing the profile said " .. tostring(said))
		end

		-- Edited: the player's own lines, and the dropdown lets go.
		phrases.set({ "phrases" }, RP.Examples("orc", "Horde", "WARRIOR") .. "\nMy own line, {name}.")
		if preset.get({ "preset" }) ~= nil then
			fail(scenario, "the dropdown still reads " .. tostring(preset.get({ "preset" })) .. " over edited lines")
		end
		if not note.hidden() then fail(scenario, "the note stays up over lines that are now the player's") end
		speech.phrases = "My own line, {name}."
		if ns.PickPhrase(entry, 250) ~= "/say My own line, Bram." then
			fail(scenario, "edited lines were not the ones spoken")
		end

		-- Emptied: back to the set it names.
		phrases.set({ "phrases" }, "")
		if not RP.Active(speech) then fail(scenario, "an emptied box did not go back to In character") end
		ns.ClampSettings()
		if speech.phrases ~= RP.Examples("orc", "Horde", "WARRIOR") then
			fail(scenario, "the load-time repair rewrote the set: |" .. tostring(speech.phrases) .. "|")
		end
		if ns.ExportSettings():find("speech.phrases=", 1, true) then
			fail(scenario, "an untouched In character box is exported as though it were edited")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-14
-- Roll a few shows a line for each reason the set speaks for, labelled, since
-- it says something different for each, and then two moments it notices: a
-- favour whose spell is known, answered with a trade line naming it, and
-- somebody met for the third time. Only the favours when that is all speech
-- is on for.
do
	local scenario = "rp: roll a few rolls a line per reason"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "Goblin")
		if not ns then return end
		local RP = ns.InCharacter
		local roll = findOption(ns.optionsTable, "roll")
		if not (roll and roll.func) then
			fail(scenario, "SKIPPED -- Roll a few is not on the page")
			return
		end
		local function rolled()
			Mock.printed = {}
			roll.func()
			local labels, lines = {}, {}
			for _, printed in ipairs(Mock.printed) do
				local label, said = tostring(printed):match("|cff888888(.-)|r /say (.+)$")
				if label then
					labels[#labels + 1] = label
					lines[#lines + 1] = said
				end
			end
			return labels, lines, #Mock.printed
		end
		local gifted = "Returning a favour of "
		local again = "Meeting somebody a third time:"
		local labels, lines, printed = rolled()
		local want = { "Returning a favour:", "Answering a request:", "In your group:", "Offering unasked:",
			gifted, again }
		if #labels ~= #want then
			fail(scenario, "rolled " .. #labels .. " labelled lines out of " .. printed .. ", not one per reason"
				.. " and the two moments")
		else
			for i, label in ipairs(want) do
				if labels[i]:sub(1, #label) ~= label then
					fail(scenario, "line " .. i .. " is labelled " .. labels[i])
				end
			end
			-- The trade row names a spell and says a trade line with it.
			local spell = labels[5]:match("^Returning a favour of (.+):$")
			local entry = { short = "Somebody", buff = someBuff(ns) }
			local trade, familiar = {}, {}
			render(ns, entry, RP.TRADE, trade, true, spell)
			for _, pool in pairs(RP.GIFT) do render(ns, entry, pool, trade, true, spell) end
			render(ns, entry, RP.HISTORY.again, familiar, true)
			if not (spell and trade[lines[5]]) then
				fail(scenario, "the favour's row said no trade line: " .. tostring(labels[5]) .. " "
					.. tostring(lines[5]))
			end
			if spell == ns.BuffName(entry.buff) then
				fail(scenario, "the favour's row trades " .. spell .. " for itself")
			end
			if not familiar[lines[6]] then
				fail(scenario, "the third meeting's row said: " .. tostring(lines[6]))
			end
		end
		ns.db.profile.speech.onlyWhenReturning = true
		labels = rolled()
		if #labels ~= 3 then
			fail(scenario, "with only favours spoken, rolled " .. #labels .. " lines")
		else
			if labels[1] ~= want[1] or labels[2]:sub(1, #gifted) ~= gifted or labels[3] ~= again then
				fail(scenario, "with only favours spoken, rolled " .. table.concat(labels, " / "))
			end
		end
		for _, label in ipairs(labels) do
			if label == want[2] or label == want[3] or label == want[4] then
				fail(scenario, "with only favours spoken, rolled a line for " .. label)
				break
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-15
-- With no spell to name, a line built around one is left out rather than
-- said with a hole where the spell would go.
do
	local scenario = "rp: no hole where a spell name would go"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Gnome")
		if not ns then return end
		local holes = {}
		for _, text in ipairs(everyLine(ns.InCharacter)) do
			if text:find("{buff}", 1, true) or text:find("{gift}", 1, true) then
				local said = ns.Swap(ns.Swap(ns.Swap(text, "{name}", "Bram"), "{buff}", ""), "{gift}", "")
				holes[(said:gsub("%s+", " "):match("^%s*(.-)%s*$"))] = true
			end
		end
		counting()
		for _, reason in ipairs({ "owed", "asked", "nearby" }) do
			local entry = person(ns, reason)
			entry.buff = nil
			for _ = 1, 60 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				if not said then
					fail(scenario, "fell silent for " .. reason .. " with no spell")
					break
				end
				if holes[said] then
					fail(scenario, "said a line with its spell missing: " .. said)
					break
				end
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-16
-- "Only when returning a favour" holds for this set as for every other: it
-- speaks to somebody who buffed you and to nobody else. Roll a few picks only
-- favours when that is on, so this asks ns.PickPhrase for the other reasons
-- itself -- a merge that moved the set's hook above the check would otherwise
-- go unseen.
do
	local scenario = "rp: in character keeps to returning favours"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "Orc")
		if not ns then return end
		local speech = ns.db.profile.speech
		speech.onlyWhenReturning = true
		if not ns.InCharacter.Active(speech) then
			fail(scenario, "SKIPPED -- In character is not what speaks")
			return
		end
		for _, reason in ipairs({ "asked", "group", "nearby", "target" }) do
			local line = ns.PickPhrase(person(ns, reason), 250)
			if line ~= nil then
				fail(scenario, "spoke for reason " .. reason .. " with only favours on: " .. line)
			end
		end
		if not ns.PickPhrase(person(ns, "owed"), 250) then
			fail(scenario, "said nothing to somebody who buffed us first")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-17
-- A player on a French client picks the set while its lines are still English,
-- so the box saves English examples; a later release translates the lines. The
-- set must still be the one speaking -- else the dropdown goes blank and the
-- examples are said as plain lines, thanks and all, to strangers -- and the
-- load-time repair turns the box into the translated examples, as core-12
-- does for the fixed sets.
--
-- The "translation" is Phrases.lua run again into the same session with every
-- string prefixed, so the English each line shipped with is captured before
-- it, as in core-12.
do
	local scenario = "rp: english examples still count once the lines are translated"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local speech = ns.db.profile.speech
		local english = speech.phrases
		if english ~= ns.InCharacter.Examples("dwarf", "Alliance", "MAGE") then
			fail(scenario, "SKIPPED -- the set did not load the dwarf's examples")
			return
		end
		for i = #ns.PHRASE_SET_ORDER, 1, -1 do
			if ns.PHRASE_SET_ORDER[i] == "incharacter" then table.remove(ns.PHRASE_SET_ORDER, i) end
		end
		local realL = ns.L
		ns.L = setmetatable({}, { __index = function(_, key) return "[fr] " .. key end })
		local chunk, err = loadfile(dir .. "/Phrases.lua")
		local ok, runErr = false, err
		if chunk then ok, runErr = pcall(chunk, "Manners", ns) end
		ns.L = realL
		if not ok then
			fail(scenario, "Phrases.lua would not load translated: " .. tostring(runErr))
			return
		end
		local RP = ns.InCharacter
		if RP.Text() == english then
			fail(scenario, "SKIPPED -- the translated examples read the same as the English ones")
			return
		end
		if not RP.Active(speech) then
			fail(scenario, "the English examples saved before translation count as edited lines")
		end
		ns.ClampSettings()
		if speech.phrases ~= RP.Text() then
			fail(scenario, "the load-time repair left the box as |" .. tostring(speech.phrases) .. "|")
		end
		if not RP.Active(speech) then fail(scenario, "the repaired box is not In character") end
		local preset = findOption(ns.optionsTable, "preset")
		if preset and preset.get and preset.get({ "preset" }) ~= "incharacter" then
			fail(scenario, "the dropdown reads " .. tostring(preset.get({ "preset" })) .. " over the untouched set")
		end
		if ns.ExportSettings():find("speech.phrases=", 1, true) then
			fail(scenario, "an untouched In character box is exported as though it were edited")
		end
		-- A stranger nearby hears an offer, in the new language, never the
		-- thanks at the top of the box.
		local entry = person(ns, "nearby")
		local expected = {}
		render(ns, entry, RP.RACE.dwarf.offer, expected, true)
		render(ns, entry, RP.FACTION.Alliance.offer, expected, true)
		render(ns, entry, RP.GENERAL.offer, expected, true)
		speaker(ns, entry, "offer", expected)
		counting()
		for _ = 1, 30 do
			local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
			if not (said and expected[said]) then
				fail(scenario, "a stranger nearby heard " .. tostring(said))
				break
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-18
-- The speaker's class: a mage talks like a mage, a warrior like a warrior,
-- each only in its own moment's lines, and never in another class's. A class
-- with no lines of its own, or one the client will not say, speaks without.
do
	local scenario = "rp: each class speaks with its own lines"
	for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "PALADIN", "WARLOCK", "WARRIOR", "ROGUE", "secret" }) do
		local classes = { player = class == "secret" and Mock.SECRET or class }
		with(scenario, "Alliance", nil, function()
			local ns = ready(scenario, "Human")
			if not ns then return end
			local RP = ns.InCharacter
			for _, reason in ipairs({ "owed", "asked", "nearby", "group" }) do
				local kind = reason == "owed" and "thanks" or reason == "nearby" and "offer" or reason
				local entry = person(ns, reason)
				local lines = {}
				for token, pools in pairs(RP.CLASS) do
					for poolKind, pool in pairs(pools) do
						render(ns, entry, pool, lines, token .. "." .. poolKind)
					end
				end
				counting()
				local heard = {}
				for _ = 1, 300 do
					local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
					local tag = said and lines[said]
					if tag then heard[tag] = (heard[tag] or 0) + 1 end
				end
				local mine = RP.CLASS[class] and (class .. "." .. kind)
				for tag in pairs(heard) do
					if tag ~= mine then
						fail(scenario, ("a %s said a %s line for %s"):format(class, tag, reason))
					end
				end
				if mine and not heard[mine] then
					fail(scenario, ("a %s never said a line of its own for %s"):format(class, reason))
				end
			end
			noErrors(scenario, ns)
		end, classes)
	end
end

-- ------------------------------------------------------------------ rp-19
-- The spell going out: lines about it come up for it, and never another's.
do
	local scenario = "rp: lines about the spell going out"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local tried = 0
		for class, buffs in pairs(ns.BUFFS or {}) do
			for _, buff in ipairs(buffs) do
				if RP.SPELL[buff.key] then
					tried = tried + 1
					local entry = person(ns, "nearby")
					entry.buff = buff
					local lines = {}
					for key, pool in pairs(RP.SPELL) do render(ns, entry, pool, lines, key) end
					counting()
					local heard = 0
					for _ = 1, 150 do
						local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
						local key = said and lines[said]
						if key == buff.key then
							heard = heard + 1
						elseif key then
							fail(scenario, ("%s's %s said a line about %s: %s"):format(class, buff.key, key, said))
							break
						end
					end
					if heard == 0 then
						fail(scenario, ("%s's %s never had a line about it"):format(class, buff.key))
					end
				end
			end
		end
		if tried < 10 then fail(scenario, "SKIPPED -- only " .. tried .. " spells have lines of their own") end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-20
-- A favour whose spell is known is thanked for by name: the debt the aura scan
-- files carries the spell, and a thank-you then draws on the trade lines with
-- {gift} as that spell, and on the lines about what that spell does (RP.GIFT,
-- found by its buff key) -- that spell's, never another's. Never for any other
-- moment, never with the spell unknown (a debt kept across a reload, an id the
-- client will not name, a secret), and never "Fortitude for Fortitude".
do
	local scenario = "rp: a favour is thanked for by the spell it was"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		H.clearClicks(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 4101)
		local name, debt = next(ns.owed)
		if not (name and debt) then
			fail(scenario, "SKIPPED -- no favour was filed")
			return
		end
		if debt.spell ~= 10938 then
			fail(scenario, "the debt does not carry the spell they gave: " .. tostring(debt.spell))
		end
		local entry = { name = name, short = "Petra", reason = "owed", buff = someBuff(ns) }
		local gift = "Power Word: Fortitude"
		local trade = {}
		render(ns, entry, RP.TRADE, trade, "trade", gift)
		for key, pool in pairs(RP.GIFT) do render(ns, entry, pool, trade, key, gift) end
		local heard
		local function trades(e, n, lean)
			e.lean = lean
			counting()
			local hits = 0
			heard = {}
			for _ = 1, n do
				local said = (ns.PickPhrase(e, 250) or ""):match("^/say (.+)$")
				if said and trade[said] then
					hits = hits + 1
					heard[trade[said]] = true
				end
			end
			e.lean = nil
			return hits
		end
		if trades(entry, 200) == 0 then fail(scenario, "a thank-you never named the spell they gave") end
		if not heard.trade then fail(scenario, "a thank-you never said a trade line") end
		if not heard.fortitude then fail(scenario, "Fortitude given was never thanked for as Fortitude") end
		for key in pairs(heard) do
			if key ~= "trade" and key ~= "fortitude" then
				fail(scenario, "Fortitude given was thanked for as " .. key)
			end
		end
		if trades(entry, 20, "trade") ~= 20 then
			fail(scenario, "leaning on the trade lines said something else")
		end
		for _, reason in ipairs({ "asked", "nearby", "group", "target" }) do
			entry.reason = reason
			if trades(entry, 100, "trade") > 0 then fail(scenario, "a trade line for reason " .. reason) end
		end
		entry.reason = "owed"
		-- Unknown, for each of the ways it can be.
		local cases = {
			{ "a debt with no spell", function() debt.spell = nil end },
			{ "a secret spell", function() debt.spell = Mock.SECRET end },
			{ "a spell the client will not name", function()
				debt.spell = 10938
				Mock.unknownSpells = { [10938] = true }
			end },
			{ "no debt at all", function() ns.owed[name] = nil end },
		}
		for _, case in ipairs(cases) do
			case[2]()
			local ok, hits = pcall(trades, entry, 100, "trade")
			if not ok then
				fail(scenario, "threw on " .. case[1] .. ": " .. tostring(hits))
			elseif hits > 0 then
				fail(scenario, "a trade line with " .. case[1])
			end
		end
		Mock.unknownSpells = nil
		-- The spell going back is the one they gave.
		ns.owed[name] = debt
		debt.spell = 10157
		entry.buff = ns.FindBuff("MAGE", "intellect")
		if ns.BuffName(entry.buff) == "Arcane Intellect" then
			trade = {}
			render(ns, entry, RP.TRADE, trade, "trade", "Arcane Intellect")
			if trades(entry, 100, "trade") > 0 then fail(scenario, "traded a spell for itself") end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-21
-- How often two people have traded this session: the first time is nothing
-- special, the second and third are "again", the fourth on "regular". A
-- favour counts once however many buffs it arrives as, its return completes it
-- rather than counting twice, a gift counts once and a refused one not at all.
-- The count is heard through Core, from the aura scan onward.
do
	local scenario = "rp: meeting the same person again"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local A = { name = "Ada Aim" }
		local function is(kind, want, step)
			local got = RP.Familiar(A, kind)
			if got ~= want then
				fail(scenario, ("%s: a %s reads %s, not %s"):format(step, kind, tostring(got), tostring(want)))
			end
		end
		is("offer", nil, "never met")
		RP.Heard("Settled", A.name, nil)
		is("offer", "again", "after one gift")
		RP.Heard("Received", { name = A.name, key = 1459 })
		is("thanks", "again", "their favour back")
		RP.Heard("Received", { name = A.name, key = 10938 })
		is("thanks", "again", "a second buff in the same favour")
		RP.Heard("Settled", A.name, { at = 1 })
		is("offer", "again", "the favour returned")
		RP.Heard("Settled", A.name, nil)
		is("offer", "regular", "a third exchange done")
		RP.Heard("Refused", A.name, GetTime())
		is("offer", "again", "the third refused")
		RP.Heard("Refused", A.name, GetTime())
		is("offer", "again", "a refusal nothing settled")
		RP.Heard("Received", { name = A.name, key = 1459 }, true)
		is("thanks", "regular", "a favour nothing returns")
		RP.Heard("Received", { name = A.name, key = 1459 })
		RP.Heard("LetGo", A.name, "expired")
		is("thanks", "regular", "a favour let go")
		-- Nothing that is not a name is counted, and nothing throws.
		for _, junk in ipairs({ { Mock.SECRET }, { nil }, { 5 } }) do
			local ok, err = pcall(RP.Heard, "Settled", junk[1], nil)
			if not ok then fail(scenario, "threw on a name that is not one: " .. tostring(err)) end
			ok, err = pcall(RP.Heard, "Received", { name = junk[1] })
			if not ok then fail(scenario, "threw on a favour with no name: " .. tostring(err)) end
		end

		-- Through the addon: a favour the aura scan files is counted.
		H.clearClicks(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 4101)
		local name = next(ns.owed)
		if not name then
			fail(scenario, "SKIPPED -- no favour was filed")
		else
			local B = { name = name, short = "Petra", reason = "owed", buff = someBuff(ns) }
			if RP.Familiar(B, "thanks") ~= nil then fail(scenario, "a first favour read as a second meeting") end
			if RP.Familiar(B, "offer") ~= "again" then
				fail(scenario, "the favour the aura scan filed was never counted")
			end
			-- And the lines follow: a regular hears the regulars' lines, and
			-- somebody met for the first time never does.
			local lines = {}
			for key, pool in pairs(RP.HISTORY) do render(ns, B, pool, lines, key) end
			local function heard(n)
				B.met = n
				counting()
				local got = {}
				for _ = 1, 200 do
					local said = (ns.PickPhrase(B, 250) or ""):match("^/say (.+)$")
					local key = said and lines[said]
					if key then got[key] = true end
				end
				return got
			end
			local first, regular = heard(1), heard(5)
			if next(first) then fail(scenario, "somebody met for the first time heard a line about meeting again") end
			if not regular.regular or regular.again then
				fail(scenario, "a regular did not hear the regulars' lines, or heard the second meeting's")
			end
			B.met = nil
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-22
-- Where this is: a city or an inn, the wilds, a dungeon or a raid, a
-- battleground or an arena, and none of them in a scenario or whenever the
-- client will not say.
do
	local scenario = "rp: lines for where you are"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local cases = {
			{ "city", "city" }, { "wild", "wild" }, { "party", "instance" }, { "raid", "instance" },
			{ "pvp", "battle" }, { "arena", "battle" }, { "scenario", nil }, { nil, nil },
		}
		local entry = person(ns, "nearby")
		local lines = {}
		for key, pool in pairs(RP.PLACE) do render(ns, entry, pool, lines, key) end
		for _, case in ipairs(cases) do
			world(case[1], nil)
			local got = RP.Place()
			if got ~= case[2] then
				fail(scenario, ("%s reads as %s"):format(tostring(case[1]), tostring(got)))
			end
			counting()
			local heard = {}
			for _ = 1, 150 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				local key = said and lines[said]
				if key then heard[key] = true end
			end
			for key in pairs(heard) do
				if key ~= case[2] then
					fail(scenario, ("%s said a line for %s"):format(tostring(case[1]), key))
				end
			end
			if case[2] and not heard[case[2]] then
				fail(scenario, ("%s never said a line for it"):format(tostring(case[1])))
			end
		end
		-- The client will not say: a throw, a secret, either question.
		local refusals = {
			{ "IsInInstance throws", function() error("no") end, function() return false end },
			{ "IsInInstance secret", function() return Mock.SECRET, "none" end, function() return false end },
			{ "the instance type secret", function() return true, Mock.SECRET end, function() return false end },
			{ "IsResting secret", function() return false, "none" end, function() return Mock.SECRET end },
			{ "IsResting throws", function() return false, "none" end, function() error("no") end },
		}
		for _, case in ipairs(refusals) do
			rawset(_G, "IsInInstance", case[2])
			rawset(_G, "IsResting", case[3])
			local ok, got = pcall(RP.Place)
			if not ok then
				fail(scenario, case[1] .. " threw: " .. tostring(got))
			elseif got ~= nil then
				fail(scenario, case[1] .. " read as " .. tostring(got))
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-23
-- The hour on the realm's clock: morning from five until eleven, night from
-- ten at night until five, nothing in between or when the client will not
-- say.
do
	local scenario = "rp: lines for the hour"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local want = {
			[0] = "night", [3] = "night", [4] = "night", [5] = "morning", [8] = "morning",
			[10] = "morning", [11] = false, [15] = false, [21] = false, [22] = "night", [23] = "night",
		}
		local entry = person(ns, "nearby")
		local lines = {}
		for key, pool in pairs(RP.TIME) do render(ns, entry, pool, lines, key) end
		for hour, key in pairs(want) do
			world(nil, hour)
			local got = RP.Hour()
			if got ~= (key or nil) then
				fail(scenario, ("%d o'clock reads as %s"):format(hour, tostring(got)))
			end
			counting()
			local heard = {}
			for _ = 1, 150 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				local k = said and lines[said]
				if k then heard[k] = true end
			end
			for k in pairs(heard) do
				if k ~= key then fail(scenario, ("%d o'clock said a %s line"):format(hour, k)) end
			end
			if key and not heard[key] then fail(scenario, ("%d o'clock never said a %s line"):format(hour, key)) end
		end
		for _, case in ipairs({
			{ "no clock", nil },
			{ "a secret hour", function() return Mock.SECRET, 5 end },
			{ "a clock that throws", function() error("no") end },
		}) do
			rawset(_G, "GetGameTime", case[2])
			local ok, got = pcall(RP.Hour)
			if not ok or got ~= nil then fail(scenario, case[1] .. " read as " .. tostring(got)) end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-24
-- The class of the person being helped: their own pool, or when it is ours
-- that class's own lines about meeting itself (a mage to a mage), and the
-- lines for any two of a kind when the class has none; read from the queue or
-- else from a token still holding them, and nothing when it is unknown, a
-- secret, or read off a token now holding somebody else.
do
	local scenario = "rp: lines for the class being helped"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		Mock.unitNames = { nameplate1 = { "Bram" } }
		Mock.unitClass = "WARRIOR"
		local cases = {
			{ "a warrior on the entry", { class = "WARRIOR" }, "WARRIOR" },
			{ "a mage helping a mage", { class = "MAGE" }, "same.MAGE" },
			{ "a mage helping a mage, with no mage lines for it", { class = "MAGE" }, "sameclass", "MAGE" },
			-- Every class the client has is written for; a token of one it may
			-- add later is not.
			{ "a class with no lines", { class = "ADVENTURER" }, nil },
			{ "a secret class", { class = Mock.SECRET }, nil },
			{ "read off the token", { unit = "nameplate1" }, "WARRIOR" },
			{ "a token now holding somebody else", { unit = "nameplate1", name = "Somebody Else" }, nil },
			{ "nothing to go on", {}, nil },
		}
		for _, case in ipairs(cases) do
			local entry = person(ns, "nearby")
			for k, v in pairs(case[2]) do entry[k] = v end
			local lines = {}
			for key, pool in pairs(RP.TARGET) do render(ns, entry, pool, lines, key) end
			for key, pool in pairs(RP.SAME) do render(ns, entry, pool, lines, "same." .. key) end
			local without = case[4] and RP.SAME[case[4]]
			if without then RP.SAME[case[4]] = nil end
			counting()
			local heard = {}
			for _ = 1, 150 do
				local ok, line = pcall(ns.PickPhrase, entry, 250)
				if not ok then
					fail(scenario, case[1] .. " threw: " .. tostring(line))
					break
				end
				local said = line and line:match("^/say (.+)$")
				local key = said and lines[said]
				if key then heard[key] = true end
			end
			if without then RP.SAME[case[4]] = without end
			for key in pairs(heard) do
				if key ~= case[3] then fail(scenario, case[1] .. " said a line for " .. key) end
			end
			if case[3] and not heard[case[3]] then
				fail(scenario, case[1] .. " never said a line for " .. case[3])
			end
		end
		-- A secret straight off the token.
		Mock.unitClass = Mock.SECRET
		local entry = person(ns, "nearby", "nameplate1")
		if RP.Target(entry, "MAGE") ~= nil then fail(scenario, "a secret class read off the token was used") end
		noErrors(scenario, ns)
	end, { nameplate1 = nil })
end

-- ------------------------------------------------------------------ rp-25
-- The weighing: with every moment known at once, each pool is heard in
-- proportion to its weight times its lines, counted up to RP.SPREAD. The
-- people's own lines come first, a meeting again next, and the rare moments
-- made for this click (a trade, a gift, kin, a meeting again) outweigh the
-- ones that are nearly always true, and what a gift does outweighs its name.
-- Returning a favour, the
-- pools that do not say thank you (the spell, the place, the hour, whoever is
-- helped) weigh half; the spell on a class it does little for shares the
-- pool of whoever is helped rather than adding to it. A people with no group
-- lines speaks its offers to a group at half its weight.
--
-- The memory that keeps a line from being said twice in a row (RP.RECENT) is
-- off here, since it bends every share on purpose; rp-28 checks it.
do
	local scenario = "rp: pools are weighed as documented"
	with(scenario, "Alliance", { nameplate1 = "Dwarf" }, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local RP = ns.InCharacter
		local recent = RP.RECENT
		RP.RECENT = 0
		Mock.unitNames = { nameplate1 = { "Bram" } }
		world("wild", 23)
		local gift = "Mark of the Wild"
		local entry = person(ns, "owed", "nameplate1")
		entry.name = ns.UnitFullName("nameplate1")
		entry.class, entry.gift, entry.giftKey, entry.met = "WARRIOR", gift, "motw", 3
		local W = RP.WEIGHT
		-- A warrior helped: their lines, and the spell's on a warrior if it
		-- has any, as one pool.
		local onto = RP.ONTO[entry.buff.key]
		local warrior = joined(RP.TARGET.WARRIOR, onto and onto.WARRIOR)
		local pools = {
			race = { RP.RACE.dwarf.thanks, W.race }, kin = { RP.RACE.dwarf.kin, W.kin },
			faction = { RP.FACTION.Alliance.thanks, W.faction }, general = { RP.GENERAL.thanks, W.general },
			class = { RP.CLASS.MAGE.thanks, W.class }, spell = { RP.SPELL[entry.buff.key], W.spell / 2 },
			trade = { RP.TRADE, W.trade }, gift = { RP.GIFT.motw, W.gift },
			history = { RP.HISTORY.again, W.history },
			place = { RP.PLACE.wild, W.place / 2 }, time = { RP.TIME.night, W.time / 2 },
			target = { warrior, W.target / 2 },
		}
		local expected, share, total = {}, {}, 0
		for tag, p in pairs(pools) do
			render(ns, entry, p[1], expected, tag, gift)
			share[tag] = p[2] * math.min(#p[1], RP.SPREAD)
			total = total + share[tag]
		end
		counting()
		local N = 4000
		local counts, strays = tally(ns, entry, expected, N)
		if strays[1] then fail(scenario, "said a line from no pool of this moment: " .. strays[1]) end
		for tag, s in pairs(share) do
			local want, got = s / total, (counts[tag] or 0) / N
			if math.abs(want - got) > 0.015 then
				fail(scenario, ("%s heard %.1f%% of the time, weighed for %.1f%%"):format(tag, got * 100, want * 100))
			end
		end
		-- The order, by the exact shares: the counts are held to them above,
		-- and two counts a couple of standard deviations apart could swap on
		-- any change to the order of the draws.
		local function more(a, b)
			if (share[a] or 0) <= (share[b] or 0) then
				fail(scenario, ("%s (%.1f) is not weighed above %s (%.1f)"):format(a, share[a] or 0, b, share[b] or 0))
			end
		end
		more("race", "class") more("race", "faction") more("race", "general")
		more("trade", "place") more("trade", "time") more("trade", "spell")
		more("gift", "place") more("gift", "time") more("gift", "trade")
		more("history", "place") more("history", "trade") more("race", "history")
		more("kin", "general")

		-- A pool of one line is heard a third as often as a full one, and a
		-- pool of twelve no more often than one of three.
		local saved = RP.TIME.night
		for _, case in ipairs({ { "a lone line", 1 }, { "a pool of twelve", 12 } }) do
			local pool = {}
			for i = 1, case[2] do
				pool[i] = i == 1 and saved[1] or ("Night line " .. i .. ", {name}.")
				render(ns, entry, { pool[i] }, expected, "time")
			end
			RP.TIME.night = pool
			counting()
			counts = tally(ns, entry, expected, N)
			local s = W.time / 2 * math.min(case[2], RP.SPREAD)
			local want = s / (total - share.time + s)
			if math.abs((counts.time or 0) / N - want) > 0.01 then
				fail(scenario, ("%s heard %.1f%% of the time, not the %.1f%% its share gives")
					:format(case[1], (counts.time or 0) / N * 100, want * 100))
			end
		end
		RP.TIME.night = saved

		-- In a group, at midday in a dungeon, with the dwarves' group lines
		-- taken away: their offers at half weight.
		world("party", 14)
		local party = person(ns, "group")
		party.class = "WARRIOR"
		local own = RP.RACE.dwarf.group
		RP.RACE.dwarf.group = nil
		local group = {
			race = { RP.RACE.dwarf.offer, W.race / 2 },
			group = { RP.FACTION.Alliance.group, W.group },
			general = { RP.GENERAL.group, W.group }, class = { RP.CLASS.MAGE.group, W.class },
			spell = { RP.SPELL[party.buff.key], W.spell }, place = { RP.PLACE.instance, W.place },
			target = { warrior, W.target },
		}
		expected, share, total = {}, {}, 0
		for tag, p in pairs(group) do
			render(ns, party, p[1], expected, tag)
			share[tag] = p[2] * math.min(#p[1], RP.SPREAD)
			total = total + share[tag]
		end
		counting()
		counts, strays = tally(ns, party, expected, N)
		RP.RACE.dwarf.group = own
		if strays[1] then fail(scenario, "a group heard a line from no pool of its moment: " .. strays[1]) end
		local want, got = share.race / total, (counts.race or 0) / N
		if math.abs(want - got) > 0.015 then
			fail(scenario, ("a people without group lines offered to its group %.1f%% of the time, not %.1f%%")
				:format(got * 100, want * 100))
		end
		RP.RECENT = recent
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-26
-- The box shows the set noticing the moment -- a line of the character's
-- class, somebody met again, a dungeon -- and a box beta.9 saved, five lines
-- long, is still the untouched set on every people and side, and is turned
-- into today's examples when the profile loads.
do
	local scenario = "rp: the box shows the moment, and beta.9's box still counts"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local RP = ns.InCharacter
		local box = RP.Text()
		for _, text in ipairs({ RP.CLASS.MAGE.offer[1], RP.HISTORY.again[1], RP.PLACE.instance[1] }) do
			if not box:find(text, 1, true) then fail(scenario, "the box does not show: " .. text) end
		end
		-- Exactly what beta.9 put in a dwarf's box on the Alliance.
		local speech = ns.db.profile.speech
		speech.phrases = table.concat({
			"Thank ye kindly, {name}! First round's on me when we're back at the forge.",
			"Aye, {name}, ye only had to ask. Hold still now!",
			"Here, {name}, a wee somethin' to keep ye on yer feet.",
			"For the Alliance, {name}! Stay strong out there.",
			"Everyone ready? You are now, {name}.",
		}, "\n")
		if not RP.Active(speech) then fail(scenario, "a dwarf's beta.9 box counts as edited") end
		ns.ClampSettings()
		if speech.phrases ~= RP.Text() then
			fail(scenario, "the beta.9 box was not turned into today's: |" .. tostring(speech.phrases) .. "|")
		end
		-- Every people and side, as beta.9 composed them, however the pools
		-- have been rewritten since: the pools' first lines are moved out of
		-- the way here to prove it.
		local moved = {}
		for family, people in pairs(RP.RACE) do
			moved[family] = people.thanks
			people.thanks = { "Something new, {name}." }
		end
		local L = RP.LEGACY
		local families = {}
		for family in pairs(L.race) do families[#families + 1] = family end
		families[#families + 1] = false
		for _, faction in ipairs({ "Alliance", "Horde", "Neutral" }) do
			local side = L.side[faction]
			for _, family in ipairs(families) do
				local race = family and L.race[family]
				local text
				if race then
					text = table.concat({ race[1], race[2], race[3], side[3], L.general.group }, "\n")
				else
					text = table.concat({ side[1], side[2], side[3], L.general.thanks, L.general.offer }, "\n")
				end
				speech.phrases = text
				if not RP.Active(speech) then
					fail(scenario, ("the beta.9 box of a %s of the %s counts as edited"):format(tostring(family), faction))
				end
			end
		end
		for family, pool in pairs(moved) do RP.RACE[family].thanks = pool end
		-- And today's box for every class counts on every character.
		for class in pairs(RP.CLASS) do
			speech.phrases = RP.Examples("troll", "Horde", class)
			if not RP.Active(speech) then fail(scenario, "a troll " .. class .. "'s box counts as edited") end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-27
-- Every people, class, spell, place, hour and class helped that the set can
-- meet has lines of its own -- enough of them for a full share of the draw
-- (RP.SPREAD) -- and nothing is filed under a name the engine never asks for,
-- where a misspelt key would make a pool nobody hears.
do
	local scenario = "rp: every moment the set knows has lines"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local full = RP.SPREAD
		local function has(pool, where, least)
			local n = type(pool) == "table" and #pool or 0
			if n < least then fail(scenario, ("%s has %d lines, fewer than %d"):format(where, n, least)) end
		end
		local function known(tbl, allowed, what)
			for key in pairs(tbl) do
				if not allowed[key] then fail(scenario, what .. " lines filed under " .. tostring(key)) end
			end
		end
		local function set(list)
			local out = {}
			for _, key in ipairs(list) do out[key] = true end
			return out
		end

		-- Every people a race speaks as, the Haranir aside.
		local families = {}
		for _, family in pairs(RP.FAMILY) do families[family] = true end
		-- A people's own hour is optional, but full when it is there, and a
		-- people that has one keeps it: these are the hours written for, so a
		-- batch of new lines pasted over a pool that drops one is caught.
		local KINDS = set({ "thanks", "asked", "offer", "kin", "group", "night", "morning", "city", "outsider" })
		local HOURS = {
			dwarf = { "morning" }, nightelf = { "night", "morning" }, voidelf = { "night" },
			gnome = { "morning" }, worgen = { "night", "morning" }, forsaken = { "night", "morning" },
			tauren = { "morning", "night" }, troll = { "night" }, bloodelf = { "morning" },
			nightborne = { "night", "morning" }, goblin = { "morning" }, vulpera = { "night" },
			pandaren = { "morning", "night" },
		}
		for family in pairs(families) do
			if family ~= "haranir" then
				for _, kind in ipairs({ "thanks", "asked", "offer", "kin", "group" }) do
					has(RP.RACE[family] and RP.RACE[family][kind], family .. "." .. kind, full)
				end
				for _, hour in ipairs({ "night", "morning" }) do
					if RP.RACE[family][hour] then has(RP.RACE[family][hour], family .. "." .. hour, full) end
				end
				for _, hour in ipairs(HOURS[family] or {}) do
					has(RP.RACE[family][hour], family .. "." .. hour, full)
				end
				known(RP.RACE[family], KINDS, family .. "'s")
				-- A city of its own is heard only where RP.HOME finds it, and
				-- the lines for outsiders only for a moment that has lines.
				local people = RP.RACE[family]
				if people.city then
					has(people.city, family .. ".city", full)
					if type(RP.HOME[family]) ~= "table" or not next(RP.HOME[family]) then
						fail(scenario, family .. " has city lines and no city to say them in")
					end
				end
				if people.outsider then
					known(people.outsider, set({ "thanks", "asked", "offer", "group" }), family .. "'s outsider")
					for kind, pool in pairs(people.outsider) do
						has(pool, family .. ".outsider." .. kind, 2)
					end
				end
			end
		end
		known(RP.RACE, families, "people's")
		for family in pairs(RP.HOME) do
			if not (RP.RACE[family] and RP.RACE[family].city) then
				fail(scenario, family .. " has a city in RP.HOME and no lines for it")
			end
		end
		for _, side in ipairs({ "Alliance", "Horde", "Neutral" }) do
			for _, kind in ipairs({ "thanks", "asked", "offer", "group" }) do
				has(RP.FACTION[side][kind], side .. "." .. kind, full)
			end
		end
		for _, kind in ipairs({ "thanks", "asked", "offer", "group" }) do
			has(RP.GENERAL[kind], "general." .. kind, full)
		end

		-- Every class with something to give on this client speaks as itself,
		-- and every spell it gives has lines about it.
		local CLASSES = set({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
			"MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER" })
		local givers, keys = { MAGE = true, PRIEST = true, DRUID = true, PALADIN = true, WARLOCK = true,
			WARRIOR = true }, {}
		for class, buffs in pairs(ns.BUFFS or {}) do
			if #buffs > 0 then givers[class] = true end
			for _, buff in ipairs(buffs) do keys[buff.key] = true end
		end
		for class in pairs(givers) do
			for _, kind in ipairs({ "thanks", "asked", "offer", "group" }) do
				has(RP.CLASS[class] and RP.CLASS[class][kind], class .. "." .. kind, full)
			end
		end
		known(RP.CLASS, CLASSES, "class")
		if not next(keys) then fail(scenario, "SKIPPED -- no buffs on this client to check the spells against") end
		for key in pairs(keys) do has(RP.SPELL[key], "spell " .. key, full) end
		-- And Classic Era's Blessing of Sanctuary, which Forever deleted.
		keys.sanctuary = keys.sanctuary or "elsewhere"
		known(RP.SPELL, keys, "spell")
		-- What a gift does: every spell somebody can give you, and every
		-- favour Manners never offers (Buffs.lua, favourOnly), found by its id.
		local gifts = {}
		for key in pairs(keys) do
			has(RP.GIFT[key], "gift " .. key, 2)
			gifts[key] = true
		end
		local owed = ns.owed
		if not (ns.FAVOUR_ONLY_IDS and ns.FAVOUR_ONLY_IDS[1]) then
			fail(scenario, "SKIPPED -- no favour-only gifts on this client to check")
		end
		for _, id in ipairs(ns.FAVOUR_ONLY_IDS or {}) do
			ns.owed = { Bram = { spell = id } }
			local key = RP.GiftKey({ name = "Bram" })
			if key == nil then
				fail(scenario, "the favour of spell " .. id .. " has no gift lines")
			else
				has(RP.GIFT[key], "gift " .. key, 2)
				gifts[key] = true
			end
		end
		ns.owed = owed
		known(RP.GIFT, gifts, "gift")

		-- The moments.
		has(RP.TRADE, "trade", full)
		known(RP.HISTORY, set({ "again", "regular" }), "history")
		has(RP.HISTORY.again, "history.again", full)
		has(RP.HISTORY.regular, "history.regular", full)
		known(RP.PLACE, set({ "city", "wild", "instance", "battle" }), "place")
		for _, place in ipairs({ "city", "wild", "instance", "battle" }) do
			has(RP.PLACE[place], "place." .. place, full)
		end
		known(RP.TIME, set({ "morning", "night" }), "hour")
		for _, hour in ipairs({ "morning", "night" }) do has(RP.TIME[hour], "time." .. hour, full) end

		-- Whoever is helped, whatever their class.
		has(RP.TARGET.sameclass, "target.sameclass", full)
		for class in pairs(CLASSES) do has(RP.TARGET[class], "target." .. class, full) end
		local targets = set({ "sameclass" })
		for class in pairs(CLASSES) do targets[class] = true end
		known(RP.TARGET, targets, "target")
		-- And two of the same class, for every class with something to give.
		for class in pairs(givers) do has(RP.SAME[class], "same." .. class, full) end
		known(RP.SAME, CLASSES, "same class")
		-- A spell on a class it does little for: a spell somebody gives, and
		-- a class the client has.
		known(RP.ONTO, keys, "spell on a class")
		for key, classes in pairs(RP.ONTO) do
			known(classes, CLASSES, "spell " .. key .. " on a class")
			for class, pool in pairs(classes) do has(pool, key .. " on " .. class, 2) end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-28
-- No line twice in a row: one said in the last RP.RECENT has no share
-- while any other line still fits, so a party of five helped in turn hears
-- five different lines. Each pick here is said, as a press that carries it
-- remembers it (Prompt/Press.lua); a pick alone is not. When every line that fits has been said lately --
-- here, a few of the lines about meeting again, fewer than the memory holds,
-- leaned on as Roll a few does --
-- the set still speaks rather than falling silent.
--
-- The rolls here come from a fixed pseudo-random sequence, not the counter:
-- the golden-ratio counter never lands near its last few rolls, so it would
-- not repeat a line even with no memory at all.
do
	local scenario = "rp: no line twice in a row"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local RP = ns.InCharacter
		local keep = RP.RECENT
		if type(keep) ~= "number" or keep < 5 then
			fail(scenario, "remembers " .. tostring(keep) .. " lines, fewer than a party of five")
			return
		end
		world("wild", 14)
		local seed = 12345
		math.random = function(n)
			seed = (seed * 16807) % 2147483647
			if not n then return seed / 2147483647 end
			return seed % n + 1
		end
		for _, reason in ipairs({ "group", "nearby", "owed" }) do
			local entry = person(ns, reason)
			local said = {}
			for i = 1, 60 do
				local source
				said[i], source = ns.PickPhrase(entry, 250)
				RP.Remember(source)
				if not said[i] then
					fail(scenario, "fell silent on pick " .. i .. " for " .. reason)
					break
				end
				for back = math.max(1, i - keep), i - 1 do
					if said[back] == said[i] then
						fail(scenario, ("for %s, pick %d repeats pick %d: %s"):format(reason, i, back, said[i]))
						break
					end
				end
			end
		end
		-- Every line that fits said lately: one of them again, not nothing.
		local entry = person(ns, "nearby")
		entry.lean, entry.met = "history", 2
		local saved, few = RP.HISTORY.again, {}
		for i = 1, math.min(#saved, keep - 2) do few[i] = saved[i] end
		RP.HISTORY.again = few
		local again = {}
		render(ns, entry, few, again, true)
		for i = 1, keep + 5 do
			local line, source = ns.PickPhrase(entry, 250)
			RP.Remember(source)
			local said = line and line:match("^/say (.+)$")
			if not (said and again[said]) then
				fail(scenario, "pick " .. i .. " leaning on " .. #few .. " lines said " .. tostring(line))
				break
			end
		end
		RP.HISTORY.again = saved
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-29
-- A people's own hour: a night elf at midnight has the night elves' night
-- lines as well as everybody's, never their morning ones, and neither at
-- midday; a dwarf, whose hour is the morning, has none at night.
do
	local scenario = "rp: a people's own hour"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "NightElf")
		if not ns then return end
		local RP = ns.InCharacter
		local entry = person(ns, "nearby")
		local lines = {}
		for family, people in pairs(RP.RACE) do
			render(ns, entry, people.night, lines, family .. ".night")
			render(ns, entry, people.morning, lines, family .. ".morning")
		end
		local function heard(race, hour)
			Mock.playerRace = race
			world("wild", hour)
			counting()
			local got = {}
			for _ = 1, 200 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				local key = said and lines[said]
				if key then got[key] = true end
			end
			return got
		end
		local cases = {
			{ "NightElf", 0, "nightelf.night" }, { "NightElf", 7, "nightelf.morning" },
			{ "NightElf", 14, nil }, { "Dwarf", 23, nil }, { "Dwarf", 6, "dwarf.morning" },
		}
		for _, case in ipairs(cases) do
			local got = heard(case[1], case[2])
			for key in pairs(got) do
				if key ~= case[3] then
					fail(scenario, ("a %s at %d o'clock said a %s line"):format(case[1], case[2], key))
				end
			end
			if case[3] and not got[case[3]] then
				fail(scenario, ("a %s at %d o'clock never said a %s line"):format(case[1], case[2], case[3]))
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-30
-- On a client in another language a line with no translation yet is left out,
-- not said in English: never picked, never the box's example, never rolled by
-- Try a few; a pool with none translated joins no draw (the dwarves' group
-- lines here, so a group hears their offers, as for a people never given
-- any). On an English client every line stays, and so it does on a client
-- whose language has no translations at all, where thinning would leave the
-- set nothing to say.
--
-- The "translation" is Phrases.lua run again into the same session over an
-- ns.L filled the way Locales/<code>.lua fills it -- a value set on the table
-- for each key -- for every line but the ones left out, each prefixed so a
-- line said in English shows. The line left out is the first of the dwarves'
-- thanks, which the box shows.
do
	local scenario = "rp: an untranslated line is not said on another language's client"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Dwarf")
		if not ns then return end
		local english = ns.InCharacter
		local victim = english.RACE.dwarf.thanks[1]
		local silent = {}
		for _, text in ipairs(english.RACE.dwarf.group) do silent[text] = true end
		-- And one line of a pool the draw reaches another way -- a spell on a
		-- class it does little for -- so every kind of pool is thinned, not
		-- only the ones the shipped translations happen to leave gaps in.
		local onto = english.ONTO and english.ONTO.intellect and english.ONTO.intellect.WARRIOR
		local ontoVictim = onto and onto[1]
		if ontoVictim then silent[ontoVictim] = true end
		local lines = everyLine(english)
		local realL, realLocale = ns.L, ns.LOCALE
		local function reload(locale, translations)
			for i = #ns.PHRASE_SET_ORDER, 1, -1 do
				if ns.PHRASE_SET_ORDER[i] == "incharacter" then table.remove(ns.PHRASE_SET_ORDER, i) end
			end
			local L = setmetatable({}, { __index = function(_, key) return key end })
			if translations then
				for _, text in ipairs(lines) do
					if text ~= victim and not silent[text] then rawset(L, text, "[de] " .. text) end
				end
			end
			ns.L, ns.LOCALE = L, locale
			local chunk, err = loadfile(dir .. "/Phrases.lua")
			local ok, runErr = false, err
			if chunk then ok, runErr = pcall(chunk, "Manners", ns) end
			ns.L, ns.LOCALE = realL, realLocale
			if not ok then
				fail(scenario, "Phrases.lua would not load as " .. locale .. ": " .. tostring(runErr))
				return nil
			end
			-- The box as a player on this client has it: its own examples. The
			-- English box filled above has the line left out as its first, and
			-- would read as lines of the player's own.
			ns.db.profile.speech.phrases = ns.InCharacter.Text()
			return ns.InCharacter
		end
		-- Every line said, by the set and by Try a few, for each reason and
		-- the moments Try a few leans on.
		local function said(RP, n)
			local out = {}
			counting()
			for _, reason in ipairs({ "owed", "asked", "group", "nearby" }) do
				local entry = person(ns, reason)
				for _ = 1, n do
					local line = ns.PickPhrase(entry, 250)
					out[#out + 1] = line and line:match("^/say (.+)$") or "(nothing for " .. reason .. ")"
				end
			end
			for _ = 1, 10 do
				Mock.printed = {}
				RP.Roll("Bram")
				for _, printed in ipairs(Mock.printed) do
					local line = tostring(printed):match("|r /say (.+)$")
					out[#out + 1] = line or tostring(printed)
				end
			end
			return out
		end

		local RP = reload("deDE", true)
		if not RP then return end
		for _, text in ipairs(RP.RACE.dwarf.thanks or {}) do
			if text == victim then fail(scenario, "an untranslated line stayed in its pool on deDE") end
		end
		if RP.RACE.dwarf.group ~= nil then
			fail(scenario, "a pool with nothing translated still joins the draw on deDE")
		end
		if not ontoVictim then
			fail(scenario, "SKIPPED -- no Intellect-on-a-warrior lines to leave untranslated")
		else
			local left = RP.ONTO and RP.ONTO.intellect and RP.ONTO.intellect.WARRIOR
			for _, text in ipairs(left or {}) do
				if text == ontoVictim then
					fail(scenario, "an untranslated line for a spell on a class stayed in its pool on deDE")
				end
			end
		end
		for line in RP.Text():gmatch("[^\n]+") do
			if line:sub(1, 5) ~= "[de] " then fail(scenario, "the box shows an untranslated example on deDE: " .. line) end
		end
		for _, line in ipairs(said(RP, 120)) do
			if line:sub(1, 5) ~= "[de] " then
				fail(scenario, "said in English on deDE: " .. line)
				break
			end
		end

		-- English, and a language nobody has translated: every line stays.
		for _, case in ipairs({ { "enUS", true }, { "ruRU", false } }) do
			RP = reload(case[1], case[2])
			if not RP then return end
			if RP.RACE.dwarf.thanks[1] ~= victim then
				fail(scenario, "the first thanks line was taken away on " .. case[1])
			end
			if not RP.RACE.dwarf.group then fail(scenario, "the dwarves' group lines are gone on " .. case[1]) end
			if not RP.Text():find(victim, 1, true) then
				fail(scenario, "the box does not show the first thanks line on " .. case[1])
			end
			local heard = false
			for _, line in ipairs(said(RP, 120)) do heard = heard or line == victim:gsub("{name}", "Bram") end
			if not heard then fail(scenario, "the line was never said on " .. case[1]) end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-31
-- The shipped translations, in every language they are in: whatever the set
-- is left with there has a translation, and every pool that has lines in
-- English still has some -- no people, side, class or moment falls silent in
-- a language because its newest lines are not translated yet. The pools that
-- only add to another may wait for their translations, since the moment still
-- has its own there: a people's city (anybody's city lines), its own hours
-- (everybody's lines for the hour, heard beside them: the trolls' night was
-- rewritten whole in a review of the lines), its lines for outsiders (its
-- lines for the moment), a spell on a class it does little for (the lines for
-- that class).
do
	local function localeCodes()
		local f = io.open(dir .. "/Locales/Locales.xml", "r")
		if not f then return {} end
		local body = f:read("*a")
		f:close()
		local codes = {}
		for code in body:gmatch("<Script%s+file%s*=%s*\"(%a%a%a%a)%.lua\"") do
			if code ~= "Init" then codes[#codes + 1] = code end
		end
		return codes
	end
	local scenario = "rp: every language keeps a line for every moment"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local english = allPools(ns.InCharacter)
		local keys = {}
		for _, text in ipairs(everyLine(ns.InCharacter)) do keys[text] = true end
		for _, code in ipairs(localeCodes()) do
			Mock.reset()
			Mock.locale = code
			local there = load(scenario)
			if not there then break end
			local pools = allPools(there.InCharacter)
			for where, pool in pairs(english) do
				local adds = where:find("^RACE%.[^.]+%.city$") or where:find("^RACE%.[^.]+%.outsider%.")
					or where:find("^RACE%.[^.]+%.night$") or where:find("^RACE%.[^.]+%.morning$")
					or where:find("^ONTO%.")
				if not adds and type(pool) == "table" and #pool > 0 then
					local left = pools[where]
					if type(left) ~= "table" or #left == 0 then
						fail(scenario, where .. " has nothing left to say in " .. code)
					end
				end
			end
			for where, pool in pairs(pools) do
				for _, text in ipairs(type(pool) == "table" and pool or {}) do
					if keys[text] and rawget(there.L, text) == nil then
						fail(scenario, where .. " says English in " .. code .. ": " .. text)
						break
					end
				end
			end
			noErrors(scenario, there)
		end
		Mock.locale = nil
		noErrors(scenario, ns)
	end)
end

-- A client map naming the player's; nil for none at all.
local function onMap(id)
	if id == nil then
		rawset(_G, "C_Map", nil)
		return
	end
	rawset(_G, "C_Map", { GetBestMapForUnit = function(unit)
		if unit ~= "player" then return nil end
		return id
	end })
end

-- ------------------------------------------------------------------ rp-32
-- A people's own city: a Forsaken resting in Undercity hears Undercity's lines
-- in place of anybody's for a city, which were written for warm beds and
-- mailbox queues. Anywhere else (Orgrimmar, an inn, outside the walls), for
-- anybody else in Undercity, and whenever the map is unknown or a secret,
-- the city is anybody's.
do
	local scenario = "rp: a people's own city"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "Scourge")
		if not ns then return end
		local RP = ns.InCharacter
		local lines = {}
		for _, reason in ipairs({ "nearby", "owed" }) do
			local entry = person(ns, reason)
			render(ns, entry, RP.PLACE.city, lines, "anybody's")
			render(ns, entry, RP.RACE.forsaken.city, lines, "Undercity's")
		end
		local cases = {
			{ "a Forsaken in Undercity", "Scourge", 1458, "city", "Undercity's" },
			{ "a Forsaken in Orgrimmar", "Scourge", 1454, "city", "anybody's" },
			{ "a Forsaken on no map", "Scourge", nil, "city", "anybody's" },
			{ "a Forsaken on a secret map", "Scourge", Mock.SECRET, "city", "anybody's" },
			{ "a troll in Undercity", "Troll", 1458, "city", "anybody's" },
			{ "a Forsaken in Undercity, not resting", "Scourge", 1458, "wild", nil },
		}
		for _, case in ipairs(cases) do
			Mock.playerRace = case[2]
			world(case[4], 14)
			onMap(case[3])
			for _, reason in ipairs({ "nearby", "owed" }) do
				local entry = person(ns, reason)
				counting()
				local heard = {}
				for _ = 1, 200 do
					local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
					local key = said and lines[said]
					if key then heard[key] = true end
				end
				for key in pairs(heard) do
					if key ~= case[5] then
						fail(scenario, ("%s (%s) heard %s lines for a city"):format(case[1], reason, key))
					end
				end
				if case[5] and not heard[case[5]] then
					fail(scenario, ("%s (%s) never heard %s lines"):format(case[1], reason, case[5]))
				end
			end
		end
		-- A map lookup that throws is no map.
		Mock.playerRace = "Scourge"
		rawset(_G, "C_Map", { GetBestMapForUnit = function() error("no") end })
		local ok, home = pcall(RP.Home, "forsaken")
		if not ok or home then fail(scenario, "a map lookup that throws read as " .. tostring(home)) end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-33
-- A people's lines about how others take to it are for others: a Forsaken
-- hears them for an orc, never for another Forsaken, and never in Undercity,
-- where nearly everybody is one -- whether the one helped reads as kin or not.
do
	local scenario = "rp: lines for outsiders are not said to kin"
	with(scenario, "Horde", { nameplate1 = "Scourge", nameplate2 = "Orc" }, function()
		local ns = ready(scenario, "Scourge")
		if not ns then return end
		local RP = ns.InCharacter
		Mock.unitNames = { nameplate1 = { "Bram" }, nameplate2 = { "Bram" } }
		local outsider = RP.RACE.forsaken.outsider or {}
		local tried = 0
		for _, case in ipairs({ { "owed", "thanks" }, { "asked", "asked" }, { "nearby", "offer" } }) do
			local reason, kind = case[1], case[2]
			if outsider[kind] then
				tried = tried + 1
				local lines = {}
				render(ns, person(ns, reason), outsider[kind], lines, true)
				local function heard(unit, map)
					world(map and "city" or "wild", 14)
					onMap(map)
					local entry = person(ns, reason, unit)
					entry.name = ns.UnitFullName(unit)
					counting()
					local hits, which = 0, {}
					for _ = 1, 400 do
						local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
						if said and lines[said] then
							hits = hits + 1
							which[said] = true
						end
					end
					return hits, which
				end
				local hits, which = heard("nameplate2")
				if hits == 0 then fail(scenario, "an orc never heard a Forsaken's " .. kind .. " for outsiders") end
				for line in pairs(lines) do
					if not which[line] then fail(scenario, "never said to an orc: " .. line) end
				end
				if heard("nameplate1") > 0 then
					fail(scenario, "a Forsaken heard the " .. kind .. " for outsiders from another")
				end
				if heard("nameplate2", 1458) > 0 then
					fail(scenario, "the " .. kind .. " for outsiders was said in Undercity")
				end
				if heard("nameplate2", 1454) == 0 then
					fail(scenario, "the " .. kind .. " for outsiders was never said in another city")
				end
			end
		end
		if tried < 3 then fail(scenario, "SKIPPED -- the Forsaken have outsider lines for only " .. tried .. " moments") end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-34
-- A spell on a class it does little for: Arcane Intellect on a warrior or a
-- rogue, who have no mana, has lines of its own, heard with the lines for
-- that class; on a priest it has none, and neither has Fortitude on a warrior.
do
	local scenario = "rp: a spell on a class it does little for"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local RP = ns.InCharacter
		local intellect = ns.FindBuff("MAGE", "intellect")
		local fortitude = ns.FindBuff("PRIEST", "fortitude")
		if not (intellect and fortitude) then
			fail(scenario, "SKIPPED -- no Arcane Intellect or Fortitude on this client")
			return
		end
		local lines = {}
		local stand = { short = "Bram", buff = intellect }
		for key, classes in pairs(RP.ONTO) do
			for class, pool in pairs(classes) do render(ns, stand, pool, lines, key .. " on " .. class) end
		end
		render(ns, stand, RP.TARGET.WARRIOR, lines, "for a warrior")
		local cases = {
			{ "Arcane Intellect on a warrior", intellect, "WARRIOR", "intellect on WARRIOR", true },
			{ "Arcane Intellect on a rogue", intellect, "ROGUE", "intellect on ROGUE" },
			{ "Arcane Intellect on a priest", intellect, "PRIEST", nil },
			{ "Fortitude on a warrior", fortitude, "WARRIOR", nil, true },
			{ "Arcane Intellect on somebody unknown", intellect, nil, nil },
		}
		for _, case in ipairs(cases) do
			local entry = person(ns, "nearby")
			entry.buff, entry.class = case[2], case[3]
			counting()
			local heard = {}
			for _ = 1, 300 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				local key = said and lines[said]
				if key then heard[key] = true end
			end
			for key in pairs(heard) do
				if key ~= case[4] and key ~= "for a warrior" then
					fail(scenario, case[1] .. " said a line for " .. key)
				end
			end
			if case[4] and not heard[case[4]] then fail(scenario, case[1] .. " never said a line for it") end
			if case[5] and not heard["for a warrior"] then
				fail(scenario, case[1] .. " lost the lines for a warrior")
			end
		end
		noErrors(scenario, ns)
	end)
end
