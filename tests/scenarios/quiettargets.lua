-- Hold back my target and focus too (1.11.14). "Offer nothing in cities and
-- inns" and "Offer nothing in dungeons, raids and battlegrounds" leave the
-- person you target or focus alone, because you picked them on purpose. A
-- player on GitHub (issue 8) wanted no offers at all in a city: with this switch
-- on they are held back too. Off by default; out in the world nothing changes.
--
-- Every scenario name starts with "quiettargets:" so the mutations in
-- tests/mutations/quiettargets.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt = H.strangers, H.freshPrompt

local TOUCHED = { "IsInInstance", "UnitInParty", "IsResting" }

-- One session as a mage with a passer-by, a party member and a target, inside
-- an instance or not (`state.inside`).
local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local state = { inside = false, resting = false }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsInInstance", function()
			return state.inside, state.inside and "party" or "none"
		end)
		rawset(_G, "IsResting", function() return state.resting end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns, state)
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

local function named(first, last)
	return Mock.surnames and (first .. " " .. last) or first
end

local function names(ns)
	Mock.advance(4)
	local out = {}
	for _, entry in ipairs(ns.BuildQueue()) do out[#out + 1] = entry.name end
	table.sort(out)
	return table.concat(out, ",")
end

do
	local scenario = "quiettargets: off by default, the target is still offered inside"
	with(scenario, function(ns, state)
		if ns.db.profile.filters.quietTargets ~= false then fail(scenario, "the setting is not off by default") end
		ns.db.profile.filters.quietInInstances = true
		state.inside = true
		if not names(ns):find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the target was dropped inside with the new switch off: " .. names(ns))
		end
	end)
end

do
	local scenario = "quiettargets: on, the target is held back inside an instance"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInInstances = true
		ns.db.profile.filters.quietTargets = true
		state.inside = true
		local out = names(ns)
		if out ~= "" then fail(scenario, "somebody was offered inside with the target held back too: " .. out) end
	end)
end

do
	local scenario = "quiettargets: on, the target is held back in a city"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInTowns = true
		ns.db.profile.filters.quietTargets = true
		state.resting = true
		local out = names(ns)
		if out:find(named("Tess", "Target"), 1, true) then fail(scenario, "the target was offered in a city: " .. out) end
		state.resting = false
		if not names(ns):find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the target was not offered again out in the world")
		end
	end)
end

do
	local scenario = "quiettargets: on, out in the world the target is offered as ever"
	with(scenario, function(ns)
		ns.db.profile.filters.quietInInstances = true
		ns.db.profile.filters.quietInTowns = true
		ns.db.profile.filters.quietTargets = true
		if not names(ns):find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the target was dropped out in the world with neither place rule applying")
		end
	end)
end

do
	local scenario = "quiettargets: on, with neither place rule switched on nothing is held back"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietTargets = true
		state.inside = true
		if not names(ns):find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the target was dropped inside with both place rules off")
		end
	end)
end

do
	local scenario = "quiettargets: Who to buff has the switch, and it is kept"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "quietTargets")
		if not control then
			fail(scenario, "Who to buff has no switch for holding the target back too")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		local info = { "who", "quietTargets" }
		if control.get(info) then fail(scenario, "the switch is on in a new profile") end
		control.set(info, true)
		if ns.db.profile.filters.quietTargets ~= true or not control.get(info) then
			fail(scenario, "the switch was not kept")
		end
	end)
end
