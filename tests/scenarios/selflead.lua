-- Remind me this many minutes early (filters.selfLead), exact from 1.11.15. A
-- player on CurseForge was told about his Fortitude fifteen minutes before it
-- ended and his weapon oil at eight, and the slider could only move that
-- earlier. Now any number set is the moment itself, for your own buffs alone:
-- later than the worked-out one as well as earlier, the same in a dungeon or a
-- raid, in half minutes (0.5 is thirty seconds), never past half the buff's
-- length. 0 is the worked-out moment, as before.
--
-- Every scenario name starts with "selflead:" so the mutations in
-- tests/mutations/selflead.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, findOption = H.strangers, H.freshPrompt, H.findOption

-- Thorns, ten minutes long (playerHeldDuration). Worked out, yours is topped
-- up at 90 s left (a tenth, half as much again), 180 s in a dungeon.
local THORNS = 467

local function wear(ns, ids)
	Mock.playerHeld = ids
	ns.ForgetUnitAuras(ns.plain(UnitGUID("player")))
end

local function thorns(ns)
	for _, entry in ipairs(ns.BuildQueue()) do
		if entry.reason == "self" then return entry.buff and entry.buff.key == "thorns" end
	end
	return false
end

-- A druid who knows Thorns and wears it with `left` seconds to run, nobody
-- else about. `inside` puts him in a dungeon.
local function with(scenario, body)
	Mock.reset()
	Mock.class = "DRUID"
	local saved = {}
	for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell", "IsInInstance" }) do saved[name] = rawget(_G, name) end
	IsSpellKnown = function(id) return id == THORNS end
	IsPlayerSpell = IsSpellKnown
	local undo = strangers({})
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		freshPrompt(ns, scenario)
		Mock.playerHeldDuration = 600
		local function at(left, inside)
			rawset(_G, "IsInInstance", function() return inside == true, inside and "party" or "none" end)
			Mock.playerHeldFor = left
			Mock.advance(1)
			wear(ns, { [THORNS] = true })
			return thorns(ns)
		end
		body(ns, ns.db.profile.filters, at)
	end)
	undo()
	-- By name: pairs would skip one that was nil to begin with, and leave ours.
	for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell", "IsInInstance" }) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

do
	local scenario = "selflead: 0 is the worked-out moment, as before"
	with(scenario, function(ns, f, at)
		if f.selfLead ~= 0 then fail(scenario, "a new profile does not start at 0") end
		if at(120) then fail(scenario, "Thorns with 120 s left was topped up on the worked-out moment") end
		if not at(80) then fail(scenario, "Thorns with 80 s left was not topped up on the worked-out moment") end
	end)
end

do
	local scenario = "selflead: half a minute is half a minute, later than the worked-out moment"
	with(scenario, function(ns, f, at)
		f.selfLead = 0.5
		if at(80) then fail(scenario, "half a minute asked for, Thorns with 80 s left was topped up") end
		if not at(25) then fail(scenario, "half a minute asked for, Thorns with 25 s left was not topped up") end
	end)
end

do
	local scenario = "selflead: the moment asked for holds in a dungeon too"
	with(scenario, function(ns, f, at)
		if not at(150, true) then
			fail(scenario, "SKIPPED -- in a dungeon, Thorns with 150 s left was not topped up on the worked-out moment")
			return
		end
		f.selfLead = 1
		if at(100, true) then fail(scenario, "one minute asked for, in a dungeon Thorns with 100 s left was topped up") end
		if not at(50, true) then fail(scenario, "one minute asked for, in a dungeon Thorns with 50 s left was not topped up") end
	end)
end

do
	local scenario = "selflead: earlier still works, up to half the buff's length"
	with(scenario, function(ns, f, at)
		f.selfLead = 4
		if not at(200) then fail(scenario, "four minutes asked for, Thorns with 200 s left was not topped up") end
		f.selfLead = 10
		if at(400) then fail(scenario, "ten minutes asked of a ten-minute buff, it was topped up past half its length") end
	end)
end

do
	local scenario = "selflead: the slider goes in half minutes and a hand-edited value is kept to them"
	with(scenario, function(ns, f)
		local option = findOption(ns.optionsTable, "selfLead")
		if not option or option.step ~= 0.5 then
			fail(scenario, "the slider's step is " .. tostring(option and option.step))
		end
		f.selfLead = 0.5
		ns.ClampSettings()
		if f.selfLead ~= 0.5 then fail(scenario, "half a minute was not kept: " .. tostring(f.selfLead)) end
		f.selfLead = 2.7
		ns.ClampSettings()
		if f.selfLead ~= 2.5 then fail(scenario, "2.7 was kept as " .. tostring(f.selfLead)) end
	end)
end
