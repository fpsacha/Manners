-- Plain English, part 1: no label says its unit in brackets or "this many",
-- the unit sits in the slider's box, and a label that lost its unit has it in
-- its tooltip (the dialog the window falls back to has no unit field).
--
-- ns.L is empty in English, so an L["..."] call reads back its own key: the
-- spot checks below are the English as written.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local findOption = H.findOption

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

-- One session as `class`, everything put back.
local function with(scenario, class, body)
	Mock.reset()
	Mock.class = class or "MAGE"
	Mock.knownSpells = setmetatable({}, { __index = function() return true end })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		ns.Prompt:ExitTest()
		body(ns)
		ns.Prompt:ExitTest()
		noErrors(scenario, ns)
		ns.CloseOptions()
		ns.Prompt:ExitTest()
	end)
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A name or description, called when it is a function.
local function text(value)
	if type(value) == "function" then
		local ok, out = pcall(value)
		value = ok and out or nil
	end
	return type(value) == "string" and value or nil
end

-- Every control, as (key, node).
local function walk(node, visit, key)
	if type(node) ~= "table" then return end
	if key and node.type then visit(key, node) end
	for k, child in pairs(node.args or {}) do walk(child, visit, k) end
end

-- ------------------------------------------------------------------ 1
local scenario = "menupass-words: no label says its unit in brackets or this many"
local BRACKETS = { "(seconds)", "(minutes)", "(% mana)", "(one per line)" }
for _, class in ipairs({ "MAGE", "PRIEST", "ROGUE", "WARRIOR", "HUNTER", "PALADIN" }) do
	with(scenario, class, function(ns)
		walk(ns.optionsTable, function(key, node)
			local name, desc = text(node.name), text(node.desc)
			for _, bad in ipairs(BRACKETS) do
				if name and name:find(bad, 1, true) then fail(scenario, ("%s: %s is named %q"):format(class, key, name)) end
				if desc and desc:find(bad, 1, true) then fail(scenario, ("%s: %s's tooltip says %q"):format(class, key, bad)) end
			end
			-- A count ("When this many need it") is fine; a length is not.
			if name and (name:find("this many minutes", 1, true) or name:find("this many seconds", 1, true) or name:find("this many times", 1, true)) then
				fail(scenario, ("%s: %s is named %q"):format(class, key, name))
			end
			if name and name:find("Reason text", 1, true) then fail(scenario, ("%s: %s is named %q"):format(class, key, name)) end
			if desc and desc:find("Reason text", 1, true) then fail(scenario, ("%s: %s's tooltip says Reason text"):format(class, key)) end
		end)
	end)
end

-- ------------------------------------------------------------------ 2
scenario = "menupass-words: the reworded labels read as written"
with(scenario, "MAGE", function(ns)
	local CHECKS = {
		{ "owedClassBuffsOnly", "Only class buffs count as favours" },
		{ "repayCovered", "Buff them back even when they already have my buff" },
		{ "reciprocateWindow", "How long a favour stays on offer" },
		{ "retryCooldown", "Wait before trying the same spell on someone again" },
		{ "scanInterval", "Look for people every" },
		{ "reasonTarget", "For my target" },
		{ "reasonUnknown", "When the game hides their buffs" },
		{ "whenBuffed", "When they already have my buff" },
		{ "refreshUnder", "Top up at most this early" },
		{ "manaFloor", "Save mana below" },
		{ "manaFloorKeeps", "While saving mana, still offer" },
		{ "skipGuilds", "Skip these guilds" },
		{ "hideInFight", "Hide the prompt in a fight" },
		{ "fightButtons", "Show the fight buttons" },
		{ "phrases", "Your lines" },
	}
	for _, check in ipairs(CHECKS) do
		local node = findOption(ns.optionsTable, check[1])
		if not node then
			fail(scenario, check[1] .. " is not in the options")
		elseif text(node.name) ~= check[2] then
			fail(scenario, ("%s reads %q, not %q"):format(check[1], tostring(text(node.name)), check[2]))
		end
	end
end)

-- ------------------------------------------------------------------ 3
scenario = "menupass-words: every slider with a unit shows it"
with(scenario, "MAGE", function(ns)
	local UI = ns.WindowUI
	ns.OpenOptions("general")
	ns.Prompt:ExitTest()
	ns.db.profile.filters.whenBuffed = "refresh"
	local function reads(path, store, field, value, want)
		ns.OpenOptions(UI.PageOf(path))
		ns.Prompt:ExitTest()
		ns.db.profile[store][field] = value
		UI.Refresh()
		local row = UI.RowFor(path)
		if not (row and row.box) then
			fail(scenario, path .. " has no slider box on its page")
			return
		end
		-- A row in a shut fold is not repainted with the page: ask it directly.
		if row.Refresh then row:Refresh() end
		if row.box:GetText() ~= want then
			fail(scenario, ("%s at %s reads %q, not %q"):format(path, tostring(value), tostring(row.box:GetText()), want))
		end
	end
	reads("advanced.reciprocateWindow", "timing", "reciprocateWindow", 60, "1 min")
	reads("advanced.reciprocateWindow", "timing", "reciprocateWindow", 45, "45 s")
	reads("advanced.scanInterval", "timing", "scanInterval", 0.6, "0.6 s")
	reads("advanced.scanInterval", "timing", "scanInterval", 0.5, "0.5 s")
	reads("when.refreshRaid", "filters", "refreshRaid", 2, "2x")
	reads("when.refreshRaid", "filters", "refreshRaid", 2.5, "2.5x")
	reads("when.refreshUnder", "filters", "refreshUnder", 10, "10 min")
	reads("when.selfLead", "filters", "selfLead", 0, "Automatic")
	reads("when.selfLead", "filters", "selfLead", 0.5, "0.5 min")
	reads("when.manaFloor", "filters", "manaFloor", 30, "30%")
	reads("when.manaFloor", "filters", "manaFloor", 0, "Off")
end)

-- ------------------------------------------------------------------ 4
scenario = "menupass-words: a label that lost its unit has it in the tooltip"
for _, class in ipairs({ "MAGE", "HUNTER" }) do
	with(scenario, class, function(ns)
		local WANT = {
			reciprocateWindow = "second", graceSeconds = "second", retryCooldown = "second",
			scanInterval = "second", cureSeconds = "second", skipSeconds = "second",
			refreshUnder = "minute", quietShortMinutes = "minute", selfLead = "minute",
			ownSkipMinutes = "minute", manaFloor = "percent",
		}
		for key, word in pairs(WANT) do
			local node = findOption(ns.optionsTable, key)
			if node then
				local desc = text(node.desc)
				if not (desc and desc:lower():find(word, 1, true)) then
					fail(scenario, ("%s: %s's tooltip does not say %s (%q)"):format(class, key, word, tostring(desc)))
				end
			elseif class == "MAGE" and key ~= "cureSeconds" then
				fail(scenario, key .. " is not in the options")
			end
		end
	end)
end
