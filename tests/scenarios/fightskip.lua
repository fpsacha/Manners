-- Skip players in a fight (filters.skipFighting, off; asked for on
-- CurseForge): a buff on somebody fighting pulls you into the fight. With the
-- switch on, nobody the game says is in a fight is offered anything, whatever
-- the reason, but your target or focus; the fight's end offers them again
-- (Queue.lua, "in a fight").
--
-- Every scenario name starts with "fightskip:" so the mutations in
-- tests/mutations/fightskip.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local ANNA, BERT = "Anna Aim", "Bert Beside"

local TOUCHED = { "UnitAffectingCombat" }

local function with(scenario, opts, body)
	Mock.reset()
	if opts.groupSize then Mock.groupSize = opts.groupSize end
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local undo = strangers(opts.people or {})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	undo()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- One scan: this person's entry (or nil) and whether the scan wrote a verdict.
local function look(ns, name)
	local queue, rejected = ns.BuildQueue()
	local found
	for _, entry in ipairs(queue) do
		if entry.name == name then found = entry end
	end
	local verdict = rejected == true or (type(rejected) == "table" and rejected[name] == true)
	return found, verdict
end

-- The game says these tokens are in a fight; nil puts the world at peace.
local function fighting(tokens)
	if not tokens then
		rawset(_G, "UnitAffectingCombat", function() return false end)
		return
	end
	rawset(_G, "UnitAffectingCombat", function(unit) return tokens[unit] == true end)
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "fightskip: a passer-by in a fight is left alone only with the switch on"
	with(scenario, { people = { nameplate1 = { "Anna", "Aim" }, nameplate2 = { "Bert", "Beside" } } },
		function(ns)
			if ns.db.profile.filters.skipFighting ~= false then
				fail(scenario, "Skip players in a fight is not off by default")
			end
			fighting(nil)
			if not (look(ns, ANNA) and look(ns, BERT)) then
				fail(scenario, "SKIPPED -- the two passers-by were not both offered at peace")
				return
			end
			fighting({ nameplate1 = true })
			if not look(ns, ANNA) then
				fail(scenario, "a passer-by in a fight was held back with the switch off")
			end
			ns.db.profile.filters.skipFighting = true
			local anna, verdict = look(ns, ANNA)
			if anna then fail(scenario, "a passer-by in a fight was offered with the switch on") end
			if not verdict then fail(scenario, "holding them back is no verdict, so memory offers them") end
			if not look(ns, BERT) then fail(scenario, "a passer-by at peace was held back too") end
			fighting(nil)
			if not look(ns, ANNA) then fail(scenario, "the fight's end does not offer them again") end
		end)
end

-- ------------------------------------------------------------------ 2
for _, case in ipairs({
	{ label = "a group member", people = { party1 = { "Anna", "Aim" } }, token = "party1", groupSize = 2 },
}) do
	local scenario = "fightskip: " .. case.label .. " in a fight is left alone"
	with(scenario, { people = case.people, groupSize = case.groupSize }, function(ns)
		ns.db.profile.filters.skipFighting = true
		fighting(nil)
		if not look(ns, ANNA) then
			fail(scenario, "SKIPPED -- Anna was not offered as " .. case.label .. " at peace")
			return
		end
		fighting({ [case.token] = true })
		if look(ns, ANNA) then fail(scenario, case.label .. " in a fight was offered") end
	end)
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "fightskip: your target in a fight is still offered"
	with(scenario, { people = { target = { "Anna", "Aim" } } }, function(ns)
		ns.db.profile.filters.skipFighting = true
		fighting(nil)
		if not look(ns, ANNA) then
			fail(scenario, "SKIPPED -- your target was not offered at peace")
			return
		end
		fighting({ target = true })
		if not look(ns, ANNA) then fail(scenario, "your target in a fight was held back") end
	end)
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "fightskip: the switch is on Who to skip"
	with(scenario, {}, function(ns)
		local option = findOption(ns.optionsTable, "skipFighting")
		if not option then fail(scenario, "no Skip players in a fight control") return end
		if option.type ~= "toggle" then fail(scenario, "the control is a " .. tostring(option.type)) end
	end)
end
