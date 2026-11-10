-- The line for somebody on WoW Forever who buffs the author's character through
-- the prompt (Clicks.lua, ns.NoteBuffedAuthor).
--
-- Every scenario name starts with "author-egg:" so the mutations in
-- tests/mutations/author-egg.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local AUTHOR = "Mort Defrette"

-- Records what the addon prints, and counts the lines that are the joke.
local function listen(ns)
	local said = {}
	ns.addon.Print = function(_, text) said[#said + 1] = tostring(text) end
	return function()
		local jokes = 0
		for _, line in ipairs(said) do
			if line:find("author of Manners", 1, true) or line:find("wrote this addon", 1, true) then
				jokes = jokes + 1
			end
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
	local bowed = {}
	rawset(_G, "DoEmote", function(token) bowed[#bowed + 1] = tostring(token) end)
	local shown = {}
	rawset(_G, "UIErrorsFrame", { AddMessage = function(_, text) shown[#shown + 1] = tostring(text) end })
	loaded(scenario, nil, { "Anna", "Aim" }, function(ns)
		local said = {}
		ns.addon.Print = function(_, text) said[#said + 1] = tostring(text) end
		ns.NoteBuffedAuthor(AUTHOR)
		if #shown ~= 1 or not shown[1]:find("Mort Defrette", 1, true) then
			fail(scenario, "nothing was put across the screen: " .. table.concat(shown, " | "))
		end
		if not (said[1] or ""):find("|cffffd100", 1, true) then
			fail(scenario, "the chat line is not gold: " .. tostring(said[1]))
		end
		if #bowed ~= 1 or bowed[1] ~= "BOW" then fail(scenario, "the buffer did not bow: " .. table.concat(bowed, ",")) end
		ns.NoteBuffedAuthor(AUTHOR)
		if #shown ~= 1 then fail(scenario, "a second buff put it across the screen again") end
		if #bowed ~= 1 then fail(scenario, "a second buff bowed again") end
	end)
	rawset(_G, "UIErrorsFrame", saved)
	rawset(_G, "DoEmote", savedEmote)
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
