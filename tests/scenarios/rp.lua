-- The "In character" phrase set (Phrases.lua): a line picked at the click for
-- the player's people, their faction and the reason for the buff.
--
-- Called by scenarios.lua with the addon directory and its helpers. The mock
-- knows the player's race (Mock.playerRace) and nothing about factions or other
-- people's races, so UnitFactionGroup and UnitRace are set here for the length
-- of one scenario and put back after it, rather than added to mockapi.lua.
--
-- math.random is swapped for a counter where the scenario counts lines: with a
-- real roll a line that should come up could miss by luck, and a weighting
-- could pass by luck. Counting up through every residue in turn visits every
-- candidate in proportion to its weight.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption, pressButton = H.findOption, H.pressButton

local TOUCHED = { "UnitRace", "UnitFactionGroup" }
local original = {}
for _, name in ipairs(TOUCHED) do original[name] = rawget(_G, name) end
local realRandom = math.random

-- Runs one scenario with the player's faction and other people's races in
-- place, and puts them back, and math.random too, whether it finished or threw.
-- `races` maps a unit token to a race file name or Mock.SECRET.
local function with(scenario, faction, races, body)
	local playerRace = original.UnitRace
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
	local ok, err = pcall(body)
	for _, name in ipairs(TOUCHED) do rawset(_G, name, original[name]) end
	math.random = realRandom
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function counting()
	local rolls = 0
	math.random = function(n)
		rolls = rolls + 1
		if not n then return 0.5 end
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
local function render(ns, entry, pool, into, tag)
	if type(pool) == "string" then pool = { pool } end
	for _, text in ipairs(pool or {}) do
		local said = ns.Swap(ns.Swap(text, "{name}", entry.short), "{buff}", ns.BuffName(entry.buff))
		into[said] = tag
	end
end

-- n lines picked for this person, counted by the tag of the pool each came
-- from; a line from no pool expected is counted under "stray" and kept.
local function tally(ns, entry, expected, n)
	local counts, strays = {}, {}
	for _ = 1, n do
		local line = ns.PickPhrase(entry, 250)
		local said = line and line:match("^/say (.+)$")
		local tag = said and expected[said] or "stray"
		if tag == "stray" then strays[#strays + 1] = tostring(line) end
		counts[tag] = (counts[tag] or 0) + 1
	end
	return counts, strays
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
	end
	take(RP.KIN)
	for _, side in pairs(RP.FACTION) do
		take(side.thanks) take(side.asked) take(side.offer) take(side.group)
	end
	for _, pool in pairs(RP.GENERAL) do take(pool) end
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
			-- Every people but the Haranir has a line for every moment.
			local lines = RP.RACE[family]
			if family ~= "haranir" then
				if not (lines and lines.thanks and lines.asked and lines.offer and lines.kin) then
					fail(scenario, family .. " is missing a kind of line")
				end
			elseif lines then
				fail(scenario, "the Haranir were given lines of their own to guess at")
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-2
-- A dwarf of the Alliance thanking somebody: dwarvish thanks most, the
-- Alliance's next, the general ones least, and nothing from anybody else.
-- Somebody from another realm is called by their short name, as every other
-- set calls them, never "Bram-Realm".
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
		counting()
		local counts, strays = tally(ns, entry, expected, 390)
		for _, line in ipairs(strays) do
			if line:find("-Realm", 1, true) then
				fail(scenario, "called somebody by their realm-qualified name: " .. line)
				break
			end
		end
		if strays[1] then
			fail(scenario, "said a line that is not a dwarf's, the Alliance's or anybody's thanks: "
				.. strays[1])
		end
		for _, tag in ipairs({ "race", "faction", "general" }) do
			if not counts[tag] then fail(scenario, "never said a " .. tag .. " line") end
		end
		if (counts.race or 0) <= (counts.faction or 0) or (counts.race or 0) <= (counts.general or 0) then
			fail(scenario, ("the dwarf's own lines are not the most heard: %d race, %d faction, %d general")
				:format(counts.race or 0, counts.faction or 0, counts.general or 0))
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
		counting()
		local counts, strays = tally(ns, entry, expected, 300)
		if strays[1] then fail(scenario, "an orc of the Horde said: " .. strays[1]) end
		if not (counts.race and counts.faction and counts.general) then
			fail(scenario, "some of the orc's, the Horde's or the general offers never came up")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-4
-- Each reason has its own lines: an answer is not a thank-you, and a group
-- member hears the friendlier group lines as well as the offers.
do
	local scenario = "rp: reasons pick their own lines"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "HighmountainTauren")
		if not ns then return end
		local RP = ns.InCharacter
		local cases = {
			{ reason = "asked", pools = { RP.RACE.tauren.asked, RP.FACTION.Horde.asked, RP.GENERAL.asked } },
			{ reason = "target", pools = { RP.RACE.tauren.offer, RP.FACTION.Horde.offer, RP.GENERAL.offer } },
			{ reason = "group", pools = { RP.RACE.tauren.offer, RP.FACTION.Horde.group,
				RP.FACTION.Horde.offer, RP.GENERAL.group } },
			{ reason = "owed", pools = { RP.RACE.tauren.thanks, RP.FACTION.Horde.thanks, RP.GENERAL.thanks } },
		}
		counting()
		for _, case in ipairs(cases) do
			local entry = person(ns, case.reason)
			local expected = {}
			for i, pool in ipairs(case.pools) do render(ns, entry, pool, expected, "pool" .. i) end
			local counts, strays = tally(ns, entry, expected, 300)
			if strays[1] then
				fail(scenario, "for reason " .. case.reason .. " it said: " .. strays[1])
			end
			for i = 1, #case.pools do
				if not counts["pool" .. i] then
					fail(scenario, "for reason " .. case.reason .. ", pool " .. i .. " never came up")
				end
			end
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
		counting()
		local counts, strays = tally(ns, entry, expected, 100)
		if strays[1] then fail(scenario, "said: " .. strays[1]) end
		if not (counts.faction and counts.general) then
			fail(scenario, "fell silent, or lost the faction's or the general lines")
		end
		if ns.PhraseSetText("incharacter") ~= RP.Examples(nil, "Alliance") then
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
			render(ns, entry, RP.FACTION.Neutral.offer, expected, "faction")
			render(ns, entry, RP.GENERAL[kind], expected, "general")
			counting()
			local counts, strays = tally(ns, entry, expected, 200)
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
-- somebody of another people.
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
			local hits = 0
			for _ = 1, 100 do
				local said = (ns.PickPhrase(entry, 250) or ""):match("^/say (.+)$")
				if said and kin[said] then hits = hits + 1 end
			end
			return hits
		end
		if heard("nameplate1") == 0 then
			fail(scenario, "a Dark Iron dwarf was never greeted as a dwarf's kin")
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
		render(ns, ana, ns.InCharacter.RACE.troll.thanks, expected, true)
		render(ns, ana, ns.InCharacter.FACTION.Horde.thanks, expected, true)
		render(ns, ana, ns.InCharacter.GENERAL.thanks, expected, true)
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
-- A long name, the longest spell, and a /target line with the target handed
-- back: every line of every people still fits the macro, and a pick is never
-- over the room it is given, however little.
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
		local budget = ns.PhraseBudget(long)
		local spell = ns.BuffName(long.buff)
		for _, text in ipairs(everyLine(RP)) do
			local said = ns.Swap(ns.Swap(text, "{name}", long.short), "{buff}", spell)
			if #("/emote " .. said) > budget then
				fail(scenario, ("%d characters left, and |%s| needs %d"):format(budget, said, #said + 7))
			end
		end
		-- One race of every people, and one with none, on every side.
		local RACES = { "Dwarf", "Human", "NightElf", "VoidElf", "Gnome", "Draenei", "Worgen",
			"Orc", "Scourge", "Tauren", "Troll", "BloodElf", "Nightborne", "Goblin", "Vulpera",
			"Pandaren", "Dracthyr", "Haranir", "Murloc" }
		for _, faction in ipairs({ "Alliance", "Horde", "Neutral" }) do
			rawset(_G, "UnitFactionGroup", function() return faction, faction end)
			for _, race in ipairs(RACES) do
				Mock.playerRace = race
				for _, reason in ipairs({ "owed", "asked", "group", "nearby", "target" }) do
					long.reason = reason
					if not ns.PickPhrase(long, budget) then
						fail(scenario, ("a %s of the %s has nothing to say for %s with a long name")
							:format(race, faction, reason))
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
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rp-11
-- What players will read: short, safe in a macro, not doubled up, and enough
-- of them that a people does not repeat itself.
do
	local scenario = "rp: the lines are short and safe in a macro"
	with(scenario, "Alliance", nil, function()
		local ns = ready(scenario, "Human")
		if not ns then return end
		local lines = everyLine(ns.InCharacter)
		if #lines < 120 or #lines > 170 then
			fail(scenario, #lines .. " lines in all, not the hundred and twenty to a hundred and seventy written")
		end
		local seen = {}
		for _, text in ipairs(lines) do
			-- A twelve-letter name and a long spell.
			local said = text:gsub("{name}", "Bartholomewz"):gsub("{buff}", "Power Word: Fortitude")
			if #said > 90 then fail(scenario, #said .. " characters: " .. said) end
			if text:find("[|%[%]\r\n]") or text:find("^%s*/") or text:match("^%s*$") then
				fail(scenario, "not safe in a macro: " .. text)
			end
			if text:find("{", 1, true) and not text:gsub("{name}", ""):gsub("{buff}", ""):find("^[^{}]*$") then
				fail(scenario, "a token the set does not swap: " .. text)
			end
			if seen[text] then fail(scenario, "written twice: " .. text) end
			seen[text] = true
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
-- character sharing the profile. Editing the box makes the lines your own, and
-- emptying it goes back to the set.
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
		if speech.phrases ~= RP.Examples("nightelf", "Alliance") then
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

		-- An orc of the Horde on the same profile, last saved by a dracthyr
		-- (whose box nothing here has read yet).
		Mock.playerRace = "Orc"
		rawset(_G, "UnitFactionGroup", function() return "Horde", "Horde" end)
		speech.phrases = RP.Examples("dracthyr", "Neutral")
		if not RP.Active(speech) then
			fail(scenario, "a dracthyr's untouched set counted as edited on an orc sharing the profile")
		end
		if phrases.get({ "phrases" }) ~= RP.Examples("orc", "Horde") then
			fail(scenario, "the orc's box shows |" .. tostring(phrases.get({ "phrases" })) .. "|")
		end
		if preset.get({ "preset" }) ~= "incharacter" then
			fail(scenario, "the orc's dropdown reads " .. tostring(preset.get({ "preset" })))
		end
		counting()
		local said = (ns.PickPhrase(person(ns, "owed"), 250) or ""):match("^/say (.+)$")
		local expected = {}
		local entry = person(ns, "owed")
		render(ns, entry, RP.RACE.orc.thanks, expected, true)
		render(ns, entry, RP.FACTION.Horde.thanks, expected, true)
		render(ns, entry, RP.GENERAL.thanks, expected, true)
		if not (said and expected[said]) then
			fail(scenario, "the orc sharing the profile said " .. tostring(said))
		end

		-- Edited: the player's own lines, and the dropdown lets go.
		phrases.set({ "phrases" }, RP.Examples("orc", "Horde") .. "\nMy own line, {name}.")
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
		if speech.phrases ~= RP.Examples("orc", "Horde") then
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
-- it says something different for each; only the favours when that is all
-- speech is on for.
do
	local scenario = "rp: roll a few rolls a line per reason"
	with(scenario, "Horde", nil, function()
		local ns = ready(scenario, "Goblin")
		if not ns then return end
		local roll = findOption(ns.optionsTable, "roll")
		if not (roll and roll.func) then
			fail(scenario, "SKIPPED -- Roll a few is not on the page")
			return
		end
		local function rolled()
			Mock.printed = {}
			roll.func()
			local out = {}
			for _, line in ipairs(Mock.printed) do
				local label = tostring(line):match("|cff888888(.-)|r /say ")
				if label then out[#out + 1] = label end
			end
			return out, #Mock.printed
		end
		local labels, printed = rolled()
		local want = { "Returning a favour:", "Answering a request:", "In your group:", "Offering unasked:" }
		if #labels ~= #want then
			fail(scenario, "rolled " .. #labels .. " labelled lines out of " .. printed .. " printed, not one per reason")
		else
			for i, label in ipairs(want) do
				if labels[i] ~= label then fail(scenario, "line " .. i .. " is labelled " .. labels[i]) end
			end
		end
		ns.db.profile.speech.onlyWhenReturning = true
		labels = rolled()
		if #labels ~= 3 then
			fail(scenario, "with only favours spoken, rolled " .. #labels .. " lines")
		end
		for _, label in ipairs(labels) do
			if label ~= want[1] then
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
		local RP = ns.InCharacter
		counting()
		for _, reason in ipairs({ "owed", "asked", "nearby" }) do
			local entry = person(ns, reason)
			entry.buff = nil
			local kind = reason == "owed" and "thanks" or reason == "asked" and "asked" or "offer"
			local holes = {}
			for _, text in ipairs(RP.GENERAL[kind]) do
				if text:find("{buff}", 1, true) then
					holes[ns.Swap(ns.Swap(text, "{name}", "Bram"), "{buff}", ""):gsub("%s+", " ")] = true
				end
			end
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
-- five examples are said as plain lines, thanks and all, to strangers -- and
-- the load-time repair turns the box into the translated examples, as core-12
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
		if english ~= ns.InCharacter.Examples("dwarf", "Alliance") then
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
