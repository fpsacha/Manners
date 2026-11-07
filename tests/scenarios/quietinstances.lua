-- Never in dungeons, raids and battlegrounds (1.11.11). A player asked on
-- CurseForge for no offers inside an instance, where the group shares out its
-- own buffs. Who to buff has it, under Never in cities and inns, and it is the
-- same rule: with it on, inside a dungeon, raid, battleground, arena or
-- scenario, nothing is offered to anybody -- passers-by, your group, a favour
-- you owe -- except somebody you target or focus. Off by default; out in the
-- world, or when the game will not say where you are, nothing changes.
--
-- Every scenario name starts with "quietinstances:" so the mutations in
-- tests/mutations/quietinstances.py can name the one that has to catch them.

local dir, H = ...
local fail, load = H.fail, H.load
local strangers, freshPrompt, owe = H.strangers, H.freshPrompt, H.owe

local TOUCHED = { "IsInInstance", "UnitInParty" }

-- One session as a mage, inside or not (`state.inside`, `state.kind`), with a
-- passer-by, a party member and a target.
local function with(scenario, body)
	Mock.reset()
	Mock.class = "MAGE"
	Mock.groupSize = 2
	local saved = {}
	for _, name in ipairs(TOUCHED) do saved[name] = rawget(_G, name) end
	local state = { inside = false, kind = "none" }
	local restore = strangers({ nameplate1 = { "Anna", "Aim" }, party1 = { "Gwen", "Hale" },
		target = { "Tess", "Target" } })
	local ok, err = pcall(function()
		local ns = load(scenario)
		if not ns then return end
		rawset(_G, "IsInInstance", function() return state.inside, state.kind end)
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

local function enter(state, kind)
	state.inside, state.kind = true, kind
end

do
	local scenario = "quietinstances: off by default, and then a dungeon changes nothing"
	with(scenario, function(ns, state)
		if ns.db.profile.filters.quietInInstances ~= false then fail(scenario, "the setting is not off by default") end
		local out = names(ns)
		if not (out:find(named("Gwen", "Hale"), 1, true) and out:find(named("Tess", "Target"), 1, true)) then
			fail(scenario, "SKIPPED -- the party member and the target are not offered with nothing set: " .. out)
			return
		end
		enter(state, "party")
		if names(ns) ~= out then fail(scenario, "a dungeon changed who is offered with the setting off: " .. names(ns)) end
	end)
end

for _, kind in ipairs({ "party", "raid", "pvp", "arena", "scenario" }) do
	local scenario = "quietinstances: on, nobody but the target is offered inside (" .. kind .. ")"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInInstances = true
		enter(state, kind)
		owe(ns, named("Anna", "Aim"))
		local out = names(ns)
		if out:find(named("Anna", "Aim"), 1, true) then fail(scenario, "a passer-by who is owed was offered inside: " .. out) end
		if out:find(named("Gwen", "Hale"), 1, true) then fail(scenario, "a party member was offered inside: " .. out) end
		if not out:find(named("Tess", "Target"), 1, true) then fail(scenario, "the person you targeted was dropped inside: " .. out) end
	end)
end

do
	local scenario = "quietinstances: on, a favour owed to somebody out of sight waits for the instance to end"
	with(scenario, function(ns, state)
		owe(ns, named("Zed", "Gone"))
		if not names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "SKIPPED -- a favour owed to somebody out of sight is not offered at all")
			return
		end
		ns.db.profile.filters.quietInInstances = true
		enter(state, "raid")
		if names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "a favour owed to somebody out of sight was offered inside")
		end
		state.inside, state.kind = false, "none"
		if not names(ns):find(named("Zed", "Gone"), 1, true) then
			fail(scenario, "the favour was lost with the instance: it is not offered outside")
		end
	end)
end

do
	local scenario = "quietinstances: on, out in the world everybody is offered as ever"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInInstances = true
		local out = names(ns)
		if not (out:find(named("Anna", "Aim"), 1, true) and out:find(named("Gwen", "Hale"), 1, true)) then
			fail(scenario, "out in the world with the setting on, somebody was dropped: " .. out)
		end
	end)
end

do
	local scenario = "quietinstances: when the game will not say where you are, nothing is held back"
	with(scenario, function(ns, state)
		ns.db.profile.filters.quietInInstances = true
		for label, fn in pairs({
			secret = function() return Mock.SECRET, Mock.SECRET end,
			throws = function() error("refused", 0) end,
			nokind = function() return true, nil end,
		}) do
			rawset(_G, "IsInInstance", fn)
			local out = names(ns)
			if not (out:find(named("Anna", "Aim"), 1, true) and out:find(named("Gwen", "Hale"), 1, true)) then
				fail(scenario, ("when the instance could not be told (%s), somebody was dropped: %s"):format(label, out))
			end
		end
	end)
end

do
	local scenario = "quietinstances: Who to buff has the switch, and it is kept"
	with(scenario, function(ns)
		local control = H.findOption(ns.optionsTable, "quietInInstances")
		if not control then
			fail(scenario, "Who to buff has no switch for nothing inside an instance")
			return
		end
		if control.type ~= "toggle" then fail(scenario, "the switch is a " .. tostring(control.type)) end
		local info = { "who", "quietInInstances" }
		if control.get(info) then fail(scenario, "the switch is on in a new profile") end
		control.set(info, true)
		if ns.db.profile.filters.quietInInstances ~= true or not control.get(info) then fail(scenario, "the switch was not kept") end
	end)
end
