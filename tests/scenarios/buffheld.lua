-- This buff on this person, not the person (1.11.14). When the game says
-- "A more powerful spell is already active" (a campfire's buff, say, which no
-- aura read of ours knows to hold the buff off) or "Target is too low level",
-- retrying in two seconds never helps. That buff is held off that person for
-- ten minutes (Queue.lua, NoteRefusal), their other buffs and everybody else
-- stay as they were, and the refusal does not count towards backing the person
-- off from everything. Also the mage's scrolls on Forever count as consumables
-- (Core.lua, OwnItemsHeldToDungeons), and a right-click's own length
-- (Queue.lua, SkipSeconds).
--
-- Every scenario name starts with "buffheld:" so the mutations in
-- tests/mutations/buffheld.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local ANNA, BERT = "Anna Aim", "Bert Beside"
local BOUNCED = "A more powerful spell is already active"
local LOWLEVEL = "Target is too low level"

local function party(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	local had = { bounced = rawget(_G, "SPELL_FAILED_AURA_BOUNCED"), low = rawget(_G, "SPELL_FAILED_LOWLEVEL") }
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", BOUNCED)
	rawset(_G, "SPELL_FAILED_LOWLEVEL", LOWLEVEL)
	local restoreUnits = strangers({ party1 = { "Anna", "Aim" }, party2 = { "Bert", "Beside" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		Mock.groupSize = 3
		freshPrompt(ns, scenario)
		Mock.runTimers(0)
		ns.Prompt:ExitTest()
		body(ns)
	end)
	restoreUnits()
	rawset(_G, "SPELL_FAILED_AURA_BOUNCED", had.bounced)
	rawset(_G, "SPELL_FAILED_LOWLEVEL", had.low)
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "buffheld: a stronger buff already on them holds that buff off for ten minutes"
	party(scenario, function(ns)
		ns.NoteRefusal(ANNA, BOUNCED .. ".", nil, true, "intellect")
		Mock.advance(300)
		if not ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "five minutes after 'a more powerful spell is already active', the buff was offered again")
		end
		Mock.advance(310)
		if ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "ten minutes on, the buff was still held off")
		end
	end)
end

do
	local scenario = "buffheld: only that buff, only that person"
	party(scenario, function(ns)
		ns.NoteRefusal(ANNA, BOUNCED .. ".", nil, true, "intellect")
		Mock.advance(5)
		if ns.IsBlocked(ANNA, "frostarmor", GetTime()) then
			fail(scenario, "another buff on the same person was held off")
		end
		if ns.IsBlocked(BERT, "intellect", GetTime()) then
			fail(scenario, "somebody else was held off the same buff")
		end
	end)
end

do
	local scenario = "buffheld: it does not count towards backing the person off"
	party(scenario, function(ns)
		for _ = 1, 4 do ns.NoteRefusal(ANNA, BOUNCED .. ".", nil, true, "intellect") end
		Mock.advance(5)
		if ns.IsBlocked(ANNA, "frostarmor", GetTime()) then
			fail(scenario, "four stronger-buff refusals backed Anna off from everything")
		end
	end)
end

do
	local scenario = "buffheld: too low a level holds that buff off too"
	party(scenario, function(ns)
		ns.NoteRefusal(ANNA, LOWLEVEL .. ".", nil, true, "intellect")
		Mock.advance(300)
		if not ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "five minutes after 'target is too low level', the buff was offered again")
		end
	end)
end

do
	local scenario = "buffheld: any other refusal still backs the person off as before"
	party(scenario, function(ns)
		ns.NoteRefusal(BERT, "Something else.", nil, true, "intellect")
		ns.NoteRefusal(BERT, "Something else.", nil, true, "intellect")
		Mock.advance(5)
		if not ns.IsBlocked(BERT, "frostarmor", GetTime()) then
			fail(scenario, "two plain refusals in a row no longer back the person off")
		end
	end)
end

do
	-- Re-aimed by the right-buff audit. This held that a refused group cast kept
	-- the single buff off everybody it covered ("a group cast holds the buff
	-- off everyone it covered"): one member too low for Arcane Brilliance, or
	-- wearing something stronger, cost the whole party its Intellect for ten
	-- minutes. What cannot land is the group version aimed at that one, so that
	-- is what is held, off them as the one a group cast is aimed at; nobody's
	-- single buff is.
	local scenario = "buffheld: a refused group cast holds the group version, and the single buff off nobody"
	party(scenario, function(ns)
		ns.NoteRefusal(ANNA, BOUNCED .. ".", nil, true, "intellect", { BERT })
		Mock.advance(5)
		if ns.IsBlocked(BERT, "intellect", GetTime()) then
			fail(scenario, "Bert, covered by the same cast, is held off the single buff")
		end
		if ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "Anna, whom the group cast was aimed at, is held off the single buff")
		end
		if not ns.IsBlocked(ANNA, "intellect" .. ns.GROUP_HOLD, GetTime()) then
			fail(scenario, "the group version is not held off Anna as the one it is aimed at")
		end
		Mock.advance(610)
		if ns.IsBlocked(ANNA, "intellect" .. ns.GROUP_HOLD, GetTime()) then
			fail(scenario, "ten minutes on, the group version is still held off her")
		end
	end)
end

do
	local scenario = "buffheld: a mage's scrolls count as consumables"
	Mock.reset()
	Mock.class = "MAGE"
	local ns = load(scenario)
	if ns then
		local found = 0
		for _, family in ipairs(ns.GetOwnFamilies("MAGE") or {}) do
			if family.isScroll then
				found = found + 1
				if not ns.OwnItemsHeldToDungeons(family) then
					fail(scenario, tostring(family.key) .. " is not held back to dungeons and raids")
				end
			end
		end
		if found == 0 then fail(scenario, "SKIPPED -- this client has no scroll family for a mage") end
	end
end

do
	local scenario = "buffheld: a right-click's length is its own setting"
	party(scenario, function(ns)
		local timing = ns.db.profile.timing
		if timing.skipSeconds ~= 12 then fail(scenario, "the default is " .. tostring(timing.skipSeconds)) end
		timing.retryCooldown = 5
		timing.skipSeconds = 900
		if ns.SkipSeconds() ~= 900 then fail(scenario, "SkipSeconds is " .. tostring(ns.SkipSeconds())) end
		ns.BlockPerson(ANNA, ns.SkipSeconds())
		Mock.advance(600)
		if not ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "ten minutes into a fifteen-minute skip, Anna was offered again")
		end
		Mock.advance(310)
		if ns.IsBlocked(ANNA, "intellect", GetTime()) then
			fail(scenario, "a skip outlasted its setting")
		end
		timing.skipSeconds = 99999
		ns.ClampSettings()
		if timing.skipSeconds ~= 1800 then fail(scenario, "the length is not capped: " .. tostring(timing.skipSeconds)) end
	end)
end

do
	local scenario = "buffheld: a right-click on the prompt skips for that long"
	party(scenario, function(ns)
		ns.db.profile.timing.skipSeconds = 600
		ns.db.profile.timing.retryCooldown = 5
		Mock.advance(5)
		ns.Prompt:Refresh()
		local showing = ns.Prompt.Showing and ns.Prompt:Showing()
		if not (showing and showing.name and showing.buff) then
			fail(scenario, "SKIPPED -- nobody was on the prompt")
			return
		end
		H.pressButton(ns, "RightButton")
		Mock.advance(300)
		if not ns.IsBlocked(showing.name, showing.buff.key, GetTime()) then
			fail(scenario, "five minutes into a ten-minute skip, " .. showing.name .. " was offered again")
		end
	end)
end

do
	local scenario = "buffheld: a skip has a slider on When to offer"
	party(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "skipSeconds")
		if not control then
			fail(scenario, "no setting for how long a right-click skips")
			return
		end
		if control.type ~= "range" or control.max ~= 1800 then fail(scenario, "the setting is not a slider up to 1800") end
	end)
end
