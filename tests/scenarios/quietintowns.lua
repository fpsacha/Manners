-- Never in cities and inns (1.11.7). A player asked on Reddit for an option to
-- not offer while in cities and inns. Who to buff has it: with it on, while the
-- game calls you resting, nothing is offered to anybody -- passers-by, your
-- group, a favour you owe -- except somebody you target or focus, whom you
-- picked on purpose. Off by default. Passers-by only in a city (restingOnly) is
-- the other way round and stays as it was.
--
-- Every scenario name starts with "quietintowns:" so the mutations in
-- tests/mutations/quietintowns.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local TOUCHED = { "IsResting", "UnitInParty" }

-- One session as a mage, resting or not (`state.resting`), with a passer-by, a
-- party member and a target.
local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local state = { resting = false }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsResting", function() return state.resting end)
		rawset(_G, "UnitInParty", function(unit)
			return type(unit) == "string" and unit:find("^party%d") ~= nil
		end)
		freshPrompt(ns, scenario)
		ns.db.profile.sources.strangers = true
		ns.db.profile.sources.group = true
		body(ns, state)
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
	end)
	restore()
	for _, name in ipairs(TOUCHED) do rawset(_G, name, saved[name]) end
	Mock.reset()
	if not ok then fail(scenario, "threw: " .. tostring(err)) end
end

-- A name as the queue files it: Forever's two-part names, the others' first.
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
	local scenario = "quietintowns: off by default, and then a city changes nothing"
	with(scenario, function(ns, state)
		if ns.db.profile.filters.quietInTowns ~= false then fail(scenario, "the setting is not off by default") end
		local out = names(ns)
		if not (out:find(named("Anna", "Aim"), 1, true) and out:find(named("Gwen", "Hale"), 1, true) and out:find(named("Tess", "Target"), 1, true)) then
			fail(scenario, "SKIPPED -- three people are not offered with nothing set: " .. out)
			return
		end
		state.resting = true
		if names(ns) ~= out then fail(scenario, "resting changed who is offered with the setting off: " .. names(ns)) end
	end)
end

do
	local scenario = "quietintowns: on, nobody is offered in a city, not even a favour or the group"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInTowns = true
		state.resting = true
		owe(ns, named("Anna", "Aim"))
		local out = names(ns)
		if out:find(named("Anna", "Aim"), 1, true) then fail(scenario, "a passer-by who is owed was offered in a city: " .. out) end
		if out:find(named("Gwen", "Hale"), 1, true) then fail(scenario, "a party member was offered in a city: " .. out) end
	end)
end

do
	local scenario = "quietintowns: on, a favour owed to somebody out of sight waits for a city to end"
	with(scenario, function(ns, state)
		owe(ns, named("Zed", "Gone"))
		if not names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "SKIPPED -- a favour owed to somebody out of sight is not offered at all")
			return
		end
		ns.db.profile.filters.quietInTowns = true
		state.resting = true
		if names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "a favour owed to somebody out of sight was offered in a city")
		end
		state.resting = false
		if not names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "the favour was lost with the city: it is not offered out in the world")
		end
	end)
end

do
	local scenario = "quietintowns: on, a target or focus is still offered in a city"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInTowns = true
		state.resting = true
		local out = names(ns)
		if not out:find(named("Tess", "Target"), 1, true) then
			fail(scenario, "the person you targeted was dropped in a city: " .. out)
		end
	end)
end

do
	local scenario = "quietintowns: on, out in the world everybody is offered as ever"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInTowns = true
		state.resting = false
		local out = names(ns)
		if not (out:find(named("Anna", "Aim"), 1, true) and out:find(named("Gwen", "Hale"), 1, true)) then
			fail(scenario, "out in the world with the setting on, somebody was dropped: " .. out)
		end
	end)
end

do
	local scenario = "quietintowns: when resting cannot be told, nothing is held back"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInTowns = true
		for label, fn in pairs({
			secret = function() return Mock.SECRET end,
			throws = function() error("refused", 0) end,
		}) do
			rawset(_G, "IsResting", fn)
			local out = names(ns)
			if not (out:find(named("Anna", "Aim"), 1, true) and out:find(named("Gwen", "Hale"), 1, true)) then
				fail(scenario, ("when resting could not be told (%s), somebody was dropped: %s"):format(label, out))
			end
		end
	end)
end

do
	local scenario = "quietintowns: Who to buff has the switch, and it is kept"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "quietInTowns")
		if not control then
			fail(scenario, "Who to buff has no switch for nothing in cities and inns")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		local info = { "who", "quietInTowns" }
		if control.get(info) then fail(scenario, "the switch is on in a new profile") end
		control.set(info, true)
		if ns.db.profile.filters.quietInTowns ~= true or not control.get(info) then fail(scenario, "the switch was not kept") end
	end)
end
