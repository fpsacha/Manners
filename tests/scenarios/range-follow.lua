-- Somebody too far for the spell, on a client whose range check has nothing to
-- say about it. The follow prompt (about 28 yards) is asked as a second
-- opinion, and only its no counts (Core.lua, ns.PastFollowReach). Once the game
-- itself has answered "Out of range" they stay off the prompt for ten seconds
-- (Queue.lua, NoteRefusal).
--
-- Every scenario name starts with "range-follow:" so the mutations in
-- tests/mutations/range-follow.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local ANNA, BERT = "Anna Aim", "Bert Beside"

local function entryFor(ns, name)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.name == name then return entry end
	end
	return nil
end

-- A party of two with the spell's range check silent: Anna sixty yards off,
-- Bert five. `before` runs ahead of the addon's load. Hands `body` the addon.
local function party(scenario, before, body)
	Mock.reset()
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } })
	local ok, err = pcall(function()
		if before then before() end
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 3
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		ns.db.profile.sources.strangers = false
		Mock.rangeless = {}
		for _, id in ipairs(ns.FindBuff("MAGE", "intellect").ranks) do Mock.rangeless[id] = true end
		Mock.yards = { party1 = 60, party2 = 5 }
		body(ns)
	end)
	restoreUnits()
	Mock.inCombat = false
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "range-follow: past the follow prompt is not offered when the spell will not say"
	party(scenario, nil, function(ns)
		if not entryFor(ns, BERT) then
			fail(scenario, "SKIPPED -- Bert, five yards away, was not offered")
			return
		end
		if entryFor(ns, ANNA) then fail(scenario, "Anna, sixty yards away, was offered") end
		owe(ns, ANNA)
		if entryFor(ns, ANNA) then fail(scenario, "a favour put Anna, sixty yards away, on the prompt") end
		if not ns.owed[ANNA] then fail(scenario, "being far away wrote off the favour") end
		Mock.yards.party1 = 5
		if not entryFor(ns, ANNA) then fail(scenario, "Anna came back within reach and was not offered") end
	end)
end

do
	local scenario = "range-follow: the follow prompt's silence is still offered"
	party(scenario, nil, function(ns)
		Mock.interact = "restricted"
		if not entryFor(ns, ANNA) then
			fail(scenario, "nothing said Anna was far and she was dropped all the same")
		end
	end)
end

do
	local scenario = "range-follow: Skip players out of range switched off offers them"
	party(scenario, nil, function(ns)
		ns.db.profile.filters.requireInRange = false
		if not entryFor(ns, ANNA) then fail(scenario, "the switch is off and Anna was dropped") end
	end)
end

do
	local scenario = "range-follow: the press hears it too"
	party(scenario, nil, function(ns)
		local buff = ns.FindBuff("MAGE", "intellect")
		if ns.ReachNow("party1", buff) ~= false then
			fail(scenario, "the press read Anna, sixty yards away, as " .. tostring(ns.ReachNow("party1", buff)))
		end
		if ns.ReachNow("party2", buff) == false then fail(scenario, "the press read Bert as out of reach") end
	end)
end

do
	local scenario = "range-follow: only WoW Forever asks the follow prompt"
	party(scenario, function() Mock.setFlavour("mists") end, function(ns)
		if ns.PastFollowReach("party1") ~= nil then
			fail(scenario, "Mists read Anna past the follow prompt, inside a spell's 40 yards")
		end
	end)
end

do
	local scenario = "range-follow: nothing is asked of the follow prompt in a fight"
	party(scenario, nil, function(ns)
		Mock.inCombat = true
		local before = Mock.counts.interact
		local said = ns.PastFollowReach("party1")
		if said ~= nil then fail(scenario, "a fight was answered " .. tostring(said)) end
		if Mock.counts.interact ~= before then fail(scenario, "the follow prompt was asked in a fight") end
	end)
end

do
	local scenario = "range-follow: refused out of range stays off the prompt for ten seconds"
	local had = rawget(_G, "ERR_OUT_OF_RANGE")
	rawset(_G, "ERR_OUT_OF_RANGE", "Out of range")
	party(scenario, nil, function(ns)
		local buffKey = "intellect"
		ns.NoteRefusal(ANNA, "Out of range.")
		Mock.advance(5)
		if not ns.IsBlocked(ANNA, buffKey, GetTime()) then
			fail(scenario, "five seconds after the game said out of range, Anna was offered again")
		end
		Mock.advance(6)
		if ns.IsBlocked(ANNA, buffKey, GetTime()) then
			fail(scenario, "eleven seconds on, Anna was still held back")
		end
		ns.NoteLanded(BERT)
		ns.NoteRefusal(BERT, "Something else.")
		Mock.advance(5)
		if ns.IsBlocked(BERT, buffKey, GetTime()) then
			fail(scenario, "another refusal took the ten seconds too")
		end
	end)
	rawset(_G, "ERR_OUT_OF_RANGE", had)
end
