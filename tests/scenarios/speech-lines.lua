-- What the spoken line says, and who reads it: the what-if pass before 1.6.5.
--
-- - A ready-made thank-you ("Thanks for the buff", "Consider us even") went to
--   anybody once "Only when I buff someone back" was off, its default since
--   1.5.1: a passer-by who never buffed you was thanked for a buff.
-- - /party and /raid counted the group the game forms for a battleground or a
--   dungeon queue, which talks in /instance, and reached nobody there.
-- - A /party or /raid line went to somebody outside that group: a stranger
--   who buffed you while you quest in a party never read their thank-you.
-- - An emote said a ready-made line as an action: "Mortimer Cheers, Munin!".
--
-- Every scenario name starts with "speech-lines:" so the mutations in
-- tests/mutations/speech-lines.py can name the one that has to catch them.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local MUNIN = "Munin Hugins"
local realRandom = math.random

local function guarded(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function flat(text)
	return (tostring(text):gsub("\n", " / "))
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

-- A session with speech on and a set loaded through the dropdown, as a player
-- loads it.
local function withSet(scenario, set)
	Mock.reset()
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "SAY"
	if set then
		local preset = findOption(ns.optionsTable, "preset")
		if not (preset and preset.set) then
			fail(scenario, "SKIPPED -- the Load a set dropdown is not on the page")
			return nil
		end
		preset.set({ "preset" }, set)
	end
	return ns
end

local function person(ns, reason)
	return { name = "Bram", short = "Bram", reason = reason, buff = ns.ResolveBuff(true),
		inGroup = reason == "group" or nil }
end

-- The lines said to this person over n presses, by the line.
local function rolls(ns, entry, n)
	local said, silent = {}, 0
	counting()
	for _ = 1, n do
		local line = ns.PickPhrase(entry, 200)
		if line then said[line] = true else silent = silent + 1 end
	end
	math.random = realRandom
	return said, silent
end

local RETURN = { "Thanks for the buff, Bram!", "Returning the favour, Bram.",
	"One good buff deserves another, Bram.", "Consider us even, Bram." }

-- ------------------------------------------------------------ speech-lines-1
-- Polite or Cheeky, "Only when I buff someone back" off: a passer-by, a group
-- member and somebody who asked hear the set's other lines, never a thank-you
-- for a buff they did not give; somebody owed one still hears them all. The
-- player's own lines go to anybody, and a box of nothing but thank-yous says
-- nothing to a stranger.
do
	local scenario = "speech-lines: a ready-made thank-you only to somebody owed"
	for _, set in ipairs({ "polite", "cheeky" }) do
		local ns = withSet(scenario, set)
		if ns then
			for _, reason in ipairs({ "nearby", "group", "asked" }) do
				local said, silent = rolls(ns, person(ns, reason), 60)
				if silent > 0 then
					fail(scenario, ("%s, %s: %d presses said nothing; the set has other lines"):format(set, reason, silent))
				end
				for _, text in ipairs(RETURN) do
					if said["/say " .. text] then
						fail(scenario, ("%s: '%s' said to somebody %s"):format(set, text, reason))
					end
				end
			end
			local owed = rolls(ns, person(ns, "owed"), 60)
			for _, text in ipairs(RETURN) do
				local inSet = ns.db.profile.speech.phrases:find((text:gsub("Bram", "{name}")), 1, true)
				if inSet and not owed["/say " .. text] then
					fail(scenario, ("%s: '%s' never said to somebody owed a favour"):format(set, text))
				end
			end
			guarded(scenario, ns)
		end
	end

	local ns = withSet(scenario, "polite")
	if ns then
		local speech = ns.db.profile.speech
		speech.phrases = "Thanks for the buff, {name}!\nWell met, {name}."
		local said = rolls(ns, person(ns, "nearby"), 20)
		if not said["/say Well met, Bram."] then
			fail(scenario, "the player's own line was not said to a passer-by: " .. flat(next(said)))
		end
		if said["/say Thanks for the buff, Bram!"] then
			fail(scenario, "a hand-edited box thanked a passer-by for a buff")
		end
		speech.phrases = "Thanks for the buff, {name}!\nConsider us even, {name}."
		local _, silent = rolls(ns, person(ns, "nearby"), 10)
		if silent ~= 10 then
			fail(scenario, "a box of thank-yous alone still spoke to a passer-by")
		end
		guarded(scenario, ns)
	end
end

-- A session with Munin on a nameplate, owed a favour, and a line that fits,
-- on this channel, as speech-range.lua sets one up.
local function session(scenario, channel)
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Munin", "Hugins" } })
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = channel
	speech.phrases = "Thanks, {name}."
	H.owe(ns, MUNIN)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

local function macro(ns)
	return ns.Prompt:GetButton():GetAttribute("macrotext1")
end

-- Whether the macro, after a repaint, has Munin armed and a line on this
-- channel; nil (and a SKIPPED failure) when Munin is not armed at all.
local function speaksTo(scenario, ns, command, label)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	local text = macro(ns)
	if not (text and text:find(MUNIN, 1, true)) then
		fail(scenario, "SKIPPED -- Munin is not armed (" .. label .. "): " .. flat(text))
		return nil
	end
	return text:find("\n/" .. command .. " ", 1, true) ~= nil, text
end

-- Puts back the globals a scenario below stands in.
local function standIns(names)
	local saved = {}
	for _, name in ipairs(names) do saved[name] = rawget(_G, name) end
	return function()
		for _, name in ipairs(names) do rawset(_G, name, saved[name]) end
	end
end

-- ------------------------------------------------------------ speech-lines-2
-- A battleground joined alone, or a dungeon queue: the game's instance group,
-- and no party or raid of your own. /party and /raid are said only in your
-- own (LE_PARTY_CATEGORY_HOME); in it, they are.
do
	local scenario = "speech-lines: no party line in an instance group alone"
	for _, channel in ipairs({ "PARTY", "RAID" }) do
		local command = channel:lower()
		local put = standIns({ "LE_PARTY_CATEGORY_HOME", "IsInGroup", "IsInRaid", "UnitInRaid" })
		local home = true
		rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
		-- Any group at all, unless asked about your own: a dungeon's party,
		-- or a battleground's raid.
		rawset(_G, "IsInGroup", function(category) return category ~= 1 or home end)
		rawset(_G, "IsInRaid", function(category)
			if channel == "PARTY" then return false end
			return category ~= 1 or home
		end)
		local realInRaid = rawget(_G, "UnitInRaid")
		rawset(_G, "UnitInRaid", function(unit)
			if unit == "nameplate1" then return 2 end
			return realInRaid(unit)
		end)
		local ns, restore = session(scenario, channel)
		if ns then
			Mock.groupSize = 5
			for _, step in ipairs({ { "only an instance group", false }, { "your own group", true } }) do
				home = step[2]
				local says, text = speaksTo(scenario, ns, command, step[1])
				if says ~= nil and says ~= step[2] then
					fail(scenario, ("/%s, %s: the macro %s the line: %s"):format(command, step[1],
						step[2] and "lost" or "kept", flat(text)))
				end
			end
			Mock.groupSize = 0
			guarded(scenario, ns)
			restore()
		end
		put()
	end
end

-- ------------------------------------------------------------ speech-lines-3
-- In a party, somebody who is not in it -- a stranger who buffed you while you
-- quest with friends -- gets the buff with no /party line; a member gets it.
-- /say has no such rule.
do
	local scenario = "speech-lines: no party line to somebody outside the party"
	local put = standIns({ "UnitInParty" })
	local member = false
	local realInParty = rawget(_G, "UnitInParty")
	rawset(_G, "UnitInParty", function(unit)
		if unit == "nameplate1" then return member end
		return realInParty(unit)
	end)
	local ns, restore = session(scenario, "PARTY")
	if ns then
		Mock.groupSize = 3
		for _, step in ipairs({ { "a stranger", false }, { "a party member", true } }) do
			member = step[2]
			local says, text = speaksTo(scenario, ns, "party", step[1])
			if says ~= nil and says ~= step[2] then
				fail(scenario, ("%s: the macro %s the /party line: %s"):format(step[1],
					step[2] and "lost" or "kept", flat(text)))
			end
		end
		member = false
		ns.db.profile.speech.channel = "SAY"
		local says, text = speaksTo(scenario, ns, "say", "a stranger, /say")
		if says == false then fail(scenario, "a stranger lost the /say line: " .. flat(text)) end
		Mock.groupSize = 0
		guarded(scenario, ns)
		restore()
	end
	put()
end

-- ------------------------------------------------------------ speech-lines-4
-- In a raid, /party is your own subgroup: a raider in another one never
-- reads it. Asked of UnitInSubgroup where the client has it, else of the raid
-- roster. /raid reaches them either way.
do
	local scenario = "speech-lines: no party line to another subgroup of the raid"
	for _, roster in ipairs({ false, true }) do
		local put = standIns({ "UnitInRaid", "UnitInSubgroup" })
		local index = 7
		local realInRaid = rawget(_G, "UnitInRaid")
		rawset(_G, "UnitInRaid", function(unit)
			if unit == "nameplate1" then return index end
			return realInRaid(unit)
		end)
		rawset(_G, "UnitInSubgroup", function(unit)
			if unit == "nameplate1" then return Mock.subgroupOf(index) == Mock.subgroupOf(1) end
			return false
		end)
		if roster then rawset(_G, "UnitInSubgroup", nil) end
		local how = roster and " (by the roster)" or ""
		local ns, restore = session(scenario, "PARTY")
		if ns then
			Mock.raid = { size = 10, player = 1 }
			for _, step in ipairs({ { "another subgroup", 7, false }, { "your subgroup", 2, true } }) do
				index = step[2]
				local says, text = speaksTo(scenario, ns, "party", step[1] .. how)
				if says ~= nil and says ~= step[3] then
					fail(scenario, ("%s%s: the macro %s the /party line: %s"):format(step[1], how,
						step[3] and "lost" or "kept", flat(text)))
				end
			end
			index = 7
			ns.db.profile.speech.channel = "RAID"
			local says, text = speaksTo(scenario, ns, "raid", "another subgroup, /raid" .. how)
			if says == false then fail(scenario, "a raider in another subgroup lost the /raid line" .. how .. ": " .. flat(text)) end
			Mock.raid = nil
			guarded(scenario, ns)
			restore()
		end
		put()
	end
end

-- ------------------------------------------------------------ speech-lines-5
-- Emote: the addon's own words are quoted -- Mortimer says, "Cheers, Bram!" --
-- from a ready-made set or In character, measured as they go out; a line the
-- player wrote for an emote ("bows to {name}.") goes as typed. The tooltip
-- quotes the words, not the frame.
do
	local scenario = "speech-lines: an emote quotes the addon's lines"
	local ns = withSet(scenario, "polite")
	if ns then
		local speech = ns.db.profile.speech
		speech.channel = "EMOTE"
		local quote = ns.L['says, "%s"']
		local said = rolls(ns, person(ns, "owed"), 30)
		local n = 0
		for line in pairs(said) do
			n = n + 1
			local words = line:match('^/emote says, "(.+)"$')
			if not words then
				fail(scenario, "a Polite line went out as an action: " .. line)
			elseif ns.SpokenText(line) ~= words then
				fail(scenario, "the tooltip quotes " .. tostring(ns.SpokenText(line)) .. " for " .. line)
			end
		end
		if n == 0 then fail(scenario, "the Polite set said nothing as an emote") end

		speech.phrases = "bows to {name}."
		local own = rolls(ns, person(ns, "owed"), 5)
		if not own["/emote bows to Bram."] then
			fail(scenario, "the player's own emote was not said as typed: " .. flat(next(own)))
		end

		-- In character, held to a budget a quoted line only just fits.
		local preset = findOption(ns.optionsTable, "preset")
		preset.set({ "preset" }, "incharacter")
		speech.channel = "EMOTE"
		local entry = person(ns, "owed")
		local budget = 75
		local RP = ns.InCharacter
		local recent = RP.RECENT
		RP.RECENT = 0
		counting()
		local lines = 0
		for _ = 1, 300 do
			local line, source = ns.PickPhrase(entry, budget)
			if line then
				lines = lines + 1
				if #line > budget then
					fail(scenario, ("an In character emote of %d characters, over its %d: %s"):format(#line, budget, line))
					break
				end
				local words = line:match('^/emote says, "(.+)"$')
				if not (words and source) then
					fail(scenario, "an In character line went out unquoted: " .. line)
					break
				end
			end
		end
		math.random = realRandom
		RP.RECENT = recent
		if lines == 0 then fail(scenario, "In character said nothing as an emote within " .. budget) end
		if quote ~= 'says, "%s"' then fail(scenario, "the English client's frame is " .. tostring(quote)) end
		guarded(scenario, ns)
	end
end

-- ------------------------------------------------------------ speech-lines-6
-- A box with one line too long for the macro: the press says the other, not
-- nothing, whichever line the roll lands on.
do
	local scenario = "speech-lines: a line too long for the macro leaves the others to say"
	local ns = withSet(scenario, nil)
	if ns then
		ns.db.profile.speech.phrases = "Hi {name}.\n" .. string.rep("y", 300)
		local entry = person(ns, "owed")
		local budget = ns.PhraseBudget(entry)
		local said, silent = rolls(ns, entry, 20)
		if silent > 0 then
			fail(scenario, ("%d of 20 presses said nothing; one line of the box fits in %d"):format(silent, budget))
		end
		if not said["/say Hi Bram."] then fail(scenario, "the line that fits was never said") end
		guarded(scenario, ns)
	end
end
