-- Say nothing at all in chat (1.11.7). A player unticked "Tell me in chat what
-- Manners is doing" and still got lines, because a few are kept whatever that
-- switch says (a title earned, the game refusing somebody, a skip in a fight).
-- Start here now has "Say nothing at all in chat": with it on, no line Manners
-- prints on its own reaches chat; what you type after /manners is answered, and
-- so is the paste of settings and a set of lines you loaded (addon:Reply).
--
-- Every scenario name starts with "silentchat:" so the mutations in
-- tests/mutations/silentchat.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function said() return table.concat(Mock.printed, "\n") end

local function with(scenario, body)
	Mock.reset()
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		H.freshPrompt(ns, scenario)
		Mock.printed = {}
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "silentchat: off by default, and then every line is printed, the chat switch off or on"
	with(scenario, function(ns)
		if ns.db.profile.silentChat ~= false then fail(scenario, "the setting is not off by default") end
		ns.addon:Print("line one")
		ns.db.profile.verbose = false
		ns.addon:Print("line two")
		if not (said():find("line one", 1, true) and said():find("line two", 1, true)) then
			fail(scenario, "a line was lost with the new switch off: " .. said())
		end
	end)
end

do
	local scenario = "silentchat: on, a line of Manners' own does not reach chat"
	with(scenario, function(ns)
		ns.db.profile.silentChat = true
		ns.addon:Print("an automatic line")
		if said():find("automatic line", 1, true) then fail(scenario, "the line was printed: " .. said()) end
	end)
end

do
	local scenario = "silentchat: on, a command typed in chat is still answered"
	with(scenario, function(ns)
		ns.db.profile.silentChat = true
		ns.addon:HandleSlash("help")
		if not said():find("Manners commands:", 1, true) then fail(scenario, "/manners help printed nothing: " .. said()) end
		Mock.printed = {}
		ns.addon:Print("after the command")
		if said():find("after the command", 1, true) then
			fail(scenario, "a line of its own was printed after a command: " .. said())
		end
	end)
end

do
	local scenario = "silentchat: on, a command that throws still puts the silence back"
	with(scenario, function(ns)
		ns.db.profile.silentChat = true
		local real = ns.addon.UpdateScan
		-- A command that raises: the dispatcher's own guard may take it, or it
		-- reaches here; either way the flag must be down again.
		pcall(ns.addon.HandleSlash, ns.addon, { bad = "input" })
		Mock.printed = {}
		ns.addon:Print("still silent")
		if said():find("still silent", 1, true) then fail(scenario, "the flag stayed up after a failing command") end
		ns.addon.UpdateScan = real
	end)
end

do
	local scenario = "silentchat: on, what pasting settings or loading a set says is still said"
	with(scenario, function(ns)
		ns.db.profile.silentChat = true
		ns.addon:Reply("settings applied")
		if not said():find("settings applied", 1, true) then fail(scenario, "a reply was not printed: " .. said()) end
	end)
end

do
	local scenario = "silentchat: Start here has the switch, and it is kept"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "silentChat")
		if not control then
			fail(scenario, "Start here has no switch for saying nothing in chat")
			return
		end
		local info = { "general", "silentChat" }
		if control.type ~= "toggle" or control.get(info) then fail(scenario, "the switch is not an off toggle") end
		control.set(info, true)
		if ns.db.profile.silentChat ~= true or not control.get(info) then fail(scenario, "the switch was not kept") end
	end)
end
