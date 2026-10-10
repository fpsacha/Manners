-- The phrase box's examples for "In character" (Phrases.lua's RP.Examples):
-- many of the logged-in character's own lines, and every box an earlier
-- version saved still the untouched set.
--
-- The set picks from some 2,400 lines at the click, and the box is all a
-- player sees of them. 1.5.0 showed eight, a line of each of a few pools, and
-- the owner read those eight as everything the set would say. The box is also
-- how the addon knows the set is still chosen and untouched, so a box saved by
-- an earlier version -- beta.9's five lines, the eight of beta.10 to 1.5.0 --
-- in English or in the client's language must still read as the set, and turn
-- into today's when the profile loads; a box the player edited must do
-- neither.
--
-- Called by scenarios.lua with the addon directory and its helpers. The mock
-- knows the player's race and class; the faction is set here for the length
-- of one scenario and put back after it, as tests/scenarios/rp.lua does.

local dir, H = ...
local fail, load, drive, findOption = H.fail, H.load, H.drive, H.findOption

local realFaction = rawget(_G, "UnitFactionGroup")

-- Runs one scenario on this side, and puts the faction back whether it
-- finished or threw.
local function with(scenario, faction, body)
	rawset(_G, "UnitFactionGroup", function(unit)
		if unit == "player" then return faction, faction end
		return nil
	end)
	local ok, err = pcall(body)
	rawset(_G, "UnitFactionGroup", realFaction)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A session for this race and class with "In character" loaded through the
-- dropdown, as a player would load it.
local function ready(scenario, race, class, locale)
	Mock.reset()
	Mock.playerRace = race
	Mock.class = class
	Mock.locale = locale
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local speech = ns.db.profile.speech
	speech.enabled, speech.onlyWhenReturning, speech.channel = true, false, "SAY"
	local preset = findOption(ns.optionsTable, "preset")
	if not (preset and preset.set and preset.get) then
		fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
		return nil
	end
	preset.set({ "preset" }, "incharacter")
	return ns, preset
end

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function split(text)
	local out = {}
	for line in tostring(text or ""):gmatch("[^\n]+") do out[#out + 1] = line end
	return out
end

-- Exactly what the box held when these versions saved it: 1.5.0's for a
-- Forsaken mage of the Horde and a dwarf priest of the Alliance (every
-- version from beta.10 saved the same), and beta.9's for a Forsaken; and
-- 1.6.4's and 1.5.0's for a troll mage of the Horde, whose examples have been
-- reworded since. Written out, not rebuilt from the pools, so a line
-- reworded since shows.
local SAVED = {
	troll164 = {
		"Ya be too kind, {name}! Dis one be from me.",
		"Thanks, mon! Da spirits smile on ya, {name}.",
		"Ya gave me good mojo, {name}. Now ya get some back, extra spicy.",
		"Bwonsamdi gonna be real disappointed, {name}. Thanks, mon.",
		"Sure ting, {name}. Hold still; da mojo don't like a movin' target.",
		"No worries, {name}. Da loa got ya covered.",
		"Stay away from da voodoo, {name}. ...Except dis voodoo. Dis one fine.",
		"Da loa be watchin' over ya, {name}. Dey real nosy like dat.",
		"Stay sharp out dere, {name}. Take dis wit' ya.",
		"Ya look like somebody who appreciate quality, {name}. Here: quality.",
		"Take dis, {name}. Walk like ya own da jungle. I do.",
		"For the Horde, {name}! Go with strength. I've just handed you some.",
		"Go with honour, {name}. Victory awaits.",
		"Stay close, {name}. Trolls regenerate; da rest of ya gotta be careful.",
		"Dis crew got style, {name}. Now it got mojo too.",
		"We go in together, {name}, we come out together. Dat be da whole plan, mon.",
		"Our strength is each other, {name}. For the Horde!",
		"Forward, {name}. The Horde advances together. Retreats... never, officially.",
		"Hey, {name}! Always good to see family, mon.",
		"Here, {name}. I had a spare thought and nowhere to put it.",
		"Take this, {name}. I'd add bread, but conjured bread tastes of nothing.",
		"We have to stop meeting like this, {name}. Actually, no, we don't.",
		"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
		"Night be da best time for mojo, {name}. Nobody see where it come from.",
	},
	troll150 = {
		"Ya be too kind, {name}! Dis one be from me.",
		"Sure ting, {name}. Hold still; da mojo don't like a movin' target.",
		"Da loa be watchin' over ya, {name}. Dey real nosy like dat.",
		"For the Horde, {name}! Go with strength. I've just handed you some.",
		"Everyone ready? You are now, {name}.",
		"Here, {name}. I had a spare thought and nowhere to put it.",
		"We have to stop meeting like this, {name}. Actually, no, we don't.",
		"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	},
	forsaken150 = {
		"Thank you, {name}. It would warm my heart, if it still beat.",
		"Certainly, {name}. Try not to die. It's overrated.",
		"Stay among the living a little longer, {name}.",
		"For the Horde, {name}! Go with strength. I've just handed you some.",
		"Everyone ready? You are now, {name}.",
		"Here, {name}. I had a spare thought and nowhere to put it.",
		"We have to stop meeting like this, {name}. Actually, no, we don't.",
		"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	},
	dwarf150 = {
		"Thank ye kindly, {name}! First round's on me when we're back at the forge.",
		"Aye, {name}, ye only had to ask. Hold still now, like a good anvil.",
		"Here, {name}, a wee somethin' to keep ye on yer feet. Wee, like me.",
		"For the Alliance, {name}! Stay strong out there. Stronger, now.",
		"Everyone ready? You are now, {name}.",
		"Bless you, {name}. No, you didn't sneeze; I'm simply thorough.",
		"We have to stop meeting like this, {name}. Actually, no, we don't.",
		"Somewhere in here a villain is rehearsing a speech, {name}. Let's interrupt.",
	},
	forsaken9 = {
		"Thank you, {name}. It would warm my heart, if it still beat.",
		"Certainly, {name}. Try not to die. It's overrated.",
		"Stay among the living a little longer, {name}.",
		"For the Horde, {name}! Go with strength.",
		"Everyone ready? You are now, {name}.",
	},
}

-- ------------------------------------------------------------------ rpx-1
-- The box shows many lines, and every one of them is the character's own: its
-- people's, its side's and its class's, or one of the moments the box names
-- (somebody met again, a dungeon, the people's own hours). Thanks first, no
-- line twice. A people with no lines of its own shows its side's and the
-- general ones in their place.
do
	local scenario = "rp examples: the box shows many of the character's own lines"
	local CASES = {
		{ race = "Scourge", family = "forsaken", faction = "Horde", class = "MAGE", hours = { "night", "morning" } },
		{ race = "Dwarf", family = "dwarf", faction = "Alliance", class = "PRIEST", hours = { "morning" } },
		{ race = "Harronir", family = "haranir", faction = "Horde", class = "MAGE", hours = {} },
		-- A people the addon does not know, as the Haranir were until 1.7.2.
		{ race = "Murloc", faction = "Alliance", class = "MAGE", hours = {} },
	}
	for _, case in ipairs(CASES) do
		with(scenario, case.faction, function()
			local ns = ready(scenario, case.race, case.class)
			if not ns then return end
			local RP = ns.InCharacter
			local who = tostring(case.family or case.race) .. " " .. case.class
			local phrases = findOption(ns.optionsTable, "phrases")
			if not (phrases and phrases.get) then
				fail(scenario, "SKIPPED -- the phrase box is not on the page")
				return
			end
			local box = phrases.get({ "phrases" })
			if box ~= RP.Examples(case.family, case.faction, case.class) then
				fail(scenario, "the box does not show this character's examples: " .. who)
			end
			local speech = ns.db.profile.speech
			if speech.phrases ~= box or not RP.Active(speech) then
				fail(scenario, "loading the set did not save the box it shows: " .. who)
			end
			local lines = split(box)
			if #lines < 20 then
				fail(scenario, ("the box shows only %d lines for a %s"):format(#lines, who))
			end

			-- Where a line may come from.
			local race, side, class = RP.RACE[case.family], RP.FACTION[case.faction], RP.CLASS[case.class]
			local from = {}
			local function allow(pool, tag)
				for _, text in ipairs(pool or {}) do from[text] = tag end
			end
			for kind, pool in pairs(race or {}) do
				if kind ~= "outsider" then allow(pool, "race." .. kind) end
			end
			for kind, pool in pairs(side) do allow(pool, "side." .. kind) end
			if not race then
				for kind, pool in pairs(RP.GENERAL) do allow(pool, "general." .. kind) end
			end
			for kind, pool in pairs(class) do allow(pool, "class." .. kind) end
			allow(RP.HISTORY.again, "again")
			allow(RP.PLACE.instance, "instance")

			local seen, shown = {}, {}
			for _, text in ipairs(lines) do
				local tag = from[text]
				if tag then
					shown[tag] = true
				else
					fail(scenario, "the box shows a line that is not the character's own: " .. who .. ": " .. text)
				end
				if seen[text] then fail(scenario, "the box shows a line twice: " .. text) end
				seen[text] = true
			end
			local opening = race and race.thanks[1] or side.thanks[1]
			if lines[1] ~= opening then
				fail(scenario, "the box does not open with a thank-you: " .. tostring(lines[1]))
			end
			-- Every kind of line the set says as this character, and the moments.
			local want = { "side.offer", "side.group", "class.offer", "again", "instance" }
			if race then
				for _, kind in ipairs({ "thanks", "asked", "offer", "group", "kin" }) do
					want[#want + 1] = "race." .. kind
				end
			else
				for _, kind in ipairs({ "side.thanks", "side.asked", "general.thanks", "general.offer", "general.group" }) do
					want[#want + 1] = kind
				end
			end
			for _, hour in ipairs(case.hours) do want[#want + 1] = "race." .. hour end
			for _, tag in ipairs(want) do
				if not shown[tag] then fail(scenario, "the box shows no " .. tag .. " line for a " .. who) end
			end
			noErrors(scenario, ns)
		end)
	end
end

-- ------------------------------------------------------------------ rpx-2
-- A box saved by 1.5.0 -- this character's, or a dwarf priest's on the same
-- profile -- and one saved by beta.9 are still In character, and the load
-- repair turns each into this character's box as it reads now; the dropdown
-- keeps the set and an export does not carry the box. And the 1.5.0 box of
-- every people, side and class, as 1.5.0 built it from the first line of each
-- pool, still counts: a profile is often shared.
do
	local scenario = "rp examples: a box saved by 1.5.0 still counts and becomes today's"
	with(scenario, "Horde", function()
		local ns, preset = ready(scenario, "Scourge", "MAGE")
		if not ns then return end
		local RP = ns.InCharacter
		local speech = ns.db.profile.speech
		local today = RP.Text()
		if #split(today) < 20 then
			fail(scenario, "SKIPPED -- today's box is not the long one")
			return
		end
		for _, saved in ipairs({
			{ "a Forsaken mage's 1.5.0 box", SAVED.forsaken150 },
			{ "a dwarf priest's 1.5.0 box", SAVED.dwarf150 },
			{ "a Forsaken's beta.9 box", SAVED.forsaken9 },
		}) do
			speech.phrases = table.concat(saved[2], "\n")
			if not RP.Active(speech) then fail(scenario, saved[1] .. " counts as edited") end
			if preset.get({ "preset" }) ~= "incharacter" then
				fail(scenario, "the dropdown lets go of " .. saved[1])
			end
			ns.ClampSettings()
			if speech.phrases ~= today then
				fail(scenario, saved[1] .. " was not turned into today's: |" .. tostring(speech.phrases) .. "|")
			end
			if not RP.Active(speech) then fail(scenario, saved[1] .. ", repaired, is not In character") end
			if ns.ExportSettings():find("speech.phrases=", 1, true) then
				fail(scenario, saved[1] .. ", repaired, is exported as though it were edited")
			end
		end

		-- Of the pools as they read then: a line reworded since (the trolls')
		-- put back as it was, which RP.BEFORE does. Without it, today's.
		local before = RP.BEFORE or RP
		local families = { false }
		for family in pairs(before.RACE) do families[#families + 1] = family end
		local classes = { false }
		for class in pairs(before.CLASS) do classes[#classes + 1] = class end
		local general = before.GENERAL
		for _, faction in ipairs({ "Alliance", "Horde", "Neutral" }) do
			local side = before.FACTION[faction]
			for _, family in ipairs(families) do
				local race = family and before.RACE[family]
				for _, class in ipairs(classes) do
					local lines
					if race then
						lines = { race.thanks[1], race.asked[1], race.offer[1], side.offer[1], general.group[1] }
					else
						lines = { side.thanks[1], side.asked[1], side.offer[1], general.thanks[1], general.offer[1] }
					end
					if class then lines[#lines + 1] = before.CLASS[class].offer[1] end
					lines[#lines + 1] = before.HISTORY.again[1]
					lines[#lines + 1] = before.PLACE.instance[1]
					speech.phrases = table.concat(lines, "\n")
					if not RP.Active(speech) then
						fail(scenario, ("the 1.5.0 box of a %s %s of the %s counts as edited")
							:format(tostring(family), tostring(class), faction))
					end
				end
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rpx-3
-- A box the player edited is theirs, whichever box they began from: never In
-- character, and never replaced when the profile loads.
do
	local scenario = "rp examples: an edited box is never the set and never replaced"
	with(scenario, "Horde", function()
		local ns = ready(scenario, "Scourge", "MAGE")
		if not ns then return end
		local RP = ns.InCharacter
		local speech = ns.db.profile.speech
		local today = split(RP.Text())
		local function edit(lines, change)
			local out = {}
			for i, text in ipairs(lines) do out[i] = text end
			change(out)
			return table.concat(out, "\n")
		end
		local mine = "My own line, {name}."
		local EDITS = {
			{ "today's box and a line of the player's", edit(today, function(t) t[#t + 1] = mine end) },
			{ "today's box less its second line", edit(today, function(t) table.remove(t, 2) end) },
			{ "today's box with two lines swapped", edit(today, function(t) t[1], t[2] = t[2], t[1] end) },
			{ "1.5.0's box and a line of the player's", edit(SAVED.forsaken150, function(t) t[#t + 1] = mine end) },
			{ "1.5.0's box with a line reworded", edit(SAVED.forsaken150, function(t)
				t[3] = "Stay among the living a little longer, {name}!"
			end) },
			{ "1.5.0's box less its last line", edit(SAVED.forsaken150, function(t) t[#t] = nil end) },
			{ "beta.9's box and a line of the player's", edit(SAVED.forsaken9, function(t) t[#t + 1] = mine end) },
		}
		for _, case in ipairs(EDITS) do
			speech.phrases = case[2]
			if RP.Active(speech) then fail(scenario, case[1] .. " counts as In character") end
			ns.ClampSettings()
			if speech.phrases ~= case[2] then
				fail(scenario, case[1] .. " was replaced at load: |" .. tostring(speech.phrases) .. "|")
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rpx-4
-- On a client in another language the box shows only lines with a
-- translation, the next translated line of a pool moving up into the place of
-- one without, and still many of them. 1.5.0's box saved in that language, or
-- in English before the lines were translated, still counts and becomes
-- today's box in that language; an edited one does neither. Two lines
-- translated alike are shown once, while 1.5.0's box, which never checked,
-- is recognised with both.
--
-- The "translation" is Phrases.lua run again into the same session over an
-- ns.L filled the way Locales/<code>.lua fills it, as in rp.lua's rp-30: a
-- value set on the table for every line but the ones left out, each prefixed
-- so a line shown in English stands out.
do
	local scenario = "rp examples: another language's box shows only translated lines"
	with(scenario, "Horde", function()
		local ns = ready(scenario, "Scourge", "MAGE")
		if not ns then return end
		local english = ns.InCharacter
		local forsaken, mage = english.RACE.forsaken, english.CLASS.MAGE
		if not (forsaken and forsaken.night and #forsaken.thanks >= 5 and mage and #mage.offer >= 3) then
			fail(scenario, "SKIPPED -- the Forsaken's or the mage's pools are not what this expects")
			return
		end
		local lines = {}
		local function walk(tbl)
			for _, value in pairs(tbl) do
				if type(value) == "string" then
					lines[#lines + 1] = value
				elseif type(value) == "table" then
					walk(value)
				end
			end
		end
		for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
			"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO", "LEGACY" }) do
			walk(english[name] or {})
		end

		-- Phrases.lua in German, every line translated but those left out,
		-- and those in alike translated as the line they name.
		local speech = ns.db.profile.speech
		local realL, realLocale = ns.L, ns.LOCALE
		local function german(left, alike)
			for i = #ns.PHRASE_SET_ORDER, 1, -1 do
				if ns.PHRASE_SET_ORDER[i] == "incharacter" then table.remove(ns.PHRASE_SET_ORDER, i) end
			end
			local L = setmetatable({}, { __index = function(_, key) return key end })
			local de = {}
			for _, text in ipairs(lines) do
				if not left[text] then
					de[text] = "[de] " .. (alike[text] or text)
					rawset(L, text, de[text])
				end
			end
			ns.L, ns.LOCALE = L, "deDE"
			local chunk, err = loadfile(dir .. "/Phrases.lua")
			local ok, runErr = false, err
			if chunk then ok, runErr = pcall(chunk, "Manners", ns) end
			ns.L, ns.LOCALE = realL, realLocale
			if not ok then
				fail(scenario, "Phrases.lua would not load as deDE: " .. tostring(runErr))
				return nil
			end
			-- 1.5.0's box as it saved it on this client.
			local saved = {}
			for _, text in ipairs(SAVED.forsaken150) do
				if de[text] == nil then
					fail(scenario, "SKIPPED -- 1.5.0's lines are not all translated here")
					return nil
				end
				saved[#saved + 1] = de[text]
			end
			return ns.InCharacter, table.concat(saved, "\n")
		end

		-- Left untranslated: a thanks, a class offer and a night line the box
		-- shows on an English client.
		local left = { [forsaken.thanks[2]] = true, [mage.offer[2]] = true, [forsaken.night[1]] = true }
		local RP, saved = german(left, {})
		if not RP then return end
		local today = RP.Text()
		local box = split(today)
		if #box < 20 then fail(scenario, ("the box shows only %d lines on deDE"):format(#box)) end
		local seen = {}
		for _, line in ipairs(box) do
			if line:sub(1, 5) ~= "[de] " then fail(scenario, "the box shows an untranslated line on deDE: " .. line) end
			seen[line] = true
		end
		if not seen["[de] " .. forsaken.thanks[5]] then
			fail(scenario, "the next translated thanks did not move up on deDE")
		end
		for _, case in ipairs({
			{ "1.5.0's box in German", saved },
			{ "1.5.0's box in English", table.concat(SAVED.forsaken150, "\n") },
		}) do
			speech.phrases = case[2]
			if not RP.Active(speech) then fail(scenario, case[1] .. " counts as edited on deDE") end
			ns.ClampSettings()
			if speech.phrases ~= today then
				fail(scenario, case[1] .. " did not become the German box: |" .. tostring(speech.phrases) .. "|")
			end
		end
		local edited = saved .. "\n[de] My own line, {name}."
		speech.phrases = edited
		if RP.Active(speech) then fail(scenario, "an edited German box counts as In character") end
		ns.ClampSettings()
		if speech.phrases ~= edited then fail(scenario, "an edited German box was replaced at load") end

		-- The Forsaken's first answer translated as their first thanks.
		RP, saved = german({}, { [forsaken.asked[1]] = forsaken.thanks[1] })
		if not RP then return end
		seen = {}
		for _, line in ipairs(split(RP.Text())) do
			if seen[line] then fail(scenario, "the box shows a line twice on deDE: " .. line) end
			seen[line] = true
		end
		speech.phrases = saved
		if not RP.Active(speech) then
			fail(scenario, "1.5.0's German box with two lines alike counts as edited")
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rpx-5
-- Example lines reworded since boxes were saved with them: the trolls', after
-- 1.6.4. A troll mage's box as 1.6.4 saved it, and as 1.5.0 did, still
-- counts and becomes today's at load, in English and in the client's
-- language. There the new lines have no translation yet and the old ones
-- do, as the locale files stand; and a line the language had no translation
-- for was left out of the box it saved, the next one moving up, which the
-- saved box keeps. The "translation" is made as in rpx-4.
do
	local scenario = "rp examples: a box of lines reworded since still counts"
	with(scenario, "Horde", function()
		local ns = ready(scenario, "Troll", "MAGE")
		if not ns then return end
		local english = ns.InCharacter
		local speech = ns.db.profile.speech
		local today = english.Text()
		if today == table.concat(SAVED.troll164, "\n") then
			fail(scenario, "SKIPPED -- the troll's examples read as 1.6.4's")
			return
		end
		for _, saved in ipairs({
			{ "a troll mage's 1.6.4 box", SAVED.troll164 },
			{ "a troll mage's 1.5.0 box", SAVED.troll150 },
		}) do
			speech.phrases = table.concat(saved[2], "\n")
			if not english.Active(speech) then fail(scenario, saved[1] .. " counts as edited") end
			ns.ClampSettings()
			if speech.phrases ~= today then
				fail(scenario, saved[1] .. " was not turned into today's: |" .. tostring(speech.phrases) .. "|")
			end
		end

		-- Every line the set knows, today's and the ones it keeps to
		-- recognise; and the box's lines 1.6.4's did not have, the new ones.
		local lines = {}
		local function walk(tbl)
			for _, value in pairs(tbl) do
				if type(value) == "string" then
					lines[#lines + 1] = value
				elseif type(value) == "table" then
					walk(value)
				end
			end
		end
		for _, name in ipairs({ "RACE", "KIN", "FACTION", "GENERAL", "CLASS", "SPELL", "TRADE", "GIFT",
			"HISTORY", "PLACE", "TIME", "TARGET", "SAME", "ONTO", "LEGACY" }) do
			walk(english[name] or {})
		end
		local old = {}
		for _, text in ipairs(SAVED.troll164) do old[text] = true end
		local new = {}
		for _, text in ipairs(split(today)) do
			if not old[text] then new[text] = true end
		end

		-- Phrases.lua in German with every line translated but the new ones
		-- and those in more; and a saved box as it read in that German.
		local realL, realLocale = ns.L, ns.LOCALE
		local function german(more)
			for i = #ns.PHRASE_SET_ORDER, 1, -1 do
				if ns.PHRASE_SET_ORDER[i] == "incharacter" then table.remove(ns.PHRASE_SET_ORDER, i) end
			end
			local L = setmetatable({}, { __index = function(_, key) return key end })
			for _, text in ipairs(lines) do
				if not (new[text] or more[text]) then rawset(L, text, "[de] " .. text) end
			end
			ns.L, ns.LOCALE = L, "deDE"
			local chunk, err = loadfile(dir .. "/Phrases.lua")
			local ok, runErr = false, err
			if chunk then ok, runErr = pcall(chunk, "Manners", ns) end
			ns.L, ns.LOCALE = realL, realLocale
			if not ok then
				fail(scenario, "Phrases.lua would not load as deDE: " .. tostring(runErr))
				return nil
			end
			local function box(list)
				local out = {}
				for _, text in ipairs(list) do
					local de = rawget(L, text)
					if de == nil then
						fail(scenario, "SKIPPED -- a saved line is not translated here: " .. text)
						return nil
					end
					out[#out + 1] = de
				end
				return table.concat(out, "\n")
			end
			return ns.InCharacter, box
		end

		local RP, box = german({})
		if not RP then return end
		local germanToday = RP.Text()
		local cases = {
			{ "a troll mage's German 1.6.4 box", box(SAVED.troll164) },
			{ "a troll mage's German 1.5.0 box", box(SAVED.troll150) },
			{ "a troll mage's 1.6.4 box in English on deDE", table.concat(SAVED.troll164, "\n") },
		}
		if cases[1][2] == germanToday then
			fail(scenario, "SKIPPED -- the German box reads as 1.6.4's")
		end
		for _, case in ipairs(cases) do
			if case[2] then
				speech.phrases = case[2]
				if not RP.Active(speech) then fail(scenario, case[1] .. " counts as edited") end
				ns.ClampSettings()
				if speech.phrases ~= germanToday then
					fail(scenario, case[1] .. " did not become the German box: |" .. tostring(speech.phrases) .. "|")
				end
			end
		end

		-- The troll's third offer untranslated, then as now: 1.6.4's German
		-- box had the fifth, which the review kept, after the fourth.
		local third = "Ya look like somebody who appreciate quality, {name}. Here: quality."
		local fourth = "Take dis, {name}. Walk like ya own da jungle. I do."
		local fifth = "Everybody need mojo, {name}. I make so much I gotta give it away."
		RP, box = german({ [third] = true })
		if not RP then return end
		local moved = {}
		for _, text in ipairs(SAVED.troll164) do
			if text ~= third then moved[#moved + 1] = text end
			if text == fourth then moved[#moved + 1] = fifth end
		end
		local saved = box(moved)
		if saved then
			speech.phrases = saved
			if not RP.Active(speech) then
				fail(scenario, "a troll mage's German 1.6.4 box, a line left out, counts as edited")
			end
			ns.ClampSettings()
			if speech.phrases ~= RP.Text() then
				fail(scenario, "a troll mage's German 1.6.4 box, a line left out, did not become the German box: |"
					.. tostring(speech.phrases) .. "|")
			end
		end
		noErrors(scenario, ns)
	end)
end

-- ------------------------------------------------------------------ rpx-6
-- A box of English examples, today's or 1.6.4's, loaded on a client whose
-- language translates a line reworded since 1.6.4 as it translated the line it
-- was: the shipped German, French, Italian and Brazilian files do for the
-- trolls', and the German and French for the goblins'. The English box still
-- counts and becomes the language's, as it does where no two lines read
-- alike (rpx-4, rpx-5 make their "translation" so). The lines and files are
-- the shipped ones.
do
	local scenario = "rp examples: an English box counts where a reworded line reads alike"
	local CASES = {
		{ race = "Troll", codes = { "deDE", "frFR", "itIT", "ptBR", "esES" } },
		{ race = "Goblin", codes = { "deDE", "frFR" } },
	}
	for _, case in ipairs(CASES) do
		with(scenario, "Horde", function()
			local ns = ready(scenario, case.race, "MAGE")
			if not ns then return end
			local english = ns.InCharacter
			local family, faction, class = english.Player()
			local boxes = {
				{ "today's", english.Text() },
				{ "1.6.4's", english.Examples(family, faction, class, false, false, english.BEFORE) },
			}
			for _, code in ipairs(case.codes) do
				for _, box in ipairs(boxes) do
					local there = ready(scenario, case.race, "MAGE", code)
					if not there then return end
					local speech = there.db.profile.speech
					local RP = there.InCharacter
					local mine = RP.Text()
					if mine == box[2] then
						fail(scenario, "SKIPPED -- the box reads the same in English and " .. code)
					end
					speech.phrases = box[2]
					if not RP.Active(speech) then
						fail(scenario, ("a %s English box of %s counts as edited on %s"):format(box[1], case.race, code))
					end
					there.ClampSettings()
					if speech.phrases ~= mine then
						fail(scenario, ("a %s English box of %s did not become the box on %s: |%s|")
							:format(box[1], case.race, code, tostring(speech.phrases)))
					end
					noErrors(scenario, there)
				end
			end
			Mock.locale = nil
		end)
	end
end
