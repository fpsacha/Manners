-- The Diagnostics tab of the options page (Options.lua, BuildDiagnosticsTab):
-- what Manners is doing, and why. Four sections: the chat messages it can
-- print for you, what it can see on this client (and how it is measuring a
-- passer-by's distance), the errors this session, and the bug report.
--
-- The tab is read through ns.optionsTable, the table AceConfig is handed, so a
-- label here is the label on the page.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive
local optionText = H.optionText

local function noErrors(scenario, ns)
	for _, e in ipairs(ns.errors or {}) do
		fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
	end
end

local function text(value)
	if type(value) == "function" then value = value() end
	return tostring(value or "")
end

local function hidden(option)
	local h = option.hidden
	if type(h) == "function" then return h() == true end
	return h == true
end

-- The tab itself, or nil after saying why.
local function tab(scenario, ns)
	local t = ns.optionsTable and ns.optionsTable.args and ns.optionsTable.args.diagnostics
	if not t then fail(scenario, "SKIPPED -- there is no diagnostics tab") end
	return t
end

local function session(scenario, setup)
	Mock.reset()
	if setup then setup() end
	local ns = load(scenario)
	if not ns then return nil end
	drive(scenario, ns)
	ns.Prompt:ExitTest()
	return ns
end

-- ------------------------------------------------------------------ 1
-- The tab, its four sections in order, and the two chat switches living on it
-- rather than on General.
do
	local scenario = "diagnostics: four sections, chat switches on this tab"
	local ns = session(scenario)
	local t = ns and tab(scenario, ns)
	if t then
		if text(t.name) ~= "Diagnostics" then
			fail(scenario, "the tab is called " .. text(t.name))
		end
		if t.order ~= 7 then
			fail(scenario, "the tab is at order " .. tostring(t.order))
		end
		local want = {
			{ "chatHeader", "Messages in chat", 1 },
			{ "capsHeader", "What Manners can see", 10 },
			{ "errorsHeader", "Errors this session", 20 },
			{ "reportHeader", "Reporting a bug", 30 },
		}
		for _, w in ipairs(want) do
			local h = t.args[w[1]]
			if not h then
				fail(scenario, "no " .. w[1] .. " on the tab")
			elseif h.type ~= "header" or text(h.name) ~= w[2] or h.order ~= w[3] then
				fail(scenario, ("%s reads %q at order %s"):format(w[1], text(h.name),
					tostring(h.order)))
			end
		end

		local verbose, clicks = t.args.verbose, t.args.debugClicks
		if not (verbose and clicks) then
			fail(scenario, "the chat switches are not on the Diagnostics tab")
		else
			if text(verbose.name) ~= "Tell me in chat what Manners is doing" then
				fail(scenario, "the verbose switch reads " .. text(verbose.name))
			end
			if not text(verbose.desc):find("Only you see these", 1, true) then
				fail(scenario, "the verbose switch does not say only you see it: "
					.. text(verbose.desc))
			end
			if text(clicks.name) ~= "Log every click (noisy)" then
				fail(scenario, "the click log reads " .. text(clicks.name))
			end
			if not text(clicks.desc):find("why a cast failed", 1, true) then
				fail(scenario, "the click log does not say what it is for: " .. text(clicks.desc))
			end
			if not (verbose.order > 1 and verbose.order < 10 and clicks.order > verbose.order
				and clicks.order < 10) then
				fail(scenario, "the chat switches are not under Messages in chat")
			end

			-- The same saved keys as ever.
			local profile = ns.db.profile
			local was = profile.verbose
			verbose.set({ "verbose" }, not was)
			if profile.verbose ~= not was or verbose.get({ "verbose" }) ~= not was then
				fail(scenario, "the verbose switch does not write profile.verbose")
			end
			verbose.set({ "verbose" }, was)
			clicks.set({ "debugClicks" }, true)
			if profile.debugClicks ~= true or clicks.get({ "debugClicks" }) ~= true then
				fail(scenario, "the click log does not write profile.debugClicks")
			end
			clicks.set({ "debugClicks" }, false)
			if profile.debugClicks ~= false then
				fail(scenario, "the click log cannot be switched off")
			end
		end
		noErrors(scenario, ns)
	end
end

-- ------------------------------------------------------------------ 2
-- What Manners can see: the class in words, each spell learned or not, and
-- whether Manners can see who has it.
do
	local scenario = "diagnostics: says what Manners can see in plain words"
	local realNames = LOCALIZED_CLASS_NAMES_MALE
	local ns = session(scenario)
	local t = ns and tab(scenario, ns)
	if t then
		local diag = t.args.diag
		if not diag or hidden(diag) then
			fail(scenario, "SKIPPED -- a mage sees no capability list")
		else
			LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Magier" }
			local said = optionText(diag.name)
			if not said:find("Magier", 1, true) then
				fail(scenario, "the class is not given in the client's words: " .. said)
			end
			LOCALIZED_CLASS_NAMES_MALE = nil
			said = optionText(diag.name)
			if not said:find("MAGE", 1, true) then
				fail(scenario, "with no class names the class is not shown at all: " .. said)
			end
			if not said:find("learned: ", 1, true) then
				fail(scenario, "the spell lines do not say whether it is learned: " .. said)
			end
			if not said:find("can see who has it: |cff00ff00yes|r", 1, true) then
				fail(scenario, "a readable buff does not read can see who has it: yes: " .. said)
			end
			if said:find("missing-check", 1, true) then
				fail(scenario, "the page still speaks of a missing-check: " .. said)
			end
			if not said:find("Where Manners cannot see a buff, people are still offered,"
				.. " but some may already have it.", 1, true) then
				fail(scenario, "the footnote is missing: " .. said)
			end
		end
		noErrors(scenario, ns)
	end
	LOCALIZED_CLASS_NAMES_MALE = realNames
end

do
	local scenario = "diagnostics: a buff Manners cannot see reads no"
	local ns = session(scenario, function() Mock.allSecret = true end)
	local t = ns and tab(scenario, ns)
	if t then
		ns.Guard("probe", ns.ProbeCapabilities)
		local diag = t.args.diag
		if not diag or hidden(diag) then
			fail(scenario, "SKIPPED -- a mage sees no capability list")
		else
			local said = optionText(diag.name)
			if not said:find("can see who has it: |cffff8080no|r", 1, true) then
				fail(scenario, "every aura secret, and no spell reads can see who has it: no: "
					.. said)
			end
			if said:find("can see who has it: |cff00ff00yes|r", 1, true) then
				fail(scenario, "every aura secret, and a spell still reads yes: " .. said)
			end
		end
	end
	Mock.allSecret = false
end

-- ------------------------------------------------------------------ 3
-- The passer-by distance line: what is measuring, shown on this tab, and
-- nothing at all for a class whose buffs never reach a passer-by.
do
	local scenario = "diagnostics: says how passer-by distance is measured"
	local ns = session(scenario)
	local t = ns and tab(scenario, ns)
	if t then
		local line = t.args.proximityDiag
		if not line then
			fail(scenario, "there is no passer-by distance line on the tab")
		elseif line.type ~= "description" then
			fail(scenario, "the passer-by distance line is a " .. tostring(line.type))
		else
			if hidden(line) then
				fail(scenario, "a mage, whose buffs reach passers-by, is not shown the distance")
			end
			if not (line.order > 10 and line.order < 20) then
				fail(scenario, "the distance line is not under What Manners can see")
			end
			local said = optionText(line.name)
			local summary = tostring(ns.ProximitySummary())
			if not said:find("Passer-by distance: " .. summary, 1, true) then
				fail(scenario, "the line does not give the measurement: " .. said
					.. " (expected " .. summary .. ")")
			end
		end
		noErrors(scenario, ns)
	end
end

do
	local scenario = "diagnostics: a warrior is not shown passer-by distance"
	local realKnown, realPlayer = IsSpellKnown, IsPlayerSpell
	Mock.reset()
	Mock.class = "WARRIOR"
	local ns = load(scenario)
	if ns then
		local known = {}
		for _, id in ipairs(ns.FindBuff("WARRIOR", "battleshout").ranks) do known[id] = true end
		IsSpellKnown = function(id) return known[id] == true end
		IsPlayerSpell = IsSpellKnown
		drive(scenario, ns)
		ns.Guard("probe", ns.ProbeCapabilities)
		local t = tab(scenario, ns)
		local line = t and t.args.proximityDiag
		if not ns.OnlyReachesGroup() then
			fail(scenario, "SKIPPED -- the shout is not the only thing on offer")
		elseif not line then
			fail(scenario, "there is no passer-by distance line on the tab")
		elseif not hidden(line) then
			fail(scenario, "a shout that never reaches a passer-by is shown passer-by distance: "
				.. optionText(line.name))
		end
		noErrors(scenario, ns)
	end
	IsSpellKnown, IsPlayerSpell = realKnown, realPlayer
end

-- ------------------------------------------------------------------ 4
-- Errors this session: a plain line when nothing has gone wrong.
do
	local scenario = "diagnostics: says plainly when nothing has gone wrong"
	local ns = session(scenario)
	local t = ns and tab(scenario, ns)
	if t then
		local none, list = t.args.noErrors, t.args.errorList
		if not (none and list) then
			fail(scenario, "the error lines are not on the tab")
		else
			if hidden(none) then
				fail(scenario, "no errors, and the page does not say so")
			end
			if text(none.name) ~= "Nothing has gone wrong this session." then
				fail(scenario, "the no-errors line reads " .. text(none.name))
			end
			if not (none.order > 20 and none.order < 30 and list.order > 20
				and list.order < 30) then
				fail(scenario, "the error lines are not under Errors this session")
			end
		end
		noErrors(scenario, ns)
	end
end
