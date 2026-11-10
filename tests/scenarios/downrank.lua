-- A rank for a low-level target (GitHub issue 9). A macro's "/cast Arcane
-- Intellect" does not lower the rank for somebody too low a level for it the way
-- an action bar button does, so with rank 3 and somebody of level 17 the cast
-- was refused again and again. The macro now names the rank the game would land
-- on them (Core.lua, LandingRank: the best rank you know up to ten levels above
-- theirs), as the client writes it, "Arcane Intellect(Rank 2)". Only for a
-- single cast at somebody whose level the client says; anything else keeps the
-- plain name.
--
-- Every scenario name starts with "downrank:" so the mutations in
-- tests/mutations/downrank.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local ANNA = "Anna Aim"
local INTELLECT_RANKS = { [1459] = 1, [1460] = 2, [1461] = 3, [10156] = 4, [10157] = 5 }

-- A level-60 mage with Anna in the party at `level`, the client's rank text
-- there (`rankText`, on by default), the prompt on Anna. Hands `body` the addon
-- and a function that changes Anna's level.
local function party(scenario, rankText, body)
	Mock.reset()
	Mock.class = "MAGE"
	local savedLevel, savedText = rawget(_G, "UnitLevel"), rawget(_G, "GetSpellSubtext")
	local savedKnown, savedPlayer = rawget(_G, "IsSpellKnown"), rawget(_G, "IsPlayerSpell")
	local level = 60
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" } })
	local ok, err = pcall(function()
		-- Every rank of Arcane Intellect learned: the mock knows the first only.
		rawset(_G, "IsSpellKnown", function(id) return INTELLECT_RANKS[id] ~= nil end)
		rawset(_G, "IsPlayerSpell", _G.IsSpellKnown)
		rawset(_G, "UnitLevel", function(unit)
			if unit == "party1" then return level end
			return 60
		end)
		if rankText ~= false then
			rawset(_G, "GetSpellSubtext", function(id)
				local rank = INTELLECT_RANKS[id]
				return rank and ("Rank " .. rank) or ""
			end)
		end
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 2
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		body(ns, function(value) level = value end)
	end)
	restoreUnits()
	rawset(_G, "UnitLevel", savedLevel)
	rawset(_G, "GetSpellSubtext", savedText)
	rawset(_G, "IsSpellKnown", savedKnown)
	rawset(_G, "IsPlayerSpell", savedPlayer)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- What the prompt's button is armed to cast at Anna, nil when she is not on it.
local function castLine(ns)
	Mock.advance(5)
	ns.Prompt:Refresh()
	local showing = ns.Prompt.Showing and ns.Prompt:Showing()
	if not (showing and showing.name == ANNA) then return nil end
	local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
	return text:match("/cast ([^\n]*)")
end

local function check(scenario, level, want, ranks)
	party(scenario, ranks, function(ns, setLevel)
		setLevel(level)
		local line = castLine(ns)
		if line == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		if line ~= want then fail(scenario, ("level %d: the macro casts %q, wanted %q"):format(level, line, want)) end
	end)
end

check("downrank: level 30 gets rank 3", 30, "Arcane Intellect(Rank 3)")
check("downrank: level 12 gets rank 2", 12, "Arcane Intellect(Rank 2)")
check("downrank: level 1 gets rank 1", 1, "Arcane Intellect(Rank 1)")
check("downrank: somebody of level 60 keeps the plain name", 60, "Arcane Intellect")
check("downrank: the rank is the plain name once they are high enough for the top", 46, "Arcane Intellect")
check("downrank: no rank text from the client keeps the plain name", 12, "Arcane Intellect", false)

do
	local scenario = "downrank: a change of level rebuilds the macro"
	party(scenario, nil, function(ns, setLevel)
		setLevel(60)
		local first = castLine(ns)
		if first == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		if first ~= "Arcane Intellect" then fail(scenario, "level 60 was cast as " .. first) end
		setLevel(30)
		local line = castLine(ns)
		if line ~= "Arcane Intellect(Rank 3)" then
			fail(scenario, "after she dropped to level 30 the macro casts " .. tostring(line))
		end
	end)
end

do
	local scenario = "downrank: a level the client will not say keeps the plain name"
	party(scenario, nil, function(ns, setLevel)
		rawset(_G, "UnitLevel", function(unit)
			if unit == "party1" then return Mock.SECRET end
			return 60
		end)
		local line = castLine(ns)
		if line == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		if line ~= "Arcane Intellect" then fail(scenario, "a secret level was cast as " .. line) end
	end)
end

do
	local scenario = "downrank: a skull keeps the plain name"
	party(scenario, nil, function(ns, setLevel)
		setLevel(-1)
		local line = castLine(ns)
		if line == nil then
			fail(scenario, "SKIPPED -- Anna was not on the prompt")
			return
		end
		if line ~= "Arcane Intellect" then fail(scenario, "a skull was cast as " .. line) end
	end)
end

do
	local scenario = "downrank: the line is never longer than the macro allows"
	party(scenario, nil, function(ns, setLevel)
		setLevel(12)
		castLine(ns)
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1") or ""
		if #text > ns.MACRO_LIMIT then fail(scenario, "the macro is " .. #text .. " characters") end
	end)
end
