-- The line for somebody on WoW Forever who buffs the author's character through
-- the prompt (Clicks.lua, ns.NoteBuffedAuthor).
--
-- Every scenario name starts with "author-egg:" so the mutations in
-- tests/mutations/author-egg.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local AUTHOR = "Mort Defrette"

-- Whether a line is one of the joke's lines. The line is picked at random, and
-- not every one has the author's name in it.
local function isJoke(line)
	line = tostring(line)
	return line:find("author of Manners", 1, true) ~= nil or line:find("wrote this addon", 1, true) ~= nil
end

-- Records what the addon prints, and counts the lines that are the joke.
local function listen(ns)
	local said = {}
	ns.addon.Print = function(_, text) said[#said + 1] = tostring(text) end
	return function()
		local jokes = 0
		for _, line in ipairs(said) do
			if isJoke(line) then jokes = jokes + 1 end
		end
		return jokes
	end
end

local function loaded(scenario, flavour, playerName, body)
	Mock.reset()
	if flavour then Mock.setFlavour(flavour) end
	Mock.playerName = playerName
	local ok, err = pcall(function()
		local ns = load(scenario)
		if ns then body(ns) end
	end)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "author-egg: a press that lands on the author says so once"
	Mock.reset()
	Mock.playerName = { "Anna", "Aim" }
	local restoreUnits = strangers({ party1 = { "Mort", "Defrette" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 2
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		local jokes = listen(ns)
		local entry
		for _, candidate in ipairs(ns.BuildQueue()) do
			if candidate.name == AUTHOR then entry = candidate end
		end
		if not entry then
			fail(scenario, "SKIPPED -- the author was not offered")
			return
		end
		if not H.pressAndSend(ns, entry, ns.FindBuff("MAGE", "intellect").ranks[1]) then
			fail(scenario, "SKIPPED -- the press went nowhere")
			return
		end
		if jokes() ~= 1 then fail(scenario, ("the press said the joke %d times"):format(jokes())) end
		ns.NoteBuffedAuthor(AUTHOR)
		if jokes() ~= 1 then fail(scenario, "a second buff said the joke again in the same session") end
	end)
	restoreUnits()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "author-egg: it also shows across the screen, in gold in chat"
	local saved = rawget(_G, "UIErrorsFrame")
	local savedEmote = rawget(_G, "DoEmote")
	local savedNotice, savedWarning, savedSound =
		rawget(_G, "RaidNotice_AddMessage"), rawget(_G, "RaidWarningFrame"), rawget(_G, "PlaySound")
	local banners, sounds = {}, {}
	rawset(_G, "RaidWarningFrame", {})
	rawset(_G, "RaidNotice_AddMessage", function(_, text) banners[#banners + 1] = tostring(text) end)
	rawset(_G, "PlaySound", function(id) sounds[#sounds + 1] = id end)
	local bowed = {}
	rawset(_G, "DoEmote", function(token) bowed[#bowed + 1] = tostring(token) end)
	local shown = {}
	rawset(_G, "UIErrorsFrame", { AddMessage = function(_, text) shown[#shown + 1] = tostring(text) end })
	loaded(scenario, nil, { "Anna", "Aim" }, function(ns)
		local said = {}
		ns.addon.Print = function(_, text) said[#said + 1] = tostring(text) end
		ns.NoteBuffedAuthor(AUTHOR)
		if #shown ~= 1 or not isJoke(shown[1]) then
			fail(scenario, "nothing was put across the screen: " .. table.concat(shown, " | "))
		end
		if not (said[1] or ""):find("|cffffd100", 1, true) then
			fail(scenario, "the chat line is not gold: " .. tostring(said[1]))
		end
		if #banners ~= 1 or not isJoke(banners[1]) then
			fail(scenario, "no banner in the raid warning's lettering: " .. table.concat(banners, " | "))
		end
		if #sounds ~= 1 or sounds[1] ~= 888 then fail(scenario, "no fanfare: " .. table.concat(sounds, ",")) end
		if #bowed ~= 1 or bowed[1] ~= "BOW" then fail(scenario, "the buffer did not bow: " .. table.concat(bowed, ",")) end
		ns.NoteBuffedAuthor(AUTHOR)
		if #shown ~= 1 then fail(scenario, "a second buff put it across the screen again") end
		if #bowed ~= 1 then fail(scenario, "a second buff bowed again") end
		if #banners ~= 1 or #sounds ~= 1 then fail(scenario, "a second buff made the fanfare again") end
	end)
	rawset(_G, "UIErrorsFrame", saved)
	rawset(_G, "DoEmote", savedEmote)
	rawset(_G, "RaidNotice_AddMessage", savedNotice)
	rawset(_G, "RaidWarningFrame", savedWarning)
	rawset(_G, "PlaySound", savedSound)
end

do
	local scenario = "author-egg: the seal is shown under the line, then fades and goes"
	loaded(scenario, nil, { "Anna", "Aim" }, function(ns)
		ns.addon.Print = function() end
		ns.NoteBuffedAuthor(AUTHOR)
		local seal = Mock.namedFrames and Mock.namedFrames.MannersAuthorSeal
		if not seal then fail(scenario, "no seal was made") return end
		if not seal:IsShown() then fail(scenario, "the seal is not shown") end
		if not seal.art then fail(scenario, "the seal has no art") end
		if not isJoke(seal.text:GetText()) then
			fail(scenario, "the line under the seal reads " .. tostring(seal.text:GetText()))
		end
		local update = seal.scripts and seal.scripts.OnUpdate
		if not update then fail(scenario, "the seal has no fade") return end
		update(seal, 0.2)
		local early = seal:GetAlpha()
		if not (early > 0 and early < 1) then fail(scenario, "fading in, its alpha is " .. tostring(early)) end
		update(seal, 2)
		if seal:GetAlpha() ~= 1 then fail(scenario, "held, its alpha is " .. tostring(seal:GetAlpha())) end
		update(seal, 20)
		if seal:IsShown() then fail(scenario, "the seal never goes") end
	end)
end

do
	local scenario = "author-egg: the author's Manners is told, once"
	local saved = rawget(_G, "C_ChatInfo")
	local sent = {}
	loaded(scenario, nil, { "Anna", "Aim" }, function(ns)
		ns.addon.Print = function() end
		rawset(_G, "C_ChatInfo", { SendAddonMessage = function(...) sent[#sent + 1] = { ... } end })
		ns.NoteBuffedAuthor(AUTHOR)
		ns.NoteBuffedAuthor(AUTHOR)
		local one = sent[1]
		if #sent ~= 1 or not one then
			fail(scenario, ("%d messages went to the author"):format(#sent))
		elseif one[1] ~= "Manners" or one[2] ~= "author" or one[3] ~= "WHISPER" or one[4] ~= AUTHOR then
			fail(scenario, "the message was " .. table.concat({ tostring(one[1]), tostring(one[2]),
				tostring(one[3]), tostring(one[4]) }, ", "))
		end
	end)
	rawset(_G, "C_ChatInfo", saved)
end

-- The author's own client, on Forever, and somebody else's.
local function heard(scenario, flavour, playerName, prefix, text)
	local said = {}
	loaded(scenario, flavour, playerName, function(ns)
		ns.addon.Print = function(_, line) said[#said + 1] = tostring(line) end
		ns.addon:CHAT_MSG_ADDON("CHAT_MSG_ADDON", prefix, text, "WHISPER", "Anna Aim")
	end)
	return table.concat(said, " | ")
end

do
	local scenario = "author-egg: the author is told who it was, and nobody else is"
	local told = heard(scenario, nil, { "Mort", "Defrette" }, "Manners", "author")
	if not told:find("Anna Aim buffed you with Manners", 1, true) then
		fail(scenario, "the author was told: " .. told)
	end
	local other = heard(scenario, nil, { "Bert", "Beside" }, "Manners", "author")
	if other ~= "" then fail(scenario, "somebody else was told: " .. other) end
	local era = heard(scenario, "vanilla", { "Mort", "Defrette" }, "Manners", "author")
	if era ~= "" then fail(scenario, "Classic Era told the author: " .. era) end
	local wrong = heard(scenario, nil, { "Mort", "Defrette" }, "SomeAddon", "author")
	if wrong ~= "" then fail(scenario, "another addon's prefix was read: " .. wrong) end
	local word = heard(scenario, nil, { "Mort", "Defrette" }, "Manners", "hello")
	if word ~= "" then fail(scenario, "another word was read: " .. word) end
end

do
	local scenario = "author-egg: never for the author"
	loaded(scenario, nil, nil, function(ns)
		local jokes = listen(ns)
		ns.NoteBuffedAuthor(AUTHOR)
		if jokes() ~= 0 then fail(scenario, "the author was told they had buffed the author") end
	end)
end

do
	local scenario = "author-egg: only on WoW Forever"
	loaded(scenario, "vanilla", { "Anna", "Aim" }, function(ns)
		local jokes = listen(ns)
		ns.NoteBuffedAuthor(AUTHOR)
		if jokes() ~= 0 then fail(scenario, "Classic Era said the joke") end
	end)
end

do
	local scenario = "author-egg: nobody else counts"
	loaded(scenario, nil, { "Anna", "Aim" }, function(ns)
		local jokes = listen(ns)
		ns.NoteBuffedAuthor("Mort Mortimer")
		ns.NoteBuffedAuthor("Bert Beside")
		if jokes() ~= 0 then fail(scenario, "somebody else was taken for the author") end
	end)
end
