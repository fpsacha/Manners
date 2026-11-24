-- A full check-up for a bug report (1.11.9). Diagnostics has one button that
-- runs every check Manners has and puts it all in one box to copy: the bug
-- report, the self-test, what /manners debug and /manners errors say, your own
-- buffs' reasons and the settings, each under its heading, with no colour codes
-- and nothing printed to chat or said to anybody.
--
-- Every scenario name starts with "fullreport:" so the mutations in
-- tests/mutations/fullreport.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load

local function with(scenario, body)
	Mock.reset()
	local restore = H.strangers({ nameplate1 = { "Anna", "Aim" } })
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
	restore()
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "fullreport: the check-up holds every part, plain, and prints nothing to chat"
	with(scenario, function(ns)
		local text = ns.FullReport()
		for _, part in ipairs({ "== Bug report ==", "== Self-test ==", "== /manners debug ==", "== /manners errors ==",
			"== Your own buffs ==", "== Settings ==" }) do
			if not text:find(part, 1, true) then fail(scenario, "the check-up has no " .. part) end
		end
		if text:find("this part failed", 1, true) then fail(scenario, "a part of the check-up failed: " .. text) end
		if not text:find("checks:", 1, true) then fail(scenario, "the self-test's count is not in it") end
		if not text:find("queue", 1, true) then fail(scenario, "what /manners debug says is not in it") end
		if text:find("|c", 1, true) or text:find("|r", 1, true) then fail(scenario, "colour codes are left in it") end
		if #Mock.printed ~= 0 then fail(scenario, "the check-up printed to chat: " .. table.concat(Mock.printed, " / ")) end
		-- And the chat is the addon's again afterwards.
		ns.addon:Print("after the check-up")
		if not table.concat(Mock.printed, "\n"):find("after the check-up", 1, true) then
			fail(scenario, "the chat stayed caught after the check-up")
		end
	end)
end

do
	local scenario = "fullreport: Diagnostics has the button, and it fills the box"
	with(scenario, function(ns)
		local button = H.findOption(ns.optionsTable, "fullReport")
		if not button then
			fail(scenario, "Diagnostics has no full check-up button")
			return
		end
		button.func()
		local text = ns.OptionsPage.selftestText
		if type(text) ~= "string" or not text:find("== Self-test ==", 1, true) then
			fail(scenario, "the box does not hold the check-up: " .. tostring(text and text:sub(1, 80)))
		end
	end)
end

do
	local scenario = "fullreport: the trail says what happened, by alias, and is kept short"
	with(scenario, function(ns)
		H.primeAuras(ns)
		H.favourFrom(ns, "nameplate1", 10938, 9101)
		ns.addon:Tick()
		H.pressButton(ns)
		local text = ns.FullReport()
		for _, want in ipairs({ "== What happened lately ==", "== The queue now ==", "== Where you are ==",
			"== The bar macro ==", "== Other addons loaded ==", "buffed you", "on the prompt:" }) do
			if not text:find(want, 1, true) then fail(scenario, "the check-up has no " .. want) end
		end
		if not text:find("[Person 1]", 1, true) then fail(scenario, "the people in the trail are not named by alias") end
		if text:find("Anna Aim", 1, true) or text:find("Anna", 1, true) then
			fail(scenario, "a player's name is left in the check-up")
		end
		for _ = 1, 300 do ns.Trail("test", "filler") end
		if #ns.db.char.trail ~= 200 then fail(scenario, ("the trail holds %d lines, not 200"):format(#ns.db.char.trail)) end
	end)
end
