-- Send Manners messages to (1.12.1). A player's chat filled up with Manners'
-- lines running past a crowd, and asked for the lines in a tab of their own
-- or none at all. "Show what Manners is doing in my chat window" (verbose) is
-- off by default now, and Start here has "Send Manners messages to"
-- (chat.frame; "general.chatFrame"): the default chat window or an open chat
-- tab by name. addon:Print and addon:Reply hand the chosen tab's frame to the
-- print (ns.ChatFrame); a tab since closed or renamed is the default window.
--
-- Every scenario name starts with "chatframe:" so the mutations in
-- tests/mutations/chatframe.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local GLOBALS = { "NUM_CHAT_WINDOWS", "GetChatWindowInfo", "ChatFrame1", "ChatFrame2", "ChatFrame3", "ChatFrame4", "COMBAT_LOG" }

-- Four chat windows: General, the combat log, a tab "Manners" and a closed one.
local TABS = {
	{ name = "General", shown = true, docked = 1 },
	{ name = "Combat Log", shown = false, docked = 2 },
	{ name = "Manners", shown = false, docked = 3 },
	{ name = "Old", shown = false, docked = nil },
}

local function with(scenario, body)
	Mock.reset()
	local saved = {}
	for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end
	local ok, err = pcall(function()
		rawset(_G, "NUM_CHAT_WINDOWS", #TABS)
		rawset(_G, "COMBAT_LOG", nil)
		local frames = {}
		for i = 1, #TABS do
			frames[i] = { AddMessage = function() end, id = i }
			rawset(_G, "ChatFrame" .. i, frames[i])
		end
		rawset(_G, "GetChatWindowInfo", function(i)
			local tab = TABS[i]
			if not tab then return nil end
			return tab.name, 14, 1, 1, 1, 1, tab.shown, false, tab.docked
		end)
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.printed, Mock.printedTo = {}, {}
		body(ns, frames)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	for _, name in ipairs(GLOBALS) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- Where the last line went: the frame, or false for the default window.
local function lastTo()
	return Mock.printedTo[#Mock.printed]
end

do
	local scenario = "chatframe: the chat lines are off by default, and the default window is the one"
	with(scenario, function(ns)
		if H.shipped.verbose ~= false then
			fail(scenario, "Show what Manners is doing in my chat window ships " .. tostring(H.shipped.verbose) .. ", not off")
		end
		if ns.defaults.profile.chat.frame ~= "" then fail(scenario, "the default window is not the default") end
		ns.addon:Print("a line")
		if lastTo() ~= false then fail(scenario, "with nothing chosen the line went to a tab") end
	end)
end

do
	local scenario = "chatframe: lines go to the tab chosen, a reply too"
	with(scenario, function(ns, frames)
		ns.db.profile.chat.frame = "Manners"
		ns.addon:Print("to the tab")
		if lastTo() ~= frames[3] then fail(scenario, "the line did not go to the Manners tab") end
		if Mock.printed[#Mock.printed] ~= "to the tab" then
			fail(scenario, "the frame was printed as part of the line: " .. tostring(Mock.printed[#Mock.printed]))
		end
		ns.addon:Reply("a reply")
		if lastTo() ~= frames[3] then fail(scenario, "a reply did not go to the Manners tab") end
	end)
end

do
	local scenario = "chatframe: a tab gone falls back to the default window"
	with(scenario, function(ns, frames)
		ns.db.profile.chat.frame = "Old"
		ns.addon:Print("closed tab")
		if lastTo() ~= false then fail(scenario, "a line went to a closed tab") end
		ns.db.profile.chat.frame = "Renamed away"
		ns.addon:Print("renamed tab")
		if lastTo() ~= false then fail(scenario, "a line went somewhere for a tab that is not there") end
	end)
end

do
	local scenario = "chatframe: the choice lists the default window and the open tabs, not the combat log"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "chatFrame")
		if not control then return fail(scenario, "Start here has no Send Manners messages to") end
		local values = control.values()
		if not values[""] or not values.General or not values.Manners then
			fail(scenario, "the choice lacks the default window or an open tab")
		end
		if values.Old then fail(scenario, "a closed tab is offered") end
		rawset(_G, "COMBAT_LOG", "Combat Log")
		values = control.values()
		if values["Combat Log"] then fail(scenario, "the combat log is offered") end
		local order = control.sorting()
		if order[1] ~= "" then fail(scenario, "the default window is not first") end
		control.set({}, "Manners")
		if ns.db.profile.chat.frame ~= "Manners" or control.get({}) ~= "Manners" then
			fail(scenario, "choosing the tab did not save it")
		end
		-- The choice made, then the tab closed: still listed, so it reads as made.
		ns.db.profile.chat.frame = "Old"
		if not control.values().Old then fail(scenario, "a saved tab since closed is not listed") end
		ns.db.profile.chat.frame = 5
		ns.ClampSettings()
		if ns.db.profile.chat.frame ~= "" then
			fail(scenario, "a damaged choice was not repaired")
		end
		local found
		local page = ns.WindowLayout and ns.WindowLayout.pages and ns.WindowLayout.pages.general
		for _, section in ipairs(page and page.sections or {}) do
			for _, item in ipairs(section.items or {}) do
				if item == "general.chatFrame" then found = true end
			end
		end
		if not found then fail(scenario, "the options window does not place general.chatFrame") end
	end)
end
