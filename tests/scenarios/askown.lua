-- My own words for an ask (Ask.lua, ask.line "own" and ask.own; asked for on
-- CurseForge): the player writes what the ask says, {name} and {buff} as in
-- the plain lines, either left out; said even with the In character set on;
-- empty, the first plain line.
--
-- Every scenario name starts with "askown:" so the mutations in
-- tests/mutations/askown.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

local TOUCHED = { "IsResting", "UnitAffectingCombat" }

local function with(scenario, body)
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	rawset(_G, "IsResting", function() return false end)
	rawset(_G, "UnitAffectingCombat", function() return false end)
	Mock.reset()
	Mock.class = "WARRIOR"
	Mock.unitClass = "PRIEST"
	Mock.playerHeld = {}
	local undo = strangers({ nameplate1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		ns.db.profile.sources.ask = true
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

local function macroFor(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.ask then return (ns.Ask.MacroFor(entry, {})) end
	end
	return nil
end

local function fortitude(ns)
	return ns.SpellNameFor(ns.FindBuff("PRIEST", "fortitude").ranks[1])
end

-- ------------------------------------------------------------------ 1
do
	local scenario = "askown: my own words are what the ask says, with no name when I leave it out"
	with(scenario, function(ns)
		local spell = fortitude(ns)
		local ask = ns.db.profile.ask
		if ns.defaults.profile.ask.own ~= "" then fail(scenario, "own words are not empty out of the box") end
		ask.line = "own"
		ask.own = "Hey, could I get {buff}? Cheers!"
		local want = "/w Anna Aim Hey, could I get " .. spell .. "? Cheers!"
		local got = macroFor(ns)
		if got ~= want then fail(scenario, "the ask is |" .. tostring(got) .. "|, not |" .. want .. "|") end
		-- The In character set does not talk over what the player wrote.
		ns.db.profile.speech.presetChoice = "incharacter"
		ns.db.profile.speech.phrases = ns.PhraseSetText("incharacter")
		got = macroFor(ns)
		if got ~= want then fail(scenario, "with In character the ask is |" .. tostring(got) .. "|") end
	end)
end

-- ------------------------------------------------------------------ 2
do
	local scenario = "askown: empty own words say the first line"
	with(scenario, function(ns)
		local spell = fortitude(ns)
		local ask = ns.db.profile.ask
		ask.line = "own"
		ask.own = ""
		local want = "/w Anna Aim " .. ns.Ask.LINES.moment:gsub("{name}", "Anna Aim"):gsub("{buff}", spell)
		local got = macroFor(ns)
		if got ~= want then fail(scenario, "the ask is |" .. tostring(got) .. "|, not |" .. want .. "|") end
	end)
end

-- ------------------------------------------------------------------ 3
do
	local scenario = "askown: the repair keeps my own words, on one line and with no |"
	with(scenario, function(ns)
		local ask = ns.db.profile.ask
		ask.line = "own"
		ask.own = "  Hi {name},\nmay I have |cffff0000{buff}|r?  "
		ns.AskClamp(ns.db.profile)
		if ask.line ~= "own" then fail(scenario, "the repair turned the choice into " .. tostring(ask.line)) end
		if ask.own ~= "Hi {name}, may I have cffff0000{buff}r?" then
			fail(scenario, "the repair left |" .. tostring(ask.own) .. "|")
		end
		ask.own = string.rep("a", 300)
		ns.AskClamp(ns.db.profile)
		if #ask.own ~= ns.Ask.OWN_MAX then fail(scenario, "own words of " .. #ask.own .. " letters kept") end
	end)
end

-- ------------------------------------------------------------------ 4
do
	local scenario = "askown: the box is shown only while my own words are chosen"
	with(scenario, function(ns)
		local line = findOption(ns.optionsTable, "askLine")
		local box = findOption(ns.optionsTable, "askOwn")
		if not (line and box) then fail(scenario, "no What the ask says, or no box for my own words") return end
		local values = type(line.values) == "function" and line.values() or line.values
		if not (values and values.own) then fail(scenario, "What the ask says has no My own words") end
		ns.db.profile.ask.line = "moment"
		if not box.hidden() then fail(scenario, "the box shows with a plain line chosen") end
		ns.db.profile.ask.line = "own"
		if box.hidden() then fail(scenario, "the box is hidden with my own words chosen") end
		box.set(nil, "Buff me, {name}|r\n")
		if ns.db.profile.ask.own ~= "Buff me, {name}r" then
			fail(scenario, "the box saved |" .. tostring(ns.db.profile.ask.own) .. "|")
		end
	end)
end
